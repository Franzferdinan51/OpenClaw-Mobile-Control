# Agent Monitor Dashboard - Feature Analysis

**Source:** https://github.com/Franzferdinan51/agent-monitor-openclaw-dashboard  
**Target:** DuckBot Mobile App (Flutter/Dart)  
**Analysis Date:** 2026-03-10  
**Analyst:** DuckBot Subagent

---

## Executive Summary

The agent-monitor-openclaw-dashboard is a Next.js/React web application providing real-time visualization of OpenClaw agent sessions. This analysis identifies the top features to integrate into the DuckBot mobile app, prioritized for mobile-first UX.

---

## Top 10 Features for Mobile Integration

### 1. 🟢 Live Agent Status Cards (HIGH PRIORITY)

**Source Component:** `src/components/dashboard/AgentCard.tsx`

**What it provides:**
- Real-time agent status display with behavior indicators
- Token usage visualization with progress bars
- Current tool/phase display
- Activity timestamps with relative time formatting
- Subagent count badges
- Quick actions (chat, restart, edit)
- Pixel-art avatar rendering

**Mobile Adaptation:**
- Card-based layout optimized for vertical scrolling
- Swipe gestures for quick actions
- Pull-to-refresh for manual updates
- Compact token bar (horizontal progress)
- Tap to expand full details (bottom sheet)
- Long-press for quick actions menu

**Key Features to Port:**
- StatusBadge with color-coded behaviors
- TokenBar with dynamic color thresholds (green/yellow/red)
- PixelAvatar canvas rendering (can use emoji fallback)
- Quick editor modal for agent customization

**Existing Implementation:** `lib/screens/agent_monitor_screen.dart` has basic version

---

### 2. 🟢 Real-Time Activity Feed (HIGH PRIORITY)

**Source Component:** `src/components/dashboard/ActivityFeed.tsx`

**What it provides:**
- Chronological event log with icons
- Event types: state_change, task_start, task_complete, task_fail, tool_call, message, error, system
- Agent attribution (emoji + name)
- Relative timestamps
- Auto-scroll to latest
- DOMPurify sanitization for messages

**Mobile Adaptation:**
- Vertical scrollable list (newest at top)
- Color-coded icons by event type
- Expandable message content
- Filter by agent/event type (tabs or dropdown)
- Vibration alerts for critical events (error, task_fail)

**Key Features to Port:**
- Event type styling (icon + color mapping)
- formatRelativeTime() utility
- Auto-scroll management
- Message sanitization

---

### 3. 🟢 Boss Chat / Global Broadcast (HIGH PRIORITY)

**Source Component:** `src/components/chat/GlobalChatPanel.tsx`

**What it provides:**
- Broadcast messages to all primary agents
- Filter tabs: All, Broadcasts, Direct, System
- Message history with agent attribution
- Real-time message streaming
- Target count display
- Send button with loading state

**Mobile Adaptation:**
- Bottom sheet for broadcast input
- Chat bubbles with agent emoji
- Swipe to filter by message type
- Quick reply suggestions
- Voice-to-text input option

**Existing Implementation:** ✅ `lib/screens/boss_chat_screen.dart` already implements basic version

---

### 4. 🟢 Per-Agent Direct Chat (HIGH PRIORITY)

**Source Component:** `src/components/chat/EnhancedChatPanel.tsx`, `ChatWindow.tsx`

**What it provides:**
- One-on-one messaging with specific agent
- Message history loading
- Thinking indicators
- Timestamp display
- Scope badges (direct/broadcast)

**Mobile Adaptation:**
- Chat interface with message bubbles
- Typing indicator animation
- Swipe to reply/forward
- Message reactions
- Read receipts (if supported)

**Existing Implementation:** ✅ `lib/screens/boss_chat_screen.dart` has `_DirectChatScreen`

---

### 5. 🟢 Token Usage Visualization (HIGH PRIORITY)

**Source Component:** `src/components/dashboard/SystemStats.tsx`, `AgentCard.tsx`

**What it provides:**
- Animated number counters
- System-wide stats (total agents, active, tokens, broadcasts, failed)
- Per-agent token bars with color thresholds
- Context limit visualization

