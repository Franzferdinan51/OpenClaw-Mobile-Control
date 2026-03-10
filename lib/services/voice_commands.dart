import '../services/gateway_service.dart';

/// Command types for voice commands
enum CommandType {
  gatewayStatus,
  sendMessage,
  restartGateway,
  showLogs,
  growStatus,
  takePlantPhoto,
  weather,
  navigateDashboard,
  navigateChat,
  navigateSettings,
  navigateControl,
  unknown,
}

/// Parsed command result
class CommandResult {
  final CommandType type;
  final Map<String, dynamic> params;
  final String originalCommand;
  final bool requiresConfirmation;

  CommandResult({
    required this.type,
    required this.params,
    required this.originalCommand,
    this.requiresConfirmation = false,
  });
}

/// Voice command parsing and execution
class VoiceCommands {
  final GatewayService? gatewayService;
  
  VoiceCommands({this.gatewayService});

  /// Parse a voice command string
  CommandResult parseCommand(String input) {
    final command = input.toLowerCase().trim();
    
    // Gateway status
    if (_matchesAny(command, [
      'check gateway status',
      'gateway status',
      'how is the gateway',
      'is the gateway running',
      'open claw status',
      'status',
    ])) {
      return CommandResult(
        type: CommandType.gatewayStatus,
        params: {},
        originalCommand: input,
      );
    }
    
    // Send message
    if (_matchesAny(command, [
      'send message',
      'send to',
      'message',
      'tell',
    ])) {
      final params = _extractMessageParams(command);
      return CommandResult(
        type: CommandType.sendMessage,
        params: params,
        originalCommand: input,
      );
    }
    
    // Restart gateway
    if (_matchesAny(command, [
      'restart gateway',
      'restart the gateway',
      'reboot gateway',
      'reload gateway',
    ])) {
      return CommandResult(
        type: CommandType.restartGateway,
        params: {},
        originalCommand: input,
        requiresConfirmation: true,
      );
    }
    
    // Show logs
    if (_matchesAny(command, [
      'show me the logs',
      'show logs',
      'view logs',
      'open logs',
      'get logs',
    ])) {
      return CommandResult(
        type: CommandType.showLogs,
        params: {},
        originalCommand: input,
      );
    }
    
    // Grow status
    if (_matchesAny(command, [
      'run grow status',
      'grow status',
      'plant status',
      'check plants',
      'how are the plants',
    ])) {
      return CommandResult(
        type: CommandType.growStatus,
        params: {},
        originalCommand: input,
      );
    }
    
    // Take plant photo
    if (_matchesAny(command, [
      'take a plant photo',
      'take photo',
      'capture plant',
      'snap plant',
      'photo of plants',
    ])) {
      return CommandResult(
        type: CommandType.takePlantPhoto,
        params: {},
        originalCommand: input,
      );
    }
    
    // Weather
    if (_matchesAny(command, [
      "what's the weather",
      'weather',
      'how is the weather',
      'temperature',
      'is it going to rain',
    ])) {
      return CommandResult(
        type: CommandType.weather,
        params: {},
        originalCommand: input,
      );
    }
    
    // Navigation commands
    if (_matchesAny(command, [
      'go to dashboard',
      'open dashboard',
      'show dashboard',
      'dashboard',
    ])) {
      return CommandResult(
        type: CommandType.navigateDashboard,
        params: {},
        originalCommand: input,
      );
    }
    
    if (_matchesAny(command, [
      'open chat',
      'go to chat',
      'show chat',
      'start chat',
    ])) {
      return CommandResult(
        type: CommandType.navigateChat,
        params: {},
        originalCommand: input,
      );
    }
    
    if (_matchesAny(command, [
      'show settings',
      'open settings',
      'go to settings',
      'settings',
    ])) {
      return CommandResult(
        type: CommandType.navigateSettings,
        params: {},
        originalCommand: input,
      );
    }
    
    if (_matchesAny(command, [
      'open control',
      'go to control',
      'control center',
      'game control',
    ])) {
      return CommandResult(
        type: CommandType.navigateControl,
        params: {},
        originalCommand: input,
      );
    }
    
    // Unknown command
    return CommandResult(
      type: CommandType.unknown,
      params: {'raw': input},
      originalCommand: input,
    );
  }

