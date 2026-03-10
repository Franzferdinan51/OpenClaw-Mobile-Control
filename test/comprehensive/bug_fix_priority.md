# Bug Fix Priority List - DuckBot Android App

**Generated:** March 10, 2026  
**Total Issues:** 123  
**Critical:** 5 | **High:** 8 | **Medium:** 12 | **Low:** 8

---

## 🔴 CRITICAL - Fix Immediately

### FIX-001: Gateway Service Timeout Chain Improvement

**File:** `lib/services/gateway_service.dart`  
**Lines:** 72-119  
**Estimated Time:** 2 hours

**Current Problem:**
```dart
// All errors are silently caught, user gets generic message
} catch (e) {
  print('❌ Error getting status from /health: $e');
}
return null;
```

**Proposed Fix:**
```dart
Future<GatewayStatus?> getStatus({Duration? timeout}) async {
  final errors = <String, String>{};
  
  for (final endpoint in ['/api/gateway', '/api/status', '/health']) {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      ).timeout(timeout ?? _shortTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GatewayStatus.fromJson(json);
      }
      errors[endpoint] = 'HTTP ${response.statusCode}';
    } on TimeoutException {
      errors[endpoint] = 'Timeout after ${timeout?.inSeconds ?? 5}s';
    } on SocketException catch (e) {
      errors[endpoint] = 'Connection: ${e.message}';
    } catch (e) {
      errors[endpoint] = e.toString();
    }
  }
  
  // Log all errors for debugging
  _lastErrors = errors;
  debugPrint('All endpoints failed: $errors');
  
  return null;
}

Map<String, String>? _lastErrors;
Map<String, String>? get lastErrors => _lastErrors;
```

---

### FIX-002: Discovery Service Memory Optimization

**File:** `lib/services/discovery_service.dart`  
**Lines:** 390-430  
**Estimated Time:** 3 hours

**Current Problem:**
```dart
// Creates 16000+ IPs in memory
for (int i = 64; i <= 127; i++) {
  for (int j = 0; j <= 255; j += 8) {
    for (int k = 1; k <= 254; k += 32) {
      ipsToScan.add('100.$i.$j.$k');
    }
  }
}
```

**Proposed Fix:**
```dart
/// Scan Tailscale network with streaming approach
Future<List<GatewayConnection>> _scanTailscale() async {
  final List<GatewayConnection> found = [];
  
  _log('info', 'Scanning Tailscale network...');
  
  // Use generator instead of building full list
  int totalScanned = 0;
  
  // Process in batches of 100 IPs
  for (int i = 64; i <= 127 && !_isDisposed; i++) {
    for (int j = 0; j <= 255; j += 8) {
      // Create batch of ~100 IPs
      final batch = <String>[];
      for (int k = 1; k <= 254; k += 32) {
        batch.add('100.$i.$j.$k');
      }
      
      // Check memory pressure before continuing
      if (await _isMemoryPressure()) {
        _log('warning', 'Memory pressure detected, pausing scan');
        await Future.delayed(const Duration(seconds: 1));
      }
      
      // Scan batch
      final results = await _scanIPsInParallel(batch, port: 18789);
      totalScanned += batch.length;
      
      for (final result in results) {
        if (result.found && result.url != null) {
          found.add(GatewayConnection(
            name: result.name ?? 'OpenClaw Tailscale (${result.ip})',
            url: result.url!,
            ip: result.ip,
            port: 18789,
            isOnline: true,
          ));
        }
      }
      
      // Update progress
      _updateProgress(totalScanned, totalScanned, 'Scanning Tailscale...');
    }
  }
  
  return found;
}

Future<bool> _isMemoryPressure() async {
  // Could integrate with device_info_plus for real memory stats
  return false; // Placeholder
}
```

---

### FIX-003: Termux Process Cleanup

**File:** `lib/services/termux_service.dart`  
**Lines:** 140-148  
**Estimated Time:** 1 hour

**Current Problem:**
```dart
try {
  exitCode = await process.exitCode.timeout(timeout);
} catch (e) {
  process.kill(ProcessSignal.sigkill);
  exitCode = -1;
}
```

