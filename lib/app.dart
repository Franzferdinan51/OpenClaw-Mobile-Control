import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../services/discovery_service.dart';
import '../services/app_settings_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/theme_service.dart';
import '../dialogs/connection_success_dialog.dart';
import '../widgets/connection_status_card.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/quick_actions_screen.dart';
import 'screens/control_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settings_advanced_screen.dart';
import 'screens/browser_control_screen.dart';
import 'screens/workflows_screen.dart';
import 'screens/scheduled_tasks_screen.dart';
import 'screens/model_hub_screen.dart';
import 'screens/local_installer_screen.dart';

class DuckBotGoApp extends StatefulWidget {
  const DuckBotGoApp({super.key});

  @override
  State<DuckBotGoApp> createState() => _DuckBotGoAppState();
}

class _DuckBotGoAppState extends State<DuckBotGoApp> {
  final DiscoveryService _discoveryService = DiscoveryService();
  GatewayService? _gatewayService;
  bool _isLoading = true;
  bool _autoConnectFailed = false;
  bool _isFirstLaunch = false;
  String? _initialError;

  // Global navigator key for route handling
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

    // Check if first launch
    _isFirstLaunch = !(prefs.getBool('has_completed_setup') ?? false);
    final hasShownSuccessDialog =
        prefs.getBool('has_shown_connection_success') ?? false;

    String? gatewayUrl = prefs.getString('gateway_url');
    String? token = prefs.getString('gateway_token');
    String? gatewayName = prefs.getString('gateway_name');

    // Try last connected gateway first
    if (gatewayUrl != null &&
        await _tryStartupGateway(
          prefs,
          gatewayUrl: gatewayUrl,
          gatewayName: gatewayName,
          token: token,
          showSuccessDialog: !hasShownSuccessDialog,
        )) {
      return;
    }

    final lastConnected = await _discoveryService.getLastConnected();
    final fallbackCandidates = <Map<String, String?>>[
      {
        'url': 'http://127.0.0.1:18789',
        'name': 'Local Gateway (This Device)',
      },
      {
        'url': 'http://localhost:18789',
        'name': 'Local Gateway (Loopback)',
      },
      {
        'url': 'http://10.0.2.2:18789',
        'name': 'Android Emulator Gateway',
      },
      if (lastConnected != null &&
          lastConnected.url.isNotEmpty &&
          lastConnected.url != gatewayUrl)
        {
          'url': lastConnected.url,
          'name': lastConnected.name,
          'token': lastConnected.token ?? token,
        },
    ];

    for (final candidate in fallbackCandidates) {
      final candidateUrl = candidate['url'];
      if (candidateUrl == null || candidateUrl == gatewayUrl) continue;

      if (await _tryStartupGateway(
        prefs,
        gatewayUrl: candidateUrl,
        gatewayName: candidate['name'],
        token: candidate['token'] ?? token,
        showSuccessDialog: !hasShownSuccessDialog,
      )) {
        return;
      }
    }

    // Last gateway failed, try discovery
    final discovered = await _discoveryService.scan();

    for (final gateway in discovered) {
      if (await _tryStartupGateway(
        prefs,
        gatewayUrl: gateway.url,
        gatewayName: gateway.name,
        token: gateway.token ?? token,
        showSuccessDialog: !hasShownSuccessDialog,
      )) {
        return;
      }
    }

