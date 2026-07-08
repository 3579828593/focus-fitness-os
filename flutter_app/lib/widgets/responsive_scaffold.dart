import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 响应式脚手架 — 根据屏幕宽度自动切换导航模式
///
/// 手机 (<600px): BottomNavigationBar 底部导航
/// 平板 (600-900px): NavigationRail 紧凑侧边栏
/// 桌面 (>=900px): NavigationRail 扩展侧边栏 + 宽内容区
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页', route: '/'),
    (icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: '日程', route: '/schedule'),
    (icon: Icons.fitness_center_outlined, selectedIcon: Icons.fitness_center, label: '训练', route: '/session'),
    (icon: Icons.lightbulb_outline, selectedIcon: Icons.lightbulb, label: '提案', route: '/proposals'),
  ];

  void _navigate(BuildContext context, int index) {
    final route = _destinations[index].route;
    if (route == '/schedule') {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      context.go('/schedule/$today');
    } else {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // 桌面/平板: 侧边导航栏
    if (width >= 600) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => _navigate(context, i),
              extended: width >= 900,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.fitness_center, size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // 手机: 底部导航栏
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// 获取当前路由对应的导航索引
int getCurrentNavIndex(String location) {
  if (location.startsWith('/schedule')) return 1;
  if (location.startsWith('/session')) return 2;
  if (location.startsWith('/proposals')) return 3;
  return 0; // home
}
