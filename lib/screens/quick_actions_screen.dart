import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import '../services/gateway_service.dart';
import '../services/local_metrics_service.dart';
import 'agent_monitor_screen.dart';
import 'backup_restore_screen.dart';
import 'boss_chat_screen.dart';
import 'chat_screen.dart';
import 'connect_gateway_screen.dart';
import 'local_installer_screen.dart';
import 'logs_screen.dart';
import 'office_preview_screen.dart';
import 'termux_screen.dart';

class QuickActionsScreen extends StatefulWidget {
  final bool showAdvanced;
  final GatewayService? gatewayService;
  final VoidCallback? onOpenChat;

  const QuickActionsScreen({
    super.key,
    this.showAdvanced = false,
    this.gatewayService,
    this.onOpenChat,
  });

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  final Map<String, bool> _loadingActions = {};
  final BackupService _backupService = BackupService();
  final LocalMetricsService _localMetricsService = LocalMetricsService();

  GatewayService? _service;
  LocalMetrics? _lastMetrics;
  LocalRuntimeStatus? _runtimeStatus;
  Map<String, dynamic>? _connectionCheck;

  @override
  void initState() {
    super.initState();
    _initializeContext();
  }

  @override
  void didUpdateWidget(covariant QuickActionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final gatewayChanged =
        oldWidget.gatewayService?.baseUrl != widget.gatewayService?.baseUrl ||
            oldWidget.gatewayService?.token != widget.gatewayService?.token;

    if (gatewayChanged) {
      _initializeContext();
    }
  }

  @override
  void dispose() {
    _localMetricsService.dispose();
    super.dispose();
  }

  Future<void> _initializeContext() async {
    final service = await _resolveGatewayService();
    if (!mounted) return;

    setState(() {
      _service = service;
    });

    if (service != null) {
      _localMetricsService.setGatewayUrl(service.baseUrl);
    }

    await _refreshOverview();
  }

  Future<GatewayService?> _resolveGatewayService() async {
    if (widget.gatewayService != null) {
      return widget.gatewayService;
    }

    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString('gateway_url');
    if (gatewayUrl == null || gatewayUrl.isEmpty) {
      return null;
    }

    return GatewayService(
      baseUrl: gatewayUrl,
      token: prefs.getString('gateway_token'),
    );
  }

  Future<void> _refreshOverview() async {
    if (_service == null) {
      if (mounted) {
        setState(() {
          _connectionCheck = null;
          _lastMetrics = null;
          _runtimeStatus = null;
        });
      }
      return;
    }

    final connectionCheck = await _service!.checkConnection();
    LocalMetrics? metrics;
    LocalRuntimeStatus? runtimeStatus;

    if (_isLocalGateway(_service!.baseUrl)) {
      try {
        metrics = await _localMetricsService.getMetrics(forceRefresh: true);
      } catch (_) {
        metrics = null;
      }

      try {
        runtimeStatus = await _localMetricsService.getRuntimeStatus();
      } catch (_) {
        runtimeStatus = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _connectionCheck = connectionCheck;
      _lastMetrics = metrics;
      _runtimeStatus = runtimeStatus;
    });
  }

  bool _isLocalGateway(String url) {
    return url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.startsWith('http://192.168.') ||
        url.startsWith('http://10.') ||
        url.startsWith('http://172.');
  }

