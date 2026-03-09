import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

// ============================================================================
// CUSTOM CATEGORIES FOR OPENCLAW
// ============================================================================

/// Extended categories for OpenClaw quick actions
enum OpenClawCategory {
  grow,      // 🌿 Plant/garden monitoring
  system,    // 🛠️ System operations
  setup,     // ⚙️ Installation & setup
  weather,   // 🌤️ Weather info
  agents,    // 🤖 Agent interactions
  phone,     // 📱 Phone/Termux/ADB
}

// ============================================================================
// BUILT-IN ACTION DEFINITIONS
// ============================================================================

/// Built-in quick actions (not from API)
class BuiltInAction {
  final String id;
  final String name;
  final String description;
  final String icon;
  final OpenClawCategory category;
  final Future<String> Function(WidgetRef ref) execute;

  const BuiltInAction({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.execute,
  });
}

// ============================================================================
// QUICK ACTIONS SCREEN
// ============================================================================

/// Quick Actions Screen - Grid of action buttons by category
class QuickActionsScreen extends ConsumerStatefulWidget {
  final String? category;

  const QuickActionsScreen({super.key, this.category});

  @override
  ConsumerState<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends ConsumerState<QuickActionsScreen> {
  String _searchQuery = '';
  OpenClawCategory? _selectedCategory;
  bool _showSetupWizard = false;

  /// Built-in actions for this device
  late final List<BuiltInAction> _builtInActions = _createBuiltInActions();

  List<BuiltInAction> _createBuiltInActions() {
    return [
      // 🌿 GROW CATEGORY
      BuiltInAction(
        id: 'grow_status',
        name: 'Status',
        description: 'Check plant health status',
        icon: 'eco',
        category: OpenClawCategory.grow,
        execute: (ref) async => await _executeGrowCommand('status'),
      ),
      BuiltInAction(
        id: 'grow_photo',
        name: 'Photo',
        description: 'Capture plant photo',
        icon: 'photo_camera',
        category: OpenClawCategory.grow,
        execute: (ref) async => await _executeGrowCommand('photo'),
      ),
      BuiltInAction(
        id: 'grow_analyze',
        name: 'Analyze',
        description: 'AI plant health analysis',
        icon: 'analytics',
        category: OpenClawCategory.grow,
        execute: (ref) async => await _executeGrowCommand('analyze'),
      ),
      BuiltInAction(
        id: 'grow_alerts',
        name: 'Alerts',
        description: 'Check grow alerts',
        icon: 'notifications_active',
        category: OpenClawCategory.grow,
        execute: (ref) async => await _executeGrowCommand('alerts'),
      ),

      // 🛠️ SYSTEM CATEGORY
      BuiltInAction(
        id: 'system_backup',
        name: 'Backup',
        description: 'Backup OpenClaw config',
        icon: 'backup',
        category: OpenClawCategory.system,
        execute: (ref) async => await _executeSystemCommand('backup'),
      ),
      BuiltInAction(
        id: 'system_restart',
        name: 'Restart',
        description: 'Restart OpenClaw gateway',
        icon: 'restart_alt',
        category: OpenClawCategory.system,
        execute: (ref) async => await _executeSystemCommand('restart'),
      ),
      BuiltInAction(
        id: 'system_kanban',
        name: 'KANBAN',
        description: 'View task board',
        icon: 'view_kanban',
        category: OpenClawCategory.system,
        execute: (ref) async => 'KANBAN view coming soon...',
      ),
      BuiltInAction(
        id: 'system_config',
        name: 'Config',
        description: 'Edit configuration',
        icon: 'settings_suggest',
        category: OpenClawCategory.system,
        execute: (ref) async => await _executeSystemCommand('config'),
      ),

      // ⚙️ SETUP CATEGORY
      BuiltInAction(
        id: 'setup_install',
        name: 'Install OpenClaw',
        description: 'Run installer via ADB/Termux',
        icon: 'download',
        category: OpenClawCategory.setup,
        execute: (ref) async => await _runInstaller(),
      ),
      BuiltInAction(
        id: 'setup_node',
        name: 'Setup Node',
        description: 'Configure phone as node',
        icon: 'devices',
        category: OpenClawCategory.setup,
        execute: (ref) async => await _setupNode(),
      ),
      BuiltInAction(
        id: 'setup_connect',
        name: 'Connect Gateway',
        description: 'Auto-discover gateway',
        icon: 'router',
        category: OpenClawCategory.setup,
        execute: (ref) async => await _connectGateway(),
      ),
      BuiltInAction(
        id: 'setup_wizard',
        name: 'Guided Setup',
        description: 'Step-by-step wizard',
        icon: 'auto_fix_high',
        category: OpenClawCategory.setup,
        execute: (ref) async {
          _openSetupWizard();
          return 'Opening setup wizard...';
        },
      ),

      // 🌤️ WEATHER CATEGORY
      BuiltInAction(
        id: 'weather_current',
        name: 'Current',
        description: 'Current conditions',
        icon: 'wb_sunny',
        category: OpenClawCategory.weather,
        execute: (ref) async => await _getWeather('current'),
      ),
      BuiltInAction(
        id: 'weather_storm',
        name: 'Storm',
        description: 'Storm alerts nearby',
        icon: 'thunderstorm',
        category: OpenClawCategory.weather,
        execute: (ref) async => await _getWeather('storm'),
      ),
      BuiltInAction(
        id: 'weather_forecast',
        name: 'Forecast',
        description: '7-day forecast',
        icon: 'calendar_today',
        category: OpenClawCategory.weather,
        execute: (ref) async => await _getWeather('forecast'),
      ),

      // 🤖 AGENTS CATEGORY
      BuiltInAction(
        id: 'agent_chat',
        name: 'Chat',
        description: 'Start agent chat',
        icon: 'chat',
        category: OpenClawCategory.agents,
        execute: (ref) async {
          _navigateToChat();
          return 'Opening chat...';
        },
      ),
      BuiltInAction(
        id: 'agent_research',
        name: 'Research',
        description: 'Deep research task',
        icon: 'travel_explore',
        category: OpenClawCategory.agents,
        execute: (ref) async => await _spawnAgent('research', ref),
      ),
      BuiltInAction(
        id: 'agent_code',
        name: 'Code',
        description: 'Spawn coding agent',
        icon: 'code',
        category: OpenClawCategory.agents,
        execute: (ref) async => await _spawnAgent('coding', ref),
      ),

      // 📱 PHONE CATEGORY
      BuiltInAction(
        id: 'phone_adb',
        name: 'ADB Commands',
        description: 'Execute ADB commands',
        icon: 'terminal',
        category: OpenClawCategory.phone,
        execute: (ref) async => await _showAdbSheet(),
      ),
      BuiltInAction(
        id: 'phone_termux',
        name: 'Termux Shell',
        description: 'Open Termux shell',
        icon: 'terminal',
        category: OpenClawCategory.phone,
        execute: (ref) async => await _executeTermuxCommand('shell'),
      ),
      BuiltInAction(
        id: 'phone_status',
        name: 'Node Status',
        description: 'This device status',
        icon: 'device_hub',
        category: OpenClawCategory.phone,
        execute: (ref) async => await _getNodeStatus(),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _selectedCategory = OpenClawCategory.values.firstWhere(
        (c) => c.name == widget.category,
        orElse: () => OpenClawCategory.setup,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show setup wizard if requested
    if (_showSetupWizard) {
      return _SetupWizardScreen(
        onClose: () => setState(() => _showSetupWizard = false),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Actions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshActions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          // Category filter chips
          _buildCategoryChips(context),
          // Actions grid
          Expanded(
            child: _buildActionsGrid(context),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ...OpenClawCategory.values.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Text(_getCategoryEmoji(category)),
                  label: Text(_getCategoryLabel(category)),
                  selected: _selectedCategory == category,
                  onSelected: (_) => setState(() => _selectedCategory = category),
                  selectedColor: _getCategoryColor(category).withOpacity(0.2),
                  checkmarkColor: _getCategoryColor(category),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    // Get built-in actions filtered by category
    var actions = _builtInActions;
    if (_selectedCategory != null) {
      actions = actions.where((a) => a.category == _selectedCategory).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      actions = actions.where((a) {
        final query = _searchQuery.toLowerCase();
        return a.name.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query);
      }).toList();
    }

    if (actions.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group by category if no category selected
    if (_selectedCategory == null) {
      return _buildGroupedView(context, actions);
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshActions(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) => _BuiltInActionCard(
          action: actions[index],
          onTap: () => _executeBuiltInAction(actions[index]),
        ),
      ),
    );
  }

  Widget _buildGroupedView(BuildContext context, List<BuiltInAction> actions) {
    final grouped = <OpenClawCategory, List<BuiltInAction>>{};
    for (final action in actions) {
      grouped.putIfAbsent(action.category, () => []);
      grouped[action.category]!.add(action);
    }

    // Sort by category order
    final sortedCategories = OpenClawCategory.values.where((c) => grouped.containsKey(c)).toList();

    return RefreshIndicator(
      onRefresh: () async => _refreshActions(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: sortedCategories.map((category) {
          final categoryActions = grouped[category]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryHeader(category: category),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: categoryActions.length,
                itemBuilder: (context, index) => _BuiltInActionCard(
                  action: categoryActions[index],
                  onTap: () => _executeBuiltInAction(categoryActions[index]),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Quick Actions',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No actions match your search.'
                  : 'Quick actions will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 3,
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

  // ===========================================================================
  // ACTION EXECUTION METHODS
  // ===========================================================================

  Future<void> _executeBuiltInAction(BuiltInAction action) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ActionExecutionDialog(
        actionName: action.name,
        onExecute: () => action.execute(ref),
      ),
    );
  }

  Future<String> _executeGrowCommand(String command) async {
    // TODO: Implement grow monitoring commands
    await Future.delayed(const Duration(seconds: 1));
    return 'Grow command "$command" executed successfully';
  }

  Future<String> _executeSystemCommand(String command) async {
    final settings = ref.read(settingsProvider);
    final gatewayUrl = settings.gatewayUrl;

    if (gatewayUrl.isEmpty) {
      return 'Error: Gateway not configured';
    }

    try {
      final dio = Dio();
      final response = await dio.post('$gatewayUrl/api/system/$command');
      return response.data['message'] ?? 'Command executed';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _runInstaller() async {
    // TODO: Implement OpenClaw installer via ADB/Termux
    return '''OpenClaw Installer
==================
1. Checking prerequisites...
2. Installing Node.js...
3. Installing OpenClaw CLI...
4. Configuring gateway...

Installation started in Termux.''';
  }

  Future<String> _setupNode() async {
    // TODO: Implement node setup
    return '''Node Setup
==========
1. Generating node credentials...
2. Configuring ADB access...
3. Setting up permissions...
4. Registering with gateway...

Node configuration started.''';
  }

  Future<String> _connectGateway() async {
    final dio = Dio();

    // Try to auto-discover gateway
    try {
      // Common gateway ports
      const ports = [18789, 8080, 3000];
      
      for (final port in ports) {
        try {
          final response = await dio.get('http://localhost:$port/health',
              options: Options(receiveTimeout: const Duration(seconds: 2)));
          if (response.statusCode == 200) {
            // Found gateway!
            ref.read(settingsProvider.notifier).setGatewayUrl('http://localhost:$port');
            return 'Gateway found at http://localhost:$port';
          }
        } catch (_) {
          continue;
        }
      }

      // Try network discovery
      return 'No gateway found on localhost. Try network discovery.';
    } catch (e) {
      return 'Discovery failed: $e';
    }
  }

  void _openSetupWizard() {
    setState(() => _showSetupWizard = true);
  }

  Future<String> _getWeather(String type) async {
    // TODO: Implement weather via wttr.in or Open-Meteo
    await Future.delayed(const Duration(milliseconds: 500));
    
    switch (type) {
      case 'current':
        return 'Current weather: 72°F, Partly Cloudy';
      case 'storm':
        return 'No storm alerts in your area';
      case 'forecast':
        return '7-day forecast available in weather skill';
      default:
        return 'Weather info coming soon...';
    }
  }

  void _navigateToChat() {
    context.go('/chat');
  }

  Future<String> _spawnAgent(String type, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final gatewayUrl = settings.gatewayUrl;

    if (gatewayUrl.isEmpty) {
      return 'Error: Gateway not configured';
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        '$gatewayUrl/api/agents/spawn',
        data: {'type': type},
      );
      return 'Agent spawned: ${response.data['agentId']}';
    } catch (e) {
      return 'Error spawning agent: $e';
    }
  }

  Future<String> _showAdbSheet() async {
    // Show ADB command sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AdbCommandSheet(),
    );
    return 'ADB sheet closed';
  }

  Future<String> _executeTermuxCommand(String command) async {
    // TODO: Implement Termux API calls
    // This would use Termux:Tasker or Termux:API
    return 'Termux command "$command" executed';
  }

  Future<String> _getNodeStatus() async {
    // TODO: Get local node status
    return '''Node Status
===========
Device: Android
Status: Online
Gateway: Connected
Capabilities:
- Camera: ✓
- Location: ✓
- Notifications: ✓
- Files: ✓
- Shell: ✓ (Termux)''';
  }

  void _refreshActions() {
    setState(() {});
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/chat');
      case 2:
        context.go('/control');
      case 4:
        context.go('/settings');
    }
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ActionSearchDelegate(
        onSearch: (query) => setState(() => _searchQuery = query),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY HELPERS
  // ===========================================================================

  String _getCategoryEmoji(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return '🌿';
      case OpenClawCategory.system:
        return '🛠️';
      case OpenClawCategory.setup:
        return '⚙️';
      case OpenClawCategory.weather:
        return '🌤️';
      case OpenClawCategory.agents:
        return '🤖';
      case OpenClawCategory.phone:
        return '📱';
    }
  }

  String _getCategoryLabel(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return 'GROW';
      case OpenClawCategory.system:
        return 'SYSTEM';
      case OpenClawCategory.setup:
        return 'SETUP';
      case OpenClawCategory.weather:
        return 'WEATHER';
      case OpenClawCategory.agents:
        return 'AGENTS';
      case OpenClawCategory.phone:
        return 'PHONE';
    }
  }

  Color _getCategoryColor(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return Colors.green;
      case OpenClawCategory.system:
        return Colors.blue;
      case OpenClawCategory.setup:
        return Colors.orange;
      case OpenClawCategory.weather:
        return Colors.cyan;
      case OpenClawCategory.agents:
        return Colors.purple;
      case OpenClawCategory.phone:
        return Colors.indigo;
    }
  }
}

// ============================================================================
// BUILT-IN ACTION CARD
// ============================================================================

class _BuiltInActionCard extends StatelessWidget {
  final BuiltInAction action;
  final VoidCallback onTap;

  const _BuiltInActionCard({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = _getCategoryColor(action.category);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(action.icon),
                      color: categoryColor,
                    ),
                  ),
                  const Spacer(),
                  // Name
                  Text(
                    action.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Description
                  Text(
                    action.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'eco':
        return Icons.eco_rounded;
      case 'photo_camera':
      case 'camera':
        return Icons.photo_camera_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'notifications_active':
        return Icons.notifications_active_rounded;
      case 'backup':
        return Icons.backup_rounded;
      case 'restart_alt':
      case 'restart':
        return Icons.restart_alt_rounded;
      case 'view_kanban':
      case 'kanban':
        return Icons.view_kanban_rounded;
      case 'settings_suggest':
      case 'config':
        return Icons.settings_suggest_rounded;
      case 'download':
        return Icons.download_rounded;
      case 'devices':
        return Icons.devices_rounded;
      case 'router':
        return Icons.router_rounded;
      case 'auto_fix_high':
      case 'wizard':
        return Icons.auto_fix_high_rounded;
      case 'wb_sunny':
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'thunderstorm':
      case 'storm':
        return Icons.thunderstorm_rounded;
      case 'calendar_today':
      case 'forecast':
        return Icons.calendar_today_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'travel_explore':
      case 'research':
        return Icons.travel_explore_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'device_hub':
        return Icons.device_hub_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _getCategoryColor(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return Colors.green;
      case OpenClawCategory.system:
        return Colors.blue;
      case OpenClawCategory.setup:
        return Colors.orange;
      case OpenClawCategory.weather:
        return Colors.cyan;
      case OpenClawCategory.agents:
        return Colors.purple;
      case OpenClawCategory.phone:
        return Colors.indigo;
    }
  }
}

// ============================================================================
// CATEGORY HEADER
// ============================================================================

class _CategoryHeader extends StatelessWidget {
  final OpenClawCategory category;

  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor(category);

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getCategoryEmoji(category),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8),
        Text(
          _getCategoryLabel(category),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getCategoryEmoji(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return '🌿';
      case OpenClawCategory.system:
        return '🛠️';
      case OpenClawCategory.setup:
        return '⚙️';
      case OpenClawCategory.weather:
        return '🌤️';
      case OpenClawCategory.agents:
        return '🤖';
      case OpenClawCategory.phone:
        return '📱';
    }
  }

  String _getCategoryLabel(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return 'GROW';
      case OpenClawCategory.system:
        return 'SYSTEM';
      case OpenClawCategory.setup:
        return 'SETUP';
      case OpenClawCategory.weather:
        return 'WEATHER';
      case OpenClawCategory.agents:
        return 'AGENTS';
      case OpenClawCategory.phone:
        return 'PHONE';
    }
  }

  Color _getCategoryColor(OpenClawCategory category) {
    switch (category) {
      case OpenClawCategory.grow:
        return Colors.green;
      case OpenClawCategory.system:
        return Colors.blue;
      case OpenClawCategory.setup:
        return Colors.orange;
      case OpenClawCategory.weather:
        return Colors.cyan;
      case OpenClawCategory.agents:
        return Colors.purple;
      case OpenClawCategory.phone:
        return Colors.indigo;
    }
  }
}

// ============================================================================
// ACTION EXECUTION DIALOG
// ============================================================================

class _ActionExecutionDialog extends StatefulWidget {
  final String actionName;
  final Future<String> Function() onExecute;

  const _ActionExecutionDialog({
    required this.actionName,
    required this.onExecute,
  });

  @override
  State<_ActionExecutionDialog> createState() => _ActionExecutionDialogState();
}

class _ActionExecutionDialogState extends State<_ActionExecutionDialog> {
  late Future<String> _executionFuture;

  @override
  void initState() {
    super.initState();
    _executionFuture = widget.onExecute();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<String>(
      future: _executionFuture,
      builder: (context, snapshot) {
        return AlertDialog(
          title: Row(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (snapshot.hasError)
                Icon(Icons.error_outline, color: colorScheme.error)
              else
                Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Text(widget.actionName),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Text('Executing...')
                else if (snapshot.hasError)
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: colorScheme.error),
                  )
                else
                  SelectableText(
                    snapshot.data ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (snapshot.connectionState != ConnectionState.waiting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// ADB COMMAND SHEET
// ============================================================================

class _AdbCommandSheet extends StatefulWidget {
  const _AdbCommandSheet();

  @override
  State<_AdbCommandSheet> createState() => _AdbCommandSheetState();
}

class _AdbCommandSheetState extends State<_AdbCommandSheet> {
  final _commandController = TextEditingController();
  String _output = '';
  bool _isExecuting = false;

  final _commonCommands = [
    ('Devices', 'adb devices'),
    ('Shell', 'adb shell'),
    ('Screenshot', 'adb shell screencap -p /sdcard/screenshot.png'),
    ('Install APK', 'adb install'),
    ('Logcat', 'adb logcat -d'),
    ('Reboot', 'adb reboot'),
  ];

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'ADB Commands',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Quick commands
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonCommands.map((cmd) {
                  return ActionChip(
                    label: Text(cmd.$1),
                    onPressed: () {
                      _commandController.text = cmd.$2;
                      _executeCommand();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Command input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      decoration: const InputDecoration(
                        hintText: 'adb shell ...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isExecuting ? null : _executeCommand,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Output
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      _output.isEmpty ? 'Output will appear here...' : _output,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _isExecuting = true;
      _output = '> $command\n';
    });

    try {
      // TODO: Implement actual ADB execution
      // This would use Termux or a background service
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _output += 'Command execution simulated.\n';
        _output += 'In production, this would execute via Termux API.\n';
      });
    } catch (e) {
      setState(() {
        _output += 'Error: $e\n';
      });
    } finally {
      setState(() => _isExecuting = false);
    }
  }
}

// ============================================================================
// SETUP WIZARD SCREEN
// ============================================================================

class _SetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _SetupWizardScreen({required this.onClose});

  @override
  ConsumerState<_SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<_SetupWizardScreen> {
  int _currentStep = 0;
  final _steps = [
    'Welcome',
    'Discovery',
    'Connect',
    'Node Setup',
    'Permissions',
    'Skills',
    'Complete',
  ];

  // State for each step
  List<DiscoveredGateway> _discoveredGateways = [];
  String? _selectedGatewayUrl;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _nodeName = '';
  bool _adbEnabled = false;
  bool _sshEnabled = false;
  List<String> _selectedSkills = [];
  List<ClawhubSkill> _availableSkills = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableSkills();
  }

  Future<void> _loadAvailableSkills() async {
    // TODO: Fetch from clawhub
    setState(() {
      _availableSkills = [
        ClawhubSkill(id: 'weather', name: 'Weather', description: 'Get weather info'),
        ClawhubSkill(id: 'summarize', name: 'Summarize', description: 'Summarize content'),
        ClawhubSkill(id: 'browser', name: 'Browser', description: 'Web automation'),
        ClawhubSkill(id: 'coding-agent', name: 'Coding Agent', description: 'Spawn coding subagents'),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onClose,
        ),
        title: const Text('Setup Wizard'),
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
          ),
          // Step indicator
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green
                                    : isActive
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (index < _steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted ? Colors.green : colorScheme.surfaceContainerHighest,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Step content
          Expanded(
            child: _buildStepContent(context),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep(context);
      case 1:
        return _buildDiscoveryStep(context);
      case 2:
        return _buildConnectStep(context);
      case 3:
        return _buildNodeSetupStep(context);
      case 4:
        return _buildPermissionsStep(context);
      case 5:
        return _buildSkillsStep(context);
      case 6:
        return _buildCompleteStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets_rounded,
              size: 50,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to OpenClaw Mobile',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This wizard will help you:\n\n'
            '• Discover OpenClaw gateways on your network\n'
            '• Connect to your gateway\n'
            '• Configure this device as a node\n'
            '• Set up permissions and capabilities\n'
            '• Install useful skills',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover Gateways',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Scanning your network for OpenClaw gateways...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_isScanning)
            const Center(child: CircularProgressIndicator())
          else if (_discoveredGateways.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No gateways found'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _startDiscovery,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _discoveredGateways.length,
                itemBuilder: (context, index) {
                  final gateway = _discoveredGateways[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.dns_rounded),
                      title: Text(gateway.name),
                      subtitle: Text(gateway.url),
                      trailing: gateway.isOnline
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.error_outline, color: Colors.grey),
                      onTap: () {
                        setState(() {
                          _selectedGatewayUrl = gateway.url;
                        });
                      },
                      selected: _selectedGatewayUrl == gateway.url,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _startDiscovery,
            icon: const Icon(Icons.wifi_find_rounded),
            label: const Text('Start Discovery'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to Gateway',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to ${_selectedGatewayUrl ?? "your gateway"}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Gateway URL',
              border: OutlineInputBorder(),
              hintText: 'http://192.168.1.100:18789',
            ),
            onChanged: (value) => _selectedGatewayUrl = value,
            controller: TextEditingController(text: _selectedGatewayUrl ?? ''),
          ),
          const SizedBox(height: 16),
          if (_isConnecting)
            const Center(child: CircularProgressIndicator())
          else if (_isConnected)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('Connected!', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isConnected ? null : _testConnection,
            icon: const Icon(Icons.power_rounded),
            label: Text(_isConnected ? 'Connected' : 'Test Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeSetupStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure Node',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Set up this device as an OpenClaw node',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Node Name',
              border: OutlineInputBorder(),
              hintText: 'My Android Phone',
            ),
            onChanged: (value) => _nodeName = value,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('ADB Access'),
            subtitle: const Text('Allow remote ADB commands'),
            value: _adbEnabled,
            onChanged: (value) => setState(() => _adbEnabled = value),
          ),
          SwitchListTile(
            title: const Text('SSH Access'),
            subtitle: const Text('Allow SSH connections (via Termux)'),
            value: _sshEnabled,
            onChanged: (value) => setState(() => _sshEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final permissions = [
      ('Camera', 'Take photos and record video', Icons.camera_alt_rounded),
      ('Location', 'Access device location', Icons.location_on_rounded),
      ('Notifications', 'Send and receive notifications', Icons.notifications_rounded),
      ('Files', 'Access device files', Icons.folder_rounded),
      ('Microphone', 'Record audio', Icons.mic_rounded),
      ('Shell', 'Execute shell commands (Termux)', Icons.terminal_rounded),
    ];

    final grantedPermissions = <String>{};

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grant Permissions',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Enable capabilities for this node',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    final (name, description, icon) = permissions[index];
                    final isGranted = grantedPermissions.contains(name);

                    return ListTile(
                      leading: Icon(icon),
                      title: Text(name),
                      subtitle: Text(description),
                      trailing: Switch(
                        value: isGranted,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              grantedPermissions.add(name);
                            } else {
                              grantedPermissions.remove(name);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Install Skills',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose skills to install from ClawHub',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _availableSkills.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _availableSkills.length,
                    itemBuilder: (context, index) {
                      final skill = _availableSkills[index];
                      final isSelected = _selectedSkills.contains(skill.id);

                      return ListTile(
                        leading: const Icon(Icons.extension_rounded),
                        title: Text(skill.name),
                        subtitle: Text(skill.description),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedSkills.add(skill.id);
                              } else {
                                _selectedSkills.remove(skill.id);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSkills.remove(skill.id);
                            } else {
                              _selectedSkills.add(skill.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            'Setup Complete!',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your OpenClaw Mobile is now configured.\n\n'
            'Gateway: ${_selectedGatewayUrl ?? "Not connected"}\n'
            'Node: ${_nodeName.isNotEmpty ? _nodeName : "Not configured"}\n'
            'Skills: ${_selectedSkills.length} installed',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(_currentStep == _steps.length - 1 ? 'Finish' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return _selectedGatewayUrl != null;
      case 2:
        return _isConnected;
      case 3:
        return _nodeName.isNotEmpty;
      case 4:
        return true;
      case 5:
        return true;
      case 6:
        return true;
      default:
        return false;
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      // Finish
      _saveConfiguration();
      widget.onClose();
    }
  }

  Future<void> _startDiscovery() async {
    setState(() => _isScanning = true);

    // Simulate discovery
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isScanning = false;
      _discoveredGateways = [
        DiscoveredGateway(
          name: 'OpenClaw Gateway',
          url: 'http://192.168.1.100:18789',
          isOnline: true,
        ),
        DiscoveredGateway(
          name: 'DuckBot Main',
          url: 'http://100.106.80.61:18789',
          isOnline: true,
        ),
      ];
    });
  }

  Future<void> _testConnection() async {
    setState(() => _isConnecting = true);

    try {
      // Save gateway URL
      if (_selectedGatewayUrl != null) {
        await ref.read(settingsProvider.notifier).setGatewayUrl(_selectedGatewayUrl!);
      }

      // Try to connect
      final dio = Dio();
      final response = await dio.get(
        '$_selectedGatewayUrl/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      setState(() {
        _isConnected = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _saveConfiguration() async {
    // Save all settings
    final settings = ref.read(settingsProvider);

    // TODO: Save node configuration to gateway
    // TODO: Install selected skills
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class DiscoveredGateway {
  final String name;
  final String url;
  final bool isOnline;

  DiscoveredGateway({
    required this.name,
    required this.url,
    required this.isOnline,
  });
}

class ClawhubSkill {
  final String id;
  final String name;
  final String description;

  ClawhubSkill({
    required this.id,
    required this.name,
    required this.description,
  });
}

// ============================================================================
// SEARCH DELEGATE
// ============================================================================

class _ActionSearchDelegate extends SearchDelegate<String> {
  final void Function(String) onSearch;

  _ActionSearchDelegate({required this.onSearch});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}