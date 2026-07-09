import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/auth_service.dart';

/// AuthService 全局 Provider
///
/// 使用 String.fromEnvironment 获取 baseUrl 作为默认回退值。
/// 在 main() 中会通过 ProviderContainer 的 overrides 使用 AppConfig
/// 加载的真实 baseUrl 覆盖此 Provider，确保与 nodeRedApiProvider 一致。
final authServiceProvider = Provider<AuthService>((ref) {
  final baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://focus-fitness-os-api.pages.dev',
  );
  final service = AuthService(baseUrl: baseUrl);
  ref.onDispose(() => service.dispose());
  return service;
});

/// 认证状态 Stream Provider
///
/// 监听 AuthService 的 statusStream，驱动 UI 响应式更新。
final authStateProvider = StreamProvider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.statusStream;
});

/// 是否已认证
///
/// 优先读取 StreamProvider 的最新状态；当 Stream 尚未发出数据时
/// （例如应用启动初期 init() 已在 main() 中执行但 StreamProvider
/// 尚未订阅到广播流的历史事件），回退到 AuthService 的同步状态
/// `isAuthenticated`，避免已登录用户被错误重定向到登录页。
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (status) => status == AuthStatus.authenticated,
    orElse: () => authService.isAuthenticated,
  );
});
