import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/autowork_config.dart';

class AutoworkScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const AutoworkScreen({super.key, this.gatewayService});

  @override
  State<AutoworkScreen> createState() => _AutoworkScreenState();
}

class _AutoworkScreenState extends State<AutoworkScreen> {
  GatewayService? _service;
  AutoworkConfig? _config;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _running = false;

  // Global settings controllers
  late TextEditingController _defaultDirectiveController;
  late TextEditingController _maxSendsController;

  @override
  void initState() {
    super.initState();
    _defaultDirectiveController = TextEditingController();
    _maxSendsController = TextEditingController(text: '3');
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
    await _refreshConfig();
  }

  Future<void> _refreshConfig() async {
    if (_service == null) return;

    setState(() => _loading = true);

    try {
      final config = await _service!.getAutoworkConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
          _error = null;
          _defaultDirectiveController.text = config?.defaultDirective ?? '';
          _maxSendsController.text = (config?.maxSendsPerTick ?? 3).toString();
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

  Future<void> _saveGlobalConfig() async {
    if (_service == null) return;

    setState(() => _saving = true);

    try {
      final maxSends = int.tryParse(_maxSendsController.text) ?? 3;
      final directive = _defaultDirectiveController.text;

      final config = await _service!.updateAutoworkConfig(
        maxSendsPerTick: maxSends,
        defaultDirective: directive,
      );

      if (mounted) {
        if (config != null) {
          setState(() => _config = config);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration saved!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save configuration'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSessionAutowork(String sessionKey, bool enabled) async {
    if (_service == null) return;

    try {
      final config = await _service!.updateAutoworkConfig(
        sessionKey: sessionKey,
        enabled: enabled,
      );

      if (mounted) {
        if (config != null) {
          setState(() => _config = config);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSessionInterval(String sessionKey, int intervalMs) async {
    if (_service == null) return;

    try {
      final config = await _service!.updateAutoworkConfig(
        sessionKey: sessionKey,
        intervalMs: intervalMs,
      );

      if (mounted && config != null) {
        setState(() => _config = config);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runAutowork({String? sessionKey}) async {
    if (_service == null) return;

    setState(() => _running = true);

    try {
      final result = await _service!.runAutowork(sessionKey: sessionKey);

      if (mounted) {
        if (result?['ok'] == true) {
          final sent = (result?['sent'] as List?)?.length ?? 0;
          final skipped = (result?['skipped'] as List?)?.length ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Autowork complete: $sent sent, $skipped skipped'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result?['error'] ?? 'Failed'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _defaultDirectiveController.dispose();
    _maxSendsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autowork'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshConfig,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
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
          Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final config = _config;
    final targets = config?.targets ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Global config card
        _buildGlobalConfigCard(),
        const SizedBox(height: 16),

        // Run now buttons
        _buildActionButtons(),
        const SizedBox(height: 24),

        // Targets header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Agent Autowork Policies', style: Theme.of(context).textTheme.titleLarge),
            Text('${targets.length} agents', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),

        if (targets.isEmpty)
          _buildEmptyState()
        else
          ...targets.map((target) => _buildTargetCard(target)),
      ],
    );
  }

  Widget _buildGlobalConfigCard() {
    final config = _config;
    final isEnabled = (config?.maxSendsPerTick ?? 0) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.play_circle : Icons.pause_circle,
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('Global Autowork', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEnabled ? 'Active' : 'Disabled',
                    style: TextStyle(color: isEnabled ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Max sends per tick
            Row(
              children: [
                const Icon(Icons.speed, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Max sends per tick:'),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _maxSendsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Default directive
            const Text('Default Directive:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _defaultDirectiveController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter default directive for all agents...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[850],
              ),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveGlobalConfig,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Global Config'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _running ? null : () => _runAutowork(),
            icon: _running
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running...' : 'Run All Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No agents available', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start an agent to configure autowork',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(AutoworkTarget target) {
    final policy = _config?.getPolicy(target.sessionKey);
    final isEnabled = policy?.enabled ?? false;
    final intervalMs = policy?.intervalMs ?? 600000;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: const Text('🤖', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(target.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        target.canSend ? 'Can receive autowork' : 'Cannot receive autowork',
                        style: TextStyle(
                          fontSize: 12,
                          color: target.canSend ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled && target.canSend,
                  onChanged: target.canSend
                      ? (value) => _toggleSessionAutowork(target.sessionKey, value)
                      : null,
                  activeColor: const Color(0xFF00D4AA),
                ),
              ],
            ),
            if (isEnabled) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Interval: ', style: TextStyle(color: Colors.grey)),
                  DropdownButton<int>(
                    value: intervalMs,
                    items: const [
                      DropdownMenuItem(value: 300000, child: Text('5 min')),
                      DropdownMenuItem(value: 600000, child: Text('10 min')),
                      DropdownMenuItem(value: 900000, child: Text('15 min')),
                      DropdownMenuItem(value: 1800000, child: Text('30 min')),
                      DropdownMenuItem(value: 3600000, child: Text('1 hour')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _updateSessionInterval(target.sessionKey, value);
                      }
                    },
                  ),
                  const Spacer(),
                  if (policy != null)
                    Text(
                      'Last: ${policy.lastSentDisplay}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _running ? null : () => _runAutowork(sessionKey: target.sessionKey),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run Now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}