# DuckBot Go

DuckBot Go is an Android Flutter client for OpenClaw gateway control, chat, local runtime setup, and agent monitoring.

**Version:** 3.1.0  
**Last Updated:** March 11, 2026  
**Status:** Active development  
**Platform:** Android  
**Package ID:** `com.duckbot.go`

## What Ships Today

- Chat with session-aware HTTP send/history and optional WebSocket live updates.
- Dashboard with gateway status, local metrics integration, runtime/source freshness, and agent visualization.
- Quick Actions control hub for gateway checks, logs, backup, chat tests, metrics tests, runtime repair, and agent monitor entry points.
- Agent monitor with boss chat entry, activity surfaces, and session detail drill-down.
- Local no-root OpenClaw install flow using the official Termux app plus Termux:API.
- Termux Bridge screen for sending commands into Termux and checking local runtime readiness.

## Current Gaps

- Chat attachments, voice input, and persistence across restart are not finished.
- Local metrics helper productization still needs more repair/setup automation.
- Some analyzer cleanup and broader on-device smoke coverage are still pending.

The current priority list lives in [docs/V3.0.5-PRIORITIES.md](/Users/duckets/Desktop/DuckBot-Go-Project/docs/V3.0.5-PRIORITIES.md).

## Quick Start

### Remote Gateway

1. Build or install the APK.
2. Start your OpenClaw gateway on a reachable host.
3. Open DuckBot Go.
4. Use auto-discovery or connect manually to `http://YOUR_IP:18789`.
5. Open Chat, Dashboard, Quick Actions, or Agent Monitor.

Example gateway prep:

```bash
openclaw config set gateway.bind lan
openclaw config set discovery.mdns.mode full
openclaw gateway restart
curl http://YOUR_IP:18789/health
```

### Local Android Runtime (No Root)

DuckBot Go now uses the official no-root Termux path. It does not require root, `proot`, or Ubuntu as the primary install path.

1. Install the official Termux app from F-Droid or GitHub Releases.
2. Install the official Termux:API app from the same source as Termux.
3. Open Termux once so it can finish first-run setup.
4. In Android Settings, grant DuckBot Go the Termux `RUN_COMMAND` permission.
5. In DuckBot Go, open `Quick Actions -> Repair` or the `Termux Bridge` screen.
6. Send the no-root setup command to Termux, or run the commands manually.

Manual fallback:

```bash
pkg update -y && pkg upgrade -y
pkg install -y nodejs termux-api
termux-setup-storage
npm install -g openclaw --unsafe-perm
openclaw gateway start --port 18789
```

After the gateway starts, connect to:

```text
http://127.0.0.1:18789
```

## Termux Notes

- Use official Termux builds from F-Droid or GitHub Releases.
- Install Termux and Termux:API from the same source.
- The Google Play build is not the supported path for the local installer flow.
- DuckBot Go sends commands into Termux through the official `RUN_COMMAND` integration.
- Command output for that flow appears inside the Termux session, not inside DuckBot Go.

Useful links:

- Termux app: https://github.com/termux/termux-app
- Termux app releases: https://github.com/termux/termux-app/releases
- Termux:API: https://github.com/termux/termux-api
- Termux:API releases: https://github.com/termux/termux-api/releases
- F-Droid Termux: https://f-droid.org/packages/com.termux/
- F-Droid Termux:API: https://f-droid.org/packages/com.termux.api/

## Main Screens

### Home / Dashboard

- Gateway health and local runtime status.
- Local metrics with source and freshness indicators.
- Agent overview, activity context, and quick entry points.

### Chat

- Session-aware chat transport.
- HTTP-first message send/history.
- Optional WebSocket live updates.
- Connection state UX for connected, reconnecting, and offline cases.

### Quick Actions

- Test gateway.
- Restart gateway.
- Open logs.
- Backup now.
- Refresh agents.
- Test metrics.
- Test chat.
- Open runtime status.
- Open local installer.
- Open Termux Bridge.

### Agent Monitor

- Boss chat entry point.
- Session drill-down.
- Agent cards and activity context.

### Termux Bridge

- Check Termux install state.
- Check Termux:API install state.
- Check `RUN_COMMAND` permission.
- Send setup/start/stop/status commands to Termux.
- Copy manual setup commands.

## Build

Requirements:

- Flutter SDK for the version pinned by this project.
- Android SDK / Android Studio or command-line tools.
- Java 17.

Build from source:

```bash
flutter pub get
flutter build apk --debug
flutter build apk --release
```

## Verification

Recent verification for the current local runtime and README-aligned flow:

```bash
flutter test test/widget_test.dart
cd android && ./gradlew app:compileDebugKotlin
```

`flutter analyze` on the touched runtime/install screens currently passes without errors. Remaining analyzer output is mostly older `withOpacity` deprecation info in existing UI code.

## Development Notes

- The app targets Android with Flutter and Material UI.
- Local runtime setup is designed to stay no-root.
- Remote gateway use remains the primary production path.
- The local runtime flow is intended for on-device control, diagnostics, and lightweight local usage.

## Related References

- OpenClaw: https://github.com/openclaw/openclaw
- Agent monitor reference repo: https://github.com/Franzferdinan51/agent-monitor-openclaw-dashboard
- V3.0.5 priorities: [docs/V3.0.5-PRIORITIES.md](/Users/duckets/Desktop/DuckBot-Go-Project/docs/V3.0.5-PRIORITIES.md)

## License

MIT. See [LICENSE](/Users/duckets/Desktop/DuckBot-Go-Project/LICENSE) if present in your distribution.
