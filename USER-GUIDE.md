# OpenClaw Mobile App - User Guide

**Version:** 1.0.0  
**Purpose:** Complete guide to using the OpenClaw Mobile App

---

## Quick Start

1. **Install the app** - See [INSTALL-GUIDE.md](./INSTALL-GUIDE.md)
2. **Connect to gateway** - Enter your OpenClaw gateway URL and token
3. **Start monitoring** - View dashboard, chat with agents, control your setup

---

## First-Time Setup: Guided Wizard

The app includes a step-by-step setup wizard to get you connected quickly.

### Step 1: Welcome Screen
```
┌─────────────────────────────────────────┐
│  🦆 Welcome to OpenClaw!                │
│                                         │
│  Let's get you set up in 5 minutes.    │
│                                         │
│  [Get Started]                          │
└─────────────────────────────────────────┘
```

### Step 2: Auto-Discovery
The app automatically scans your local network for OpenClaw gateways.

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
│  [Select DuckBot-Gateway]               │
│  [Manual Setup]                         │
│                                         │
└─────────────────────────────────────────┘
```

### Step 3: Authentication
```
┌─────────────────────────────────────────┐
│  🔐 Authenticate                        │
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

**Find your token:**
```bash
# On your gateway machine
cat ~/.openclaw/config | grep token
```

### Step 4: Node Setup (Optional)
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

### Step 5: Skills Installation
```
┌─────────────────────────────────────────┐
│  🧩 Install Recommended Skills          │
│                                         │
│  ☑️ Weather (storm watch, forecasts)   │
│  ☑️ Grow Monitoring (AC Infinity)        │
│  ☑️ Brain Backup (auto backups)         │
│  ☐ Social Media (posting automation)   │
│                                         │
│  [Install Selected] [Skip]              │
│                                         │
└─────────────────────────────────────────┘
```

### Step 6: Notifications
```
┌─────────────────────────────────────────┐
│  🔔 Notification Preferences            │
│                                         │
│  ☑️ Critical Alerts (gateway down)     │
│  ☑️ Grow Alerts (temp/humidity)         │
│  ☐ Weather Alerts (storms)             │
│  ☐ Agent Updates (task complete)       │
│                                         │
│  [Enable] [Skip]                        │
│                                         │
└─────────────────────────────────────────┘
```

### Step 7: Complete!
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

## Auto-Discovery Feature

The app can automatically find your OpenClaw gateway on the network.

### Discovery Methods

| Method | Description | Status |
|--------|-------------|--------|
| **mDNS/Bonjour** | Primary - broadcasts on local network | ✅ Default |
| **Network Scan** | Fallback - scans IP range | ✅ If mDNS fails |
| **Manual Entry** | Enter IP/hostname directly | ✅ Available |

### Manual Discovery

If auto-discovery fails:

```
Settings → Gateway → Manual Setup

Gateway URL: http://192.168.1.101:18789
Gateway Token: [enter-token]
```

### Troubleshooting Discovery

| Issue | Solution |
|-------|----------|
| Gateway not found | Ensure phone and gateway on same network |
| mDNS fails | Check router supports multicast |
| Connection refused | Verify gateway is running |

---

## Install OpenClaw from App

You can install or update OpenClaw directly from the mobile app.

### In-App Installation

1. **Quick Actions → Setup → Install OpenClaw**
2. The app will guide you through installation
3. For Termux: Opens Termux and runs install commands

### Termux Installation (via App)

If using your phone as a gateway:

```
Quick Actions → Setup → Install Termux
```

This will:
- Download and install Termux from F-Droid
- Guide you through initial setup
- Install required packages
- Clone and configure OpenClaw

---

## App Navigation

The app uses a bottom navigation bar with 4 main tabs:

| Tab | Icon | Purpose |
|-----|------|---------|
| **Dashboard** | 📊 | Monitor gateway, agents, nodes status |
| **Chat** | 💬 | Direct conversation with DuckBot |
| **Control** | 🎮 | Remote control of gateway and agents |
| **Quick Actions** | ⚡ | One-tap execution of common tasks |

---

## Dashboard Screen

The Dashboard provides a real-time overview of your entire OpenClaw deployment.

### Main Components

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
│                                         │
│  📊 Usage (This Week)                   │
│     Qwen 3.5 Plus: 8.2K / 18K           │
│     MiniMax: ∞ (FREE)                   │
│                                         │
│  ⚠️ Recent Alerts (2)                   │
│     • Grow temp high (2h ago)           │
│     • Phone node disconnected (5h ago)  │
│                                         │
└─────────────────────────────────────────┘
```

### Status Indicators

| Indicator | Color | Meaning |
|-----------|-------|---------|
| 🟢 Online/Active | Green | Fully operational |
| 🟡 Warning/Busy | Yellow | Needs attention |
| 🔴 Offline/Error | Red | Critical issue |
| ⚪ Unknown | Gray | Status unknown |

### Tap Actions

- **Gateway card** → View detailed gateway info, logs, restart option
- **Agent card** → View session details, kill agent
- **Node card** → View node details, reconnect
- **Alerts** → View all alerts, acknowledge

---

## Chat Screen

Directly chat with DuckBot (or any configured agent) without Telegram.

### Interface

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
├─────────────────────────────────────────┤
│  📎 [📷] [📁]                    [🎤] ➤ │
│  Type a message...                      │
│                                         │
└─────────────────────────────────────────┘
```

