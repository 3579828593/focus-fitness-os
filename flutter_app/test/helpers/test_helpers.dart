import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';
import 'package:focus_fitness_os/main.dart' hide main;
import 'package:focus_fitness_os/screens/home_screen.dart';
import 'package:focus_fitness_os/screens/schedule_screen.dart';
import 'package:focus_fitness_os/screens/focus_session_screen.dart';
import 'package:focus_fitness_os/screens/workout_session_screen.dart';
import 'package:focus_fitness_os/screens/proposal_screen.dart';

/// ============================================================
/// 共享测试工具类
/// 提供: 内存数据库 / Provider 覆盖 / 测试用 App 包装
/// 所有 widget 测试与集成测试复用本文件
/// ============================================================

/// 创建内存数据库用于测试
/// 使用 NativeDatabase.memory() 确保每次测试数据隔离,
/// 数据库在 onCreate 中自动执行种子数据 (seedDatabase)
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// 创建测试用 Provider overrides
/// - databaseProvider: 覆盖为传入的内存数据库
/// - nodeRedApiProvider: 覆盖为无效地址 (http://localhost:1, maxRetries: 0)
///   使所有网络请求快速失败, 走本地降级逻辑
List<Override> createTestOverrides(AppDatabase db) {
  return [
    databaseProvider.overrideWithValue(db),
    nodeRedApiProvider.overrideWithValue(
      NodeRedApi(
        baseUrl: 'http://localhost:1',
        apiToken: 'test-token',
        maxRetries: 0,
      ),
    ),
  ];
}

/// 初始化测试所需的 locale 数据
/// HomeScreen 使用 DateFormat('MM月dd日 EEEE', 'zh_CN'), 需在测试前调用一次
Future<void> initTestLocales() async {
  await initializeDateFormatting('zh_CN', null);
}

/// ============================================================
/// TestApp: 测试用 App 包装
/// 组合 ProviderScope (带 overrides) + MaterialApp.router + 路由配置
/// 路由配置:
///   /                          -> HomeScreen
///   /schedule/:date            -> ScheduleScreen
///   /session/focus/:entryId    -> FocusSessionScreen
///   /session/workout/:entryId  -> WorkoutSessionScreen
///   /proposals                 -> ProposalScreen
/// ============================================================
class TestApp extends StatelessWidget {
  /// ProviderScope 覆盖列表 (通常由 createTestOverrides 生成)
  final List<Override> overrides;

  /// 路由初始位置, 默认首页
  final String initialLocation;

  const TestApp({
    super.key,
    this.overrides = const [],
    this.initialLocation = '/',
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        title: '专注健身OS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8F72),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true),
        ),
        routerConfig: _buildRouter(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// 构建测试路由配置
  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/schedule/:date',
          builder: (_, state) =>
              ScheduleScreen(date: state.pathParams['date']!),
        ),
        GoRoute(
          path: '/session/focus/:entryId',
          builder: (_, state) => FocusSessionScreen(
            entryId: int.parse(state.pathParams['entryId']!),
          ),
        ),
        GoRoute(
          path: '/session/workout/:entryId',
          builder: (_, state) => WorkoutSessionScreen(
            entryId: int.parse(state.pathParams['entryId']!),
          ),
        ),
        GoRoute(
          path: '/proposals',
          builder: (_, __) => const ProposalScreen(),
        ),
      ],
    );
  }
}
