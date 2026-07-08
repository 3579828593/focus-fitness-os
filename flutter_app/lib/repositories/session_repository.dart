import 'dart:convert';
import '../data/database.dart';
import '../data/daos/daos.dart';
import '../data/tables.dart';
import '../services/nodered_api.dart';
import 'package:drift/drift.dart';

/// ============================================================
/// SessionRepository: 会话数据仓库
/// 整合 SessionDao + NodeRedApi + LocalFallbackRules + OpLogDao
/// UI 层通过此仓库访问数据，不直接操作 DAO 或 API
/// ============================================================
class SessionRepository {
  final AppDatabase _db;
  final NodeRedApi _api;
  final SessionDao _sessionDao;
  final OpLogDao _opLogDao;

  SessionRepository(this._db, this._api)
      : _sessionDao = SessionDao(_db),
        _opLogDao = OpLogDao(_db);

  /// 创建会话记录
  Future<int> createSession(int entryId) async {
    final now = DateTime.now().toIso8601String();
    final sessionId = await _sessionDao.createSession(
      SessionsCompanion.insert(
        entryId: entryId,
        state: const Constant('CREATED'),
        createdAt: Value(now),
        startedAt: Value(now),
      ),
    );
    // 记录操作日志
    await _opLogDao.logOperation(
      tableName: 'sessions',
      recordId: sessionId,
      opType: 'INSERT',
      payload: {'session_id': sessionId, 'entry_id': entryId, 'state': 'CREATED'},
    );
    return sessionId;
  }

  /// 更新会话状态
  Future<void> updateSessionState(
    int sessionId,
    String state, {
    double? completionRatio,
    String? endedAt,
  }) async {
    await _sessionDao.updateSessionState(
      sessionId,
      state,
      completionRatio: completionRatio,
      endedAt: endedAt,
    );
    // 记录操作日志
    await _opLogDao.logOperation(
      tableName: 'sessions',
      recordId: sessionId,
      opType: 'UPDATE',
      payload: {
        'session_id': sessionId,
        'state': state,
        'completion_ratio': completionRatio,
        'ended_at': endedAt,
      },
    );
  }

  /// 保存训练片段
  Future<void> saveSegments(int sessionId, List<SessionSegmentsCompanion> segments) async {
    await _sessionDao.createSegments(segments);
    // 记录操作日志
    await _opLogDao.logOperation(
      tableName: 'session_segments',
      recordId: sessionId,
      opType: 'INSERT',
      payload: {'session_id': sessionId, 'count': segments.length},
    );
  }

  /// 上报训练完成到后端 (含降级策略)
  /// 成功: 调用 NodeRedApi.reportSessionComplete
  /// 失败: 使用 LocalFallbackRules 本地计算 + 写入 OpLog 等待同步
  Future<SessionReportResult> reportSessionComplete({
    required int sessionId,
    required int entryId,
    required double completionRatio,
    required List<Map<String, dynamic>> segments,
    double currentWeight = 0,
  }) async {
    try {
      final result = await _api.reportSessionComplete(
        sessionId: sessionId,
        entryId: entryId,
        completionRatio: completionRatio,
        segments: segments,
      );
      return SessionReportResult(
        success: true,
        source: ReportSource.remote,
        responseData: result,
      );
    } catch (e) {
      // 降级: 本地计算新重量
      final newWeight = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );
      // 写入 OpLog 等待后续同步
      await _opLogDao.logOperation(
        tableName: 'sessions',
        recordId: sessionId,
        opType: 'UPDATE',
        payload: {
          'session_id': sessionId,
          'completion_ratio': completionRatio,
          'fallback_new_weight': newWeight,
          'error': e.toString(),
        },
      );
      return SessionReportResult(
        success: true,
        source: ReportSource.localFallback,
        fallbackWeight: newWeight,
      );
    }
  }

  /// 查询活跃会话 (用于续接)
  Future<Session?> getActiveSession(int entryId) {
    return _sessionDao.getActiveSessionByEntry(entryId);
  }

  /// 监听某日日程
  Stream<List<ScheduleEntry>> watchSchedule(String date) {
    return ScheduleDao(_db).watchByDate(date);
  }
}

/// 上报结果
class SessionReportResult {
  final bool success;
  final ReportSource source;
  final Map<String, dynamic>? responseData;
  final double? fallbackWeight;

  SessionReportResult({
    required this.success,
    required this.source,
    this.responseData,
    this.fallbackWeight,
  });
}

/// 上报来源
enum ReportSource {
  remote, // Node-RED 后端成功处理
  localFallback, // 本地降级规则
}
