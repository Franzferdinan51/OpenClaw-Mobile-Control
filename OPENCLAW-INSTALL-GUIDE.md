# OpenClaw Installation Guide

**Version:** 1.0.0  
**Platform:** Android (Termux), Linux, macOS, Windows  
**Purpose:** Complete guide for installing and configuring OpenClaw

---

## Overview

OpenClaw is an AI agent platform that can run as a gateway, node, or both. This guide covers installation on Android via Termux and standard platforms.

---

## Installation Methods

### Method 1: Automated Install (Recommended for Desktop)

```bash
# One-line install script
curl -sL https://get.openclaw.dev | bash

# Or with specific version
curl -sL https://get.openclaw.dev | bash -s v1.2.0
```

### Method 2: npm Package (Cross-Platform)

```bash
# Install globally via npm
npm install -g openclaw

# Verify installation
openclaw --version

# Show help
openclaw --help
```

### Method 3: Manual Install via Termux (Android)

See [TERMUX-SETUP.md](./TERMUX-SETUP.md) for full Termux setup, then:

```bash
# Update packages
pkg update && pkg upgrade

# Install dependencies
pkg install python nodejs git openssh

# Install OpenClaw
npm install -g openclaw

# Verify
openclaw --version
```

---

## Gateway Configuration

### Starting the Gateway

```bash
# Start gateway with default settings
openclaw gateway start

# Start on custom port
openclaw gateway start --port 18789

# Start with specific network interface
openclaw gateway start --host 0.0.0.0 --port 18789
```

### Gateway Configuration File

Create `~/.openclaw/config.json`:

```json
{
  "gateway": {
    "port": 18789,
    "host": "0.0.0.0",
    "auth": {
      "enabled": true,
      "token": "your-secure-token-here"
    }
  },
  "node": {
    "autoRegister": true,
    "heartbeatInterval": 30000
  }
}
```

### Gateway API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Gateway health check |
| `/agents` | GET | List active agents |
| `/agents/spawn` | POST | Spawn new agent |
| `/nodes` | GET | List connected nodes |
| `/nodes/register` | POST | Register new node |
| `/ws` | WS | WebSocket for real-time comms |

---

## Node Setup

### Connecting as a Node

```bash
# Start node with default gateway
openclaw node start

# Connect to specific gateway
openclaw node start --gateway http://192.168.1.100:18789

# With authentication token
openclaw node start --gateway http://192.168.1.100:18789 --token your-token
```

### Node Configuration

```json
{
  "node": {
    "id": "my-android-node",
    "name": "Android Device",
    "gateway": "http://192.168.1.100:18789",
    "token": "your-gateway-token"
  },
  "capabilities": {
    "android": true,
    "adb": true,
    "vision": false,
    "tts": false
  }
}
```

### Auto-Discovery

OpenClaw nodes can auto-discover the gateway on your local network:

```bash
# Enable auto-discovery
openclaw node start --auto-discover

# The node will:
# 1. Broadcast presence on port 18790
# 2. Listen for gateway announcements
# 3. Connect automatically when gateway found
```

---

## First-Time Wizard

### Running the Wizard

```bash
# Launch interactive setup wizard
openclaw setup

# Or run specific wizard steps
openclaw setup gateway    # Configure gateway
openclaw setup node       # Configure node
openclaw setup skills     # Install skills
```

### Wizard Steps

1. **Choose Role**:
   - Gateway only
   - Node only
   - Gateway + Node (combined)

2. **Configure Network**:
   - Set host/IP
   - Set port (default: 18789)
   - Enable/disable authentication

3. **Register Node** (if applicable):
   - Enter gateway URL
   - Enter node name
   - Generate/enter token

4. **Install Skills**:
   - Select skills to install
   - Configure skill permissions

---

## Verifying Installation

### Check Gateway Status

```bash
# Check if gateway is running
openclaw gateway status

# Or via HTTP
curl http://localhost:18789/health
```

### Check Node Status

```bash
# Check node connection
openclaw node status

# List connected nodes (from gateway)
openclaw gateway nodes
```

### Test Agent Spawn

```bash
# Spawn a test agent
openclaw agents spawn --model openai/gpt-4 --task "Hello, world!"
```

---

## Platform-Specific Notes

### Android (Termux)

- Run `termux-setup-storage` for file access
- SSH on port 8022
- Use `termux-wake-lock` to prevent sleep
- Consider using Termux:Widget for quick actions

### Linux (Desktop/Server)

- Works best on Ubuntu/Debian
- Install via apt: `apt install openclaw`
- Or use npm: `npm install -g openclaw`

### macOS

- Install via Homebrew: `brew install openclaw`
- Or use npm: `npm install -g openclaw`

### Windows

- Install via Chocolatey: `choco install openclaw`
- Or use npm: `npm install -g openclaw`
- Requires PowerShell or WSL for best experience

---

## Updating OpenClaw

```bash
# Check for updates
openclaw update check

# Update to latest version
openclaw update install

# Update specific version
openclaw update install v1.2.0
```

---

## Uninstalling

```bash
# Remove npm package
npm uninstall -g openclaw

# Remove configuration (optional)
rm -rf ~/.openclaw
```

---

## Troubleshooting

### Gateway Won't Start

```bash
# Check port availability
lsof -i :18789

# Kill process on port
fuser -k 18789/tcp

# Check logs
openclaw logs --gateway
```

### Node Can't Connect

```bash
# Verify gateway is running
curl http://<gateway-ip>:18789/health

# Check network connectivity
ping <gateway-ip>

# Verify firewall settings
# Ensure 18789 is open on gateway
```

### Permission Errors

```bash
# Fix npm permissions (Linux/macOS)
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
# Add to ~/.bashrc or ~/.zshrc:
# export PATH=~/.npm-global/bin:$PATH
```

---

## Next Steps

- **[TERMUX-SETUP.md](./TERMUX-SETUP.md)** - Termux installation for Android
- **[COMMANDS-REFERENCE.md](./COMMANDS-REFERENCE.md)** - CLI command reference
- **[INSTALL-GUIDE.md](./INSTALL-GUIDE.md)** - Flutter mobile app installation

---

## Additional Resources

- **Official Docs:** https://docs.openclaw.dev
- **GitHub:** https://github.com/Franzferdinan51/openclaw
- **Discord:** https://discord.gg/openclaw
- **Issues:** https://github.com/Franzferdinan51/openclaw/issues

---

**Need help?** See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)