import 'package:flutter/services.dart';

class TermuxCommandResult {
  final bool accepted;
  final bool completed;
  final bool pending;
  final int? exitCode;
  final int? errorCode;
  final String? errorMessage;
  final String? stdout;
  final String? stderr;
  final bool requiresAllowExternalApps;

  const TermuxCommandResult({
    required this.accepted,
    required this.completed,
    required this.pending,
    this.exitCode,
    this.errorCode,
    this.errorMessage,
    this.stdout,
    this.stderr,
    this.requiresAllowExternalApps = false,
  });

  factory TermuxCommandResult.fromMap(Map<Object?, Object?> map) {
    final errorMessage = map['errorMessage']?.toString();
    return TermuxCommandResult(
      accepted: map['accepted'] == true,
      completed: map['completed'] == true,
      pending: map['pending'] == true,
      exitCode: map['exitCode'] is int ? map['exitCode'] as int : null,
      errorCode: map['errorCode'] is int ? map['errorCode'] as int : null,
      errorMessage: errorMessage,
      stdout: map['stdout']?.toString(),
      stderr: map['stderr']?.toString(),
      requiresAllowExternalApps: map['requiresAllowExternalApps'] == true ||
          (errorMessage?.contains('allow-external-apps') ?? false),
    );
  }

  bool get ok {
    if (!accepted) return false;
    if (pending) return true;
    if (!completed) return true;
    if (errorCode != null && errorCode != 0) return false;
    if (exitCode != null && exitCode != 0) return false;
    return true;
  }
}

class TermuxRunCommandService {
  static const MethodChannel _channel = MethodChannel('duckbot/termux_bridge');

  static const String termuxPackage = 'com.termux';
  static const String termuxApiPackage = 'com.termux.api';

  static const String termuxAppFdroidUrl =
      'https://f-droid.org/packages/com.termux/';
  static const String termuxApiFdroidUrl =
      'https://f-droid.org/packages/com.termux.api/';
  static const String termuxAppGithubUrl =
      'https://github.com/termux/termux-app/releases';
  static const String termuxApiGithubUrl =
      'https://github.com/termux/termux-api/releases';
  static const String runCommandHelpUrl =
      'https://github.com/termux/termux-app/wiki/RUN_COMMAND-Intent';
  static const String allowExternalAppsSnippet = 'allow-external-apps=true';
  static const String allowExternalAppsReloadCommand = 'termux-reload-settings';

  Future<bool> isTermuxInstalled() async {
    final result = await _channel.invokeMethod<bool>('isTermuxInstalled');
    return result ?? false;
  }

  Future<bool> hasRunCommandPermission() async {
    final result = await _channel.invokeMethod<bool>('hasRunCommandPermission');
    return result ?? false;
  }

  Future<bool> launchTermux() async {
    final result = await _channel.invokeMethod<bool>('launchTermux');
    return result ?? false;
  }

  Future<void> openAppSettings({String? packageName}) async {
    await _channel.invokeMethod<void>('openAppSettings', {
      if (packageName != null) 'packageName': packageName,
    });
  }

  Future<bool> runCommand({
    required String script,
    required String label,
    String? description,
    bool background = false,
  }) async {
    final result = await runCommandDetailed(
      script: script,
      label: label,
      description: description,
      background: background,
    );
    return result.accepted;
  }

  Future<TermuxCommandResult> runCommandDetailed({
    required String script,
    required String label,
    String? description,
    bool background = false,
    int waitForResultMs = 1800,
  }) async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('runCommandDetailed', {
      'script': script,
      'label': label,
      'description': description,
      'background': background,
      'waitForResultMs': waitForResultMs,
    });

    if (result == null) {
      return const TermuxCommandResult(
        accepted: false,
        completed: true,
        pending: false,
        errorMessage: 'No response returned from Termux bridge',
      );
    }

    return TermuxCommandResult.fromMap(result);
  }

  String get noRootInstallScript => '''
pkg update -y && pkg upgrade -y
pkg install -y nodejs termux-api
termux-setup-storage
npm install -g openclaw --unsafe-perm
''';

  String get startGatewayScript => 'openclaw gateway start --port 18789';

  String get stopGatewayScript => 'openclaw gateway stop';

  String get statusScript => 'openclaw status';

  String get allowExternalAppsSetupScript => '''
mkdir -p ~/.termux
if [ -f ~/.termux/termux.properties ] && grep -q '^allow-external-apps=' ~/.termux/termux.properties; then
  sed -i 's/^allow-external-apps=.*/allow-external-apps=true/' ~/.termux/termux.properties
else
  printf '\\nallow-external-apps=true\\n' >> ~/.termux/termux.properties
fi
termux-reload-settings
''';
}
