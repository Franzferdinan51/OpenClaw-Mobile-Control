import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gateway_service.dart';
import '../services/termux_run_command_service.dart';
import '../utils/android_package_detector.dart';
import 'termux_hub_screen.dart';

class TermuxScreen extends StatefulWidget {
  const TermuxScreen({super.key});

  @override
  State<TermuxScreen> createState() => _TermuxScreenState();
}

class _TermuxScreenState extends State<TermuxScreen> {
  final TermuxRunCommandService _bridge = TermuxRunCommandService();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();
  final List<_OutputLine> _output = [];

  bool _isRefreshing = false;
  bool _isSending = false;
  bool _isTermuxInstalled = false;
  bool _isTermuxApiInstalled = false;
  bool _hasRunCommandPermission = false;
  bool _isGatewayRunning = false;
  String? _termuxVersion;
  String? _termuxApiVersion;
  TermuxCommandResult? _lastCommandResult;
  final String _gatewayUrl = 'http://127.0.0.1:18789';

  @override
  void initState() {
    super.initState();
    _addOutput(
      'Refreshing Termux bridge status...',
      isSystem: true,
    );
    _refreshStatus(logSummary: false);
  }

  Future<void> _refreshStatus({bool logSummary = true}) async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final termuxResult = await AndroidPackageDetector.checkTermux();
      final termuxApiResult = await AndroidPackageDetector.checkTermuxApi();

      bool hasPermission = false;
      try {
        hasPermission = await _bridge.hasRunCommandPermission();
      } catch (e) {
        _addOutput(
          'Could not verify RUN_COMMAND permission: $e',
          isSystem: true,
          isWarning: true,
        );
      }

      final gatewayResult =
          await GatewayService(baseUrl: _gatewayUrl).checkConnection();
      final gatewayRunning = gatewayResult['success'] == true;

      if (!mounted) return;

      setState(() {
        _isTermuxInstalled = termuxResult.isInstalled;
        _isTermuxApiInstalled = termuxApiResult.isInstalled;
        _hasRunCommandPermission = hasPermission;
        _isGatewayRunning = gatewayRunning;
        _termuxVersion = termuxResult.versionName;
        _termuxApiVersion = termuxApiResult.versionName;
      });

