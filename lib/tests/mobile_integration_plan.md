# Mobile Integration Plan

**Project:** Agent Monitor Dashboard → DuckBot Mobile  
**Target Platform:** Flutter/Dart (iOS, Android)  
**Created:** 2026-03-10  
**Status:** Planning Complete

---

## Overview

This document outlines the step-by-step implementation plan for integrating agent-monitor-dashboard features into the DuckBot mobile app. Features are prioritized based on user value and implementation complexity.

---

## Implementation Roadmap

### Phase 1: Core Enhancements (Week 1-2)

**Goal:** Enhance existing features with real-time updates and better UX

#### 1.1 Real-Time SSE Integration

**Current State:** Mobile polls every 5 seconds  
**Target State:** Real-time updates via Server-Sent Events

**Tasks:**
- [ ] Create `SSEService` class for persistent connection
- [ ] Implement auto-reconnect with exponential backoff
- [ ] Parse event types from `/api/gateway/events`
- [ ] Stream to Riverpod providers
- [ ] Handle connection state in UI

**Files to Create/Modify:**
```
lib/services/sse_service.dart          (NEW)
lib/providers/agent_provider.dart      (NEW - Riverpod)
lib/providers/activity_provider.dart   (NEW - Riverpod)
lib/screens/agent_monitor_screen.dart  (MODIFY - use streams)
```

**SSE Event Types to Handle:**
```dart
enum SSEEventType {
  open,       // Connection established
  state,      // Agent state change
  heartbeat,  // Keep-alive
}
```

---

#### 1.2 Enhanced Agent Cards

**Current State:** Basic card with status and tokens  
**Target State:** Rich card with animations and quick actions

**Tasks:**
- [ ] Add animated token bar with color thresholds
- [ ] Implement status badge with behavior icons
- [ ] Add subagent count badge
- [ ] Create quick actions menu (long-press)
- [ ] Add pull-to-refresh gesture

**Widget Structure:**
```dart
AgentCard
├── AgentAvatar (emoji or initial)
├── AgentHeader
│   ├── Name + Emoji
│   ├── StatusBadge
│   └── SubagentBadge
├── AgentInfo
│   ├── Model name
│   ├── Current tool (if any)
│   └── Status summary
├── TokenBar
│   ├── Progress indicator
│   └── Token count label
├── LastActivity
└── QuickActions (swipe or long-press)
    ├── Chat
    ├── Restart
    └── Details
```

**Color Thresholds:**
```dart
Color getTokenBarColor(double percentage) {
  if (percentage > 80) return Colors.red;
  if (percentage > 50) return Colors.orange;
  return Colors.green;
}
```

---

#### 1.3 Activity Feed Screen

**Current State:** No activity feed  
**Target State:** Real-time event log

**Tasks:**
- [ ] Create `ActivityFeedScreen`
- [ ] Create `ActivityEvent` model
- [ ] Implement event type styling
- [ ] Add filter tabs (All, Tasks, Tools, Errors)
- [ ] Implement auto-scroll to newest

**Widget Structure:**
```dart
ActivityFeedScreen
├── AppBar with filters
├── EventListView
│   └── ActivityEventCard
│       ├── EventIcon (color-coded)
│       ├── AgentInfo (emoji + name)
│       ├── Message
│       └── Timestamp
└── EmptyState (if no events)
```

**Event Type Styling:**
```dart
const eventStyles = {
  'state_change': {'icon': Icons.sync, 'color': Colors.blue},
  'task_start':   {'icon': Icons.play_arrow, 'color': Colors.green},
  'task_complete': {'icon': Icons.check_circle, 'color': Colors.green},
  'task_fail':    {'icon': Icons.error, 'color': Colors.red},
  'tool_call':    {'icon': Icons.build, 'color': Colors.orange},
  'message':      {'icon': Icons.chat, 'color': Colors.purple},
  'error':        {'icon': Icons.warning, 'color': Colors.red},
  'system':       {'icon': Icons.computer, 'color': Colors.grey},
};
```

---

### Phase 2: Chat Enhancements (Week 2-3)

**Goal:** Full-featured boss chat and direct messaging

#### 2.1 Enhanced Boss Chat

**Current State:** Basic broadcast functionality  
**Target State:** Full-featured chat with filtering and history