**Mobile Adaptation:**
- Animated counters on stats cards
- Linear progress bars (not radial - harder to read small)
- Color thresholds: <50% green, 50-80% yellow, >80% red
- Pull-down to show detailed breakdown

**Key Features to Port:**
- AnimatedNumber component
- formatTokens() utility (K/M abbreviations)
- Token bar with gradient colors

---

### 6. 🟢 Agent Achievements/Leaderboard (HIGH PRIORITY)

**Source Component:** `src/components/achievements/Leaderboard.tsx`

**What it provides:**
- Ranked agent list by metric (tokens, tasks, uptime)
- Badge display for top 3
- Gradient backgrounds for ranks
- Number formatting for large values

**Mobile Adaptation:**
- Horizontal swipeable leaderboards (by metric)
- Animated rank changes
- Profile tap for agent details
- Confetti animation for top agent

**New Features for Mobile:**
- Achievement badges (unlocked through milestones)
- Daily/weekly/monthly leaderboards
- Push notifications for rank changes

---

### 7. 🟢 Theme Support (HIGH PRIORITY)

**Source Component:** `src/components/settings/SettingsPanel.tsx`

**Available Themes:**
1. **Midnight (default)** - Deep dark with cyan accents
2. **Void (dark)** - Coldest and darkest
3. **Warm (cozy)** - Warm tones and amber glow
4. **Neon (cyberpunk)** - High-contrast accent mode

**Mobile Adaptation:**
- Theme selection in settings
- System theme detection (follow device)
- Per-screen theme customization
- Animated theme transitions

**Implementation:**
- Use Flutter ThemeExtension
- Store preference in SharedPreferences
- Hot reload on theme change

---

### 8. 🟡 System Stats Dashboard (MEDIUM PRIORITY)

**Source Component:** `src/components/dashboard/SystemStats.tsx`

**What it provides:**
- Grid of stat cards with icons
- Total agents, primary, subagents, active, tokens, broadcasts, failed
- Connection status indicator

**Mobile Adaptation:**
- Horizontal scrollable stat bar at top
- Pull-down to expand full stats
- Stat card tap for drill-down

**Existing Implementation:** ✅ `lib/screens/dashboard_screen.dart` has basic stats

---

### 9. 🟡 Autowork Configuration (MEDIUM PRIORITY)

**Source Component:** `src/components/dashboard/AutoworkPanel.tsx`

**What it provides:**
- Per-agent auto-task policies
- Interval configuration
- Directive text input
- Enable/disable toggle
- Run-now action

**Mobile Adaptation:**
- List of agents with toggle switches
- Tap to configure interval/directive
- Quick action: Run now button
- Notification when auto-task completes

**Existing Implementation:** ✅ `lib/screens/autowork_screen.dart` exists

---

### 10. 🔴 Pixel-Art Office Visualization (FUTURE/COMPLEX)

**Source Components:** `src/components/office/*`, `src/sprites/*`

**What it provides:**
- Isometric pixel-art office view
- Agent sprites with animations
- Zone-based positioning (desk, meeting room, break room)
- Owner (boss) character
- Furniture placement

**Mobile Complexity:**
- Canvas rendering at different screen sizes
- Touch gestures for pan/zoom
- Performance optimization for 60fps
- Sprite atlas management

**Recommendation:** Defer to v2.1 or implement as static preview first

---

## Component Dependency Map

```
AgentCard
├── StatusBadge (shared component)
├── PixelAvatar (sprite rendering)
├── TokenBar (progress visualization)
└── AgentQuickEditor (modal)

ActivityFeed
├── formatRelativeTime (utility)
└── DOMPurify (sanitization)

GlobalChatPanel
├── ChatMessage model
└── Filter tabs

Leaderboard
├── LeaderboardEntry model
└── getRankStyle (helper)

SettingsPanel
├── ThemeSelector
├── OwnerCustomizer
├── AgentCustomizer
└── Toggle (UI component)
```

---

## TypeScript/React → Flutter/Dart Adaptation Notes

### Component Patterns

| React Pattern | Flutter Equivalent |
|--------------|-------------------|
| `useState` | `State<T>` with `setState()` |
| `useEffect` | `initState()` + `dispose()` |
| `useRef` | `GlobalKey` or instance variables |
| `useMemo` | Computed getters or `late final` |
| Props | Constructor parameters |
| Context | `InheritedWidget` or Provider |

