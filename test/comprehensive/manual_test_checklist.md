# Comprehensive Manual Test Checklist - DuckBot Android App

**Generated:** March 10, 2026  
**Version:** 1.0

---

## Pre-Test Setup

- [ ] Install latest APK on test device
- [ ] Ensure test device has network connectivity
- [ ] Ensure OpenClaw gateway is running for connection tests
- [ ] Clear app data before testing

---

## 1. App Launch & Initialization

### 1.1 Cold Start
- [ ] App launches within 3 seconds
- [ ] Splash/loading screen displays correctly
- [ ] No crashes on launch
- [ ] Proper initialization sequence

### 1.2 Auto-Connect
- [ ] App attempts to connect to last gateway
- [ ] Shows "Connecting..." state during attempt
- [ ] Falls back to setup screen if no connection
- [ ] Shows connection success dialog on first connection

### 1.3 First Launch Experience
- [ ] Welcome screen displays
- [ ] Two options shown (Install Local / Connect Remote)
- [ ] Setup flow is intuitive
- [ ] Can complete setup without guidance

---

## 2. Dashboard Screen

### 2.1 Connection Status Card
- [ ] Shows gateway name
- [ ] Shows connection status (online/offline)
- [ ] Shows latency/ping
- [ ] Retry button works when disconnected
- [ ] Expands to show more details

### 2.2 Quick Stats
- [ ] Agent count displays correctly
- [ ] Node count displays correctly
- [ ] Status shows Active/Paused correctly
- [ ] Cards are clickable and navigate correctly

### 2.3 System Health
- [ ] CPU usage displays correctly
- [ ] Memory usage displays correctly
- [ ] Progress bars animate smoothly
- [ ] Colors change based on thresholds

### 2.4 Gateway Card
- [ ] Shows version
- [ ] Shows uptime
- [ ] Shows CPU/memory
- [ ] Status icon reflects actual state

### 2.5 Agents Card
- [ ] Lists all active agents
- [ ] Shows agent status (active/paused)
- [ ] Shows current task if available
- [ ] Empty state shows when no agents

### 2.6 Nodes Card
- [ ] Lists all connected nodes
- [ ] Shows connection type
- [ ] Shows IP address
- [ ] Empty state shows when no nodes

### 2.7 Quick Actions
- [ ] Refresh button works
- [ ] Settings button navigates correctly
- [ ] Logs button navigates correctly
- [ ] Chat button navigates correctly

### 2.8 Pull to Refresh
- [ ] Pull gesture triggers refresh
- [ ] Loading indicator shows
- [ ] Data updates after refresh
- [ ] Refresh completes within reasonable time

---

## 3. Chat Screen

### 3.1 Message Input
- [ ] Text field accepts input
- [ ] Send button is enabled when text present
- [ ] Enter key sends message
- [ ] Clear button resets text field

### 3.2 Message Display
- [ ] User messages appear on right
- [ ] Bot messages appear on left
- [ ] Timestamps display correctly
- [ ] Avatars display correctly

### 3.3 Message Sending
- [ ] Message sends within 2 seconds
- [ ] Response generates within 5 seconds
- [ ] Loading state shows during send
- [ ] Error handling for failed sends

### 3.4 Agent Mode
- [ ] Agent library opens
- [ ] Can select agent
- [ ] Agent indicator shows in header
- [ ] Agent-specific responses work
- [ ] Can deactivate agent

### 3.5 Multi-Agent Mode
- [ ] Multi-agent screen opens
- [ ] Can select multiple agents
- [ ] Team indicator shows in header
- [ ] Team response generates correctly

### 3.6 Chat Export
- [ ] Export button works
- [ ] Export dialog shows options
- [ ] Can copy chat to clipboard
- [ ] Can share chat

### 3.7 Voice Input
- [ ] Microphone button shows
- [ ] "Coming soon" message displays (if not implemented)

### 3.8 Scroll Behavior
- [ ] Auto-scrolls to bottom on new message
- [ ] Can scroll to view older messages
- [ ] Scroll position preserved when keyboard opens

---

## 4. Connect Gateway Screen

### 4.1 Auto Discovery Tab
- [ ] Discovery starts automatically
- [ ] Progress indicator shows
- [ ] Gateways appear as discovered
- [ ] Can tap to connect
- [ ] Connection dialog shows

### 4.2 LAN Discovery
- [ ] Local network gateways found
- [ ] Shows gateway name and IP
- [ ] Online status displays correctly
- [ ] Multiple gateways listed

