import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Void Theme - Pure black OLED-friendly
class VoidTheme {
  static const ThemeColors colors = ThemeColors(
    primary: Color(0xFF00D4AA),
    secondary: Color(0xFF424242),
    tertiary: Color(0xFF616161),
    surface: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFF0A0A0A),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
    onSurface: Color(0xFFE0E0E0),
    onError: Color(0xFF000000),
  );

  static const String name = 'Void';
  static const String description = 'Pure black OLED-friendly theme';
  static const String previewGradient = 'True black with teal accent';
}