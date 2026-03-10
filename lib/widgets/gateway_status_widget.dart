import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/gateway_service.dart';
import '../models/gateway_status.dart';

/// Gateway status widget for displaying real-time gateway information
class GatewayStatusWidget extends StatefulWidget {
  final GatewayService? gatewayService;
  final VoidCallback? onTap;
  final bool compact;

  const GatewayStatusWidget({
    super.key,
    this.gatewayService,
    this.onTap,
    this.compact = false,
  });

  @override
  State<GatewayStatusWidget> createState() => _GatewayStatusWidgetState();
}

class _GatewayStatusWidgetState extends State<GatewayStatusWidget> {
  GatewayStatus? _status;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadStatus();
    });
  }

  Future<void> _loadStatus() async {
    if (widget.gatewayService == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final status = await widget.gatewayService!.getStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactWidget();
    }
    return _buildFullWidget();
  }

  Widget _buildCompactWidget() {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getStatusColor().withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _status?.online == true ? 'Online' : 'Offline',
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidget() {
    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.wifi,
                          color: _getStatusColor(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gateway Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _status?.online == true
                                ? 'Connected'
                                : 'Disconnected',
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadStatus,
                      tooltip: 'Refresh',
                    ),
                ],
              ),
              if (_status != null) ...[
                const Divider(height: 24),
                _buildStatusRow('Status', _status!.online ? 'Online' : 'Offline'),
                _buildStatusRow('Version', _status!.version),
                if (_status!.uptime > 0)
                  _buildStatusRow('Uptime', _status!.formattedUptime),
                if (_status!.cpuPercent != null)
                  _buildStatusRow('CPU', '${_status!.cpuPercent!.toStringAsFixed(1)}%'),
                if (_status!.formattedMemory != null)
                  _buildStatusRow('Memory', _status!.formattedMemory!),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      'Auto-refresh: 10s',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_status == null) return Colors.grey;
    return _status!.online ? Colors.green : Colors.red;
  }
}