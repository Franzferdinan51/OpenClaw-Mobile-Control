#!/usr/bin/env dart
/// OpenClaw Mobile CLI
/// 
/// Command-line interface for controlling OpenClaw Mobile from Termux
/// 
/// Usage:
///   dart openclaw_mobile.dart <command> [arguments]
/// 
/// Commands:
///   status              - Get gateway/agent/node status
///   chat <message>     - Send chat message (requires --session)
///   action <name>      - Execute quick action
///   control <action>  - Control gateway (restart, stop, kill-agent, etc.)
///   logs               - Get recent logs
///   settings           - Get/update settings
///   intent <command>  - Parse and execute natural language command
///   serve              - Start API/WebSocket servers
///   help               - Show this help message
/// 
/// Examples:
///   dart openclaw_mobile.dart status
///   dart openclaw_mobile.dart chat "hello" --session main
///   dart openclaw_mobile.dart control restart --reason "maintenance"
///   dart openclaw_mobile.dart logs --limit 50
///   dart openclaw_mobile.dart intent "check gateway status"
///   dart openclaw_mobile.dart serve --port 8765

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// CLI entry point
void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    printHelp();
    exit(1);
  }

  final command = arguments[0];
  final args = arguments.sublist(1);

  // Default configuration
  final config = _loadConfig();
  final baseUrl = config['gateway_url'] ?? 'http://localhost:18789';
  final apiUrl = config['api_url'] ?? 'http://localhost:8765';
  final token = config['token'];
  
  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  try {
    switch (command) {
      case 'status':
        await getStatus(apiUrl, headers);
        break;
      
      case 'chat':
        final message = args.join(' ');
        final session = _getArg(args, '--session') ?? 'main';
        await sendChat(apiUrl, headers, session, message);
        break;
      
      case 'action':
        if (args.isEmpty) {
          print('Error: action name required');
          print('Usage: openclaw-mobile action <name>');
          exit(1);
        }
        await executeAction(apiUrl, headers, args[0], _parseParams(args));
        break;
      
      case 'control':
        if (args.isEmpty) {
          print('Error: control action required');
          print('Usage: openclaw-mobile control <restart|stop|kill-agent|pause-all|resume-all>');
          exit(1);
        }
        await controlAction(apiUrl, headers, args[0], _parseParams(args));
        break;
      
      case 'logs':
        final limit = int.tryParse(_getArg(args, '--limit') ?? '100') ?? 100;
        final level = _getArg(args, '--level');
        await getLogs(apiUrl, headers, limit, level);
        break;
      
      case 'settings':
        if (args.isEmpty || args[0] == 'get') {
          await getSettings(apiUrl, headers);
        } else if (args[0] == 'update') {
          await updateSettings(apiUrl, headers, _parseParams(args));
        }
        break;
      
      case 'intent':
        final commandText = args.join(' ');
        await parseIntent(apiUrl, headers, commandText);
        break;
      
      case 'serve':
        final port = int.tryParse(_getArg(args, '--port') ?? '8765') ?? 8765;
        await startServer(port);
        break;
      
      case 'help':
      case '--help':
      case '-h':
        printHelp();
        break;
      
      default:
        print('Unknown command: $command');
        printHelp();
        exit(1);
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

/// Get status
Future<void> getStatus(String apiUrl, Map<String, String> headers) async {
  print('Fetching status from $apiUrl...\n');
  
  final response = await http.get(
    Uri.parse('$apiUrl/status'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Send chat message
Future<void> sendChat(String apiUrl, Map<String, String> headers, String session, String message) async {
  print('Sending message to session "$session": $message\n');
  
  final response = await http.post(
    Uri.parse('$apiUrl/chat/send'),
    headers: headers,
    body: jsonEncode({
      'session_key': session,
      'message': message,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print(data['ok'] == true ? '✅ Message sent successfully' : '❌ Failed to send message');
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Execute action
Future<void> executeAction(String apiUrl, Map<String, String> headers, String action, Map<String, dynamic> params) async {
  print('Executing action: $action\n');
  
  final response = await http.post(
    Uri.parse('$apiUrl/action/execute'),
    headers: headers,
    body: jsonEncode({
      'action': action,
      'params': params,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Control action
Future<void> controlAction(String apiUrl, Map<String, String> headers, String action, Map<String, dynamic> params) async {
  print('Control action: $action\n');
  
  String endpoint;
  Map<String, dynamic> body = {};
  
  switch (action) {
    case 'restart':
      endpoint = '/control/restart';
      body['reason'] = params['reason'] ?? 'CLI request';
      break;
    case 'stop':
      endpoint = '/control/stop';
      body['reason'] = params['reason'] ?? 'CLI request';
      break;
    case 'kill-agent':
      endpoint = '/control/kill-agent';
      body['session_key'] = params['session_key'] ?? params['session'];
      if (body['session_key'] == null) {
        print('Error: --session required for kill-agent');
        exit(1);
      }
      break;
    case 'pause-all':
    case 'pause':
      endpoint = '/control/pause-all';
      body['hold_seconds'] = int.tryParse(params['hold_seconds']?.toString() ?? '60') ?? 60;
      break;
    case 'resume-all':
    case 'resume':
      endpoint = '/control/resume-all';
      break;
    default:
      print('Unknown control action: $action');
      print('Available: restart, stop, kill-agent, pause-all, resume-all');
      exit(1);
  }
  
  final response = await http.post(
    Uri.parse('$apiUrl$endpoint'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Get logs
Future<void> getLogs(String apiUrl, Map<String, String> headers, int limit, String? level) async {
  print('Fetching logs (limit: $limit${level != null ? ', level: $level' : ''})...\n');
  
  final uri = Uri.parse('$apiUrl/logs').replace(queryParameters: {
    'limit': limit.toString(),
    if (level != null) 'level': level,
  });
  
  final response = await http.get(uri, headers: headers);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Get settings
Future<void> getSettings(String apiUrl, Map<String, String> headers) async {
  print('Fetching settings...\n');
  
  final response = await http.get(
    Uri.parse('$apiUrl/settings'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Update settings
Future<void> updateSettings(String apiUrl, Map<String, String> headers, Map<String, dynamic> params) async {
  print('Updating settings...\n');
  
  final response = await http.post(
    Uri.parse('$apiUrl/settings/update'),
    headers: headers,
    body: jsonEncode(params),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    _printJson(data);
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}

/// Parse intent
Future<void> parseIntent(String apiUrl, Map<String, String> headers, String command) async {
  print('Parsing intent: "$command"\n');
  
  // Use the intent parser endpoint
  final response = await http.get(
    Uri.parse('$apiUrl/action/list'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    
    // Simple keyword matching for CLI
    final lowerCommand = command.toLowerCase();
    
    if (lowerCommand.contains('status') || lowerCommand.contains('health')) {
      await getStatus(apiUrl, headers);
    } else if (lowerCommand.contains('log')) {
      await getLogs(apiUrl, headers, 50, null);
    } else if (lowerCommand.contains('restart')) {
      await controlAction(apiUrl, headers, 'restart', {'reason': 'CLI intent'});
    } else if (lowerCommand.contains('pause')) {
      await controlAction(apiUrl, headers, 'pause-all', {});
    } else if (lowerCommand.contains('resume')) {
      await controlAction(apiUrl, headers, 'resume-all', {});
    } else if (lowerCommand.contains('agent')) {
      print('Available agent commands:');
      print('  - kill-agent --session <key>');
    } else {
      print('Could not understand command. Available commands:');
      print('  - status');
      print('  - logs');
      print('  - control restart');
      print('  - control pause-all');
      print('  - control resume-all');
    }
  }
}

/// Start server (placeholder - requires Flutter run)
Future<void> startServer(int port) async {
  print('Starting API server on port $port...');
  print('');
  print('To start the API server, run the app and enable Agent Control API in settings.');
  print('The API will be available at http://localhost:$port');
}

/// Helper to get named argument
String? _getArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index >= 0 && index < args.length - 1) {
    return args[index + 1];
  }
  // Also check for = syntax
  for (final arg in args) {
    if (arg.startsWith('$name=')) {
      return arg.substring(name.length + 1);
    }
  }
  return null;
}

/// Parse key=value parameters
Map<String, dynamic> _parseParams(List<String> args) {
  final params = <String, dynamic>{};
  for (final arg in args) {
    if (arg.startsWith('--')) {
      final parts = arg.substring(2).split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }
  }
  return params;
}

/// Load configuration from file
Map<String, String> _loadConfig() {
  final configFile = File('${_configDir()}/config.json');
  if (configFile.existsSync()) {
    try {
      return Map<String, String>.from(jsonDecode(configFile.readAsStringSync()));
    } catch (e) {
      // Ignore parse errors
    }
  }
  return {};
}

/// Get config directory
String _configDir() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  return '$home/.openclaw-mobile';
}

/// Print JSON nicely
void _printJson(dynamic data) {
  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(data));
}

/// Print help
void printHelp() {
  print('''
🦆 OpenClaw Mobile CLI v1.5.0

Usage:
  openclaw-mobile <command> [arguments]

Commands:
  status                    Get gateway/agent/node status
  chat <message>           Send chat message (use --session for specific agent)
  action <name>            Execute quick action
  control <action>         Control gateway (restart, stop, kill-agent, etc.)
  logs                     Get recent logs (use --limit and --level)
  settings [get|update]    Get or update settings
  intent <command>         Parse and execute natural language command
  serve                    Start API/WebSocket servers
  help                     Show this help message

Options:
  --session=<key>          Specify agent session key
  --limit=<n>              Limit number of results (for logs)
  --level=<level>          Filter logs by level (debug, info, warn, error)
  --reason=<text>          Reason for gateway restart/stop
  --port=<n>               API server port (default: 8765)

Examples:
  openclaw-mobile status
  openclaw-mobile chat "hello world" --session=main
  openclaw-mobile control restart --reason="maintenance"
  openclaw-mobile logs --limit=50 --level=error
  openclaw-mobile intent "check gateway status"
  openclaw-mobile settings get

Environment Variables:
  OPENCLAW_API_URL     API server URL (default: http://localhost:8765)
  OPENCLAW_TOKEN       API authentication token
''');
}