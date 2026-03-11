/// Android Package Detection Utilities
/// 
/// Provides methods to detect installed Android packages (APKs) without root access.
/// Used for detecting Termux, Termux:API, and other prerequisite apps.
/// 
/// Detection Methods:
/// 1. PackageManager (pm list packages) - Most reliable, works without root
/// 2. File system checks - Check for app data directories
/// 3. Intent resolution - Check if app can handle specific intents
/// 
/// References:
/// - https://github.com/termux/termux-app
/// - https://github.com/termux/termux-api
/// - https://termux.dev/en/

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Result of package detection
class PackageDetectionResult {
  final bool isInstalled;
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final bool isEnabled;
  final String? installSource;
  final DateTime? firstInstallTime;
  final DateTime? lastUpdateTime;

  const PackageDetectionResult({
    required this.isInstalled,
    this.packageName,
    this.versionName,
    this.versionCode,
    this.isEnabled = true,
    this.installSource,
    this.firstInstallTime,
    this.lastUpdateTime,
  });

  factory PackageDetectionResult.notInstalled() {
    return const PackageDetectionResult(isInstalled: false);
  }

  @override
  String toString() => 'PackageDetectionResult($packageName: ${isInstalled ? "installed" : "not installed"})';
}

/// Prerequisite check result
class PrerequisiteCheck {
  final String name;
  final bool isSatisfied;
  final String? message;
  final String? actionRequired;
  final PrerequisiteSeverity severity;

  const PrerequisiteCheck({
    required this.name,
    required this.isSatisfied,
    this.message,
    this.actionRequired,
    this.severity = PrerequisiteSeverity.required,
  });

  @override
  String toString() => 'PrerequisiteCheck($name: ${isSatisfied ? "✓" : "✗"} - ${message ?? "OK"})';
}

/// Severity level for prerequisites
enum PrerequisiteSeverity {
  required,    // Must be satisfied
  recommended, // Should be satisfied
  optional,    // Nice to have
}

/// Android Package Detector
/// 
/// Detects installed Android packages using various methods.
class AndroidPackageDetector {
  static const String TERMUX_PACKAGE = 'com.termux';
  static const String TERMUX_API_PACKAGE = 'com.termux.api';
  static const String TERMUX_FLOAT_PACKAGE = 'com.termux.float';
  static const String TERMUX_WIDGET_PACKAGE = 'com.termux.widget';
  static const String TERMUX_BOOT_PACKAGE = 'com.termux.boot';
  static const String TERMUX_FDROID_URL =
      'https://f-droid.org/packages/com.termux/';
  static const String TERMUX_API_FDROID_URL =
      'https://f-droid.org/packages/com.termux.api/';
  static const String TERMUX_GITHUB_RELEASES_URL =
      'https://github.com/termux/termux-app/releases';
  static const String TERMUX_API_GITHUB_RELEASES_URL =
      'https://github.com/termux/termux-api/releases';

