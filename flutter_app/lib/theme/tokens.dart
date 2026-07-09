import 'package:flutter/material.dart';

/// Focus Fitness OS — Blueprint Design System Tokens
/// 基于建筑蓝图美学的完整设计令牌系统

// ============ 色彩令牌 ============
class AppColors {
  // 主色调
  static const accent = Color(0xFFD4744A);      // 赤陶 — 主强调色
  static const brass = Color(0xFFC9A227);        // 黄铜 — 次强调色
  static const celadon = Color(0xFF7FB069);      // 青瓷绿 — 成功/自然
  static const signal = Color(0xFF58A6FF);       // 信号蓝 — 信息/链接
  
  // 功能色
  static const success = Color(0xFF7FB069);
  static const warning = Color(0xFFD4A04A);
  static const danger = Color(0xFFE85D4A);
  
  // 深色模式背景
  static const bgDeep = Color(0xFF0D1117);       // 蓝图纸暗面
  static const bgPanel = Color(0xFF161B22);      // 面板背景
  static const bgCard = Color(0xFF1C232D);       // 卡片背景
  static const bgElevated = Color(0xFF232B36);   // 提升层
  
  // 浅色模式背景
  static const bgLight = Color(0xFFF6F8FA);
  static const bgLightPanel = Color(0xFFFFFFFF);
  static const bgLightCard = Color(0xFFF0F2F5);
  static const bgLightElevated = Color(0xFFE8EBF0);
  
  // 文字色
  static const inkDark = Color(0xFFE6EDF3);      // 深色模式主文字
  static const inkSoftDark = Color(0xFF8B949E);  // 深色模式次文字
  static const inkLight = Color(0xFF1A1A1A);     // 浅色模式主文字
  static const inkSoftLight = Color(0xFF6A737D); // 浅色模式次文字
  
  // 边框
  static const borderDark = Color(0xFF30363D);
  static const borderLight = Color(0xFFD0D7DE);
  
  // 原种子色（保留兼容）
  static const seedColor = Color(0xFF6F8F72);
}

// ============ 间距令牌 (8px 基准) ============
class AppSpacing {
  static const double xs = 4.0;     // 紧凑内间距
  static const double sm = 8.0;     // 控件间距
  static const double md = 16.0;    // 卡片内边距
  static const double lg = 24.0;    // 组间距
  static const double xl = 32.0;    // 区块间距
  static const double xxl = 48.0;   // 页面边距
}

// ============ 圆角令牌 ============
class AppRadius {
  static const double sm = 4.0;     // chips, badges
  static const double md = 8.0;     // cards, containers
  static const double lg = 12.0;    // action cards
  static const double xl = 20.0;    // pills, tags
  static const double full = 999.0; // circular
}

// ============ 字体令牌 ============
class AppFonts {
  // Flutter 端使用系统字体 + Google Fonts（运行时加载）
  // Web 端使用 CSS @font-face
  static const String sansSerif = 'Noto Sans SC';  // 中文正文
  static const String serif = 'Fraunces';           // 衬线展示
  static const String mono = 'JetBrains Mono';      // 等宽数字
  
  // 字号体系 (基于 Material 3 但自定义)
  static const double displayLarge = 32.0;
  static const double displayMedium = 28.0;
  static const double displaySmall = 24.0;
  static const double headlineLarge = 22.0;
  static const double headlineMedium = 20.0;
  static const double headlineSmall = 18.0;
  static const double titleLarge = 18.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
}

// ============ 动画令牌 ============
class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.elasticOut;
}
