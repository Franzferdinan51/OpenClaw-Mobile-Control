import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';

class LogEntry {
  final String level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: (json['level'] ?? 'INFO').toString().toUpperCase(),
      message: json['message'] ?? json['msg'] ?? json['text'] ?? 'Unknown log',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : json['time'] != null
              ? DateTime.tryParse(json['time'].toString()) ?? DateTime.now()
              : DateTime.now(),
    );
  }
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedLevel = 'All';
  final List<LogEntry> _logs = [];
  GatewayService? _service;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
    final token = prefs.getString('gateway_token');

    setState(() {
      _service = GatewayService(baseUrl: gatewayUrl, token: token);
    });

    await _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    if (_service == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service!.getLogs(limit: 100);
      
      if (result is List) {
        // Direct list of logs
        setState(() {
          _logs.clear();
          _logs.addAll(result.map((log) => LogEntry.fromJson(log as Map<String, dynamic>)).toList());
          _loading = false;
        });
      } else if (result is Map && result['logs'] != null) {
        // Map with 'logs' key
        final logsList = result['logs'] as List;
        setState(() {
          _logs.clear();
          _logs.addAll(logsList.map((log) => LogEntry.fromJson(log as Map<String, dynamic>)).toList());
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          if (_logs.isEmpty) {
            _error = 'No logs available from gateway';
          }
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to fetch logs: $e';
      });
    }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Refresh logs',
          ),
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
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLogs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filteredLogs.isEmpty
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