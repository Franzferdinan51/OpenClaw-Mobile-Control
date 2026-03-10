import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';
import '../services/discovery_service.dart';
import '../services/tailscale_service.dart';
import '../services/app_settings_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/gateway_service.dart';
import '../widgets/connection_status_icon.dart';
import 'node_settings_screen.dart';

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
  final DiscoveryService _discoveryService = DiscoveryService();
  final TailscaleService _tailscaleService = TailscaleService();
  final AppSettingsService _appSettings = AppSettingsService();

  // Manual entry controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  // Tailscale entry
  final _tailscaleController = TextEditingController();
  final _tailscaleNameController = TextEditingController();
  bool _tailscaleRunning = false;
  List<GatewayConnection> _tailscaleGateways = [];
  List<GatewayConnection> _discoveredTailscaleGateways = [];
  bool _discovering = false;

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
    _tabController = TabController(length: 6, vsync: this); // App, Node, Discover, Manual, History, Tailscale
    _urlController = TextEditingController();
    _portController = TextEditingController(text: '18789');
    _tokenController = TextEditingController();

    // Initialize app settings service first
    _initializeAppSettings();

    _loadSettings();
    _loadHistory();
    _checkTailscale();
    _startDiscovery();
  }

  Future<void> _initializeAppSettings() async {
    await AppSettingsService.initialize();
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _checkTailscale() async {
    final isRunning = await _tailscaleService.isTailscaleRunning();
    final gateways = await _tailscaleService.getSavedTailscaleGateways();
    
    if (mounted) {
      setState(() {
        _tailscaleRunning = isRunning;
        _tailscaleGateways = gateways;
      });
    }
  }

  Future<void> _discoverTailscaleGateways() async {
    if (!_tailscaleRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tailscale is not running. Please connect to Tailscale first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _discovering = true;
      _discoveredTailscaleGateways = [];
    });

    try {
      final discovered = await _tailscaleService.discoverTailscaleGateways();

      if (mounted) {
        setState(() {
          _discoveredTailscaleGateways = discovered;
          _discovering = false;
        });

        if (discovered.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No Tailscale gateways found. Try manual entry.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${discovered.length} Tailscale gateway(s)!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _discovering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovery error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _addTailscaleGateway() async {
    if (_tailscaleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Tailscale URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final gateway = TailscaleService.parseTailscaleUrl(
        _tailscaleController.text,
        name: _tailscaleNameController.text.isNotEmpty
            ? _tailscaleNameController.text
            : null,
      );

      if (gateway == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Tailscale URL. Must be 100.x.x.x or *.ts.net'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Test connection
      final success = await _discoveryService.testConnection(gateway);
      if (!success) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to Tailscale gateway'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save Tailscale gateway
      await _tailscaleService.saveTailscaleGateway(gateway);
      await _checkTailscale();

      // Clear controllers
      _tailscaleController.clear();
      _tailscaleNameController.clear();

      setState(() => _saving = false);

      // Connect
      await _connectToGateway(gateway);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeTailscaleGateway(String url) async {
    await _tailscaleService.removeTailscaleGateway(url);
    await _checkTailscale();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _tailscaleController.dispose();
    _tailscaleNameController.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'App'),
            Tab(icon: Icon(Icons.router), text: 'Node'),
            Tab(icon: Icon(Icons.wifi_find), text: 'Discover'),
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.vpn_lock), text: 'Tailscale'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppSettingsTab(),
          const NodeSettingsScreen(),
          _buildDiscoverTab(),
          _buildManualTab(),
          _buildHistoryTab(),
          _buildTailscaleTab(),
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
                onPressed: () async {
                  setState(() => _scanning = true);
                  final found = await _discoveryService.scan();
                  if (mounted) {
                    setState(() {
                      _discovered = found;
                      _scanning = false;
                    });
                  }
                },
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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.edit),
                        label: const Text('Enter Manually'),
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
                          backgroundColor: Colors.green,
                          child: Icon(Icons.dns, color: Colors.white),
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

  Widget _buildTailscaleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tailscale status card
          Card(
            color: _tailscaleRunning 
                ? Colors.green.withOpacity(0.1) 
                : Colors.orange.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _tailscaleRunning ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                    color: _tailscaleRunning ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tailscaleRunning 
                              ? 'Tailscale Connected' 
                              : 'Tailscale Not Detected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _tailscaleRunning
                              ? 'You can connect to Tailscale gateways'
                              : 'Connect to Tailscale VPN first',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Discover Gateways Button
          ElevatedButton.icon(
            onPressed: _discovering ? null : _discoverTailscaleGateways,
            icon: _discovering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_discovering ? 'Discovering...' : 'Discover Tailscale Gateways'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),

          // Add Tailscale gateway manually
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Manual Entry',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter Tailscale IP or URL manually',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _tailscaleController,
                    decoration: const InputDecoration(
                      labelText: 'Tailscale URL',
                      hintText: 'http://100.x.x.x:18789',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _tailscaleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      hintText: 'Home Server',
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _saving ? null : _addTailscaleGateway,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_saving ? 'Connecting...' : 'Add & Connect'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Discovered Tailscale gateways
          if (_discoveredTailscaleGateways.isNotEmpty) ...[
            Text(
              'Discovered Gateways',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            ...(_discoveredTailscaleGateways.map((gateway) => Card(
              color: Colors.green.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.wifi, color: Colors.white),
                ),
                title: Text(gateway.displayName),
                subtitle: Text(gateway.url),
                trailing: ElevatedButton(
                  onPressed: () => _connectToGateway(gateway),
                  child: const Text('Connect'),
                ),
              ),
            ))),
            const SizedBox(height: 24),
          ],

          // Saved Tailscale gateways
          if (_tailscaleGateways.isNotEmpty) ...[
            Text(
              'Saved Tailscale Gateways',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...(_tailscaleGateways.map((gateway) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.vpn_lock, color: Colors.white),
                ),
                title: Text(gateway.displayName),
                subtitle: Text(gateway.url),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeTailscaleGateway(gateway.url),
                      tooltip: 'Remove',
                    ),
                    ElevatedButton(
                      onPressed: () => _connectToGateway(gateway),
                      child: const Text('Connect'),
                    ),
                  ],
                ),
              ),
            ))),
          ],
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette),
                          const SizedBox(width: 8),
                          Text(
                            'Theme',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _appSettings.theme,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System Default')),
                          DropdownMenuItem(value: 'light', child: Text('Light')),
                          DropdownMenuItem(value: 'dark', child: Text('Dark')),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            await _appSettings.setTheme(value);
                          }
                        },
                      ),
                    ],
                  ),
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
                      'Version 2.0.1',
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
                        label: const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Disconnect and go to discovery
                          connectionMonitor.disconnect();
                          _tabController.animateTo(1); // Go to Discover tab
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Go to discovery to change gateway
                      _tabController.animateTo(1);
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change Gateway'),
                  ),
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