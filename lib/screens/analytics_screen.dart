import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../services/export_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final ExportService _exportService = ExportService();
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<UsageStatistics> _weeklyStats = [];
  Map<String, int> _actionBreakdown = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _analyticsService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _analyticsService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await _analyticsService.initialize();
    
    final summary = _analyticsService.getStatisticsSummary();
    final weeklyStats = await _analyticsService.getUsageStatistics(
      startDate: DateTime.now().subtract(const Duration(days: 7)),
    );
    final actionBreakdown = _analyticsService.getActionBreakdown(
      since: DateTime.now().subtract(const Duration(days: 7)),
    );
    
    setState(() {
      _summary = summary;
      _weeklyStats = weeklyStats;
      _actionBreakdown = actionBreakdown;
      _isLoading = false;
    });
  }

  Future<void> _exportAnalytics() async {
    final json = await _analyticsService.exportToJson();
    
    final result = await _exportService.exportData(
      dataType: ExportDataType.analytics,
      format: ExportFormat.json,
      data: jsonDecode(json) as Map<String, dynamic>,
    );
    
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Analytics exported to ${result.filePath}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _exportService.shareExportedFile(result.filePath!),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Export failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAnalytics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Analytics'),
          ],
        ),
        content: const Text(
          'This will delete all analytics data. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _analyticsService.clearAllData();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Analytics cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportAnalytics,
            tooltip: 'Export',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Clear Analytics'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Today's Stats
                _buildTodayCard(),
                const SizedBox(height: 16),

                // Total Stats
                _buildTotalStatsCard(),
                const SizedBox(height: 16),

                // Weekly Activity
                _buildWeeklyActivityCard(),
                const SizedBox(height: 16),

                // Top Actions
                _buildTopActionsCard(),
                const SizedBox(height: 16),

                // Usage Chart
                _buildUsageChartCard(),
                const SizedBox(height: 24),

                // Privacy Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.privacy_tip, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Privacy First',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• All analytics are stored locally on your device\n'
                        '• No data is sent to external servers\n'
                        '• You can export or delete your data anytime',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTodayCard() {
    final today = _summary['today'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('EEEE, MMM d').format(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatBox(
                  'Messages',
                  '${today['messagesCount'] ?? 0}',
                  Icons.chat,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildStatBox(
                  'Actions',
                  '${today['actionsCount'] ?? 0}',
                  Icons.bolt,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatBox(
                  'Time',
                  '${today['totalTime'] ?? 0}m',
                  Icons.timer,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Total Sessions',
              '${_summary['totalSessions'] ?? 0}',
              Icons.login,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Total Messages',
              '${_summary['totalMessages'] ?? 0}',
              Icons.chat,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Total Actions',
              '${_summary['totalActions'] ?? 0}',
              Icons.bolt,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Gateway Connections',
              '${_summary['totalGatewayConnections'] ?? 0}',
              Icons.wifi,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Total Time',
              '${_summary['totalDuration'] ?? 0} minutes',
              Icons.timer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildWeeklyBars(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _buildDayLabels(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeeklyBars() {
    final bars = <Widget>[];
    int maxValue = 1;
    
    for (final stat in _weeklyStats) {
      if (stat.actionsCount > maxValue) maxValue = stat.actionsCount;
    }
    
    for (final stat in _weeklyStats) {
      final height = (stat.actionsCount / maxValue * 100).clamp(10.0, 100.0);
      bars.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }
    
    return bars;
  }

  List<Widget> _buildDayLabels() {
    return _weeklyStats.map((stat) {
      return Expanded(
        child: Text(
          DateFormat('E').format(stat.date),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }).toList();
  }

  Widget _buildTopActionsCard() {
    final topActions = _summary['topActions'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Actions (This Week)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (topActions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No actions recorded yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topActions.length,
                itemBuilder: (context, index) {
                  final action = topActions[index] as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(action['name'] ?? 'Unknown'),
                    trailing: Text(
                      '${action['count']}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Action Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_actionBreakdown.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No action data available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _actionBreakdown.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}