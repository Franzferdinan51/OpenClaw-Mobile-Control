# Edge Case Test Cases - DuckBot Android App

**Generated:** March 10, 2026

---

## Network Edge Cases

### TC-NET-001: No Network Connection
**Precondition:** Device in airplane mode or no WiFi/cellular  
**Steps:**
1. Launch app
2. Observe connection attempt

**Expected:** Show clear "No network" message with retry button  
**Actual:** Shows generic "Could not connect" message  
**Status:** ⚠️ PARTIAL  
**Bug:** No specific network detection

---

### TC-NET-002: Slow Network (High Latency)
**Precondition:** Network with >5s latency  
**Steps:**
1. Launch app
2. Attempt to connect

**Expected:** Timeout with retry option  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-NET-003: Network Switch (WiFi → Cellular)
**Precondition:** Connected via WiFi, then switch to cellular  
**Steps:**
1. Connect to gateway via WiFi
2. Switch to cellular data
3. Observe app behavior

**Expected:** Reconnect to gateway or show disconnected state  
**Actual:** App continues showing "connected"  
**Status:** ❌ FAIL  
**Bug:** No network change detection

---

### TC-NET-004: Gateway Offline
**Precondition:** Gateway was online, then stopped  
**Steps:**
1. Connect to gateway
2. Stop gateway process
3. Observe app behavior

**Expected:** Show disconnected state with retry option  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-NET-005: Gateway Wrong Port
**Precondition:** Gateway running on different port  
**Steps:**
1. Enter URL with wrong port
2. Attempt connection

**Expected:** Clear "Connection refused" message  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-NET-006: Multiple Gateways on Network
**Precondition:** Multiple OpenClaw instances running  
**Steps:**
1. Start discovery
2. Observe found gateways

**Expected:** List all found gateways  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-NET-007: Tailscale Only Connection
**Precondition:** No LAN, only Tailscale available  
**Steps:**
1. Disconnect from LAN
2. Connect via Tailscale
3. Attempt discovery

**Expected:** Find Tailscale gateway  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-NET-008: Large Message (>1MB)
**Precondition:** Connected to gateway  
**Steps:**
1. Send very long message (10000+ characters)
2. Observe behavior

**Expected:** Message sent or size limit warning  
**Actual:** ⚠️ No size validation  
**Status:** ⚠️ PARTIAL  
**Bug:** No message size limit

---

### TC-NET-009: Many Messages (1000+)
**Precondition:** Long chat session  
**Steps:**
1. Send 1000+ messages
2. Observe memory and performance

**Expected:** Smooth scrolling, reasonable memory  
**Actual:** ⚠️ Not tested  
**Status:** ⚠️ UNTESTED  
**Concern:** Memory usage

---

### TC-NET-010: DNS Resolution Failure
**Precondition:** Use hostname instead of IP  
**Steps:**
1. Enter gateway hostname
2. DNS fails to resolve

**Expected:** Clear error message about DNS  
**Actual:** Generic connection error  
**Status:** ⚠️ PARTIAL

---

## Device Edge Cases

### TC-DEV-001: Low Memory Pressure
**Precondition:** Device under memory pressure  
**Steps:**
1. Open many other apps
2. Launch DuckBot
3. Observe behavior

**Expected:** Graceful handling, cache clearing  
**Actual:** ✅ Works with cache clearing  
**Status:** ✅ PASS

---

### TC-DEV-002: Low Storage Space
**Precondition:** Device almost out of storage  
**Steps:**
1. Fill device storage
2. Attempt installation or data save

**Expected:** Warning about low storage  
**Actual:** ❌ No check  
**Status:** ❌ FAIL  
**Bug:** No storage space check

---

### TC-DEV-003: Screen Rotation
**Precondition:** App open in portrait  
**Steps:**
1. Rotate to landscape
2. Observe UI

**Expected:** UI adapts correctly  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DEV-004: App Backgrounded
**Precondition:** App in foreground, connected  
**Steps:**
1. Press home button
2. Wait 5 minutes
3. Return to app

**Expected:** Timers paused, state preserved  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DEV-005: App Killed by System
**Precondition:** App running, messages in chat  
**Steps:**
1. Add messages to chat
2. Force kill app
3. Reopen app

**Expected:** Chat history preserved  
**Actual:** ❌ Messages lost  
**Status:** ❌ FAIL  
**Bug:** No persistence

---

### TC-DEV-006: Permission Denied (Microphone)
**Precondition:** Microphone permission denied  
**Steps:**
1. Tap voice input button
2. Observe behavior

**Expected:** Permission request or explanation  
**Actual:** ⚠️ Shows "coming soon"  
**Status:** ⚠️ PARTIAL

---

### TC-DEV-007: Permission Denied (Camera)
**Precondition:** Camera permission denied  
**Steps:**
1. Try to scan QR code
2. Observe behavior

**Expected:** Permission request  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DEV-008: Small Screen Device
**Precondition:** Device with <5" screen  
**Steps:**
1. Launch app
2. Navigate all screens

**Expected:** All UI elements accessible  
**Actual:** ⚠️ Some overflow  
**Status:** ⚠️ PARTIAL  
**Bug:** CircleAvatar emoji overflow

