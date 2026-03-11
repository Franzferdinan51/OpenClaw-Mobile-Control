import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/gateway_service.dart';
import '../services/connection_monitor_service.dart';
import '../models/gateway_status.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/connection_status_icon.dart';
import 'settings_screen.dart';
import 'connect_gateway_screen.dart';
import 'logs_screen.dart';
import 'chat_screen.dart';
import 'termux_screen.dart';

class DashboardScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const DashboardScreen({super.key, this.gatewayService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  GatewayService? _service;
  GatewayStatus? _status;
  bool _loading = true;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _autoRefreshTimer;
  String? _gatewayName;
  ConnectionStatus _lastConnectionStatus = ConnectionStatus.disconnected;
  bool _hasShownLostNotification = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // Listen for connection status changes
    connectionMonitor.addListener(_onConnectionStatusChanged);
    // Auto-refresh every 30 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    connectionMonitor.removeListener(_onConnectionStatusChanged);
    super.dispose();
  }

  void _onConnectionStatusChanged() {
    final state = connectionMonitor.state;
    
    // Show SnackBar when connection is lost (only once per disconnection)
    if (state.isDisconnected || state.hasError) {
      if (_lastConnectionStatus == ConnectionStatus.connected && !_hasShownLostNotification) {
        _hasShownLostNotification = true;
        _showConnectionLostNotification(state.errorMessage);
      }
    } else if (state.isConnected) {
      // Reset notification flag when reconnected
      _hasShownLostNotification = false;
    }
    
    _lastConnectionStatus = state.status;
  }

  void _showConnectionLostNotification(String? error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gateway Connection Lost${error != null ? ': $error' : ''}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Reconnect',
          textColor: Colors.white,
          onPressed: () => connectionMonitor.reconnect(),
        ),
      ),
    );
  }

  Future<void> _loadConfig() async {
    // Use passed service or create new one from stored settings
    if (widget.gatewayService != null) {
      setState(() {
        _service = widget.gatewayService;
        _loading = true;
      });
      
      // Start connection monitoring
      connectionMonitor.startMonitoring(
        widget.gatewayService!,
        gatewayName: _gatewayName,
      );
      
      await _refreshStatus();
      return;
    }

    // Fallback to loading from preferences
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
    final token = prefs.getString('gateway_token');
    _gatewayName = prefs.getString('gateway_name');

    setState(() {
      _service = GatewayService(baseUrl: gatewayUrl, token: token);
      _loading = true;
    });
    
    // Start connection monitoring
    connectionMonitor.startMonitoring(
      _service!,
      gatewayName: _gatewayName,
    );

    await _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (_service == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await _service!.getStatus();
      setState(() {
        _status = status;
        _loading = false;
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw Mobile'),
        actions: [
          // Connection status icon
          const ConnectionStatusIcon(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _status == null
              ? _buildConnectionPrompt(context)
              : RefreshIndicator(
                  onRefresh: _refreshStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Connection Status Card (prominent at top)
                      ConnectionStatusCard(
                        onRetry: _refreshStatus,
                      ),
                      const SizedBox(height: 16),
                      
                      // Last refresh indicator
                      if (_lastRefresh != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Updated ${_getTimeAgo(_lastRefresh!)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      
                      // Quick Stats Row
                      _buildQuickStatsRow(),
                      const SizedBox(height: 16),
                      
                      // System Health
                      _buildSystemHealthCard(),
                      const SizedBox(height: 16),
                      
                      _buildGatewayCard(),
                      const SizedBox(height: 16),
                      _buildAgentsCard(),
                      const SizedBox(height: 16),
                      _buildNodesCard(),
                      const SizedBox(height: 16),
                      
                      // Quick Actions
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGatewayCard() {
    final status = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status?.online ?? false ? Icons.check_circle : Icons.error,
                  color: status?.online ?? false ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('Gateway', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (status != null) ...[
              _buildInfoRow('Version', status.version == 'unknown' ? 'Unavailable' : status.version),
              _buildInfoRow('Uptime', _formatUptime(status.uptime)),
              if (status.cpuPercent != null) _buildInfoRow('CPU', '${status.cpuPercent!.toStringAsFixed(1)}%'),
              if (status.memoryUsed != null && status.memoryTotal != null)
                _buildInfoRow('Memory', '${(status.memoryUsed! / 1024 / 1024).toStringAsFixed(0)} MB / ${(status.memoryTotal! / 1024 / 1024).toStringAsFixed(0)} MB'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgentsCard() {
    final agents = _status?.agents ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agents (${agents.length})', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (agents.isEmpty)
              const Text('No agents active')
            else
              ...agents.map((agent) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      agent.status == 'active' ? Icons.play_circle : Icons.pause_circle,
                      color: agent.status == 'active' ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(agent.name, style: Theme.of(context).textTheme.titleMedium),
                          if (agent.currentTask != null)
                            Text(agent.currentTask!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildNodesCard() {
    final nodes = _status?.nodes ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nodes (${nodes.length})', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (nodes.isEmpty)
              const Text('No nodes connected')
            else
              ...nodes.map((node) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      node.status == 'connected' ? Icons.check_circle : Icons.error,
                      color: node.status == 'connected' ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(node.name, style: Theme.of(context).textTheme.titleMedium),
                          Text('${node.connectionType ?? 'unknown'} ${node.ip != null ? '(${node.ip})' : ''}', 
                               style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return 'Unavailable';

    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Build connection prompt when no gateway is connected
  Widget _buildConnectionPrompt(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DuckBot mascot icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.android, // Android robot as mascot
                size: 80,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            Text(
              'Welcome to OpenClaw Mobile!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Description
            Text(
              'Get started by connecting to your OpenClaw gateway. Choose one of the options below:',
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
            
            // Option 2: Connect to Remote - Single entry point
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () => _navigateToConnectGateway(context),
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
            const SizedBox(height: 24),
            
            // Quick actions - Single Connect button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _navigateToConnectGateway(context),
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Connect to Gateway'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog for installing OpenClaw locally
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
              // Navigate to Termux screen to start installation
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermuxScreen()),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Start Installation'),
          ),
        ],
      ),
    );
  }

  /// Navigate to unified Connect Gateway screen
  void _navigateToConnectGateway(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectGatewayScreen(
          onConnected: () {
            _loadConfig();
          },
        ),
      ),
    );
  }

  /// Show dialog for connecting to remote gateway - Simplified to single entry point
  void _showConnectRemoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud, color: Colors.blue),
            SizedBox(width: 8),
            Text('Connect to Gateway'),
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
              _buildConnectionOption(
                'Find Gateway',
                'Auto-discover via LAN or Tailscale',
                Icons.wifi_find,
                () {
                  Navigator.pop(context);
                  _navigateToConnectGateway(context);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tip:',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-discovery will scan your network and Tailscale for available gateways.',
                      style: Theme.of(context).textTheme.bodySmall,
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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

  Widget _buildQuickStatsRow() {
    final agentCount = _status?.agents?.length ?? 0;
    final nodeCount = _status?.nodes?.length ?? 0;
    final isPaused = _status?.isPaused ?? false;
    
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Agents',
            '$agentCount',
            Icons.people,
            agentCount > 0 ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Nodes',
            '$nodeCount',
            Icons.devices,
            nodeCount > 0 ? Colors.blue : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Status',
            isPaused ? 'Paused' : 'Active',
            Icons.play_circle,
            isPaused ? Colors.orange : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    final cpuPercent = _status?.cpuPercent;
    final memoryPercent = _status?.memoryPercent;
    final hasAnySystemMetrics = cpuPercent != null || memoryPercent != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (cpuPercent != null)
              _buildHealthIndicator('CPU Usage', cpuPercent, Colors.green, Colors.orange, Colors.red)
            else
              _buildUnavailableHealthIndicator('CPU Usage'),
            const SizedBox(height: 12),
            if (memoryPercent != null)
              _buildHealthIndicator('Memory', memoryPercent, Colors.green, Colors.orange, Colors.red,
                  detail: _status?.formattedMemory)
            else
              _buildUnavailableHealthIndicator('Memory', detail: _status?.formattedMemory),
            if (!hasAnySystemMetrics) ...[
              const SizedBox(height: 12),
              Text(
                'This gateway is not currently exposing live CPU/memory stats, so the dashboard will show them as unavailable instead of fake 0% values.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String label, double percent, Color good, Color warn, Color error, {String? detail}) {
    final clampedPercent = percent.clamp(0.0, 100.0);
    final color = clampedPercent < 70 ? good : clampedPercent < 90 ? warn : error;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(
              '${clampedPercent.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedPercent / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableHealthIndicator(String label, {String? detail}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(
              'Unavailable',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton('Refresh', Icons.refresh, () => _refreshStatus()),
                _buildQuickActionButton('Settings', Icons.settings, () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                )),
                _buildQuickActionButton('Logs', Icons.list, () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                )),
                _buildQuickActionButton('Chat', Icons.chat, () {
                  // Pop to main screen - user can tap Chat tab
                  // This preserves the existing ChatScreen state
                  Navigator.pop(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
