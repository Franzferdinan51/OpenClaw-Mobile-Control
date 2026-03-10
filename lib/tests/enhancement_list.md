# Enhancement List - OpenClaw Mobile App

**Generated:** March 10, 2026
**Total Enhancements:** 30

---

## 🟢 High Value Enhancements (Implement)

### ENH-001: Real Gateway API Integration for Chat
**Location:** `lib/screens/chat_screen.dart`
**Value:** High
**Description:** Connect chat screen to actual gateway API for real AI responses instead of local mock responses.

**Implementation:**
1. Create `ChatService` to interface with gateway
2. Implement streaming responses
3. Add error handling for API failures
4. Support multi-agent chat through gateway

**Impact:** Core functionality - makes chat actually useful

---

### ENH-002: Message Persistence
**Location:** `lib/screens/chat_screen.dart`
**Value:** High
**Description:** Persist chat messages so history survives app restarts.

**Implementation:**
1. Use SharedPreferences for simple storage
2. Or SQLite for full-featured storage with search
3. Implement message export functionality
4. Add clear history option

**Impact:** User experience - no data loss

---

### ENH-003: Real API for Quick Actions
**Location:** `lib/screens/quick_actions_screen.dart`
**Value:** High
**Description:** Implement actual functionality for GROW and WEATHER actions instead of placeholders.

**Implementation:**
1. Connect to sensor/camera APIs for GROW actions
2. Integrate weather API for weather actions
3. Add configuration for API endpoints

**Impact:** Core functionality

---

### ENH-004: Connect Logs to Real Gateway API
**Location:** `lib/screens/logs_screen.dart`
**Value:** High
**Description:** Replace mock data with real gateway log streaming.

**Implementation:**
1. Use WebSocket for real-time logs
2. Add log level filtering server-side
3. Implement log buffering for offline viewing
4. Add export to file

**Impact:** Debugging capability

---

### ENH-005: Real Usage Data in Model Hub
**Location:** `lib/screens/model_hub_screen.dart`
**Value:** High
**Description:** Connect usage statistics to actual gateway usage API.

**Implementation:**
1. Create usage API endpoint on gateway
2. Track per-model message counts
3. Display real-time usage bars
4. Add usage alerts when near limit

**Impact:** Cost management

---

### ENH-006: QR Code Scanning for Gateway Connection
**Location:** `lib/screens/settings_screen.dart`
**Value:** High
**Description:** Allow users to scan QR code from gateway to auto-configure connection.

**Implementation:**
1. Add qr_code_scanner package
2. Define QR data format
3. Auto-fill connection details from scan
4. Generate QR codes on gateway side

**Impact:** Easier setup

---

### ENH-007: Skeleton Loading States
**Location:** `lib/screens/dashboard_screen.dart`
**Value:** High
**Description:** Replace loading spinners with skeleton placeholders for better perceived performance.

**Implementation:**
1. Create skeleton widget components
2. Add shimmer animation
3. Show while data loads
4. Progressive reveal

**Impact:** Better UX during loading

---

## 🟡 Medium Value Enhancements (Document)

### ENH-008: Chat Typing Indicator
**Location:** `lib/screens/chat_screen.dart`
**Value:** Medium
**Description:** Show typing animation while AI generates response.

---

### ENH-009: Message Copy/Edit Functionality
**Location:** `lib/screens/chat_screen.dart`
**Value:** Medium
**Description:** Allow users to copy or edit previous messages.

---

### ENH-010: Voice Input Implementation
**Location:** `lib/screens/chat_screen.dart`
**Value:** Medium
**Description:** Implement actual voice-to-text for message input.

---

### ENH-011: File Attachment Implementation
**Location:** `lib/screens/chat_screen.dart`
**Value:** Medium
**Description:** Allow attaching files/images to messages.

---

### ENH-012: Action History/Undo
**Location:** `lib/screens/quick_actions_screen.dart`
**Value:** Medium
**Description:** Track action history and allow undoing actions.

---

### ENH-013: Customizable Quick Actions
**Location:** `lib/screens/quick_actions_screen.dart`
**Value:** Medium
**Description:** Allow users to customize which actions appear.

---

### ENH-014: Batch Agent Operations
**Location:** `lib/screens/control_screen.dart`
**Value:** Medium
**Description:** Select multiple agents for batch kill/restart operations.

---

### ENH-015: Logs Search Functionality
**Location:** `lib/screens/logs_screen.dart`
**Value:** Medium
**Description:** Add search bar to filter logs by content.

---

### ENH-016: Logs Export to File
**Location:** `lib/screens/logs_screen.dart`
**Value:** Medium
**Description:** Export logs to text file for sharing/analysis.

---

