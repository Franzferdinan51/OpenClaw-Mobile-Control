import 'package:flutter/material.dart';

/// Search settings widget with filtering
class SettingsSearch extends StatefulWidget {
  final Function(String) onSearch;
  final String? hintText;
  final VoidCallback? onClear;

  const SettingsSearch({
    super.key,
    required this.onSearch,
    this.hintText,
    this.onClear,
  });

  @override
  State<SettingsSearch> createState() => _SettingsSearchState();
}

class _SettingsSearchState extends State<SettingsSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onSearch(value);
    setState(() {});
  }

  void _onClear() {
    _controller.clear();
    widget.onSearch('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasFocus 
              ? theme.colorScheme.primary 
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search settings...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Search result item
class SearchResultItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final String? category;

  const SearchResultItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.onTap,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: category != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category!,
                style: theme.textTheme.labelSmall,
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Empty search results
class EmptySearchResults extends StatelessWidget {
  final String query;
  final VoidCallback? onClearSearch;

  const EmptySearchResults({
    super.key,
    required this.query,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'No settings match "$query"',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (onClearSearch != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings search delegate for full-screen search
class SettingsSearchDelegate extends SearchDelegate<String?> {
  final List<SearchableSetting> settings;
  final Function(String) onSettingSelected;

  SettingsSearchDelegate({
    required this.settings,
    required this.onSettingSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = query.isEmpty
        ? settings
        : settings
            .where((s) =>
                s.title.toLowerCase().contains(query.toLowerCase()) ||
                (s.subtitle?.toLowerCase().contains(query.toLowerCase()) ??
                    false) ||
                s.category.toLowerCase().contains(query.toLowerCase()))
            .toList();

    if (results.isEmpty) {
      return EmptySearchResults(
        query: query,
        onClearSearch: () {
          query = '';
          showSuggestions(context);
        },
      );
    }

    // Group by category
    final groupedResults = <String, List<SearchableSetting>>{};
    for (final result in results) {
      groupedResults.putIfAbsent(result.category, () => []).add(result);
    }

    return ListView(
      children: groupedResults.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...entry.value.map((setting) => SearchResultItem(
                  title: setting.title,
                  subtitle: setting.subtitle,
                  icon: setting.icon,
                  iconColor: setting.iconColor,
                  onTap: () {
                    onSettingSelected(setting.id);
                    close(context, setting.id);
                  },
                )),
          ],
        );
      }).toList(),
    );
  }
}

/// Searchable setting model
class SearchableSetting {
  final String id;
  final String title;
  final String? subtitle;
  final String category;
  final IconData icon;
  final Color? iconColor;

  const SearchableSetting({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    required this.icon,
    this.iconColor,
  });
}

/// Helper to generate searchable settings from current settings
List<SearchableSetting> generateSearchableSettings() {
  return [
    // Gateway Settings
    const SearchableSetting(
      id: 'gateway_auto_discover',
      title: 'Auto-discover Gateways',
      subtitle: 'Automatically find gateways on network',
      category: 'Gateway',
      icon: Icons.wifi_find,
    ),
    const SearchableSetting(
      id: 'gateway_manual_entry',
      title: 'Manual Gateway Entry',
      subtitle: 'Enter gateway URL, port, and token',
      category: 'Gateway',
      icon: Icons.edit,
    ),
    const SearchableSetting(
      id: 'gateway_test',
      title: 'Test Connection',
      subtitle: 'Test gateway connectivity',
      category: 'Gateway',
      icon: Icons.network_check,
    ),
    const SearchableSetting(
      id: 'gateway_saved',
      title: 'Saved Gateways',
      subtitle: 'Quick switch between saved gateways',
      category: 'Gateway',
      icon: Icons.bookmark,
    ),
    const SearchableSetting(
      id: 'gateway_default',
      title: 'Default Gateway',
      subtitle: 'Set default gateway for auto-connect',
      category: 'Gateway',
      icon: Icons.star,
    ),

    // App Preferences
    const SearchableSetting(
      id: 'app_theme',
      title: 'Theme',
      subtitle: 'Light, Dark, or System',
      category: 'Preferences',
      icon: Icons.palette,
    ),
    const SearchableSetting(
      id: 'app_language',
      title: 'Language',
      subtitle: 'App display language',
      category: 'Preferences',
      icon: Icons.language,
    ),
    const SearchableSetting(
      id: 'app_notifications',
      title: 'Notifications',
      subtitle: 'Push notification settings',
      category: 'Preferences',
      icon: Icons.notifications,
    ),
    const SearchableSetting(
      id: 'app_refresh',
      title: 'Auto-refresh Interval',
      subtitle: 'How often to refresh data',
      category: 'Preferences',
      icon: Icons.refresh,
    ),
    const SearchableSetting(
      id: 'app_data_saving',
      title: 'Data Saving Mode',
      subtitle: 'Reduce API calls to save data',
      category: 'Preferences',
      icon: Icons.data_saver_off,
    ),

    // Agent Settings
    const SearchableSetting(
      id: 'agent_personality',
      title: 'Default Agent Personality',
      subtitle: 'Choose default AI agent',
      category: 'Agent',
      icon: Icons.psychology,
    ),
    const SearchableSetting(
      id: 'agent_style',
      title: 'Agent Response Style',
      subtitle: 'Concise, Balanced, Detailed, or Technical',
      category: 'Agent',
      icon: Icons.format_size,
    ),
    const SearchableSetting(
      id: 'agent_multi',
      title: 'Multi-agent Mode',
      subtitle: 'Enable multiple simultaneous agents',
      category: 'Agent',
      icon: Icons.groups,
    ),
    const SearchableSetting(
      id: 'agent_timeout',
      title: 'Agent Timeout',
      subtitle: 'Maximum wait time for agent response',
      category: 'Agent',
      icon: Icons.timer,
    ),

    // Voice Settings
    const SearchableSetting(
      id: 'voice_wakeword',
      title: 'Wake Word',
      subtitle: 'Voice activation phrase',
      category: 'Voice',
      icon: Icons.mic,
    ),
    const SearchableSetting(
      id: 'voice_feedback',
      title: 'Voice Feedback',
      subtitle: 'Enable voice responses',
      category: 'Voice',
      icon: Icons.record_voice_over,
    ),
    const SearchableSetting(
      id: 'voice_tts',
      title: 'TTS Voice',
      subtitle: 'Text-to-speech voice selection',
      category: 'Voice',
      icon: Icons.volume_up,
    ),
    const SearchableSetting(
      id: 'voice_speed',
      title: 'TTS Speed',
      subtitle: 'Voice response speed',
      category: 'Voice',
      icon: Icons.speed,
    ),
    const SearchableSetting(
      id: 'voice_continuous',
      title: 'Continuous Listening',
      subtitle: 'Always listen for wake word',
      category: 'Voice',
      icon: Icons.hearing,
    ),

    // BrowserOS Settings
    const SearchableSetting(
      id: 'browseros_url',
      title: 'BrowserOS Server URL',
      subtitle: 'Remote browser control server',
      category: 'BrowserOS',
      icon: Icons.public,
    ),
    const SearchableSetting(
      id: 'browseros_auto',
      title: 'Auto-connect',
      subtitle: 'Connect to BrowserOS on startup',
      category: 'BrowserOS',
      icon: Icons.autorenew,
    ),
    const SearchableSetting(
      id: 'browseros_model',
      title: 'Default Model',
      subtitle: 'AI model for browser control',
      category: 'BrowserOS',
      icon: Icons.smart_toy,
    ),
    const SearchableSetting(
      id: 'browseros_api_key',
      title: 'API Keys',
      subtitle: 'Securely store API keys',
      category: 'BrowserOS',
      icon: Icons.key,
    ),
    const SearchableSetting(
      id: 'browseros_workflow',
      title: 'Workflow Auto-save',
      subtitle: 'Automatically save workflows',
      category: 'BrowserOS',
      icon: Icons.save,
    ),

    // Automation Settings
    const SearchableSetting(
      id: 'automation_webhook',
      title: 'Webhook URL',
      subtitle: 'Incoming webhook endpoint',
      category: 'Automation',
      icon: Icons.webhook,
    ),
    const SearchableSetting(
      id: 'automation_secret',
      title: 'Webhook Secret',
      subtitle: 'Authentication secret',
      category: 'Automation',
      icon: Icons.lock,
    ),
    const SearchableSetting(
      id: 'automation_tasks',
      title: 'Scheduled Tasks',
      subtitle: 'Enable automated tasks',
      category: 'Automation',
      icon: Icons.schedule,
    ),
    const SearchableSetting(
      id: 'automation_notifications',
      title: 'Task Notifications',
      subtitle: 'Notify on task completion',
      category: 'Automation',
      icon: Icons.notifications_active,
    ),
    const SearchableSetting(
      id: 'automation_ifttt',
      title: 'IFTTT Integration',
      subtitle: 'Connect to IFTTT',
      category: 'Automation',
      icon: Icons.link,
    ),

    // Termux Settings
    const SearchableSetting(
      id: 'termux_enabled',
      title: 'Termux Integration',
      subtitle: 'Enable Termux commands',
      category: 'Termux',
      icon: Icons.terminal,
    ),
    const SearchableSetting(
      id: 'termux_auto_install',
      title: 'Auto-install OpenClaw',
      subtitle: 'Install OpenClaw in Termux automatically',
      category: 'Termux',
      icon: Icons.download,
    ),
    const SearchableSetting(
      id: 'termux_shell',
      title: 'Default Shell',
      subtitle: 'Bash, Zsh, or Fish',
      category: 'Termux',
      icon: Icons.code,
    ),
    const SearchableSetting(
      id: 'termux_history',
      title: 'Command History',
      subtitle: 'View and clear command history',
      category: 'Termux',
      icon: Icons.history,
    ),

    // Advanced Settings
    const SearchableSetting(
      id: 'advanced_developer',
      title: 'Developer Mode',
      subtitle: 'Enable developer options',
      category: 'Advanced',
      icon: Icons.developer_mode,
    ),
    const SearchableSetting(
      id: 'advanced_debug',
      title: 'Debug Logging',
      subtitle: 'Enable verbose logging',
      category: 'Advanced',
      icon: Icons.bug_report,
    ),
    const SearchableSetting(
      id: 'advanced_export',
      title: 'Export Logs',
      subtitle: 'Download app logs',
      category: 'Advanced',
      icon: Icons.download,
    ),
    const SearchableSetting(
      id: 'advanced_clear',
      title: 'Clear Cache',
      subtitle: 'Free up storage space',
      category: 'Advanced',
      icon: Icons.delete_sweep,
    ),
    const SearchableSetting(
      id: 'advanced_reset',
      title: 'Reset All Settings',
      subtitle: 'Restore default settings',
      category: 'Advanced',
      icon: Icons.restore,
    ),
    const SearchableSetting(
      id: 'advanced_version',
      title: 'App Version',
      subtitle: 'Current app version',
      category: 'Advanced',
      icon: Icons.info,
    ),
    const SearchableSetting(
      id: 'advanced_update',
      title: 'Check for Updates',
      subtitle: 'Check for new versions',
      category: 'Advanced',
      icon: Icons.system_update,
    ),
    const SearchableSetting(
      id: 'advanced_export_settings',
      title: 'Export Settings',
      subtitle: 'Backup settings to file',
      category: 'Advanced',
      icon: Icons.save_alt,
    ),
    const SearchableSetting(
      id: 'advanced_import_settings',
      title: 'Import Settings',
      subtitle: 'Restore settings from file',
      category: 'Advanced',
      icon: Icons.file_upload,
    ),
  ];
}