import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../services/discovery_service.dart';
import '../models/gateway_status.dart';

/// Quick connect widget for fast gateway connection
class QuickConnectWidget extends StatefulWidget {
  final Function(GatewayService)? onConnected;
  final VoidCallback? onConfigure;

  const QuickConnectWidget({
    super.key,
    this.onConnected,
    this.onConfigure,
  });

  @override
  State<QuickConnectWidget> createState() => _QuickConnectWidgetState();
}

class _QuickConnectWidgetState extends State<QuickConnectWidget> {
  final DiscoveryService _discoveryService = DiscoveryService();
  GatewayService? _gatewayService;
  List<GatewayConnection> _discoveredGateways = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _lastGatewayUrl;
  String? _lastGatewayName;

  @override
  void initState() {
    super.initState();
    _loadLastGateway();
  }

  Future<void> _loadLastGateway() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastGatewayUrl = prefs.getString('gateway_url');
      _lastGatewayName = prefs.getString('gateway_name');
    });
  }

  Future<void> _scanForGateways() async {
    setState(() => _isScanning = true);

    try {
      final gateways = await _discoveryService.scan();
      setState(() {
        _discoveredGateways = gateways;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToGateway(GatewayConnection gateway) async {
    setState(() => _isConnecting = true);

    try {
      final service = GatewayService(baseUrl: gateway.url);
      final status = await service.getStatus();

      if (status?.online == true) {
        // Save as last gateway
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gateway_url', gateway.url);
        await prefs.setString('gateway_name', gateway.displayName);

        setState(() {
          _lastGatewayUrl = gateway.url;
          _lastGatewayName = gateway.displayName;
          _isConnecting = false;
        });

        widget.onConnected?.call(service);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Connected to ${gateway.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Gateway is offline');
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToLastGateway() async {
    if (_lastGatewayUrl == null) return;

    setState(() => _isConnecting = true);

    try {
      final service = GatewayService(baseUrl: _lastGatewayUrl!);
      final status = await service.getStatus();

      if (status?.online == true) {
        setState(() {
          _gatewayService = service;
          _isConnecting = false;
        });

        widget.onConnected?.call(service);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Connected to $_lastGatewayName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Gateway is offline');
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Connect',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isScanning ? null : _scanForGateways,
                  tooltip: 'Scan for gateways',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Last connected gateway
            if (_lastGatewayUrl != null) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: Colors.blue),
                ),
                title: Text(_lastGatewayName ?? 'Last Gateway'),
                subtitle: Text(
                  _lastGatewayUrl!,
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: ElevatedButton(
                  onPressed: _isConnecting ? null : _connectToLastGateway,
                  child: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ),
              const Divider(),
            ],

            // Discovered gateways
            if (_discoveredGateways.isEmpty) ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.wifi_find,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning ? 'Scanning...' : 'Tap scan to find gateways',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Discovered Gateways',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _discoveredGateways.length,
                itemBuilder: (context, index) {
                  final gateway = _discoveredGateways[index];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.wifi, color: Colors.green, size: 20),
                    ),
                    title: Text(gateway.displayName),
                    subtitle: Text(
                      gateway.url,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _isConnecting
                          ? null
                          : () => _connectToGateway(gateway),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),

            // Manual configuration
            OutlinedButton.icon(
              onPressed: widget.onConfigure,
              icon: const Icon(Icons.settings),
              label: const Text('Configure Manually'),
            ),
          ],
        ),
      ),
    );
  }
}