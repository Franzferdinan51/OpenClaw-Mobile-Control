/// QR Code Widget
/// 
/// Displays a QR code for node pairing.
/// Uses qr_flutter package for generation.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/node_connection.dart';

class QRCodeWidget extends StatelessWidget {
  final PairingQRData? data;
  final double size;
  final bool showDetails;
  final VoidCallback? onRefresh;

  const QRCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.showDetails = true,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return _buildPlaceholder(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: QrImageView(
            data: data!.toQRString(),
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorStateBuilder: (context, error) {
              return Center(
                child: Text(
                  'Error generating QR code: $error',
                  textAlign: TextAlign.center,
                ),
              );
            },
            embeddedImage: null, // Could add app logo here
            embeddedImageStyle: const QrEmbeddedImageStyle(
              size: Size(40, 40),
            ),
          ),
        ),
        
        if (showDetails) ...[
          const SizedBox(height: 16),
          _buildConnectionDetails(context),
        ],
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size + 32,
      height: size + 32,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_2,
            size: size * 0.6,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            'Start Host Mode to generate QR code',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            Icons.computer,
            'IP Address',
            data!.hostIp,
          ),
          const Divider(height: 16),
          _buildDetailRow(
            context,
            Icons.numbers,
            'Port',
            data!.port.toString(),
          ),
          const Divider(height: 16),
          _buildDetailRow(
            context,
            Icons.vpn_key,
            'Token',
            data!.token,
            isMonospace: true,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Token'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

/// Compact QR code display for inline use
class CompactQRCode extends StatelessWidget {
  final String data;
  final double size;

  const CompactQRCode({
    super.key,
    required this.data,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(8),
    );
  }
}

/// QR code scanner widget placeholder
/// Note: Actual scanning requires mobile_scanner package setup
class QRCodeScanner extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final String? hintText;

  const QRCodeScanner({
    super.key,
    required this.onQRCodeScanned,
    this.hintText,
  });

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner view placeholder
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Scan overlay
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
                      size: 60,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              // Hint text
              if (widget.hintText != null)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      widget.hintText!,
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
        const SizedBox(height: 16),
        // Scan button
        ElevatedButton.icon(
          onPressed: _toggleScanning,
          icon: Icon(_isScanning ? Icons.stop : Icons.camera_alt),
          label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
        ),
      ],
    );
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
    });

    // Note: Actual scanning would use mobile_scanner package
    // This is a placeholder that simulates scanning after 3 seconds
    if (_isScanning) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isScanning) {
          // Simulate finding a QR code
          setState(() {
            _isScanning = false;
          });
          // Would call widget.onQRCodeScanned with scanned data
        }
      });
    }
  }
}