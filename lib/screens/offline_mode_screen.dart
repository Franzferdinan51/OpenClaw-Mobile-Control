import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/offline_service.dart';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  final OfflineService _offlineService = OfflineService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _cachedItems = [];
  List<QueuedAction> _queuedActions = [];
  String _cacheSize = '0 MB';
  bool _offlineMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _offlineService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _offlineService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _offlineService.initialize();
    
    setState(() {
      _cachedItems = _offlineService.getCachedItemsSummary();
      _queuedActions = _offlineService.queuedActions;
      _cacheSize = 'Calculating...';
      _offlineMode = _offlineService.isOfflineMode;
    });

    final size = await _offlineService.getFormattedCacheSize();
    
    setState(() {
      _cacheSize = size;
      _isLoading = false;
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    await _offlineService.setOfflineMode(value);
    setState(() {
      _offlineMode = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Offline mode enabled' : 'Offline mode disabled'),
          backgroundColor: value ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Cache'),
          ],
        ),
        content: const Text(
          'This will delete all cached data. You won\'t be able to access this data offline. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineService.clearCache();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Cache cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Queue'),
          ],
        ),
        content: Text(
          'This will remove ${_queuedActions.length} queued action(s). These actions will not be synced. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineService.clearQueue();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Queue cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _removeQueuedAction(String id) async {
    await _offlineService.removeQueuedAction(id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Offline Mode Toggle
                Card(
                  child: SwitchListTile(
                    title: const Text('Offline Mode'),
                    subtitle: Text(
                      _offlineMode
                          ? 'App is working offline'
                          : 'App will sync when online',
                    ),
                    secondary: Icon(
                      _offlineMode ? Icons.cloud_off : Icons.cloud,
                      color: _offlineMode ? Colors.orange : Colors.green,
                    ),
                    value: _offlineMode,
                    onChanged: _toggleOfflineMode,
                  ),
                ),
                const SizedBox(height: 16),

                // Cache Statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cache Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _cachedItems.isEmpty ? null : _clearCache,
                              tooltip: 'Clear Cache',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'Cached Items',
                          '${_cachedItems.length}',
                          Icons.inventory,
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Cache Size',
                          _cacheSize,
                          Icons.storage,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Queued Actions
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
                              'Queued Actions (${_queuedActions.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear_all),
                              onPressed: _queuedActions.isEmpty ? null : _clearQueue,
                              tooltip: 'Clear Queue',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_queuedActions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No actions queued',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _queuedActions.length,
                            itemBuilder: (context, index) {
                              final action = _queuedActions[index];
                              return ListTile(
                                leading: const Icon(Icons.schedule),
                                title: Text(action.action),
                                subtitle: Text(
                                  'Queued: ${DateFormat('MMM dd, HH:mm').format(action.queuedAt)}\n'
                                  'Retries: ${action.retryCount}',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeQueuedAction(action.id),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cached Items List
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cached Items',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_cachedItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No cached items',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cachedItems.length,
                            itemBuilder: (context, index) {
                              final item = _cachedItems[index];
                              final isExpired = item['isExpired'] as bool? ?? false;
                              final cachedAt = item['cachedAt'] as DateTime?;
                              
                              return ListTile(
                                leading: Icon(
                                  isExpired ? Icons.warning : Icons.check_circle,
                                  color: isExpired ? Colors.orange : Colors.green,
                                ),
                                title: Text(item['key'] ?? 'Unknown'),
                                subtitle: Text(
                                  cachedAt != null
                                      ? 'Cached: ${DateFormat('MMM dd, HH:mm').format(cachedAt)}'
                                      : '',
                                ),
                                trailing: isExpired
                                    ? const Text(
                                        'Expired',
                                        style: TextStyle(color: Colors.orange),
                                      )
                                    : null,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Help Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'How Offline Mode Works',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Cached data is stored locally for offline access\n'
                        '• Actions performed offline are queued for sync\n'
                        '• When online, queued actions are synced automatically\n'
                        '• Expired cache items may need to be refreshed',
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}