  /// Check if a package is installed using pm command
  static Future<PackageDetectionResult> checkPackage(String packageName) async {
    if (!Platform.isAndroid) {
      return PackageDetectionResult.notInstalled();
    }

    try {
      // Method 1: Use pm list packages
      final pmResult = await Process.run(
        'pm',
        ['list', 'packages', packageName],
        runInShell: true,
      );

      if (pmResult.exitCode == 0) {
        final output = pmResult.stdout.toString().trim();
        if (output.contains('package:$packageName')) {
          // Package is installed
          final isEnabled = !output.contains('disabled');
          
          // Try to get more details
          final dumpResult = await Process.run(
            'dumpsys',
            ['package', packageName],
            runInShell: true,
          );

          String? versionName;
          int? versionCode;
          String? installSource;
          DateTime? firstInstallTime;
          DateTime? lastUpdateTime;

          if (dumpResult.exitCode == 0) {
            final dumpOutput = dumpResult.stdout.toString();
            
            // Extract version name
            final versionNameMatch = RegExp(r'versionName=([^\s]+)').firstMatch(dumpOutput);
            versionName = versionNameMatch?.group(1);

            // Extract version code
            final versionCodeMatch = RegExp(r'versionCode=(\d+)').firstMatch(dumpOutput);
            versionCode = versionCodeMatch != null ? int.tryParse(versionCodeMatch.group(1)!) : null;

            // Extract install source
            final installSourceMatch = RegExp(r'installSource=([^\s]+)').firstMatch(dumpOutput);
            installSource = installSourceMatch?.group(1);

            // Extract install times
            final firstInstallMatch = RegExp(r'firstInstallTime=(\d+)').firstMatch(dumpOutput);
            if (firstInstallMatch != null) {
              final timestamp = int.tryParse(firstInstallMatch.group(1)!);
              if (timestamp != null) {
                firstInstallTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
              }
            }

            final lastUpdateMatch = RegExp(r'lastUpdateTime=(\d+)').firstMatch(dumpOutput);
            if (lastUpdateMatch != null) {
              final timestamp = int.tryParse(lastUpdateMatch.group(1)!);
              if (timestamp != null) {
                lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
              }
            }
          }

          return PackageDetectionResult(
            isInstalled: true,
            packageName: packageName,
            versionName: versionName,
            versionCode: versionCode,
            isEnabled: isEnabled,
            installSource: installSource,
            firstInstallTime: firstInstallTime,
            lastUpdateTime: lastUpdateTime,
          );
        }
      }
    } catch (e) {
      debugPrint('Package detection failed for $packageName: $e');
    }

    // Fallback: Check file system
    return _checkFileSystem(packageName);
  }

  /// Fallback: Check if app data directory exists
  static Future<PackageDetectionResult> _checkFileSystem(String packageName) async {
    try {
      // Convert package name to directory path
      // e.g., com.termux -> /data/data/com.termux
      final dataDir = Directory('/data/data/$packageName');
      final exists = await dataDir.exists();

      if (exists) {
        return PackageDetectionResult(
          isInstalled: true,
          packageName: packageName,
          isEnabled: true,
        );
      }

      // Also check /sdcard/Android/data for some apps
      final sdcardDir = Directory('/sdcard/Android/data/$packageName');
      if (await sdcardDir.exists()) {
        return PackageDetectionResult(
          isInstalled: true,
          packageName: packageName,
          isEnabled: true,
        );
      }
    } catch (e) {
      debugPrint('File system check failed for $packageName: $e');
    }

    return PackageDetectionResult.notInstalled();
  }

  /// Check if Termux is installed
  static Future<PackageDetectionResult> checkTermux() {
    return checkPackage(TERMUX_PACKAGE);
  }

  /// Check if Termux:API is installed
  static Future<PackageDetectionResult> checkTermuxApi() {
    return checkPackage(TERMUX_API_PACKAGE);
  }

  /// Check if Termux:Float (floating window) is installed
  static Future<PackageDetectionResult> checkTermuxFloat() {
    return checkPackage(TERMUX_FLOAT_PACKAGE);
  }

  /// Check if Termux:Widget is installed
  static Future<PackageDetectionResult> checkTermuxWidget() {
    return checkPackage(TERMUX_WIDGET_PACKAGE);
  }

  /// Check if Termux:Boot is installed
  static Future<PackageDetectionResult> checkTermuxBoot() {
    return checkPackage(TERMUX_BOOT_PACKAGE);
  }

  /// Check all Termux-related packages
  static Future<Map<String, PackageDetectionResult>> checkAllTermuxPackages() async {
    final results = <String, PackageDetectionResult>{};

    final packages = {
      'Termux': TERMUX_PACKAGE,
      'Termux:API': TERMUX_API_PACKAGE,
      'Termux:Float': TERMUX_FLOAT_PACKAGE,
      'Termux:Widget': TERMUX_WIDGET_PACKAGE,
      'Termux:Boot': TERMUX_BOOT_PACKAGE,
    };

    for (final entry in packages.entries) {
      results[entry.key] = await checkPackage(entry.value);
    }

    return results;
  }
}

