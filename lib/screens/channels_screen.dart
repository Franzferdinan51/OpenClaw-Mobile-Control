import 'package:flutter/material.dart';
import '../services/gateway_service.dart';

/// Multi-Channel Support Screen
/// Displays status for WhatsApp, Telegram, Slack, Discord, etc.
/// Allows per-channel notifications toggle and channel switching
class ChannelsScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const ChannelsScreen({super.key, this.gatewayService});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<ChannelInfo> _channels = [];
  bool _isLoading = true;
  String? _error;
  String? _activeChannel;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In production, this would fetch from gateway API
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _channels = [
          ChannelInfo(
            id: 'telegram',
            name: 'Telegram',
            type: ChannelType.messaging,
            status: ChannelStatus.connected,
            icon: '📱',
            notificationsEnabled: true,
            unreadCount: 3,
            lastMessage: 'New message from Duckets',
            lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          ChannelInfo(
            id: 'discord',
            name: 'Discord',
            type: ChannelType.messaging,
            status: ChannelStatus.connected,
            icon: '🎮',
            notificationsEnabled: true,
            unreadCount: 12,
            lastMessage: 'AI Council discussion',
            lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          ChannelInfo(
            id: 'whatsapp',
            name: 'WhatsApp',
            type: ChannelType.messaging,
            status: ChannelStatus.disconnected,
            icon: '💬',
            notificationsEnabled: false,
            unreadCount: 0,
          ),
          ChannelInfo(
            id: 'slack',
            name: 'Slack',
            type: ChannelType.messaging,
            status: ChannelStatus.configured,
            icon: '💼',
            notificationsEnabled: false,
            unreadCount: 0,
          ),
          ChannelInfo(
            id: 'x_twitter',
            name: 'X (Twitter)',
            type: ChannelType.social,
            status: ChannelStatus.connected,
            icon: '🐦',
            notificationsEnabled: true,
            unreadCount: 45,
            lastMessage: 'New mentions and DMs',
            lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          ChannelInfo(
            id: 'gmail',
            name: 'Gmail',
            type: ChannelType.email,
            status: ChannelStatus.connected,
            icon: '📧',
            notificationsEnabled: true,
            unreadCount: 8,
            lastMessage: '3 new emails',
            lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          ChannelInfo(
            id: 'agentmail',
            name: 'AgentMail',
            type: ChannelType.email,
            status: ChannelStatus.connected,
            icon: '🤖',
            notificationsEnabled: true,
            unreadCount: 0,
            lastMessage: 'duckbot@agentmail.to ready',
            lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        _activeChannel = 'telegram';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleNotifications(String channelId, bool enabled) {
    setState(() {
      final index = _channels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _channels[index] = _channels[index].copyWith(
          notificationsEnabled: enabled,
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$channelId notifications ${enabled ? 'enabled' : 'disabled'}'),
        backgroundColor: enabled ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setActiveChannel(String channelId) {
    setState(() {
      _activeChannel = channelId;
    });
    
    final channel = _channels.firstWhere((c) => c.id == channelId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${channel.name}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showChannelDetails(ChannelInfo channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ChannelDetailSheet(
        channel: channel,
        onToggleNotifications: (enabled) {
          _toggleNotifications(channel.id, enabled);
          Navigator.pop(context);
        },
        onSetActive: () {
          _setActiveChannel(channel.id);
          Navigator.pop(context);
        },
        isActive: _activeChannel == channel.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChannels,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChannels,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Active Channel Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Active: ${_channels.firstWhere((c) => c.id == _activeChannel, orElse: () => _channels.first).name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    // Channel List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _channels.length,
                        itemBuilder: (context, index) {
                          final channel = _channels[index];
                          return _ChannelCard(
                            channel: channel,
                            isActive: _activeChannel == channel.id,
                            onTap: () => _showChannelDetails(channel),
                            onToggleNotifications: (enabled) => _toggleNotifications(channel.id, enabled),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChannelDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Channel'),
      ),
    );
  }

  void _showAddChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Channel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('📱', style: TextStyle(fontSize: 24)),
                title: const Text('Telegram'),
                subtitle: const Text('Configure Telegram bot'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('telegram');
                },
              ),
              ListTile(
                leading: const Text('🎮', style: TextStyle(fontSize: 24)),
                title: const Text('Discord'),
                subtitle: const Text('Configure Discord bot'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('discord');
                },
              ),
              ListTile(
                leading: const Text('💬', style: TextStyle(fontSize: 24)),
                title: const Text('WhatsApp'),
                subtitle: const Text('Configure WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('whatsapp');
                },
              ),
              ListTile(
                leading: const Text('💼', style: TextStyle(fontSize: 24)),
                title: const Text('Slack'),
                subtitle: const Text('Configure Slack workspace'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('slack');
                },
              ),
              ListTile(
                leading: const Text('🐦', style: TextStyle(fontSize: 24)),
                title: const Text('X (Twitter)'),
                subtitle: const Text('Configure X API'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('x_twitter');
                },
              ),
              ListTile(
                leading: const Text('📧', style: TextStyle(fontSize: 24)),
                title: const Text('Gmail'),
                subtitle: const Text('Configure Gmail'),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelConfig('gmail');
                },
              ),
            ],
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

  void _showChannelConfig(String channelId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configure $channelId - coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final ChannelInfo channel;
  final bool isActive;
  final VoidCallback onTap;
  final Function(bool) onToggleNotifications;

  const _ChannelCard({
    required this.channel,
    required this.isActive,
    required this.onTap,
    required this.onToggleNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 1,
      color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(channel.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    channel.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          channel.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(channel.status),
                          size: 14,
                          color: _getStatusColor(channel.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          channel.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStatusColor(channel.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (channel.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${channel.unreadCount}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (channel.lastMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.lastMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: channel.notificationsEnabled,
                onChanged: onToggleNotifications,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ChannelStatus status) {
    switch (status) {
      case ChannelStatus.connected:
        return Colors.green;
      case ChannelStatus.connecting:
        return Colors.orange;
      case ChannelStatus.disconnected:
        return Colors.red;
      case ChannelStatus.error:
        return Colors.red.shade700;
      case ChannelStatus.configured:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(ChannelStatus status) {
    switch (status) {
      case ChannelStatus.connected:
        return Icons.check_circle;
      case ChannelStatus.connecting:
        return Icons.sync;
      case ChannelStatus.disconnected:
        return Icons.cancel_outlined;
      case ChannelStatus.error:
        return Icons.error;
      case ChannelStatus.configured:
        return Icons.settings;
    }
  }
}

class _ChannelDetailSheet extends StatelessWidget {
  final ChannelInfo channel;
  final Function(bool) onToggleNotifications;
  final VoidCallback onSetActive;
  final bool isActive;

  const _ChannelDetailSheet({
    required this.channel,
    required this.onToggleNotifications,
    required this.onSetActive,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(channel.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      channel.type.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildInfoRow(
            context,
            'Status',
            channel.status.name.toUpperCase(),
            _getStatusColor(channel.status),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications'),
              Switch(
                value: channel.notificationsEnabled,
                onChanged: onToggleNotifications,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (channel.unreadCount > 0)
            _buildInfoRow(
              context,
              'Unread',
              '${channel.unreadCount}',
              Colors.red,
            ),
          const SizedBox(height: 24),
          
          if (!isActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSetActive,
                icon: const Icon(Icons.check),
                label: const Text('Set as Active Channel'),
              ),
            ),
          if (isActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle),
                label: const Text('Currently Active'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ChannelStatus status) {
    switch (status) {
      case ChannelStatus.connected:
        return Colors.green;
      case ChannelStatus.connecting:
        return Colors.orange;
      case ChannelStatus.disconnected:
        return Colors.red;
      case ChannelStatus.error:
        return Colors.red.shade700;
      case ChannelStatus.configured:
        return Colors.blue;
    }
  }
}

enum ChannelType { messaging, social, email }
enum ChannelStatus { connected, connecting, disconnected, error, configured }

class ChannelInfo {
  final String id;
  final String name;
  final ChannelType type;
  final ChannelStatus status;
  final String icon;
  final bool notificationsEnabled;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  ChannelInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.icon,
    required this.notificationsEnabled,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageTime,
  });

  ChannelInfo copyWith({
    String? id,
    String? name,
    ChannelType? type,
    ChannelStatus? status,
    String? icon,
    bool? notificationsEnabled,
    int? unreadCount,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return ChannelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }
}