### 4.3 Tailscale Discovery
- [ ] Tailscale status detected
- [ ] Can scan Tailscale network
- [ ] Tailscale gateways found
- [ ] Warning shows if Tailscale not running

### 4.4 History Tab
- [ ] Previous connections shown
- [ ] Can connect from history
- [ ] Can remove from history
- [ ] Last connected time shown

### 4.5 Manual Tab
- [ ] URL field accepts input
- [ ] Token field accepts input
- [ ] Test connection button works
- [ ] Connect button works
- [ ] Error messages display correctly

### 4.6 Debug Logs
- [ ] Can expand debug logs
- [ ] Logs show discovery progress
- [ ] Can copy logs
- [ ] Can clear logs

---

## 5. Local Installer Screen

### 5.1 Initial State
- [ ] Shows installation options
- [ ] Requirements listed
- [ ] Start button works

### 5.2 Installation Progress
- [ ] Progress bar updates
- [ ] Status messages display
- [ ] Steps show current phase
- [ ] Logs panel shows activity

### 5.3 Error Handling
- [ ] Shows error message
- [ ] Retry button works
- [ ] Troubleshooting help available

### 5.4 Completion
- [ ] Success message shows
- [ ] Gateway URL displayed
- [ ] Test connection works
- [ ] Can connect to local gateway

---

## 6. Termux Screen

### 6.1 Command Execution
- [ ] Command input works
- [ ] Output displays correctly
- [ ] Error output shown
- [ ] Command completes

### 6.2 OpenClaw Commands
- [ ] Can check OpenClaw version
- [ ] Can start gateway
- [ ] Can stop gateway
- [ ] Can check gateway status

### 6.3 Setup Progress
- [ ] Shows setup steps
- [ ] Progress updates
- [ ] Errors handled

---

## 7. Quick Actions Screen

### 7.1 Basic Actions
- [ ] STATUS action works
- [ ] AGENTS action works
- [ ] NODES action works
- [ ] LOGS action works
- [ ] REFRESH action works

### 7.2 Gateway Actions
- [ ] START action works
- [ ] STOP action works
- [ ] RESTART action works
- [ ] DIAGNOSE action works

### 7.3 Agent Actions
- [ ] PAUSE ALL works
- [ ] RESUME ALL works
- [ ] AUTOWORK toggle works
- [ ] KILL AGENT works

### 7.4 Advanced Actions (if applicable)
- [ ] BACKUP action works
- [ ] RESTORE action works
- [ ] CONFIG action works
- [ ] DOCTOR action works

---

## 8. Control Screen

### 8.1 Gateway Controls
- [ ] Restart button works
- [ ] Stop button works
- [ ] Confirmation dialog shows
- [ ] Action executes

### 8.2 Agent Controls
- [ ] Agent list displays
- [ ] Kill button works
- [ ] Status updates after action

### 8.3 Node Controls
- [ ] Node list displays
- [ ] Reconnect button works
- [ ] Status updates after action

### 8.4 Hold-to-Pause
- [ ] Long press starts progress
- [ ] Progress bar fills
- [ ] Action triggers when complete
- [ ] Can cancel by releasing

---

## 9. Logs Screen

### 9.1 Log Display
- [ ] Logs load correctly
- [ ] Log levels color-coded
- [ ] Timestamps display
- [ ] Source displayed

### 9.2 Filtering
- [ ] Can filter by level
- [ ] Can filter by source
- [ ] Filter applies correctly

### 9.3 Refresh
- [ ] Pull to refresh works
- [ ] Auto-refresh works
- [ ] New logs appear

---

## 10. Settings Screen

### 10.1 App Mode
- [ ] Mode selector shows
- [ ] Basic mode works
- [ ] Power User mode works
- [ ] Developer mode works
- [ ] Navigation changes based on mode

### 10.2 Theme
- [ ] System theme option
- [ ] Light theme option
- [ ] Dark theme option
- [ ] Theme applies immediately

### 10.3 Notifications
- [ ] Toggle works
- [ ] Setting persists

### 10.4 Haptic Feedback
- [ ] Toggle works
- [ ] Setting persists

### 10.5 Auto-Refresh
- [ ] Slider works
- [ ] Value displays
- [ ] Setting persists

### 10.6 Debug Logging (Developer Mode)
- [ ] Toggle shows in dev mode
- [ ] Toggle works
- [ ] Setting persists

### 10.7 Gateway Settings
- [ ] Shows current gateway
- [ ] Can disconnect
- [ ] Can connect to different gateway

