import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/gateway_status.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  GatewayService? _service;
  GatewayStatus? _status;
  bool _loading = true;
  String? _error;
  
  // Hold to pause state
  double _holdProgress = 0.0;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
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

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    final isDangerous = title.contains('Stop') || title.contains('Kill') || title.contains('Pause');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isDangerous ? 'Confirm' : 'OK',
              style: TextStyle(color: isDangerous ? Colors.red : null),
            ),
          ),
        ],
      ),
    );
  }

  // Gateway Controls
  Future<void> _restartGateway() async {
    final confirm = await _showConfirmDialog(
      'Restart Gateway',
      'Are you sure you want to restart the gateway? This will briefly disconnect all agents.',
    );
    if (confirm != true) return;

    final result = await _service?.restartGateway('Manual restart from mobile app');
    if (result != null && result['success'] == true) {
      _showToast('Gateway restarting...');
      await Future.delayed(const Duration(seconds: 2));
      await _refreshStatus();
    } else {
      _showToast('Failed to restart gateway', isError: true);
    }
  }

  Future<void> _stopGateway() async {
    final confirm = await _showConfirmDialog(
      'Stop Gateway',
      'WARNING: This will completely stop the gateway. You will need to restart it manually.',
    );
    if (confirm != true) return;

    final result = await _service?.stopGateway('Manual stop from mobile app');
    if (result != null && result['success'] == true) {
      _showToast('Gateway stopping...');
      await _refreshStatus();
    } else {
      _showToast('Failed to stop gateway', isError: true);
    }
  }

  // Agent Controls
  Future<void> _killAgent(AgentInfo agent) async {
    final confirm = await _showConfirmDialog(
      'Kill Agent',
      'Are you sure you want to kill agent "${agent.name}"? Current task will be lost.',
    );
    if (confirm != true) return;

    // Extract session key from agent info
    final sessionKey = agent.name; // Using name as identifier
    final result = await _service?.killAgent(sessionKey);
    if (result != null && result['success'] == true) {
      _showToast('Agent ${agent.name} terminated');
      await _refreshStatus();
    } else {
      _showToast('Failed to kill agent', isError: true);
    }
  }

  // Node Controls
  Future<void> _reconnectNode(NodeInfo node) async {
    final result = await _service?.reconnectNode(node.name);
    if (result != null && result['success'] == true) {
      _showToast('Reconnection initiated for ${node.name}');
      await Future.delayed(const Duration(seconds: 2));
      await _refreshStatus();
    } else {
      _showToast('Failed to reconnect node', isError: true);
    }
  }

  // Cron Controls
  Future<void> _runCron(CronInfo cron) async {
    final result = await _service?.runCron(cron.name);
    if (result != null && result['success'] == true) {
      _showToast('${cron.name} started');
      await Future.delayed(const Duration(seconds: 1));
      await _refreshStatus();
    } else {
      _showToast('Failed to run cron', isError: true);
    }
  }

  Future<void> _toggleCron(CronInfo cron) async {
    final result = await _service?.toggleCron(cron.name, !cron.enabled);
    if (result != null && result['success'] == true) {
      _showToast('${cron.name} ${!cron.enabled ? 'enabled' : 'disabled'}');
      await _refreshStatus();
    } else {
      _showToast('Failed to toggle cron', isError: true);
    }
  }

  // Emergency Controls
  Future<void> _pauseAll() async {
    final result = await _service?.pauseAll(3);
    if (result != null && result['success'] == true) {
      _showToast('All automation paused');
      await _refreshStatus();
    } else {
      _showToast('Failed to pause', isError: true);
    }
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _resumeAll() async {
    final result = await _service?.resumeAll();
    if (result != null && result['success'] == true) {
      _showToast('All automation resumed');
      await _refreshStatus();
    } else {
      _showToast('Failed to resume', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Connection Error', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshStatus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildGatewayControls(),
                      const SizedBox(height: 16),
                      _buildAgentControls(),
                      const SizedBox(height: 16),
                      _buildNodeControls(),
                      const SizedBox(height: 16),
                      _buildCronControls(),
                      const SizedBox(height: 24),
                      _buildEmergencyControls(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGatewayControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns),
                const SizedBox(width: 8),
                Text('Gateway Controls', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            // Status indicator
            Row(
              children: [
                Icon(
                  _status?.online ?? false ? Icons.check_circle : Icons.error,
                  color: _status?.online ?? false ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _status?.online ?? false ? 'Gateway Online' : 'Gateway Offline',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('v${_status?.version ?? '?'}'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restartGateway,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _stopGateway,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentControls() {
    final agents = _status?.agents ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people),
                const SizedBox(width: 8),
                Text('Agents (${agents.length})', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (agents.isEmpty)
              const Text('No agents active')
            else
              ...agents.map((agent) => ListTile(
                    leading: Icon(
                      agent.status == 'active' ? Icons.play_circle : Icons.pause_circle,
                      color: agent.status == 'active' ? Colors.green : Colors.grey,
                    ),
                    title: Text(agent.name),
                    subtitle: Text(agent.currentTask ?? agent.status),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          onPressed: () {
                            _showToast('Session: ${agent.name}');
                          },
                          tooltip: 'View Session',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.red),
                          onPressed: () => _killAgent(agent),
                          tooltip: 'Kill Agent',
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeControls() {
    final nodes = _status?.nodes ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices),
                const SizedBox(width: 8),
                Text('Nodes (${nodes.length})', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (nodes.isEmpty)
              const Text('No nodes connected')
            else
              ...nodes.map((node) => ListTile(
                    leading: Icon(
                      node.status == 'connected' ? Icons.check_circle : Icons.error,
                      color: node.status == 'connected' ? Colors.green : Colors.orange,
                    ),
                    title: Text(node.name),
                    subtitle: Text('${node.connectionType ?? 'unknown'} ${node.ip != null ? '(${node.ip})' : ''}'),
                    trailing: node.status != 'connected'
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _reconnectNode(node),
                            tooltip: 'Reconnect',
                          )
                        : null,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildCronControls() {
    final crons = _status?.crons ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 8),
                Text('Cron Tasks (${crons.length})', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (crons.isEmpty)
              const Text('No scheduled tasks')
            else
              ...crons.map((cron) => ListTile(
                    leading: Icon(
                      cron.enabled ? Icons.schedule : Icons.pause,
                      color: cron.enabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(cron.name),
                    subtitle: Text('${cron.schedule} • ${cron.status ?? 'unknown'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: cron.enabled,
                          onChanged: (_) => _toggleCron(cron),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _runCron(cron),
                          tooltip: 'Run Now',
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyControls() {
    final isPaused = _status?.isPaused ?? false;
    
    return Card(
      color: Colors.red.shade900.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Emergency Controls',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPaused)
              Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pause_circle, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'SYSTEM PAUSED',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resumeAll,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('RESUME ALL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Text(
                    'Hold for 3 seconds to pause all automation',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onLongPressStart: (_) {
                      setState(() {
                        _isHolding = true;
                        _holdProgress = 0.0;
                      });
                    },
                    onLongPressEnd: (_) {
                      if (_holdProgress < 1.0) {
                        setState(() {
                          _isHolding = false;
                          _holdProgress = 0.0;
                        });
                        _showToast('Hold longer to confirm', isError: true);
                      }
                    },
                    onLongPress: _pauseAll,
                    child: Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isHolding ? Colors.white : Colors.red.shade300,
                          width: 3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Progress indicator
                          if (_isHolding)
                            FractionallySizedBox(
                              widthFactor: _holdProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          Center(
                            child: _isHolding
                                ? Text(
                                    'HOLDING... ${((1 - _holdProgress) * 3).toStringAsFixed(1)}s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : const Text(
                                    'PAUSE ALL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}