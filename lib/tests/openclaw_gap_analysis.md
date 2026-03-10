# OpenClaw Gap Analysis - Mobile App vs Core Features

**Generated:** March 10, 2026  
**App Version:** 2.0.0  
**OpenClaw Core Version:** v2026.3.8

---

## Executive Summary

The OpenClaw Mobile App (v2.0) has made significant progress with 12 major features implemented. However, comparing against the full OpenClaw core feature set reveals several gaps that represent opportunities for enhancement. This analysis identifies **47 potential features** across 10 categories.

---

## 1. Gateway Management Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Gateway Status | ✅ | Dashboard shows online/offline |
| Gateway Control | ✅ | Restart/stop via Control Panel |
| Connection Management | ✅ | Auto-discovery + manual entry |
| Token Auth | ✅ | Token entry in settings |
| Tailscale Support | ✅ | Remote gateway access |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Gateway Configuration Editor | **HIGH** | Medium | Edit openclaw.json remotely |
| Gateway Logs Live View | Medium | Low | Real-time log streaming (partial - has logs tab) |
| Gateway Health Checks | Medium | Low | `openclaw doctor` integration |
| Gateway Backup/Restore | **HIGH** | Medium | `openclaw backup create/verify` |
| Gateway Update | **HIGH** | Low | `openclaw update` from app |
| Hot Reload Config | Low | Low | Config hot-reload monitoring |
| Gateway Metrics Dashboard | Medium | Medium | CPU, memory, uptime charts |

---

## 2. Agent Management Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Agent List | ✅ | Dashboard shows agents |
| Agent Personalities | ✅ | 61 agent personalities from agency-agents |
| Agent Monitor | ✅ | Live visualization |
| Boss Chat | ✅ | Broadcast to agents |
| Multi-Agent Mode | ✅ | Deploy agent teams |
| Kill Agents | ✅ | Control Panel |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Agent Configuration | **HIGH** | Medium | Per-agent model, tools, workspace |
| Agent Routing Rules | Medium | Medium | Channel → agent routing |
| Agent Spawn/Kill API | Medium | Low | REST API for agent lifecycle |
| Agent Heartbeat Config | Medium | Low | Heartbeat interval, prompt |
| Agent Sandbox Settings | Low | High | Docker sandbox configuration |
| Agent Tool Profiles | Medium | Medium | `tools.profile` per agent |
| Agent Model Selection | **HIGH** | Low | Per-agent model override |
| Agent Fallback Models | Medium | Low | Model failover config |
| Sub-Agent Orchestration | Medium | High | `sessions_spawn` tool |

---

## 3. Channel Integrations

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Gateway Connection | ✅ | WebSocket to gateway |
| Multi-Gateway Support | ✅ | History + discovery |

### ❌ MISSING (ALL - These run on Gateway, not Node)
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| WhatsApp Channel Config | **HIGH** | Medium | QR pairing, allowlist |
| Telegram Channel Config | **HIGH** | Medium | Bot token, dmPolicy |
| Discord Channel Config | **HIGH** | Medium | Bot setup, server config |
| Slack Channel Config | Medium | Medium | App installation |
| Signal Channel Config | Medium | Medium | Phone number pairing |
| iMessage/BlueBubbles | Medium | High | Requires macOS gateway |
| Google Chat Config | Medium | Medium | Google Workspace setup |
| MS Teams Config | Medium | High | Enterprise setup |
| Matrix Config | Low | Medium | Homeserver config |
| IRC Config | Low | Low | Server + channel setup |
| WebChat Config | Medium | Low | WebChat settings |
| Channel Pairing UI | **HIGH** | High | Interactive pairing flows |
| Channel Status Monitor | Medium | Low | Per-channel health |
| Group Routing Rules | Medium | Medium | Mention patterns, allowlists |
| DM Policy Config | Medium | Medium | pairing/allowlist/open |

---

