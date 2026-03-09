import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Auth Service - JWT token management for OpenClaw Mobile
/// 
/// Handles:
/// - JWT token storage and validation
/// - Token refresh management
/// - Authentication state
/// - Login/logout flows
class AuthService {
  static AuthService? _instance;

  final void Function(String level, String message, [dynamic data])? onLog;

  // Token storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';

  // Token data
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _userId;
  String? _userEmail;

  // Auth state
  AuthState _state = AuthState.unauthenticated;
  final StreamController<AuthState> _stateController =
      StreamController<AuthState>.broadcast();

  // User info
  OpenClawUser? _currentUser;
  final StreamController<OpenClawUser?> _userController =
      StreamController<OpenClawUser?>.broadcast();

  // Token refresh
  Timer? _refreshTimer;
  Timer? _expiryCheckTimer;
  static const Duration _refreshBuffer = Duration(minutes: 5);
  static const Duration _expiryCheckInterval = Duration(minutes: 1);

  // Callbacks for token operations
  Future<String> Function(String refreshToken)? onRefreshToken;
  Future<void> Function()? onLogout;
  Future<bool> Function(String email, String password)? onLogin;
  Future<bool> Function(String email, String password, String? name)? onRegister;

  factory AuthService() {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  AuthService._internal();

  // ==================== Getters ====================

  /// Current authentication state
  AuthState get state => _state;

  /// Stream of authentication state changes
  Stream<AuthState> get stateStream => _stateController.stream;

  /// Whether user is currently authenticated
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Current access token
  String? get accessToken => _accessToken;

  /// Current refresh token
  String? get refreshToken => _refreshToken;

  /// Token expiry time
  DateTime? get tokenExpiry => _tokenExpiry;

  /// Time until token expires
  Duration? get timeUntilExpiry {
    if (_tokenExpiry == null) return null;
    final remaining = _tokenExpiry!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether token needs refresh
  bool get needsRefresh {
    if (_tokenExpiry == null) return false;
    return DateTime.now().add(_refreshBuffer).isAfter(_tokenExpiry!);
  }

  /// Current user
  OpenClawUser? get currentUser => _currentUser;

  /// Stream of user changes
  Stream<OpenClawUser?> get userStream => _userController.stream;

  /// User ID
  String? get userId => _userId;

  /// User email
  String? get userEmail => _userEmail;

  // ==================== Token Management ====================

  /// Initialize auth service with stored tokens
  Future<void> initialize({
    required Future<String?> Function(String key) getStoredValue,
    required Future<void> Function(String key, String value) storeValue,
    required Future<void> Function(String key) deleteStoredValue,
  }) async {
    _log('info', 'Initializing auth service...');

    try {
      // Load stored tokens
      _accessToken = await getStoredValue(_accessTokenKey);
      _refreshToken = await getStoredValue(_refreshTokenKey);
      final expiryStr = await getStoredValue(_tokenExpiryKey);
      _userId = await getStoredValue(_userIdKey);
      _userEmail = await getStoredValue(_userEmailKey);

      if (expiryStr != null) {
        _tokenExpiry = DateTime.tryParse(expiryStr);
      }

      // Validate stored tokens
      if (_accessToken != null && _isTokenValid(_accessToken!)) {
        _updateState(AuthState.authenticated);
        _parseUserInfo(_accessToken!);
        _scheduleRefresh(getStoredValue, storeValue, deleteStoredValue);
        _log('info', 'Auth restored from stored tokens');
      } else if (_refreshToken != null) {
        // Try to refresh
        _updateState(AuthState.refreshing);
        try {
          await refreshTokens(
            getStoredValue: getStoredValue,
            storeValue: storeValue,
            deleteStoredValue: deleteStoredValue,
          );
        } catch (e) {
          _log('error', 'Failed to refresh stored token', e);
          await logout(
            getStoredValue: getStoredValue,
            deleteStoredValue: deleteStoredValue,
          );
        }
      } else {
        _updateState(AuthState.unauthenticated);
        _log('info', 'No valid stored tokens');
      }

      // Start expiry check
      _startExpiryCheck(getStoredValue, storeValue, deleteStoredValue);
    } catch (e) {
      _log('error', 'Failed to initialize auth service', e);
      _updateState(AuthState.unauthenticated);
    }
  }

  /// Set tokens from login/refresh response
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    required Future<void> Function(String key, String value) storeValue,
  }) async {
    _accessToken = accessToken;
    
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await storeValue(_refreshTokenKey, refreshToken);
    }