**Proposed Fix:**
```dart
Future<CommandResult> _runInTermux(
  String command, {
  List<String>? args,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final startTime = DateTime.now();
  Process? process;
  StreamSubscription? stdoutSub;
  StreamSubscription? stderrSub;

  try {
    final fullCommand = args != null && args.isNotEmpty
        ? '$command ${args.join(' ')}'
        : command;

    _log('Termux: $fullCommand');

    final shellPath = '$_termuxPrefixPath/bin/sh';
    final processArgs = ['-c', fullCommand];

    final environment = {
      'PATH': '$_termuxPrefixPath/bin:$_termuxPrefixPath/bin/applets:\$PATH',
      'HOME': _termuxHomePath ?? '/data/data/com.termux/files/home',
      'PREFIX': _termuxPrefixPath ?? '/data/data/com.termux/files/usr',
      'TERMUX_VERSION': '1',
      'LD_LIBRARY_PATH': '$_termuxPrefixPath/lib',
    };

    process = await Process.start(
      shellPath,
      processArgs,
      environment: environment,
      runInShell: false,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    // Collect stdout
    stdoutSub = process.stdout.transform(const SystemEncoding().decoder).listen((data) {
      stdoutBuffer.write(data);
      onOutput?.call(data);
    });

    // Collect stderr
    stderrSub = process.stderr.transform(const SystemEncoding().decoder).listen((data) {
      stderrBuffer.write(data);
      onOutput?.call(data);
    });

    // Wait for process with timeout
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } catch (e) {
      // CLEANUP: Cancel subscriptions BEFORE killing
      await stdoutSub.cancel();
      await stderrSub.cancel();
      process.kill(ProcessSignal.sigkill);
      exitCode = -1;
      _log('Command timed out after ${timeout.inSeconds}s');
    }

    final duration = DateTime.now().difference(startTime);

    return CommandResult(
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      duration: duration,
      success: exitCode == 0,
    );
  } catch (e) {
    // CLEANUP: Ensure cleanup on any error
    await stdoutSub?.cancel();
    await stderrSub?.cancel();
    process?.kill(ProcessSignal.sigkill);
    
    final duration = DateTime.now().difference(startTime);
    _log('Command execution failed: $e');

    return CommandResult(
      exitCode: -1,
      stdout: '',
      stderr: e.toString(),
      duration: duration,
      success: false,
    );
  }
}
```

---

### FIX-004: Connection Monitor Race Condition

**File:** `lib/services/connection_monitor_service.dart`  
**Lines:** 177-201  
**Estimated Time:** 2 hours

**Current Problem:**
```dart
void reconnect() {
  _retryTimer?.cancel();
  _countdownTimer?.cancel();
  // What if _doPing() is already in progress?
  _doPing();
}
```

**Proposed Fix:**
```dart
class ConnectionMonitorService extends ChangeNotifier {
  // Add flag to prevent overlapping pings
  bool _isPinging = false;
  
  void _doPing() async {
    // Prevent overlapping ping operations
    if (_isPinging || _gatewayService == null || !_isMonitoring) return;
    
    _isPinging = true;
    final stopwatch = Stopwatch()..start();
    
    try {
      final status = await _gatewayService!.getStatus();
      stopwatch.stop();
      
      if (status != null && status.online) {
        _retryAttempts = 0;
        _retryCountdown = 0;
        _retryTimer?.cancel();
        _countdownTimer?.cancel();
        
        _state = _state.copyWith(
          status: ConnectionStatus.connected,
          gatewayInfo: status,
          lastPing: DateTime.now(),
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: null,
        );
      } else {
        _handleConnectionLost('Gateway offline');
      }
    } catch (e) {
      stopwatch.stop();
      _handleConnectionLost(e.toString());
    } finally {
      _isPinging = false;
      notifyListeners();
    }
  }
  
  void reconnect() {
    // Wait for any in-progress ping to complete
    if (_isPinging) {
      _log('Ping already in progress, reconnect queued');
      return;
    }
    
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _retryAttempts = 0;
    _retryCountdown = 0;
    
    _state = _state.copyWith(
      status: ConnectionStatus.connecting,
      errorMessage: null,
    );
    notifyListeners();
    
    _doPing();
  }
}
```

