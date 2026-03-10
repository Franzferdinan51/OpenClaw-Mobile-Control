import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Export format types
enum ExportFormat {
  markdown,
  pdf,
  json,
  text,
}

/// Extension for ExportFormat to get display info
extension ExportFormatExtension on ExportFormat {
  String get displayName {
    switch (this) {
      case ExportFormat.markdown:
        return 'Markdown (.md)';
      case ExportFormat.pdf:
        return 'PDF (.pdf)';
      case ExportFormat.json:
        return 'JSON (.json)';
      case ExportFormat.text:
        return 'Plain Text (.txt)';
    }
  }

  String get extension {
    switch (this) {
      case ExportFormat.markdown:
        return '.md';
      case ExportFormat.pdf:
        return '.pdf';
      case ExportFormat.json:
        return '.json';
      case ExportFormat.text:
        return '.txt';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFormat.markdown:
        return 'text/markdown';
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.text:
        return 'text/plain';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.markdown:
        return Icons.code;
      case ExportFormat.pdf:
        return Icons.picture_as_pdf;
      case ExportFormat.json:
        return Icons.data_object;
      case ExportFormat.text:
        return Icons.text_snippet;
    }
  }
}

/// Simple message model for export
class ExportMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? agentName;
  final String? agentEmoji;

  ExportMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.agentName,
    this.agentEmoji,
  });
}

