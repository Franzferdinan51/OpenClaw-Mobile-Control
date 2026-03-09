/// Intent Parser for Natural Language Commands
/// 
/// Parses natural language commands into structured API calls.
/// Supports commands like:
/// - "check status" → GET /status
/// - "send message hello" → POST /chat/send
/// - "restart gateway" → POST /control/restart
/// - "get logs" → GET /logs
/// - "pause all agents" → POST /control/pause-all
/// 
/// Features:
/// - Fuzzy matching for commands
/// - Parameter extraction
/// - Multi-command support
/// - Confidence scoring

/// Intent parsing result
class IntentResult {
  final String action;
  final String endpoint;
  final String method;
  final Map<String, dynamic> params;
  final double confidence;
  final String? error;
  final String? suggestion;

  const IntentResult({
    required this.action,
    required this.endpoint,
    required this.method,
    this.params = const {},
    this.confidence = 1.0,
    this.error,
    this.suggestion,
  });

  bool get isError => error != null;

  Map<String, dynamic> toJson() => {
    'action': action,
    'endpoint': endpoint,
    'method': method,
    'params': params,
    'confidence': confidence,
    if (error != null) 'error': error,
    if (suggestion != null) 'suggestion': suggestion,
  };
}

/// Intent Parser
class IntentParser {
  // Command patterns with aliases
  static const Map<String, List<String>> _commandPatterns = {
    'status': [
      'status',
      'check status',
      'get status',
      'show status',
      'what\'s the status',
      'how is everything',
      'health check',
      'system status',
      'gateway status',
      'agent status',
      'check health',
    ],
    'logs': [
      'logs',
      'get logs',
      'show logs',
      'view logs',
      'recent logs',
      'log entries',
      'activity log',
      'error logs',
      'debug logs',
    ],
    'restart': [
      'restart',
      'restart gateway',
      'restart server',
      'reboot gateway',
      'restart openclaw',
    ],
    'stop': [
      'stop',
      'stop gateway',
      'shutdown gateway',
      'stop server',
    ],
    'kill-agent': [
      'kill agent',
      'stop agent',
      'terminate agent',
      'end agent',
      'kill session',
      'stop session',
    ],
    'pause-all': [
      'pause all',
      'pause agents',
      'pause all agents',
      'hold agents',
      'freeze agents',
    ],
    'resume-all': [
      'resume all',
      'resume agents',
      'resume all agents',
      'unfreeze agents',
      'continue agents',
    ],
    'chat': [
      'send message',
      'chat',
      'tell',
      'say',
      'message',
      'ask',
    ],
    'action': [
      'run action',
      'execute action',
      'do action',
      'trigger',
      'fire',
    ],
    'settings': [
      'settings',
      'get settings',
      'show settings',
      'update settings',
      'change settings',
    ],
  };

  // Quick action aliases
  static const Map<String, String> _actionAliases = {
    'grow': 'grow-status',
    'grow status': 'grow-status',
    'grow room': 'grow-status',
    'weather': 'weather-check',
    'weather check': 'weather-check',
    'news': 'news-brief',
    'news brief': 'news-brief',
    'headlines': 'news-brief',
    'health': 'system-health',
    'system health': 'system-health',
    'backup': 'backup-now',
    'backup now': 'backup-now',
    'create backup': 'backup-now',
  };

