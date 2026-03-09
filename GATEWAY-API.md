# OpenClaw Gateway API Extensions for Mobile

**Version:** 1.0.0  
**Created:** 2026-03-09  
**Purpose:** Extend OpenClaw Gateway to support mobile app connections

---

## 🔌 New Endpoints

### **Discovery & Connection**

#### `GET /api/mobile/discover`
Advertise gateway on local network via mDNS.

**mDNS Service:**
```
Service: _openclaw._tcp.local.
Port: 18789
TXT Records:
  - version=1.2.3
  - hostname=DuckBot-Gateway
  - token_required=true
  - features=chat,control,logs,quick-actions
```

---

#### `POST /api/mobile/auth`
Authenticate mobile app with gateway token.

**Request:**
```json
{
  "token": "gateway-token-here",
  "device_name": "DuckBot's iPhone",
  "device_id": "uuid-of-device"
}
```

**Response:**
```json
{
  "success": true,
  "access_token": "jwt-token-here",
  "refresh_token": "refresh-token-here",
  "expires_in": 2592000,
  "gateway_info": {
    "version": "1.2.3",
    "hostname": "DuckBot-Gateway",
    "uptime": 432000,
    "features": ["chat", "control", "logs", "quick-actions"]
  }
}
```

---

#### `POST /api/mobile/auth/refresh`
Refresh access token.

**Request:**
```json
{
  "refresh_token": "refresh-token-here"
}
```

**Response:**
```json
{
  "success": true,
  "access_token": "new-jwt-token",
  "expires_in": 2592000
}
```

---

### **Status & Monitoring**

#### `GET /api/mobile/status`
Get comprehensive gateway status.

**Response:**
```json
{
  "gateway": {
    "status": "online",
    "version": "1.2.3",
    "uptime": 432000,
    "cpu_percent": 23.5,
    "memory_used": 1258291200,
    "memory_total": 8589934592,
    "disk_used": 52428800000,
    "disk_total": 536870912000
  },
  "agents": [
    {
      "name": "DuckBot",
      "status": "active",
      "current_task": "Researching AI models",
      "model": "bailian/qwen3.5-plus",
      "session_key": "session-abc123",
      "started_at": "2026-03-09T14:30:00Z",
      "message_count": 45
    },
    {
      "name": "Sub-agent #42",
      "status": "busy",
      "current_task": "Coding: REST API",
      "model": "bailian/glm-5",
      "session_key": "session-xyz789",
      "started_at": "2026-03-09T14:45:00Z",
      "message_count": 12
    }
  ],
  "nodes": [
    {
      "name": "Phone Node",
      "status": "connected",
      "connection_type": "adb",
      "ip": "192.168.1.251",
      "last_seen": "2026-03-09T14:50:00Z"
    },
    {
      "name": "Camera",
      "status": "streaming",
      "connection_type": "usb",
      "device": "/dev/video0",
      "last_seen": "2026-03-09T14:50:00Z"
    }
  ],
  "usage": {
    "period": "week",
    "models": [
      {
        "model": "bailian/qwen3.5-plus",
        "messages": 8200,
        "quota": 18000,
        "cost": 0
      },
      {
        "model": "bailian/MiniMax-M2.5",
        "messages": 15000,
        "quota": null,
        "cost": 0
      },
      {
        "model": "openai-codex/gpt-5.3-codex",
        "messages": 45,
        "quota": 200,
        "cost": 0
      }
    ]
  },
  "alerts": [
    {
      "id": "alert-001",
      "severity": "warning",
      "message": "Grow temperature high (82°F)",
      "timestamp": "2026-03-09T12:30:00Z",
      "acknowledged": false
    },
    {
      "id": "alert-002",
      "severity": "info",
      "message": "Phone node reconnected",
      "timestamp": "2026-03-09T09:15:00Z",
      "acknowledged": true
    }
  ],
  "crons": [
    {
      "name": "grow-monitor",
      "schedule": "0 * * * *",
      "enabled": true,
      "last_run": "2026-03-09T14:00:00Z",
      "next_run": "2026-03-09T15:00:00Z",
      "status": "success"
    },
    {
      "name": "storm-watch",
      "schedule": "33 5,9,13,17 * * *",
      "enabled": true,
      "last_run": "2026-03-09T13:33:00Z",
      "next_run": "2026-03-09T17:33:00Z",
      "status": "success"
    }
  ]
}
```

---

#### `GET /api/mobile/status/ws`
WebSocket endpoint for real-time status updates.

