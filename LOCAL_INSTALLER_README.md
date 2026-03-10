# Local OpenClaw Installer

## Overview
The local installer allows you to run OpenClaw AI Gateway directly on your Android device without needing a separate server or PC.

## Quick Start

### Prerequisites
1. Android 7.0 or higher
2. ~500MB free storage space
3. Internet connection
4. Termux app (from F-Droid, NOT Play Store)

### Installation Steps

1. **Open the app** and tap "Install on This Phone" on the welcome screen
   - Or go to Settings → Advanced → Install OpenClaw Locally

2. **Tap "Start Installation"**
   - The installer will check prerequisites automatically

3. **Wait for installation**
   - Node.js will be installed (if not present)
   - OpenClaw will be downloaded and installed
   - Environment will be configured

4. **Start the Gateway**
   - Tap "Start Gateway" when installation completes
   - Wait for the gateway to be ready (health check)

5. **Connect**
   - Tap "Connect to Gateway" to start using OpenClaw

## What Gets Installed

- **Node.js 18+**: JavaScript runtime
- **OpenClaw CLI**: AI Gateway and CLI tools
- **Configuration**: Bionic bypass for Android compatibility

## Troubleshooting

### "Termux not available"
Download Termux from F-Droid:
https://f-droid.org/packages/com.termux/

**Do NOT use the Play Store version** - it's outdated and broken.

### "Insufficient storage"
Free up at least 500MB of storage space before installing.

### "Installation failed"
1. Check your internet connection
2. Make sure Termux is installed
3. Try the manual installation steps in the troubleshooting dialog

### "Gateway won't start"
1. Check that port 18789 is not in use
2. Try stopping any existing gateway: `openclaw gateway stop`
3. Check logs for specific errors

### Manual Installation (Fallback)
If automatic installation fails:

```bash
# In Termux:
pkg update
pkg install -y nodejs
npm install -g openclaw
openclaw onboarding  # Select "Loopback (127.0.0.1)"
openclaw gateway start
```

## Technical Details

### Installation Path
- Node.js: Via Termux package manager
- OpenClaw: `~/.npm-global/lib/node_modules/openclaw`
- Config: `~/.openclaw/`

### Bionic Bypass
Android uses Bionic libc which has issues with Node.js's `os.networkInterfaces()`. The installer creates a preload script that provides a fallback.

### Port
The gateway runs on port 18789 by default (localhost:18789).

## Uninstalling

To remove the local installation:
1. Go to Settings → Advanced
2. Tap "Clear App Data" (this clears preferences)
3. In Termux: `npm uninstall -g openclaw`

## Support

If you encounter issues:
1. Copy the installation logs (tap copy button in logs panel)
2. Check the troubleshooting dialog
3. Try manual installation steps
4. Share logs for debugging

## Limitations

- Requires Termux (for now)
- No root access needed
- Gateway stops when app is closed (unless running as service)
- Battery optimization may kill the process
