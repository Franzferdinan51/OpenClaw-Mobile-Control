# Agent Control API Reference

> OpenClaw Mobile App - Agent Control API  
> Version: 1.5.0  
> Port: 8765 (REST), 8766 (WebSocket)

## Overview

The Agent Control API provides a programmatic interface for controlling OpenClaw from the mobile app, CLI, or external tools. It's designed for localhost-only access by default, with optional token authentication for remote access.

---

## Quick Start

### Start the API Server

**Option 1: From the App**
1. Open OpenClaw Mobile
2. Go to Settings → Agent Control API
3. Enable "API Server"
4. The API will start on port 8765

**Option 2: From CLI**
```bash
# Start the app with API enabled
flutter run --dart-define=ENABLE_API=true

# Or use the CLI directly
dart run bin/mobile_cli.dart serve --port 8765
```

### Test the API

```bash
# Health check
curl http://localhost:8765/health

# Get status
curl http://localhost:8765/status
```

---

## Authentication

### Localhost (Default)
By default, the API only accepts connections from `localhost`, `127.0.0.1`, or `::1`. No authentication required.

### Token Authentication
For remote access, enable token authentication:

```bash
# Start with token
dart run bin/mobile_cli.dart serve --port 8765 --token YOUR_SECRET_TOKEN

# Use token in requests
curl -H "Authorization: Bearer YOUR_SECRET_TOKEN" http://localhost:8765/status
```

### Network Access
For LAN access (e.g., from another device on the same network):

```bash
# Disable localhost restriction (use with caution!)
dart run bin/mobile_cli.dart serve --port 8765 --allow-remote --token YOUR_SECRET_TOKEN
```

---

## REST API Endpoints

### Status Endpoints

#### GET /status
Get complete system status including gateway, agents, nodes, and settings.

**Example:**
```bash
curl http://localhost:8765/status
```

**Response:**
```json
{
  "ok": true,
  "timestamp": "2026-03-09T16:00:00.000Z",
  "gateway": {
    "isOnline": true,
    "version": "2.5.0",
    "uptime": "2 days, 4 hours",
    "activeConnections": 3
  },
  "agents": [
    {
      "id": "main",
      "name": "DuckBot",
      "model": "bailian/qwen3.5-plus",
      "status": "active"
    }
  ],
  "nodes": [
    {
      "id": "android-tablet",
      "name": "Samsung Tablet",
      "type": "android",
      "status": "online"
    }
  ],
  "settings": {
    "autoStart": true,
    "notifications": true,
    "theme": "system",
    "gatewayUrl": "http://localhost:18789"
  }
}
```

#### GET /health
Simple health check endpoint.

**Example:**
```bash
curl http://localhost:8765/health
```

**Response:**
```json
{
  "ok": true,
  "status": "healthy",
  "uptime": 3600,
  "port": 8765
}
```

---

### Chat Endpoints

#### POST /chat/send
Send a chat message to an agent session.

**Request Body:**
```json
{
  "session_key": "main",
  "message": "Hello, how are you?"
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/chat/send \
  -H "Content-Type: application/json" \
  -d '{"session_key": "main", "message": "Hello!"}'
```

**Response:**
```json
{
  "ok": true,
  "message": "Message sent",
  "session_key": "main",
  "timestamp": "2026-03-09T16:00:00.000Z"
}
```

#### GET /chat/history
Get chat history for a session.

**Query Parameters:**
- `session_key` (optional): Session ID (default: "main")
- `limit` (optional): Number of messages (default: 50)

**Example:**
```bash
curl "http://localhost:8765/chat/history?session_key=main&limit=10"
```

---

### Action Endpoints

#### GET /action/list
List available quick actions.

**Example:**
```bash
curl http://localhost:8765/action/list
```

**Response:**
```json
{
  "ok": true,
  "actions": [
    {"id": "grow-status", "name": "Grow Status", "description": "Check grow room status"},
    {"id": "weather-check", "name": "Weather Check", "description": "Get current weather"},
    {"id": "news-brief", "name": "News Brief", "description": "Get latest news summary"}
  ]
}
```

#### POST /action/execute
Execute a quick action.

**Request Body:**
```json
{
  "action": "grow-status",
  "params": {}
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/action/execute \
  -H "Content-Type: application/json" \
  -d '{"action": "grow-status"}'
```

---

### Control Endpoints

