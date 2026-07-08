import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/database.dart';
import '../data/daos/daos.dart';
import 'conflict_resolver.dart';
import 'nodered_api.dart';
import 'sync_config.dart';

/// ============================================================
/// SyncEngine: 双向同步引擎 (OpLogSyncEngine 的升级版)
///
/// 与 OpLogSyncEngine 的关系:
///   - OpLogSyncEngine 仅做单向上行 (本地 → 服务端), 逐条推送
///   - SyncEngine 做双向同步 (上行批量推送 + 下行游标拉取)
///   - 两者共存, SyncEngine 是更完整的实现
///
/// 同步流程:
///   上行 (pushChanges):
///     1. 扫描 unsynced OpLog (批量)
///     2. 按 tableName 分组
///     3. 调用 /api/v1/sync/push 批量上传
///     4. 标记 synced
///
///   下行 (pullChanges):
///     1. 使用 _lastSyncCursor 请求增量变更 (/api/v1/sync/pull)
///     2. 解析响应中的变更记录
///     3. 按 opType (INSERT/UPDATE/DELETE) 应用到本地 DB
///        - INSERT: 插入新记录
///        - UPDATE: 更新现有记录 (使用 updatedAt + Lamport Clock 冲突解决)
///        - DELETE: 软删除 (设置 deletedAt)
///     4. 更新 _lastSyncCursor
///
/// 冲突解决策略: Last-Write-Wins + Lamport Clock
/// ============================================================

/// 同步状态枚举
enum SyncStatus {
  /// 空闲 (未在同步)
  idle,

  /// 正在同步
  syncing,

  /// 同步成功
  success,

  /// 同步失败
  failed,

  /// 离线 (网络不可达)
  offline,
}

/// 单次同步结果
class SyncResult {
  /// 同步最终状态
  final SyncStatus status;

  /// 上行推送的条数
  final int pushedCount;

  /// 下行拉取并应用的条数
  final int pulledCount;

  /// 错误信息 (失败时)
  final String? error;

  /// 同步完成时间戳
  final DateTime timestamp;

  SyncResult({
    required this.status,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'SyncResult(status: $status, pushed: $pushedCount, '
        'pulled: $pulledCount, error: $error, at: $timestamp)';
  }
}

/// 双向同步引擎
class SyncEngine {
  final AppDatabase _db;
  final NodeRedApi _api;
  final SyncConfig _config;
  final OpLogDao _opLogDao;

  /// 定时同步计时器
  Timer? _timer;

  /// 当前同步状态
  SyncStatus _status = SyncStatus.idle;

  /// 最后一次同步时间
  DateTime? _lastSyncTime;

  /// 下行同步游标 (游标式增量拉取, null 表示从头开始)
  String? _lastSyncCursor;

  /// 重试计数器 (连续失败次数)
  int _retryCount = 0;

  /// 同步状态广播控制器
  final _statusController = StreamController<SyncStatus>.broadcast();

  /// 防止并发同步的锁
  bool _isSyncing = false;

  // ============================================================
  // 表名 → SQLite 表名 + 主键列 的映射
  // ============================================================

  /// 业务表主键列名映射 (tableName → pkColumnName)
  static const Map<String, String> _pkColumns = {
    'executable_units': 'id',
    'learning_task_exts': 'unit_id',
    'workout_plan_exts': 'unit_id',
    'workout_exercises': 'exercise_id',
    'schedule_entries': 'entry_id',
    'sessions': 'session_id',
    'session_segments': 'segment_id',
    'goals': 'goal_id',
    'streaks': 'streak_id',
  };

  /// 同步元数据字段 (不属于业务表列, 应用变更时需排除)
  static const Set<String> _syncMetaKeys = {
    'lamport_clock',
    'device_id',
    'op_type',
    'cursor',
    'table',
    'record_id',
  };

  // ============================================================
  // 构造函数
  // ============================================================

  SyncEngine({
    required AppDatabase db,
    required NodeRedApi api,
    required SyncConfig config,
  })  : _db = db,
        _api = api,
        _config = config,
        _opLogDao = OpLogDao(db);

  // ============================================================
  // 公开属性
  // ============================================================

  /// 监听同步状态变化
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// 当前同步状态
  SyncStatus get status => _status;

  /// 最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 最后同步游标
  String? get lastSyncCursor => _lastSyncCursor;

  /// 当前设备 ID
  String get deviceId => _config.deviceId;

