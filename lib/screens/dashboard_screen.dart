import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/gateway_status.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // Use passed service or create new one from stored settings
    if (widget.gatewayService != null) {
      setState(() {
        _service = widget.gatewayService;
        _loading = true;
      });
      await _refreshStatus();
      return;
    }

    // Fallback to loading from preferences
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
    final token = prefs.getString('gateway_token');

    setState(() {
      _service = GatewayService(baseUrl: gatewayUrl, token: token);
      _loading = true;
    });

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
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw Mobile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
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
                      _buildGatewayCard(),
                      const SizedBox(height: 16),
                      _buildAgentsCard(),
                      const SizedBox(height: 16),
                      _buildNodesCard(),
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
              _buildInfoRow('Version', status.version),
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
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
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
            
            // Option 2: Connect to Remote
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () => _showConnectRemoteDialog(context),
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
            
            // Quick actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('Manual Setup'),
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
              Navigator.pushNamed(context, '/termux');
            },
            icon: const Icon(Icons.download),
            label: const Text('Start Installation'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for connecting to remote gateway
  void _showConnectRemoteDialog(BuildContext context) {
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
                'Local Network',
                'Auto-discover gateways on your WiFi',
                Icons.wifi,
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              const SizedBox(height: 8),
              _buildConnectionOption(
                'Manual Entry',
                'Enter gateway IP and port manually',
                Icons.edit,
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              const SizedBox(height: 8),
              _buildConnectionOption(
                'Tailscale',
                'Connect via Tailscale private network',
                Icons.security,
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
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
                      'Auto-discovery will scan your network for available gateways.',
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
              Navigator.pushNamed(context, '/settings');
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
