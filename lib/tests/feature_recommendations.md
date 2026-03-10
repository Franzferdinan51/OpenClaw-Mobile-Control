# OpenClaw Mobile App - Feature Recommendations

**Generated:** March 10, 2026  
**App Version:** 2.0.0  
**Target Versions:** v2.1 - v3.0

---

## Priority Ranking System

| Priority | Description | Timeline |
|----------|-------------|----------|
| **P0 - Critical** | Blocks core user workflows | v2.1 (Next Release) |
| **P1 - High** | Significant user value, frequent use | v2.1 - v2.2 |
| **P2 - Medium** | Important but not blocking | v2.3 - v2.5 |
| **P3 - Low** | Nice to have, polish | v3.0+ |

---

## P0 - Critical Features (v2.1)

### 1. Gateway Backup/Restore
**Priority:** P0  
**Effort:** Medium (3-5 days)  
**User Value:** Critical - Users cannot backup/restore gateway state from mobile

**Implementation:**
```dart
// New screen: BackupScreen
class BackupScreen extends StatelessWidget {
  // Features:
  // - Create backup: POST /api/backup/create
  // - Verify backup: POST /api/backup/verify
  // - List backups: GET /api/backup/list
  // - Restore backup: POST /api/backup/restore
  // - Download backup: GET /api/backup/download/:id
}
```

**API Endpoints Needed:**
- `POST /backup/create` - Trigger `openclaw backup create`
- `GET /backup/list` - List available backups
- `POST /backup/verify/:id` - Verify backup integrity
- `POST /backup/restore/:id` - Restore from backup

**Notes:**
- OpenClaw v2026.3.8 added native backup commands
- Must handle large file downloads (1.6GB+ backups)
- Add progress indicators for backup/restore

---

### 2. Cron Job Management
**Priority:** P0  
**Effort:** Medium (4-6 days)  
**User Value:** Critical - Users cannot create/edit cron jobs from mobile

**Implementation:**
```dart
// New screen: CronEditorScreen
class CronEditorScreen extends StatelessWidget {
  // Features:
  // - Create job (one-shot, recurring, cron expression)
  // - Edit existing job
  // - Delete job
  // - Run job immediately
  // - View job history
}

// Cron expression builder widget
class CronExpressionBuilder extends StatefulWidget {
  // Visual builder for cron expressions
  // - Minute, Hour, Day, Month, DayOfWeek
  // - Presets: Every hour, Daily, Weekly
}
```

**API Endpoints Needed:**
- `GET /cron/list` - List all jobs
- `POST /cron/add` - Create job
- `POST /cron/edit/:id` - Update job
- `DELETE /cron/delete/:id` - Delete job
- `POST /cron/run/:id` - Execute immediately
- `GET /cron/runs/:id` - Job history

**Notes:**
- OpenClaw has full cron support via `openclaw cron` commands
- Support three schedule kinds: `at`, `every`, `cron`
- Add timezone picker (IANA timezones)

---

### 3. Node Approval UI
**Priority:** P0  
**Effort:** Low (1-2 days)  
**User Value:** Critical - Cannot approve new node pairings from mobile

**Implementation:**
```dart
// Enhancement to existing NodeSettingsScreen
class NodeApprovalWidget extends StatelessWidget {
  // Features:
  // - List pending approvals: openclaw devices list
  // - Approve button: openclaw devices approve <id>
  // - Reject button: openclaw devices reject <id>
  // - Device info display (name, type, IP)
}
```

**API Endpoints Needed:**
- `GET /devices/list` - List pending device requests
- `POST /devices/approve/:id` - Approve device
- `POST /devices/reject/:id` - Reject device

**Notes:**
- Very low effort, high value
- Should show prominently when pending requests exist
- Add notification badge for pending approvals

---

### 4. Skill Installation from ClawHub
**Priority:** P0  
**Effort:** Medium (4-5 days)  
**User Value:** Critical - Cannot discover/install new skills from mobile

