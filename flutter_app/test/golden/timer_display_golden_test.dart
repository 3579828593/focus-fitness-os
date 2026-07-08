import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_fitness_os/widgets/timer_display.dart';

/// ============================================================
/// TimerDisplay Golden 测试
///
/// pubspec.yaml 未引入 golden_toolkit, 使用 Flutter 原生
/// matchesGoldenFile + pumpWidget 方案。
///
/// 首次运行需生成 golden 基线:
///   flutter test --update-goldens test/golden/timer_display_golden_test.dart
/// golden 文件输出路径: test/golden/goldens/
/// ============================================================

/// 包装 TimerDisplay 使其拥有 Theme 上下文 (CustomPainter 依赖主题色)
Widget _wrapTimer(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6F8F72),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
    home: Scaffold(body: Center(child: child)),
    debugShowCheckedModeBanner: false,
  );
}

void main() {
  group('TimerDisplay Golden Tests', () {
    /// ----------------------------------------------------------
    /// 测试1: 正常倒计时状态
    /// totalSeconds=300, remainingSeconds=180 → 进度 40%, 显示 03:00
    /// ----------------------------------------------------------
    testWidgets('正常倒计时状态 golden test', (tester) async {
      // Arrange - 总时长 300 秒, 剩余 180 秒
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(
          totalSeconds: 300,
          remainingSeconds: 180,
          color: Colors.green,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - 与 golden 基线比对
      await expectLater(
        find.byType(TimerDisplay),
        matchesGoldenFile('goldens/timer_normal.png'),
      );
    });

    /// ----------------------------------------------------------
    /// 测试2: 即将完成状态
    /// totalSeconds=300, remainingSeconds=5 → 进度约 98.3%, 显示 00:05
    /// ----------------------------------------------------------
    testWidgets('即将完成状态 golden test', (tester) async {
      // Arrange - 仅剩 5 秒
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(
          totalSeconds: 300,
          remainingSeconds: 5,
          color: Colors.green,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - 与 golden 基线比对
      await expectLater(
        find.byType(TimerDisplay),
        matchesGoldenFile('goldens/timer_almost_done.png'),
      );
    });

    /// ----------------------------------------------------------
    /// 测试3: 已完成状态
    /// totalSeconds=300, remainingSeconds=0 → 进度 100%, 显示 00:00
    /// ----------------------------------------------------------
    testWidgets('已完成状态 golden test', (tester) async {
      // Arrange - 倒计时归零
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(
          totalSeconds: 300,
          remainingSeconds: 0,
          color: Colors.green,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - 与 golden 基线比对
      await expectLater(
        find.byType(TimerDisplay),
        matchesGoldenFile('goldens/timer_completed.png'),
      );
    });
  });
}
