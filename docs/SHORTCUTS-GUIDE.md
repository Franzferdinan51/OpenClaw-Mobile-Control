# iOS Shortcuts & Android Intents Guide

Control OpenClaw Mobile from iOS Shortcuts, Android Intents, Siri, and Google Assistant.

---

## Table of Contents

1. [Overview](#overview)
2. [URL Schemes](#url-schemes)
3. [iOS Shortcuts](#ios-shortcuts)
4. [Android Intents](#android-intents)
5. [Siri Integration](#siri-integration)
6. [Google Assistant Integration](#google-assistant-integration)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)

---

## Overview

OpenClaw Mobile supports deep linking and automation through:

| Platform | Method | Capability |
|----------|--------|------------|
| **iOS** | URL Schemes + Shortcuts | Siri, Widgets, Automation |
| **Android** | Intents + App Links | Google Assistant, Widgets |

### Supported URL Schemes

```
openclaw://action/{actionId}?params=...
openclaw://chat?message=...
openclaw://control/{command}?params=...
openclaw://dashboard
openclaw://settings
```

---

## URL Schemes

### Action URL Scheme

**Format:**
```
openclaw://action/{actionId}?param1=value1&param2=value2
```

**Examples:**
```
# Send notification
openclaw://action/send_notification?title=Hello&body=World

# Check gateway
openclaw://action/check_gateway

# Restart gateway
openclaw://action/restart_gateway?reason=manual

# Start agent
openclaw://action/start_agent?model=gpt-4
```

### Chat URL Scheme

**Format:**
```
openclaw://chat?message={encoded_message}
```

**Example:**
```
openclaw://chat?message=Check%20the%20gateway%20status
```

### Control URL Scheme

**Format:**
```
openclaw://control/{command}?param=value
```

**Commands:**
| Command | Parameters | Description |
|---------|------------|-------------|
| `restart` | `reason` | Restart gateway |
| `stop` | `reason` | Stop gateway |
| `pause_all` | `duration` | Pause all agents |
| `resume_all` | - | Resume all agents |
| `kill_agent` | `session_key` | Kill specific agent |

**Example:**
```
openclaw://control/pause_all?duration=60
```

### Navigation URL Scheme

**Format:**
```
openclaw://dashboard
openclaw://settings
openclaw://chat
openclaw://control
openclaw://logs
openclaw://agents
```

---

## iOS Shortcuts

### Creating a Shortcut

**Method 1: URL Action**

1. Open **Shortcuts** app
2. Tap **+** to create new shortcut
3. Add action: **URL**
4. Enter URL scheme:
   ```
   openclaw://action/check_gateway
   ```
5. Add action: **Open URLs**
6. Name your shortcut (e.g., "Check Gateway")

**Method 2: Using "Open In" Action**

1. Create new shortcut
2. Add action: **Open In...**
3. Enter URL: `openclaw://dashboard`
4. Configure for quick access

### Shortcut Examples

#### Example 1: Gateway Status Widget

**Shortcut Steps:**
1. **URL**: `openclaw://action/check_gateway`
2. **Open URLs**
3. **Show Notification**: "Gateway status checked"

**Add to Home Screen:**
1. Long press shortcut
2. Tap "Add to Home Screen"
3. Name: "Gateway Status"
4. Icon: Choose appropriate icon

#### Example 2: Quick Chat

**Shortcut Steps:**
1. **Ask for Input**: "What would you like to ask?"
2. **URL**: `openclaw://chat?message=[Input]`
3. **Open URLs**

#### Example 3: Morning Routine

**Shortcut Steps:**
1. **URL**: `openclaw://action/check_gateway`
2. **Open URLs**
3. **Wait**: 2 seconds
4. **URL**: `openclaw://chat?message=What%27s%20the%20status%3F`
5. **Open URLs**

### iOS Automation Triggers

**Create Personal Automation:**

1. Open Shortcuts → Automation
2. Tap **+** → Create Personal Automation
3. Choose trigger:
   - **Time of Day**: Daily at 8 AM
   - **Location**: When arriving home
   - **Wi-Fi**: When connecting to home network
   - **NFC**: When scanning a tag

4. Add action: **URL** → OpenClaw URL scheme
5. Disable "Ask Before Running" for true automation

**Example: Location-Based Gateway Check**

```yaml
Trigger: Arrive at [Home]
Action: URL: openclaw://action/check_gateway
Action: Wait 5 seconds
Action: URL: openclaw://action/send_notification?title=Welcome%20Home&body=Gateway%20checked
```

### iOS Widgets

**Create Widget:**

1. Long press home screen
2. Tap **+** in top left
3. Search **Shortcuts**
4. Choose size (Small, Medium, Large)
5. Tap **Add Widget**
6. Long press widget → Edit Widget
7. Select your OpenClaw shortcut

---

## Android Intents

### Intent Structure

**Kotlin Example:**
```kotlin
val intent = Intent(Intent.ACTION_VIEW).apply {
    data = Uri.parse("openclaw://action/check_gateway")
}
startActivity(intent)
```

**Java Example:**
```java
Intent intent = new Intent(Intent.ACTION_VIEW);
intent.setData(Uri.parse("openclaw://action/check_gateway"));
startActivity(intent);
```

### Intent Filters (AndroidManifest.xml)

The app declares these intent filters:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="openclaw" />
</intent-filter>

<!-- App Links (verified URLs) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="openclaw.app" />
</intent-filter>
```

### Android App Links

**HTTPS URL Format:**
```
https://openclaw.app/action/{actionId}
https://openclaw.app/chat?message=...
https://openclaw.app/control/{command}
```

These URLs open the app directly when clicked (no disambiguation dialog).

### Tasker Integration

**Setup in Tasker:**

1. Create new Task
2. Add Action: **Intent** → **Send Intent**
3. Configure:
   - Action: `android.intent.action.VIEW`
   - Data: `openclaw://action/check_gateway`
   - Target: Activity

**Example Task: Gateway Check on Wi-Fi Connect**

```
Profile: Wi-Fi Connected [ SSID: HomeWiFi ]
Enter Task: Gateway Check
  A1: Send Intent [
    Action: android.intent.action.VIEW
    Data: openclaw://action/check_gateway
    Target: Activity
  ]
```

### Automate (LlamaLab)

**Flow Setup:**

1. Add block: **Broadcast intent**
2. Configure:
   - Action: `android.intent.action.VIEW`
   - Data URI: `openclaw://action/send_notification?title=Hello&body=World`

### Android Widgets

**Create App Widget:**

The app provides a configurable widget for quick actions.

1. Long press home screen
2. Tap **Widgets**
3. Find **OpenClaw Mobile**
4. Drag widget to home screen
5. Configure:
   - Action: select from dropdown
   - Label: custom text
   - Icon: choose icon

---

## Siri Integration

### Siri Shortcuts (iOS)

**Create Siri Shortcut:**

1. Open **Shortcuts** app
2. Create shortcut with OpenClaw URL
3. Tap **i** button → Add to Siri
4. Record phrase: "Check my gateway"
5. Say phrase to trigger

**Example Siri Phrases:**
- "Check my gateway" → `openclaw://action/check_gateway`
- "OpenClaw dashboard" → `openclaw://dashboard`
- "Restart OpenClaw" → `openclaw://control/restart`

### Siri Suggestions

The app donates shortcuts to Siri based on usage:

- Frequently used actions appear in Siri Suggestions
- Lock screen and search suggestions
- Siri learns your patterns

**Donate Shortcut (in app):**
```swift
// iOS app code
let activity = NSUserActivity(activityType: "com.openclaw.mobile.check_gateway")
activity.title = "Check Gateway"
activity.userInfo = ["action": "check_gateway"]
activity.isEligibleForSearch = true
activity.isEligibleForPrediction = true
view.userActivity = activity
activity.becomeCurrent()
```

---

## Google Assistant Integration

### IFTTT + Google Assistant

**Setup:**

1. Create IFTTT applet
2. Trigger: **Google Assistant** → "Say a simple phrase"
3. Phrase: "check my gateway"
4. Action: **Webhooks** → POST to OpenClaw
5. URL: `https://your-ngrok.io/webhook/action/check_gateway`

### Google Assistant Routine

**Add to Routine:**

1. Open Google Assistant settings
2. Go to **Routines**
3. Create new or edit existing
4. Add action: Open app/URL
5. Enter: `openclaw://action/check_gateway`

**Voice Command:**
```
"Hey Google, check my gateway"
```

---

## Examples

### Example 1: Complete iOS Automation

**Scenario:** Daily health check + notification

**iOS Shortcuts:**
```yaml
Automation: Daily at 8:00 AM
Actions:
  1. URL: openclaw://action/check_gateway
  2. Open URLs
  3. Wait: 3 seconds
  4. URL: openclaw://action/send_notification?title=Morning%20Check&body=Gateway%20is%20online
  5. Open URLs
```

### Example 2: Android NFC Tag

**Scenario:** Scan NFC tag to restart gateway

**Tasker Profile:**
```yaml
Profile: NFC Tag Scanned [ Tag ID: YOUR_TAG_ID ]
Enter Task: Restart Gateway
  A1: Send Intent [
    Action: android.intent.action.VIEW
    Data: openclaw://control/restart?reason=NFC%20tag
    Target: Activity
  ]
  A2: Flash [ Text: Restarting gateway... ]
```

### Example 3: Home Assistant Integration

**iOS (via Home Assistant):**
```yaml
automation:
  - alias: "OpenClaw Gateway Check"
    trigger:
      - platform: time
        at: "08:00:00"
    action:
      - service: notify.mobile_app_iphone
        data:
          message: "command_openclaw_check"
          data:
            url: "openclaw://action/check_gateway"
```

**Android (via Intent):**
```yaml
automation:
  - alias: "OpenClaw Gateway Check"
    trigger:
      - platform: time
        at: "08:00:00"
    action:
      - service: androidtv.intent
        data:
          action: android.intent.action.VIEW
          data_uri: "openclaw://action/check_gateway"
```

### Example 4: MacroDroid Integration (Android)

**Macro Setup:**
```
Trigger: Shake device
Action:
  - Intent: android.intent.action.VIEW
  - Data: openclaw://action/check_gateway
Constraint: None
```

### Example 5: NFC Tag + Shortcuts (iOS)

**Setup:**
1. Create shortcut: `openclaw://action/check_gateway`
2. Name: "Gateway Status"
3. Create automation: When NFC tag scanned
4. Select shortcut: "Gateway Status"

**Use:**
1. Tap iPhone to NFC tag
2. OpenClaw checks gateway
3. Notification shows result

---

## Troubleshooting

### URL Scheme Not Working (iOS)

1. **Check app is installed:**
   - URL scheme only works if app is installed
   - Verify scheme: `openclaw://`

2. **Check iOS version:**
   - iOS 14+ recommended
   - Some features require iOS 16+

3. **Reset URL scheme:**
   ```bash
   # Open in Safari
   openclaw://dashboard
   ```

### Intent Not Working (Android)

1. **Check intent filter:**
   - App must be installed
   - Intent must match declared filter

2. **Test with ADB:**
   ```bash
   adb shell am start -a android.intent.action.VIEW \
     -d "openclaw://action/check_gateway"
   ```

3. **Check default app:**
   - Settings → Apps → Default apps
   - Verify OpenClaw is set for its links

### Siri Shortcut Not Triggering

1. **Re-record phrase:**
   - Different wording
   - Clear pronunciation

2. **Enable Siri Suggestions:**
   - Settings → Siri & Search
   - Enable Suggestions

3. **Check shortcut permissions:**
   - Settings → Shortcuts
   - Allow untrusted shortcuts (if needed)

### Google Assistant Not Responding

1. **Check IFTTT connection:**
   - Reconnect Google Assistant
   - Verify applet is enabled

2. **Use exact phrase:**
   - Phrase must match exactly
   - Try alternative phrases

---

## Advanced Configuration

### Custom URL Handler (iOS)

**Info.plist:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>openclaw</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.openclaw.mobile</string>
    </dict>
</array>
```

### App Links Verification (Android)

**Asset Links JSON:**
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.openclaw.mobile",
      "sha256_cert_fingerprints": ["YOUR_APP_SIGNATURE"]
    }
  }
]
```

Host at: `https://openclaw.app/.well-known/assetlinks.json`

---

## API Reference

### URL Scheme Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionId` | string | Action to execute |
| `title` | string | Notification title |
| `body` | string | Notification body |
| `message` | string | Chat message |
| `reason` | string | Reason for action |
| `session_key` | string | Agent session key |
| `duration` | number | Duration in seconds |

### Response Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Invalid parameters |
| 401 | Unauthorized |
| 404 | Action not found |
| 500 | Internal error |

---

## Support

- **Documentation:** `/docs/AUTOMATION-GUIDE.md`
- **IFTTT Integration:** `/docs/IFTTT-INTEGRATION.md`
- **GitHub Issues:** Report bugs
- **Discord:** Community support

---

*Last updated: 2026-03-09*