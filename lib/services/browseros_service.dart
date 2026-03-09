import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mcp_client.dart';

/// BrowserOS-specific MCP client with all 31+ browser automation tools
class BrowserOsService {
  static const String _serverUrlKey = 'browseros_server_url';
  static const String _serverTokenKey = 'browseros_server_token';
  static const String _workflowsKey = 'browseros_workflows';
  static const String _scheduledTasksKey = 'browseros_scheduled_tasks';

  McpClient? _mcpClient;
  String? _serverUrl;
  String? _serverToken;
  List<McpTool> _cachedTools = [];

  bool get isConnected => _mcpClient?.isConnected ?? false;
  String? get serverUrl => _serverUrl;
  List<McpTool> get availableTools => _cachedTools;

  /// Initialize with saved settings or defaults
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverUrlKey) ?? 'http://localhost:9239';
    _serverToken = prefs.getString(_serverTokenKey);
    
    _mcpClient = McpClient(
      baseUrl: _serverUrl!,
      authToken: _serverToken,
    );
  }

  /// Save server configuration
  Future<void> saveConfig(String url, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_serverTokenKey, token);
    }
    
    _serverUrl = url;
    _serverToken = token;
    
    _mcpClient?.dispose();
    _mcpClient = McpClient(baseUrl: url, authToken: token);
  }

  /// Connect to BrowserOS MCP server
  Future<bool> connect() async {
    if (_mcpClient == null) {
      await initialize();
    }
    return await _mcpClient!.connect();
  }

  /// Test connection without full initialization
  Future<bool> testConnection() async {
    try {
      final client = McpClient(
        baseUrl: _serverUrl ?? 'http://localhost:9239',
        authToken: _serverToken,
      );
      final result = await client.testConnection();
      client.dispose();
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Load available tools from BrowserOS
  Future<List<McpTool>> loadTools() async {
    if (_mcpClient == null) {
      await connect();
    }
    
    _cachedTools = await _mcpClient!.listTools();
    return _cachedTools;
  }

  // ==================== Navigation & Tabs (8 tools) ====================
  
  /// Get the currently focused page/tab
  Future<McpToolResult> getActivePage() async {
    return await _mcpClient!.callTool('get_active_page', {});
  }

  /// List all open pages with title, URL, and tab ID
  Future<McpToolResult> listPages() async {
    return await _mcpClient!.callTool('list_pages', {});
  }

  /// Navigate to a URL, or go back/forward/reload
  Future<McpToolResult> navigatePage(String url, {String? action}) async {
    return await _mcpClient!.callTool('navigate_page', {
      'url': url,
      if (action != null) 'action': action,
    });
  }

  /// Open a new tab
  Future<McpToolResult> newPage(String url, {bool active = true}) async {
    return await _mcpClient!.callTool('new_page', {
      'url': url,
      'active': active,
    });
  }

  /// Open a hidden tab for background automation
  Future<McpToolResult> newHiddenPage(String url) async {
    return await _mcpClient!.callTool('new_hidden_page', {'url': url});
  }

  /// Restore a hidden page to visible state
  Future<McpToolResult> showPage(String pageId) async {
    return await _mcpClient!.callTool('show_page', {'pageId': pageId});
  }

  /// Move a tab to a different window or position
  Future<McpToolResult> movePage(String pageId, {int? windowId, int? position}) async {
    return await _mcpClient!.callTool('move_page', {
      'pageId': pageId,
      if (windowId != null) 'windowId': windowId,
      if (position != null) 'position': position,
    });
  }

  /// Close a tab
  Future<McpToolResult> closePage(String pageId) async {
    return await _mcpClient!.callTool('close_page', {'pageId': pageId});
  }

  // ==================== Content & Observation (8 tools) ====================

  /// Get accessibility tree with interactive element IDs
  Future<McpToolResult> takeSnapshot({String? pageId}) async {
    return await _mcpClient!.callTool('take_snapshot', {
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Get detailed accessibility tree with structural context
  Future<McpToolResult> takeEnhancedSnapshot({String? pageId}) async {
    return await _mcpClient!.callTool('take_enhanced_snapshot', {
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Extract page as clean Markdown
  Future<McpToolResult> getPageContent({String? pageId}) async {
    return await _mcpClient!.callTool('get_page_content', {
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Extract all links from a page
  Future<McpToolResult> getPageLinks({String? pageId}) async {
    return await _mcpClient!.callTool('get_page_links', {
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Get raw HTML DOM
  Future<McpToolResult> getDom({String? selector, String? pageId}) async {
    return await _mcpClient!.callTool('get_dom', {
      if (selector != null) 'selector': selector,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Search DOM by text, CSS selector, or XPath
  Future<McpToolResult> searchDom(String query, {String? type, String? pageId}) async {
    return await _mcpClient!.callTool('search_dom', {
      'query': query,
      if (type != null) 'type': type,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Capture page screenshot
  Future<McpToolResult> takeScreenshot({
    String? pageId, 
    String format = 'png',
    bool fullPage = false,
  }) async {
    return await _mcpClient!.callTool('take_screenshot', {
      if (pageId != null) 'pageId': pageId,
      'format': format,
      'fullPage': fullPage,
    });
  }

  /// Execute JavaScript in the page context
  Future<McpToolResult> evaluateScript(String expression, {String? pageId}) async {
    return await _mcpClient!.callTool('evaluate_script', {
      'expression': expression,
      if (pageId != null) 'pageId': pageId,
    });
  }

  // ==================== Interaction & Input (14 tools) ====================

  /// Click an element by ID from snapshot
  Future<McpToolResult> click(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('click', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Click at specific X,Y coordinates
  Future<McpToolResult> clickAt(int x, int y, {String? pageId}) async {
    return await _mcpClient!.callTool('click_at', {
      'x': x,
      'y': y,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Hover over an element
  Future<McpToolResult> hover(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('hover', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Focus an element
  Future<McpToolResult> focus(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('focus', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Type text into an input
  Future<McpToolResult> fill(String elementId, String text, {bool clear = false, String? pageId}) async {
    return await _mcpClient!.callTool('fill', {
      'elementId': elementId,
      'text': text,
      'clear': clear,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Clear text from input/textarea
  Future<McpToolResult> clear(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('clear', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Check a checkbox or radio button
  Future<McpToolResult> check(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('check', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Uncheck a checkbox
  Future<McpToolResult> uncheck(String elementId, {String? pageId}) async {
    return await _mcpClient!.callTool('uncheck', {
      'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Select a dropdown option
  Future<McpToolResult> selectOption(String elementId, String value, {String? pageId}) async {
    return await _mcpClient!.callTool('select_option', {
      'elementId': elementId,
      'value': value,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Press a key or key combination
  Future<McpToolResult> pressKey(String key, {String? pageId}) async {
    return await _mcpClient!.callTool('press_key', {
      'key': key,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Drag an element
  Future<McpToolResult> drag(String fromElementId, String toElementId, {String? pageId}) async {
    return await _mcpClient!.callTool('drag', {
      'fromElementId': fromElementId,
      'toElementId': toElementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Scroll page or element
  Future<McpToolResult> scroll(String direction, {int? pixels, String? elementId, String? pageId}) async {
    return await _mcpClient!.callTool('scroll', {
      'direction': direction,
      if (pixels != null) 'pixels': pixels,
      if (elementId != null) 'elementId': elementId,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Upload files to a file input
  Future<McpToolResult> uploadFile(String elementId, List<String> filePaths, {String? pageId}) async {
    return await _mcpClient!.callTool('upload_file', {
      'elementId': elementId,
      'filePaths': filePaths,
      if (pageId != null) 'pageId': pageId,
    });
  }

  /// Handle JavaScript dialogs
  Future<McpToolResult> handleDialog(bool accept, {String? text, String? pageId}) async {
    return await _mcpClient!.callTool('handle_dialog', {
      'accept': accept,
      if (text != null) 'text': text,
      if (pageId != null) 'pageId': pageId,
    });
  }

  // ==================== File & Export (3 tools) ====================

  /// Print page to PDF
  Future<McpToolResult> savePdf({String? pageId, String? path}) async {
    return await _mcpClient!.callTool('save_pdf', {
      if (pageId != null) 'pageId': pageId,
      if (path != null) 'path': path,
    });
  }

  /// Capture and save screenshot to disk
  Future<McpToolResult> saveScreenshot({String? pageId, String? path, String format = 'png'}) async {
    return await _mcpClient!.callTool('save_screenshot', {
      if (pageId != null) 'pageId': pageId,
      if (path != null) 'path': path,
      'format': format,
    });
  }

  /// Click element to trigger download and save
  Future<McpToolResult> downloadFile(String elementId, {String? path, String? pageId}) async {
    return await _mcpClient!.callTool('download_file', {
      'elementId': elementId,
      if (path != null) 'path': path,
      if (pageId != null) 'pageId': pageId,
    });
  }

  // ==================== Workflow Management ====================

  /// Get saved workflows
  Future<List<BrowserWorkflow>> getWorkflows() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_workflowsKey);
    if (json == null) return [];
    
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((w) => BrowserWorkflow.fromJson(w)).toList();
  }

  /// Save a workflow
  Future<void> saveWorkflow(BrowserWorkflow workflow) async {
    final workflows = await getWorkflows();
    workflows.removeWhere((w) => w.id == workflow.id);
    workflows.add(workflow);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _workflowsKey,
      jsonEncode(workflows.map((w) => w.toJson()).toList()),
    );
  }

  /// Delete a workflow
  Future<void> deleteWorkflow(String id) async {
    final workflows = await getWorkflows();
    workflows.removeWhere((w) => w.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _workflowsKey,
      jsonEncode(workflows.map((w) => w.toJson()).toList()),
    );
  }

  /// Run a saved workflow
  Future<McpToolResult> runWorkflow(BrowserWorkflow workflow) async {
    // Execute each step in the workflow
    for (final step in workflow.steps) {
      final result = await _mcpClient!.callTool(step['tool'] as String, step['arguments'] ?? {});
      if (!result.success) {
        return result;
      }
    }
    return McpToolResult(success: true, content: 'Workflow completed');
  }

  // ==================== Scheduled Tasks ====================

  /// Get saved scheduled tasks
  Future<List<ScheduledTask>> getScheduledTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_scheduledTasksKey);
    if (json == null) return [];
    
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((t) => ScheduledTask.fromJson(t)).toList();
  }

  /// Save a scheduled task
  Future<void> saveScheduledTask(ScheduledTask task) async {
    final tasks = await getScheduledTasks();
    tasks.removeWhere((t) => t.id == task.id);
    tasks.add(task);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduledTasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  /// Delete a scheduled task
  Future<void> deleteScheduledTask(String id) async {
    final tasks = await getScheduledTasks();
    tasks.removeWhere((t) => t.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduledTasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  /// Toggle task enabled state
  Future<void> toggleScheduledTask(String id, bool enabled) async {
    final tasks = await getScheduledTasks();
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(enabled: enabled);
      await saveScheduledTask(tasks[index]);
    }
  }

  void dispose() {
    _mcpClient?.dispose();
  }
}

/// Represents a saved workflow
class BrowserWorkflow {
  final String id;
  final String name;
  final String description;
  final List<Map<String, dynamic>> steps;
  final DateTime createdAt;
  final bool isPreset;

  BrowserWorkflow({
    required this.id,
    required this.name,
    this.description = '',
    required this.steps,
    required this.createdAt,
    this.isPreset = false,
  });

  factory BrowserWorkflow.fromJson(Map<String, dynamic> json) {
    return BrowserWorkflow(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      steps: List<Map<String, dynamic>>.from(json['steps'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      isPreset: json['isPreset'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'steps': steps,
    'createdAt': createdAt.toIso8601String(),
    'isPreset': isPreset,
  };

  BrowserWorkflow copyWith({
    String? id,
    String? name,
    String? description,
    List<Map<String, dynamic>>? steps,
    DateTime? createdAt,
    bool? isPreset,
  }) {
    return BrowserWorkflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      isPreset: isPreset ?? this.isPreset,
    );
  }
}

/// Represents a scheduled task
class ScheduledTask {
  final String id;
  final String name;
  final String workflowId;
  final String schedule; // cron expression or interval
  final bool enabled;
  final DateTime? lastRun;
  final DateTime createdAt;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.workflowId,
    required this.schedule,
    this.enabled = true,
    this.lastRun,
    required this.createdAt,
  });

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: json['id'],
      name: json['name'],
      workflowId: json['workflowId'],
      schedule: json['schedule'],
      enabled: json['enabled'] ?? true,
      lastRun: json['lastRun'] != null ? DateTime.parse(json['lastRun']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'workflowId': workflowId,
    'schedule': schedule,
    'enabled': enabled,
    'lastRun': lastRun?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  ScheduledTask copyWith({
    String? id,
    String? name,
    String? workflowId,
    String? schedule,
    bool? enabled,
    DateTime? lastRun,
    DateTime? createdAt,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      name: name ?? this.name,
      workflowId: workflowId ?? this.workflowId,
      schedule: schedule ?? this.schedule,
      enabled: enabled ?? this.enabled,
      lastRun: lastRun ?? this.lastRun,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get human-readable schedule description
  String get scheduleDescription {
    if (schedule.startsWith('interval:')) {
      final minutes = schedule.replaceFirst('interval:', '');
      return 'Every $minutes minutes';
    }
    if (schedule.startsWith('daily:')) {
      final time = schedule.replaceFirst('daily:', '');
      return 'Daily at $time';
    }
    if (schedule.startsWith('weekly:')) {
      final parts = schedule.replaceFirst('weekly:', '').split(':');
      return 'Every ${parts[0]} at ${parts[1]}';
    }
    return schedule;
  }
}

/// Pre-built workflow templates for mobile
class WorkflowTemplates {
  static List<BrowserWorkflow> get presets => [
    BrowserWorkflow(
      id: 'preset_google_search',
      name: 'Quick Google Search',
      description: 'Search Google for a query',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'navigate_page', 'arguments': {'url': 'https://google.com'}},
        {'tool': 'fill', 'arguments': {'elementId': 'q', 'text': '{{query}}', 'clear': true}},
        {'tool': 'press_key', 'arguments': {'key': 'Enter'}},
      ],
    ),
    BrowserWorkflow(
      id: 'preset_youtube_search',
      name: 'YouTube Search',
      description: 'Search YouTube for videos',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'navigate_page', 'arguments': {'url': 'https://youtube.com'}},
        {'tool': 'fill', 'arguments': {'elementId': 'search', 'text': '{{query}}', 'clear': true}},
        {'tool': 'press_key', 'arguments': {'key': 'Enter'}},
      ],
    ),
    BrowserWorkflow(
      id: 'preset_screenshot',
      name: 'Take Screenshot',
      description: 'Capture current page screenshot',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'take_screenshot', 'arguments': {'format': 'png', 'fullPage': false}},
      ],
    ),
    BrowserWorkflow(
      id: 'preset_extract_links',
      name: 'Extract Page Links',
      description: 'Get all links from current page',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'get_page_links', 'arguments': {}},
      ],
    ),
    BrowserWorkflow(
      id: 'preset_fill_form',
      name: 'Fill Form Field',
      description: 'Fill a form input field',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'fill', 'arguments': {'elementId': '{{fieldId}}', 'text': '{{value}}', 'clear': true}},
      ],
    ),
    BrowserWorkflow(
      id: 'preset_scroll_down',
      name: 'Scroll Down',
      description: 'Scroll page down',
      isPreset: true,
      createdAt: DateTime.now(),
      steps: [
        {'tool': 'scroll', 'arguments': {'direction': 'down', 'pixels': 500}},
      ],
    ),
  ];
}