**Connection:**
```
ws://gateway:18789/api/mobile/status/ws?token=jwt-token
```

**Server → Client Messages:**
```json
{
  "type": "status_update",
  "data": {
    "gateway": { "cpu_percent": 25.2, "memory_used": 1300000000 },
    "agents": [...],
    "nodes": [...]
  }
}
```

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

```json
{
  "type": "agent_state_change",
  "data": {
    "agent": "DuckBot",
    "old_state": "active",
    "new_state": "idle",
    "timestamp": "2026-03-09T14:52:00Z"
  }
}
```

---

### **Chat**

#### `POST /api/mobile/chat/send`
Send a message to DuckBot (or specified agent).

**Request:**
```json
{
  "message": "Check the grow status",
  "agent": "DuckBot",
  "session_key": "existing-session-or-null"
}
```

**Response:**
```json
{
  "success": true,
  "session_key": "session-abc123",
  "message_id": "msg-001"
}
```

**WebSocket Response (async):**
```json
{
  "type": "chat_response",
  "data": {
    "session_key": "session-abc123",
    "message_id": "msg-001",
    "agent": "DuckBot",
    "content": "🌿 Grow Status Check\n\nTemp: 74.6°F | Humidity: 50.5%\nVPD: 1.45 kPa - All optimal! ✅",
    "timestamp": "2026-03-09T14:53:00Z",
    "attachments": [
      {
        "type": "image",
        "url": "/api/mobile/files/grow-status-2026-03-09.png",
        "mime_type": "image/png"
      }
    ]
  }
}
```

---

#### `GET /api/mobile/chat/history/:session_key`
Get chat history for a session.

**Query Params:**
- `limit` (default: 50, max: 200)
- `before` (timestamp for pagination)

**Response:**
```json
{
  "session_key": "session-abc123",
  "agent": "DuckBot",
  "created_at": "2026-03-09T14:30:00Z",
  "messages": [
    {
      "id": "msg-001",
      "role": "user",
      "content": "Check the grow status",
      "timestamp": "2026-03-09T14:53:00Z"
    },
    {
      "id": "msg-002",
      "role": "assistant",
      "content": "🌿 Grow Status Check...",
      "timestamp": "2026-03-09T14:53:05Z",
      "attachments": [...]
    }
  ]
}
```

---

#### `POST /api/mobile/chat/upload`
Upload a file (photo, document) for chat.

**Request:** `multipart/form-data`
- `file`: Binary file
- `session_key`: Optional

**Response:**
```json
{
  "success": true,
  "file_id": "file-abc123",
  "url": "/api/mobile/files/file-abc123",
  "mime_type": "image/png",
  "size": 1048576
}
```

---

### **Control**

#### `POST /api/mobile/control/gateway/restart`
Restart the gateway.

**Request:**
```json
{
  "confirm": true,
  "reason": "Manual restart from mobile app"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Gateway restarting...",
  "expected_downtime": 5
}
```

---

#### `POST /api/mobile/control/gateway/stop`
Stop the gateway.

**Request:**
```json
{
  "confirm": true,
  "reason": "Emergency stop"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Gateway stopping..."
}
```

---

#### `POST /api/mobile/control/agent/:agent_id/kill`
Kill a specific agent.

**Request:**
```json
{
  "confirm": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Agent DuckBot terminated",
  "session_key": "session-abc123"
}
```

---

#### `POST /api/mobile/control/node/:node_id/reconnect`
Reconnect a node.

**Response:**
```json
{
  "success": true,
  "message": "Reconnection initiated",
  "node": "Phone Node"
}
```

---

#### `POST /api/mobile/control/cron/:cron_id/run`
Run a cron job immediately.

**Response:**
```json
{
  "success": true,
  "message": "Grow monitor started",
  "cron": "grow-monitor"
}
```

---

#### `POST /api/mobile/control/cron/:cron_id/toggle`
Enable/disable a cron job.

**Request:**
```json
{
  "enabled": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Grow monitor disabled",
  "cron": "grow-monitor",
  "enabled": false
}
```

---

#### `POST /api/mobile/control/pause-all`
Emergency stop all automation.

**Request:**
```json
{
  "confirm": true,
  "hold_seconds": 3
}
```

**Response:**
```json
{
  "success": true,
  "message": "All automation paused",
  "paused_at": "2026-03-09T14:55:00Z"
}
```

---

#### `POST /api/mobile/control/resume-all`
Resume all automation.

**Response:**
```json
{
  "success": true,
  "message": "All automation resumed",
  "resumed_at": "2026-03-09T15:00:00Z"
}
```

