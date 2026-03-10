/// Node Settings Screen
/// 
/// Configuration for Node Mode (Client, Host, Bridge).
/// Integrates with the main Settings screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node_connection.dart';
import '../services/node_approval_service.dart';
import 'node_host_screen.dart';
import 'qr_pairing_screen.dart';
import 'connected_devices_screen.dart';
import 'node_approval_screen.dart';

class NodeSettingsScreen extends StatelessWidget {
  const NodeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NodeHostProvider(),
      child: const _NodeSettingsContent(),
    );
  }
}

class _NodeSettingsContent extends StatelessWidget {
  const _NodeSettingsContent();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NodeHostProvider()),
        ChangeNotifierProvider(create: (_) => NodeApprovalProvider()),
      ],
      child: Consumer2<NodeHostProvider, NodeApprovalProvider>(
        builder: (context, hostProvider, approvalProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Node Mode Selection
              _buildNodeModeSection(context, hostProvider),
              const SizedBox(height: 16),

              // Quick Status
              _buildQuickStatusSection(context, hostProvider),
              const SizedBox(height: 16),

              // Pending Requests Section (only if host/bridge mode and has pending)
              if (hostProvider.mode == NodeMode.host || hostProvider.mode == NodeMode.bridge)
                _buildPendingRequestsSection(context, hostProvider, approvalProvider),

              // Host Node Controls
              if (hostProvider.mode == NodeMode.host || hostProvider.mode == NodeMode.bridge)
                _buildHostControlsSection(context, hostProvider),

              // Client Node Controls
              if (hostProvider.mode == NodeMode.client || hostProvider.mode == NodeMode.bridge)
                _buildClientControlsSection(context, hostProvider),

              const SizedBox(height: 24),

              // Navigation Buttons
              _buildNavigationButtons(context, hostProvider, approvalProvider),
            ],
          );
        },
      ),
    );
  }

  /// Pending requests section with badge
  Widget _buildPendingRequestsSection(
    BuildContext context,
    NodeHostProvider hostProvider,
    NodeApprovalProvider approvalProvider,
  ) {
    final pendingCount = approvalProvider.pendingCount;
    
    // Only show if there are pending requests
    if (pendingCount == 0) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: InkWell(
        onTap: () => _openApprovalScreen(context, hostProvider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon with badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pending_actions,
                      color: Colors.orange,
                    ),
                  ),
                  // Badge
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        pendingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Approval Requests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pendingCount device(s) waiting for approval',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              const Icon(Icons.chevron_right, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeModeSection(BuildContext context, NodeHostProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Node Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose how this device connects to the OpenClaw network:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Client Node
            _buildModeOption(
              context,
              mode: NodeMode.client,
              title: 'Client Node',
              subtitle: 'Connect to a gateway server',
              icon: Icons.phone_android,
              color: Colors.green,
              isSelected: provider.mode == NodeMode.client,
              onTap: () => provider.setMode(NodeMode.client),
            ),
            const SizedBox(height: 8),

            // Host Node
            _buildModeOption(
              context,
              mode: NodeMode.host,
              title: 'Host Node',
              subtitle: 'Accept connections from other devices',
              icon: Icons.router,
              color: Colors.blue,
              isSelected: provider.mode == NodeMode.host,
              onTap: () => provider.setMode(NodeMode.host),
            ),
            const SizedBox(height: 8),

            // Bridge Node
            _buildModeOption(
              context,
              mode: NodeMode.bridge,
              title: 'Bridge Node',
              subtitle: 'Connect to gateway AND accept device connections',
              icon: Icons.hub,
              color: Colors.purple,
              isSelected: provider.mode == NodeMode.bridge,
              onTap: () => provider.setMode(NodeMode.bridge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required NodeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusSection(BuildContext context, NodeHostProvider provider) {
    return Card(
      color: provider.isRunning
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: provider.isRunning ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isRunning ? 'Node Active' : 'Node Inactive',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.isRunning
                        ? '${provider.activeConnections} device(s) connected'
                        : 'Tap "Start" to activate',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: provider.isRunning,
              onChanged: (value) async {
                if (value) {
                  await provider.start();
                } else {
                  await provider.stop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostControlsSection(BuildContext context, NodeHostProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.router, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Host Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Port
            ListTile(
              leading: const Icon(Icons.numbers),
              title: const Text('Port'),
              subtitle: Text('${provider.port}'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showPortDialog(context, provider),
            ),

            // Require Approval
            SwitchListTile(
              secondary: const Icon(Icons.approval),
              title: const Text('Require Approval'),
              subtitle: const Text('Manually approve each connection'),
              value: provider.requireApproval,
              onChanged: (value) => provider.setRequireApproval(value),
            ),

            // Enable Encryption
            SwitchListTile(
              secondary: const Icon(Icons.lock),
              title: const Text('Enable Encryption'),
              subtitle: const Text('Encrypt all communications'),
              value: provider.enableEncryption,
              onChanged: (value) => provider.setEnableEncryption(value),
            ),

            // Max Connections
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Max Connections'),
              subtitle: Text('${provider.maxConnections}'),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: provider.maxConnections.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: provider.maxConnections.toString(),
                  onChanged: (value) => provider.setMaxConnections(value.round()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientControlsSection(BuildContext context, NodeHostProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Client Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QR Scanner
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Pair with a host node'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openQRScanner(context, provider),
            ),

            // Manual Connect
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Manual Connect'),
              subtitle: const Text('Enter host IP and token manually'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showManualConnectDialog(context, provider),
            ),

            // Connection History
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Connection History'),
              subtitle: const Text('Previously connected hosts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to connection history
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    NodeHostProvider provider,
    NodeApprovalProvider approvalProvider,
  ) {
    return Column(
      children: [
        // Approval requests button (only for host/bridge mode)
        if (provider.mode == NodeMode.host || provider.mode == NodeMode.bridge) ...[
          ElevatedButton.icon(
            onPressed: () => _openApprovalScreen(context, provider),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.approval),
                if (approvalProvider.pendingCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        approvalProvider.pendingCount > 99 
                            ? '99+' 
                            : approvalProvider.pendingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(
              approvalProvider.pendingCount > 0
                  ? 'Approval Requests (${approvalProvider.pendingCount})'
                  : 'Node Approval',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: approvalProvider.pendingCount > 0 
                  ? Colors.orange 
                  : null,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (provider.mode == NodeMode.host || provider.mode == NodeMode.bridge) ...[
          ElevatedButton.icon(
            onPressed: () => _openHostScreen(context, provider),
            icon: const Icon(Icons.router),
            label: const Text('Open Host Dashboard'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (provider.isRunning && (provider.mode == NodeMode.host || provider.mode == NodeMode.bridge)) ...[
          OutlinedButton.icon(
            onPressed: () => _openQRScreen(context, provider),
            icon: const Icon(Icons.qr_code),
            label: const Text('Show Pairing QR Code'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
        ],

        OutlinedButton.icon(
          onPressed: () => _openConnectedDevices(context, provider),
          icon: const Icon(Icons.devices),
          label: const Text('View Connected Devices'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  void _showPortDialog(BuildContext context, NodeHostProvider provider) {
    final controller = TextEditingController(text: provider.port.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Host Port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Port Number',
            hintText: '18790',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (port != null && port > 0 && port < 65536) {
                provider.setPort(port);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openHostScreen(BuildContext context, NodeHostProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: const NodeHostScreen(),
        ),
      ),
    );
  }

  void _openQRScreen(BuildContext context, NodeHostProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRPairingScreen(
          qrData: provider.qrData,
          onRefresh: provider.generateNewQRCode,
        ),
      ),
    );
  }

  void _openQRScanner(BuildContext context, NodeHostProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRPairingScreen(
          onQRScanned: (data) {
            // Handle scanned QR data
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connecting to ${data.hostIp}...'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openConnectedDevices(BuildContext context, NodeHostProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectedDevicesScreen(
          connections: provider.connections,
          onApprove: (id) => provider.approveConnection(id),
          onReject: (id) => provider.rejectConnection(id),
          onDisconnect: (id) => provider.disconnectConnection(id),
        ),
      ),
    );
  }

  void _showManualConnectDialog(BuildContext context, NodeHostProvider provider) {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '18790');
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Connect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Host IP',
                hintText: '192.168.1.100',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '18790',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                hintText: 'Enter pairing token',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle manual connection
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connecting to ${ipController.text}...'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _openApprovalScreen(BuildContext context, NodeHostProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NodeApprovalScreen(
          hostService: provider.service,
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Node Modes'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Client Node',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Connect to an OpenClaw gateway server running on another device. '
                  'Best for remote control and monitoring.'),
              SizedBox(height: 16),
              Text(
                'Host Node',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Accept connections from other devices. Your phone becomes the hub. '
                  'Other devices can control OpenClaw through your phone.'),
              SizedBox(height: 16),
              Text(
                'Bridge Node',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Combines Client and Host modes. Connect to a gateway AND accept '
                  'device connections. Useful for extending network reach.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}