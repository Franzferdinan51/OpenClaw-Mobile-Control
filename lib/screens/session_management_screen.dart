import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/session_service.dart';
import '../widgets/session_card.dart';

/// Screen for managing conversation sessions
class SessionManagementScreen extends StatefulWidget {
  final SessionService sessionService;
  final Function(Session)? onSessionSelected;

  const SessionManagementScreen({
    super.key,
    required this.sessionService,
    this.onSessionSelected,
  });

  @override
  State<SessionManagementScreen> createState() => _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Session> get _filteredSessions {
    if (_searchQuery.isEmpty) {
      return widget.sessionService.sessions;
    }
    final query = _searchQuery.toLowerCase();
    return widget.sessionService.sessions.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.messages.any((m) => m.content.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search sessions...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Session Management'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('New Session'),
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Import Session'),
                ),
              ),
              const PopupMenuItem(
                value: 'export_all',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export All Sessions'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Session>>(
        stream: widget.sessionService.sessionsStream,
        initialData: widget.sessionService.sessions,
        builder: (context, snapshot) {
          final sessions = _searchQuery.isEmpty
              ? snapshot.data ?? []
              : _filteredSessions;

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No sessions match your search'
                        : 'No sessions yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'Create a new session to get started',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _createNewSession(),
                      icon: const Icon(Icons.add),
                      label: const Text('New Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4AA),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            onReorder: (oldIndex, newIndex) {
              // Handle reordering if needed
            },
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isActive = widget.sessionService.activeSession?.id == session.id;

              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) => _confirmDelete(session),
                onDismissed: (direction) {
                  widget.sessionService.deleteSession(session.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Session "${session.name}" deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          // Restore session - would need to keep reference
                        },
                      ),
                    ),
                  );
                },
                child: SessionCard(
                  session: session,
                  isActive: isActive,
                  onTap: () => _selectSession(session),
                  onLongPress: () => _showSessionOptions(session),
                  onReset: () => _resetSession(session),
                  onCompact: () => _compactSession(session),
                  onExport: () => _exportSession(session),
                  onDelete: () => _deleteSession(session),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewSession(),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        backgroundColor: const Color(0xFF00D4AA),
        foregroundColor: Colors.black,
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new':
        _createNewSession();
        break;
      case 'import':
        _importSession();
        break;
      case 'export_all':
        _exportAllSessions();
        break;
    }
  }

  Future<void> _createNewSession() async {
    final session = await widget.sessionService.createSession();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created "${session.name}"'),
          action: SnackBarAction(
            label: 'Switch',
            onPressed: () => _selectSession(session),
          ),
        ),
      );
    }
  }

  void _selectSession(Session session) {
    widget.sessionService.switchSession(session.id);
    widget.onSessionSelected?.call(session);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to "${session.name}"'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _resetSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Session'),
        content: Text(
          'Clear all messages in "${session.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.sessionService.resetSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session reset'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _compactSession(Session session) async {
    final summaryController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compact Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Summarize the conversation in "${session.name}" to save context space.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: summaryController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Summary (optional)',
                hintText: 'Enter a summary of the conversation...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4AA),
              foregroundColor: Colors.black,
            ),
            child: const Text('Compact'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final summary = summaryController.text.isNotEmpty
          ? summaryController.text
          : 'Conversation compacted at ${DateTime.now()}';
      
      await widget.sessionService.compactSession(session.id, summary);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session compacted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    
    summaryController.dispose();
  }

  Future<void> _exportSession(Session session) async {
    final json = widget.sessionService.exportSession(session.id);
    
    await Clipboard.setData(ClipboardData(text: json));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session "${session.name}" copied to clipboard'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => Share.share(json, subject: session.name),
          ),
        ),
      );
    }
  }

  Future<void> _exportAllSessions() async {
    final sessions = widget.sessionService.sessions;
    final export = sessions.map((s) => s.toJson()).toList();
    final json = const JsonEncoder.withIndent('  ').convert(export);
    
    await Clipboard.setData(ClipboardData(text: json));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${sessions.length} sessions to clipboard'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => Share.share(json, subject: 'DuckBot Sessions'),
          ),
        ),
      );
    }
  }

  Future<void> _importSession() async {
    final controller = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the session JSON below:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '{"id": "...", "name": "...", ...}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      final session = await widget.sessionService.importSession(controller.text);
      
      if (mounted) {
        if (session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported "${session.name}"'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to import session - invalid JSON'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    controller.dispose();
  }

  Future<bool?> _confirmDelete(Session session) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Delete "${session.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await _confirmDelete(session);
    if (confirmed == true) {
      await widget.sessionService.deleteSession(session.id);
    }
  }

  void _showSessionOptions(Session session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameSession(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset'),
              onTap: () {
                Navigator.pop(context);
                _resetSession(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.compress),
              title: const Text('Compact'),
              onTap: () {
                Navigator.pop(context);
                _compactSession(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export'),
              onTap: () {
                Navigator.pop(context);
                _exportSession(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteSession(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameSession(Session session) async {
    final controller = TextEditingController(text: session.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Session name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await widget.sessionService.updateSession(
        session.copyWith(name: newName, updatedAt: DateTime.now()),
      );
    }
    
    controller.dispose();
  }
}