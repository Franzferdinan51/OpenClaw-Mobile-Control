# Bug List - OpenClaw Mobile App

**Generated:** March 10, 2026
**Total Bugs Found:** 23

---

## 🔴 Critical Bugs (Fix Immediately)

### BUG-001: Chat Response Memory Leak
**Location:** `lib/screens/chat_screen.dart:181`
**Severity:** Critical
**Description:** `_generateResponse()` uses `Future.delayed()` but doesn't check if widget is still mounted before calling `setState()`. This can cause memory leaks and "setState called after dispose" errors.

**Current Code:**
```dart
void _generateResponse(String userInput) {
  Future.delayed(const Duration(milliseconds: 800), () {
    // No mounted check before setState
    setState(() { ... });
  });
}
```

**Fix:**
```dart
void _generateResponse(String userInput) {
  Future.delayed(const Duration(milliseconds: 800), () {
    if (!mounted) return; // Add mounted check
    setState(() { ... });
  });
}
```

---

### BUG-002: Hold Timer Memory Leak
**Location:** `lib/screens/control_screen.dart`
**Severity:** Critical
**Description:** The hold-to-pause timer in `_ControlScreenState` doesn't get cancelled in `dispose()`, causing memory leaks if user navigates away while holding.

**Fix:**
```dart
@override
void dispose() {
  _holdTimer?.cancel(); // Add this line
  super.dispose();
}
```

---

### BUG-003: Logs Screen Uses Mock Data
**Location:** `lib/screens/logs_screen.dart:17-33`
**Severity:** Critical
**Description:** Logs screen shows hardcoded sample data instead of real gateway logs. Users cannot see actual system logs.

**Current Code:**
```dart
_logs.addAll([
  LogEntry(level: 'INFO', message: 'Gateway connected successfully', ...),
  // Hardcoded sample data
]);
```

**Fix:** Connect to `gatewayService.getLogs()` API instead of hardcoded data.

---

## 🟠 Medium Bugs (Fix Soon)

### BUG-004: Memory Percent Divide by Zero
**Location:** `lib/screens/dashboard_screen.dart:_buildHealthIndicator()`
**Severity:** Medium
**Description:** Memory percentage calculation can divide by zero if `memoryTotal` is 0.

**Current Code:**
```dart
final memoryPercent = _status?.memoryTotal != null && _status!.memoryTotal! > 0
    ? (_status!.memoryUsed!.toDouble() / _status!.memoryTotal!.toDouble() * 100.0)
    : 0.0;
```

**Issue:** Doesn't check if `memoryUsed` is null.

**Fix:**
```dart
final memoryPercent = (_status?.memoryTotal ?? 0) > 0 && _status?.memoryUsed != null
    ? (_status!.memoryUsed!.toDouble() / _status!.memoryTotal!.toDouble() * 100.0)
    : 0.0;
```

---

### BUG-005: Chat History Not Persisted
**Location:** `lib/screens/chat_screen.dart`
**Severity:** Medium
**Description:** All chat messages are lost when app restarts. No persistence mechanism implemented.

**Fix:** Implement SharedPreferences or SQLite storage for message history.

---

### BUG-006: No Rate Limiting on Message Sending
**Location:** `lib/screens/chat_screen.dart:_sendMessage()`
**Severity:** Medium
**Description:** Users can spam send button, potentially overwhelming the system.

**Fix:** Add debounce or disable button while previous message is processing.

---

### BUG-007: Quick Command Output Not Scrollable
**Location:** `lib/screens/quick_actions_screen.dart:_executeAction()`
**Severity:** Medium
**Description:** Command result dialog doesn't scroll for long output, truncating content.

**Fix:** Wrap `SelectabledText` in `SingleChildScrollView` with max height constraint.

---

### BUG-008: Agent Session Key Incorrect
**Location:** `lib/screens/control_screen.dart:_killAgent()`
**Severity:** Medium
**Description:** Uses `agent.name` as session key which may not match actual session key format expected by API.

**Fix:** Extract actual session key from agent data or use proper ID field.

---

### BUG-009: Model Hub Uses Mock Data
**Location:** `lib/screens/model_hub_screen.dart:23-29`
**Severity:** Medium
**Description:** Usage statistics are hardcoded mock data, not real usage from gateway.

