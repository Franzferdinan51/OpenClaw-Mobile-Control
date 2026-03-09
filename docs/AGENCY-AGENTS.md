# Agency-Agents Integration Guide

> **61 Specialized Agent Personalities** for DuckBot Mobile App

This document describes the integration of the [Agency-Agents](https://github.com/msitarzewski/agency-agents) collection into the DuckBot mobile application.

---

## Overview

The Agency is a collection of **61 specialized AI agent personalities** across **9 divisions**:

| Division | Agents | Emoji |
|----------|--------|-------|
| Engineering | 8 | 💻 |
| Design | 7 | 🎨 |
| Marketing | 11 | 📢 |
| Product | 3 | 📊 |
| Project Management | 5 | 🎬 |
| Testing | 8 | 🧪 |
| Support | 6 | 🛟 |
| Spatial Computing | 6 | 🥽 |
| Specialized | 7 | 🎯 |

---

## Features

### 1. Agent Personality Selector
- Browse 61 specialized agent personalities
- Select an agent for the current task
- Each agent has a unique voice, workflow, and deliverables
- Example: "Activate Frontend Developer mode"

### 2. Agent Mode Integration
- Chat with a selected agent personality
- Agent responds in their unique style
- Specialized workflows per agent
- Success metrics per agent

### 3. Multi-Agent Orchestration
- Deploy multiple agents for complex tasks
- Example: Frontend Dev + UI Designer + Growth Hacker = App Launch Team
- Coordinated workflows
- Unified output

### 4. Agent Templates
- Pre-built agent combinations for common tasks:
  - **App Launch Team** (5 agents) - Build and launch a new app
  - **Marketing Campaign** (4 agents) - Multi-channel marketing
  - **Enterprise Delivery** (6 agents) - Enterprise-grade projects
  - **MVP Rapid Build** (3 agents) - Fast prototyping
  - **Security Review** (3 agents) - Comprehensive security
  - **XR Experience** (3 agents) - Spatial computing

### 5. Agent Library
- Browse all 61 agents
- Search by specialty
- View agent details (personality, workflow, deliverables)
- Favorite agents

---

## All 61 Agents

### 💻 Engineering Division

| Agent | Specialty |
|-------|-----------|
| 🎨 Frontend Developer | React/Vue/Angular, UI implementation, performance |
| 🏗️ Backend Architect | API design, database architecture, scalability |
| 📱 Mobile App Builder | iOS/Android, React Native, Flutter |
| 🤖 AI Engineer | ML models, deployment, AI integration |
| 🚀 DevOps Automator | CI/CD, infrastructure automation, cloud ops |
| ⚡ Rapid Prototyper | Fast POC development, MVPs |
| 💎 Senior Developer | Laravel/Livewire, advanced patterns |
| 🔒 Security Engineer | Threat modeling, secure code review |

### 🎨 Design Division

| Agent | Specialty |
|-------|-----------|
| 🎯 UI Designer | Visual design, component libraries, design systems |
| 🔍 UX Researcher | User testing, behavior analysis, research |
| 🏛️ UX Architect | Technical architecture, CSS systems, implementation |
| 🎭 Brand Guardian | Brand identity, consistency, positioning |
| 📖 Visual Storyteller | Visual narratives, multimedia content |
| ✨ Whimsy Injector | Personality, delight, playful interactions |
| 📷 Image Prompt Engineer | AI image generation prompts, photography |

### 📢 Marketing Division

| Agent | Specialty |
|-------|-----------|
| 🚀 Growth Hacker | Rapid user acquisition, viral loops, experiments |
| 📝 Content Creator | Multi-platform content, editorial calendars |
| 🐦 Twitter Engager | Real-time engagement, thought leadership |
| 🎵 TikTok Strategist | Viral content, algorithm optimization |
| 📸 Instagram Curator | Visual storytelling, community building |
| 🤝 Reddit Community Builder | Authentic engagement, value-driven content |
| 📱 App Store Optimizer | ASO, conversion optimization, discoverability |
| 🌐 Social Media Strategist | Cross-platform strategy, campaigns |
| 📕 Xiaohongshu Specialist | Lifestyle content, Chinese social |
| 💬 WeChat Manager | WeChat Official Account, subscriber engagement |
| 🧠 Zhihu Strategist | Thought leadership, Q&A authority |

### 📊 Product Division

| Agent | Specialty |
|-------|-----------|
| 🎯 Sprint Prioritizer | Agile planning, feature prioritization |
| 🔍 Trend Researcher | Market intelligence, competitive analysis |
| 💬 Feedback Synthesizer | User feedback analysis, insights extraction |

### 🎬 Project Management Division

| Agent | Specialty |
|-------|-----------|
| 🎬 Studio Producer | High-level orchestration, portfolio management |
| 🐑 Project Shepherd | Cross-functional coordination, timeline management |
| ⚙️ Studio Operations | Day-to-day efficiency, process optimization |
| 🧪 Experiment Tracker | A/B tests, hypothesis validation |
| 👔 Senior PM | Realistic scoping, task conversion |

### 🧪 Testing Division

| Agent | Specialty |
|-------|-----------|
| 📸 Evidence Collector | Screenshot-based QA, visual proof |
| 🔍 Reality Checker | Evidence-based certification, quality gates |
| 📊 Test Results Analyzer | Test evaluation, metrics analysis |
| ⚡ Performance Benchmarker | Performance testing, optimization |
| 🔌 API Tester | API validation, integration testing |
| 🛠️ Tool Evaluator | Technology assessment, tool selection |
| 🔄 Workflow Optimizer | Process analysis, workflow improvement |
| ♿ Accessibility Auditor | WCAG auditing, assistive technology testing |

### 🛟 Support Division

| Agent | Specialty |
|-------|-----------|
| 💬 Support Responder | Customer service, issue resolution |
| 📊 Analytics Reporter | Data analysis, dashboards, insights |
| 💰 Finance Tracker | Financial planning, budget management |
| 🏗️ Infrastructure Maintainer | System reliability, performance optimization |
| ⚖️ Legal Compliance Checker | Compliance, regulations, legal review |
| 📑 Executive Summary Generator | C-suite communication, strategic summaries |

### 🥽 Spatial Computing Division

| Agent | Specialty |
|-------|-----------|
| 🏗️ XR Interface Architect | Spatial interaction design, immersive UX |
| 💻 macOS Spatial/Metal Engineer | Swift, Metal, high-performance 3D |
| 🌐 XR Immersive Developer | WebXR, browser-based AR/VR |
| 🎮 XR Cockpit Specialist | Cockpit-based controls, immersive systems |
| 🍎 visionOS Engineer | Apple Vision Pro development |
| 🔌 Terminal Integration Specialist | Terminal integration, command-line tools |

### 🎯 Specialized Division

| Agent | Specialty |
|-------|-----------|
| 🎭 Agents Orchestrator | Multi-agent coordination, workflow management |
| 📊 Data Analytics Reporter | Business intelligence, data insights |
| 🔍 LSP/Index Engineer | Language Server Protocol, code intelligence |
| 📥 Sales Data Extraction | Excel monitoring, sales metric extraction |
| 📈 Data Consolidation | Sales data aggregation, dashboard reports |
| 📬 Report Distribution | Automated report delivery |
| 🔐 Agentic Identity & Trust Architect | Agent identity, authentication, trust verification |

---

## Usage in Chat

### Activate a Single Agent

**Method 1:** Type "activate [agent name]"
```
activate Frontend Developer
```

**Method 2:** Use the agent selector button (🧠) in chat

**Method 3:** Browse the Agent Library

### Use Multi-Agent Mode

**Method 1:** Type "multi-agent" or "team"
```
multi-agent
```

**Method 2:** Tap the group icon (👥) in chat

### Browse All Agents

Type "show agents" or "agent library"
```
show agents
```

### Deactivate Agent Mode

Type "deactivate" or "stop agent"
```
deactivate
```

---

## Technical Implementation

### Files Created

| File | Purpose |
|------|---------|
| `lib/models/agent_personality.dart` | Agent personality model & enums |
| `lib/data/agency_agents.dart` | All 61 agent definitions |
| `lib/services/agent_personality_service.dart` | Agent mode management service |
| `lib/screens/agent_library_screen.dart` | Browse all agents |
| `lib/screens/agent_selector_screen.dart` | Select agent for task |
| `lib/screens/agent_detail_screen.dart` | Agent detail view |
| `lib/screens/multi_agent_screen.dart` | Multi-agent orchestration |
| `lib/screens/chat_screen.dart` | Updated chat with agent support |

### Model: AgentPersonality

```dart
class AgentPersonality {
  final String id;
  final String name;
  final String shortDescription;
  final String fullDescription;
  final AgentDivision division;
  final String emoji;
  final String role;
  final List<String> specialties;
  final List<String> workflows;
  final List<String> deliverables;
  final List<String> successMetrics;
  final String communicationStyle;
  final String greeting;
  final Map<String, String> examplePhrases;
}
```

### Service: AgentPersonalityService

```dart
class AgentPersonalityService extends ChangeNotifier {
  // Single agent mode
  AgentPersonality? activeAgent;
  void activateAgent(AgentPersonality agent);
  void deactivateAgent();

  // Multi-agent mode
  bool isMultiAgentMode;
  List<AgentPersonality> activeMultiAgents;
  void activateMultiAgentMode(List<AgentPersonality> agents);
  void exitMultiAgentMode();

  // Favorites
  Set<String> favoriteAgentIds;
  void toggleFavorite(String agentId);

  // Query methods
  List<AgentPersonality> getAgentsByDivision(AgentDivision division);
  List<AgentPersonality> searchAgents(String query);
  List<AgentTemplate> templates;
}
```

---

## Division Colors

| Division | Color |
|----------|-------|
| Engineering | Blue (#2196F3) |
| Design | Purple (#9C27B0) |
| Marketing | Orange (#FF9800) |
| Product | Green (#4CAF50) |
| Project Management | Pink (#E91E63) |
| Testing | Cyan (#00BCD4) |
| Support | Brown (#795548) |
| Spatial Computing | Blue Grey (#607D8B) |
| Specialized | Yellow (#FFEB3B) |

---

## Examples

### Single Agent Activation

```
User: activate Frontend Developer
Bot: 🤖 Switching to 🎨 Frontend Developer mode!
     👋 Ready to build beautiful, performant UIs! What are we creating today?

User: build a login form
Bot: 🎨 I'll create a responsive login component with proper validation.
```

### Multi-Agent Team

```
User: multi-agent
Bot: (opens multi-agent screen)

User: adds Frontend Developer, UI Designer, Growth Hacker
Bot: 🎭 Multi-agent team activated!
     🎨 Frontend Developer, 🎯 UI Designer, 🚀 Growth Hacker

User: launch my app
Bot: 🎭 Team responding to: "launch my app"
     Coordinating 3 agents:
     - 🎨 Frontend Developer: Building the UI
     - 🎯 UI Designer: Creating visual assets
     - 🚀 Growth Hacker: Planning user acquisition
```

### Template Usage

```
User: I need to launch a new app
Bot: Try the "App Launch Team" template!
     Includes: Frontend Dev, Backend Architect, UI Designer, ASO, QA

User: use App Launch Team
Bot: 🎭 Multi-agent team activated!
     Team: Frontend Developer, Backend Architect, UI Designer, 
           App Store Optimizer, Evidence Collector
```

---

## Voice Commands

The agent system integrates with voice commands:

- **"Activate [agent]"** → Switch to specific agent mode
- **"Show agents"** → Open Agent Library
- **"Multi-agent"** → Open Multi-Agent screen
- **"Deactivate"** → Return to default DuckBot mode

---

## Credits

The Agency-Agents collection is maintained by [msitarzewski](https://github.com/msitarzewski/agency-agents) and licensed under MIT.

This mobile integration was created for DuckBot (OpenClaw).