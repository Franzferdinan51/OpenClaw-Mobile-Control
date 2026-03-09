import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Control Screen - Remote control for gateway, agents, nodes, and crons
class ControlScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const ControlScreen({super.key, this.initialTab});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );
    _tabController.addListener(() => setState(() {}));
  }

  int _getInitialTabIndex() {
    switch (widget.initialTab) {
      case 'agents':
        return 1;
      case 'nodes':
        return 2;
      case 'crons':
        return 3;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshCurrentTab,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dns_rounded), text: 'Gateway'),
            Tab(icon: Icon(Icons.pets_rounded), text: 'Agents'),
            Tab(icon: Icon(Icons.devices_rounded), text: 'Nodes'),
            Tab(icon: Icon(Icons.schedule_rounded), text: 'Crons'),
          ],
          onTap: (_) => setState(() {}),
        ),
      ),
      body: const ConnectionBanner(
        child: TabBarView(
          controller: DefaultTabController.of(context),
          children: [
            GatewayControlPanel(),
            AgentsControlPanel(),
            NodesControlPanel(),
            CronsControlPanel(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 2,
      onDestinationSelected: (index) => _navigateTo(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Control',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: 'Quick',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget? _buildFab(BuildContext context) {
    switch (_tabController.index) {
      case 1: // Agents
        return FloatingActionButton.extended(
          onPressed: () => _showCreateAgentDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Agent'),
        );
      case 2: // Nodes
        return FloatingActionButton.extended(
          onPressed: () => _showPairNodeDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Pair Node'),
        );
      case 3: // Crons
        return FloatingActionButton.extended(
          onPressed: () => _showCreateCronDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Cron'),
        );
      default:
        return null;
    }
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/chat');
      case 3:
        context.go('/quick-actions');
      case 4:
        context.go('/settings');
    }
  }

  void _refreshCurrentTab() {
    switch (_tabController.index) {
      case 0:
        ref.read(gatewayProvider.notifier).refreshStatus();
      case 1:
        ref.read(agentsProvider.notifier).loadAgents();
      case 2:
        ref.read(nodesProvider.notifier).loadNodes();
      case 3:
        // TODO: Implement crons refresh
        break;
    }
  }

  void _showCreateAgentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateAgentDialog(),
    );
  }

  void _showPairNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PairNodeDialog(),
    );
  }

  void _showCreateCronDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateCronDialog(),
    );
  }
}

/// Gateway Control Panel
class GatewayControlPanel extends ConsumerWidget {
  const GatewayControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gatewayState = ref.watch(gatewayProvider);