---

### **Quick Actions**

#### `GET /api/mobile/quick-actions`
List available quick actions.

**Response:**
```json
{
  "categories": [
    {
      "id": "grow",
      "name": "Grow",
      "icon": "🌿",
      "actions": [
        {
          "id": "grow-status",
          "name": "Status",
          "icon": "📊",
          "command": "./grow-status-check.sh",
          "confirmation": false,
          "description": "Full environmental report"
        },
        {
          "id": "grow-photo",
          "name": "Photo",
          "icon": "📸",
          "command": "./take-plant-photo.sh",
          "confirmation": false,
          "description": "Capture plant photo"
        }
      ]
    },
    {
      "id": "system",
      "name": "System",
      "icon": "🛠️",
      "actions": [...]
    }
  ]
}
```

---

#### `POST /api/mobile/quick-actions/:action_id/run`
Execute a quick action.

**Response (immediate):**
```json
{
  "success": true,
  "action": "grow-status",
  "message": "Grow status check started",
  "job_id": "job-abc123"
}
```

**WebSocket Response (async):**
```json
{
  "type": "quick_action_complete",
  "data": {
    "job_id": "job-abc123",
    "action": "grow-status",
    "success": true,
    "output": "🌿 Grow Status Check\n\nTemp: 74.6°F...",
    "duration_ms": 3500,
    "timestamp": "2026-03-09T14:56:00Z"
  }
}
```

---

#### `POST /api/mobile/quick-actions/custom`
Create a custom quick action.

**Request:**
```json
{
  "name": "Morning Brief",
  "command": "./morning-brief.sh",
  "icon": "🌅",
  "category": "custom",
  "confirmation": false
}
```

**Response:**
```json
{
  "success": true,
  "action_id": "custom-001",
  "message": "Custom action created"
}
```

---

### **Logs**

#### `GET /api/mobile/logs`
Get recent logs.

**Query Params:**
- `level` (INFO, WARN, ERROR, DEBUG)
- `limit` (default: 100, max: 1000)
- `since` (timestamp)
- `search` (text search)

**Response:**
```json
{
  "logs": [
    {
      "timestamp": "2026-03-09T14:50:00.123Z",
      "level": "INFO",
      "message": "Gateway started",
      "source": "gateway"
    },
    {
      "timestamp": "2026-03-09T14:50:01.456Z",
      "level": "INFO",
      "message": "WebSocket ready",
      "source": "websocket"
    },
    {
      "timestamp": "2026-03-09T14:51:15.234Z",
      "level": "WARN",
      "message": "Node reconnecting",
      "source": "nodes"
    }
  ],
  "total": 1250,
  "has_more": true
}
```

---

#### `GET /api/mobile/logs/ws`
WebSocket for live log streaming.

**Connection:**
```
ws://gateway:18789/api/mobile/logs/ws?token=jwt-token&level=INFO,WARN,ERROR
```

**Server → Client:**
```json
{
  "type": "log_entry",
  "data": {
    "timestamp": "2026-03-09T14:52:00.789Z",
    "level": "INFO",
    "message": "Sub-agent spawned",
    "source": "agents"
  }
}
```

---

#### `GET /api/mobile/logs/export`
Export logs as file.

**Query Params:**
- `format` (txt, json)
- `since` (timestamp)
- `until` (timestamp)
- `level` (optional filter)

**Response:** File download

---

### **Files**

#### `GET /api/mobile/files/:file_id`
Download a file.

**Response:** Binary file with appropriate Content-Type

---

#### `DELETE /api/mobile/files/:file_id`
Delete a file.

**Response:**
```json
{
  "success": true,
  "message": "File deleted"
}
```

---

### **Setup & Configuration**

#### `GET /api/mobile/setup/status`
Check if gateway is configured.

**Response:**
```json
{
  "configured": true,
  "version": "1.2.3",
  "skills_installed": 88,
  "nodes_connected": 2,
  "crons_active": 5
}
```

---

#### `POST /api/mobile/setup/install`
Install OpenClaw (for new setups).

**Request:**
```json
{
  "config": {
    "gateway_token": "user-generated-token",
    "models": {...},
    "crons": [...]
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Installation started",
  "job_id": "install-abc123"
}
```

---

#### `POST /api/mobile/setup/node`
Set up a new node.

**Request:**
```json
{
  "node_name": "Phone Node",
  "connection_type": "adb",
  "config": {...}
}
```

