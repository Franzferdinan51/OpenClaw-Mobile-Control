# OpenClaw Mobile App - Deployment Guide

**Version:** 1.0.0  
**Purpose:** Deploy and share the OpenClaw Mobile App

---

## Build APK

### Prerequisites

```bash
# Ensure Flutter is installed and configured
flutter --version

# Navigate to project
cd /Users/duckets/Desktop/Android-App-DuckBot

# Get dependencies
flutter pub get
```

### Build Commands

```bash
# Debug APK (faster, larger, for testing)
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Release APK (optimized, smaller, for distribution)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Split APKs by ABI (smaller download sizes)
flutter build apk --split-per-abi --release
# Outputs:
#   arm64-v8a/app-arm64-v8a-release.apk
#   armeabi-v7a/app-armeabi-v7a-release.apk
#   x86_64/app-x86_64-release.apk
```

---

## Install via USB

### Step 1: Enable USB Debugging on Phone

1. **Settings → About Phone**
2. **Tap "Build Number" 7 times** → Developer mode enabled
3. **Settings → System → Developer Options**
4. **Enable "USB Debugging"**

### Step 2: Connect Phone

```bash
# Connect phone via USB cable
# Grant permission on phone when prompted

# Verify connection
adb devices
```

### Step 3: Install APK

```bash
# Install debug APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# Install release APK
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Install to specific device (if multiple connected)
adb -s <device-id> install build/app/outputs/flutter-apk/app-release.apk
```

---

## Install via WiFi (ADB Wireless)

### Option A: USB + Wireless (One-Time Setup)

```bash
# Connect via USB first, then:
adb tcpip 5555

# Disconnect USB

# Find phone IP: Settings → WiFi → Network Details
adb connect <phone-ip>:5555

# Verify
adb devices
```

### Option B: Pair Code (Android 11+)

```bash
# Enable "Wireless debugging" on phone
# Settings → System → Developer Options → Wireless debugging

# Click "Pair with pairing code"
# Note the IP, port, and pairing code

adb pair <ip>:<port> <pairing-code>

# Then connect
adb connect <ip>:5555
```

### Step 3: Install Over WiFi

```bash
adb connect <phone-ip>:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Direct APK Transfer

### Methods

| Method | How |
|--------|-----|
| **Google Drive** | Upload APK → Download on phone |
| **Email** | Send APK to yourself → Download |
| **USB Cable** | Copy APK to phone storage |
| **Local Web Server** | Host APK locally → Download via browser |
| **Scp/SFTP** | Transfer to phone's file system |

### On Phone: Install APK

1. Open file manager / Downloads
2. Tap the APK file
3. Allow "Install from unknown sources" when prompted
4. Complete installation

### Enable Unknown App Installation

- **Android 8.0+ (API 26+):**
  - Settings → Apps → OpenClaw → Install unknown apps
  - Enable "Allow from this source"

- **Android 7 and below:**
  - Settings → Security → Unknown sources
  - Enable

---

## Share with Multiple Phones

### Method 1: Google Drive (Recommended)

```bash
# Upload APK to Google Drive
# Share link with all users

# Or use CLI
# Install drive.google.com/drive-client
drive upload --parent <folder-id> build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: Local Web Server

```bash
# Start simple HTTP server
cd build/app/outputs/flutter-apk
python3 -m http.server 8080

# Users visit http://<your-ip>:8080/app-release.apk
```

### Method 3: GitHub Releases

```bash
# Tag release
git tag v1.0.0
git push origin v1.0.0

# Create release on GitHub
# Upload APK as release asset

# Users download from Releases page
```

### Method 4: Direct ADB (For Multiple Devices)

```bash
# Connect all phones via USB (use hub)
# Or connect via WiFi

# Install to all connected devices
for device in $(adb devices | grep device$ | cut -f1); do
    adb -s $device install -r build/app/outputs/flutter-apk/app-release.apk
done
```

