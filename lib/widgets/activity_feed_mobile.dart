import 'package:flutter/material.dart';

/// Activity event model for the feed
class ActivityEvent {
  final String id;
  final String agentId;
  final String agentName;
  final String agentEmoji;
  final String type;
  final String message;
  final DateTime timestamp;

  const ActivityEvent({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.agentEmoji,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      agentId: json['agentId'] ?? '',
      agentName: json['agentName'] ?? 'Unknown',
      agentEmoji: json['agentEmoji'] ?? '🤖',
      type: json['type'] ?? 'system',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentId': agentId,
        'agentName': agentName,
        'agentEmoji': agentEmoji,
        'type': type,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Mobile activity feed widget
/// 
/// Features:
/// - Real-time event log with auto-scroll
/// - Color-coded event types
/// - Filter tabs (All, Tasks, Tools, Errors)
/// - Pull-to-refresh
class ActivityFeedMobile extends StatefulWidget {
  final List<ActivityEvent> events;
  final bool loading;
  final String? error;
  final VoidCallback? onRefresh;
  final Function(String type)? onFilterChanged;

  const ActivityFeedMobile({
    super.key,
    required this.events,
    this.loading = false,
    this.error,
    this.onRefresh,
    this.onFilterChanged,
  });

  @override
  State<ActivityFeedMobile> createState() => _ActivityFeedMobileState();
}

class _ActivityFeedMobileState extends State<ActivityFeedMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ActivityFeedMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to top when new events arrive
    if (_autoScroll &&
        widget.events.length != oldWidget.events.length &&
        _scrollController.hasClients) {
      _scrollToTop();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging && widget.onFilterChanged != null) {
      final filters = ['all', 'tasks', 'tools', 'errors'];
      widget.onFilterChanged!(filters[_tabController.index]);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // Disable auto-scroll if user scrolls down
      setState(() {
        _autoScroll = _scrollController.offset < 50;
      });
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterTabs(context),
        Expanded(child: _buildEventList(context)),
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF00D4AA),
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: const Color(0xFF00D4AA),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Tasks'),
          Tab(text: 'Tools'),
          Tab(text: 'Errors'),
        ],
      ),
    );
  }

  Widget _buildEventList(BuildContext context) {
    if (widget.loading && widget.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return _buildErrorState();
    }

    final filteredEvents = _getFilteredEvents();

    if (filteredEvents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh?.call(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return ActivityEventCard(event: event);
        },
      ),
    );
  }

  List<ActivityEvent> _getFilteredEvents() {
    final index = _tabController.index;
    if (index == 0) return widget.events; // All

    final taskTypes = ['task_start', 'task_complete', 'task_fail'];
    final toolTypes = ['tool_call'];
    final errorTypes = ['error', 'task_fail'];

    switch (index) {
      case 1: // Tasks
        return widget.events.where((e) => taskTypes.contains(e.type)).toList();
      case 2: // Tools
        return widget.events.where((e) => toolTypes.contains(e.type)).toList();
      case 3: // Errors
        return widget.events.where((e) => errorTypes.contains(e.type)).toList();
      default:
        return widget.events;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_activity, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Events will appear here as agents work',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading events', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(widget.error!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Individual activity event card
class ActivityEventCard extends StatelessWidget {
  final ActivityEvent event;

  const ActivityEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final style = _getEventStyle(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: style.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(style.icon, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent info
                Row(
                  children: [
                    Text(
                      event.agentEmoji,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.agentName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: style.color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRelativeTime(event.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Message
                Text(
                  event.message,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _EventStyle _getEventStyle(String type) {
    switch (type) {
      case 'state_change':
        return _EventStyle('🔄', Colors.blue);
      case 'task_start':
        return _EventStyle('▶️', Colors.green);
      case 'task_complete':
        return _EventStyle('✅', Colors.green);
      case 'task_fail':
        return _EventStyle('❌', Colors.red);
      case 'tool_call':
        return _EventStyle('🔧', Colors.orange);
      case 'message':
        return _EventStyle('💬', Colors.purple);
      case 'error':
        return _EventStyle('🚨', Colors.red);
      case 'system':
        return _EventStyle('🖥️', Colors.grey);
      default:
        return _EventStyle('•', Colors.grey);
    }
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EventStyle {
  final String icon;
  final Color color;

  _EventStyle(this.icon, this.color);
}