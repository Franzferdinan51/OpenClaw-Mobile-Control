// Performance Optimization Service
// 
// Implements:
// - Request debouncing
// - Response caching with TTL
// - Exponential backoff for retries
// - Network optimization
// - Memory management

import 'dart:async';
import 'dart:collection';

/// Cache entry with TTL support
class CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  
  CacheEntry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Request debouncer for reducing API calls
class RequestDebouncer {
  final Duration delay;
  Timer? _timer;
  Completer<dynamic>? _completer;
  
  RequestDebouncer({this.delay = const Duration(milliseconds: 300)});
  
  Future<T> debounce<T>(Future<T> Function() request) async {
    _timer?.cancel();
    _completer?.completeError(StateError('Debounced'));
    
    _completer = Completer<T>();
    
    _timer = Timer(delay, () async {
      try {
        final result = await request();
        if (!_completer!.isCompleted) {
          _completer!.complete(result);
        }
      } catch (e) {
        if (!_completer!.isCompleted) {
          _completer!.completeError(e);
        }
      }
    });
    
    return _completer!.future as Future<T>;
  }
  
  void dispose() {
    _timer?.cancel();
    _completer?.completeError(StateError('Disposed'));
  }
}

/// Response cache with LRU eviction and TTL
class ResponseCache {
  final int maxSize;
  final Duration defaultTtl;
  
  final LinkedHashMap<String, CacheEntry<dynamic>> _cache = LinkedHashMap();
  final Map<String, DateTime> _lastAccess = {};
  
  ResponseCache({
    this.maxSize = 100,
    this.defaultTtl = const Duration(minutes: 5),
  });
  
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      _lastAccess.remove(key);
      return null;
    }
    
    _lastAccess[key] = DateTime.now();
    return entry.data as T;
  }
  
  void put<T>(String key, T data, {Duration? ttl}) {
    // Evict oldest if at capacity
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      _evictOldest();
    }
    
    _cache[key] = CacheEntry(data, ttl ?? defaultTtl);
    _lastAccess[key] = DateTime.now();
  }
  
  void _evictOldest() {
    if (_lastAccess.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _lastAccess.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }
    
    if (oldestKey != null) {
      _cache.remove(oldestKey);
      _lastAccess.remove(oldestKey);
    }
  }
  
  void invalidate(String key) {
    _cache.remove(key);
    _lastAccess.remove(key);
  }
  
  void clear() {
    _cache.clear();
    _lastAccess.clear();
  }
  
  int get size => _cache.length;
}

/// Exponential backoff retry handler
class RetryHandler {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  
  RetryHandler({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        await Future.delayed(delay);
        
        // Calculate next delay with exponential backoff
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
        
        // Cap at max delay
        if (delay > maxDelay) {
          delay = maxDelay;
        }
      }
    }
  }
}

/// Performance service for the app
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();
  
  // Caches for different data types
  final ResponseCache _statusCache = ResponseCache(
    maxSize: 10,
    defaultTtl: const Duration(seconds: 30),
  );
  
  final ResponseCache _agentsCache = ResponseCache(
    maxSize: 50,
    defaultTtl: const Duration(seconds: 15),
  );
  
  final ResponseCache _nodesCache = ResponseCache(
    maxSize: 20,
    defaultTtl: const Duration(seconds: 30),
  );
  
  final ResponseCache _generalCache = ResponseCache(
    maxSize: 100,
    defaultTtl: const Duration(minutes: 5),
  );
  
  // Debouncers for different operations
  final RequestDebouncer _statusDebouncer = RequestDebouncer(delay: const Duration(milliseconds: 300));
  final RequestDebouncer _refreshDebouncer = RequestDebouncer(delay: const Duration(milliseconds: 500));
  
  // Retry handler
  final RetryHandler _retryHandler = RetryHandler(
    maxRetries: 3,
    initialDelay: const Duration(seconds: 1),
    backoffMultiplier: 2.0,
  );
  
  // Performance metrics
  final Map<String, int> _requestCounts = {};
  final Map<String, Duration> _avgResponseTimes = {};
  DateTime? _lastMemoryWarning;
  
  // Getters for caches
  ResponseCache get statusCache => _statusCache;
  ResponseCache get agentsCache => _agentsCache;
  ResponseCache get nodesCache => _nodesCache;
  ResponseCache get generalCache => _generalCache;
  
  // Getters for debouncers
  RequestDebouncer get statusDebouncer => _statusDebouncer;
  RequestDebouncer get refreshDebouncer => _refreshDebouncer;
  
  // Get retry handler
  RetryHandler get retryHandler => _retryHandler;
  
  /// Execute a cached request
  Future<T?> cachedRequest<T>({
    required String key,
    required Future<T> Function() fetcher,
    ResponseCache? cache,
    bool forceRefresh = false,
  }) async {
    final targetCache = cache ?? _generalCache;
    
    // Check cache first
    if (!forceRefresh) {
      final cached = targetCache.get<T>(key);
      if (cached != null) {
        return cached;
      }
    }
    
    // Fetch with retry
    try {
      final result = await _retryHandler.execute(fetcher);
      targetCache.put(key, result);
      return result;
    } catch (e) {
      // Return stale data if available
      return targetCache.get<T>(key);
    }
  }
  
  /// Record a request for metrics
  void recordRequest(String endpoint, Duration responseTime) {
    _requestCounts[endpoint] = (_requestCounts[endpoint] ?? 0) + 1;
    
    final current = _avgResponseTimes[endpoint];
    if (current == null) {
      _avgResponseTimes[endpoint] = responseTime;
    } else {
      _avgResponseTimes[endpoint] = Duration(
        milliseconds: (current.inMilliseconds + responseTime.inMilliseconds) ~/ 2,
      );
    }
  }
  
  /// Get performance metrics
  Map<String, dynamic> getMetrics() {
    return {
      'cacheSizes': {
        'status': _statusCache.size,
        'agents': _agentsCache.size,
        'nodes': _nodesCache.size,
        'general': _generalCache.size,
      },
      'requestCounts': Map.from(_requestCounts),
      'avgResponseTimes': _avgResponseTimes.map(
        (k, v) => MapEntry(k, '${v.inMilliseconds}ms'),
      ),
      'lastMemoryWarning': _lastMemoryWarning?.toIso8601String(),
    };
  }
  
  /// Clear all caches (call when app goes to background or memory warning)
  void clearAllCaches() {
    _statusCache.clear();
    _agentsCache.clear();
    _nodesCache.clear();
    _generalCache.clear();
    _lastMemoryWarning = DateTime.now();
  }
  
  /// Dispose resources
  void dispose() {
    _statusDebouncer.dispose();
    _refreshDebouncer.dispose();
    clearAllCaches();
  }
}