    if (gatewayState.isConnecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!gatewayState.isConnected && gatewayState.status == null) {
      return _buildDisconnectedState(context, ref);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _GatewayStatusCard(status: gatewayState.status, isConnected: gatewayState.isConnected),
          const SizedBox(height: 16),
          // Quick actions
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickActions(context, ref, gatewayState),
          const SizedBox(height: 16),
          // System resources
          if (gatewayState.status?.resources != null)
            _ResourceUsageCard(resources: gatewayState.status!.resources!),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Connected',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your OpenClaw Gateway to control your deployment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(gatewayProvider.notifier).connect(),
              icon: const Icon(Icons.power_rounded),
              label: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, GatewayState state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: [
        _QuickActionCard(
          icon: Icons.restart_alt_rounded,
          label: 'Restart',
          enabled: state.isConnected,
          onTap: () => _showConfirmDialog(
            context,
            'Restart Gateway',
            'Are you sure you want to restart the gateway?',
            () => ref.read(gatewayProvider.notifier).reconnect(),
          ),
        ),
        _QuickActionCard(
          icon: Icons.power_settings_new_rounded,
          label: 'Disconnect',
          enabled: state.isConnected,
          onTap: () => ref.read(gatewayProvider.notifier).disconnect(),
        ),
        _QuickActionCard(
          icon: Icons.terminal_rounded,
          label: 'Shell',
          enabled: state.isConnected,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shell coming soon...')),
          ),
        ),
        _QuickActionCard(
          icon: Icons.analytics_rounded,
          label: 'Analytics',
          enabled: state.isConnected,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analytics coming soon...')),
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Gateway Status Card
class _GatewayStatusCard extends StatelessWidget {
  final GatewayStatus? status;
  final bool isConnected;

  const _GatewayStatusCard({required this.status, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isConnected ? colorScheme.primary : colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isConnected ? colorScheme.primary : colorScheme.error,
                  ),
                ),
                const Spacer(),
                if (status?.version != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${status?.version ?? 'unknown'}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.pets_rounded,
                      label: 'Agents',
                      value: '${status?.activeConnections ?? 0}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.devices_rounded,
                      label: 'Nodes',
                      value: '${status?.activeConnections ?? 0}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.schedule_rounded,
                      label: 'Crons',
                      value: '0',
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
}

/// Resource Usage Card
class _ResourceUsageCard extends StatelessWidget {
  final SystemResources resources;

  const _ResourceUsageCard({required this.resources});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Resources',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ResourceGauge(
                    label: 'CPU',
                    value: resources.cpuUsage,
                    color: _getResourceColor(resources.cpuUsage),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ResourceGauge(
                    label: 'Memory',
                    value: resources.memoryUsage,
                    color: _getResourceColor(resources.memoryUsage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getResourceColor(double value) {
    if (value < 50) return Colors.green;
    if (value < 80) return Colors.orange;
    return Colors.red;
  }
}

/// Agents Control Panel
class AgentsControlPanel extends ConsumerWidget {
  const AgentsControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsState = ref.watch(agentsProvider);

    return agentsState.when(
      data: (agents) {
        if (agents.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(agentsProvider.notifier).loadAgents(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) => _AgentControlTile(agent: agents[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(agentsProvider.notifier).loadAgents(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Agents',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create an agent to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent Control Tile
class _AgentControlTile extends ConsumerWidget {
  final Agent agent;

  const _AgentControlTile({required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = _getStatusColor(agent.status, colorScheme);
    final isActive = agent.status == AgentStatus.active || agent.status == AgentStatus.busy;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.smart_toy_rounded,
            color: statusColor,
          ),
        ),
        title: Text(agent.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${agent.model} • ${agent.status.name}'),
            Text(
              '\$${agent.totalCost.toStringAsFixed(4)} • ${agent.messageCount} messages',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isActive,
              onChanged: (value) => _toggleAgentStatus(context, ref, value),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, ref, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'chat', child: Text('Chat')),
                const PopupMenuItem(value: 'logs', child: Text('View Logs')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AgentStatus status, ColorScheme colorScheme) {
    switch (status) {
      case AgentStatus.active:
      case AgentStatus.busy:
        return colorScheme.primary;
      case AgentStatus.idle:
        return colorScheme.tertiary;
      case AgentStatus.error:
      case AgentStatus.offline:
        return colorScheme.error;
    }
  }

  void _toggleAgentStatus(BuildContext context, WidgetRef ref, bool activate) {
    final status = activate ? AgentStatus.active : AgentStatus.idle;
    ref.read(agentsProvider.notifier).setAgentStatus(agent.id, status);
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'chat':
        context.go('/chat?agentId=${agent.id}');
      case 'logs':
        context.go('/logs?source=${agent.id}');
      case 'delete':
        _showDeleteConfirmation(context, ref);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Agent'),
        content: Text('Are you sure you want to delete "${agent.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(agentsProvider.notifier).deleteAgent(agent.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Nodes Control Panel
class NodesControlPanel extends ConsumerWidget {
  const NodesControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodesState = ref.watch(nodesProvider);

    return nodesState.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(nodesProvider.notifier).loadNodes(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nodes.length,
            itemBuilder: (context, index) => _NodeControlTile(node: nodes[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(nodesProvider.notifier).loadNodes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Nodes Paired',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Pair a device to control it remotely.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Node Control Tile
class _NodeControlTile extends ConsumerWidget {
  final Node node;

  const _NodeControlTile({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isOnline = node.status == NodeStatus.online;
    final statusColor = isOnline ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getNodeIcon(node.type),
            color: statusColor,
          ),
        ),
        title: Text(node.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${node.type} • ${node.status.name}'),
            Text(
              '${node.ipAddress}:${node.port}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCapabilityBadges(colorScheme),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, ref, action),
              itemBuilder: (context) => [
                if (node.capabilities.hasCamera)
                  const PopupMenuItem(value: 'camera', child: Text('Camera')),
                if (node.capabilities.hasScreen)
                  const PopupMenuItem(value: 'screen', child: Text('Screen')),
                const PopupMenuItem(value: 'notify', child: Text('Send Notification')),
                const PopupMenuItem(value: 'unpair', child: Text('Unpair')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityBadges(ColorScheme colorScheme) {
    final capabilities = <Widget>[];

    if (node.capabilities.hasCamera) {
      capabilities.add(_CapabilityBadge(icon: Icons.camera_alt_rounded));
    }
    if (node.capabilities.hasScreen) {
      capabilities.add(_CapabilityBadge(icon: Icons.screen_share_rounded));
    }
    if (node.capabilities.hasLocation) {
      capabilities.add(_CapabilityBadge(icon: Icons.location_on_rounded));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: capabilities);
  }

  IconData _getNodeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.phone_android_rounded;
      case 'tablet':
        return Icons.tablet_rounded;
      case 'desktop':
        return Icons.computer_rounded;
      case 'server':
        return Icons.dns_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'camera':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera coming soon...')),
        );
      case 'screen':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen control coming soon...')),
        );
      case 'notify':
        _showNotificationDialog(context, ref);
      case 'unpair':
        _showUnpairConfirmation(context, ref);
    }
  }

  void _showNotificationDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(nodesProvider.notifier).sendNotification(
                    nodeId: node.id,
                    title: titleController.text,
                    message: messageController.text,
                  );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showUnpairConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Node'),
        content: Text('Are you sure you want to unpair "${node.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(nodesProvider.notifier).unpairNode(node.id);
            },
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }
}

/// Crons Control Panel
class CronsControlPanel extends StatelessWidget {
  const CronsControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // TODO: Implement crons provider
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Cron Jobs',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduled tasks will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widgets

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ResourceGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ResourceGauge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.2),
                color: color,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? null : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityBadge extends StatelessWidget {
  final IconData icon;

  const _CapabilityBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 12),
      ),
    );
  }
}

// Dialogs

class _CreateAgentDialog extends StatefulWidget {
  const _CreateAgentDialog();

  @override
  State<_CreateAgentDialog> createState() => _CreateAgentDialogState();
}

class _CreateAgentDialogState extends State<_CreateAgentDialog> {
  final _nameController = TextEditingController();
  final _modelController = TextEditingController(text: 'bailian/MiniMax-M2.5');

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Agent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // TODO: Implement create agent
            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PairNodeDialog extends StatefulWidget {
  const _PairNodeDialog();

  @override
  State<_PairNodeDialog> createState() => _PairNodeDialogState();
}

class _PairNodeDialogState extends State<_PairNodeDialog> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pair Node'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Pairing Code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: Implement pair node
          },
          child: const Text('Pair'),
        ),
      ],
    );
  }
}

class _CreateCronDialog extends StatelessWidget {
  const _CreateCronDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Cron Job'),
      content: const Text('Cron creation coming soon...'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}