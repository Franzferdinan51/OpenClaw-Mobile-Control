# OpenClaw Mobile App - Termux Setup Guide

**Version:** 1.0.0  
**Purpose:** Complete Termux configuration to run OpenClaw on Android

---

## Why Termux?

Termux is a Linux terminal emulator for Android that allows you to run a full OpenClaw gateway directly on your phone. No computer required!

### Benefits

- **Run OpenClaw anywhere** - Your phone becomes a gateway
- **Always available** - No computer needs to be on
- **Native performance** - Python, Node.js, Git all supported
- **ADB integration** - Control your phone remotely
- **Portable** - Take your automation anywhere

---

## Installation

### Step 1: Install Termux

**Option A: F-Droid (Recommended)**
1. Visit https://f-droid.org/packages/com.termux/
2. Download the APK
3. Install (enable "Install from unknown sources" if prompted)

**Option B: GitHub**
1. Visit https://github.com/termux/termux-app/releases
2. Download latest `termux-app_v*.apk`
3. Install the APK

**⚠️ Important:** Only install from trusted sources (F-Droid or GitHub). Avoid "Termux" apps in regular app stores that may be fakes.

---

### Step 2: Initial Setup

Open Termux and run:

```bash
# Update package lists
pkg update

# Upgrade existing packages
pkg upgrade

# Install base packages
pkg install git curl wget
```

---

## Required Packages

### Core Packages

```bash
# Install Python (required for OpenClaw)
pkg install python

# Verify Python
python --version  # Should be Python 3.x
```

### Node.js

```bash
# Install Node.js
pkg install nodejs

# Verify Node
node --version   # Should be 18.x or higher
npm --version
```

### Build Tools

```bash
# Install build tools (for some packages)
pkg install build-essential

# Install Rust (for certain OpenClaw components)
pkg install rust
```

### Version Control

```bash
# Git should be pre-installed, but verify
git --version

# Install Git if needed
pkg install git
```

### OpenClaw Dependencies

```bash
# Install additional dependencies
pkg install coreutils grep sed awk tar gzip

# For network tools
pkg install net-tools iputils-ping

# For text processing
pkg install vim nano  # Your preference
```

---

## ADB Wireless Debugging

### Enable on Phone

1. **Settings → About Phone**
2. **Tap "Build Number" 7 times** → Developer mode enabled
3. **Settings → System → Developer Options**
4. **Enable "Wireless Debugging"**

### Install ADB in Termux

```bash
# Install ADB
pkg install android-tools
# Or
pkg install adb
```

### Pair with Computer

```bash
# In Termux, start ADB daemon
adb -L tcpip:5037 fork-server server &

# On your computer, pair with the phone
# From phone: Settings → Wireless Debugging → Pair
# Note the IP, port, and pairing code

adb pair 192.168.1.100:37215 123456

# Connect
adb connect 192.168.1.100:5555

# Verify
adb devices
```

### From Computer to Termux

Alternatively, run ADB on computer to connect to phone running Termux:

```bash
# Enable wireless debugging on phone
# Note the IP and port

# From computer
adb connect <phone-ip>:<port>

# Now control phone from computer
adb shell
```

---

## SSH Setup

Access your Termux session from your computer.

### Install SSH

```bash
pkg install openssh
```

### Configure SSH

```bash
# Set password (required for SSH)
passwd

# Check username
whoami  # Usually "u0_aXXX"
```

### Start SSH Server

```bash
# Start SSH daemon
sshd

# Default port is 8022
# Check with: logcat | grep sshd
```

### Connect from Computer

```bash
# SSH into phone
ssh <username>@<phone-ip> -p 8022

# Example:
ssh u0_a234@192.168.1.100 -p 8022

# Enter password when prompted
```

---

## OpenClaw Installation

### Clone Repository

```bash
# Navigate to home directory
cd ~

# Clone OpenClaw (adjust URL as needed)
git clone https://github.com/your-repo/OpenClaw.git openclaw
cd openclaw
```

### Run Installation Script

```bash
# Make install script executable
chmod +x install.sh

# Run installation
./install.sh
```

### Manual Installation

```bash
# Install npm packages
npm install

# Install Python dependencies
pip install -r requirements.txt

# Initialize OpenClaw
openclaw init

# Or use setup script
python setup.py install
```

### Configuration

```bash
# Configure OpenClaw
openclaw config set gateway.token "your-token-here"

# View configuration
openclaw config show
```