### Styling

| React CSS | Flutter |
|-----------|---------|
| `style={{ color: 'var(--text-primary)' }}` | `TextStyle(color: theme.primaryColor)` |
| Tailwind classes | Custom `ThemeData` with extensions |
| CSS variables | `Theme.of(context).extension<MyTheme>()` |
| Hover states | `InkWell` with `onHover` |

### State Management

| React | Flutter Recommendation |
|-------|----------------------|
| Local state | `StatefulWidget` |
| Prop drilling | Provider / Riverpod |
| Context API | InheritedWidget / Provider |
| Redux | Redux.dart or Riverpod |

---

## UI/UX Adaptation: Desktop → Mobile

### Layout Changes

| Desktop Layout | Mobile Layout |
|---------------|---------------|
| Multi-column grid | Single column scroll |
| Fixed sidebar | Bottom navigation |
| Hover tooltips | Long-press for info |
| Right-click context menu | Long-press menu |
| Keyboard shortcuts | Swipe gestures + FAB |

### Interaction Changes

| Desktop Action | Mobile Action |
|---------------|---------------|
| Click | Tap |
| Hover | Long-press preview |
| Scroll | Vertical swipe |
| Drag | Pan gesture |
| Double-click | Double-tap |
| Right-click | Long-press |

### Responsive Considerations

- **Phone:** Single column, compact cards
- **Tablet:** Two-column grid, expanded details
- **Landscape:** Two-pane layout (list + detail)

---

## API Integration Points

### Existing Gateway Endpoints (Mobile Already Uses)

```
GET  /api/gateway              - Status
GET  /api/gateway/agents       - Agent list
GET  /api/gateway/stats        - System stats
POST /api/gateway/broadcast    - Boss chat
POST /api/gateway/agent/:key   - Direct message
GET  /api/gateway/events       - SSE stream
```

### New Endpoints Needed for Features

```
GET  /api/gateway/leaderboard  - Achievement data
GET  /api/gateway/achievements - Badge definitions
POST /api/gateway/autowork     - Configure auto-tasks
GET  /api/gateway/achievements/:agentId - Per-agent achievements
```

---

## Performance Considerations

### Mobile-Specific Optimizations

1. **Lazy Loading:** Load agents on-demand, not all at once
2. **Pagination:** Activity feed should paginate (50 items per page)
3. **Caching:** Cache agent data locally with SQLite
4. **Debouncing:** Token updates should debounce (300ms)
5. **Image Optimization:** Use emoji instead of sprite canvas for avatar
6. **Memory Management:** Dispose controllers in `dispose()`

### Animation Budget

- Target 60fps for scrolling
- Limit to 2-3 simultaneous animations
- Use `AnimatedBuilder` for smooth transitions
- Avoid `setState` in tight loops (use streams)

---

## Data Models to Create

### ActivityEvent Model (NEW)

```dart
class ActivityEvent {
  final String id;
  final String agentId;
  final String agentName;
  final String agentEmoji;
  final String type; // state_change, task_start, task_complete, etc.
  final String message;
  final DateTime timestamp;
}
```

### Achievement Model (NEW)

```dart
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int requiredValue;
  final String category; // tokens, tasks, uptime
}
```

### LeaderboardEntry Model (NEW)

```dart
class LeaderboardEntry {
  final int rank;
  final String agentId;
  final String agentName;
  final String agentEmoji;
  final int value;
  final String? badge;
}
```

---

## Conclusion

The agent-monitor-dashboard provides excellent features ready for mobile adaptation. Priority should be given to:

1. **Enhancing existing features** with real-time updates via SSE
2. **Adding leaderboard/achievements** for gamification
3. **Implementing theme support** for personalization
4. **Deferring complex features** (pixel-art office) to v2.1

**Estimated Implementation Time:**
- High Priority Features: 2-3 weeks
- Medium Priority Features: 1 week
- Low Priority Features: Future release

**Dependencies:**
- ✅ Gateway service already exists
- ✅ Agent session model exists
- ⚠️ SSE streaming needs enhancement
- ⚠️ Theme system needs creation