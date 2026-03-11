# Changelog

All notable changes to DuckBot Go will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.1+301] - 2026-03-10

### Fixed
- **CRITICAL:** Chat send button now correctly routes to OpenClaw gateway
  - Fixed: ChatScreen was created without gatewayService in DashboardScreen, QuickActionsScreen, and GlobalSearchScreen
  - Messages now properly send via WebSocket to the backend
- Memory percent divide by zero bug in dashboard (BUG-004)
- Removed backup `lib-full-backup` folder from analysis (was causing false compilation errors)

### Changed
- QuickActionsScreen now accepts gatewayService parameter
- _ActionsHubScreen now passes gatewayService to QuickActionsScreen
- All ChatScreen navigations now pass gatewayService for proper message routing

## [3.0.0+300] - 2026-03-10

### Added
- Inline generative UI (ChatGPT-style)
  - Weather widgets inline in chat
  - Chart widgets (bar/line/pie/gauge) inline
  - Info cards (10 types) inline
  - Status cards inline
- ACP Agents integration
  - Codex, Claude Code, Gemini, Claude
  - Telegram thread bindings
  - Discord thread bindings
- Modern chat UI/UX (WhatsApp/Telegram style)
- Agent assistance features (session management, model selection, token usage)
- Weather integration with OpenWeatherMap API
- Chart widgets with animations and tooltips
- Info cards (status/data/code/file/link/image)

### Changed
- Chat now uses WebSocket for real-time communication
- Inline UI instead of separate screens
- ACP agents available in threads

---

## [1.0.0+1] - 2026-03-10

### Added
- Initial release
- Basic chat functionality
- Dashboard with gateway status
- Quick actions
- Control panel
- Logs viewer
- Settings

---

**Note:** This changelog is being updated. Full version 3.0.0 release pending fix of compilation errors.
