// App Lifecycle Manager
// 
// Handles:
// - App backgrounding/foregrounding
// - Memory pressure events
// - Network connectivity changes
// - Screen rotation
// - Proper resource cleanup

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';

class AppLifecycleManager extends WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();
  
  final _performanceService = PerformanceService();
  
  // State tracking
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  bool _isInBackground = false;
  DateTime? _backgroundedAt;
  Timer? _backgroundCleanupTimer;
  
  // Callbacks
  final List<VoidCallback> _onForegroundCallbacks = [];
  final List<VoidCallback> _onBackgroundCallbacks = [];
  final List<VoidCallback> _onMemoryWarningCallbacks = [];
  final List<void Function(bool isConnected)> _onConnectivityChangeCallbacks = [];
  
  // Getters
  AppLifecycleState get currentState => _currentState;
  bool get isInBackground => _isInBackground;
  Duration? get backgroundDuration => 
      _backgroundedAt != null ? DateTime.now().difference(_backgroundedAt!) : null;
  
  /// Initialize the lifecycle manager
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  /// Dispose the lifecycle manager
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundCleanupTimer?.cancel();
  }
  
  /// Register callbacks
  void onForeground(VoidCallback callback) => _onForegroundCallbacks.add(callback);
  void onBackground(VoidCallback callback) => _onBackgroundCallbacks.add(callback);
  void onMemoryWarning(VoidCallback callback) => _onMemoryWarningCallbacks.add(callback);
  void onConnectivityChange(void Function(bool) callback) => 
      _onConnectivityChangeCallbacks.add(callback);
  
  /// Remove callbacks
  void removeOnForeground(VoidCallback callback) => _onForegroundCallbacks.remove(callback);
  void removeOnBackground(VoidCallback callback) => _onBackgroundCallbacks.remove(callback);
  void removeOnMemoryWarning(VoidCallback callback) => _onMemoryWarningCallbacks.remove(callback);
  void removeOnConnectivityChange(void Function(bool) callback) => 
      _onConnectivityChangeCallbacks.remove(callback);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentState = state;
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleForeground();
        break;
      case AppLifecycleState.paused:
        _handleBackground();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // These states don't require immediate action
        break;
    }
  }
  
  @override
  void didHaveMemoryPressure() {
    _handleMemoryWarning();
  }
  
  void _handleForeground() {
    if (!_isInBackground) return;
    
    _isInBackground = false;
    _backgroundCleanupTimer?.cancel();
    
    // Log foreground time
    if (_backgroundedAt != null) {
      final duration = DateTime.now().difference(_backgroundedAt!);
      debugPrint('🦆 App foregrounded after ${duration.inSeconds}s');
      _backgroundedAt = null;
    }
    
    // Notify listeners
    for (final callback in _onForegroundCallbacks) {
      callback();
    }
  }
  
  void _handleBackground() {
    if (_isInBackground) return;
    
    _isInBackground = true;
    _backgroundedAt = DateTime.now();
    
    // Schedule cleanup after 5 minutes in background
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = Timer(const Duration(minutes: 5), () {
      if (_isInBackground) {
        _performanceService.clearAllCaches();
        debugPrint('🦆 Cleared caches after 5 minutes in background');
      }
    });
    
    // Notify listeners
    for (final callback in _onBackgroundCallbacks) {
      callback();
    }
  }
  
  void _handleMemoryWarning() {
    debugPrint('🦆 Memory pressure detected');
    
    // Clear all caches immediately
    _performanceService.clearAllCaches();
    
    // Notify listeners
    for (final callback in _onMemoryWarningCallbacks) {
      callback();
    }
  }
  
  void notifyConnectivityChange(bool isConnected) {
    for (final callback in _onConnectivityChangeCallbacks) {
      callback(isConnected);
    }
  }
}

/// Mixin for screens that need lifecycle awareness
mixin LifecycleAwareMixin<T extends StatefulWidget> on State<T> {
  final _lifecycleManager = AppLifecycleManager();
  
  @override
  void initState() {
    super.initState();
    _lifecycleManager.onForeground(_onForeground);
    _lifecycleManager.onBackground(_onBackground);
    _lifecycleManager.onMemoryWarning(_onMemoryWarning);
  }
  
  @override
  void dispose() {
    _lifecycleManager.removeOnForeground(_onForeground);
    _lifecycleManager.removeOnBackground(_onBackground);
    _lifecycleManager.removeOnMemoryWarning(_onMemoryWarning);
    super.dispose();
  }
  
  /// Called when app comes to foreground
  void _onForeground() {
    if (mounted) {
      onForeground();
    }
  }
  
  /// Called when app goes to background
  void _onBackground() {
    if (mounted) {
      onBackground();
    }
  }
  
  /// Called when memory pressure is detected
  void _onMemoryWarning() {
    if (mounted) {
      onMemoryWarning();
    }
  }
  
  /// Override these methods in your screen
  void onForeground() {}
  void onBackground() {}
  void onMemoryWarning() {}
}

/// Wrapper widget that handles lifecycle events
class LifecycleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onForeground;
  final VoidCallback? onBackground;
  final VoidCallback? onMemoryWarning;
  
  const LifecycleWrapper({
    super.key,
    required this.child,
    this.onForeground,
    this.onBackground,
    this.onMemoryWarning,
  });
  
  @override
  State<LifecycleWrapper> createState() => _LifecycleWrapperState();
}

class _LifecycleWrapperState extends State<LifecycleWrapper> 
    with LifecycleAwareMixin {
  @override
  void onForeground() {
    widget.onForeground?.call();
  }
  
  @override
  void onBackground() {
    widget.onBackground?.call();
  }
  
  @override
  void onMemoryWarning() {
    widget.onMemoryWarning?.call();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}