import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/event_bus.dart';
import '../services/webhook_server.dart';
import '../services/automation_engine.dart';
import '../services/scripting_engine.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  final Uuid _uuid = const Uuid();
  
  // Services
  late WebhookServer _webhookServer;
  late AutomationEngine _automationEngine;
  late ScriptingEngine _scriptingEngine;
  
  // State
  int _selectedTab = 0;
  bool _isLoading = true;
  
  // Webhooks
  List<WebhookConfig> _webhooks = [];
  final _webhookUrlController = TextEditingController();
  final _webhookNameController = TextEditingController();
  final _webhookSecretController = TextEditingController();

  // Automations
  List<AutomationRule> _rules = [];
  
  // Scripts
  List<SavedScript> _scripts = [];
  final _scriptNameController = TextEditingController();
  final _scriptCodeController = TextEditingController();
  
  // Secret
  String? _incomingSecret;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _webhookServer = WebhookServer();
    _automationEngine = AutomationEngine();
    _scriptingEngine = ScriptingEngine();
    
    await _webhookServer.initialize();
    await _automationEngine.initialize();
    await _scriptingEngine.initialize();
    
    setState(() {
      _webhooks = _webhookServer.webhooks;
      _rules = _automationEngine.rules;
      _scripts = _scriptingEngine.scripts;
      _incomingSecret = _webhookServer.incomingSecret;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _webhookNameController.dispose();
    _webhookSecretController.dispose();
    _scriptNameController.dispose();
    _scriptCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation & Webhooks'),
        bottom: TabBar(
          onTap: (index) => setState(() => _selectedTab = index),
          tabs: const [
            Tab(icon: Icon(Icons.webhook), text: 'Webhooks'),
            Tab(icon: Icon(Icons.schedule), text: 'Automation'),
            Tab(icon: Icon(Icons.code), text: 'Scripts'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            children: [
              _buildWebhooksTab(),
              _buildAutomationTab(),
              _buildScriptsTab(),
            ],
          ),
    );
  }

  // ==================== WEBHOOKS TAB ====================
  Widget _buildWebhooksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Secret Configuration
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Webhook Security', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a secret to authenticate incoming webhooks:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _webhookSecretController,
                        decoration: InputDecoration(
                          hintText: _incomingSecret ?? 'Enter webhook secret',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveSecret,
                      child: const Text('Save'),
                    ),
                  ],
                ),
                if (_incomingSecret != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Current secret configured ✅',
                      style: TextStyle(color: Colors.green[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Outgoing Webhooks
        Row(
          children: [
            const Text('Outgoing Webhooks', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _showAddWebhookDialog,
            ),
          ],
        ),
        
        if (_webhooks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.webhook, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No webhooks configured', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddWebhookDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Webhook'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._webhooks.map((webhook) => Card(
            child: ListTile(
              leading: Icon(
                webhook.enabled ? Icons.check_circle : Icons.pause_circle,
                color: webhook.enabled ? Colors.green : Colors.grey,
              ),
              title: Text(webhook.name),
              subtitle: Text('${webhook.url}\nEvents: ${webhook.events.join(", ")}'),
              isThreeLine: true,
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'toggle', child: Text('Toggle')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) {
                  if (value == 'delete') _deleteWebhook(webhook.id);
                  else if (value == 'toggle') _toggleWebhook(webhook);
                },
              ),
            ),
          )),
        
        const SizedBox(height: 24),
        
        // Incoming Webhook Info
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Incoming Webhooks', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Use a tunneling service (ngrok, cloudflare tunnel) '
                  'to receive webhooks on mobile. Then use:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('POST /webhook/action/{actionId}', 
                        style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      const Text('POST /webhook/chat/{message}', 
                        style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      const Text('POST /webhook/control/{command}', 
                        style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                      const SizedBox(height: 8),
                      Text('Header: X-Webhook-Secret: ${_incomingSecret ?? "your-secret"}',
                        style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSecret() async {
    if (_webhookSecretController.text.isNotEmpty) {
      await _webhookServer.setSecret(_webhookSecretController.text);
      setState(() => _incomingSecret = _webhookSecretController.text);
      _webhookSecretController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook secret saved')),
        );
      }
    }
  }

  void _showAddWebhookDialog() {
    _webhookNameController.clear();
    _webhookUrlController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Webhook'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _webhookNameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _webhookUrlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
                hintText: 'https://webhook.site/...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addWebhook();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWebhook() async {
    final webhook = WebhookConfig(
      id: _uuid.v4(),
      name: _webhookNameController.text,
      url: _webhookUrlController.text,
    );
    await _webhookServer.addWebhook(webhook);
    setState(() => _webhooks = _webhookServer.webhooks);
  }

  Future<void> _deleteWebhook(String id) async {
    await _webhookServer.removeWebhook(id);
    setState(() => _webhooks = _webhookServer.webhooks);
  }

  Future<void> _toggleWebhook(WebhookConfig webhook) async {
    await _webhookServer.updateWebhook(webhook.copyWith(enabled: !webhook.enabled));
    setState(() => _webhooks = _webhookServer.webhooks);
  }

  // ==================== AUTOMATION TAB ====================
  Widget _buildAutomationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Actions
        Card(
          color: Colors.purple[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Quick Automations', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.refresh, size: 18),
                      label: const Text('Check Gateway Every 5 min'),
                      onPressed: _addGatewayCheckAutomation,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wifi_off, size: 18),
                      label: const Text('Alert on Offline'),
                      onPressed: _addOfflineAlertAutomation,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wb_sunny, size: 18),
                      label: const Text('Morning Check'),
                      onPressed: _addMorningCheckAutomation,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            const Text('Automation Rules', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _showAddAutomationDialog,
            ),
          ],
        ),
        
        if (_rules.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No automation rules', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  const Text('Add quick automations above to get started!'),
                ],
              ),
            ),
          )
        else
          ..._rules.map((rule) => Card(
            child: ListTile(
              leading: Icon(
                rule.enabled ? Icons.play_circle : Icons.pause_circle,
                color: rule.enabled ? Colors.green : Colors.grey,
              ),
              title: Text(rule.name),
              subtitle: Text(
                rule.description ?? 
                '${rule.intervalMinutes != null ? "Every ${rule.intervalMinutes} min" : "On condition"} • '
                '${rule.actions.length} action(s)'
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rule.lastTriggered != null)
                    Text(
                      _formatDate(rule.lastTriggered!),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'toggle', child: Text('Toggle')),
                      const PopupMenuItem(value: 'run', child: Text('Run Now')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') _deleteRule(rule.id);
                      else if (value == 'toggle') _toggleRule(rule);
                      else if (value == 'run') _runRule(rule.id);
                    },
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  void _showAddAutomationDialog() {
    // Simplified dialog - in full version would have form
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Automation'),
        content: const Text('Use the Quick Automations chips above or create custom rules.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addGatewayCheckAutomation() async {
    final rule = AutomationRule(
      id: _uuid.v4(),
      name: 'Check Gateway Every 5 Minutes',
      description: 'Check gateway status every 5 minutes',
      intervalMinutes: 5,
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.checkGateway,
          parameters: {},
        ),
      ],
    );
    await _automationEngine.addRule(rule);
    setState(() => _rules = _automationEngine.rules);
  }

  Future<void> _addOfflineAlertAutomation() async {
    final rule = AutomationRule(
      id: _uuid.v4(),
      name: 'Alert on Gateway Offline',
      description: 'Send notification when gateway goes offline',
      condition: AutomationCondition(
        id: _uuid.v4(),
        type: ConditionType.gatewayOffline,
        parameters: {},
      ),
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.sendNotification,
          parameters: {
            'title': 'Gateway Offline',
            'body': 'The OpenClaw gateway is not responding',
          },
        ),
      ],
    );
    await _automationEngine.addRule(rule);
    setState(() => _rules = _automationEngine.rules);
  }

  Future<void> _addMorningCheckAutomation() async {
    final rule = AutomationRule(
      id: _uuid.v4(),
      name: 'Morning Status Check',
      description: 'Check gateway every morning at 8 AM',
      schedule: '0 8 * * *',
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.checkGateway,
          parameters: {},
        ),
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.sendNotification,
          parameters: {
            'title': 'Morning Check',
            'body': 'Gateway status check complete',
          },
        ),
      ],
    );
    await _automationEngine.addRule(rule);
    setState(() => _rules = _automationEngine.rules);
  }

  Future<void> _deleteRule(String id) async {
    await _automationEngine.removeRule(id);
    setState(() => _rules = _automationEngine.rules);
  }

  Future<void> _toggleRule(AutomationRule rule) async {
    await _automationEngine.updateRule(rule.copyWith(enabled: !rule.enabled));
    setState(() => _rules = _automationEngine.rules);
  }

  Future<void> _runRule(String ruleId) async {
    await _automationEngine.triggerRule(ruleId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Automation triggered!')),
      );
    }
  }

  // ==================== SCRIPTS TAB ====================
  Widget _buildScriptsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info
        Card(
          color: Colors.teal[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Scripting API', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Scripts have access to these functions:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('api.isGatewayOnline() → boolean', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                      Text('api.request(url) → JSON', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                      Text('api.notify(title, body)', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                      Text('api.getState() → object', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                      Text('api.logMsg(message)', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                      Text('await api.sleep(ms)', 
                        style: TextStyle(color: Colors.cyan, fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            const Text('Saved Scripts', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _showAddScriptDialog,
            ),
          ],
        ),
        
        if (_scripts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.code, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No scripts', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          )
        else
          ..._scripts.map((script) => Card(
            child: ListTile(
              leading: Icon(
                script.type == ScriptType.javascript ? Icons.javascript : Icons.code,
                color: Colors.amber,
              ),
              title: Text(script.name),
              subtitle: Text(
                script.description.isNotEmpty 
                  ? script.description 
                  : '${script.code.split("\n").length} lines'
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () => _runScript(script.id),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') _deleteScript(script.id);
                      else if (value == 'edit') _showEditScriptDialog(script);
                    },
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  void _showAddScriptDialog() {
    _scriptNameController.clear();
    _scriptCodeController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Script'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _scriptNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('JavaScript code (use async main() function):'),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: TextField(
                  controller: _scriptCodeController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'async function main() {\n  // your code\n}',
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addScript();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditScriptDialog(SavedScript script) {
    _scriptNameController.text = script.name;
    _scriptCodeController.text = script.code;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Script'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _scriptNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: TextField(
                  controller: _scriptCodeController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateScript(script.id);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addScript() async {
    final script = SavedScript(
      id: _uuid.v4(),
      name: _scriptNameController.text,
      type: ScriptType.javascript,
      code: _scriptCodeController.text,
    );
    await _scriptingEngine.addScript(script);
    setState(() => _scripts = _scriptingEngine.scripts);
  }

  Future<void> _updateScript(String id) async {
    final script = _scripts.firstWhere((s) => s.id == id);
    final updated = script.copyWith(
      name: _scriptNameController.text,
      code: _scriptCodeController.text,
    );
    await _scriptingEngine.updateScript(updated);
    setState(() => _scripts = _scriptingEngine.scripts);
  }

  Future<void> _deleteScript(String id) async {
    await _scriptingEngine.deleteScript(id);
    setState(() => _scripts = _scriptingEngine.scripts);
  }

  Future<void> _runScript(String scriptId) async {
    // Configure API callbacks first
    _scriptingEngine.configure(
      log: (msg) => print('[Script] $msg'),
      sendNotification: (title, body) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title: $body')),
        );
      },
      checkGateway: () async {
        // Would check actual gateway
        return true;
      },
      getAppState: () => {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    final result = await _scriptingEngine.runScript(scriptId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status == ScriptStatus.completed
              ? 'Script completed!'
              : 'Script error: ${result.error}',
          ),
          backgroundColor: result.status == ScriptStatus.completed 
            ? Colors.green : Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}