      if (logSummary) {
        _addOutput(
          _isTermuxInstalled
              ? 'Termux ${_termuxVersion ?? ""} detected'
              : 'Termux is not installed',
          isSystem: true,
          isSuccess: _isTermuxInstalled,
          isWarning: !_isTermuxInstalled,
        );
        _addOutput(
          _isTermuxApiInstalled
              ? 'Termux:API ${_termuxApiVersion ?? ""} detected'
              : 'Termux:API is not installed',
          isSystem: true,
          isSuccess: _isTermuxApiInstalled,
          isWarning: !_isTermuxApiInstalled,
        );
        _addOutput(
          _hasRunCommandPermission
              ? 'RUN_COMMAND permission is granted'
              : 'RUN_COMMAND permission is missing for this app',
          isSystem: true,
          isSuccess: _hasRunCommandPermission,
          isWarning: !_hasRunCommandPermission,
        );
        _addOutput(
          _isGatewayRunning
              ? 'Gateway is reachable at $_gatewayUrl'
              : 'Gateway is not reachable at $_gatewayUrl',
          isSystem: true,
          isSuccess: _isGatewayRunning,
          isWarning: !_isGatewayRunning,
        );
        _addSeparator();
      }
    } catch (e) {
      _addOutput(
        'Status refresh failed: $e',
        isSystem: true,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _sendCommand({
    required String label,
    required String script,
    String? description,
  }) async {
    if (!_isTermuxInstalled) {
      _showSnackBar('Install Termux first');
      return;
    }

    if (!_hasRunCommandPermission) {
      _showSnackBar('Grant RUN_COMMAND permission first');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final trimmedScript = script.trim();
    _addOutput('Sending command to Termux: $label', isSystem: true);
    _addOutput(trimmedScript, isCommand: true);

    try {
      final result = await _bridge.runCommandDetailed(
        script: trimmedScript,
        label: label,
        description: description,
        background: false,
      );

      if (!mounted) return;
      _lastCommandResult = result;

      if (result.requiresAllowExternalApps) {
        _addOutput(
          'Termux rejected the command because allow-external-apps is disabled. Open Termux, add allow-external-apps=true to ~/.termux/termux.properties, run termux-reload-settings, then retry.',
          isSystem: true,
          isError: true,
        );
        _showAllowExternalAppsDialog();
      } else if (result.accepted) {
        _addOutput(
          result.pending
              ? 'Command accepted by Termux. Watch the Termux session for output.'
              : 'Command finished. Review the Termux session for output.',
          isSystem: true,
          isSuccess: true,
        );

        if (trimmedScript.contains('openclaw gateway')) {
          Future<void>.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _refreshStatus(logSummary: false);
            }
          });
        }
      } else {
        _addOutput(
          _describeTermuxResult(
            result,
            fallback: 'Termux did not accept the command.',
          ),
          isSystem: true,
          isError: true,
        );
      }
    } catch (e) {
      _addOutput(
        'Command failed: $e',
        isSystem: true,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendTypedCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _commandController.clear();
    await _sendCommand(
      label: 'Custom DuckBot Command',
      script: command,
      description: 'Run a custom command in Termux',
    );
  }

  Future<void> _copySetupCommands() async {
    await Clipboard.setData(
      ClipboardData(text: _bridge.noRootInstallScript.trim()),
    );
    _showSnackBar('Setup commands copied');
  }

  Future<void> _copyAllowExternalAppsFix() async {
    await Clipboard.setData(
      ClipboardData(text: _bridge.allowExternalAppsSetupScript.trim()),
    );
    _showSnackBar('allow-external-apps fix copied');
  }

  Future<void> _launchTermux() async {
    final launched = await _bridge.launchTermux();
    if (!mounted) return;

    if (!launched) {
      _showSnackBar('Termux is not installed');
    }
  }

  Future<void> _openAppSettings({String? packageName}) async {
    await _bridge.openAppSettings(packageName: packageName);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showSnackBar('Could not open $url');
    }
  }

  Future<void> _openTermuxHubCatalog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermuxHubScreen(),
      ),
    );
  }

  String _describeTermuxResult(
    TermuxCommandResult result, {
    required String fallback,
  }) {
    if (result.requiresAllowExternalApps) {
      return 'Termux needs ${TermuxRunCommandService.allowExternalAppsSnippet} in ~/.termux/termux.properties, then ${TermuxRunCommandService.allowExternalAppsReloadCommand}.';
    }
    if ((result.errorMessage ?? '').trim().isNotEmpty) {
      return result.errorMessage!.trim();
    }
    if (result.exitCode != null) {
      return 'Command exited with code ${result.exitCode}. Review Termux for output.';
    }
    return fallback;
  }

  void _showAllowExternalAppsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Termux External Commands'),
        content: const Text(
          'Termux blocks external command intents until you enable allow-external-apps in ~/.termux/termux.properties. '
          'Open Termux, add "allow-external-apps=true", run "termux-reload-settings", then retry.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openUrl(TermuxRunCommandService.runCommandHelpUrl);
            },
            child: const Text('Open Docs'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _copyAllowExternalAppsFix();
            },
            child: const Text('Copy Fix'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchTermux();
            },
            child: const Text('Open Termux'),
          ),
        ],
      ),
    );
  }

  void _addOutput(
    String text, {
    bool isCommand = false,
    bool isSystem = false,
    bool isSuccess = false,
    bool isError = false,
    bool isWarning = false,
  }) {
    setState(() {
      _output.add(
        _OutputLine(
          text,
          isCommand: isCommand,
          isSystem: isSystem,
          isSuccess: isSuccess,
          isError: isError,
          isWarning: isWarning,
        ),
      );
    });
    _scrollToBottom();
  }

  void _addSeparator() {
    _addOutput('─' * 40, isSystem: true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyOutput() {
    final allOutput = _output.map((line) => line.text).join('\n');
    Clipboard.setData(ClipboardData(text: allOutput));
    _showSnackBar('Bridge log copied');
  }

  void _clearOutput() {
    setState(() {
      _output.clear();
    });
    _addOutput('Bridge log cleared', isSystem: true);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux Bridge'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh status',
            onPressed: _isRefreshing ? null : () => _refreshStatus(),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy bridge log',
            onPressed: _copyOutput,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear',
            onPressed: _clearOutput,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          _buildNoticeBanner(),
          _buildQuickActionsBar(),
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              child: ListView.builder(
                controller: _outputScrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  final line = _output[index];
                  return _buildOutputLine(line);
                },
              ),
            ),
          ),
          _buildCommandInput(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statusChip(
              'Termux',
              _isTermuxInstalled ? (_termuxVersion ?? 'Installed') : 'Missing',
              _isTermuxInstalled,
            ),
            const SizedBox(width: 8),
            _statusChip(
              'Termux:API',
              _isTermuxApiInstalled
                  ? (_termuxApiVersion ?? 'Installed')
                  : 'Missing',
              _isTermuxApiInstalled,
            ),
            const SizedBox(width: 8),
            _statusChip(
              'RUN_COMMAND',
              _hasRunCommandPermission ? 'Granted' : 'Missing',
              _hasRunCommandPermission,
            ),
            const SizedBox(width: 8),
            _statusChip(
              'Gateway',
              _isGatewayRunning ? 'Reachable' : 'Offline',
              _isGatewayRunning,
            ),
            if (_lastCommandResult?.requiresAllowExternalApps == true) ...[
              const SizedBox(width: 8),
              _statusChip(
                'External Apps',
                'Enable in Termux',
                false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String detail, bool ok) {
    final color = ok ? Colors.green : Colors.orange;
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        size: 16,
        color: color,
      ),
      label: Text(
        '$label: $detail',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.35),
      child: Text(
        'This screen sends commands to the official Termux app. Command output appears in Termux, not inside DuckBot. If commands are rejected, enable allow-external-apps=true in ~/.termux/termux.properties and run termux-reload-settings.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _quickActionBtn(
              'Open Termux',
              Icons.terminal,
              _launchTermux,
              isPrimary: true,
            ),
            _quickActionBtn(
              'Copy Setup',
              Icons.copy,
              _copySetupCommands,
            ),
            _quickActionBtn(
              'External Apps',
              Icons.tune,
              _copyAllowExternalAppsFix,
            ),
            _quickActionBtn(
              'Send Setup',
              Icons.download,
              () => _sendCommand(
                label: 'DuckBot No-Root Setup',
                script: _bridge.noRootInstallScript,
                description:
                    'Install Node.js, termux-api, storage access, and OpenClaw',
              ),
            ),
            _quickActionBtn(
              'Start Gateway',
              Icons.play_arrow,
              () => _sendCommand(
                label: 'Start OpenClaw Gateway',
                script: _bridge.startGatewayScript,
                description: 'Start the local OpenClaw gateway',
              ),
            ),
            _quickActionBtn(
              'Stop Gateway',
              Icons.stop,
              () => _sendCommand(
                label: 'Stop OpenClaw Gateway',
                script: _bridge.stopGatewayScript,
                description: 'Stop the local OpenClaw gateway',
              ),
            ),
            _quickActionBtn(
              'Status',
              Icons.info_outline,
              () => _sendCommand(
                label: 'OpenClaw Status',
                script: _bridge.statusScript,
                description: 'Check OpenClaw status inside Termux',
              ),
            ),
            _quickActionBtn(
              'Tool Catalog',
              Icons.explore,
              _openTermuxHubCatalog,
            ),
            if (!_hasRunCommandPermission)
              _quickActionBtn(
                'Permission',
                Icons.settings,
                () => _openAppSettings(),
              ),
            if (!_isTermuxInstalled) ...[
              _quickActionBtn(
                'F-Droid',
                Icons.download,
                () => _openUrl(TermuxRunCommandService.termuxAppFdroidUrl),
              ),
              _quickActionBtn(
                'Releases',
                Icons.open_in_new,
                () => _openUrl(TermuxRunCommandService.termuxAppGithubUrl),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickActionBtn(
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            )
          : ActionChip(
              avatar: Icon(icon, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 11)),
              onPressed: onPressed,
            ),
    );
  }

  Widget _buildOutputLine(_OutputLine line) {
    Color textColor;
    if (line.isError) {
      textColor = Colors.redAccent;
    } else if (line.isSuccess) {
      textColor = Colors.greenAccent;
    } else if (line.isWarning) {
      textColor = Colors.orangeAccent;
    } else if (line.isCommand) {
      textColor = Colors.cyanAccent;
    } else if (line.isSystem) {
      textColor = Colors.grey;
    } else {
      textColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        line.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: textColor,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildCommandInput() {
    final enabled =
        !_isSending && _isTermuxInstalled && _hasRunCommandPermission;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Text(
            r'$ ',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _commandController,
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Send a command to Termux'
                    : 'Install Termux and grant permission first',
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onSubmitted: (_) => _sendTypedCommand(),
              enabled: enabled,
            ),
          ),
          if (_isSending)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: enabled ? _sendTypedCommand : null,
              color: Colors.cyan,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }
}

class _OutputLine {
  final String text;
  final bool isCommand;
  final bool isSystem;
  final bool isSuccess;
  final bool isError;
  final bool isWarning;

  _OutputLine(
    this.text, {
    this.isCommand = false,
    this.isSystem = false,
    this.isSuccess = false,
    this.isError = false,
    this.isWarning = false,
  });
}
