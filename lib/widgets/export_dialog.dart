import 'package:flutter/material.dart';
import '../services/chat_export_service.dart';

/// Export format selection with preview
class ExportDialog extends StatefulWidget {
  final List<ExportMessage> messages;
  final String? title;
  final bool showPreview;

  const ExportDialog({
    super.key,
    required this.messages,
    this.title,
    this.showPreview = true,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.markdown;
  bool _isExporting = false;
  bool _includeTimestamp = true;
  String? _previewContent;

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  void _updatePreview() {
    setState(() {
      switch (_selectedFormat) {
        case ExportFormat.markdown:
          _previewContent = ChatExportService.exportToMarkdown(
            widget.messages,
            title: widget.title,
          );
          break;
        case ExportFormat.json:
          _previewContent = ChatExportService.exportToJSON(
            widget.messages,
            title: widget.title,
          );
          break;
        case ExportFormat.text:
          _previewContent = ChatExportService.exportToText(
            widget.messages,
            title: widget.title,
          );
          break;
        case ExportFormat.pdf:
          _previewContent = 'PDF Preview\n\n'
              '${widget.messages.length} messages will be exported.\n\n'
              '• Format: A4 page size\n'
              '• Includes: Timestamps, sender names, message content\n'
              '• Styled with headers and footers';
          break;
      }
    });
  }

  Future<void> _shareExport() async {
    setState(() => _isExporting = true);
    
    try {
      final success = await ChatExportService.exportAndShare(
        widget.messages,
        format: _selectedFormat,
        title: widget.title,
      );
      
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chat exported as ${_selectedFormat.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to share export'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _saveExport() async {
    setState(() => _isExporting = true);
    
    try {
      final path = await ChatExportService.exportToFile(
        widget.messages,
        format: _selectedFormat,
        title: widget.title,
      );
      
      if (mounted) {
        if (path != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to: $path'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () async {
                  await ChatExportService.exportAndShare(
                    widget.messages,
                    format: _selectedFormat,
                    title: widget.title,
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save export'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Export Chat'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selection
            Text(
              'Export Format',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportFormat.values.map((format) {
                final isSelected = format == _selectedFormat;
                return ChoiceChip(
                  avatar: Icon(
                    format.icon,
                    size: 16,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                  label: Text(format.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFormat = format);
                      _updatePreview();
                    }
                  },
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Message count
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline, 
                    size: 20, 
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.messages.length} messages will be exported',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Preview
            if (widget.showPreview) ...[
              Text(
                'Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _previewContent ?? '',
                    style: TextStyle(
                      fontFamily: _selectedFormat == ExportFormat.json ? 'monospace' : null,
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _saveExport,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Save'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _shareExport,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share),
          label: const Text('Share'),
        ),
      ],
    );
  }
}

/// Simple export bottom sheet for quick actions
class ExportBottomSheet extends StatelessWidget {
  final List<ExportMessage> messages;
  final String? title;

  const ExportBottomSheet({
    super.key,
    required this.messages,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ExportMessage> messages,
    String? title,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => ExportBottomSheet(
        messages: messages,
        title: title,
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, ExportFormat format) async {
    Navigator.of(context).pop();
    
    final success = await ChatExportService.exportAndShare(
      messages,
      format: format,
      title: title,
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Chat exported as ${format.displayName}'
                : 'Failed to export chat',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Export Chat',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${messages.length} messages',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose export format:',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ExportFormat.values.map((format) {
                return _ExportFormatButton(
                  format: format,
                  onTap: () => _handleExport(context, format),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => ExportDialog(
                      messages: messages,
                      title: title,
                    ),
                  );
                },
                icon: const Icon(Icons.preview),
                label: const Text('Preview & Customize'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportFormatButton extends StatelessWidget {
  final ExportFormat format;
  final VoidCallback onTap;

  const _ExportFormatButton({
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(format.icon, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              format.extension.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick export FAB for chat screens
class ExportFab extends StatelessWidget {
  final List<ExportMessage> messages;
  final String? title;

  const ExportFab({
    super.key,
    required this.messages,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'export_fab',
      onPressed: () => ExportBottomSheet.show(
        context,
        messages: messages,
        title: title,
      ),
      tooltip: 'Export chat',
      child: const Icon(Icons.download),
    );
  }
}