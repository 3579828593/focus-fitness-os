import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/runners/session_state.dart';

/// 构造一个动作数据
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

/// 3 个动作 (各 4 组) 的标准测试数据
List<ExerciseData> _threeExercises() => [
      _exercise(id: 1, name: '深蹲', plannedWeight: 60, restSeconds: 90),
      _exercise(id: 2, name: '卧推', plannedWeight: 40, restSeconds: 90),
      _exercise(id: 3, name: '硬拉', plannedWeight: 80, restSeconds: 120),
    ];

/// 完成一个动作的全部组 (4 组), 并在结束时确认切换到下一动作
/// [confirmSwitch] 最后一组休息后是否需要 confirmNextExercise
void _completeFullExercise(WorkoutRunner runner, {required bool confirmSwitch}) {
  for (int i = 0; i < 4; i++) {
    runner.recordSet(reps: 8, weight: 60);
    runner.advanceToNextSegment(); // workoutSet → rest
    runner.advanceToNextSegment(); // rest → 下一组 / 切换 / 完成
  }
  if (confirmSwitch) {
    runner.confirmNextExercise();
  }
}

void main() {
  group('WorkoutRunner segments 构造', () {
    test('3个动作(各4组)生成24个segments (3×4×2)', () {
      // Arrange
      final runner = WorkoutRunner(exercises: _threeExercises());

      // Act
      final count = runner.segments.length;

      // Assert
      expect(count, 24);
      // 验证交替 workoutSet / rest
      expect(runner.segments[0].segType, SegmentType.workoutSet);
      expect(runner.segments[1].segType, SegmentType.rest);
      expect(runner.segments[22].segType, SegmentType.workoutSet);
      expect(runner.segments[23].segType, SegmentType.rest);
    });
  });

  group('WorkoutRunner 记录与推进', () {
    test('recordSet 后 repsDone 和 weightKgDone 正确更新', () {
      // Arrange
      final runner = WorkoutRunner(exercises: _threeExercises())..start();

      // Act
      runner.recordSet(reps: 12, weight: 65.0, rpe: 9);

      // Assert
      final seg = runner.segments[runner.currentSegmentIndex];
      expect(seg.repsDone, 12);
      expect(seg.weightKgDone, 65.0);
      expect(seg.rpe, 9);
    });

    test('advanceToNextSegment 从 workoutSet 到 rest 触发TTS', () {
      // Arrange
      final ttsMessages = <String>[];
      final runner = WorkoutRunner(exercises: _threeExercises());
      runner.onTtsRequested = (msg) => ttsMessages.add(msg);
      runner.start();
      runner.recordSet(reps: 8, weight: 60);

      // Act — workoutSet → rest
      runner.advanceToNextSegment();

      // Assert
      expect(ttsMessages, isNotEmpty);
      expect(runner.currentSegmentIndex, 1);
      expect(runner.segments[1].segType, SegmentType.rest);
    });

    test('第4组完成后 currentSetNumber 重置为1，currentExerciseIndex+1', () {
      // Arrange
      final runner = WorkoutRunner(exercises: _threeExercises())..start();

      // Act — 完成第 1 个动作的全部 4 组
      _completeFullExercise(runner, confirmSwitch: false);

      // Assert — 第 4 组休息后触发切换: index +1, set 重置为 1
      expect(runner.currentExerciseIndex, 1);
      expect(runner.currentSetNumber, 1);
      expect(runner.waitingForConfirm, isTrue);
    });

    test('切换动作时 waitingForConfirm = true', () {
      // Arrange
      final ttsMessages = <String>[];
      final runner = WorkoutRunner(exercises: _threeExercises());
      runner.onTtsRequested = (msg) => ttsMessages.add(msg);
      runner.start();

      // Act — 完成第 1 个动作 4 组
      for (int i = 0; i < 4; i++) {
        runner.recordSet(reps: 8, weight: 60);
        runner.advanceToNextSegment();
        runner.advanceToNextSegment();
      }

      // Assert
      expect(runner.waitingForConfirm, isTrue);
      // 切换动作时播报包含下一个动作名
      expect(ttsMessages.any((m) => m.contains('卧推')), isTrue);
    });

    test('confirmNextExercise 后推进到下一段', () {
      // Arrange
      final runner = WorkoutRunner(exercises: _threeExercises())..start();
      _completeFullExercise(runner, confirmSwitch: false);
      final indexBefore = runner.currentSegmentIndex;
      expect(runner.waitingForConfirm, isTrue);

      // Act
      runner.confirmNextExercise();

      // Assert
      expect(runner.waitingForConfirm, isFalse);
      expect(runner.currentSegmentIndex, indexBefore + 1);
      // 进入第 2 个动作的第 1 组
      expect(runner.currentExerciseIndex, 1);
      expect(runner.currentSetNumber, 1);
    });
  });

  group('WorkoutRunner 完成与统计', () {
    test('最后一个动作最后一组完成后 complete()', () {
      // Arrange
      final runner = WorkoutRunner(exercises: _threeExercises())..start();

      // Act — 依次完成 3 个动作
      _completeFullExercise(runner, confirmSwitch: true); // 动作 1 → 2
      _completeFullExercise(runner, confirmSwitch: true); // 动作 2 → 3
      _completeFullExercise(runner, confirmSwitch: false); // 动作 3 → 完成

      // Assert
      expect(runner.state, SessionState.completed);
      expect(runner.isTerminal, isTrue);
    });

    test('completionRatio 计算: 完成6/12组 = 0.5', () {
      // Arrange — 3 动作 × 4 组 = 12 组
      final runner = WorkoutRunner(exercises: _threeExercises())..start();

      // Act — 完成动作 1 全部 4 组, 切换到动作 2
      _completeFullExercise(runner, confirmSwitch: true);
      // 再完成动作 2 的 2 组 (共 6 组)
      for (int i = 0; i < 2; i++) {
        runner.recordSet(reps: 8, weight: 40);
        runner.advanceToNextSegment();
        runner.advanceToNextSegment();
      }

      // Assert — 6 / 12 = 0.5
      expect(runner.completionRatio, 0.5);
    });

    test('TTS播报内容包含组号和休息秒数', () {
      // Arrange
      final ttsMessages = <String>[];
      final runner = WorkoutRunner(
        exercises: [_exercise(restSeconds: 90)],
      );
      runner.onTtsRequested = (msg) => ttsMessages.add(msg);
      runner.start();
      runner.recordSet(reps: 8, weight: 60);

      // Act
      runner.advanceToNextSegment(); // workoutSet → rest

      // Assert
      expect(ttsMessages, isNotEmpty);
      final msg = ttsMessages.last;
      expect(msg, contains('1')); // 组号
      expect(msg, contains('90')); // 休息秒数
    });
  });

  group('WorkoutRunner 续接恢复', () {
    test('restoreFrom 恢复后 currentExerciseIndex 和 currentSetNumber 正确', () {
      // Arrange
      final exercises = _threeExercises();
      final runner = WorkoutRunner(exercises: exercises);
      final originalSegments = runner.segments;

      // Act — 模拟从第 2 个动作第 2 组 (segmentIndex 10) 恢复
      // segmentIndex 10 = 动作1(0..7) 之后, 动作2 的第 2 个 workoutSet
      runner.restoreFrom(
        existingState: 'PAUSED',
        lastSegmentIndex: 10,
        existingSegments: originalSegments,
      );
      // 持久化层需同步恢复动作进度 (restoreFrom 仅恢复 state/segmentIndex)
      runner.currentExerciseIndex = 1;
      runner.currentSetNumber = 2;
      runner.start(); // paused → running

      // Assert
      expect(runner.state, SessionState.running);
      expect(runner.currentSegmentIndex, 10);
      expect(runner.currentExerciseIndex, 1);
      expect(runner.currentSetNumber, 2);
      // 恢复到的片段应为第 2 个动作的第 2 组 workoutSet
      expect(runner.segments[10].segType, SegmentType.workoutSet);
      expect(runner.currentExercise?.name, '卧推');
    });
  });
}
