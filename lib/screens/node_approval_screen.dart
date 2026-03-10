/// Node Approval Screen
/// 
/// Displays pending node pairing requests and allows approval/rejection.
/// Integrates with NodeApprovalService and NodeHostService.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/node_approval_service.dart';
import '../services/node_host_service.dart';
import '../widgets/node_request_card.dart';

class NodeApprovalScreen extends StatefulWidget {
  final NodeHostService? hostService;

  const NodeApprovalScreen({
    super.key,
    this.hostService,
  });

  @override
  State<NodeApprovalScreen> createState() => _NodeApprovalScreenState();
}

class _NodeApprovalScreenState extends State<NodeApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NodeApprovalProvider _approvalProvider;
  String? _loadingNodeId;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _approvalProvider = NodeApprovalProvider();
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    await _approvalProvider.initialize(hostService: widget.hostService);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _approvalProvider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Node Approval'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.pending_actions),
                text: 'Pending',
              ),
              Tab(
                icon: const Icon(Icons.verified),
                text: 'Approved',
              ),
            ],
          ),
          actions: [
            // Auto-approve toggle
            Consumer<NodeApprovalProvider>(
              builder: (context, provider, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Auto',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Switch(
                      value: provider.autoApproveEnabled,
                      onChanged: (value) => _toggleAutoApprove(provider, value),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
          ],
        ),
        body: _initialized
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingTab(),
                  _buildApprovedTab(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildPendingTab() {
    return Consumer<NodeApprovalProvider>(
      builder: (context, provider, child) {
        final requests = provider.pendingRequests;

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: 'No Pending Requests',
            subtitle: 'New pairing requests will appear here',
            color: Colors.orange,
          );
        }

        return Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${requests.length} device(s) waiting for approval',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Approve all button
                  TextButton.icon(
                    onPressed: () => _approveAll(provider),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Approve All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Requests list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return NodeRequestCard(
                    request: request,
                    isLoading: _loadingNodeId == request.id,
                    onApprove: () => _approveNode(provider, request.id),
                    onReject: () => _rejectNode(provider, request.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return Consumer<NodeApprovalProvider>(
      builder: (context, provider, child) {
        final nodes = provider.approvedNodes;

        if (nodes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.verified,
            title: 'No Approved Nodes',
            subtitle: 'Approved devices will appear here',
            color: Colors.green,
          );
        }

        return Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${nodes.length} approved device(s)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Whitelist count
                  if (nodes.where((n) => n.isWhitelisted).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${nodes.where((n) => n.isWhitelisted).length} whitelisted',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Approved nodes list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  return ApprovedNodeCard(
                    node: node,
                    isLoading: _loadingNodeId == node.id,
                    onToggleWhitelist: () => _toggleWhitelist(provider, node.id),
                    onRemove: () => _removeNode(provider, node.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _approveNode(NodeApprovalProvider provider, String nodeId) async {
    setState(() => _loadingNodeId = nodeId);
    try {
      await provider.approveNode(nodeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Node approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNodeId = null);
      }
    }
  }

  Future<void> _rejectNode(NodeApprovalProvider provider, String nodeId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request?'),
        content: const Text('This will reject the pairing request. The device will need to request again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingNodeId = nodeId);
    try {
      await provider.rejectNode(nodeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNodeId = null);
      }
    }
  }

  Future<void> _approveAll(NodeApprovalProvider provider) async {
    // Show confirmation dialog
    final count = provider.pendingCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve All?'),
        content: Text('This will approve all $count pending request(s).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Approve each one
    for (final request in provider.pendingRequests) {
      await provider.approveNode(request.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count request(s) approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleAutoApprove(NodeApprovalProvider provider, bool enabled) async {
    if (enabled) {
      // Show warning dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Auto-Approve?'),
          content: const Text(
            'With auto-approve enabled, all new pairing requests will be automatically approved without confirmation. '
            'This is less secure but convenient for trusted networks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    await provider.setAutoApprove(enabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Auto-approve enabled - new requests will be approved automatically'
                : 'Auto-approve disabled',
          ),
          backgroundColor: enabled ? Colors.blue : Colors.grey,
        ),
      );
    }
  }

  Future<void> _toggleWhitelist(NodeApprovalProvider provider, String nodeId) async {
    try {
      await provider.toggleWhitelist(nodeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Whitelist updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeNode(NodeApprovalProvider provider, String nodeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Approved Node?'),
        content: const Text('This device will need to request pairing again to connect.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await provider.removeApprovedNode(nodeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Node removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Badge widget for showing pending request count
class PendingRequestsBadge extends StatelessWidget {
  final int count;
  final double size;

  const PendingRequestsBadge({
    super.key,
    required this.count,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      constraints: BoxConstraints(minWidth: size),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size > 16 ? 12 : 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}