### Start OpenClaw

```bash
# Start gateway
openclaw gateway start

# Check status
openclaw gateway status

# View logs
openclaw logs
```

---

## Permission Grants

### Storage Access

```bash
# Grant storage permission
termux-setup-storage

# This creates ~/storage and symlinks to:
# - ~/storage/shared (internal storage)
# - ~/storage/dcim (camera)
# - ~/storage/downloads
```

### Camera Access

```bash
# Install camera tool
pkg install termux-api

# Take photo
termux-camera-photo -c 0 /sdcard/openclaw/photo.jpg
```

### Other Permissions

| Permission | Command |
|------------|---------|
| Location | `termux-location` |
| SMS | `termux-sms-send` |
| Notifications | `termux-notification` |
| Vibration | `termux-vibrate` |
| TTS | `termux-tts` |

---

## Running as a Service

### Using Termux:Boot

```bash
# Install Termux:Boot from F-Droid
# https://f-droid.org/packages/com.termux.boot/

# Create startup script
mkdir -p ~/.termux/boot/
nano ~/.termux/boot/startup.sh
```

### Startup Script Example

```bash
#!/data/data/com.termux/files/usr/bin/sh
# ~/.termux/boot/startup.sh

# Start SSH (optional)
sshd

# Start OpenClaw
cd ~/openclaw
openclaw gateway start

# Optional: Enable WiFi sharing
# More advanced setup required
```

```bash
# Make executable
chmod +x ~/.termux/boot/startup.sh
```

---

## Keeping Termux Updated

### Regular Maintenance

```bash
# Update packages weekly
pkg update && pkg upgrade

# Clean up
pkg autoclean
pkg clean
```

### Update OpenClaw

```bash
# Navigate to OpenClaw directory
cd ~/openclaw

# Pull latest changes
git pull

# Rebuild if needed
pip install -r requirements.txt --upgrade

# Restart gateway
openclaw gateway restart
```

---

## Troubleshooting

### Package Installation Fails

```bash
# Fix repository issues
pkg update --upgrade
rm -rf $PREFIX/var/lib/apt/lists/*

# Try again
pkg install <package>
```

### Python Issues

```bash
# Upgrade pip
pip install --upgrade pip

# Fix Python
python -m pip install --upgrade pip setuptools wheel
```

### Storage Permission Not Working

```bash
# Re-run setup
termux-setup-storage

# Check if storage is accessible
ls -la ~/storage/
```

### OpenClaw Won't Start

```bash
# Check logs
openclaw logs

# Common fixes:
# - Check configuration: openclaw config show
# - Check ports: netstat -tulpn | grep 18789
# - Restart: openclaw gateway restart
```

---

## Backup & Restore

### Backup Termux

```bash
# Backup OpenClaw data
cp -r ~/openclaw ~/storage/shared/Backup/

# Or use termux-backup (from F-Droid)
```

### Restore

```bash
# Restore OpenClaw
cp -r ~/storage/Backup/openclaw ~/

# Re-install dependencies
cd ~/openclaw
pip install -r requirements.txt
```

---

## Security Considerations

### Don't Run as Root

Termux on unrooted devices runs as a regular user. This is good!

### Protect Your Token

```bash
# Set secure permissions
chmod 600 ~/.openclaw/config

# Don't share your token
```

### SSH Security

```bash
# Use key-based auth instead of password (advanced)
# Generate key on computer, copy to Termux
```

---

## Quick Reference

### Common Commands

| Command | Description |
|---------|-------------|
| `pkg update` | Update package lists |
| `pkg upgrade` | Upgrade packages |
| `pkg install <pkg>` | Install package |
| `python --version` | Check Python |
| `node --version` | Check Node.js |
| `openclaw gateway start` | Start OpenClaw |
| `openclaw gateway status` | Check status |
| `termux-setup-storage` | Grant storage |

### Useful Shortcuts

```bash
# Copy file to phone
adb push app.apk /sdcard/Download/

# Pull file from phone
adb pull /sdcard/photo.jpg .

# Open shell on phone
adb shell

# Reboot phone
adb reboot
```

---

## Related Documentation

- [INSTALL-GUIDE.md](./INSTALL-GUIDE.md)
- [USER-GUIDE.md](./USER-GUIDE.md)
- [DEPLOYMENT.md](./DEPLOYMENT.md)
- [API-TESTING.md](./API-TESTING.md)
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)