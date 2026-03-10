# Termux Integration - Fixed Implementation

## Overview

This document describes the fixed Termux integration for DuckBot Go. The implementation uses **proot-distro** to run Ubuntu inside Termux, providing a full Linux environment without requiring root access.

## How It Works

### Architecture

```
DuckBot Go App (Flutter)
    ↓
Termux Service (Dart)
    ↓
Termux Environment (/data/data/com.termux/files/)
    ↓
proot-distro (Ubuntu container)
    ↓
OpenClaw + Node.js (Full Linux environment)
```

### Key Components

1. **TermuxService** (`lib/services/termux_service.dart`)
   - Detects Termux environment
   - Manages proot-distro Ubuntu container
   - Executes commands in Ubuntu environment
   - Handles Bionic libc bypass

2. **TermuxScreen** (`lib/screens/termux_screen.dart`)
   - Interactive terminal UI
   - Setup wizard with progress tracking
   - Quick action buttons
   - Real-time output display

3. **InstallerService** (`lib/services/installer_service.dart`)
   - High-level installation management
   - Gateway lifecycle management
   - Node setup and configuration

4. **TerminalWidget** (`lib/widgets/terminal_widget.dart`)
   - Reusable terminal component
   - Can be embedded in any screen

## Installation Process

### Prerequisites

1. **Termux** must be installed from F-Droid (NOT Play Store)
   - Download: https://f-droid.org/packages/com.termux/
   - Play Store version is deprecated and doesn't work properly

2. **No root required** - Everything runs in user space

### Automated Setup

When the user taps "Setup" in the Termux screen:

1. **Update Termux packages** (`pkg update -y`)
2. **Install proot-distro** (`pkg install proot-distro -y`)
3. **Install Ubuntu** (`proot-distro install ubuntu`)
4. **Update Ubuntu packages** (`apt update && apt upgrade`)
5. **Install Node.js 22** (via NodeSource or apt)
6. **Install OpenClaw** (`npm install -g openclaw --unsafe-perm`)
7. **Create startup scripts** (Bionic libc workaround)

### Bionic libc Workaround

Android's Bionic libc causes issues with Node.js. The fix:

```bash
# Set environment variables in Ubuntu
export NODE_OPTIONS="--openssl-legacy-provider --no-warnings"
export UV_THREADPOOL_SIZE=128

# Run OpenClaw with these settings
openclaw gateway start
```

## Usage

### Starting the Terminal

```dart
// Navigate to Termux screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TermuxScreen()),
);
```

### Executing Commands

```dart
final termuxService = TermuxService();
await termuxService.initialize();

// Execute in Ubuntu environment
final result = await termuxService.executeCommand(
  'openclaw status',
  useProot: true,
);

print(result.stdout);
print(result.exitCode);
```

### Running Setup

```dart
final termuxService = TermuxService();

// Set up progress callback
termuxService.onSetupProgress = (progress) {
  print('${progress.step}: ${progress.message} (${progress.progress * 100}%)');
};

// Run setup
final success = await termuxService.runSetup();
```

### Managing Gateway

```dart
// Start gateway
await termuxService.startGateway(port: 18789);

// Check if running
final isRunning = await termuxService.isGatewayRunning();

// Stop gateway
await termuxService.stopGateway();

// Get status
final result = await termuxService.getGatewayStatus();
```

## File Structure

```
lib/
├── services/
│   ├── termux_service.dart      # Core Termux integration
│   └── installer_service.dart   # High-level installer
├── screens/
│   └── termux_screen.dart       # Terminal UI
└── widgets/
    └── terminal_widget.dart     # Reusable terminal component
```

## API Reference

### TermuxService

#### Properties

- `isInitialized` - Whether service is initialized
- `isTermuxAvailable` - Whether Termux is installed
- `isProotAvailable` - Whether proot-distro is available
- `isUbuntuInstalled` - Whether Ubuntu is installed
- `isSetupComplete` - Whether full setup is complete
- `openClawVersion` - Installed OpenClaw version
- `nodeVersion` - Installed Node.js version

#### Methods

- `initialize()` - Initialize the service
- `runSetup()` - Run complete setup process
- `executeCommand(command, {useProot})` - Execute shell command
- `installOpenClaw()` - Install OpenClaw via npm
- `updateOpenClaw()` - Update OpenClaw
- `startGateway({port})` - Start OpenClaw gateway
- `stopGateway()` - Stop OpenClaw gateway
- `isGatewayRunning()` - Check if gateway is running
- `setupNode({nodeName, nodeCapabilities})` - Setup as node

### SetupProgress

```dart
class SetupProgress {
  final String step;        // Current step ID
  final String message;     // Human-readable message
  final double progress;    // 0.0 to 1.0
  final bool isError;       // Error occurred
  final bool isComplete;    // Setup complete
}
```

## Troubleshooting

### "Termux not available"

- Install Termux from F-Droid, not Play Store
- Play Store version is deprecated and broken

### "proot-distro not available"

- Run setup to install proot-distro
- Or manually: `pkg install proot-distro`

### "Ubuntu not installed"

- Run setup to install Ubuntu
- Or manually: `proot-distro install ubuntu`

### Node.js installation fails

- Check internet connection
- Try manual install: `apt install nodejs npm`
- May need to use NodeSource setup script

### OpenClaw installation fails

- Ensure Node.js is installed first
- Check disk space (need ~500MB)
- Try with `--unsafe-perm` flag

### Gateway won't start

- Check if port 18789 is available
- Check logs: `cat /tmp/openclaw-gateway.log`
- Ensure OpenClaw is installed: `openclaw --version`

## Security Notes

- **No root required** - Everything runs in user space
- **Isolated environment** - Ubuntu runs in proot container
- **Network access** - Gateway binds to localhost by default
- **File access** - Limited to Termux's app directory

## Comparison with Reference Implementation

This implementation is based on https://github.com/mithun50/openclaw-termux:

| Feature | Reference | This Implementation |
|---------|-----------|---------------------|
| proot-distro | ✅ Yes | ✅ Yes |
| Ubuntu | ✅ Yes | ✅ Yes |
| Node.js 22 | ✅ Yes | ✅ Yes |
| Bionic bypass | ✅ Yes | ✅ Yes |
| Auto-setup | ❌ Manual | ✅ Automated |
| Terminal UI | ❌ CLI only | ✅ Flutter UI |
| Progress tracking | ❌ None | ✅ Real-time |
| Gateway control | ✅ Yes | ✅ Yes |

## Testing

### Build APK

```bash
flutter build apk --release
```

### Install on Device

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Test Steps

1. Install Termux from F-Droid
2. Install DuckBot Go APK
3. Open Termux screen
4. Tap "Setup"
5. Wait for completion
6. Tap "Start Gateway"
7. Verify gateway is running

## Future Improvements

- [ ] Add support for other Linux distros (Debian, Alpine)
- [ ] Implement backup/restore of OpenClaw config
- [ ] Add auto-start on boot option
- [ ] Support for custom gateway ports
- [ ] Integration with Tailscale for remote access
- [ ] Add file manager for OpenClaw workspace

## Credits

- Based on https://github.com/mithun50/openclaw-termux
- Uses proot-distro by Termux
- Ubuntu packages from Canonical