---

## 11. Model Hub Screen

### 11.1 Model List
- [ ] Models display correctly
- [ ] Usage statistics shown
- [ ] Quota information shown

### 11.2 Model Selection
- [ ] Can select model
- [ ] Selection persists

---

## 12. Browser Control Screen

### 12.1 Page Management
- [ ] Can open new page
- [ ] Can close page
- [ ] Can switch between pages

### 12.2 Navigation
- [ ] Can navigate to URL
- [ ] Can go back/forward
- [ ] Can refresh

### 12.3 Actions
- [ ] Can click elements
- [ ] Can type text
- [ ] Can take screenshot

---

## 13. Workflows Screen

### 13.1 Workflow List
- [ ] Workflows display
- [ ] Status shown
- [ ] Can run workflow

### 13.2 Workflow Actions
- [ ] Run button works
- [ ] Edit option available
- [ ] Delete option available

---

## 14. Scheduled Tasks Screen

### 14.1 Task List
- [ ] Tasks display
- [ ] Schedule shown
- [ ] Status shown

### 14.2 Task Actions
- [ ] Can run task now
- [ ] Can edit task
- [ ] Can delete task
- [ ] Can enable/disable task

---

## 15. Sessions Screen

### 15.1 Session List
- [ ] Sessions display
- [ ] Agent info shown
- [ ] Status shown

### 15.2 Session Actions
- [ ] Can view session details
- [ ] Can kill session
- [ ] Can interact with session

---

## 16. Skills Screen

### 16.1 Skills List
- [ ] Skills display
- [ ] Categories shown
- [ ] Status shown

### 16.2 Skill Actions
- [ ] Can view skill details
- [ ] Can enable/disable skill

---

## 17. Backup Screen

### 17.1 Backup Actions
- [ ] Create backup works
- [ ] Restore from backup works
- [ ] Backup list shows

### 17.2 Backup Management
- [ ] Can download backup
- [ ] Can delete backup
- [ ] Can share backup

---

## 18. Global Search

### 18.1 Search Functionality
- [ ] Search icon accessible
- [ ] Search input works
- [ ] Results display
- [ ] Can navigate to result

---

## 19. Navigation

### 19.1 Bottom Navigation
- [ ] All tabs accessible
- [ ] Tab icons display
- [ ] Tab labels display
- [ ] Current tab highlighted

### 19.2 Mode-Specific Tabs
- [ ] Basic: 4 tabs
- [ ] Power User: 5 tabs
- [ ] Developer: 6 tabs

### 19.3 Back Navigation
- [ ] Back button works
- [ ] Back gesture works
- [ ] Navigation stack maintained

---

## 20. Error Handling

### 20.1 Network Errors
- [ ] Shows user-friendly message
- [ ] Retry option available
- [ ] Debug details available

### 20.2 API Errors
- [ ] Shows error message
- [ ] Doesn't crash app
- [ ] Can recover

### 20.3 Permission Errors
- [ ] Permission request shown
- [ ] Denial handled gracefully
- [ ] Can retry permission

---

## 21. Accessibility

### 21.1 Screen Reader
- [ ] Labels are descriptive
- [ ] Actions are announced
- [ ] Navigation is clear

### 21.2 Font Scaling
- [ ] UI adapts to large fonts
- [ ] No text truncation
- [ ] Buttons remain tappable

---

## Test Summary

| Section | Tests | Pass | Fail | Notes |
|---------|-------|------|------|-------|
| App Launch | 8 | | | |
| Dashboard | 28 | | | |
| Chat | 28 | | | |
| Connect Gateway | 24 | | | |
| Local Installer | 12 | | | |
| Termux | 9 | | | |
| Quick Actions | 16 | | | |
| Control | 12 | | | |
| Logs | 8 | | | |
| Settings | 20 | | | |
| Model Hub | 4 | | | |
| Browser Control | 8 | | | |
| Workflows | 6 | | | |
| Scheduled Tasks | 8 | | | |
| Sessions | 6 | | | |
| Skills | 4 | | | |
| Backup | 6 | | | |
| Global Search | 4 | | | |
| Navigation | 12 | | | |
| Error Handling | 8 | | | |
| Accessibility | 6 | | | |
| **TOTAL** | **227** | | | |

---

## Sign-Off

- Tester: ___________________
- Date: ___________________
- Device: ___________________
- App Version: ___________________
- Overall Status: [ ] PASS [ ] FAIL [ ] CONDITIONAL

---

*Generated by DuckBot Sub-Agent*