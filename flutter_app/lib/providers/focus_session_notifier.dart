import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod/riverpod.dart';

import '../repositories/providers.dart';
import '../repositories/session_repository.dart';
import '../repositories/workout_repository.dart';
import '../runners/session_state.dart';
import '../services/tts_service.dart';

/// ============================================================
/// 专注会话不可变状态
/// 持有 FocusRunner 引用 + 派生 UI 字段
/// ============================================================
class FocusSessionState {
  final FocusRunner? runner;
  final int remainingSeconds;
  final List<String> ttsMessages;
  final int? sessionId;
  final bool isInitialized;
  final bool isRunning;

  const FocusSessionState({
    this.runner,
    this.remainingSeconds = 0,
    this.ttsMessages = const [],
    this.sessionId,
    this.isInitialized = false,
    this.isRunning = false,
  });

  FocusSessionState copyWith({
    FocusRunner? runner,
    int? remainingSeconds,
    List<String>? ttsMessages,
    int? sessionId,
    bool? isInitialized,
    bool? isRunning,
  }) {
    return FocusSessionState(
      runner: runner ?? this.runner,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      ttsMessages: ttsMessages ?? this.ttsMessages,
      sessionId: sessionId ?? this.sessionId,
      isInitialized: isInitialized ?? this.isInitialized,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// ============================================================
/// FocusSessionNotifier: 专注计时会话状态管理
///
/// 职责:
/// - 读取 DB 获取专注参数, 创建 FocusRunner
/// - 创建/更新 DB 会话记录
/// - 管理 Timer.periodic 倒计时
/// - 内部管理 TtsQueue + FlutterTts
/// ============================================================
class FocusSessionNotifier extends Notifier<FocusSessionState> {
  Timer? _timer;
  TtsQueue? _ttsQueue;
  FlutterTts? _flutterTts;

  @override
  FocusSessionState build() {
    // 注册资源释放 (provider 被 dispose 时触发)
    ref.onDispose(() {
      _timer?.cancel();
      _ttsQueue?.dispose();
    });
    return const FocusSessionState();
  }

  /// 初始化: 读取 DB 专注参数 → 创建 FocusRunner → 创建 DB 会话 → 绑定回调
  Future<void> init(int entryId) async {
    // 清理旧资源 (重新初始化时避免泄漏)
    _timer?.cancel();
    _ttsQueue?.dispose();
    state = const FocusSessionState();

    final repo = ref.read(sessionRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);

    // 查找是否有可续接的会话 (用于后续扩展, 当前仅查询)
    await repo.getActiveSession(entryId);

    // 从数据库读取专注参数 (focusMinutes / breakMinutes)
    int focusMinutes = 25;
    int breakMinutes = 5;
    final entry = await workoutRepo.getScheduleEntry(entryId);
    if (entry != null) {
      final config = await workoutRepo.loadFocusConfig(entry.unitId);
      focusMinutes = config.focusMinutes;
      breakMinutes = config.breakMinutes;
    }

    final runner = FocusRunner(
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      totalRounds: 4,
    );

    // 创建 DB 会话记录
    final sessionId = await repo.createSession(entryId);

    // 初始化 TTS 队列 (内部创建, 不通过构造函数注入)
    _flutterTts = FlutterTts();
    _ttsQueue = TtsQueue((text) async {
      await _flutterTts!.speak(text);
    });

    // 绑定回调
    runner.onStateChanged = (sessionState) {
      // 持久化状态到 DB
      final stateStr = sessionState.name.toUpperCase();
      repo.updateSessionState(sessionId, stateStr);
      // 更新派生 UI 状态
      state = state.copyWith(
        isRunning: sessionState == SessionState.running,
      );
    };

    runner.onSegmentChanged = (index, segment) {
      state = state.copyWith(remainingSeconds: segment.plannedSeconds);
    };

    runner.onTtsRequested = (message) {
      _ttsQueue?.enqueue(message, priority: TtsPriority.medium);
      state = state.copyWith(ttsMessages: [...state.ttsMessages, message]);
    };

    runner.onTick = (remaining) {
      state = state.copyWith(remainingSeconds: remaining);
    };

    // 标记初始化完成
    state = state.copyWith(
      runner: runner,
      sessionId: sessionId,
      isInitialized: true,
    );
  }

  /// 切换计时器 (开始 / 暂停)
  void toggleTimer() {
    final runner = state.runner;
    if (runner == null) return;

    if (runner.state == SessionState.created ||
        runner.state == SessionState.paused) {
      runner.start();
      _startTimer();
    } else if (runner.state == SessionState.running) {
      runner.pause();
      _timer?.cancel();
    }
  }

  /// 完成会话: 保存最终状态到 DB
  void complete() {
    _timer?.cancel();
    final runner = state.runner;
    if (runner == null) return;
    runner.complete();

    final sessionId = state.sessionId;
    if (sessionId != null) {
      final repo = ref.read(sessionRepositoryProvider);
      repo.updateSessionState(
        sessionId,
        'COMPLETED',
        completionRatio: 1.0,
        endedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  /// 放弃会话
  void abandon() {
    _timer?.cancel();
    final runner = state.runner;
    if (runner == null) return;
    runner.abandon();
    _ttsQueue?.clear();
  }

  /// 清理资源 (供 UI 在离开时调用, 仅停止 Timer 不改变会话状态)
  void cleanup() {
    _timer?.cancel();
  }

  /// 内部: 启动 Timer, 每秒递减 remainingSeconds
  /// 到 0 时调用 runner.advanceToNextSegment 推进片段
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds > 0) {
        final newRemaining = state.remainingSeconds - 1;
        // 通过 onTick 回调更新 state (保持与 runner 回调链一致)
        state.runner?.onTick?.call(newRemaining);
      } else {
        // 当前片段计时结束 → 推进到下一片段
        _timer?.cancel();
        state.runner?.advanceToNextSegment();
        // 若仍在运行状态, 重新启动计时器
        if (state.runner?.state == SessionState.running) {
          _startTimer();
        }
      }
    });
  }
}

/// 专注会话 NotifierProvider
final focusSessionNotifierProvider =
    NotifierProvider<FocusSessionNotifier, FocusSessionState>(
        FocusSessionNotifier.new);
