import 'package:flutter/material.dart';
import 'tokens.dart';

/// Focus Fitness OS — 应用主题
/// 蓝图美学设计系统的 ThemeData 实现

class AppTheme {
  // ============ 深色主题（默认） ============
  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accent.withValues(alpha: 0.15),
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.brass,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brass.withValues(alpha: 0.15),
      onSecondaryContainer: AppColors.brass,
      tertiary: AppColors.celadon,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.celadon.withValues(alpha: 0.15),
      onTertiaryContainer: AppColors.celadon,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.danger.withValues(alpha: 0.15),
      onErrorContainer: AppColors.danger,
      surface: AppColors.bgPanel,
      onSurface: AppColors.inkDark,
      surfaceContainerHighest: AppColors.bgCard,
      onSurfaceVariant: AppColors.inkSoftDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark.withValues(alpha: 0.5),
      shadow: Colors.black.withValues(alpha: 0.3),
      scrim: Colors.black.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgDeep,
      canvasColor: AppColors.bgPanel,
      // 文字主题
      textTheme: _buildTextTheme(colorScheme),
      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.bgPanel,
        foregroundColor: AppColors.inkDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.sansSerif,
          fontSize: AppFonts.titleLarge,
          fontWeight: FontWeight.w600,
          color: AppColors.inkDark,
        ),
      ),
      // Card
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: EdgeInsets.zero,
      ),
      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          textStyle: TextStyle(
            fontFamily: AppFonts.sansSerif,
            fontSize: AppFonts.labelLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: AppColors.borderDark),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        ),
      ),
      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.signal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        labelStyle: TextStyle(color: AppColors.inkSoftDark, fontFamily: AppFonts.sansSerif),
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedColor: AppColors.accent.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontFamily: AppFonts.sansSerif,
          fontSize: AppFonts.labelMedium,
          color: AppColors.inkDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: BorderSide(color: AppColors.borderDark),
      ),
      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        elevation: 2,
      ),
      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgPanel,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.labelSmall),
        ),
      ),
      // ProgressIndicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.bgElevated,
        linearMinHeight: 4,
      ),
      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.bgElevated,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.sansSerif,
          color: AppColors.inkDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============ 浅色主题 ============
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accent.withValues(alpha: 0.12),
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.brass,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brass.withValues(alpha: 0.12),
      onSecondaryContainer: AppColors.brass,
      tertiary: AppColors.celadon,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.celadon.withValues(alpha: 0.12),
      onTertiaryContainer: AppColors.celadon,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.danger.withValues(alpha: 0.12),
      onErrorContainer: AppColors.danger,
      surface: AppColors.bgLightPanel,
      onSurface: AppColors.inkLight,
      surfaceContainerHighest: AppColors.bgLightCard,
      onSurfaceVariant: AppColors.inkSoftLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.borderLight.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      canvasColor: AppColors.bgLightPanel,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.bgLightPanel,
        foregroundColor: AppColors.inkLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.sansSerif,
          fontSize: AppFonts.titleLarge,
          fontWeight: FontWeight.w600,
          color: AppColors.inkLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgLightPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.borderLight),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: AppColors.borderLight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgLightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgLightCard,
        selectedColor: AppColors.accent.withValues(alpha: 0.12),
        labelStyle: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.labelMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide(color: AppColors.borderLight),
      ),
      dividerTheme: DividerThemeData(color: AppColors.borderLight, thickness: 1, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgLightPanel,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.bgLightCard,
        linearMinHeight: 4,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.bgLightCard,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
    );
  }

  // ============ TextTheme 构建 ============
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    final base = TextTheme(
      displayLarge: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.displayLarge, fontWeight: FontWeight.w700, color: scheme.onSurface),
      displayMedium: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.displayMedium, fontWeight: FontWeight.w700, color: scheme.onSurface),
      displaySmall: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.displaySmall, fontWeight: FontWeight.w600, color: scheme.onSurface),
      headlineLarge: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.headlineLarge, fontWeight: FontWeight.w600, color: scheme.onSurface),
      headlineMedium: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.headlineMedium, fontWeight: FontWeight.w600, color: scheme.onSurface),
      headlineSmall: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.headlineSmall, fontWeight: FontWeight.w500, color: scheme.onSurface),
      titleLarge: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.titleLarge, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.titleMedium, fontWeight: FontWeight.w500, color: scheme.onSurface),
      titleSmall: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.titleSmall, fontWeight: FontWeight.w500, color: scheme.onSurface),
      bodyLarge: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.bodyLarge, fontWeight: FontWeight.w400, color: scheme.onSurface),
      bodyMedium: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.bodyMedium, fontWeight: FontWeight.w400, color: scheme.onSurface),
      bodySmall: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.bodySmall, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.labelLarge, fontWeight: FontWeight.w500, color: scheme.onSurface),
      labelMedium: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.labelMedium, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(fontFamily: AppFonts.sansSerif, fontSize: AppFonts.labelSmall, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
    );
    return base;
  }
}
