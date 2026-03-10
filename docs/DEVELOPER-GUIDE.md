# OpenClaw Mobile - Developer Guide

**Version:** 2.0.0  
**Last Updated:** March 9, 2026

---

## Table of Contents

1. [Architecture](#architecture)
2. [Project Structure](#project-structure)
3. [Code Style](#code-style)
4. [Dependencies](#dependencies)
5. [Building](#building)
6. [Testing](#testing)
7. [Adding Screens](#adding-screens)
8. [Services](#services)
9. [Models](#models)
10. [API Integration](#api-integration)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw Mobile App                       │
│                         Flutter                              │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Screens)                                         │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────────┐ │
│  │Dashboard │  Chat   │  Quick   │ Control  │   Settings   │ │
│  │          │          │ Actions  │          │              │ │
│  └──────────┴──────────┴──────────┴──────────┴──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                               │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────────┐ │
│  │ Gateway  │  Voice   │  Termux  │   MCP    │   Settings   │ │
│  │ Service  │ Service  │ Service  │ Service  │   Service    │ │
│  └──────────┴──────────┴──────────┴──────────┴──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Network Layer                                               │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────────┐ │
│  │   mDNS   │   HTTP   │WebSocket │Tailscale │     BLE      │ │
│  └──────────┴──────────┴──────────┴──────────┴──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                  │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────────┐ │
│  │  Models  │   DTOs   │   Enums  │ Constants │     Utils    │ │
│  └──────────┴──────────┴──────────┴──────────┴──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw Gateway                           │
│                 (ws://localhost:18789)                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Provider Pattern** - State management using Provider
2. **Service Layer** - API calls isolated in services
3. **Model-Driven** - Strong typing with Dart models
4. **Reactive UI** - Using StreamBuilder and FutureBuilder

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # MaterialApp configuration
├── models/                   # Data models
│   ├── agent_personality.dart
│   ├── agent_session.dart
│   ├── app_settings.dart
│   ├── autowork_config.dart
│   └── gateway_status.dart
├── screens/                  # UI screens (22 screens)
│   ├── dashboard_screen.dart
│   ├── chat_screen.dart
│   ├── quick_actions_screen.dart
│   ├── control_screen.dart
│   ├── logs_screen.dart
│   ├── settings_screen.dart
│   └── ...
├── services/                 # Business logic
│   ├── gateway_service.dart
│   ├── voice_service.dart
│   ├── termux_service.dart
│   ├── mcp_service.dart
│   └── app_settings_service.dart
├── widgets/                  # Reusable widgets
│   └── ...
└── utils/                    # Utilities
    ├── constants.dart
    └── helpers.dart
```

---

## Code Style

### Follow Dart Style Guide

- Use `camelCase` for variables and functions
- Use `PascalCase` for classes and types
- Use `SCREAMING_SNAKE_CASE` for constants

### Formatting

```dart
// Good
void myFunction() {
  final result = doSomething();
  return result;
}

// Bad
void myFunction(){
  final result = doSomething();
  return result;
}
```

### Naming

```dart
// Classes
class GatewayService { ... }
class ChatMessage { ... }

// Variables
final gatewayUrl = 'http://localhost:18789';
var isConnected = false;

// Constants
const int defaultPort = 18789;
const String gatewayToken = 'my-token';
```

### Imports

```dart
// Standard
import 'dart:async';

// External packages
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Local
import '../models/gateway_status.dart';
import '../services/gateway_service.dart';
```

---

## Dependencies

### Core Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  http: ^1.1.0
  web_socket_channel: ^2.4.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
  path_provider: ^2.1.2
  uuid: ^4.2.2
  intl: ^0.19.0

  # Automation
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  webkit_inspection_protocol: ^1.2.1
  cron: ^0.6.1
  multicast_dns: ^0.3.2+4

  # Voice
  speech_to_text: ^7.0.0
  flutter_tts: ^4.0.0
```

### Adding Dependencies

```bash
# Add dependency
flutter pub add package_name

# Get all dependencies
flutter pub get
```

---

## Building

### Development Build

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build debug APK
flutter build apk --debug
```

### Release Build

```bash
# Build release APK
flutter build apk --release

# Output location
# build/app/outputs/flutter-apk/app-release.apk
```

### Build Options

```bash
# Specific target
flutter build apk --target-platform android-arm64

# Split APKs (smaller)
flutter build apk --split-per-abi
```

---

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GatewayService connects correctly', () async {
    final service = GatewayService();
    await service.connect('http://localhost:18789', 'token');
    expect(service.isConnected, true);
  });
}
```

### Widget Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_mobile/screens/dashboard_screen.dart';

void main() {
  testWidgets('Dashboard shows status', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(),
    ));

    expect(find.text('Gateway Status'), findsOneWidget);
  });
}
```

### Running Tests

```bash
# All tests
flutter test

# Specific file
flutter test test/dashboard_test.dart

# With coverage
flutter test --coverage
```

---

## Adding Screens

### 1. Create the Screen

```dart
// lib/screens/my_new_screen.dart

import 'package:flutter/material.dart';

class MyNewScreen extends StatefulWidget {
  const MyNewScreen({Key? key}) : super(key: key);

  @override
  State<MyNewScreen> createState() => _MyNewScreenState();
}

class _MyNewScreenState extends State<MyNewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My New Screen'),
      ),
      body: const Center(
        child: Text('Hello, World!'),
      ),
    );
  }
}
```

### 2. Add to Navigation

In `lib/app.dart`, add to `_buildScreens()`:

```dart
// Add import
import 'screens/my_new_screen.dart';

// Add to list
const List<Widget> _screens = [
  DashboardScreen(),
  ChatScreen(),
  // ... other screens
  MyNewScreen(),  // Add here
];
```

### 3. Add Navigation Item

In `_buildNavDestinations()`:

```dart
const List<NavigationDestination> _destinations = [
  // ... other destinations
  const NavigationDestination(
    icon: Icon(Icons.new_releases),
    label: 'New',
  ),
];
```

---

## Services

### GatewayService

Main service for communicating with OpenClaw gateway.

```dart
class GatewayService {
  // Connect to gateway
  Future<bool> connect(String url, String token);

  // Get status
  Future<GatewayStatus> getStatus();

  // Get agents
  Future<List<AgentSession>> getAgents();

  // Send message
  Future<void> sendMessage(String message);

  // Restart gateway
  Future<void> restart();

  // Kill agent
  Future<void> killAgent(String agentId);
}
```

### VoiceService

Speech-to-text and TTS.

```dart
class VoiceService {
  // Start listening
  Future<void> startListening(Function(String) onResult);

  // Stop listening
  Future<void> stopListening();

  // Speak text
  Future<void> speak(String text);

  // Check availability
  Future<bool> isAvailable();
}
```

### AppSettingsService

Manages app settings with persistence.

```dart
class AppSettingsService extends ChangeNotifier {
  // Initialize (call once at startup)
  static Future<void> initialize();

  // Getters
  String get appMode;
  bool get notificationsEnabled;
  String get theme;

  // Setters
  Future<void> setAppMode(String mode);
  Future<void> setNotifications(bool enabled);
  Future<void> setTheme(String theme);
}
```

---

## Models

### GatewayStatus

```dart
class GatewayStatus {
  final bool isOnline;
  final String version;
  final int agentCount;
  final int nodeCount;
  final double cpuUsage;
  final double memoryUsage;
  final DateTime uptime;
}
```

### AgentSession

```dart
class AgentSession {
  final String id;
  final String name;
  final String status;
  final DateTime startedAt;
  final String? currentTask;
}
```

### ChatMessage

```dart
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? agentName;
}
```

### AppSettings

```dart
class AppSettings {
  final String appMode;         // basic, powerUser, developer
  final bool notifications;
  final bool hapticFeedback;
  final String theme;           // system, light, dark
  final int autoRefreshInterval;
  final bool debugLogging;
}
```

---

## API Integration

### REST API Calls

```dart
class GatewayService {
  final http.Client _client = http.Client();

  Future<GatewayStatus> getStatus() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return GatewayStatus.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get status: ${response.statusCode}');
    }
  }
}
```

### WebSocket Communication

```dart
class GatewayService {
  WebSocket? _socket;