**Implementation:**
```dart
// New screen: ClawHubScreen
class ClawHubScreen extends StatelessWidget {
  // Features:
  // - Browse skills: https://clawhub.com/api/skills
  // - Search skills
  // - Skill detail view (description, metadata, requirements)
  // - Install skill: clawhub install <slug>
  // - Update installed skills: clawhub update --all
}

// Enhancement to SkillsScreen
class InstalledSkillCard extends StatelessWidget {
  // - Show installed version
  // - Check for updates
  // - Enable/disable toggle
}
```

**API Endpoints Needed:**
- `GET /skills/browse` - Browse ClawHub registry
- `POST /skills/install` - Install skill
- `POST /skills/update/:name` - Update skill
- `GET /skills/installed` - List installed skills

**Notes:**
- ClawHub is the official skills registry
- Show skill requirements (bins, env, config)
- Handle installation failures gracefully

---

### 5. Channel Configuration UI
**Priority:** P0  
**Effort:** High (8-10 days)  
**User Value:** Critical - Cannot set up channels from mobile

**Implementation:**
```dart
// New screen: ChannelSetupScreen
class ChannelSetupScreen extends StatelessWidget {
  // Per-channel setup wizards:
  // - Telegram: Bot token entry, dmPolicy
  // - WhatsApp: QR code display, pairing flow
  // - Discord: Bot token, server selection
  // - Slack: OAuth flow, workspace selection
}

// Channel config widgets
class TelegramSetupWizard extends StatelessWidget {
  // 1. Enter bot token
  // 2. Test connection
  // 3. Configure dmPolicy
  // 4. Set allowlist
  // 5. Save config
}

class WhatsAppSetupWizard extends StatelessWidget {
  // 1. Start pairing
  // 2. Display QR code
  // 3. Poll for pairing status
  // 4. Configure allowlist
}
```

**API Endpoints Needed:**
- `GET /channels/status` - List channel status
- `POST /channels/:provider/config` - Configure channel
- `POST /channels/:provider/pairing/start` - Start pairing
- `GET /channels/:provider/pairing/status` - Check pairing status

**Notes:**
- Each channel has different setup flow
- WhatsApp requires QR code display
- Telegram is simplest (bot token only)
- Discord/Slack need OAuth flows

---

## P1 - High Priority Features (v2.2)

### 6. Agent Configuration Screen
**Priority:** P1  
**Effort:** Medium (3-4 days)  
**User Value:** High - Users want to customize agent settings

**Features:**
- Model selection (primary + fallbacks)
- Tool profiles (minimal/coding/messaging/full)
- Heartbeat config (interval, prompt)
- Workspace path
- Agent enable/disable

---

### 7. Gateway Configuration Editor
**Priority:** P1  
**Effort:** Medium (4-5 days)  
**User Value:** High - Edit openclaw.json remotely

**Features:**
- JSON editor with syntax highlighting
- Schema validation
- Category-based editor (agents, channels, tools, etc.)
- Hot reload support

---

### 8. Session Token Tracking
**Priority:** P1  
**Effort:** Low (1-2 days)  
**User Value:** High - Monitor context usage

**Features:**
- Display inputTokens, outputTokens, totalTokens
- Token usage charts
- Session reset option
- Token warning thresholds

---

### 9. Canvas Commands
**Priority:** P1  
**Effort:** Medium (3-4 days)  
**User Value:** High - Control node canvas from mobile

**Features:**
- Navigate canvas: `canvas.navigate`
- Snapshot canvas: `canvas.snapshot`
- Eval JavaScript: `canvas.eval`
- A2UI push/reset
- Position/size controls

---

### 10. Node Commands
**Priority:** P1  
**Effort:** Medium (4-5 days)  
**User Value:** High - Execute node commands from mobile

**Features:**
- Camera snap: `camera.snap`
- Camera clip: `camera.clip`
- Screen record: `screen.record`
- Location get: `location.get`
- Device status: `device.status/info/health`
- Notifications list: `notifications.list`

---

## P2 - Medium Priority Features (v2.3-v2.5)

### 11. Gateway Health Dashboard
**Priority:** P2  
**Effort:** Medium (2-3 days)