**Current Code:**
```dart
final Map<String, Map<String, dynamic>> _modelUsage = {
  'bailian/qwen3.5-plus': {'used': 8200, 'limit': 18000, ...},
  // Hardcoded mock data
};
```

**Fix:** Fetch real usage data from gateway API.

---

### BUG-010: No Workflow Editing
**Location:** `lib/screens/workflows_screen.dart:_showEditDialog()`
**Severity:** Medium
**Description:** Can only view workflow steps, not edit them. Steps must be added via API.

**Fix:** Implement step editor UI or at least JSON editor.

---

### BUG-011: Discovery Service Errors Not Handled
**Location:** `lib/screens/settings_screen.dart:_startDiscovery()`
**Severity:** Medium
**Description:** Discovery errors are silently caught, user sees no feedback on failure.

**Fix:** Add error handling and show SnackBar on discovery failure.

---

### BUG-012: URL Validation Missing
**Location:** `lib/screens/settings_screen.dart:_buildManualTab()`
**Severity:** Medium
**Description:** Manual entry form only validates presence, not URL format validity.

**Fix:** Add URL format validation in TextFormField validator.

---

### BUG-013: Mode Change Doesn't Update Navigation
**Location:** `lib/app.dart:_onModeChanged()`
**Severity:** Medium
**Description:** Switching app mode doesn't immediately update bottom navigation tabs until full rebuild.

**Fix:** Force navigation rebuild with UniqueKey or explicit rebuild.

---

### BUG-014: BrowserOS Parse Errors Silently Caught
**Location:** `lib/screens/browser_control_screen.dart:_refreshPages()`
**Severity:** Medium
**Description:** JSON parse errors are silently ignored, making debugging difficult.

**Fix:** Log parse errors and show user-friendly error message.

---

## 🟡 Low Priority Bugs (Document)

### BUG-015: Future Timestamp Handling
**Location:** `lib/screens/dashboard_screen.dart:_getTimeAgo()`
**Severity:** Low
**Description:** Doesn't handle future timestamps, could show negative time.

---

### BUG-016: Scroll Position Check Missing
**Location:** `lib/screens/chat_screen.dart:_scrollToBottom()`
**Severity:** Low
**Description:** Always scrolls even if user is viewing older messages.

---

### BUG-017: Agent Emoji Overflow
**Location:** `lib/screens/chat_screen.dart:_buildMessageBubble()`
**Severity:** Low
**Description:** CircleAvatar emoji can overflow on small screens.

---

### BUG-018: Loading State Not Persisted
**Location:** `lib/screens/quick_actions_screen.dart`
**Severity:** Low
**Description:** Loading state resets when navigating away and back.

---

### BUG-019: Generic Placeholder Messages
**Location:** `lib/screens/quick_actions_screen.dart:_showPlaceholderDialog()`
**Severity:** Low
**Description:** All placeholder actions show generic message instead of specific guidance.

---

### BUG-020: Time Slider Usability
**Location:** `lib/screens/scheduled_tasks_screen.dart`
**Severity:** Low
**Description:** Time slider is difficult to use for precise time selection.

---

### BUG-021: Provider State Loss
**Location:** `lib/screens/node_settings_screen.dart`
**Severity:** Low
**Description:** Provider creates new instance on rebuild, losing state.

---

### BUG-022: Port Range Validation Missing
**Location:** `lib/screens/node_settings_screen.dart:_showPortDialog()`
**Severity:** Low
**Description:** Port validation only checks range, not validity of parsed integer.

---

### BUG-023: Connection History Navigation Missing
**Location:** `lib/screens/node_settings_screen.dart:_buildClientControlsSection()`
**Severity:** Low
**Description:** Connection history list tile doesn't navigate anywhere.

---

## Summary

| Severity | Count | Action |
|----------|-------|--------|
| Critical | 3 | Fix immediately |
| Medium | 11 | Fix in next sprint |
| Low | 9 | Document and fix as time permits |

**Estimated Fix Times:**
- Critical bugs: 2-4 hours each
- Medium bugs: 1-2 hours each
- Low bugs: 30 min - 1 hour each

**Total estimated fix time:** 25-35 developer hours