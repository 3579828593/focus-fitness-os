import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/database.dart';
import 'providers/auth_provider.dart';
import 'services/app_config.dart';
import 'services/auth_service.dart';
import 'services/nodered_api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/focus_session_screen.dart';
import 'screens/workout_session_screen.dart';
import 'screens/proposal_screen.dart';
import 'theme/app_theme.dart';

/// 数据库全局 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Node-RED API 全局 Provider
/// 运行时通过 main() 中加载的 AppConfig 以 ProviderScope override 注入
/// 此处的默认值仅作为未 override 时的回退 (如直接测试场景)
final nodeRedApiProvider = Provider<NodeRedApi>((ref) {
  return NodeRedApi(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://focus-fitness-os-api.pages.dev',
    ),
    apiToken: 'dev-token',
  );
});

/// 路由配置 Provider
///
/// 监听 isAuthenticatedProvider：认证状态变化时重建 GoRouter，
/// redirect 守卫据此自动在 /login 与受保护路由之间切换。
final routerProvider = Provider<GoRouter>((ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      // 未认证且不在登录页 → 重定向到登录页
      if (!isAuth && !isLoginRoute) return '/login';
      // 已认证但仍停留在登录页 → 重定向到首页
      if (isAuth && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/schedule/:date',
        builder: (_, state) =>
            ScheduleScreen(date: state.pathParameters['date']!),
      ),
      GoRoute(
        path: '/session/focus/:entryId',
        builder: (_, state) =>
            FocusSessionScreen(entryId: int.parse(state.pathParameters['entryId']!)),
      ),
      GoRoute(
        path: '/session/workout/:entryId',
        builder: (_, state) => WorkoutSessionScreen(
            entryId: int.parse(state.pathParameters['entryId']!)),
      ),
      GoRoute(
          path: '/proposals', builder: (_, __) => const ProposalScreen()),
    ],
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  final config = await AppConfig.load();

  // 创建 ProviderContainer，注入 AppConfig 加载的真实配置。
  // 同时覆盖 nodeRedApiProvider 与 authServiceProvider，
  // 确保两者使用相同的 baseUrl。
  final container = ProviderContainer(
    overrides: [
      nodeRedApiProvider.overrideWithValue(
        NodeRedApi(
          baseUrl: config.apiBaseUrl,
          apiToken: config.apiToken,
        ),
      ),
      authServiceProvider.overrideWithValue(
        AuthService(baseUrl: config.apiBaseUrl),
      ),
    ],
  );

  // 初始化认证服务：从 SharedPreferences 加载持久化令牌。
  // 在 runApp 之前完成，保证路由守卫能正确判断初始认证状态。
  await container.read(authServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FocusFitnessApp(),
    ),
  );
}

class FocusFitnessApp extends HookConsumerWidget {
  const FocusFitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '专注健身OS',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