**Features:**
- `openclaw doctor` results
- Health check badges
- Configuration warnings
- Quick fixes

---

### 12. Webhook Configuration
**Priority:** P2  
**Effort:** Medium (2-3 days)

**Features:**
- Create webhook endpoints
- View webhook logs
- Test webhooks
- Configure delivery modes

---

### 13. Skill Editor
**Priority:** P2  
**Effort:** High (5-7 days)

**Features:**
- Edit SKILL.md files
- YAML frontmatter editor
- Syntax highlighting
- Preview rendered skill

---

### 14. Job Delivery Configuration
**Priority:** P2  
**Effort:** Medium (2-3 days)

**Features:**
- Delivery mode selection (announce/webhook/none)
- Webhook URL configuration
- Channel selection
- Best-effort toggle

---

### 15. Model Provider Configuration
**Priority:** P2  
**Effort:** Medium (3-4 days)

**Features:**
- Add/remove providers
- API key management
- Model catalog
- Custom providers/base URLs

---

### 16. Session Maintenance
**Priority:** P2  
**Effort:** Medium (2-3 days)

**Features:**
- Session cleanup UI
- Prune configuration
- Max entries setting
- Disk budget config

---

### 17. Browser Tool Integration
**Priority:** P2  
**Effort:** High (5-7 days)

**Features:**
- Native browser tool (not MCP)
- Profile management
- Snapshot/action controls
- Upload support

---

### 18. Voice Wake Configuration
**Priority:** P2  
**Effort:** Medium (3-4 days)

**Features:**
- Wake word selection
- Sensitivity tuning
- ElevenLabs config
- STT provider selection

---

## P3 - Low Priority Features (v3.0+)

### 19. iOS App
**Priority:** P3  
**Effort:** Very High (20-30 days)

**Notes:**
- Swift/SwiftUI development
- Shared Dart logic possible via Flutter
- Apple App Store distribution

---

### 20. Web PWA
**Priority:** P3  
**Effort:** High (10-15 days)

**Notes:**
- Progressive Web App
- Shared codebase with Flutter
- Browser-based access

---

### 21. Multi-Device Sync
**Priority:** P3  
**Effort:** High (7-10 days)

**Notes:**
- Sync settings across devices
- Cloud storage integration
- Conflict resolution

---

### 22. Widgets
**Priority:** P3  
**Effort:** Medium (3-4 days)

**Notes:**
- Android home screen widgets
- Quick actions widget
- Status widget

---

### 23. Watch App
**Priority:** P3  
**Effort:** High (10-15 days)

**Notes:**
- WearOS companion
- Quick voice commands
- Status glance

---

### 24. Advanced Analytics
**Priority:** P3  
**Effort:** Medium (4-5 days)

**Notes:**
- Usage statistics
- Token usage charts
- Response time metrics

---

### 25. Custom Themes
**Priority:** P3  
**Effort:** Low (2-3 days)

**Notes:**
- Theme editor
- Import/export themes
- OLED-friendly dark mode

---

## Implementation Roadmap

### v2.1 (Q2 2026) - Foundation
| Week | Features |
|------|----------|
| 1-2 | Gateway Backup/Restore |
| 2-3 | Cron Job Management |
| 3-4 | Node Approval UI |
| 4-5 | Skill Installation |
| 5-8 | Channel Configuration |

**Deliverables:** Core workflow completion

---

### v2.2 (Q3 2026) - Enhancement
| Week | Features |
|------|----------|
| 1-2 | Agent Configuration |
| 2-3 | Gateway Config Editor |
| 3-4 | Session Token Tracking |
| 4-5 | Canvas Commands |
| 5-6 | Node Commands |

**Deliverables:** Advanced control and monitoring

---

### v2.3-v2.5 (Q4 2026) - Polish
| Feature | Target |
|---------|--------|
| Health Dashboard | v2.3 |
| Webhook Config | v2.3 |
| Skill Editor | v2.4 |
| Job Delivery | v2.4 |
| Model Providers | v2.5 |
| Session Maintenance | v2.5 |
| Browser Tool | v2.5 |
| Voice Wake | v2.5 |

