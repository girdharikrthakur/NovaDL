import 'package:flutter/material.dart';

final class AppTheme {
  static const _fontFamily = 'Google Sans Flex';
  static const _fontFallback = <String>[
    'Google Sans',
    'Segoe UI Variable',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  static ThemeData dark({
    Color seed = const Color(0xFF60A5FA),
    Color appColor = const Color(0xFF3B82F6),
  }) {
    final background = Color.lerp(const Color(0xFF121417), appColor, .12)!;
    final surface = Color.lerp(const Color(0xFF1D2026), appColor, .10)!;
    final rail = Color.lerp(const Color(0xFF181B20), appColor, .08)!;
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: .08),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: rail,
        indicatorColor: seed.withValues(alpha: .18),
      ),
    );
  }

  static ThemeData light({
    Color seed = const Color(0xFF2563EB),
    Color appColor = const Color(0xFF3B82F6),
  }) {
    final background = Color.lerp(const Color(0xFFF1F3F6), appColor, .07)!;
    final surface = Color.lerp(const Color(0xFFF8FAFC), appColor, .04)!;
    final rail = Color.lerp(const Color(0xFFECEFF4), appColor, .06)!;
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, surface: surface),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: .07),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: rail,
        indicatorColor: seed.withValues(alpha: .16),
      ),
    );
  }
}
