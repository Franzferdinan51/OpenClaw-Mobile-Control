/// Model Hub - OpenClaw Model Configuration & Usage Analytics
/// Configure which models OpenClaw uses and view usage statistics
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelHubScreen extends StatefulWidget {
  const ModelHubScreen({super.key});

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Model configurations
  String _selectedMainModel = 'bailian/qwen3.5-plus';
  String _selectedSubagentModel = 'bailian/MiniMax-M2.5';
  String _selectedVisionModel = 'bailian/kimi-k2.5';
  String _selectedCodeModel = 'bailian/glm-5';
  
  // Mock usage data (would come from gateway in real implementation)
  final Map<String, Map<String, dynamic>> _modelUsage = {
    'bailian/qwen3.5-plus': {'used': 8200, 'limit': 18000, 'unit': 'msgs', 'cost': 0.0},
    'bailian/MiniMax-M2.5': {'used': 15000, 'limit': null, 'unit': 'msgs', 'cost': 0.0},
    'bailian/kimi-k2.5': {'used': 5000, 'limit': null, 'unit': 'msgs', 'cost': 0.0},
    'bailian/glm-5': {'used': 3200, 'limit': null, 'unit': 'msgs', 'cost': 0.0},
    'openai-codex/gpt-5.3-codex': {'used': 45, 'limit': 200, 'unit': 'msgs/day', 'cost': 20.0},
  };
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadModelSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModelSettings() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMainModel = prefs.getString('main_model') ?? 'bailian/qwen3.5-plus';
      _selectedSubagentModel = prefs.getString('subagent_model') ?? 'bailian/MiniMax-M2.5';
      _selectedVisionModel = prefs.getString('vision_model') ?? 'bailian/kimi-k2.5';
      _selectedCodeModel = prefs.getString('code_model') ?? 'bailian/glm-5';
    });
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveModelSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('main_model', _selectedMainModel);
    await prefs.setString('subagent_model', _selectedSubagentModel);
    await prefs.setString('vision_model', _selectedVisionModel);
    await prefs.setString('code_model', _selectedCodeModel);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model settings saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Config'),
            Tab(icon: Icon(Icons.analytics), text: 'Usage'),
            Tab(icon: Icon(Icons.speed), text: 'Performance'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveModelSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigTab(),
          _buildUsageTab(),
          _buildPerformanceTab(),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Card(
            color: Colors.blue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Configuration',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure which AI models OpenClaw uses for different tasks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Main Chat Model
          _buildModelSelector(
            'Main Chat Model',
            'Used for direct chat and complex reasoning',
            _selectedMainModel,
            (value) => setState(() => _selectedMainModel = value!),
            [
              {'value': 'bailian/qwen3.5-plus', 'label': 'Qwen 3.5 Plus (Best)'},
              {'value': 'bailian/glm-5', 'label': 'GLM-5 (Fast)'},
              {'value': 'bailian/glm-4.7', 'label': 'GLM-4.7 (Fallback)'},
              {'value': 'openai-codex/gpt-5.3-codex', 'label': 'OpenAI Codex (Complex Architecture)'},
            ],
          ),
          const SizedBox(height: 16),
          
          // Sub-Agent Model
          _buildModelSelector(
            'Sub-Agent Model',
            'Used for background tasks and automation',
            _selectedSubagentModel,
            (value) => setState(() => _selectedSubagentModel = value!),
            [
              {'value': 'bailian/MiniMax-M2.5', 'label': 'MiniMax-M2.5 (High Quota)'},
              {'value': 'bailian/glm-5', 'label': 'GLM-5 (Fast)'},
              {'value': 'openai-codex/gpt-5.3-codex', 'label': 'OpenAI Codex (Complex Tasks)'},
            ],
          ),
          const SizedBox(height: 16),
          
          // Vision Model
          _buildModelSelector(
            'Vision Model',
            'Used for image analysis and screen understanding',
            _selectedVisionModel,
            (value) => setState(() => _selectedVisionModel = value!),
            [
              {'value': 'bailian/kimi-k2.5', 'label': 'Kimi K2.5 (High Quota)'},
              {'value': 'bailian/qwen3.5-plus', 'label': 'Qwen 3.5 Plus (Best)'},
              {'value': 'openai-codex/gpt-5.3-codex', 'label': 'OpenAI Codex (Complex Analysis)'},
            ],
          ),
          const SizedBox(height: 16),
          
          // Code Model
          _buildModelSelector(
            'Code Model',
            'Used for code generation and review',
            _selectedCodeModel,
            (value) => setState(() => _selectedCodeModel = value!),
            [
              {'value': 'bailian/glm-5', 'label': 'GLM-5 (Fast)'},
              {'value': 'bailian/qwen3.5-plus', 'label': 'Qwen 3.5 Plus (Best)'},
              {'value': 'openai-codex/gpt-5.3-codex', 'label': 'OpenAI Codex (Coding Specialist)'},
            ],
          ),
          const SizedBox(height: 32),
          
          // Model Info Card
          Card(
            color: Colors.blue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Model Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('🔷 MiniMax-M2.5', 'High quota - Sub-agents'),
                  _buildInfoRow('🔷 Kimi K2.5', 'High quota - Vision tasks'),
                  const SizedBox(height: 8),
                  _buildInfoRow('💎 Qwen 3.5 Plus', '18K messages/month quota'),
                  _buildInfoRow('💎 GLM-5', 'API credits required'),
                  _buildInfoRow('🤖 OpenAI Codex', 'Specialized for coding'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Model Usage (This Month)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._modelUsage.entries.map((entry) => _buildUsageBar(
                    entry.key.split('/').last,
                    entry.value['used'] as int,
                    entry.value['limit'] as int?,
                    entry.value['unit'] as String,
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Cost Summary
          Card(
            color: Colors.orange.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Usage Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Model usage is tracked against your Alibaba Bailian quota.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• MiniMax-M2.5: High quota (recommended for sub-agents)\n• Kimi K2.5: High quota (recommended for vision)\n• Qwen 3.5 Plus: 18K messages/month\n• GLM-5: API credits\n• OpenAI Codex: \$20/month subscription',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Model Performance',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildModelPerformanceCard(
                    'Qwen 3.5 Plus',
                    'Best for complex reasoning',
                    83.2,
                    'MMLU Score',
                    'Fast',
                    'High',
                  ),
                  const SizedBox(height: 12),
                  _buildModelPerformanceCard(
                    'MiniMax-M2.5',
                    'Best for sub-agents (FREE)',
                    76.4,
                    'MMLU Score',
                    'Very Fast',
                    'Medium',
                  ),
                  const SizedBox(height: 12),
                  _buildModelPerformanceCard(
                    'Kimi K2.5',
                    'Best for vision (High Quota)',
                    78.9,
                    'MMLU Score',
                    'Fast',
                    'High',
                  ),
                  const SizedBox(height: 12),
                  _buildModelPerformanceCard(
                    'GLM-5',
                    'Best for coding',
                    81.5,
                    'MMLU Score',
                    'Very Fast',
                    'Medium',
                  ),
                  const SizedBox(height: 12),
                  _buildModelPerformanceCard(
                    'OpenAI Codex',
                    'Best for complex architecture',
                    92.0,
                    'MMLU Score',
                    'Medium',
                    'Highest',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Recommendations
          Card(
            color: Colors.blue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Recommendations',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendation(
                    'For sub-agents',
                    'Use MiniMax-M2.5 (High quota, good performance)',
                  ),
                  const SizedBox(height: 8),
                  _buildRecommendation(
                    'For vision tasks',
                    'Use Kimi K2.5 (High quota, vision-capable)',
                  ),
                  const SizedBox(height: 8),
                  _buildRecommendation(
                    'For complex chat',
                    'Use Qwen 3.5 Plus (best reasoning, limited quota)',
                  ),
                  const SizedBox(height: 8),
                  _buildRecommendation(
                    'For coding',
                    'Use GLM-5 (fast, good code generation)',
                  ),
                  const SizedBox(height: 8),
                  _buildRecommendation(
                    'For complex architecture',
                    'Use OpenAI Codex (best for critical code, \$20/mo)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(
    String title,
    String description,
    String currentValue,
    ValueChanged<String?> onChanged,
    List<Map<String, String>> options,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: currentValue,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: options.map((opt) => DropdownMenuItem(
                value: opt['value'],
                child: Text(opt['label']!),
              )).toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBar(String name, int used, int? limit, String unit) {
    final percentage = limit != null ? (used / limit).clamp(0.0, 1.0) : null;
    final color = limit != null && percentage! > 0.9 ? Colors.red : 
                  limit != null && percentage! > 0.7 ? Colors.orange : Colors.green;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: Theme.of(context).textTheme.labelLarge),
              Text(
                limit != null ? '$used / $limit $unit' : '$used $unit (∞)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: limit != null ? percentage! : null, // null shows indeterminate animation for unlimited
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelPerformanceCard(
    String name,
    String description,
    double score,
    String metric,
    String speed,
    String quality,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBadge(score.toStringAsFixed(1), metric),
                      const SizedBox(width: 8),
                      _buildBadge(speed, 'Speed'),
                      const SizedBox(width: 8),
                      _buildBadge(quality, 'Quality'),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildRecommendation(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