---

### FIX-005: Hold Timer Disposal

**File:** `lib/screens/control_screen.dart`  
**Lines:** Variable (dispose method)  
**Estimated Time:** 30 minutes

**Current Problem:**
Hold timer not cancelled in dispose.

**Proposed Fix:**
```dart
@override
void dispose() {
  _holdTimer?.cancel();  // Add this line
  super.dispose();
}
```

---

## 🟠 HIGH - Fix Soon

### FIX-006: Chat Real AI Integration

**File:** `lib/screens/chat_screen.dart`  
**Estimated Time:** 4 hours

**Current Problem:**
Mock responses instead of real AI.

**Proposed Approach:**
```dart
Future<void> _sendToGateway(String message) async {
  if (_gatewayService == null || !_gatewayService!.isConnected) {
    // Fallback to mock response
    _generateResponse(message);
    return;
  }
  
  try {
    setState(() {
      _isTyping = true;
    });
    
    final response = await _gatewayService!.sendAgentMessage(
      _activeAgent?.id ?? 'default',
      message,
    );
    
    if (mounted && response != null) {
      setState(() {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response.content,
          isUser: false,
          timestamp: DateTime.now(),
          agent: _activeAgent,
        ));
        _isTyping = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
      _addSystemMessage('Error: Could not reach gateway. $e');
    }
  }
}
```

---

### FIX-007: Logs Screen Real Data

**File:** `lib/screens/logs_screen.dart`  
**Estimated Time:** 2 hours

**Current Problem:**
Hardcoded sample logs.

**Proposed Fix:**
```dart
@override
void initState() {
  super.initState();
  _loadLogs();
}

Future<void> _loadLogs() async {
  if (widget.gatewayService == null) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final logs = await widget.gatewayService!.getLogs(
      limit: 100,
      level: _selectedLevel,
    );
    
    if (mounted) {
      setState(() {
        _logs = logs.map((log) => LogEntry.fromJson(log)).toList();
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }
}
```

---

### FIX-008: Chat History Persistence

**File:** New file `lib/services/chat_history_service.dart`  
**Estimated Time:** 3 hours

**Proposed Implementation:**
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatHistoryService {
  static const _messagesKey = 'chat_messages';
  static const _maxMessages = 100;
  
  Future<List<Message>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_messagesKey);
    
    if (json == null) return [];
    
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((m) => Message.fromJson(m)).toList();
  }
  
  Future<void> saveMessage(Message message) async {
    final history = await loadHistory();
    history.add(message);
    
    // Keep only last N messages
    while (history.length > _maxMessages) {
      history.removeAt(0);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _messagesKey,
      jsonEncode(history.map((m) => m.toJson()).toList()),
    );
  }
  
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }
}
```

---

### FIX-009: URL Validation Enhancement

**File:** `lib/services/gateway_service.dart`  
**Lines:** 38-59  
**Estimated Time:** 1 hour

**Proposed Fix:**
```dart
static String? validateUrl(String url) {
  if (url.isEmpty) return null;
  
  String normalized = url.trim();
  
  // Add protocol if missing
  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
    normalized = 'http://$normalized';
  }
  
  // Remove trailing slash
  normalized = normalized.replaceAll(RegExp(r'/$'), '');
  
  // Parse and validate
  try {
    final uri = Uri.parse(normalized);
    
    // Host validation
    if (uri.host.isEmpty) {
      return null;
    }
    
    // Check for valid IP or hostname
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final isIp = ipRegex.hasMatch(uri.host);
    final isHostname = uri.host.contains('.') && !uri.host.startsWith('.');
    
    if (!isIp && !isHostname && uri.host != 'localhost') {
      return null;
    }
    
    // Validate IP octets if IP
    if (isIp) {
      final octets = uri.host.split('.');
      for (final octet in octets) {
        final value = int.tryParse(octet);
        if (value == null || value < 0 || value > 255) {
          return null;
        }
      }
    }
    
    // Port validation (if specified)
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return null;
    }
    
    return normalized;
  } catch (e) {
    return null;
  }
}
```

---

### FIX-010: Memory Percent Safe Calculation

**File:** `lib/screens/dashboard_screen.dart`  
**Estimated Time:** 15 minutes

**Proposed Fix:**
```dart
Widget _buildSystemHealthCard() {
  final cpuPercent = _status?.cpuPercent ?? 0.0;
  
  // Safe calculation with null checks
  final memoryTotal = _status?.memoryTotal;
  final memoryUsed = _status?.memoryUsed;
  final memoryPercent = (memoryTotal != null && memoryTotal > 0 && memoryUsed != null)
      ? (memoryUsed.toDouble() / memoryTotal.toDouble() * 100.0)
      : 0.0;
  
  return Card(
    // ...
  );
}
```

---

### FIX-011: Network Connectivity Detection

**File:** Add to `pubspec.yaml` and create new service  
**Estimated Time:** 2 hours

**Proposed Implementation:**
```yaml
# pubspec.yaml
dependencies:
  connectivity_plus: ^5.0.0
