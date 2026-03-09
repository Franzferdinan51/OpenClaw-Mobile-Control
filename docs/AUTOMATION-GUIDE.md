# OpenClaw Mobile - Automation Guide

Make your OpenClaw mobile app automatable by external scripts, agents, and automation platforms.

---

## Table of Contents

1. [Webhook Triggers](#webhook-triggers)
2. [IFTTT/Make/Zapier Integration](#iftttmakezapier-integration)
3. [iOS Shortcuts & Android Intents](#ios-shortcuts--android-intents)
4. [Background Automation](#background-automation)
5. [Event Subscriptions](#event-subscriptions)
6. [Scripting API](#scripting-api)
7. [Quick Start Examples](#quick-start-examples)

---

## Webhook Triggers

### Receiving Webhooks (Incoming)

To receive webhooks on your mobile app, you need a public URL. Use a tunneling service:

```bash
# Using ngrok (recommended)
ngrok http 18789

# Using Cloudflare Tunnel
cloudflared tunnel --url http://localhost:18789
```

**Webhook Endpoints:**

| Endpoint | Description | Example |
|----------|-------------|---------|
| `POST /webhook/action/{actionId}` | Trigger an action | `curl -X POST https://your-url/webhook/action/send_notification` |
| `POST /webhook/chat/{message}` | Send a chat message | `curl -X POST https://your-url/webhook/chat/Hello%20World` |
| `POST /webhook/control/{command}` | Execute a control command | `curl -X POST https://your-url/webhook/control/restart` |

**Authentication:**

All requests should include the `X-Webhook-Secret` header:
```bash
curl -X POST https://your-url/webhook/action/send_notification \
  -H "X-Webhook-Secret: your-webhook-secret" \
  -H "Content-Type: application/json" \
  -d '{"parameters": {"title": "Hello", "body": "World"}}'
```

**Request Body Examples:**

```json
// Action webhook
{
  "actionId": "send_notification",
  "parameters": {
    "title": "Alert",
    "body": "Gateway is offline!"
  }
}

// Chat webhook
{
  "message": "Check the gateway status",
  "sessionId": "optional-session-id"
}

// Control webhook
{
  "command": "restart",
  "parameters": {
    "service": "gateway"
  }
}
```

### Sending Webhooks (Outgoing)

Configure webhooks to send events to external services:

1. Open Automation screen → Webhooks tab
2. Click + to add webhook
3. Enter name and URL (e.g., IFTTT webhook URL)
4. Choose which events to send

---

## IFTTT/Make/Zapier Integration

### IFTTT Setup

1. **Create an Applet in IFTTT:**
   - If: Webhook (Receive web request)
   - Then: Notifications (Send a notification)

2. **Get your webhook URL:**
   - Go to: https://ifttt.com/maker_webhooks
   - Click "Documentation"
   - Copy the URL (format: `https://maker.ifttt.com/trigger/{event}/with/key/xxx`)

3. **Add to OpenClaw:**
   - Go to Automation → Webhooks
   - Add your IFTTT webhook URL
   - Configure events (e.g., `gatewayOffline`)

### Make (formerly Integromat) Setup

1. Create a new scenario in Make
2. Add "Webhook" as trigger
3. Copy the webhook URL
4. Add to OpenClaw webhooks

### Zapier Setup

1. Create a new Zap
2. Choose "Webhook" as trigger
3. Copy webhook URL
4. Add to OpenClaw webhooks

### Example Automations

**If weather alert → Send notification:**
```
Make/Zapier detects weather API alert
  ↓
Trigger OpenClaw webhook: POST /webhook/action/send_notification
  ↓
OpenClaw shows push notification
```

**If gateway down → Restart:**
```
Automation engine detects gatewayOffline
  ↓
Trigger webhook to server: POST /webhook/control/restart
  ↓
Gateway restarts automatically
```

---

## iOS Shortcuts & Android Intents

### iOS Shortcuts

**Trigger via URL Scheme:**
```
openclaw://action?action=send_notification&title=Hello&body=World
openclaw://chat?message=Check%20status
openclaw://control?command=restart
```

**Create Shortcut:**
1. Open Shortcuts app
2. Tap + → Add Action
3. Search "URL"
4. Enter `openclaw://action?action=send_notification&title=Test`
5. Add to Home Screen

**Using Shortcuts from OpenClaw:**
- Use `Action` type in automation to trigger iOS Shortcuts
- Requires iOS 16+ for App Intents

### Android Intents

**Send Intent from external app:**
```kotlin
// Kotlin example
val intent = Intent().apply {
  component = ComponentName(
    "com.openclaw.mobile",
    "com.openclaw.mobile.MainActivity"
  )
  putExtra("action", "send_notification")
  putExtra("title", "Hello")
  putExtra("body", "World")
}
startActivity(intent)
```

**App Links (Android 6+):**
```
https://openclaw.app/action/send_notification?title=Hello
```

**Home Screen Widgets:**
- Use Android's AppWidgetProvider
- Create quick action buttons that trigger intents

---

## Background Automation

### Scheduled Actions

Configure actions to run on a schedule:

| Schedule | Description |
|----------|-------------|
| `Every X minutes` | Check gateway every X minutes |
| `At specific time` | Daily at 8 AM |
| `Cron expression` | Advanced scheduling |

**Example: Check gateway every 5 minutes**
1. Go to Automation → Quick Automations
2. Tap "Check Gateway Every 5 min"
3. The automation runs in background

### Condition-Based Triggers

Automations trigger when conditions are met:

| Condition | Description |
|-----------|-------------|
| `gatewayOnline` | Gateway comes online |
| `gatewayOffline` | Gateway goes offline |
| `wifiConnected` | Device connects to WiFi |
| `wifiDisconnected` | Device disconnects from WiFi |
| `timeOfDay` | Specific time reached |

### Location-Based Triggers

Requires location permissions:

**Arrive Home:**
- Trigger: Location enters home area
- Action: Check gateway status

**Leave Work:**
- Trigger: Location leaves work area  
- Action: Send status notification

---

## Event Subscriptions

### Local WebSocket Server

The app can broadcast events via WebSocket for local apps to subscribe:

```javascript
// Connect to local WebSocket
const ws = new WebSocket('ws://localhost:9867/events');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Event:', data.type, data.data);
};
```

### Event Types

| Event | Data | Description |
|-------|------|-------------|
| `gatewayOnline` | URL | Gateway came online |
| `gatewayOffline` | reason | Gateway went offline |
| `agentStarted` | agentId | Agent session started |
| `agentStopped` | agentId | Agent session stopped |
| `actionExecuted` | actionId | Action was executed |
| `automationTriggered` | automationId | Automation triggered |
| `scheduleTriggered` | scheduleId | Scheduled task ran |

### Forward Events to Webhook

Configure outgoing webhooks to forward events:

1. Automation → Webhooks → Add
2. Enter webhook URL
3. Select events to forward

---

## Scripting API

### Available Functions

JavaScript/Python scripts can use these functions:

```javascript
// Check gateway status
const isOnline = await api.isGatewayOnline();

// Make HTTP request
const response = await api.request('https://api.example.com/data');

// Send notification
api.notify('Title', 'Message');

// Get app state
const state = api.getState();

// Log message
api.logMsg('Hello from script');

// Wait/sleep
await api.sleep(5000);
```

### Example Scripts

**Gateway Health Check:**
```javascript
async function main() {
  const isOnline = await api.isGatewayOnline();
  
  if (!isOnline) {
    api.notify('Gateway Alert', 'Gateway is offline!');
  } else {
    api.logMsg('Gateway is online');
  }
  
  return { status: isOnline ? 'online' : 'offline' };
}

main();
```

**Weather Alert Integration:**
```javascript
async function main() {
  const response = await api.request(
    'https://api.weather.example/current?city=NYC'
  );
  
  const temp = response.data?.temperature;
  
  if (temp > 95) {
    api.notify('🌡️ Heat Alert', 'Temperature is ' + temp + '°F');
  }
  
  return { temperature: temp };
}

main();
```

**Periodic Status Report:**
```javascript
async function main() {
  const isOnline = await api.isGatewayOnline();
  const state = api.getState();
  
  const message = `OpenClaw Status
Gateway: ${isOnline ? '✅ Online' : '❌ Offline'}
Time: ${new Date().toLocaleString()}`;
  
  api.notify('Daily Report', message);
  api.logMsg('Report sent');
}

main();
```

---

## Quick Start Examples

### Example 1: IFTTT Weather Alert

```
1. Create IFTTT applet with Webhook trigger
2. Get webhook URL: https://maker.ifttt.com/trigger/weather_alert/with/key/xxx
3. In OpenClaw: Automation → Webhooks → Add
4. URL: your IFTTT URL
5. Events: select "automation" events
6. Create automation: Check weather every hour
7. IF weather alert → automation triggers IFTTT → phone notification
```

### Example 2: Gateway Auto-Restart

```
1. Create automation:
   - Condition: gatewayOffline
   - Action: wait 5 minutes
   - Action: executeWebhook (control/restart)
2. Or trigger from external:
   curl -X POST https://your-ngrok/webhook/control/restart
```

### Example 3: Morning Status to Slack

```
1. Create Slack webhook URL
2. Add to OpenClaw webhooks
3. Create automation:
   - Schedule: 8 AM daily
   - Action: runScript (gateway check)
   - Action: sendWebhook (to Slack)
```

### Example 4: iOS Shortcut Trigger

```
1. Create Shortcut in iOS Shortcuts app
2. Add URL action: openclaw://action?action=check_status
3. Add to Home Screen
4. Tap widget to trigger action in OpenClaw
```

---

## Troubleshooting

### Webhooks Not Working

1. **Check tunnel is running:**
   ```bash
   ngrok http 18789
   ```
   
2. **Verify secret matches:**
   - In app: Automation → Webhooks → Check secret
   - In request: Header must match

3. **Check logs:**
   - Look for "Webhook received" in app logs

### Automations Not Running

1. **Ensure automation is enabled**
2. **Check conditions are correct**
3. **Verify app is in background (not force closed)**
4. **Check battery optimization settings**

### Scripts Not Executing

1. **Check script syntax**
2. **Verify API calls are correct**
3. **Check network connectivity**
4. **Review script logs in console**

---

## Security Considerations

1. **Use webhook secrets** - Don't leave webhooks unauthenticated
2. **Keep API keys secure** - Don't hardcode in scripts
3. **Limit exposed endpoints** - Use firewall rules
4. **Rotate secrets periodically** - Update regularly

---

## API Reference

### REST Endpoints (for external services)

```
GET  /api/automation/rules         # List automation rules
POST /api/automation/rules         # Create rule
DELETE /api/automation/rules/{id}  # Delete rule
POST /api/automation/rules/{id}/run  # Trigger rule

GET  /api/webhooks                 # List webhooks
POST /api/webhooks                 # Add webhook
DELETE /api/webhooks/{id}          # Remove webhook

GET  /api/scripts                  # List scripts
POST /api/scripts                  # Add script
POST /api/scripts/{id}/run         # Run script
DELETE /api/scripts/{id}          # Delete script
```

### WebSocket Events

```
ws://localhost:18789/ws/events
```

Subscribe to event stream for real-time updates.

---

## Support

- GitHub Issues: Report bugs
- Discord: Ask questions
- Documentation: Check updated guides

---

*Last updated: 2026-03-09*