    // Could not auto-connect - show guided setup on first launch
    setState(() {
      _isLoading = false;
      _autoConnectFailed = true;
      _initialError = gatewayUrl != null
          ? 'Could not connect to last gateway and no auto-discovered gateways found'
          : 'No gateway configured';
    });
  }

  Future<bool> _tryStartupGateway(
    SharedPreferences prefs, {
    required String gatewayUrl,
    String? gatewayName,
    String? token,
    required bool showSuccessDialog,
  }) async {
    final service = GatewayService(baseUrl: gatewayUrl, token: token);
    final status = await service.getStatus(timeout: const Duration(seconds: 3));
    if (status == null || !status.online) {
      return false;
    }

    _gatewayService = service;
    await prefs.setString('gateway_url', gatewayUrl);
    if (gatewayName != null && gatewayName.isNotEmpty) {
      await prefs.setString('gateway_name', gatewayName);
    }
    if (token != null && token.isNotEmpty) {
      await prefs.setString('gateway_token', token);
    }
    await prefs.setBool('has_completed_setup', true);
    if (showSuccessDialog) {
      await prefs.setBool('has_shown_connection_success', true);
    }

    connectionMonitor.startMonitoring(
      service,
      gatewayName: gatewayName,
    );

    if (!mounted) return true;

    setState(() {
      _isLoading = false;
      _isFirstLaunch = false;
      _autoConnectFailed = false;
      _initialError = null;
    });

    if (showSuccessDialog) {
      await showConnectionSuccessDialog(
        context: context,
        gatewayName: gatewayName ?? 'OpenClaw Gateway',
        gatewayUrl: gatewayUrl,
        status: status,
      );
    }

    return true;
  }

  void _onGatewayChanged() {
    // Reload gateway service with new settings
    _loadGatewayService();
  }

  Future<void> _loadGatewayService() async {
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl =
        prefs.getString('gateway_url') ?? 'http://localhost:18789';
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
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'DuckBot Go',
          debugShowCheckedModeBanner: false,
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          themeMode: themeService.themeMode,
          navigatorKey: _navigatorKey,
          // Named routes for navigation with tab selection
          routes: {
            '/main': (context) => _isLoading
                ? const _LoadingScreen()
                : _isFirstLaunch || _autoConnectFailed
                    ? _GuidedSetupScreen(
                        error: _initialError,
                        onComplete: () {
                          setState(() {
                            _isFirstLaunch = false;
                            _autoConnectFailed = false;
                            _loadGatewayService();
                          });
                        },
                      )
                    : MainNavigationScreen(
                        gatewayService: _gatewayService,
                        onGatewayChanged: _onGatewayChanged,
                        initialTab: _getInitialTab(context),
                      ),
          },
          home: _isLoading
              ? const _LoadingScreen()
              : _isFirstLaunch || _autoConnectFailed
                  ? _GuidedSetupScreen(
                      error: _initialError,
                      onComplete: () {
                        setState(() {
                          _isFirstLaunch = false;
                          _autoConnectFailed = false;
                          _loadGatewayService();
                        });
                      },
                    )
                  : MainNavigationScreen(
                      gatewayService: _gatewayService,
                      onGatewayChanged: _onGatewayChanged,
                    ),
        );
      },
    );
  }

  /// Get initial tab from route parameters
  int? _getInitialTab(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('tab')) {
      final tab = args['tab'] as String;
      switch (tab) {
        case 'chat':
          return 1;
        case 'home':
          return 0;
        case 'actions':
          return 2;
        case 'settings':
          return 3;
        default:
          return null;
      }
    }
    return null;
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

