# OpenClaw Mobile - Minimal Build Plan

**Date:** 2026-03-09 15:05 EDT  
**Status:** Creating minimal working APK

## Problem

The full auto-generated app (50+ files) has too many integration issues:
- Type conflicts across files
- Missing service implementations
- Provider dependency issues
- Import conflicts

**Fixing all would take 1-2 hours**

## Solution: Minimal APK

Create a **simplified version** with just 5-10 files that will:
- ✅ Compile successfully
- ✅ Install on phone
- ✅ Show core features
- ✅ Be expandable later

## Minimal File Structure

```
lib/
├── main.dart (entry point)
├── app.dart (app structure)
├── screens/
│   ├── dashboard_screen.dart (status display)
│   └── settings_screen.dart (connection config)
├── services/
│   └── gateway_service.dart (HTTP API calls)
└── models/
    └── gateway_status.dart (data models)
```

**Total:** 5-7 files instead of 50+

## Features

**Included:**
- ✅ Gateway connection
- ✅ Status dashboard (gateway, agents, nodes)
- ✅ Settings (IP, port, token)
- ✅ Auto-discovery (basic)

**Deferred:**
- Chat (add later)
- Quick Actions (add later)
- Logs viewer (add later)
- Control panel (add later)

## Build Command

```bash
cd /Users/duckets/Desktop/Android-App-DuckBot
flutter build apk --release
```

**ETA:** 15-20 minutes

---

**Next:** Create minimal files, delete problematic ones, build APK
