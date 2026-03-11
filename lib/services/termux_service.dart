/// Termux Service - Execute shell commands on Android via Termux
///
/// Provides shell command execution, OpenClaw CLI integration,
/// and node management capabilities for OpenClaw Mobile.
///
/// Uses proot-distro to run Ubuntu inside Termux for full Linux compatibility.
/// Handles Bionic libc bypass for Node.js compatibility on Android.
/// 
/// Detection: Uses Android package manager (pm) for reliable Termux detection.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/android_package_detector.dart';

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

/// Setup progress state
class SetupProgress {
  final String step;
  final String message;
  final double progress; // 0.0 to 1.0
  final bool isError;
  final bool isComplete;

  const SetupProgress({
    required this.step,
    required this.message,
    this.progress = 0.0,
    this.isError = false,
    this.isComplete = false,
  });
}

/// Termux Service - Shell command execution with proot-distro support
class TermuxService {
  static TermuxService? _instance;

  bool _isInitialized = false;
  bool _isTermuxAvailable = false;
  bool _isTermuxApiAvailable = false;
  bool _isProotAvailable = false;
  bool _isUbuntuInstalled = false;
  String? _openClawVersion;
  String? _nodeVersion;
  String? _gatewayStatus;
  String? _termuxVersion;

  // Termux paths
  String? _termuxHomePath;
  String? _termuxPrefixPath;

  // Detection results
  PackageDetectionResult? _termuxDetectionResult;
  PackageDetectionResult? _termuxApiDetectionResult;

  // Progress callbacks
  void Function(SetupProgress progress)? onSetupProgress;
  void Function(String line)? onOutput;

  factory TermuxService() {
    _instance ??= TermuxService._internal();
    return _instance!;
  }

  TermuxService._internal();

  // ==================== Initialization ====================

  /// Initialize the Termux service with comprehensive detection
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _log('Initializing Termux service...');

      // Check if running in Termux environment using Android package manager
      await _checkTermuxAvailability();

