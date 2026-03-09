import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Gateway Service - HTTP client for OpenClaw Gateway API
/// 
/// Provides authenticated HTTP communication with OpenClaw Gateway
/// using JWT tokens managed by AuthService.
class GatewayService {
  static GatewayService? _instance;
  static final _instanceMutex = Object();

  late final Dio _dio;
  String? _baseUrl;
  String? _jwtToken;
  
  // Logger callback for external logging integration
  void Function(String level, String message, [dynamic data])? onLog;

  factory GatewayService() {
    if (_instance == null) {
      synchronized:
      {
        if (_instance == null) {
          _instance = GatewayService._internal();
        }
      }
    }
    return _instance!;
  }

  GatewayService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor(this));
    _dio.interceptors.add(_LoggingInterceptor(this));
    _dio.interceptors.add(_RetryInterceptor(this));
  }

  /// Get the underlying Dio instance for advanced usage
  Dio get dio => _dio;

  /// Current base URL for the Gateway
  String? get baseUrl => _baseUrl;

  /// Current JWT token (for debugging only)
  String? get jwtToken => _jwtToken;

  /// Configure the gateway connection
  void configure({
    required String baseUrl,
    String? jwtToken,
  }) {
    _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');
    if (jwtToken != null) {
      _jwtToken = jwtToken;
    }
    _log('info', 'Gateway configured: $_baseUrl');
  }

  /// Update JWT token (called by AuthService)
  void setToken(String? token) {
    _jwtToken = token;
    if (token != null) {
      _log('debug', 'JWT token updated');
    } else {
      _log('debug', 'JWT token cleared');
    }
  }

  /// Clear all authentication
  void clearAuth() {
    _jwtToken = null;
    _log('info', 'Authentication cleared');
  }

  // ==================== HTTP Methods ====================

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _validateConfiguration();
    return _dio.get<T>(
      '$_baseUrl$path',
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _validateConfiguration();
    return _dio.post<T>(
      '$_baseUrl$path',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _validateConfiguration();
    return _dio.put<T>(
      '$_baseUrl$path',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _validateConfiguration();
    return _dio.delete<T>(
      '$_baseUrl$path',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _validateConfiguration();
    return _dio.patch<T>(
      '$_baseUrl$path',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ==================== API Endpoints ====================

  /// Health check endpoint
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await get<Map<String, dynamic>>('/health');
      return response.data ?? {'status': 'unknown'};
    } on DioException catch (e) {
      _log('error', 'Health check failed', e);
      throw GatewayException(
        message: 'Health check failed',
        code: e.response?.statusCode?.toString(),
        originalError: e,
      );
    }
  }

  /// Get current session status
  Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      final response = await get<Map<String, dynamic>>('/api/session/status');
      return response.data ?? {};
    } on DioException catch (e) {
      _log('error', 'Failed to get session status', e);
      throw GatewayException(
        message: 'Failed to get session status',
        code: e.response?.statusCode?.toString(),
        originalError: e,
      );
    }
  }

  /// Send message to agent
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await post<Map<String, dynamic>>(
        '/api/chat/message',
        data: {
          'message': message,
          if (sessionId != null) 'sessionId': sessionId,
          if (metadata != null) 'metadata': metadata,
        },
      );
      return response.data ?? {};
    } on DioException catch (e) {
      _log('error', 'Failed to send message', e);
      throw GatewayException(
        message: 'Failed to send message',
        code: e.response?.statusCode?.toString(),
        originalError: e,
      );
    }
  }

  /// Get available agents
  Future<List<Map<String, dynamic>>> getAgents() async {
    try {
      final response = await get<List<dynamic>>('/api/agents');
      return (response.data ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _log('error', 'Failed to get agents', e);
      throw GatewayException(
        message: 'Failed to get agents',
        code: e.response?.statusCode?.toString(),
        originalError: e,
      );
    }
  }

  /// Get gateway configuration
  Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await get<Map<String, dynamic>>('/api/config');
      return response.data ?? {};
    } on DioException catch (e) {
      _log('error', 'Failed to get config', e);
      throw GatewayException(
        message: 'Failed to get configuration',
        code: e.response?.statusCode?.toString(),
        originalError: e,
      );
    }
  }

  // ==================== Private Helpers ====================

  void _validateConfiguration() {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw GatewayException(
        message: 'Gateway not configured. Call configure() first.',
        code: 'NOT_CONFIGURED',
      );
    }
  }

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[GatewayService][$level] $message ${data ?? ''}');
    }
  }
}

// ==================== Interceptors ====================

class _AuthInterceptor extends Interceptor {
  final GatewayService _service;

  _AuthInterceptor(this._service);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _service._jwtToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _service._log('warn', 'Authentication failed - token may be expired');
      // AuthService should handle token refresh via callback
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  final GatewayService _service;

  _LoggingInterceptor(this._service);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _service._log('debug', '→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _service._log(
      'debug',
      '← ${response.statusCode} ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _service._log(
      'error',
      '✗ ${err.type} ${err.requestOptions.path}: ${err.message}',
    );
    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  final GatewayService _service;
  final int maxRetries;
  final Duration retryDelay;

  _RetryInterceptor(
    this._service, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only retry on network errors or 5xx errors
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
      if (retryCount < maxRetries) {
        err.requestOptions.extra['retryCount'] = retryCount + 1;
        
        _service._log(
          'warn',
          'Retrying (${retryCount + 1}/$maxRetries): ${err.requestOptions.path}',
        );

        await Future.delayed(retryDelay * (retryCount + 1));
        
        try {
          final response = await _service._dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } on DioException catch (e) {
          handler.next(e);
          return;
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500);
  }
}

// ==================== Exceptions ====================

class GatewayException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  GatewayException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    final parts = [message];
    if (code != null) parts.add('($code)');
    return 'GatewayException: ${parts.join(' ')}';
  }
}