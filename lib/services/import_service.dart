import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Import source type
enum ImportSource {
  file,
  clipboard,
  url,
}

/// Import conflict resolution strategy
enum ConflictResolution {
  keepExisting,
  replaceWithImport,
  merge,
  askEachTime,
}

/// Import result model
class ImportResult {
  final bool success;
  final int itemsImported;
  final int itemsSkipped;
  final int conflictsResolved;
  final String? error;
  final List<String> warnings;

  ImportResult({
    required this.success,
    this.itemsImported = 0,
    this.itemsSkipped = 0,
    this.conflictsResolved = 0,
    this.error,
    this.warnings = const [],
  });
}

/// Import data type
enum ImportDataType {
  conversations,
  settings,
  backup,
  profiles,
  allData,
}

/// Import service for importing app data
class ImportService extends ChangeNotifier {
  Directory? _importDirectory;
  bool _isImporting = false;
  String? _lastError;
  double _importProgress = 0.0;
  ConflictResolution _conflictResolution = ConflictResolution.askEachTime;

  bool get isImporting => _isImporting;
  String? get lastError => _lastError;
  double get importProgress => _importProgress;
  ConflictResolution get conflictResolution => _conflictResolution;

  /// Set conflict resolution strategy
  void setConflictResolution(ConflictResolution resolution) {
    _conflictResolution = resolution;
    notifyListeners();
  }

  /// Initialize import service
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _importDirectory = Directory('${appDir.path}/imports');
    