    await storeValue(_accessTokenKey, accessToken);

    // Parse token for expiry
    if (_isTokenValid(accessToken)) {
      final decoded = JwtDecoder.decode(accessToken);
      final exp = decoded['exp'] as int?;
      if (exp != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        await storeValue(_tokenExpiryKey, _tokenExpiry!.toIso8601String());
      }

      _parseUserInfo(accessToken);
    }

    _updateState(AuthState.authenticated);
    _log('info', 'Tokens set successfully');
  }

  /// Refresh access token using refresh token
  Future<void> refreshTokens({
    required Future<String?> Function(String key) getStoredValue,
    required Future<void> Function(String key, String value) storeValue,
    required Future<void> Function(String key) deleteStoredValue,
  }) async {
    if (_refreshToken == null) {
      throw AuthException('No refresh token available');
    }

    if (onRefreshToken == null) {
      throw AuthException('Refresh token callback not configured');
    }

    _updateState(AuthState.refreshing);
    _log('info', 'Refreshing tokens...');

    try {
      final newAccessToken = await onRefreshToken!(_refreshToken!);
      
      await setTokens(
        accessToken: newAccessToken,
        refreshToken: _refreshToken,
        storeValue: storeValue,
      );

      _scheduleRefresh(getStoredValue, storeValue, deleteStoredValue);
      _log('info', 'Tokens refreshed successfully');
    } catch (e) {
      _log('error', 'Failed to refresh tokens', e);
      await logout(
        getStoredValue: getStoredValue,
        deleteStoredValue: deleteStoredValue,
      );
      rethrow;
    }
  }

  /// Check if a JWT token is valid
  bool _isTokenValid(String token) {
    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      _log('error', 'Invalid token format', e);
      return false;
    }
  }

  /// Parse user info from token
  void _parseUserInfo(String token) {
    try {
      final decoded = JwtDecoder.decode(token);
      
      _userId = decoded['sub'] as String? ??
                 decoded['user_id'] as String? ??
                 decoded['id'] as String?;
      
      _userEmail = decoded['email'] as String? ??
                   decoded['user_email'] as String?;

      final name = decoded['name'] as String? ??
                   decoded['user_name'] as String?;

      if (_userId != null) {
        _currentUser = OpenClawUser(
          id: _userId!,
          email: _userEmail,
          name: name,
          metadata: Map<String, dynamic>.from(decoded),
        );
        _userController.add(_currentUser);
      }
    } catch (e) {
      _log('error', 'Failed to parse user info from token', e);
    }
  }

  /// Schedule automatic token refresh
  void _scheduleRefresh(
    Future<String?> Function(String key) getStoredValue,
    Future<void> Function(String key, String value) storeValue,
    Future<void> Function(String key) deleteStoredValue,
  ) {
    _refreshTimer?.cancel();

    if (_tokenExpiry == null) return;

    final refreshTime = _tokenExpiry!.subtract(_refreshBuffer);
    final timeUntilRefresh = refreshTime.difference(DateTime.now());

    if (timeUntilRefresh.isNegative) {
      // Already past refresh time, refresh now
      refreshTokens(
        getStoredValue: getStoredValue,
        storeValue: storeValue,
        deleteStoredValue: deleteStoredValue,
      );
      return;
    }

    _refreshTimer = Timer(timeUntilRefresh, () {
      refreshTokens(
        getStoredValue: getStoredValue,
        storeValue: storeValue,
        deleteStoredValue: deleteStoredValue,
      );
    });

    _log('debug', 'Token refresh scheduled in ${timeUntilRefresh.inMinutes} minutes');
  }

  /// Start periodic expiry check
  void _startExpiryCheck(
    Future<String?> Function(String key) getStoredValue,
    Future<void> Function(String key, String value) storeValue,
    Future<void> Function(String key) deleteStoredValue,
  ) {
    _expiryCheckTimer?.cancel();
    
    _expiryCheckTimer = Timer.periodic(_expiryCheckInterval, (_) {
      if (_accessToken != null && !_isTokenValid(_accessToken!)) {
        _log('warn', 'Access token expired');
        if (_refreshToken != null) {
          refreshTokens(
            getStoredValue: getStoredValue,
            storeValue: storeValue,
            deleteStoredValue: deleteStoredValue,
          );
        } else {
          logout(
            getStoredValue: getStoredValue,
            deleteStoredValue: deleteStoredValue,
          );
        }
      }
    });
  }

  // ==================== Authentication Flows ====================

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
    required Future<String?> Function(String key) getStoredValue,
    required Future<void> Function(String key, String value) storeValue,
    required Future<void> Function(String key) deleteStoredValue,
  }) async {
    _updateState(AuthState.authenticating);
    _log('info', 'Logging in as $email...');

    try {
      if (onLogin == null) {
        throw AuthException('Login callback not configured');
      }

      final success = await onLogin!(email, password);
      
      if (success) {
        _userEmail = email;
        await storeValue(_userEmailKey, email);
        _updateState(AuthState.authenticated);
        _log('info', 'Login successful');
        return true;
      } else {
        _updateState(AuthState.unauthenticated);
        _log('warn', 'Login failed');
        return false;
      }
    } catch (e) {
      _log('error', 'Login failed', e);
      _updateState(AuthState.error);
      rethrow;
    }
  }

  /// Register a new account
  Future<bool> register({
    required String email,
    required String password,
    String? name,
    required Future<String?> Function(String key) getStoredValue,
    required Future<void> Function(String key, String value) storeValue,
    required Future<void> Function(String key) deleteStoredValue,
  }) async {
    _updateState(AuthState.authenticating);
    _log('info', 'Registering $email...');

    try {
      if (onRegister == null) {
        throw AuthException('Register callback not configured');
      }

      final success = await onRegister!(email, password, name);
      
      if (success) {
        _userEmail = email;
        await storeValue(_userEmailKey, email);
        _updateState(AuthState.authenticated);
        _log('info', 'Registration successful');
        return true;
      } else {
        _updateState(AuthState.unauthenticated);
        _log('warn', 'Registration failed');
        return false;
      }
    } catch (e) {
      _log('error', 'Registration failed', e);
      _updateState(AuthState.error);
      rethrow;
    }
  }

  /// Logout and clear all auth data
  Future<void> logout({
    required Future<String?> Function(String key) getStoredValue,
    required Future<void> Function(String key) deleteStoredValue,
  }) async {
    _log('info', 'Logging out...');

    try {
      // Call logout callback
      if (onLogout != null) {
        await onLogout!();
      }
    } catch (e) {
      _log('error', 'Logout callback failed', e);
    }

    // Clear tokens
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _userId = null;
    _userEmail = null;
    _currentUser = null;

    // Cancel timers
    _refreshTimer?.cancel();
    _expiryCheckTimer?.cancel();

    // Delete stored values
    await deleteStoredValue(_accessTokenKey);
    await deleteStoredValue(_refreshTokenKey);
    await deleteStoredValue(_tokenExpiryKey);
    await deleteStoredValue(_userIdKey);
    await deleteStoredValue(_userEmailKey);

    _updateState(AuthState.unauthenticated);
    _userController.add(null);
    _log('info', 'Logged out successfully');
  }

  /// Clear all auth data without calling logout callback
  void clearAuth() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _userId = null;
    _userEmail = null;
    _currentUser = null;
    _refreshTimer?.cancel();
    _expiryCheckTimer?.cancel();
    _updateState(AuthState.unauthenticated);
    _userController.add(null);
  }

  // ==================== State Management ====================

  void _updateState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _log('debug', 'Auth state: $newState');
    }
  }

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[AuthService][$level] $message ${data ?? ''}');
    }
  }

  // ==================== Cleanup ====================

  void dispose() {
    _refreshTimer?.cancel();
    _expiryCheckTimer?.cancel();
    _stateController.close();
    _userController.close();
    _instance = null;
  }
}

// ==================== Models ====================

/// Authentication states
enum AuthState {
  unauthenticated,
  authenticating,
  authenticated,
  refreshing,
  error,
}

/// OpenClaw user information
class OpenClawUser {
  final String id;
  final String? email;
  final String? name;
  final Map<String, dynamic>? metadata;

  OpenClawUser({
    required this.id,
    this.email,
    this.name,
    this.metadata,
  });

  String get displayName => name ?? email ?? 'User';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'metadata': metadata,
    };
  }

  factory OpenClawUser.fromJson(Map<String, dynamic> json) {
    return OpenClawUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'OpenClawUser(id: $id, email: $email, name: $name)';
}

/// Authentication exception
class AuthException implements Exception {
  final String message;
  final int? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message${code != null ? ' ($code)' : ''}';
}