  Future<void> _executeAction(String actionName) async {
    setState(() {
      _loadingActions[actionName] = true;
    });

    try {
      switch (actionName) {
        case 'refresh_overview':
          await _refreshOverview();
          _showResult('Status refreshed');
          break;
        case 'test_gateway':
          await _testGateway();
          break;
        case 'connect_gateway':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConnectGatewayScreen(
                onConnected: () {
                  _initializeContext();
                },
              ),
            ),
          );
          break;
        case 'open_logs':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogsScreen()),
          );
          break;
        case 'restart_gateway':
          await _restartGateway();
          break;
        case 'open_chat':
          if (!mounted) break;
          if (widget.onOpenChat != null) {
            widget.onOpenChat!();
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(gatewayService: _service),
              ),
            );
          }
          break;
        case 'test_chat':
          await _testChat();
          break;
        case 'boss_chat':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BossChatScreen(gatewayService: _service),
            ),
          );
          break;
        case 'agent_monitor':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AgentMonitorScreen(gatewayService: _service),
            ),
          );
          break;
        case 'office_view':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OfficePreviewScreen(gatewayService: _service),
            ),
          );
          break;
        case 'test_metrics':
          await _testMetrics();
          break;
        case 'runtime_status':
          if (!mounted) break;
          await _refreshOverview();
          if (!mounted) break;
          _showRuntimeStatusSheet();
          break;
        case 'installer':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocalInstallerScreen(),
            ),
          );
          await _refreshOverview();
          break;
        case 'termux_console':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TermuxScreen()),
          );
          await _refreshOverview();
          break;
        case 'backup_now':
          await _createBackup();
          break;
        case 'open_backups':
          if (!mounted) break;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BackupRestoreScreen(),
            ),
          );
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingActions[actionName] = false;
        });
      }
    }
  }

  Future<void> _testGateway() async {
    if (_service == null) {
      _showResult('No gateway configured', isError: true);
      return;
    }

    final result = await _service!.checkConnection();
    if (!mounted) return;

    setState(() {
      _connectionCheck = result;
    });

    _showResult(
      result['success'] == true
          ? 'Gateway reachable via ${result['endpoint']}'
          : 'Gateway test failed: ${result['error']}',
      isError: result['success'] != true,
    );
  }

  Future<void> _restartGateway() async {
    if (_service == null) {
      _showResult('No gateway configured', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Gateway'),
        content: const Text(
          'This will briefly disconnect active sessions. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result =
        await _service!.restartGateway('Manual restart from control hub');
    await _refreshOverview();
    _showResult(
      result?['success'] == true
          ? 'Gateway restart requested'
          : 'Restart failed',
      isError: result?['success'] != true,
    );
  }

  Future<void> _testChat() async {
    if (_service == null) {
      _showResult('No gateway configured', isError: true);
      return;
    }

    final agents = await _service!.getAgents();
    if (agents == null || agents.isEmpty) {
      _showResult('No active sessions found for chat', isError: true);
      return;
    }

    final target = agents.firstWhere(
      (agent) => !agent.isSubagent && agent.key.isNotEmpty,
      orElse: () => agents.first,
    );

    final history = await _service!.getChatHistory(target.key, limit: 5);
    _showResult(
      history != null
          ? 'Chat session "${target.name}" responded with ${history.length} message(s)'
          : 'Chat history unavailable',
      isError: history == null,
    );
  }

  Future<void> _testMetrics() async {
    if (_service == null || !_isLocalGateway(_service!.baseUrl)) {
      _showResult('Local metrics only apply to local or LAN runtimes',
          isError: true);
      return;
    }

    try {
      final metrics = await _localMetricsService.getMetrics(forceRefresh: true);
      final runtime = await _localMetricsService.getRuntimeStatus();

      if (!mounted) return;
      setState(() {
        _lastMetrics = metrics;
        _runtimeStatus = runtime;
      });

      _showResult(
        metrics.isAvailable
            ? 'Metrics OK via ${metrics.source ?? 'unknown'}'
            : metrics.error ?? 'Metrics unavailable',
        isError: !metrics.isAvailable,
      );
    } catch (e) {
      _showResult('Metrics test failed: $e', isError: true);
    }
  }

  Future<void> _createBackup() async {
    final success = await _backupService.backup();
    _showResult(
      success
          ? 'Backup created successfully'
          : 'Backup failed: ${_backupService.lastError}',
      isError: !success,
    );
  }

  void _showRuntimeStatusSheet() {
    final runtime = _runtimeStatus;
    if (runtime == null) {
      _showResult('Runtime status is not available', isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Local Runtime Status',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildRuntimeRow(
                'Gateway',
                runtime.gatewayRunning,
                runtime.gatewayLatencyMs != null
                    ? '${runtime.gatewayLatencyMs}ms'
                    : runtime.gatewayError ?? 'Unavailable',
              ),
              _buildRuntimeRow(
                'Metrics Helper',
                runtime.helperRunning,
                runtime.helperLatencyMs != null
                    ? '${runtime.helperLatencyMs}ms'
                    : runtime.helperError ?? 'Not running',
              ),
              _buildRuntimeRow(
                'Termux',
                runtime.termuxInstalled,
                runtime.termuxInstalled ? 'Installed' : 'Missing',
              ),
              _buildRuntimeRow(
                'Termux API',
                runtime.termuxApiInstalled,
                runtime.termuxApiInstalled ? 'Installed' : 'Missing',
              ),
              _buildRuntimeRow(
                'RUN_COMMAND',
                runtime.runCommandPermissionGranted,
                runtime.runCommandPermissionGranted
                    ? 'Granted'
                    : 'Grant in app settings',
              ),
              if (runtime.readiness != null) ...[
                const SizedBox(height: 16),
                Text(
                  runtime.readiness!.readinessText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _executeAction('termux_console');
                      },
                      icon: const Icon(Icons.terminal),
                      label: const Text('Termux'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _executeAction('installer');
                      },
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Repair'),
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

  void _showResult(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
        title: const Text('Control Hub'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOverviewCard(),
          const SizedBox(height: 16),
          _buildCategory(
            'GATEWAY',
            Icons.router,
            [
              _ActionItem('Refresh', Icons.refresh, 'refresh_overview'),
              _ActionItem('Test Gateway', Icons.wifi_tethering, 'test_gateway'),
              _ActionItem('Connect', Icons.link, 'connect_gateway'),
              _ActionItem('Restart', Icons.restart_alt, 'restart_gateway'),
              _ActionItem('Logs', Icons.subject, 'open_logs'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            'CHAT & AGENTS',
            Icons.smart_toy,
            [
              _ActionItem('Open Chat', Icons.chat, 'open_chat'),
              _ActionItem('Test Chat', Icons.mark_chat_read, 'test_chat'),
              _ActionItem('Boss Chat', Icons.campaign, 'boss_chat'),
              _ActionItem('Monitor', Icons.monitor_heart, 'agent_monitor'),
              if (widget.showAdvanced)
                _ActionItem('Office View', Icons.apartment, 'office_view'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            'LOCAL RUNTIME',
            Icons.developer_mode,
            [
              _ActionItem('Test Metrics', Icons.memory, 'test_metrics'),
              _ActionItem('Status', Icons.health_and_safety, 'runtime_status'),
              _ActionItem('Repair', Icons.build_circle_outlined, 'installer'),
              _ActionItem('Termux', Icons.terminal, 'termux_console'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            'DATA',
            Icons.backup,
            [
              _ActionItem('Backup Now', Icons.backup, 'backup_now'),
              _ActionItem('Backups', Icons.restore, 'open_backups'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final gatewayOk = _connectionCheck?['success'] == true;
    final metricsOk = _lastMetrics?.isAvailable == true;
    final helperOk = _runtimeStatus?.helperRunning == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _service?.baseUrl ?? 'No gateway configured',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusPill(
                  gatewayOk ? 'Gateway connected' : 'Gateway offline',
                  gatewayOk ? Colors.green : Colors.red,
                ),
                _buildStatusPill(
                  metricsOk
                      ? 'Metrics: ${_lastMetrics!.source ?? 'unknown'}'
                      : (_service != null && _isLocalGateway(_service!.baseUrl)
                          ? 'Metrics unavailable'
                          : 'Remote runtime'),
                  metricsOk ? Colors.blue : Colors.orange,
                ),
                if (_runtimeStatus != null)
                  _buildStatusPill(
                    helperOk ? 'Helper running' : 'Helper missing',
                    helperOk ? Colors.green : Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCategory(
      String title, IconData icon, List<_ActionItem> actions) {
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
                childAspectRatio: 2.7,
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

  Widget _buildRuntimeRow(String label, bool ok, String detail) {
    final color = ok ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
