import 'package:flutter/material.dart';
import '../services/termux_service.dart';
import '../services/gateway_service.dart';
import 'termux_screen.dart';
import 'chat_screen.dart';

class QuickActionsScreen extends StatefulWidget {
  final bool showAdvanced;
  final GatewayService? gatewayService;

  const QuickActionsScreen({super.key, this.showAdvanced = false, this.gatewayService});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  // Track loading state for each action
  final Map<String, bool> _loadingActions = {};
  final TermuxService _termuxService = TermuxService();
  String? _openClawVersion;

  @override
  void initState() {
    super.initState();
    _checkTermuxStatus();
  }

  Future<void> _checkTermuxStatus() async {
    await _termuxService.initialize();
    setState(() {
      _openClawVersion = _termuxService.openClawVersion;
    });
  }

  void _navigateToTermux() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermuxScreen()),
    );
  }

  void _executeAction(String actionName) async {
    setState(() {
      _loadingActions[actionName] = true;
    });

    // Handle Termux-based actions
    if (actionName == 'termux_console') {
      _navigateToTermux();
      setState(() => _loadingActions[actionName] = false);
      return;
    }

    if (actionName == 'install_openclaw') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Installing OpenClaw via Termux...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      final result = await _termuxService.installOpenClaw();
      
      setState(() {
        _openClawVersion = _termuxService.openClawVersion;
        _loadingActions[actionName] = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(result.success ? 'OpenClaw installed: $_openClawVersion' : 'Install failed: ${result.stderr}'),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (actionName == 'update_openclaw') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Updating OpenClaw...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      final result = await _termuxService.updateOpenClaw();
      
      setState(() {
        _openClawVersion = _termuxService.openClawVersion;
        _loadingActions[actionName] = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(result.success ? 'Updated to: $_openClawVersion' : 'Update failed: ${result.stderr}'),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (actionName == 'setup_node') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Setting up node...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final result = await _termuxService.setupNode();
      
      setState(() {
        _loadingActions[actionName] = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(result.success ? 'Node setup complete!' : 'Setup failed: ${result.stderr}'),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Quick command execution
    if (actionName.startsWith('cmd_')) {
      final command = actionName.substring(4); // Remove 'cmd_' prefix
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Running: $command'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      final result = await _termuxService.runQuickCommand(command);
      
      setState(() {
        _loadingActions[actionName] = false;
      });

      if (!mounted) return;

      // Show result dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(command),
          content: SingleChildScrollView(
            child: SelectableText(
              result.output.isNotEmpty ? result.output : '(no output)',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    // Handle specific placeholder actions
    if (actionName == 'agents_chat') {
      setState(() {
        _loadingActions[actionName] = false;
      });
      // Navigate to chat screen with gateway service
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(gatewayService: widget.gatewayService)),
      );
      return;
    }

    // Default fallback for other actions (placeholder)
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _loadingActions[actionName] = false;
    });

    // Show a more informative placeholder message
    _showPlaceholderDialog(actionName);
  }

  void _showPlaceholderDialog(String actionName) {
    final actionDescriptions = {
      'status': 'Check plant/system status - requires connected sensors',
      'photo': 'Capture photo from camera - requires camera permission',
      'analyze': 'Analyze plant health using AI - requires photo first',
      'alerts': 'Configure alert notifications - requires gateway connection',
      'backup': 'Create system backup - requires storage permission',
      'restart': 'Restart OpenClaw services - requires Termux',
      'kanban': 'Open KANBAN board - feature coming soon',
      'config': 'Edit configuration files - requires Termux',
      'weather_current': 'Get current weather from weather service',
      'weather_storm': 'Check for storm alerts - requires weather API',
      'weather_forecast': 'Get weather forecast - requires weather API',
      'agents_research': 'Spawn research agent - requires gateway connection',
      'agents_code': 'Spawn coding agent - requires gateway connection',
      'connect_gateway': 'Connect to OpenClaw gateway',
      'guided_setup': 'Run guided setup wizard',
    };

    final description = actionDescriptions[actionName] ?? 'Feature coming soon!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(actionName.replaceAll('_', ' ').toUpperCase()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool _isLoading(String actionName) {
    return _loadingActions[actionName] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Actions'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory(
            '🌿 GROW',
            Icons.eco,
            [
              _ActionItem('Status', Icons.info_outline, 'status'),
              _ActionItem('Photo', Icons.camera_alt, 'photo'),
              _ActionItem('Analyze', Icons.analytics, 'analyze'),
              _ActionItem('Alerts', Icons.notifications_active, 'alerts'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '🛠️ SYSTEM',
            Icons.build,
            [
              _ActionItem('Backup', Icons.backup, 'backup'),
              _ActionItem('Restart', Icons.refresh, 'restart'),
              _ActionItem('Update OpenClaw', Icons.system_update, 'update_openclaw'),
              _ActionItem('KANBAN', Icons.view_kanban, 'kanban'),
              _ActionItem('Config', Icons.settings_applications, 'config'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '🌤️ WEATHER',
            Icons.wb_sunny,
            [
              _ActionItem('Current', Icons.thermostat, 'weather_current'),
              _ActionItem('Storm', Icons.thunderstorm, 'weather_storm'),
              _ActionItem('Forecast', Icons.calendar_month, 'weather_forecast'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '🤖 AGENTS',
            Icons.smart_toy,
            [
              _ActionItem('Chat', Icons.chat, 'agents_chat'),
              _ActionItem('Research', Icons.search, 'agents_research'),
              _ActionItem('Code', Icons.code, 'agents_code'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '📱 TERMUX',
            Icons.terminal,
            [
              _ActionItem('Console', Icons.terminal, 'termux_console'),
              _ActionItem('Install OpenClaw', Icons.download, 'install_openclaw'),
              _ActionItem('Update OpenClaw', Icons.system_update, 'update_openclaw'),
              _ActionItem('Setup Node', Icons.computer, 'setup_node'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '⚡ QUICK COMMANDS',
            Icons.flash_on,
            [
              _ActionItem('openclaw status', Icons.info_outline, 'cmd_openclaw status'),
              _ActionItem('gateway restart', Icons.refresh, 'cmd_openclaw gateway restart'),
              _ActionItem('nodes status', Icons.hub, 'cmd_openclaw nodes status'),
              _ActionItem('gateway start', Icons.play_arrow, 'cmd_openclaw gateway start'),
              _ActionItem('gateway stop', Icons.stop, 'cmd_openclaw gateway stop'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            '⚙️ SETUP',
            Icons.settings,
            [
              _ActionItem('Connect Gateway', Icons.wifi_tethering, 'connect_gateway'),
              _ActionItem('Guided Setup', Icons.auto_fix_high, 'guided_setup'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, IconData icon, List<_ActionItem> actions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return _ActionButton(
                  label: action.label,
                  icon: action.icon,
                  isLoading: _isLoading(action.name),
                  onPressed: () => _executeAction(action.name),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final String name;

  _ActionItem(this.label, this.icon, this.name);
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}