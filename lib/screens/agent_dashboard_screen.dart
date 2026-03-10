import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/agent_session.dart';
import '../widgets/agent_card_mobile.dart';
import '../widgets/activity_feed_mobile.dart';
import 'agent_detail_screen.dart';
import 'boss_chat_screen.dart';

/// Mobile Agent Dashboard Hub
/// 
/// Central screen for agent monitoring with:
/// - Agent status cards
/// - Real-time activity feed
/// - System statistics
/// - Quick actions (boss chat, settings)
class AgentDashboardScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const AgentDashboardScreen({super.key, this.gatewayService});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GatewayService? _service;
  List<AgentSession> _agents = [];
  List<ActivityEvent> _activityEvents = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (widget.gatewayService != null) {
      setState(() => _service = widget.gatewayService);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
      final token = prefs.getString('gateway_token');
      setState(() => _service = GatewayService(baseUrl: gatewayUrl, token: token));
    }
    await _refreshData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshData());
  }

  Future<void> _refreshData() async {
    if (_service == null) return;

    try {
      final agents = await _service!.getAgents();
      final stats = await _service!.getAgentStats();

      if (mounted) {
        setState(() {
          _agents = agents ?? [];
          _stats = stats;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BossChatScreen(gatewayService: _service),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00D4AA),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF00D4AA),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Agents'),
            Tab(icon: Icon(Icons.activity), text: 'Activity'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Stats'),
          ],
        ),
      ),
      body: _loading && _agents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _agents.isEmpty
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAgentsTab(),
                    _buildActivityTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Connection Error', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsTab() {
    final filteredAgents = _getFilteredAgents();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          // Agent count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredAgents.length} agent${filteredAgents.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${_agents.where((a) => a.isActive).length} active',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ),
          // Agent list
          Expanded(
            child: filteredAgents.isEmpty
                ? _buildEmptyAgentsState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredAgents.length,
                    itemBuilder: (context, index) {
                      final agent = filteredAgents[index];
                      return AgentCardMobile(
                        agent: agent,
                        onTap: () => _showAgentDetails(agent),
                        onChat: () => _openDirectChat(agent),
                        onRestart: () => _restartAgent(agent),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Active', 'active'),
          const SizedBox(width: 8),
          _buildFilterChip('Primary', 'primary'),
          const SizedBox(width: 8),
          _buildFilterChip('Subagents', 'subagent'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _activeFilter = value);
      },
      selectedColor: const Color(0xFF00D4AA).withOpacity(0.3),
      checkmarkColor: const Color(0xFF00D4AA),
      backgroundColor: Colors.grey[850],
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF00D4AA) : Colors.grey[400],
      ),
    );
  }

  List<AgentSession> _getFilteredAgents() {
    switch (_activeFilter) {
      case 'active':
        return _agents.where((a) => a.isActive).toList();
      case 'primary':
        return _agents.where((a) => !a.isSubagent).toList();
      case 'subagent':
        return _agents.where((a) => a.isSubagent).toList();
      default:
        return _agents;
    }
  }

  Widget _buildEmptyAgentsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('No agents found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Start an OpenClaw session to see agents here',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return ActivityFeedMobile(
      events: _activityEvents,
      loading: _loading,
      error: _error,
      onRefresh: _refreshData,
      onFilterChanged: (type) {
        // Handle filter change
      },
    );
  }

  Widget _buildStatsTab() {
    final stats = _stats ?? {};
    final total = stats['totalAgents'] ?? 0;
    final active = stats['activeAgents'] ?? 0;
    final tokens = stats['totalTokens'] ?? 0;
    final tasks = stats['totalTasks'] ?? 0;
    final completed = stats['completedTasks'] ?? 0;
    final failed = stats['failedTasks'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview section
          _buildSectionHeader('Overview'),
          const SizedBox(height: 12),
          _buildStatsGrid([
            _StatItem('Total Agents', total.toString(), Icons.people, Colors.blue),
            _StatItem('Active', active.toString(), Icons.play_circle, Colors.green),
            _StatItem('Primary', (total - (stats['subAgents'] ?? 0)).toString(), Icons.person, Colors.teal),
            _StatItem('Subagents', (stats['subAgents'] ?? 0).toString(), Icons.group, Colors.purple),
          ]),
          const SizedBox(height: 24),

          // Token section
          _buildSectionHeader('Token Usage'),
          const SizedBox(height: 12),
          _buildTokenCard(tokens),
          const SizedBox(height: 24),

          // Tasks section
          _buildSectionHeader('Tasks'),
          const SizedBox(height: 12),
          _buildStatsGrid([
            _StatItem('Total', tasks.toString(), Icons.task, Colors.blue),
            _StatItem('Completed', completed.toString(), Icons.check_circle, Colors.green),
            _StatItem('Failed', failed.toString(), Icons.error, Colors.red),
            _StatItem('Success Rate', _calculateSuccessRate(completed, tasks), Icons.trending_up, Colors.teal),
          ]),
          const SizedBox(height: 24),

          // Leaderboard preview
          _buildSectionHeader('Top Agents'),
          const SizedBox(height: 12),
          _buildLeaderboardPreview(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildStatCard(items[index]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(item.icon, color: item.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(int totalTokens) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.token, color: Color(0xFF00D4AA)),
                const SizedBox(width: 8),
                const Text('Total Tokens', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text(
                  _formatTokens(totalTokens),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D4AA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Token breakdown by agent (top 3)
            ..._getTopTokenAgents().map((agent) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(agent.emoji ?? '🤖', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          agent.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTokens(agent.totalTokens),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardPreview() {
    final sortedAgents = List<AgentSession>.from(_agents)
      ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
    final topAgents = sortedAgents.take(5).toList();

    if (topAgents.isEmpty) {
      return Card(
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No agents to display',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...topAgents.asMap().entries.map((entry) {
              final index = entry.key;
              final agent = entry.value;
              return _buildLeaderboardRow(index + 1, agent);
            }),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // Navigate to full leaderboard
              },
              icon: const Icon(Icons.leaderboard, size: 16),
              label: const Text('View Full Leaderboard'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00D4AA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow(int rank, AgentSession agent) {
    String badge;
    if (rank == 1) badge = '🥇';
    else if (rank == 2) badge = '🥈';
    else if (rank == 3) badge = '🥉';
    else badge = '#$rank';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(badge, style: const TextStyle(fontSize: 18)),
          ),
          Text(agent.emoji ?? '🤖', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              agent.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTokens(agent.totalTokens),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF00D4AA),
            ),
          ),
        ],
      ),
    );
  }

  List<AgentSession> _getTopTokenAgents() {
    final sorted = List<AgentSession>.from(_agents)
      ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
    return sorted.take(3).toList();
  }

  String _calculateSuccessRate(int completed, int total) {
    if (total == 0) return '0%';
    return '${((completed / total) * 100).toStringAsFixed(0)}%';
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  void _showAgentDetails(AgentSession agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentDetailScreen(
          agent: agent,
          gatewayService: _service,
        ),
      ),
    );
  }

  void _openDirectChat(AgentSession agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BossChatScreen(
          gatewayService: _service,
        ),
      ),
    );
  }

  Future<void> _restartAgent(AgentSession agent) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Agent?'),
        content: Text('Are you sure you want to restart ${agent.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restarting ${agent.name}...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}