# Animations Directory

This directory contains animation assets for DuckBot Go.

## Planned Animations

- **Loading states:** Spinner animations, skeleton loaders
- **Success/error feedback:** Check marks, error indicators
- **Onboarding:** Animated walkthrough sequences
- **Transitions:** Screen transitions, element transforms
- **Character animations:** DuckBot mascot animations

## Format Guidelines

- Use Lottie (.json) for vector animations (recommended)
- Use Rive (.riv) for interactive animations
- Use GIF for simple frame-based animations
- Keep animation files optimized and small

## Adding Animations

### Lottie Animations
1. Add .json file to this directory
2. Add `lottie: ^3.0.0` to pubspec.yaml dependencies
3. Use: `Lottie.asset('assets/animations/filename.json')`

### Rive Animations
1. Add .riv file to this directory
2. Add `rive: ^0.13.0` to pubspec.yaml dependencies
3. Use RiveAnimation widget

## Current Status

🚧 Placeholder directory - animations to be added in future releases