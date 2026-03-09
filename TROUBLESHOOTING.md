# OpenClaw Mobile App - Troubleshooting Guide

**Version:** 1.0.0  
**Purpose:** Common errors and solutions

---

## Build Issues

### Flutter Command Not Found

**Error:**
```
bash: flutter: command not found
```

**Solution:**
```bash
# Add Flutter to PATH (add to ~/.zshrc or ~/.bashrc)
export PATH="$HOME/flutter/bin:$PATH"

# Or use full path
/Users/your-username/flutter/bin/flutter --version

# Then reload terminal
source ~/.zshrc
```

---

### Android SDK Not Found

**Error:**
```
Android toolchain not found - please install the Android SDK
```

**Solution:**
```bash
# Set ANDROID_HOME environment variable
export ANDROID_HOME=~/Library/Android/sdk

# Add to shell profile
echo 'export ANDROID_HOME=~/Library/Android/sdk' >> ~/.zshrc

# Install SDK components
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Verify
flutter doctor
```

---

### Build Fails with Gradle Error

**Error:**
```
Execution failed for task ':app:compileDebugKotlin'
> Kotlin could not be found
```

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

Or update `android/build.gradle`:
```groovy
buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

---

### APK Too Large

**Error:**
```
APK size is much larger than expected (100MB+)
```

**Solution:**
```bash
# Build release APK (smaller)
flutter build apk --release

# Or split by ABI
flutter build apk --split-per-abi --release
```

Or enable R8 minification in `android/app/build.gradle`:
```groovy
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
    }
}
```

---

## Installation Issues

### USB Debugging Not Working

**Error:**
```
error: device unauthorized
```

**Solution:**
1. Unlock your phone
2. Connect via USB
3. Check phone screen - you'll see "Allow USB debugging?"
4. Tap "Allow" and optionally "Always allow"
5. Run `adb devices` again

---

### ADB Not Recognizing Device

**Error:**
```
List of devices attached
(empty)
```

**Solution:**
```bash
# Restart ADB server
adb kill-server
adb start-server

# Check USB cable (use data-capable cable)
# Try different USB port

# For Windows: Install ADB drivers from manufacturer
```

---

### "Install from unknown sources" Blocked

**Error:**
```
Install blocked by Play Protect
```

**Solution:**
- **Android 8.0+:**
  1. Settings → Apps → OpenClaw → Install unknown apps
  2. Enable "Allow from this source"

- **Bypass Play Protect:**
  1. Open Play Store → Profile → Play Protect
  2. Disable "Scan apps with Play Protect"

---

### ADB Wireless Not Connecting

**Error:**
```
failed to connect to 192.168.1.100:5555
```

**Solution:**
```bash
# Make sure phone and computer on same network
# Check firewall: adb uses port 5555

# Restart ADB daemon on phone
# Developer Options → Wireless debugging → Turn off, then on

# Try connecting again
adb connect <phone-ip>:5555
```

---

## Connection Issues

### Cannot Connect to Gateway

**Error:**
```
Connection refused
Connection timed out
```

**Possible Causes:**
1. Gateway not running
2. Wrong IP address
3. Firewall blocking port 18789
4. Phone not on same network

**Solutions:**
```bash
# 1. Check if gateway is running
curl http://localhost:18789/api/health

# 2. Verify gateway IP
# On gateway machine, run:
hostname -I

# 3. Test connectivity from phone
ping <gateway-ip>

# 4. Check firewall (on gateway)
sudo ufw allow 18789/tcp

# 5. Find correct local IP
# Gateway must be accessible from phone
```

---

### Token Authentication Failed

**Error:**
```json
{
  "success": false,
  "error": {
    "code": "AUTH_INVALID",
    "message": "Token expired or invalid"
  }
}
```

**Solution:**
```bash
# Get fresh token from gateway
cat ~/.openclaw/config | grep token

# Or regenerate
openclaw gateway token generate
```

---

### WebSocket Connection Failed

**Error:**
```
WebSocket connection failed
```

**Solution:**
```bash
# Check WebSocket endpoint is enabled
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: test" \
  http://localhost:18789/api/mobile/ws

# Check gateway logs for WebSocket errors
tail -f ~/.openclaw/logs/gateway.log
```

---

## Runtime Issues

### App Crashes on Launch

**Error:**
```
App keeps crashing / stops working
```

**Solutions:**
```bash
# 1. Clear app cache
adb shell pm clear com.openclaw.mobile

# 2. Uninstall and reinstall
adb uninstall com.openclaw.mobile
adb install app-release.apk

# 3. Check for updates
# Make sure you're using latest APK

