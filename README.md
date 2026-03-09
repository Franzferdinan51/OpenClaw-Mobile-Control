# OpenClaw Mobile App - Complete Specification

**Version:** 1.0.0  
**Created:** 2026-03-09  
**Status:** 🚀 Planning Phase  
**Platform:** Flutter (iOS + Android + Web PWA)

---

## 🚀 Quick Start

### Build the APK

```bash
cd /Users/duckets/Desktop/Android-App-DuckBot
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### Install on Phone

```bash
# Connect phone with USB debugging enabled
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Connect to Gateway

1. Open the app
2. The app auto-discovers your gateway on local network
3. Enter your gateway token (from `~/.openclaw/config`)
4. Start using the app!

**Find your token:**
```bash
cat ~/.openclaw/config | grep token
```

---

## ✨ Feature Highlights

| Feature | Description |
|---------|-------------|
| 📊 **Real-time Dashboard** | Live gateway, agent, and node status monitoring |
| 💬 **Direct Chat** | Chat with DuckBot directly - no Telegram needed |
| 🎮 **Remote Control** | Restart gateway, kill agents, manage nodes |
| ⚡ **Quick Actions** | One-tap grow status, photos, backups, weather |
| 📜 **Live Logs** | Stream gateway logs in real-time |
| 🔍 **Auto-Discovery** | Finds your gateway automatically on the network |
| 🔔 **Push Notifications** | Get alerts for critical events |
| 🌐 **Offline Support** | Works with cached data when offline |

---

## 📱 Feature Categories

### **1. Dashboard & Monitoring** ⭐⭐⭐⭐⭐
### **2. Direct Chat** ⭐⭐⭐⭐⭐
### **3. Remote Control** ⭐⭐⭐⭐⭐
### **4. Quick Actions** ⭐⭐⭐⭐⭐
### **5. Log Viewer** ⭐⭐⭐⭐
### **6. Guided Setup** ⭐⭐⭐⭐⭐
### **7. Auto-Discovery** ⭐⭐⭐⭐⭐
### **8. Settings & Configuration** ⭐⭐⭐

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     OpenClaw Mobile App                         │
│                        (Flutter)                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │ Dashboard   │ │    Chat     │ │   Control   │ │  Settings │ │
│  │   Screen    │ │   Screen    │ │   Screen    │ │  Screen   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    State Management (Riverpod)                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │  WebSocket  │ │   HTTP      │ │  Local DB   │ │  Services │ │
│  │  Client     │ │   Client    │ │  (Hive)     │ │ (Background)││
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Network Layer (mDNS + HTTP)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                   OpenClaw Gateway API                          │
│                   (Extended for Mobile)                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Feature Details

### **1. Dashboard & Monitoring**

#### **Main Dashboard Screen**
```
┌─────────────────────────────────────────┐
│  🦆 OpenClaw Status              ⚙️    │
├─────────────────────────────────────────┤
│                                         │
│  🟢 Gateway                             │
│     localhost:18789                     │
│     Uptime: 4d 12h 33m                  │
│     CPU: 23%  Memory: 1.2GB / 8GB      │
│                                         │
│  🟢 Agents (3 active)                   │
│     • DuckBot - Researching (12 min)    │
│     • Agent Smith - Idle                │
│     • Sub-agent #42 - Coding (3 min)    │
│                                         │
│  🟡 Nodes                               │
│     • Phone Node - Connected (ADB)      │
│     • Camera - Streaming                │
│     • Windows PC - Offline              │
│                                         │
│  📊 Usage (This Week)                   │
│     Qwen 3.5 Plus: 8.2K / 18K           │
│     MiniMax: ∞ (FREE)                   │
│     Kimi K2.5: ∞ (FREE)                 │
│     Codex: 45 / 200 msgs                │
│                                         │
│  ⚠️ Recent Alerts (2)                   │
│     • Grow temp high (2h ago)           │
│     • Phone node disconnected (5h ago)  │
│                                         │
├─────────────────────────────────────────┤
│  [Dashboard] [Chat] [Control] [Quick]   │
└─────────────────────────────────────────┘
```

