import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

/// Session model for managing conversation sessions
class Session {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String? modelId;
  final int totalTokens;
  final Map<String, dynamic>? metadata;

  Session({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.modelId,
    this.totalTokens = 0,
    this.metadata,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? 'New Session',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      messages: (json['messages'] as List?)
          ?.map((m) => ChatMessage.fromJson(m))
          .toList() ?? [],
      modelId: json['modelId'],
      totalTokens: json['totalTokens'] ?? 0,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'modelId': modelId,
    'totalTokens': totalTokens,
    'metadata': metadata,
  };

  Session copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    String? modelId,
    int? totalTokens,
    Map<String, dynamic>? metadata,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      modelId: modelId ?? this.modelId,
      totalTokens: totalTokens ?? this.totalTokens,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Service for managing multiple conversation sessions
class SessionService {
  static const String _sessionsKey = 'duckbot_sessions';
  static const String _activeSessionKey = 'duckbot_active_session';
  
  final Uuid _uuid = const Uuid();
  List<Session> _sessions = [];
  Session? _activeSession;
  
  List<Session> get sessions => List.unmodifiable(_sessions);
  Session? get activeSession => _activeSession;
  
  // Stream controllers for reactive updates
  final StreamController<List<Session>> _sessionsController = 
      StreamController<List<Session>>.broadcast();
  final StreamController<Session?> _activeSessionController = 
      StreamController<Session?>.broadcast();
  
  Stream<List<Session>> get sessionsStream => _sessionsController.stream;
  Stream<Session?> get activeSessionStream => _activeSessionController.stream;

  /// Initialize the service and load sessions from storage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load sessions
    final sessionsJson = prefs.getString(_sessionsKey);
    if (sessionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(sessionsJson);
        _sessions = decoded.map((s) => Session.fromJson(s)).toList();
      } catch (e) {
        _sessions = [];
      }
    }
    
    // Load active session
    final activeId = prefs.getString(_activeSessionKey);
    if (activeId != null) {
      _activeSession = _sessions.where((s) => s.id == activeId).firstOrNull;
    }
    
    // Create default session if none exist
    if (_sessions.isEmpty) {
      await createSession(name: 'Default Session');
    }
    
    // Set first session as active if none selected
    if (_activeSession == null && _sessions.isNotEmpty) {
      _activeSession = _sessions.first;
    }
    
    _notifyListeners();
  }

  /// Create a new session
  Future<Session> createSession({
    String? name,
    String? modelId,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final session = Session(
      id: _uuid.v4(),
      name: name ?? 'Session ${_sessions.length + 1}',
      createdAt: now,
      updatedAt: now,
      modelId: modelId,
      metadata: metadata,
    );
    
    _sessions.insert(0, session);
    await _saveSessions();
    _notifyListeners();
    
    return session;
  }

  /// Switch to a different session
  Future<void> switchSession(String sessionId) async {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session != null) {
      _activeSession = session;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSessionKey, sessionId);
      _activeSessionController.add(_activeSession);
    }
  }

  /// Update a session
  Future<void> updateSession(Session updatedSession) async {
    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _sessions[index] = updatedSession;
      if (_activeSession?.id == updatedSession.id) {
        _activeSession = updatedSession;
      }
      await _saveSessions();
      _notifyListeners();
    }
  }

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    
    // If deleted session was active, switch to another
    if (_activeSession?.id == sessionId) {
      _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
      final prefs = await SharedPreferences.getInstance();
      if (_activeSession != null) {
        await prefs.setString(_activeSessionKey, _activeSession!.id);
      } else {
        await prefs.remove(_activeSessionKey);
      }
    }
    
    await _saveSessions();
    _notifyListeners();
  }

  /// Reset/clear a session's context
  Future<void> resetSession(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index] = _sessions[index].copyWith(
        messages: [],
        totalTokens: 0,
        updatedAt: DateTime.now(),
      );
      if (_activeSession?.id == sessionId) {
        _activeSession = _sessions[index];
      }
      await _saveSessions();
      _notifyListeners();
    }
  }

  /// Compact a session (summarize context)
  Future<void> compactSession(String sessionId, String summary) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _sessions[index];
      final systemMessage = ChatMessage(
        id: _uuid.v4(),
        role: 'system',
        content: '[Context Summary]\n$summary',
        timestamp: DateTime.now(),
      );
      
      _sessions[index] = session.copyWith(
        messages: [systemMessage],
        totalTokens: (summary.length / 4).round(), // Rough token estimate
        updatedAt: DateTime.now(),
      );
      
      if (_activeSession?.id == sessionId) {
        _activeSession = _sessions[index];
      }
      await _saveSessions();
      _notifyListeners();
    }
  }

  /// Add a message to the active session
  Future<void> addMessage(ChatMessage message) async {
    if (_activeSession == null) return;
    
    final updatedMessages = [..._activeSession!.messages, message];
    final tokenEstimate = message.content.length ~/ 4;
    
    _activeSession = _activeSession!.copyWith(
      messages: updatedMessages,
      totalTokens: _activeSession!.totalTokens + tokenEstimate,
      updatedAt: DateTime.now(),
    );
    
    final index = _sessions.indexWhere((s) => s.id == _activeSession!.id);
    if (index != -1) {
      _sessions[index] = _activeSession!;
    }
    
    await _saveSessions();
    _activeSessionController.add(_activeSession);
  }

  /// Export session to JSON
  String exportSession(String sessionId) {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return '{}';
    
    return JsonEncoder.withIndent('  ').convert(session.toJson());
  }

  /// Import session from JSON
  Future<Session?> importSession(String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final session = Session.fromJson(json);
      
      // Generate new ID to avoid conflicts
      final newSession = session.copyWith(
        id: _uuid.v4(),
        name: '${session.name} (Imported)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _sessions.insert(0, newSession);
      await _saveSessions();
      _notifyListeners();
      
      return newSession;
    } catch (e) {
      return null;
    }
  }

  /// Save sessions to storage
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, json);
  }

  /// Notify listeners of changes
  void _notifyListeners() {
    _sessionsController.add(List.unmodifiable(_sessions));
    _activeSessionController.add(_activeSession);
  }

  /// Dispose resources
  void dispose() {
    _sessionsController.close();
    _activeSessionController.close();
  }
}