import 'package:flutter/material.dart';

/// AppTheme provides the light theme for the Calories App using the
/// visual tokens requested by the designer.
class AppTheme {
  static const Color primary = Color(0xFF00A86B);
  static const Color background = Color(0xFFF7FBF6);
  static const double cardRadius = 16.0;
  static const double cardElevation = 6.0;
  static const double padding = 16.0;

  static ThemeData lightTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(surface: background);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'Roboto',
      // Card theming is applied at the Card widget level to avoid SDK
      // compatibility differences between CardTheme / CardThemeData.
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14.0),
      ),
    );
  }
}