#### **Real-Time Updates**
- WebSocket connection to gateway
- Live status changes (green/yellow/red)
- Push notifications for critical events
- Auto-refresh every 30 seconds

#### **Detailed Views**
- **Gateway Detail:** Process info, logs, config, restart button
- **Agent Detail:** Current task, model, session history, kill button
- **Node Detail:** Connection type, last seen, health metrics
- **Usage Detail:** Per-model breakdown, cost estimates, quota alerts

---

### **2. Direct Chat**

#### **Chat Interface**
```
┌─────────────────────────────────────────┐
│  💬 Chat with DuckBot            📞    │
├─────────────────────────────────────────┤
│                                         │
│  🤖 DuckBot (2:43 PM)                   │
│  Hey! What can I help you with?         │
│                                         │
│  👤 You (2:44 PM)                       │
│  Check the grow status                  │
│                                         │
│  🤖 DuckBot (2:44 PM)                   │
│  🌿 Grow Status Check                   │
│  Temp: 74.6°F | Humidity: 50.5%        │
│  VPD: 1.45 kPa - All optimal! ✅        │
│                                         │
│  [📊 View Full Report]                  │
│                                         │
├─────────────────────────────────────────┤
│  📎 [📷] [📁]                    [🎤] ➤ │
│  Type a message...                      │
│                                         │
└─────────────────────────────────────────┘
```

#### **Features**
- **Direct WebSocket** to OpenClaw Gateway (no Telegram)
- **Voice Input** (speech-to-text)
- **Photo Upload** (snap → send → analyze)
- **File Attachments** (logs, configs, etc.)
- **Message History** (local + cloud sync)
- **Multi-Agent Switch** (talk to different agents)
- **Typing Indicators** (see when agent is thinking)
- **Read Receipts** (message delivered/processed)
- **Quick Replies** (suggested actions)
- **Code Blocks** (syntax highlighting)
- **Markdown Support** (tables, lists, bold, etc.)

#### **Voice Commands**
```
"Check the grow" → Trigger grow-status-check.sh
"Storm watch" → Run storm-watch.sh
"Backup now" → Execute brain-backup.sh
"Restart gateway" → Confirm → Restart
"Who's online?" → Show agent/node status
"Research X" → Spawn research sub-agent
```

---

### **3. Remote Control**

