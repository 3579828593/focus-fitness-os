import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod/riverpod.dart';

import '../data/database.dart';
import '../repositories/providers.dart';
import '../repositories/session_repository.dart';
import '../repositories/workout_repository.dart';
import '../runners/session_state.dart';
import '../services/tts_service.dart';
import '../services/tts/tts_factory.dart';

/// ============================================================
/// 健身会话不可变状态
/// 持有 WorkoutRunner 引用 + 派生 UI 字段
/// ============================================================
class WorkoutSessionState {
  final WorkoutRunner? runner;
  final int remainingSeconds;
  final List<String> ttsMessages;
  final int? sessionId;
  final bool isInitialized;
  final double rpe;
  final bool isResting;
  final bool isWaitingConfirm;
  final bool isDone;

  const WorkoutSessionState({
    this.runner,
    this.remainingSeconds = 0,
    this.ttsMessages = const [],
    this.sessionId,
    this.isInitialized = false,
    this.rpe = 7.0,
    this.isResting = false,
    this.isWaitingConfirm = false,
    this.isDone = false,
  });

  WorkoutSessionState copyWith({
    WorkoutRunner? runner,
    int? remainingSeconds,
    List<String>? ttsMessages,
    int? sessionId,
    bool? isInitialized,
    double? rpe,
    bool? isResting,
    bool? isWaitingConfirm,
    bool? isDone,
  }) {
    return WorkoutSessionState(
      runner: runner ?? this.runner,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      ttsMessages: ttsMessages ?? this.ttsMessages,
      sessionId: sessionId ?? this.sessionId,
      isInitialized: isInitialized ?? this.isInitialized,
      rpe: rpe ?? this.rpe,
      isResting: isResting ?? this.isResting,
      isWaitingConfirm: isWaitingConfirm ?? this.isWaitingConfirm,
      isDone: isDone ?? this.isDone,
    );
  }
}

/// ============================================================
/// WorkoutSessionNotifier: 健身训练会话状态管理
///
/// 职责:
/// - 读取 DB 获取动作数据, 创建 WorkoutRunner
/// - 创建/更新 DB 会话记录
/// - 管理休息倒计时 Timer (最后3秒 TTS 倒数)
/// - 终态时保存片段到 DB + 上报 NodeRedApi (失败降级)
/// - 内部管理 TtsQueue + FlutterTts
/// ============================================================
class WorkoutSessionNotifier extends Notifier<WorkoutSessionState> {
  Timer? _timer;
  TtsQueue? _ttsQueue;
  TtsService? _tts;
  int _entryId = 0; // 当前会话对应的日程 ID (上报用)

  @override
  WorkoutSessionState build() {
    // 注册资源释放 (provider 被 dispose 时触发)
    ref.onDispose(() {
      _timer?.cancel();
      _ttsQueue?.dispose();
    });
    return const WorkoutSessionState();
  }

  /// 初始化: 读取 DB 动作数据 → 创建 WorkoutRunner → 创建 DB 会话 → 绑定回调
  ///
  /// 若未找到日程或动作数据, 抛出异常供 UI 层处理
  Future<void> init(int entryId) async {
    // 清理旧资源 (重新初始化时避免泄漏)
    _timer?.cancel();
    _ttsQueue?.dispose();
    state = const WorkoutSessionState();

    final repo = ref.read(sessionRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);
    _entryId = entryId;

    // 通过 entryId 查询对应日程
    final entry = await workoutRepo.getScheduleEntry(entryId);
    if (entry == null) {
      throw StateError('未找到日程');
    }

    // 加载健身计划数据 (动作列表)
    final plan = await workoutRepo.loadWorkoutPlan(entry.unitId);
    final runner = WorkoutRunner(exercises: plan.exercises);

    // 创建 DB 会话记录
    final sessionId = await repo.createSession(entryId);

    // 初始化 TTS 队列 (跨平台抽象, 自动适配 Web/Native)
    _tts = createTtsService();
    _ttsQueue = TtsQueue((text) async {
      await _tts!.speak(text);
    });

    // 绑定回调
    runner.onStateChanged = (sessionState) {
      // 持久化状态到 DB
      final stateStr = sessionState.name.toUpperCase();
      repo.updateSessionState(sessionId, stateStr);
      // 同步派生 UI 状态
      _syncDerived();
      // 终态时保存片段并上报
      if (sessionState == SessionState.completed ||
          sessionState == SessionState.partial) {
        _onTerminal(runner);
      }
    };

    runner.onSegmentChanged = (index, segment) {
      if (segment.segType == SegmentType.rest) {
        state = state.copyWith(remainingSeconds: segment.plannedSeconds);
      }
      _syncDerived();
    };

    // 健身场景使用 urgent 优先级
    runner.onTtsRequested = (message) {
      _ttsQueue?.enqueue(message, priority: TtsPriority.urgent);
      state = state.copyWith(ttsMessages: [...state.ttsMessages, message]);
    };

    // 标记初始化完成
    state = state.copyWith(
      runner: runner,
      sessionId: sessionId,
      isInitialized: true,
    );
    _syncDerived();
  }

