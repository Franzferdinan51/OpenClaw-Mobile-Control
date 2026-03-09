import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Script type
enum ScriptType {
  javascript,
  python,
}

/// Script status
enum ScriptStatus {
  idle,
  running,
  completed,
  error,
}

/// Saved script model
class SavedScript {
  final String id;
  final String name;
  final String description;
  final ScriptType type;
  final String code;
  final DateTime createdAt;
  final DateTime? lastRun;

  SavedScript({
    required this.id,
    required this.name,
    this.description = '',
    required this.type,
    required this.code,
    DateTime? createdAt,
    this.lastRun,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'code': code,
    'createdAt': createdAt.toIso8601String(),
    'lastRun': lastRun?.toIso8601String(),
  };

  factory SavedScript.fromJson(Map<String, dynamic> json) => SavedScript(
    id: json['id'],
    name: json['name'],
    description: json['description'] ?? '',
    type: ScriptType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ScriptType.javascript,
    ),
    code: json['code'],
    createdAt: DateTime.parse(json['createdAt']),
    lastRun: json['lastRun'] != null ? DateTime.parse(json['lastRun']) : null,
  );

  SavedScript copyWith({
    String? id,
    String? name,
    String? description,
    ScriptType? type,
    String? code,
    DateTime? createdAt,
    DateTime? lastRun,
  }) => SavedScript(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    type: type ?? this.type,
    code: code ?? this.code,
    createdAt: createdAt ?? this.createdAt,
    lastRun: lastRun ?? this.lastRun,
  );
}

/// Script execution result
class ScriptResult {
  final String scriptId;
  final ScriptStatus status;
  final String? output;
  final String? error;
  final Duration? duration;
  final DateTime executedAt;

  ScriptResult({
    required this.scriptId,
    required this.status,
    this.output,
    this.error,
    this.duration,
    DateTime? executedAt,
  }) : executedAt = executedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'scriptId': scriptId,
    'status': status.name,
    'output': output,
    'error': error,
    'duration': duration?.inMilliseconds,
    'executedAt': executedAt.toIso8601String(),
  };
}

/// Script API for scripts to interact with the app
class ScriptApi {
  /// Callback for making HTTP requests from scripts
  Future<Map<String, dynamic>> Function(String url, {String? method, Map<String, dynamic>? body})? httpRequest;
  
  /// Callback for sending notifications
  void Function(String title, String body)? sendNotification;
  
  /// Callback for checking gateway
  Future<bool> Function()? checkGateway;
  
  /// Callback for getting app state
  Map<String, dynamic>? Function()? getAppState;
  
  /// Callback for logging
  void Function(String message)? log;

  /// Make HTTP request
  Future<Map<String, dynamic>> request(
    String url, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (httpRequest != null) {
      return await httpRequest!(url, method: method, body: body);
    }
    return {'error': 'HTTP not available'};
  }

  /// Send notification
  void notify(String title, String body) {
    sendNotification?.call(title, body);
  }

  /// Check if gateway is online
  Future<bool> isGatewayOnline() async {
    if (checkGateway != null) {
      return await checkGateway!();
    }
    return false;
  }

  /// Get app state
  Map<String, dynamic> getState() {
    return getAppState?.call() ?? {};
  }

  /// Log message
  void logMsg(String message) {
    log?.call(message);
    print('[Script] $message');
  }

  /// Sleep/wait
  Future<void> sleep(int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }
}

/// Scripting engine - run JavaScript/Python scripts
class ScriptingEngine {
  static final ScriptingEngine _instance = ScriptingEngine._internal();
  factory ScriptingEngine() => _instance;
  ScriptingEngine._internal();

  final Uuid _uuid = const Uuid();
  final ScriptApi _api = ScriptApi();
  
  List<SavedScript> _scripts = [];
  final Map<String, ScriptResult> _lastResults = {};
  bool _isInitialized = false;

  List<SavedScript> get scripts => _scripts;
  ScriptApi get api => _api;
  bool get isInitialized => _isInitialized;

