# OpenClaw Mobile App - Quick Start Guide

**🚀 Get Started in 5 Minutes**

---

## Prerequisites

### **1. Install Flutter**
```bash
# macOS
brew install --cask flutter

# Verify installation
flutter doctor
```

**Required:**
- Flutter SDK 3.0+
- Dart 3.0+
- Xcode (for iOS)
- Android Studio (for Android)

---

### **2. OpenClaw Gateway Requirements**

**Minimum Version:** OpenClaw 1.2.0+

**Gateway Extensions Needed:**
- Mobile API endpoints (see `GATEWAY-API.md`)
- WebSocket support
- mDNS discovery
- JWT authentication

---

## 📱 Project Setup

### **Step 1: Clone/Create Project**
```bash
cd /Users/duckets/.openclaw/workspace/mobile-app

# Initialize Flutter project (if not already done)
flutter create --org ai.openclaw --project-name openclaw_mobile .

# Install dependencies
flutter pub get
```

---

### **Step 2: Configure Firebase (for Push Notifications)**

**Optional but recommended for push notifications.**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: "OpenClaw Mobile"
3. Add iOS app:
   - Bundle ID: `ai.openclaw.mobile`
   - Download `GoogleService-Info.plist`
   - Place in `ios/Runner/GoogleService-Info.plist`
4. Add Android app:
   - Package name: `ai.openclaw.mobile`
   - Download `google-services.json`
   - Place in `android/app/google-services.json`

---

### **Step 3: Run Development Build**

```bash
# Run on connected device or emulator
flutter run

# Run on specific device
flutter devices  # List devices
flutter run -d <device-id>

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android
```

---

## 🛠️ Development Workflow

### **Hot Reload**
```bash
# While app is running, press 'r' to hot reload
# Press 'R' to hot restart
# Press 'q' to quit
```

### **Debug Mode**
```bash
# Enable verbose logging
flutter run --verbose

# Debug specific widget
flutter run --debug
```

### **Build for Production**

**iOS:**
```bash
flutter build ios --release
```

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**Web (PWA):**
```bash
flutter build web --release
```

---

## 🧪 Testing

### **Run All Tests**
```bash
flutter test
```

### **Run Specific Test**
```bash
flutter test test/widget_test.dart
```

### **Coverage**
```bash
flutter test --coverage
```

---

## 📦 Project Structure

```
mobile-app/
├── lib/
│   ├── main.dart              # App entry point
│   ├── app.dart               # App configuration
│   ├── config/                # Routes, themes, constants
│   ├── models/                # Data models
│   ├── services/              # API, WebSocket, storage
│   ├── providers/             # Riverpod state management
│   ├── screens/               # UI screens
│   └── widgets/               # Reusable widgets
├── test/                      # Tests
├── assets/                    # Images, fonts, animations
├── pubspec.yaml              # Dependencies
└── README.md                 # This file
```

---

## 🔧 Common Tasks

### **Add New Dependency**
```bash
flutter pub add <package-name>
```

### **Generate Code (Hive, Riverpod)**
```bash
dart run build_runner build --delete-conflicting-outputs
```

### **Update Dependencies**
```bash
flutter pub upgrade
```

### **Clean Build**
```bash
flutter clean
flutter pub get
```

---

## 🐛 Troubleshooting

### **Flutter Doctor Issues**
```bash
flutter doctor -v  # Detailed diagnostics
```

### **iOS Build Fails**
```bash
cd ios
pod install
pod repo update
cd ..
```

### **Android Build Fails**
```bash
cd android
./gradlew clean
cd ..
```

### **Package Conflicts**
```bash
flutter pub deps
flutter pub upgrade --major-versions
```

---

## 📚 Next Steps

1. **Read `README.md`** - Full feature specification
2. **Read `GATEWAY-API.md`** - API documentation
3. **Implement Gateway Extensions** - Add mobile endpoints
4. **Build MVP Screens** - Dashboard, Chat, Control
5. **Test Locally** - Connect to your gateway
6. **Deploy** - App Store + Play Store

---

## 🤝 Contributing

### **Branch Naming**
```
feature/dashboard
bugfix/websocket-reconnect
docs/api-update
```

### **Commit Messages**
```
feat: Add dashboard screen
fix: WebSocket reconnection logic
docs: Update API documentation
```

---

## 📞 Support

- **Documentation:** `/Users/duckets/.openclaw/workspace/mobile-app/README.md`
- **API Spec:** `/Users/duckets/.openclaw/workspace/mobile-app/GATEWAY-API.md`
- **OpenClaw Docs:** https://docs.openclaw.ai
- **Discord:** https://discord.com/invite/clawd

---

## 🎯 MVP Checklist

**Phase 1 (Week 1-2):**
- [ ] Flutter project initialized
- [ ] Gateway API extensions implemented
- [ ] Basic dashboard (static data)
- [ ] WebSocket connection working
- [ ] Discovery service (mDNS)

**Phase 2 (Week 3-4):**
- [ ] Live dashboard (real-time updates)
- [ ] Chat interface (direct to gateway)
- [ ] Remote control panel
- [ ] Quick actions (built-in)
- [ ] Settings screen

**Phase 3 (Week 5-6):**
- [ ] Log viewer (live stream)
- [ ] Guided setup wizard
- [ ] Auto-discovery UI
- [ ] Push notifications
- [ ] Voice commands

**Phase 4 (Week 7-8):**
- [ ] Custom quick actions
- [ ] Theme support
- [ ] Offline mode
- [ ] Performance optimization
- [ ] Testing complete

**Phase 5 (Week 9):**
- [ ] Beta testing
- [ ] Bug fixes
- [ ] App Store submission
- [ ] Play Store submission
- [ ] Web deployment

---

**Let's build! 🦆**

```bash
cd /Users/duckets/.openclaw/workspace/mobile-app
flutter create --org ai.openclaw --project-name openclaw_mobile .
flutter pub get
flutter run
```