**Tasks:**
- [ ] Add filter tabs (All, Broadcasts, Direct, System)
- [ ] Implement message history loading
- [ ] Add thinking indicators
- [ ] Create message bubbles with timestamps
- [ ] Add target count display
- [ ] Implement message sanitization

**Enhancements to `_DirectChatScreen`:**
- [ ] Add typing indicator animation
- [ ] Implement message status (sent, delivered, read)
- [ ] Add swipe-to-reply gesture
- [ ] Create quick reply suggestions

---

#### 2.2 Real-Time Message Streaming

**Tasks:**
- [ ] Create `ChatProvider` for message state
- [ ] Implement SSE message handling
- [ ] Add optimistic UI updates
- [ ] Handle message acknowledgments

---

### Phase 3: Gamification (Week 3-4)

**Goal:** Add achievements and leaderboards

#### 3.1 Leaderboard Screen

**Tasks:**
- [ ] Create `LeaderboardScreen`
- [ ] Create `LeaderboardEntry` model
- [ ] Implement tab-based metric switching
- [ ] Add rank badges (🥇🥈🥉)
- [ ] Create gradient backgrounds for top 3
- [ ] Add tap to view agent details

**Widget Structure:**
```dart
LeaderboardScreen
├── MetricTabs (Tokens, Tasks, Uptime)
├── LeaderboardList
│   └── LeaderboardEntryCard
│       ├── RankBadge
│       ├── AgentAvatar
│       ├── AgentName
│       └── Value
└── EmptyState
```

**Metrics:**
- **Tokens:** Total tokens used
- **Tasks:** Tasks completed
- **Uptime:** Session duration

---

#### 3.2 Achievement System

**Tasks:**
- [ ] Create `Achievement` model
- [ ] Create `AchievementService` for badge logic
- [ ] Implement achievement definitions
- [ ] Create `AchievementsScreen`
- [ ] Add notification on unlock

**Achievement Categories:**
```dart
enum AchievementCategory {
  tokens,    // Token milestones
  tasks,     // Task completion
  uptime,    // Time-based
  special,   // Special events
}
```

**Sample Achievements:**
```dart
const achievements = [
  Achievement(
    id: 'first_task',
    name: 'First Steps',
    description: 'Complete your first task',
    icon: '🎯',
    category: AchievementCategory.tasks,
    requiredValue: 1,
  ),
  Achievement(
    id: 'token_100k',
    name: 'Token Master',
    description: 'Process 100,000 tokens',
    icon: '🔥',
    category: AchievementCategory.tokens,
    requiredValue: 100000,
  ),
  Achievement(
    id: 'uptime_24h',
    name: 'Marathon Runner',
    description: 'Stay active for 24 hours',
    icon: '🏃',
    category: AchievementCategory.uptime,
    requiredValue: 86400, // seconds
  ),
];
```

---

### Phase 4: Theme System (Week 4)

**Goal:** Multiple theme support with persistence

#### 4.1 Theme Definitions

**Tasks:**
- [ ] Create `AppTheme` enum
- [ ] Define 4 theme variants
- [ ] Create `ThemeData` for each variant
- [ ] Implement theme extension for custom colors

**Theme Definitions:**
```dart
enum AppTheme {
  midnight,  // Deep dark with cyan
  void_,     // Coldest and darkest
  warm,      // Warm tones and amber
  neon,      // High-contrast cyberpunk
}

class AppColors extends ThemeExtension<AppColors> {
  final Color accentPrimary;
  final Color accentSuccess;
  final Color accentWarning;
  final Color accentDanger;
  final Color textPrimary;
  final Color textSecondary;
  final Color bgPrimary;
  final Color bgCard;
  final Color border;
  
  // ... implementation
}
```

#### 4.2 Theme Selection UI

**Tasks:**
- [ ] Add theme selector to settings
- [ ] Implement theme preview cards
- [ ] Add system theme detection
- [ ] Persist theme preference

---

### Phase 5: Integration (Week 5)

**Goal:** Integrate all features into app navigation

#### 5.1 Navigation Updates

**Tasks:**
- [ ] Add "Agents" tab to bottom navigation
- [ ] Create agent dashboard hub
- [ ] Link to existing screens

