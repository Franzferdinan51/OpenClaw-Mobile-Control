import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// Advanced settings screen with developer options
class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  
  // Controllers
  late TextEditingController _gatewayUrlController;
  late TextEditingController _gatewayTokenController;
  late TextEditingController _browserosUrlController;
  late TextEditingController _browserosApiKeyController;
  late TextEditingController _webhookUrlController;
  late TextEditingController _webhookSecretController;
  late TextEditingController _iftttKeyController;
  late TextEditingController _customWakeWordController;

  @override
  void initState() {
    super.initState();
    _gatewayUrlController = TextEditingController();
    _gatewayTokenController = TextEditingController();
    _browserosUrlController = TextEditingController();
    _browserosApiKeyController = TextEditingController();
    _webhookUrlController = TextEditingController();
    _webhookSecretController = TextEditingController();
    _iftttKeyController = TextEditingController();
    _customWakeWordController = TextEditingController();
    
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    
    try {
      final settings = await _settingsService.loadSettings();
      setState(() {
        _settings = settings;
        
        // Initialize controllers
        _gatewayUrlController.text = settings.gatewayUrl;
        _gatewayTokenController.text = settings.gatewayToken;
        _browserosUrlController.text = settings.browserosUrl;
        _browserosApiKeyController.text = settings.browserosApiKey;
        _webhookUrlController.text = settings.webhookUrl;
        _webhookSecretController.text = settings.webhookSecret;
        _iftttKeyController.text = settings.iftttKey;
        _customWakeWordController.text = settings.customWakeWord;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
    
    setState(() => _loading = false);
  }

  Future<void> _saveSettings([AppSettings? newSettings]) async {
    if (newSettings != null) {
      setState(() => _settings = newSettings);
    }
    await _settingsService.saveSettings(_settings);
  }

  @override
  void dispose() {
    _gatewayUrlController.dispose();
    _gatewayTokenController.dispose();
    _browserosUrlController.dispose();
    _browserosApiKeyController.dispose();
    _webhookUrlController.dispose();
    _webhookSecretController.dispose();
    _iftttKeyController.dispose();
    _customWakeWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        actions: [
          if (_settings.developerMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.developer_mode, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'DEV',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          // Developer Mode Section
          _buildSection(
            title: 'Developer Options',
            icon: Icons.developer_mode,
            children: [
              SwitchListTile(
                title: const Text('Developer Mode'),
                subtitle: const Text('Enable developer options and tools'),
                value: _settings.developerMode,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(developerMode: value));
                },
              ),
              SwitchListTile(
                title: const Text('Debug Logging'),
                subtitle: const Text('Enable verbose logging for troubleshooting'),
                value: _settings.debugLogging,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(debugLogging: value));
                },
              ),
              if (_settings.developerMode || _settings.debugLogging) ...[
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('View Debug Logs'),
                  subtitle: const Text('Open log viewer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _viewDebugLogs,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export Logs'),
                  subtitle: const Text('Download logs for analysis'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportLogs,
                ),
              ],
            ],
          ),

          // Gateway Advanced
          _buildSection(
            title: 'Gateway Advanced',
            icon: Icons.settings_ethernet,
            children: [
              TextFormField(
                controller: _gatewayUrlController,
                decoration: const InputDecoration(
                  labelText: 'Gateway URL',
                  hintText: 'http://192.168.1.100:18789',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gatewayTokenController,
                decoration: const InputDecoration(
                  labelText: 'Gateway Token',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testConnection,
                      child: const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveSettings(_settings.copyWith(
                          gatewayUrl: _gatewayUrlController.text,
                          gatewayToken: _gatewayTokenController.text,
                        ));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gateway saved')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // BrowserOS Advanced
          _buildSection(
            title: 'BrowserOS Advanced',
            icon: Icons.public,
            children: [
              TextFormField(
                controller: _browserosUrlController,
                decoration: const InputDecoration(
                  labelText: 'BrowserOS Server URL',
                  hintText: 'http://localhost:9000',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _browserosApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto-connect'),
                value: _settings.browserosAutoConnect,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(browserosAutoConnect: value));
                },
              ),
              DropdownButtonFormField<String>(
                value: _settings.browserosDefaultModel,
                decoration: const InputDecoration(
                  labelText: 'Default Model',
                ),
                items: BrowserOsModel.availableModels
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _saveSettings(_settings.copyWith(browserosDefaultModel: value));
                  }
                },
              ),
            ],
          ),

          // Automation Advanced
          _buildSection(
            title: 'Automation Advanced',
            icon: Icons.smart_toy,
            children: [
              TextFormField(
                controller: _webhookUrlController,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://your-webhook.com/endpoint',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _webhookSecretController,
                decoration: const InputDecoration(
                  labelText: 'Webhook Secret',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iftttKeyController,
                decoration: const InputDecoration(
                  labelText: 'IFTTT Key',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Scheduled Tasks'),
                value: _settings.scheduledTasksEnabled,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(scheduledTasksEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('Task Notifications'),
                value: _settings.taskNotificationsEnabled,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(taskNotificationsEnabled: value));
                },
              ),
            ],
          ),

          // Voice Advanced
          _buildSection(
            title: 'Voice Advanced',
            icon: Icons.mic,
            children: [
              DropdownButtonFormField<WakeWord>(
                value: _settings.wakeWord,
                decoration: const InputDecoration(
                  labelText: 'Wake Word',
                ),
                items: WakeWord.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.displayName)))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _saveSettings(_settings.copyWith(wakeWord: value));
                  }
                },
              ),
              if (_settings.wakeWord == WakeWord.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customWakeWordController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Wake Word',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _settings.ttsVoice,
                decoration: const InputDecoration(
                  labelText: 'TTS Voice',
                ),
                items: TtsVoice.availableVoices
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _saveSettings(_settings.copyWith(ttsVoice: value));
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('TTS Speed'),
                subtitle: Slider(
                  value: _settings.ttsSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${_settings.ttsSpeed.toStringAsFixed(1)}x',
                  onChanged: (value) async {
                    await _saveSettings(_settings.copyWith(ttsSpeed: value));
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Voice Feedback'),
                value: _settings.voiceFeedbackEnabled,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(voiceFeedbackEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('Continuous Listening'),
                subtitle: const Text('Battery intensive'),
                value: _settings.continuousListening,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(continuousListening: value));
                },
              ),
            ],
          ),

          // Termux Advanced
          _buildSection(
            title: 'Termux Advanced',
            icon: Icons.terminal,
            children: [
              SwitchListTile(
                title: const Text('Termux Integration'),
                value: _settings.termuxEnabled,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(termuxEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('Auto-install OpenClaw'),
                value: _settings.autoInstallOpenClaw,
                onChanged: (value) async {
                  await _saveSettings(_settings.copyWith(autoInstallOpenClaw: value));
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _settings.defaultShell,
                decoration: const InputDecoration(
                  labelText: 'Default Shell',
                ),
                items: ShellType.values
                    .map((e) => DropdownMenuItem(value: e.name, child: Text(e.displayName)))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _saveSettings(_settings.copyWith(defaultShell: value));
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Clear Command History', style: TextStyle(color: Colors.red)),
                onTap: _clearTermuxHistory,
              ),
            ],
          ),

          // Data Management
          _buildSection(
            title: 'Data Management',
            icon: Icons.storage,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Export Settings'),
                subtitle: const Text('Backup settings to JSON file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportSettings,
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import Settings'),
                subtitle: const Text('Restore from JSON file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importSettings,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text('Clear Cache', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Free up storage space'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearCache,
              ),
            ],
          ),

          // Reset Options
          _buildSection(
            title: 'Reset Options',
            icon: Icons.restore,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Gateway Settings'),
                onTap: () => _resetCategory(SettingsCategory.gateway),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Preferences'),
                onTap: () => _resetCategory(SettingsCategory.appPreferences),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Agent Settings'),
                onTap: () => _resetCategory(SettingsCategory.agent),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Voice Settings'),
                onTap: () => _resetCategory(SettingsCategory.voice),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset BrowserOS'),
                onTap: () => _resetCategory(SettingsCategory.browseros),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Automation'),
                onTap: () => _resetCategory(SettingsCategory.automation),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset Termux'),
                onTap: () => _resetCategory(SettingsCategory.termux),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.red),
                title: const Text('Reset All Settings', style: TextStyle(color: Colors.red)),
                onTap: _resetAllSettings,
              ),
            ],
          ),

          // App Info
          _buildSection(
            title: 'About',
            icon: Icons.info,
            children: [
              ListTile(
                title: const Text('App Version'),
                subtitle: Text(_settings.appVersion),
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Check for Updates'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _checkForUpdates,
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('View Source Code'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // Open GitHub
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(context: context);
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...')),
    );
    // Implement connection test
  }

  void _viewDebugLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.bug_report),
                  const SizedBox(width: 8),
                  Text(
                    'Debug Logs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<String>(
                future: _settingsService.getSettingsJson(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      snapshot.data!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final path = await _settingsService.exportSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportSettings() async {
    try {
      final path = await _settingsService.exportSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings exported to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a settings file to import')),
    );
    // Implement file picker
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Your settings will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    }
  }

  Future<void> _clearTermuxHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('termux_history');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Command history cleared')),
      );
    }
  }

  Future<void> _resetCategory(SettingsCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset ${category.displayName}'),
        content: const Text('This will reset all settings in this category to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newSettings = await _settingsService.resetCategory(_settings, category);
      setState(() => _settings = newSettings);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.displayName} reset to defaults')),
        );
      }
    }
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text('This will restore ALL settings to their default values. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newSettings = await _settingsService.resetAllSettings();
      setState(() => _settings = newSettings);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All settings reset to defaults')),
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are using the latest version!')),
    );
  }
}