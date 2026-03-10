import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Midnight Theme - Dark blue/purple tones
class MidnightTheme {
  static const ThemeColors colors = ThemeColors(
    primary: Color(0xFF00D4AA),
    secondary: Color(0xFF7C4DFF),
    tertiary: Color(0xFFBB86FC),
    surface: Color(0xFF121212),
    surfaceContainerHighest: Color(0xFF1E1E2E),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
    onSurface: Color(0xFFE0E0E0),
    onError: Color(0xFF000000),
  );

  static const String name = 'Midnight';
  static const String description = 'Dark blue/purple tones with teal accent';
  static const String previewGradient = 'Deep blues and purples';
}