### ENH-017: Workflow Step Editor
**Location:** `lib/screens/workflows_screen.dart`
**Value:** Medium
**Description:** Visual editor for adding/editing workflow steps.

---

### ENH-018: Workflow Import/Export
**Location:** `lib/screens/workflows_screen.dart`
**Value:** Medium
**Description:** Share workflows via JSON import/export.

---

### ENH-019: Browser Snapshot Preview
**Location:** `lib/screens/browser_control_screen.dart`
**Value:** Medium
**Description:** Show live snapshot preview in browser control.

---

### ENH-020: Element Selector from Snapshot
**Location:** `lib/screens/browser_control_screen.dart`
**Value:** Medium
**Description:** Click elements in snapshot to get their ID.

---

### ENH-021: Connection Profiles
**Location:** `lib/screens/settings_screen.dart`
**Value:** Medium
**Description:** Save and switch between multiple gateway configurations.

---

### ENH-022: Accessibility Improvements
**Location:** All screens
**Value:** Medium
**Description:** Add semantic labels, screen reader support, high contrast mode.

---

## ⚪ Low Value Enhancements (Ignore)

### ENH-023: Haptic Feedback on Actions
**Location:** Multiple screens
**Value:** Low
**Description:** Add haptic feedback on button presses.

---

### ENH-024: Message Reactions
**Location:** `lib/screens/chat_screen.dart`
**Value:** Low
**Description:** Add emoji reactions to messages.

---

### ENH-025: Task Templates
**Location:** `lib/screens/scheduled_tasks_screen.dart`
**Value:** Low
**Description:** Pre-defined task templates for common schedules.

---

### ENH-026: Model Cost Calculator
**Location:** `lib/screens/model_hub_screen.dart`
**Value:** Low
**Description:** Calculate estimated costs based on usage.

---

### ENH-027: Browser Bookmarks
**Location:** `lib/screens/browser_control_screen.dart`
**Value:** Low
**Description:** Save frequently visited URLs.

---

### ENH-028: Workflow Categories
**Location:** `lib/screens/workflows_screen.dart`
**Value:** Low
**Description:** Organize workflows into categories.

---

### ENH-029: Log Detail View
**Location:** `lib/screens/logs_screen.dart`
**Value:** Low
**Description:** Full-screen log detail on tap.

---

### ENH-030: Node Statistics Dashboard
**Location:** `lib/screens/node_settings_screen.dart`
**Value:** Low
**Description:** Show connection statistics and history.

---

## Priority Matrix

| Enhancement | Value | Effort | Priority |
|-------------|-------|--------|----------|
| Real Chat API | High | Medium | P1 |
| Message Persistence | High | Low | P1 |
| Real Quick Actions | High | Medium | P1 |
| Real Logs | High | Low | P1 |
| Real Usage Data | High | Low | P1 |
| QR Scanning | High | Medium | P1 |
| Skeleton Loading | High | Low | P1 |
| Typing Indicator | Medium | Low | P2 |
| Message Copy/Edit | Medium | Low | P2 |
| Voice Input | Medium | Medium | P2 |
| File Attachments | Medium | Medium | P2 |
| Action History | Medium | Medium | P2 |
| Custom Actions | Medium | Medium | P2 |
| Batch Operations | Medium | Low | P2 |
| Logs Search | Medium | Low | P2 |
| Logs Export | Medium | Low | P2 |
| Workflow Editor | Medium | High | P3 |
| Workflow Import/Export | Medium | Low | P3 |
| Snapshot Preview | Medium | Medium | P3 |
| Element Selector | Medium | Medium | P3 |
| Connection Profiles | Medium | Medium | P3 |
| Accessibility | Medium | High | P3 |

---

## Implementation Recommendations

### Phase 1 (Next Sprint):
1. ENH-001: Real Chat API
2. ENH-002: Message Persistence
3. ENH-004: Real Logs
4. ENH-005: Real Usage Data
5. ENH-007: Skeleton Loading

**Estimated Time:** 20-30 hours

### Phase 2 (Following Sprint):
1. ENH-003: Real Quick Actions
2. ENH-006: QR Scanning
3. ENH-008: Typing Indicator
4. ENH-009: Message Copy/Edit
5. ENH-015: Logs Search
6. ENH-016: Logs Export

**Estimated Time:** 25-35 hours

### Phase 3 (Backlog):
1. ENH-010: Voice Input
2. ENH-011: File Attachments
3. ENH-017: Workflow Editor
4. ENH-021: Connection Profiles
5. ENH-022: Accessibility

**Estimated Time:** 40-60 hours

---

**Total Enhancement Backlog:** 30 items
**High Priority:** 7 items
**Medium Priority:** 15 items
**Low Priority:** 8 items