#### **Control Panel**
```
┌─────────────────────────────────────────┐
│  🎮 Remote Control                      │
├─────────────────────────────────────────┤
│                                         │
│  GATEWAY                                │
│  ┌─────────────────────────────────┐   │
│  │ 🟢 Running (PID: 12345)         │   │
│  │ [Restart] [Stop] [View Logs]    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  AGENTS                                 │
│  ┌─────────────────────────────────┐   │
│  │ DuckBot                         │   │
│  │ 🟢 Active - Researching         │   │
│  │ [View Session] [Kill]           │   │
│  ├─────────────────────────────────┤   │
│  │ Sub-agent #42                   │   │
│  │ 🟡 Busy - Coding (3 min)        │   │
│  │ [View Session] [Kill]           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  NODES                                  │
│  ┌─────────────────────────────────┐   │
│  │ Phone Node (192.168.1.251)      │   │
│  │ 🟢 Connected via ADB            │   │
│  │ [Reconnect] [Status]            │   │
│  ├─────────────────────────────────┤   │
│  │ Camera (usb://0)                │   │
│  │ 🟢 Streaming                    │   │
│  │ [Restart Stream]                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  AUTOMATIONS                            │
│  ┌─────────────────────────────────┐   │
│  │ ⏰ Grow Monitor (hourly)        │   │
│  │ ✅ Enabled | Next: 23 min       │   │
│  │ [Disable] [Run Now]             │   │
│  ├─────────────────────────────────┤   │
│  │ ⏰ Storm Watch (4x daily)       │   │
│  │ ✅ Enabled | Next: 2h 15m       │   │
│  │ [Disable] [Run Now]             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ⚠️ EMERGENCY                           │
│  ┌─────────────────────────────────┐   │
│  │ 🔴 PAUSE ALL AUTOMATION         │   │
│  │ [Confirm: Hold 3 seconds]       │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

#### **Control Actions**
| Action | Confirmation | Effect |
|--------|--------------|--------|
| Restart Gateway | Yes (5s countdown) | Soft restart gateway process |
| Stop Gateway | Yes (warning) | Stop all automation |
| Kill Agent | Yes | Terminate specific agent |
| Reconnect Node | No | Attempt node reconnection |
| Run Cron Now | No | Trigger scheduled task immediately |
| Enable/Disable Cron | No | Toggle automation |
| Pause All | Yes (hold 3s) | Emergency stop all automation |
| Resume All | Yes | Resume after pause |

---

### **4. Quick Actions**

#### **Quick Actions Screen**
```
┌─────────────────────────────────────────┐
│  ⚡ Quick Actions                  ➕   │
├─────────────────────────────────────────┤
│                                         │
│  🌿 GROW                                │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │ 📊   │ │ 📸   │ │ 🧠   │ │ 🚨   │  │
│  │Status│ │Photo │ │Analyze│ │Alerts│  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
│                                         │
│  🛠️ SYSTEM                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │ 💾   │ │ 🔄   │ │ 📋   │ │ ⚙️   │  │
│  │Backup │ │Restart│ │KANBAN│ │Config│  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
│                                         │
│  🌤️ WEATHER                            │
│  ┌──────┐ ┌──────┐ ┌──────┐            │
│  │ 🌡️   │ │ ⛈️   │ │ 📅   │            │
│  │Current│ │Storm │ │Forecast│          │
│  └──────┘ └──────┘ └──────┘            │
│                                         │
│  🤖 AGENTS                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │ 💬   │ │ 🔬   │ │ 💻   │ │ 📝   │  │
│  │Chat  │ │Research│ │Code │ │Post  │  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
│                                         │
│  📱 SETUP                               │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │
│  │ 📥   │ │ 🔗   │ │ 🆕   │ │ ❓   │  │
│  │Install│ │Node  │ │Skill │ │Help  │  │
│  └──────┘ └──────┘ └──────┘ └──────┘  │
│                                         │
│  CUSTOM (Your Actions)                  │
│  ┌──────┐ ┌──────┐ ┌──────┐            │
│  │ ✏️   │ │ ✏️   │ │ ➕   │            │
│  │Custom│ │Custom│ │Add   │            │
│  └──────┘ └──────┘ └──────┘            │
│                                         │
└─────────────────────────────────────────┘
```

#### **Built-In Quick Actions**

**Grow Category:**
| Action | Command | Result |
|--------|---------|--------|
| 📊 Status | `./grow-status-check.sh` | Full environmental report |
| 📸 Photo | `./take-plant-photo.sh` | Capture + save plant photo |
| 🧠 Analyze | `./analyze-plant-health.py` | CannaAI analysis |
| 🚨 Alerts | `./grow-alerts.sh` | Check thresholds |
| 📈 Report | `./grow-daily-report.sh` | Generate daily summary |
| 🎬 Timelapse | `./create-grow-timelapse.sh` | Generate timelapse video |

**System Category:**
| Action | Command | Result |
|--------|---------|--------|
| 💾 Backup | `./brain-backup.sh` | Emergency brain backup |
| 🔄 Restart | `openclaw gateway restart` | Restart gateway |
| 📋 KANBAN | Read KANBAN.md | Show current tasks |
| ⚙️ Config | View config files | Gateway, agents, models |
| 📊 Usage | `openclaw session status` | Model usage report |
| 🔍 Health | `openclaw status` | Full system health |

**Weather Category:**
| Action | Command | Result |
|--------|---------|--------|
| 🌡️ Current | `./open-meteo-weather.sh` | Current conditions |
| ⛈️ Storm | `./storm-watch.sh` | Severe weather check |
| 📅 Forecast | `./open-meteo-weather.sh 7d` | 7-day forecast |

**Agents Category:**
| Action | Command | Result |
|--------|---------|--------|
| 💬 Chat | Spawn chat session | Direct conversation |
| 🔬 Research | `sessions_spawn research` | Research sub-agent |
| 💻 Code | `sessions_spawn coding` | Coding sub-agent |
| 📝 Post | Social media workflow | Draft + schedule post |

**Setup Category:**
| Action | Command | Result |
|--------|---------|--------|
| 📥 Install | OpenClaw installer | Install/upgrade OpenClaw |
| 🔗 Node | Node setup wizard | Connect new node |
| 🆕 Skill | `clawhub install` | Browse + install skills |
| ❓ Help | Documentation | Guides + troubleshooting |

#### **Custom Quick Actions**
Users can create custom actions:
```
Name: "Morning Brief"
Command: "./morning-brief.sh"
Icon: 🌅
Category: Custom
Confirmation: No
```

---

### **5. Log Viewer**

#### **Live Log Stream**
```
┌─────────────────────────────────────────┐
│  📜 Logs                    🔴 🔵 ⚪   │
├─────────────────────────────────────────┤
│  Filter: [All ▼]  Search: [______] 🔍 │
├─────────────────────────────────────────┤
│                                         │
│  14:32:45.123 [INFO] Gateway started    │
│  14:32:46.456 [INFO] WebSocket ready    │
│  14:33:01.789 [INFO] Heartbeat check OK │
│  14:33:15.234 [WARN] Node reconnecting  │
│  14:33:18.567 [INFO] Node connected     │
│  14:34:00.890 [INFO] Grow monitor run   │
│  14:34:02.123 [ERROR] AC Infinity timeout│
│  14:34:05.456 [INFO] Retry successful   │
│  14:35:00.789 [INFO] Sub-agent spawned  │
│  14:35:01.012 [INFO] Task: research X   │
│                                         │
│  [Auto-scroll: ON] [Pause] [Export]    │
│                                         │
└─────────────────────────────────────────┘
```

#### **Features**
- **Live Streaming** (WebSocket log tail)
- **Filter by Level** (INFO, WARN, ERROR, DEBUG)
- **Search** (text search across logs)
- **Color Coding** (green=info, yellow=warn, red=error)
- **Timestamp Toggle** (show/hide, 12h/24h format)
- **Auto-scroll** (follow new logs)
- **Pause/Resume** (freeze scroll for reading)
- **Export** (download as .txt or .json)
- **Session Logs** (view specific agent session logs)
- **Crash Reports** (view recent crashes with stack traces)

---

### **6. Guided Setup**

#### **First Launch Wizard**
```
┌─────────────────────────────────────────┐
│  🦆 Welcome to OpenClaw!                │
│                                         │
│  Let's get you set up in 5 minutes.    │
│                                         │
│  [Get Started]                          │
└─────────────────────────────────────────┘
```

#### **Step 1: Discovery**
```
┌─────────────────────────────────────────┐
│  🔍 Finding OpenClaw Installations...   │
│                                         │
│  Scanning local network (mDNS/Bonjour) │
│                                         │
│  ✅ Found: DuckBot-Gateway              │
│     192.168.1.101:18789                │
│     Status: Online                     │
│     Version: 1.2.3                     │
│                                         │
│  ⚪ Found: Agent-Smith-PC               │
│     192.168.1.102:18789                │
│     Status: Offline                    │
│                                         │
│  [Select DuckBot-Gateway]               │
│  [Manual Setup]                         │
│                                         │
└─────────────────────────────────────────┘
```

#### **Step 2: Authentication**
```
┌─────────────────────────────────────────┐
│  🔐 Authenticate                        │
│                                         │
│  Connect to DuckBot-Gateway?            │
│                                         │
│  Gateway Token:                         │
│  ┌─────────────────────────────────┐   │
│  │ ••••••••••••••••••••••••••••   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  (Find token in ~/.openclaw/config)    │
│                                         │
│  [Connect] [Skip for Now]               │
│                                         │
└─────────────────────────────────────────┘
```

#### **Step 3: Node Setup**
```
┌─────────────────────────────────────────┐
│  📱 Set Up Phone Node                   │
│                                         │
│  Enable ADB debugging on this device?   │
│                                         │
│  This app can:                          │
│  • Monitor sensors (light, temp, etc.) │
│  • Take scheduled photos                │
│  • Run local automations                │
│  • Act as OpenClaw node                 │
│                                         │
│  [Enable ADB] [Skip] [Learn More]       │
│                                         │
└─────────────────────────────────────────┘
```

#### **Step 4: Skill Installation**
```
┌─────────────────────────────────────────┐
│  🧩 Install Recommended Skills          │
│                                         │
│  ☑️ Weather (storm watch, forecasts)   │
│  ☑️ Grow Monitoring (AC Infinity)      │
│  ☑️ Brain Backup (auto backups)        │
│  ☐ Social Media (posting automation)   │
│  ☐ GitHub Integration (issues/PRs)     │
│  ☐ Email (AgentMail integration)       │
│                                         │
│  [Install Selected] [Skip]              │
│                                         │
└─────────────────────────────────────────┘
```

#### **Step 5: Notifications**
```
┌─────────────────────────────────────────┐
│  🔔 Notification Preferences            │
│                                         │
│  Enable push notifications for:         │
│                                         │
│  ☑️ Critical Alerts (gateway down)     │
│  ☑️ Grow Alerts (temp/humidity)        │
│  ☑️ Weather Alerts (storms)            │
│  ☐ Agent Updates (task complete)       │
│  ☐ Daily Digest (morning brief)        │
│                                         │
│  [Enable] [Skip]                        │
│                                         │
└─────────────────────────────────────────┘
```

#### **Step 6: Complete!**
```
┌─────────────────────────────────────────┐
│  🎉 Setup Complete!                     │
│                                         │
│  You're ready to use OpenClaw.          │
│                                         │
│  Gateway: 🟢 Connected                  │
│  Node: 🟢 Active                        │
│  Skills: 3 installed                    │
│                                         │
│  [Go to Dashboard] [Tour]               │
│                                         │
└─────────────────────────────────────────┘
```

---

### **7. Auto-Discovery**

#### **Discovery Methods**

**1. mDNS/Bonjour (Primary)**
```
Service: _openclaw._tcp.local.
Port: 18789
TXT Records:
  - version=1.2.3
  - hostname=DuckBot-Gateway
  - token_required=true