## 4. Skills Platform Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Skills Browser | ✅ | Skills screen |
| Skill Categories | ✅ | Organized by category |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Skill Installation | **HIGH** | Medium | ClawHub integration |
| Skill Editor | Medium | High | Edit SKILL.md in app |
| Skill Gating Display | Medium | Low | Show requires.bins/env |
| Skill API Key Management | **HIGH** | Medium | Manage skill API keys |
| Skill Enable/Disable | Medium | Low | Toggle skills on/off |
| Skill Logs | Medium | Low | Per-skill execution logs |
| ClawHub Browse/Search | Medium | Medium | Public skills registry |
| Skill Version Updates | Medium | Low | Check for updates |
| Workspace vs Shared Skills | Low | Low | Skill location info |

---

## 5. Automation Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Webhooks | ✅ | Webhook server |
| IFTTT Integration | ✅ | IFTTT templates |
| Scheduled Tasks | ✅ | Scheduled tasks screen |
| Automation Rules | ✅ | Automation engine |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Cron Job Management | **HIGH** | Medium | Full cron CRUD |
| Cron Editor UI | **HIGH** | Medium | Visual cron builder |
| Wake-up Jobs | Medium | Low | `wakeMode: now/next-heartbeat` |
| Isolated Session Jobs | Medium | Medium | `sessionTarget: isolated` |
| Webhook Endpoint Config | Medium | Medium | Custom webhook endpoints |
| Gmail Pub/Sub | Low | High | Gmail push notifications |
| Event Hooks | Medium | Low | Gateway event triggers |
| Job History/Runs | Medium | Low | `openclaw cron runs` |
| Job Delivery Config | Medium | Medium | announce/webhook/none |

---

## 6. Session Management Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Chat History | ✅ | Chat screen with history |
| Session Selection | ✅ | Session selector |
| Multi-Session | ✅ | Multiple sessions |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Session List API | Medium | Low | `sessions_list` tool |
| Session History API | Medium | Low | `sessions_history` tool |
| Session Reset | Medium | Low | Reset/clear session |
| Session Pruning Config | Low | Medium | Maintenance settings |
| Session Token Counts | Medium | Low | Display token usage |
| Session Cleanup | Low | Low | `openclaw sessions cleanup` |
| Thread Bindings | Medium | Medium | Discord thread routing |
| dmScope Config | Medium | Low | Session isolation mode |
| Identity Links | Low | Medium | Cross-channel identity |

---

