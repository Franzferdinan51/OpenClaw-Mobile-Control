import 'package:flutter/material.dart';
import '../services/token_service.dart';

/// Screen showing token usage statistics and quota
class TokenUsageScreen extends StatefulWidget {
  final TokenService tokenService;

  const TokenUsageScreen({
    super.key,
    required this.tokenService,
  });

  @override
  State<TokenUsageScreen> createState() => _TokenUsageScreenState();
}

class _TokenUsageScreenState extends State<TokenUsageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.tokenService.resetSessionCounter(),
            tooltip: 'Reset session counter',
          ),
        ],
      ),
      body: StreamBuilder<TokenUsage?>(
        stream: widget.tokenService.sessionUsageStream,
        initialData: widget.tokenService.currentSessionUsage,
        builder: (context, snapshot) {
          final sessionUsage = snapshot.data;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Usage Card
                _buildSessionUsageCard(sessionUsage),
                const SizedBox(height: 16),
                
                // Quota Card
                StreamBuilder<TokenQuota?>(
                  stream: widget.tokenService.quotaStream,
                  initialData: widget.tokenService.quota,
                  builder: (context, snapshot) {
                    return _buildQuotaCard(snapshot.data);
                  },
                ),
                const SizedBox(height: 16),
                
                // Usage Tips
                _buildUsageTips(),
                const SizedBox(height: 16),
                
                // Daily Usage Chart
                _buildDailyUsageChart(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionUsageCard(TokenUsage? usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Session Usage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: Color(0xFF00D4AA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Token display
            Center(
              child: Column(
                children: [
                  Text(
                    '${widget.tokenService.sessionTotalTokens.toLocaleString()}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D4AA),
                    ),
                  ),
                  const Text(
                    'Total Tokens',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Prompt',
                    widget.tokenService.sessionPromptTokens,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    'Completion',
                    widget.tokenService.sessionCompletionTokens,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cost estimate
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('Estimated Cost'),
                    ],
                  ),
                  Text(
                    '\$${widget.tokenService.sessionEstimatedCost.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reset button
            Center(
              child: TextButton.icon(
                onPressed: () => _showResetConfirmation(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Session Counter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toLocaleString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(TokenQuota? quota) {
    if (quota == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Quota',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Quota information not available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Quota',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (quota.resetDate != null)
                  Text(
                    'Resets: ${_formatDate(quota.resetDate!)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Monthly progress
            _buildProgressBar(
              'Monthly',
              quota.usedThisMonth,
              quota.monthlyLimit,
              quota.isMonthWarning,
              quota.isMonthCritical,
            ),
            const SizedBox(height: 16),
            
            // Weekly progress
            _buildProgressBar(
              'Weekly',
              quota.usedThisWeek,
              quota.weeklyLimit,
              quota.isWeekWarning,
              quota.isWeekCritical,
            ),
            const SizedBox(height: 20),
            
            // Warning message
            if (quota.isMonthWarning || quota.isWeekWarning)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (quota.isMonthCritical ? Colors.red : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: quota.isMonthCritical ? Colors.red : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      quota.isMonthCritical ? Icons.warning : Icons.info,
                      color: quota.isMonthCritical ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quota.isMonthCritical
                            ? '⚠️ You\'ve used ${quota.monthPercentage.toStringAsFixed(0)}% of your monthly quota!'
                            : 'You\'ve used ${quota.weekPercentage.toStringAsFixed(0)}% of your weekly quota.',
                        style: TextStyle(
                          color: quota.isMonthCritical ? Colors.red : Colors.orange,
                        ),
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

  Widget _buildProgressBar(
    String label,
    int used,
    int total,
    bool isWarning,
    bool isCritical,
  ) {
    final percentage = total > 0 ? (used / total) * 100 : 0.0;
    final color = isCritical ? Colors.red : isWarning ? Colors.orange : const Color(0xFF00D4AA);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${used.toLocaleString()} / ${total.toLocaleString()}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}% used',
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tips to Reduce Token Usage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTip(
              Icons.compress,
              'Compact Sessions',
              'Summarize old conversations to save context space.',
            ),
            const SizedBox(height: 12),
            _buildTip(
              Icons.psychology,
              'Use Efficient Models',
              'Switch to faster models for simple tasks.',
            ),
            const SizedBox(height: 12),
            _buildTip(
              Icons.delete_sweep,
              'Clear Context',
              'Reset session context when starting a new topic.',
            ),
            const SizedBox(height: 12),
            _buildTip(
              Icons.list,
              'Be Concise',
              'Shorter prompts use fewer tokens.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF00D4AA)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyUsageChart() {
    final dailyUsage = widget.tokenService.getDailyUsageSummary(days: 7);
    final maxTokens = dailyUsage.values.isEmpty
        ? 1
        : dailyUsage.values.reduce((a, b) => a > b ? a : b);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 Days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dailyUsage.entries.map((entry) {
                  final percentage = maxTokens > 0
                      ? entry.value / maxTokens
                      : 0.0;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatShortDate(entry.key),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 100 * percentage,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4AA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value > 1000
                                ? '${(entry.value / 1000).toStringAsFixed(1)}K'
                                : entry.value.toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatShortDate(DateTime date) {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdays[date.weekday - 1];
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Session Counter'),
        content: const Text(
          'This will reset the current session token counter to zero. '
          'Your usage history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.tokenService.resetSessionCounter();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session counter reset'),
                  backgroundColor: Color(0xFF00D4AA),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toLocaleString() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}