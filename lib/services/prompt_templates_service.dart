import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prompt_template.dart';
import '../data/default_templates.dart';

/// Service for managing prompt templates
class PromptTemplatesService {
  static const String _storageKey = 'prompt_templates';
  static const String _favoritesKey = 'prompt_template_favorites';
  static const String _usageKey = 'prompt_template_usage';
  
  static PromptTemplatesService? _instance;
  static SharedPreferences? _prefs;
  
  List<PromptTemplate>? _cachedTemplates;
  
  PromptTemplatesService._();
  
  /// Get singleton instance
  static Future<PromptTemplatesService> getInstance() async {
    if (_instance == null) {
      _prefs = await SharedPreferences.getInstance();
      _instance = PromptTemplatesService._();
    }
    return _instance!;
  }
  
  /// Initialize service (call at app startup)
  static Future<void> initialize() async {
    await getInstance();
  }
  
  /// Get all templates (default + custom)
  Future<List<PromptTemplate>> getTemplates() async {
    if (_cachedTemplates != null) {
      return _cachedTemplates!;
    }
    
    // Start with default templates
    final templates = <PromptTemplate>[...DefaultPromptTemplates.all];
    
    // Load custom templates from storage
    final customJson = _prefs!.getString(_storageKey);
    if (customJson != null) {
      try {
        final List<dynamic> customList = jsonDecode(customJson);
        final customTemplates = customList
            .map((json) => PromptTemplate.fromJson(json as Map<String, dynamic>))
            .toList();
        templates.addAll(customTemplates);
      } catch (e) {
        // Ignore parse errors
      }
    }
    
    // Load favorites
    final favoritesJson = _prefs!.getString(_favoritesKey);
    final Set<String> favoriteIds = favoritesJson != null
        ? Set<String>.from(jsonDecode(favoritesJson) as List)
        : {};
    
    // Load usage counts
    final usageJson = _prefs!.getString(_usageKey);
    final Map<String, int> usageCounts = {};
    if (usageJson != null) {
      final Map<String, dynamic> usageMap = jsonDecode(usageJson);
      usageMap.forEach((key, value) {
        usageCounts[key] = value as int;
      });
    }
    
    // Apply favorites and usage counts
    _cachedTemplates = templates.map((t) {
      return t.copyWith(
        isFavorite: favoriteIds.contains(t.id),
        usageCount: usageCounts[t.id] ?? t.usageCount,
      );
    }).toList();
    
    return _cachedTemplates!;
  }
  
