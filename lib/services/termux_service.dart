/// Termux Service - Execute shell commands on Android via Termux
/// 
/// Provides shell command execution, OpenClaw CLI integration,
/// and node management capabilities for OpenClaw Mobile.
/// 
/// Uses dart:io Process to execute commands in Termux environment.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Command execution result
class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool success;

  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.success,
  });

  String get output => stdout.isNotEmpty ? stdout : stderr;

  @override
  String toString() => 'CommandResult(exitCode: $exitCode, success: $success)';
}

/// Termux Service - Shell command execution
class TermuxService {
  static TermuxService? _instance;
  
  bool _isInitialized = false;
  bool _isTermuxAvailable = false;
  String? _openClawVersion;
  String? _nodeStatus;
  
  // Termux paths
  String? _termuxBinPath;
  String? _termuxHomePath;

  // Progress callbacks
  void Function(String status, double progress)? onProgress;
  void Function(String line)? onOutput;

  factory TermuxService() {
    _instance ??= TermuxService._internal();
    return _instance!;
  }

  TermuxService._internal();

  /// Initialize the Termux service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if running in Termux environment
      await _checkTermuxAvailability();
      
      if (_isTermuxAvailable) {
        _findTermuxPaths();
        debugPrint('[TermuxService] Termux available at: $_termuxBinPath');
      } else {
        debugPrint('[TermuxService] Not in Termux environment');
      }

