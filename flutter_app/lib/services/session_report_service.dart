import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/database.dart';
import '../data/daos/daos.dart';
import '../main.dart';
import '../runners/session_state.dart';
import 'nodered_api.dart';

/// ============================================================
/// SessionReportService: 会话上报编排服务
/// 职责: 编排 NodeRedApi 上报 + LocalFallbackRules 降级 + OpLog 记录
/// 被 SessionRepository 调用，也可被 Screen 直接调用
/// ============================================================
class SessionReportService {
  final NodeRedApi _api;
  final OpLogDao _opLogDao;

  SessionReportService(AppDatabase db, this._api) : _opLogDao = OpLogDao(db);

  /// 上报训练完成 (含自动降级)
  ///
  /// 流程:
  /// 1. 尝试调用 NodeRedApi.reportSessionComplete
  /// 2. 成功 → 返回远程结果
  /// 3. 失败 → LocalFallbackRules.calculateNewWeight 本地计算
  /// 4. 失败 → 写入 OpLog (synced=false) 等待 OpLogSyncEngine 重发
  Future<ReportOutcome> reportWorkoutComplete({
    required int sessionId,
    required int entryId,
    required double completionRatio,
    required List<SegmentData> segments,
    double currentWeight = 0,
  }) async {
    // 构造 segments payload (仅提取训练组数据)
    final segmentsPayload = segments
        .where((s) => s.segType == SegmentType.workoutSet)
        .map((s) => <String, dynamic>{
              'seg_type': s.segTypeString,
              'reps_done': s.repsDone ?? 0,
              'weight_kg_done': s.weightKgDone ?? 0,
              'rpe': s.rpe ?? 0,
            })
        .toList();

    try {
      // 尝试远程上报
      final result = await _api.reportSessionComplete(
        sessionId: sessionId,
        entryId: entryId,
        completionRatio: completionRatio,
        segments: segmentsPayload,
      );
      return ReportOutcome(
        status: ReportStatus.remoteSuccess,
        responseData: result,
      );
    } catch (e) {
      // 降级: 本地计算新重量
      final newWeight = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );

      // 写入 OpLog 等待同步引擎重发
      await _opLogDao.logOperation(
        tableName: 'sessions',
        recordId: sessionId,
        opType: 'UPDATE',
        payload: {
          'session_id': sessionId,
          'entry_id': entryId,
          'completion_ratio': completionRatio,
          'segments': segmentsPayload,
          'fallback_new_weight': newWeight,
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return ReportOutcome(
        status: ReportStatus.localFallback,
        fallbackWeight: newWeight,
        error: e.toString(),
      );
    }
  }

  /// 上报专注会话完成
  Future<ReportOutcome> reportFocusComplete({
    required int sessionId,
    required int entryId,
    required double completionRatio,
  }) async {
    try {
      final result = await _api.reportSessionComplete(
        sessionId: sessionId,
        entryId: entryId,
        completionRatio: completionRatio,
        segments: [],
      );
      return ReportOutcome(
        status: ReportStatus.remoteSuccess,
        responseData: result,
      );
    } catch (e) {
      // 专注会话无需降级计算，仅记录 OpLog
      await _opLogDao.logOperation(
        tableName: 'sessions',
        recordId: sessionId,
        opType: 'UPDATE',
        payload: {
          'session_id': sessionId,
          'entry_id': entryId,
          'completion_ratio': completionRatio,
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return ReportOutcome(
        status: ReportStatus.localFallback,
        error: e.toString(),
      );
    }
  }
}

/// 上报结果
class ReportOutcome {
  final ReportStatus status;
  final Map<String, dynamic>? responseData;
  final double? fallbackWeight;
  final String? error;

  ReportOutcome({
    required this.status,
    this.responseData,
    this.fallbackWeight,
    this.error,
  });

  bool get isSuccess => status == ReportStatus.remoteSuccess;
  bool get isFallback => status == ReportStatus.localFallback;
}

/// 上报状态
enum ReportStatus {
  remoteSuccess, // 远程上报成功
  localFallback, // 本地降级
}

/// ============================================================
/// Riverpod Providers
/// ============================================================

/// SessionReportService Provider
final sessionReportServiceProvider = Provider<SessionReportService>((ref) {
  final db = ref.read(databaseProvider);
  final api = ref.read(nodeRedApiProvider);
  return SessionReportService(db, api);
});