  /// Get template by ID
  Future<PromptTemplate?> getTemplateById(String id) async {
    final templates = await getTemplates();
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get templates by category
  Future<List<PromptTemplate>> getTemplatesByCategory(PromptCategory category) async {
    final templates = await getTemplates();
    return templates.where((t) => t.category == category).toList();
  }
  
  /// Get all categories with template counts
  Future<Map<PromptCategory, int>> getCategories() async {
    final templates = await getTemplates();
    final counts = <PromptCategory, int>{};
    
    for (final category in PromptCategory.values) {
      final count = templates.where((t) => t.category == category).length;
      if (count > 0) {
        counts[category] = count;
      }
    }
    
    return counts;
  }
  
  /// Search templates by query
  Future<List<PromptTemplate>> searchTemplates(String query) async {
    if (query.isEmpty) {
      return getTemplates();
    }
    
    final templates = await getTemplates();
    final lowerQuery = query.toLowerCase();
    
    return templates.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          t.prompt.toLowerCase().contains(lowerQuery) ||
          (t.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          t.category.displayName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
  
  /// Get favorite templates
  Future<List<PromptTemplate>> getFavorites() async {
    final templates = await getTemplates();
    return templates.where((t) => t.isFavorite).toList();
  }
  
  /// Get most used templates
  Future<List<PromptTemplate>> getMostUsed({int limit = 10}) async {
    final templates = await getTemplates();
    final sorted = List<PromptTemplate>.from(templates)
      ..sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));
    return sorted.take(limit).toList();
  }
  
  /// Save a custom template
  Future<bool> saveTemplate(PromptTemplate template) async {
    try {
      // Load existing custom templates
      final customJson = _prefs!.getString(_storageKey);
      List<Map<String, dynamic>> customList = [];
      if (customJson != null) {
        customList = List<Map<String, dynamic>>.from(jsonDecode(customJson));
      }
      
      // Check if updating existing or adding new
      final existingIndex = customList.indexWhere((j) => j['id'] == template.id);
      if (existingIndex >= 0) {
        // Update existing
        customList[existingIndex] = template.toJson();
      } else {
        // Add new
        customList.add(template.toJson());
      }
      
      // Save to storage
      await _prefs!.setString(_storageKey, jsonEncode(customList));
      
      // Clear cache to force reload
      _cachedTemplates = null;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete a custom template (can't delete default templates)
  Future<bool> deleteTemplate(String id) async {
    try {
      // Check if it's a default template
      final defaultIds = DefaultPromptTemplates.all.map((t) => t.id).toSet();
      if (defaultIds.contains(id)) {
        return false; // Can't delete default templates
      }
      
      // Load existing custom templates
      final customJson = _prefs!.getString(_storageKey);
      if (customJson == null) return false;
      
      List<Map<String, dynamic>> customList = 
          List<Map<String, dynamic>>.from(jsonDecode(customJson));
      
      // Remove template
      customList.removeWhere((j) => j['id'] == id);
      
      // Save to storage
      await _prefs!.setString(_storageKey, jsonEncode(customList));
      
      // Clear cache
      _cachedTemplates = null;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Toggle favorite status
  Future<bool> toggleFavorite(String id) async {
    try {
      final templates = await getTemplates();
      final template = templates.firstWhere((t) => t.id == id);
      
      // Load favorites
      final favoritesJson = _prefs!.getString(_favoritesKey);
      final Set<String> favoriteIds = favoritesJson != null
          ? Set<String>.from(jsonDecode(favoritesJson) as List)
          : {};
      
      // Toggle
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
      } else {
        favoriteIds.add(id);
      }
      
      // Save
      await _prefs!.setString(_favoritesKey, jsonEncode(favoriteIds.toList()));
      
      // Clear cache
      _cachedTemplates = null;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Increment usage count for a template
  Future<void> incrementUsage(String id) async {
    try {
      final usageJson = _prefs!.getString(_usageKey);
      final Map<String, int> usageCounts = {};
      if (usageJson != null) {
        final Map<String, dynamic> usageMap = jsonDecode(usageJson);
        usageMap.forEach((key, value) {
          usageCounts[key] = value as int;
        });
      }
      
      usageCounts[id] = (usageCounts[id] ?? 0) + 1;
      
      await _prefs!.setString(_usageKey, jsonEncode(usageCounts));
      
      // Clear cache
      _cachedTemplates = null;
    } catch (e) {
      // Ignore errors
    }
  }
  
  /// Export templates to JSON string
  Future<String> exportTemplates({List<String>? ids}) async {
    final templates = await getTemplates();
    final toExport = ids != null
        ? templates.where((t) => ids.contains(t.id)).toList()
        : templates;
    return jsonEncode(toExport.map((t) => t.toJson()).toList());
  }
  
  /// Import templates from JSON string
  Future<int> importTemplates(String jsonString) async {
    try {
      final List<dynamic> imported = jsonDecode(jsonString);
      int count = 0;
      
      for (final json in imported) {
        final template = PromptTemplate.fromJson(json as Map<String, dynamic>);
        // Generate new ID for imported templates
        final newTemplate = template.copyWith(
          id: 'imported_${DateTime.now().millisecondsSinceEpoch}_$count',
          isDefault: false,
          createdAt: DateTime.now(),
        );
        if (await saveTemplate(newTemplate)) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      return 0;
    }
  }
  
  /// Clear all custom templates (reset to defaults)
  Future<void> clearCustomTemplates() async {
    await _prefs!.remove(_storageKey);
    await _prefs!.remove(_favoritesKey);
    await _prefs!.remove(_usageKey);
    _cachedTemplates = null;
  }
  
  /// Clear cache (force reload on next access)
  void clearCache() {
    _cachedTemplates = null;
  }
}