### Features

| Feature | How to Use |
|---------|------------|
| **Send message** | Type in text box, tap send button |
| **Voice input** | Tap microphone icon, speak |
| **Send photo** | Tap camera icon, take or select photo |
| **Attach file** | Tap file icon, select document |
| **Quick replies** | Tap suggested action buttons |

### Voice Commands

Speak these commands for quick actions:

| Command | Action |
|---------|--------|
| "Check the grow" | Run grow status check |
| "Storm watch" | Run storm watch script |
| "Backup now" | Execute brain backup |
| "Restart gateway" | Confirm and restart |
| "Who's online?" | Show agent/node status |

---

## Control Screen

Full remote control of your OpenClaw deployment.

### Sections

#### Gateway Control
```
┌─────────────────────────────────────────┐
│  GATEWAY                                │
│  ┌─────────────────────────────────┐   │
│  │ 🟢 Running (PID: 12345)         │   │
│  │ [Restart] [Stop] [View Logs]    │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Agent Control
```
┌─────────────────────────────────────────┐
│  AGENTS                                 │
│  ┌─────────────────────────────────┐   │
│  │ DuckBot 🟢 Active - Researching │   │
│  │ [View Session] [Kill]           │   │
│  ├─────────────────────────────────┤   │
│  │ Sub-agent #42 🟡 Busy - Coding  │   │
│  │ [View Session] [Kill]           │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Node Control
```
┌─────────────────────────────────────────┐
│  NODES                                  │
│  ┌─────────────────────────────────┐   │
│  │ Phone Node (192.168.1.251)      │   │
│  │ 🟢 Connected via ADB            │   │
│  │ [Reconnect] [Status]           │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Cron Jobs
```
┌─────────────────────────────────────────┐
│  AUTOMATIONS                            │
│  ┌─────────────────────────────────┐   │
│  │ ⏰ Grow Monitor (hourly)        │   │
│  │ ✅ Enabled | Next: 23 min       │   │
│  │ [Disable] [Run Now]            │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Control Actions

| Action | Confirmation | Effect |
|--------|--------------|--------|
| Restart Gateway | Yes (5s countdown) | Restarts gateway process |
| Stop Gateway | Yes (warning) | Stops all automation |
| Kill Agent | Yes | Terminates agent |
| Reconnect Node | No | Attempts reconnection |
| Run Cron Now | No | Triggers task immediately |
| Enable/Disable Cron | No | Toggles automation |
| Pause All | Yes (hold 3s) | Emergency stop all |

---

## Quick Actions Screen

One-tap access to frequently used commands.

### Categories

#### 🌿 Grow Actions
| Action | Command | Description |
|--------|---------|-------------|
| 📊 Status | `./grow-status-check.sh` | Full environmental report |
| 📸 Photo | `./take-plant-photo.sh` | Capture plant photo |
| 🧠 Analyze | `./analyze-plant-health.py` | AI plant analysis |
| 🚨 Alerts | `./grow-alerts.sh` | Check threshold alerts |

#### 🛠️ System Actions
| Action | Command | Description |
|--------|---------|-------------|
| 💾 Backup | `./brain-backup.sh` | Emergency brain backup |
| 🔄 Restart | `openclaw gateway restart` | Restart gateway |
| 📋 KANBAN | Read KANBAN.md | View current tasks |
| ⚙️ Config | View config files | Gateway, agents, models |

#### 🌤️ Weather Actions
| Action | Command | Description |
|--------|---------|-------------|
| 🌡️ Current | `./open-meteo-weather.sh` | Current conditions |
| ⛈️ Storm | `./storm-watch.sh` | Severe weather check |
| 📅 Forecast | `./open-meteo-weather.sh 7d` | 7-day forecast |

#### 🤖 Agent Actions
| Action | Description |
|--------|-------------|
| 💬 Chat | Open chat with DuckBot |
| 🔬 Research | Spawn research sub-agent |
| 💻 Code | Spawn coding sub-agent |

### Running Quick Actions

1. **Tap action button** - Executes immediately (no confirmation)
2. **Long-press** - Shows confirmation dialog
3. **Results** - Displayed in app, also sent via notification

---

## Settings

Configure app behavior and gateway connection.

### Settings Categories

| Category | Options |
|----------|---------|
| **Theme** | Dark / Light / System |
| **Notifications** | Critical / Grow / Weather / Agent / Daily digest |
| **Language** | English (default) |
| **Data Usage** | Cache settings, auto-refresh interval |
| **Gateway Config** | URL, token, timeout |
| **Advanced** | Logs, debug mode, export data |

