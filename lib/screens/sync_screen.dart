import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  final String? gatewayUrl;
  final String? gatewayToken;

  const SyncScreen({
    super.key,
    this.gatewayUrl,
    this.gatewayToken,
  });

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final SyncService _syncService = SyncService();
  bool _isLoading = true;
  List<SyncItemStatus> _syncStatuses = [];

  @override
  void initState() {
    super.initState();
    _initialize();
    _syncService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    if (widget.gatewayUrl != null) {
      _syncService.setGatewayConnection(widget.gatewayUrl!, widget.gatewayToken);
    }
    await _syncService.initialize();
    await _loadSyncStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSyncStatus() async {
    final statuses = await _syncService.getSyncStatus();
    setState(() {
      _syncStatuses = statuses;
    });
  }

  Future<void> _performSync() async {
    final result = await _syncService.sync();
    
    if (!mounted) return;
    
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Sync complete\n'
            'Uploaded: ${result.itemsUploaded}, Downloaded: ${result.itemsDownloaded}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _loadSyncStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Sync failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _forceUpload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Upload'),
        content: const Text('This will upload all local data, overwriting remote data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _syncService.forceUpload();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? '✓ Upload complete: ${result.itemsUploaded} items'
                  : '✗ Upload failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _forceDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Download'),
        content: const Text('This will download all remote data, overwriting local data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _syncService.forceDownload();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? '✓ Download complete: ${result.itemsDownloaded} items'
                  : '✗ Download failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SyncSettingsDialog(
        config: _syncService.config,
        onSave: (config) async {
          await _syncService.updateConfig(config);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _syncService.config;
    final state = _syncService.state;
    final progress = _syncService.progress;
    final lastSync = _syncService.lastSyncTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sync Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sync Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _buildStateChip(state),
                          ],
                        ),
                        if (state == SyncState.syncing) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 8),
                          Text(
                            'Syncing... ${(progress * 100).toInt()}%',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                        if (state != SyncState.syncing && lastSync != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last sync: ${DateFormat('MMM dd, yyyy HH:mm').format(lastSync)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state == SyncState.syncing ? null : _performSync,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state == SyncState.syncing ? null : _forceUpload,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state == SyncState.syncing ? null : _forceDownload,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sync Items
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sync Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (config.syncConversations)
                          _buildSyncItem('Conversations', Icons.chat, true),
                        if (config.syncSettings)
                          _buildSyncItem('Settings', Icons.settings, true),
                        if (config.syncProfiles)
                          _buildSyncItem('Gateway Profiles', Icons.wifi, true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Conflict Resolution
                if (_syncStatuses.any((s) => s.hasConflict)) ...[
                  Card(
                    color: Colors.orange.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Conflicts Detected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _syncStatuses.where((s) => s.hasConflict).length,
                            itemBuilder: (context, index) {
                              final status = _syncStatuses.where((s) => s.hasConflict).elementAt(index);
                              return ListTile(
                                title: Text(status.key),
                                subtitle: Text(
                                  'Local: ${status.localModified != null ? DateFormat('HH:mm').format(status.localModified!) : 'N/A'}\n'
                                  'Remote: ${status.remoteModified != null ? DateFormat('HH:mm').format(status.remoteModified!) : 'N/A'}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => _syncService.resolveConflict(status.key, keepLocal: true),
                                      child: const Text('Keep Local'),
                                    ),
                                    TextButton(
                                      onPressed: () => _syncService.resolveConflict(status.key, keepLocal: false),
                                      child: const Text('Keep Remote'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Auto Sync Info
                if (config.autoSync)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.autorenew, color: Colors.green),
                      title: const Text('Auto Sync Enabled'),
                      subtitle: Text(
                        'Syncs every ${config.syncInterval.inMinutes} minutes',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Help
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'How Sync Works',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Sync keeps your data consistent across devices\n'
                        '• Upload sends local changes to gateway\n'
                        '• Download receives changes from gateway\n'
                        '• Conflicts occur when both sides changed\n'
                        '• Auto sync runs in the background',
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStateChip(SyncState state) {
    Color color;
    String label;
    IconData icon;

    switch (state) {
      case SyncState.idle:
        color = Colors.grey;
        label = 'Idle';
        icon = Icons.pause_circle;
        break;
      case SyncState.syncing:
        color = Colors.blue;
        label = 'Syncing';
        icon = Icons.sync;
        break;
      case SyncState.success:
        color = Colors.green;
        label = 'Success';
        icon = Icons.check_circle;
        break;
      case SyncState.error:
        color = Colors.red;
        label = 'Error';
        icon = Icons.error;
        break;
      case SyncState.conflict:
        color = Colors.orange;
        label = 'Conflict';
        icon = Icons.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncItem(String name, IconData icon, bool enabled) {
    return ListTile(
      leading: Icon(icon, color: enabled ? Colors.green : Colors.grey),
      title: Text(name),
      trailing: enabled
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
    );
  }
}

class _SyncSettingsDialog extends StatefulWidget {
  final SyncConfig config;
  final Function(SyncConfig) onSave;

  const _SyncSettingsDialog({
    required this.config,
    required this.onSave,
  });

  @override
  State<_SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<_SyncSettingsDialog> {
  late bool _enabled;
  late bool _autoSync;
  late int _syncIntervalMinutes;
  late SyncDirection _direction;
  late bool _syncConversations;
  late bool _syncSettings;
  late bool _syncProfiles;
  late bool _syncOnWifiOnly;
  late bool _syncOnChargeOnly;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _autoSync = widget.config.autoSync;
    _syncIntervalMinutes = widget.config.syncInterval.inMinutes;
    _direction = widget.config.direction;
    _syncConversations = widget.config.syncConversations;
    _syncSettings = widget.config.syncSettings;
    _syncProfiles = widget.config.syncProfiles;
    _syncOnWifiOnly = widget.config.syncOnWifiOnly;
    _syncOnChargeOnly = widget.config.syncOnChargeOnly;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Sync Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Sync Enabled'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            SwitchListTile(
              title: const Text('Auto Sync'),
              subtitle: const Text('Automatically sync data'),
              value: _autoSync,
              onChanged: _enabled ? (value) => setState(() => _autoSync = value) : null,
            ),
            ListTile(
              title: const Text('Sync Interval'),
              subtitle: Text('Every $_syncIntervalMinutes minutes'),
              trailing: DropdownButton<int>(
                value: _syncIntervalMinutes,
                items: [5, 10, 15, 30, 60].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text('$m min'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _syncIntervalMinutes = value);
                },
              ),
            ),
            const Divider(),
            const Text('Sync Direction:', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<SyncDirection>(
              title: const Text('Bidirectional'),
              value: SyncDirection.bidirectional,
              groupValue: _direction,
              onChanged: (value) => setState(() => _direction = value!),
            ),
            RadioListTile<SyncDirection>(
              title: const Text('Upload Only'),
              value: SyncDirection.upload,
              groupValue: _direction,
              onChanged: (value) => setState(() => _direction = value!),
            ),
            RadioListTile<SyncDirection>(
              title: const Text('Download Only'),
              value: SyncDirection.download,
              groupValue: _direction,
              onChanged: (value) => setState(() => _direction = value!),
            ),
            const Divider(),
            const Text('What to Sync:', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Conversations'),
              value: _syncConversations,
              onChanged: _enabled ? (value) => setState(() => _syncConversations = value) : null,
            ),
            SwitchListTile(
              title: const Text('Settings'),
              value: _syncSettings,
              onChanged: _enabled ? (value) => setState(() => _syncSettings = value) : null,
            ),
            SwitchListTile(
              title: const Text('Gateway Profiles'),
              value: _syncProfiles,
              onChanged: _enabled ? (value) => setState(() => _syncProfiles = value) : null,
            ),
            const Divider(),
            const Text('Conditions:', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('WiFi Only'),
              subtitle: const Text('Only sync on WiFi'),
              value: _syncOnWifiOnly,
              onChanged: _enabled ? (value) => setState(() => _syncOnWifiOnly = value) : null,
            ),
            SwitchListTile(
              title: const Text('Charging Only'),
              subtitle: const Text('Only sync while charging'),
              value: _syncOnChargeOnly,
              onChanged: _enabled ? (value) => setState(() => _syncOnChargeOnly = value) : null,
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
            widget.onSave(SyncConfig(
              enabled: _enabled,
              autoSync: _autoSync,
              syncInterval: Duration(minutes: _syncIntervalMinutes),
              direction: _direction,
              syncConversations: _syncConversations,
              syncSettings: _syncSettings,
              syncProfiles: _syncProfiles,
              syncOnWifiOnly: _syncOnWifiOnly,
              syncOnChargeOnly: _syncOnChargeOnly,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}