/// Chat export service supporting multiple formats
class ChatExportService {
  /// Format a timestamp for display
  static String _formatDateTime(DateTime time) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
  }

  /// Format a timestamp for filename
  static String _formatFileName(DateTime time) {
    return DateFormat('yyyyMMdd_HHmmss').format(time);
  }

  /// Export chat to Markdown format
  static String exportToMarkdown(List<ExportMessage> messages, {String? title}) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('# ${title ?? 'DuckBot Chat Export'}');
    buffer.writeln();
    buffer.writeln('> Exported on ${_formatDateTime(DateTime.now())}');
    buffer.writeln('> ${messages.length} messages');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Messages
    for (final message in messages) {
      final sender = message.isUser 
          ? '👤 You' 
          : '${message.agentEmoji ?? '🦆'} ${message.agentName ?? 'DuckBot'}';
      
      buffer.writeln('### $sender');
      buffer.writeln('`[${_formatDateTime(message.timestamp)}]`');
      buffer.writeln();
      buffer.writeln(message.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export chat to JSON format
  static String exportToJSON(List<ExportMessage> messages, {String? title}) {
    final data = {
      'title': title ?? 'DuckBot Chat Export',
      'exportedAt': DateTime.now().toIso8601String(),
      'messageCount': messages.length,
      'messages': messages.map((m) => {
        'id': m.id,
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
        'agentName': m.agentName,
        'agentEmoji': m.agentEmoji,
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Export chat to plain text format
  static String exportToText(List<ExportMessage> messages, {String? title}) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('========================================');
    buffer.writeln(title ?? 'DuckBot Chat Export');
    buffer.writeln('========================================');
    buffer.writeln();
    buffer.writeln('Exported: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('Messages: ${messages.length}');
    buffer.writeln();
    buffer.writeln('----------------------------------------');
    buffer.writeln();

    // Messages
    for (final message in messages) {
      final sender = message.isUser 
          ? 'You' 
          : '${message.agentName ?? 'DuckBot'}';
      
      buffer.writeln('[${_formatDateTime(message.timestamp)}] $sender:');
      buffer.writeln();
      buffer.writeln(message.content);
      buffer.writeln();
      buffer.writeln('----------------------------------------');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export chat to PDF format
  static Future<Uint8List> exportToPDF(List<ExportMessage> messages, {String? title}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title ?? 'DuckBot Chat Export',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Exported on ${_formatDateTime(DateTime.now())} • ${messages.length} messages',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
        build: (context) => messages.map((message) {
          final sender = message.isUser 
              ? '👤 You' 
              : '${message.agentEmoji ?? '🦆'} ${message.agentName ?? 'DuckBot'}';
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    sender,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: message.isUser ? PdfColors.blue : PdfColors.green700,
                    ),
                  ),
                  pw.Text(
                    _formatDateTime(message.timestamp),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: message.isUser ? PdfColors.blue50 : PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(message.content),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );

    return pdf.save();
  }

  /// Save export to file and return the file path
  static Future<String?> saveExport(
    String content,
    ExportFormat format, {
    String? fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'duckbot_chat_${_formatFileName(DateTime.now())}';
      final file = File('${directory.path}/$name${format.extension}');
      
      await file.writeAsString(content);
      return file.path;
    } catch (e) {
      debugPrint('Error saving export: $e');
      return null;
    }
  }

  /// Save PDF export to file and return the file path
  static Future<String?> savePDFExport(
    Uint8List pdfBytes, {
    String? fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'duckbot_chat_${_formatFileName(DateTime.now())}';
      final file = File('${directory.path}/$name.pdf');
      
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF export: $e');
      return null;
    }
  }

  /// Share export via system share sheet
  static Future<bool> shareExport(
    String content,
    ExportFormat format, {
    String? subject,
    String? fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'duckbot_chat_${_formatFileName(DateTime.now())}';
      final file = File('${directory.path}/$name${format.extension}');
      
      await file.writeAsString(content);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'DuckBot Chat Export',
        text: 'Chat exported from DuckBot',
      );
      
      return true;
    } catch (e) {
      debugPrint('Error sharing export: $e');
      return false;
    }
  }

  /// Share PDF export via system share sheet
  static Future<bool> sharePDFExport(
    Uint8List pdfBytes, {
    String? subject,
    String? fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = fileName ?? 'duckbot_chat_${_formatFileName(DateTime.now())}';
      final file = File('${directory.path}/$name.pdf');
      
      await file.writeAsBytes(pdfBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'DuckBot Chat Export',
        text: 'Chat exported from DuckBot',
      );
      
      return true;
    } catch (e) {
      debugPrint('Error sharing PDF export: $e');
      return false;
    }
  }

  /// Export and share in one step
  static Future<bool> exportAndShare(
    List<ExportMessage> messages, {
    ExportFormat format = ExportFormat.markdown,
    String? title,
  }) async {
    try {
      if (format == ExportFormat.pdf) {
        final pdfBytes = await exportToPDF(messages, title: title);
        return await sharePDFExport(pdfBytes, subject: title);
      } else {
        String content;
        switch (format) {
          case ExportFormat.markdown:
            content = exportToMarkdown(messages, title: title);
            break;
          case ExportFormat.json:
            content = exportToJSON(messages, title: title);
            break;
          case ExportFormat.text:
            content = exportToText(messages, title: title);
            break;
          case ExportFormat.pdf:
            content = '';
            break;
        }
        return await shareExport(content, format, subject: title);
      }
    } catch (e) {
      debugPrint('Error exporting and sharing: $e');
      return false;
    }
  }

  /// Export to file and return path
  static Future<String?> exportToFile(
    List<ExportMessage> messages, {
    ExportFormat format = ExportFormat.markdown,
    String? title,
    String? fileName,
  }) async {
    try {
      if (format == ExportFormat.pdf) {
        final pdfBytes = await exportToPDF(messages, title: title);
        return await savePDFExport(pdfBytes, fileName: fileName);
      } else {
        String content;
        switch (format) {
          case ExportFormat.markdown:
            content = exportToMarkdown(messages, title: title);
            break;
          case ExportFormat.json:
            content = exportToJSON(messages, title: title);
            break;
          case ExportFormat.text:
            content = exportToText(messages, title: title);
            break;
          case ExportFormat.pdf:
            content = '';
            break;
        }
        return await saveExport(content, format, fileName: fileName);
      }
    } catch (e) {
      debugPrint('Error exporting to file: $e');
      return null;
    }
  }
}