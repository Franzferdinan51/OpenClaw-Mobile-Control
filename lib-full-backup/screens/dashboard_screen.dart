import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

/// System status overview
class SystemStatus {
  final bool isOnline;
  final int agentCount;
  final int activeAgents;
  final int nodeCount;
  final int activeNodes;
  final int cronCount;
  final double cpuUsage;
  final double memoryUsage;
  final String? gatewayVersion;

  const SystemStatus({
    this.isOnline = false,
    this.agentCount = 0,
    this.activeAgents = 0,
    this.nodeCount = 0,
    this.activeNodes = 0,
    this.cronCount = 0,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.gatewayVersion,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      isOnline: json['isOnline'] ?? true,
      agentCount: json['agentCount'] ?? 0,
      activeAgents: json['activeAgents'] ?? 0,
      nodeCount: json['nodeCount'] ?? 0,
      activeNodes: json['activeNodes'] ?? 0,
      cronCount: json['cronCount'] ?? 0,
      cpuUsage: (json['cpuUsage'] ?? 0.0).toDouble(),
      memoryUsage: (json['memoryUsage'] ?? 0.0).toDouble(),
      gatewayVersion: json['version'],
    );
  }
}

/// Agent info
class AgentInfo {
  final String id;
  final String name;
  final String status;
  final String? model;
  final DateTime? lastActive;

  AgentInfo({
    required this.id,
    required this.name,
    required this.status,
    this.model,
    this.lastActive,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      status: json['status'] ?? 'offline',
      model: json['model'],
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : null,
    );
  }
}

/// Node info
class NodeInfo {
  final String id;
  final String name;
  final String status;
  final String? os;
  final bool isOnline;

  NodeInfo({
    required this.id,
    required this.name,
    required this.status,
    this.os,
    this.isOnline = false,
  });

  factory NodeInfo.fromJson(Map<String, dynamic> json) {
    return NodeInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      status: json['status'] ?? 'offline',
      os: json['os'],
      isOnline: json['isOnline'] ?? false,
    );
  }
}

