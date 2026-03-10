import 'package:flutter/material.dart';

/// AppTheme enum for the 5 theme options
enum DuckBotTheme {
  midnight('Midnight', 'Dark blue/purple tones'),
  void_('Void', 'Pure black OLED-friendly'),
  warm('Warm', 'Amber/orange warmth'),
  neon('Neon', 'Cyberpunk colors'),
  materialYou('Material You', 'Dynamic system colors');

  final String displayName;
  final String description;

  const DuckBotTheme(this.displayName, this.description);
}

/// Theme colors data class
class ThemeColors {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color surface;
  final Color surfaceContainerHighest;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onSurface;
  final Color onError;

  const ThemeColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surface,
    required this.surfaceContainerHighest,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onSurface,
    required this.onError,
  });

  /// Convert to ColorScheme for dark theme
  ColorScheme toDarkColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withOpacity(0.2),
      onPrimaryContainer: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondary.withOpacity(0.2),
      onSecondaryContainer: onSecondary,
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: tertiary.withOpacity(0.2),
      onTertiaryContainer: Colors.white,
      error: error,
      onError: onError,
      errorContainer: error.withOpacity(0.2),
      onErrorContainer: onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurface.withOpacity(0.7),
      outline: onSurface.withOpacity(0.3),
      outlineVariant: onSurface.withOpacity(0.15),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: primary,
    );
  }

  /// Convert to ColorScheme for light theme
  ColorScheme toLightColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withOpacity(0.15),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondary.withOpacity(0.15),
      onSecondaryContainer: secondary,
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: tertiary.withOpacity(0.15),
      onTertiaryContainer: tertiary,
      error: error,
      onError: onError,
      errorContainer: error.withOpacity(0.15),
      onErrorContainer: error,
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceContainerHighest: const Color(0xFFF5F5F5),
      onSurfaceVariant: Colors.black.withOpacity(0.7),
      outline: Colors.black.withOpacity(0.3),
      outlineVariant: Colors.black.withOpacity(0.15),
      shadow: Colors.black26,
      scrim: Colors.black,
      inverseSurface: Colors.black,
      onInverseSurface: Colors.white,
      inversePrimary: primary,
    );
  }
}

/// Theme extension for custom colors accessible via Theme.of(context).extension<CustomColors>()
class CustomColors extends ThemeExtension<CustomColors> {
  final Color accent;
  final Color success;
  final Color warning;
  final Color info;
  final Color gradientStart;
  final Color gradientEnd;

  const CustomColors({
    required this.accent,
    required this.success,
    required this.warning,
    required this.info,
    required this.gradientStart,
    required this.gradientEnd,
  });

  static const CustomColors midnight = CustomColors(
    accent: Color(0xFF00D4AA),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    info: Color(0xFF2196F3),
    gradientStart: Color(0xFF1A237E),
    gradientEnd: Color(0xFF4A148C),
  );

  static const CustomColors voidTheme = CustomColors(
    accent: Color(0xFF00D4AA),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    info: Color(0xFF2196F3),
    gradientStart: Color(0xFF000000),
    gradientEnd: Color(0xFF1A1A1A),
  );

  static const CustomColors warm = CustomColors(
    accent: Color(0xFFFF9800),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    info: Color(0xFF2196F3),
    gradientStart: Color(0xFFFF6F00),
    gradientEnd: Color(0xFFE65100),
  );

  static const CustomColors neon = CustomColors(
    accent: Color(0xFFFF00FF),
    success: Color(0xFF00FF00),
    warning: Color(0xFFFFFF00),
    info: Color(0xFF00FFFF),
    gradientStart: Color(0xFFFF0080),
    gradientEnd: Color(0xFF00FFFF),
  );

  static const CustomColors materialYou = CustomColors(
    accent: Color(0xFF00D4AA),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    info: Color(0xFF2196F3),
    gradientStart: Color(0xFF00D4AA),
    gradientEnd: Color(0xFF00D4AA),
  );

  @override
  CustomColors copyWith({
    Color? accent,
    Color? success,
    Color? warning,
    Color? info,
    Color? gradientStart,
    Color? gradientEnd,
  }) {
    return CustomColors(
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
    );
  }

  @override
  CustomColors lerp(CustomColors? other, double t) {
    if (other == null) return this;
    return CustomColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
    );
  }
}