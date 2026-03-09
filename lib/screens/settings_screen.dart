import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';
import '../services/discovery_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function()? onGatewayChanged;

  const SettingsScreen({super.key, this.onGatewayChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscoveryService _discoveryService = DiscoveryService();

  // Manual entry controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  // UI state
  bool _saving = false;
  String? _savedMessage;
  bool _testing = false;
  String? _testResult;
  bool _scanning = false;
  List<GatewayConnection> _discovered = [];
  List<GatewayConnection> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _urlController = TextEditingController();
    _portController = TextEditingController(text: '18789');
    _tokenController = TextEditingController();

    _loadSettings();
    _loadHistory();
    _startDiscovery();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('gateway_url') ?? 'http://localhost:18789';

    // Parse URL to extract host and port
    final uri = Uri.tryParse(url);
    if (uri != null) {
      setState(() {
        _urlController.text = uri.host;
        _portController.text = uri.port.toString();
      });
    } else {
      setState(() {
        _urlController.text = 'localhost';
        _portController.text = '18789';
      });
    }
    _tokenController.text = prefs.getString('gateway_token') ?? '';
  }

  Future<void> _loadHistory() async {
    final history = await _discoveryService.getHistory();
    setState(() {
      _history = history;
    });
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _scanning = true;
    });

    _discoveryService.startBackgroundScan();

    _discoveryService.discoveredGateways.listen((gateways) {
      if (mounted) {
        setState(() {
          _discovered = gateways;
          _scanning = false;
        });
      }
    });

    // Initial scan
    final found = await _discoveryService.scan();
    if (mounted) {
      setState(() {
        _discovered = found;
        _scanning = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _savedMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final url = 'http://${_urlController.text}:${_portController.text}';
      await prefs.setString('gateway_url', url);
      await prefs.setString('gateway_token', _tokenController.text);

      // Save to history
      final gateway = GatewayConnection(
        name: _urlController.text,
        url: url,
        ip: _urlController.text,
        port: int.parse(_portController.text),
        token: _tokenController.text.isNotEmpty ? _tokenController.text : null,
      );
      await _discoveryService.saveToHistory(gateway);
      await _loadHistory();

      setState(() {
        _saving = false;
        _savedMessage = 'Settings saved!';
      });

      widget.onGatewayChanged?.call();

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _savedMessage = 'Error: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final gateway = GatewayConnection(
        name: _urlController.text,
        url: 'http://${_urlController.text}:${_portController.text}',
        ip: _urlController.text,
        port: int.parse(_portController.text),
        token: _tokenController.text.isNotEmpty ? _tokenController.text : null,
      );

      final success = await _discoveryService.testConnection(gateway);

      setState(() {
        _testing = false;
        _testResult = success
            ? '✓ Connection successful!'
            : '✗ Connection failed';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = '✗ Error: $e';
      });
    }
  }

  Future<void> _connectToGateway(GatewayConnection gateway) async {
    // Parse URL to populate fields
    final uri = Uri.tryParse(gateway.url);
    if (uri != null) {
      setState(() {
        _urlController.text = uri.host;
        _portController.text = uri.port.toString();
        if (gateway.token != null) {
          _tokenController.text = gateway.token!;
        }
      });
    }

    // Save and connect
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gateway_url', gateway.url);
    if (gateway.token != null) {
      await prefs.setString('gateway_token', gateway.token!);
    }

    await _discoveryService.saveToHistory(gateway);
    await _loadHistory();

    widget.onGatewayChanged?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${gateway.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _removeFromHistory(String url) async {
    await _discoveryService.removeFromHistory(url);
    await _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateway Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi_find), text: 'Discover'),
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildManualTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Scanning indicator
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              if (_scanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.wifi, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _scanning
                      ? 'Scanning for OpenClaw gateways...'
                      : '${_discovered.length} gateway(s) found on network',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _startDiscovery,
                tooltip: 'Scan again',
              ),
            ],
          ),
        ),

        // Discovered gateways list
        Expanded(
          child: _discovered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_find,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No gateways found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure your gateway is running\nand on the same network',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _discovered.length,
                  itemBuilder: (context, index) {
                    final gateway = _discovered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.dns),
                        ),
                        title: Text(gateway.name ?? gateway.displayName),
                        subtitle: Text(gateway.url),
                        trailing: ElevatedButton(
                          onPressed: () => _connectToGateway(gateway),
                          child: const Text('Connect'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your gateway details manually if discovery is not working',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // IP/Hostname field
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'IP Address / Hostname',
                hintText: '192.168.1.100 or localhost',
                prefixIcon: Icon(Icons.computer),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter IP address or hostname';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Port field
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '18789',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter port';
                }
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Please enter a valid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Token field
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Gateway Token (optional)',
                hintText: 'Enter token if required',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // Test connection button
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),

            // Test result
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.startsWith('✓')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Save button
            if (_savedMessage != null)
              Text(
                _savedMessage!,
                style: TextStyle(
                  color: _savedMessage!.startsWith('Error')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save & Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No connection history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your recently connected gateways will appear here',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final gateway = _history[index];
        final lastConnected = gateway.lastConnected;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.history),
            ),
            title: Text(gateway.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gateway.url),
                if (lastConnected != null)
                  Text(
                    'Last connected: ${_formatDate(lastConnected)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            isThreeLine: lastConnected != null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeFromHistory(gateway.url),
                  tooltip: 'Remove from history',
                ),
                ElevatedButton(
                  onPressed: () => _connectToGateway(gateway),
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}