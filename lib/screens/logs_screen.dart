import 'package:flutter/material.dart';

class LogEntry {
  final String level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedLevel = 'All';
  final List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    // Add sample log entries
    _logs.addAll([
      LogEntry(
        level: 'INFO',
        message: 'Gateway connected successfully',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      LogEntry(
        level: 'INFO',
        message: 'Agent status refreshed',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      LogEntry(
        level: 'WARN',
        message: 'Node connection slow',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      LogEntry(
        level: 'ERROR',
        message: 'Failed to fetch status',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      LogEntry(
        level: 'DEBUG',
        message: 'Processing request...',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _selectedLevel == 'All'
        ? _logs
        : _logs.where((log) => log.level == _selectedLevel).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedLevel = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'INFO', child: Text('INFO')),
              const PopupMenuItem(value: 'WARN', child: Text('WARN')),
              const PopupMenuItem(value: 'ERROR', child: Text('ERROR')),
              const PopupMenuItem(value: 'DEBUG', child: Text('DEBUG')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
          ),
        ],
      ),
      body: filteredLogs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No logs to display'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                return ListTile(
                  leading: Icon(
                    _getLogIcon(log.level),
                    color: _getLogColor(log.level),
                  ),
                  title: Text(log.message),
                  subtitle: Text(
                    '${log.level} • ${_formatTime(log.timestamp)}',
                    style: TextStyle(
                      color: _getLogColor(log.level),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _logs.insert(0, LogEntry(
              level: 'INFO',
              message: 'Manual log entry',
              timestamp: DateTime.now(),
            ));
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getLogIcon(String level) {
    switch (level) {
      case 'ERROR':
        return Icons.error;
      case 'WARN':
        return Icons.warning;
      case 'DEBUG':
        return Icons.bug_report;
      default:
        return Icons.info;
    }
  }

  Color _getLogColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARN':
        return Colors.orange;
      case 'DEBUG':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}