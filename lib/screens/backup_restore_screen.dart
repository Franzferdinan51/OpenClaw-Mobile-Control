import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';
import '../services/openclaw_backup_service.dart';
import 'local_installer_screen.dart';
import 'termux_screen.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();
  final OpenClawBackupService _openClawBackupService = OpenClawBackupService();
  bool _isLoading = true;
  List<BackupMetadata> _backups = [];
  List<OpenClawBackupRecord> _openClawBackups = [];
  BackupMetadata? _lastBackup;
  OpenClawBackupAvailability? _openClawAvailability;
  bool _autoBackupEnabled = false;
  String _backupSize = '0 MB';

  @override
  void initState() {
    super.initState();
    _loadData();
    _backupService.addListener(_onBackupServiceChanged);
    _openClawBackupService.addListener(_onBackupServiceChanged);
  }

  @override
  void dispose() {
    _backupService.removeListener(_onBackupServiceChanged);
    _openClawBackupService.removeListener(_onBackupServiceChanged);
    super.dispose();
  }

  void _onBackupServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _backupService.initialize();
    await _openClawBackupService.initialize();
    final backups = await _backupService.getBackupFiles();
    final lastBackup = await _backupService.getLastBackup();
    final autoBackup = await _backupService.isAutoBackupEnabled();
    final size = await _backupService.getFormattedBackupSize();
    final openClawBackups = await _openClawBackupService.getBackups();
    final openClawAvailability =
        await _openClawBackupService.getAvailability(forceRefresh: true);

    if (mounted) {
      setState(() {
        _backups = backups;
        _openClawBackups = openClawBackups;
        _lastBackup = lastBackup;
        _openClawAvailability = openClawAvailability;
        _autoBackupEnabled = autoBackup;
        _isLoading = false;
        _backupSize = size;
      });
    }
  }

  Future<void> _createOpenClawBackup(OpenClawBackupScope scope) async {
    final result = await _openClawBackupService.createBackup(scope: scope);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? (result.pending ? Colors.orange : Colors.green)
            : Colors.red,
      ),
    );
    await _loadData();
  }

  Future<void> _verifyOpenClawBackup(OpenClawBackupRecord backup) async {
    final result =
        await _openClawBackupService.verifyBackup(backup.archivePath);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? (result.pending ? Colors.orange : Colors.green)
            : Colors.red,
      ),
    );
    await _loadData();
  }

  Future<void> _deleteOpenClawBackup(OpenClawBackupRecord backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Native Backup'),
          ],
        ),
        content: Text(
          'Delete ${backup.filename} from Termux backup storage?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _openClawBackupService.deleteBackup(backup);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Native OpenClaw backup deleted'
            : _openClawBackupService.lastError ?? 'Delete failed'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
    await _loadData();
  }

  Future<void> _copyOpenClawPath(OpenClawBackupRecord backup) async {
    await Clipboard.setData(ClipboardData(text: backup.archivePath));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup path copied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showOpenClawRestoreGuide([OpenClawBackupRecord? backup]) {
    final guide = _openClawBackupService.buildRestoreGuide(
      archivePath: backup?.archivePath,
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_page, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restore Guide'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(guide),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: guide));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restore guide copied')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermuxScreen()),
              );
            },
            child: const Text('Open Termux Bridge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.green),
            SizedBox(width: 8),
            Text('Create Backup'),
          ],
        ),
        content: const Text(
          'This will create a backup of your current app settings, '
          'connection profiles, and preferences. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.backup),
            label: const Text('Create Backup'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Creating backup...'),
          ],
        ),
      ),
    );

    final success = await _backupService.backup();

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Backup created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Backup failed: ${_backupService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.blue),
            SizedBox(width: 8),
            Text('Restore Backup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will restore your app to the state from:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backup.formattedDate,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Size: ${backup.formattedSize}'),
                  Text('Version: ${backup.version}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Your current settings will be replaced. Continue?',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Restoring backup...'),
          ],
        ),
      ),
    );

    final success = await _backupService.restore(backup.filename);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✓ Backup restored successfully! Restart app for changes to take effect.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Restore failed: ${_backupService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Backup'),
          ],
        ),
        content: Text('Delete backup from ${backup.formattedDate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _backupService.deleteBackup(backup.filename);
      await _loadData();
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await _backupService.setAutoBackupEnabled(value);
    setState(() {
      _autoBackupEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? '✓ Auto-backup enabled' : 'Auto-backup disabled',
          ),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildNativeBackupCard(),
                const SizedBox(height: 16),
                _buildNativeBackupHistoryCard(),
                const SizedBox(height: 24),

                // Status Card
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
                              'DuckBot App Backup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: _autoBackupEnabled,
                              onChanged: _toggleAutoBackup,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'App-only backup: ${_autoBackupEnabled ? 'Auto-enabled' : 'Manual only'}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This covers DuckBot settings and connection preferences, not the full OpenClaw host state.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_lastBackup != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last app backup: ${_lastBackup!.timeAgo}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Total backup size: $_backupSize',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Create Backup Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _backupService.isBackingUp ? null : _createBackup,
                    icon: _backupService.isBackingUp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.backup),
                    label: Text(_backupService.isBackingUp
                        ? 'Creating...'
                        : 'Create App Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Backup List
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'App Backup History (${_backups.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_backups.isNotEmpty)
                              TextButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete All Backups'),
                                      content: const Text(
                                          'Are you sure you want to delete all backups?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          child: const Text('Delete All'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    for (final backup in _backups) {
                                      await _backupService
                                          .deleteBackup(backup.filename);
                                    }
                                    await _loadData();
                                  }
                                },
                                icon: const Icon(Icons.delete_sweep,
                                    color: Colors.red),
                                label: const Text('Clear All',
                                    style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_backups.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No app backups yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Create a DuckBot app backup above',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final backup = _backups[index];

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.folder_zip,
                                      color: Colors.blue),
                                ),
                                title: Text(backup.formattedDate),
                                subtitle: Text(
                                  'Size: ${backup.formattedSize} • v${backup.version}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'restore') {
                                      _restoreBackup(backup);
                                    } else if (value == 'delete') {
                                      _deleteBackup(backup);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'restore',
                                      child: ListTile(
                                        leading: Icon(Icons.restore,
                                            color: Colors.blue),
                                        title: Text('Restore'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            color: Colors.red),
                                        title: Text('Delete'),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _showBackupDetails(backup),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'App Backup Contents',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Native OpenClaw host archives appear in the cards above.\n\n'
                        '• App settings and preferences\n'
                        '• Gateway connection profiles\n'
                        '• Saved configurations\n'
                        '• User preferences\n\n'
                        'These app backups are stored in DuckBot local storage.',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showBackupDetails(BackupMetadata backup) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_zip, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        backup.formattedDate,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('File', backup.filename),
            _buildDetailRow('Size', backup.formattedSize),
            _buildDetailRow('Version', backup.version),
            _buildDetailRow('Created', backup.formattedDate),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteBackup(backup);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _restoreBackup(backup);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNativeBackupCard() {
    final availability = _openClawAvailability;
    final isAvailable = availability?.isAvailable == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'OpenClaw Native Backup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              availability?.summary ??
                  'Checking whether native OpenClaw backup is available...',
              style: TextStyle(
                color: isAvailable ? Colors.green[700] : Colors.grey[700],
              ),
            ),
            if (availability?.openClawVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                'CLI: ${availability!.openClawVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isAvailable && !_openClawBackupService.isBusy
                      ? () => _createOpenClawBackup(OpenClawBackupScope.full)
                      : null,
                  icon: const Icon(Icons.backup),
                  label: Text(_openClawBackupService.isBusy
                      ? 'Working...'
                      : 'Create Full Backup'),
                ),
                OutlinedButton.icon(
                  onPressed: isAvailable && !_openClawBackupService.isBusy
                      ? () =>
                          _createOpenClawBackup(OpenClawBackupScope.configOnly)
                      : null,
                  icon: const Icon(Icons.settings_suggest),
                  label: const Text('Config Only'),
                ),
                OutlinedButton.icon(
                  onPressed: isAvailable && !_openClawBackupService.isBusy
                      ? () =>
                          _createOpenClawBackup(OpenClawBackupScope.noWorkspace)
                      : null,
                  icon: const Icon(Icons.folder_off),
                  label: const Text('No Workspace'),
                ),
                TextButton.icon(
                  onPressed: _showOpenClawRestoreGuide,
                  icon: const Icon(Icons.restore_page),
                  label: const Text('Restore Guide'),
                ),
              ],
            ),
            if (!isAvailable) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocalInstallerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.construction),
                    label: const Text('Local Setup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermuxScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.terminal),
                    label: const Text('Termux Bridge'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNativeBackupHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native Backup History (${_openClawBackups.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_openClawBackups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.archive_outlined, size: 44, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No native OpenClaw backups recorded yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _openClawBackups.length,
                itemBuilder: (context, index) {
                  final backup = _openClawBackups[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        backup.status == OpenClawBackupStatus.failed
                            ? Icons.error_outline
                            : Icons.cloud_done,
                        color: backup.status == OpenClawBackupStatus.failed
                            ? Colors.red
                            : Colors.deepPurple,
                      ),
                    ),
                    title: Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(backup.createdAt),
                    ),
                    subtitle: Text(
                      '${backup.scopeLabel} • ${backup.statusLabel}\n${backup.filename}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'verify':
                            _verifyOpenClawBackup(backup);
                            break;
                          case 'copy_path':
                            _copyOpenClawPath(backup);
                            break;
                          case 'restore':
                            _showOpenClawRestoreGuide(backup);
                            break;
                          case 'delete':
                            _deleteOpenClawBackup(backup);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'verify',
                          child: ListTile(
                            leading: Icon(Icons.verified_outlined,
                                color: Colors.green),
                            title: Text('Verify'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'copy_path',
                          child: ListTile(
                            leading: Icon(Icons.copy_all_outlined),
                            title: Text('Copy Path'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'restore',
                          child: ListTile(
                            leading:
                                Icon(Icons.restore_page, color: Colors.orange),
                            title: Text('Restore Guide'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showOpenClawBackupDetails(backup),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOpenClawBackupDetails(OpenClawBackupRecord backup) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native OpenClaw Backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Created',
                DateFormat('yyyy-MM-dd HH:mm').format(backup.createdAt)),
            _buildDetailRow('Scope', backup.scopeLabel),
            _buildDetailRow('Status', backup.statusLabel),
            _buildDetailRow('Path', backup.archivePath),
            if (backup.lastVerifiedAt != null)
              _buildDetailRow(
                'Last verified',
                DateFormat('yyyy-MM-dd HH:mm').format(backup.lastVerifiedAt!),
              ),
            if (backup.message != null && backup.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                backup.message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _verifyOpenClawBackup(backup);
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _copyOpenClawPath(backup);
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy Path'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showOpenClawRestoreGuide(backup);
                  },
                  icon: const Icon(Icons.restore_page),
                  label: const Text('Restore Guide'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
