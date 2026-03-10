/// Node Host Screen
/// 
/// Main UI for Host Node Mode.
/// Allows the phone to act as a hub for other devices.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node_connection.dart';
import '../services/node_host_service.dart';

class NodeHostScreen extends StatefulWidget {
  const NodeHostScreen({super.key});

  @override
  State<NodeHostScreen> createState() => _NodeHostScreenState();
}

class _NodeHostScreenState extends State<NodeHostScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NodeHostProvider _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _provider = NodeHostProvider();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Host Node Mode'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.router), text: 'Host'),
              Tab(icon: Icon(Icons.devices), text: 'Devices'),
              Tab(icon: Icon(Icons.history), text: 'Logs'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(context),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _HostControlTab(),
            _ConnectedDevicesTab(),
            _ConnectionLogsTab(),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _HostSettingsDialog(),
    );
  }
}

/// Host Control Tab
class _HostControlTab extends StatelessWidget {
  const _HostControlTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<NodeHostProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              _buildStatusCard(context, provider),
              const SizedBox(height: 16),

              // Quick Stats
              _buildQuickStats(context, provider),
              const SizedBox(height: 24),

              // QR Code Section
              if (provider.isRunning) ...[
                _buildQRCodeSection(context, provider),
                const SizedBox(height: 24),
              ],

              // Control Buttons
              _buildControlButtons(context, provider),
              const SizedBox(height: 24),

