import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/gateway_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
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
}
