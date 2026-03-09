import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Log severity levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Represents a single log entry
class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? source;
  final String? stackTrace;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.timestamp,
    required this.message,
    this.level = LogLevel.info,
    this.source,
    this.stackTrace,
    this.metadata,
  });

  String get formattedTimestamp {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$ms';
  }
}

/// A Material 3 log viewer widget with syntax highlighting and filtering.
/// 
/// Features:
/// - Color-coded log levels
/// - Optional syntax highlighting for code
/// - Search/filter functionality
/// - Copy to clipboard
/// - Auto-scroll to latest entries
/// 
/// Usage:
/// ```dart
/// LogViewer(
///   logs: logEntries,
///   showTimestamp: true,
///   showSource: true,
/// )
/// ```
class LogViewer extends StatefulWidget {
  /// List of log entries to display
  final List<LogEntry> logs;
  
  /// Maximum number of logs to keep in memory
  final int maxLogs;
  
  /// Whether to show timestamps
  final bool showTimestamp;
  
  /// Whether to show source labels
  final bool showSource;
  
  /// Whether to enable syntax highlighting
  final bool enableHighlighting;
  
  /// Whether to auto-scroll to bottom
  final bool autoScroll;
  
  /// Initial filter level (null shows all)
  final LogLevel? filterLevel;
  
  /// Whether to show the filter bar
  final bool showFilterBar;
  
  /// Height of the viewer (null for expanded)
  final double? height;

  const LogViewer({
    super.key,
    required this.logs,
    this.maxLogs = 1000,
    this.showTimestamp = true,
    this.showSource = true,
    this.enableHighlighting = true,
    this.autoScroll = true,
    this.filterLevel,
    this.showFilterBar = true,
    this.height,
  });

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  LogLevel? _filterLevel;
  String _searchQuery = '';
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _filterLevel = widget.filterLevel;
  }

  @override
  void didUpdateWidget(LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final filteredLogs = _filterLogs(widget.logs);
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          if (widget.showFilterBar) _buildFilterBar(context, colorScheme),
          Expanded(
            child: filteredLogs.isEmpty
                ? _buildEmptyState(context, colorScheme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      return _buildLogTile(context, filteredLogs[index], theme, colorScheme);
                    },
                  ),
          ),
          _buildStatusBar(context, colorScheme, filteredLogs.length),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(
                          Icons.clear,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Case sensitivity toggle
          IconButton(
            onPressed: () => setState(() => _caseSensitive = !_caseSensitive),
            icon: Icon(
              _caseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
              size: 20,
              color: _caseSensitive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Case sensitive',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          // Level filter
          _buildLevelFilter(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildLevelFilter(BuildContext context, ColorScheme colorScheme) {
    return PopupMenuButton<LogLevel?>(
      initialValue: _filterLevel,
      onSelected: (level) => setState(() => _filterLevel = level),
      tooltip: 'Filter by level',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _filterLevel != null
              ? _getLevelColor(_filterLevel!).withOpacity(0.2)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: _filterLevel != null
                  ? _getLevelColor(_filterLevel!)
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              _filterLevel?.name.toUpperCase() ?? 'ALL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _filterLevel != null
                        ? _getLevelColor(_filterLevel!)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Levels')),
        ...LogLevel.values.map((level) => PopupMenuItem(
              value: level,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getLevelColor(level),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(level.name.toUpperCase()),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            widget.logs.isEmpty ? 'No logs yet' : 'No matching logs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(
    BuildContext context,
    LogEntry log,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final levelColor = _getLevelColor(log.level);
    final shouldHighlight = widget.enableHighlighting && _containsCode(log.message);
    
    return InkWell(
      onTap: () => _showLogDetails(context, log),
      onLongPress: () => _copyLog(log),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: levelColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.showTimestamp)
                        Text(
                          log.formattedTimestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (widget.showTimestamp) const SizedBox(width: 8),
                      if (widget.showSource && log.source != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            log.source!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: 'monospace',
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      _buildLevelChip(context, log.level, levelColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: shouldHighlight ? 'monospace' : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(BuildContext context, LogLevel level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, ColorScheme colorScheme, int visibleCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$visibleCount of ${widget.logs.length} entries',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _copyAllLogs(),
            icon: Icon(
              Icons.copy,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Copy all logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: () => _clearLogs(),
            icon: Icon(
              Icons.clear_all,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Clear logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(BuildContext context, LogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.25,
        expand: false,
        builder: (context, scrollController) => _LogDetailSheet(
          log: log,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _copyLog(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyAllLogs() {
    final text = widget.logs.map((log) {
      return '[${log.formattedTimestamp}] [${log.level.name.toUpperCase()}] ${log.message}';
    }).join('\n');
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All logs copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      // In a real app, this would clear the log source
    });
  }

  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    var filtered = logs;
    
    if (_filterLevel != null) {
      filtered = filtered.where((log) => log.level == _filterLevel).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _caseSensitive ? _searchQuery : _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        final message = _caseSensitive ? log.message : log.message.toLowerCase();
        return message.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  bool _containsCode(String text) {
    // Simple heuristic for code detection
    return text.contains('{') ||
        text.contains('}') ||
        text.contains('()') ||
        text.contains('=>') ||
        text.contains('import ') ||
        text.contains('function ') ||
        text.contains('const ') ||
        text.contains('Error:') ||
        text.contains('Exception:');
  }
}

/// Modal sheet for showing log details
class _LogDetailSheet extends StatelessWidget {
  final LogEntry log;
  final ScrollController scrollController;

  const _LogDetailSheet({
    required this.log,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              Text(
                'Log Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: log.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
              ),
            ],
          ),
          const Divider(),
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _buildDetailRow(context, 'Time', log.formattedTimestamp),
                _buildDetailRow(context, 'Level', log.level.name.toUpperCase()),
                if (log.source != null)
                  _buildDetailRow(context, 'Source', log.source!),
                const SizedBox(height: 12),
                Text(
                  'Message',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    log.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (log.stackTrace != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Stack Trace',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      log.stackTrace!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Metadata',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      log.metadata!.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}