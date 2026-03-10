import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model information from the gateway
class ModelInfo {
  final String id;
  final String name;
  final String? provider;
  final int? contextWindow;
  final int? maxTokens;
  final double? costPer1kTokens;
  final String? speed; // 'fast', 'medium', 'slow'
  final List<String>? capabilities;
  final bool isAvailable;

  ModelInfo({
    required this.id,
    required this.name,
    this.provider,
    this.contextWindow,
    this.maxTokens,
    this.costPer1kTokens,
    this.speed,
    this.capabilities,
    this.isAvailable = true,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] ?? json['model'] ?? '',
      name: json['name'] ?? json['model'] ?? 'Unknown Model',
      provider: json['provider'],
      contextWindow: json['contextWindow'] ?? json['context_window'],
      maxTokens: json['maxTokens'] ?? json['max_tokens'],
      costPer1kTokens: (json['costPer1kTokens'] ?? json['cost_per_1k'])?.toDouble(),
      speed: json['speed'],
      capabilities: (json['capabilities'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      isAvailable: json['isAvailable'] ?? json['available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'contextWindow': contextWindow,
    'maxTokens': maxTokens,
    'costPer1kTokens': costPer1kTokens,
    'speed': speed,
    'capabilities': capabilities,
    'isAvailable': isAvailable,
  };

  String get displayName {
    if (provider != null && provider!.isNotEmpty) {
      return '$provider / $name';
    }
    return name;
  }

  String get contextWindowDisplay {
    if (contextWindow == null) return 'Unknown';
    if (contextWindow! >= 1000000) {
      return '${(contextWindow! / 1000000).toStringAsFixed(1)}M';
    }
    return '${(contextWindow! / 1000).toStringAsFixed(0)}K';
  }

  String get costDisplay {
    if (costPer1kTokens == null) return 'N/A';
    return '\$${costPer1kTokens!.toStringAsFixed(4)}/1K';
  }

  IconData get speedIcon {
    switch (speed) {
      case 'fast':
        return Icons.bolt;
      case 'medium':
        return Icons.speed;
      case 'slow':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  Color get speedColor {
    switch (speed) {
      case 'fast':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'slow':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Service for managing model selection and info
class ModelService {
  static const String _selectedModelKey = 'duckbot_selected_model';
  static const String _recentModelsKey = 'duckbot_recent_models';
  
  String baseUrl;
  String? token;
  
  List<ModelInfo> _availableModels = [];
  ModelInfo? _selectedModel;
  List<String> _recentModelIds = [];
  bool _loading = false;
  String? _error;
  
  List<ModelInfo> get availableModels => List.unmodifiable(_availableModels);
  ModelInfo? get selectedModel => _selectedModel;
  List<ModelInfo> get recentModels => _recentModelIds
      .map((id) => _availableModels.where((m) => m.id == id).firstOrNull)
      .whereType<ModelInfo>()
      .toList();
  bool get loading => _loading;
  String? get error => _error;
  
  final StreamController<List<ModelInfo>> _modelsController = 
      StreamController<List<ModelInfo>>.broadcast();
  final StreamController<ModelInfo?> _selectedModelController = 
      StreamController<ModelInfo?>.broadcast();
  
  Stream<List<ModelInfo>> get modelsStream => _modelsController.stream;
  Stream<ModelInfo?> get selectedModelStream => _selectedModelController.stream;

  ModelService({this.baseUrl = 'http://127.0.0.1:18789', this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Initialize the service
  Future<void> initialize() async {
    await _loadSelectedModel();
    await _loadRecentModels();
    await fetchAvailableModels();
  }

  /// Fetch available models from the gateway
  Future<List<ModelInfo>> fetchAvailableModels() async {
    _loading = true;
    _error = null;
    _modelsController.add(_availableModels);

    try {
      // Try to fetch from gateway API
      final response = await http.get(
        Uri.parse('$baseUrl/api/models'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final models = (json['models'] as List?)
            ?.map((m) => ModelInfo.fromJson(m))
            .toList() ?? [];
        
        _availableModels = models;
        _loading = false;
        _modelsController.add(_availableModels);
        return models;
      }
    } catch (e) {
      // Fallback to default models if gateway not available
      _availableModels = _getDefaultModels();
      _loading = false;
      _error = null; // Don't show error for fallback
      _modelsController.add(_availableModels);
      return _availableModels;
    }

    // Fallback to default models
    _availableModels = _getDefaultModels();
    _loading = false;
    _modelsController.add(_availableModels);
    return _availableModels;
  }

  /// Get default models when gateway is unavailable
  List<ModelInfo> _getDefaultModels() {
    return [
      ModelInfo(
        id: 'bailian/qwen3.5-plus',
        name: 'Qwen 3.5 Plus',
        provider: 'Alibaba Bailian',
        contextWindow: 1000000,
        speed: 'fast',
        capabilities: ['chat', 'reasoning', 'code'],
        isAvailable: true,
      ),
      ModelInfo(
        id: 'bailian/MiniMax-M2.5',
        name: 'MiniMax M2.5',
        provider: 'Alibaba Bailian',
        contextWindow: 196000,
        speed: 'fast',
        capabilities: ['chat', 'reasoning'],
        isAvailable: true,
      ),
      ModelInfo(
        id: 'bailian/kimi-k2.5',
        name: 'Kimi K2.5',
        provider: 'Alibaba Bailian',
        contextWindow: 196000,
        speed: 'medium',
        capabilities: ['chat', 'vision', 'reasoning'],
        isAvailable: true,
      ),
      ModelInfo(
        id: 'bailian/glm-5',
        name: 'GLM-5',
        provider: 'Alibaba Bailian',
        contextWindow: 128000,
        speed: 'fast',
        capabilities: ['chat', 'code'],
        isAvailable: true,
      ),
      ModelInfo(
        id: 'openai-codex/gpt-5.3-codex',
        name: 'GPT-5.3 Codex',
        provider: 'OpenAI Codex',
        contextWindow: 200000,
        speed: 'medium',
        capabilities: ['chat', 'code', 'reasoning'],
        isAvailable: true,
      ),
      ModelInfo(
        id: 'lmstudio/jan-v3-4b',
        name: 'Jan v3 4B',
        provider: 'LM Studio (Local)',
        contextWindow: 8192,
        speed: 'fast',
        capabilities: ['chat'],
        isAvailable: true,
      ),
    ];
  }

  /// Select a model
  Future<void> selectModel(String modelId) async {
    final model = _availableModels.where((m) => m.id == modelId).firstOrNull;
    if (model == null) return;

    _selectedModel = model;
    
    // Add to recent models
    _recentModelIds.remove(modelId);
    _recentModelIds.insert(0, modelId);
    if (_recentModelIds.length > 5) {
      _recentModelIds = _recentModelIds.sublist(0, 5);
    }

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelId);
    await prefs.setStringList(_recentModelsKey, _recentModelIds);

    _selectedModelController.add(_selectedModel);
  }

  /// Load selected model from preferences
  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelId = prefs.getString(_selectedModelKey);
    
    if (modelId != null) {
      // Will be set after models are fetched
      _recentModelIds.insert(0, modelId);
    }
  }

  /// Load recent models from preferences
  Future<void> _loadRecentModels() async {
    final prefs = await SharedPreferences.getInstance();
    _recentModelIds = prefs.getStringList(_recentModelsKey) ?? [];
  }

  /// Get model info by ID
  ModelInfo? getModelById(String modelId) {
    return _availableModels.where((m) => m.id == modelId).firstOrNull;
  }

  /// Update gateway URL
  void setBaseUrl(String url) {
    baseUrl = url;
  }

  /// Update token
  void setToken(String? newToken) {
    token = newToken;
  }

  /// Dispose resources
  void dispose() {
    _modelsController.close();
    _selectedModelController.close();
  }
}