/// Dashboard state
class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final SystemStatus? status;
  final List<AgentInfo> agents;
  final List<NodeInfo> nodes;
  final DateTime? lastUpdated;

  const DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.status,
    this.agents = const [],
    this.nodes = const [],
    this.lastUpdated,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    SystemStatus? status,
    List<AgentInfo>? agents,
    List<NodeInfo>? nodes,
    DateTime? lastUpdated,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      status: status ?? this.status,
      agents: agents ?? this.agents,
      nodes: nodes ?? this.nodes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Dashboard notifier
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Dio _dio;
  final String? gatewayUrl;
  Timer? _refreshTimer;

  DashboardNotifier({
    this.gatewayUrl,
    Dio? dio,
  })  : _dio = dio ?? Dio(),
        super(const DashboardState()) {
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    fetchDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchDashboard(),
    );
  }

  Future<void> fetchDashboard() async {
    if (gatewayUrl == null) {
      state = DashboardState(
        errorMessage: 'Not connected to a gateway',
      );
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      // Fetch status
      final statusResponse = await _dio.get(
        '$gatewayUrl/api/status',
      ).timeout(const Duration(seconds: 10));

      // Fetch agents
      final agentsResponse = await _dio.get(
        '$gatewayUrl/api/agents',
      ).timeout(const Duration(seconds: 10));

      // Fetch nodes
      final nodesResponse = await _dio.get(
        '$gatewayUrl/api/nodes',
      ).timeout(const Duration(seconds: 10));

      final status = SystemStatus.fromJson(statusResponse.data);
      final agents = (agentsResponse.data as List)
          .map((a) => AgentInfo.fromJson(a))
          .toList();
      final nodes = (nodesResponse.data as List)
          .map((n) => NodeInfo.fromJson(n))
          .toList();

      state = DashboardState(
        status: status,
        agents: agents,
        nodes: nodes,
        lastUpdated: DateTime.now(),
      );
    } on DioException catch (e) {
      state = DashboardState(
        errorMessage: 'Failed to fetch dashboard: ${e.message}',
      );
    } catch (e) {
      state = DashboardState(
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(
    gatewayUrl: 'http://localhost:18789', // TODO: Get from stored auth
  ),
);

/// Dashboard Screen - Main status overview
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dashboardState = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dashboard'),
            if (dashboardState.lastUpdated != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dashboardState.errorMessage != null
                      ? colorScheme.error
                      : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(dashboardProvider.notifier).fetchDashboard(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).fetchDashboard(),
        child: _buildBody(context, dashboardState),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBody(BuildContext context, DashboardState state) {
    if (state.isLoading && state.status == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.errorMessage != null && state.status == null) {
      return _buildErrorState(context, state.errorMessage!);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status cards
          _buildStatusCards(context, state),

          const SizedBox(height: 24),

          // Resource usage
          if (state.status != null) _buildResourceUsage(context, state.status!),

          const SizedBox(height: 24),

          // Agents section
          _buildSectionHeader(
            context,
            'Agents',
            state.status?.activeAgents ?? 0,
            state.status?.agentCount ?? 0,
            onSeeAll: () => context.go('/control?tab=agents'),
          ),
          _buildAgentsList(context, state.agents),

          const SizedBox(height: 24),

          // Nodes section
          _buildSectionHeader(
            context,
            'Nodes',
            state.status?.activeNodes ?? 0,
            state.status?.nodeCount ?? 0,
            onSeeAll: () => context.go('/control?tab=nodes'),
          ),
          _buildNodesList(context, state.nodes),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(context),

          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(dashboardProvider.notifier).fetchDashboard(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards(BuildContext context, DashboardState state) {
    final status = state.status;

    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            icon: Icons.dns_rounded,
            title: 'Gateway',
            value: status?.isOnline == true ? 'Online' : 'Offline',
            subtitle: status?.gatewayVersion != null
                ? 'v${status!.gatewayVersion}'
                : null,
            color: status?.isOnline == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusCard(
            icon: Icons.pets_rounded,
            title: 'Agents',
            value: '${status?.activeAgents ?? 0}',
            subtitle: 'of ${status?.agentCount ?? 0} active',
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildResourceUsage(BuildContext context, SystemStatus status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    value: status.cpuUsage,
                    color: _getResourceColor(status.cpuUsage),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ResourceGauge(
                    label: 'Memory',
                    value: status.memoryUsage,
                    color: _getResourceColor(status.memoryUsage),
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

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int active,
    int total, {
    VoidCallback? onSeeAll,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$active/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See All'),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentsList(BuildContext context, List<AgentInfo> agents) {
    if (agents.isEmpty) {
      return _buildEmptyState(context, 'No agents found', Icons.pets_rounded);
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: agents.length,
        itemBuilder: (context, index) {
          final agent = agents[index];
          return _AgentCard(agent: agent);
        },
      ),
    );
  }

  Widget _buildNodesList(BuildContext context, List<NodeInfo> nodes) {
    if (nodes.isEmpty) {
      return _buildEmptyState(context, 'No nodes found', Icons.devices_rounded);
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: nodes.length,
        itemBuilder: (context, index) {
          final node = nodes[index];
          return _NodeCard(node: node);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.chat_rounded,
                    label: 'Chat',
                    onTap: () => context.go('/chat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.gamepad_rounded,
                    label: 'Control',
                    onTap: () => context.go('/control'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.bolt_rounded,
                    label: 'Actions',
                    onTap: () => context.go('/quick-actions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            break; // Already on dashboard
          case 1:
            context.go('/chat');
          case 2:
            context.go('/control');
          case 3:
            context.go('/quick-actions');
          case 4:
            context.go('/settings');
        }
      },
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _NotificationsSheet(),
    );
  }
}

// Helper widgets

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ResourceGauge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _GaugePainter(value: value, color: color),
            child: Center(
              child: Text(
                '${value.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _AgentCard extends StatelessWidget {
  final AgentInfo agent;

  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = agent.status == 'active' || agent.status == 'running';
    final statusColor = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    agent.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (agent.model != null)
              Text(
                agent.model!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              agent.status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final NodeInfo node;

  const _NodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = node.isOnline ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only right: 12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    node.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (node.os != null)
                    Text(
                      node.os!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}