  // ============================================================
  // 生命周期管理
  // ============================================================

  /// 启动定时同步
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _config.syncInterval),
      (_) => sync(),
    );
    // 启动时立即同步一次
    sync();
  }

  /// 停止同步
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源
  void dispose() {
    stop();
    _statusController.close();
  }

  // ============================================================
  // 核心同步逻辑
  // ============================================================

  /// 手动触发一次完整同步 (上行 + 下行)
  Future<SyncResult> sync() async {
    // 防止并发
    if (_isSyncing) {
      return SyncResult(
        status: _status,
        error: '同步正在进行中, 跳过本次触发',
      );
    }

    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    int totalPushed = 0;
    int totalPulled = 0;

    try {
      // 1. 上行: 推送本地变更到服务端
      totalPushed = await pushChanges();

      // 2. 下行: 拉取服务端变更
      totalPulled = await pullChanges();

      // 3. 更新同步元数据
      _lastSyncTime = DateTime.now();
      _retryCount = 0;
      _setStatus(SyncStatus.success);

      return SyncResult(
        status: SyncStatus.success,
        pushedCount: totalPushed,
        pulledCount: totalPulled,
      );
    } catch (e) {
      _retryCount++;

      // 判断是网络错误还是服务端错误
      final isOffline = _isNetworkError(e);
      _setStatus(isOffline ? SyncStatus.offline : SyncStatus.failed);

      return SyncResult(
        status: isOffline ? SyncStatus.offline : SyncStatus.failed,
        pushedCount: totalPushed,
        pulledCount: totalPulled,
        error: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// ============================================================
  /// 上行: 推送本地变更到服务端
  ///
  /// 流程:
  ///   1. 查询 unsynced OpLog (limit = pushBatchSize)
  ///   2. 组装批量推送请求体
  ///   3. 调用 /api/v1/sync/push 批量上传
  ///   4. 服务端确认后, 标记 synced
  ///
  /// 返回成功推送的条数
  /// ============================================================
  Future<int> pushChanges() async {
    // 1. 查询未同步的操作日志
    final unsyncedLogs = await _opLogDao.getUnsynced(limit: _config.pushBatchSize);
    if (unsyncedLogs.isEmpty) return 0;

    // 2. 组装批量推送请求体
    final operations = unsyncedLogs.map((log) {
      return {
        'op_id': log.opId,
        'table': log.tblName,
        'record_id': log.recordId,
        'op_type': log.opType,
        'payload': log.payload,
        'device_id': log.deviceId ?? _config.deviceId,
        'lamport_clock': log.lamportClock ?? 0,
        'created_at': log.createdAt,
      };
    }).toList();

    final requestBody = {
      'device_id': _config.deviceId,
      'operations': operations,
    };

    // 3. 调用批量上传 API (带重试)
    final response = await _httpPostWithRetry(
      _config.pushUrl,
      requestBody,
    );

    // 4. 解析响应, 标记已同步
    final syncedOpIds = <int>[];
    final syncedList = response['synced_op_ids'] as List?;
    if (syncedList != null) {
      for (final id in syncedList) {
        syncedOpIds.add((id as num).toInt());
      }
    } else {
      // 服务端未返回具体的 op_id 列表 → 假设全部成功
      syncedOpIds.addAll(unsyncedLogs.map((log) => log.opId));
    }

    if (syncedOpIds.isNotEmpty) {
      await _opLogDao.markBatchSynced(syncedOpIds);
    }

    return syncedOpIds.length;
  }

  /// ============================================================
  /// 下行: 拉取服务端变更
  ///
  /// 流程:
  ///   1. 使用 _lastSyncCursor 请求增量变更
  ///   2. 解析响应中的变更记录
  ///   3. 按 opType (INSERT/UPDATE/DELETE) 应用到本地 DB
  ///   4. 更新 _lastSyncCursor
  ///
  /// 返回成功应用的条数
  /// ============================================================
  Future<int> pullChanges() async {
    int totalApplied = 0;
    bool hasMore = true;

    // 循环拉取直到没有更多变更 (服务端分页)
    while (hasMore) {
      // 1. 构建拉取请求
      final uri = Uri.parse(_config.pullUrl).replace(
        queryParameters: {
          'device_id': _config.deviceId,
          'limit': _config.pullBatchSize.toString(),
          if (_lastSyncCursor != null) 'cursor': _lastSyncCursor!,
        },
      );

      // 2. 请求增量变更
      final response = await _httpGetWithRetry(uri.toString());

      // 3. 解析变更记录
      final changes = response['changes'] as List? ?? [];
      final nextCursor = response['next_cursor'] as String?;
      hasMore = (response['has_more'] as bool?) ?? false;

      // 4. 应用变更到本地 DB (事务保证原子性)
      if (changes.isNotEmpty) {
        final applied = await _db.transaction(() async {
          int count = 0;
          for (final change in changes) {
            final changeMap = change as Map<String, dynamic>;
            final success = await _applyChange(changeMap);
            if (success) count++;
          }
          return count;
        });
        totalApplied += applied;
      }

      // 5. 更新游标
      _lastSyncCursor = nextCursor ?? _lastSyncCursor;

      // 没有更多变更 → 退出循环
      if (changes.isEmpty) break;
    }

    return totalApplied;
  }

  // ============================================================
  // 变更应用 (下行同步核心)
  // ============================================================

  /// 应用单条远程变更到本地数据库
  ///
  /// [change] 变更记录, 格式:
  ///   {
  ///     "table": "sessions",
  ///     "record_id": 42,
  ///     "op_type": "UPDATE",
  ///     "data": { ... },
  ///     "updated_at": "2026-07-08T10:00:00",
  ///     "lamport_clock": 15,
  ///     "device_id": "device-A"
  ///   }
  ///
  /// 返回 true 表示成功应用, false 表示跳过 (冲突解决后本地胜出)
  Future<bool> _applyChange(Map<String, dynamic> change) async {
    final tableName = change['table'] as String?;
    final recordId = change['record_id'] as int?;
    final opType = change['op_type'] as String?;
    final data = change['data'] as Map<String, dynamic>? ?? {};

    // 参数校验
    if (tableName == null || recordId == null || opType == null) {
      return false;
    }

    // 未知表 → 跳过
    final pkCol = _pkColumns[tableName];
    if (pkCol == null) {
      return false;
    }

    switch (opType.toUpperCase()) {
      case 'INSERT':
        return _applyInsert(tableName, pkCol, recordId, data, change);
      case 'UPDATE':
        return _applyUpdate(tableName, pkCol, recordId, data, change);
      case 'DELETE':
        return _applyDelete(tableName, pkCol, recordId, change);
      default:
        return false;
    }
  }

  /// 应用 INSERT 操作
  ///
  /// 如果本地已存在同 ID 记录 → 走冲突解决流程
  /// 如果本地不存在 → 直接插入
  Future<bool> _applyInsert(
    String table,
    String pkCol,
    int recordId,
    Map<String, dynamic> data,
    Map<String, dynamic> change,
  ) async {
    // 检查本地是否已存在该记录
    final localRecord = await _getLocalRecord(table, pkCol, recordId);

    if (localRecord != null) {
      // 本地已存在 → 冲突解决
      return _resolveAndApply(
        table: table,
        pkCol: pkCol,
        recordId: recordId,
        remoteData: data,
        change: change,
        localRecord: localRecord,
        isDelete: false,
      );
    }

    // 本地不存在 → 直接插入
    await _insertRecord(table, pkCol, recordId, data);
    return true;
  }

  /// 应用 UPDATE 操作
  ///
  /// 如果本地不存在 → 当作 INSERT 处理
  /// 如果本地存在 → 冲突解决后决定是否覆盖
  Future<bool> _applyUpdate(
    String table,
    String pkCol,
    int recordId,
    Map<String, dynamic> data,
    Map<String, dynamic> change,
  ) async {
    final localRecord = await _getLocalRecord(table, pkCol, recordId);

    if (localRecord == null) {
      // 本地不存在 → 直接插入
      await _insertRecord(table, pkCol, recordId, data);
      return true;
    }

    // 本地存在 → 冲突解决
    return _resolveAndApply(
      table: table,
      pkCol: pkCol,
      recordId: recordId,
      remoteData: data,
      change: change,
      localRecord: localRecord,
      isDelete: false,
    );
  }

  /// 应用 DELETE 操作 (软删除)
  ///
  /// 冲突解决: 如果本地有更新的未同步变更 → 拒绝远程删除
  Future<bool> _applyDelete(
    String table,
    String pkCol,
    int recordId,
    Map<String, dynamic> change,
  ) async {
    final localRecord = await _getLocalRecord(table, pkCol, recordId);

    if (localRecord == null) {
      // 本地已不存在 → 无需操作
      return true;
    }

    // 冲突解决: 检查本地是否有更新的变更
    final remoteUpdatedAt = (change['updated_at'] as String?) ?? '';
    final localUpdatedAt = (localRecord['updated_at'] as String?) ?? '';
    final remoteLamport = ConflictResolver.extractLamport(change);
    final localLamport = _getLocalLamport(localRecord);

    final remoteWins = ConflictResolver.shouldRemoteWin(
      remoteUpdatedAt: remoteUpdatedAt.isNotEmpty
          ? remoteUpdatedAt
          : DateTime.now().toIso8601String(),
      localUpdatedAt: localUpdatedAt.isNotEmpty
          ? localUpdatedAt
          : '1970-01-01T00:00:00',
      remoteLamport: remoteLamport,
      localLamport: localLamport,
      remoteDeviceId: change['device_id'] as String?,
      localDeviceId: _config.deviceId,
    );

    if (!remoteWins) {
      // 本地有更新数据 → 拒绝删除 (本地变更会通过上行同步覆盖)
      return false;
    }

    // 执行软删除 (设置 deleted_at)
    final now = DateTime.now().toIso8601String();
    await _db.customStatement(
      'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE $pkCol = ?',
      [now, now, recordId],
    );
    return true;
  }

  // ============================================================
  // 冲突解决 (内部方法)
  // ============================================================

  /// 冲突解决并应用
  ///
  /// 使用 Last-Write-Wins + Lamport Clock 策略比较远程与本地记录。
  /// 远程胜出 → 覆盖本地; 本地胜出 → 跳过 (本地变更会通过上行同步推送)。
  Future<bool> _resolveAndApply({
    required String table,
    required String pkCol,
    required int recordId,
    required Map<String, dynamic> remoteData,
    required Map<String, dynamic> change,
    required Map<String, dynamic> localRecord,
    required bool isDelete,
  }) {
    return _shouldResolveConflict(change, localRecord).then((remoteWins) {
      if (!remoteWins) {
        // 本地胜出 → 跳过, 本地变更会通过上行同步推送
        return false;
      }

      // 远程胜出 → 合并字段并覆盖本地
      final merged = ConflictResolver.mergeFields(
        remoteData,
        localRecord,
        remoteWins: true,
      );

      // 使用 INSERT OR REPLACE 覆盖本地记录
      return _upsertRecord(table, pkCol, recordId, merged).then((_) => true);
    });
  }

  /// 冲突解决策略 (Last-Write-Wins with Lamport Clock)
  ///
  /// 比较远程与本地记录的 updatedAt 和 lamportClock,
  /// 返回 true 表示远程记录应覆盖本地。
  Future<bool> _shouldResolveConflict(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) async {
    final remoteUpdatedAt = (remote['updated_at'] as String?) ?? '';
    final localUpdatedAt = (local['updated_at'] as String?) ?? '';
    final remoteLamport = ConflictResolver.extractLamport(remote);
    final localLamport = _getLocalLamport(local);

    return ConflictResolver.shouldRemoteWin(
      remoteUpdatedAt: remoteUpdatedAt.isNotEmpty
          ? remoteUpdatedAt
          : DateTime.now().toIso8601String(),
      localUpdatedAt: localUpdatedAt.isNotEmpty
          ? localUpdatedAt
          : '1970-01-01T00:00:00',
      remoteLamport: remoteLamport,
      localLamport: localLamport,
      remoteDeviceId: remote['device_id'] as String?,
      localDeviceId: _config.deviceId,
    );
  }

  // ============================================================
  // 数据库操作辅助方法
  // ============================================================

  /// 查询本地记录 (返回包含所有列的 Map, 不存在返回 null)
  Future<Map<String, dynamic>?> _getLocalRecord(
    String table,
    String pkCol,
    int recordId,
  ) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM $table WHERE $pkCol = ?',
            [recordId],
          )
          .get();
      if (rows.isEmpty) return null;
      return rows.first.data;
    } catch (_) {
      return null;
    }
  }

  /// 从本地记录中提取 Lamport 时钟值
  ///
  /// 业务表本身不存储 lamport_clock, 这里从 data map 中尝试读取,
  /// 如果不存在则返回 0 (本地记录默认优先级最低)。
  int _getLocalLamport(Map<String, dynamic> localRecord) {
    return (localRecord['lamport_clock'] as num?)?.toInt() ?? 0;
  }

  /// 插入新记录到本地表
  ///
  /// 使用 INSERT OR REPLACE 语义, 如果主键冲突则覆盖。
  Future<void> _insertRecord(
    String table,
    String pkCol,
    int recordId,
    Map<String, dynamic> data,
  ) async {
    return _upsertRecord(table, pkCol, recordId, data);
  }

  /// 插入或更新记录 (INSERT OR REPLACE)
  ///
  /// 从 data map 中提取业务列 (排除同步元数据字段),
  /// 动态构建 SQL 并执行。
  Future<void> _upsertRecord(
    String table,
    String pkCol,
    int recordId,
    Map<String, dynamic> data,
  ) async {
    // 过滤掉同步元数据字段, 只保留业务列
    final columns = data.keys
        .where((key) => !_syncMetaKeys.contains(key))
        .toList();

    if (columns.isEmpty) return;

    // 确保主键列在数据中
    final allColumns = <String>{...columns, pkCol};
    final columnList = allColumns.join(', ');
    final placeholders = allColumns.map((_) => '?').join(', ');

    // 构建 args: 先业务列值, 再主键值
    final args = <Object?>[];
    for (final col in allColumns) {
      if (col == pkCol) {
        args.add(recordId);
      } else {
        args.add(_normalizeValue(data[col]));
      }
    }

    final sql = 'INSERT OR REPLACE INTO $table ($columnList) VALUES ($placeholders)';
    await _db.customStatement(sql, args);
  }

  /// 规范化值: 将 Dart 值转为 SQLite 兼容类型
  Object? _normalizeValue(Object? value) {
    if (value == null) return null;
    if (value is bool) return value ? 1 : 0; // SQLite 用 0/1 存储布尔值
    if (value is List || value is Map) return jsonEncode(value); // 复杂类型序列化
    return value;
  }

  // ============================================================
  // HTTP 通信 (同步专用端点)
  // ============================================================

  /// 带重试的 POST 请求 (指数退避)
  Future<Map<String, dynamic>> _httpPostWithRetry(
    String url,
    Map<String, dynamic> body,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await _httpPost(url, body);
      } catch (e) {
        if (!_isRetryable(e) || attempt >= _config.maxRetryCount) {
          rethrow;
        }
        // 指数退避: 1s → 2s → 4s
        final delaySeconds = 1 << attempt;
        await Future.delayed(Duration(seconds: delaySeconds));
        attempt++;
      }
    }
  }

  /// 带重试的 GET 请求 (指数退避)
  Future<Map<String, dynamic>> _httpGetWithRetry(String url) async {
    int attempt = 0;
    while (true) {
      try {
        return await _httpGet(url);
      } catch (e) {
        if (!_isRetryable(e) || attempt >= _config.maxRetryCount) {
          rethrow;
        }
        final delaySeconds = 1 << attempt;
        await Future.delayed(Duration(seconds: delaySeconds));
        attempt++;
      }
    }
  }

  /// 单次 POST 请求
  Future<Map<String, dynamic>> _httpPost(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer ${_api.apiToken}',
            'Content-Type': 'application/json',
            'X-Device-Id': _config.deviceId,
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: _config.timeoutSeconds));

    if (response.statusCode != 200) {
      throw SyncException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 单次 GET 请求
  Future<Map<String, dynamic>> _httpGet(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer ${_api.apiToken}',
            'Content-Type': 'application/json',
            'X-Device-Id': _config.deviceId,
          },
        )
        .timeout(Duration(seconds: _config.timeoutSeconds));

    if (response.statusCode != 200) {
      throw SyncException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 判断错误是否可重试 (超时、5xx 可重试; 4xx 不可重试)
  bool _isRetryable(Object error) {
    if (error is SyncException) {
      return error.statusCode >= 500;
    }
    // 超时及其它网络层异常默认可重试
    return true;
  }

  /// 判断是否为网络错误 (离线)
  bool _isNetworkError(Object error) {
    if (error is http.ClientException) return true;
    if (error is TimeoutException) return true;
    if (error is SyncException && error.statusCode >= 500) return true;
    return false;
  }

  /// 更新同步状态并广播
  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }
}

/// ============================================================
/// 同步异常
/// ============================================================
class SyncException implements Exception {
  final int statusCode;
  final String body;

  SyncException(this.statusCode, this.body);

  @override
  String toString() => 'SyncException($statusCode): $body';
}
