import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'gateway_service.dart';

class OpenClawCompanionConfig {
  final String gatewayEndpoint;
  final String? gatewayToken;
  final String nodeDisplayName;
  final int localPort;

  const OpenClawCompanionConfig({
    required this.gatewayEndpoint,
    this.gatewayToken,
    this.nodeDisplayName = OpenClawCompanionService.defaultNodeDisplayName,
    this.localPort = OpenClawCompanionService.defaultPort,
  });

  String get normalizedGatewayWsUrl =>
      OpenClawCompanionService.normalizeGatewayWsUrl(gatewayEndpoint);

  String get normalizedGatewayHttpUrl =>
      OpenClawCompanionService.normalizeGatewayHttpUrl(gatewayEndpoint);

  OpenClawCompanionConfig copyWith({
    String? gatewayEndpoint,
    String? gatewayToken,
    String? nodeDisplayName,
    int? localPort,
  }) {
    return OpenClawCompanionConfig(
      gatewayEndpoint: gatewayEndpoint ?? this.gatewayEndpoint,
      gatewayToken: gatewayToken ?? this.gatewayToken,
      nodeDisplayName: nodeDisplayName ?? this.nodeDisplayName,
      localPort: localPort ?? this.localPort,
    );
  }
}

class OpenClawCompanionRuntimeStatus {
  final bool bridgeReachable;
  final bool gatewayReachable;
  final bool nodeConfigured;
  final bool nodeConnected;
  final Map<String, dynamic>? payload;
  final String? error;

  const OpenClawCompanionRuntimeStatus({
    required this.bridgeReachable,
    required this.gatewayReachable,
    required this.nodeConfigured,
    required this.nodeConnected,
    this.payload,
    this.error,
  });
}

class OpenClawCompanionService {
  static const int defaultPort = 18989;
  static const String defaultNodeDisplayName = 'DuckBot Android Node';
  static const String _gatewayEndpointKey = 'openclaw_companion_gateway_endpoint';
  static const String _gatewayTokenKey = 'openclaw_companion_gateway_token';
  static const String _nodeDisplayNameKey =
      'openclaw_companion_node_display_name';
  static const String _localPortKey = 'openclaw_companion_local_port';
  static const String _companionName = 'DuckBot OpenClaw Companion';

  String get baseUrl => 'http://127.0.0.1:$defaultPort';

