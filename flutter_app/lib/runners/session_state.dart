/// ============================================================
/// 会话状态机 + 双执行器
/// FocusRunner(专注计时, 全自动推进) + WorkoutRunner(健身计数, 半自动+TTS)
/// 共享 SessionStateMachine 通用状态流转
/// ============================================================

/// 会话级状态枚举
enum SessionState {
  created,
  running,
  paused,
  completed,
  partial,
  abandoned,
}

/// 片段类型枚举
enum SegmentType {
  focusBlock,
  break_,
  workoutSet,
  rest,
}

/// 片段数据
class SegmentData {
  final int? segmentId;
  final SegmentType segType;
  final int plannedSeconds;
  int actualSeconds;
  int? repsDone;
  double? weightKgDone;
  double? rpe;

  SegmentData({
    this.segmentId,
    required this.segType,
    required this.plannedSeconds,
    this.actualSeconds = 0,
    this.repsDone,
    this.weightKgDone,
    this.rpe,
  });

  String get segTypeString {
    switch (segType) {
      case SegmentType.focusBlock:
        return 'FOCUS_BLOCK';
      case SegmentType.break_:
        return 'BREAK';
      case SegmentType.workoutSet:
        return 'WORKOUT_SET';
      case SegmentType.rest:
        return 'REST';
    }
  }

  static SegmentType fromString(String s) {
    switch (s) {
      case 'FOCUS_BLOCK':
        return SegmentType.focusBlock;
      case 'BREAK':
        return SegmentType.break_;
      case 'WORKOUT_SET':
        return SegmentType.workoutSet;
      case 'REST':
        return SegmentType.rest;
      default:
        throw ArgumentError('Unknown segment type: $s');
    }
  }
}

/// 动作数据 (健身用)
class ExerciseData {
  final int exerciseId;
  final String name;
  final int plannedSets;
  final int plannedReps;
  final double plannedWeight;
  final int restSeconds;

  ExerciseData({
    required this.exerciseId,
    required this.name,
    required this.plannedSets,
    required this.plannedReps,
    required this.plannedWeight,
    required this.restSeconds,
  });
}

/// ============================================================
/// 共享会话状态机
/// CREATED → RUNNING → (PAUSED) → COMPLETED / PARTIAL / ABANDONED
/// ============================================================

abstract class SessionRunner {
  SessionState state = SessionState.created;
  List<SegmentData> segments = [];
  int currentSegmentIndex = 0;

  /// 回调接口
  void Function(SessionState newState)? onStateChanged;
  void Function(int segmentIndex, SegmentData segment)? onSegmentChanged;
  void Function(String message)? onTtsRequested;
  void Function(int remainingSeconds)? onTick;

  /// 启动会话
  void start() {
    if (state != SessionState.created && state != SessionState.paused) {
      throw StateError('Cannot start from state: $state');
    }
    state = SessionState.running;
    onStateChanged?.call(state);
    if (segments.isNotEmpty) {
      onSegmentChanged?.call(currentSegmentIndex, segments[currentSegmentIndex]);
    }
  }

  /// 暂停
  void pause() {
    if (state != SessionState.running) {
      throw StateError('Cannot pause from state: $state');
    }
    state = SessionState.paused;
    onStateChanged?.call(state);
  }

  /// 恢复
  void resume() {
    if (state != SessionState.paused) {
      throw StateError('Cannot resume from state: $state');
    }
    state = SessionState.running;
    onStateChanged?.call(state);
  }

  /// 完成 (全部完成)
  void complete() {
    if (state != SessionState.running) {
      throw StateError('Cannot complete from state: $state');
    }
    state = SessionState.completed;
    onStateChanged?.call(state);
  }

  /// 部分完成
  void partial() {
    if (state != SessionState.running && state != SessionState.paused) {
      throw StateError('Cannot partial from state: $state');
    }
    state = SessionState.partial;
    onStateChanged?.call(state);
  }

  /// 放弃
  void abandon() {
    state = SessionState.abandoned;
    onStateChanged?.call(state);
  }

  /// 是否处于终态
  bool get isTerminal =>
      state == SessionState.completed ||
      state == SessionState.partial ||
      state == SessionState.abandoned;

  /// 是否可以续接
  bool get canRestore =>
      state == SessionState.paused || state == SessionState.running;

  /// 从已有会话续接
  void restoreFrom({
    required String existingState,
    required int lastSegmentIndex,
    required List<SegmentData> existingSegments,
  }) {
    segments = existingSegments;
    currentSegmentIndex = lastSegmentIndex;

    switch (existingState) {
      case 'CREATED':
        state = SessionState.created;
        break;
      case 'RUNNING':
        state = SessionState.running;
        break;
      case 'PAUSED':
        state = SessionState.paused;
        break;
      default:
        throw StateError('Cannot restore from terminal state: $existingState');
    }
    onStateChanged?.call(state);
    if (segments.isNotEmpty && currentSegmentIndex < segments.length) {
      onSegmentChanged?.call(currentSegmentIndex, segments[currentSegmentIndex]);
    }
  }

  /// 子类实现: 片段推进策略
  void advanceToNextSegment();

  /// 检查是否还有下一段
  bool get hasNextSegment => currentSegmentIndex < segments.length - 1;

  /// 推进到指定片段
  void _goToSegment(int index) {
    if (index < 0 || index >= segments.length) {
      complete();
      return;
    }
    currentSegmentIndex = index;
    onSegmentChanged?.call(currentSegmentIndex, segments[currentSegmentIndex]);
  }
}

