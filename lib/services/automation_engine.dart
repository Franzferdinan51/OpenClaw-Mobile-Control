import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../services/event_bus.dart';

/// Automation condition types
enum ConditionType {
  gatewayOnline,
  gatewayOffline,
  timeOfDay,
  interval,
  locationArrive,
  locationLeave,
  batteryBelow,
  wifiConnected,
  wifiDisconnected,
}

/// Automation action types
enum ActionType {
  sendNotification,
  executeWebhook,
  runScript,
  checkGateway,
  sendMessage,
  startAgent,
  stopAgent,
  toggleSetting,
}

/// Automation condition
class AutomationCondition {
  final String id;
  final ConditionType type;
  final Map<String, dynamic> parameters;
  bool isMet;

  AutomationCondition({
    required this.id,
    required this.type,
    required this.parameters,
    this.isMet = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'parameters': parameters,
    'isMet': isMet,
  };

  factory AutomationCondition.fromJson(Map<String, dynamic> json) => AutomationCondition(
    id: json['id'],
    type: ConditionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ConditionType.gatewayOnline,
    ),
    parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    isMet: json['isMet'] ?? false,
  );
}

/// Automation action
class AutomationAction {
  final String id;
  final ActionType type;
  final Map<String, dynamic> parameters;

  AutomationAction({
    required this.id,
    required this.type,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'parameters': parameters,
  };

  factory AutomationAction.fromJson(Map<String, dynamic> json) => AutomationAction(
    id: json['id'],
    type: ActionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ActionType.sendNotification,
    ),
    parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
  );
}

/// Complete automation rule
class AutomationRule {
  final String id;
  final String name;
  final String? description;
  final AutomationCondition? condition;
  final String? schedule; // cron expression
  final int? intervalMinutes;
  final List<AutomationAction> actions;
  final bool enabled;
  final DateTime? lastTriggered;
  final DateTime createdAt;