  Future<OpenClawCompanionConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return OpenClawCompanionConfig(
      gatewayEndpoint:
          prefs.getString(_gatewayEndpointKey) ?? 'ws://127.0.0.1:18789',
      gatewayToken: prefs.getString(_gatewayTokenKey),
      nodeDisplayName:
          prefs.getString(_nodeDisplayNameKey) ?? defaultNodeDisplayName,
      localPort: prefs.getInt(_localPortKey) ?? defaultPort,
    );
  }

  Future<void> saveConfig(OpenClawCompanionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gatewayEndpointKey,
      normalizeGatewayWsUrl(config.gatewayEndpoint),
    );
    await prefs.setInt(_localPortKey, config.localPort);
    await prefs.setString(_nodeDisplayNameKey, config.nodeDisplayName.trim());

    final token = config.gatewayToken?.trim();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_gatewayTokenKey, token);
    } else {
      await prefs.remove(_gatewayTokenKey);
    }
  }

  Future<void> useCompanionAsGateway() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gateway_url', baseUrl);
    await prefs.setString('gateway_name', _companionName);
    await prefs.remove('gateway_token');
    await prefs.setBool('has_completed_setup', true);
  }

  Future<OpenClawCompanionRuntimeStatus> getRuntimeStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/companion/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return const OpenClawCompanionRuntimeStatus(
          bridgeReachable: false,
          gatewayReachable: false,
          nodeConfigured: false,
          nodeConnected: false,
          error: 'Companion bridge is not responding',
        );
      }

      final payload =
          jsonDecode(response.body) as Map<String, dynamic>? ?? const {};
      final gateway = payload['gateway'] as Map<String, dynamic>?;
      final node = payload['node'] as Map<String, dynamic>?;
      final nodeRaw = node?['raw'] as Map<String, dynamic>?;
      final statusText = (nodeRaw?['status'] ?? node?['status'] ?? '')
          .toString()
          .toLowerCase();

      return OpenClawCompanionRuntimeStatus(
        bridgeReachable: true,
        gatewayReachable: gateway?['reachable'] == true,
        nodeConfigured: node?['configured'] == true || node?['installed'] == true,
        nodeConnected: node?['connected'] == true ||
            statusText.contains('running') ||
            statusText.contains('connected'),
        payload: payload,
      );
    } catch (e) {
      return OpenClawCompanionRuntimeStatus(
        bridgeReachable: false,
        gatewayReachable: false,
        nodeConfigured: false,
        nodeConnected: false,
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> checkGatewayThroughCompanion() async {
    final service = GatewayService(baseUrl: baseUrl);
    return await service.checkConnection();
  }

  String buildInstallScript(OpenClawCompanionConfig config) {
    final companionConfigJson = const JsonEncoder.withIndent('  ').convert({
      'name': _companionName,
      'gatewayWsUrl': normalizeGatewayWsUrl(config.gatewayEndpoint),
      'gatewayHttpUrl': normalizeGatewayHttpUrl(config.gatewayEndpoint),
      'nodeDisplayName': config.nodeDisplayName.trim(),
      'port': config.localPort,
      'installedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final remoteConfigCommands = _buildRemoteConfigCommands(config);

    return '''
set -e
pkg update -y && pkg upgrade -y
pkg install -y nodejs termux-api
termux-setup-storage || true
npm install -g openclaw --unsafe-perm
mkdir -p ~/.duckbot-go/openclaw-companion
cat > ~/.duckbot-go/openclaw-companion/config.json <<'EOF'
$companionConfigJson
EOF
cat > ~/.duckbot-go/openclaw-companion/server.mjs <<'EOF'
$_bridgeScript
EOF
chmod +x ~/.duckbot-go/openclaw-companion/server.mjs
$remoteConfigCommands
''';
  }

  String buildStartScript({int port = defaultPort}) {
    return '''
set -e
mkdir -p ~/.duckbot-go/openclaw-companion
if [ -f ~/.duckbot-go/openclaw-companion/bridge.pid ] && kill -0 "\$(cat ~/.duckbot-go/openclaw-companion/bridge.pid)" 2>/dev/null; then
  echo "DuckBot OpenClaw Companion already running"
  exit 0
fi
nohup env DUCKBOT_OPENCLAW_COMPANION_PORT=$port node ~/.duckbot-go/openclaw-companion/server.mjs >> ~/.duckbot-go/openclaw-companion/bridge.log 2>&1 &
echo \$! > ~/.duckbot-go/openclaw-companion/bridge.pid
sleep 1
''';
  }

  String buildStopScript() {
    return '''
set -e
if [ -f ~/.duckbot-go/openclaw-companion/bridge.pid ]; then
  pid="\$(cat ~/.duckbot-go/openclaw-companion/bridge.pid)"
  if kill -0 "\$pid" 2>/dev/null; then
    kill "\$pid"
  fi
  rm -f ~/.duckbot-go/openclaw-companion/bridge.pid
fi
pkill -f "openclaw-companion/server.mjs" 2>/dev/null || true
''';
  }

  String buildNodeInstallScript(OpenClawCompanionConfig config) {
    final gatewayUri = Uri.parse(config.normalizedGatewayWsUrl);
    final tlsFlag = gatewayUri.scheme == 'wss' ? '--tls' : '';
    final host = gatewayUri.host;
    final port = gatewayUri.hasPort ? gatewayUri.port : 18789;
    final safeDisplayName = _shellSingleQuote(config.nodeDisplayName.trim());

    return '''
set -e
${_buildRemoteConfigCommands(config)}
openclaw node install --host $host --port $port $tlsFlag --display-name '$safeDisplayName' --runtime node --force
''';
  }

  String buildNodeRunScript(OpenClawCompanionConfig config) {
    final gatewayUri = Uri.parse(config.normalizedGatewayWsUrl);
    final tlsFlag = gatewayUri.scheme == 'wss' ? '--tls' : '';
    final host = gatewayUri.host;
    final port = gatewayUri.hasPort ? gatewayUri.port : 18789;
    final safeDisplayName = _shellSingleQuote(config.nodeDisplayName.trim());

    return '''
set -e
${_buildRemoteConfigCommands(config)}
nohup openclaw node run --host $host --port $port $tlsFlag --display-name '$safeDisplayName' >> ~/.duckbot-go/openclaw-companion/node.log 2>&1 &
echo \$! > ~/.duckbot-go/openclaw-companion/node.pid
sleep 1
''';
  }

  String buildNodeStopScript() {
    return '''
set -e
openclaw node stop 2>/dev/null || true
if [ -f ~/.duckbot-go/openclaw-companion/node.pid ]; then
  pid="\$(cat ~/.duckbot-go/openclaw-companion/node.pid)"
  if kill -0 "\$pid" 2>/dev/null; then
    kill "\$pid"
  fi
  rm -f ~/.duckbot-go/openclaw-companion/node.pid
fi
''';
  }

  String buildConfigureScript(OpenClawCompanionConfig config) {
    return _buildRemoteConfigCommands(config);
  }

  String buildUseCompanionHint() =>
      'Set DuckBot to $baseUrl after the bridge is running.';

  String _buildRemoteConfigCommands(OpenClawCompanionConfig config) {
    final wsUrl = normalizeGatewayWsUrl(config.gatewayEndpoint);
    final token = config.gatewayToken?.trim();

    final commands = <String>[
      'openclaw config set gateway.mode remote',
      'openclaw config set gateway.remote.transport direct',
      "openclaw config set gateway.remote.url '${_shellSingleQuote(wsUrl)}'",
    ];

    if (token != null && token.isNotEmpty) {
      commands.add(
        "openclaw config set gateway.remote.token '${_shellSingleQuote(token)}'",
      );
    } else {
      commands.add('openclaw config unset gateway.remote.token || true');
    }

    commands.add('openclaw config unset gateway.remote.password || true');
    return commands.join('\n');
  }

  static String normalizeGatewayWsUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'ws://127.0.0.1:18789';
    }

    final withScheme = trimmed.contains('://')
        ? trimmed
        : '${_isLoopbackLike(trimmed) ? 'ws' : 'wss'}://$trimmed';
    final parsed = Uri.parse(withScheme);
    final scheme = switch (parsed.scheme) {
      'http' => 'ws',
      'https' => 'wss',
      'ws' => 'ws',
      'wss' => 'wss',
      _ => _isLoopbackLike(parsed.host) ? 'ws' : 'wss',
    };
    final port = parsed.hasPort ? parsed.port : 18789;
    return parsed
        .replace(
          scheme: scheme,
          port: port,
          path: '',
          queryParameters: null,
          fragment: null,
        )
        .toString();
  }

  static String normalizeGatewayHttpUrl(String input) {
    final wsUrl = normalizeGatewayWsUrl(input);
    final parsed = Uri.parse(wsUrl);
    final scheme = parsed.scheme == 'wss' ? 'https' : 'http';
    return parsed
        .replace(
          scheme: scheme,
          path: '',
          queryParameters: null,
          fragment: null,
        )
        .toString();
  }

  static bool _isLoopbackLike(String value) {
    final host = value.contains('://')
        ? Uri.parse(value).host
        : value.split('/').first.split(':').first;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }

  String _shellSingleQuote(String value) =>
      value.replaceAll("'", "'\"'\"'");

  static const String _bridgeScript = r'''#!/usr/bin/env node
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import fs from "node:fs";
import { promises as fsp } from "node:fs";

const HOME = process.env.HOME || "/data/data/com.termux/files/home";
const BASE_DIR = path.join(HOME, ".duckbot-go", "openclaw-companion");
const CONFIG_PATH = path.join(BASE_DIR, "config.json");
const LOG_PATH = path.join(BASE_DIR, "bridge.log");
const PID_PATH = path.join(BASE_DIR, "bridge.pid");
const DEFAULT_PORT = Number(process.env.DUCKBOT_OPENCLAW_COMPANION_PORT || "18989");

function now() {
  return new Date().toISOString();
}

async function ensureBaseDir() {
  await fsp.mkdir(BASE_DIR, { recursive: true });
}

async function readConfig() {
  await ensureBaseDir();
  try {
    const raw = await fsp.readFile(CONFIG_PATH, "utf8");
    const parsed = JSON.parse(raw);
    return {
      name: typeof parsed.name === "string" ? parsed.name : "DuckBot OpenClaw Companion",
      gatewayWsUrl: typeof parsed.gatewayWsUrl === "string" ? parsed.gatewayWsUrl : "ws://127.0.0.1:18789",
      gatewayHttpUrl:
        typeof parsed.gatewayHttpUrl === "string" ? parsed.gatewayHttpUrl : "http://127.0.0.1:18789",
      nodeDisplayName:
        typeof parsed.nodeDisplayName === "string" ? parsed.nodeDisplayName : "DuckBot Android Node",
      port:
        typeof parsed.port === "number" && Number.isFinite(parsed.port) ? parsed.port : DEFAULT_PORT,
      installedAt: typeof parsed.installedAt === "string" ? parsed.installedAt : null,
    };
  } catch (_error) {
    return {
      name: "DuckBot OpenClaw Companion",
      gatewayWsUrl: "ws://127.0.0.1:18789",
      gatewayHttpUrl: "http://127.0.0.1:18789",
      nodeDisplayName: "DuckBot Android Node",
      port: DEFAULT_PORT,
      installedAt: null,
    };
  }
}

function execOpenClaw(args, { timeoutMs = 25000, allowFailure = false } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn("openclaw", args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });

    let stdout = "";
    let stderr = "";
    let killedByTimeout = false;
    const timer = setTimeout(() => {
      killedByTimeout = true;
      child.kill("SIGTERM");
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      if (killedByTimeout) {
        reject(new Error(`openclaw ${args.join(" ")} timed out after ${timeoutMs}ms`));
        return;
      }
      const trimmedStdout = stdout.trim();
      const trimmedStderr = stderr.trim();
      let data = null;
      if (trimmedStdout) {
        try {
          data = JSON.parse(trimmedStdout);
        } catch (_error) {
          data = null;
        }
      }
      if (code === 0 || allowFailure) {
        resolve({
          ok: code === 0,
          code,
          stdout: trimmedStdout,
          stderr: trimmedStderr,
          data,
        });
        return;
      }
      reject(
        new Error(
          trimmedStderr ||
            trimmedStdout ||
            `openclaw ${args.join(" ")} failed with exit code ${code ?? "unknown"}`,
        ),
      );
    });
  });
}

function normalizeSessions(value) {
  const sessions = Array.isArray(value?.sessions)
    ? value.sessions
    : Array.isArray(value?.result?.sessions)
      ? value.result.sessions
      : [];

  return sessions.map((entry, index) => {
    const item = entry && typeof entry === "object" ? entry : {};
    const key =
      item.key ??
      item.sessionKey ??
      item.session_key ??
      item.id ??
      item.sessionId ??
      `session-${index}`;
    const status = String(item.status ?? item.agentStatus ?? "idle");
    const kind = String(item.kind ?? "agent");
    return {
      id: item.id ?? item.sessionId ?? key,
      key,
      name: item.name ?? item.agent ?? item.displayName ?? "Agent",
      label: item.label,
      displayName: item.displayName,
      derivedTitle: item.derivedTitle,
      lastMessagePreview: item.lastMessagePreview ?? item.latest_message,
      status,
      agentStatus: item.agentStatus ?? status,
      statusSummary: item.statusSummary ?? item.currentToolName ?? status,
      currentToolName: item.currentToolName,
      currentToolPhase: item.currentToolPhase,
      isActive: item.isActive === true || status === "active" || status === "busy",
      isSubagent: item.isSubagent === true || kind === "subagent" || String(key).includes(":subagent:"),
      kind,
      channel: item.channel ?? "default",
      model: item.model ?? "unknown",
      modelProvider: item.modelProvider ?? item.provider,
      inputTokens: Number(item.inputTokens ?? 0),
      outputTokens: Number(item.outputTokens ?? 0),
      totalTokens: Number(item.totalTokens ?? item.total_tokens ?? 0),
      contextTokens: Number(item.contextTokens ?? 0),
      updatedAt: item.updatedAt ?? null,
      avatarUrl: item.avatarUrl ?? null,
      identityTheme: item.identityTheme ?? null,
      subagentIds: Array.isArray(item.subagentIds) ? item.subagentIds : [],
    };
  });
}

function normalizeNodes(value) {
  const nodes = Array.isArray(value?.nodes)
    ? value.nodes
    : Array.isArray(value?.result?.nodes)
      ? value.result.nodes
      : [];

  return nodes.map((entry, index) => {
    const item = entry && typeof entry === "object" ? entry : {};
    return {
      id: item.id ?? item.nodeId ?? `node-${index}`,
      name: item.name ?? item.displayName ?? item.nodeId ?? "Node",
      status: item.status ?? (item.connected === true ? "connected" : "unknown"),
      connected: item.connected === true,
      connectionType: item.connectionType ?? item.connection_type ?? item.transport,
      ip: item.ip ?? item.address,
      platform: item.platform,
      lastSeenAt: item.lastSeenAt ?? item.updatedAt ?? null,
      raw: item,
    };
  });
}

function normalizeMessages(value) {
  const list = Array.isArray(value?.messages)
    ? value.messages
    : Array.isArray(value?.result?.messages)
      ? value.result.messages
      : Array.isArray(value?.history)
        ? value.history
        : [];

  return list.map((entry, index) => {
    const item = entry && typeof entry === "object" ? entry : {};
    const content = Array.isArray(item.content)
      ? item.content
      : typeof item.message === "string"
        ? [{ type: "text", text: item.message }]
        : typeof item.text === "string"
          ? [{ type: "text", text: item.text }]
          : [];
    return {
      id: item.id ?? `msg-${index}`,
      role: item.role ?? item.sender ?? "assistant",
      content,
      timestamp: item.timestamp ?? item.createdAt ?? item.updatedAt ?? now(),
      metadata: item.metadata ?? {},
    };
  });
}

async function readTail(filePath, limit) {
  try {
    const content = await fsp.readFile(filePath, "utf8");
    return content
      .split("\n")
      .filter(Boolean)
      .slice(Math.max(0, limit * -1));
  } catch (_error) {
    return [];
  }
}

async function gatewayHealthProbe() {
  try {
    const response = await execOpenClaw(["gateway", "health", "--json", "--timeout", "8000"], {
      timeoutMs: 9000,
    });
    return {
      reachable: true,
      payload: response.data ?? { ok: true, stdout: response.stdout },
    };
  } catch (error) {
    return {
      reachable: false,
      error: String(error),
      payload: null,
    };
  }
}

async function gatewaySnapshot() {
  const config = await readConfig();
  const health = await gatewayHealthProbe();
  if (!health.reachable) {
    return {
      ok: false,
      config,
      error: health.error ?? "Gateway health probe failed",
      sessions: [],
      nodes: [],
      health: null,
    };
  }

  const [sessionsResult, nodesResult] = await Promise.allSettled([
    execOpenClaw(["gateway", "call", "sessions.list", "--params", "{\"limit\":200}", "--json", "--timeout", "12000"], {
      timeoutMs: 13000,
    }),
    execOpenClaw(["gateway", "call", "node.list", "--params", "{}", "--json", "--timeout", "12000"], {
      timeoutMs: 13000,
      allowFailure: true,
    }),
  ]);

  const sessionsPayload =
    sessionsResult.status === "fulfilled" ? sessionsResult.value.data ?? {} : {};
  const nodesPayload =
    nodesResult.status === "fulfilled" ? nodesResult.value.data ?? {} : {};

  return {
    ok: true,
    config,
    health: health.payload,
    sessions: normalizeSessions(sessionsPayload),
    nodes: normalizeNodes(nodesPayload),
  };
}

async function nodeStatusSnapshot() {
  try {
    const response = await execOpenClaw(["node", "status", "--json"], {
      timeoutMs: 10000,
      allowFailure: true,
    });
    const raw = response.data && typeof response.data === "object" ? response.data : {};
    const text = String(raw.status ?? response.stdout ?? response.stderr ?? "");
    return {
      installed: response.ok || text.length > 0,
      configured: response.ok || text.length > 0,
      connected: /running|connected|active/i.test(text),
      status: text || (response.ok ? "installed" : "unknown"),
      raw,
    };
  } catch (error) {
    return {
      installed: false,
      configured: false,
      connected: false,
      status: "unavailable",
      error: String(error),
      raw: {},
    };
  }
}

function writeJson(res, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type, authorization",
    "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  });
  res.end(payload);
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.from(chunk));
  }
  if (chunks.length === 0) {
    return {};
  }
  const raw = Buffer.concat(chunks).toString("utf8").trim();
  if (!raw) {
    return {};
  }
  return JSON.parse(raw);
}

async function handleAction(req, res) {
  const body = await readRequestBody(req);
  const action = String(body.action ?? "");
  const sessionKey = String(body.sessionKey ?? body.session_key ?? "main");

  if (action === "send") {
    const message = String(body.message ?? "");
    if (!message.trim()) {
      writeJson(res, 400, { ok: false, error: "Message is required" });
      return;
    }

    try {
      const payload = await execOpenClaw(
        [
          "gateway",
          "call",
          "chat.send",
          "--params",
          JSON.stringify({
            sessionKey,
            message,
            deliver: body.deliver === true,
            idempotencyKey: body.idempotencyKey ?? body.idempotency_key,
          }),
          "--json",
          "--timeout",
          "45000",
        ],
        { timeoutMs: 47000 },
      );
      writeJson(res, 200, {
        ok: true,
        sessionKey,
        result: payload.data ?? { ok: true, stdout: payload.stdout },
      });
      return;
    } catch (error) {
      writeJson(res, 502, {
        ok: false,
        error: String(error),
        sessionKey,
      });
      return;
    }
  }

  if (action === "history") {
    try {
      const payload = await execOpenClaw(
        [
          "gateway",
          "call",
          "chat.history",
          "--params",
          JSON.stringify({
            sessionKey,
            limit: Number(body.limit ?? 50),
          }),
          "--json",
          "--timeout",
          "15000",
        ],
        { timeoutMs: 17000 },
      );
      writeJson(res, 200, {
        ok: true,
        sessionKey,
        messages: normalizeMessages(payload.data ?? {}),
        result: payload.data ?? {},
      });
      return;
    } catch (error) {
      writeJson(res, 502, {
        ok: false,
        error: String(error),
        sessionKey,
      });
      return;
    }
  }

  if (action === "broadcast") {
    try {
      const sessionsResponse = await execOpenClaw(
        ["gateway", "call", "sessions.list", "--params", "{\"limit\":200}", "--json", "--timeout", "12000"],
        { timeoutMs: 13000 },
      );
      const allSessions = normalizeSessions(sessionsResponse.data ?? {});
      const sessionKeys = Array.isArray(body.sessionKeys) && body.sessionKeys.length > 0
        ? body.sessionKeys.map((value) => String(value))
        : allSessions.filter((item) => item.isSubagent !== true).map((item) => String(item.key));

      const message = String(body.message ?? "");
      const delivered = [];
      for (const key of sessionKeys) {
        try {
          await execOpenClaw(
            [
              "gateway",
              "call",
              "chat.send",
              "--params",
              JSON.stringify({
                sessionKey: key,
                message,
                deliver: false,
              }),
              "--json",
              "--timeout",
              "30000",
            ],
            { timeoutMs: 32000 },
          );
          delivered.push(key);
        } catch (_error) {
          // Continue to the next session and report partial success.
        }
      }

      writeJson(res, 200, {
        ok: delivered.length > 0,
        sent: delivered.length,
        sessionKeys: delivered,
      });
      return;
    } catch (error) {
      writeJson(res, 502, { ok: false, error: String(error) });
      return;
    }
  }

  writeJson(res, 400, {
    ok: false,
    error: `Unsupported action: ${action || "unknown"}`,
  });
}

async function handleGatewayStatus(res) {
  const snapshot = await gatewaySnapshot();
  if (!snapshot.ok) {
    writeJson(res, 503, {
      ok: false,
      status: "offline",
      error: snapshot.error,
      bridge: {
        ok: true,
        port: snapshot.config.port,
        target: snapshot.config.gatewayWsUrl,
      },
      sessions: [],
      nodes: [],
    });
    return;
  }

  writeJson(res, 200, {
    ok: true,
    status: "online",
    timestamp: now(),
    gateway: {
      status: "online",
      transport: "companion-http",
      target: snapshot.config.gatewayWsUrl,
    },
    sessions: snapshot.sessions,
    agents: snapshot.sessions,
    nodes: snapshot.nodes,
    result: {
      ok: true,
      gateway: {
        status: "online",
        transport: "companion-http",
        target: snapshot.config.gatewayWsUrl,
      },
      sessions: snapshot.sessions,
      nodes: snapshot.nodes,
      health: snapshot.health,
    },
  });
}

async function handleCompanionStatus(res) {
  const config = await readConfig();
  const [gateway, node] = await Promise.all([gatewaySnapshot(), nodeStatusSnapshot()]);
  const logs = await readTail(LOG_PATH, 60);
  writeJson(res, 200, {
    ok: true,
    timestamp: now(),
    bridge: {
      online: true,
      port: config.port,
      pid: process.pid,
      hostname: os.hostname(),
      uptimeSeconds: Math.floor(process.uptime()),
      target: config.gatewayWsUrl,
    },
    gateway: {
      reachable: gateway.ok,
      error: gateway.ok ? null : gateway.error,
      sessionCount: gateway.sessions.length,
      nodeCount: gateway.nodes.length,
      health: gateway.health,
    },
    node,
    config,
    logs,
  });
}

async function handleLogs(res, searchParams) {
  const limit = Number(searchParams.get("limit") ?? "100");
  const lines = await readTail(LOG_PATH, Number.isFinite(limit) ? limit : 100);
  writeJson(res, 200, {
    ok: true,
    logs: lines.map((line, index) => ({
      id: index,
      level: /error|failed|exception/i.test(line)
        ? "error"
        : /warn/i.test(line)
          ? "warning"
          : "info",
      message: line,
      timestamp: now(),
    })),
  });
}

async function main() {
  await ensureBaseDir();
  await fsp.writeFile(PID_PATH, String(process.pid));
  const config = await readConfig();

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url || "/", `http://127.0.0.1:${config.port}`);

      if (req.method === "OPTIONS") {
        writeJson(res, 200, { ok: true });
        return;
      }

      if (req.method === "GET" && (url.pathname === "/health" || url.pathname === "/api/health")) {
        const snapshot = await gatewaySnapshot();
        if (!snapshot.ok) {
          writeJson(res, 503, {
            ok: false,
            status: "offline",
            bridge: true,
            error: snapshot.error,
            target: snapshot.config.gatewayWsUrl,
          });
          return;
        }
        writeJson(res, 200, {
          ok: true,
          status: "live",
          transport: "companion-http",
          target: snapshot.config.gatewayWsUrl,
          sessionCount: snapshot.sessions.length,
          nodeCount: snapshot.nodes.length,
        });
        return;
      }

      if (req.method === "GET" && (url.pathname === "/api/gateway" || url.pathname === "/api/status" || url.pathname === "/status")) {
        await handleGatewayStatus(res);
        return;
      }

      if (req.method === "GET" && url.pathname === "/api/companion/status") {
        await handleCompanionStatus(res);
        return;
      }

      if (req.method === "GET" && url.pathname === "/api/logs") {
        await handleLogs(res, url.searchParams);
        return;
      }

      if (req.method === "POST" && url.pathname === "/api/gateway/action") {
        await handleAction(req, res);
        return;
      }

      if (req.method === "POST" && url.pathname === "/api/mobile/control/gateway/restart") {
        writeJson(res, 409, {
          ok: false,
          error:
            "Gateway restart is not exposed through the Android companion bridge. Restart the remote gateway on its host.",
        });
        return;
      }

      writeJson(res, 404, {
        ok: false,
        error: `Not found: ${req.method} ${url.pathname}`,
      });
    } catch (error) {
      writeJson(res, 500, {
        ok: false,
        error: String(error),
      });
    }
  });

  server.listen(config.port, "127.0.0.1", () => {
    fs.appendFileSync(LOG_PATH, `[${now()}] listening on http://127.0.0.1:${config.port}\n`);
  });

  const shutdown = async () => {
    try {
      await fsp.unlink(PID_PATH);
    } catch (_error) {
      // Ignore cleanup races.
    }
    process.exit(0);
  };

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

main().catch(async (error) => {
  await ensureBaseDir();
  fs.appendFileSync(LOG_PATH, `[${now()}] fatal: ${String(error)}\n`);
  process.exit(1);
});
''';
}