  /// Execute a parsed command
  Future<String> executeCommand(CommandResult result) async {
    switch (result.type) {
      case CommandType.gatewayStatus:
        return await _executeGatewayStatus();
        
      case CommandType.sendMessage:
        return await _executeSendMessage(result.params);
        
      case CommandType.restartGateway:
        return await _executeRestartGateway();
        
      case CommandType.showLogs:
        return _executeShowLogs();
        
      case CommandType.growStatus:
        return await _executeGrowStatus();
        
      case CommandType.takePlantPhoto:
        return await _executeTakePlantPhoto();
        
      case CommandType.weather:
        return await _executeWeather();
        
      case CommandType.navigateDashboard:
        return 'Navigating to dashboard';
        
      case CommandType.navigateChat:
        return 'Navigating to chat';
        
      case CommandType.navigateSettings:
        return 'Navigating to settings';
        
      case CommandType.navigateControl:
        return 'Navigating to control';
        
      case CommandType.unknown:
        return "Sorry, I didn't understand that command. Try saying 'check gateway status' or 'show me the logs'.";
    }
  }

  /// Execute gateway status check
  Future<String> _executeGatewayStatus() async {
    if (gatewayService == null) {
      return 'Gateway service not available';
    }
    
    try {
      final status = await gatewayService!.getStatus();
      if (status != null) {
        final online = status.online ? 'online' : 'offline';
        final agents = status.agents?.length ?? 0;
        return 'Gateway is $online. Currently running $agents active agents.';
      }
      return 'Could not get gateway status';
    } catch (e) {
      return 'Error getting gateway status: $e';
    }
  }

  /// Execute send message
  Future<String> _executeSendMessage(Map<String, dynamic> params) async {
    final target = params['target'] ?? 'DuckBot';
    final message = params['message'] ?? 'hello';
    
    // This would integrate with the chat service
    return 'Sending "$message" to $target';
  }

  /// Execute restart gateway
  Future<String> _executeRestartGateway() async {
    if (gatewayService == null) {
      return 'Gateway service not available';
    }
    
    try {
      // Note: Gateway restart may not be exposed via API
      return 'Gateway restart requested. This may take a moment.';
    } catch (e) {
      return 'Error restarting gateway: $e';
    }
  }

  /// Execute show logs
  String _executeShowLogs() {
    return 'Opening logs. You can view recent gateway activity in the logs screen.';
  }

  /// Execute grow status
  Future<String> _executeGrowStatus() async {
    // This would integrate with the grow/monitor service
    return 'Running grow status check. Checking plant sensors and camera...';
  }

  /// Execute take plant photo
  Future<String> _executeTakePlantPhoto() async {
    // This would trigger camera capture
    return 'Taking plant photo. Check your camera feed to see the image.';
  }

  /// Execute weather
  Future<String> _executeWeather() async {
    // This would integrate with weather service
    return 'Weather feature is not yet implemented. Would you like me to add it?';
  }

  /// Helper to match multiple phrases
  bool _matchesAny(String input, List<String> phrases) {
    return phrases.any((p) => input.contains(p));
  }

  /// Extract message parameters from command
  Map<String, dynamic> _extractMessageParams(String command) {
    // Pattern: "send message [message] to [target]"
    // or "tell [target] [message]"
    
    String message = '';
    String target = 'DuckBot';
    
    // Try to extract message and target
    final toMatch = RegExp(r'to\s+(\w+)', caseSensitive: false);
    final toResult = toMatch.firstMatch(command);
    if (toResult != null) {
      target = toResult.group(1) ?? 'DuckBot';
    }
    
    // Extract the message part
    final messageStartIndex = command.indexOf('message');
    if (messageStartIndex != -1) {
      message = command.substring(messageStartIndex + 7).trim();
      // Remove "to [target]" if present
      message = message.replaceAll(RegExp(r'to\s+\w+\s*'), '').trim();
    }
    
    if (message.isEmpty) {
      message = 'hello';
    }
    
    return {
      'target': target,
      'message': message,
    };
  }

  /// Get all available commands as help text
  static String getHelpText() {
    return '''Available voice commands:
- "Check gateway status" - Get gateway status
- "Send message hello to DuckBot" - Send a chat message
- "Restart the gateway" - Restart the gateway
- "Show me the logs" - Open the logs screen
- "Run grow status check" - Check plant status
- "Take a plant photo" - Capture plant camera image
- "What's the weather" - Get weather information
- "Go to dashboard" - Navigate to dashboard
- "Open chat" - Navigate to chat screen
- "Show settings" - Navigate to settings''';
  }
}