    if (!await _importDirectory!.exists()) {
      await _importDirectory!.create(recursive: true);
    }
  }

  /// Import data from file
  Future<ImportResult> importFromFile(
    String filePath, {
    ImportDataType? dataType,
    ConflictResolution? resolution,
  }) async {
    if (_isImporting) {
      return ImportResult(success: false, error: 'Import already in progress');
    }

    _isImporting = true;
    _lastError = null;
    _importProgress = 0.0;
    notifyListeners();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _isImporting = false;
        return ImportResult(success: false, error: 'File not found: $filePath');
      }

      final extension = filePath.split('.').last.toLowerCase();
      Map<String, dynamic> data;

      _importProgress = 0.2;
      notifyListeners();

      // Read and parse file
      switch (extension) {
        case 'json':
          final content = await file.readAsString();
          data = jsonDecode(content) as Map<String, dynamic>;
          break;
        case 'txt':
        case 'md':
          final content = await file.readAsString();
          data = _parseTextFile(content, dataType);
          break;
        default:
          _isImporting = false;
          return ImportResult(success: false, error: 'Unsupported file format: $extension');
      }

      _importProgress = 0.5;
      notifyListeners();

      // Determine data type from content if not specified
      final actualType = dataType ?? _detectDataType(data);

      // Import based on type
      final result = await _importData(data, actualType, resolution ?? _conflictResolution);

      _importProgress = 1.0;
      _isImporting = false;
      notifyListeners();

      return result;
    } catch (e) {
      _lastError = e.toString();
      _isImporting = false;
      notifyListeners();
      return ImportResult(success: false, error: e.toString());
    }
  }

  /// Import data from JSON string
  Future<ImportResult> importFromJson(
    String jsonString, {
    ImportDataType? dataType,
    ConflictResolution? resolution,
  }) async {
    if (_isImporting) {
      return ImportResult(success: false, error: 'Import already in progress');
    }

    _isImporting = true;
    _lastError = null;
    notifyListeners();

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final actualType = dataType ?? _detectDataType(data);
      
      final result = await _importData(data, actualType, resolution ?? _conflictResolution);
      
      _isImporting = false;
      notifyListeners();
      return result;
    } catch (e) {
      _lastError = e.toString();
      _isImporting = false;
      notifyListeners();
      return ImportResult(success: false, error: e.toString());
    }
  }

  /// Import from clipboard
  Future<ImportResult> importFromClipboard({
    ImportDataType? dataType,
    ConflictResolution? resolution,
  }) async {
    // Note: This requires clipboard_watcher package or similar
    // For now, we'll show a placeholder
    return ImportResult(
      success: false,
      error: 'Clipboard import requires additional setup',
    );
  }

  /// Validate import file before importing
  Future<Map<String, dynamic>> validateFile(String filePath) async {
    final result = <String, dynamic>{
      'valid': false,
      'type': null,
      'items': 0,
      'errors': <String>[],
      'warnings': <String>[],
    };

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        result['errors'].add('File not found');
        return result;
      }

      final extension = filePath.split('.').last.toLowerCase();
      
      if (extension != 'json' && extension != 'txt' && extension != 'md') {
        result['errors'].add('Unsupported file format: $extension');
        return result;
      }

      final content = await file.readAsString();
      Map<String, dynamic> data;

      if (extension == 'json') {
        data = jsonDecode(content) as Map<String, dynamic>;
      } else {
        data = _parseTextFile(content, null);
      }

      result['type'] = _detectDataType(data);
      
      // Count items
      if (data.containsKey('conversations')) {
        result['items'] = (data['conversations'] as List).length;
      } else if (data.containsKey('settings')) {
        result['items'] = (data['settings'] as Map).length;
      } else {
        result['items'] = data.length;
      }

      // Check version compatibility
      if (data.containsKey('version')) {
        final version = data['version'] as String;
        if (version != '1.0' && version != '2.0') {
          result['warnings'].add('Unknown backup version: $version');
        }
      }

      result['valid'] = true;
      return result;
    } catch (e) {
      result['errors'].add(e.toString());
      return result;
    }
  }

  /// Get import history
  Future<List<Map<String, dynamic>>> getImportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('import_history');
    
    if (historyJson == null) return [];
    
    final List<dynamic> history = jsonDecode(historyJson);
    return history.cast<Map<String, dynamic>>();
  }

  /// Clear import history
  Future<void> clearImportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('import_history');
  }

  // Private methods
  Future<ImportResult> _importData(
    Map<String, dynamic> data,
    ImportDataType dataType,
    ConflictResolution resolution,
  ) async {
    int imported = 0;
    int skipped = 0;
    int conflicts = 0;
    final warnings = <String>[];

    try {
      final prefs = await SharedPreferences.getInstance();

      switch (dataType) {
        case ImportDataType.conversations:
          if (data.containsKey('conversations')) {
            final conversations = data['conversations'] as List;
            
            // Get existing conversations
            final existingJson = prefs.getString('conversations');
            final existing = existingJson != null
                ? List<Map<String, dynamic>>.from(jsonDecode(existingJson))
                : <Map<String, dynamic>>[];
            
            for (final conv in conversations) {
              final convMap = Map<String, dynamic>.from(conv);
              final id = convMap['id']?.toString();
              
              if (id != null) {
                final exists = existing.any((c) => c['id'] == id);
                
                if (exists) {
                  switch (resolution) {
                    case ConflictResolution.replaceWithImport:
                      existing.removeWhere((c) => c['id'] == id);
                      existing.add(convMap);
                      imported++;
                      conflicts++;
                      break;
                    case ConflictResolution.merge:
                      // Merge logic
                      final index = existing.indexWhere((c) => c['id'] == id);
                      existing[index] = {...existing[index], ...convMap};
                      imported++;
                      conflicts++;
                      break;
                    case ConflictResolution.keepExisting:
                      skipped++;
                      break;
                    case ConflictResolution.askEachTime:
                      // For now, keep existing
                      skipped++;
                      warnings.add('Conflict for conversation $id - kept existing');
                      break;
                  }
                } else {
                  existing.add(convMap);
                  imported++;
                }
              }
            }
            
            await prefs.setString('conversations', jsonEncode(existing));
          }
          break;

        case ImportDataType.settings:
          if (data.containsKey('appSettings') || data.containsKey('settings')) {
            final settings = data['appSettings'] ?? data['settings'] as Map<String, dynamic>;
            
            for (final entry in settings.entries) {
              final key = entry.key;
              final value = entry.value;
              
              final existingValue = prefs.get(key);
              
              if (existingValue != null && existingValue != value) {
                switch (resolution) {
                  case ConflictResolution.replaceWithImport:
                    await _setPrefValue(prefs, key, value);
                    imported++;
                    conflicts++;
                    break;
                  case ConflictResolution.keepExisting:
                    skipped++;
                    break;
                  default:
                    await _setPrefValue(prefs, key, value);
                    imported++;
                }
              } else {
                await _setPrefValue(prefs, key, value);
                imported++;
              }
            }
          }
          break;

        case ImportDataType.backup:
        case ImportDataType.allData:
          // Import everything
          if (data.containsKey('appSettings')) {
            for (final entry in (data['appSettings'] as Map<String, dynamic>).entries) {
              await _setPrefValue(prefs, entry.key, entry.value);
              imported++;
            }
          }
          
          if (data.containsKey('connectionProfiles')) {
            for (final entry in (data['connectionProfiles'] as Map<String, dynamic>).entries) {
              await _setPrefValue(prefs, entry.key, entry.value);
              imported++;
            }
          }
          
          if (data.containsKey('preferences')) {
            for (final entry in (data['preferences'] as Map<String, dynamic>).entries) {
              await _setPrefValue(prefs, entry.key, entry.value);
              imported++;
            }
          }
          
          if (data.containsKey('conversations')) {
            await prefs.setString('conversations', jsonEncode(data['conversations']));
            imported++;
          }
          break;

        case ImportDataType.profiles:
          if (data.containsKey('savedGateways') || data.containsKey('profiles')) {
            final profiles = data['savedGateways'] ?? data['profiles'];
            await prefs.setString('saved_gateways', jsonEncode(profiles));
            imported = (profiles as List).length;
          }
          break;
      }

      // Add to import history
      await _addToHistory(dataType, imported, skipped, conflicts);

      return ImportResult(
        success: true,
        itemsImported: imported,
        itemsSkipped: skipped,
        conflictsResolved: conflicts,
        warnings: warnings,
      );
    } catch (e) {
      return ImportResult(success: false, error: e.toString());
    }
  }

  Future<void> _setPrefValue(SharedPreferences prefs, String key, dynamic value) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, List<String>.from(value));
    }
  }

  Map<String, dynamic> _parseTextFile(String content, ImportDataType? dataType) {
    // Simple text parsing for conversations
    final lines = content.split('\n');
    final conversations = <Map<String, dynamic>>[];
    String? currentRole;
    final currentContent = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('[USER]') || line.startsWith('[ASSISTANT]')) {
        if (currentRole != null && currentContent.isNotEmpty) {
          conversations.add({
            'role': currentRole.toLowerCase(),
            'content': currentContent.toString().trim(),
          });
          currentContent.clear();
        }
        currentRole = line.startsWith('[USER]') ? 'user' : 'assistant';
      } else if (currentRole != null) {
        currentContent.writeln(line);
      }
    }

    if (currentRole != null && currentContent.isNotEmpty) {
      conversations.add({
        'role': currentRole.toLowerCase(),
        'content': currentContent.toString().trim(),
      });
    }

    return {'conversations': conversations};
  }

  ImportDataType _detectDataType(Map<String, dynamic> data) {
    if (data.containsKey('version') && data.containsKey('createdAt')) {
      return ImportDataType.backup;
    }
    if (data.containsKey('conversations')) {
      return ImportDataType.conversations;
    }
    if (data.containsKey('appSettings') || data.containsKey('settings')) {
      return ImportDataType.settings;
    }
    if (data.containsKey('savedGateways') || data.containsKey('profiles')) {
      return ImportDataType.profiles;
    }
    return ImportDataType.allData;
  }

  Future<void> _addToHistory(ImportDataType type, int imported, int skipped, int conflicts) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('import_history');
    final history = historyJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(historyJson))
        : <Map<String, dynamic>>[];
    
    history.insert(0, {
      'type': type.name,
      'imported': imported,
      'skipped': skipped,
      'conflicts': conflicts,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Keep only last 20 entries
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    
    await prefs.setString('import_history', jsonEncode(history));
  }
}