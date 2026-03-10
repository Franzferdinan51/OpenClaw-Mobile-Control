import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../services/theme_service.dart';

class ThemeSelectorScreen extends StatefulWidget {
  const ThemeSelectorScreen({super.key});

  @override
  State<ThemeSelectorScreen> createState() => _ThemeSelectorScreenState();
}

class _ThemeSelectorScreenState extends State<ThemeSelectorScreen> {
  late DuckBotTheme _selectedTheme;
  late ThemeMode _selectedThemeMode;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _selectedTheme = _themeService.currentTheme;
    _selectedThemeMode = _themeService.themeMode;
  }

  Future<void> _applyTheme() async {
    await _themeService.setTheme(_selectedTheme);
    await _themeService.setThemeMode(_selectedThemeMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme changed to ${_selectedTheme.displayName}'),
          backgroundColor: _themeService.getThemeColors(_selectedTheme).primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Theme Settings'),
            actions: [
              if (_selectedTheme != _themeService.currentTheme ||
                  _selectedThemeMode != _themeService.themeMode)
                TextButton(
                  onPressed: _applyTheme,
                  child: const Text('Apply'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Mode Section
              _buildSectionHeader('Theme Mode'),
              const SizedBox(height: 8),
              _buildThemeModeSelector(),
              const SizedBox(height: 24),

              // Theme Selection Section
              _buildSectionHeader('Color Theme'),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred color scheme',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Theme Cards
              ...DuckBotTheme.values.map((theme) => _buildThemeCard(theme)),

              const SizedBox(height: 24),

              // Preview Section
              _buildSectionHeader('Preview'),
              const SizedBox(height: 16),
              _buildThemePreview(),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildThemeModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_selectedThemeMode},
              onSelectionChanged: (Set<ThemeMode> selected) {
                setState(() {
                  _selectedThemeMode = selected.first;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(DuckBotTheme theme) {
    final colors = _themeService.getThemeColors(theme);
    final isSelected = _selectedTheme == theme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTheme = theme;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Theme name and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              theme.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                color: colors.primary,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Color palette preview
              _buildColorPalette(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette(ThemeColors colors) {
    return Row(
      children: [
        _buildColorSwatch('Primary', colors.primary),
        const SizedBox(width: 8),
        _buildColorSwatch('Secondary', colors.secondary),
        const SizedBox(width: 8),
        _buildColorSwatch('Tertiary', colors.tertiary),
        const SizedBox(width: 8),
        _buildColorSwatch('Surface', colors.surface),
      ],
    );
  }

  Widget _buildColorSwatch(String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview() {
    final colors = _themeService.getThemeColors(_selectedTheme);
    final customColors = _themeService.getCustomColors(_selectedTheme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App bar preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  customColors.gradientStart,
                  customColors.gradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${_selectedTheme.displayName} Theme',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primary,
                  radius: 16,
                  child: Icon(Icons.person, color: colors.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample Card',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Preview text content',
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onSurface, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Button preview
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Primary Button',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Secondary',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chip preview
          Wrap(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tag 1',
                  style: TextStyle(color: colors.primary, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tag 2',
                  style: TextStyle(color: colors.secondary, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.tertiary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tag 3',
                  style: TextStyle(color: colors.tertiary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}