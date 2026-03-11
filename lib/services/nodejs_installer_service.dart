import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/android_package_detector.dart';
import 'termux_service.dart';

/// Installation states
enum InstallationState {
  idle,
  checkingPrerequisites,
  installing,
  installingNodejs,
  installingOpenClaw,
  configuringEnvironment,
  startingGateway,
  completed,
  error,
}

/// Installation steps for progress tracking
enum InstallationStep {
  checkingPrerequisites('Checking Prerequisites'),
  installingNodejs('Installing Node.js'),
  installingOpenClaw('Installing OpenClaw'),
  configuringEnvironment('Configuring Environment'),
  startingGateway('Starting Gateway'),
  completed('Installation Complete');

  final String displayName;
  const InstallationStep(this.displayName);
}

/// Node.js Installer Service
/// 
/// Handles the installation of Node.js and OpenClaw on Android devices
/// without requiring root access. Supports multiple installation methods:
/// 1. Termux (preferred) - Uses Termux's package manager
/// 2. Bundled Node.js - Uses a bundled Node.js binary
/// 3. Proot - Sets up a proot environment (like openclaw-termux)
class NodejsInstallerService {
  static NodejsInstallerService? _instance;
  
  // Installation paths
  String? _appDir;
  String? _nodeDir;
  String? _openclawDir;
  
  // State
  InstallationState _state = InstallationState.idle;
  String? _lastError;
  
  // Callbacks
  void Function(InstallationStep step, double progress, String message)? onProgress;
  void Function(String level, String message, [String? details])? onLog;
  void Function(InstallationState state)? onStateChange;

  // Process references for cleanup
  Process? _currentProcess;

  factory NodejsInstallerService() {
    _instance ??= NodejsInstallerService._internal();
    return _instance!;
  }

  NodejsInstallerService._internal();

  // Getters
  InstallationState get state => _state;
  String? get lastError => _lastError;
  bool get isInstalling => _state == InstallationState.installingNodejs ||
                           _state == InstallationState.installingOpenClaw ||
                           _state == InstallationState.configuringEnvironment;

  /// Initialize directories
  Future<void> _initDirectories() async {
    final appDir = await getApplicationSupportDirectory();
    _appDir = appDir.path;
    _nodeDir = '$_appDir/nodejs';
    _openclawDir = '$_appDir/openclaw';
    
    _log('debug', 'Initialized directories', 'App: $_appDir, Node: $_nodeDir, OpenClaw: $_openclawDir');
  }

  /// Get installation readiness summary
  Future<TermuxReadinessSummary> getReadinessSummary() async {
    return await TermuxPrerequisiteChecker.getReadinessSummary();
  }

