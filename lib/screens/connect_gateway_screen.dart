import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';
import '../services/discovery_service.dart';
import '../services/tailscale_service.dart';
import '../services/connection_monitor_service.dart';

// ScanProgress is defined in discovery_service.dart

/// Unified gateway connection screen
/// Combines LAN auto-discovery, Tailscale discovery, and manual entry
class ConnectGatewayScreen extends StatefulWidget {
  final Function()? onConnected;

  const ConnectGatewayScreen({super.key, this.onConnected});

  @override
  State<ConnectGatewayScreen> createState() => _ConnectGatewayScreenState();
}

class _ConnectGatewayScreenState extends State<ConnectGatewayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscoveryService _discoveryService = DiscoveryService();
  final TailscaleService _tailscaleService = TailscaleService();

  // Discovery state
  bool _isScanning = false;
  bool _tailscaleScanning = false;
  List<GatewayConnection> _lanGateways = [];
  List<GatewayConnection> _tailscaleGateways = [];
  List<GatewayConnection> _history = [];
  bool _tailscaleRunning = false;

  // Debug logs state
  bool _showDebugLogs = false;
  List<DiscoveryLogEntry> _logs = [];
  late StreamSubscription<List<DiscoveryLogEntry>> _logsSubscription;
  final ScrollController _logsScrollController = ScrollController();

  // Scan progress state
  ScanProgress _scanProgress = ScanProgress(percent: 0, scanned: 0, total: 0, status: 'Idle');
  late StreamSubscription<ScanProgress> _progressSubscription;

  // Manual entry controllers
  final _manualFormKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _testingManual = false;
  Map<String, dynamic>? _manualTestResult;

  // Connection state
  bool _connecting = false;
  String? _connectionError;
  String? _connectionErrorDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
    _checkTailscale();
    _startDiscovery();
    _subscribeToLogs();
    _subscribeToProgress();
  }

  void _subscribeToProgress() {
    _progressSubscription = _discoveryService.scanProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _scanProgress = progress;
        });
      }
    });
  }

  void _subscribeToLogs() {
    _logsSubscription = _discoveryService.logs.listen((logs) {
      if (mounted) {
        setState(() {
          _logs = logs;
        });
        // Auto-scroll to bottom if debug logs are visible
        if (_showDebugLogs && _logsScrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _logsScrollController.animateTo(
              _logsScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        }
      }
    });
  }

  Future<void> _loadHistory() async {
    final history = await _discoveryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _checkTailscale() async {
    final isRunning = await _tailscaleService.isTailscaleRunning();
    if (mounted) {
      setState(() {
        _tailscaleRunning = isRunning;
      });
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isScanning = true;
    });

    // Listen for discovered gateways
    _discoveryService.discoveredGateways.listen((gateways) {
      if (mounted) {
        setState(() {
          _lanGateways = gateways;
        });

        // Show prompt if new gateway found and we're on the auto tab
        if (gateways.isNotEmpty && _tabController.index == 0) {
          _showGatewayFoundNotification(gateways.first);
        }
      }
    });

    // Start background scanning
    _discoveryService.startBackgroundScan();

    // Initial scan
    final found = await _discoveryService.scan();
    if (mounted) {
      setState(() {
        _lanGateways = found;
        _isScanning = false;
      });
    }
  }

  Future<void> _scanTailscale() async {
    if (!_tailscaleRunning) {
      _showTailscaleNotRunningDialog();
      return;
    }

    setState(() {
      _tailscaleScanning = true;
    });

    try {
      final found = await _tailscaleService.discoverTailscaleGateways();

      if (mounted) {
        setState(() {
          _tailscaleGateways = found;
          _tailscaleScanning = false;
        });

        if (found.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No Tailscale gateways found. Try manual entry.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${found.length} Tailscale gateway(s)!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tailscaleScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tailscale discovery error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTailscaleNotRunningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Tailscale Not Connected'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tailscale VPN is not currently running on this device.'),
            SizedBox(height: 12),
            Text('To connect via Tailscale:'),
            SizedBox(height: 8),
            Text('1. Install the Tailscale app'),
            Text('2. Sign in to your tailnet'),
            Text('3. Connect to Tailscale VPN'),
            Text('4. Return to this app and try again'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGatewayFoundNotification(GatewayConnection gateway) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔍 Found: ${gateway.name}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'CONNECT',
          textColor: Colors.white,
          onPressed: () => _showConnectionDialog(gateway),
        ),
      ),
    );
  }

  Future<void> _showConnectionDialog(GatewayConnection gateway) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.wifi_find, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Connect to Gateway?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An OpenClaw gateway was discovered:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gateway.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gateway.url,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('CONNECT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _connectToGateway(gateway);
    }
  }

  Future<void> _connectToGateway(GatewayConnection gateway) async {
    setState(() {
      _connecting = true;
      _connectionError = null;
      _connectionErrorDetails = null;
    });

    try {
      // Test connection first with detailed diagnostics
      final testResult = await _discoveryService.testConnection(gateway);

      if (!testResult['success']) {
        setState(() {
          _connecting = false;
          _connectionError = testResult['error'] ?? 'Could not connect to gateway';
          _connectionErrorDetails = testResult['details'];
        });
        _showDetailedErrorDialog();
        return;
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gateway_url', gateway.url);
      if (gateway.token != null) {
        await prefs.setString('gateway_token', gateway.token!);
      }

      // Save to history
      await _discoveryService.saveToHistory(gateway);

      // Update connection monitor
      await connectionMonitor.connect(gateway.url, token: gateway.token);

      setState(() {
        _connecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connected to ${gateway.name}'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onConnected?.call();

      // Delay then pop
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _connecting = false;
        _connectionError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDetailedErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _connectionError ?? 'Unknown error',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              if (_connectionErrorDetails != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Debug Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _connectionErrorDetails!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Common fixes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Run: openclaw gateway run --bind lan\n'
                '2. Check: openclaw gateway status\n'
                '3. Verify phone and gateway on same WiFi\n'
                '4. Check firewall allows port 18789',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Error: $_connectionError\n\nDetails:\n$_connectionErrorDetails',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error details copied')),
              );
            },
            child: const Text('COPY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _testManualConnection() async {
    if (!_manualFormKey.currentState!.validate()) return;

    setState(() {
      _testingManual = true;
      _manualTestResult = null;
      _connectionError = null;
      _connectionErrorDetails = null;
    });

    try {
      final url = _urlController.text.trim();
      final gateway = GatewayConnection(
        name: 'Manual Entry',
        url: url,
        token: _tokenController.text.isNotEmpty ? _tokenController.text : null,
      );

      final result = await _discoveryService.testConnection(gateway);

      setState(() {
        _testingManual = false;
        _manualTestResult = result;
        if (!result['success']) {
          _connectionError = result['error'];
          _connectionErrorDetails = result['details'];
        }
      });
    } catch (e) {
      setState(() {
        _testingManual = false;
        _manualTestResult = {
          'success': false,
          'error': 'Error: $e',
        };
      });
    }
  }

  Future<void> _connectManual() async {
    if (!_manualFormKey.currentState!.validate()) return;

    final gateway = GatewayConnection(
      name: 'Manual Gateway',
      url: _urlController.text.trim(),
      token: _tokenController.text.isNotEmpty ? _tokenController.text : null,
    );

    await _connectToGateway(gateway);
  }

  Future<void> _copyLogsToClipboard() async {
    final logText = _discoveryService.getLogsAsText();
    await Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Logs copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Troubleshooting'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTroubleshootingSection(
                '1. Make sure gateway is running',
                [
                  'Check that OpenClaw gateway is started on your computer',
                  'Run: openclaw gateway status',
                  'Look for the gateway to be listening on port 18789',
                  'IMPORTANT: Use --bind lan for network access',
                  '  openclaw gateway run --bind lan',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                '2. Check network connectivity',
                [
                  'Your phone and gateway must be on the same network',
                  'Try: curl http://GATEWAY_IP:18789/health',
                  'Should return: {"ok":true,"status":"live"}',
                  'If "No route to host", check firewall settings',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                '3. Common error: "No route to host"',
                [
                  'This means the gateway is not reachable from your phone',
                  'Solutions:',
                  '  a) Start gateway with --bind lan',
                  '  b) Check firewall allows port 18789',
                  '  c) Verify IP address is correct',
                  '  d) Ensure both devices on same network',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                '4. Try manual connection',
                [
                  'Use the Manual tab to enter the gateway IP directly',
                  'Format: http://192.168.1.100:18789',
                  'For Tailscale: http://100.x.x.x:18789',
                  'Check debug logs for detailed error information',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _logsSubscription.cancel();
    _progressSubscription.cancel();
    _logsScrollController.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Gateway'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showTroubleshootingDialog,
            tooltip: 'Troubleshooting',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_fix_high), text: 'Auto'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAutoTab(),
                _buildHistoryTab(),
                _buildManualTab(),
              ],
            ),
          ),
          // Debug logs panel (collapsible)
          _buildDebugLogsPanel(),
        ],
      ),
    );
  }

  Widget _buildDebugLogsPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showDebugLogs ? 200 : 50,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: Column(
        children: [
          // Header bar
          InkWell(
            onTap: () {
              setState(() {
                _showDebugLogs = !_showDebugLogs;
              });
            },
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _showDebugLogs ? Icons.expand_more : Icons.expand_less,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.bug_report, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Debug Logs',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isScanning ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isScanning ? 'SCANNING' : 'IDLE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_showDebugLogs) ...[
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.grey[400], size: 20),
                      onPressed: _copyLogsToClipboard,
                      tooltip: 'Copy logs',
                    ),
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                      onPressed: () => _discoveryService.clearLogs(),
                      tooltip: 'Clear logs',
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Logs content
          if (_showDebugLogs)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No logs yet. Start a scan to see debug output.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        controller: _logsScrollController,
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return _buildLogEntry(log);
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(DiscoveryLogEntry log) {
    Color levelColor;
    IconData levelIcon;

    switch (log.level) {
      case 'success':
        levelColor = Colors.green;
        levelIcon = Icons.check_circle;
        break;
      case 'warning':
        levelColor = Colors.orange;
        levelIcon = Icons.warning;
        break;
      case 'error':
        levelColor = Colors.red;
        levelIcon = Icons.error;
        break;
      default:
        levelColor = Colors.blue;
        levelIcon = Icons.info;
    }

    final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(levelIcon, color: levelColor, size: 14),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.message,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (log.details != null)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 2),
              child: Text(
                '→ ${log.details}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAutoTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _discoveryService.scan();
        if (_tailscaleRunning) {
          await _scanTailscale();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Help card
            _buildHelpCard(),
            const SizedBox(height: 16),

            // Scanning status card
            _buildScanStatusCard(),
            const SizedBox(height: 24),

            // LAN Gateways section
            _buildSectionHeader('Local Network', Icons.wifi),
            const SizedBox(height: 12),
            if (_isScanning && _lanGateways.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_lanGateways.isEmpty)
              _buildEmptyState(
                icon: Icons.wifi_off,
                title: 'No local gateways found',
                subtitle: 'Make sure your gateway is on the same WiFi network',
              )
            else
              ..._lanGateways.map((g) => _buildGatewayCard(g, isLan: true)),

            const SizedBox(height: 32),

            // Tailscale section
            _buildSectionHeader('Tailscale', Icons.vpn_lock),
            const SizedBox(height: 12),
            if (!_tailscaleRunning)
              _buildTailscaleNotRunningCard()
            else if (_tailscaleScanning && _tailscaleGateways.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_tailscaleGateways.isEmpty)
              Column(
                children: [
                  _buildEmptyState(
                    icon: Icons.vpn_lock_outlined,
                    title: 'No Tailscale gateways found',
                    subtitle: 'Scan your Tailscale network to find gateways',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _tailscaleScanning ? null : _scanTailscale,
                    icon: _tailscaleScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_tailscaleScanning ? 'Scanning...' : 'Scan Tailscale'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ..._tailscaleGateways.map((g) => _buildGatewayCard(g, isTailscale: true)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _tailscaleScanning ? null : _scanTailscale,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Connection Tips',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• Gateway must be running with --bind lan for network access\n'
              '• Phone and gateway must be on the same network\n'
              '• Use Manual tab if auto-discovery fails\n'
              '• Check debug logs for detailed error information',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showTroubleshootingDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text(
                    'View full troubleshooting guide',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStatusCard() {
    final hasResults = _lanGateways.isNotEmpty || _tailscaleGateways.isNotEmpty;
    final isScanning = _isScanning || _tailscaleScanning;
    final scanProgress = _scanProgress;

    return Card(
      color: hasResults
          ? Colors.green.withOpacity(0.1)
          : isScanning
              ? Colors.blue.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                if (isScanning)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    hasResults ? Icons.wifi_find : Icons.wifi_off,
                    color: hasResults ? Colors.green : Colors.orange,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isScanning
                            ? 'Scanning for gateways...'
                            : hasResults
                                ? '${_lanGateways.length + _tailscaleGateways.length} gateway(s) found'
                                : 'No gateways found',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (isScanning && scanProgress.total > 0)
                        Text(
                          '${scanProgress.percent}% - ${scanProgress.status}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue,
                          ),
                        )
                      else if (!isScanning)
                        Text(
                          hasResults
                              ? 'Tap a gateway to connect'
                              : 'Pull down to scan again or check debug logs',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (!isScanning)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _discoveryService.scan();
                      if (_tailscaleRunning) await _scanTailscale();
                    },
                  ),
              ],
            ),
            // Progress bar when scanning
            if (isScanning && scanProgress.total > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: scanProgress.percent / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 4),
              Text(
                '${scanProgress.scanned}/${scanProgress.total} IPs checked',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTailscaleNotRunningCard() {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.vpn_lock_outlined, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'Tailscale Not Connected',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to Tailscale VPN to discover remote gateways',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showTailscaleNotRunningDialog,
              icon: const Icon(Icons.info_outline),
              label: const Text('How to Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayCard(GatewayConnection gateway, {bool isLan = false, bool isTailscale = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isLan ? Colors.green : Colors.purple,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            isLan ? Icons.wifi : Icons.vpn_lock,
            color: Colors.white,
          ),
        ),
        title: Text(
          gateway.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gateway.url),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: gateway.isOnline ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  gateway.isOnline ? 'Online' : 'Unknown',
                  style: TextStyle(
                    color: gateway.isOnline ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                if (isLan) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.wifi, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('LAN', style: TextStyle(fontSize: 12)),
                ],
                if (isTailscale) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.vpn_lock, size: 12, color: Colors.purple),
                  const SizedBox(width: 4),
                  const Text('Tailscale', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        trailing: _connecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton.icon(
                onPressed: () => _showConnectionDialog(gateway),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
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
            const Icon(Icons.history, size: 64, color: Colors.grey),
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
                  onPressed: () async {
                    await _discoveryService.removeFromHistory(gateway.url);
                    await _loadHistory();
                  },
                  tooltip: 'Remove from history',
                ),
                ElevatedButton(
                  onPressed: () => _showConnectionDialog(gateway),
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _manualFormKey,
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
                        'Enter your gateway URL manually',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // URL field
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Gateway URL',
                hintText: 'http://192.168.1.100:18789',
                prefixIcon: Icon(Icons.link),
                helperText: 'Examples: http://192.168.1.100:18789 or http://100.x.x.x:18789',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a URL';
                }
                if (!value.startsWith('http://') && !value.startsWith('https://')) {
                  return 'URL must start with http:// or https://';
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
              onPressed: _testingManual ? null : _testManualConnection,
              icon: _testingManual
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(_testingManual ? 'Testing...' : 'Test Connection'),
            ),

            // Test result
            if (_manualTestResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: _manualTestResult!['success'] == true
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _manualTestResult!['success'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _manualTestResult!['success'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _manualTestResult!['success'] == true
                                    ? '✓ Connection successful!'
                                    : '✗ Connection failed',
                                style: TextStyle(
                                  color: _manualTestResult!['success'] == true
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_manualTestResult!['endpoint'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Working endpoint: ${_manualTestResult!['endpoint']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (_manualTestResult!['error'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _manualTestResult!['error'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (_manualTestResult!['details'] != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                text: _manualTestResult!['details'].toString(),
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Details copied')),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.copy, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'Copy debug details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Connect button
            ElevatedButton.icon(
              onPressed: _connecting ? null : _connectManual,
              icon: _connecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_connecting ? 'Connecting...' : 'Connect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            if (_connectionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _connectionError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        if (_connectionErrorDetails != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: InkWell(
                              onTap: _showDetailedErrorDialog,
                              child: Row(
                                children: [
                                  const Icon(Icons.bug_report, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View debug details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
