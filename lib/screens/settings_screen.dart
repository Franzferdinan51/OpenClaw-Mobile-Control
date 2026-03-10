import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/theme_service.dart';
import '../widgets/connection_status_icon.dart';
import 'theme_selector_screen.dart';
import 'connect_gateway_screen.dart';
import 'local_installer_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function()? onGatewayChanged;
  final Function()? onModeChanged;

  const SettingsScreen({super.key, this.onGatewayChanged, this.onModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppSettingsService _appSettings = AppSettingsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // App, Backup, Advanced
    _initializeAppSettings();
  }

  Future<void> _initializeAppSettings() async {
    await AppSettingsService.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToConnectScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectGatewayScreen(
          onConnected: () {
            widget.onGatewayChanged?.call();
          },
        ),
      ),
    );
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
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'App'),
            Tab(icon: Icon(Icons.backup), text: 'Backup'),
            Tab(icon: Icon(Icons.build), text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppSettingsTab(),
          _buildBackupTab(),
          _buildAdvancedTab(),
        ],
      ),
    );
  }

  Widget _buildAppSettingsTab() {
    return AnimatedBuilder(
      animation: _appSettings,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Section
              _buildConnectionStatusSection(),
              const SizedBox(height: 16),
              
              // Connect Button (prominent)
              _buildConnectButtonSection(),
              const SizedBox(height: 24),
              
              // App Mode Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.layers, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'App Mode',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your interface complexity level',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<AppMode>(
                        segments: [
                          ButtonSegment(
                            value: AppMode.basic,
                            label: const Text('Basic'),
                            icon: Icon(Icons.star, color: _appSettings.currentMode == AppMode.basic ? Colors.green : null),
                            tooltip: 'Simple interface, essential features only',
                          ),
                          ButtonSegment(
                            value: AppMode.powerUser,
                            label: const Text('Power User'),
                            icon: Icon(Icons.bolt, color: _appSettings.currentMode == AppMode.powerUser ? Colors.blue : null),
                            tooltip: 'Full feature set, organized cleanly',
                          ),
                          ButtonSegment(
                            value: AppMode.developer,
                            label: const Text('Developer'),
                            icon: Icon(Icons.build, color: _appSettings.currentMode == AppMode.developer ? Colors.purple : null),
                            tooltip: 'All options, technical details, API access',
                          ),
                        ],
                        selected: {_appSettings.currentMode},
                        onSelectionChanged: (Set<AppMode> selected) async {
                          final newMode = selected.first;
                          await _appSettings.setAppMode(newMode);
                          // Notify parent to rebuild navigation
                          widget.onModeChanged?.call();
                          widget.onGatewayChanged?.call();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Mode changed to ${newMode.name}'),
                                backgroundColor: _getModeColor(newMode),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        multiSelectionEnabled: false,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getModeColor(_appSettings.currentMode).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getModeColor(_appSettings.currentMode)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getModeIcon(_appSettings.currentMode),
                              color: _getModeColor(_appSettings.currentMode),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getModeDescription(_appSettings.currentMode),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notifications
              Card(
                child: SwitchListTile(
                  title: const Text('Notifications'),
                  subtitle: const Text('Enable push notifications'),
                  value: _appSettings.notificationsEnabled,
                  onChanged: (value) async {
                    await _appSettings.setNotificationsEnabled(value);
                  },
                  secondary: const Icon(Icons.notifications),
                ),
              ),
              const SizedBox(height: 12),

              // Haptic Feedback
              Card(
                child: SwitchListTile(
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Vibrate on button presses'),
                  value: _appSettings.hapticFeedback,
                  onChanged: (value) async {
                    await _appSettings.setHapticFeedback(value);
                  },
                  secondary: const Icon(Icons.vibration),
                ),
              ),
              const SizedBox(height: 12),

              // Theme
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeDisplayName()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeSelectorScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Auto-Refresh Interval
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.refresh),
                          const SizedBox(width: 8),
                          Text(
                            'Auto-Refresh Interval',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _appSettings.autoRefreshInterval.toDouble(),
                        min: 15,
                        max: 300,
                        divisions: 19,
                        label: '${_appSettings.autoRefreshInterval}s',
                        onChanged: (value) async {
                          await _appSettings.setAutoRefreshInterval(value.round());
                        },
                      ),
                      Text(
                        'Dashboard and logs refresh every ${_appSettings.autoRefreshInterval} seconds',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Developer Options (only visible in developer mode)
              if (_appSettings.isDeveloperMode) ...[
                Card(
                  color: Colors.purple.withOpacity(0.1),
                  child: SwitchListTile(
                    title: const Text('Debug Logging'),
                    subtitle: const Text('Enable verbose logging for debugging'),
                    value: _appSettings.debugLogging,
                    onChanged: (value) async {
                      await _appSettings.setDebugLogging(value);
                    },
                    secondary: const Icon(Icons.bug_report),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // App Info
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.android,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'OpenClaw Mobile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Version 3.0.0',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Built with ❤️ by DuckBot 🦆',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectButtonSection() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: _navigateToConnectScreen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wifi_find,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to Gateway',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-discover, history, or manual entry',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusSection() {
    return AnimatedBuilder(
      animation: connectionMonitor,
      builder: (context, child) {
        final state = connectionMonitor.state;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getConnectionStatusColor(state.status).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.router,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gateway Connection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Status dot
                    ConnectionStatusDot(showLabel: true),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Gateway URL
                if (state.gatewayUrl != null)
                  _buildConnectionDetail(
                    context,
                    'Gateway URL',
                    state.gatewayUrl!,
                    Icons.link,
                  ),
                
                // Version
                if (state.gatewayInfo != null)
                  _buildConnectionDetail(
                    context,
                    'Version',
                    state.gatewayInfo!.version,
                    Icons.info_outline,
                  ),
                
                // Latency
                if (state.isConnected && state.lastPing != null)
                  _buildConnectionDetail(
                    context,
                    'Latency',
                    '${state.latencyMs}ms',
                    Icons.speed,
                  ),
                
                // Error message
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final success = await connectionMonitor.testConnection();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? '✓ Connection successful!'
                                      : '✗ Connection failed',
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.network_check, size: 18),
                        label: const Text('Test'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToConnectScreen,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Change'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionDetail(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backup,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Backup & Restore',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Local Installation Section
          Text(
            'Local Installation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.install_desktop, color: Colors.green),
              title: const Text('Install OpenClaw Locally'),
              subtitle: const Text('Run OpenClaw gateway on this device'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocalInstallerScreen(
                      onInstallationComplete: () {
                        widget.onGatewayChanged?.call();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Troubleshooting Section
          Text(
            'Troubleshooting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildTroubleshootingCard(),
          const SizedBox(height: 24),

          // Clear Data
          Text(
            'Data Management',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear App Data'),
              subtitle: const Text('Reset all settings and cached data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Data?'),
                    content: const Text(
                      'This will reset all app settings, clear connection history, and remove cached data. This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All data cleared'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Export Logs
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Export Debug Logs'),
              subtitle: const Text('Save logs for troubleshooting'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export logs - coming soon'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAboutRow('Version', '3.0.0'),
                  const Divider(),
                  _buildAboutRow('Build', '20260310'),
                  const Divider(),
                  _buildAboutRow('Platform', 'Android'),
                  const Divider(),
                  _buildAboutRow('OpenClaw API', 'v1'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Issues
            _buildTroubleshootingItem(
              icon: Icons.wifi_off,
              iconColor: Colors.orange,
              title: 'Can\'t find gateway?',
              steps: [
                'Make sure the OpenClaw gateway is running',
                'Verify mDNS is enabled in gateway config',
                'Ensure phone and gateway are on the same WiFi network',
                'Try manual connection with gateway IP address',
              ],
            ),
            const Divider(height: 24),

            // Tailscale Issues
            _buildTroubleshootingItem(
              icon: Icons.vpn_lock,
              iconColor: Colors.purple,
              title: 'Tailscale not working?',
              steps: [
                'mDNS does not work over Tailscale',
                'Use Manual tab and enter Tailscale IP directly',
                'Format: http://100.x.x.x:18789',
                'Make sure Tailscale is connected on both devices',
              ],
            ),
            const Divider(height: 24),

            // Connection Failed
            _buildTroubleshootingItem(
              icon: Icons.error_outline,
              iconColor: Colors.red,
              title: 'Connection failed?',
              steps: [
                'Check that gateway port 18789 is not blocked by firewall',
                'Verify the gateway URL is correct',
                'Try restarting the gateway service',
                'Check debug logs for detailed error information',
              ],
            ),
            const Divider(height: 24),

            // Debug Info
            _buildTroubleshootingItem(
              icon: Icons.bug_report,
              iconColor: Colors.blue,
              title: 'Need more help?',
              steps: [
                'Open Connect screen and tap "Show Debug Logs"',
                'Copy logs to clipboard using the copy button',
                'Share logs with support for troubleshooting',
                'Check OpenClaw documentation for more info',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...steps.map((step) => Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.basic:
        return Icons.star;
      case AppMode.powerUser:
        return Icons.bolt;
      case AppMode.developer:
        return Icons.build;
    }
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

  String _getModeDescription(AppMode mode) {
    switch (mode) {
      case AppMode.basic:
        return 'Basic Mode: Simple interface with essential features. Perfect for quick monitoring and basic control. Shows 4 tabs: Home, Chat, Actions, Settings.';
      case AppMode.powerUser:
        return 'Power User Mode: Full feature set with organized complexity. For daily users who want complete control. Shows 6 tabs with hub screens.';
      case AppMode.developer:
        return 'Developer Mode: All options, technical details, and API access. For developers and power users who need debug tools. Shows 7 tabs including Dev Tools.';
    }
  }

  Color _getConnectionStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red.shade800;
    }
  }

  String _getThemeDisplayName() {
    final theme = themeService.currentTheme;
    final mode = themeService.themeMode;
    String modeStr;
    switch (mode) {
      case ThemeMode.system:
        modeStr = 'System';
        break;
      case ThemeMode.light:
        modeStr = 'Light';
        break;
      case ThemeMode.dark:
        modeStr = 'Dark';
        break;
    }
    return '${theme.displayName} • $modeStr';
  }
}