  /// Main installation entry point
  Future<bool> installOpenClaw() async {
    try {
      _setState(InstallationState.checkingPrerequisites);
      _updateProgress(InstallationStep.checkingPrerequisites, 0.0, 'Running comprehensive prerequisite check...');
      
      await _initDirectories();
      
      // Use comprehensive prerequisite checker
      _updateProgress(InstallationStep.checkingPrerequisites, 0.1, 'Checking all prerequisites...');
      final readiness = await TermuxPrerequisiteChecker.getReadinessSummary();
      
      // Log readiness status
      _log('info', 'Installation readiness: ${readiness.readinessText}');
      _log('info', 'Passed ${readiness.passedChecks}/${readiness.totalChecks} checks');
      
      // Check for blocking issues
      if (readiness.blockingIssues.isNotEmpty) {
        final issues = readiness.blockingIssues.map((i) => '${i.name}: ${i.actionRequired}').join('\n');
        _setError('Installation blocked:\n$issues');
        _updateProgress(InstallationStep.checkingPrerequisites, 1.0, 'Prerequisites not met');
        return false;
      }
      
      // Log recommendations
      if (readiness.recommendations.isNotEmpty) {
        final recs = readiness.recommendations.map((r) => '• ${r.name}: ${r.actionRequired}').join('\n');
        _log('info', 'Recommendations:\n$recs');
      }
      
      _updateProgress(InstallationStep.checkingPrerequisites, 0.5, 'Checking existing Node.js...');
      final nodeInstalled = await _isNodeInstalled();
      
      // Get Termux info
      final termuxService = TermuxService();
      await termuxService.initialize();
      final termuxInfo = termuxService.getTermuxInfo();
      _log('info', 'Termux: ${termuxInfo['isInstalled']} (version: ${termuxInfo['version']})');
      _log('info', 'Termux:API: ${termuxInfo['isApiInstalled']}');
      
      _updateProgress(InstallationStep.checkingPrerequisites, 1.0, 'Prerequisites check complete ✅');
      
      // Install Node.js if needed
      if (!nodeInstalled) {
        _setState(InstallationState.installingNodejs);
        _updateProgress(InstallationStep.installingNodejs, 0.0, 'Starting Node.js installation...');
        
        if (termuxService.isTermuxAvailable) {
          if (!await _installNodeViaTermux()) {
            _setError('Failed to install Node.js via Termux');
            return false;
          }
        } else {
          // Try bundled Node.js or proot method
          if (!await _installBundledNodejs()) {
            _setError('Failed to install Node.js. Please install Termux from F-Droid.');
            return false;
          }
        }
      } else {
        _log('info', 'Node.js already installed, skipping...');
        _updateProgress(InstallationStep.installingNodejs, 1.0, 'Node.js already installed ✅');
      }
      
      // Install OpenClaw
      _setState(InstallationState.installingOpenClaw);
      _updateProgress(InstallationStep.installingOpenClaw, 0.0, 'Installing OpenClaw...');
      
      if (!await _installOpenClawPackage()) {
        _setError('Failed to install OpenClaw package');
        return false;
      }
      
      // Configure environment
      _setState(InstallationState.configuringEnvironment);
      _updateProgress(InstallationStep.configuringEnvironment, 0.0, 'Configuring environment...');
      
      if (!await _configureEnvironment()) {
        _setError('Failed to configure environment');
        return false;
      }
      
      // Save installation state
      await _saveInstallationState();
      
      _setState(InstallationState.completed);
      _updateProgress(InstallationStep.completed, 1.0, 'Installation complete! 🎉');
      _log('success', 'OpenClaw installed successfully!');
      
      return true;
    } catch (e, stackTrace) {
      _setError('Installation failed: $e');
      _log('error', 'Installation exception', '$e\n$stackTrace');
      return false;
    }
  }

