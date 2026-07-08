import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/runners/session_state.dart';

/// 测试辅助: 构造一个动作数据
ExerciseData _exercise({
  int id = 1,
  String name = '深蹲',
  int plannedSets = 4,
  int plannedReps = 8,
  double plannedWeight = 60,
  int restSeconds = 90,
}) {
  return ExerciseData(
    exerciseId: id,
    name: name,
    plannedSets: plannedSets,
    plannedReps: plannedReps,
    plannedWeight: plannedWeight,
    restSeconds: restSeconds,
  );
}

void main() {
  // ============================================================
  // 基础状态流转
  // ============================================================
  group('SessionStateMachine 基础状态流转', () {
    test('FocusRunner 初始状态为 created', () {
      // Arrange
      final runner = FocusRunner();

      // Act & Assert
      expect(runner.state, SessionState.created);
    });

    test('start() 后状态变为 running', () {
      // Arrange
      final runner = FocusRunner();

      // Act
      runner.start();

      // Assert
      expect(runner.state, SessionState.running);
    });

    test('pause() 后状态变为 paused', () {
      // Arrange
      final runner = FocusRunner()..start();

      // Act
      runner.pause();

      // Assert
      expect(runner.state, SessionState.paused);
    });

    test('resume() 后状态变回 running', () {
      // Arrange
      final runner = FocusRunner()..start()..pause();

      // Act
      runner.resume();

      // Assert
      expect(runner.state, SessionState.running);
    });

    test('complete() 后状态变为 completed', () {
      // Arrange
      final runner = FocusRunner()..start();

      // Act
      runner.complete();

      // Assert
      expect(runner.state, SessionState.completed);
    });

    test('abandon() 后状态变为 abandoned', () {
      // Arrange
      final runner = FocusRunner()..start();

      // Act
      runner.abandon();

      // Assert
      expect(runner.state, SessionState.abandoned);
    });
  });

  // ============================================================
  // 终态与可恢复判断
  // ============================================================
  group('终态与可恢复判断', () {
    test('isTerminal 在 completed/partial/abandoned 时为 true', () {
      // Arrange
      final completed = FocusRunner()..start()..complete();
      final partial = FocusRunner()..start()..partial();
      final abandoned = FocusRunner()..start()..abandon();
      final created = FocusRunner();
      final running = FocusRunner()..start();
      final paused = FocusRunner()..start()..pause();

      // Act & Assert
      expect(completed.isTerminal, isTrue);
      expect(partial.isTerminal, isTrue);
      expect(abandoned.isTerminal, isTrue);
      expect(created.isTerminal, isFalse);
      expect(running.isTerminal, isFalse);
      expect(paused.isTerminal, isFalse);
    });

    test('canRestore 在 paused/running 时为 true', () {
      // Arrange
      final running = FocusRunner()..start();
      final paused = FocusRunner()..start()..pause();
      final completed = FocusRunner()..start()..complete();
      final created = FocusRunner();

      // Act & Assert
      expect(running.canRestore, isTrue);
      expect(paused.canRestore, isTrue);
      expect(completed.canRestore, isFalse);
      expect(created.canRestore, isFalse);
    });
  });

  // ============================================================
  // 非法状态转换
  // ============================================================
  group('非法状态转换', () {
    test('不能从 completed 状态 start()', () {
      // Arrange
      final runner = FocusRunner()..start()..complete();

      // Act & Assert
      expect(() => runner.start(), throwsStateError);
    });

    test('不能从 created 状态 pause()', () {
      // Arrange
      final runner = FocusRunner();

      // Act & Assert
      expect(() => runner.pause(), throwsStateError);
    });

    test('不能从 paused 状态 complete()', () {
      // Arrange
      final runner = FocusRunner()..start()..pause();

      // Act & Assert
      expect(() => runner.complete(), throwsStateError);
    });
  });

  // ============================================================
  // FocusRunner segments
  // ============================================================
  group('FocusRunner segments', () {
    test('FocusRunner 默认生成 8 个 segments (4轮×2段)', () {
      // Arrange
      final runner = FocusRunner();

      // Act
      final count = runner.segments.length;

      // Assert
      expect(count, 8);
      // 交替 focusBlock / break_
      expect(runner.segments[0].segType, SegmentType.focusBlock);
      expect(runner.segments[1].segType, SegmentType.break_);
      expect(runner.segments[6].segType, SegmentType.focusBlock);
      expect(runner.segments[7].segType, SegmentType.break_);
    });

    test('FocusRunner.advanceToNextSegment() 从 focusBlock 推进到 break', () {
      // Arrange
      final runner = FocusRunner()..start();
      expect(
        runner.segments[runner.currentSegmentIndex].segType,
        SegmentType.focusBlock,
      );

      // Act
      runner.advanceToNextSegment();

      // Assert
      expect(runner.currentSegmentIndex, 1);
      expect(
        runner.segments[runner.currentSegmentIndex].segType,
        SegmentType.break_,
      );
    });

    test('FocusRunner 全部推进后状态为 completed', () {
      // Arrange
      final runner = FocusRunner()..start(); // 8 segments (index 0..7)

      // Act
      for (int i = 0; i < 8; i++) {
        runner.advanceToNextSegment();
      }

      // Assert
      expect(runner.state, SessionState.completed);
      expect(runner.isTerminal, isTrue);
    });
  });

  // ============================================================
  // WorkoutRunner
  // ============================================================
  group('WorkoutRunner', () {
    test('WorkoutRunner 初始 currentSetNumber 为 1', () {
      // Arrange
      final runner = WorkoutRunner(exercises: [_exercise()]);

      // Act & Assert
      expect(runner.currentSetNumber, 1);
      expect(runner.currentExerciseIndex, 0);
      expect(runner.waitingForConfirm, isFalse);
    });

    test('WorkoutRunner.recordSet() 正确记录 reps 和 weight', () {
      // Arrange
      final runner = WorkoutRunner(exercises: [_exercise()])..start();

      // Act
      runner.recordSet(reps: 10, weight: 55.5, rpe: 8);

      // Assert
      final seg = runner.segments[0];
      expect(seg.repsDone, 10);
      expect(seg.weightKgDone, 55.5);
      expect(seg.rpe, 8);
    });

    test('WorkoutRunner.advanceToNextSegment() 从 workoutSet 推进到 rest', () {
      // Arrange
      final runner = WorkoutRunner(exercises: [_exercise()])..start();
      expect(
        runner.segments[runner.currentSegmentIndex].segType,
        SegmentType.workoutSet,
      );

      // Act
      runner.advanceToNextSegment();

      // Assert
      expect(runner.currentSegmentIndex, 1);
      expect(runner.segments[1].segType, SegmentType.rest);
    });

    test('WorkoutRunner 完成所有组后切换动作 (waitingForConfirm = true)', () {
      // Arrange
      final runner = WorkoutRunner(
        exercises: [_exercise(), _exercise(id: 2, name: '卧推')],
      )..start();

      // Act — 完成 4 组 (每组的 workoutSet + rest 各推进一次)
      for (int i = 0; i < 4; i++) {
        runner.recordSet(reps: 8, weight: 60);
        runner.advanceToNextSegment(); // workoutSet → rest
        runner.advanceToNextSegment(); // rest → 下一组 / 切换动作
      }

      // Assert
      expect(runner.waitingForConfirm, isTrue);
      expect(runner.currentExerciseIndex, 1);
      expect(runner.currentSetNumber, 1);
    });

    test('WorkoutRunner.confirmNextExercise() 推进到下一段', () {
      // Arrange
      final runner = WorkoutRunner(
        exercises: [_exercise(), _exercise(id: 2, name: '卧推')],
      )..start();
      for (int i = 0; i < 4; i++) {
        runner.recordSet(reps: 8, weight: 60);
        runner.advanceToNextSegment();
        runner.advanceToNextSegment();
      }
      final indexBefore = runner.currentSegmentIndex;
      expect(runner.waitingForConfirm, isTrue);

      // Act
      runner.confirmNextExercise();

      // Assert
      expect(runner.waitingForConfirm, isFalse);
      expect(runner.currentSegmentIndex, indexBefore + 1);
    });

    test('WorkoutRunner.completionRatio 正确计算完成率', () {
      // Arrange — 单动作 4 组
      final runner = WorkoutRunner(exercises: [_exercise()])..start();

      // Act — 完成 2 组
      runner.recordSet(reps: 8, weight: 60);
      runner.advanceToNextSegment(); // → rest
      runner.advanceToNextSegment(); // → 第2组
      runner.recordSet(reps: 8, weight: 60);

      // Assert — 2 / 4 = 0.5
      expect(runner.completionRatio, 0.5);
    });
  });

  // ============================================================
  // restoreFrom
  // ============================================================
  group('restoreFrom 续接', () {
    test('restoreFrom() 正确恢复 paused 状态和 segmentIndex', () {
      // Arrange
      final runner = FocusRunner();
      final segs = runner.segments;

      // Act
      runner.restoreFrom(
        existingState: 'PAUSED',
        lastSegmentIndex: 5,
        existingSegments: segs,
      );

      // Assert
      expect(runner.state, SessionState.paused);
      expect(runner.currentSegmentIndex, 5);
      expect(runner.canRestore, isTrue);
    });
  });
}
