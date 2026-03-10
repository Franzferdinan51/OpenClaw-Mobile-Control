import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ImportService _importService = ImportService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _importHistory = [];
  String? _selectedFilePath;
  Map<String, dynamic>? _validationResult;
  
  ConflictResolution _conflictResolution = ConflictResolution.askEachTime;

  @override
  void initState() {
    super.initState();
    _loadData();
    _importService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _importService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await _importService.initialize();
    final history = await _importService.getImportHistory();
    
    setState(() {
      _importHistory = history;
      _isLoading = false;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'md'],
    );

    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path;
      
      setState(() {
        _selectedFilePath = filePath;
        _validationResult = null;
      });
      
      // Validate the file
      final validation = await _importService.validateFile(filePath!);
      setState(() {
        _validationResult = validation;
      });
    }
  }

  Future<void> _performImport() async {
    if (_selectedFilePath == null) return;
    
    final result = await _importService.importFromFile(
      _selectedFilePath!,
      resolution: _conflictResolution,
    );
    
    if (mounted) {
      if (result.success) {
        _showImportSuccessDialog(result);
        setState(() {
          _selectedFilePath = null;
          _validationResult = null;
        });
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Import failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportSuccessDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✓ Items imported: ${result.itemsImported}'),
            if (result.itemsSkipped > 0)
              Text('⊘ Items skipped: ${result.itemsSkipped}'),
            if (result.conflictsResolved > 0)
              Text('⚡ Conflicts resolved: ${result.conflictsResolved}'),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...result.warnings.map((w) => Text('• $w', style: const TextStyle(fontSize: 12))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Clear import history? This won\'t affect imported data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _importService.clearImportHistory();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_history') _clearHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_history',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Clear History'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // File Selection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select File',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Pick File Button
                        InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedFilePath != null
                                    ? Colors.green
                                    : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _selectedFilePath != null
                                      ? Icons.check_circle
                                      : Icons.upload_file,
                                  size: 48,
                                  color: _selectedFilePath != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFilePath != null
                                      ? _selectedFilePath!.split('/').last
                                      : 'Tap to select a file',
                                  style: TextStyle(
                                    color: _selectedFilePath != null
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                if (_selectedFilePath != null)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedFilePath = null;
                                        _validationResult = null;
                                      });
                                    },
                                    child: const Text('Clear'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Validation Result
                        if (_validationResult != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _validationResult!['valid'] == true
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _validationResult!['valid'] == true
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: _validationResult!['valid'] == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _validationResult!['valid'] == true
                                          ? 'Valid File'
                                          : 'Invalid File',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _validationResult!['valid'] == true
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_validationResult!['valid'] == true) ...[
                                  const SizedBox(height: 8),
                                  Text('Type: ${_validationResult!['type']}'),
                                  Text('Items: ${_validationResult!['items']}'),
                                  if ((_validationResult!['warnings'] as List).isNotEmpty)
                                    Text(
                                      'Warnings: ${(_validationResult!['warnings'] as List).join(', ')}',
                                      style: const TextStyle(color: Colors.orange),
                                    ),
                                ],
                                if ((_validationResult!['errors'] as List).isNotEmpty)
                                  Text(
                                    'Errors: ${(_validationResult!['errors'] as List).join(', ')}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Conflict Resolution
                if (_selectedFilePath != null && _validationResult?['valid'] == true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Conflict Resolution',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'What to do if imported data conflicts with existing data?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ...ConflictResolution.values.map((resolution) {
                            return RadioListTile<ConflictResolution>(
                              title: Text(_getResolutionLabel(resolution)),
                              subtitle: Text(_getResolutionDescription(resolution)),
                              value: resolution,
                              groupValue: _conflictResolution,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _conflictResolution = value);
                                }
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Import Button
                if (_selectedFilePath != null && _validationResult?['valid'] == true)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _importService.isImporting ? null : _performImport,
                      icon: _importService.isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload),
                      label: Text(_importService.isImporting ? 'Importing...' : 'Import'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Import History
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_importHistory.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No imports yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _importHistory.length,
                            itemBuilder: (context, index) {
                              final entry = _importHistory[index];
                              final timestamp = DateTime.tryParse(entry['timestamp'] ?? '') ?? DateTime.now();
                              
                              return ListTile(
                                leading: const Icon(Icons.history, color: Colors.grey),
                                title: Text(entry['type'] ?? 'Unknown'),
                                subtitle: Text(
                                  '${entry['imported']} imported, ${entry['skipped']} skipped',
                                ),
                                trailing: Text(
                                  DateFormat('MMM dd, HH:mm').format(timestamp),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  String _getResolutionLabel(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepExisting:
        return 'Keep Existing';
      case ConflictResolution.replaceWithImport:
        return 'Replace with Import';
      case ConflictResolution.merge:
        return 'Merge';
      case ConflictResolution.askEachTime:
        return 'Ask Each Time';
    }
  }

  String _getResolutionDescription(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepExisting:
        return 'Don\'t overwrite existing data';
      case ConflictResolution.replaceWithImport:
        return 'Replace existing data with imported data';
      case ConflictResolution.merge:
        return 'Combine imported and existing data';
      case ConflictResolution.askEachTime:
        return 'Prompt for each conflict';
    }
  }
}