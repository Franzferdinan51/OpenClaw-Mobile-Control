# IFTTT/Make Integration Guide

Connect OpenClaw Mobile with IFTTT, Make (Integromat), and Zapier for powerful automation workflows.

---

## Table of Contents

1. [Overview](#overview)
2. [IFTTT Setup](#ifttt-setup)
3. [Make (Integromat) Setup](#make-integromat-setup)
4. [Zapier Setup](#zapier-setup)
5. [Pre-built Templates](#pre-built-templates)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

---

## Overview

OpenClaw Mobile can integrate with automation platforms in two ways:

| Direction | Method | Use Case |
|-----------|--------|----------|
| **Incoming** | Webhook endpoints | External services trigger OpenClaw actions |
| **Outgoing** | Webhook URLs | OpenClaw sends events to external services |

### Prerequisites

- OpenClaw Mobile app installed
- Public URL via ngrok or Cloudflare Tunnel (for incoming webhooks)
- IFTTT/Make/Zapier account

---

## IFTTT Setup

### Step 1: Get Your IFTTT Webhook Key

1. Go to [IFTTT Webhooks](https://ifttt.com/maker_webhooks)
2. Click "Documentation" in the top right
3. Copy your key (format: `your-ifttt-key-here`)

Your webhook URL format:
```
https://maker.ifttt.com/trigger/{event}/with/key/{your-key}
```

### Step 2: Create an Applet (Incoming to OpenClaw)

**Example: Weather Alert → OpenClaw Notification**

1. Go to [IFTTT Create](https://ifttt.com/create)
2. Click "If This" → Search "Weather Underground"
3. Choose trigger: "Today's weather report"
4. Configure: Select your location and condition (e.g., "High temperature above 90°F")
5. Click "Then That" → Search "Webhooks"
6. Choose action: "Make a web request"
7. Configure:
   - URL: `https://your-ngrok-url.ngrok.io/webhook/action/send_notification`
   - Method: `POST`
   - Content-Type: `application/json`
   - Body:
     ```json
     {
       "parameters": {
         "title": "🌡️ Heat Alert",
         "body": "Temperature will reach {{Value}}°F today!"
       }
     }
     ```
8. Add header: `X-Webhook-Secret: your-webhook-secret`
9. Create action

### Step 3: Create an Applet (Outgoing from OpenClaw)

**Example: Gateway Offline → IFTTT Notification**

1. In OpenClaw Mobile:
   - Go to Automation → Webhooks
   - Add webhook
   - URL: `https://maker.ifttt.com/trigger/gateway_offline/with/key/YOUR_KEY`
   - Events: `gatewayOffline`

2. In IFTTT:
   - Create applet
   - If: Webhooks → "Receive a web request" → Event: `gateway_offline`
   - Then: Notifications → "Send a notification"
   - Message: "⚠️ OpenClaw Gateway is offline!"

---

## Make (Integromat) Setup

### Step 1: Create a Scenario

1. Go to [Make](https://www.make.com)
2. Click "Create a new scenario"
3. Add module: "Webhooks" → "Custom webhook"
4. Copy the webhook URL

### Step 2: Configure OpenClaw to Send Events

In OpenClaw Mobile:
- Go to Automation → Webhooks
- Add the Make webhook URL
- Select events to forward

### Example: Gateway Status to Slack

```
OpenClaw Mobile
    ↓ (gatewayOffline event)
Make Webhook
    ↓
Slack "Create a Message"
    ↓
#alerts channel: "⚠️ Gateway offline at {{timestamp}}"
```

### Step 3: Advanced Scenario with Conditions

1. Webhook trigger (receives OpenClaw event)
2. Router (filter by event type)
   - Route A: `gatewayOffline` → Slack alert
   - Route B: `agentStarted` → Log to Google Sheets
   - Route C: `actionExecuted` → Update dashboard
3. Each route can have multiple actions

---

## Zapier Setup

### Step 1: Create a Zap

1. Go to [Zapier](https://zapier.com)
2. Click "Create Zap"
3. Trigger: "Webhooks by Zapier" → "Catch Hook"
4. Copy the webhook URL

### Step 2: Configure OpenClaw

In OpenClaw Mobile:
- Add the Zapier webhook URL
- Select events to forward

### Example: Daily Status Report

```
Trigger: Schedule (every day at 8 AM)
    ↓
Action: Webhooks → POST to OpenClaw
    URL: https://your-url/webhook/action/check_status
    Body: {"parameters": {"report": true}}
    ↓
OpenClaw checks gateway and sends notification
```

---

## Pre-built Templates

### Template 1: Weather Alert → Notification

**IFTTT Configuration:**
```yaml
Trigger: Weather Underground - High temperature above threshold
Action: Webhooks - POST to OpenClaw
URL: https://your-ngrok.io/webhook/action/send_notification
Headers:
  X-Webhook-Secret: your-secret
Body:
  actionId: send_notification
  parameters:
    title: "🌡️ Heat Alert"
    body: "Temperature will reach {{Value}}°F"
```

### Template 2: Gateway Offline → Restart

**OpenClaw Automation Rule:**
```yaml
name: "Gateway Offline Alert and Restart"
condition:
  type: gatewayOffline
actions:
  - type: sendNotification
    parameters:
      title: "⚠️ Gateway Offline"
      body: "Attempting restart..."
  - type: executeWebhook
    parameters:
      url: https://maker.ifttt.com/trigger/gateway_restart/with/key/YOUR_KEY
  - type: wait
    parameters:
      seconds: 60
  - type: checkGateway
```

### Template 3: Location-Based Actions

**IFTTT + OpenClaw:**
```yaml
Trigger: Location - Enter area (home)
Action: Webhooks - POST to OpenClaw
URL: https://your-ngrok.io/webhook/action/execute
Body:
  actionId: check_gateway
  parameters:
    notifyOnSuccess: true
```

### Template 4: Scheduled Health Check

**OpenClaw Automation Rule:**
```yaml
name: "Hourly Gateway Check"
schedule: "0 * * * *"  # Every hour
actions:
  - type: checkGateway
  - type: sendWebhook
    parameters:
      url: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
      body:
        text: "✅ Gateway online - {{timestamp}}"
```

### Template 5: Agent Started → Log to Sheets

**Make/Integromat:**
```
Webhook (OpenClaw agentStarted event)
    ↓
Google Sheets - Add Row
    Sheet: Agent Log
    Row: [timestamp, agentId, status]
```

---

## Examples

### Example 1: Complete IFTTT Weather Integration

**Setup in IFTTT:**

1. Create applet: "If weather alert, then notify OpenClaw"
   - Trigger: Weather Underground → "Today's weather report"
   - Condition: "High temperature above 95°F"
   - Action: Webhooks → POST to your OpenClaw webhook

**OpenClaw Webhook Handler:**
```bash
curl -X POST https://your-ngrok.io/webhook/action/send_notification \
  -H "X-Webhook-Secret: your-secret" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": {
      "title": "🌡️ Extreme Heat Warning",
      "body": "Temperature will reach {{Value}}°F - Stay hydrated!"
    }
  }'
```

### Example 2: Make Scenario for Multi-Action

**Scenario Flow:**
```
1. Webhook receives OpenClaw event
2. Filter: event.type == "gatewayOffline"
3. Parallel actions:
   a. Slack: Post to #alerts
   b. Email: Send to admin
   c. HTTP: Call restart endpoint
```

**Make Configuration:**
```json
{
  "trigger": {
    "type": "webhook",
    "url": "https://hook.make.com/your-webhook-id"
  },
  "filter": {
    "condition": "{{event.type}} = gatewayOffline"
  },
  "actions": [
    {
      "type": "slack",
      "channel": "#alerts",
      "message": "⚠️ Gateway offline at {{timestamp}}"
    },
    {
      "type": "email",
      "to": "admin@example.com",
      "subject": "OpenClaw Alert",
      "body": "Gateway went offline at {{timestamp}}"
    }
  ]
}
```

### Example 3: Zapier Multi-Step Zap

**Zap Flow:**
```
1. Schedule (daily at 8 AM)
2. Webhook POST to OpenClaw (check status)
3. Filter: if gateway offline
4. SMS to admin
5. Create Trello card for follow-up
```

---

## Troubleshooting

### Webhook Not Received

1. **Check tunnel is running:**
   ```bash
   # ngrok
   ngrok http 8765
   
   # Cloudflare Tunnel
   cloudflared tunnel --url http://localhost:8765
   ```

2. **Verify URL in request:**
   - Must match your tunnel URL
   - Must include `/webhook/action/{actionId}` path

3. **Check webhook secret:**
   - Header: `X-Webhook-Secret` must match app setting
   - Case-sensitive

### Events Not Forwarding

1. **Check webhook is enabled:**
   - OpenClaw → Automation → Webhooks
   - Toggle should be ON

2. **Verify event subscription:**
   - Webhook should have `*` or specific events selected

3. **Check external service logs:**
   - IFTTT: Check applet activity
   - Make: Check scenario history
   - Zapier: Check zap run history

### Timeout Errors

1. **Increase timeout in automation platform:**
   - IFTTT: Default 5 seconds
   - Make: Configure in module settings
   - Zapier: Use "Wait" action

2. **Use async processing:**
   - OpenClaw responds immediately
   - Processes in background

### Debug Mode

Enable debug logging in OpenClaw:
```bash
curl -X POST https://your-url/webhook/control/debug \
  -H "X-Webhook-Secret: your-secret" \
  -d '{"enabled": true}'
```

---

## API Reference

### Incoming Webhook Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/webhook/action/{actionId}` | POST | Trigger an action |
| `/webhook/chat` | POST | Send a chat message |
| `/webhook/control/{command}` | POST | Execute control command |

### Request Format

```json
{
  "actionId": "send_notification",
  "parameters": {
    "title": "Alert",
    "body": "Message content"
  }
}
```

### Response Format

```json
{
  "ok": true,
  "actionId": "send_notification",
  "executedAt": "2026-03-09T16:00:00Z"
}
```

---

## Security Best Practices

1. **Always use webhook secrets**
   - Never leave webhooks unauthenticated
   - Rotate secrets periodically

2. **Use HTTPS only**
   - Never use HTTP for production
   - Verify SSL certificates

3. **Limit exposed endpoints**
   - Use firewall rules
   - Whitelist IP addresses if possible

4. **Validate incoming data**
   - Check required fields
   - Sanitize user input

5. **Rate limiting**
   - Implement rate limits
   - Use queues for high volume

---

## Support

- **Documentation:** `/docs/AUTOMATION-GUIDE.md`
- **GitHub Issues:** Report bugs
- **Discord:** Community support

---

*Last updated: 2026-03-09*