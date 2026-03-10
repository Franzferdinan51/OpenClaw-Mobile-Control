import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';
import 'gateway_service.dart';

/// Connection status enumeration
enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

/// Connection state with detailed information
class AppConnectionState {
  final ConnectionStatus status;
  final GatewayStatus? gatewayInfo;
  final String? errorMessage;
  final DateTime? lastPing;
  final int latencyMs;
  final int retryCountdown;
  final String? gatewayUrl;
  final String? gatewayName;

  const AppConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.gatewayInfo,
    this.errorMessage,
    this.lastPing,
    this.latencyMs = 0,
    this.retryCountdown = 0,
    this.gatewayUrl,
    this.gatewayName,
  });

  AppConnectionState copyWith({
    ConnectionStatus? status,
    GatewayStatus? gatewayInfo,
    String? errorMessage,
    DateTime? lastPing,
    int? latencyMs,
    int? retryCountdown,
    String? gatewayUrl,
    String? gatewayName,
  }) {
    return AppConnectionState(
      status: status ?? this.status,
      gatewayInfo: gatewayInfo ?? this.gatewayInfo,
      errorMessage: errorMessage ?? this.errorMessage,
      lastPing: lastPing ?? this.lastPing,
      latencyMs: latencyMs ?? this.latencyMs,
      retryCountdown: retryCountdown ?? this.retryCountdown,
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      gatewayName: gatewayName ?? this.gatewayName,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isDisconnected => status == ConnectionStatus.disconnected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => status == ConnectionStatus.error;

  String get statusText {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.error:
        return 'Error';
    }
  }
}

/// Service that monitors gateway connection status in real-time
class ConnectionMonitorService extends ChangeNotifier {
  static const Duration _pingInterval = Duration(seconds: 5);
  static const Duration _retryInterval = Duration(seconds: 10);
  static const int _maxRetryAttempts = 3;

  GatewayService? _gatewayService;
  Timer? _pingTimer;
  Timer? _retryTimer;
  Timer? _countdownTimer;
  
  AppConnectionState _state = const AppConnectionState();
  bool _isMonitoring = false;
  int _retryAttempts = 0;
  int _retryCountdown = 0;

  /// Current connection state
  AppConnectionState get state => _state;
  
  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Start monitoring the gateway connection
  void startMonitoring(GatewayService gatewayService, {String? gatewayName}) {
    _gatewayService = gatewayService;
    _isMonitoring = true;
    
    _state = _state.copyWith(
      gatewayUrl: gatewayService.baseUrl,
      gatewayName: gatewayName,
      status: ConnectionStatus.connecting,
    );
    notifyListeners();
    
    // Initial ping
    _doPing();
    
    // Start periodic ping
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _doPing());
  }

  /// Stop monitoring
  void stopMonitoring() {
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _isMonitoring = false;
    _pingTimer = null;
    _retryTimer = null;
    _countdownTimer = null;
    
    _state = _state.copyWith(
      status: ConnectionStatus.disconnected,
    );
    notifyListeners();
  }

  /// Manual test connection
  Future<bool> testConnection() async {
    if (_gatewayService == null) return false;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final status = await _gatewayService!.getStatus();
      stopwatch.stop();
      
      if (status != null && status.online) {
        _state = _state.copyWith(
          status: ConnectionStatus.connected,
          gatewayInfo: status,
          lastPing: DateTime.now(),
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: null,
        );
        notifyListeners();
        return true;
      } else {
        _state = _state.copyWith(
          status: ConnectionStatus.disconnected,
          errorMessage: 'Gateway offline',
          lastPing: DateTime.now(),
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      stopwatch.stop();
      _state = _state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
        lastPing: DateTime.now(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Force reconnect attempt
  void reconnect() {
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

  /// Disconnect from gateway
  void disconnect() {
    stopMonitoring();
    _state = const AppConnectionState();
    notifyListeners();
  }

  /// Connect to a new gateway URL
  Future<bool> connect(String url, {String? token}) async {
    try {
      _state = _state.copyWith(
        status: ConnectionStatus.connecting,
        gatewayUrl: url,
        errorMessage: null,
      );
      notifyListeners();

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gateway_url', url);
      if (token != null) {
        await prefs.setString('gateway_token', token);
      }

      // Create new gateway service
      _gatewayService = GatewayService(baseUrl: url, token: token);
      _isMonitoring = true;

      // Test connection
      final success = await testConnection();

      if (success) {
        // Start monitoring
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(_pingInterval, (_) => _doPing());
      }

      return success;
    } catch (e) {
      _state = _state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  void _doPing() async {
    if (_gatewayService == null || !_isMonitoring) return;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final status = await _gatewayService!.getStatus();
      stopwatch.stop();
      
      if (status != null && status.online) {
        // Connection successful
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
        // Gateway returned but is offline
        _handleConnectionLost('Gateway offline');
      }
    } catch (e) {
      stopwatch.stop();
      _handleConnectionLost(e.toString());
    }
    
    notifyListeners();
  }

  void _handleConnectionLost(String error) {
    _state = _state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: error,
      lastPing: DateTime.now(),
    );
    notifyListeners();
    
    // Start auto-retry if not already retrying
    if (_retryTimer == null || !_retryTimer!.isActive) {
      _startAutoRetry();
    }
  }

  void _startAutoRetry() {
    _retryAttempts = 0;
    _retryCountdown = _retryInterval.inSeconds;
    
    _startCountdown();
    
    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      _retryAttempts++;
      
      if (_retryAttempts >= _maxRetryAttempts) {
        timer.cancel();
        _state = _state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Connection lost. Max retries exceeded.',
          retryCountdown: 0,
        );
        notifyListeners();
        return;
      }
      
      _retryCountdown = _retryInterval.inSeconds;
      _startCountdown();
      
      _doPing();
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _retryCountdown = _retryInterval.inSeconds;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _retryCountdown--;
      
      _state = _state.copyWith(
        retryCountdown: _retryCountdown,
      );
      notifyListeners();
      
      if (_retryCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Global connection monitor instance
final connectionMonitor = ConnectionMonitorService();