**Deliverables:** Professional feature set

---

### v3.0 (2027) - Platform Expansion
| Feature | Target |
|---------|--------|
| iOS App | v3.0 |
| Web PWA | v3.0 |
| Multi-Device Sync | v3.1 |
| Widgets | v3.1 |
| Watch App | v3.2 |

**Deliverables:** Cross-platform presence

---

## Quick Wins (Implement First)

These features provide immediate user value with minimal effort:

| # | Feature | Effort | Days |
|---|---------|--------|------|
| 1 | Node Approval UI | Low | 1-2 |
| 2 | Session Token Display | Low | 1-2 |
| 3 | Gateway Update Button | Low | 1 |
| 4 | Node Rename | Low | 1 |
| 5 | Canvas Snapshot | Low | 1-2 |

**Total Quick Win Effort:** 5-8 days

---

## Technical Recommendations

### 1. API Abstraction Layer
Create a unified API service that abstracts Gateway WebSocket calls:

```dart
class GatewayApiService {
  Future<Map<String, dynamic>> get(String endpoint);
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data);
  Future<void> delete(String endpoint);
  Stream<Map<String, dynamic>> subscribe(String event);
}
```

### 2. Reactive State Management
Use Provider/Riverpod for consistent state:

```dart
// Example: Cron state
final cronJobsProvider = StateNotifierProvider<CronJobsNotifier, List<CronJob>>((ref) {
  return CronJobsNotifier();
});
```

### 3. Error Handling
Implement consistent error handling with user-friendly messages:

```dart
class GatewayException implements Exception {
  final String message;
  final int? code;
  final bool recoverable;
}
```

### 4. Offline Support
Cache configuration and status for offline viewing:

```dart
class CachedGatewayService {
  Future<void> cacheConfig();
  Future<Map<String, dynamic>?> getCachedConfig();
}
```

### 5. Background Updates
Use work_manager for background sync:

```dart
Workmanager().initialize(callbackDispatcher);
Workmanager().registerPeriodicTask(
  'gateway-sync',
  'gatewaySync',
  frequency: Duration(minutes: 15),
);
```

---

## Security Considerations

### 1. Token Storage
Store gateway tokens securely using flutter_secure_storage:

```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'gateway_token', value: token);
```

### 2. API Key Management
Never store API keys in plain text. Use the gateway's secret management.

### 3. Certificate Pinning
Implement SSL pinning for production builds.

### 4. Biometric Auth
Add biometric unlock for sensitive operations:

```dart
final auth = LocalAuthentication();
bool authenticated = await auth.authenticate(localizedReason: 'Authenticate to continue');
```

---

## Testing Strategy

### Unit Tests
- API service methods
- State management logic
- Utility functions

### Widget Tests
- Screen rendering
- Navigation flows
- Form validation

### Integration Tests
- Full user workflows
- Gateway connection
- Error scenarios

### Performance Tests
- Large list rendering
- Memory usage
- Network latency handling

---

## Metrics to Track

| Metric | Target | Measurement |
|--------|--------|-------------|
| Feature Coverage | 50% by v2.2 | Gap analysis |
| User Satisfaction | 4.5+ rating | App store reviews |
| Crash-Free Rate | 99.5%+ | Crashlytics |
| API Response Time | <500ms | Gateway metrics |
| Daily Active Users | +20% MoM | Analytics |

---

## Conclusion

This roadmap provides a clear path from the current 26% feature coverage to a comprehensive mobile control center for OpenClaw. The prioritization focuses on:

1. **Unblocking core workflows** (backup, cron, channels)
2. **Adding monitoring capabilities** (tokens, health)
3. **Expanding control surfaces** (canvas, nodes)
4. **Platform expansion** (iOS, PWA)

By following this roadmap, the OpenClaw Mobile App will become a first-class interface for managing OpenClaw installations.

---

*Generated by OpenClaw Feature Analysis Tool*
*Last Updated: March 10, 2026 00:00 EST*