  /// 记录一组训练数据 → 推进到休息段 → 启动休息 Timer
  void completeSet(int reps, double weight, double rpe) {
    final runner = state.runner;
    if (runner == null) return;

    runner.recordSet(reps: reps, weight: weight, rpe: rpe);

    // 更新 state 中的 rpe
    state = state.copyWith(rpe: rpe);

    // 推进到休息段
    runner.advanceToNextSegment();

    if (runner.state == SessionState.running) {
      _startRestTimer();
    }
    _syncDerived();
  }

  /// 确认进入下一动作 (半自动推进)
  void confirmNextExercise() {
    final runner = state.runner;
    if (runner == null) return;
    runner.confirmNextExercise();
    _syncDerived();
  }

  /// 跳过休息
  void skipRest() {
    _timer?.cancel();
    final runner = state.runner;
    if (runner == null) return;
    state = state.copyWith(remainingSeconds: 0);
    runner.advanceToNextSegment();
    _syncDerived();
  }

  /// 放弃会话
  void abandon() {
    _timer?.cancel();
    final runner = state.runner;
    if (runner == null) return;
    runner.abandon();
    _ttsQueue?.clear();
    _syncDerived();
  }

  /// 更新 RPE 滑块值
  void updateRpe(double value) {
    state = state.copyWith(rpe: value);
  }

  /// 清理资源 (供 UI 在离开时调用, 仅停止 Timer 不改变会话状态)
  void cleanup() {
    _timer?.cancel();
  }

  /// 内部: 启动休息倒计时 Timer
  /// 最后 3 秒触发 TTS 倒数, 到 0 时推进片段
  void _startRestTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds > 0) {
        final newRemaining = state.remainingSeconds - 1;
        state = state.copyWith(remainingSeconds: newRemaining);

        // 最后 3 秒 TTS 倒数
        if (newRemaining <= 3 && newRemaining > 0) {
          final countdown = WorkoutTtsBuilder.restCountdown(newRemaining);
          if (countdown.isNotEmpty) {
            _ttsQueue?.enqueue(countdown, priority: TtsPriority.high);
          }
        }
      } else {
        // 休息结束 → 推进到下一片段
        _timer?.cancel();
        state.runner?.advanceToNextSegment();
        _syncDerived();
      }
    });
  }

  /// 终态处理: 保存训练片段到 DB + 上报 (含降级策略, 由 Repository 统一处理)
  Future<void> _onTerminal(WorkoutRunner runner) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final repo = ref.read(sessionRepositoryProvider);

    // 保存训练片段到 DB
    final segments = runner.segments
        .map((seg) => SessionSegmentsCompanion.insert(
              sessionId: sessionId,
              segType: seg.segTypeString,
              plannedSeconds: seg.plannedSeconds,
              actualSeconds: Value(seg.actualSeconds),
              repsDone: seg.repsDone != null
                  ? Value(seg.repsDone!)
                  : const Value.absent(),
              weightKgDone: seg.weightKgDone != null
                  ? Value(seg.weightKgDone!)
                  : const Value.absent(),
            ))
        .toList();
    await repo.saveSegments(sessionId, segments);
    await repo.updateSessionState(
      sessionId,
      runner.state.name.toUpperCase(),
      completionRatio: runner.completionRatio,
      endedAt: DateTime.now().toIso8601String(),
    );

    // 上报到 Node-RED (含降级策略, 由 Repository 统一处理)
    final reportSegments = runner.segments
        .where((s) => s.segType == SegmentType.workoutSet)
        .map((s) => <String, dynamic>{
              'seg_type': s.segTypeString,
              'reps_done': s.repsDone ?? 0,
              'weight_kg_done': s.weightKgDone ?? 0,
              'rpe': s.rpe ?? 0,
            })
        .toList();
    await repo.reportSessionComplete(
      sessionId: sessionId,
      entryId: _entryId,
      completionRatio: runner.completionRatio,
      segments: reportSegments,
      currentWeight: runner.currentExercise?.plannedWeight ?? 0,
    );
  }

  /// 同步派生 UI 状态 (isResting / isWaitingConfirm / isDone / isRunning)
  void _syncDerived() {
    final runner = state.runner;
    if (runner == null) return;

    // 防止 currentSegmentIndex 越界
    final segIndex = runner.currentSegmentIndex;
    final isResting = segIndex < runner.segments.length &&
        runner.segments[segIndex].segType == SegmentType.rest;

    state = state.copyWith(
      isResting: isResting,
      isWaitingConfirm: runner.waitingForConfirm,
      isDone: runner.isTerminal,
    );
  }
}

/// 健身会话 NotifierProvider
final workoutSessionNotifierProvider =
    NotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
        WorkoutSessionNotifier.new);
