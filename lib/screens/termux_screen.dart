import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/termux_service.dart';

class TermuxScreen extends StatefulWidget {
  const TermuxScreen({super.key});

  @override
  State<TermuxScreen> createState() => _TermuxScreenState();
}

class _TermuxScreenState extends State<TermuxScreen> {
  final TermuxService _service = TermuxService();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();
  final List<_OutputLine> _output = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isTermuxAvailable = false;
  bool _isProotAvailable = false;
  bool _isUbuntuInstalled = false;
  bool _isSetupComplete = false;
  String? _openClawVersion;
  String? _nodeVersion;
  bool _isGatewayRunning = false;
  double _setupProgress = 0.0;
  String _setupStatus = '';
  bool _isSetupRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _output.add(_OutputLine('Initializing Termux service...', isSystem: true));
    });

    // Set up progress callback
    _service.onSetupProgress = (progress) {
      setState(() {
        _setupProgress = progress.progress;
        _setupStatus = progress.message;
        if (progress.isError) {
          _output.add(_OutputLine('✗ ${progress.message}', isSystem: true, isError: true));
        } else if (progress.isComplete) {
          _output.add(_OutputLine('✓ ${progress.message}', isSystem: true, isSuccess: true));
        } else {
          _output.add(_OutputLine('⏳ ${progress.message}', isSystem: true));
        }
      });
      _scrollToBottom();
    };

    _service.onOutput = (line) {
      setState(() {
        _output.add(_OutputLine(line, isSystem: true));
      });
      _scrollToBottom();
    };

    final initialized = await _service.initialize();

    setState(() {
      _isInitialized = initialized;
      _isTermuxAvailable = _service.isTermuxAvailable;
      _isProotAvailable = _service.isProotAvailable;
      _isUbuntuInstalled = _service.isUbuntuInstalled;
      _isSetupComplete = _service.isSetupComplete;

      if (_isTermuxAvailable) {
        _output.add(_OutputLine('✓ Termux environment detected', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('⚠ Termux not available', isSystem: true, isWarning: true));
        _output.add(_OutputLine('   Install Termux from F-Droid:', isSystem: true));
        _output.add(_OutputLine('   https://f-droid.org/packages/com.termux/', isSystem: true));
      }

      if (_isProotAvailable) {
        _output.add(_OutputLine('✓ proot-distro available', isSystem: true, isSuccess: true));
      }

      if (_isUbuntuInstalled) {
        _output.add(_OutputLine('✓ Ubuntu installed', isSystem: true, isSuccess: true));
      }
    });

    // Check OpenClaw installation
    if (_isSetupComplete) {
      await _checkOpenClawStatus();
    }

    _addSeparator();
  }

  Future<void> _checkOpenClawStatus() async {
    final isInstalled = await _service.checkOpenClawInstalled();
    setState(() {
      _openClawVersion = _service.openClawVersion;
      if (isInstalled) {
        _output.add(_OutputLine('✓ OpenClaw $_openClawVersion installed', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('⚠ OpenClaw not installed', isSystem: true, isWarning: true));
      }
    });

    // Check if gateway is running
    final isRunning = await _service.isGatewayRunning();
    setState(() {
      _isGatewayRunning = isRunning;
      if (isRunning) {
        _output.add(_OutputLine('✓ Gateway is running', isSystem: true, isSuccess: true));
      }
    });
  }

  void _addSeparator() {
    setState(() {
      _output.add(_OutputLine('─' * 40, isSystem: true));
    });
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

  Future<void> _runSetup() async {
    if (_isSetupRunning) return;

    setState(() {
      _isSetupRunning = true;
      _isLoading = true;
      _output.add(_OutputLine('Starting setup...', isSystem: true));
    });

    final success = await _service.runSetup();

    setState(() {
      _isSetupRunning = false;
      _isLoading = false;
      _isSetupComplete = _service.isSetupComplete;
      _openClawVersion = _service.openClawVersion;
      _nodeVersion = _service.nodeVersion;

      if (success) {
        _output.add(_OutputLine('✓ Setup completed successfully!', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('✗ Setup failed', isSystem: true, isError: true));
      }
    });

    _addSeparator();
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _output.add(_OutputLine('\$ $command', isCommand: true));
      _commandController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    final result = await _service.executeCommand(command, useProot: true);

    setState(() {
      _isLoading = false;
      if (result.stdout.isNotEmpty) {
        _output.add(_OutputLine(result.stdout));
      }
      if (result.stderr.isNotEmpty) {
        _output.add(_OutputLine(result.stderr, isError: true));
      }
      _output.add(_OutputLine(
        '[Exit code: ${result.exitCode}, ${result.duration.inMilliseconds}ms]',
        isSystem: true,
        isSuccess: result.success,
        isError: !result.success,
      ));
    });

    _scrollToBottom();
  }

  Future<void> _installOpenClaw() async {
    setState(() {
      _output.add(_OutputLine('Installing OpenClaw...', isSystem: true));
      _isLoading = true;
    });

    final result = await _service.installOpenClaw();

    setState(() {
      _isLoading = false;
      _openClawVersion = _service.openClawVersion;
      if (result.success) {
        _output.add(_OutputLine('✓ OpenClaw installed successfully!', isSystem: true, isSuccess: true));
        _output.add(_OutputLine('Version: $_openClawVersion', isSystem: true));
      } else {
        _output.add(_OutputLine('✗ Installation failed: ${result.stderr}', isSystem: true, isError: true));
      }
    });
  }

  Future<void> _updateOpenClaw() async {
    setState(() {
      _output.add(_OutputLine('Updating OpenClaw...', isSystem: true));
      _isLoading = true;
    });

    final result = await _service.updateOpenClaw();

    setState(() {
      _isLoading = false;
      _openClawVersion = _service.openClawVersion;
      if (result.success) {
        _output.add(_OutputLine('✓ OpenClaw updated!', isSystem: true, isSuccess: true));
        _output.add(_OutputLine('New version: $_openClawVersion', isSystem: true));
      } else {
        _output.add(_OutputLine('✗ Update failed: ${result.stderr}', isSystem: true, isError: true));
      }
    });
  }

  Future<void> _startGateway() async {
    setState(() {
      _output.add(_OutputLine('Starting OpenClaw gateway...', isSystem: true));
      _isLoading = true;
    });

    final result = await _service.startGateway();

    setState(() {
      _isLoading = false;
      if (result.success) {
        _isGatewayRunning = true;
        _output.add(_OutputLine('✓ Gateway started!', isSystem: true, isSuccess: true));
        _output.add(_OutputLine('Access at: http://localhost:18789', isSystem: true));
      } else {
        _output.add(_OutputLine('✗ Failed to start gateway: ${result.stderr}', isSystem: true, isError: true));
      }
    });
  }

  Future<void> _stopGateway() async {
    setState(() {
      _output.add(_OutputLine('Stopping OpenClaw gateway...', isSystem: true));
      _isLoading = true;
    });

    final result = await _service.stopGateway();

    setState(() {
      _isLoading = false;
      _isGatewayRunning = false;
      if (result.success) {
        _output.add(_OutputLine('✓ Gateway stopped', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('Gateway stop result: ${result.stderr}', isSystem: true, isWarning: true));
      }
    });
  }

  Future<void> _runQuickCommand(String label, String command) async {
    setState(() {
      _output.add(_OutputLine('Running: $label', isSystem: true));
      _output.add(_OutputLine('\$ $command', isCommand: true));
      _isLoading = true;
    });

    _scrollToBottom();

    final result = await _service.runQuickCommand(command);

    setState(() {
      _isLoading = false;
      if (result.stdout.isNotEmpty) {
        _output.add(_OutputLine(result.stdout));
      }
      if (result.stderr.isNotEmpty) {
        _output.add(_OutputLine(result.stderr, isError: true));
      }
    });

    _scrollToBottom();
  }

  void _copyOutput() {
    final allOutput = _output.map((line) => line.text).join('\n');
    Clipboard.setData(ClipboardData(text: allOutput));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Output copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearOutput() {
    setState(() {
      _output.clear();
      _output.add(_OutputLine('Console cleared', isSystem: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux Console'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy output',
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
          // Status bar
          _buildStatusBar(),

          // Setup progress indicator
          if (_isSetupRunning) _buildSetupProgress(),

          // Quick actions bar
          _buildQuickActionsBar(),

          // Terminal output
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

          // Command input
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
      child: Row(
        children: [
          // Termux status
          _statusChip(
            'Termux',
            _isTermuxAvailable ? Icons.check_circle : Icons.error,
            _isTermuxAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),

          // Ubuntu status
          _statusChip(
            'Ubuntu',
            _isUbuntuInstalled ? Icons.check_circle : Icons.pending,
            _isUbuntuInstalled ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),

          // OpenClaw status
          _statusChip(
            _openClawVersion ?? 'OpenClaw',
            _openClawVersion != null ? Icons.check_circle : Icons.download,
            _openClawVersion != null ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),

          // Gateway status
          _statusChip(
            _isGatewayRunning ? 'Running' : 'Stopped',
            _isGatewayRunning ? Icons.play_circle : Icons.stop_circle,
            _isGatewayRunning ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildSetupProgress() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _setupStatus,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _setupProgress,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          const SizedBox(height: 4),
          Text(
            '${(_setupProgress * 100).toInt()}%',
            style: const TextStyle(fontSize: 10),
          ),
        ],
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
            // Setup button (if not complete)
            if (!_isSetupComplete && !_isSetupRunning)
              _quickActionBtn(
                'Setup',
                Icons.build,
                _runSetup,
                isPrimary: true,
              ),

            // Install/Update OpenClaw
            if (_isSetupComplete && _openClawVersion == null)
              _quickActionBtn(
                'Install',
                Icons.download,
                _installOpenClaw,
              ),

            if (_isSetupComplete && _openClawVersion != null)
              _quickActionBtn(
                'Update',
                Icons.system_update,
                _updateOpenClaw,
              ),

            const SizedBox(width: 8),

            // Gateway controls
            if (_isSetupComplete && _openClawVersion != null)
              _isGatewayRunning
                  ? _quickActionBtn(
                      'Stop Gateway',
                      Icons.stop,
                      _stopGateway,
                      color: Colors.red,
                    )
                  : _quickActionBtn(
                      'Start Gateway',
                      Icons.play_arrow,
                      _startGateway,
                      color: Colors.green,
                    ),

            const SizedBox(width: 8),

            // OpenClaw commands
            if (_isSetupComplete && _openClawVersion != null) ...[
              _quickActionBtn(
                'Status',
                Icons.info_outline,
                () => _runQuickCommand('Gateway Status', 'status'),
              ),
              _quickActionBtn(
                'Doctor',
                Icons.medical_services,
                () => _runQuickCommand('Doctor', 'doctor'),
              ),
              _quickActionBtn(
                'Nodes',
                Icons.hub,
                () => _runQuickCommand('Node Status', 'nodes status'),
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
    Color? color,
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
              avatar: Icon(icon, size: 14, color: color),
              label: Text(label, style: const TextStyle(fontSize: 11)),
              onPressed: onPressed ?? () {},
              backgroundColor: onPressed == null ? Colors.grey.withOpacity(0.3) : null,
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
            '\$ ',
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
              decoration: const InputDecoration(
                hintText: 'Enter command...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onSubmitted: (_) => _executeCommand(),
              enabled: !_isLoading && _isSetupComplete,
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isSetupComplete ? _executeCommand : null,
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
    _service.dispose();
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