```

```dart
// lib/services/network_state_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkStateService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  bool get isConnected => !_connectionStatus.contains(ConnectivityResult.none);
  bool get isWifi => _connectionStatus.contains(ConnectivityResult.wifi);
  bool get isMobile => _connectionStatus.contains(ConnectivityResult.mobile);
  
  Future<void> initialize() async {
    _connectionStatus = await _connectivity.checkConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    _connectionStatus = result;
    notifyListeners();
  }
}

final networkState = NetworkStateService();
```

---

### FIX-012: Message Send Debounce

**File:** `lib/screens/chat_screen.dart`  
**Estimated Time:** 30 minutes

**Proposed Fix:**
```dart
class _ChatScreenState extends State<ChatScreen> {
  bool _isSending = false;
  
  void _sendMessage() async {
    if (_isSending) return; // Prevent double-sends
    
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _isSending = false; // Re-enable after adding
    });

    _scrollToBottom();
    _generateResponse(text);
  }
  
  // In build():
  IconButton(
    icon: const Icon(Icons.send),
    onPressed: _isSending ? null : _sendMessage,
    tooltip: 'Send',
  ),
}
```

---

### FIX-013: Termux Singleton Fix

**File:** `lib/services/termux_service.dart`  
**Estimated Time:** 1 hour

**Proposed Fix:**
```dart
/// Use proper singleton pattern - no dispose on singleton
class TermuxService {
  static final TermuxService _instance = TermuxService._internal();
  
  factory TermuxService() => _instance;
  
  TermuxService._internal();
  
  // Remove dispose() that breaks singleton
  // Or: Change to non-singleton with proper state management
  
  void reset() {
    _isInitialized = false;
    _isTermuxAvailable = false;
    _isProotAvailable = false;
    _isUbuntuInstalled = false;
    _isOpenClawInstalled = false;
    // Don't set _instance = null
  }
}
```

---

## Summary

| Priority | Count | Estimated Time |
|----------|-------|----------------|
| Critical | 5 | 8.5 hours |
| High | 8 | 15 hours |
| **Total** | **13** | **23.5 hours** |

**Recommended Fix Order:**
1. FIX-005 (Hold Timer) - 30 min
2. FIX-010 (Memory Percent) - 15 min
3. FIX-012 (Message Debounce) - 30 min
4. FIX-004 (Connection Monitor) - 2 hours
5. FIX-001 (Gateway Timeout) - 2 hours
6. FIX-003 (Termux Cleanup) - 1 hour
7. FIX-002 (Discovery Memory) - 3 hours
8. FIX-009 (URL Validation) - 1 hour
9. FIX-011 (Network Detection) - 2 hours
10. FIX-013 (Termux Singleton) - 1 hour
11. FIX-007 (Logs Real Data) - 2 hours
12. FIX-008 (Chat History) - 3 hours
13. FIX-006 (Chat AI) - 4 hours

---

*Generated by DuckBot Sub-Agent*