  /// Start the OpenClaw gateway
  Future<bool> startGateway() async {
    try {
      _setState(InstallationState.startingGateway);
      _updateProgress(InstallationStep.startingGateway, 0.0, 'Starting gateway...');
      
      // Check if already running
      _updateProgress(InstallationStep.startingGateway, 0.2, 'Checking if gateway is already running...');
      if (await _isGatewayRunning()) {
        _log('info', 'Gateway already running');
        _setState(InstallationState.completed);
        return true;
      }
      
      // Start gateway
      _updateProgress(InstallationStep.startingGateway, 0.4, 'Launching gateway process...');
      
      final openclawPath = await _findOpenClawBinary();
      if (openclawPath == null) {
        _setError('OpenClaw binary not found');
        return false;
      }
      
      _log('info', 'Starting gateway using: $openclawPath');
      
      // Start gateway in background
      final process = await Process.start(
        openclawPath,
        ['gateway', 'start', '--port', '18789'],
        environment: await _getEnvironment(),
      );
      
      _currentProcess = process;
      
      // Log output
      process.stdout.transform(utf8.decoder).listen((data) {
        _log('debug', 'Gateway stdout', data.trim());
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        _log('warning', 'Gateway stderr', data.trim());
      });
      
      // Wait for gateway to be ready
      _updateProgress(InstallationStep.startingGateway, 0.6, 'Waiting for gateway to be ready...');
      
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (await _isGatewayRunning()) {
          _updateProgress(InstallationStep.startingGateway, 1.0, 'Gateway is running!');
          _log('success', 'Gateway started successfully on port 18789');
          _setState(InstallationState.completed);
          return true;
        }
        
        _updateProgress(InstallationStep.startingGateway, 0.6 + (i / 30) * 0.4, 
          'Waiting for gateway... (${i + 1}s)');
      }
      
      _setError('Gateway failed to start within timeout');
      return false;
    } catch (e, stackTrace) {
      _setError('Failed to start gateway: $e');
      _log('error', 'Gateway start exception', '$e\n$stackTrace');
      return false;
    }
  }

  /// Stop the gateway
  Future<bool> stopGateway() async {
    try {
      final openclawPath = await _findOpenClawBinary();
      if (openclawPath == null) return false;
      
      final result = await Process.run(
        openclawPath,
        ['gateway', 'stop'],
        environment: await _getEnvironment(),
      );
      
      return result.exitCode == 0;
    } catch (e) {
      _log('error', 'Failed to stop gateway', e.toString());
      return false;
    }
  }

  /// Check if gateway is running
  Future<bool> _isGatewayRunning() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:18789/api/mobile/status'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check if Node.js is already installed
  Future<bool> _isNodeInstalled() async {
    try {
      final result = await Process.run('which', ['node']);
      if (result.exitCode == 0) {
        // Check version
        final versionResult = await Process.run('node', ['--version']);
        if (versionResult.exitCode == 0) {
          final version = versionResult.stdout.toString().trim();
          _log('info', 'Found Node.js: $version');
          
          // Parse version number
          final versionMatch = RegExp(r'v(\d+)').firstMatch(version);
          if (versionMatch != null) {
            final majorVersion = int.parse(versionMatch.group(1)!);
            return majorVersion >= 18;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Install Node.js via Termux
  Future<bool> _installNodeViaTermux() async {
    try {
      _updateProgress(InstallationStep.installingNodejs, 0.1, 'Updating Termux packages...');
      
      var result = await _runCommand('pkg', ['update', '-y'], 
        timeout: const Duration(minutes: 2));
      if (!result.success) {
        _log('warning', 'pkg update failed, continuing anyway', result.stderr);
      }
      
      _updateProgress(InstallationStep.installingNodejs, 0.3, 'Installing Node.js...');
      
      result = await _runCommand('pkg', ['install', '-y', 'nodejs'],
        timeout: const Duration(minutes: 5));
      if (!result.success) {
        _log('error', 'Failed to install Node.js via pkg', result.stderr);
        return false;
      }
      
      _updateProgress(InstallationStep.installingNodejs, 0.8, 'Verifying Node.js installation...');
      
      if (!await _isNodeInstalled()) {
        _log('error', 'Node.js installation verification failed');
        return false;
      }
      
      _updateProgress(InstallationStep.installingNodejs, 1.0, 'Node.js installed successfully!');
      _log('success', 'Node.js installed via Termux');
      return true;
    } catch (e) {
      _log('error', 'Node.js installation error', e.toString());
      return false;
    }
  }

  /// Install bundled Node.js (fallback method)
  Future<bool> _installBundledNodejs() async {
    // This would download and extract a pre-built Node.js binary
    // For now, we require Termux
    _log('warning', 'Bundled Node.js not implemented. Please install Termux from F-Droid.');
    return false;
  }

  /// Install OpenClaw npm package
  Future<bool> _installOpenClawPackage() async {
    try {
      _updateProgress(InstallationStep.installingOpenClaw, 0.1, 'Installing OpenClaw via npm...');
      
      // Try global install first
      var result = await _runCommand('npm', ['install', '-g', 'openclaw'],
        timeout: const Duration(minutes: 5));
      
      if (!result.success) {
        _log('warning', 'Global npm install failed, trying with --unsafe-perm', result.stderr);
        
        // Try with --unsafe-perm (sometimes needed on Android)
        result = await _runCommand('npm', ['install', '-g', 'openclaw', '--unsafe-perm'],
          timeout: const Duration(minutes: 5));
      }
      
      if (!result.success) {
        // Try local install as fallback
        _log('warning', 'Global install failed, trying local install...');
        
        final localDir = '$_appDir/.npm-global';
        await Directory(localDir).create(recursive: true);
        
        result = await _runCommand('npm', ['install', 'openclaw'],
          workingDirectory: localDir,
          timeout: const Duration(minutes: 5));
        
        if (result.success) {
          // Add to PATH
          await _setupLocalNpmPath(localDir);
        }
      }
      
      if (!result.success) {
        _log('error', 'Failed to install OpenClaw', result.stderr);
        return false;
      }
      
      _updateProgress(InstallationStep.installingOpenClaw, 0.8, 'Verifying OpenClaw installation...');
      
      final openclawPath = await _findOpenClawBinary();
      if (openclawPath == null) {
        _log('error', 'OpenClaw binary not found after installation');
        return false;
      }
      
      // Check version
      final versionResult = await Process.run(openclawPath, ['--version'],
        environment: await _getEnvironment());
      if (versionResult.exitCode == 0) {
        _log('info', 'OpenClaw version: ${versionResult.stdout.trim()}');
      }
      
      _updateProgress(InstallationStep.installingOpenClaw, 1.0, 'OpenClaw installed successfully!');
      _log('success', 'OpenClaw installed');
      return true;
    } catch (e) {
      _log('error', 'OpenClaw installation error', e.toString());
      return false;
    }
  }

  /// Configure environment for OpenClaw
  Future<bool> _configureEnvironment() async {
    try {
      _updateProgress(InstallationStep.configuringEnvironment, 0.2, 'Setting up environment variables...');
      
      // Create .openclaw directory
      final openclawHome = Directory('$_appDir/.openclaw');
      await openclawHome.create(recursive: true);
      
      _updateProgress(InstallationStep.configuringEnvironment, 0.4, 'Creating Bionic bypass...');
      
      // Create Bionic bypass script (fixes Android B libc issues)
      final bionicBypass = File('${openclawHome.path}/bionic-bypass.js');
      await bionicBypass.writeAsString('''
// Bionic libc bypass for Android
const os = require('os');
const originalNetworkInterfaces = os.networkInterfaces;
os.networkInterfaces = function() {
  try {
    const interfaces = originalNetworkInterfaces.call(os);
    if (interfaces && Object.keys(interfaces).length > 0) {
      return interfaces;
    }
  } catch (e) {}
  // Return loopback fallback
  return {
    lo: [{
      address: '127.0.0.1',
      netmask: '255.0.0.0',
      family: 'IPv4',
      mac: '00:00:00:00:00:00',
      internal: true,
      cidr: '127.0.0.1/8'
    }]
  };
};
''');
      
      _updateProgress(InstallationStep.configuringEnvironment, 0.6, 'Setting up npm configuration...');
      
      // Configure npm prefix if using local install
      final npmrc = File('$_appDir/.npmrc');
      if (!await npmrc.exists()) {
        await npmrc.writeAsString('''
prefix=${_appDir}/.npm-global
''');
      }
      
      _updateProgress(InstallationStep.configuringEnvironment, 0.8, 'Creating startup scripts...');
      
      // Create a wrapper script for starting OpenClaw
      final wrapperScript = File('${openclawHome.path}/start-gateway.sh');
      await wrapperScript.writeAsString('''
#!/bin/bash
export NODE_OPTIONS="--require ${openclawHome.path}/bionic-bypass.js"
export PATH="\$PATH:${_appDir}/.npm-global/bin"
openclaw gateway start --port 18789
''');
      await Process.run('chmod', ['+x', wrapperScript.path]);
      
      _updateProgress(InstallationStep.configuringEnvironment, 1.0, 'Environment configured!');
      _log('success', 'Environment configured');
      return true;
    } catch (e) {
      _log('error', 'Environment configuration error', e.toString());
      return false;
    }
  }

  /// Setup local npm path
  Future<void> _setupLocalNpmPath(String localDir) async {
    final shellRc = File('$_appDir/.bashrc');
    final exportLine = 'export PATH="\$PATH:$localDir/node_modules/.bin:$localDir/bin"';
    
    if (await shellRc.exists()) {
      final content = await shellRc.readAsString();
      if (!content.contains(exportLine)) {
        await shellRc.writeAsString('\n$exportLine\n', mode: FileMode.append);
      }
    } else {
      await shellRc.writeAsString('$exportLine\n');
    }
  }

  /// Find the OpenClaw binary
  Future<String?> _findOpenClawBinary() async {
    final possiblePaths = [
      '/data/data/com.termux/files/usr/bin/openclaw',
      '/usr/local/bin/openclaw',
      '/usr/bin/openclaw',
      '$_appDir/.npm-global/bin/openclaw',
      '$_appDir/.npm-global/node_modules/.bin/openclaw',
    ];
    
    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    // Try which command
    try {
      final result = await Process.run('which', ['openclaw']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    
    return null;
  }

  /// Get environment variables for running commands
  Future<Map<String, String>> _getEnvironment() async {
    final env = Map<String, String>.from(Platform.environment);
    
    // Add npm global paths
    env['PATH'] = '${_appDir}/.npm-global/bin:${_appDir}/.npm-global/node_modules/.bin:${env['PATH']}';
    
    // Add Node.js options for Bionic bypass
    env['NODE_OPTIONS'] = '--require $_appDir/.openclaw/bionic-bypass.js';
    
    return env;
  }

  /// Run a shell command with proper error handling
  Future<CommandResult> _runCommand(
    String command,
    List<String> args, {
    String? workingDirectory,
    Duration? timeout,
  }) async {
    try {
      _log('debug', 'Running: $command ${args.join(' ')}');
      
      final process = await Process.start(
        command,
        args,
        workingDirectory: workingDirectory,
        environment: await _getEnvironment(),
      );
      
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      
      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write(data);
        if (data.trim().isNotEmpty) {
          _log('debug', '[$command stdout]', data.trim());
        }
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write(data);
        if (data.trim().isNotEmpty) {
          _log('debug', '[$command stderr]', data.trim());
        }
      });
      
      int exitCode;
      if (timeout != null) {
        exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        });
      } else {
        exitCode = await process.exitCode;
      }
      
      return CommandResult(
        exitCode: exitCode,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
        success: exitCode == 0,
      );
    } catch (e) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        success: false,
      );
    }
  }

  /// Save installation state to preferences
  Future<void> _saveInstallationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openclaw_installed', true);
    await prefs.setString('openclaw_install_path', _openclawDir ?? '');
    await prefs.setInt('openclaw_install_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if OpenClaw is installed
  static Future<bool> isInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('openclaw_installed') ?? false;
  }

  /// Update progress
  void _updateProgress(InstallationStep step, double progress, String message) {
    onProgress?.call(step, progress, message);
  }

  /// Set state
  void _setState(InstallationState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Set error state
  void _setError(String message) {
    _lastError = message;
    _setState(InstallationState.error);
    _log('error', message);
  }

  /// Log helper
  void _log(String level, String message, [String? details]) {
    if (kDebugMode) {
      print('[NodejsInstallerService][$level] $message ${details ?? ''}');
    }
    onLog?.call(level, message, details);
  }

  /// Dispose resources
  void dispose() {
    _currentProcess?.kill(ProcessSignal.sigterm);
    _instance = null;
  }
}

/// Command execution result
class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;

  CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.success,
  });
}
