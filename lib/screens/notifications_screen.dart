import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
    _notificationService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _notificationService.initialize();
    setState(() => _isLoading = false);
  }

  Future<void> _requestPermissions() async {
    final granted = await _notificationService.requestPermissions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted ? '✓ Permissions granted' : '✗ Permissions denied'),
          backgroundColor: granted ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAll();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _NotificationSettingsDialog(
        settings: _notificationService.settings,
        onSave: (settings) async {
          await _notificationService.updateSettings(settings);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notificationService.notifications;
    final unreadCount = _notificationService.unreadCount;
    final settings = _notificationService.settings;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  _markAllAsRead();
                  break;
                case 'clear_all':
                  _clearAll();
                  break;
                case 'request_permissions':
                  _requestPermissions();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Mark All as Read'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear All'),
                ),
              ),
              const PopupMenuItem(
                value: 'request_permissions',
                child: ListTile(
                  leading: Icon(Icons.notifications_active),
                  title: Text('Request Permissions'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(notifications),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          if (!_notificationService.isInitialized)
            ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Enable Notifications'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationCard(
          notification: notification,
          onTap: () => _notificationService.markAsRead(notification.id),
          onDismiss: () => _notificationService.deleteNotification(notification.id),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: notification.isRead ? 0 : 2,
        color: notification.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notification.priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    notification.typeIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notification.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: notification.priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notification.priority.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: notification.priorityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(time);
  }
}

class _NotificationSettingsDialog extends StatefulWidget {
  final NotificationSettings settings;
  final Function(NotificationSettings) onSave;

  const _NotificationSettingsDialog({
    required this.settings,
    required this.onSave,
  });

  @override
  State<_NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<_NotificationSettingsDialog> {
  late bool _enabled;
  late bool _gatewayStatus;
  late bool _newMessages;
  late bool _actionComplete;
  late bool _errors;
  late bool _sync;
  late bool _reminders;
  late bool _sound;
  late bool _vibration;
  late bool _led;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _gatewayStatus = widget.settings.gatewayStatus;
    _newMessages = widget.settings.newMessages;
    _actionComplete = widget.settings.actionComplete;
    _errors = widget.settings.errors;
    _sync = widget.settings.sync;
    _reminders = widget.settings.reminders;
    _sound = widget.settings.sound;
    _vibration = widget.settings.vibration;
    _led = widget.settings.led;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Notification Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Notifications Enabled'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const Divider(),
            const Text('Notification Types:', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Gateway Status'),
              subtitle: const Text('Connection changes'),
              value: _gatewayStatus,
              onChanged: _enabled ? (value) => setState(() => _gatewayStatus = value) : null,
            ),
            SwitchListTile(
              title: const Text('New Messages'),
              subtitle: const Text('Chat notifications'),
              value: _newMessages,
              onChanged: _enabled ? (value) => setState(() => _newMessages = value) : null,
            ),
            SwitchListTile(
              title: const Text('Action Complete'),
              subtitle: const Text('Task finished notifications'),
              value: _actionComplete,
              onChanged: _enabled ? (value) => setState(() => _actionComplete = value) : null,
            ),
            SwitchListTile(
              title: const Text('Errors'),
              subtitle: const Text('Error alerts'),
              value: _errors,
              onChanged: _enabled ? (value) => setState(() => _errors = value) : null,
            ),
            SwitchListTile(
              title: const Text('Sync'),
              subtitle: const Text('Sync status updates'),
              value: _sync,
              onChanged: _enabled ? (value) => setState(() => _sync = value) : null,
            ),
            SwitchListTile(
              title: const Text('Reminders'),
              subtitle: const Text('Scheduled reminders'),
              value: _reminders,
              onChanged: _enabled ? (value) => setState(() => _reminders = value) : null,
            ),
            const Divider(),
            const Text('Alert Options:', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Sound'),
              value: _sound,
              onChanged: _enabled ? (value) => setState(() => _sound = value) : null,
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              value: _vibration,
              onChanged: _enabled ? (value) => setState(() => _vibration = value) : null,
            ),
            SwitchListTile(
              title: const Text('LED Light'),
              value: _led,
              onChanged: _enabled ? (value) => setState(() => _led = value) : null,
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
            widget.onSave(NotificationSettings(
              enabled: _enabled,
              gatewayStatus: _gatewayStatus,
              newMessages: _newMessages,
              actionComplete: _actionComplete,
              errors: _errors,
              sync: _sync,
              reminders: _reminders,
              sound: _sound,
              vibration: _vibration,
              led: _led,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}