# OpenClaw Mobile App - Installation Guide

**Version:** 1.0.0  
**Platform:** Flutter (Android/iOS/Web)

---

## Prerequisites

Before building the OpenClaw Mobile App, ensure you have:

- **macOS, Linux, or Windows** with Flutter SDK support
- **Git** for version control
- **Android Studio** or command-line Android SDK tools
- **Flutter SDK** (3.x or newer)

---

## Step 1: Install Flutter SDK

### macOS / Linux

```bash
# Using Homebrew (macOS)
brew install flutter

# Or download from https://docs.flutter.dev/get-started/install

# Verify Flutter installation
flutter --version
```

### Windows

```powershell
# Download Flutter SDK
# https://docs.flutter.dev/get-started/install/windows

# Extract to desired location (e.g., C:\src\flutter)

# Add to PATH
# Right-click "This PC" → Properties → Advanced → Environment Variables
# Add C:\src\flutter\bin to Path

# Restart terminal and verify
flutter --version
```

---

## Option 3: Termux (Run OpenClaw on Android Phone)

You can run OpenClaw directly on your Android phone using Termux! This allows your phone to act as a full OpenClaw gateway.

### Install Termux

1. **Download from F-Droid** (recommended):
   - Visit https://f-droid.org/packages/com.termux/
   - Download the APK
   - Or search "Termux" in F-Droid app

2. **Or from GitHub**:
   - Visit https://github.com/termux/termux-app/releases
   - Download latest `termux-app_v*.apk`

### Initial Termux Setup

```bash
# Update package lists
pkg update

# Upgrade existing packages
pkg upgrade

# Install required packages
pkg install git python nodejs rust

# Install OpenClaw dependencies
pkg install coreutils curl wget tar

# Verify installations
python --version  # Should be 3.x
node --version    # Should be 18.x or higher
npm --version
```

### Install OpenClaw in Termux

```bash
# Clone OpenClaw repository
git clone https://github.com/your-repo/OpenClaw.git ~/openclaw
cd ~/openclaw

# Run installation
./install.sh

# Or manual setup
npm install -g openclaw-cli
openclaw init

# Start the gateway
openclaw gateway start

# Check status
openclaw gateway status
```

### Termux Node Configuration

Your phone can act as an OpenClaw node with these capabilities:

```bash
# Install Termux:API for additional access
pkg install termux-api

# Grant permissions for:
# - Camera access
# - Storage access
# - Vibration
termux-setup-storage
```

### Access Termux from Computer

```bash
# Install SSH in Termux
pkg install openssh

# Set password
passwd

# Start SSH daemon
sshd

# Connect from computer (default port 8022)
ssh <phone-ip> -p 8022
```

---

## Step 2: Install Android Studio & SDK

### Option A: Full Android Studio (Recommended)

1. **Download:** https://developer.android.com/studio
2. **Install:** Drag Android Studio to Applications (macOS) or run installer (Windows)
3. **First Launch:** Complete setup wizard
4. **Install SDK:** Select API 34 (Android 14) during setup

### Option B: Command-Line Tools Only

```bash
# Create Android SDK directory
mkdir -p ~/Library/Android/sdk

# Download command line tools
cd ~/Library/Android/sdk
curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip cmdline-tools.zip

# Organize directory structure
mkdir -p cmdline-tools/latest
mv cmdline-tools/bin cmdline-tools/latest/
mv cmdline-tools/lib cmdline-tools/latest/
mv cmdline-tools/NOTICE.txt cmdline-tools/latest/
mv cmdline-tools/source.properties cmdline-tools/latest/

# Set environment variables (add to ~/.zshrc or ~/.bashrc)
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
```

### Accept Licenses & Install Components

```bash
# Accept all Android SDK licenses
yes | sdkmanager --licenses 2>/dev/null

# Install required SDK components
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

---

## Step 3: Verify Flutter Setup

Run the Flutter doctor command to verify everything is properly configured:

```bash
flutter doctor
```

**Expected output:**
```
[✓] Flutter - SDK is properly installed
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Connected device - available devices to test
```

**If you see errors:**

| Error | Solution |
|-------|----------|
| `Android toolchain not found` | Set `ANDROID_HOME` environment variable |
| `Flutter SDK not found` | Add Flutter to system PATH |
| `Android SDK out of date` | Run `sdkmanager "platforms;android-34"` |

---

## Step 4: Clone & Setup Project

```bash
# Navigate to project directory
cd /Users/duckets/Desktop/Android-App-DuckBot

# Get Flutter dependencies
flutter pub get

# Verify project structure
ls -la lib/
```

---

## Step 5: Build Debug APK

```bash
# Build debug APK (faster, for testing)
flutter build apk --debug

# APK location: build/app/outputs/flutter-apk/app-debug.apk
```

---

## Step 6: Build Release APK

```bash
# Build release APK (optimized, smaller, for distribution)
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

---

## Build Commands Reference

