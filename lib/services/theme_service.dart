import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';
import '../themes/midnight_theme.dart';
import '../themes/void_theme.dart';
import '../themes/warm_theme.dart';
import '../themes/neon_theme.dart';
import '../themes/material_you_theme.dart';

/// Theme Service - Manages app-wide theming with 5 preset themes
class ThemeService extends ChangeNotifier {
  static ThemeService? _instance;
  static bool _initialized = false;

  DuckBotTheme _currentTheme = DuckBotTheme.midnight;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useDynamicColors = false;

  factory ThemeService() {
    _instance ??= ThemeService._internal();
    return _instance!;
  }

  ThemeService._internal();

  /// Initialize theme service from storage
  static Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final instance = ThemeService();

    final themeName = prefs.getString('duckbot_theme') ?? 'midnight';
    instance._currentTheme = DuckBotTheme.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => DuckBotTheme.midnight,
    );

    final themeModeName = prefs.getString('theme_mode') ?? 'dark';
    instance._themeMode = ThemeMode.values.firstWhere(
      (t) => t.name == themeModeName,
      orElse: () => ThemeMode.dark,
    );

    instance._useDynamicColors = prefs.getBool('use_dynamic_colors') ?? false;

    _initialized = true;
    instance.notifyListeners();
  }

  /// Get current theme
  DuckBotTheme get currentTheme => _currentTheme;

  /// Get theme mode (light/dark/system)
  ThemeMode get themeMode => _themeMode;

  /// Get use dynamic colors flag
  bool get useDynamicColors => _useDynamicColors;

  /// Check if Material You theme is active
  bool get isMaterialYou => _currentTheme == DuckBotTheme.materialYou;

  /// Set current theme
  Future<void> setTheme(DuckBotTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('duckbot_theme', theme.name);
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  /// Set use dynamic colors
  Future<void> setUseDynamicColors(bool value) async {
    _useDynamicColors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_dynamic_colors', value);
    notifyListeners();
  }

  /// Get theme colors for a specific theme
  ThemeColors getThemeColors([DuckBotTheme? theme]) {
    final targetTheme = theme ?? _currentTheme;
    switch (targetTheme) {
      case DuckBotTheme.midnight:
        return MidnightTheme.colors;
      case DuckBotTheme.void_:
        return VoidTheme.colors;
      case DuckBotTheme.warm:
        return WarmTheme.colors;
      case DuckBotTheme.neon:
        return NeonTheme.colors;
      case DuckBotTheme.materialYou:
        return MaterialYouTheme.colors;
    }
  }

  /// Get custom colors extension for a specific theme
  CustomColors getCustomColors([DuckBotTheme? theme]) {
    final targetTheme = theme ?? _currentTheme;
    switch (targetTheme) {
      case DuckBotTheme.midnight:
        return CustomColors.midnight;
      case DuckBotTheme.void_:
        return CustomColors.voidTheme;
      case DuckBotTheme.warm:
        return CustomColors.warm;
      case DuckBotTheme.neon:
        return CustomColors.neon;
      case DuckBotTheme.materialYou:
        return CustomColors.materialYou;
    }
  }

  /// Get list of all available themes
  List<DuckBotTheme> get availableThemes => DuckBotTheme.values;

  /// Get light ThemeData for a specific theme
  ThemeData getLightTheme([DuckBotTheme? theme]) {
    final targetTheme = theme ?? _currentTheme;
    final colors = getThemeColors(targetTheme);
    final customColors = getCustomColors(targetTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colors.toLightColorScheme(),
      extensions: [customColors],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        surfaceTintColor: colors.primary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: colors.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(color: colors.onSurface.withOpacity(0.7));
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.onSurface.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: colors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.primary.withOpacity(0.1),
        labelStyle: TextStyle(color: colors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(color: colors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Get dark ThemeData for a specific theme
  ThemeData getDarkTheme([DuckBotTheme? theme]) {
    final targetTheme = theme ?? _currentTheme;
    final colors = getThemeColors(targetTheme);
    final customColors = getCustomColors(targetTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors.toDarkColorScheme(),
      extensions: [customColors],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: colors.primary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colors.surfaceContainerHighest,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(color: colors.onSurface.withOpacity(0.7));
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.onSurface.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: colors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.primary.withOpacity(0.2),
        labelStyle: TextStyle(color: colors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(color: colors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary.withOpacity(0.5);
          }
          return null;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primary;
            }
            return colors.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.onPrimary;
            }
            return colors.onSurface;
          }),
        ),
      ),
    );
  }

  /// Get current ThemeData based on theme mode
  ThemeData get currentThemeData {
    switch (_themeMode) {
      case ThemeMode.light:
        return getLightTheme();
      case ThemeMode.dark:
        return getDarkTheme();
      case ThemeMode.system:
        // This will be resolved by MaterialApp
        return getDarkTheme();
    }
  }

  /// Get theme preview colors for display in selector
  List<Color> getThemePreviewColors(DuckBotTheme theme) {
    final colors = getThemeColors(theme);
    return [
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.surface,
    ];
  }
}

/// Global theme service instance
final themeService = ThemeService();