              // Node Mode Selector
              _buildNodeModeSelector(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, NodeHostProvider provider) {
    return Card(
      color: provider.isRunning 
          ? Colors.green.withOpacity(0.1) 
          : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: provider.isRunning ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                provider.isRunning ? Icons.router : Icons.router_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isRunning ? 'Host Node Active' : 'Host Node Inactive',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.isRunning
                        ? 'Listening on port ${provider.port}'
                        : 'Toggle to start accepting connections',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (provider.isRunning) ...[
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
                        const SizedBox(width: 8),
                        Text(
                          '${provider.activeConnections} device(s) connected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, NodeHostProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.devices, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.activeConnections}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Connected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.schedule, color: Colors.purple),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(provider.uptime),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Uptime',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.vpn_key, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    provider.currentToken ?? '---',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Token',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodeSection(BuildContext context, NodeHostProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pairing QR Code',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: provider.generateNewQRCode,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildQRCodeWidget(context, provider),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scan this QR code with another device to pair',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (provider.qrData != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'IP: ${provider.qrData!.hostIp}:${provider.qrData!.port}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeWidget(BuildContext context, NodeHostProvider provider) {
    // Simple QR code placeholder - would use qr_flutter package
    if (provider.qrData == null) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code, size: 100, color: Colors.black87),
          const SizedBox(height: 8),
          Text(
            provider.currentToken ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, NodeHostProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isRunning ? provider.stop : provider.start,
            icon: Icon(provider.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(provider.isRunning ? 'Stop Hosting' : 'Start Hosting'),
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isRunning ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeModeSelector(BuildContext context, NodeHostProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Node Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<NodeMode>(
              segments: [
                ButtonSegment(
                  value: NodeMode.client,
                  label: const Text('Client'),
                  icon: const Icon(Icons.phone_android),
                ),
                ButtonSegment(
                  value: NodeMode.host,
                  label: const Text('Host'),
                  icon: const Icon(Icons.router),
                ),
                ButtonSegment(
                  value: NodeMode.bridge,
                  label: const Text('Bridge'),
                  icon: const Icon(Icons.hub),
                ),
              ],
              selected: {provider.mode},
              onSelectionChanged: (selected) {
                provider.setMode(selected.first);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.mode.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0m';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Connected Devices Tab
class _ConnectedDevicesTab extends StatelessWidget {
  const _ConnectedDevicesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<NodeHostProvider>(
      builder: (context, provider, child) {
        final connections = provider.connections;

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.devices_other,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Connected Devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start hosting to accept connections',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final conn = connections[index];
            return _ConnectionCard(connection: conn);
          },
        );
      },
    );
  }
}

/// Connection Card Widget
class _ConnectionCard extends StatelessWidget {
  final NodeConnection connection;

  const _ConnectionCard({required this.connection});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NodeHostProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${connection.ip}:${connection.port}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDeviceIcon(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.access_time,
                    _formatDuration(connection.connectedDuration),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.devices,
                    connection.deviceType.displayName,
                  ),
                ),
              ],
            ),
            if (connection.status == ConnectionStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.approveConnection(connection.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => provider.rejectConnection(connection.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (connection.status == ConnectionStatus.connected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDisconnectDialog(context, connection),
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    switch (connection.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        break;
      case ConnectionStatus.pending:
        color = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildDeviceIcon() {
    IconData iconData;
    switch (connection.deviceType) {
      case DeviceType.android:
        iconData = Icons.phone_android;
        break;
      case DeviceType.ios:
        iconData = Icons.phone_iphone;
        break;
      case DeviceType.desktop:
        iconData = Icons.computer;
        break;
      case DeviceType.server:
        iconData = Icons.dns;
        break;
      case DeviceType.iot:
        iconData = Icons.router;
        break;
      case DeviceType.unknown:
        iconData = Icons.device_unknown;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: Colors.blue),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _showDisconnectDialog(BuildContext context, NodeConnection connection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device?'),
        content: Text('Are you sure you want to disconnect ${connection.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<NodeHostProvider>().disconnectConnection(connection.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

/// Connection Logs Tab
class _ConnectionLogsTab extends StatelessWidget {
  const _ConnectionLogsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<NodeHostProvider>(
      builder: (context, provider, child) {
        final logs = provider.logs;

        if (logs.isEmpty) {
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
                  'No Logs Yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[logs.length - 1 - index]; // Reverse order
            return _LogEntryTile(log: log);
          },
        );
      },
    );
  }
}

/// Log Entry Tile
class _LogEntryTile extends StatelessWidget {
  final ConnectionLogEntry log;

  const _LogEntryTile({required this.log});

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    IconData levelIcon;
    
    switch (log.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        levelIcon = Icons.bug_report;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        levelIcon = Icons.info_outline;
        break;
      case LogLevel.warn:
        levelColor = Colors.orange;
        levelIcon = Icons.warning_amber;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        levelIcon = Icons.error_outline;
        break;
    }

    return ListTile(
      leading: Icon(levelIcon, color: levelColor, size: 20),
      title: Text(log.message),
      subtitle: Text(
        _formatTime(log.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      dense: true,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Host Settings Dialog
class _HostSettingsDialog extends StatelessWidget {
  const _HostSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NodeHostProvider>();

    return AlertDialog(
      title: const Text('Host Node Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Port Setting
            TextField(
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '18790',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: provider.port.toString()),
              onChanged: (value) {
                final port = int.tryParse(value);
                if (port != null && port > 0 && port < 65536) {
                  provider.setPort(port);
                }
              },
            ),
            const SizedBox(height: 16),

            // Require Approval
            SwitchListTile(
              title: const Text('Require Approval'),
              subtitle: const Text('Manually approve each connection'),
              value: provider.requireApproval,
              onChanged: (value) => provider.setRequireApproval(value),
            ),

            // Enable Encryption
            SwitchListTile(
              title: const Text('Enable Encryption'),
              subtitle: const Text('Encrypt all communications'),
              value: provider.enableEncryption,
              onChanged: (value) => provider.setEnableEncryption(value),
            ),

            // Enable Whitelist
            SwitchListTile(
              title: const Text('Enable Whitelist'),
              subtitle: const Text('Only allow connections from whitelisted IPs'),
              value: provider.enableWhitelist,
              onChanged: (value) => provider.setEnableWhitelist(value),
            ),

            // Max Connections
            const SizedBox(height: 16),
            Text(
              'Max Connections: ${provider.maxConnections}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: provider.maxConnections.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: provider.maxConnections.toString(),
              onChanged: (value) => provider.setMaxConnections(value.round()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Provider for Node Host state
class NodeHostProvider extends ChangeNotifier {
  NodeHostService? _service;
  NodeModeConfig _config = NodeModeConfig();
  DateTime? _startTime;

  List<NodeConnection> _connections = [];
  List<ConnectionLogEntry> _logs = [];
  PairingQRData? _qrData;

  bool get isRunning => _service?.isRunning ?? false;
  int get port => _config.hostPort;
  int get activeConnections => _connections.where((c) => c.isActive).length;
  int get maxConnections => _config.maxConnections;
  bool get requireApproval => _config.requireApproval;
  bool get enableEncryption => _config.enableEncryption;
  bool get enableWhitelist => _config.enableWhitelist;
  String? get currentToken => _service?.currentToken;
  PairingQRData? get qrData => _qrData;
  NodeMode get mode => _config.mode;
  Duration? get uptime => _startTime != null ? DateTime.now().difference(_startTime!) : null;
  List<NodeConnection> get connections => List.unmodifiable(_connections);
  List<ConnectionLogEntry> get logs => List.unmodifiable(_logs);
  
  /// Get the underlying NodeHostService
  NodeHostService? get service => _service;

  /// Start the host server
  Future<void> start() async {
    if (_service != null) return;

    _service = NodeHostService(
      config: _config,
      onLog: _addLog,
    );

    // Listen to events
    _service!.eventStream.listen(_handleEvent);

    await _service!.start();
    _startTime = DateTime.now();
    _qrData = _service!.currentQRData;
    notifyListeners();
  }

  /// Stop the host server
  Future<void> stop() async {
    await _service?.stop();
    _service?.dispose();
    _service = null;
    _startTime = null;
    _connections = [];
    _qrData = null;
    notifyListeners();
  }

  /// Generate new QR code
  Future<void> generateNewQRCode() async {
    if (_service == null) return;
    _qrData = await _service!.generateNewQRCode();
    notifyListeners();
  }

  /// Approve connection
  void approveConnection(String connectionId) {
    _service?.approveConnection(connectionId);
  }

  /// Reject connection
  void rejectConnection(String connectionId) {
    _service?.rejectConnection(connectionId);
  }

  /// Disconnect connection
  void disconnectConnection(String connectionId) {
    _service?.disconnectConnection(connectionId);
  }

  /// Set node mode
  void setMode(NodeMode mode) {
    _config = _config.copyWith(mode: mode);
    notifyListeners();
  }

  /// Set port
  void setPort(int port) {
    _config = _config.copyWith(hostPort: port);
    notifyListeners();
  }

  /// Set require approval
  void setRequireApproval(bool value) {
    _config = _config.copyWith(requireApproval: value);
    notifyListeners();
  }

  /// Set enable encryption
  void setEnableEncryption(bool value) {
    _config = _config.copyWith(enableEncryption: value);
    notifyListeners();
  }

  /// Set enable whitelist
  void setEnableWhitelist(bool value) {
    _config = _config.copyWith(enableWhitelist: value);
    notifyListeners();
  }

  /// Set max connections
  void setMaxConnections(int value) {
    _config = _config.copyWith(maxConnections: value);
    notifyListeners();
  }

  void _handleEvent(NodeHostEvent event) {
    switch (event) {
      case ConnectionPendingEvent(:final connectionId, :final ip):
        _connections.add(NodeConnection(
          id: connectionId,
          name: 'Pending',
          ip: ip,
          status: ConnectionStatus.pending,
        ));
        notifyListeners();
        break;
      case ConnectionApprovedEvent(:final connectionId):
        final index = _connections.indexWhere((c) => c.id == connectionId);
        if (index >= 0) {
          _connections[index] = _connections[index].copyWith(
            isApproved: true,
            status: ConnectionStatus.connected,
          );
        }
        notifyListeners();
        break;
      case ConnectionRejectedEvent(:final connectionId):
      case ConnectionDisconnectedEvent(:final connectionId):
        _connections.removeWhere((c) => c.id == connectionId);
        notifyListeners();
        break;
      case QRCodeGeneratedEvent(:final data):
        _qrData = data;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _addLog(ConnectionLogEntry log) {
    _logs.add(log);
    if (_logs.length > 100) {
      _logs.removeRange(0, _logs.length - 100);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}