#### POST /control/restart
Restart the OpenClaw gateway.

**Request Body:**
```json
{
  "reason": "Maintenance"
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/control/restart \
  -H "Content-Type: application/json" \
  -d '{"reason": "Scheduled maintenance"}'
```

#### POST /control/stop
Stop the OpenClaw gateway.

**Example:**
```bash
curl -X POST http://localhost:8765/control/stop
```

#### POST /control/kill-agent
Kill a specific agent session.

**Request Body:**
```json
{
  "session_key": "subagent-123"
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/control/kill-agent \
  -H "Content-Type: application/json" \
  -d '{"session_key": "subagent-123"}'
```

#### POST /control/pause-all
Pause all running agents.

**Request Body:**
```json
{
  "hold_seconds": 120
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/control/pause-all \
  -H "Content-Type: application/json" \
  -d '{"hold_seconds": 120}'
```

#### POST /control/resume-all
Resume all paused agents.

**Example:**
```bash
curl -X POST http://localhost:8765/control/resume-all
```

---

### Log Endpoints

#### GET /logs
Get recent log entries.

**Query Parameters:**
- `limit` (optional): Number of entries (default: 100)
- `level` (optional): Filter by level (debug, info, warn, error)

**Example:**
```bash
# Get last 50 logs
curl "http://localhost:8765/logs?limit=50"

# Get only errors
curl "http://localhost:8765/logs?level=error"
```

**Response:**
```json
{
  "ok": true,
  "logs": [
    {
      "level": "info",
      "message": "API server started",
      "timestamp": "2026-03-09T16:00:00.000Z"
    },
    {
      "level": "warn",
      "message": "High memory usage detected",
      "data": {"usage": "85%"},
      "timestamp": "2026-03-09T16:00:05.000Z"
    }
  ],
  "total": 150,
  "limit": 50
}
```

#### POST /logs/clear
Clear all stored logs.

**Example:**
```bash
curl -X POST http://localhost:8765/logs/clear
```

---

### Settings Endpoints

#### GET /settings
Get current settings.

**Example:**
```bash
curl http://localhost:8765/settings
```

#### POST /settings/update
Update settings.

**Request Body:**
```json
{
  "theme": "dark",
  "notifications": true,
  "gatewayUrl": "http://192.168.1.100:18789"
}
```

**Example:**
```bash
curl -X POST http://localhost:8765/settings/update \
  -H "Content-Type: application/json" \
  -d '{"theme": "dark"}'
```

---

### Gateway Endpoints

#### GET /gateway/status
Get detailed gateway status.

#### POST /gateway/connect
Connect to a gateway.

**Request Body:**
```json
{
  "url": "http://192.168.1.100:18789"
}
```

#### POST /gateway/disconnect
Disconnect from current gateway.

---

### Agent Endpoints

#### GET /agents
List all agents.

#### GET /agents/:id
Get specific agent details.

---

### Node Endpoints

#### GET /nodes
List all paired nodes.

---

## WebSocket API

### Connection

```javascript
const ws = new WebSocket('ws://localhost:8766');
```

### Message Format

All messages are JSON:

```json
{
  "type": "<message_type>",
  "data": { /* payload */ },
  "timestamp": "2026-03-09T16:00:00.000Z"
}
```

### Client-to-Server Messages

#### Subscribe to Events
```json
{"type": "subscribe", "data": {"events": ["log", "chat.message", "state.gateway"]}}
```

#### Send Chat
```json
{"type": "chat", "data": {"session_key": "main", "message": "Hello"}}
```

#### Execute Action
```json
{"type": "action", "data": {"action": "grow-status", "params": {}}}
```

#### Control Command
```json
{"type": "control", "data": {"command": "restart", "params": {"reason": "test"}}}
```

#### Ping/Pong
```json
{"type": "ping"}
// Response: {"type": "pong", "data": {"timestamp": "..."}}
```

### Server-to-Client Events

| Event Type | Description |
|------------|-------------|
| `connected` | Connection established |
| `log` | New log entry |
| `chat.message` | Incoming chat message |
| `state.gateway` | Gateway state update |
| `state.agents` | Agents list update |
| `state.nodes` | Nodes list update |
| `action.execute` | Action execution event |
| `control.*` | Control command events |
| `heartbeat` | Periodic heartbeat |

---

## CLI Reference