/// ============================================================
/// FocusRunner: 专注计时执行器 (全自动推进)
/// 番茄块线性: FOCUS_BLOCK → BREAK → FOCUS_BLOCK → BREAK → ...
/// ============================================================

class FocusRunner extends SessionRunner {
  final int focusMinutes;
  final int breakMinutes;
  final int totalRounds;

  FocusRunner({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.totalRounds = 4,
  }) {
    _buildSegments();
  }

  void _buildSegments() {
    segments.clear();
    for (int i = 0; i < totalRounds; i++) {
      segments.add(SegmentData(
        segType: SegmentType.focusBlock,
        plannedSeconds: focusMinutes * 60,
      ));
      segments.add(SegmentData(
        segType: SegmentType.break_,
        plannedSeconds: breakMinutes * 60,
      ));
    }
  }

  @override
  void advanceToNextSegment() {
    if (state != SessionState.running) return;

    final current = segments[currentSegmentIndex];

    if (current.segType == SegmentType.focusBlock) {
      // 专注块结束 → 自动进入休息
      onTtsRequested?.call('休息时间');

      if (hasNextSegment) {
        _goToSegment(currentSegmentIndex + 1);
      } else {
        complete();
      }
    } else {
      // 休息结束 → 自动进入下一专注块 (无TTS, 避免干扰)
      if (hasNextSegment) {
        _goToSegment(currentSegmentIndex + 1);
      } else {
        complete();
      }
    }
  }
}

/// ============================================================
/// WorkoutRunner: 健身计数执行器 (半自动 + TTS强播报)
/// 双层嵌套: 动作 × 组 → WORKOUT_SET → REST → 下一组/下一动作
/// ============================================================

class WorkoutRunner extends SessionRunner {
  final List<ExerciseData> exercises;
  int currentExerciseIndex = 0;
  int currentSetNumber = 1;

  /// 是否需要用户确认才进入下一动作
  bool waitingForConfirm = false;

  WorkoutRunner({required this.exercises}) {
    assert(exercises.isNotEmpty, '至少需要一个动作');
    _buildSegments();
  }

  void _buildSegments() {
    segments.clear();
    for (final exercise in exercises) {
      for (int set = 0; set < exercise.plannedSets; set++) {
        segments.add(SegmentData(
          segType: SegmentType.workoutSet,
          plannedSeconds: 0, // 健身组时间不固定, 由用户控制
          repsDone: 0,
          weightKgDone: exercise.plannedWeight,
        ));
        segments.add(SegmentData(
          segType: SegmentType.rest,
          plannedSeconds: exercise.restSeconds,
        ));
      }
    }
  }

  /// 获取当前动作
  ExerciseData? get currentExercise {
    if (currentExerciseIndex < exercises.length) {
      return exercises[currentExerciseIndex];
    }
    return null;
  }

  /// 获取当前是第几组
  int get currentSetInExercise => currentSetNumber;

  /// 记录一组训练数据
  void recordSet({required int reps, required double weight, double? rpe}) {
    if (currentSegmentIndex >= segments.length) return;

    final seg = segments[currentSegmentIndex];
    seg.repsDone = reps;
    seg.weightKgDone = weight;
    seg.rpe = rpe;
  }

  @override
  void advanceToNextSegment() {
    if (state != SessionState.running) return;

    final current = segments[currentSegmentIndex];

    if (current.segType == SegmentType.workoutSet) {
      // 一组完成 → TTS播报 → 进入休息
      final exercise = currentExercise;
      if (exercise != null) {
        onTtsRequested?.call(
            '第$currentSetNumber组完成，休息${exercise.restSeconds}秒');
      }

      if (hasNextSegment) {
        _goToSegment(currentSegmentIndex + 1);
      } else {
        complete();
      }
    } else if (current.segType == SegmentType.rest) {
      // 休息结束 → 检查是否换动作
      final exercise = currentExercise;
      if (exercise == null) {
        complete();
        return;
      }

      currentSetNumber++;

      if (currentSetNumber > exercise.plannedSets) {
        // 当前动作全部完成 → 切换下一动作
        currentExerciseIndex++;
        currentSetNumber = 1;

        if (currentExerciseIndex < exercises.length) {
          // 有下一个动作 → TTS播报 + 等待确认 (半自动)
          final next = exercises[currentExerciseIndex];
          onTtsRequested?.call(
              '下一个动作：${next.name}，${next.plannedSets}组×${next.plannedReps}次');
          waitingForConfirm = true;
          // 不自动推进, 等待 confirmNextExercise()
        } else {
          // 全部动作完成
          complete();
        }
      } else {
        // 同一动作下一组 → TTS提示
        onTtsRequested?.call('第$currentSetNumber组，开始');
        if (hasNextSegment) {
          _goToSegment(currentSegmentIndex + 1);
        }
      }
    }
  }

  /// 用户确认进入下一动作 (半自动)
  void confirmNextExercise() {
    if (!waitingForConfirm) return;
    waitingForConfirm = false;

    if (hasNextSegment) {
      _goToSegment(currentSegmentIndex + 1);
    }
  }

  /// 计算完成率
  double get completionRatio {
    if (segments.isEmpty) return 0.0;
    final totalSets = exercises.fold<int>(0, (sum, e) => sum + e.plannedSets);
    if (totalSets == 0) return 0.0;
    final completedSets = segments
        .where((s) => s.segType == SegmentType.workoutSet && s.repsDone! > 0)
        .length;
    return completedSets / totalSets;
  }
}