## 7. Node Management Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Node List | ✅ | Dashboard shows nodes |
| Node Details | ✅ | Node info display |
| QR Pairing | ✅ | QR pairing screen |
| Node Host Config | ✅ | Node host screen |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Node Approval UI | **HIGH** | Low | Approve pending nodes |
| Node Rename | Medium | Low | `openclaw nodes rename` |
| Node Commands | Medium | Medium | camera.snap, screen.record |
| Canvas Navigate | Medium | Low | `canvas.navigate` |
| Canvas Snapshot | Medium | Low | `canvas.snapshot` |
| A2UI Push/Reset | Medium | Medium | `canvas.a2ui.push/reset` |
| Location Get | Low | Low | `location.get` |
| Notifications List | Medium | Medium | Android notifications |
| Device Status | Medium | Low | `device.status/info/health` |
| System.run on Node | Medium | Medium | Remote exec |
| File Push/Pull | Medium | Medium | (Requested in #41716) |
| Node Approvals/Allowlist | Medium | Medium | Exec approvals |

---

## 8. Browser Control Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| BrowserOS MCP | ✅ | 53 browser tools |
| Browser Workflows | ✅ | Visual workflow builder |
| Scheduled Browser Tasks | ✅ | Scheduling support |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| OpenClaw Browser Tool | Medium | High | Native browser tool (not MCP) |
| Browser Profile Config | Medium | Medium | Chrome profiles |
| Browser Snapshot | Medium | Low | Page snapshots |
| Browser Actions | Medium | Medium | Click, type, navigate |
| Browser Upload | Low | Medium | File uploads |

---

## 9. Canvas/A2UI Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Canvas Screen | ✅ | Canvas screen exists |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Canvas Navigate | **HIGH** | Low | Navigate to URLs |
| Canvas Eval | Medium | Medium | Execute JavaScript |
| Canvas Snapshot | **HIGH** | Low | Capture canvas state |
| A2UI Push | Medium | High | Push A2UI JSONL |
| A2UI Reset | Medium | Low | Reset A2UI state |
| Canvas Live Preview | Medium | High | Real-time canvas view |
| Canvas Position/Size | Low | Low | x/y/width/height |

---

## 10. Voice Features

### ✅ IMPLEMENTED
| Feature | Status | Notes |
|---------|--------|-------|
| Voice Commands | ✅ | Wake words + commands |
| TTS Feedback | ✅ | Text-to-speech |
| Voice Config | ✅ | Voice config screen |

### ❌ MISSING
| Feature | Priority | Effort | Notes |
|---------|----------|--------|-------|
| Voice Wake Config | Medium | Medium | Wake word settings |
| Talk Mode Toggle | Medium | Low | Continuous voice mode |
| Silence Timeout Config | Medium | Low | `talk.silenceTimeoutMs` |
| ElevenLabs Config | Medium | Medium | Voice provider settings |
| Speech-to-Text Config | Medium | Medium | STT provider selection |
| Voice on Lock Screen | Low | High | Background voice |

---

## Summary Statistics

| Category | Implemented | Missing | Coverage |
|----------|-------------|---------|----------|
| Gateway Management | 5 | 8 | 38% |
| Agent Management | 6 | 9 | 40% |
| Channel Integrations | 2 | 16 | 11% |
| Skills Platform | 2 | 9 | 18% |
| Automation | 4 | 10 | 29% |
| Session Management | 3 | 9 | 25% |
| Node Management | 4 | 13 | 24% |
| Browser Control | 3 | 5 | 38% |
| Canvas/A2UI | 1 | 7 | 13% |
| Voice Features | 3 | 6 | 33% |
| **TOTAL** | **33** | **92** | **26%** |

---

## Key Findings

### High-Impact Gaps (Blocking User Workflows)

1. **Channel Configuration** - Users cannot set up WhatsApp/Telegram/Discord from the app
2. **Gateway Backup/Restore** - No way to backup gateway state from mobile
3. **Cron Job Management** - Cannot create/edit cron jobs (only view scheduled tasks)
4. **Skill Installation** - Cannot install new skills from ClawHub
5. **Node Approval UI** - Cannot approve new node pairings

### Quick Wins (Low Effort, High Value)

1. **Gateway Update** - One button to run `openclaw update`
2. **Session Token Counts** - Display existing token data
3. **Node Rename** - Simple text field
4. **Canvas Snapshot** - Single API call
5. **Job History** - Display existing run data

### Complex Features (High Effort, Strategic Value)

1. **Channel Pairing UI** - Full OAuth/QR flows for each channel
2. **Agent Sandbox Config** - Docker settings UI
3. **A2UI Builder** - Visual A2UI construction
4. **Sub-Agent Orchestration** - Full `sessions_spawn` integration

---

## Recent OpenClaw Updates (Last 30 Days)

Based on commits and releases from Feb 10 - Mar 10, 2026:

### v2026.3.8 Highlights
- **Backup System** - `openclaw backup create/verify` commands
- **Talk Mode Config** - `talk.silenceTimeoutMs` setting
- **Remote Gateway Token** - Token field in macOS onboarding
- **Brave LLM Context** - `web_search` with LLM context mode
- **TUI Agent Inference** - Auto-detect active agent from workspace
- **Secret Resolution** - Atomic SecretRefs in web tools

### Feature Requests from Issues
- **File Push/Pull** (#41716) - Bidirectional file transfer between gateway and nodes
- **Vaultwarden Integration** (#1237) - Suggest password manager
- **Multiple Chat Contexts** (#101) - Separate contexts per Telegram group

---

## Recommendations

See `feature_recommendations.md` for prioritized implementation roadmap.

---

*Generated by OpenClaw Gap Analysis Tool*
*Last Updated: March 10, 2026 00:00 EST*