**Navigation Structure:**
```
BottomNav
├── Dashboard (existing)
├── Agents (NEW)
│   ├── Monitor (agent cards)
│   ├── Activity (event feed)
│   ├── Leaderboard
│   └── Achievements
├── Chat (existing boss_chat)
├── Tools (existing)
└── Settings (existing)
```

#### 5.2 Settings Integration

**Tasks:**
- [ ] Add agent configuration section
- [ ] Add theme selection
- [ ] Add boss identity customization
- [ ] Add notification preferences

---

## File Structure

### New Files to Create

```
lib/
├── models/
│   ├── activity_event.dart         (NEW)
│   ├── achievement.dart            (NEW)
│   └── leaderboard_entry.dart      (NEW)
├── services/
│   ├── sse_service.dart            (NEW)
│   └── achievement_service.dart    (NEW)
├── providers/
│   ├── agent_provider.dart         (NEW)
│   ├── activity_provider.dart      (NEW)
│   └── theme_provider.dart         (NEW)
├── screens/
│   ├── agent_dashboard_screen.dart (NEW - hub)
│   ├── activity_feed_screen.dart   (NEW)
│   └── achievements_screen.dart    (NEW)
├── widgets/
│   ├── agent_card_mobile.dart      (NEW - enhanced)
│   ├── activity_event_card.dart    (NEW)
│   ├── token_bar.dart              (NEW)
│   ├── status_badge.dart           (NEW)
│   ├── leaderboard_card.dart       (NEW)
│   └── achievement_badge.dart      (NEW)
└── theme/
    ├── app_theme.dart              (NEW)
    ├── theme_midnight.dart         (NEW)
    ├── theme_void.dart             (NEW)
    ├── theme_warm.dart             (NEW)
    └── theme_neon.dart             (NEW)
```

### Files to Modify

```
lib/
├── screens/
│   ├── agent_monitor_screen.dart   (enhance)
│   ├── boss_chat_screen.dart       (enhance)
│   ├── settings_screen.dart        (add theme config)
│   └── dashboard_screen.dart       (add navigation)
├── models/
│   └── agent_session.dart          (add behavior field)
└── services/
    └── gateway_service.dart        (add SSE methods)
```

---

## Code Templates

### SSE Service Template

```dart
// lib/services/sse_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SSEService {
  final String gatewayUrl;
  final String? token;
  
  HttpClient? _client;
  StreamSubscription? _subscription;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _client != null;
  
  SSEService({required this.gatewayUrl, this.token});
  
  Future<void> connect() async {
    final url = Uri.parse('$gatewayUrl/api/gateway/events');
    _client = HttpClient();
    
    final request = await _client!.getUrl(url);
    if (token != null) {
      request.headers.set('Authorization', 'Bearer $token');
    }
    
    final response = await request.close();
    
    _subscription = response.transform(utf8.decoder).listen(
      (data) => _parseEvent(data),
      onError: (e) => _reconnect(),
      onDone: () => _reconnect(),
    );
  }
  
  void _parseEvent(String data) {
    // Parse SSE format: event: state\ndata: {...}
    final lines = data.split('\n');
    String? eventType;
    String? eventData;
    
    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        eventData = line.substring(5).trim();
      }
    }
    
    if (eventData != null) {
      _eventController.add({
        'type': eventType ?? 'unknown',
        'data': jsonDecode(eventData),
      });
    }
  }
  
  Future<void> _reconnect() async {
    await Future.delayed(Duration(seconds: 5));
    await connect();
  }
  
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _client?.close();
    _client = null;
  }
}
```

### Enhanced Agent Card Template

