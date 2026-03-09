import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Settings Screen - App settings for connection, theme, notifications, etc.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenuAction(action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restore_rounded),
                  title: Text('Reset to Defaults'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_rounded),
                  title: Text('Clear All Data'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          const ConnectionBanner(),
          // Connection section
          _SettingsSection(
            title: 'Connection',
            icon: Icons.link_rounded,
            children: [
              _SettingsTile(
                icon: Icons.dns_rounded,
                title: 'Gateway URL',
                subtitle: settings.gatewayUrl.isNotEmpty
                    ? settings.gatewayUrl
                    : 'Not configured',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showGatewayUrlDialog(context),
              ),
              _SettingsTile(
                icon: Icons.vpn_key_rounded,
                title: 'API Token',
                subtitle: settings.gatewayToken != null
                    ? '••••••••${settings.gatewayToken!.substring(settings.gatewayToken!.length - 4)}'
                    : 'Not configured',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showTokenDialog(context),
              ),
              _SettingsSwitch(
                icon: Icons.sync_rounded,
                title: 'Auto-Connect',
                subtitle: 'Automatically connect on app start',
                value: settings.autoConnect,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleAutoConnect(value),
              ),
              _SettingsTile(
                icon: Icons.timer_rounded,
                title: 'Connection Timeout',
                subtitle: '${settings.connectionTimeout} seconds',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showTimeoutDialog(context, settings.connectionTimeout),
              ),
            ],
          ),
          const Divider(height: 1),
          // Appearance section
          _SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            children: [
              _SettingsTile(
                icon: Icons.brightness_6_rounded,
                title: 'Theme',
                subtitle: _getThemeLabel(settings.themeMode),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemeDialog(context, settings.themeMode),
              ),
              _SettingsTile(
                icon: Icons.text_fields_rounded,
                title: 'Message Font Size',
                subtitle: '${settings.messageFontSize}px',
                trailing: SizedBox(
                  width: 100,
                  child: Slider(
                    value: settings.messageFontSize.toDouble(),
                    min: 12,
                    max: 24,
                    divisions: 12,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setMessageFontSize(value.toInt()),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          // Chat section
          _SettingsSection(
            title: 'Chat',
            icon: Icons.chat_rounded,
            children: [
              _SettingsSwitch(
                icon: Icons.code_rounded,
                title: 'Markdown Rendering',
                subtitle: 'Render markdown in messages',
                value: settings.markdownEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleMarkdown(value),
              ),
              _SettingsSwitch(
                icon: Icons.highlight_rounded,
                title: 'Code Highlighting',
                subtitle: 'Highlight code blocks',
                value: settings.codeHighlightEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleCodeHighlight(value),
              ),
              _SettingsSwitch(
                icon: Icons.access_time_rounded,
                title: 'Show Timestamps',
                subtitle: 'Display message timestamps',
                value: settings.showTimestamps,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleTimestamps(value),
              ),
              _SettingsSwitch(
                icon: Icons.numbers_rounded,
                title: 'Show Token Counts',
                subtitle: 'Display token usage in messages',
                value: settings.showTokenCounts,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleTokenCounts(value),
              ),
              _SettingsTile(
                icon: Icons.pets_rounded,
                title: 'Default Agent',
                subtitle: settings.defaultAgentId.isNotEmpty
                    ? settings.defaultAgentId
                    : 'None selected',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showAgentSelector(context),
              ),
            ],
          ),
          const Divider(height: 1),
          // Notifications section
          _SettingsSection(
            title: 'Notifications',
            icon: Icons.notifications_rounded,
            children: [
              _SettingsSwitch(
                icon: Icons.notifications_active_rounded,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: settings.notificationsEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleNotifications(value),
              ),
              _SettingsSwitch(
                icon: Icons.volume_up_rounded,
                title: 'Sound',
                subtitle: 'Play notification sounds',
                value: settings.soundEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleSound(value),
              ),
              _SettingsSwitch(
                icon: Icons.vibration_rounded,
                title: 'Vibration',
                subtitle: 'Vibrate on notifications',
                value: settings.vibrationEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).toggleVibration(value),
              ),
            ],
          ),
          const Divider(height: 1),
          // Data section
          _SettingsSection(
            title: 'Data & Storage',
            icon: Icons.storage_rounded,
            children: [
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'Message History',
                subtitle: 'Keep last ${settings.maxHistoryDays} days',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showHistoryDialog(context, settings.maxHistoryDays),
              ),
              _SettingsTile(
                icon: Icons.clear_all_rounded,
                title: 'Clear Chat History',
                subtitle: 'Delete all message history',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showClearHistoryDialog(context),
              ),
            ],
          ),
          const Divider(height: 1),
          // About section
          _SettingsSection(
            title: 'About',
            icon: Icons.info_rounded,
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'OpenClaw Mobile',
                subtitle: 'Version 1.0.0',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showAboutDialog(context),
              ),
              _SettingsTile(
                icon: Icons.description_rounded,
                title: 'Privacy Policy',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // TODO: Open privacy policy
                },
              ),
              _SettingsTile(
                icon: Icons.article_rounded,
                title: 'Terms of Service',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // TODO: Open terms of service
                },
              ),
              _SettingsTile(
                icon: Icons.bug_report_rounded,
                title: 'Report a Bug',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // TODO: Open bug report
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 4,
      onDestinationSelected: (index) => _navigateTo(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Control',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: 'Quick',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/chat');
      case 2:
        context.go('/control');
      case 3:
        context.go('/quick-actions');
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'reset':
        _showResetConfirmation(context);
      case 'clear':
        _showClearDataConfirmation(context);
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showGatewayUrlDialog(BuildContext context) {
    final controller = TextEditingController(
      text: ref.read(settingsProvider).gatewayUrl,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gateway URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://localhost:18789',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setGatewayUrl(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context) {
    final controller = TextEditingController(
      text: ref.read(settingsProvider).gatewayToken ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your API token',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setGatewayToken(
                    controller.text.isEmpty ? null : controller.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog(BuildContext context, int currentTimeout) {
    int selectedTimeout = currentTimeout;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Connection Timeout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$selectedTimeout seconds'),
              const SizedBox(height: 16),
              Slider(
                value: selectedTimeout.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (value) => setState(() => selectedTimeout = value.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setConnectionTimeout(selectedTimeout);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeMode currentTheme) {
    ThemeMode selectedTheme = currentTheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System Default'),
                value: ThemeMode.system,
                groupValue: selectedTheme,
                onChanged: (value) => setState(() => selectedTheme = value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: selectedTheme,
                onChanged: (value) => setState(() => selectedTheme = value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: selectedTheme,
                onChanged: (value) => setState(() => selectedTheme = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setThemeMode(selectedTheme);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, int currentDays) {
    int selectedDays = currentDays;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Message History'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Keep last $selectedDays days'),
              const SizedBox(height: 16),
              Slider(
                value: selectedDays.toDouble(),
                min: 7,
                max: 90,
                divisions: 83,
                onChanged: (value) => setState(() => selectedDays = value.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setMaxHistoryDays(selectedDays);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentSelector(BuildContext context) {
    final agents = ref.read(agentsProvider).valueOrNull ?? [];
    final currentAgentId = ref.read(settingsProvider).defaultAgentId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Agent'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: agents.isEmpty
              ? const Center(child: Text('No agents available'))
              : ListView.builder(
                  itemCount: agents.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return RadioListTile<String?>(
                        title: const Text('None'),
                        value: '',
                        groupValue: currentAgentId,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setDefaultAgent('');
                          Navigator.pop(context);
                        },
                      );
                    }

                    final agent = agents[index - 1];
                    return RadioListTile<String?>(
                      title: Text(agent.name),
                      subtitle: Text(agent.model),
                      value: agent.id,
                      groupValue: currentAgentId,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setDefaultAgent(value!);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'This will permanently delete all message history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              // TODO: Implement clear history
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showClearDataConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all app data including settings, chat history, and cached data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(settingsProvider.notifier).clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'OpenClaw Mobile',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.pets_rounded,
          size: 32,
          color: Colors.white,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'OpenClaw Mobile Companion App\n\n'
          'Monitor, control, and chat with your OpenClaw deployment from anywhere.',
        ),
      ],
    );
  }
}

/// Settings Section Widget
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Settings Tile Widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Settings Switch Widget
class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged?.call(!value),
    );
  }
}