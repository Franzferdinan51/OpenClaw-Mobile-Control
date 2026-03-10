import 'package:flutter/material.dart';
import '../models/agent_session.dart';

/// Achievement definition
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int requiredValue;
  final String category;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredValue,
    required this.category,
    this.unlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🏆',
      requiredValue: json['requiredValue'] ?? 0,
      category: json['category'] ?? 'general',
      unlocked: json['unlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'])
          : null,
    );
  }
}

/// Leaderboard entry
class LeaderboardEntry {
  final int rank;
  final String agentId;
  final String agentName;
  final String agentEmoji;
  final int value;
  final String? badge;

  const LeaderboardEntry({
    required this.rank,
    required this.agentId,
    required this.agentName,
    required this.agentEmoji,
    required this.value,
    this.badge,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      agentId: json['agentId'] ?? '',
      agentName: json['agentName'] ?? 'Unknown',
      agentEmoji: json['agentEmoji'] ?? '🤖',
      value: json['value'] ?? 0,
      badge: json['badge'],
    );
  }
}

/// Agent Achievements & Leaderboard Screen
/// 
/// Features:
/// - Daily/weekly/monthly leaderboards
/// - Achievement badges with progress
/// - Metric filtering (tokens, tasks, uptime)
/// - Animated rank changes
class AgentAchievementsScreen extends StatefulWidget {
  final List<AgentSession> agents;

  const AgentAchievementsScreen({super.key, required this.agents});

  @override
  State<AgentAchievementsScreen> createState() => _AgentAchievementsScreenState();
}