```

**2. Local Network Scan**
```
Scan range: 192.168.1.1-254
Port: 18789
Timeout: 2 seconds per IP
Parallel: 50 concurrent scans
```

**3. Manual Entry**
```
IP/Hostname: ________________
Port: 18789
Token: _____________________
[Connect]
```

**4. Cloud Registry (Optional)**
```
Register gateway with cloud.openclaw.ai
Discover via account login
Sync across devices
```

#### **Discovery Screen**
```
┌─────────────────────────────────────────┐
│  🔗 Connections                   ➕   │
├─────────────────────────────────────────┤
│                                         │
│  LOCAL NETWORK                          │
│  ┌─────────────────────────────────┐   │
│  │ 🟢 DuckBot-Gateway              │   │
│  │    192.168.1.101:18789          │   │
│  │    v1.2.3 • Connected           │   │
│  │    [Disconnect] [Configure]     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  SAVED                                  │
│  ┌─────────────────────────────────┐   │
│  │ ⚪ Agent-Smith-PC               │   │
│  │    192.168.1.102:18789          │   │
│  │    v1.2.1 • Offline             │   │
│  │    [Connect] [Remove]           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ADD NEW                                │
│  [Scan Network] [Manual Entry]         │
│                                         │
└─────────────────────────────────────────┘
```

---

### **8. Settings & Configuration**

#### **Settings Screen**
```
┌─────────────────────────────────────────┐
│  ⚙️ Settings                            │
├─────────────────────────────────────────┤
│                                         │
│  ACCOUNT                                │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Profile                      │   │
│  │ 📱 Connected Devices            │   │
│  │ 🔐 Security                     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  APP                                    │
│  ┌─────────────────────────────────┐   │
│  │ 🎨 Theme (Dark/Light/Auto)      │   │
│  │ 🔔 Notifications                │   │
│  │ 🌐 Language                     │   │
│  │ 📊 Data Usage                   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  GATEWAY                                │
│  ┌─────────────────────────────────┐   │
│  │ 📝 Gateway Config               │   │
│  │ 🤖 Agent Settings               │   │
│  │ 📡 Model Configuration          │   │
│  │ ⏰ Cron Schedule                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ADVANCED                               │
│  ┌─────────────────────────────────┐   │
│  │ 📜 Logs                         │   │
│  │ 🐛 Debug Mode                   │   │
│  │ 📤 Export Data                  │   │
│  │ 🗑️ Clear Cache                 │   │
│  │ ℹ️ About                        │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🛠️ Technical Stack