### Gateway Connection

```
Gateway URL: http://192.168.1.101:18789
Gateway Token: [Enter your token from ~/.openclaw/config]
```

Find your token:
```bash
cat ~/.openclaw/config | grep token
```

---

## First-Time Setup

When you first launch the app:

### Step 1: Discovery
The app scans your local network for OpenClaw gateways via mDNS/Bonjour.

### Step 2: Authentication
Enter your gateway token to authenticate.

### Step 3: Phone Node (Optional)
Enable ADB debugging to use your phone as an OpenClaw node.

### Step 4: Skills
Install recommended skills (Weather, Grow Monitoring, etc.)

### Step 5: Notifications
Choose which alerts you want to receive.

---

## Offline Mode

The app works offline with cached data:

- **Cached dashboard** - Last known status
- **Cached chat history** - Previous messages
- **Queued messages** - Sent when reconnected

---

## Auto-Discovery

The app automatically finds OpenClaw gateways on your network:

1. **mDNS/Bonjour** - Primary discovery method
2. **Local network scan** - Fallback if mDNS fails
3. **Manual entry** - Enter IP/hostname directly

---

## Notifications

Configure which events trigger push notifications:

| Notification Type | Trigger |
|-------------------|---------|
| **Critical** | Gateway down, critical errors |
| **Grow Alerts** | Temperature, humidity thresholds |
| **Weather** | Storm warnings |
| **Agent** | Task completion, agent status changes |
| **Daily Digest** | Morning summary (optional) |

---

## Termux Command Execution

The app can execute commands directly in Termux on your Android device.

### Supported Commands

Run commands directly from the app:

| Command Type | Example | Description |
|--------------|---------|-------------|
| **Package Management** | `pkg install git` | Install packages |
| **File Operations** | `ls -la` | List files |
| **System Info** | `uname -a` | System information |
| **Process Management** | `ps` | Running processes |
| **Network** | `ip addr` | Network configuration |
| **OpenClaw** | `openclaw gateway status` | Gateway commands |

### Executing Commands

1. **Quick Actions → System → Terminal**
2. **Type command** in input field
3. **Results** displayed in output area

### OpenClaw via Termux

The app can control OpenClaw running in Termux:

```bash
# Check status
openclaw gateway status

# Start gateway
openclaw gateway start

# Stop gateway
openclaw gateway stop

# View logs
openclaw logs

# Install skills
clawhub install weather
```

### Termux API Integration

The app can access Termux APIs for enhanced functionality:

| API | Permission | Use Case |
|-----|------------|----------|
| `termux-camera-photo` | Camera | Capture photos |
| `termux-location` | Location | GPS coordinates |
| `termux-sms-send` | SMS | Send text messages |
| `termux-notification` | Notifications | Push notifications |
| `termux-vibrate` | Vibration | Haptic feedback |
| `termux-tts` | TTS | Text-to-speech |

---

## ADB Commands Available

The app can execute ADB commands when connected to your phone.

### Basic ADB Commands

| Command | Description |
|---------|-------------|
| `adb devices` | List connected devices |
| `adb shell` | Open shell on device |
| `adb pull` | Copy file from device |
| `adb push` | Copy file to device |
| `adb install` | Install APK |
| `adb uninstall` | Remove app |
| `adb reboot` | Reboot device |
| `adb logcat` | View log output |

### Using ADB in App

1. **Control → Nodes → Phone Node**
2. **Execute command** via terminal
3. **View results** in output

### ADB Wireless Setup

If running OpenClaw on a separate machine:

```bash
# From phone (with Termux or ADB app)
adb pair 192.168.1.x:5555

# From computer
adb connect 192.168.1.x:5555

# Now use all ADB commands remotely
adb -s 192.168.1.x:5555 shell
```

### Node as ADB Target

Your phone can be an OpenClaw node via ADB:

- **Screen capture** - Automated screenshots
- **Shell execution** - Run scripts on phone
- **File transfer** - Move files to/from phone
- **App control** - Install/uninstall apps

---

## Tips & Tricks

### Efficient Usage
- **Swipe down** on dashboard to refresh
- **Tap status indicators** for detailed info
- **Long-press** actions for confirmation
- **Use Quick Actions** for frequently used commands

### Keyboard Shortcuts (External Keyboard)
- `Cmd+K` - Open chat
- `Cmd+D` - Go to dashboard
- `Cmd+,` - Settings

### Voice Commands
- Speak naturally - the app understands context
- Works best in quiet environments
- Check "Voice Commands" in settings for full list

---

## Security

- **Token stored securely** - In platform-specific secure storage
- **TLS encryption** - All network traffic encrypted
- **Local-only mode** - No cloud dependency
- **Auto-logout** - After 30 days of inactivity

---

## Need Help?

- **Troubleshooting** → See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- **API Testing** → See [API-TESTING.md](./API-TESTING.md)
- **Deployment** → See [DEPLOYMENT.md](./DEPLOYMENT.md)