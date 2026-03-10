# Fonts Directory

This directory contains custom font files for DuckBot Go.

## Current Fonts

- `OpenClaw-Regular.ttf` - Placeholder (0 bytes, not used)
- `OpenClaw-Bold.ttf` - Placeholder (0 bytes, not used)

## Font Status

⚠️ **Custom fonts are currently disabled.**

The app uses Material Design system fonts:
- Default text: Roboto (Android default)
- Monospace: Platform monospace font
- Used for code/terminal output

## Adding Custom Fonts

When ready to add custom fonts:

1. **Replace placeholder files:**
   - Add actual .ttf or .otf font files
   - Ensure files are not 0 bytes

2. **Update pubspec.yaml:**
   ```yaml
   flutter:
     fonts:
       - family: OpenClaw
         fonts:
           - asset: assets/fonts/OpenClaw-Regular.ttf
           - asset: assets/fonts/OpenClaw-Bold.ttf
             weight: 700
   ```

3. **Update code:**
   ```dart
   Text(
     'Custom Font Text',
     style: TextStyle(fontFamily: 'OpenClaw'),
   )
   ```

## Font Recommendations

- **Primary:** Inter, Poppins, or Nunito for modern UI
- **Monospace:** JetBrains Mono or Fira Code for code blocks
- **Display:** Custom brand font for headers

## Current Status

🚧 Using system fonts - custom fonts to be added in future releases