  Future<void> connect() async {
    _socket = await WebSocket.connect(
      'ws://$host:$port/ws',
    );

    _socket!.listen((message) {
      // Handle incoming message
    });
  }

  void sendMessage(String data) {
    _socket?.add(data);
  }
}
```

---

## Best Practices

1. **Always dispose resources** - Use `dispose()` in StatefulWidgets
2. **Handle errors gracefully** - Try-catch with user-friendly messages
3. **Use const constructors** - Where possible for performance
4. **Avoid magic numbers** - Use constants
5. **Comment complex logic** - But don't over-comment
6. **Test thoroughly** - Unit tests for services, widget tests for UI
7. **Follow naming conventions** - Consistency is key

---

## Debug Tools

### Developer Mode Features

- **API Explorer** - Test gateway endpoints
- **Debug Console** - Run diagnostic commands
- **Raw Logs** - Unfiltered log viewer
- **Network Inspector** - Monitor API calls

### Enabling Debug Mode

1. Go to Settings → App tab
2. Select "Developer" mode
3. Access Dev Tools from Tools hub

---

## Support

- **GitHub Issues:** https://github.com/Franzferdinan51/OpenClaw-Mobile-Control/issues
- **Discord:** https://discord.gg/clawd

---

**Happy Coding! 🦆**