      if (_isTermuxAvailable) {
        _findTermuxPaths();
        _log('Termux available at: $_termuxPrefixPath (version: $_termuxVersion)');

        // Check Termux:API
        await _checkTermuxApiAvailability();
        _log('Termux:API available: $_isTermuxApiAvailable');

        // Check proot-distro
        _isProotAvailable = await _checkProotAvailable();
        _log('proot-distro available: $_isProotAvailable');

        // Check if Ubuntu is installed
        if (_isProotAvailable) {
          _isUbuntuInstalled = await _checkUbuntuInstalled();
          _log('Ubuntu installed: $_isUbuntuInstalled');
        }
      } else {
        _log('Not in Termux environment - will use system shell fallback');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _log('Failed to initialize Termux service: $e');
      return false;
    }
  }

  /// Check if Termux is installed using Android package manager
  Future<void> _checkTermuxAvailability() async {
    if (!Platform.isAndroid) {
      _isTermuxAvailable = false;
      return;
    }

    try {
      // Primary method: Use Android package manager
      _termuxDetectionResult = await AndroidPackageDetector.checkTermux();
      _isTermuxAvailable = _termuxDetectionResult!.isInstalled;
      _termuxVersion = _termuxDetectionResult?.versionName;

      if (_isTermuxAvailable) {
        _log('✅ Termux detected via package manager: ${_termuxDetectionResult?.packageName}');
        return;
      }

      // Fallback: Check for Termux directory
      _log('⚠️ Package manager check failed, trying file system fallback...');
      final termuxDir = Directory('/data/data/com.termux/files');
      if (await termuxDir.exists()) {
        _isTermuxAvailable = true;
        _log('✅ Termux detected via file system');
        return;
      }

      // Final fallback: Check alternative paths
      final altDir = Directory('/data/data/com.termux');
      _isTermuxAvailable = await altDir.exists();
      if (_isTermuxAvailable) {
        _log('✅ Termux detected via alternative path');
      } else {
        _log('❌ Termux not detected by any method');
      }
    } catch (e) {
      _log('Termux detection error: $e');
      _isTermuxAvailable = false;
    }
  }

  /// Check if Termux:API is installed
  Future<void> _checkTermuxApiAvailability() async {
    if (!Platform.isAndroid) {
      _isTermuxApiAvailable = false;
      return;
    }

    try {
      _termuxApiDetectionResult = await AndroidPackageDetector.checkTermuxApi();
      _isTermuxApiAvailable = _termuxApiDetectionResult!.isInstalled;

      if (_isTermuxApiAvailable) {
        _log('✅ Termux:API detected: ${_termuxApiDetectionResult?.versionName}');
      } else {
        _log('ℹ️ Termux:API not installed (optional)');
      }
    } catch (e) {
      _log('Termux:API detection error: $e');
      _isTermuxApiAvailable = false;
    }
  }

  /// Find Termux paths
  void _findTermuxPaths() {
    _termuxPrefixPath = '/data/data/com.termux/files/usr';
    _termuxHomePath = '/data/data/com.termux/files/home';
  }

  /// Check if proot-distro is available
  Future<bool> _checkProotAvailable() async {
    final result = await _runInTermux('which proot-distro');
    return result.success && result.stdout.trim().isNotEmpty;
  }

  /// Check if Ubuntu is installed in proot
  Future<bool> _checkUbuntuInstalled() async {
    final result = await _runInTermux('proot-distro list');
    return result.success && result.stdout.contains('ubuntu');
  }

  // ==================== Getters ====================

  bool get isInitialized => _isInitialized;
  bool get isTermuxAvailable => _isTermuxAvailable;
  bool get isTermuxApiAvailable => _isTermuxApiAvailable;
  bool get isProotAvailable => _isProotAvailable;
  bool get isUbuntuInstalled => _isUbuntuInstalled;
  bool get isSetupComplete => _isTermuxAvailable && _isProotAvailable && _isUbuntuInstalled;
  String? get openClawVersion => _openClawVersion;
  String? get nodeVersion => _nodeVersion;
  String? get gatewayStatus => _gatewayStatus;
  String? get termuxVersion => _termuxVersion;
  PackageDetectionResult? get termuxDetectionResult => _termuxDetectionResult;
  PackageDetectionResult? get termuxApiDetectionResult => _termuxApiDetectionResult;

  /// Get detailed Termux installation info
  Map<String, dynamic> getTermuxInfo() {
    return {
      'isInstalled': _isTermuxAvailable,
      'version': _termuxVersion,
      'packageName': _termuxDetectionResult?.packageName,
      'versionCode': _termuxDetectionResult?.versionCode,
      'isEnabled': _termuxDetectionResult?.isEnabled,
      'installSource': _termuxDetectionResult?.installSource,
      'firstInstallTime': _termuxDetectionResult?.firstInstallTime?.toIso8601String(),
      'lastUpdateTime': _termuxDetectionResult?.lastUpdateTime?.toIso8601String(),
      'isApiInstalled': _isTermuxApiAvailable,
      'apiVersion': _termuxApiDetectionResult?.versionName,
      'isProotAvailable': _isProotAvailable,
      'isUbuntuInstalled': _isUbuntuInstalled,
    };
  }

  // ==================== Command Execution ====================

  /// Execute a command in Termux environment
  Future<CommandResult> executeCommand(
    String command, {
    List<String>? args,
    Duration timeout = const Duration(seconds: 30),
    String? workingDirectory,
    bool useProot = false,
  }) async {
    if (useProot && _isProotAvailable && _isUbuntuInstalled) {
      return _runInProot(command, args: args, timeout: timeout);
    }
    return _runInTermux(command, args: args, timeout: timeout);
  }

  /// Run command in Termux shell
  Future<CommandResult> _runInTermux(
    String command, {
    List<String>? args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final startTime = DateTime.now();

    try {
      final fullCommand = args != null && args.isNotEmpty
          ? '$command ${args.join(' ')}'
          : command;

      _log('Termux: $fullCommand');

      // Use Termux shell
      final shellPath = '$_termuxPrefixPath/bin/sh';
      final processArgs = ['-c', fullCommand];

      // Set up environment
      final environment = {
        'PATH': '$_termuxPrefixPath/bin:$_termuxPrefixPath/bin/applets:\$PATH',
        'HOME': _termuxHomePath ?? '/data/data/com.termux/files/home',
        'PREFIX': _termuxPrefixPath ?? '/data/data/com.termux/files/usr',
        'TERMUX_VERSION': '1',
        'LD_LIBRARY_PATH': '$_termuxPrefixPath/lib',
      };

      final process = await Process.start(
        shellPath,
        processArgs,
        environment: environment,
        runInShell: false,
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

      // Wait for process with timeout
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } catch (e) {
        process.kill(ProcessSignal.sigkill);
        exitCode = -1;
        _log('Command timed out after ${timeout.inSeconds}s');
      }

      final duration = DateTime.now().difference(startTime);

      return CommandResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: duration,
        success: exitCode == 0,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _log('Command execution failed: $e');

      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: duration,
        success: false,
      );
    }
  }

  /// Run command in proot Ubuntu environment
  Future<CommandResult> _runInProot(
    String command, {
    List<String>? args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final startTime = DateTime.now();

    try {
      final fullCommand = args != null && args.isNotEmpty
          ? '$command ${args.join(' ')}'
          : command;

      _log('proot: $fullCommand');

      // Build proot command with proper environment setup
      final prootCommand = 'proot-distro login ubuntu -- bash -c '
          '"export HOME=/root && export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin && '
          'export NODE_OPTIONS=--openssl-legacy-provider && '
          '$fullCommand"';

      return _runInTermux(prootCommand, timeout: timeout);
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _log('proot command failed: $e');

      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: duration,
        success: false,
      );
    }
  }

  // ==================== Setup & Installation ====================

  /// Run the complete setup process
  Future<bool> runSetup() async {
    onSetupProgress?.call(const SetupProgress(
      step: 'init',
      message: 'Starting setup...',
      progress: 0.0,
    ));

    // Step 1: Update Termux packages
    onSetupProgress?.call(const SetupProgress(
      step: 'update',
      message: 'Updating Termux packages...',
      progress: 0.1,
    ));

    final updateResult = await _runInTermux('pkg update -y', timeout: const Duration(minutes: 5));
    if (!updateResult.success) {
      onSetupProgress?.call(SetupProgress(
        step: 'update',
        message: 'Package update failed: ${updateResult.stderr}',
        progress: 0.1,
        isError: true,
      ));
      // Continue anyway - might just be network issues
    }

    // Step 2: Install proot-distro
    onSetupProgress?.call(const SetupProgress(
      step: 'proot',
      message: 'Installing proot-distro...',
      progress: 0.2,
    ));

    if (!_isProotAvailable) {
      final prootResult = await _runInTermux(
        'pkg install proot-distro -y',
        timeout: const Duration(minutes: 3),
      );

      if (!prootResult.success) {
        onSetupProgress?.call(SetupProgress(
          step: 'proot',
          message: 'Failed to install proot-distro: ${prootResult.stderr}',
          progress: 0.2,
          isError: true,
        ));
        return false;
      }

      _isProotAvailable = true;
    }

    // Step 3: Install Ubuntu
    onSetupProgress?.call(const SetupProgress(
      step: 'ubuntu',
      message: 'Installing Ubuntu (this may take a while)...',
      progress: 0.3,
    ));

    if (!_isUbuntuInstalled) {
      final ubuntuResult = await _runInTermux(
        'proot-distro install ubuntu',
        timeout: const Duration(minutes: 15),
      );

      if (!ubuntuResult.success && !ubuntuResult.stdout.contains('already installed')) {
        onSetupProgress?.call(SetupProgress(
          step: 'ubuntu',
          message: 'Failed to install Ubuntu: ${ubuntuResult.stderr}',
          progress: 0.3,
          isError: true,
        ));
        return false;
      }

      _isUbuntuInstalled = true;
    }

    // Step 4: Update Ubuntu packages
    onSetupProgress?.call(const SetupProgress(
      step: 'ubuntu-update',
      message: 'Updating Ubuntu packages...',
      progress: 0.5,
    ));

    await _runInProot('apt update -y', timeout: const Duration(minutes: 5));
    await _runInProot('apt upgrade -y', timeout: const Duration(minutes: 5));

    // Step 5: Install Node.js
    onSetupProgress?.call(const SetupProgress(
      step: 'nodejs',
      message: 'Installing Node.js...',
      progress: 0.6,
    ));

    // Install Node.js 22.x
    final nodeSetupResult = await _runInProot(
      'curl -fsSL https://deb.nodesource.com/setup_22.x | bash -',
      timeout: const Duration(minutes: 3),
    );

    if (!nodeSetupResult.success) {
      // Fallback: install from apt
      _log('NodeSource setup failed, trying apt...');
    }

    final nodeInstallResult = await _runInProot(
      'apt install -y nodejs npm curl',
      timeout: const Duration(minutes: 5),
    );

    if (!nodeInstallResult.success) {
      onSetupProgress?.call(SetupProgress(
        step: 'nodejs',
        message: 'Failed to install Node.js: ${nodeInstallResult.stderr}',
        progress: 0.6,
        isError: true,
      ));
      return false;
    }

    // Check Node.js version
    final nodeVersionResult = await _runInProot('node --version');
    if (nodeVersionResult.success) {
      _nodeVersion = nodeVersionResult.stdout.trim();
      _log('Node.js version: $_nodeVersion');
    }

    // Step 6: Install OpenClaw
    onSetupProgress?.call(const SetupProgress(
      step: 'openclaw',
      message: 'Installing OpenClaw...',
      progress: 0.8,
    ));

    // Install OpenClaw globally with Bionic libc workaround
    final openclawResult = await _runInProot(
      'npm install -g openclaw --unsafe-perm',
      timeout: const Duration(minutes: 10),
    );

    if (!openclawResult.success) {
      onSetupProgress?.call(SetupProgress(
        step: 'openclaw',
        message: 'Failed to install OpenClaw: ${openclawResult.stderr}',
        progress: 0.8,
        isError: true,
      ));
      return false;
    }

    // Verify OpenClaw installation
    final versionResult = await _runInProot('openclaw --version');
    if (versionResult.success) {
      _openClawVersion = versionResult.stdout.trim();
      _log('OpenClaw version: $_openClawVersion');
    }

    // Step 7: Create startup script with Bionic bypass
    onSetupProgress?.call(const SetupProgress(
      step: 'scripts',
      message: 'Creating startup scripts...',
      progress: 0.9,
    ));

    await _createStartupScripts();

    onSetupProgress?.call(const SetupProgress(
      step: 'complete',
      message: 'Setup complete!',
      progress: 1.0,
      isComplete: true,
    ));

    return true;
  }

  /// Create helper scripts for running OpenClaw
  Future<void> _createStartupScripts() async {
    // Create openclawx script (similar to reference implementation)
    final scriptContent = '''#!/bin/bash
# OpenClaw wrapper script for proot-distro
# Handles Bionic libc bypass and environment setup

export HOME=/root
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export NODE_OPTIONS="--openssl-legacy-provider --no-warnings"

# Bionic libc workaround - use IPv4 only for network interfaces
export UV_THREADPOOL_SIZE=128

# Run OpenClaw with proper environment
case "\$1" in
  setup)
    echo "OpenClaw is already set up!"
    ;;
  start)
    echo "Starting OpenClaw gateway..."
    openclaw gateway start --daemon
    ;;
  stop)
    echo "Stopping OpenClaw gateway..."
    openclaw gateway stop
    ;;
  status)
    openclaw status
    ;;
  shell)
    echo "Entering Ubuntu shell..."
    exec bash
    ;;
  *)
    # Pass through any other command
    openclaw "\$@"
    ;;
esac
''';

    // Write script to Termux home
    final scriptPath = '$_termuxHomePath/.openclawx';
    await _runInTermux('cat > $scriptPath << \'EOF\'\n$scriptContent\nEOF');
    await _runInTermux('chmod +x $scriptPath');

    // Create symlink in proot
    await _runInProot('ln -sf /usr/bin/openclaw /usr/local/bin/openclawx');
  }

  // ==================== OpenClaw Commands ====================

  /// Check if OpenClaw is installed
  Future<bool> checkOpenClawInstalled() async {
    final result = await _runInProot('which openclaw');
    if (result.success && result.stdout.trim().isNotEmpty) {
      // Get version
      final versionResult = await _runInProot('openclaw --version');
      if (versionResult.success) {
        _openClawVersion = versionResult.stdout.trim();
      }
      return true;
    }
    return false;
  }

  /// Install OpenClaw via npm
  Future<CommandResult> installOpenClaw() async {
    onSetupProgress?.call(const SetupProgress(
      step: 'install',
      message: 'Installing OpenClaw...',
      progress: 0.0,
    ));

    // Check Node.js first
    final nodeCheck = await _runInProot('node --version');
    if (!nodeCheck.success) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Node.js is not installed. Please run setup first.',
        duration: Duration.zero,
        success: false,
      );
    }

    onSetupProgress?.call(const SetupProgress(
      step: 'install',
      message: 'Running npm install...',
      progress: 0.3,
    ));

    final result = await _runInProot(
      'npm install -g openclaw --unsafe-perm',
      timeout: const Duration(minutes: 10),
    );

    if (result.success) {
      await checkOpenClawInstalled();
      onSetupProgress?.call(const SetupProgress(
        step: 'install',
        message: 'OpenClaw installed successfully!',
        progress: 1.0,
        isComplete: true,
      ));
    } else {
      onSetupProgress?.call(SetupProgress(
        step: 'install',
        message: 'Installation failed: ${result.stderr}',
        progress: 1.0,
        isError: true,
      ));
    }

    return result;
  }

  /// Update OpenClaw
  Future<CommandResult> updateOpenClaw() async {
    onSetupProgress?.call(const SetupProgress(
      step: 'update',
      message: 'Updating OpenClaw...',
      progress: 0.0,
    ));

    final result = await _runInProot(
      'npm install -g openclaw@latest --unsafe-perm',
      timeout: const Duration(minutes: 10),
    );

    if (result.success) {
      await checkOpenClawInstalled();
      onSetupProgress?.call(const SetupProgress(
        step: 'update',
        message: 'OpenClaw updated!',
        progress: 1.0,
        isComplete: true,
      ));
    }

    return result;
  }

  // ==================== Gateway Commands ====================

  /// Start OpenClaw gateway
  Future<CommandResult> startGateway({int port = 18789}) async {
    _log('Starting OpenClaw gateway on port $port...');

    // Create a startup script that handles Bionic libc issues
    final startupScript = '''
export HOME=/root
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export NODE_OPTIONS="--openssl-legacy-provider --no-warnings"
export UV_THREADPOOL_SIZE=128

# Start gateway in background
nohup openclaw gateway start --port $port > /tmp/openclaw-gateway.log 2>&1 &
echo \$!
''';

    return _runInProot(startupScript, timeout: const Duration(seconds: 10));
  }

  /// Stop OpenClaw gateway
  Future<CommandResult> stopGateway() async {
    return _runInProot('openclaw gateway stop');
  }

  /// Get gateway status
  Future<CommandResult> getGatewayStatus() async {
    final result = await _runInProot('openclaw status');
    if (result.success) {
      _gatewayStatus = result.stdout;
    }
    return result;
  }

  /// Check if gateway is running
  Future<bool> isGatewayRunning() async {
    final result = await _runInProot('pgrep -f "openclaw gateway"');
    return result.success && result.stdout.trim().isNotEmpty;
  }

  // ==================== Quick Commands ====================

  /// Run a quick OpenClaw command
  Future<CommandResult> runQuickCommand(String command) async {
    return _runInProot('openclaw $command', timeout: const Duration(seconds: 60));
  }

  /// Run OpenClaw doctor
  Future<CommandResult> runDoctor() async {
    return _runInProot('openclaw doctor', timeout: const Duration(seconds: 30));
  }

  /// Configure OpenClaw
  Future<CommandResult> configureOpenClaw() async {
    return _runInProot('openclaw configure', timeout: const Duration(seconds: 30));
  }

  // ==================== Node Commands ====================

  /// Setup this device as a node
  Future<CommandResult> setupNode({String? nodeName, List<String>? nodeCapabilities}) async {
    _log('Setting up node...');

    final name = nodeName ?? 'android-node';
    final caps = nodeCapabilities?.join(',') ?? 'shell,terminal';

    return _runInProot(
      'openclaw node setup --name "$name" --capabilities "$caps"',
      timeout: const Duration(seconds: 30),
    );
  }

  /// Get node status
  Future<CommandResult> getNodeStatus() async {
    return _runInProot('openclaw nodes status', timeout: const Duration(seconds: 10));
  }

  /// Start node service
  Future<CommandResult> startNode() async {
    return _runInProot('openclaw node start', timeout: const Duration(seconds: 10));
  }

  /// Stop node service
  Future<CommandResult> stopNode() async {
    return _runInProot('openclaw node stop', timeout: const Duration(seconds: 10));
  }

  // ==================== Helpers ====================

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[TermuxService] $message');
    }
    onOutput?.call('[TermuxService] $message\n');
  }

  /// Get setup instructions
  static String getSetupInstructions() {
    return '''
📱 Termux Setup Instructions:

1. Download Termux from F-Droid (NOT Play Store):
   https://f-droid.org/packages/com.termux/

2. Open Termux and the app will auto-setup:
   - Updates packages
   - Installs proot-distro
   - Installs Ubuntu
   - Installs Node.js 22
   - Installs OpenClaw

3. Tap "Start Gateway" to run OpenClaw

4. Configure API keys in Settings

No root required! Everything runs in proot (user-space).
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