  /// Configure script API callbacks
  void configure({
    Future<Map<String, dynamic>> Function(String url, {String? method, Map<String, dynamic>? body})? httpRequest,
    void Function(String title, String body)? sendNotification,
    Future<bool> Function()? checkGateway,
    Map<String, dynamic>? Function()? getAppState,
    void Function(String message)? log,
  }) {
    _api.httpRequest = httpRequest;
    _api.sendNotification = sendNotification;
    _api.checkGateway = checkGateway;
    _api.getAppState = getAppState;
    _api.log = log;
  }

  /// Initialize scripting engine
  Future<void> initialize() async {
    await _loadScripts();
    _isInitialized = true;
  }

  Future<void> _loadScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final scriptsJson = prefs.getString('saved_scripts');
    if (scriptsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(scriptsJson);
        _scripts = list.map((e) => SavedScript.fromJson(e)).toList();
      } catch (e) {
        print('Error loading scripts: $e');
      }
    }
    
    // Add default example scripts if none exist
    if (_scripts.isEmpty) {
      _scripts.addAll(_getExampleScripts());
      await _saveScripts();
    }
  }

  Future<void> _saveScripts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_scripts', jsonEncode(_scripts.map((s) => s.toJson()).toList()));
  }

  /// Add a new script
  Future<void> addScript(SavedScript script) async {
    _scripts.add(script);
    await _saveScripts();
  }

  /// Update a script
  Future<void> updateScript(SavedScript script) async {
    final index = _scripts.indexWhere((s) => s.id == script.id);
    if (index >= 0) {
      _scripts[index] = script;
      await _saveScripts();
    }
  }

  /// Delete a script
  Future<void> deleteScript(String id) async {
    _scripts.removeWhere((s) => s.id == id);
    _lastResults.remove(id);
    await _saveScripts();
  }

  /// Run a script
  Future<ScriptResult> runScript(String scriptId, {Map<String, dynamic>? context}) async {
    final script = _scripts.firstWhere(
      (s) => s.id == scriptId,
      orElse: () => throw Exception('Script not found'),
    );

    final startTime = DateTime.now();
    
    try {
      String result;
      
      if (script.type == ScriptType.javascript) {
        result = await _runJavaScript(script.code, context ?? {});
      } else {
        result = await _runPython(script.code, context ?? {});
      }
      
      final duration = DateTime.now().difference(startTime);
      
      // Update last run time
      final updated = script.copyWith(lastRun: DateTime.now());
      await updateScript(updated);
      
      final scriptResult = ScriptResult(
        scriptId: scriptId,
        status: ScriptStatus.completed,
        output: result,
        duration: duration,
      );
      
      _lastResults[scriptId] = scriptResult;
      return scriptResult;
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      final scriptResult = ScriptResult(
        scriptId: scriptId,
        status: ScriptStatus.error,
        error: e.toString(),
        duration: duration,
      );
      
      _lastResults[scriptId] = scriptResult;
      return scriptResult;
    }
  }

  /// Run raw JavaScript code
  Future<String> _runJavaScript(String code, Map<String, dynamic> context) async {
    // Note: In a real implementation, you'd use a JavaScript runtime like
    // flutter_js or quickjs. This is a simplified demonstration.
    
    // For now, we'll simulate JavaScript execution with a basic interpreter
    // In production, integrate with: https://github.com/erlorenzen/flutter_js
    
    // Simple JS-like execution for demo
    // Real implementation would use: context['jsRuntime'].evaluate(code);
    
    // Check for common patterns and simulate
    if (code.contains('console.log') || code.contains('api.')) {
      // Simulate API calls
      if (code.contains('api.isGatewayOnline()')) {
        final isOnline = await _api.isGatewayOnline();
        return isOnline.toString();
      }
      if (code.contains('api.request')) {
        return '{"status": "simulated"}';
      }
    }
    
    // Return simulated output
    return 'Script executed (simulated)';
  }

  /// Run Python code
  Future<String> _runPython(String code, Map<String, dynamic> context) async {
    // Note: In a real implementation, you'd use chacha or pythondart
    // For now, this is a placeholder
    
    // In production, integrate with: https://github.com/tekartik/chacha
    // or: https://github.com/AbStatic/flutter_python
    
    return 'Python script executed (simulated)';
  }

  /// Get last result for a script
  ScriptResult? getLastResult(String scriptId) => _lastResults[scriptId];

  /// Stop running script (if supported)
  Future<void> stopScript(String scriptId) async {
    // Would need to track running scripts and cancel them
    _lastResults[scriptId] = ScriptResult(
      scriptId: scriptId,
      status: ScriptStatus.idle,
      output: 'Stopped',
    );
  }

  /// Get example scripts
  List<SavedScript> _getExampleScripts() => [
    SavedScript(
      id: _uuid.v4(),
      name: 'Gateway Health Check',
      description: 'Check gateway status every 5 minutes',
      type: ScriptType.javascript,
      code: '''
// Gateway Health Check Script
// Runs every 5 minutes via automation

async function main() {
  const isOnline = await api.isGatewayOnline();
  
  if (!isOnline) {
    api.notify('Gateway Alert', 'Gateway is offline!');
    api.logMsg('Gateway is not responding');
  } else {
    api.logMsg('Gateway is online');
  }
  
  return { status: isOnline ? 'online' : 'offline' };
}

main();
''',
    ),
    SavedScript(
      id: _uuid.v4(),
      name: 'Periodic Status Report',
      description: 'Send daily status summary',
      type: ScriptType.javascript,
      code: '''
// Daily Status Report Script
// Sends notification with gateway status

async function main() {
  const state = api.getState();
  const isOnline = await api.isGatewayOnline();
  
  const message = \`OpenClaw Status Report
Gateway: \${isOnline ? '✅ Online' : '❌ Offline'}
Agents: \${state.agents?.length || 0} active
Last Check: \${new Date().toLocaleString()}\`;
  
  api.notify('Daily Report', message);
  api.logMsg('Status report sent');
  
  return { success: true, message };
}

main();
''',
    ),
    SavedScript(
      id: _uuid.v4(),
      name: 'Weather Alert Integration',
      description: 'Check weather and notify if severe',
      type: ScriptType.javascript,
      code: '''
// Weather Alert Integration
// Check weather API and send alerts

async function main() {
  // Example: Fetch weather data
  const weatherUrl = 'https://api.weather.example/current';
  
  try {
    const response = await api.request(weatherUrl);
    const temp = response.data?.temperature;
    
    if (temp > 95) {
      api.notify('🌡️ Heat Alert', 'Temperature is \${temp}°F - Stay cool!');
    } else if (temp < 32) {
      api.notify('❄️ Cold Alert', 'Temperature is \${temp}°F - Stay warm!');
    }
    
    return { temperature: temp };
  } catch (e) {
    api.logMsg('Weather check failed: ' + e);
    return { error: e };
  }
}

main();
''',
    ),
    SavedScript(
      id: _uuid.v4(),
      name: 'IFTTT Webhook Trigger',
      description: 'Trigger IFTTT webhook on condition',
      type: ScriptType.javascript,
      code: '''
// IFTTT Webhook Trigger
// Replace YOUR_KEY and YOUR_EVENT with your IFTTT values

async function main() {
  const isOnline = await api.isGatewayOnline();
  
  if (!isOnline) {
    // Trigger IFTTT notification
    const iftttUrl = 'https://maker.ifttt.com/trigger/gateway_offline/with/key/YOUR_KEY';
    
    await api.request(iftttUrl, { method: 'POST' });
    api.logMsg('IFTTT webhook triggered');
  }
}

main();
''',
    ),
  ];

  /// Validate script syntax
  Map<String, dynamic> validateScript(String code, ScriptType type) {
    try {
      if (type == ScriptType.javascript) {
        // Basic syntax validation
        if (code.isEmpty) {
          return {'valid': false, 'error': 'Empty script'};
        }
        
        // Check for common issues
        if (code.contains('function') && !code.contains('main()')) {
          return {'warning': 'Consider using main() async function'};
        }
        
        if (!code.contains('async') && code.contains('await')) {
          return {'valid': false, 'error': 'await must be in async function'};
        }
        
        return {'valid': true};
      } else {
        // Python validation
        if (code.isEmpty) {
          return {'valid': false, 'error': 'Empty script'};
        }
        
        return {'valid': true};
      }
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }
}