### Installation
```bash
# Make CLI executable
chmod +x bin/mobile_cli.dart

# Run directly
./bin/mobile_cli.dart status

# Or via dart
dart run bin/mobile_cli.dart status
```

### Commands

```bash
# Status
openclaw-mobile status

# Chat
openclaw-mobile chat "Hello world" --session=main

# Actions
openclaw-mobile action grow-status
openclaw-mobile action weather-check

# Control
openclaw-mobile control restart --reason="maintenance"
openclaw-mobile control kill-agent --session=subagent-123
openclaw-mobile control pause-all
openclaw-mobile control resume-all

# Logs
openclaw-mobile logs --limit=50 --level=error

# Settings
openclaw-mobile settings get
openclaw-mobile settings update --theme=dark

# Natural Language
openclaw-mobile intent "check gateway status"
openclaw-mobile intent "send message hello"
openclaw-mobile intent "restart gateway"
```

---

## Integration Examples

### Python Client

```python
import requests

API_URL = "http://localhost:8765"

def get_status():
    r = requests.get(f"{API_URL}/status")
    return r.json()

def send_chat(message, session="main"):
    r = requests.post(f"{API_URL}/chat/send", json={
        "session_key": session,
        "message": message
    })
    return r.json()

def restart_gateway(reason="API request"):
    r = requests.post(f"{API_URL}/control/restart", json={
        "reason": reason
    })
    return r.json()

# Usage
status = get_status()
print(f"Gateway online: {status['gateway']['isOnline']}")

send_chat("Hello from Python!")
```

### JavaScript Client

```javascript
const API_URL = 'http://localhost:8765';

async function getStatus() {
  const res = await fetch(`${API_URL}/status`);
  return res.json();
}

async function sendChat(message, session = 'main') {
  const res = await fetch(`${API_URL}/chat/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_key: session, message })
  });
  return res.json();
}

// Usage
const status = await getStatus();
console.log(`Gateway online: ${status.gateway.isOnline}`);
```

### WebSocket Client (JavaScript)

```javascript
const ws = new WebSocket('ws://localhost:8766');

ws.onopen = () => {
  console.log('Connected');
  
  // Subscribe to logs and chat
  ws.send(JSON.stringify({
    type: 'subscribe',
    data: { events: ['log', 'chat.message'] }
  }));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  console.log(`[${msg.type}]`, msg.data);
};

// Send chat
ws.send(JSON.stringify({
  type: 'chat',
  data: { session_key: 'main', message: 'Hello via WebSocket' }
}));
```

### Shell Script

```bash
#!/bin/bash
API="http://localhost:8765"

# Check status
status=$(curl -s $API/status)
echo "Status: $status"

# Send message
curl -s -X POST $API/chat/send \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from shell script"}'

# Get logs
curl -s "$API/logs?limit=10" | jq '.logs'
```

---

## Error Handling

All errors return JSON with an `error` field:

```json
{
  "error": "session_key required"
}
```

HTTP Status Codes:
- `200` - Success
- `400` - Bad Request (missing/invalid parameters)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (not localhost)
- `404` - Not Found
- `500` - Internal Server Error

---

## Security Considerations

1. **Localhost Only by Default**: The API binds to `127.0.0.1` by default, preventing external access.

2. **Token Authentication**: Enable token auth when allowing network access.

3. **No Sensitive Data**: The API does not expose credentials or private keys.

4. **Rate Limiting**: Consider adding rate limiting for production use.

5. **HTTPS**: For remote access, use a reverse proxy with HTTPS.

---

## Troubleshooting

### API Not Starting
```bash
# Check if port is in use
lsof -i :8765

# Try a different port
dart run bin/mobile_cli.dart serve --port 8766
```

### Connection Refused
```bash
# Check if server is running
curl http://localhost:8765/health

# Check firewall (if allowing remote access)
sudo ufw allow 8765/tcp
```

### WebSocket Not Connecting
```javascript
// Check WebSocket server is running
fetch('http://localhost:8766')
  .then(r => r.json())
  .then(console.log)
```

---

## Version History

| Version | Changes |
|---------|---------|
| 1.5.0 | Added WebSocket API, intent parser, CLI |
| 1.0.0 | Initial REST API |

---

## Support

For issues or feature requests, visit:  
https://github.com/Franzferdinan51/openclaw-mobile

---

**🦆 OpenClaw Mobile - Agent Control API**