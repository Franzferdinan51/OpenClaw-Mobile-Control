import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Neon Theme - Cyberpunk colors
class NeonTheme {
  static const ThemeColors colors = ThemeColors(
    primary: Color(0xFFFF00FF),
    secondary: Color(0xFF00FFFF),
    tertiary: Color(0xFFFF0080),
    surface: Color(0xFF0D0D0D),
    surfaceContainerHighest: Color(0xFF1A1A1A),
    error: Color(0xFFFF0040),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    onError: Color(0xFFFFFFFF),
  );

  static const String name = 'Neon';
  static const String description = 'Cyberpunk neon colors';
  static const String previewGradient = 'Pink, cyan, and purple neon';
}