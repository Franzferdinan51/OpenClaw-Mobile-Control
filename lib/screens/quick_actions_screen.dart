import 'package:flutter/material.dart';

class QuickActionsScreen extends StatefulWidget {
  const QuickActionsScreen({super.key});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  // Track loading state for each action
  final Map<String, bool> _loadingActions = {};

  void _executeAction(String actionName) async {
    setState(() {
      _loadingActions[actionName] = true;
    });

    // Special handling for Update OpenClaw
    if (actionName == 'update_openclaw') {
      if (!mounted) return;
      
      // Show "Updating OpenClaw..." toast
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

      // Simulate update process (replace with actual SSH/Termux command)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _loadingActions[actionName] = false;
      });

      // Show "Update complete!" toast
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Update complete!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Simulate API call delay (replace with actual HTTP service calls)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _loadingActions[actionName] = false;
    });

    // Show toast with result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: $actionName executed'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
            '⚙️ SETUP',
            Icons.settings,
            [
              _ActionItem('Install OpenClaw', Icons.download, 'install_openclaw'),
              _ActionItem('Update OpenClaw', Icons.system_update, 'update_openclaw'),
              _ActionItem('Setup Node', Icons.computer, 'setup_node'),
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