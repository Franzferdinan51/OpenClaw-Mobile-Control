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
  bool _isTermuxAvailable = false;
  String? _openClawVersion;
  bool _showKeyboard = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _output.add(_OutputLine('Initializing Termux service...', isSystem: true));
    });

    final initialized = await _service.initialize();
    
    setState(() {
      _isTermuxAvailable = _service.isTermuxAvailable;
      if (_isTermuxAvailable) {
        _output.add(_OutputLine('✓ Termux:API is available', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('⚠ Termux not available - using shell fallback', isSystem: true, isWarning: true));
      }
    });

    // Check OpenClaw installation
    final isInstalled = await _service.checkOpenClawInstalled();
    setState(() {
      _openClawVersion = _service.openClawVersion;
      if (isInstalled) {
        _output.add(_OutputLine('✓ OpenClaw $_openClawVersion installed', isSystem: true, isSuccess: true));
      } else {
        _output.add(_OutputLine('⚠ OpenClaw not installed', isSystem: true, isWarning: true));
      }
    });

    _addSeparator();
  }

  void _addSeparator() {
    setState(() {
      _output.add(_OutputLine('─' * 40, isSystem: true));
    });
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _output.add(_OutputLine('\$ $command', isCommand: true));
      _commandController.clear();
      _isLoading = true;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    final result = await _service.executeCommand(command);

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

    // Scroll to bottom after result
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

  Future<void> _runQuickCommand(String label, String command) async {
    setState(() {
      _output.add(_OutputLine('Running: $label', isSystem: true));
      _output.add(_OutputLine('\$ $command', isCommand: true));
      _isLoading = true;
    });

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

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // OpenClaw status chip
            Chip(
              avatar: Icon(
                _openClawVersion != null ? Icons.check_circle : Icons.warning,
                size: 16,
                color: _openClawVersion != null ? Colors.green : Colors.orange,
              ),
              label: Text(
                _openClawVersion ?? 'Not installed',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            
            // Action buttons
            _quickActionBtn(
              'Install',
              Icons.download,
              _openClawVersion == null ? _installOpenClaw : null,
            ),
            _quickActionBtn(
              'Update',
              Icons.system_update,
              _openClawVersion != null ? _updateOpenClaw : null,
            ),
            const SizedBox(width: 4),
            
            // OpenClaw commands
            _quickActionBtn(
              'Status',
              Icons.info_outline,
              () => _runQuickCommand('Gateway Status', 'openclaw status'),
            ),
            _quickActionBtn(
              'Restart',
              Icons.refresh,
              () => _runQuickCommand('Restart Gateway', 'openclaw gateway restart'),
            ),
            _quickActionBtn(
              'Nodes',
              Icons.hub,
              () => _runQuickCommand('Node Status', 'openclaw nodes status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionBtn(String label, IconData icon, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        avatar: Icon(icon, size: 14),
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
              enabled: !_isLoading,
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
              onPressed: _executeCommand,
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