# 4. Check logs
adb logcat -d | grep -i openclaw
```

---

### Chat Not Working

**Error:**
```
Messages not sending / receiving
```

**Solutions:**
1. Check WebSocket connection (should auto-reconnect)
2. Verify gateway is running: `openclaw gateway status`
3. Check network connectivity
4. Review chat history with:
```bash
curl -X GET http://localhost:18789/api/mobile/chat/history/session-key \
  -H "Authorization: Bearer $TOKEN"
```

---

### Quick Actions Not Running

**Error:**
```
Action fails or returns error
```

**Solutions:**
```bash
# 1. List available actions
curl -X GET http://localhost:18789/api/mobile/quick-actions \
  -H "Authorization: Bearer $TOKEN"

# 2. Check if script exists on gateway
ls -la ~/.openclaw/scripts/

# 3. Manually run script to test
cd ~/.openclaw/scripts
./grow-status-check.sh
```

---

### Notifications Not Receiving

**Error:**
```
No push notifications
```

**Solutions:**
1. **Check notification permissions:**
   - Settings → Apps → OpenClaw → Notifications
   - Enable all permissions

2. **Check gateway notifications:**
```bash
# Check notification configuration
cat ~/.openclaw/config | grep -i notify
```

3. **Android 13+ specific:**
   - Settings → Apps → OpenClaw → Notifications
   - Enable "Notifications" toggle

---

## Network Issues

### mDNS Discovery Not Working

**Error:**
```
Gateway not found during auto-discovery
```

**Solutions:**
```bash
# 1. Check if avahi-daemon (Linux) or Bonjour (macOS) is running
# macOS: Should be running by default
# Linux:
sudo systemctl status avahi-daemon

# 2. Test mDNS manually
ping duckbot-gateway.local

# 3. Fallback: Use manual IP entry
# In app: Settings → Gateway → Manual Entry
```

---

### Cannot Access Gateway Over Internet

**Error:**
```
Connection works on WiFi but not cellular
```

**Solutions:**
This is **by design** - the app uses local network only. For remote access:

1. **VPN:** Set up OpenVPN or Tailscale to access home network
2. **Port Forward:** Forward port 18789 on router (not recommended - security risk)
3. **Cloud Relay:** Use optional cloud sync feature (future)

---

## Data Issues

### Cache Issues

**Error:**
```
Stale data / old status showing
```

**Solutions:**
```bash
# Clear local cache (in app)
# Settings → Data Usage → Clear Cache

# Or via ADB
adb shell pm clear com.openclaw.mobile
```

---

### Chat History Not Syncing

**Error:**
```
Missing chat messages
```

**Solutions:**
```bash
# Check if history is stored locally
ls -la ~/.openclaw/mobile/

# Export chat from gateway
curl -X GET "http://localhost:18789/api/mobile/chat/history/session-key?limit=200" \
  -H "Authorization: Bearer $TOKEN" \
  -o chat-history.json
```

---

## Performance Issues

### App Running Slow

**Solutions:**
1. Close unused apps on phone
2. Check phone storage - free up space
3. Update to latest APK version
4. Restart your phone

---

### High Battery Usage

**Solutions:**
1. Reduce auto-refresh interval
   - Settings → Data Usage → Auto-refresh

2. Disable background data
   - Settings → Data Usage → Background data

3. Use WiFi instead of cellular

---

## Gateway Issues

### Gateway Not Running

**Error:**
```
Gateway offline
```

**Solution:**
```bash
# On gateway machine
openclaw gateway start
openclaw gateway status

# Check logs
tail -f ~/.openclaw/logs/gateway.log
```

---

### Gateway Not Responding

**Solutions:**
```bash
# Restart gateway
openclaw gateway restart

# Or manually
pkill -f openclaw
openclaw gateway start

# Check for errors
cat ~/.openclaw/logs/gateway.log | tail -50
```

---

## Getting More Help

### Collect Debug Information

```bash
# 1. Flutter doctor output
flutter doctor -v > flutter-doctor.txt

# 2. Gateway logs
cp ~/.openclaw/logs/gateway.log gateway-debug.log

# 3. App logs
adb logcat -d > app-debug.log

# 4. Network info
ip addr > network-info.txt
```

### Report an Issue

When reporting issues, include:
1. **Phone model** and Android version
2. **Gateway OS** (Linux/Windows/macOS)
3. **OpenClaw version**: `openclaw --version`
4. **Steps to reproduce**
5. **Debug logs** (see above)

---

## Quick Reference

### Common Commands

```bash
# ADB
adb devices
adb install app-release.apk
adb uninstall com.openclaw.mobile
adb logcat | grep openclaw

# Gateway
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw gateway status

# Network
ping <gateway-ip>
curl http://<gateway-ip>:18789/api/health
```

---

## Related Documentation

- [INSTALL-GUIDE.md](./INSTALL-GUIDE.md)
- [USER-GUIDE.md](./USER-GUIDE.md)
- [DEPLOYMENT.md](./DEPLOYMENT.md)
- [API-TESTING.md](./API-TESTING.md)