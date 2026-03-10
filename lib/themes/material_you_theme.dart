import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Material You Theme - Dynamic system colors
/// Uses a teal-based default that can be overridden by dynamic color extraction
class MaterialYouTheme {
  // Default colors when dynamic colors are not available
  static const ThemeColors colors = ThemeColors(
    primary: Color(0xFF00D4AA),
    secondary: Color(0xFF03DAC6),
    tertiary: Color(0xFF3700B3),
    surface: Color(0xFF121212),
    surfaceContainerHighest: Color(0xFF1E1E1E),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFFE0E0E0),
    onError: Color(0xFF000000),
  );

  static const String name = 'Material You';
  static const String description = 'Dynamic system colors (Android 12+)';
  static const String previewGradient = 'Adapts to your wallpaper';

  /// Create theme colors from dynamic color scheme
  static ThemeColors fromColorScheme(ColorScheme scheme) {
    return ThemeColors(
      primary: scheme.primary,
      secondary: scheme.secondary,
      tertiary: scheme.tertiary,
      surface: scheme.surface,
      surfaceContainerHighest: scheme.surfaceContainerHighest,
      error: scheme.error,
      onPrimary: scheme.onPrimary,
      onSecondary: scheme.onSecondary,
      onSurface: scheme.onSurface,
      onError: scheme.onError,
    );
  }
}