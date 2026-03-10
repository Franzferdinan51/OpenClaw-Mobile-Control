import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/nodejs_installer_service.dart';
import '../services/gateway_service.dart';
import 'connect_gateway_screen.dart';

/// Local OpenClaw Installer Screen
/// 
/// Guides users through installing OpenClaw locally on their Android device
/// using Termux or a bundled Node.js runtime. No root required.
class LocalInstallerScreen extends StatefulWidget {
  final Function()? onInstallationComplete;

  const LocalInstallerScreen({super.key, this.onInstallationComplete});

  @override
  State<LocalInstallerScreen> createState() => _LocalInstallerScreenState();
}

class _LocalInstallerScreenState extends State<LocalInstallerScreen>
    with TickerProviderStateMixin {
  final NodejsInstallerService _installerService = NodejsInstallerService();
  
  // Installation state
  InstallationState _state = InstallationState.idle;
  InstallationStep _currentStep = InstallationStep.checkingPrerequisites;
  double _progress = 0.0;
  String _statusMessage = 'Ready to install OpenClaw';
  String? _errorMessage;
  List<InstallLogEntry> _logs = [];
  
  // Controllers
  final ScrollController _logsScrollController = ScrollController();
  late AnimationController _pulseController;
  
  // Gateway info after installation
  String? _gatewayUrl;
  bool _gatewayRunning = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _setupListeners();
  }

  void _setupListeners() {
    _installerService.onProgress = (step, progress, message) {
      if (mounted) {
        setState(() {
          _currentStep = step;
          _progress = progress;
          _statusMessage = message;
        });
      }
    };

    _installerService.onLog = (level, message, [details]) {
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
    };

    _installerService.onStateChange = (state) {
      if (mounted) {
        setState(() {
          _state = state;
          if (state == InstallationState.error) {
            _errorMessage = _installerService.lastError;
          }
        });
      }
    };
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

  Future<void> _startInstallation() async {
    setState(() {
      _state = InstallationState.installingNodejs;
      _errorMessage = null;
      _logs.clear();
    });

    final success = await _installerService.installOpenClaw();

    if (success && mounted) {
      setState(() {
        _gatewayUrl = 'http://127.0.0.1:18789';
        _gatewayRunning = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ OpenClaw installed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _startGateway() async {
    setState(() {
      _state = InstallationState.startingGateway;
    });

    final success = await _installerService.startGateway();

    if (mounted) {
      setState(() {
        _gatewayRunning = success;
        _state = success ? InstallationState.completed : InstallationState.error;
        if (!success) {
          _errorMessage = 'Failed to start gateway. Check logs for details.';
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Gateway started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (_gatewayUrl == null) return;

    setState(() {
      _statusMessage = 'Testing connection...';
    });

    final gatewayService = GatewayService(baseUrl: _gatewayUrl!);
    final result = await gatewayService.checkConnection();

    if (mounted) {
      final success = result['success'] == true;
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
                  'If using Termux, ensure it\'s from F-Droid, not Play Store',
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
                  'If automatic install fails, you can manually install:',
                  '1. Install Termux from F-Droid',
                  '2. Run: pkg update && pkg install -y nodejs',
                  '3. Run: npm install -g openclaw',
                  '4. Run: openclaw onboarding (select Loopback)',
                  '5. Run: openclaw gateway start',
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
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
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
    _installerService.dispose();
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
                  
                  // Progress indicator
                  if (_state != InstallationState.idle && 
                      _state != InstallationState.completed)
                    _buildProgressCard(colorScheme),
                  
                  if (_state != InstallationState.idle && 
                      _state != InstallationState.completed)
                    const SizedBox(height: 24),
                  
                  // Error card
                  if (_errorMessage != null)
                    _buildErrorCard(colorScheme),
                  
                  if (_errorMessage != null)
                    const SizedBox(height: 24),
                  
                  // Success card
                  if (_state == InstallationState.completed || _gatewayRunning)
                    _buildSuccessCard(colorScheme),
                  
                  if (_state == InstallationState.completed || _gatewayRunning)
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
          if (_logs.isNotEmpty)
            _buildLogsPanel(colorScheme),
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
                        colorScheme.primary.withOpacity(0.3 + (_pulseController.value * 0.3)),
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
              'Run OpenClaw AI Gateway directly on your Android device. '
              'No root access required!',
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
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Installation Complete!',
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
            if (_gatewayUrl != null)
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
                            _gatewayUrl!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _gatewayUrl!));
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
                          _gatewayRunning ? 'Gateway Running' : 'Gateway Stopped',
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
    // Show different buttons based on state
    if (_state == InstallationState.idle) {
      return FilledButton.icon(
        onPressed: _startInstallation,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        icon: const Icon(Icons.download),
        label: const Text(
          'Start Installation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

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

    if (_state == InstallationState.error) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: _startInstallation,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.orange,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Installation'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyLogs,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Error Logs'),
          ),
        ],
      );
    }

    if (_state == InstallationState.completed || _gatewayRunning) {
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
              label: const Text('Start Gateway'),
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
              label: const Text('Connect to Gateway'),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
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
            const Divider(height: 24),
            Text(
              'What will be installed:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Node.js 20+ (JavaScript runtime)\n'
              '• OpenClaw CLI (AI Gateway)\n'
              '• Required npm packages',
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
            color: met ? (isPositive ? Colors.green : Colors.blue) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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

    final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

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
