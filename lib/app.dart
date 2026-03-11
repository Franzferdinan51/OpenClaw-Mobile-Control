import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../services/discovery_service.dart';
import '../services/app_settings_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/theme_service.dart';
import '../dialogs/connection_success_dialog.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/quick_actions_screen.dart';
import 'screens/control_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
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
    _isFirstLaunch = prefs.getBool('has_completed_setup') ?? true;
    final hasShownSuccessDialog = prefs.getBool('has_shown_connection_success') ?? false;
    
    String? gatewayUrl = prefs.getString('gateway_url');
    String? token = prefs.getString('gateway_token');
    String? gatewayName = prefs.getString('gateway_name');

    // Try last connected gateway first
    if (gatewayUrl != null) {
      _gatewayService = GatewayService(baseUrl: gatewayUrl, token: token);
      final status = await _gatewayService!.getStatus();

      if (status != null && status.online) {
        // Successfully connected to last gateway
        // Start connection monitoring
        connectionMonitor.startMonitoring(
          _gatewayService!,
          gatewayName: gatewayName,
        );
        
        setState(() {
          _isLoading = false;
          _isFirstLaunch = false;
        });
        
        // Show success dialog on first connection (but not on app restart)
        if (!hasShownSuccessDialog && mounted) {
          await prefs.setBool('has_shown_connection_success', true);
          
          // Show success dialog
          final status = await _gatewayService!.getStatus();
          if (status != null && mounted) {
            await showConnectionSuccessDialog(
              context: context,
              gatewayName: gatewayName ?? 'OpenClaw Gateway',
              gatewayUrl: gatewayUrl,
              version: status.version,
              uptime: status.uptime,
            );
          }
        }
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
        await prefs.setString('gateway_name', gateway.name);
        await prefs.setBool('has_completed_setup', true);
        await prefs.setBool('has_shown_connection_success', true);

        // Get status for success dialog
        final status = await _gatewayService!.getStatus();

        // Start connection monitoring
        connectionMonitor.startMonitoring(
          _gatewayService!,
          gatewayName: gateway.name,
        );

        setState(() {
          _isLoading = false;
          _isFirstLaunch = false;
        });

        // Show success dialog for discovered gateway
        if (status != null && mounted) {
          await showConnectionSuccessDialog(
            context: context,
            gatewayName: gateway.name ?? 'OpenClaw Gateway',
            gatewayUrl: gatewayUrl,
            version: status.version,
            uptime: status.uptime,
          );
        }
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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Install OpenClaw locally via Termux',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connect to OpenClaw on another device',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
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

  Widget _buildConnectionOption(String title, String description, IconData icon, VoidCallback onTap) {
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
  void dispose() {
    _appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Rebuild navigation when mode changes
    setState(() {});
  }

  void _updateGatewayService(GatewayService service) {
    setState(() {
      _gatewayService = service;
    });
  }

  void _onModeChanged() {
    // Force rebuild of navigation
    setState(() {
      _currentIndex = 0; // Reset to home tab
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
      DashboardScreen(gatewayService: _gatewayService),
      // Tab 1: Chat
      ChatScreen(gatewayService: _gatewayService),
    ];
    
    // Tab 2: Actions
    screens.add(_ActionsHubScreen(
      mode: mode,
      showAdvanced: mode != AppMode.basic,
      gatewayService: _gatewayService,
    ));
    
    // Tab 3: Tools (Power User and Developer only)
    if (mode == AppMode.powerUser || mode == AppMode.developer) {
      screens.add(_ToolsHubScreen(
        showDeveloperTools: mode == AppMode.developer,
      ));
    }
    
    // Tab 4: Dev Tools (Developer only)
    if (mode == AppMode.developer) {
      screens.add(const _DevToolsScreen());
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

  const _ActionsHubScreen({
    this.mode = AppMode.basic,
    this.showAdvanced = false,
    this.gatewayService,
  });

  @override
  State<_ActionsHubScreen> createState() => _ActionsHubScreenState();
}

class _ActionsHubScreenState extends State<_ActionsHubScreen> with SingleTickerProviderStateMixin {
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
          QuickActionsScreen(showAdvanced: widget.showAdvanced, gatewayService: widget.gatewayService),
          ControlScreen(showAdvanced: widget.showAdvanced),
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

class _ToolsHubScreenState extends State<_ToolsHubScreen> with SingleTickerProviderStateMixin {
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
  const _DevToolsScreen();

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API Explorer coming soon!'),
                    backgroundColor: Colors.purple,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debug Console coming soon!'),
                    backgroundColor: Colors.red,
                  ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Raw Logs coming soon!'),
                    backgroundColor: Colors.orange,
                  ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Advanced Config coming soon!'),
                    backgroundColor: Colors.blue,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Network Inspector coming soon!'),
                    backgroundColor: Colors.green,
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