class _GuidedSetupScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onComplete;

  const _GuidedSetupScreen({this.error, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to OpenClaw Mobile'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.android,
                  size: 80,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Let\'s Get You Connected!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error ?? 'Choose how you want to use OpenClaw Mobile:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Option 1: Install Locally
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: () => _showInstallLocallyDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone_android,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Install on This Phone',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Install OpenClaw locally via Termux',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✨ Best for:',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Using this phone as your OpenClaw node\n• Running automations on this device\n• Voice control and mobile access',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Option 2: Connect to Remote
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: () => _showConnectRemoteDialog(context, onComplete),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.cloud,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connect to Remote Gateway',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connect to OpenClaw on another device',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✨ Best for:',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• OpenClaw already running on PC/server\n• Using this phone as a remote control\n• Monitoring from mobile',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInstallLocallyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.green),
            SizedBox(width: 8),
            Text('Install on This Phone'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will install OpenClaw directly on your phone using Termux.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Requirements:'),
              const SizedBox(height: 8),
              _buildRequirementItem('Termux app (from F-Droid)'),
              _buildRequirementItem('Node.js installed'),
              _buildRequirementItem('Internet connection'),
              const SizedBox(height: 16),
              const Text('Steps:'),
              const SizedBox(height: 8),
              _buildStepItem('1', 'Download Termux from F-Droid'),
              _buildStepItem('2', 'Open Termux and run: pkg install nodejs'),
              _buildStepItem('3', 'Tap "Start Installation" below'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Termux not available on Google Play. Must download from F-Droid.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocalInstallerScreen(
                    onInstallationComplete: () {
                      // Refresh app state after installation
                      onComplete();
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Start Installation'),
          ),
        ],
      ),
    );
  }

  void _showConnectRemoteDialog(BuildContext context, VoidCallback onComplete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud, color: Colors.blue),
            SizedBox(width: 8),
            Text('Connect to Remote Gateway'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connect to an OpenClaw gateway running on another device.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Connection Options:'),
              const SizedBox(height: 8),
              _buildConnectionOption(
                'Auto-Discover',
                'Scan network for gateways',
                Icons.wifi,
                () {
                  Navigator.pop(context);
                  onComplete();
                },
              ),
              const SizedBox(height: 8),
              _buildConnectionOption(
                'Manual Entry',
                'Enter IP and port manually',
                Icons.edit,
                () {
                  Navigator.pop(context);
                  onComplete();
                },
              ),
              const SizedBox(height: 8),
              _buildConnectionOption(
                'Tailscale',
                'Connect via private network',
                Icons.security,
                () {
                  Navigator.pop(context);
                  onComplete();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onComplete();
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Gateways'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildConnectionOption(
      String title, String description, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final GatewayService? gatewayService;
  final VoidCallback onGatewayChanged;
  final int? initialTab;

  const MainNavigationScreen({
    super.key,
    this.gatewayService,
    required this.onGatewayChanged,
    this.initialTab,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late GatewayService? _gatewayService;
  final AppSettingsService _appSettings = AppSettingsService();

  @override
  void initState() {
    super.initState();
    _gatewayService = widget.gatewayService;
    _currentIndex = widget.initialTab ?? 0;
    _appSettings.addListener(_onSettingsChanged);
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final gatewayChanged =
        oldWidget.gatewayService?.baseUrl != widget.gatewayService?.baseUrl ||
            oldWidget.gatewayService?.token != widget.gatewayService?.token;

    if (gatewayChanged) {
      _gatewayService = widget.gatewayService;
    }
  }

  @override
  void dispose() {
    _appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Rebuild navigation when mode changes
    setState(() {});
  }

  void _onModeChanged() {
    // Force rebuild of navigation
    setState(() {
      _currentIndex = 0; // Reset to home tab
    });
  }

  void _openTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build navigation based on current mode
    final destinations = _buildNavDestinations();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }

  List<NavigationDestination> _buildNavDestinations() {
    final mode = _appSettings.currentMode;

    // All modes have these core tabs
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.chat_outlined),
        selectedIcon: Icon(Icons.chat),
        label: 'Chat',
      ),
    ];

    // Add Actions tab (different for each mode)
    destinations.add(NavigationDestination(
      icon: Icon(Icons.bolt_outlined, color: _getModeColor(mode)),
      selectedIcon: Icon(Icons.bolt, color: _getModeColor(mode)),
      label: 'Actions',
    ));

    // Power User and Developer get Tools tab
    if (mode == AppMode.powerUser || mode == AppMode.developer) {
      destinations.add(NavigationDestination(
        icon: Icon(Icons.build_outlined, color: _getModeColor(mode)),
        selectedIcon: Icon(Icons.build, color: _getModeColor(mode)),
        label: 'Tools',
      ));
    }

    // Developer gets Dev tab
    if (mode == AppMode.developer) {
      destinations.add(NavigationDestination(
        icon: Icon(Icons.code_outlined, color: _getModeColor(mode)),
        selectedIcon: Icon(Icons.code, color: _getModeColor(mode)),
        label: 'Dev',
      ));
    }

    // All modes have Settings
    destinations.add(const NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ));

    return destinations;
  }

  List<Widget> _buildScreens() {
    final mode = _appSettings.currentMode;

    final screens = <Widget>[
      // Tab 0: Home (Dashboard)
      DashboardScreen(
        gatewayService: _gatewayService,
        onGatewayChanged: widget.onGatewayChanged,
        onOpenChat: () => _openTab(1),
      ),
      // Tab 1: Chat
      ChatScreen(gatewayService: _gatewayService),
    ];

    // Tab 2: Actions
    screens.add(_ActionsHubScreen(
      mode: mode,
      showAdvanced: mode != AppMode.basic,
      gatewayService: _gatewayService,
      onOpenChat: () => _openTab(1),
    ));

    // Tab 3: Tools (Power User and Developer only)
    if (mode == AppMode.powerUser || mode == AppMode.developer) {
      screens.add(_ToolsHubScreen(
        showDeveloperTools: mode == AppMode.developer,
      ));
    }

    // Tab 4: Dev Tools (Developer only)
    if (mode == AppMode.developer) {
      screens.add(_DevToolsScreen(gatewayService: _gatewayService));
    }

    // Settings tab (last)
    screens.add(SettingsScreen(
      onGatewayChanged: widget.onGatewayChanged,
      onModeChanged: _onModeChanged,
    ));

    return screens;
  }

  Color _getModeColor(AppMode mode) {
    switch (mode) {
      case AppMode.basic:
        return Colors.green;
      case AppMode.powerUser:
        return Colors.blue;
      case AppMode.developer:
        return Colors.purple;
    }
  }
}

