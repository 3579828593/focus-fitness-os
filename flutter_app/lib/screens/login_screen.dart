import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/tokens.dart';

/// 登录屏幕 — Blueprint 设计系统美学
///
/// 深色背景 + 居中登录卡片，赤陶色主按钮，
/// 衬线标题 "专注健身OS" + 无衬线副标题 "Focus Fitness OS"。
/// 登录成功后由路由守卫 (routerProvider redirect) 自动跳转首页。
class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 默认填充 admin 用户名，方便测试
    final usernameController = useTextEditingController(text: 'admin');
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final obscurePassword = useState(true);

    Future<void> handleLogin() async {
      final username = usernameController.text.trim();
      final password = passwordController.text;

      if (username.isEmpty || password.isEmpty) {
        errorMessage.value = '请输入用户名和密码';
        return;
      }

      errorMessage.value = null;
      isLoading.value = true;

      final authService = ref.read(authServiceProvider);
      final success = await authService.login(username, password);

      if (!context.mounted) return;

      isLoading.value = false;

      if (success) {
        // 登录成功：AuthService 状态变为 authenticated，
        // isAuthenticatedProvider 随之更新，触发 routerProvider 重建，
        // GoRouter redirect 检测到已认证且位于 /login → 自动跳转 /
        // 此处无需手动导航，由路由守卫接管。
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登录成功'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        errorMessage.value = '登录失败，请检查用户名和密码';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ============ 标题区域 ============
                    Text(
                      '专注健身OS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: AppFonts.displayLarge,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Focus Fitness OS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.sansSerif,
                        fontSize: AppFonts.bodyMedium,
                        color: AppColors.inkSoftDark,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ============ 用户名输入框 ============
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: 'admin',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading.value,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ============ 密码输入框 ============
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        hintText: '请输入密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => obscurePassword.value =
                              !obscurePassword.value,
                        ),
                      ),
                      obscureText: obscurePassword.value,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading.value,
                      onSubmitted: (_) =>
                          isLoading.value ? null : handleLogin(),
                    ),

                    // ============ 错误提示 ============
                    if (errorMessage.value != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        errorMessage.value!,
                        style: TextStyle(
                          fontFamily: AppFonts.sansSerif,
                          color: AppColors.danger,
                          fontSize: AppFonts.bodySmall,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    // ============ 登录按钮 ============
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed:
                            isLoading.value ? null : handleLogin,
                        child: isLoading.value
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                ),
                              )
                            : Text(
                                '登录',
                                style: TextStyle(
                                  fontFamily: AppFonts.sansSerif,
                                  fontSize: AppFonts.labelLarge,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ============ 测试提示 ============
                    Text(
                      '测试账号: admin / 密码',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.sansSerif,
                        fontSize: AppFonts.labelSmall,
                        color: AppColors.inkSoftDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
