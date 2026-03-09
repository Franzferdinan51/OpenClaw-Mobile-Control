import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Gateway discovered on the network
class GatewayDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? version;
  final bool isOnline;
  final DateTime discoveredAt;

  GatewayDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.version,
    this.isOnline = true,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  String get url => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port/ws';

  factory GatewayDevice.fromJson(Map<String, dynamic> json) {
    return GatewayDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Gateway',
      host: json['host'] ?? '',
      port: json['port'] ?? 18789,
      version: json['version'],
      isOnline: json['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'version': version,
        'isOnline': isOnline,
      };
}

/// State for gateway discovery
enum DiscoveryStatus {
  idle,
  scanning,
  success,
  error,
}

class DiscoveryState {
  final DiscoveryStatus status;
  final List<GatewayDevice> gateways;
  final String? errorMessage;
  final int progress;

  const DiscoveryState({
    this.status = DiscoveryStatus.idle,
    this.gateways = const [],
    this.errorMessage,
    this.progress = 0,
  });

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    List<GatewayDevice>? gateways,
    String? errorMessage,
    int? progress,
  }) {
    return DiscoveryState(
      status: status ?? this.status,
      gateways: gateways ?? this.gateways,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }

  bool get isScanning => status == DiscoveryStatus.scanning;
  bool get hasGateways => gateways.isNotEmpty;
  bool get hasError => status == DiscoveryStatus.error;
}

