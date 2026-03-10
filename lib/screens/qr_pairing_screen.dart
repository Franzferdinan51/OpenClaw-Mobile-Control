/// QR Pairing Screen
/// 
/// Displays QR code for pairing with host node.
/// Also can scan QR codes to connect to a host.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/node_connection.dart';
import '../widgets/qr_code_widget.dart';

class QRPairingScreen extends StatefulWidget {
  final PairingQRData? qrData;
  final VoidCallback? onRefresh;
  final Function(PairingQRData)? onQRScanned;

  const QRPairingScreen({
    super.key,
    this.qrData,
    this.onRefresh,
    this.onQRScanned,
  });

  @override
  State<QRPairingScreen> createState() => _QRPairingScreenState();
}

class _QRPairingScreenState extends State<QRPairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _manualIpController = TextEditingController();
  final TextEditingController _manualTokenController = TextEditingController();
  final TextEditingController _manualPortController = TextEditingController(text: '18790');
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualIpController.dispose();
    _manualTokenController.dispose();
    _manualPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Pairing'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Show QR'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShowQRTab(),
          _buildScanQRTab(),
        ],
      ),
    );
  }

  Widget _buildShowQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR Code Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (widget.qrData != null) ...[
                    // QR Code Display
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildQRCodeWidget(),
                    ),
                    const SizedBox(height: 20),

                    // Connection Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('IP Address', widget.qrData!.hostIp),
                          const Divider(),
                          _buildDetailRow('Port', widget.qrData!.port.toString()),
                          const Divider(),
                          _buildDetailRow('Token', widget.qrData!.token, isMonospace: true),
                          const Divider(),
                          _buildDetailRow('Device Name', widget.qrData!.deviceName),
                        ],
                      ),
                    ),
                  ] else ...[
                    // No QR Data
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No QR Code Available',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start Host Node Mode to generate a QR code',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Refresh Button
          if (widget.onRefresh != null)
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate New QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

          const SizedBox(height: 16),

          // Copy Details
          Card(
            child: ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Connection Details'),
              subtitle: const Text('Copy IP, port, and token to clipboard'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _copyConnectionDetails(),
            ),
          ),
          const SizedBox(height: 8),

          // Share Details
          Card(
            child: ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Connection'),
              subtitle: const Text('Share connection details via another app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _shareConnectionDetails(),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'How to Pair',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStep('1', 'Open OpenClaw on another device'),
                _buildStep('2', 'Go to Settings → Node → Scan QR'),
                _buildStep('3', 'Point camera at this QR code'),
                _buildStep('4', 'Approve the connection on this device'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeWidget() {
    if (widget.qrData == null) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Use the new QR code widget
    return QRCodeWidget(
      data: widget.qrData,
      size: 200,
      showDetails: false,
      onRefresh: widget.onRefresh,
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildScanQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera View Placeholder
          Card(
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Scanner overlay
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isScanning ? Colors.green : Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 80,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  // Instructions
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Point camera at QR code',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scan Button
          ElevatedButton.icon(
            onPressed: _startScanning,
            icon: Icon(_isScanning ? Icons.stop : Icons.camera_alt),
            label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 24),

          // Manual Entry
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Manual Entry',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // IP Address
                  TextField(
                    controller: _manualIpController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '192.168.1.100',
                      prefixIcon: Icon(Icons.computer),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Port
                  TextField(
                    controller: _manualPortController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '18790',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Token
                  TextField(
                    controller: _manualTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Token',
                      hintText: 'Enter pairing token',
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),

                  // Connect Button
                  ElevatedButton.icon(
                    onPressed: _connectManually,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startScanning() {
    setState(() {
      _isScanning = !_isScanning;
    });

    // Simulate scanning (would use mobile_scanner package)
    if (_isScanning) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isScanning) {
          // Simulate finding a QR code
          _showScannedResultDialog();
        }
      });
    }
  }

  void _showScannedResultDialog() {
    setState(() {
      _isScanning = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.green),
            SizedBox(width: 8),
            Text('QR Code Found'),
          ],
        ),
        content: const Text('Would you like to connect to this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Would call widget.onQRScanned
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connecting to device...'),
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

  void _connectManually() {
    final ip = _manualIpController.text.trim();
    final port = int.tryParse(_manualPortController.text) ?? 18790;
    final token = _manualTokenController.text.trim().toUpperCase();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an IP address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a token'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qrData = PairingQRData(
      hostIp: ip,
      port: port,
      token: token,
      deviceName: 'Manual Entry',
    );

    widget.onQRScanned?.call(qrData);
  }

  void _copyConnectionDetails() {
    if (widget.qrData == null) return;

    final text = '''
OpenClaw Host Node Connection Details
IP: ${widget.qrData!.hostIp}
Port: ${widget.qrData!.port}
Token: ${widget.qrData!.token}
''';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection details copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareConnectionDetails() {
    // Would use share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}