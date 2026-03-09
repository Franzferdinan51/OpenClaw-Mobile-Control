# Android Studio Installation Guide

**Required to build APK files**

---

## Option 1: Install Android Studio (Recommended)

### **Download:**
https://developer.android.com/studio

### **Install:**
1. Download the DMG file
2. Drag Android Studio to Applications
3. Open Android Studio
4. Go through setup wizard
5. Install Android SDK (API 34 recommended)

### **After Installation:**
```bash
# Accept licenses
sdkmanager --licenses

# Verify installation
flutter doctor
```

---

## Option 2: Command Line Tools Only (Faster)

### **Download:**
https://developer.android.com/studio#command-line-tools-only

### **Install:**
```bash
# Create Android SDK directory
mkdir -p ~/Library/Android/sdk

# Download command line tools
cd ~/Library/Android/sdk
curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip cmdline-tools.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/bin cmdline-tools/latest/
mv cmdline-tools/lib cmdline-tools/latest/
mv cmdline-tools/NOTICE.txt cmdline-tools/latest/
mv cmdline-tools/source.properties cmdline-tools/latest/

# Set environment variables
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Add to ~/.zshrc for persistence
echo 'export ANDROID_HOME=~/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc

# Accept licenses
sdkmanager --licenses

# Install required components
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

---

## Verify Installation

```bash
flutter doctor
```

**Expected output:**
```
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
```

---

## Build APK

Once Android toolchain is ready:

```bash
cd /Users/duckets/Desktop/Android-App-DuckBot
flutter pub get
flutter build apk --release
```

**APK will be at:**
`build/app/outputs/flutter-apk/app-release.apk`

---

## Install on Phone

### **Via USB:**
```bash
# Enable USB debugging on phone
# Connect phone via USB
adb install build/app/outputs/flutter-apk/app-release.apk
```

### **Via WiFi (ADB Wireless):**
```bash
# Enable wireless debugging on phone
adb pair <IP>:<port>
adb connect <IP>:<port>
adb install build/app/outputs/flutter-apk/app-release.apk
```

### **Direct APK Transfer:**
1. Copy APK to phone (Google Drive, email, etc.)
2. Open APK file on phone
3. Allow "Install from unknown sources"
4. Install

---

## Share with Multiple Phones

Copy `app-release.apk` to:
- Google Drive
- Dropbox
- Local web server
- USB drive
- Direct ADB install

**Each phone needs:**
- Android 8.0+ (API 26+)
- Permission to install unknown apps
- Network access to OpenClaw gateway

---

**Ready to install Android Studio?** 🦆
