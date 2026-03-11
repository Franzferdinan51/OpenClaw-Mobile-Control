import 'package:flutter/services.dart';

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
    final result = await _channel.invokeMethod<bool>('runCommand', {
      'script': script,
      'label': label,
      'description': description,
      'background': background,
    });

    return result ?? false;
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
}
