import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/database.dart';
import 'services/app_config.dart';
import 'services/nodered_api.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/focus_session_screen.dart';
import 'screens/workout_session_screen.dart';
import 'screens/proposal_screen.dart';

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
      defaultValue: 'https://focus-fitness-os-api.focus-fitness-os.workers.dev',
    ),
    apiToken: 'dev-token',
  );
});

/// 路由配置 Provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
  final config = await AppConfig.load();
  runApp(
    ProviderScope(
      overrides: [
        nodeRedApiProvider.overrideWithValue(
          NodeRedApi(
            baseUrl: config.apiBaseUrl,
            apiToken: config.apiToken,
          ),
        ),
      ],
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F8F72),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F8F72),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
