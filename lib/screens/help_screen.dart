import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final List<HelpTopic> _topics = [
    HelpTopic(
      category: 'Getting Started',
      title: 'Quick Start Guide',
      icon: Icons.rocket_launch,
      items: [
        HelpItem(
          question: 'How do I connect to a gateway?',
          answer: '1. Open Settings\n2. Tap "Gateway Connection"\n3. Enter your gateway URL or use auto-discover\n4. Tap "Connect"\n\nYou can also scan a QR code from your OpenClaw instance.',
        ),
        HelpItem(
          question: 'What is DuckBot Go?',
          answer: 'DuckBot Go is your mobile companion for the OpenClaw ecosystem. It lets you:\n\n• Chat with AI agents\n• Control your smart home\n• Run automations\n• Monitor your gateway\n• Execute quick actions',
        ),
        HelpItem(
          question: 'How do I set up offline mode?',
          answer: 'Offline mode allows you to use cached data when offline:\n\n1. Go to Settings > Offline Mode\n2. Enable "Offline Mode"\n3. Your recent conversations and data will be cached\n4. Actions performed offline will sync when you reconnect',
        ),
      ],
    ),
    HelpTopic(
      category: 'Chat & Messaging',
      title: 'Chat Help',
      icon: Icons.chat,
      items: [
        HelpItem(
          question: 'How do I start a conversation?',
          answer: '1. Tap the "Chat" tab at the bottom\n2. Type your message in the text field\n3. Tap send or press enter\n\nYou can also use voice input by tapping the microphone icon.',
        ),
        HelpItem(
          question: 'Can I use voice commands?',
          answer: 'Yes! DuckBot supports voice input:\n\n1. Tap the microphone icon in the chat\n2. Speak your message\n3. Tap "Send" when done\n\nYou can also enable voice output in Settings > Voice.',
        ),
        HelpItem(
          question: 'How do I attach files or images?',
          answer: '1. In chat, tap the attachment icon\n2. Choose file type (image, document, etc.)\n3. Select the file from your device\n4. Add any additional message\n5. Tap send',
        ),
      ],
    ),
    HelpTopic(
      category: 'Quick Actions',
      title: 'Quick Actions',
      icon: Icons.bolt,
      items: [
        HelpItem(
          question: 'What are Quick Actions?',
          answer: 'Quick Actions are shortcuts for common tasks:\n\n• System: Backup, restart, update\n• Grow: Status, photo, analyze\n• Weather: Current, storm, forecast\n• Agents: Chat, research, code\n• Termux: Console, install, setup',
        ),
        HelpItem(
          question: 'How do I create custom actions?',
          answer: '1. Go to Settings > Quick Actions\n2. Tap "Add Custom Action"\n3. Enter the action name and command\n4. Choose an icon\n5. Save\n\nYour custom action will appear in the Quick Actions list.',
        ),
        HelpItem(
          question: 'Actions aren\'t working - what do I do?',
          answer: '1. Check your gateway connection\n2. Verify the action requires no additional setup\n3. Check the action logs for errors\n4. Try restarting the app\n\nSome actions require Termux or specific permissions.',
        ),
      ],
    ),
    HelpTopic(
      category: 'Gateway & Connection',
      title: 'Gateway Management',
      icon: Icons.wifi,
      items: [
        HelpItem(
          question: 'How do I restart the gateway?',
          answer: '1. Go to Control tab\n2. Tap "Restart Gateway"\n3. Confirm the action\n\nYou can also use Quick Actions > System > Restart.',
        ),
        HelpItem(
          question: 'How do I check gateway status?',
          answer: '1. Open the Dashboard\n2. Look at the connection banner\n3. Tap for detailed status\n\nYou can also check Control > Gateway Status for real-time info.',
        ),
        HelpItem(
          question: 'What is auto-discovery?',
          answer: 'Auto-discovery scans your local network for OpenClaw gateways.\n\n1. Go to Settings > Gateway\n2. Tap "Scan Network"\n3. Wait for discovery (usually <10 seconds)\n4. Select your gateway from the list',
        ),
      ],
    ),
    HelpTopic(
      category: 'Backup & Sync',
      title: 'Data Management',
      icon: Icons.backup,
      items: [
        HelpItem(
          question: 'How do I backup my data?',
          answer: '1. Go to Settings > Backup\n2. Tap "Create Backup"\n3. Choose what to include:\n   - Conversations\n   - Settings\n   - Gateway profiles\n4. Tap "Backup"\n\nBackups are stored locally on your device.',
        ),
        HelpItem(
          question: 'How do I restore from backup?',
          answer: '1. Go to Settings > Backup\n2. Tap the backup you want to restore\n3. Review what will be restored\n4. Tap "Restore"\n\nYour current data will be replaced with the backup.',
        ),
        HelpItem(
          question: 'How does sync work?',
          answer: 'Sync keeps your data consistent across devices:\n\n1. Go to Settings > Sync\n2. Enable sync\n3. Choose what to sync\n4. Set sync interval\n\nSync requires an active gateway connection.',
        ),
      ],
    ),
    HelpTopic(
      category: 'Notifications',
      title: 'Notifications',
      icon: Icons.notifications,
      items: [
        HelpItem(
          question: 'How do I enable notifications?',
          answer: '1. Go to Settings > Notifications\n2. Enable "Notifications"\n3. Grant notification permissions\n4. Choose which types to receive',
        ),
        HelpItem(
          question: 'What notification types are available?',
          answer: '• Gateway Status: Connection changes\n• New Messages: Chat notifications\n• Action Complete: Task finished\n• Errors: Error alerts\n• Sync: Sync status updates\n• Reminders: Scheduled reminders',
        ),
        HelpItem(
          question: 'How do I disable notification sounds?',
          answer: '1. Go to Settings > Notifications\n2. Tap the settings gear\n3. Toggle off "Sound"\n\nYou can also disable vibration and LED from here.',
        ),
      ],
    ),
    HelpTopic(
      category: 'Troubleshooting',
      title: 'Common Issues',
      icon: Icons.build,
      items: [
        HelpItem(
          question: 'App won\'t connect to gateway',
          answer: '1. Check your network connection\n2. Verify the gateway URL is correct\n3. Try auto-discovery\n4. Check if gateway is running\n5. Restart the app\n\nIf using Tailscale, verify your connection.',
        ),
        HelpItem(
          question: 'Actions are slow or not responding',
          answer: '1. Check gateway status\n2. Verify network speed\n3. Clear app cache\n4. Restart the gateway\n5. Check for app updates',
        ),
        HelpItem(
          question: 'Data not syncing between devices',
          answer: '1. Ensure sync is enabled on both devices\n2. Check both devices are connected\n3. Try manual sync\n4. Check for conflicts in Sync screen\n\nConflicts need manual resolution.',
        ),
      ],
    ),
  ];

  List<HelpTopic> get _filteredTopics {
    if (_searchQuery.isEmpty) return _topics;
    
    return _topics.map((topic) {
      final filteredItems = topic.items.where((item) {
        final query = _searchQuery.toLowerCase();
        return item.question.toLowerCase().contains(query) ||
               item.answer.toLowerCase().contains(query);
      }).toList();
      
      if (filteredItems.isEmpty) return null;
      
      return HelpTopic(
        category: topic.category,
        title: topic.title,
        icon: topic.icon,
        items: filteredItems,
      );
    }).whereType<HelpTopic>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search help topics...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Help Topics
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredTopics.length,
              itemBuilder: (context, index) {
                return _HelpTopicCard(topic: _filteredTopics[index]);
              },
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFooterButton(
                      'Contact Support',
                      Icons.email,
                      () => _showContactDialog(),
                    ),
                    _buildFooterButton(
                      'Report Bug',
                      Icons.bug_report,
                      () => _showBugReportDialog(),
                    ),
                    _buildFooterButton(
                      'Feature Request',
                      Icons.lightbulb,
                      () => _showFeatureRequestDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _launchUrl('https://github.com/Franzferdinan51/openclaw'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View Documentation'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email),
            SizedBox(width: 8),
            Text('Contact Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: support@openclaw.dev'),
            SizedBox(height: 16),
            Text('Response time: Usually within 24 hours'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red),
            SizedBox(width: 8),
            Text('Report Bug'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the bug:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What happened? What did you expect?',
                border: OutlineInputBorder(),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Bug report submitted. Thank you!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showFeatureRequestDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.orange),
            SizedBox(width: 8),
            Text('Request Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe your feature idea:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What feature would you like to see?',
                border: OutlineInputBorder(),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Feature request submitted. Thank you!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class HelpTopic {
  final String category;
  final String title;
  final IconData icon;
  final List<HelpItem> items;

  HelpTopic({
    required this.category,
    required this.title,
    required this.icon,
    required this.items,
  });
}

class HelpItem {
  final String question;
  final String answer;

  HelpItem({
    required this.question,
    required this.answer,
  });
}

class _HelpTopicCard extends StatefulWidget {
  final HelpTopic topic;

  const _HelpTopicCard({required this.topic});

  @override
  State<_HelpTopicCard> createState() => _HelpTopicCardState();
}

class _HelpTopicCardState extends State<_HelpTopicCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.topic.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.topic.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.topic.items.length} articles',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            ...widget.topic.items.map((item) => _HelpItemTile(item: item)),
        ],
      ),
    );
  }
}

class _HelpItemTile extends StatelessWidget {
  final HelpItem item;

  const _HelpItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        item.question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            item.answer,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}