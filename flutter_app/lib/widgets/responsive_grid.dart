import 'package:flutter/material.dart';

/// 响应式网格 — 根据屏幕宽度自动调整列数
///
/// 手机: 1 列
/// 平板: 2 列
/// 桌面: 3-4 列
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200 ? 4 : (width >= 900 ? 3 : (width >= 600 ? 2 : 1));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: width >= 600 ? 1.5 : 1.0,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// 响应式内容容器 — 限制最大宽度，居中显示
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
