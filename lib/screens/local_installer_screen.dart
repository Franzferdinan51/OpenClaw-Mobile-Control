import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/nodejs_installer_service.dart';
import '../services/gateway_service.dart';
import '../services/termux_service.dart';
import '../services/termux_run_command_service.dart';
import '../utils/android_package_detector.dart';
import 'agent_library_screen.dart';
import 'connect_gateway_screen.dart';
import 'node_settings_screen.dart';

/// Local OpenClaw Installer Screen
///
/// Guides users through installing OpenClaw locally on Android using
/// the official Termux app and Termux:API app. No root required.
///
/// Features:
/// - Comprehensive prerequisite checking
/// - Clear status messages for what's installed/missing
/// - Step-by-step installation with progress
/// - Detailed logging for troubleshooting
class LocalInstallerScreen extends StatefulWidget {
  final Function()? onInstallationComplete;

  const LocalInstallerScreen({super.key, this.onInstallationComplete});

  @override
  State<LocalInstallerScreen> createState() => _LocalInstallerScreenState();
}

class _LocalInstallerScreenState extends State<LocalInstallerScreen>
    with TickerProviderStateMixin {
  final TermuxService _termuxService = TermuxService();
  final TermuxRunCommandService _termuxBridge = TermuxRunCommandService();

  // Installation state
  InstallationState _state = InstallationState.idle;
  InstallationStep _currentStep = InstallationStep.checkingPrerequisites;
  double _progress = 0.0;
  String _statusMessage = 'Checking prerequisites...';
  String? _errorMessage;
  final List<InstallLogEntry> _logs = [];
  bool _setupSentToTermux = false;
  bool _hasRunCommandPermission = false;

  // Prerequisite check results
  TermuxReadinessSummary? _readinessSummary;
  bool _isCheckingReadiness = false;
  bool _hasShownReadiness = false;

  // Controllers
  final ScrollController _logsScrollController = ScrollController();
  late AnimationController _pulseController;

  // Gateway info after installation
  final String _gatewayUrl = 'http://127.0.0.1:18789';
  bool _gatewayRunning = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _checkReadiness();
  }

  Future<void> _checkReadiness() async {
    setState(() {
      _isCheckingReadiness = true;
    });

    try {
      // Initialize Termux service for detection
      await _termuxService.initialize();
      _hasRunCommandPermission = await _termuxBridge.hasRunCommandPermission();

      // Get readiness summary
      _readinessSummary = await TermuxPrerequisiteChecker.getReadinessSummary();

      // Log results
      _log('info',
          'Readiness check complete: ${_readinessSummary!.readinessText}');
      _log('info',
          'Passed ${_readinessSummary!.passedChecks}/${_readinessSummary!.totalChecks} checks');
      _log(
        _hasRunCommandPermission ? 'info' : 'error',
        _hasRunCommandPermission
            ? 'RUN_COMMAND permission granted'
            : 'RUN_COMMAND permission missing - grant it in app settings',
      );

      if (_readinessSummary!.blockingIssues.isNotEmpty) {
        for (final issue in _readinessSummary!.blockingIssues) {
          _log('error', 'BLOCKING: ${issue.name} - ${issue.actionRequired}');
        }
      }

      if (_readinessSummary!.recommendations.isNotEmpty) {
        for (final rec in _readinessSummary!.recommendations) {
          _log('info', 'RECOMMENDED: ${rec.name} - ${rec.actionRequired}');
        }
      }
    } catch (e) {
      _log('error', 'Readiness check failed: $e');
    }

    setState(() {
      _isCheckingReadiness = false;
      _hasShownReadiness = true;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logsScrollController.hasClients) {
        _logsScrollController.animateTo(
          _logsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _log(String level, String message, [String? details]) {
    if (mounted) {
      setState(() {
        _logs.add(InstallLogEntry(
          timestamp: DateTime.now(),
          level: level,
          message: message,
          details: details,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _startInstallation() async {
    // Check if ready to install
    if (_readinessSummary != null && !_readinessSummary!.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please resolve blocking issues before installing'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!_hasRunCommandPermission) {
      _showRunCommandPermissionDialog();
      return;
    }

    setState(() {
      _state = InstallationState.installingOpenClaw;
      _currentStep = InstallationStep.installingOpenClaw;
      _progress = 0.2;
      _statusMessage = 'Sending no-root setup to Termux...';
      _errorMessage = null;
    });

    _log('info', 'Sending no-root install command to Termux');
    _log('info', 'Command sequence:');
    _log('info', _termuxBridge.noRootInstallScript.trim());

    try {
      final success = await _termuxBridge.runCommand(
        script: _termuxBridge.noRootInstallScript,
        label: 'DuckBot No-Root Setup',
        description:
            'Install Node.js, termux-api package, storage access, and OpenClaw',
        background: false,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _setupSentToTermux = true;
          _state = InstallationState.idle;
          _progress = 1.0;
          _statusMessage =
              'Setup sent to Termux. Finish there, then return and test connection.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Setup sent to Termux. Complete it there and return here.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _state = InstallationState.error;
          _errorMessage = 'Termux did not accept the setup command.';
        });
      }
    } catch (e) {
      setState(() {
        _state = InstallationState.error;
        _errorMessage = 'Failed to send setup to Termux: $e';
      });
    }
  }

  Future<void> _startGateway() async {
    setState(() {
      _state = InstallationState.startingGateway;
      _currentStep = InstallationStep.startingGateway;
      _progress = 0.3;
      _statusMessage = 'Sending gateway start command to Termux...';
    });

    try {
      final success = await _termuxBridge.runCommand(
        script: _termuxBridge.startGatewayScript,
        label: 'Start OpenClaw Gateway',
        description: 'Start the local OpenClaw gateway on port 18789',
        background: false,
      );

      if (!mounted) return;

      setState(() {
        _gatewayRunning = false;
        _setupSentToTermux = success || _setupSentToTermux;
        _state =
            success ? InstallationState.completed : InstallationState.error;
        _progress = success ? 1.0 : 0.0;
        _statusMessage = success
            ? 'Gateway start sent to Termux. Verify reachability after it starts.'
            : 'Gateway start failed.';
        _errorMessage =
            success ? null : 'Failed to send gateway start to Termux.';
      });

      if (success) {
        _log('info', 'Gateway start command sent to Termux');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gateway start sent to Termux'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = InstallationState.error;
        _errorMessage = 'Failed to send gateway command: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _statusMessage = 'Testing connection...';
    });

    final gatewayService = GatewayService(baseUrl: _gatewayUrl);
    final result = await gatewayService.checkConnection();

    if (mounted) {
      final success = result['success'] == true;
      setState(() {
        _gatewayRunning = success;
        _state = success ? InstallationState.completed : _state;
        _statusMessage = success
            ? 'Gateway is reachable at $_gatewayUrl'
            : 'Gateway is not reachable yet';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ Connection successful!'
              : '❌ Connection failed: ${result['error']}'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _copyLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== OpenClaw Installation Logs ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    for (final log in _logs) {
      buffer.writeln('[${log.level.toUpperCase()}] ${log.message}');
      if (log.details != null) {
        buffer.writeln('  → ${log.details}');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Logs copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _copyNoRootSetupCommands() async {
    await Clipboard.setData(
      ClipboardData(text: _termuxBridge.noRootInstallScript.trim()),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No-root setup commands copied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _copyGatewayStartCommand() async {
    await Clipboard.setData(
      ClipboardData(text: _termuxBridge.startGatewayScript),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gateway start command copied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _openAppSettings({String? packageName}) async {
    await _termuxBridge.openAppSettings(packageName: packageName);
  }

  Future<void> _launchTermuxApp() async {
    final launched = await _termuxBridge.launchTermux();
    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Termux app is not installed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRunCommandPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Termux Command Permission'),
        content: const Text(
          'This app needs the official Termux RUN_COMMAND permission to send no-root setup commands. '
          'Open this app’s Android settings, allow the additional Termux permission, then retry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  void _showTroubleshooting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Troubleshooting'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTroubleshootingSection(
                'Installation Fails',
                [
                  'Make sure you have enough storage space (~500MB)',
                  'Check your internet connection',
                  'Try restarting the app and trying again',
                  'Use the official Termux app from F-Droid or GitHub Releases, not Google Play',
                  'Install the Termux:API app from the same source as Termux',
                  'Grant this app the Termux RUN_COMMAND permission in Android settings',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                'Gateway Won\'t Start',
                [
                  'Check that port 18789 is not in use by another app',
                  'Try stopping any existing gateway: "openclaw gateway stop"',
                  'Check the logs for specific error messages',
                  'Make sure Node.js was installed correctly',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                'Connection Issues',
                [
                  'Verify the gateway is running: check the status indicator',
                  'Try connecting to http://127.0.0.1:18789 in your browser',
                  'Check that no firewall is blocking localhost connections',
                  'Restart the gateway if needed',
                ],
              ),
              const SizedBox(height: 16),
              _buildTroubleshootingSection(
                'Manual Installation (Fallback)',
                [
                  'If in-app launch fails, use the official no-root flow manually:',
                  '1. Install Termux and Termux:API from the same source (F-Droid or GitHub Releases)',
                  '2. Open Termux once',
                  '3. Run: pkg update -y && pkg upgrade -y',
                  '4. Run: pkg install -y nodejs termux-api',
                  '5. Run: termux-setup-storage',
                  '6. Run: npm install -g openclaw --unsafe-perm',
                  '7. Run: openclaw gateway start --port 18789',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14)),
                  Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _logsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local OpenClaw Installer'),
        actions: [
          if (!_isCheckingReadiness && _readinessSummary != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkReadiness,
              tooltip: 'Re-check prerequisites',
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showTroubleshooting,
            tooltip: 'Troubleshooting',
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyLogs,
              tooltip: 'Copy logs',
            ),
        ],
      ),
      body: Column(
        children: [
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card
                  _buildHeaderCard(colorScheme),
                  const SizedBox(height: 24),

                  // Prerequisites check (shown before installation)
                  if (_hasShownReadiness &&
                      _readinessSummary != null &&
                      _state == InstallationState.idle)
                    _buildReadinessCard(colorScheme),

                  if (_hasShownReadiness &&
                      _readinessSummary != null &&
                      _state == InstallationState.idle)
                    const SizedBox(height: 24),

                  // Progress indicator
                  if (_state != InstallationState.idle &&
                      _state != InstallationState.completed)
                    _buildProgressCard(colorScheme),

                  if (_state != InstallationState.idle &&
                      _state != InstallationState.completed)
                    const SizedBox(height: 24),

                  // Error card
                  if (_errorMessage != null) _buildErrorCard(colorScheme),

                  if (_errorMessage != null) const SizedBox(height: 24),

                  // Success card
                  if (_setupSentToTermux ||
                      _state == InstallationState.completed ||
                      _gatewayRunning)
                    _buildSuccessCard(colorScheme),

                  if (_setupSentToTermux ||
                      _state == InstallationState.completed ||
                      _gatewayRunning)
                    const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(colorScheme),
                  const SizedBox(height: 24),

                  // Requirements info
                  _buildRequirementsCard(colorScheme),
                ],
              ),
            ),
          ),

          // Logs panel (collapsible)
          if (_logs.isNotEmpty) _buildLogsPanel(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colorScheme.primary
                            .withOpacity(0.3 + (_pulseController.value * 0.3)),
                        colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.install_desktop,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Install OpenClaw Locally',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the official Termux app and Termux:API app to run OpenClaw '
              'directly on Android with no root access.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCard(ColorScheme colorScheme) {
    if (_isCheckingReadiness) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking prerequisites...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifying Termux, Node.js, and system requirements',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _readinessSummary!;
    final isReady = summary.isReady;
    final blockingCount = summary.blockingIssues.length;
    final recommendedCount = summary.recommendations.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReady ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.error,
                  color: isReady ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Installation Readiness',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        summary.readinessText,
                        style: TextStyle(
                          color: isReady ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Progress
            LinearProgressIndicator(
              value: summary.passedChecks / summary.totalChecks,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isReady ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.passedChecks}/${summary.totalChecks} checks passed',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 16),

            // Blocking issues
            if (blockingCount > 0) ...[
              Text(
                '⚠️ Blocking Issues ($blockingCount)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...summary.blockingIssues.map((issue) => _buildPrerequisiteItem(
                    issue.name,
                    issue.message ?? 'Not satisfied',
                    issue.actionRequired,
                    false,
                  )),
              const SizedBox(height: 16),
            ],

            // Recommendations
            if (recommendedCount > 0) ...[
              Text(
                '💡 Recommendations ($recommendedCount)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...summary.recommendations.map((issue) => _buildPrerequisiteItem(
                    issue.name,
                    issue.message ?? 'Not satisfied',
                    issue.actionRequired,
                    true,
                  )),
              const SizedBox(height: 16),
            ],

            // Termux info
            if (_termuxService.isInitialized) ...[
              const Divider(height: 24),
              Text(
                'Detected Environment',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Termux',
                  _termuxService.isTermuxAvailable
                      ? '✅ ${_termuxService.termuxVersion ?? "Installed"}'
                      : '❌ Not installed'),
              _buildInfoRow(
                  'Termux:API',
                  _termuxService.isTermuxApiAvailable
                      ? '✅ ${_termuxService.termuxApiDetectionResult?.versionName ?? "Installed"}'
                      : 'ℹ️ Missing app'),
              _buildInfoRow(
                  'RUN_COMMAND Permission',
                  _hasRunCommandPermission
                      ? '✅ Granted'
                      : '❌ Grant in app settings'),
              _buildInfoRow('Install Mode', 'Official Termux no-root'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _launchExternalUrl(
                      TermuxRunCommandService.termuxAppFdroidUrl,
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Termux F-Droid'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launchExternalUrl(
                      TermuxRunCommandService.termuxAppGithubUrl,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Termux Releases'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launchExternalUrl(
                      TermuxRunCommandService.termuxApiFdroidUrl,
                    ),
                    icon: const Icon(Icons.extension),
                    label: const Text('Termux:API F-Droid'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launchExternalUrl(
                      TermuxRunCommandService.termuxApiGithubUrl,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Termux:API Releases'),
                  ),
                  if (!_hasRunCommandPermission)
                    OutlinedButton.icon(
                      onPressed: () => _openAppSettings(),
                      icon: const Icon(Icons.settings),
                      label: const Text('Grant Permission'),
                    )
                  else if (_termuxService.isTermuxAvailable)
                    OutlinedButton.icon(
                      onPressed: _launchTermuxApp,
                      icon: const Icon(Icons.terminal),
                      label: const Text('Open Termux'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisiteItem(
      String name, String status, String? action, bool isRecommended) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecommended
            ? Colors.orange.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRecommended
              ? Colors.orange.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRecommended ? Icons.info_outline : Icons.error_outline,
                size: 16,
                color: isRecommended ? Colors.orange : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color:
                  isRecommended ? Colors.orange.shade700 : Colors.red.shade700,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 4),
            Text(
              '→ $action',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isRecommended
                    ? Colors.orange.shade600
                    : Colors.red.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ColorScheme colorScheme) {
    IconData stepIcon;
    Color stepColor;

    switch (_currentStep) {
      case InstallationStep.checkingPrerequisites:
        stepIcon = Icons.fact_check;
        stepColor = Colors.blue;
        break;
      case InstallationStep.installingNodejs:
        stepIcon = Icons.download;
        stepColor = Colors.orange;
        break;
      case InstallationStep.installingOpenClaw:
        stepIcon = Icons.install_mobile;
        stepColor = Colors.purple;
        break;
      case InstallationStep.configuringEnvironment:
        stepIcon = Icons.settings;
        stepColor = Colors.teal;
        break;
      case InstallationStep.startingGateway:
        stepIcon = Icons.rocket_launch;
        stepColor = Colors.green;
        break;
      case InstallationStep.completed:
        stepIcon = Icons.check_circle;
        stepColor = Colors.green;
        break;
    }

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: stepColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(stepIcon, color: stepColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStep.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_state == InstallationState.installingNodejs ||
                    _state == InstallationState.installingOpenClaw ||
                    _state == InstallationState.startingGateway)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: colorScheme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(stepColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}% complete',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Card(
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Installation Error',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showTroubleshooting,
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('View Troubleshooting Guide'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(ColorScheme colorScheme) {
    final gatewayUrl = _gatewayUrl;
    final title = _gatewayRunning
        ? 'Gateway Ready'
        : _setupSentToTermux
            ? 'Setup Sent to Termux'
            : 'Local Setup Ready';
    final description = _gatewayRunning
        ? 'The local OpenClaw gateway responded. You can test or connect to it from this device.'
        : _setupSentToTermux
            ? 'Finish the install in Termux, then return here and start or test the gateway.'
            : 'Local setup commands are ready. Continue in Termux to finish installation.';

    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green[800],
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          gatewayUrl,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: gatewayUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copied to clipboard'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _gatewayRunning ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _gatewayRunning
                            ? 'Gateway reachable'
                            : 'Awaiting verification',
                        style: TextStyle(
                          color: _gatewayRunning ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    if (_state == InstallationState.installingNodejs ||
        _state == InstallationState.installingOpenClaw ||
        _state == InstallationState.startingGateway) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Installing...'),
      );
    }

    if (_isCheckingReadiness) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Checking prerequisites...'),
      );
    }

    final readinessReady = _readinessSummary?.isReady ?? false;
    final canInstall = readinessReady && _hasRunCommandPermission;
    final needsTermux = !_termuxService.isTermuxAvailable;
    final needsPermission = !_hasRunCommandPermission;
    final showPostSetup = _setupSentToTermux ||
        _state == InstallationState.completed ||
        _gatewayRunning;

    if (_state == InstallationState.error) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: canInstall ? _startInstallation : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.orange,
            ),
            icon: const Icon(Icons.refresh),
            label: Text(
              canInstall ? 'Retry Setup' : 'Resolve Setup Issues First',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyNoRootSetupCommands,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Setup Commands'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyLogs,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Copy Error Logs'),
          ),
        ],
      );
    }

    if (showPostSetup) {
      return Column(
        children: [
          if (!_gatewayRunning)
            FilledButton.icon(
              onPressed: _startGateway,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.green,
              ),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Send Gateway Start to Termux'),
            )
          else ...[
            FilledButton.icon(
              onPressed: _testConnection,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              icon: const Icon(Icons.network_check),
              label: const Text('Test Connection'),
            ),
          ],
          const SizedBox(height: 12),
          if (!_gatewayRunning)
            OutlinedButton.icon(
              onPressed: _testConnection,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.network_check),
              label: const Text('Check Gateway Reachability'),
            ),
          if (!_gatewayRunning) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConnectGatewayScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Connect Local or Remote Gateway'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AgentLibraryScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.psychology_alt),
            label: const Text('Agent Setup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NodeSettingsScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.hub),
            label: const Text('Node Setup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _launchTermuxApp,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.terminal),
            label: const Text('Open Termux'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyGatewayStartCommand,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy Gateway Command'),
          ),
        ],
      );
    }

    if (needsTermux) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: () => _launchExternalUrl(
              TermuxRunCommandService.termuxAppFdroidUrl,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Install Termux from F-Droid'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _launchExternalUrl(
              TermuxRunCommandService.termuxAppGithubUrl,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Termux Releases'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConnectGatewayScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Use Remote Gateway Instead'),
          ),
        ],
      );
    }

    if (needsPermission) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: () => _openAppSettings(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Grant RUN_COMMAND Permission'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyNoRootSetupCommands,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Setup Commands'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _launchTermuxApp,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.terminal),
            label: const Text('Open Termux'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConnectGatewayScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Use Remote Gateway Instead'),
          ),
        ],
      );
    }

    return Column(
      children: [
        FilledButton.icon(
          onPressed: canInstall ? _startInstallation : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: canInstall
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            foregroundColor: canInstall
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
          icon: Icon(canInstall ? Icons.download : Icons.block),
          label: Text(
            readinessReady
                ? 'Send No-Root Setup to Termux'
                : 'Resolve Issues First',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _copyNoRootSetupCommands,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: const Icon(Icons.copy),
          label: const Text('Copy Setup Commands'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _launchTermuxApp,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: const Icon(Icons.terminal),
          label: const Text('Open Termux'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConnectGatewayScreen(),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: const Icon(Icons.link),
          label: const Text('Connect to Remote Gateway Instead'),
        ),
      ],
    );
  }

  Widget _buildRequirementsCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requirements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildRequirementItem(
              Icons.storage,
              'Storage',
              '~500 MB free space',
              true,
            ),
            _buildRequirementItem(
              Icons.network_wifi,
              'Internet',
              'Required for download',
              true,
            ),
            _buildRequirementItem(
              Icons.android,
              'Android',
              'Android 7.0+ (API 24)',
              true,
            ),
            _buildRequirementItem(
              Icons.security,
              'Root Access',
              'Not required!',
              true,
              isPositive: true,
            ),
            _buildRequirementItem(
              Icons.terminal,
              'Termux Source',
              'Install Termux and Termux:API from F-Droid or GitHub Releases',
              _termuxService.isTermuxAvailable,
            ),
            _buildRequirementItem(
              Icons.admin_panel_settings_outlined,
              'App Permission',
              'Grant this app the Termux RUN_COMMAND permission',
              _hasRunCommandPermission,
            ),
            const Divider(height: 24),
            Text(
              'What will be installed:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Node.js inside Termux\n'
              '• Termux CLI package for `termux-api`\n'
              '• OpenClaw CLI and local gateway\n'
              '• Optional shared storage access via `termux-setup-storage`',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(
    IconData icon,
    String title,
    String subtitle,
    bool met, {
    bool isPositive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                met ? (isPositive ? Colors.green : Colors.blue) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: met ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel(ColorScheme colorScheme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.terminal, color: Colors.grey[400], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Installation Logs',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} entries',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Logs content
          Expanded(
            child: ListView.builder(
              controller: _logsScrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return _buildLogEntry(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(InstallLogEntry log) {
    Color levelColor;
    switch (log.level) {
      case 'error':
        levelColor = Colors.red;
        break;
      case 'warning':
        levelColor = Colors.orange;
        break;
      case 'success':
        levelColor = Colors.green;
        break;
      default:
        levelColor = Colors.blue;
    }

    final time =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: levelColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.message,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (log.details != null)
            Padding(
              padding: const EdgeInsets.only(left: 60, top: 2),
              child: Text(
                '→ ${log.details}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Installation log entry
class InstallLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? details;

  InstallLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });
}
