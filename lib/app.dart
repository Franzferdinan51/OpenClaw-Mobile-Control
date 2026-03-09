import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../services/discovery_service.dart';
import '../models/gateway_status.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/quick_actions_screen.dart';
import 'screens/control_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';

class OpenClawApp extends StatefulWidget {
  const OpenClawApp({super.key});

  @override
  State<OpenClawApp> createState() => _OpenClawAppState();
}

class _OpenClawAppState extends State<OpenClawApp> {
  final DiscoveryService _discoveryService = DiscoveryService();
  GatewayService? _gatewayService;
  bool _isLoading = true;
  bool _autoConnectFailed = false;
  String? _initialError;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    String? gatewayUrl = prefs.getString('gateway_url');
    String? token = prefs.getString('gateway_token');

    // Try last connected gateway first
    if (gatewayUrl != null) {
      _gatewayService = GatewayService(baseUrl: gatewayUrl, token: token);
      final status = await _gatewayService!.getStatus();

      if (status != null && status.online) {
        // Successfully connected to last gateway
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Last gateway failed, try discovery
    final discovered = await _discoveryService.scan();

    if (discovered.isNotEmpty) {
      // Connect to first discovered gateway
      final gateway = discovered.first;
      gatewayUrl = gateway.url;
      _gatewayService = GatewayService(baseUrl: gatewayUrl!);

      final status = await _gatewayService!.getStatus();
      if (status != null && status.online) {
        // Save discovered gateway
        await prefs.setString('gateway_url', gatewayUrl!);

        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Could not auto-connect
    setState(() {
      _isLoading = false;
      _autoConnectFailed = true;
      _initialError = gatewayUrl != null
          ? 'Could not connect to last gateway and no auto-discovered gateways found'
          : 'No gateway configured';
    });
  }

  void _onGatewayChanged() {
    // Reload gateway service with new settings
    _loadGatewayService();
  }

  Future<void> _loadGatewayService() async {
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
    final token = prefs.getString('gateway_token');

    setState(() {
      _gatewayService = GatewayService(baseUrl: gatewayUrl, token: token);
    });
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenClaw Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4AA),
          brightness: Brightness.dark,
        ),
      ),
      home: _isLoading
          ? const _LoadingScreen()
          : _autoConnectFailed
              ? _ErrorScreen(
                  error: _initialError,
                  onRetry: _initializeConnection,
                )
              : MainNavigationScreen(
                  gatewayService: _gatewayService,
                  onGatewayChanged: _onGatewayChanged,
                ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Connecting to Gateway...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Searching for OpenClaw on your network',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _ErrorScreen({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                'Could Not Connect',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                error ?? 'No gateway found',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please configure your gateway in Settings',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MainNavigationScreen(
                        onGatewayChanged: () {},
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final GatewayService? gatewayService;
  final VoidCallback onGatewayChanged;

  const MainNavigationScreen({
    super.key,
    this.gatewayService,
    required this.onGatewayChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late GatewayService? _gatewayService;

  @override
  void initState() {
    super.initState();
    _gatewayService = widget.gatewayService;
  }

  void _updateGatewayService(GatewayService service) {
    setState(() {
      _gatewayService = service;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(gatewayService: _gatewayService),
          const ChatScreen(),
          const QuickActionsScreen(),
          const ControlScreen(),
          const LogsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on),
            label: 'Quick',
          ),
          NavigationDestination(
            icon: Icon(Icons.gamepad_outlined),
            selectedIcon: Icon(Icons.gamepad),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}