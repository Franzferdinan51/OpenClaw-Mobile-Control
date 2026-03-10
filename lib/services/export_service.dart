import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Export format options
enum ExportFormat {
  json,
  pdf,
  txt,
  markdown,
  csv,
}

/// Export data type
enum ExportDataType {
  conversations,
  logs,
  settings,
  analytics,
  allData,
  cachedData,
}

/// Export result model
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int bytesWritten;

  ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.bytesWritten = 0,
  });
}

/// Export service for exporting app data
class ExportService extends ChangeNotifier {
  Directory? _exportDirectory;
  bool _isExporting = false;
  String? _lastError;
  double _exportProgress = 0.0;

  bool get isExporting => _isExporting;
  String? get lastError => _lastError;
  double get exportProgress => _exportProgress;

  /// Initialize export service
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _exportDirectory = Directory('${appDir.path}/exports');
    
    if (!await _exportDirectory!.exists()) {
      await _exportDirectory!.create(recursive: true);
    }
  }

  /// Export data to specified format
  Future<ExportResult> exportData({
    required ExportDataType dataType,
    required ExportFormat format,
    required Map<String, dynamic> data,
    String? customFileName,
  }) async {
    if (_isExporting) {
      return ExportResult(success: false, error: 'Export already in progress');
    }

    _isExporting = true;
    _lastError = null;
    _exportProgress = 0.0;
    notifyListeners();

    try {
      await initialize();
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = customFileName ?? '${dataType.name}_$timestamp';
      
      String filePath;
      String content;
      
      _exportProgress = 0.1;
      notifyListeners();
      
      switch (format) {
        case ExportFormat.json:
          filePath = await _exportAsJson(fileName, data);
          break;
        case ExportFormat.pdf:
          filePath = await _exportAsPdf(fileName, dataType, data);
          break;
        case ExportFormat.txt:
          filePath = await _exportAsTxt(fileName, dataType, data);
          break;
        case ExportFormat.markdown:
          filePath = await _exportAsMarkdown(fileName, dataType, data);
          break;
        case ExportFormat.csv:
          filePath = await _exportAsCsv(fileName, dataType, data);
          break;
      }
      
      _exportProgress = 1.0;
      _isExporting = false;
      notifyListeners();
      
      final file = File(filePath);
      final bytes = await file.length();
      
      return ExportResult(
        success: true,
        filePath: filePath,
        bytesWritten: bytes,
      );
    } catch (e) {
      _lastError = e.toString();
      _isExporting = false;
      notifyListeners();
      return ExportResult(success: false, error: e.toString());
    }
  }

  /// Export conversations
  Future<ExportResult> exportConversations(
    List<Map<String, dynamic>> conversations, {
    ExportFormat format = ExportFormat.json,
  }) async {
    return exportData(
      dataType: ExportDataType.conversations,
      format: format,
      data: {'conversations': conversations},
    );
  }

  /// Export logs
  Future<ExportResult> exportLogs(
    List<Map<String, dynamic>> logs, {
    ExportFormat format = ExportFormat.txt,
  }) async {
    return exportData(
      dataType: ExportDataType.logs,
      format: format,
      data: {'logs': logs},
    );
  }

  /// Export settings
  Future<ExportResult> exportSettings(
    Map<String, dynamic> settings, {
    ExportFormat format = ExportFormat.json,
  }) async {
    return exportData(
      dataType: ExportDataType.settings,
      format: format,
      data: settings,
    );
  }

  /// Export all data
  Future<ExportResult> exportAllData(Map<String, dynamic> allData) async {
    return exportData(
      dataType: ExportDataType.allData,
      format: ExportFormat.json,
      data: allData,
      customFileName: 'full_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}',
    );
  }

  /// Share exported file
  Future<bool> shareExportedFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Get list of exported files
  Future<List<FileSystemEntity>> getExportedFiles() async {
    await initialize();
    
    final files = <FileSystemEntity>[];
    await for (final entity in _exportDirectory!.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }
    
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Delete exported file
  Future<bool> deleteExportedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Get total export directory size
  Future<int> getExportDirectorySize() async {
    await initialize();
    
    int totalSize = 0;
    await for (final entity in _exportDirectory!.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  // Private export methods
  Future<String> _exportAsJson(String fileName, Map<String, dynamic> data) async {
    final filePath = '${_exportDirectory!.path}/$fileName.json';
    final file = File(filePath);
    
    _exportProgress = 0.3;
    notifyListeners();
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);
    
    return filePath;
  }

  Future<String> _exportAsPdf(String fileName, ExportDataType dataType, Map<String, dynamic> data) async {
    final filePath = '${_exportDirectory!.path}/$fileName.pdf';
    final file = File(filePath);
    
    _exportProgress = 0.3;
    notifyListeners();
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'DuckBot Export - ${_getDataTypeLabel(dataType)}',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Exported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 20),
            ..._buildPdfContent(dataType, data),
          ];
        },
      ),
    );
    
    _exportProgress = 0.7;
    notifyListeners();
    
    await file.writeAsBytes(await pdf.save());
    
    return filePath;
  }

  List<pw.Widget> _buildPdfContent(ExportDataType dataType, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];
    
    switch (dataType) {
      case ExportDataType.conversations:
        final conversations = data['conversations'] as List<dynamic>? ?? [];
        for (final conv in conversations) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    conv['role']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(conv['content']?.toString() ?? ''),
                ],
              ),
            ),
          );
        }
        break;
        
      case ExportDataType.logs:
        final logs = data['logs'] as List<dynamic>? ?? [];
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Time')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Level')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Message')),
                ],
              ),
              ...logs.map((log) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(log['timestamp']?.toString() ?? '')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(log['level']?.toString() ?? '')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(log['message']?.toString() ?? '')),
                ],
              )),
            ],
          ),
        );
        break;
        
      case ExportDataType.settings:
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Setting')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value')),
                ],
              ),
              ...data.entries.map((entry) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(entry.key)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(entry.value.toString())),
                ],
              )),
            ],
          ),
        );
        break;
        
      default:
        widgets.add(
          pw.Text(
            const JsonEncoder.withIndent('  ').convert(data),
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
          ),
        );
    }
    
    return widgets;
  }

  Future<String> _exportAsTxt(String fileName, ExportDataType dataType, Map<String, dynamic> data) async {
    final filePath = '${_exportDirectory!.path}/$fileName.txt';
    final file = File(filePath);
    
    _exportProgress = 0.3;
    notifyListeners();
    
    final buffer = StringBuffer();
    buffer.writeln('DuckBot Export - ${_getDataTypeLabel(dataType)}');
    buffer.writeln('Exported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    switch (dataType) {
      case ExportDataType.conversations:
        final conversations = data['conversations'] as List<dynamic>? ?? [];
        for (final conv in conversations) {
          buffer.writeln('[${conv['role']?.toString().toUpperCase() ?? 'UNKNOWN'}]');
          buffer.writeln(conv['content']?.toString() ?? '');
          buffer.writeln('-' * 40);
        }
        break;
        
      case ExportDataType.logs:
        final logs = data['logs'] as List<dynamic>? ?? [];
        for (final log in logs) {
          buffer.writeln('[${log['timestamp']}] [${log['level']}] ${log['message']}');
        }
        break;
        
      default:
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(data));
    }
    
    _exportProgress = 0.7;
    notifyListeners();
    
    await file.writeAsString(buffer.toString());
    
    return filePath;
  }

  Future<String> _exportAsMarkdown(String fileName, ExportDataType dataType, Map<String, dynamic> data) async {
    final filePath = '${_exportDirectory!.path}/$fileName.md';
    final file = File(filePath);
    
    _exportProgress = 0.3;
    notifyListeners();
    
    final buffer = StringBuffer();
    buffer.writeln('# DuckBot Export - ${_getDataTypeLabel(dataType)}');
    buffer.writeln();
    buffer.writeln('> Exported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln();
    
    switch (dataType) {
      case ExportDataType.conversations:
        buffer.writeln('## Conversations');
        buffer.writeln();
        final conversations = data['conversations'] as List<dynamic>? ?? [];
        for (final conv in conversations) {
          final role = conv['role']?.toString() ?? 'unknown';
          buffer.writeln('### ${role[0].toUpperCase()}${role.substring(1)}');
          buffer.writeln();
          buffer.writeln(conv['content']?.toString() ?? '');
          buffer.writeln();
        }
        break;
        
      case ExportDataType.logs:
        buffer.writeln('## Logs');
        buffer.writeln();
        buffer.writeln('| Timestamp | Level | Message |');
        buffer.writeln('|-----------|-------|---------|');
        final logs = data['logs'] as List<dynamic>? ?? [];
        for (final log in logs) {
          buffer.writeln('| ${log['timestamp']} | ${log['level']} | ${log['message']} |');
        }
        break;
        
      default:
        buffer.writeln('```json');
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(data));
        buffer.writeln('```');
    }
    
    _exportProgress = 0.7;
    notifyListeners();
    
    await file.writeAsString(buffer.toString());
    
    return filePath;
  }

  Future<String> _exportAsCsv(String fileName, ExportDataType dataType, Map<String, dynamic> data) async {
    final filePath = '${_exportDirectory!.path}/$fileName.csv';
    final file = File(filePath);
    
    _exportProgress = 0.3;
    notifyListeners();
    
    final buffer = StringBuffer();
    
    switch (dataType) {
      case ExportDataType.logs:
        buffer.writeln('timestamp,level,message');
        final logs = data['logs'] as List<dynamic>? ?? [];
        for (final log in logs) {
          final timestamp = log['timestamp']?.toString().replaceAll(',', ';') ?? '';
          final level = log['level']?.toString().replaceAll(',', ';') ?? '';
          final message = log['message']?.toString().replaceAll(',', ';').replaceAll('\n', ' ') ?? '';
          buffer.writeln('$timestamp,$level,$message');
        }
        break;
        
      default:
        // Generic CSV export
        final keys = data.keys.toList();
        buffer.writeln(keys.join(','));
        buffer.writeln(keys.map((k) => data[k]?.toString().replaceAll(',', ';') ?? '').join(','));
    }
    
    _exportProgress = 0.7;
    notifyListeners();
    
    await file.writeAsString(buffer.toString());
    
    return filePath;
  }

  String _getDataTypeLabel(ExportDataType dataType) {
    switch (dataType) {
      case ExportDataType.conversations:
        return 'Conversations';
      case ExportDataType.logs:
        return 'Logs';
      case ExportDataType.settings:
        return 'Settings';
      case ExportDataType.analytics:
        return 'Analytics';
      case ExportDataType.allData:
        return 'All Data';
      case ExportDataType.cachedData:
        return 'Cached Data';
    }
  }
}