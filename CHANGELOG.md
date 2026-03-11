# Changelog

All notable changes to DuckBot Go will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.2+302] - 2026-03-11

### Added
- **Termux Detection System**: Comprehensive Android package detection using `pm list packages`
  - New `AndroidPackageDetector` utility for reliable app detection without root
  - Detects Termux, Termux:API, Termux:Float, Termux:Widget, Termux:Boot
  - Provides version info, install source, and timestamps
- **Prerequisite Checker**: `TermuxPrerequisiteChecker` validates installation readiness
  - Checks Android platform, Termux installation, storage permissions
  - Validates Node.js availability, network connectivity, storage space
  - Returns detailed blocking issues and recommendations
- **Enhanced Installer UI**: Local installer now shows prerequisite status before installation
  - Visual readiness card with pass/fail indicators
  - Clear blocking issues with actionable fixes
  - Recommendations for optional improvements
  - Real-time Termux environment detection display

### Changed
- **TermuxService**: Improved initialization with Android package manager detection
  - Uses `pm list packages` as primary detection method (more reliable)
  - Falls back to file system checks if package manager unavailable
  - Detects Termux:API availability for enhanced functionality
  - Provides detailed `getTermuxInfo()` with all detection results
- **NodejsInstallerService**: Uses comprehensive prerequisite checker
  - Replaced ad-hoc checks with `TermuxPrerequisiteChecker.getReadinessSummary()`
  - Better error messages with specific action items
  - Removed deprecated standalone check methods
- **LocalInstallerScreen**: Complete UX overhaul
  - Pre-installation readiness check runs automatically
  - Shows detailed prerequisite status before allowing installation
  - Prevents installation when blocking issues exist
  - Improved logging and troubleshooting display

### Fixed
- Termux detection no longer relies solely on file system checks
- Installer now properly validates all prerequisites before starting
- Clear user feedback on what's missing and how to fix it

### Technical
- New file: `lib/utils/android_package_detector.dart` (400+ lines)
- Updated: `lib/services/termux_service.dart` (enhanced detection)
- Updated: `lib/services/nodejs_installer_service.dart` (prerequisite integration)
- Updated: `lib/screens/local_installer_screen.dart` (UX improvements)

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
