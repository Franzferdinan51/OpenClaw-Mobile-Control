import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'discovery_screen.dart';

/// Authentication state
enum AuthStatus {
  idle,
  authenticating,
  success,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? token;
  final Map<String, dynamic>? user;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.token,
    this.user,
  });

  bool get isAuthenticating => status == AuthStatus.authenticating;
  bool get isAuthenticated => status == AuthStatus.success;
  bool get hasError => status == AuthStatus.error;
}

/// Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final GatewayDevice? gateway;
  final Dio _dio;

  AuthNotifier({
    this.gateway,
    Dio? dio,
  })  : _dio = dio ?? Dio(),
        super(const AuthState());

  Future<void> authenticate(String token) async {
    if (gateway == null) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'No gateway selected',
      );
      return;
    }

    state = AuthState(status: AuthStatus.authenticating);

    try {
      // Test connection with provided token
      final response = await _dio.get(
        '${gateway!.url}/api/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Token is valid - save it
        final box = await Hive.openBox('auth');
        await box.put('token', token);
        await box.put('gateway', gateway!.toJson());
        await box.put('gatewayUrl', gateway!.url);

        state = AuthState(
          status: AuthStatus.success,
          token: token,
          user: response.data,
        );
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: 'Invalid token. Please check and try again.',
        );
      }
    } on DioException catch (e) {
      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Connection timed out. Please check your network.';
          break;
        case DioExceptionType.connectionRefused:
          errorMessage = 'Could not connect to gateway. Is it running?';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 401) {
            errorMessage = 'Invalid token. Please check and try again.';
          } else {
            errorMessage = 'Server error: ${e.response?.statusCode}';
          }
          break;
        default:
          errorMessage = 'Connection failed: ${e.message}';
      }

      state = AuthState(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  Future<void> checkExistingAuth() async {
    try {
      final box = await Hive.openBox('auth');
      final token = box.get('token');
      final gatewayData = box.get('gateway');

      if (token != null && gatewayData != null) {
        state = AuthState(
          status: AuthStatus.success,
          token: token,
        );
      }
    } catch (e) {
      // Ignore errors during auth check
    }
  }

  Future<void> logout() async {
    try {
      final box = await Hive.openBox('auth');
      await box.clear();
      state = const AuthState();
    } catch (e) {
      // Ignore errors during logout
    }
  }
}

/// Provider factory that accepts gateway parameter
final authProvider = StateNotifierProvider.family<AuthNotifier, AuthState, GatewayDevice?>(
  (ref, gateway) => AuthNotifier(gateway: gateway),
);

/// Simple auth provider for current session
final currentAuthProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Auth Screen - Gateway token entry and authentication
class AuthScreen extends ConsumerStatefulWidget {
  final GatewayDevice? gateway;

  const AuthScreen({
    super.key,
    this.gateway,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    // Check for existing auth
    Future.microtask(() {
      ref.read(currentAuthProvider.notifier).checkExistingAuth();
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(currentAuthProvider);

    // Listen for auth success
    ref.listen<AuthState>(currentAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go('/');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Gateway'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/discovery'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gateway info card
                if (widget.gateway != null) _buildGatewayInfoCard(context),

                const SizedBox(height: 32),

                // Instructions
                Text(
                  'Authentication Token',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your OpenClaw gateway token to connect. You can find this in your OpenClaw configuration or generate one from the dashboard.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                // Token input
                TextFormField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    labelText: 'Token',
                    hintText: 'Enter your authentication token',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken
                            ? Icons.visibility_rounded
                            : Visibility_off_rounded,
                      ),
                      onPressed: () {
                        setState(() => _obscureToken = !_obscureToken);
                      },
                    ),
                  ),
                  obscureText: _obscureToken,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your token';
                    }
                    if (value.length < 10) {
                      return 'Token seems too short';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleAuthenticate(),
                ),

                const SizedBox(height: 16),

                // Error message
                if (authState.hasError)
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Connect button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: authState.isAuthenticating
                        ? null
                        : _handleAuthenticate,
                    icon: authState.isAuthenticating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      authState.isAuthenticating
                          ? 'Connecting...'
                          : 'Connect',
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Help section
                _buildHelpSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gateway = widget.gateway!;

    return Card(
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dns_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gateway.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gateway.url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => context.go('/discovery'),
              tooltip: 'Change gateway',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Where do I find my token?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1. Open your OpenClaw dashboard in a browser\n'
              '2. Go to Settings → API Tokens\n'
              '3. Generate a new token or copy an existing one\n'
              '4. Paste the token above',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _openGatewayDashboard(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open Gateway Dashboard',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAuthenticate() {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenController.text.trim();
    ref.read(currentAuthProvider.notifier).authenticate(token);
  }

  void _openGatewayDashboard() {
    if (widget.gateway != null) {
      // In production, open browser or webview
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${widget.gateway!.url}...'),
        ),
      );
    }
  }
}