---

## App Permissions

The app requires these permissions:

| Permission | Purpose |
|------------|---------|
| `INTERNET` | Connect to OpenClaw gateway |
| `ACCESS_NETWORK_STATE` | Check connectivity |
| `ACCESS_WIFI_STATE` | Network discovery |
| `RECORD_AUDIO` | Voice input |
| `CAMERA` | Take photos |
| `READ_EXTERNAL_STORAGE` | Access photos |
| `WRITE_EXTERNAL_STORAGE` | Save files |
| `POST_NOTIFICATIONS` | Push notifications (Android 13+) |

---

## Termux API Permissions

If running OpenClaw in Termux on your phone, you'll need these additional permissions:

### Required Termux Packages

```bash
# Install Termux API for full functionality
pkg install termux-api

# Additional useful packages
pkg install coreutils curl wget git python nodejs
```

### Granting Termux Permissions

After installing `termux-api`, grant these permissions:

| Permission | Termux Command | Purpose |
|------------|----------------|---------|
| **Camera** | `termux-camera-photo` | Capture photos |
| **Storage** | `termux-setup-storage` | Access files |
| **Location** | `termux-location` | GPS coordinates |
| **SMS** | `termux-sms-send` | Send messages |
| **Notifications** | `termux-notification` | Push alerts |
| **Vibration** | `termux-vibrate` | Haptic feedback |
| **TTS** | `termux-tts` | Text-to-speech |
| **Microphone** | `termux-media-player` | Audio playback |

### Example Permission Grants

```bash
# Grant storage access
termux-setup-storage

# Test camera
termux-camera-photo -c 0 /sdcard/photo.jpg

# Get location
termux-location

# Send notification
termux-notification -t "OpenClaw" -c "Gateway online"
```

---

## ADB Setup for Multiple Phones

Deploy and manage the app across multiple Android devices.

### Network Setup (All Phones Same Network)

```bash
# Enable wireless debugging on each phone
# Settings → Developer Options → Wireless Debugging → Pair

# Pair each phone with different port
adb pair 192.168.1.101:37215  # Phone 1
adb pair 192.168.1.102:37216  # Phone 2
adb pair 192.168.1.103:37217  # Phone 3

# Verify all connected
adb devices
```

### Installation Script for Multiple Devices

```bash
#!/bin/bash
# multi-install.sh - Install on multiple phones

APK="build/app/outputs/flutter-apk/app-release.apk"

# Get all device IPs (assuming wireless ADB)
PHONES=(
    "192.168.1.101:5555"
    "192.168.1.102:5555"
    "192.168.1.103:5555"
)

for PHONE in "${PHONES[@]}"; do
    echo "Installing on $PHONE..."
    adb connect $PHONE 2>/dev/null
    adb -s $PHONE install -r $APK
    echo "✓ Installed on $PHONE"
done

echo "All devices updated!"
```

### Managing Multiple Installations

```bash
# List all devices with details
adb devices -l

# Check specific device
adb -s <serial> shell getprop ro.product.model

# Install different APKs to different devices
adb -s <serial1> install app-arm64-release.apk
adb -s <serial2> install app-armeabi-release.apk

# Uninstall from specific device
adb -s <serial> uninstall com.openclaw.mobile

# Reboot all devices
for device in $(adb devices | grep device$ | cut -f1); do
    adb -s $device reboot
done
```

### USB Hub Setup

For physical USB connections:

```bash
# Use powered USB hub (recommended)
# Connect multiple phones via hub

# Install to all at once
adb devices  # Note all serial numbers

# Use install-multiple for parallel install
adb install-multiple \
    device1_serial:app.apk \
    device2_serial:app.apk \
    device3_serial:app.apk
```

---

## Remote Command Execution Security

When running OpenClaw and executing commands remotely, follow these security practices.

### Authentication

