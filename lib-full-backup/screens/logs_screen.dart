import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Logs Screen - Live log viewer with filters
class LogsScreen extends ConsumerStatefulWidget {
  final String? source;

  const LogsScreen({super.key, this.source});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  bool _autoScroll = true;
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    // Load logs on init
    Future.microtask(() => ref.read(logsProvider.notifier).loadLogs());

    // Auto-scroll to bottom when new logs arrive
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 100) {
        setState(() => _autoScroll = false);
      }
    });
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
    final logsState = ref.watch(logsProvider);
    final filter = ref.watch(logFilterProvider);
    final filteredLogs = ref.watch(filteredLogsProvider);
    final logCounts = ref.watch(logCountByLevelProvider);
    final availableSources = ref.watch(logSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.vertical_align_center_rounded,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
                if (_autoScroll) {
                  _scrollToBottom();
                }
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          ),
          // Filter toggle
          IconButton(
            icon: Badge(
              isLabelVisible: filter.levels.isNotEmpty || filter.sources.isNotEmpty,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => setState(() => _showFilterPanel = !_showFilterPanel),
            tooltip: 'Filters',
          ),
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _showClearConfirmation(context),
            tooltip: 'Clear logs',
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenuAction(action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Export logs'),
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_rounded),
                  title: Text('Share logs'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_rounded),
                  title: Text('Log settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          // Log level summary bar
          _buildLogLevelBar(context, logCounts, filteredLogs.length),
          // Filter panel
          if (_showFilterPanel) _buildFilterPanel(context, filter, availableSources),
          // Search bar
          _buildSearchBar(context),
          // Log count
          _buildLogCount(context, filteredLogs.length, logsState.valueOrNull?.length ?? 0),
          // Log list
          Expanded(
            child: logsState.when(
              data: (logs) => _buildLogList(context, filteredLogs),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorState(context, e.toString()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildLogLevelBar(
    BuildContext context,
    Map<LogLevel, int> counts,
    int visibleCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: LogLevel.values.map((level) {
          final count = counts[level] ?? 0;
          final color = _getLevelColor(level);

          return Expanded(
            child: GestureDetector(
              onTap: () => _toggleLevelFilter(level),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      level.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterPanel(
    BuildContext context,
    LogFilter filter,
    List<String> sources,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level filters
          Text(
            'Log Levels',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LogLevel.values.map((level) {
              final isSelected = filter.levels.contains(level);
              final color = _getLevelColor(level);

              return FilterChip(
                label: Text(level.displayName),
                selected: isSelected,
                onSelected: (_) => _toggleLevelFilter(level),
                selectedColor: color.withOpacity(0.2),
                checkmarkColor: color,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Source filters
          if (sources.isNotEmpty) ...[
            Text(
              'Sources',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources.take(10).map((source) {
                final isSelected = filter.sources.contains(source);

                return FilterChip(
                  label: Text(source),
                  selected: isSelected,
                  onSelected: (_) => _toggleSourceFilter(source),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Clear filters button
          if (filter.levels.isNotEmpty || filter.sources.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(logFilterProvider.notifier).reset(),
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filter = ref.watch(logFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => ref.read(logFilterProvider.notifier).setSearchQuery(value),
        decoration: InputDecoration(
          hintText: 'Search logs...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: filter.searchQuery?.isNotEmpty == true
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(logFilterProvider.notifier).setSearchQuery(null);
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCount(BuildContext context, int visible, int total) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Showing $visible of $total entries',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_autoScroll)
            Row(
              children: [
                Icon(
                  Icons.vertical_align_bottom_rounded,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<LogEntry> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) => _LogEntryTile(
        log: logs[index],
        onTap: () => _showLogDetails(logs[index]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filter = ref.watch(logFilterProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filter.levels.isNotEmpty || filter.sources.isNotEmpty
                  ? 'No matching logs'
                  : 'No logs yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filter.levels.isNotEmpty || filter.sources.isNotEmpty
                  ? 'Try adjusting your filters'
                  : 'Logs will appear here when events occur',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Logs',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(logsProvider.notifier).loadLogs(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 4, // Logs is in settings area
      onDestinationSelected: (index) => _navigateTo(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Control',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: 'Quick',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/chat');
      case 2:
        context.go('/control');
      case 3:
        context.go('/quick-actions');
      case 4:
        context.go('/settings');
    }
  }

  void _toggleLevelFilter(LogLevel level) {
    ref.read(logFilterProvider.notifier).toggleLevel(level);
  }

  void _toggleSourceFilter(String source) {
    ref.read(logFilterProvider.notifier).toggleSource(source);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showLogDetails(LogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LogDetailSheet(log: log),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(logsProvider.notifier).clearLogs();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportLogs();
      case 'share':
        _shareLogs();
      case 'settings':
        context.go('/settings');
    }
  }

  void _exportLogs() {
    final logs = ref.read(logsProvider).valueOrNull ?? [];
    final text = logs.map((log) {
      return '[${log.formattedTimestamp}] [${log.level.displayName}] [${log.source}] ${log.message}';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _shareLogs() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon...')),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.fatal:
        return Colors.purple;
    }
  }
}

// ============================================================================
// LOG ENTRY TILE
// ============================================================================

class _LogEntryTile extends StatelessWidget {
  final LogEntry log;
  final VoidCallback onTap;

  const _LogEntryTile({
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final levelColor = _getLevelColor(log.level);

    return InkWell(
      onTap: onTap,
      onLongPress: () => _copyLog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level indicator
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: levelColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Timestamp
                      Text(
                        log.formattedTimestamp,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Source
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.source,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Level badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.level.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message
                  Text(
                    log.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: _containsCode(log.message) ? 'monospace' : null,
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

  void _copyLog(BuildContext context) {
    Clipboard.setData(ClipboardData(text: log.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.fatal:
        return Colors.purple;
    }
  }

  bool _containsCode(String text) {
    return text.contains('{') ||
        text.contains('}') ||
        text.contains('()') ||
        text.contains('=>') ||
        text.contains('Error:') ||
        text.contains('Exception:');
  }
}

// ============================================================================
// LOG DETAIL SHEET
// ============================================================================

class _LogDetailSheet extends StatelessWidget {
  final LogEntry log;

  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final levelColor = _getLevelColor(log.level);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: levelColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          log.level.displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: log.message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy',
                  ),
                ],
              ),
              const Divider(height: 32),
              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow(context, 'Time', log.formattedTimestamp),
                    _buildDetailRow(context, 'Level', log.level.name.toUpperCase()),
                    _buildDetailRow(context, 'Source', log.source),
                    const SizedBox(height: 16),
                    // Message
                    Text(
                      'Message',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    // Stack trace
                    if (log.stackTrace != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Stack Trace',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                    // Metadata
                    if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Metadata',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _formatMetadata(log.metadata!),
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
      },
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

  String _formatMetadata(Map<String, dynamic> metadata) {
    return metadata.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.fatal:
        return Colors.purple;
    }
  }
}