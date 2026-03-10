import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/agent_session.dart';
import '../models/node_connection.dart';
import '../data/agency_agents.dart';
import '../models/agent_personality.dart';
import 'gateway_service.dart';

/// Search result category
enum SearchCategory {
  messages('Messages', Icons.chat, Colors.blue),
  agents('Agents', Icons.smart_toy, Colors.purple),
  nodes('Nodes', Icons.devices, Colors.green),
  settings('Settings', Icons.settings, Colors.orange),
  actions('Actions', Icons.flash_on, Colors.amber);

  final String label;
  final IconData icon;
  final Color color;

  const SearchCategory(this.label, this.icon, this.color);
}

/// A single search result
class SearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final String category;
  final SearchCategory categoryEnum;
  final IconData icon;
  final Color color;
  final Map<String, dynamic>? metadata;
  final double relevanceScore;

  const SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    required this.categoryEnum,
    required this.icon,
    required this.color,
    this.metadata,
    this.relevanceScore = 1.0,
  });
}

/// Global search service that searches across all app content
class GlobalSearchService {
  static const int _maxRecentSearches = 10;
  static const String _recentSearchesKey = 'global_search_recent';
  
  final GatewayService? _gatewayService;
  List<ChatMessage> _cachedMessages = [];
  List<AgentSession> _cachedAgents = [];
  List<NodeConnection> _cachedNodes = [];

  GlobalSearchService({GatewayService? gatewayService}) 
      : _gatewayService = gatewayService;

  /// Cache messages for faster searching
  void cacheMessages(List<ChatMessage> messages) {
    _cachedMessages = messages;
  }

  /// Cache agents for faster searching
  void cacheAgents(List<AgentSession> agents) {
    _cachedAgents = agents;
  }

  /// Cache nodes for faster searching
  void cacheNodes(List<NodeConnection> nodes) {
    _cachedNodes = nodes;
  }

  /// Perform global search across all categories
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search all categories in parallel
    final futures = await Future.wait([
      searchChatMessages(query),
      searchAgents(query),
      searchNodes(query),
      searchSettings(query),
      searchActions(query),
    ]);

    for (final categoryResults in futures) {
      results.addAll(categoryResults);
    }