```dart
// lib/widgets/agent_card_mobile.dart
import 'package:flutter/material.dart';

class AgentCardMobile extends StatelessWidget {
  final AgentSession agent;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onRestart;
  
  const AgentCardMobile({
    super.key,
    required this.agent,
    this.onTap,
    this.onChat,
    this.onRestart,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showQuickActions(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 12),
              _buildTokenBar(context),
              SizedBox(height: 8),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _buildAvatar(),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    agent.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (agent.emoji != null) ...[
                    SizedBox(width: 4),
                    Text(agent.emoji!),
                  ],
                ],
              ),
              SizedBox(height: 4),
              StatusBadge(behavior: agent.behavior ?? 'idle'),
            ],
          ),
        ),
        if (agent.subagentCount > 0)
          _buildSubagentBadge(),
      ],
    );
  }
  
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _getBehaviorColor().withOpacity(0.2),
      child: Text(
        agent.emoji ?? '🤖',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
  
  Widget _buildTokenBar(BuildContext context) {
    final usage = agent.totalTokens;
    final limit = agent.contextTokens > 0 ? agent.contextTokens : 128000;
    final percentage = (usage / limit * 100).clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tokens',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Spacer(),
            Text(
              _formatTokens(usage),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getTokenColor(percentage),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation(_getTokenColor(percentage)),
        ),
      ],
    );
  }
  
  Color _getTokenColor(double percentage) {
    if (percentage > 80) return Colors.red;
    if (percentage > 50) return Colors.orange;
    return Colors.green;
  }
  
  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
  
  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chat),
              title: Text('Chat'),
              onTap: () {
                Navigator.pop(context);
                onChat?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Restart'),
              onTap: () {
                Navigator.pop(context);
                onRestart?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Testing Strategy

### Unit Tests

```dart
// test/models/activity_event_test.dart
test('parses activity event from JSON', () {
  final json = {
    'id': 'evt-1',
    'agentId': 'agent-1',
    'type': 'task_complete',
    'message': 'Task completed',
    'timestamp': '2026-03-10T00:00:00Z',
  };
  
  final event = ActivityEvent.fromJson(json);
  expect(event.id, 'evt-1');
  expect(event.type, 'task_complete');
});
```

### Widget Tests

```dart
// test/widgets/agent_card_test.dart
testWidgets('displays agent name and emoji', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AgentCardMobile(
        agent: AgentSession(
          id: '1',
          name: 'DuckBot',
          emoji: '🦆',
          // ... other fields
        ),
      ),
    ),
  ));
  
  expect(find.text('DuckBot'), findsOneWidget);
  expect(find.text('🦆'), findsOneWidget);
});
```

### Integration Tests

```dart
// integration_test/agent_monitor_test.dart
testWidgets('agent monitor shows real-time updates', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to agent monitor
  await tester.tap(find.text('Agents'));
  await tester.pumpAndSettle();
  
  // Verify agents are displayed
  expect(find.byType(AgentCardMobile), findsWidgets);
  
  // Trigger refresh
  await tester.fling(find.byType(ListView), Offset(0, 500), 1000);
  await tester.pumpAndSettle();
});
```

---

## Risk Mitigation

### Technical Risks

| Risk | Mitigation |
|------|------------|
| SSE connection drops | Implement auto-reconnect with exponential backoff |
| Memory leaks | Use StreamController.broadcast() and dispose properly |
| Performance degradation | Lazy loading + pagination for lists |
| Theme conflicts | Use ThemeExtension for custom colors |

### UX Risks

| Risk | Mitigation |
|------|------------|
| Too much data | Implement filtering and search |
| Slow updates | Add optimistic UI updates |
| Confusing navigation | Clear bottom nav labels + icons |

---

## Success Metrics

### Phase 1 Success Criteria
- [ ] Real-time updates within 1 second of gateway event
- [ ] No more than 5 second delay for any state change
- [ ] Smooth scrolling (60fps) with 100+ agents

### Phase 2 Success Criteria
- [ ] Messages appear within 500ms of send
- [ ] Chat history loads in under 2 seconds
- [ ] No message loss during reconnection

### Phase 3 Success Criteria
- [ ] Achievement notifications appear immediately on unlock
- [ ] Leaderboard updates within 5 seconds of metric change

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|-----------------|
| Phase 1 | Week 1-2 | SSE integration, enhanced agent cards, activity feed |
| Phase 2 | Week 2-3 | Chat enhancements, real-time messaging |
| Phase 3 | Week 3-4 | Leaderboard, achievements |
| Phase 4 | Week 4 | Theme system |
| Phase 5 | Week 5 | Integration, testing, polish |

**Total Estimated Time:** 5 weeks

---

## Next Steps

1. **Review this plan** with team/maintainer
2. **Set up feature branches** for each phase
3. **Begin Phase 1** with SSE service implementation
4. **Create test fixtures** for mock gateway data
5. **Document API contracts** for any new endpoints needed

---

**Plan Status:** ✅ Complete  
**Ready for Implementation:** Yes  
**Dependencies Resolved:** Yes