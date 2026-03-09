# OpenClaw Mobile App - API Testing Guide

**Version:** 1.0.0  
**Purpose:** Test OpenClaw Gateway API endpoints with curl

---

## Prerequisites

### Get Your Gateway Token

```bash
# Find your gateway token
cat ~/.openclaw/config | grep -A5 "gateway"
# Or
cat ~/.openclaw/config.yaml | grep token
```

### Gateway URL

Default: `http://localhost:18789`  
Network: `http://192.168.1.101:18789` (replace with your gateway IP)

---

## Authentication

### Step 1: Authenticate with Gateway

```bash
curl -X POST http://localhost:18789/api/mobile/auth \
  -H "Content-Type: application/json" \
  -d '{
    "token": "your-gateway-token-here",
    "device_name": "Test-Device",
    "device_id": "test-device-001"
  }'
```

**Response:**
```json
{
  "success": true,
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 2592000,
  "gateway_info": {
    "version": "1.2.3",
    "hostname": "DuckBot-Gateway",
    "uptime": 432000,
    "features": ["chat", "control", "logs", "quick-actions"]
  }
}
```

### Step 2: Save Token for Later Use

```bash
# Save access token to variable
export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Or save to file
echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." > ~/.openclaw/mobile-token
```

### Step 3: Refresh Token

```bash
curl -X POST http://localhost:18789/api/mobile/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "your-refresh-token-here"
  }'
```

---

## Status & Monitoring

### Get Full Status

```bash
curl -X GET http://localhost:18789/api/mobile/status \
  -H "Authorization: Bearer $TOKEN"
```

### Get Gateway Status Only

```bash
curl -X GET http://localhost:18789/api/mobile/status/gateway \
  -H "Authorization: Bearer $TOKEN"
```

### Get Agents Status

```bash
curl -X GET http://localhost:18789/api/mobile/status/agents \
  -H "Authorization: Bearer $TOKEN"
```

### Get Nodes Status

```bash
curl -X GET http://localhost:18789/api/mobile/status/nodes \
  -H "Authorization: Bearer $TOKEN"
```

### Get Usage Statistics

```bash
curl -X GET http://localhost:18789/api/mobile/status/usage \
  -H "Authorization: Bearer $TOKEN"
```

---

## Chat

### Send Message

```bash
curl -X POST http://localhost:18789/api/mobile/chat/send \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Check the grow status",
    "agent": "DuckBot"
  }'
```

**Response:**
```json
{
  "success": true,
  "session_key": "session-abc123",
  "message_id": "msg-001"
}
```

### Get Chat History

```bash
# Get last 50 messages
curl -X GET "http://localhost:18789/api/mobile/chat/history/session-abc123?limit=50" \
  -H "Authorization: Bearer $TOKEN"
```

### Upload File for Chat

```bash
curl -X POST http://localhost:18789/api/mobile/chat/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/photo.jpg" \
  -F "session_key=session-abc123"
```

---

## Control

### Restart Gateway

```bash
curl -X POST http://localhost:18789/api/mobile/control/gateway/restart \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confirm": true,
    "reason": "Manual restart from API test"
  }'
```

### Stop Gateway

```bash
curl -X POST http://localhost:18789/api/mobile/control/gateway/stop \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confirm": true,
    "reason": "Emergency stop"
  }'
```

### Kill Agent

```bash
curl -X POST http://localhost:18789/api/mobile/control/agent/DuckBot/kill \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confirm": true
  }'
```

### Reconnect Node

```bash
curl -X POST http://localhost:18789/api/mobile/control/node/Phone-Node/reconnect \
  -H "Authorization: Bearer $TOKEN"
```

### Run Cron Job Now

```bash
curl -X POST http://localhost:18789/api/mobile/control/cron/grow-monitor/run \
  -H "Authorization: Bearer $TOKEN"
```

### Toggle Cron Job

```bash
# Disable
curl -X POST http://localhost:18789/api/mobile/control/cron/grow-monitor/toggle \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": false
  }'

# Enable
curl -X POST http://localhost:18789/api/mobile/control/cron/grow-monitor/toggle \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true
  }'
```

### Pause All Automation

```bash
curl -X POST http://localhost:18789/api/mobile/control/pause-all \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confirm": true,
    "hold_seconds": 3
  }'
```

### Resume All Automation

```bash
curl -X POST http://localhost:18789/api/mobile/control/resume-all \
  -H "Authorization: Bearer $TOKEN"
```

---

## Quick Actions

### List Quick Actions

```bash
curl -X GET http://localhost:18789/api/mobile/quick-actions \
  -H "Authorization: Bearer $TOKEN"
```

### Run Quick Action

