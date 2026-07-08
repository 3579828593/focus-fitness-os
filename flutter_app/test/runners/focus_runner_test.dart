import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/runners/session_state.dart';

void main() {
  group('FocusRunner 配置与 segments', () {
    test('25分钟专注 + 5分钟休息的默认配置', () {
      // Arrange
      final runner = FocusRunner();

      // Act & Assert
      expect(runner.focusMinutes, 25);
      expect(runner.breakMinutes, 5);
      expect(runner.totalRounds, 4);
      expect(runner.segments.length, 8);
      // 专注段 = 25 * 60 = 1500 秒
      expect(runner.segments[0].segType, SegmentType.focusBlock);
      expect(runner.segments[0].plannedSeconds, 1500);
      // 休息段 = 5 * 60 = 300 秒
      expect(runner.segments[1].segType, SegmentType.break_);
      expect(runner.segments[1].plannedSeconds, 300);
    });

    test('自定义轮数(如2轮)生成4个segments', () {
      // Arrange
      final runner = FocusRunner(totalRounds: 2);

      // Act
      final segs = runner.segments;

      // Assert
      expect(segs.length, 4);
      expect(segs[0].segType, SegmentType.focusBlock);
      expect(segs[1].segType, SegmentType.break_);
      expect(segs[2].segType, SegmentType.focusBlock);
      expect(segs[3].segType, SegmentType.break_);
    });

    test('hasNextSegment 判断正确', () {
      // Arrange — 2 轮 = 4 段 (index 0..3)
      final runner = FocusRunner(totalRounds: 2)..start();

      // Act & Assert
      expect(runner.hasNextSegment, isTrue); // index 0
      runner.advanceToNextSegment(); // 0 → 1
      expect(runner.hasNextSegment, isTrue); // index 1
      runner.advanceToNextSegment(); // 1 → 2
      expect(runner.hasNextSegment, isTrue); // index 2
      runner.advanceToNextSegment(); // 2 → 3
      expect(runner.hasNextSegment, isFalse); // index 3 (最后一段)
    });
  });

  group('FocusRunner 推进与 TTS', () {
    test('advanceToNextSegment 触发 onTtsRequested("休息时间")', () {
      // Arrange
      final ttsMessages = <String>[];
      final runner = FocusRunner(totalRounds: 2);
      runner.onTtsRequested = (msg) => ttsMessages.add(msg);
      runner.start();

      // Act — 从 focusBlock 推进到 break
      runner.advanceToNextSegment();

      // Assert
      expect(ttsMessages, contains('休息时间'));
      expect(runner.currentSegmentIndex, 1);
    });

    test('休息段推进不触发TTS(避免干扰)', () {
      // Arrange
      final ttsMessages = <String>[];
      final runner = FocusRunner(totalRounds: 2);
      runner.onTtsRequested = (msg) => ttsMessages.add(msg);
      runner.start();
      runner.advanceToNextSegment(); // 0 → 1 (focus → break, 触发TTS)
      ttsMessages.clear();

      // Act — 从 break 推进到下一个 focusBlock (不触发TTS)
      runner.advanceToNextSegment();

      // Assert
      expect(ttsMessages, isEmpty);
      expect(runner.currentSegmentIndex, 2);
      expect(
        runner.segments[runner.currentSegmentIndex].segType,
        SegmentType.focusBlock,
      );
    });

    test('全部轮次完成后调用 complete()', () {
      // Arrange — 2 轮 = 4 段
      final runner = FocusRunner(totalRounds: 2)..start();

      // Act
      runner.advanceToNextSegment(); // 0 → 1
      runner.advanceToNextSegment(); // 1 → 2
      runner.advanceToNextSegment(); // 2 → 3
      runner.advanceToNextSegment(); // 3 → complete

      // Assert
      expect(runner.state, SessionState.completed);
      expect(runner.isTerminal, isTrue);
    });

    test('onSegmentChanged 回调被正确调用', () {
      // Arrange
      final segmentChanges = <int>[];
      final runner = FocusRunner(totalRounds: 2);
      runner.onSegmentChanged = (index, seg) => segmentChanges.add(index);

      // Act
      runner.start(); // 触发 onSegmentChanged(0)
      runner.advanceToNextSegment(); // 0 → 1
      runner.advanceToNextSegment(); // 1 → 2

      // Assert
      expect(segmentChanges, [0, 1, 2]);
    });

    test('onStateChanged 回调被正确调用', () {
      // Arrange
      final stateChanges = <SessionState>[];
      final runner = FocusRunner(totalRounds: 2);
      runner.onStateChanged = (s) => stateChanges.add(s);

      // Act
      runner.start(); // → running
      runner.advanceToNextSegment(); // 0 → 1
      runner.advanceToNextSegment(); // 1 → 2
      runner.advanceToNextSegment(); // 2 → 3
      runner.advanceToNextSegment(); // 3 → complete

      // Assert
      expect(stateChanges, [SessionState.running, SessionState.completed]);
    });

    test('restoreFrom 正确恢复到指定 segmentIndex', () {
      // Arrange
      final runner = FocusRunner(totalRounds: 4);
      final segs = runner.segments;

      // Act
      runner.restoreFrom(
        existingState: 'PAUSED',
        lastSegmentIndex: 3,
        existingSegments: segs,
      );

      // Assert
      expect(runner.state, SessionState.paused);
      expect(runner.currentSegmentIndex, 3);
      expect(runner.canRestore, isTrue);
    });

    test('状态机非法转换抛出 StateError', () {
      // Arrange
      final runner = FocusRunner();

      // Act & Assert — created 不能直接 pause
      expect(() => runner.pause(), throwsStateError);

      // completed 不能再 start
      runner.start();
      runner.complete();
      expect(() => runner.start(), throwsStateError);
    });
  });
}
