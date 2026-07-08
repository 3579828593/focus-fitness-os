import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';

void main() {
  // ============================================================
  // 本地渐进超负荷 (LocalFallbackRules.calculateNewWeight)
  // 规则:
  //   completionRatio >= 1.0 → 递增 2.5kg
  //   completionRatio <  0.5 → 退阶 2.5kg (不低于 0)
  //   其它                   → 维持不变
  // ============================================================
  group('LocalFallbackRules.calculateNewWeight 渐进超负荷', () {
    test('100%完成率 → 递增2.5kg', () {
      // Arrange
      const currentWeight = 50.0;
      const completionRatio = 1.0;

      // Act
      final result = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );

      // Assert
      expect(result, 52.5);
    });

    test('40%完成率 → 退阶2.5kg', () {
      // Arrange
      const currentWeight = 50.0;
      const completionRatio = 0.4;

      // Act
      final result = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );

      // Assert
      expect(result, 47.5);
    });

    test('70%完成率 → 维持不变', () {
      // Arrange
      const currentWeight = 50.0;
      const completionRatio = 0.7;

      // Act
      final result = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );

      // Assert
      expect(result, 50.0);
    });

    test('退阶不低于0', () {
      // Arrange — 当前重量已很小, 退阶后应被 clamp 到 0
      const currentWeight = 1.0;
      const completionRatio = 0.4;

      // Act
      final result = LocalFallbackRules.calculateNewWeight(
        currentWeight: currentWeight,
        completionRatio: completionRatio,
      );

      // Assert
      expect(result, greaterThanOrEqualTo(0));
      expect(result, 0.0);
    });
  });

  // ============================================================
  // 本地冲突检测 (LocalFallbackRules.hasTimeConflict)
  // ============================================================
  group('LocalFallbackRules.hasTimeConflict 时间冲突检测', () {
    test('同时段返回true', () {
      // Arrange
      const newStartTime = '08:00';
      const existingStartTimes = ['08:00', '10:00', '19:30'];

      // Act
      final result = LocalFallbackRules.hasTimeConflict(
        newStartTime: newStartTime,
        existingStartTimes: existingStartTimes,
      );

      // Assert
      expect(result, isTrue);
    });

    test('不同时段返回false', () {
      // Arrange
      const newStartTime = '09:00';
      const existingStartTimes = ['08:00', '10:00', '19:30'];

      // Act
      final result = LocalFallbackRules.hasTimeConflict(
        newStartTime: newStartTime,
        existingStartTimes: existingStartTimes,
      );

      // Assert
      expect(result, isFalse);
    });
  });
}
