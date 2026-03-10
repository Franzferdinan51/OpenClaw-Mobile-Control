import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  List<BackupMetadata> _backups = [];
  BackupMetadata? _lastBackup;
  bool _autoBackupEnabled = false;
  bool _isLoading = true;
  String _backupSize = '0 MB';

  @override
  void initState() {
    super.initState();
    _loadData();
    _backupService.addListener(_onBackupServiceChanged);
  }

  @override
  void dispose() {
    _backupService.removeListener(_onBackupServiceChanged);
    super.dispose();
  }

  void _onBackupServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _backupService.initialize();
    final backups = await _backupService.getBackupFiles();
    final lastBackup = await _backupService.getLastBackup();
    final autoBackup = await _backupService.isAutoBackupEnabled();
    final size = await _backupService.getFormattedBackupSize();

    if (mounted) {
      setState(() {
        _backups = backups;
        _lastBackup = lastBackup;
        _autoBackupEnabled = autoBackup;
        _isLoading = false;
        _backupSize = size;
      });
    }
  }

  Future<void> _createBackup() async {
    // Show confirmation dialog
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
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
      Navigator.pop(context); // Close loading dialog

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
    // Show confirmation dialog
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
            Text(
              'This will restore your app to the state from:',
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
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
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Backup restored successfully! Restart app to apply all changes.'),
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
        content: Text(
          'Delete backup from ${backup.formattedDate}?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _backupService.deleteBackup(backup.filename);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await _backupService.setAutoBackupEnabled(value);
    setState(() => _autoBackupEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Backup & Restore'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Last Backup Status Card
                    _buildLastBackupCard(),
                    const SizedBox(height: 16),

                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 16),

                    // Auto-Backup Toggle
                    Card(
                      child: SwitchListTile(
                        title: const Text('Auto-backup Daily'),
                        subtitle: const Text('Automatically create backup at 2 AM'),
                        value: _autoBackupEnabled,
                        onChanged: _toggleAutoBackup,
                        secondary: const Icon(Icons.schedule),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Available Backups Header
                    Row(
                      children: [
                        const Icon(Icons.history, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Available Backups',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$_backupSize total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Backup List
                    if (_backups.isEmpty)
                      _buildEmptyState()
                    else
                      ...(_backups.map((backup) => _buildBackupItem(backup))),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLastBackupCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _lastBackup != null ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastBackup != null ? Icons.check_circle : Icons.warning,
                  color: _lastBackup != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last Backup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lastBackup != null) ...[
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _lastBackup!.timeAgo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Size: ${_lastBackup!.formattedSize}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Version: ${_lastBackup!.version}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No backups found. Create your first backup to protect your settings.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isWorking = _backupService.isBackingUp || _backupService.isRestoring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Create Backup Button
        ElevatedButton.icon(
          onPressed: isWorking ? null : _createBackup,
          icon: _backupService.isBackingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.backup),
          label: Text(
            _backupService.isBackingUp ? 'Creating Backup...' : 'Create Backup',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Restore Button (disabled if no backups)
        if (_backups.isNotEmpty)
          ElevatedButton.icon(
            onPressed: isWorking ? null : () => _restoreBackup(_backups.first),
            icon: _backupService.isRestoring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.restore),
            label: Text(
              _backupService.isRestoring ? 'Restoring...' : 'Restore Latest Backup',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No backups yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first backup to protect your settings and data.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupItem(BackupMetadata backup) {
    final isLatest = _backups.isNotEmpty && _backups.first.filename == backup.filename;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isLatest
            ? BorderSide(color: Colors.green.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLatest ? Colors.green : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.archive,
            color: isLatest ? Colors.white : null,
          ),
        ),
        title: Row(
          children: [
            Text(backup.formattedDate),
            if (isLatest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LATEST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('${backup.formattedSize} • v${backup.version}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Restore button
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.blue),
              onPressed: () => _restoreBackup(backup),
              tooltip: 'Restore this backup',
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteBackup(backup),
              tooltip: 'Delete backup',
            ),
          ],
        ),
        onTap: () => _showBackupDetails(backup),
      ),
    );
  }

  void _showBackupDetails(BackupMetadata backup) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Text(
                    'Backup Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Filename', backup.filename),
              _buildDetailRow('Created', backup.formattedDate),
              _buildDetailRow('Time Ago', backup.timeAgo),
              _buildDetailRow('Size', backup.formattedSize),
              _buildDetailRow('Version', backup.version),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _restoreBackup(backup);
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteBackup(backup);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}