**Response:**
```json
{
  "success": true,
  "message": "Node setup initiated",
  "node_id": "node-abc123"
}
```

---

#### `GET /api/mobile/setup/skills`
List available skills from clawhub.

**Response:**
```json
{
  "skills": [
    {
      "id": "weather",
      "name": "Weather",
      "description": "Weather forecasting via Open-Meteo",
      "author": "OpenClaw",
      "version": "1.0.0",
      "installed": true
    },
    {
      "id": "github",
      "name": "GitHub",
      "description": "GitHub operations via gh CLI",
      "author": "OpenClaw",
      "version": "1.2.0",
      "installed": false
    }
  ]
}
```

---

#### `POST /api/mobile/setup/skills/install`
Install a skill.

**Request:**
```json
{
  "skill_id": "github"
}
```

**Response:**
```json
{
  "success": true,
  "message": "GitHub skill installed",
  "skill_id": "github"
}
```

---

## 🔐 Authentication

### **Token-Based Auth**

All mobile endpoints require JWT authentication (except `/api/mobile/discover` and `/api/mobile/auth`).

**Header:**
```
Authorization: Bearer <jwt-token>
```

**Token Expiry:**
- Access token: 30 days
- Refresh token: 90 days

**Token Claims:**
```json
{
  "sub": "device-uuid",
  "device_name": "DuckBot's iPhone",
  "iat": 1709999999,
  "exp": 1712591999,
  "permissions": ["read", "write", "control"]
}
```

---

## 🚨 Error Responses

### **Standard Error Format**
```json
{
  "success": false,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Authentication required",
    "details": "Valid JWT token not provided"
  },
  "timestamp": "2026-03-09T14:50:00Z"
}
```

### **Error Codes**

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTH_REQUIRED` | 401 | No token provided |
| `AUTH_INVALID` | 401 | Token expired or invalid |
| `PERMISSION_DENIED` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `INVALID_REQUEST` | 400 | Bad request format |
| `GATEWAY_BUSY` | 503 | Gateway busy, try again |
| `INTERNAL_ERROR` | 500 | Internal server error |

---

## 📡 WebSocket Protocol

### **Connection**
```
ws://gateway:18789/api/mobile/ws?token=jwt-token
```

### **Client → Server Messages**

**Subscribe:**
```json
{
  "type": "subscribe",
  "channels": ["status", "logs", "chat", "alerts"]
}
```

**Chat Send:**
```json
{
  "type": "chat_send",
  "data": {
    "message": "Hello",
    "agent": "DuckBot"
  }
}
```

**Control Action:**
```json
{
  "type": "control",
  "data": {
    "action": "restart_gateway",
    "confirm": true
  }
}
```

### **Server → Client Messages**

**Status Update:**
```json
{
  "type": "status_update",
  "data": {...}
}
```

**Log Entry:**
```json
{
  "type": "log_entry",
  "data": {...}
}
```

**Chat Response:**
```json
{
  "type": "chat_response",
  "data": {...}
}
```

**Alert:**
```json
{
  "type": "alert",
  "data": {...}
}
```

**Quick Action Complete:**
```json
{
  "type": "quick_action_complete",
  "data": {...}
}
```

---

## 🧪 Testing

### **Test with curl**

**Auth:**
```bash
curl -X POST http://localhost:18789/api/mobile/auth \
  -H "Content-Type: application/json" \
  -d '{"token":"your-gateway-token","device_name":"Test"}'
```

**Status:**
```bash
curl -X GET http://localhost:18789/api/mobile/status \
  -H "Authorization: Bearer <jwt-token>"
```

**Quick Action:**
```bash
curl -X POST http://localhost:18789/api/mobile/quick-actions/grow-status/run \
  -H "Authorization: Bearer <jwt-token>"
```

---

## 📋 Implementation Checklist

- [ ] Add mDNS discovery service
- [ ] Implement `/api/mobile/auth` endpoint
- [ ] Create JWT middleware
- [ ] Add `/api/mobile/status` endpoint
- [ ] Implement WebSocket for real-time updates
- [ ] Add chat endpoints (send, history, upload)
- [ ] Implement control endpoints (gateway, agents, nodes, crons)
- [ ] Add quick actions API
- [ ] Implement log streaming (HTTP + WebSocket)
- [ ] Add file upload/download endpoints
- [ ] Create setup/configuration endpoints
- [ ] Add rate limiting
- [ ] Implement error handling middleware
- [ ] Write API documentation
- [ ] Create Postman collection
- [ ] Test with mobile app

---

**Ready for implementation!** 🚀