/// Discovery notifier
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(const DiscoveryState());

  Timer? _scanTimer;
  int _scanProgress = 0;

  Future<void> startScan() async {
    state = DiscoveryState(
      status: DiscoveryStatus.scanning,
      progress: 0,
    );

    _scanProgress = 0;

    // Simulate network scanning
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      _scanProgress += 5;

      if (_scanProgress >= 100) {
        timer.cancel();
        await _completeScan();
        return;
      }

      state = state.copyWith(progress: _scanProgress);
    });

    // Try to discover gateways on the network
    try {
      await _discoverGateways();
    } catch (e) {
      state = DiscoveryState(
        status: DiscoveryStatus.error,
        errorMessage: 'Failed to scan network: $e',
      );
    }
  }

  Future<void> _discoverGateways() async {
    // Simulated discovery - in production, this would use actual network scanning
    // Common ports for OpenClaw: 18789 (gateway), 18790 (agent)

    await Future.delayed(const Duration(seconds: 2));

    // Try local discovery
    final discoveredGateways = await _scanLocalNetwork();

    // Also check known hosts
    final knownGateways = await _checkKnownHosts();

    final allGateways = [...discoveredGateways, ...knownGateways];

    // Remove duplicates
    final uniqueGateways = <String, GatewayDevice>{};
    for (final gateway in allGateways) {
      uniqueGateways[gateway.id] = gateway;
    }

    state = state.copyWith(
      gateways: uniqueGateways.values.toList(),
    );
  }

  Future<List<GatewayDevice>> _scanLocalNetwork() async {
    // Simulated - in production, use multicast DNS or UDP broadcast
    // For now, return common localhost configurations for testing
    return [
      GatewayDevice(
        id: 'local-gateway',
        name: 'Local OpenClaw Gateway',
        host: 'localhost',
        port: 18789,
        version: '1.0.0',
      ),
    ];
  }

  Future<List<GatewayDevice>> _checkKnownHosts() async {
    // Check for gateways at known addresses
    // In production, this would ping known Tailscale/ZeroTier addresses
    final knownHosts = [
      {'host': '100.106.80.61', 'port': 18789},
      {'host': '192.168.1.100', 'port': 18789},
    ];

    final gateways = <GatewayDevice>[];

    for (final host in knownHosts) {
      try {
        // Simulated connectivity check
        // In production, use actual HTTP/WebSocket connection test
        final socket = await Socket.connect(
          host['host'] as String,
          host['port'] as int,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();

        gateways.add(GatewayDevice(
          id: 'gateway-${host['host']}',
          name: 'OpenClaw Gateway (${host['host']})',
          host: host['host'] as String,
          port: host['port'] as int,
        ));
      } catch (e) {
        // Host not reachable, skip
      }
    }

    return gateways;
  }

  Future<void> _completeScan() async {
    if (state.gateways.isEmpty) {
      state = DiscoveryState(
        status: DiscoveryStatus.error,
        errorMessage: 'No gateways found on your network. Make sure OpenClaw is running.',
      );
    } else {
      state = state.copyWith(status: DiscoveryStatus.success);
    }
  }

  void selectGateway(GatewayDevice gateway) {
    // Store selected gateway and navigate to auth
    // In production, save to secure storage
    state = state.copyWith(
      gateways: state.gateways.map((g) {
        return g.id == gateway.id ? g : g;
      }).toList(),
    );
  }

  void addManualGateway(String host, int port) {
    final gateway = GatewayDevice(
      id: 'manual-${host}-$port',
      name: 'Manual Gateway ($host:$port)',
      host: host,
      port: port,
    );

    state = state.copyWith(
      gateways: [...state.gateways, gateway],
      status: DiscoveryStatus.success,
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
  (ref) => DiscoveryNotifier(),
);

/// Selected gateway provider
final selectedGatewayProvider = StateProvider<GatewayDevice?>((ref) => null);

/// Discovery Screen - Scans network for OpenClaw gateways
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _hostController = TextEditingController(text: '');
  final _portController = TextEditingController(text: '18789');
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    // Auto-start scan
    Future.microtask(() {
      ref.read(discoveryProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final discoveryState = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Gateway'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: discoveryState.isScanning
                ? null
                : () => ref.read(discoveryProvider.notifier).startScan(),
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status header
              _buildStatusHeader(context, discoveryState),

              const SizedBox(height: 24),

              // Scanning progress
              if (discoveryState.isScanning)
                _buildScanningProgress(context, discoveryState),

              // Error message
              if (discoveryState.hasError)
                _buildErrorCard(context, discoveryState.errorMessage!),

              // Gateway list
              if (discoveryState.hasGateways && !discoveryState.isScanning)
                Expanded(
                  child: _buildGatewayList(context, discoveryState.gateways),
                ),

              // Manual entry option
              if (!discoveryState.isScanning) ...[
                const SizedBox(height: 16),
                _buildManualEntryToggle(context),
                if (_showManualEntry) _buildManualEntryForm(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, DiscoveryState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (state.status) {
      case DiscoveryStatus.idle:
        statusText = 'Ready to scan';
        statusIcon = Icons.wifi_find_rounded;
        statusColor = colorScheme.onSurfaceVariant;
        break;
      case DiscoveryStatus.scanning:
        statusText = 'Scanning your network...';
        statusIcon = Icons.wifi_rounded;
        statusColor = colorScheme.primary;
        break;
      case DiscoveryStatus.success:
        statusText = 'Found ${state.gateways.length} gateway(s)';
        statusIcon = Icons.check_circle_rounded;
        statusColor = colorScheme.primary;
        break;
      case DiscoveryStatus.error:
        statusText = 'Scan failed';
        statusIcon = Icons.error_outline_rounded;
        statusColor = colorScheme.error;
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'OpenClaw gateways use port 18789 by default',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanningProgress(BuildContext context, DiscoveryState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: state.progress / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning network for OpenClaw gateways...',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${state.progress}%',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayList(BuildContext context, List<GatewayDevice> gateways) {
    return ListView.builder(
      itemCount: gateways.length,
      itemBuilder: (context, index) {
        final gateway = gateways[index];
        return _GatewayCard(
          gateway: gateway,
          onTap: () => _selectGateway(gateway),
        );
      },
    );
  }

  Widget _buildManualEntryToggle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextButton.icon(
      onPressed: () => setState(() => _showManualEntry = !_showManualEntry),
      icon: Icon(
        _showManualEntry
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
      ),
      label: Text(_showManualEntry
          ? 'Hide Manual Entry'
          : 'Enter Gateway Address Manually'),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildManualEntryForm(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Gateway',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: '192.168.1.100',
                      prefixIcon: Icon(Icons.dns_rounded),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '18789',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addManualGateway,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Gateway'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectGateway(GatewayDevice gateway) {
    ref.read(selectedGatewayProvider.notifier).state = gateway;
    ref.read(discoveryProvider.notifier).selectGateway(gateway);
    context.go('/auth', extra: gateway);
  }

  void _addManualGateway() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 18789;

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a host address')),
      );
      return;
    }

    ref.read(discoveryProvider.notifier).addManualGateway(host, port);

    _hostController.clear();
    _portController.text = '18789';

    setState(() => _showManualEntry = false);
  }
}

class _GatewayCard extends StatelessWidget {
  final GatewayDevice gateway;
  final VoidCallback onTap;

  const _GatewayCard({
    required this.gateway,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gateway.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gateway.host}:${gateway.port}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (gateway.version != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'v${gateway.version}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}