---

### TC-DEV-009: Large Screen Device (Tablet)
**Precondition:** Tablet device  
**Steps:**
1. Launch app
2. Observe layout

**Expected:** Responsive layout for larger screens  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DEV-010: Android Version < 7.0
**Precondition:** Device running Android 6.0 or lower  
**Steps:**
1. Attempt to install APK
2. Observe behavior

**Expected:** Clear compatibility message  
**Actual:** ⚠️ Not tested  
**Status:** ⚠️ UNTESTED

---

## Data Edge Cases

### TC-DAT-001: Empty API Response
**Precondition:** Gateway returns empty response  
**Steps:**
1. Request status from gateway
2. Receive empty response

**Expected:** Show "No data" placeholder  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DAT-002: Malformed JSON Response
**Precondition:** Gateway returns invalid JSON  
**Steps:**
1. Request data
2. Receive malformed JSON

**Expected:** Graceful error handling  
**Actual:** ⚠️ Silent failure  
**Status:** ⚠️ PARTIAL  
**Bug:** Silent parse errors

---

### TC-DAT-003: Null Values in Response
**Precondition:** Gateway returns null values  
**Steps:**
1. Receive response with null fields
2. Observe UI

**Expected:** Graceful handling with defaults  
**Actual:** ⚠️ Some crashes  
**Status:** ⚠️ PARTIAL  
**Bug:** Memory percent can crash

---

### TC-DAT-004: Future Timestamp in Response
**Precondition:** Server time ahead of device  
**Steps:**
1. Receive future timestamp
2. Display time ago

**Expected:** Handle gracefully  
**Actual:** Shows negative time  
**Status:** ❌ FAIL  
**Bug:** Negative time display

---

### TC-DAT-005: Unicode in Messages
**Precondition:** Message contains emoji, special chars  
**Steps:**
1. Send message with unicode
2. Observe display

**Expected:** Correctly displayed  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DAT-006: Very Long Gateway Name
**Precondition:** Gateway has very long name  
**Steps:**
1. Connect to gateway with long name
2. Observe UI

**Expected:** Truncate with ellipsis  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DAT-007: Special Characters in Token
**Precondition:** Token contains special characters  
**Steps:**
1. Enter token with special chars
2. Attempt connection

**Expected:** Correctly encoded  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-DAT-008: Concurrent Operations
**Precondition:** Multiple operations simultaneously  
**Steps:**
1. Start discovery
2. Immediately connect manually
3. Both operations complete

**Expected:** No race conditions  
**Actual:** ⚠️ Potential issues  
**Status:** ⚠️ PARTIAL  
**Bug:** Overlapping timers

---

## User Input Edge Cases

### TC-INP-001: Empty Input Fields
**Precondition:** Form with required fields  
**Steps:**
1. Leave fields empty
2. Submit form

**Expected:** Validation error  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-INP-002: Invalid URL Format
**Precondition:** Manual entry form  
**Steps:**
1. Enter "not-a-url"
2. Submit

**Expected:** Validation error  
**Actual:** ⚠️ Accepts with http:// prefix  
**Status:** ⚠️ PARTIAL  
**Bug:** Weak URL validation

---

### TC-INP-003: SQL Injection Attempt
**Precondition:** Input fields  
**Steps:**
1. Enter "'; DROP TABLE users; --"
2. Observe behavior

**Expected:** Treated as literal string  
**Actual:** ✅ No SQL, just string  
**Status:** ✅ PASS

---

### TC-INP-004: XSS Attempt
**Precondition:** Chat input  
**Steps:**
1. Enter "<script>alert('xss')</script>"
2. Send message

**Expected:** Treated as literal string  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-INP-005: Rapid Button Tapping
**Precondition:** Action button visible  
**Steps:**
1. Tap button 10 times rapidly

**Expected:** Only one action executed  
**Actual:** Multiple executions  
**Status:** ❌ FAIL  
**Bug:** No debounce

---

### TC-INP-006: Long Press Hold
**Precondition:** Hold-to-pause control  
**Steps:**
1. Start long press
2. Hold for 10 seconds

**Expected:** Progress bar fills, action triggers  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

### TC-INP-007: Gesture Conflicts
**Precondition:** Scrollable list with buttons  
**Steps:**
1. Try to scroll by touching button
2. Observe behavior

**Expected:** Scroll, no button trigger  
**Actual:** ✅ Works correctly  
**Status:** ✅ PASS

---

## Summary

| Category | Total Tests | Pass | Fail | Partial | Untested |
|----------|-------------|------|------|---------|----------|
| Network | 10 | 5 | 1 | 3 | 1 |
| Device | 10 | 4 | 2 | 3 | 1 |
| Data | 8 | 4 | 1 | 3 | 0 |
| Input | 7 | 4 | 1 | 2 | 0 |
| **Total** | **35** | **17** | **5** | **11** | **2** |

**Pass Rate:** 48.6%  
**Failure Rate:** 14.3%  
**Partial/Untested:** 37.1%

---

*Generated by DuckBot Sub-Agent*