```bash
# Always use tokens for gateway access
# Never share tokens publicly

# Token file location (keep secure)
~/.openclaw/config

# Generate new token if compromised
openclaw gateway token generate
```

### Network Security

| Practice | Recommendation |
|----------|----------------|
| **Local Network Only** | Don't expose gateway to internet |
| **Firewall** | Only allow port 18789 locally |
| **VPN** | Use VPN for remote access |
| **HTTPS** | Enable TLS in production |

### Command Execution Safety

```bash
# NEVER execute these from untrusted sources:
# - Commands that modify system files
# - Commands that install packages
# - Commands that change permissions
# - Commands that expose data

# Always verify commands before execution
# Check the source of quick actions
```

### ADB Security

| Risk | Mitigation |
|------|------------|
| Unauthorized access | Use pairing codes, not open ports |
| Data exposure | Don't grant unnecessary permissions |
| Malware | Only install APKs from trusted sources |

### Recommended Security Settings

```bash
# On gateway machine
# Limit SSH access
sudo ufw allow from 192.168.1.0/24 port 22

# Disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Use fail2ban for brute force protection
sudo apt install fail2ban
```

### Token Management

| Action | Frequency |
|--------|-----------|
| Generate new token | If compromised |
| Rotate token | Every 90 days |
| Review active tokens | Monthly |
| Revoke unused tokens | Immediately |

---

## APK Sizes

| Build Type | Approximate Size | Notes |
|------------|------------------|-------|
| Debug | ~50-70 MB | Includes debug symbols |
| Release | ~15-25 MB | Optimized, smaller |
| Split ABI (arm64) | ~12-15 MB | Per architecture |

---

## Testing on Emulator

### Start Emulator

```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator-id>

# Or use AVD manager
emulator -avd <avd-name>
```

### Install on Emulator

```bash
# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# For x86/x86_64 emulators, use x86 APK
adb install build/app/outputs/flutter-apk/app-x86_64-release.apk
```

---

## Play Store Distribution (Optional)

### Step 1: Create Play Console Account

1. Sign up at https://play.google.com/console
2. Pay one-time $25 registration fee
3. Create app listing

### Step 2: Prepare Release Build

```bash
# Generate signing config (or use existing)
# keytool -genkey -v -keystore openclaw-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias openclaw

# Build release with signing
flutter build apk --release \
  --keystore=./openclaw-key.jks \
  --keystore-password=<password> \
  --key-password=<password>
```

### Step 3: Upload to Play Console

1. **Create Release** → Production/Beta/Internal
2. **Upload APK** → Drag app-release.apk
3. **App Content** → Fill in store listing
4. **Submit for Review**

---

## Firebase App Distribution (For Beta Testing)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (if not done)
firebase init appdistribution

# Upload APK
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app <firebase-app-id> \
  -- testers "email1@example.com,email2@example.com" \
  --release-notes "Bug fixes and improvements"
```

---

## Update & Reinstall

### Update App

```bash
# Rebuild with new code
flutter build apk --release

# Install over existing
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Uninstall

```bash
# Via ADB
adb uninstall com.openclaw.mobile

# Via phone
# Settings → Apps → OpenClaw → Uninstall
```

---

## Device Compatibility

| Android Version | Support |
|-----------------|----------|
| Android 14 (API 34) | ✅ Full |
| Android 13 (API 33) | ✅ Full |
| Android 12 (API 31) | ✅ Full |
| Android 11 (API 30) | ✅ Full |
| Android 10 (API 29) | ✅ Full |
| Android 9 (API 28) | ✅ Full |
| Android 8.0+ (API 26+) | ✅ Full |
| Android 7.x (API 25) | ⚠️ May work |

---

## Next Steps

- **Configure the app** → See [USER-GUIDE.md](./USER-GUIDE.md)
- **Test API endpoints** → See [API-TESTING.md](./API-TESTING.md)
- **Troubleshoot issues** → See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)