### **Frontend (Mobile App)**
| Component | Technology | Why |
|-----------|------------|-----|
| Framework | Flutter 3.x | Cross-platform (iOS/Android/Web) |
| State | Riverpod | Reactive, testable, scalable |
| Navigation | GoRouter | Deep linking, web URLs |
| UI Components | Material 3 | Modern, customizable |
| Local DB | Hive | Fast, lightweight, Flutter-native |
| HTTP | Dio | Interceptors, error handling |
| WebSocket | web_socket_channel | Real-time updates |
| Voice | speech_to_text | Native speech recognition |
| Camera | camera + image_picker | Photo capture + upload |

### **Backend (Gateway Extensions)**
| Component | Technology | Why |
|-----------|------------|-----|
| API | Express.js (existing) | Extend current gateway |
| WebSocket | ws (existing) | Real-time bidirectional |
| mDNS | mdns | Auto-discovery |
| Auth | JWT | Secure token-based |
| Rate Limit | express-rate-limit | Prevent abuse |
| Logging | winston (existing) | Structured logs |

### **Infrastructure**
| Component | Technology | Why |
|-----------|------------|-----|
| Push Notifications | Firebase (FCM) | Cross-platform push |
| Cloud Sync (Optional) | Supabase | Free tier, real-time |
| Analytics (Optional) | PostHog | Self-hosted, privacy-focused |
| Crash Reporting | Sentry | Error tracking |