      // Check if OpenClaw is installed
      await checkOpenClawInstalled();

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[TermuxService] Failed to initialize: $e');
      return false;
    }
  }

  /// Check if running in Termux
  Future<void> _checkTermuxAvailability() async {
    if (!Platform.isAndroid) {
      _isTermuxAvailable = false;
      return;
    }

    // Check for Termux directory
    final termuxDir = Directory('/data/data/com.termux/files');
    if (await termuxDir.exists()) {
      _isTermuxAvailable = true;
    } else {
      // Also check common paths
      final altDir = Directory('/data/data/com.termux');
      _isTermuxAvailable = await altDir.exists();
    }
  }

  /// Find Termux bin and home paths
  void _findTermuxPaths() {
    _termuxBinPath = '/data/data/com.termux/files/usr/bin';
    _termuxHomePath = '/data/data/com.termux/files/home';
  }

  /// Check if Termux is available
  bool get isTermuxAvailable => _isTermuxAvailable;

  /// Get OpenClaw version
  String? get openClawVersion => _openClawVersion;

  /// Get node status
  String? get nodeStatus => _nodeStatus;

  /// Get the shell to use
  String get _shellPath {
    if (_isTermuxAvailable && _termuxBinPath != null) {
      return '$_termuxBinPath/sh';
    }
    return '/system/bin/sh';
  }

  /// Get the PATH environment
  Map<String, String> get _termuxEnv {
    if (_isTermuxAvailable && _termuxBinPath != null) {
      return {
        'PATH': '$_termuxBinPath:/data/data/com.termux/files/usr/bin:\${PATH}',
        'HOME': _termuxHomePath ?? '/data/data/com.termux/files/home',
        'TERMUX_VERSION': '1',
      };
    }
    return {};
  }

  // ==================== Command Execution ====================

  /// Execute a shell command
  Future<CommandResult> executeCommand(
    String command, {
    List<String>? args,
    Duration timeout = const Duration(seconds: 30),
    String? workingDirectory,
  }) async {
    final startTime = DateTime.now();
    
    debugPrint('[TermuxService] Executing: $command ${args?.join(' ') ?? ''}');

    try {
      final fullCommand = args != null && args.isNotEmpty
          ? '$command ${args.join(' ')}'
          : command;

      onOutput?.call('\$ $fullCommand');

      // Build process arguments
      final processArgs = ['-c', fullCommand];
      
      // Run the command
      final process = await Process.start(
        _shellPath,
        processArgs,
        workingDirectory: workingDirectory,
        environment: _termuxEnv.isNotEmpty ? _termuxEnv : null,
        runInShell: true,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      // Collect stdout
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        stdoutBuffer.write(data);
        onOutput?.call(data);
      });

      // Collect stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);
      });

      // Wait for process to complete with timeout
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } catch (e) {
        // Kill process on timeout
        process.kill(ProcessSignal.sigkill);
        exitCode = -1;
        onOutput?.call('\n[Command timed out after ${timeout.inSeconds}s]');
      }

      final duration = DateTime.now().difference(startTime);
      final success = exitCode == 0;

      debugPrint('[TermuxService] Command completed: exitCode=$exitCode, duration=$duration');

      return CommandResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: duration,
        success: success,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('[TermuxService] Command execution failed: $e');
      
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: duration,
        success: false,
      );
    }
  }

  // ==================== OpenClaw CLI Commands ====================

  /// Check if OpenClaw is installed
  Future<bool> isOpenClawInstalled() async {
    final result = await executeCommand('openclaw --version');
    if (result.success) {
      _openClawVersion = result.stdout.trim();
      return true;
    }
    return false;
  }

  /// Get OpenClaw version
  Future<String?> getOpenClawVersion() async {
    final result = await executeCommand('openclaw --version');
    if (result.success) {
      _openClawVersion = result.stdout.trim();
      return _openClawVersion;
    }
    return null;
  }

  /// Install OpenClaw via npm
  Future<CommandResult> installOpenClaw() async {
    onProgress?.call('Installing OpenClaw...', 0.0);
    
    // First check if Node.js is available
    final nodeCheck = await executeCommand('node --version');
    if (!nodeCheck.success) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Node.js is not installed. Please install Node.js first.\n\nIn Termux, run:\npkg install nodejs',
        duration: Duration.zero,
        success: false,
      );
    }

    onProgress?.call('Running npm install -g openclaw...', 0.3);
    
    final result = await executeCommand(
      'npm',
      args: ['install', '-g', 'openclaw'],
      timeout: const Duration(minutes: 5),
    );

    if (result.success) {
      onProgress?.call('OpenClaw installed!', 1.0);
      await isOpenClawInstalled(); // Update version
    } else {
      onProgress?.call('Installation failed', 1.0);
    }

    return result;
  }

  /// Update OpenClaw
  Future<CommandResult> updateOpenClaw() async {
    onProgress?.call('Updating OpenClaw...', 0.0);
    
    final result = await executeCommand(
      'npm',
      args: ['install', '-g', 'openclaw@latest'],
      timeout: const Duration(minutes: 5),
    );

    if (result.success) {
      onProgress?.call('OpenClaw updated!', 1.0);
      await isOpenClawInstalled();
    }

    return result;
  }

  // ==================== Gateway Commands ====================

  /// Get gateway status
  Future<CommandResult> getGatewayStatus() async {
    return executeCommand('openclaw status');
  }

  /// Restart gateway
  Future<CommandResult> restartGateway() async {
    onProgress?.call('Restarting gateway...', 0.5);
    return executeCommand('openclaw gateway restart');
  }

  // ==================== Node Commands ====================

  /// Get node status
  Future<CommandResult> getNodeStatus() async {
    final result = await executeCommand('openclaw nodes status');
    if (result.success) {
      _nodeStatus = result.stdout;
    }
    return result;
  }

  /// Start node service
  Future<CommandResult> startNode() async {
    onProgress?.call('Starting node...', 0.5);
    return executeCommand('openclaw node start');
  }

  /// Stop node service
  Future<CommandResult> stopNode() async {
    onProgress?.call('Stopping node...', 0.5);
    return executeCommand('openclaw node stop');
  }

  /// Setup node
  Future<CommandResult> setupNode() async {
    onProgress?.call('Setting up node...', 0.0);
    return executeCommand('openclaw node setup');
  }

  // ==================== Agent Commands ====================

  /// Send agent message
  Future<CommandResult> sendAgentMessage(String message) async {
    return executeCommand(
      'openclaw',
      args: ['agent', '--message', message],
      timeout: const Duration(minutes: 2),
    );
  }

  // ==================== Quick Commands ====================

  /// Run a quick OpenClaw command
  Future<CommandResult> runQuickCommand(String command) async {
    return executeCommand(command, timeout: const Duration(seconds: 60));
  }

  // ==================== Helpers ====================

  /// Check if OpenClaw is installed (alias)
  Future<bool> checkOpenClawInstalled() async {
    return isOpenClawInstalled();
  }

  /// Get setup instructions for Termux
  static String getSetupInstructions() {
    return '''
📱 Termux Setup Instructions:

1. Download Termux from F-Droid:
   https://f-droid.org/packages/com.termux/

2. Open Termux and run:
   pkg update
   pkg install nodejs
   pkg install git

3. Install OpenClaw:
   npm install -g openclaw

4. Start OpenClaw:
   openclaw gateway start

5. Return to this app and configure the gateway URL.
''';
  }

  /// Dispose resources
  void dispose() {
    _instance = null;
  }
}

/// Termux exception
class TermuxException implements Exception {
  final String message;
  final int? exitCode;
  final String? stderr;

  const TermuxException({
    required this.message,
    this.exitCode,
    this.stderr,
  });

  @override
  String toString() => 'TermuxException: $message';
}