    // Sort by relevance score
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results;
  }

  /// Search chat messages
  Future<List<SearchResult>> searchChatMessages(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search cached messages first
    for (final message in _cachedMessages) {
      final content = message.content.toLowerCase();
      if (content.contains(lowerQuery)) {
        final score = _calculateRelevance(content, lowerQuery);
        results.add(SearchResult(
          id: 'msg_${message.id}',
          title: _truncateText(message.content, 50),
          subtitle: '${message.displayRole} • ${_formatTimestamp(message.timestamp)}',
          category: SearchCategory.messages.label,
          categoryEnum: SearchCategory.messages,
          icon: message.isUser ? Icons.person : Icons.smart_toy,
          color: SearchCategory.messages.color,
          metadata: {
            'messageId': message.id,
            'role': message.role,
            'content': message.content,
            'timestamp': message.timestamp?.toIso8601String(),
          },
          relevanceScore: score,
        ));
      }
    }

    // Also search gateway chat history if available
    if (_gatewayService != null) {
      try {
        final agents = await _gatewayService!.getAgents();
        if (agents != null) {
          for (final agent in agents) {
            final history = await _gatewayService!.getChatHistory(agent.key, limit: 50);
            if (history != null) {
              for (final message in history) {
                final content = message.content.toLowerCase();
                if (content.contains(lowerQuery)) {
                  final score = _calculateRelevance(content, lowerQuery);
                  results.add(SearchResult(
                    id: 'gw_msg_${message.id}_${agent.key}',
                    title: _truncateText(message.content, 50),
                    subtitle: '${agent.name} • ${_formatTimestamp(message.timestamp)}',
                    category: SearchCategory.messages.label,
                    categoryEnum: SearchCategory.messages,
                    icon: message.isUser ? Icons.person : Icons.smart_toy,
                    color: SearchCategory.messages.color,
                    metadata: {
                      'messageId': message.id,
                      'sessionKey': agent.key,
                      'agentName': agent.name,
                      'role': message.role,
                      'content': message.content,
                      'timestamp': message.timestamp?.toIso8601String(),
                    },
                    relevanceScore: score,
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        // Ignore gateway errors in search
      }
    }

    return results;
  }

  /// Search agents (from agent library and active sessions)
  Future<List<SearchResult>> searchAgents(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search agent library
    for (final agent in AgencyAgentsData.allAgents) {
      final nameMatch = agent.name.toLowerCase().contains(lowerQuery);
      final descMatch = agent.shortDescription.toLowerCase().contains(lowerQuery);
      final fullDescMatch = agent.fullDescription.toLowerCase().contains(lowerQuery);
      final specialtyMatch = agent.specialties.any((s) => s.toLowerCase().contains(lowerQuery));

      if (nameMatch || descMatch || fullDescMatch || specialtyMatch) {
        final score = _calculateAgentRelevance(agent, lowerQuery);
        results.add(SearchResult(
          id: 'agent_lib_${agent.id}',
          title: '${agent.emoji} ${agent.name}',
          subtitle: agent.shortDescription,
          category: SearchCategory.agents.label,
          categoryEnum: SearchCategory.agents,
          icon: Icons.smart_toy,
          color: agent.division.color,
          metadata: {
            'agentId': agent.id,
            'agentName': agent.name,
            'division': agent.division.name,
            'emoji': agent.emoji,
          },
          relevanceScore: score,
        ));
      }
    }

    // Search active agent sessions
    for (final agent in _cachedAgents) {
      final nameMatch = agent.name.toLowerCase().contains(lowerQuery);
      final modelMatch = agent.model.toLowerCase().contains(lowerQuery);
      final previewMatch = agent.lastMessagePreview?.toLowerCase().contains(lowerQuery) ?? false;

      if (nameMatch || modelMatch || previewMatch) {
        final score = nameMatch ? 1.0 : (modelMatch ? 0.8 : 0.6);
        results.add(SearchResult(
          id: 'agent_session_${agent.id}',
          title: '${agent.emoji ?? "🤖"} ${agent.displayName ?? agent.name}',
          subtitle: agent.lastMessagePreview ?? agent.model,
          category: SearchCategory.agents.label,
          categoryEnum: SearchCategory.agents,
          icon: Icons.person_pin,
          color: SearchCategory.agents.color,
          metadata: {
            'sessionId': agent.id,
            'sessionKey': agent.key,
            'agentName': agent.name,
            'model': agent.model,
            'isActive': agent.isActive,
          },
          relevanceScore: score,
        ));
      }
    }

    return results;
  }

  /// Search nodes
  Future<List<SearchResult>> searchNodes(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search cached nodes
    for (final node in _cachedNodes) {
      final nameMatch = node.name.toLowerCase().contains(lowerQuery);
      final ipMatch = node.ip.toLowerCase().contains(lowerQuery);
      final statusMatch = node.status.name.toLowerCase().contains(lowerQuery);

      if (nameMatch || ipMatch || statusMatch) {
        final score = nameMatch ? 1.0 : (ipMatch ? 0.8 : 0.6);
        results.add(SearchResult(
          id: 'node_${node.id}',
          title: node.displayName,
          subtitle: '${node.ip}:${node.port} • ${node.status.name}',
          category: SearchCategory.nodes.label,
          categoryEnum: SearchCategory.nodes,
          icon: _getDeviceIcon(node.deviceType),
          color: node.status == ConnectionStatus.connected 
              ? Colors.green 
              : Colors.orange,
          metadata: {
            'nodeId': node.id,
            'nodeName': node.name,
            'nodeIp': node.ip,
            'nodePort': node.port,
            'status': node.status.name,
          },
          relevanceScore: score,
        ));
      }
    }

    // Search from gateway if available
    if (_gatewayService != null) {
      try {
        final status = await _gatewayService!.getStatus();
        if (status != null && status.nodes != null) {
          for (final node in status.nodes!) {
            final nodeName = node.name;
            final nameMatch = nodeName.toLowerCase().contains(lowerQuery);
            
            if (nameMatch) {
              results.add(SearchResult(
                id: 'gw_node_${node.name}',
                title: nodeName,
                subtitle: node.ip ?? 'Connected Node',
                category: SearchCategory.nodes.label,
                categoryEnum: SearchCategory.nodes,
                icon: Icons.devices,
                color: SearchCategory.nodes.color,
                metadata: {
                  'nodeName': nodeName,
                  'nodeIp': node.ip,
                  'status': node.status,
                },
                relevanceScore: 0.9,
              ));
            }
          }
        }
      } catch (e) {
        // Ignore gateway errors
      }
    }

    return results;
  }

  /// Search settings
  Future<List<SearchResult>> searchSettings(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Define searchable settings
    final settingsItems = [
      {'id': 'gateway', 'title': 'Gateway Settings', 'subtitle': 'Configure gateway connection', 'icon': Icons.router, 'screen': 'gateway'},
      {'id': 'theme', 'title': 'Theme', 'subtitle': 'App appearance and colors', 'icon': Icons.palette, 'screen': 'appearance'},
      {'id': 'notifications', 'title': 'Notifications', 'subtitle': 'Push notifications and alerts', 'icon': Icons.notifications, 'screen': 'notifications'},
      {'id': 'voice', 'title': 'Voice Settings', 'subtitle': 'Wake word and TTS configuration', 'icon': Icons.mic, 'screen': 'voice'},
      {'id': 'agents', 'title': 'Agent Settings', 'subtitle': 'Default agent and response style', 'icon': Icons.smart_toy, 'screen': 'agents'},
      {'id': 'browser', 'title': 'BrowserOS', 'subtitle': 'Browser automation settings', 'icon': Icons.public, 'screen': 'browser'},
      {'id': 'automation', 'title': 'Automation', 'subtitle': 'Webhooks and scheduled tasks', 'icon': Icons.auto_mode, 'screen': 'automation'},
      {'id': 'termux', 'title': 'Termux', 'subtitle': 'Local terminal settings', 'icon': Icons.terminal, 'screen': 'termux'},
      {'id': 'developer', 'title': 'Developer Mode', 'subtitle': 'Debug and advanced options', 'icon': Icons.code, 'screen': 'developer'},
      {'id': 'backup', 'title': 'Backup & Restore', 'subtitle': 'Data backup settings', 'icon': Icons.backup, 'screen': 'backup'},
      {'id': 'about', 'title': 'About', 'subtitle': 'App version and info', 'icon': Icons.info, 'screen': 'about'},
      {'id': 'mode', 'title': 'App Mode', 'subtitle': 'Switch between Basic/Power/Dev modes', 'icon': Icons.tune, 'screen': 'mode'},
    ];

    for (final item in settingsItems) {
      final titleMatch = item['title'].toString().toLowerCase().contains(lowerQuery);
      final subtitleMatch = item['subtitle'].toString().toLowerCase().contains(lowerQuery);

      if (titleMatch || subtitleMatch) {
        final score = titleMatch ? 1.0 : 0.8;
        results.add(SearchResult(
          id: 'setting_${item['id']}',
          title: item['title'].toString(),
          subtitle: item['subtitle'].toString(),
          category: SearchCategory.settings.label,
          categoryEnum: SearchCategory.settings,
          icon: item['icon'] as IconData,
          color: SearchCategory.settings.color,
          metadata: {
            'settingId': item['id'],
            'screen': item['screen'],
          },
          relevanceScore: score,
        ));
      }
    }

    return results;
  }

  /// Search actions (quick actions)
  Future<List<SearchResult>> searchActions(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Define searchable actions
    final actions = [
      {'id': 'status', 'title': 'Check Status', 'subtitle': 'View system status', 'icon': Icons.info_outline, 'category': 'GROW'},
      {'id': 'photo', 'title': 'Take Photo', 'subtitle': 'Capture photo from camera', 'icon': Icons.camera_alt, 'category': 'GROW'},
      {'id': 'analyze', 'title': 'Analyze Plant', 'subtitle': 'AI plant health analysis', 'icon': Icons.analytics, 'category': 'GROW'},
      {'id': 'backup', 'title': 'Create Backup', 'subtitle': 'Backup app data', 'icon': Icons.backup, 'category': 'SYSTEM'},
      {'id': 'restart', 'title': 'Restart Gateway', 'subtitle': 'Restart OpenClaw gateway', 'icon': Icons.refresh, 'category': 'SYSTEM'},
      {'id': 'update', 'title': 'Update OpenClaw', 'subtitle': 'Check for updates', 'icon': Icons.system_update, 'category': 'SYSTEM'},
      {'id': 'weather', 'title': 'Check Weather', 'subtitle': 'Current weather conditions', 'icon': Icons.wb_sunny, 'category': 'WEATHER'},
      {'id': 'forecast', 'title': 'Weather Forecast', 'subtitle': '7-day weather forecast', 'icon': Icons.calendar_month, 'category': 'WEATHER'},
      {'id': 'chat', 'title': 'Agent Chat', 'subtitle': 'Chat with AI agents', 'icon': Icons.chat, 'category': 'AGENTS'},
      {'id': 'research', 'title': 'Research Agent', 'subtitle': 'Spawn research agent', 'icon': Icons.search, 'category': 'AGENTS'},
      {'id': 'code', 'title': 'Code Agent', 'subtitle': 'Spawn coding agent', 'icon': Icons.code, 'category': 'AGENTS'},
      {'id': 'termux', 'title': 'Open Termux', 'subtitle': 'Launch terminal', 'icon': Icons.terminal, 'category': 'TERMUX'},
      {'id': 'logs', 'title': 'View Logs', 'subtitle': 'Gateway logs', 'icon': Icons.article, 'category': 'TOOLS'},
      {'id': 'workflows', 'title': 'Workflows', 'subtitle': 'Manage workflows', 'icon': Icons.account_tree, 'category': 'TOOLS'},
      {'id': 'tasks', 'title': 'Scheduled Tasks', 'subtitle': 'View scheduled tasks', 'icon': Icons.schedule, 'category': 'TOOLS'},
      {'id': 'models', 'title': 'AI Models', 'subtitle': 'Model hub and settings', 'icon': Icons.analytics, 'category': 'TOOLS'},
    ];

    for (final action in actions) {
      final titleMatch = action['title'].toString().toLowerCase().contains(lowerQuery);
      final subtitleMatch = action['subtitle'].toString().toLowerCase().contains(lowerQuery);
      final categoryMatch = action['category'].toString().toLowerCase().contains(lowerQuery);

      if (titleMatch || subtitleMatch || categoryMatch) {
        final score = titleMatch ? 1.0 : (subtitleMatch ? 0.8 : 0.6);
        results.add(SearchResult(
          id: 'action_${action['id']}',
          title: action['title'].toString(),
          subtitle: '${action['category']} • ${action['subtitle']}',
          category: SearchCategory.actions.label,
          categoryEnum: SearchCategory.actions,
          icon: action['icon'] as IconData,
          color: SearchCategory.actions.color,
          metadata: {
            'actionId': action['id'],
            'actionCategory': action['category'],
          },
          relevanceScore: score,
        ));
      }
    }

    return results;
  }

  /// Get recent searches
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_recentSearchesKey);
      if (json == null) return [];
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      return [];
    }
  }

  /// Save a search to recent searches
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = await getRecentSearches();
      
      // Remove if already exists (to move to front)
      recent.remove(query);
      
      // Add to front
      recent.insert(0, query);
      
      // Keep only max recent searches
      if (recent.length > _maxRecentSearches) {
        recent.removeRange(_maxRecentSearches, recent.length);
      }
      
      await prefs.setString(_recentSearchesKey, jsonEncode(recent));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Calculate relevance score for a text match
  double _calculateRelevance(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    // Exact match
    if (lowerText == lowerQuery) return 1.0;
    
    // Starts with query
    if (lowerText.startsWith(lowerQuery)) return 0.9;
    
    // Contains query as whole word
    if (lowerText.contains(' $lowerQuery ') || 
        lowerText.contains(' $lowerQuery') ||
        lowerText.contains('$lowerQuery ')) {
      return 0.8;
    }
    
    // Contains query
    if (lowerText.contains(lowerQuery)) return 0.7;
    
    return 0.5;
  }

  /// Calculate relevance score for agent match
  double _calculateAgentRelevance(AgentPersonality agent, String query) {
    final lowerQuery = query.toLowerCase();
    
    // Name exact match
    if (agent.name.toLowerCase() == lowerQuery) return 1.0;
    
    // Name starts with
    if (agent.name.toLowerCase().startsWith(lowerQuery)) return 0.95;
    
    // Name contains
    if (agent.name.toLowerCase().contains(lowerQuery)) return 0.9;
    
    // Short description contains
    if (agent.shortDescription.toLowerCase().contains(lowerQuery)) return 0.8;
    
    // Specialty match
    if (agent.specialties.any((s) => s.toLowerCase().contains(lowerQuery))) return 0.75;
    
    // Full description contains
    if (agent.fullDescription.toLowerCase().contains(lowerQuery)) return 0.7;
    
    return 0.5;
  }

  /// Truncate text with ellipsis
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  /// Get device icon based on device type
  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return Icons.phone_android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.iot:
        return Icons.router;
      case DeviceType.unknown:
        return Icons.device_unknown;
    }
  }
}