| Command | Purpose | Output |
|---------|---------|--------|
| `flutter build apk --debug` | Debug build | `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build apk --release` | Release build | `build/app/outputs/flutter-apk/app-release.apk` |
| `flutter build apk --split-per-abi` | Split APKs by architecture | Multiple APKs in output dir |
| `flutter build apk --target-platform android-34` | Target specific API | APK for API 34+ |

---

## Environment Variables

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, or Windows System Variables):

```bash
# Flutter
export PATH="$HOME/.pub-cache/bin:$PATH"

# Android SDK (macOS/Linux)
export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# Add to PATH
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0

# For Windows (PowerShell)
# Add via System Properties → Environment Variables
$env:ANDROID_HOME = "C:\Users\YourName\AppData\Local\Android\Sdk"
```

---

## Troubleshooting Installation

### Flutter Issues

**"Flutter command not found"**
- Add Flutter SDK to system PATH
- Restart terminal after modification

**"pub get fails"**
- Run `flutter clean` then `flutter pub get`
- Check internet connection for package downloads

### Android SDK Issues

**"Android SDK not found"**
- Verify `ANDROID_HOME` is set: `echo $ANDROID_HOME`
- Run `flutter doctor -v` for detailed diagnostics

**"Build tools not found"**
- Install build tools: `sdkmanager "build-tools;34.0.0"`

**"Accept licenses failed"**
- Run: `yes | sdkmanager --licenses`

---

## Next Steps

After successful installation:

1. **ADB Wireless Debugging Setup** (below)
2. **Install on device** → See [DEPLOYMENT.md](./DEPLOYMENT.md)
3. **Test the API** → See [API-TESTING.md](./API-TESTING.md)
4. **Use the app** → See [USER-GUIDE.md](./USER-GUIDE.md)
5. **Termux Setup** → See [TERMUX-SETUP.md](./TERMUX-SETUP.md)

---

## Appendix: ADB Wireless Debugging Setup

### Enable Wireless Debugging on Phone

1. **Settings → About Phone**
2. **Tap "Build Number" 7 times** → Developer mode enabled
3. **Settings → System → Developer Options**
4. **Enable "Wireless Debugging"**
5. **Tap "Pair"** → Note the pairing code, IP, and port

### Method 1: Pair with Code (Android 11+)

```bash
# In Termux or computer with ADB
adb pair <phone-ip>:<port> <pairing-code>

# Example:
adb pair 192.168.1.100:37215 123456

# Then connect
adb connect <phone-ip>:<port>
```

### Method 2: USB to Wireless (Initial Setup)

```bash
# Connect phone via USB first
adb usb

# Switch to TCPIP mode
adb tcpip 5555

# Disconnect USB

# Connect over WiFi
adb connect <phone-ip>:5555

# Verify connection
adb devices
```

### Multiple Phones Setup

```bash
# List all connected devices
adb devices -l

# Install to specific device
adb -s <device-serial> install app.apk

# For multiple devices, use USB hub
# Or connect each via different ports:
adb connect <phone1-ip>:5555
adb connect <phone2-ip>:5556
adb connect <phone3-ip>:5557

# Install to all
for device in $(adb devices | grep device$ | cut -f1); do
    adb -s $device install -r app-release.apk
done
```

### Troubleshooting ADB

| Issue | Solution |
|-------|----------|
| Device unauthorized | Unlock phone, tap "Allow" on prompt |
| No devices found | Check USB cable (needs data transfer) |
| Connection refused | Restart ADB: `adb kill-server && adb start-server` |
| Offline device | Restart device, re-enable wireless debugging |

---

## OpenClaw on Android (Termux)

For running OpenClaw natively on Android devices (running as gateway/node), see:

- **[TERMUX-SETUP.md](./TERMUX-SETUP.md)** - Complete Termux installation
- **[OPENCLAW-INSTALL-GUIDE.md](./OPENCLAW-INSTALL-GUIDE.md)** - OpenClaw CLI installation

### Quick Termux OpenClaw Setup

```bash
# Install Termux from F-Droid (NOT Google Play!)
# Update and install packages
pkg update && pkg upgrade
pkg install python nodejs git openssh

# Install OpenClaw
npm install -g openclaw

# Start gateway
openclaw gateway start

# Or start as node (connects to gateway)
openclaw node start --gateway http://<gateway-ip>:18789
```

---

## Auto-Discovery Explanation

OpenClaw supports automatic discovery of gateways and nodes on your local network.

### How Auto-Discovery Works

1. **Broadcast**: Gateway broadcasts presence on port 18790 (UDP)
2. **Listen**: Nodes listen for gateway announcements
3. **Connect**: Nodes auto-connect when gateway found
4. **Monitor**: Heartbeat to maintain connection

### Enabling Auto-Discovery

**Gateway:**
```bash
# Start gateway (auto-discovery enabled by default)
openclaw gateway start
# Broadcasts on port 18790
```

**Node:**
```bash
# Auto-discover and connect
openclaw node start --auto-discover
```

### Discovery Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 18790/UDP | Broadcast | Gateway announcement |
| 18790/TCP | JSON | Node registration |
| 18789/HTTP | REST | Gateway API |
| 18789/WS | WebSocket | Real-time comms |

---

**Need help?** → See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)