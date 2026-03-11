import 'package:flutter/material.dart';
import '../widgets/info_card.dart';
import '../widgets/status_card.dart';
import '../widgets/data_card.dart';
import '../widgets/action_card.dart';
import '../widgets/code_card.dart';
import '../widgets/file_card.dart';
import '../widgets/link_card.dart';
import '../widgets/image_card.dart';

/// Demo screen showcasing all info card types
/// 
/// Use this screen to:
/// - Test all card types
/// - Verify animations
/// - Test interactions
/// - Reference implementation patterns
class InfoCardsDemoScreen extends StatefulWidget {
  const InfoCardsDemoScreen({super.key});

  @override
  State<InfoCardsDemoScreen> createState() => _InfoCardsDemoScreenState();
}

class _InfoCardsDemoScreenState extends State<InfoCardsDemoScreen> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[950],
      appBar: AppBar(
        title: const Text('Info Cards Demo'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Section: Status Cards
          _buildSection('Status Cards', [
            GatewayStatusCard(
              isOnline: true,
              version: '3.0.6',
              activeAgents: 5,
              totalSessions: 12,
              uptime: const Duration(hours: 24, minutes: 30),
              onTap: () => _showSnackBar('Gateway tapped'),
              onViewLogs: () => _showSnackBar('View logs'),
              onRestart: () => _showSnackBar('Restart'),
            ),
            const SizedBox(height: 8),
            NodeStatusCard(
              nodeName: 'Agent Smith',
              isOnline: true,
              nodeType: 'Linux',
              ipAddress: '192.168.1.100',
              activeSessions: 3,
              onTap: () => _showSnackBar('Node tapped'),
              onDisconnect: () => _showSnackBar('Disconnect'),
            ),
          ]),
          
          // Section: Data Cards
          _buildSection('Data Cards', [
            TokenUsageCard(
              inputTokens: 15420,
              outputTokens: 8230,
              totalTokens: 23650,
              maxTokens: 128000,
              modelName: 'bailian/MiniMax-M2.5',
              onTap: () => _showSnackBar('Token usage tapped'),
              onViewDetails: () => _showSnackBar('View details'),
            ),
            const SizedBox(height: 8),
            DataCard(
              title: 'Performance Metrics',
              items: [
                DataItem(label: 'CPU', value: 45, color: Colors.blue, icon: Icons.memory, unit: '%'),
                DataItem(label: 'Memory', value: 68, color: Colors.purple, icon: Icons.storage, unit: '%'),
                DataItem(label: 'Disk', value: 32, color: Colors.green, icon: Icons.sd_storage, unit: '%'),
              ],
              visualizationType: DataVisualizationType.progress,
            ),
            const SizedBox(height: 8),
            DataCard(
              title: 'Session Activity',
              items: const [
                DataItem(label: 'Day', value: 45),
                DataItem(label: 'Week', value: 120),
                DataItem(label: 'Month', value: 380),
                DataItem(label: 'Year', value: 1200),
              ],
              visualizationType: DataVisualizationType.sparkline,
            ),
          ]),
          
          // Section: Action Cards
          _buildSection('Action Cards', [
            ActionCard(
              title: 'Quick Actions',
              actionItems: [
                ActionItem(
                  label: 'New Chat',
                  icon: Icons.chat,
                  color: const Color(0xFF00D4AA),
                  onTap: () => _showSnackBar('New chat'),
                ),
                ActionItem(
                  label: 'Import',
                  icon: Icons.upload_file,
                  color: Colors.blue,
                  onTap: () => _showSnackBar('Import'),
                ),
                ActionItem(
                  label: 'Export',
                  icon: Icons.download,
                  color: Colors.purple,
                  onTap: () => _showSnackBar('Export'),
                ),
              ],
              layout: ActionCardLayout.horizontal,
            ),
            const SizedBox(height: 8),
            ActionCard(
              title: 'Danger Zone',
              actionItems: [
                ActionItem(
                  label: 'Clear Cache',
                  icon: Icons.cleaning_services,
                  color: Colors.orange,
                  onTap: () => _showSnackBar('Cache cleared'),
                  confirmTitle: 'Clear Cache?',
                  confirmMessage: 'This will remove all cached data.',
                ),
                ActionItem(
                  label: 'Delete Account',
                  icon: Icons.delete_forever,
                  color: Colors.red,
                  isDestructive: true,
                  onTap: () => _showSnackBar('Delete requested'),
                  confirmTitle: 'Delete Account?',
                  confirmMessage: 'This action cannot be undone.',
                ),
              ],
              layout: ActionCardLayout.vertical,
            ),
          ]),
          
          // Section: Code Cards
          _buildSection('Code Cards', [
            CodeCard(
              title: 'Example Code',
              code: '''
import 'package:flutter/material.dart';

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('Hello, DuckBot!'),
    );
  }
}
''',
              language: 'dart',
              filePath: 'lib/widgets/example.dart',
              showLineNumbers: true,
              collapsible: true,
            ),
            const SizedBox(height: 8),
            CodeCard(
              title: 'API Response',
              code: '''
{
  "status": "success",
  "data": {
    "users": [
      {"id": 1, "name": "Duckets"},
      {"id": 2, "name": "Agent Smith"}
    ]
  }
}
''',
              language: 'json',
              showStats: true,
            ),
          ]),
          
          // Section: File Cards
          _buildSection('File Cards', [
            FileCard(
              file: FileData(
                name: 'config.yaml',
                path: '/home/duckbot/config.yaml',
                sizeBytes: 2048,
                extension: 'yaml',
                modifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
                preview: '''
gateway:
  host: localhost
  port: 18789
  
agents:
  model: bailian/MiniMax-M2.5
  max_tokens: 128000
''',
              ),
              showPreview: true,
              previewLines: 5,
              onOpen: () => _showSnackBar('Open file'),
              onDownload: () => _showSnackBar('Download file'),
            ),
          ]),
          
          // Section: Link Cards
          _buildSection('Link Cards', [
            LinkCard(
              link: LinkData(
                url: 'https://github.com/Franzferdinan51/duckbot',
                domain: 'github.com',
                title: 'DuckBot - AI Assistant Framework',
                description: 'A powerful AI assistant framework with OpenClaw integration.',
                isSecure: true,
              ),
              onTap: () => _showSnackBar('Link tapped'),
            ),
            const SizedBox(height: 8),
            ArticleLinkCard(
              link: LinkData(
                url: 'https://example.com/article',
                domain: 'example.com',
                title: 'The Future of AI Assistants',
                description: 'Exploring how AI assistants will transform our daily lives.',
              ),
              source: 'Tech News',
              author: 'Jane Doe',
              readTime: 5,
              publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ]),
          
          // Section: Image Cards
          _buildSection('Image Cards', [
            ImageCard(
              title: 'Gallery Example',
              images: [
                ImageData(
                  url: 'https://example.com/image1.jpg',
                  caption: 'First image',
                ),
                ImageData(
                  url: 'https://example.com/image2.jpg',
                  caption: 'Second image',
                ),
                ImageData(
                  url: 'https://example.com/image3.jpg',
                  caption: 'Third image',
                ),
              ],
              layout: ImageCardLayout.gallery,
              showIndicators: true,
              showCounter: true,
            ),
            const SizedBox(height: 8),
            ImageCard(
              title: 'Grid Layout',
              images: List.generate(
                6,
                (i) => ImageData(
                  url: 'https://example.com/photo$i.jpg',
                  caption: 'Photo ${i + 1}',
                ),
              ),
              layout: ImageCardLayout.grid,
            ),
          ]),
          
          // Section: Swipe Actions Demo
          _buildSection('Swipe Actions', [
            StatusCard(
              title: 'Swipe Me',
              state: CardState.success,
              statusText: 'Try swiping left or right',
              accentColor: const Color(0xFF00D4AA),
              swipeLeftAction: InfoCardSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onAction: () => _showSnackBar('Delete action'),
              ),
              swipeRightAction: InfoCardSwipeAction(
                icon: Icons.archive,
                label: 'Archive',
                color: Colors.blue,
                onAction: () => _showSnackBar('Archive action'),
              ),
            ),
          ]),
          
          // Section: Loading & Error States
          _buildSection('States', [
            const StatusCard(
              title: 'Loading State',
              state: CardState.loading,
              statusText: 'Loading...',
              isLoading: true,
            ),
            const SizedBox(height: 8),
            StatusCard(
              title: 'Error State',
              state: CardState.error,
              statusText: 'Something went wrong',
              errorMessage: 'Connection timeout. Please try again.',
            ),
          ]),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        ...cards,
        const SizedBox(height: 16),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[800],
      ),
    );
  }
}