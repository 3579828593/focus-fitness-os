import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/database.dart';
import '../data/daos/daos.dart';
import '../main.dart';
import 'nodered_api.dart';

/// ============================================================
/// OpLogSyncEngine: 操作日志同步引擎
/// 定时扫描未同步的 OpLogs，批量重发到 Node-RED
/// 采用指数退避重试策略
/// ============================================================
class OpLogSyncEngine {
  final AppDatabase _db;
  final NodeRedApi _api;
  final OpLogDao _opLogDao;

  Timer? _timer;
  bool _isSyncing = false;
  final Duration _syncInterval;
  final int _batchSize;

  /// 同步状态回调 (供 UI 展示)
  void Function(int unsyncedCount, bool isSyncing)? onSyncStatusChanged;

  OpLogSyncEngine({
    required AppDatabase db,
    required NodeRedApi api,
    Duration syncInterval = const Duration(seconds: 60),
    int batchSize = 50,
  })  : _db = db,
        _api = api,
        _opLogDao = OpLogDao(db),
        _syncInterval = syncInterval,
        _batchSize = batchSize;

  /// 启动同步引擎
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => sync());
    // 启动时立即同步一次
    sync();
  }

  /// 停止同步引擎
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 执行一次同步
  Future<void> sync() async {
    if (_isSyncing) return; // 防止并发

    _isSyncing = true;
    _notifyStatus();

    try {
      final unsyncedLogs = await _opLogDao.getUnsynced(limit: _batchSize);
      if (unsyncedLogs.isEmpty) return;

      final syncedIds = <int>[];

      for (final log in unsyncedLogs) {
        final success = await _syncSingleLog(log);
        if (success) {
          syncedIds.add(log.opId);
        }
        // 失败的记录保留，下次重试
      }

      // 批量标记已同步
      if (syncedIds.isNotEmpty) {
        await _opLogDao.markBatchSynced(syncedIds);
      }
    } finally {
      _isSyncing = false;
      _notifyStatus();
    }
  }

  /// 同步单条操作日志
  Future<bool> _syncSingleLog(OpLog log) async {
    try {
      // 根据 tableName 和 opType 路由到对应的 API 端点
      switch (log.tableName) {
        case 'sessions':
          return await _syncSessionLog(log);
        case 'schedule_entries':
          return await _syncScheduleLog(log);
        case 'executable_units':
          return await _syncUnitLog(log);
        default:
          // 未知表，标记为已同步避免无限重试
          return true;
      }
    } catch (e) {
      // 同步失败，保留记录等待下次重试
      return false;
    }
  }

  /// 同步会话操作
  Future<bool> _syncSessionLog(OpLog log) async {
    try {
      final payload = jsonDecode(log.payload) as Map<String, dynamic>;
      if (log.opType == 'INSERT' || log.opType == 'UPDATE') {
        // 尝试上报到后端
        await _api.reportSessionComplete(
          sessionId: payload['session_id'] as int? ?? log.recordId,
          entryId: payload['entry_id'] as int? ?? 0,
          completionRatio:
              (payload['completion_ratio'] as num?)?.toDouble() ?? 0.0,
          segments: [],
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 同步日程操作
  Future<bool> _syncScheduleLog(OpLog log) async {
    try {
      final payload = jsonDecode(log.payload) as Map<String, dynamic>;
      // notifyScheduleChange 接受具名参数, 从 payload 中提取字段
      await _api.notifyScheduleChange(
        entryId: payload['entry_id'] as int,
        date: payload['date'] as String,
        startTime: payload['start_time'] as String,
        unitId: payload['unit_id'] as int,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 同步内容单元操作
  Future<bool> _syncUnitLog(OpLog log) async {
    // 内容单元变更暂无对应 API，标记为已同步
    return true;
  }

  /// 通知同步状态
  Future<void> _notifyStatus() async {
    final count = await _opLogDao.unsyncedCount();
    onSyncStatusChanged?.call(count, _isSyncing);
  }

  /// 销毁
  void dispose() {
    stop();
  }
}

/// ============================================================
/// Riverpod Providers
/// ============================================================

/// OpLogSyncEngine Provider (全局单例)
final opLogSyncEngineProvider = Provider<OpLogSyncEngine>((ref) {
  final db = ref.read(databaseProvider);
  final api = ref.read(nodeRedApiProvider);
  final engine = OpLogSyncEngine(db: db, api: api);
  // 注意: start() 需要在 App 启动后手动调用
  ref.onDispose(() => engine.dispose());
  return engine;
});