/// Termux Prerequisite Checker
/// 
/// Checks if all prerequisites for running OpenClaw in Termux are satisfied.
class TermuxPrerequisiteChecker {
  /// Check all prerequisites for Termux-based OpenClaw installation
  static Future<List<PrerequisiteCheck>> checkAll() async {
    final checks = <PrerequisiteCheck>[];

    // 1. Check Android platform
    checks.add(PrerequisiteCheck(
      name: 'Android Platform',
      isSatisfied: Platform.isAndroid,
      message: Platform.isAndroid ? 'Running on Android' : 'Not running on Android',
      actionRequired: Platform.isAndroid ? null : 'OpenClaw local installation requires Android',
      severity: PrerequisiteSeverity.required,
    ));

    // 2. Check Termux installation
    final termuxResult = await AndroidPackageDetector.checkTermux();
    checks.add(PrerequisiteCheck(
      name: 'Termux App',
      isSatisfied: termuxResult.isInstalled,
      message: termuxResult.isInstalled
          ? 'Termux ${termuxResult.versionName ?? ''} installed'
          : 'Termux not installed',
      actionRequired: termuxResult.isInstalled
          ? null
          : 'Install Termux from F-Droid or GitHub Releases, not Google Play',
      severity: PrerequisiteSeverity.required,
    ));

    // 3. Check Termux:API (recommended)
    final termuxApiResult = await AndroidPackageDetector.checkTermuxApi();
    checks.add(PrerequisiteCheck(
      name: 'Termux:API',
      isSatisfied: termuxApiResult.isInstalled,
      message: termuxApiResult.isInstalled
          ? 'Termux:API ${termuxApiResult.versionName ?? ''} installed'
          : 'Termux:API not installed',
      actionRequired: termuxApiResult.isInstalled
          ? null
          : 'Install the Termux:API app from the same source as Termux',
      severity: PrerequisiteSeverity.recommended,
    ));

    // 4. Check storage permission (recommended for shared file access)
    if (termuxResult.isInstalled) {
      final storageGranted = await _checkStoragePermission();
      checks.add(PrerequisiteCheck(
        name: 'Storage Permission',
        isSatisfied: storageGranted,
        message: storageGranted ? 'Storage permission granted' : 'Storage permission not granted',
        actionRequired: storageGranted
            ? null
            : 'Run "termux-setup-storage" in Termux if you want shared storage access',
        severity: PrerequisiteSeverity.recommended,
      ));
    }

    // 5. Check Node.js availability (recommended, installer can add it)
    final nodeCheck = await _checkNodeJs();
    checks.add(nodeCheck);

    // 6. Check network connectivity
    final networkCheck = await _checkNetwork();
    checks.add(networkCheck);

    // 7. Check storage space
    final storageCheck = await _checkStorageSpace();
    checks.add(storageCheck);

    return checks;
  }

