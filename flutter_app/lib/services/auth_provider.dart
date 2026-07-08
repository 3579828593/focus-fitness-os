import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth_service.dart';
import '../main.dart'; // for nodeRedApiProvider baseUrl

/// AuthService Provider
/// 创建 AuthService 实例, 使用 nodeRedApiProvider 的 baseUrl 初始化
/// 启动时自动从 SharedPreferences 加载持久化令牌
final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(nodeRedApiProvider);
  final service = AuthService(baseUrl: api.baseUrl);
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 认证状态 Stream Provider
/// 监听 AuthService 的状态变化, 驱动 UI 响应式更新
final authStatusProvider = StreamProvider<AuthStatus>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.statusStream;
});
