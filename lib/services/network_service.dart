// Network Service
// 
// Handles:
// - Network connectivity monitoring
// - Offline/online detection
// - Request queuing for offline scenarios
// - Smart retry with exponential backoff

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum NetworkStatus {
  online,
  offline,
  slow,
  unknown,
}

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();
  
  NetworkStatus _status = NetworkStatus.unknown;
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  final List<QueuedRequest> _requestQueue = [];
  static const int _maxQueueSize = 50;
  
  // Test endpoints for connectivity
  final List<String> _testEndpoints = [
    'https://www.google.com',
    'https://www.cloudflare.com',
    'https://www.apple.com',
  ];
  
  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;
  bool get isOffline => _status == NetworkStatus.offline;
  bool get isSlow => _status == NetworkStatus.slow;
  int get queueLength => _requestQueue.length;
  
  /// Start monitoring network status
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _checkConnectivity();
    
    _monitorTimer = Timer.periodic(interval, (_) => _checkConnectivity());
    debugPrint('🦆 Network monitoring started');
  }
  
  /// Stop monitoring network status
  void stopMonitoring() {
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('🦆 Network monitoring stopped');
  }
  
  /// Check network connectivity
  Future<NetworkStatus> checkConnectivity() async {
    return await _checkConnectivity();
  }
  
  Future<NetworkStatus> _checkConnectivity() async {
    NetworkStatus newStatus = NetworkStatus.offline;
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Try to connect to test endpoints
      for (final endpoint in _testEndpoints) {
        try {
          final socket = await Socket.connect(
            Uri.parse(endpoint).host,
            80,
            timeout: const Duration(seconds: 5),
          );
          socket.destroy();
          
          stopwatch.stop();
          final latency = stopwatch.elapsedMilliseconds;
          
          if (latency < 500) {
            newStatus = NetworkStatus.online;
          } else if (latency < 2000) {
            newStatus = NetworkStatus.slow;
          } else {
            newStatus = NetworkStatus.offline;
          }
          
          break;
        } catch (e) {
          // Try next endpoint
          continue;
        }
      }
    } catch (e) {
      newStatus = NetworkStatus.offline;
    }
    
    // Update status if changed
    if (newStatus != _status) {
      final oldStatus = _status;
      _status = newStatus;
      notifyListeners();
      debugPrint('🦆 Network status changed: $oldStatus -> $newStatus');
      
      // Process queued requests when coming back online
      if (newStatus == NetworkStatus.online && oldStatus == NetworkStatus.offline) {
        _processQueue();
      }
    }
    
    return newStatus;
  }
  
  /// Queue a request for later execution
  Future<T?> queueRequest<T>(
    String id,
    Future<T> Function() request, {
    Duration? maxAge,
    bool processImmediately = true,
  }) async {
    // If online and process immediately, execute now
    if (isOnline && processImmediately) {
      try {
        return await request();
      } catch (e) {
        // If request fails, queue for retry
        debugPrint('🦆 Request failed, queueing: $id');
      }
    }
    
    // Check if already in queue
    final existingIndex = _requestQueue.indexWhere((r) => r.id == id);
    if (existingIndex >= 0) {
      // Update existing request
      _requestQueue[existingIndex] = QueuedRequest(
        id: id,
        request: request,
        maxAge: maxAge ?? const Duration(minutes: 5),
        queuedAt: DateTime.now(),
      );
    } else if (_requestQueue.length < _maxQueueSize) {
      // Add to queue
      _requestQueue.add(QueuedRequest(
        id: id,
        request: request,
        maxAge: maxAge ?? const Duration(minutes: 5),
        queuedAt: DateTime.now(),
      ));
      debugPrint('🦆 Request queued: $id (queue: ${_requestQueue.length})');
    } else {
      debugPrint('🦆 Request queue full, dropping: $id');
    }
    
    return null;
  }
  
  /// Process queued requests
  Future<void> _processQueue() async {
    if (_requestQueue.isEmpty) return;
    
    debugPrint('🦆 Processing ${_requestQueue.length} queued requests');
    
    // Remove expired requests
    final now = DateTime.now();
    _requestQueue.removeWhere((r) {
      final age = now.difference(r.queuedAt);
      return age > r.maxAge;
    });
    
    // Process remaining requests
    final toProcess = List<QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();
    
    for (final queued in toProcess) {
      try {
        await queued.request();
        debugPrint('🦆 Processed queued request: ${queued.id}');
      } catch (e) {
        debugPrint('🦆 Failed to process queued request: ${queued.id} - $e');
        // Re-queue if failed
        if (_requestQueue.length < _maxQueueSize) {
          _requestQueue.add(QueuedRequest(
            id: queued.id,
            request: queued.request,
            maxAge: queued.maxAge,
            queuedAt: DateTime.now(),
          ));
        }
      }
    }
  }
  
  /// Clear request queue
  void clearQueue() {
    _requestQueue.clear();
    debugPrint('🦆 Request queue cleared');
  }
  
  /// Dispose
  @override
  void dispose() {
    stopMonitoring();
    clearQueue();
    super.dispose();
  }
}

/// Queued request container
class QueuedRequest {
  final String id;
  final Future<dynamic> Function() request;
  final Duration maxAge;
  final DateTime queuedAt;
  
  QueuedRequest({
    required this.id,
    required this.request,
    required this.maxAge,
    required this.queuedAt,
  });
}