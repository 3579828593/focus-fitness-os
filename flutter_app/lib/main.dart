import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/database.dart';
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
/// 生产环境默认使用 Railway 部署的 API
/// 本地开发可通过 --dart-define=API_BASE_URL=http://127.0.0.1:1880 覆盖
final nodeRedApiProvider = Provider<NodeRedApi>((ref) {
  return NodeRedApi(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://focus-fitness-os-backend-production.up.railway.app',
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

void main() {
  runApp(const ProviderScope(child: FocusFitnessApp()));
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
