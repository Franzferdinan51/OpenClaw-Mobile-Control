# Agent Integration Guide

This document describes how to integrate AI agents (like DuckBot, Claude Code, etc.) with the OpenClaw Mobile app using the Agent Control API.

---

## Overview

The Agent Control API allows external AI agents to programmatically control the OpenClaw Mobile app, enabling:

- **Remote Gateway Control** - Restart, stop, pause agents
- **Agent Messaging** - Send messages to specific agents or broadcast
- **Status Monitoring** - Real-time gateway, agent, and node status
- **Log Access** - Retrieve and stream logs
- **Settings Management** - Update configuration remotely

---

## Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   AI Agent      │─────▶│  OpenClaw Mobile │─────▶│  OpenClaw GW    │
│ (DuckBot/etc)   │      │  Agent Control   │      │ (Linux Server)  │
└─────────────────┘      │  API (Port 8765)  │      └─────────────────┘
                        └──────────────────┘
                                 │
                        ┌────────┴────────┐
                        │                 │
                   ┌────▼────┐      ┌────▼────┐
                   │REST API │      │WebSocket│
                   │(HTTP)   │      │(Real-ti)│
                   └─────────┘      └─────────┘
```

---

## Quick Start

### 1. Enable Agent Control API

In the OpenClaw Mobile app:
1. Go to **Settings** → **Agent Control API**
2. Enable the API server
3. (Optional) Set a security token
4. (Optional) Allow remote access

### 2. Get API URL

- **Local (on same network):** `http://<phone-ip>:8765`
- **Remote (via Termux):** The URL shown in settings

### 3. Test Connection

```bash
curl http://localhost:8765/health
```

Response:
```json
{
  "ok": true,
  "status": "healthy",
  "server": "OpenClaw Mobile Agent Control API",
  "version": "1.5.0",
  "timestamp": "2026-03-09T12:00:00.000Z"
}
```

---

## REST API Reference

### Base URL

```
http://localhost:8765
```

### Authentication

Optional token-based auth using Bearer token:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8765/status
```

### Endpoints

#### Health Check

```bash
GET /health
```

#### Get Complete Status

```bash
GET /status
```

Response:
```json
{
  "ok": true,
  "gateway": {
    "online": true,
    "version": "2.1.0",
    "uptime": 3600,
    "cpu_percent": 45.2,
    "is_paused": false
  },
  "agents": [...],
  "timestamp": "2026-03-09T12:00:00.000Z"
}
```

#### Get Gateway Status Only

```bash
GET /status/gateway
```

#### Get Agents

```bash
GET /status/agents
```

#### Get Nodes

```bash
GET /status/nodes
```

#### Send Chat Message

```bash
POST /chat/send
Content-Type: application/json

{
  "session_key": "agent:main:telegram:direct:123456",
  "message": "Hello agent!"
}
```

#### Broadcast to All Agents

```bash
POST /chat/broadcast
Content-Type: application/json

{
  "message": "Hello everyone!"
}
```

#### Get Chat History

```bash
GET /chat/history/<session_key>?limit=20
```

#### Execute Action

```bash
POST /action/execute
Content-Type: application/json

{
  "action": "pause-all",
  "params": {
    "hold_seconds": 60
  }
}
```

Available actions:
- `restart-gateway` - Restart the gateway
- `stop-gateway` - Stop the gateway
- `pause-all` - Pause all agents
- `resume-all` - Resume all agents
- `kill-agent` - Kill specific agent (requires `session_key` param)
- `reconnect-node` - Reconnect a node (requires `node_name` param)
- `run-cron` - Trigger a cron job (requires `cron_name` param)

#### List Available Actions

```bash
GET /action/list
```

#### Restart Gateway

```bash
POST /control/restart
Content-Type: application/json

{
  "reason": "Maintenance update"
}
```

#### Stop Gateway

```bash
POST /control/stop
Content-Type: application/json

{
  "reason": "Shutting down"
}
```

#### Kill Agent

```bash
POST /control/kill-agent
Content-Type: application/json

{
  "session_key": "agent:main:telegram:direct:123456"
}
```

#### Pause All Agents

```bash
POST /control/pause-all
Content-Type: application/json

{
  "hold_seconds": 60
}
```

#### Resume All Agents

```bash
POST /control/resume-all
```

#### Get Logs

```bash
GET /logs?limit=100&level=error
```

Query parameters:
- `limit` - Number of logs to return (default: 100)
- `level` - Filter by level (debug, info, warn, error)
- `source` - Filter by source

#### Get Settings

```bash
GET /settings
```

#### Update Settings

```bash
POST /settings/update
Content-Type: application/json

