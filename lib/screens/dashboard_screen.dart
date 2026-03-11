import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/gateway_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/local_metrics_service.dart';
import '../models/gateway_status.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/connection_status_icon.dart';
import '../widgets/gateway_status_card.dart';
import '../widgets/agent_visualization_widget.dart';
import 'agent_library_screen.dart';
import 'settings_screen.dart';
import 'connect_gateway_screen.dart';
import 'logs_screen.dart';
import 'chat_screen.dart';
import 'termux_screen.dart';
import 'agent_monitor_screen.dart';
import 'autowork_screen.dart';
import 'local_installer_screen.dart';
import 'node_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final GatewayService? gatewayService;
  final VoidCallback? onGatewayChanged;
  final VoidCallback? onOpenChat;

  const DashboardScreen({
    super.key,
    this.gatewayService,
    this.onGatewayChanged,
    this.onOpenChat,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  GatewayService? _service;
  GatewayStatus? _status;
  LocalMetrics? _localMetrics;
  LocalRuntimeStatus? _runtimeStatus;
  bool _loading = true;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _autoRefreshTimer;
  String? _gatewayName;
  ConnectionStatus _lastConnectionStatus = ConnectionStatus.disconnected;
  bool _hasShownLostNotification = false;
  bool _isLocalInstall = false;
  final LocalMetricsService _localMetricsService = LocalMetricsService();

  @override
  void initState() {
    super.initState();
    _initializeLocalMetrics();
    _loadConfig();
    // Listen for connection status changes
    connectionMonitor.addListener(_onConnectionStatusChanged);
    // Auto-refresh every 30 seconds
    _autoRefreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshStatus());
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final gatewayChanged =
        oldWidget.gatewayService?.baseUrl != widget.gatewayService?.baseUrl ||
            oldWidget.gatewayService?.token != widget.gatewayService?.token;

    if (gatewayChanged) {
      unawaited(_loadConfig());
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    connectionMonitor.removeListener(_onConnectionStatusChanged);
    _localMetricsService.dispose();
    super.dispose();
  }

  Future<void> _initializeLocalMetrics() async {
    try {
      await _localMetricsService.initialize();
    } catch (_) {
      // Best-effort only; dashboard falls back to gateway status.
    }
  }

  void _onConnectionStatusChanged() {
    final state = connectionMonitor.state;

    // Show SnackBar when connection is lost (only once per disconnection)
    if (state.isDisconnected || state.hasError) {
      if (_lastConnectionStatus == ConnectionStatus.connected &&
          !_hasShownLostNotification) {
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
    final prefs = await SharedPreferences.getInstance();
    _gatewayName = prefs.getString('gateway_name');

    // Use passed service or create new one from stored settings
    if (widget.gatewayService != null) {
      setState(() {
        _service = widget.gatewayService;
        _loading = true;
      });

      _localMetricsService.setGatewayUrl(widget.gatewayService!.baseUrl);
      _checkLocalInstall();

      // Start connection monitoring
      connectionMonitor.startMonitoring(
        widget.gatewayService!,
        gatewayName: _gatewayName,
      );

      await _refreshStatus();
      return;
    }

    // Fallback to loading from preferences
    final gatewayUrl =
        prefs.getString('gateway_url') ?? 'http://localhost:18789';
    final token = prefs.getString('gateway_token');
    _gatewayName = prefs.getString('gateway_name');

    setState(() {
      _service = GatewayService(baseUrl: gatewayUrl, token: token);
      _loading = true;
    });

    _localMetricsService.setGatewayUrl(gatewayUrl);
    _checkLocalInstall();

    // Start connection monitoring
    connectionMonitor.startMonitoring(
      _service!,
      gatewayName: _gatewayName,
    );

    await _refreshStatus();
  }

  void _checkLocalInstall() {
    final url = _service?.baseUrl ?? '';
    _isLocalInstall = url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.startsWith('http://192.168.') ||
        url.startsWith('http://10.') ||
        url.startsWith('http://172.');
  }

  Future<void> _refreshStatus() async {
    if (_service == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      GatewayStatus? status;
      LocalMetrics? localMetrics;
      LocalRuntimeStatus? runtimeStatus;

      if (_isLocalInstall) {
        try {
          final results = await Future.wait<dynamic>([
            _localMetricsService.getMetrics(forceRefresh: true),
            _localMetricsService.getRuntimeStatus(),
          ]);

          localMetrics = results[0] as LocalMetrics;
          runtimeStatus = results[1] as LocalRuntimeStatus;

          if (localMetrics.isAvailable && localMetrics.gatewayStatus != null) {
            status = localMetrics.gatewayStatus;
          }
        } catch (_) {
          // Fall back to direct gateway fetch below.
        }
      }

      status ??= await _service!.getStatus();

      setState(() {
        _localMetrics = localMetrics;
        _runtimeStatus = runtimeStatus;
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
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
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
                              if (_isLocalInstall &&
                                  _localMetrics?.source != null) ...[
                                Icon(Icons.memory,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Local ${_localMetrics!.source}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Updated ${_getTimeAgo(_lastRefresh!)}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      // Quick Stats Row
                      _buildQuickStatsRow(),
                      const SizedBox(height: 16),

                      // Enhanced Gateway Status Card
                      GatewayStatusCard(
                        status: _status,
                        liveStats: _buildGatewayLiveStats(),
                        lastRefresh: _lastRefresh,
                        onRefresh: _refreshStatus,
                      ),
                      const SizedBox(height: 16),

                      _buildWorkloadCard(),
                      const SizedBox(height: 16),

                      if (_isLocalInstall) ...[
                        _buildLocalRuntimeCard(),
                        const SizedBox(height: 16),
                      ],

                      // Agent Visualization
                      AgentVisualizationWidget(
                        gatewayService: _service,
                        gatewayStatus: _status,
                        onTap: () => _navigateToAgentMonitor(),
                      ),
                      const SizedBox(height: 16),
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

  void _navigateToAgentMonitor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentMonitorScreen(gatewayService: _service),
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
            Text('Nodes (${nodes.length})',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (nodes.isEmpty)
              const Text('No nodes connected')
            else
              ...nodes.map((node) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          node.status == 'connected'
                              ? Icons.check_circle
                              : Icons.error,
                          color: node.status == 'connected'
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(node.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${node.connectionType ?? 'unknown'} ${node.ip != null ? '(${node.ip})' : ''}',
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
            widget.onGatewayChanged?.call();
          },
        ),
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

  Widget _buildQuickStatCard(
      String label, String value, IconData icon, Color color) {
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

  Map<String, dynamic> _buildGatewayLiveStats() {
    final agents = _status?.agents ?? [];
    final activeAgents = agents
        .where((agent) => agent.isActive || agent.status == 'active')
        .length;
    final totalTokens =
        agents.fold<int>(0, (sum, agent) => sum + (agent.totalTokens ?? 0));

    return {
      'totalAgents': agents.length,
      'activeAgents': activeAgents,
      'totalTokens': totalTokens,
    };
  }

  Widget _buildWorkloadCard() {
    final stats = _buildGatewayLiveStats();
    final totalAgents = stats['totalAgents'] as int? ?? 0;
    final activeAgents = stats['activeAgents'] as int? ?? 0;
    final totalTokens = stats['totalTokens'] as int? ?? 0;
    final nodeCount = _status?.nodes?.length ?? 0;
    final metricsSource = _localMetrics?.source;
    final fetchedAt = _localMetrics?.fetchedAt;
    final helperRunning = _runtimeStatus?.helperRunning == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Workload',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_status?.isPaused == true)
                  _buildMetaChip(
                    Icons.pause_circle_outline,
                    'Paused',
                    foreground: Colors.orange.shade800,
                    background: Colors.orange.shade100,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                  Icons.people_alt_outlined,
                  '$totalAgents sessions',
                ),
                _buildMetaChip(
                  Icons.play_circle_outline,
                  '$activeAgents active',
                  foreground: activeAgents > 0
                      ? Colors.green.shade700
                      : Colors.grey[800],
                  background: activeAgents > 0
                      ? Colors.green.withValues(alpha: 0.10)
                      : null,
                ),
                _buildMetaChip(Icons.hub_outlined, '$nodeCount nodes'),
                _buildMetaChip(
                  helperRunning ? Icons.memory : Icons.router_outlined,
                  helperRunning
                      ? 'Helper + gateway'
                      : _isLocalInstall
                          ? 'Gateway direct'
                          : 'Remote gateway',
                ),
                if (metricsSource != null)
                  _buildMetaChip(Icons.bolt_outlined, 'Source: $metricsSource'),
                if (fetchedAt != null)
                  _buildMetaChip(
                    Icons.schedule,
                    'Sampled ${_getTimeAgo(fetchedAt)}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildWorkloadRow(
              'Chat readiness',
              activeAgents > 0
                  ? 'Primary sessions are available for direct chat.'
                  : 'Gateway is online, but no active sessions are attached yet.',
              activeAgents > 0 ? Colors.green : Colors.orange,
              activeAgents > 0 ? Icons.mark_chat_read : Icons.mark_chat_unread,
            ),
            const SizedBox(height: 10),
            _buildWorkloadRow(
              'Tool traffic',
              totalTokens > 0
                  ? '${_formatCompactNumber(totalTokens)} tokens visible in live session data.'
                  : 'No token flow reported yet from the current sessions.',
              totalTokens > 0 ? Colors.deepOrange : Colors.blueGrey,
              totalTokens > 0
                  ? Icons.local_fire_department_outlined
                  : Icons.insights_outlined,
            ),
            const SizedBox(height: 10),
            _buildWorkloadRow(
              'Runtime path',
              _isLocalInstall
                  ? 'This device can run OpenClaw locally in Termux or connect to a remote gateway.'
                  : 'This app is connected to a remote OpenClaw gateway.',
              Theme.of(context).colorScheme.primary,
              _isLocalInstall ? Icons.phone_android : Icons.cloud_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    IconData icon,
    String label, {
    Color? foreground,
    Color? background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            background ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground ?? Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground ?? Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalRuntimeCard() {
    final runtime = _runtimeStatus;
    if (!_isLocalInstall || runtime == null) {
      return const SizedBox.shrink();
    }

    final readiness = runtime.readiness;
    final blockingCount = readiness?.blockingIssues.length ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.developer_mode,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Runtime',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  'Checked ${_getTimeAgo(runtime.checkedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRuntimeStatusRow(
              'Gateway',
              runtime.gatewayRunning,
              detail: runtime.gatewayLatencyMs != null
                  ? '${runtime.gatewayLatencyMs}ms'
                  : runtime.gatewayError ?? 'Unavailable',
            ),
            const SizedBox(height: 8),
            _buildRuntimeStatusRow(
              'Metrics Helper',
              runtime.helperRunning,
              detail: runtime.helperLatencyMs != null
                  ? '${runtime.helperLatencyMs}ms'
                  : runtime.helperError ?? 'Not running',
            ),
            const SizedBox(height: 8),
            _buildRuntimeStatusRow(
              'Termux',
              runtime.termuxInstalled,
              detail: runtime.termuxInstalled
                  ? (runtime.termuxApiInstalled
                      ? 'API installed'
                      : 'API missing')
                  : 'Install from F-Droid or GitHub',
            ),
            const SizedBox(height: 8),
            _buildRuntimeStatusRow(
              'RUN_COMMAND',
              runtime.runCommandPermissionGranted,
              detail: runtime.runCommandPermissionGranted
                  ? 'Granted'
                  : 'Grant in app settings',
            ),
            if (readiness != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: blockingCount == 0
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  readiness.readinessText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: blockingCount == 0
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocalInstallerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.build_circle_outlined),
                    label: Text(blockingCount == 0 ? 'Manage' : 'Repair'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermuxScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.terminal),
                    label: const Text('Termux'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeStatusRow(String label, bool isHealthy,
      {String? detail}) {
    final color = isHealthy ? Colors.green : Colors.orange;
    return Row(
      children: [
        Icon(
          isHealthy ? Icons.check_circle : Icons.error_outline,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (detail != null)
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
          ),
      ],
    );
  }

  Widget _buildWorkloadRow(
    String title,
    String body,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[800],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
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
                Icon(Icons.flash_on,
                    color: Theme.of(context).colorScheme.primary),
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
                _buildQuickActionButton(
                    'Refresh', Icons.refresh, () => _refreshStatus()),
                _buildQuickActionButton(
                    'Agents', Icons.people, () => _navigateToAgentMonitor()),
                _buildQuickActionButton('Chat', Icons.chat, () {
                  if (widget.onOpenChat != null) {
                    widget.onOpenChat!();
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(gatewayService: _service)),
                  );
                }),
                _buildQuickActionButton(
                    'Logs',
                    Icons.list,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LogsScreen()),
                        )),
                _buildQuickActionButton(
                    'Autowork',
                    Icons.auto_awesome_motion,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  AutoworkScreen(gatewayService: _service)),
                        )),
                _buildQuickActionButton(
                    'Agents Setup',
                    Icons.psychology_alt,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AgentLibraryScreen()),
                        )),
                _buildQuickActionButton(
                    'Nodes Setup',
                    Icons.hub,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const NodeSettingsScreen()),
                        )),
                _buildQuickActionButton('Connect', Icons.link,
                    () => _navigateToConnectGateway(context)),
                _buildQuickActionButton(
                    'Runtime',
                    Icons.developer_mode,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const LocalInstallerScreen()),
                        )),
                _buildQuickActionButton(
                    'Settings',
                    Icons.settings,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    final agentCount = _status?.agents?.length ?? 0;
    final nodeCount = _status?.nodes?.length ?? 0;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.dns,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'OpenClaw Mobile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  _gatewayName ?? 'Dashboard',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),

          // Navigation items
          ListTile(
            leading:
                Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.people,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Agent Monitor'),
            subtitle: agentCount > 0 ? Text('$agentCount agents') : null,
            onTap: () {
              Navigator.pop(context);
              _navigateToAgentMonitor();
            },
          ),
          ListTile(
            leading:
                Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
            title: const Text('Chat'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ChatScreen(gatewayService: _service)),
              );
            },
          ),
          ListTile(
            leading:
                Icon(Icons.list, color: Theme.of(context).colorScheme.primary),
            title: const Text('Logs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.phone_android,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Termux'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermuxScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.devices,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Nodes ($nodeCount)'),
            onTap: () {
              Navigator.pop(context);
              _showNodesDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.settings,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNodesDialog() {
    final nodes = _status?.nodes ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.devices),
            SizedBox(width: 8),
            Text('Connected Nodes'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: nodes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No nodes connected',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    return ListTile(
                      leading: Icon(
                        node.status == 'connected'
                            ? Icons.check_circle
                            : Icons.error,
                        color: node.status == 'connected'
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(node.name),
                      subtitle: Text(
                          '${node.connectionType ?? 'unknown'} ${node.ip != null ? '(${node.ip})' : ''}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
