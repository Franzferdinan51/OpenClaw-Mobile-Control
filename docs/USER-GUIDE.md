# OpenClaw Mobile - User Guide

**Version:** 2.0.0  
**Last Updated:** March 9, 2026

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [App Modes](#app-modes)
3. [Navigation Overview](#navigation-overview)
4. [Dashboard](#dashboard)
5. [Chat](#chat)
6. [Quick Actions](#quick-actions)
7. [Control Panel](#control-panel)
8. [Logs](#logs)
9. [Agent Monitor](#agent-monitor)
10. [Automation](#automation)
11. [Browser Control](#browser-control)
12. [Settings](#settings)
13. [Voice Commands](#voice-commands)
14. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Installation

1. **Download the APK** from GitHub releases or build from source:
   ```bash
   git clone https://github.com/Franzferdinan51/OpenClaw-Mobile-Control.git
   cd OpenClaw-Mobile-Control
   flutter pub get
   flutter build apk --release
   ```

2. **Install on your phone:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. **First Launch:**
   - Open the app
   - The app will automatically scan for OpenClaw gateways on your network
   - Select your gateway from the list
   - Enter your gateway token (found in `~/.openclaw/config`)
   - You're connected!

### Connection Methods

| Method | Description |
|--------|-------------|
| **mDNS/Auto-Discovery** | Automatically finds gateways on your local network |
| **Manual Entry** | Enter IP address and port manually |
| **Tailscale** | Connect to gateways over VPN (remote access) |
| **History** | Quick reconnect to previously used gateways |

---

## App Modes

OpenClaw Mobile has three app modes that control what features are visible:

### Basic Mode (Green) 🌱
- **Tabs:** 4 (Home, Chat, Actions, Settings)
- **Best for:** Simple monitoring and basic control
- **Features:** Essential features only

### Power User Mode (Blue) ⚡
- **Tabs:** 5 (Home, Chat, Actions, Tools, Settings)
- **Best for:** Daily users who want complete control
- **Features:** Full feature set organized cleanly

### Developer Mode (Purple) 🛠️
- **Tabs:** 6 (Home, Chat, Actions, Tools, Dev, Settings)
- **Best for:** Developers and power users
- **Features:** All options including API Explorer, Debug Console, Raw Logs, Network Inspector

**Changing Modes:**
1. Go to Settings → App tab
2. Tap the mode segment (Basic/Power User/Developer)
3. The app will restart with the new mode

---

## Navigation Overview

### Tab Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  📊 Home  │  💬 Chat  │  ⚡ Actions  │  🔧 Tools  │  ⚙️ Settings  │
└─────────────────────────────────────────────────────────────────┘
```

### Tools Hub (Power User/Developer)
- 📜 Logs - Live log streaming with filters
- 🌐 Browser - BrowserOS MCP automation
- ⚙️ Workflows - Automation workflow builder
- 📅 Scheduled Tasks - Task scheduling
- 🤖 AI Models - Model selection hub

### Dev Tools (Developer Mode Only)
- 🔍 API Explorer - Test gateway API endpoints
- 📝 Debug Console - Run diagnostic commands
- 📄 Raw Logs - Unfiltered log viewer
- ⚡ Advanced Config - Raw configuration editor
- 🌐 Network Inspector - API call monitoring

---

## Dashboard

The Dashboard provides a real-time overview of your OpenClaw setup.

### Features

| Feature | Description |
|---------|-------------|
| **Gateway Status** | Online/offline indicator with uptime |
| **Agent Count** | Active agents running |
| **Node Count** | Connected nodes |
| **CPU/Memory** | System resource usage |
| **Quick Stats** | Recent messages, tasks, alerts |

### Using the Dashboard

1. **View Status:** The dashboard auto-refreshes every 30 seconds (configurable)
2. **Manual Refresh:** Pull down or tap the refresh button
3. **Quick Actions:** Tap quick action buttons for common tasks

---

## Chat

Chat with DuckBot and 61 specialized agent personalities!

### Features

- **Direct Messaging** - Chat with DuckBot
- **61 Agent Personalities** - Switch to specialized agents
- **Multi-Agent Mode** - Chat with multiple agents simultaneously
- **Voice Input** - Use voice commands (tap mic icon)
- **History** - View past conversations

### Using Agents

1. **Switch Agent:** Tap the 🧠 icon in the chat header
2. **Select Category:** Choose from Engineering, Design, Marketing, etc.
3. **Pick Agent:** Select the specific agent you want
4. **Chat:** Your messages go to that agent

### Agent Categories

| Category | Count | Examples |
|----------|-------|----------|
| Engineering | 8 | Frontend Developer, Backend Architect, AI Engineer |
| Design | 7 | UI Designer, UX Researcher, Brand Guardian |
| Marketing | 11 | Growth Hacker, Twitter Engager, TikTok Strategist |
| Product | 3 | Sprint Prioritizer, Trend Researcher |
| Project Management | 5 | Studio Producer, Project Shepherd |
| Testing | 8 | Evidence Collector, Reality Checker |
| Support | 6 | Support Responder, Analytics Reporter |
| Spatial Computing | 6 | XR Architect, visionOS Engineer |
| Specialized | 7 | Agents Orchestrator, Data Analytics |

---

## Quick Actions

One-tap access to common commands across 5 categories:

### Categories

| Category | Actions |
|----------|---------|
| **GROW** | Status, Photo, Analyze, Alerts |
| **SYSTEM** | Backup, Restart, Update OpenClaw, Config |
| **WEATHER** | Current, Storm, Forecast |
| **AGENTS** | Chat, Research, Code |
| **TERMUX** | Console, Install OpenClaw, Setup Node |

### Quick Commands

Run common OpenClaw commands with one tap:
- `openclaw status` - Check gateway status
- `gateway restart` - Restart gateway
- `nodes status` - View node status
- `gateway start` - Start gateway
- `gateway stop` - Stop gateway

---

## Control Panel

Full control over your OpenClaw gateway.

### Features

| Action | Description |
|--------|-------------|
| **Restart Gateway** | Restart the OpenClaw service |
| **Stop Gateway** | Stop the gateway |
| **Kill Agent** | Terminate a specific agent |
| **Reconnect Node** | Force node reconnection |
| **Run Cron** | Manually trigger cron jobs |
| **Pause All** | Hold to pause all agents |

### Using Control

1. **Restart/Stop:** Tap the button, confirm in dialog
2. **Kill Agent:** Swipe agent row left, tap delete
3. **Reconnect:** Tap node, select "Reconnect"
4. **Pause All:** Long-press the pause button (hold for 3 seconds)

---

## Logs

Real-time log streaming with filtering.

### Features

- **Live Streaming** - Watch logs in real-time
- **Level Filters** - Filter by DEBUG, INFO, WARN, ERROR
- **Source Filters** - Filter by component
- **Search** - Search within logs
- **Export** - Save logs to file
- **Clear** - Clear log buffer

### Using Logs

1. **View Logs:** Logs stream automatically
2. **Filter:** Tap filter icon, select level(s)
3. **Search:** Use search bar
4. **Export:** Tap export icon

---

## Agent Monitor

Visualize and manage all active agents.

### Features

- **Live Visualization** - See agent states
- **Boss Chat** - Broadcast to all agents
- **Autowork** - Configure automatic agent behaviors
- **Office Preview** - Mini office with agent behavior states

### Boss Chat

Send messages to all agents at once:
1. Go to Boss tab
2. Type your message
3. Tap "Broadcast"
4. All agents receive and process

### Autowork

Configure automatic agent behaviors:
- Auto-reconnect failed agents
- Auto-restart on gateway crash
- Periodic status checks

---

## Automation

### Webhooks

Trigger actions via HTTP POST:
```bash
# Trigger action
curl -X POST http://phone-ip:8765/webhook/action/grow-status

# Send chat message
curl -X POST http://phone-ip:8765/webhook/chat/Hello
```

### Scheduled Tasks

Create recurring tasks:
- Run every X minutes/hours
- Daily at specific time
- Conditional triggers

### Workflows

Build automation workflows:
- Sequential actions
- Conditional logic
- Error handling

---

## Browser Control

BrowserOS MCP Integration - 53 browser automation tools.

### Features

- **Navigation** - Open URL, back, forward, refresh
- **Tabs** - New, close, switch tabs
- **Interaction** - Click, fill, hover, focus, scroll
- **Content** - Get text, screenshots, extract data
- **Workflows** - Visual workflow builder
- **Scheduled** - Schedule browser automations
- **LLM Hub** - Multi-model AI chat

### Categories

| Category | Tools |
|----------|-------|
| Navigation/Tabs | Open, Back, Forward, Refresh, New Tab, Close, Switch |
| Content/Observation | Get Content, Screenshot, Extract Data, Links, Images |
| Interaction/Input | Click, Fill Form, Hover, Focus, Press Key, Select |
| File/Export | Download, Export PDF, Save Screenshot, Upload |
| Window | Resize, Fullscreen, Minimize, Maximize |

### Workflows

Pre-built automation templates:
- Web Scraping
- Form Filling
- Screenshot Collection
- Data Extraction
- Social Media Automation
- News Aggregation

---

## Settings

### App Tab

| Setting | Description |
|---------|-------------|
| **App Mode** | Basic/Power User/Developer |
| **Notifications** | Enable push notifications |
| **Haptic Feedback** | Vibration on interactions |
| **Theme** | System/Light/Dark |
| **Auto-Refresh** | Dashboard refresh interval |
| **Debug Logging** | Developer mode only |

### Discover Tab

- Auto-scan for gateways
- Manual entry fallback

### Manual Tab

- IP/Hostname
- Port (default: 18789)
- Token
- Test & Save

### History Tab

- Recent connections
- Quick reconnect
- Remove history

### Tailscale Tab

- Detect Tailscale VPN
- Discover remote gateways
- Add custom tailnet URL

---

## Voice Commands

### Wake Words

- "OpenClaw"
- "Hey DuckBot"

### Example Commands

```
"Check gateway status"
"Send message hello to DuckBot"
"Restart the gateway"
"Show me the logs"
"Run grow status check"
"Take a plant photo"
"What's the weather"
"Go to dashboard"
"Open chat"
"Show settings"
```

### Features

- Real-time transcription
- TTS voice feedback
- Hands-free mode
- Offline recognition (on-device)

---

## Troubleshooting

### Can't Connect to Gateway

1. Check gateway is running: `openclaw status`
2. Verify firewall allows port 18789
3. Try manual entry with IP address
4. Check token is correct

### Voice Not Working

1. Grant microphone permission
2. Check internet connection
3. Try offline mode

### mDNS Not Finding Gateway

1. Ensure both devices on same network
2. Try manual entry
3. Check firewall allows mDNS (port 5353)

### App Crashes

1. Clear app cache
2. Reinstall APK
3. Check for updates

---

## Support

- **GitHub Issues:** https://github.com/Franzferdinan51/OpenClaw-Mobile-Control/issues
- **Discord:** https://discord.gg/clawd
- **Email:** duckbot@agentmail.to

---

**Built with ❤️ by DuckBot 🦆**