import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/main.dart' hide main;
import 'package:focus_fitness_os/screens/home_screen.dart';

/// ============================================================
/// HomeScreen Widget 测试骨架
/// 使用内存数据库覆盖 databaseProvider, 验证基本渲染与导航
///
/// 前置条件:
///   - build_runner 已生成 .g.dart 文件 (database.g.dart, daos.g.dart)
///   - 种子数据在 AppDatabase.onCreate 中自动执行
/// ============================================================

void main() {
  late AppDatabase db;

  setUpAll(() async {
    // HomeScreen 使用 DateFormat('MM月dd日 EEEE', 'zh_CN'), 需初始化中文 locale
    await initializeDateFormatting('zh_CN', null);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// 构建带数据库覆盖的 HomeScreen 测试 Widget
  Widget buildHomeScreen({GoRouter? router}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp.router(
        routerConfig: router ??
            GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const HomeScreen(),
                ),
                GoRoute(
                  path: '/schedule/:date',
                  builder: (_, __) => const Scaffold(
                    body: Center(child: Text('Schedule Screen')),
                  ),
                ),
                GoRoute(
                  path: '/proposals',
                  builder: (_, __) => const Scaffold(
                    body: Center(child: Text('Proposals Screen')),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('渲染标题 专注健身OS', (tester) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('专注健身OS'), findsOneWidget);
    });

    testWidgets('显示日期卡片', (tester) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      // 日期卡片中包含 "今日 X 项安排" 文本
      expect(find.textContaining('今日'), findsOneWidget);
    });

    testWidgets('显示日程数量', (tester) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      // 种子数据中没有日程, 应显示 "今日 0 项安排"
      expect(find.text('今日 0 项安排'), findsOneWidget);
    });

    testWidgets('显示目标进度', (tester) async {
      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      // 标题 "目标进度" 存在
      expect(find.text('目标进度'), findsOneWidget);

      // 种子数据中有2个活跃目标, 应渲染2个进度条
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('点击日程按钮触发导航', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/schedule/:date',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Schedule Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildHomeScreen(router: router));
      await tester.pumpAndSettle();

      // 点击 "今日日程" 卡片
      await tester.tap(find.text('今日日程'));
      await tester.pumpAndSettle();

      // 验证导航到了 schedule 页面
      expect(find.text('Schedule Screen'), findsOneWidget);
    });
  });
}