// Hub screen combining Quick Actions and Control
class _ActionsHubScreen extends StatefulWidget {
  final AppMode mode;
  final bool showAdvanced;
  final GatewayService? gatewayService;
  final VoidCallback? onOpenChat;

  const _ActionsHubScreen({
    this.mode = AppMode.basic,
    this.showAdvanced = false,
    this.gatewayService,
    this.onOpenChat,
  });

  @override
  State<_ActionsHubScreen> createState() => _ActionsHubScreenState();
}

class _ActionsHubScreenState extends State<_ActionsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(_ActionsHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update tab controller if mode changed
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Actions'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getModeColor(widget.mode).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.mode.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getModeColor(widget.mode),
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.flash_on), text: 'Quick'),
            Tab(icon: Icon(Icons.gamepad), text: 'Control'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QuickActionsScreen(
              showAdvanced: widget.showAdvanced,
              gatewayService: widget.gatewayService,
              onOpenChat: widget.onOpenChat),
          ControlScreen(
            showAdvanced: widget.showAdvanced,
            gatewayService: widget.gatewayService,
          ),
        ],
      ),
    );
  }

  Color _getModeColor(AppMode mode) {
    switch (mode) {
      case AppMode.basic:
        return Colors.green;
      case AppMode.powerUser:
        return Colors.blue;
      case AppMode.developer:
        return Colors.purple;
    }
  }
}

// Hub screen combining Logs, Browser, Workflows, Tasks, and AI Models
class _ToolsHubScreen extends StatefulWidget {
  final bool showDeveloperTools;

  const _ToolsHubScreen({
    this.showDeveloperTools = false,
  });

  @override
  State<_ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<_ToolsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Tools'),
            if (widget.showDeveloperTools) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'DEV',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.article), text: 'Logs'),
            Tab(icon: Icon(Icons.public), text: 'Browser'),
            Tab(icon: Icon(Icons.account_tree), text: 'Workflows'),
            Tab(icon: Icon(Icons.schedule), text: 'Tasks'),
            Tab(icon: Icon(Icons.analytics), text: 'AI Models'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LogsScreen(),
          BrowserControlScreen(),
          WorkflowsScreen(),
          ScheduledTasksScreen(),
          ModelHubScreen(),
        ],
      ),
    );
  }
}