  /// Parse natural language command
  IntentResult parse(String input) {
    final normalized = input.toLowerCase().trim();
    
    if (normalized.isEmpty) {
      return IntentResult(
        action: 'unknown',
        endpoint: '',
        method: '',
        error: 'Empty command',
        suggestion: 'Try: status, logs, restart, send message <text>',
      );
    }

    // Try each command pattern
    for (final entry in _commandPatterns.entries) {
      final action = entry.key;
      final patterns = entry.value;
      
      for (final pattern in patterns) {
        if (normalized == pattern || normalized.startsWith('$pattern ')) {
          return _buildResult(action, normalized.substring(pattern.length).trim());
        }
        
        // Fuzzy match for similar commands
        final similarity = _calculateSimilarity(normalized, pattern);
        if (similarity > 0.8) {
          return _buildResult(action, '');
        }
      }
    }

    // Check for "send message" pattern with embedded text
    final chatMatch = RegExp(r'^(?:send\s+)?(?:message|chat|tell|say|ask)\s+(.+)$').firstMatch(normalized);
    if (chatMatch != null) {
      return IntentResult(
        action: 'chat',
        endpoint: '/chat/send',
        method: 'POST',
        params: {'message': chatMatch.group(1)},
        confidence: 0.9,
      );
    }

    // Check for action triggers
    for (final alias in _actionAliases.entries) {
      if (normalized.contains(alias.key)) {
        return IntentResult(
          action: 'action',
          endpoint: '/action/execute',
          method: 'POST',
          params: {'action': alias.value},
          confidence: 0.85,
        );
      }
    }

    // Check for log level filtering
    final logMatch = RegExp(r'^(?:get\s+)?(\w+)\s+logs?$').firstMatch(normalized);
    if (logMatch != null) {
      final level = logMatch.group(1);
      if (['error', 'warn', 'warning', 'info', 'debug'].contains(level)) {
        return IntentResult(
          action: 'logs',
          endpoint: '/logs',
          method: 'GET',
          params: {'level': level == 'warning' ? 'warn' : level},
          confidence: 0.9,
        );
      }
    }

    // Unknown command - provide suggestions
    return IntentResult(
      action: 'unknown',
      endpoint: '',
      method: '',
      error: 'Unknown command: "$input"',
      suggestion: _getSuggestion(normalized),
    );
  }

  /// Build result for matched action
  IntentResult _buildResult(String action, String remainder) {
    switch (action) {
      case 'status':
        return IntentResult(
          action: 'status',
          endpoint: '/status',
          method: 'GET',
        );
        
      case 'logs':
        return IntentResult(
          action: 'logs',
          endpoint: '/logs',
          method: 'GET',
          params: _parseLogParams(remainder),
        );
        
      case 'restart':
        return IntentResult(
          action: 'restart',
          endpoint: '/control/restart',
          method: 'POST',
          params: {'reason': remainder.isNotEmpty ? remainder : 'Intent command'},
        );
        
      case 'stop':
        return IntentResult(
          action: 'stop',
          endpoint: '/control/stop',
          method: 'POST',
          params: {'reason': remainder.isNotEmpty ? remainder : 'Intent command'},
        );
        
      case 'kill-agent':
        final sessionKey = _extractSessionKey(remainder);
        return IntentResult(
          action: 'kill-agent',
          endpoint: '/control/kill-agent',
          method: 'POST',
          params: {'session_key': sessionKey},
          error: sessionKey == null ? 'Session key required (e.g., "kill agent main")' : null,
          suggestion: sessionKey == null ? 'Try: kill agent <session_key>' : null,
        );
        
      case 'pause-all':
        final holdSeconds = _extractDuration(remainder);
        return IntentResult(
          action: 'pause-all',
          endpoint: '/control/pause-all',
          method: 'POST',
          params: {'hold_seconds': holdSeconds},
        );
        
      case 'resume-all':
        return IntentResult(
          action: 'resume-all',
          endpoint: '/control/resume-all',
          method: 'POST',
        );
        
      case 'chat':
        if (remainder.isNotEmpty) {
          return IntentResult(
            action: 'chat',
            endpoint: '/chat/send',
            method: 'POST',
            params: {'message': remainder},
          );
        }
        return IntentResult(
          action: 'chat',
          endpoint: '/chat/send',
          method: 'POST',
          error: 'Message required',
          suggestion: 'Try: send message <your message>',
        );
        
      case 'action':
        final actionName = _extractAction(remainder);
        if (actionName != null) {
          return IntentResult(
            action: 'action',
            endpoint: '/action/execute',
            method: 'POST',
            params: {'action': actionName},
          );
        }
        return IntentResult(
          action: 'action',
          endpoint: '/action/execute',
          method: 'POST',
          error: 'Action name required',
          suggestion: 'Try: run action grow-status, execute action weather-check',
        );
        
      case 'settings':
        return IntentResult(
          action: 'settings',
          endpoint: '/settings',
          method: 'GET',
        );
        
      default:
        return IntentResult(
          action: action,
          endpoint: '/$action',
          method: 'GET',
        );
    }
  }

