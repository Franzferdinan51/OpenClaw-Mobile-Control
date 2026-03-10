import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Warm Theme - Amber/orange warmth
class WarmTheme {
  static const ThemeColors colors = ThemeColors(
    primary: Color(0xFFFF9800),
    secondary: Color(0xFFFFB74D),
    tertiary: Color(0xFFFFCC80),
    surface: Color(0xFF1A1612),
    surfaceContainerHighest: Color(0xFF2D2520),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFFF5E6D3),
    onError: Color(0xFF000000),
  );

  static const String name = 'Warm';
  static const String description = 'Cozy amber/orange warmth';
  static const String previewGradient = 'Amber and orange tones';
}