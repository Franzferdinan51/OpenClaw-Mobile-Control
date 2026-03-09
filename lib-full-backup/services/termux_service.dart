/// Termux Service - Execute shell commands via Termux API
/// 
/// Provides shell command execution, OpenClaw CLI integration,
/// ADB commands, and package installation capabilities.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Termux execution environment
enum TermuxEnvironment {
  termux,
  adb,
  system,
}

/// Termux Service - Shell command execution
class TermuxService {
  static TermuxService? _instance;
  static final _instanceMutex = Object();

  bool _isInitialized = false;
  bool _isTermuxAvailable = false;
  String? _termuxPath;
  
  // Progress callback for long-running operations
  void Function(String status, double progress)? onProgress;
  void Function(String line)? onOutput;
  
  // Logger callback
  void Function(String level, String message, [dynamic data])? onLog;

  factory TermuxService() {
    if (_instance == null) {
      synchronized:
      {
        if (_instance == null) {
          _instance = TermuxService._internal();
        }
      }
    }
    return _instance!;
  }

  TermuxService._internal();

  /// Initialize the Termux service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if running in Termux environment
      _isTermuxAvailable = await _checkTermuxAvailability();
      
      if (_isTermuxAvailable) {
        _termuxPath = await _findTermuxPath();
        _log('info', 'Termux available at: $_termuxPath');
      } else {
        _log('warn', 'Termux not available, using system shell');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _log('error', 'Failed to initialize Termux service', e);
      return false;
    }
  }

  /// Check if Termux is available
  Future<bool> _checkTermuxAvailability() async {
    if (!Platform.isAndroid) return false;

    final paths = [
      '/data/data/com.termux',
      '/data/data/com.termux/files/usr/bin',
    ];

    for (final path in paths) {
      if (await FileSystemEntity.isDirectory(path)) {
        return true;
      }
    }

    // Check for Termux:Tasker plugin
    try {
      final result = await Process.run('which', ['termux-setup-storage']);
      if (result.exitCode == 0) return true;
    } catch (_) {}

    return false;
  }

  /// Find the Termux installation path
  Future<String?> _findTermuxPath() async {
    final possiblePaths = [
      '/data/data/com.termux/files/usr',
      '/data/data/com.termux',
    ];

    for (final path in possiblePaths) {
      if (await FileSystemEntity.isDirectory(path)) {
        return path;
      }
    }

    return null;
  }

  /// Check if Termux is available
  bool get isTermuxAvailable => _isTermuxAvailable;

  /// Get the Termux path
  String? get termuxPath => _termuxPath;

  // ==================== Command Execution ====================

  /// Execute a shell command
  Future<CommandResult> executeCommand(
    String command, {
    List<String>? args,
    Map<String, String>? environment,
    Duration? timeout,
    String? workingDirectory,
    TermuxEnvironment environment = TermuxEnvironment.system,
  }) async {
    final startTime = DateTime.now();
    
    _log('debug', 'Executing: $command ${args?.join(' ') ?? ''}');

    try {
      final shellPath = _getShellPath(environment);
      final shellArgs = _buildShellArgs(command, args, environment);

      final process = await Process.start(
        shellPath,
        shellArgs,
        workingDirectory: workingDirectory,
        environment: {
          ...Platform.environment,
          if (_termuxPath != null) 'PATH': '$_termuxPath/bin:${Platform.environment['PATH'] ?? ''}',
          if (environment != null) ...environment,
        },
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      // Stream output
      final stdoutSubscription = process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        stdoutBuffer.write(data);
        onOutput?.call(data);
      });

      final stderrSubscription = process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        onOutput?.call(data);
      });

      // Wait for completion with optional timeout
      int exitCode;
      if (timeout != null) {
        exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          _log('warn', 'Command timed out after $timeout');
          return -1;
        });
      } else {
        exitCode = await process.exitCode;
      }

      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();

      final duration = DateTime.now().difference(startTime);
      final success = exitCode == 0;

      _log('debug', 'Command completed: exitCode=$exitCode, duration=$duration');

      return CommandResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: duration,
        success: success,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _log('error', 'Command execution failed', e);
      
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: duration,
        success: false,
      );
    }
  }

  /// Get the shell path based on environment
  String _getShellPath(TermuxEnvironment env) {
    if (env == TermuxEnvironment.termux && _termuxPath != null) {
      return '$_termuxPath/bin/sh';
    }
    return '/system/bin/sh';
  }

  /// Build shell arguments
  List<String> _buildShellArgs(String command, List<String>? args, TermuxEnvironment env) {
    final fullCommand = args != null && args.isNotEmpty
        ? '$command ${args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ')}'
        : command;
    
    return ['-c', fullCommand];
  }

  // ==================== OpenClaw CLI Commands ====================

  /// Run an OpenClaw CLI command
  Future<CommandResult> runOpenClaw(
    String command, {
    List<String>? args,
    Duration? timeout,
  }) async {
    // Find openclaw binary
    final openclawPath = await _findOpenClawBinary();
    if (openclawPath == null) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'OpenClaw CLI not found. Please install OpenClaw first.',
        duration: Duration.zero,
        success: false,
      );
    }

    final fullCommand = '$openclawPath $command';
    return executeCommand(
      fullCommand,
      args: args,
      timeout: timeout,
      environment: TermuxEnvironment.termux,
    );
  }

  /// Find the OpenClaw binary
  Future<String?> _findOpenClawBinary() async {
    final possiblePaths = [
      '/usr/local/bin/openclaw',
      '/usr/bin/openclaw',
      '${_termuxPath ?? ''}/bin/openclaw',
      '$HOME/.npm-global/bin/openclaw',
    ];

    for (final path in possiblePaths) {
      if (await FileSystemEntity.isFile(path)) {
        return path;
      }
    }

    // Try to find via which command
    try {
      final result = await executeCommand('which', args: ['openclaw']);
      if (result.success && result.stdout.isNotEmpty) {
        return result.stdout.trim();
      }
    } catch (_) {}

    return null;
  }

  /// Check if OpenClaw is installed
  Future<bool> isOpenClawInstalled() async {
    final path = await _findOpenClawBinary();
    return path != null;
  }

  /// Get OpenClaw version
  Future<String?> getOpenClawVersion() async {
    final result = await runOpenClaw('--version');
    if (result.success) {
      return result.stdout.trim();
    }
    return null;
  }

  /// Start OpenClaw gateway
  Future<CommandResult> startGateway({
    int port = 18789,
    String? configPath,
  }) async {
    final args = ['gateway', 'start', '--port', port.toString()];
    if (configPath != null) {
      args.addAll(['--config', configPath]);
    }
    return runOpenClaw('gateway', args: ['start', '--port', port.toString()]);
  }

  /// Stop OpenClaw gateway
  Future<CommandResult> stopGateway() async {
    return runOpenClaw('gateway', args: ['stop']);
  }

  /// Get gateway status
  Future<CommandResult> gatewayStatus() async {
    return runOpenClaw('gateway', args: ['status']);
  }

  // ==================== ADB Commands ====================

  /// Execute an ADB command
  Future<CommandResult> runAdb(
    String command, {
    List<String>? args,
    String? deviceId,
    Duration? timeout,
  }) async {
    final adbArgs = <String>[];
    
    if (deviceId != null) {
      adbArgs.addAll(['-s', deviceId]);
    }
    
    adbArgs.add(command);
    if (args != null) {
      adbArgs.addAll(args);
    }

    return executeCommand(
      'adb',
      args: adbArgs,
      timeout: timeout,
      environment: TermuxEnvironment.adb,
    );
  }

  /// Check if ADB is available
  Future<bool> isAdbAvailable() async {
    try {
      final result = await executeCommand('adb', args: ['version']);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// List connected ADB devices
  Future<List<AdbDevice>> listAdbDevices() async {
    final result = await runAdb('devices', args: ['-l']);
    if (!result.success) return [];

    final devices = <AdbDevice>[];
    final lines = result.stdout.split('\n');
    
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        devices.add(AdbDevice(
          id: parts[0],
          status: parts[1],
          info: parts.length > 2 ? parts.sublist(2).join(' ') : null,
        ));
      }
    }

    return devices;
  }

  /// Connect to ADB device over network
  Future<CommandResult> connectAdbDevice(String host, {int port = 5555}) async {
    return runAdb('connect', args: ['$host:$port']);
  }

  /// Disconnect from ADB device
  Future<CommandResult> disconnectAdbDevice(String host, {int port = 5555}) async {
    return runAdb('disconnect', args: ['$host:$port']);
  }

  /// Execute shell command on ADB device
  Future<CommandResult> adbShell(
    String command, {
    String? deviceId,
    List<String>? args,
  }) async {
    final shellArgs = ['shell', command];
    if (args != null) {
      shellArgs.addAll(args);
    }
    return runAdb('shell', args: [command, ...?args], deviceId: deviceId);
  }

  /// Install APK via ADB
  Future<CommandResult> installApk(
    String apkPath, {
    String? deviceId,
    bool allowDowngrade = false,
    bool grantPermissions = true,
  }) async {
    final args = ['install'];
    if (allowDowngrade) args.add('-d');
    if (grantPermissions) args.add('-g');
    args.add(apkPath);
    
    onProgress?.call('Installing APK...', 0.0);
    final result = await runAdb('install', args: args.skip(1).toList(), deviceId: deviceId);
    onProgress?.call('Installation complete', 1.0);
    
    return result;
  }

  /// Push file to ADB device
  Future<CommandResult> pushFile(
    String localPath,
    String remotePath, {
    String? deviceId,
  }) async {
    onProgress?.call('Pushing file...', 0.0);
    final result = await runAdb('push', args: [localPath, remotePath], deviceId: deviceId);
    onProgress?.call('File pushed', 1.0);
    return result;
  }

  /// Pull file from ADB device
  Future<CommandResult> pullFile(
    String remotePath,
    String localPath, {
    String? deviceId,
  }) async {
    onProgress?.call('Pulling file...', 0.0);
    final result = await runAdb('pull', args: [remotePath, localPath], deviceId: deviceId);
    onProgress?.call('File pulled', 1.0);
    return result;
  }

  // ==================== Package Installation ====================

  /// Install a package via npm
  Future<CommandResult> installNpmPackage(
    String packageName, {
    bool global = false,
    String? version,
  }) async {
    final args = ['install'];
    if (global) args.add('-g');
    
    final package = version != null ? '$packageName@$version' : packageName;
    args.add(package);

    onProgress?.call('Installing $packageName via npm...', 0.0);
    
    final result = await executeCommand(
      'npm',
      args: args,
      timeout: const Duration(minutes: 5),
      environment: TermuxEnvironment.termux,
    );

    onProgress?.call('npm install complete', 1.0);
    return result;
  }

  /// Install a package via pip
  Future<CommandResult> installPipPackage(
    String packageName, {
    String? version,
    bool user = true,
  }) async {
    final args = ['install'];
    if (user) args.add('--user');
    
    final package = version != null ? '$packageName==$version' : packageName;
    args.add(package);

    onProgress?.call('Installing $packageName via pip...', 0.0);
    
    final result = await executeCommand(
      'pip',
      args: args,
      timeout: const Duration(minutes: 5),
      environment: TermuxEnvironment.termux,
    );

    onProgress?.call('pip install complete', 1.0);
    return result;
  }

  /// Clone a git repository
  Future<CommandResult> cloneGitRepo(
    String repoUrl, {
    String? targetDir,
    String? branch,
    int depth = 1,
  }) async {
    final args = ['clone', '--depth', depth.toString()];
    if (branch != null) {
      args.addAll(['-b', branch]);
    }
    args.add(repoUrl);
    if (targetDir != null) {
      args.add(targetDir);
    }

    onProgress?.call('Cloning repository...', 0.0);
    
    final result = await executeCommand(
      'git',
      args: args,
      timeout: const Duration(minutes: 10),
      environment: TermuxEnvironment.termux,
    );

    onProgress?.call('Repository cloned', 1.0);
    return result;
  }

  /// Install OpenClaw via npm
  Future<CommandResult> installOpenClaw({String? version}) async {
    _log('info', 'Installing OpenClaw...');
    onProgress?.call('Installing OpenClaw...', 0.0);

    // First, ensure Node.js is available
    final nodeCheck = await executeCommand('node', args: ['--version']);
    if (!nodeCheck.success) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Node.js is not installed. Please install Node.js first.',
        duration: Duration.zero,
        success: false,
      );
    }

    // Install OpenClaw globally
    final result = await installNpmPackage(
      'openclaw',
      global: true,
      version: version,
    );

    if (result.success) {
      _log('info', 'OpenClaw installed successfully');
      onProgress?.call('OpenClaw installed!', 1.0);
    } else {
      _log('error', 'Failed to install OpenClaw', result.stderr);
    }

    return result;
  }

  // ==================== Permissions ====================

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final permissions = [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.accessMediaLocation,
    ];

    bool allGranted = true;
    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        allGranted = false;
        _log('warn', 'Permission denied: $permission');
      }
    }

    return allGranted;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.storage.isGranted;
  }

  /// Request storage permission via Termux setup
  Future<bool> requestTermuxStorage() async {
    if (!_isTermuxAvailable) return false;

    final result = await executeCommand('termux-setup-storage');
    return result.success;
  }

  // ==================== Helpers ====================

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[TermuxService][$level] $message ${data ?? ''}');
    }
  }

  /// Dispose resources
  void dispose() {
    _instance = null;
  }
}

/// ADB device info
class AdbDevice {
  final String id;
  final String status;
  final String? info;

  const AdbDevice({
    required this.id,
    required this.status,
    this.info,
  });

  bool get isOnline => status == 'device';
  bool get isUnauthorized => status == 'unauthorized';
  bool get isOffline => status == 'offline';

  @override
  String toString() => 'AdbDevice(id: $id, status: $status)';
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