# Commands Reference Guide

**Version:** 1.0.0  
**Platforms:** Termux (Android), macOS, Linux, Windows  
**Purpose:** Quick reference for all available commands

---

## Table of Contents

1. [Termux Commands](#termux-commands)
2. [ADB Commands](#adb-commands)
3. [OpenClaw CLI Reference](#openclaw-cli-reference)
4. [Quick Actions](#quick-actions)

---

## Termux Commands

### Package Management

| Command | Description |
|---------|-------------|
| `pkg update` | Update package lists |
| `pkg upgrade` | Upgrade all packages |
| `pkg install <package>` | Install a package |
| `pkg uninstall <package>` | Remove a package |
| `pkg list-installed` | List installed packages |
| `pkg search <term>` | Search for packages |
| `apt update` | Alternative: update via apt |
| `apt upgrade` | Alternative: upgrade via apt |

### File & Directory Operations

| Command | Description |
|---------|-------------|
| `ls` | List directory contents |
| `ls -la` | List with hidden files |
| `cd <dir>` | Change directory |
| `pwd` | Print working directory |
| `mkdir <dir>` | Create directory |
| `rm <file>` | Remove file |
| `rm -r <dir>` | Remove directory recursively |
| `cp <src> <dest>` | Copy file |
| `mv <src> <dest>` | Move/rename file |
| `cat <file>` | Display file contents |
| `nano <file>` | Edit file with nano |
| `vim <file>` | Edit file with vim |

### Network Commands

| Command | Description |
|---------|-------------|
| `ip addr` | Show IP addresses |
| `ip route` | Show routing table |
| `ping <host>` | Ping a host |
| `curl <url>` | Fetch URL |
| `wget <url>` | Download file |
| `ssh <user>@<host>` | SSH connection |
| `sshd` | Start SSH daemon |
| `ssh-keygen` | Generate SSH keys |
| `nmap <host>` | Port scan (install first) |

### System Commands

| Command | Description |
|---------|-------------|
| `top` | Show running processes |
| `ps` | List processes |
| `kill <pid>` | Kill process |
| `df` | Show disk usage |
| `free` | Show memory usage |
| `uname -a` | System information |
| `whoami` | Current user |
| `date` | Show date/time |
| `uptime` | Show system uptime |
| `termux-setup-storage` | Grant storage permission |
| `termux-wake-lock` | Prevent device sleep |
| `termux-change-repo` | Change repository mirror |

### Python & Node.js

| Command | Description |
|---------|-------------|
| `python` | Run Python REPL |
| `python <script.py>` | Run Python script |
| `pip install <package>` | Install Python package |
| `pip list` | List installed packages |
| `node` | Run Node.js REPL |
| `node <script.js>` | Run Node.js script |
| `npm install <package>` | Install npm package |
| `npm list -g` | List global packages |

### Git Commands

| Command | Description |
|---------|-------------|
| `git clone <url>` | Clone repository |
| `git status` | Show working tree status |
| `git add <file>` | Stage file |
| `git commit -m "msg"` | Commit changes |
| `git push` | Push to remote |
| `git pull` | Pull from remote |
| `git branch` | List branches |
| `git checkout <branch>` | Switch branch |

---

## ADB Commands

### Device Management

| Command | Description |
|---------|-------------|
| `adb devices` | List connected devices |
| `adb devices -l` | List devices with details |
| `adb connect <ip>:<port>` | Connect via WiFi |
| `adb disconnect` | Disconnect all |
| `adb disconnect <ip>:<port>` | Disconnect specific |
| `adb usb` | Switch to USB mode |
| `adb tcpip <port>` | Switch to TCPIP mode |
| `adb kill-server` | Kill ADB server |
| `adb start-server` | Start ADB server |
| `adb root` | Restart ADB as root (requires rooted) |

### File Transfer

| Command | Description |
|---------|-------------|
| `adb push <local> <remote>` | Push file to device |
| `adb pull <remote> <local>` | Pull file from device |
| `adb sync <dir>` | Sync directory |

### App Management

| Command | Description |
|---------|-------------|
| `adb install <apk>` | Install APK |
| `adb install -r <apk>` | Reinstall/upgrade APK |
| `adb uninstall <package>` | Uninstall app |
| `adb install-multiple <apks>` | Install multiple APKs |
| `adb pm list packages` | List installed packages |
| `adb pm list packages <filter>` | Filter packages |

### Shell & Execute

| Command | Description |
|---------|-------------|
| `adb shell` | Open device shell |
| `adb shell <command>` | Execute command on device |
| `adb exec-out <command>` | Execute with output capture |
| `adb wait-for-device` | Wait for device connection |

### Input Events

| Command | Description |
|---------|-------------|
| `adb shell input tap <x> <y>` | Tap at coordinates |
| `adb shell input swipe <x1> <y1> <x2> <y2>` | Swipe gesture |
| `adb shell input swipe <x1> <y1> <x2> <y2> <duration>` | Swipe with duration |
| `adb shell input text <text>` | Type text |
| `adb shell input keyevent <code>` | Send key event |
| `adb shell input keyevent 26` | Power button |
| `adb shell input keyevent 4` | Back button |
| `adb shell input keyevent 3` | Home button |

### Screenshots & Recording

| Command | Description |
|---------|-------------|
| `adb shell screencap <file>` | Take screenshot |
| `adb pull $(adb shell sdcard)/<file>` | Pull screenshot |
| `adb shell screenrecord <file>` | Record screen |
| `adb shell screenrecord --time-limit 30 <file>` | Record 30 seconds |

### Package Activities

| Command | Description |
|---------|-------------|
| `adb shell pm dump <package>` | Dump package info |
| `adb shell am start <activity>` | Start activity |
| `adb shell am start -n <pkg>/<activity>` | Start specific activity |
| `adb shell am force-stop <package>` | Force stop app |
| `adb shell am kill <package>` | Kill background process |

### Logs

| Command | Description |
|---------|-------------|
| `adb logcat` | View log output |
| `adb logcat -d` | Dump current log |
| `adb logcat -s <tag>` | Filter by tag |
| `adb logcat -d > log.txt` | Save log to file |
| `adb logcat -c` | Clear log |

### Device Info

| Command | Description |
|---------|-------------|
| `adb shell getprop` | Get all properties |
| `adb shell getprop <prop>` | Get specific property |
| `adb shell settings get secure <setting>` | Get setting |
| `adb shell dumpsys` | Dump system state |
| `adb shell dumpsys battery` | Battery status |

---

## OpenClaw CLI Reference

### Gateway Commands

| Command | Description |
|---------|-------------|
| `openclaw gateway start` | Start gateway |
| `openclaw gateway start --port 18789` | Start on custom port |
| `openclaw gateway start --host 0.0.0.0` | Bind to specific host |
| `openclaw gateway stop` | Stop gateway |
| `openclaw gateway restart` | Restart gateway |
| `openclaw gateway status` | Check gateway status |
| `openclaw gateway nodes` | List connected nodes |

### Node Commands

| Command | Description |
|---------|-------------|
| `openclaw node start` | Start as node |
| `openclaw node start --gateway <url>` | Connect to specific gateway |
| `openclaw node start --auto-discover` | Auto-discover gateway |
| `openclaw node start --token <token>` | Authenticate with token |
| `openclaw node stop` | Stop node |
| `openclaw node status` | Check node status |
| `openclaw node register` | Register node manually |

### Agent Commands

| Command | Description |
|---------|-------------|
| `openclaw agents list` | List active agents |
| `openclaw agents spawn --model <m> --task <t>` | Spawn agent |
| `openclaw agents kill <id>` | Kill agent |
| `openclaw agents status <id>` | Check agent status |

### Configuration

| Command | Description |
|---------|-------------|
| `openclaw config show` | Show current config |
| `openclaw config edit` | Edit configuration |
| `openclaw config reset` | Reset to defaults |

### Setup & Update

| Command | Description |
|---------|-------------|
| `openclaw setup` | Run first-time wizard |
| `openclaw setup gateway` | Configure gateway |
| `openclaw setup node` | Configure node |
| `openclaw update check` | Check for updates |
| `openclaw update install` | Install updates |

### Utilities

| Command | Description |
|---------|-------------|
| `openclaw --version` | Show version |
| `openclaw --help` | Show help |
| `openclaw logs` | View logs |
| `openclaw logs --gateway` | Gateway logs only |
| `openclaw logs --node` | Node logs only |
| `openclaw doctor` | Diagnose issues |

---

## Quick Actions

### Termux Quick Actions

```bash
# Update everything
pkg update && pkg upgrade

# Install common packages
pkg install python nodejs git curl wget openssh

# Get storage access
termux-setup-storage

# Prevent sleep (keep node running)
termux-wake-lock

# Open SSH server
sshd

# Find your IP
ip addr show wlan0
```

### ADB Quick Actions

```bash
# Connect to device wirelessly
adb connect 192.168.1.100:5555

# Install app
adb install app.apk

# Take screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png

# Tap at center of screen (assuming 1080x1920)
adb shell input tap 540 960

# Type text
adb shell input text "Hello%sworld"  # %s = space

# Press home button
adb shell input keyevent 3
```

### OpenClaw Quick Actions

```bash
# Start gateway
openclaw gateway start

# Start node with auto-discovery
openclaw node start --auto-discover

# Spawn quick agent
openclaw agents spawn --task "Hello"

# Check status
openclaw gateway status && openclaw node status
```

### Keyboard Shortcuts (Termux)

| Shortcut | Action |
|----------|--------|
| `Ctrl + A` | Move to line start |
| `Ctrl + E` | Move to line end |
| `Ctrl + K` | Delete to end of line |
| `Ctrl + U` | Clear line |
| `Ctrl + L` | Clear screen |
| `Ctrl + C` | Cancel/SIGINT |
| `Ctrl + D` | Exit/EOF |
| `Ctrl + Z` | Suspend/SIGTSTP |
| `Volume Up + Q` | Show extra keys |
| `Volume Up + W` | Arrow up |
| `Volume Up + S` | Arrow left |
| `Volume Up + D` | Arrow right |
| `Volume Up + X` | Arrow down |

---

## Troubleshooting Quick Fixes

| Issue | Fix |
|-------|-----|
| Termux pkg not found | `apt update` |
| ADB device not found | `adb kill-server && adb start-server` |
| SSH connection refused | `sshd` (run on device) |
| Permission denied (SSH) | Check `~/.ssh/authorized_keys` permissions |
| OpenClaw not found | `npm install -g openclaw` |
| Gateway port in use | `fuser -k 18789/tcp` |
| Node can't connect | Check firewall, verify IP |

---

## Related Documentation

- **[TERMUX-SETUP.md](./TERMUX-SETUP.md)** - Complete Termux setup
- **[OPENCLAW-INSTALL-GUIDE.md](./OPENCLAW-INSTALL-GUIDE.md)** - OpenClaw installation
- **[INSTALL-GUIDE.md](./INSTALL-GUIDE.md)** - Flutter app installation

---

**Quick Note:** Use `Tab` for auto-complete and `Ctrl + R` to search command history in Termux.