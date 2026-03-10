import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService();
  bool _isLoading = true;
  List<FileSystemEntity> _exportedFiles = [];
  String _totalSize = '0 MB';
  
  ExportDataType _selectedDataType = ExportDataType.allData;
  ExportFormat _selectedFormat = ExportFormat.json;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _exportService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _exportService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await _exportService.initialize();
    final files = await _exportService.getExportedFiles();
    
    int totalBytes = 0;
    for (final file in files) {
      if (file is File) {
        totalBytes += await file.length();
      }
    }
    
    setState(() {
      _exportedFiles = files;
      _totalSize = _formatBytes(totalBytes);
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _performExport() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    // Sample data for demonstration
    Map<String, dynamic> data;
    switch (_selectedDataType) {
      case ExportDataType.conversations:
        data = {
          'conversations': [
            {'role': 'user', 'content': 'Hello!'},
            {'role': 'assistant', 'content': 'Hi there! How can I help?'},
          ]
        };
        break;
      case ExportDataType.logs:
        data = {
          'logs': [
            {'timestamp': DateTime.now().toIso8601String(), 'level': 'INFO', 'message': 'App started'},
          ]
        };
        break;
      case ExportDataType.settings:
        data = {
          'app_mode': 'basic',
          'theme': 'system',
          'notifications_enabled': true,
        };
        break;
      case ExportDataType.allData:
        data = {
          'version': '2.0',
          'createdAt': DateTime.now().toIso8601String(),
          'appSettings': {'theme': 'system'},
          'conversations': [],
          'logs': [],
        };
        break;
      default:
        data = {};
    }

    final result = await _exportService.exportData(
      dataType: _selectedDataType,
      format: _selectedFormat,
      data: data,
    );

    setState(() {
      _isExporting = false;
      _exportProgress = 1.0;
    });

    if (mounted) {
      if (result.success) {
        _showExportSuccessDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Export failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${result.filePath?.split('/').last}'),
            Text('Size: ${_formatBytes(result.bytesWritten)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportService.shareExportedFile(result.filePath!);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete ${file.path.split('/').last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _exportService.deleteExportedFile(file.path);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Export Options Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Data Type Selection
                        const Text('What to export:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ExportDataType.values.map((type) {
                            return ChoiceChip(
                              label: Text(_getDataTypeLabel(type)),
                              selected: _selectedDataType == type,
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedDataType = type);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Format Selection
                        const Text('Export format:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ExportFormat.values.map((format) {
                            return ChoiceChip(
                              label: Text(format.name.toUpperCase()),
                              selected: _selectedFormat == format,
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedFormat = format);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Export Button
                        if (_isExporting) ...[
                          LinearProgressIndicator(value: _exportProgress),
                          const SizedBox(height: 8),
                          Text(
                            'Exporting... ${(_exportProgress * 100).toInt()}%',
                            textAlign: TextAlign.center,
                          ),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _performExport,
                              icon: const Icon(Icons.file_download),
                              label: const Text('Export'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Exported Files
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Exported Files (${_exportedFiles.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total: $_totalSize',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_exportedFiles.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.folder_open, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No exported files yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _exportedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _exportedFiles[index];
                              final fileName = file.path.split('/').last;
                              final stat = file.statSync();
                              
                              return ListTile(
                                leading: Icon(
                                  _getFileIcon(fileName),
                                  color: Colors.blue,
                                ),
                                title: Text(fileName),
                                subtitle: Text(
                                  '${_formatBytes(stat.size)} • ${DateFormat('MMM dd, HH:mm').format(stat.modified)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: () => _exportService.shareExportedFile(file.path),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteFile(file),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _getDataTypeLabel(ExportDataType type) {
    switch (type) {
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
        return 'Cached';
    }
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.json')) return Icons.code;
    if (fileName.endsWith('.txt')) return Icons.article;
    if (fileName.endsWith('.md')) return Icons.description;
    if (fileName.endsWith('.csv')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }
}