{
  "gateway_url": "http://192.168.1.100:18789",
  "auto_connect": true
}
```

---

## WebSocket API

For real-time updates, connect to the WebSocket server:

```
ws://localhost:8766
```

### Subscribe to Channels

```json
{
  "type": "subscribe",
  "channels": ["status", "logs", "chat", "agents"]
}
```

### Receive Status Updates

```json
{
  "type": "status_update",
  "data": {...},
  "timestamp": "2026-03-09T12:00:00.000Z"
}
```

### Receive Log Updates

```json
{
  "type": "log_update",
  "logs": [...],
  "timestamp": "2026-03-09T12:00:00.000Z"
}
```

---

## MCP Server Mode

Run the app as an MCP (Model Context Protocol) server:

```
http://localhost:8767
```

### Available Tools

#### get_status

```json
{
  "tool": "get_status",
  "arguments": {}
}
```

#### send_chat

```json
{
  "tool": "send_chat",
  "arguments": {
    "session_key": "agent:main:telegram:direct:123456",
    "message": "Hello!"
  }
}
```

#### kill_agent

```json
{
  "tool": "kill_agent",
  "arguments": {
    "session_key": "agent:main:telegram:direct:123456"
  }
}
```

#### execute_action

```json
{
  "tool": "execute_action",
  "arguments": {
    "action": "restart-gateway",
    "params": {
      "reason": "Maintenance"
    }
  }
}
```

#### get_logs

```json
{
  "tool": "get_logs",
  "arguments": {
    "limit": 100,
    "level": "error"
  }
}
```

---

## Intent Parser

Natural language command processing:

```bash
POST /intent/parse
Content-Type: application/json

{
  "command": "restart gateway"
}
```

Maps to:
- `restart gateway` → POST /control/restart
- `check gateway status` → GET /status
- `get logs` → GET /logs
- `pause all agents` → POST /control/pause-all

---

## CLI Interface

For Termux usage:

```bash
# Get status
dart bin/mobile_cli.dart status

# Send message
dart bin/mobile_cli.dart chat "hello" --session=main

# Control
dart bin/mobile_cli.dart control restart --reason="maintenance"

# Logs
dart bin/mobile_cli.dart logs --limit=50 --level=error

# Intent
dart bin/mobile_cli.dart intent "check gateway status"
```

---

## Agent Integration Examples

### DuckBot Integration

```python
import requests

# Configure DuckBot to use mobile API
MOBILE_API = "http://<phone-ip>:8765"

def get_gateway_status():
    response = requests.get(f"{MOBILE_API}/status/gateway")
    return response.json()

def send_to_agent(session_key, message):
    response = requests.post(
        f"{MOBILE_API}/chat/send",
        json={"session_key": session_key, "message": message}
    )
    return response.json()

def restart_gateway(reason="DuckBot request"):
    response = requests.post(
        f"{MOBILE_API}/control/restart",
        json={"reason": reason}
    )
    return response.json()

def get_logs(limit=100):
    response = requests.get(f"{MOBILE_API}/logs", params={"limit": limit})
    return response.json()
```

### Claude Code Integration

```javascript
// Using fetch in Claude Code
const apiUrl = "http://<phone-ip>:8765";

// Get status
const status = await fetch(`${apiUrl}/status`).then(r => r.json());

// Send message
await fetch(`${apiUrl}/chat/send`, {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({
    session_key: "agent:main:telegram:direct:123456",
    message: "Hello!"
  })
});
```

### curl Examples

```bash
# Check gateway status
curl http://localhost:8765/status/gateway

# Send message to agent
curl -X POST http://localhost:8765/chat/send \
  -H "Content-Type: application/json" \
  -d '{"session_key":"agent:main:telegram:direct:123456","message":"Hello!"}'

# Restart gateway
curl -X POST http://localhost:8765/control/restart \
  -H "Content-Type: application/json" \
  -d '{"reason":"Maintenance"}'

# Get logs
curl "http://localhost:8765/logs?limit=50&level=error"

# With authentication
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8765/status
```

---

## Security Considerations

1. **Local Only by Default** - API only accepts localhost connections
2. **Optional Token Auth** - Set a token for additional security
3. **Allow Remote Manually** - Must explicitly enable remote access
4. **Firewall** - Consider using firewall rules for production

---

## Troubleshooting

### Connection Refused

- Ensure the API server is enabled in app settings
- Check the correct IP address (use `ip addr` on phone)
- Verify port 8765 is not blocked

### Authentication Failed

- Check token is set correctly
- Ensure token is passed as `Authorization: Bearer TOKEN`

### Gateway Not Connected

- The mobile app must have a valid gateway connection
- Check gateway is running on the server

### Logs Empty

- Check log level filter
- Increase limit parameter

---

## Version History

- **1.5.0** - Initial release with REST, WebSocket, MCP, CLI, and Intent Parser