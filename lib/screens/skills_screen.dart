import 'package:flutter/material.dart';
import '../services/gateway_service.dart';

/// Skills Platform Screen
/// ClawHub integration - list, install, uninstall skills
class SkillsScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const SkillsScreen({super.key, this.gatewayService});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SkillInfo> _installedSkills = [];
  List<SkillInfo> _availableSkills = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'agent-*',
    'apple-*',
    'automation-*',
    'communication-*',
    'data-*',
    'media-*',
    'productivity-*',
    'system-*',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSkills();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _installedSkills = [
        SkillInfo(
          id: 'android-engineer',
          name: 'Android Engineer',
          description: 'Control Android devices via ADB with vision analysis',
          category: 'automation',
          version: '1.2.0',
          author: 'OpenClaw',
          installed: true,
          icon: '📱',
          tags: ['adb', 'android', 'automation'],
        ),
        SkillInfo(
          id: 'weather',
          name: 'Weather',
          description: 'Get current weather and forecasts via wttr.in',
          category: 'data',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: true,
          icon: '🌤️',
          tags: ['weather', 'forecast', 'api'],
        ),
        SkillInfo(
          id: 'summarize',
          name: 'Summarize',
          description: 'Summarize URLs, podcasts, and local files',
          category: 'productivity',
          version: '1.1.0',
          author: 'OpenClaw',
          installed: true,
          icon: '📝',
          tags: ['summarize', 'transcription', 'content'],
        ),
        SkillInfo(
          id: 'github',
          name: 'GitHub',
          description: 'GitHub operations via gh CLI',
          category: 'productivity',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: true,
          icon: '🐙',
          tags: ['github', 'git', 'pull-requests'],
        ),
        SkillInfo(
          id: 'coding-agent',
          name: 'Coding Agent',
          description: 'Delegate coding tasks to Codex, Claude Code, or Pi',
          category: 'agent',
          version: '1.3.0',
          author: 'OpenClaw',
          installed: true,
          icon: '🤖',
          tags: ['coding', 'subagent', 'ai'],
        ),
        SkillInfo(
          id: 'discord',
          name: 'Discord',
          description: 'Discord operations via message tool',
          category: 'communication',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: true,
          icon: '🎮',
          tags: ['discord', 'chat', 'messaging'],
        ),
        SkillInfo(
          id: 'openhue',
          name: 'OpenHue',
          description: 'Control Philips Hue lights and scenes',
          category: 'automation',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: true,
          icon: '💡',
          tags: ['hue', 'lights', 'smarthome'],
        ),
        SkillInfo(
          id: 'stardew-openclaw',
          name: 'Stardew Valley',
          description: 'Control Stardew Valley through MCP bridge',
          category: 'games',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: true,
          icon: '🎮',
          tags: ['stardew', 'gaming', 'mcp'],
        ),
      ];

      _availableSkills = [
        SkillInfo(
          id: 'apple-notes',
          name: 'Apple Notes',
          description: 'Manage Apple Notes via memo CLI on macOS',
          category: 'apple',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '📝',
          tags: ['notes', 'apple', 'macos'],
          downloads: 1250,
        ),
        SkillInfo(
          id: 'apple-reminders',
          name: 'Apple Reminders',
          description: 'Manage Apple Reminders via remindctl CLI',
          category: 'apple',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '✅',
          tags: ['reminders', 'apple', 'macos'],
          downloads: 890,
        ),
        SkillInfo(
          id: 'things-mac',
          name: 'Things 3',
          description: 'Manage Things 3 via things CLI on macOS',
          category: 'apple',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '📋',
          tags: ['things', 'todos', 'macos'],
          downloads: 2100,
        ),
        SkillInfo(
          id: 'obsidian',
          name: 'Obsidian',
          description: 'Work with Obsidian vaults via obsidian-cli',
          category: 'productivity',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🔮',
          tags: ['obsidian', 'notes', 'markdown'],
          downloads: 3400,
        ),
        SkillInfo(
          id: 'bear-notes',
          name: 'Bear Notes',
          description: 'Create, search, and manage Bear notes via grizzly CLI',
          category: 'apple',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🐻',
          tags: ['bear', 'notes', 'macos'],
          downloads: 1800,
        ),
        SkillInfo(
          id: 'xurl',
          name: 'X (Twitter) API',
          description: 'Post tweets, reply, search, manage followers via xurl CLI',
          category: 'communication',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🐦',
          tags: ['twitter', 'x', 'social'],
          downloads: 4500,
        ),
        SkillInfo(
          id: 'songsee',
          name: 'SongSee',
          description: 'Generate spectrograms from audio files',
          category: 'media',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🎵',
          tags: ['audio', 'spectrogram', 'visualization'],
          downloads: 560,
        ),
        SkillInfo(
          id: 'video-frames',
          name: 'Video Frames',
          description: 'Extract frames or clips from videos using ffmpeg',
          category: 'media',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🎬',
          tags: ['video', 'ffmpeg', 'frames'],
          downloads: 2300,
        ),
        SkillInfo(
          id: 'camsnap',
          name: 'CamSnap',
          description: 'Capture frames from RTSP/ONVIF cameras',
          category: 'automation',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '📷',
          tags: ['camera', 'rtsp', 'onvif'],
          downloads: 1200,
        ),
        SkillInfo(
          id: 'blucli',
          name: 'BluOS CLI',
          description: 'Control BluOS speakers - discovery, playback, volume',
          category: 'media',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🔊',
          tags: ['bluos', 'audio', 'speaker'],
          downloads: 450,
        ),
        SkillInfo(
          id: 'sonoscli',
          name: 'Sonos CLI',
          description: 'Control Sonos speakers - discover/status/play/volume',
          category: 'media',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🔊',
          tags: ['sonos', 'audio', 'speaker'],
          downloads: 1800,
        ),
        SkillInfo(
          id: 'eightctl',
          name: 'Eight Sleep',
          description: 'Control Eight Sleep pods - temperature, alarms, schedules',
          category: 'automation',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🛏️',
          tags: ['sleep', 'temperature', 'smart-bed'],
          downloads: 890,
        ),
        SkillInfo(
          id: 'himalaya',
          name: 'Himalaya Email',
          description: 'CLI for IMAP/SMTP email management',
          category: 'communication',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '📧',
          tags: ['email', 'imap', 'smtp'],
          downloads: 1560,
        ),
        SkillInfo(
          id: 'imsg',
          name: 'iMessage/SMS',
          description: 'iMessage/SMS CLI for listing chats and sending messages',
          category: 'communication',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '💬',
          tags: ['imessage', 'sms', 'macos'],
          downloads: 3200,
        ),
        SkillInfo(
          id: 'wacli',
          name: 'WhatsApp CLI',
          description: 'Send WhatsApp messages and search history',
          category: 'communication',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '💬',
          tags: ['whatsapp', 'messaging'],
          downloads: 5600,
        ),
        SkillInfo(
          id: 'gog',
          name: 'Google Workspace',
          description: 'CLI for Gmail, Calendar, Drive, Contacts, Sheets, Docs',
          category: 'productivity',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '📊',
          tags: ['google', 'gmail', 'calendar'],
          downloads: 7800,
        ),
        SkillInfo(
          id: '1password',
          name: '1Password',
          description: 'Use 1Password CLI (op) for secrets management',
          category: 'security',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🔐',
          tags: ['1password', 'secrets', 'security'],
          downloads: 4500,
        ),
        SkillInfo(
          id: 'mcporter',
          name: 'MCP Porter',
          description: 'List, configure, auth, and call MCP servers/tools',
          category: 'developer',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🔌',
          tags: ['mcp', 'tools', 'api'],
          downloads: 2100,
        ),
        SkillInfo(
          id: 'gemini',
          name: 'Gemini CLI',
          description: 'Gemini CLI for one-shot Q&A and generation',
          category: 'ai',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '✨',
          tags: ['gemini', 'ai', 'generation'],
          downloads: 6700,
        ),
        SkillInfo(
          id: 'openai-whisper',
          name: 'Whisper STT',
          description: 'Local speech-to-text with Whisper CLI',
          category: 'ai',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '🎤',
          tags: ['whisper', 'speech', 'transcription'],
          downloads: 8900,
        ),
        SkillInfo(
          id: 'peekaboo',
          name: 'Peekaboo',
          description: 'Capture and automate macOS UI',
          category: 'apple',
          version: '1.0.0',
          author: 'OpenClaw',
          installed: false,
          icon: '👁️',
          tags: ['macos', 'ui', 'automation'],
          downloads: 1200,
        ),
      ];
      
      _isLoading = false;
    });
  }

  List<SkillInfo> _filterSkills(List<SkillInfo> skills) {
    var filtered = skills;
    
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered.where((s) => s.category.startsWith(_selectedCategory!.replaceAll('*', ''))).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }
    
    return filtered;
  }

  void _installSkill(SkillInfo skill) {
    setState(() {
      skill = skill.copyWith(installed: true);
      _installedSkills.add(skill);
      _availableSkills.removeWhere((s) => s.id == skill.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${skill.name} installed successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _uninstallSkill(SkillInfo skill) {
    setState(() {
      _installedSkills.removeWhere((s) => s.id == skill.id);
      _availableSkills.add(skill.copyWith(installed: false));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${skill.name} uninstalled'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Installed (${_installedSkills.length})'),
            Tab(text: 'Browse (${_availableSkills.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search skills...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category || 
                          (_selectedCategory == null && category == 'All');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = category),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSkillList(_filterSkills(_installedSkills), true),
                      _buildSkillList(_filterSkills(_availableSkills), false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillList(List<SkillInfo> skills, bool isInstalled) {
    if (skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInstalled ? Icons.extension_off : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isInstalled ? 'No skills installed' : 'No skills found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: skills.length,
      itemBuilder: (context, index) => _SkillCard(
        skill: skills[index],
        isInstalled: isInstalled,
        onInstall: () => _installSkill(skills[index]),
        onUninstall: () => _uninstallSkill(skills[index]),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillInfo skill;
  final bool isInstalled;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;

  const _SkillCard({
    required this.skill,
    required this.isInstalled,
    required this.onInstall,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSkillDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(skill.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            skill.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (skill.downloads != null) ...[
                          Icon(Icons.download, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDownloads(skill.downloads!),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: skill.tags.take(3).map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isInstalled)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: onUninstall,
                )
              else
                FilledButton(
                  onPressed: onInstall,
                  child: const Text('Install'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSkillDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(skill.icon, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(skill.name, style: Theme.of(context).textTheme.headlineSmall),
                        Text('v${skill.version} • ${skill.author}', style: Theme.of(context).textTheme.bodySmall),
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
              
              Text('Description', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(skill.description),
              const SizedBox(height: 24),
              
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skill.tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
              const SizedBox(height: 24),
              
              if (skill.downloads != null) ...[
                Text('Statistics', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text('${skill.downloads} downloads'),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              SizedBox(
                width: double.infinity,
                child: isInstalled
                    ? OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onUninstall();
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Uninstall'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onInstall();
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Install'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDownloads(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

class SkillInfo {
  final String id;
  final String name;
  final String description;
  final String category;
  final String version;
  final String author;
  final bool installed;
  final String icon;
  final List<String> tags;
  final int? downloads;

  SkillInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.version,
    required this.author,
    required this.installed,
    required this.icon,
    required this.tags,
    this.downloads,
  });

  SkillInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? version,
    String? author,
    bool? installed,
    String? icon,
    List<String>? tags,
    int? downloads,
  }) {
    return SkillInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      version: version ?? this.version,
      author: author ?? this.author,
      installed: installed ?? this.installed,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      downloads: downloads ?? this.downloads,
    );
  }
}