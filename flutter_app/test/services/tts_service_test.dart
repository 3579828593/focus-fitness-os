import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/services/tts_service.dart';

void main() {
  // ============================================================
  // TtsQueue 队列行为 (需要控制 speak 时序)
  // ============================================================
  group('TtsQueue 队列管理', () {
    test('TtsQueue enqueue 后 pendingCount 增加', () async {
      // Arrange — 用 gate 阻塞第一条播报, 使后续入队项保持 pending
      final spoken = <String>[];
      final gate = Completer<void>();
      final queue = TtsQueue((text) async {
        spoken.add(text);
        await gate.future;
      });

      // Act
      queue.enqueue('first'); // 立即开始播报并被 gate 阻塞
      queue.enqueue('second'); // 第一条未完成 → 排队等待

      // Assert
      expect(queue.pendingCount, 1);
      expect(queue.isSpeaking, isTrue);

      // 清理
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      queue.dispose();
    });

    test('串行播报: 第一条完成前第二条不开始', () async {
      // Arrange
      final spoken = <String>[];
      final gate = Completer<void>();
      final queue = TtsQueue((text) async {
        spoken.add(text);
        await gate.future;
      });

      // Act
      queue.enqueue('first');
      queue.enqueue('second');

      // Assert — 此时只有 first 在播报
      expect(spoken, ['first']);
      expect(queue.isSpeaking, isTrue);

      // 释放第一条 → 第二条开始
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(spoken, ['first', 'second']);

      queue.dispose();
    });

    test('clear() 后 pendingCount 为 0', () async {
      // Arrange
      final gate = Completer<void>();
      final queue = TtsQueue((text) async {
        await gate.future;
      });
      queue.enqueue('first'); // 播报中, 阻塞
      queue.enqueue('second'); // pending
      queue.enqueue('third'); // pending
      expect(queue.pendingCount, 2);

      // Act
      queue.clear();

      // Assert
      expect(queue.pendingCount, 0);

      // 清理
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      queue.dispose();
    });

    test('高优先级插队到低优先级前面', () async {
      // Arrange
      final spoken = <String>[];
      final gate = Completer<void>();
      final queue = TtsQueue((text) async {
        spoken.add(text);
        await gate.future;
      });

      // Act — 先用低优先级阻塞队列
      queue.enqueue('blocker', priority: TtsPriority.low); // 立即播报, 阻塞
      // 排入一条低优先级, 再排入一条高优先级 (urgent)
      queue.enqueue('low1', priority: TtsPriority.low);
      queue.enqueue('urgent1', priority: TtsPriority.urgent);

      // Assert — urgent1 应插入到 low1 前面
      expect(queue.pendingCount, 2);

      // 释放阻塞, 观察出队顺序
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert — blocker 先播报, 之后 urgent1 在 low1 之前
      expect(spoken, ['blocker', 'urgent1', 'low1']);

      queue.dispose();
    });
  });

  // ============================================================
  // WorkoutTtsBuilder 播报内容构建 (纯函数)
  // ============================================================
  group('WorkoutTtsBuilder 播报内容', () {
    test('WorkoutTtsBuilder.setComplete 返回正确格式', () {
      // Arrange
      const setNumber = 3;
      const restSeconds = 60;

      // Act
      final result = WorkoutTtsBuilder.setComplete(
        setNumber: setNumber,
        restSeconds: restSeconds,
      );

      // Assert
      expect(result, '第3组完成，休息60秒');
    });

    test('WorkoutTtsBuilder.restCountdown 在不同秒数返回不同内容', () {
      // Arrange & Act & Assert
      expect(WorkoutTtsBuilder.restCountdown(0), '休息结束，开始下一组');
      expect(WorkoutTtsBuilder.restCountdown(10), '还有10秒');
      expect(WorkoutTtsBuilder.restCountdown(5), '还有5秒');
      expect(WorkoutTtsBuilder.restCountdown(3), '3');
      expect(WorkoutTtsBuilder.restCountdown(2), '2');
      expect(WorkoutTtsBuilder.restCountdown(1), '1');
      // 非 5 的倍数且不在 1-3 → 空字符串 (不播报)
      expect(WorkoutTtsBuilder.restCountdown(7), '');
    });

    test('WorkoutTtsBuilder.exerciseChange 包含动作名和组数次', () {
      // Arrange
      const name = '深蹲';
      const sets = 4;
      const reps = 8;

      // Act
      final result = WorkoutTtsBuilder.exerciseChange(
        name: name,
        sets: sets,
        reps: reps,
      );

      // Assert
      expect(result, '下一个动作：深蹲，4组×8次');
      expect(result, contains('深蹲'));
      expect(result, contains('4组'));
      expect(result, contains('8次'));
    });

    test('WorkoutTtsBuilder.allComplete 包含总组数和训练量', () {
      // Arrange
      const totalSets = 12;
      const volume = 2400.5;

      // Act
      final result = WorkoutTtsBuilder.allComplete(
        totalSets: totalSets,
        volume: volume,
      );

      // Assert
      expect(result, contains('训练完成'));
      expect(result, contains('12'));
      expect(result, contains('2400.5'));
    });
  });
}