// Developer Tools screen (Developer mode only)
class _DevToolsScreen extends StatelessWidget {
  final GatewayService? gatewayService;

  const _DevToolsScreen({this.gatewayService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Dev Tools'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DEVELOPER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.terminal, color: Colors.purple),
              title: const Text('API Explorer'),
              subtitle: const Text('Test API endpoints directly'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _ApiExplorerScreen(
                      gatewayService: gatewayService,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.red),
              title: const Text('Debug Console'),
              subtitle: const Text('View debug logs and errors'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: Colors.orange),
              title: const Text('Raw Logs'),
              subtitle: const Text('View raw gateway logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_suggest, color: Colors.blue),
              title: const Text('Advanced Config'),
              subtitle: const Text('Edit raw configuration'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdvancedSettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.network_check, color: Colors.green),
              title: const Text('Network Inspector'),
              subtitle: const Text('Monitor network requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _NetworkInspectorScreen(
                      gatewayService: gatewayService,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiExplorerScreen extends StatelessWidget {
  final GatewayService? gatewayService;

  const _ApiExplorerScreen({this.gatewayService});

  @override
  Widget build(BuildContext context) {
    final baseUrl = gatewayService?.baseUrl ??
        connectionMonitor.state.gatewayUrl ??
        'http://localhost:18789';

    final endpoints = <Map<String, String>>[
      {
        'label': 'Health Check',
        'method': 'GET',
        'path': '$baseUrl/health',
        'curl': 'curl $baseUrl/health',
      },
      {
        'label': 'Gateway Status',
        'method': 'GET',
        'path': '$baseUrl/api/gateway',
        'curl': 'curl $baseUrl/api/gateway',
      },
      {
        'label': 'Gateway Logs',
        'method': 'GET',
        'path': '$baseUrl/api/logs?limit=100',
        'curl': 'curl "$baseUrl/api/logs?limit=100"',
      },
      {
        'label': 'Agent Action',
        'method': 'POST',
        'path': '$baseUrl/api/gateway/action',
        'curl':
            'curl -X POST $baseUrl/api/gateway/action -H "Content-Type: application/json" -d \'{"action":"history","sessionKey":"main","limit":20}\'',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('API Explorer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Current Gateway'),
              subtitle: SelectableText(baseUrl),
            ),
          ),
          const SizedBox(height: 12),
          ...endpoints.map((endpoint) {
            final curl = endpoint['curl']!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: endpoint['method'] == 'POST'
                                  ? Colors.orange.withOpacity(0.15)
                                  : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              endpoint['method']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: endpoint['method'] == 'POST'
                                    ? Colors.orange[800]
                                    : Colors.green[800],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              endpoint['label']!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        endpoint['path']!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: curl));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('cURL command copied'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy cURL'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NetworkInspectorScreen extends StatelessWidget {
  final GatewayService? gatewayService;

  const _NetworkInspectorScreen({this.gatewayService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: connectionMonitor,
      builder: (context, _) {
        final state = connectionMonitor.state;
        final gatewayUrl = gatewayService?.baseUrl ??
            state.gatewayUrl ??
            'No gateway configured';

        return Scaffold(
          appBar: AppBar(title: const Text('Network Inspector')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ConnectionStatusCard(
                onRetry: () => connectionMonitor.reconnect(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raw Connection State',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      _buildInspectorRow('Gateway URL', gatewayUrl),
                      _buildInspectorRow('Status', state.statusText),
                      _buildInspectorRow('Latency', '${state.latencyMs}ms'),
                      _buildInspectorRow(
                        'Last Ping',
                        state.lastPing?.toIso8601String() ?? 'Never',
                      ),
                      _buildInspectorRow(
                        'Error',
                        state.errorMessage?.isNotEmpty == true
                            ? state.errorMessage!
                            : 'None',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInspectorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