```bash
# Run grow-status action
curl -X POST http://localhost:18789/api/mobile/quick-actions/grow-status/run \
  -H "Authorization: Bearer $TOKEN"

# Run grow-photo action
curl -X POST http://localhost:18789/api/mobile/quick-actions/grow-photo/run \
  -H "Authorization: Bearer $TOKEN"
```

### Create Custom Action

```bash
curl -X POST http://localhost:18789/api/mobile/quick-actions/custom \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Morning Brief",
    "command": "./morning-brief.sh",
    "icon": "🌅",
    "category": "custom",
    "confirmation": false
  }'
```

---

## Logs

### Get Recent Logs

```bash
# Last 100 logs
curl -X GET "http://localhost:18789/api/mobile/logs?limit=100" \
  -H "Authorization: Bearer $TOKEN"

# Filter by level
curl -X GET "http://localhost:18789/api/mobile/logs?level=ERROR&limit=50" \
  -H "Authorization: Bearer $TOKEN"

# Search logs
curl -X GET "http://localhost:18789/api/mobile/logs?search=gateway&limit=50" \
  -H "Authorization: Bearer $TOKEN"
```

### Export Logs

```bash
# Export as JSON
curl -X GET "http://localhost:18789/api/mobile/logs/export?format=json&since=2026-03-09T00:00:00Z" \
  -H "Authorization: Bearer $TOKEN" \
  -o logs.json

# Export as text
curl -X GET "http://localhost:18789/api/mobile/logs/export?format=txt&since=2026-03-09T00:00:00Z" \
  -H "Authorization: Bearer $TOKEN" \
  -o logs.txt
```

---

## Setup & Configuration

### Check Setup Status

```bash
curl -X GET http://localhost:18789/api/mobile/setup/status \
  -H "Authorization: Bearer $TOKEN"
```

### List Available Skills

```bash
curl -X GET http://localhost:18789/api/mobile/setup/skills \
  -H "Authorization: Bearer $TOKEN"
```

### Install Skill

```bash
curl -X POST http://localhost:18789/api/mobile/setup/skills/install \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "skill_id": "github"
  }'
```

---

## WebSocket Connection

### Connect for Real-Time Updates

```bash
# Using wscat (install first: npm install -g wscat)
wscat -c "ws://localhost:18789/api/mobile/ws?token=$TOKEN"

# Or using curl to test (won't work, but shows URL structure)
echo "WebSocket URL: ws://localhost:18789/api/mobile/ws?token=<TOKEN>"
```

### WebSocket Subscribe Message

Once connected, send:
```json
{
  "type": "subscribe",
  "channels": ["status", "logs", "chat", "alerts"]
}
```

### Example WebSocket Messages

**Server → Client (Status Update):**
```json
{
  "type": "status_update",
  "data": {
    "gateway": { "cpu_percent": 25.2, "memory_used": 1300000000 }
  }
}
```

**Server → Client (Alert):**
```json
{
  "type": "alert",
  "data": {
    "severity": "critical",
    "message": "Gateway CPU at 95%",
    "timestamp": "2026-03-09T14:52:00Z"
  }
}
```

---

## Complete Test Script

Create a test script:

```bash
#!/bin/bash

GATEWAY="http://localhost:18789"
TOKEN_FILE="$HOME/.openclaw/mobile-token"

# Check if token exists
if [ ! -f "$TOKEN_FILE" ]; then
    echo "No token found. Please authenticate first."
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "=== Testing OpenClaw Mobile API ==="
echo ""

# Test status
echo "1. Testing status endpoint..."
curl -s -X GET "$GATEWAY/api/mobile/status" \
  -H "Authorization: Bearer $TOKEN" | jq '.gateway.version'

# Test quick actions
echo "2. Testing quick actions..."
curl -s -X GET "$GATEWAY/api/mobile/quick-actions" \
  -H "Authorization: Bearer $TOKEN" | jq '.categories | length'

# Test logs
echo "3. Testing logs..."
curl -s -X GET "$GATEWAY/api/mobile/logs?limit=5" \
  -H "Authorization: Bearer $TOKEN" | jq '.total'

echo ""
echo "=== All tests passed ==="
```

---

## Error Handling

### Common Error Responses

| Code | Meaning | Fix |
|------|---------|-----|
| 401 | Unauthorized | Check/refresh your token |
| 403 | Forbidden | Token doesn't have permissions |
| 404 | Not Found | Check endpoint URL |
| 400 | Bad Request | Check request body format |
| 503 | Gateway Busy | Try again later |

### Test Error Handling

```bash
# Test with invalid token
curl -X GET http://localhost:18789/api/mobile/status \
  -H "Authorization: Bearer invalid-token"

# Test with missing token
curl -X GET http://localhost:18789/api/mobile/status
```

---

## Next Steps

- **Use the app** → See [USER-GUIDE.md](./USER-GUIDE.md)
- **Deploy APK** → See [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Fix issues** → See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)