  /// Check if storage permission is granted
  static Future<bool> _checkStoragePermission() async {
    try {
      // Try to access shared storage
      final sdcardDir = Directory('/sdcard');
      if (await sdcardDir.exists()) {
        // Try to create a test file
        final testFile = File('/sdcard/.termux_storage_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Storage permission check failed: $e');
      return false;
    }
  }

  /// Check if Node.js is available
  static Future<PrerequisiteCheck> _checkNodeJs() async {
    try {
      final result = await Process.run('which', ['node']);
      if (result.exitCode == 0) {
        // Get version
        final versionResult = await Process.run('node', ['--version']);
        if (versionResult.exitCode == 0) {
          final version = versionResult.stdout.toString().trim();
          return PrerequisiteCheck(
            name: 'Node.js',
            isSatisfied: true,
            message: 'Node.js $version available',
          );
        }
      }

      return PrerequisiteCheck(
        name: 'Node.js',
        isSatisfied: false,
        message: 'Node.js not found',
        actionRequired: 'Install Node.js in Termux with "pkg install nodejs"',
        severity: PrerequisiteSeverity.recommended,
      );
    } catch (e) {
      return PrerequisiteCheck(
        name: 'Node.js',
        isSatisfied: false,
        message: 'Could not check Node.js: $e',
        actionRequired: 'Open Termux once, then install Node.js with "pkg install nodejs"',
        severity: PrerequisiteSeverity.recommended,
      );
    }
  }

  /// Check network connectivity
  static Future<PrerequisiteCheck> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('registry.npmjs.org')
          .timeout(const Duration(seconds: 5));
      
      return PrerequisiteCheck(
        name: 'Network Connectivity',
        isSatisfied: result.isNotEmpty,
        message: result.isNotEmpty ? 'Internet connection available' : 'No internet connection',
        actionRequired: result.isNotEmpty ? null : 'Connect to internet for installation',
        severity: PrerequisiteSeverity.required,
      );
    } catch (e) {
      return PrerequisiteCheck(
        name: 'Network Connectivity',
        isSatisfied: false,
        message: 'Network check failed: $e',
        actionRequired: 'Check internet connection',
        severity: PrerequisiteSeverity.required,
      );
    }
  }

  /// Check available storage space
  static Future<PrerequisiteCheck> _checkStorageSpace() async {
    try {
      final result = await Process.run('df', ['-k', '/data']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final availableKb = int.tryParse(parts[3]);
            if (availableKb != null) {
              final availableMb = availableKb ~/ 1024;
              final hasSpace = availableMb >= 500;
              
              return PrerequisiteCheck(
                name: 'Storage Space',
                isSatisfied: hasSpace,
                message: '${availableMb}MB available',
                actionRequired: hasSpace ? null : 'Free up at least 500MB of storage space',
                severity: PrerequisiteSeverity.required,
              );
            }
          }
        }
      }
      
      return const PrerequisiteCheck(
        name: 'Storage Space',
        isSatisfied: true,
        message: 'Unable to check storage (assuming OK)',
      );
    } catch (e) {
      return PrerequisiteCheck(
        name: 'Storage Space',
        isSatisfied: true,
        message: 'Unable to check storage: $e',
      );
    }
  }

  /// Get installation readiness summary
  static Future<TermuxReadinessSummary> getReadinessSummary() async {
    final checks = await checkAll();
    
    final requiredChecks = checks.where((c) => c.severity == PrerequisiteSeverity.required).toList();
    final recommendedChecks = checks.where((c) => c.severity == PrerequisiteSeverity.recommended).toList();
    
    final requiredPassed = requiredChecks.where((c) => c.isSatisfied).length;
    final recommendedPassed = recommendedChecks.where((c) => c.isSatisfied).length;
    
    final isReady = requiredPassed == requiredChecks.length;
    final isRecommended = recommendedPassed == recommendedChecks.length;

    return TermuxReadinessSummary(
      isReady: isReady,
      isRecommended: isRecommended,
      totalChecks: checks.length,
      passedChecks: checks.where((c) => c.isSatisfied).length,
      requiredTotal: requiredChecks.length,
      requiredPassed: requiredPassed,
      recommendedTotal: recommendedChecks.length,
      recommendedPassed: recommendedPassed,
      allChecks: checks,
      blockingIssues: requiredChecks.where((c) => !c.isSatisfied).toList(),
      recommendations: recommendedChecks.where((c) => !c.isSatisfied).toList(),
    );
  }
}

/// Summary of Termux installation readiness
class TermuxReadinessSummary {
  final bool isReady;
  final bool isRecommended;
  final int totalChecks;
  final int passedChecks;
  final int requiredTotal;
  final int requiredPassed;
  final int recommendedTotal;
  final int recommendedPassed;
  final List<PrerequisiteCheck> allChecks;
  final List<PrerequisiteCheck> blockingIssues;
  final List<PrerequisiteCheck> recommendations;

  const TermuxReadinessSummary({
    required this.isReady,
    required this.isRecommended,
    required this.totalChecks,
    required this.passedChecks,
    required this.requiredTotal,
    required this.requiredPassed,
    required this.recommendedTotal,
    required this.recommendedPassed,
    required this.allChecks,
    required this.blockingIssues,
    required this.recommendations,
  });

  String get readinessText {
    if (isReady && isRecommended) {
      return '✅ Ready for installation';
    } else if (isReady) {
      return '⚠️ Ready (optional improvements available)';
    } else {
      return '❌ Not ready (${blockingIssues.length} blocking issue${blockingIssues.length != 1 ? 's' : ''})';
    }
  }

  @override
  String toString() => 'TermuxReadinessSummary(ready: $isReady, passed: $passedChecks/$totalChecks)';
}