---

## 📁 Project Structure

```
openclaw-mobile/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── routes.dart
│   │   ├── themes.dart
│   │   └── constants.dart
│   ├── models/
│   │   ├── gateway.dart
│   │   ├── agent.dart
│   │   ├── node.dart
│   │   ├── session.dart
│   │   └── log_entry.dart
│   ├── services/
│   │   ├── gateway_service.dart
│   │   ├── websocket_service.dart
│   │   ├── discovery_service.dart
│   │   ├── auth_service.dart
│   │   ├── notification_service.dart
│   │   └── storage_service.dart
│   ├── providers/
│   │   ├── gateway_provider.dart
│   │   ├── agents_provider.dart
│   │   ├── nodes_provider.dart
│   │   └── logs_provider.dart
│   ├── screens/
│   │   ├── onboarding/
│   │   │   ├── welcome_screen.dart
│   │   │   ├── discovery_screen.dart
│   │   │   ├── auth_screen.dart
│   │   │   └── complete_screen.dart
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── gateway_detail.dart
│   │   │   ├── agent_detail.dart
│   │   │   └── node_detail.dart
│   │   ├── chat/
│   │   │   ├── chat_screen.dart
│   │   │   ├── chat_message.dart
│   │   │   └── chat_input.dart
│   │   ├── control/
│   │   │   ├── control_screen.dart
│   │   │   ├── gateway_control.dart
│   │   │   └── agent_control.dart
│   │   ├── quick_actions/
│   │   │   ├── quick_actions_screen.dart
│   │   │   ├── action_button.dart
│   │   │   └── custom_action_editor.dart
│   │   ├── logs/
│   │   │   ├── logs_screen.dart
│   │   │   └── log_detail.dart
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── config_editor.dart
│   └── widgets/
│       ├── status_indicator.dart
│       ├── agent_card.dart
│       ├── node_card.dart
│       ├── usage_chart.dart
│       └── log_viewer.dart
├── android/
│   ├── app/
│   │   ├── src/main/AndroidManifest.xml
│   │   └── build.gradle
│   └── gradle/
├── ios/
│   ├── Runner/
│   │   ├── AppDelegate.swift
│   │   └── Info.plist
│   └── Podfile
├── web/
│   ├── index.html
│   └── manifest.json
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── pubspec.yaml
├── README.md
└── analysis_options.yaml
```

