# Gateway Discovery Fix - Documentation

## Summary of Changes

Fixed mDNS and network discovery issues in the DuckBot Go Android app.

## Issues Fixed

### 1. mDNS Discovery Finding 0 Services
**Problem:** The mDNS client was not working properly on Android, finding 0 services even when gateway was advertising.

**Root Causes:**
- Using `interfacesFactory` with custom network interface listing caused issues on Android
- Android Bionic libc has known issues with `NetworkInterface.list()` in some cases
- The multicast_dns package needs simpler initialization on Android

**Fix:**
- Removed custom `interfacesFactory` - let the system handle interface selection
- Added proper error handling and logging for mDNS operations
- Added timeout handling to prevent hanging

### 2. Network Scan Finding No Gateways
**Problem:** Network scan was not finding gateways even when they were reachable.

**Root Causes:**
- Using wrong API endpoint (`/api/mobile/status` which doesn't exist)
- Not trying multiple endpoints for discovery
- Short timeout (1000ms) was too aggressive for some networks

**Fix:**
- Changed discovery to try multiple endpoints: `/api/gateway`, `/api/status`, `/health`
- Increased timeout to 1500ms for better reliability
- Added JSON validation to confirm it's actually an OpenClaw gateway

### 3. Gateway Binding to Localhost Only
**Problem:** Gateway was binding to 127.0.0.1 only, not discoverable from other devices.

**Solution:**
The gateway needs to be configured to bind to all interfaces:

```bash
# Configure gateway to bind to LAN
openclaw config set gateway.bind lan

# Enable mDNS advertising
openclaw config set discovery.mdns.mode full

# Restart gateway
openclaw gateway restart
```

### 4. Mobile API Endpoints May Not Exist
**Problem:** The app was using `/api/mobile/*` endpoints which may not exist in all OpenClaw versions.

**Fix:**
- Updated all API calls to use standard OpenClaw endpoints
- Added fallback logic to try multiple endpoints
- Documented actual working endpoints

## Files Modified

### 1. `lib/services/discovery_service.dart`
- Fixed mDNS initialization (removed problematic `interfacesFactory`)
- Updated `_quickCheckGateway()` to try multiple endpoints
- Added better logging and error handling
- Fixed network scan to be more reliable

### 2. `lib/services/gateway_service.dart`
- Updated `getStatus()` to try `/api/gateway`, `/api/status`, `/health` in order
- Updated `isReachable()` to try multiple endpoints
- Updated `checkConnection()` with better error reporting
- Added documentation of actual API endpoints

### 3. `android/app/src/main/AndroidManifest.xml`
- Already had correct permissions (no changes needed)
- Verified: `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_WIFI_STATE`, `NEARBY_WIFI_DEVICES`

## OpenClaw Gateway API Endpoints

Based on research of the OpenClaw source code and documentation:

### Status/Health Endpoints (Unauthenticated)
- `GET /api/gateway` - Gateway status, sessions, nodes
- `GET /api/status` - Alternative status endpoint
- `GET /health` - Simple health check

### Action Endpoints (Authenticated)
- `POST /api/gateway/action` - Send message, broadcast, get history
  - Body: `{"action": "send", "sessionKey": "...", "message": "..."}`
  - Body: `{"action": "broadcast", "sessionKeys": [...], "message": "..."}`
  - Body: `{"action": "history", "sessionKey": "...", "limit": 20}`

### Autowork Endpoints
- `GET /api/gateway/autowork` - Get autowork config
- `POST /api/gateway/autowork` - Update autowork config
- `PUT /api/gateway/autowork` - Trigger autowork run

### Logs Endpoints
- `GET /api/logs?limit=100` - Get gateway logs

### Control Endpoints (POST with `{"confirm": true}`)
- `POST /api/mobile/control/gateway/restart`
- `POST /api/mobile/control/gateway/stop`
- `POST /api/mobile/control/agent/{sessionKey}/kill`
- `POST /api/mobile/control/node/{nodeName}/reconnect`
- `POST /api/mobile/control/cron/{cronName}/run`
- `POST /api/mobile/control/cron/{cronName}/toggle`
- `POST /api/mobile/control/pause-all`
- `POST /api/mobile/control/resume-all`

## Testing Instructions

### Step 1: Configure Gateway

On your OpenClaw host machine:

```bash
# Set gateway to bind to all interfaces
openclaw config set gateway.bind lan

# Enable mDNS advertising
openclaw config set discovery.mdns.mode full

# Verify settings
openclaw config get gateway.bind
openclaw config get discovery.mdns.mode

# Restart gateway
openclaw gateway restart
```

### Step 2: Verify Gateway is Advertising

On the same machine:

```bash
# Check gateway status
openclaw gateway status

# Check mDNS is enabled
openclaw config get discovery.mdns.mode

# View gateway logs
openclaw logs gateway
```

### Step 3: Test from Another Device

From another device on the same network:

```bash
# Test with curl
curl http://<GATEWAY_IP>:18789/api/gateway

# Should return JSON with gateway status
```

### Step 4: Build and Test Android App

```bash
# Build release APK
cd /Users/duckets/Desktop/Android-App-DuckBot
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# Or for development
flutter run
```

### Step 5: Test Discovery

1. Open the app
2. Go to the Discovery tab
3. Tap "Scan"
4. Check logs for discovery progress
5. If mDNS fails, try manual entry with the gateway IP

## Troubleshooting

### mDNS Not Working

**Symptoms:** "mDNS finds 0 services"

**Solutions:**
1. Ensure gateway is configured: `openclaw config set discovery.mdns.mode full`
2. Check Android permissions are granted (Location, Nearby Devices)
3. Some Android devices block mDNS on certain networks
4. Use manual IP entry as fallback

### Network Scan Not Finding Gateway

**Symptoms:** "Network scan finds no gateways"

**Solutions:**
1. Ensure gateway is bound to LAN: `openclaw config set gateway.bind lan`
2. Check firewall isn't blocking port 18789
3. Verify devices are on same network/subnet
4. Try manual entry with exact IP

### Connection Test Fails

**Symptoms:** "Connection test failed"

**Solutions:**
1. Verify gateway is running: `openclaw gateway status`
2. Check token if gateway requires auth
3. Try different endpoints in browser/curl first
4. Check logs for specific error

## References

- OpenClaw Gateway Protocol: https://docs.openclaw.ai/gateway/protocol
- OpenClaw Health Checks: https://docs.openclaw.ai/gateway/health
- multicast_dns package: https://pub.dev/packages/multicast_dns
- Android mDNS permissions: https://developer.android.com/reference/android/net/wifi/WifiManager.MulticastLock