  /// Parse log parameters
  Map<String, dynamic> _parseLogParams(String remainder) {
    final params = <String, dynamic>{};
    
    // Check for level
    for (final level in ['error', 'warn', 'info', 'debug']) {
      if (remainder.contains(level)) {
        params['level'] = level;
        break;
      }
    }
    
    // Check for limit
    final limitMatch = RegExp(r'(\d+)').firstMatch(remainder);
    if (limitMatch != null) {
      params['limit'] = int.parse(limitMatch.group(1)!);
    }
    
    return params;
  }

  /// Extract session key from text
  String? _extractSessionKey(String text) {
    if (text.isEmpty) return null;
    
    // Look for "session X" pattern
    final sessionMatch = RegExp(r'session\s+(\S+)').firstMatch(text);
    if (sessionMatch != null) {
      return sessionMatch.group(1);
    }
    
    // Return the first word as session key
    final words = text.split(RegExp(r'\s+'));
    if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0];
    }
    
    return null;
  }

  /// Extract duration in seconds from text
  int _extractDuration(String text) {
    if (text.isEmpty) return 60;
    
    // Look for "X seconds" or "X minutes"
    final minuteMatch = RegExp(r'(\d+)\s*(?:minute|min|m)').firstMatch(text);
    if (minuteMatch != null) {
      return int.parse(minuteMatch.group(1)!) * 60;
    }
    
    final secondMatch = RegExp(r'(\d+)\s*(?:second|sec|s)').firstMatch(text);
    if (secondMatch != null) {
      return int.parse(secondMatch.group(1)!);
    }
    
    // Just a number
    final numberMatch = RegExp(r'(\d+)').firstMatch(text);
    if (numberMatch != null) {
      return int.parse(numberMatch.group(1)!);
    }
    
    return 60;
  }

  /// Extract action name from text
  String? _extractAction(String text) {
    if (text.isEmpty) return null;
    
    // Check action aliases first
    final normalized = text.toLowerCase().trim();
    if (_actionAliases.containsKey(normalized)) {
      return _actionAliases[normalized];
    }
    
    // Check for known action names
    for (final alias in _actionAliases.values) {
      if (normalized.contains(alias)) {
        return alias;
      }
    }
    
    // Return the last word(s) as action name
    final words = text.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      return words.last.replaceAll('-', '-');
    }
    
    return null;
  }

  /// Calculate string similarity (0.0 to 1.0)
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    // Simple Levenshtein-based similarity
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    
    if (longer.contains(shorter)) {
      return shorter.length / longer.length;
    }
    
    // Character-based similarity
    int matches = 0;
    for (int i = 0; i < shorter.length; i++) {
      if (i < longer.length && shorter[i] == longer[i]) {
        matches++;
      }
    }
    
    return matches / longer.length;
  }

  /// Get suggestion for unknown command
  String _getSuggestion(String input) {
    // Find closest match
    String? bestMatch;
    double bestScore = 0;
    
    for (final patterns in _commandPatterns.values) {
      for (final pattern in patterns) {
        final score = _calculateSimilarity(input, pattern);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = pattern;
        }
      }
    }
    
    if (bestMatch != null && bestScore > 0.3) {
      return 'Did you mean: "$bestMatch"?';
    }
    
    return 'Available commands: status, logs, restart, stop, pause all, resume all, send message <text>';
  }

  /// Parse and get help text
  static String getHelpText() {
    return '''
Available Natural Language Commands:

📊 Status:
  - "check status" / "get status" / "status"
  - "health check" / "system status"
  
📝 Logs:
  - "get logs" / "show logs" / "logs"
  - "error logs" / "debug logs"
  - "last 50 logs"
  
🔄 Control:
  - "restart gateway" / "restart"
  - "stop gateway" / "stop"
  - "pause all agents" / "pause all"
  - "resume all agents" / "resume all"
  - "kill agent <session>"
  
💬 Chat:
  - "send message hello"
  - "chat how are you"
  - "tell the agent to check status"
  
⚡ Actions:
  - "run action grow-status"
  - "check grow room" / "grow status"
  - "get weather" / "weather check"
  - "news brief" / "get headlines"
  
⚙️ Settings:
  - "get settings" / "settings"
''';
  }
}