---

## 🗓️ Development Roadmap

### **Phase 1: Foundation (Week 1-2)**
- [ ] Set up Flutter project
- [ ] Configure CI/CD (GitHub Actions)
- [ ] Implement gateway API extensions
- [ ] WebSocket service
- [ ] Basic dashboard (static data)
- [ ] Discovery service (mDNS)

### **Phase 2: Core Features (Week 3-4)**
- [ ] Live dashboard (WebSocket updates)
- [ ] Chat interface (direct to gateway)
- [ ] Remote control panel
- [ ] Quick actions (built-in)
- [ ] Settings screen

### **Phase 3: Advanced Features (Week 5-6)**
- [ ] Log viewer (live stream)
- [ ] Guided setup wizard
- [ ] Auto-discovery UI
- [ ] Push notifications (FCM)
- [ ] Voice commands

### **Phase 4: Polish (Week 7-8)**
- [ ] Custom quick actions
- [ ] Theme support (dark/light)
- [ ] Offline mode (cached data)
- [ ] Performance optimization
- [ ] Testing (unit, widget, integration)
- [ ] Documentation

### **Phase 5: Launch (Week 9)**
- [ ] Beta testing
- [ ] Bug fixes
- [ ] App Store submission (iOS)
- [ ] Play Store submission (Android)
- [ ] Web deployment (PWA)

---

## 🔐 Security Considerations

### **Authentication**
- Gateway token required for all connections
- Token stored in secure enclave (iOS) / Keystore (Android)
- JWT tokens for session management
- Auto-logout after 30 days inactivity

### **Encryption**
- TLS 1.3 for all network communication
- End-to-end encryption for chat messages
- Encrypted local storage (Hive with AES-256)

### **Permissions**
- Minimum required permissions
- Runtime permission requests with explanations
- No unnecessary data collection

### **Network**
- Local network only (no cloud required)
- Optional cloud sync (user-enabled)
- Firewall-friendly (single port 18789)

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| App Launch Time | < 2 seconds |
| WebSocket Connect | < 500ms |
| Message Delivery | < 1 second |
| Battery Impact | < 5% per day |
| Crash Rate | < 0.1% |
| User Rating | 4.5+ stars |

---

## 🚀 Next Steps

1. **Approve spec** (this document)
2. **Set up repo** (GitHub, Flutter project)
3. **Extend gateway API** (mobile endpoints)
4. **Build MVP** (dashboard + chat + control)
5. **Test internally** (Duckets + team)
6. **Beta release** (TestFlight + Play Beta)
7. **Public launch** (App Store + Play Store)

---

**Ready to build?** 🦆