  AutomationRule({
    required this.id,
    required this.name,
    this.description,
    this.condition,
    this.schedule,
    this.intervalMinutes,
    required this.actions,
    this.enabled = true,
    this.lastTriggered,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'condition': condition?.toJson(),
    'schedule': schedule,
    'intervalMinutes': intervalMinutes,
    'actions': actions.map((a) => a.toJson()).toList(),
    'enabled': enabled,
    'lastTriggered': lastTriggered?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    condition: json['condition'] != null 
      ? AutomationCondition.fromJson(json['condition']) 
      : null,
    schedule: json['schedule'],
    intervalMinutes: json['intervalMinutes'],
    actions: (json['actions'] as List<dynamic>?)
        ?.map((a) => AutomationAction.fromJson(a))
        .toList() ?? [],
    enabled: json['enabled'] ?? true,
    lastTriggered: json['lastTriggered'] != null 
      ? DateTime.tryParse(json['lastTriggered']) 
      : null,
    createdAt: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt']) 
      : DateTime.now(),
  );

  AutomationRule copyWith({
    String? id,
    String? name,
    String? description,
    AutomationCondition? condition,
    String? schedule,
    int? intervalMinutes,
    List<AutomationAction>? actions,
    bool? enabled,
    DateTime? lastTriggered,
    DateTime? createdAt,
  }) => AutomationRule(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    condition: condition ?? this.condition,
    schedule: schedule ?? this.schedule,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    actions: actions ?? this.actions,
    enabled: enabled ?? this.enabled,
    lastTriggered: lastTriggered ?? this.lastTriggered,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Automation engine - manages scheduled actions and conditions
class AutomationEngine {
  static final AutomationEngine _instance = AutomationEngine._internal();
  factory AutomationEngine() => _instance;
  AutomationEngine._internal();

  final Uuid _uuid = const Uuid();
  final EventBus _eventBus = EventBus();
  
  List<AutomationRule> _rules = [];
  final Map<String, Timer> _intervalTimers = {};
  bool _isRunning = false;
  
  /// Callback for executing actions
  Function(AutomationAction action)? onExecuteAction;
  
  /// Callback for checking gateway status
  Future<bool> Function()? onCheckGateway;

  List<AutomationRule> get rules => _rules;
  bool get isRunning => _isRunning;

  /// Initialize automation engine
  Future<void> initialize() async {
    await _loadRules();
    
    // Set up event listeners
    _eventBus.events.listen(_handleEvent);
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getString('automation_rules');
    if (rulesJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rulesJson);
        _rules = list.map((e) => AutomationRule.fromJson(e)).toList();
      } catch (e) {
        print('Error loading automation rules: $e');
      }
    }
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('automation_rules', jsonEncode(_rules.map((r) => r.toJson()).toList()));
  }

  /// Add automation rule
  Future<void> addRule(AutomationRule rule) async {
    _rules.add(rule);
    await _saveRules();
    if (_isRunning && rule.enabled) {
      _startRuleTimers(rule);
    }
  }

  /// Update automation rule
  Future<void> updateRule(AutomationRule rule) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
      await _saveRules();
      
      // Restart timers if running
      if (_isRunning) {
        _stopRuleTimers(rule.id);
        if (rule.enabled) {
          _startRuleTimers(rule);
        }
      }
    }
  }

  /// Remove automation rule
  Future<void> removeRule(String id) async {
    _stopRuleTimers(id);
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
  }

  /// Start automation engine
  void start() {
    _isRunning = true;
    for (final rule in _rules.where((r) => r.enabled)) {
      _startRuleTimers(rule);
    }
  }

  /// Stop automation engine
  void stop() {
    _isRunning = false;
    for (final timer in _intervalTimers.values) {
      timer.cancel();
    }
    _intervalTimers.clear();
  }

  void _startRuleTimers(AutomationRule rule) {
    // Schedule-based triggers
    if (rule.schedule != null) {
      // In a full implementation, use cron parser
      // For now, support simple intervals
    }

    // Interval-based triggers
    if (rule.intervalMinutes != null && rule.intervalMinutes! > 0) {
      final timer = Timer.periodic(
        Duration(minutes: rule.intervalMinutes!),
        (_) => _triggerRule(rule),
      );
      _intervalTimers[rule.id] = timer;
    }

    // Condition-based triggers are event-driven
  }

  void _stopRuleTimers(String ruleId) {
    _intervalTimers[ruleId]?.cancel();
    _intervalTimers.remove(ruleId);
  }

  void _handleEvent(AppEvent event) async {
    for (final rule in _rules.where((r) => r.enabled && r.condition != null)) {
      if (_evaluateCondition(rule.condition!, event)) {
        await _triggerRule(rule);
      }
    }
  }

  bool _evaluateCondition(AutomationCondition condition, AppEvent event) {
    switch (condition.type) {
      case ConditionType.gatewayOnline:
        return event.type == AppEventType.gatewayOnline;
      case ConditionType.gatewayOffline:
        return event.type == AppEventType.gatewayOffline;
      case ConditionType.timeOfDay:
        // Check if current time matches
        final targetHour = condition.parameters['hour'] as int?;
        final targetMinute = condition.parameters['minute'] as int?;
        if (targetHour != null && targetMinute != null) {
          final now = DateTime.now();
          return now.hour == targetHour && now.minute == targetMinute;
        }
        return false;
      case ConditionType.interval:
        // Handled by timer
        return false;
      case ConditionType.locationArrive:
      case ConditionType.locationLeave:
        // Would need location service
        return false;
      case ConditionType.wifiConnected:
        return event.type == AppEventType.automationTriggered && 
          event.data == 'wifi_connected';
      case ConditionType.wifiDisconnected:
        return event.type == AppEventType.automationTriggered && 
          event.data == 'wifi_disconnected';
      case ConditionType.batteryBelow:
        // Would need battery service - placeholder
        return false;
    }
  }

  Future<void> _triggerRule(AutomationRule rule) async {
    _eventBus.emitScheduleTriggered(rule.id);
    _eventBus.emitAutomationTriggered(rule.id);

    // Update last triggered
    final updated = rule.copyWith(lastTriggered: DateTime.now());
    await updateRule(updated);

    // Execute all actions
    for (final action in rule.actions) {
      await _executeAction(action);
    }
  }

  Future<void> _executeAction(AutomationAction action) async {
    switch (action.type) {
      case ActionType.sendNotification:
        // Would trigger local notification
        print('Action: Send notification - ${action.parameters}');
        break;
      case ActionType.executeWebhook:
        // Would trigger webhook
        print('Action: Execute webhook - ${action.parameters}');
        break;
      case ActionType.runScript:
        // Would run script
        print('Action: Run script - ${action.parameters}');
        break;
      case ActionType.checkGateway:
        if (onCheckGateway != null) {
          final isOnline = await onCheckGateway!();
          _eventBus.emitConditionMet('gateway_check', isOnline);
        }
        break;
      case ActionType.sendMessage:
        print('Action: Send message - ${action.parameters}');
        break;
      case ActionType.startAgent:
        print('Action: Start agent - ${action.parameters}');
        break;
      case ActionType.stopAgent:
        print('Action: Stop agent - ${action.parameters}');
        break;
      case ActionType.toggleSetting:
        print('Action: Toggle setting - ${action.parameters}');
        break;
    }

    // Callback for custom handling
    if (onExecuteAction != null) {
      onExecuteAction!(action);
    }
  }

  /// Manually trigger a rule
  Future<void> triggerRule(String ruleId) async {
    final rule = _rules.firstWhere(
      (r) => r.id == ruleId,
      orElse: () => throw Exception('Rule not found'),
    );
    await _triggerRule(rule);
  }

  /// Create quick action preset rules
  List<AutomationRule> getQuickActionPresets() => [
    AutomationRule(
      id: _uuid.v4(),
      name: 'Check Gateway Every 5 Minutes',
      description: 'Check gateway status every 5 minutes and alert if offline',
      intervalMinutes: 5,
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.checkGateway,
          parameters: {},
        ),
      ],
    ),
    AutomationRule(
      id: _uuid.v4(),
      name: 'Alert on Gateway Offline',
      description: 'Send notification when gateway goes offline',
      condition: AutomationCondition(
        id: _uuid.v4(),
        type: ConditionType.gatewayOffline,
        parameters: {},
      ),
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.sendNotification,
          parameters: {
            'title': 'Gateway Offline',
            'body': 'The OpenClaw gateway is not responding',
          },
        ),
      ],
    ),
    AutomationRule(
      id: _uuid.v4(),
      name: 'Morning Status Check',
      description: 'Check gateway status every morning at 8 AM',
      schedule: '0 8 * * *',
      actions: [
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.checkGateway,
          parameters: {},
        ),
        AutomationAction(
          id: _uuid.v4(),
          type: ActionType.sendNotification,
          parameters: {
            'title': 'Morning Check',
            'body': 'Gateway status check complete',
          },
        ),
      ],
    ),
  ];
}