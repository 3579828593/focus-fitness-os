import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_fitness_os/widgets/timer_display.dart';

/// ============================================================
/// TimerDisplay Widget 单元测试
/// 验证时间格式化、边界条件与进度环渲染
/// 采用 AAA 模式 (Arrange / Act / Assert)
/// ============================================================

/// 包装 TimerDisplay 使其拥有 Theme 上下文
Widget _wrapTimer(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
    debugShowCheckedModeBanner: false,
  );
}

void main() {
  group('TimerDisplay', () {
    /// ----------------------------------------------------------
    /// 测试1: 正确显示剩余时间格式 MM:SS
    /// ----------------------------------------------------------
    testWidgets('正确显示剩余时间格式 MM:SS', (tester) async {
      // Arrange - 总时长 300 秒, 剩余 180 秒 → 应显示 03:00
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(totalSeconds: 300, remainingSeconds: 180),
      ));

      // Act
      await tester.pump();

      // Assert - 中心文字显示 03:00
      expect(find.text('03:00'), findsOneWidget);
    });

    /// ----------------------------------------------------------
    /// 测试2: remainingSeconds=0 时显示 00:00
    /// ----------------------------------------------------------
    testWidgets('remainingSeconds=0 时显示 00:00', (tester) async {
      // Arrange - 倒计时归零
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(totalSeconds: 300, remainingSeconds: 0),
      ));

      // Act
      await tester.pump();

      // Assert - 显示 00:00
      expect(find.text('00:00'), findsOneWidget);
    });

    /// ----------------------------------------------------------
    /// 测试3: remainingSeconds > totalSeconds 时不崩溃
    /// progress 经 clamp 处理为 0.0, 不会抛出异常
    /// ----------------------------------------------------------
    testWidgets('remainingSeconds > totalSeconds 时不崩溃', (tester) async {
      // Arrange - 剩余 (400) 大于总数 (300)
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(totalSeconds: 300, remainingSeconds: 400),
      ));

      // Act - 触发构建, 不应抛出异常
      await tester.pump();

      // Assert - 正常渲染, 显示 06:40 (400s = 6分40秒)
      expect(find.byType(TimerDisplay), findsOneWidget);
      expect(find.text('06:40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    /// ----------------------------------------------------------
    /// 测试4: 进度环正确渲染
    /// 使用 find.byType 验证关键 widget 存在
    /// ----------------------------------------------------------
    testWidgets('进度环正确渲染', (tester) async {
      // Arrange
      await tester.pumpWidget(_wrapTimer(
        const TimerDisplay(totalSeconds: 300, remainingSeconds: 180),
      ));

      // Act
      await tester.pump();

      // Assert - TimerDisplay 内部关键 widget 均存在 (使用 descendant
      //   精确定位, 排除 Material 框架自身的 CustomPaint / SizedBox 干扰):
      //   CustomPaint: 绘制环形进度 (_TimerRingPainter)
      //   SizedBox:    尺寸容器
      //   Stack:       叠加圆环与中心文字
      expect(
        find.descendant(
          of: find.byType(TimerDisplay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TimerDisplay),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TimerDisplay),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });
  });
}
