import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/termux_service.dart';

/// A reusable terminal widget that can be embedded in any screen
class TerminalWidget extends StatefulWidget {
  final double? height;
  final bool showQuickActions;
  final bool autoScroll;
  final void Function(String command)? onCommandExecuted;
  final void Function(CommandResult result)? onResultReceived;

  const TerminalWidget({
    super.key,
    this.height,
    this.showQuickActions = true,
    this.autoScroll = true,
    this.onCommandExecuted,
    this.onResultReceived,
  });

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final TermuxService _service = TermuxService();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_TerminalLine> _lines = [];

  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _service.onOutput = (line) {
      _addLine(_TerminalLine(line, type: _LineType.output));
    };

    final initialized = await _service.initialize();
    setState(() {
      _isInitialized = initialized;
    });

    if (initialized) {
      _addLine(_TerminalLine(
        'Terminal ready. Type commands below.',
        type: _LineType.system,
      ));
    } else {
      _addLine(_TerminalLine(
        'Terminal not available. Install Termux from F-Droid.',
        type: _LineType.error,
      ));
    }
  }

  void _addLine(_TerminalLine line) {
    setState(() {
      _lines.add(line);
    });

    if (widget.autoScroll) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _commandController.clear();

    _addLine(_TerminalLine('\$ $command', type: _LineType.command));
    setState(() => _isLoading = true);

    widget.onCommandExecuted?.call(command);

    final result = await _service.executeCommand(command, useProot: true);

    setState(() => _isLoading = false);

    if (result.stdout.isNotEmpty) {
      _addLine(_TerminalLine(result.stdout, type: _LineType.output));
    }
    if (result.stderr.isNotEmpty) {
      _addLine(_TerminalLine(result.stderr, type: _LineType.error));
    }

    _addLine(_TerminalLine(
      '[${result.success ? "✓" : "✗"}] Exit: ${result.exitCode} | Time: ${result.duration.inMilliseconds}ms',
      type: result.success ? _LineType.success : _LineType.error,
    ));

    widget.onResultReceived?.call(result);
  }

  Future<void> _runQuickCommand(String command, {String? label}) async {
    if (label != null) {
      _addLine(_TerminalLine(label, type: _LineType.system));
    }
    _addLine(_TerminalLine('\$ $command', type: _LineType.command));
    setState(() => _isLoading = true);

    final result = await _service.executeCommand(command, useProot: true);

    setState(() => _isLoading = false);

    if (result.stdout.isNotEmpty) {
      _addLine(_TerminalLine(result.stdout, type: _LineType.output));
    }
    if (result.stderr.isNotEmpty) {
      _addLine(_TerminalLine(result.stderr, type: _LineType.error));
    }
  }

  void _copyAll() {
    final text = _lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to clipboard');
  }

  void _clear() {
    setState(() {
      _lines.clear();
    });
    _addLine(_TerminalLine('Terminal cleared', type: _LineType.system));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with actions
        _buildHeader(),

        // Quick actions
        if (widget.showQuickActions) _buildQuickActions(),

        // Terminal output
        Expanded(
          child: Container(
            height: widget.height,
            color: const Color(0xFF0D1117),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (context, index) => _buildLine(_lines[index]),
            ),
          ),
        ),

        // Command input
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
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
          Icon(
            Icons.terminal,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Terminal',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy all',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 18),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _quickAction('ls', 'List files'),
            _quickAction('pwd', 'Current dir'),
            _quickAction('whoami', 'User'),
            _quickAction('openclaw status', 'Status'),
            _quickAction('openclaw doctor', 'Doctor'),
            _quickAction('node --version', 'Node version'),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String command, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        onPressed: () => _runQuickCommand(command, label: label),
      ),
    );
  }

  Widget _buildLine(_TerminalLine line) {
    Color color;
    FontWeight? weight;

    switch (line.type) {
      case _LineType.command:
        color = Colors.cyanAccent;
        weight = FontWeight.w500;
        break;
      case _LineType.output:
        color = Colors.white;
        break;
      case _LineType.error:
        color = Colors.redAccent;
        break;
      case _LineType.success:
        color = Colors.greenAccent;
        break;
      case _LineType.system:
        color = Colors.grey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        line.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
          fontWeight: weight,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildInput() {
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
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onSubmitted: (_) => _executeCommand(),
              enabled: !_isLoading && _isInitialized,
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
              icon: const Icon(Icons.send, color: Colors.cyan),
              onPressed: _isInitialized ? _executeCommand : null,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

enum _LineType {
  command,
  output,
  error,
  success,
  system,
}

class _TerminalLine {
  final String text;
  final _LineType type;
  final DateTime timestamp;

  _TerminalLine(this.text, {required this.type, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}