class _AgentAchievementsScreenState extends State<AgentAchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedMetric = 'tokens';
  String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00D4AA),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF00D4AA),
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(),
          _buildAchievementsTab(),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        // Metric selector
        _buildMetricSelector(),
        // Leaderboard list
        Expanded(
          child: _buildLeaderboardList(),
        ),
      ],
    );
  }

  Widget _buildMetricSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort by',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricChip('Tokens', 'tokens', Icons.token),
                const SizedBox(width: 8),
                _buildMetricChip('Tasks', 'tasks', Icons.task),
                const SizedBox(width: 8),
                _buildMetricChip('Uptime', 'uptime', Icons.schedule),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon) {
    final isSelected = _selectedMetric == value;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? const Color(0xFF00D4AA) : Colors.grey[500],
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedMetric = value);
      },
      selectedColor: const Color(0xFF00D4AA).withOpacity(0.2),
      backgroundColor: Colors.grey[850],
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF00D4AA) : Colors.grey[400],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    final entries = _getLeaderboardEntries();

    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length + 1, // +1 for podium section
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildPodiumSection(entries.take(3).toList());
        }
        final entry = entries[index - 1];
        if (entry.rank <= 3) return const SizedBox.shrink(); // Already in podium
        return _buildLeaderboardCard(entry);
      },
    );
  }

  List<LeaderboardEntry> _getLeaderboardEntries() {
    final sortedAgents = List<AgentSession>.from(widget.agents);

    switch (_selectedMetric) {
      case 'tokens':
        sortedAgents.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
        break;
      case 'tasks':
        // Sort by total tasks if available, otherwise by tokens
        sortedAgents.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
        break;
      case 'uptime':
        // Sort by last activity
        sortedAgents.sort((a, b) {
          final aTime = a.lastActivity?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastActivity?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
        break;
    }

    return sortedAgents.asMap().entries.map((entry) {
      final index = entry.key;
      final agent = entry.value;
      int value;

      switch (_selectedMetric) {
        case 'tokens':
          value = agent.totalTokens;
          break;
        case 'tasks':
          value = agent.totalTokens ~/ 1000; // Approximation
          break;
        case 'uptime':
          value = agent.lastActivity != null
              ? DateTime.now().difference(agent.lastActivity!).inMinutes
              : 0;
          break;
        default:
          value = agent.totalTokens;
      }

      String? badge;
      if (index == 0) badge = '🥇';
      else if (index == 1) badge = '🥈';
      else if (index == 2) badge = '🥉';

      return LeaderboardEntry(
        rank: index + 1,
        agentId: agent.id,
        agentName: agent.name,
        agentEmoji: agent.emoji ?? '🤖',
        value: value,
        badge: badge,
      );
    }).toList();
  }

  Widget _buildPodiumSection(List<LeaderboardEntry> top3) {
    if (top3.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00D4AA).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // First place (center)
          if (top3.isNotEmpty) _buildPodiumPlace(top3[0], 1),
          const SizedBox(height: 8),
          // Second and third (side by side)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (top3.length > 1) _buildPodiumPlace(top3[1], 2),
              if (top3.length > 2) _buildPodiumPlace(top3[2], 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(LeaderboardEntry entry, int place) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    return Container(
      width: place == 1 ? 120 : 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[place - 1], width: 2),
      ),
      child: Column(
        children: [
          // Rank badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors[place - 1].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.badge ?? '#$place',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Avatar
          Text(entry.agentEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          // Name
          Text(
            entry.agentName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Value
          Text(
            _formatValue(entry.value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors[place - 1],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(LeaderboardEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(entry.agentEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.agentName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          _formatValue(entry.value),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D4AA),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsTab() {
    final achievements = _getAchievements();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAchievementsHeader();
        }
        final achievement = achievements[index - 1];
        return _buildAchievementCard(achievement);
      },
    );
  }

  Widget _buildAchievementsHeader() {
    final unlocked = _getAchievements().where((a) => a.unlocked).length;
    final total = _getAchievements().length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4AA), Color(0xFF00A388)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            '$unlocked / $total',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Achievements Unlocked',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: total > 0 ? unlocked / total : 0,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  List<Achievement> _getAchievements() {
    // Sample achievements - in real app, these would come from API
    return [
      Achievement(
        id: 'first_task',
        name: 'First Steps',
        description: 'Complete your first task',
        icon: '🎯',
        requiredValue: 1,
        category: 'tasks',
        unlocked: widget.agents.any((a) => a.totalTokens > 0),
      ),
      Achievement(
        id: 'token_1k',
        name: 'Token Collector',
        description: 'Process 1,000 tokens',
        icon: '💎',
        requiredValue: 1000,
        category: 'tokens',
        unlocked: widget.agents.fold(0, (sum, a) => sum + a.totalTokens) >= 1000,
      ),
      Achievement(
        id: 'token_10k',
        name: 'Token Master',
        description: 'Process 10,000 tokens',
        icon: '🔥',
        requiredValue: 10000,
        category: 'tokens',
        unlocked: widget.agents.fold(0, (sum, a) => sum + a.totalTokens) >= 10000,
      ),
      Achievement(
        id: 'token_100k',
        name: 'Token Lord',
        description: 'Process 100,000 tokens',
        icon: '👑',
        requiredValue: 100000,
        category: 'tokens',
        unlocked: widget.agents.fold(0, (sum, a) => sum + a.totalTokens) >= 100000,
      ),
      Achievement(
        id: 'multi_agent',
        name: 'Team Player',
        description: 'Have 3+ agents active',
        icon: '👥',
        requiredValue: 3,
        category: 'general',
        unlocked: widget.agents.length >= 3,
      ),
      Achievement(
        id: 'subagent',
        name: 'Multiplying',
        description: 'Spawn a subagent',
        icon: '🔀',
        requiredValue: 1,
        category: 'general',
        unlocked: widget.agents.any((a) => a.isSubagent),
      ),
      Achievement(
        id: 'uptime_1h',
        name: 'Dedicated',
        description: 'Stay active for 1 hour',
        icon: '⏱️',
        requiredValue: 3600,
        category: 'uptime',
        unlocked: false, // Would need actual uptime tracking
      ),
      Achievement(
        id: 'uptime_24h',
        name: 'Marathon Runner',
        description: 'Stay active for 24 hours',
        icon: '🏃',
        requiredValue: 86400,
        category: 'uptime',
        unlocked: false,
      ),
      Achievement(
        id: 'all_tools',
        name: 'Jack of All Trades',
        description: 'Use all available tools',
        icon: '🛠️',
        requiredValue: 10,
        category: 'tools',
        unlocked: false,
      ),
      Achievement(
        id: 'no_errors',
        name: 'Flawless',
        description: 'Complete 10 tasks without errors',
        icon: '✨',
        requiredValue: 10,
        category: 'tasks',
        unlocked: false,
      ),
    ];
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final progress = _getAchievementProgress(achievement);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: achievement.unlocked ? Colors.grey[800] : Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: achievement.unlocked
            ? const BorderSide(color: Color(0xFF00D4AA), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: achievement.unlocked
                    ? const Color(0xFF00D4AA).withOpacity(0.2)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Opacity(
                  opacity: achievement.unlocked ? 1.0 : 0.4,
                  child: Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: achievement.unlocked
                                ? const Color(0xFF00D4AA)
                                : Colors.white,
                          ),
                        ),
                      ),
                      if (achievement.unlocked)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF00D4AA),
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  if (!achievement.unlocked) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF00D4AA),
                        ),
                        minHeight: 4,
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

  double _getAchievementProgress(Achievement achievement) {
    switch (achievement.category) {
      case 'tokens':
        final total = widget.agents.fold(0, (sum, a) => sum + a.totalTokens);
        return (total / achievement.requiredValue).clamp(0.0, 1.0);
      case 'general':
        if (achievement.id == 'multi_agent') {
          return (widget.agents.length / achievement.requiredValue).clamp(0.0, 1.0);
        }
        if (achievement.id == 'subagent') {
          return widget.agents.any((a) => a.isSubagent) ? 1.0 : 0.0;
        }
        return 0.0;
      default:
        return 0.0;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No agents yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start an OpenClaw session to see the leaderboard',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatValue(int value) {
    switch (_selectedMetric) {
      case 'tokens':
        if (value >= 1000000) {
          return '${(value / 1000000).toStringAsFixed(1)}M';
        } else if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(1)}K';
        }
        return value.toString();
      case 'tasks':
        return value.toString();
      case 'uptime':
        if (value >= 60) {
          return '${value ~/ 60}h ${value % 60}m';
        }
        return '${value}m';
      default:
        return value.toString();
    }
  }
}