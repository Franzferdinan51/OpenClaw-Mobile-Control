import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model Hub - OpenClaw Model Configuration & Usage
/// Configure which AI models OpenClaw uses for different tasks
class ModelHubScreen extends StatefulWidget {
  const ModelHubScreen({super.key});

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  String _selectedMainModel = 'bailian/qwen3.5-plus';
  String _selectedSubagentModel = 'bailian/MiniMax-M2.5';
  String _selectedVisionModel = 'bailian/kimi-k2.5';
  
  bool _isLoading = false;
  Map<String, dynamic> _modelUsage = {};
  Map<String, dynamic> _quotaInfo = {};

  @override
  void initState() {
    super.initState();
    _loadModelSettings();
  }

  Future<void> _loadModelSettings() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMainModel = prefs.getString('main_model') ?? 'bailian/qwen3.5-plus';
      _selectedSubagentModel = prefs.getString('subagent_model') ?? 'bailian/MiniMax-M2.5';
      _selectedVisionModel = prefs.getString('vision_model') ?? 'bailian/kimi-k2.5';
    });
    
    // Mock usage data (would come from gateway in real implementation)
    setState(() {
      _modelUsage = {
        'bailian/qwen3.5-plus': {'used': 8200, 'limit': 18000, 'unit': 'msgs'},
        'bailian/MiniMax-M2.5': {'used': 15000, 'limit': null, 'unit': 'msgs'},
        'bailian/kimi-k2.5': {'used': 5000, 'limit': null, 'unit': 'msgs'},
      };
    });
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveModelSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('main_model', _selectedMainModel);
    await prefs.setString('subagent_model', _selectedSubagentModel);
    await prefs.setString('vision_model', _selectedVisionModel);
    
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
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveModelSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadModelSettings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model Usage Overview
              _buildUsageCard(),
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
                  {'value': 'bailian/MiniMax-M2.5', 'label': 'MiniMax-M2.5 (FREE Unlimited)'},
                  {'value': 'bailian/glm-5', 'label': 'GLM-5 (Fast)'},
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
                  {'value': 'bailian/kimi-k2.5', 'label': 'Kimi K2.5 (FREE Unlimited)'},
                  {'value': 'bailian/qwen3.5-plus', 'label': 'Qwen 3.5 Plus (Best)'},
                ],
              ),
              const SizedBox(height: 24),
              
              // Model Information
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageCard() {
    return Card(
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
              entry.value['used'],
              entry.value['limit'],
              entry.value['unit'],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBar(String name, int used, int? limit, String unit) {
    final percentage = limit != null ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final color = percentage > 0.9 ? Colors.red : percentage > 0.7 ? Colors.orange : Colors.green;
    
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
              value: limit != null ? percentage : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
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

  Widget _buildInfoCard() {
    return Card(
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
            const SizedBox(height: 16),
            _buildInfoRow('🆓 FREE Models', 'MiniMax-M2.5, Kimi K2.5 (Unlimited)'),
            _buildInfoRow('💰 Paid Models', 'Qwen 3.5 Plus (18K/mo quota)'),
            _buildInfoRow('⚡ Fast Models', 'GLM-5, GLM-4.7 (API credits)'),
            _buildInfoRow('🎯 Best Quality', 'Qwen 3.5 Plus (83.2% MMLU)'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All models provided via Alibaba Bailian - unified billing, zero ban risk',
                      style: Theme.of(context).textTheme.bodySmall,
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
}
