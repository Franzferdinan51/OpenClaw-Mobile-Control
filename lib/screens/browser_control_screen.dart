import 'package:flutter/material.dart';
import '../services/browseros_service.dart';
import '../services/mcp_client.dart';

class BrowserControlScreen extends StatefulWidget {
  const BrowserControlScreen({super.key});

  @override
  State<BrowserControlScreen> createState() => _BrowserControlScreenState();
}

class _BrowserControlScreenState extends State<BrowserControlScreen> {
  final BrowserOsService _service = BrowserOsService();
  bool _isConnected = false;
  bool _isLoading = false;
  List<McpTool> _tools = [];
  String? _error;
  String _urlInput = '';
  String _elementId = '';
  String _textInput = '';
  List<BrowserPage> _pages = [];
  String _selectedPageId = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize();
      final connected = await _service.connect();
      if (connected) {
        await _loadTools();
        await _refreshPages();
      }
      setState(() {
        _isConnected = connected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTools() async {
    final tools = await _service.loadTools();
    setState(() => _tools = tools);
  }

  Future<void> _refreshPages() async {
    final result = await _service.listPages();
    if (result.success && result.content != null) {
      try {
        final content = result.content;
        if (content is List) {
          setState(() {
            _pages = content.map((p) => BrowserPage.fromJson(p)).toList();
          });
        } else if (content is Map && content['pages'] != null) {
          setState(() {
            _pages = (content['pages'] as List).map((p) => BrowserPage.fromJson(p)).toList();
          });
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browser Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Not Connected', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Make sure BrowserOS is running and accessible',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Default: http://localhost:9239',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildConnectionCard(),
        const SizedBox(height: 16),
        _buildQuickActionsCard(),
        const SizedBox(height: 16),
        _buildNavigationCard(),
        const SizedBox(height: 16),
        _buildInteractionCard(),
        const SizedBox(height: 16),
        _buildToolsCard(),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'BrowserOS Connected' : 'Not Connected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (_isConnected && _tools.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_tools.length} tools available',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  onTap: () => _executeQuickAction('navigate', {'action': 'reload'}),
                ),
                _buildQuickActionButton(
                  icon: Icons.arrow_back,
                  label: 'Back',
                  onTap: () => _executeQuickAction('navigate', {'action': 'back'}),
                ),
                _buildQuickActionButton(
                  icon: Icons.arrow_forward,
                  label: 'Forward',
                  onTap: () => _executeQuickAction('navigate', {'action': 'forward'}),
                ),
                _buildQuickActionButton(
                  icon: Icons.screenshot,
                  label: 'Screenshot',
                  onTap: () => _executeQuickAction('take_screenshot', {'format': 'png'}),
                ),
                _buildQuickActionButton(
                  icon: Icons.content_copy,
                  label: 'Get Content',
                  onTap: () => _executeQuickAction('get_page_content', {}),
                ),
                _buildQuickActionButton(
                  icon: Icons.link,
                  label: 'Get Links',
                  onTap: () => _executeQuickAction('get_page_links', {}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildNavigationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _urlInput = v,
              onSubmitted: (_) => _navigateToUrl(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _urlInput.isNotEmpty ? _navigateToUrl : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Go'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Element ID',
                hintText: 'From snapshot',
                prefixIcon: Icon(Icons.touch_app),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _elementId = v,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Text (for fill)',
                hintText: 'Text to type',
                prefixIcon: Icon(Icons.text_fields),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _textInput = v,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _elementId.isNotEmpty ? () async => await _executeTool('click', {'elementId': _elementId}) : null,
                  icon: const Icon(Icons.touch_app, size: 18),
                  label: const Text('Click'),
                ),
                ElevatedButton.icon(
                  onPressed: _elementId.isNotEmpty ? () async => await _executeTool('fill', {'elementId': _elementId, 'text': _textInput, 'clear': true}) : null,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Fill'),
                ),
                ElevatedButton.icon(
                  onPressed: _elementId.isNotEmpty ? () async => await _executeTool('hover', {'elementId': _elementId}) : null,
                  icon: const Icon(Icons.mouse, size: 18),
                  label: const Text('Hover'),
                ),
                ElevatedButton.icon(
                  onPressed: _elementId.isNotEmpty ? () async => await _executeTool('focus', {'elementId': _elementId}) : null,
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                  label: const Text('Focus'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async => await _executeTool('scroll', {'direction': 'down', 'pixels': 500}),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    label: const Text('Scroll Down'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async => await _executeTool('scroll', {'direction': 'up', 'pixels': 500}),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: const Text('Scroll Up'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsCard() {
    final categories = <String, List<McpTool>>{};
    for (final tool in _tools) {
      final category = _getToolCategory(tool.name);
      categories.putIfAbsent(category, () => []).add(tool);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All Tools (${_tools.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...categories.entries.map((entry) => ExpansionTile(
              title: Text('${entry.key} (${entry.value.length})'),
              children: entry.value.map((tool) => ListTile(
                dense: true,
                title: Text(tool.name, style: const TextStyle(fontSize: 13)),
                subtitle: tool.description != null ? Text(
                  tool.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ) : null,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showToolDialog(tool),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }

  String _getToolCategory(String toolName) {
    if (['get_active_page', 'list_pages', 'navigate_page', 'new_page', 'new_hidden_page', 'show_page', 'move_page', 'close_page'].contains(toolName)) {
      return 'Navigation & Tabs';
    }
    if (['take_snapshot', 'take_enhanced_snapshot', 'get_page_content', 'get_page_links', 'get_dom', 'search_dom', 'take_screenshot', 'evaluate_script'].contains(toolName)) {
      return 'Content & Observation';
    }
    if (['click', 'click_at', 'hover', 'focus', 'fill', 'clear', 'check', 'uncheck', 'select_option', 'press_key', 'drag', 'scroll', 'upload_file', 'handle_dialog'].contains(toolName)) {
      return 'Interaction & Input';
    }
    if (['save_pdf', 'save_screenshot', 'download_file'].contains(toolName)) {
      return 'File & Export';
    }
    if (['list_windows', 'create_window', 'create_hidden_window', 'close_window', 'activate_window'].contains(toolName)) {
      return 'Window Management';
    }
    return 'Other';
  }

  void _showToolDialog(McpTool tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tool.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tool.description != null) ...[
              Text(tool.description!),
              const SizedBox(height: 12),
            ],
            Text('ID: ${tool.id ?? "N/A"}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeTool(tool.name, {});
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToUrl() async {
    if (_urlInput.isEmpty) return;
    await _executeTool('navigate_page', {'url': _urlInput});
    _refreshPages();
  }

  Future<void> _executeQuickAction(String tool, Map<String, dynamic> args) async {
    await _executeTool(tool, args);
    if (tool == 'navigate_page' || tool == 'take_screenshot') {
      _refreshPages();
    }
  }

  Future<void> _executeTool(String toolName, Map<String, dynamic> args) async {
    setState(() => _isLoading = true);
    
    try {
      // Use public methods from BrowserOsService
      McpToolResult? result;
      
      // Map common tool names to service methods
      switch (toolName) {
        case 'get_active_page':
          result = await _service.getActivePage();
          break;
        case 'list_pages':
          result = await _service.listPages();
          break;
        case 'navigate_page':
          result = await _service.navigatePage(args['url'] ?? '', action: args['action']);
          break;
        case 'new_page':
          result = await _service.newPage(args['url'] ?? '', active: args['active'] ?? true);
          break;
        case 'close_page':
          result = await _service.closePage(args['pageId'] ?? '');
          break;
        case 'take_snapshot':
          result = await _service.takeSnapshot(pageId: args['pageId']);
          break;
        case 'take_enhanced_snapshot':
          result = await _service.takeEnhancedSnapshot(pageId: args['pageId']);
          break;
        case 'get_page_content':
          result = await _service.getPageContent(pageId: args['pageId']);
          break;
        case 'get_page_links':
          result = await _service.getPageLinks(pageId: args['pageId']);
          break;
        case 'get_dom':
          result = await _service.getDom(selector: args['selector'], pageId: args['pageId']);
          break;
        case 'search_dom':
          result = await _service.searchDom(args['query'] ?? '', type: args['type'], pageId: args['pageId']);
          break;
        case 'take_screenshot':
          result = await _service.takeScreenshot(pageId: args['pageId'], format: args['format'] ?? 'png', fullPage: args['fullPage'] ?? false);
          break;
        case 'evaluate_script':
          result = await _service.evaluateScript(args['expression'] ?? '', pageId: args['pageId']);
          break;
        case 'click':
          result = await _service.click(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'click_at':
          result = await _service.clickAt(args['x'] ?? 0, args['y'] ?? 0, pageId: args['pageId']);
          break;
        case 'hover':
          result = await _service.hover(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'focus':
          result = await _service.focus(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'fill':
          result = await _service.fill(args['elementId'] ?? '', args['text'] ?? '', clear: args['clear'] ?? false, pageId: args['pageId']);
          break;
        case 'clear':
          result = await _service.clear(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'check':
          result = await _service.check(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'uncheck':
          result = await _service.uncheck(args['elementId'] ?? '', pageId: args['pageId']);
          break;
        case 'select_option':
          result = await _service.selectOption(args['elementId'] ?? '', args['value'] ?? '', pageId: args['pageId']);
          break;
        case 'press_key':
          result = await _service.pressKey(args['key'] ?? '', pageId: args['pageId']);
          break;
        case 'drag':
          result = await _service.drag(args['fromElementId'] ?? '', args['toElementId'] ?? '', pageId: args['pageId']);
          break;
        case 'scroll':
          result = await _service.scroll(args['direction'] ?? 'down', pixels: args['pixels'], elementId: args['elementId'], pageId: args['pageId']);
          break;
        case 'handle_dialog':
          result = await _service.handleDialog(args['accept'] ?? true, text: args['text'], pageId: args['pageId']);
          break;
        case 'save_pdf':
          result = await _service.savePdf(pageId: args['pageId'], path: args['path']);
          break;
        case 'save_screenshot':
          result = await _service.saveScreenshot(pageId: args['pageId'], path: args['path'], format: args['format'] ?? 'png');
          break;
        default:
          // Tool not directly mapped - show message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tool "$toolName" - configure in settings'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
      }
      
      if (!mounted) return;
      
      if (result != null && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$toolName executed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show result content if meaningful
        if (result.content != null && result.content.toString().length > 10) {
          _showResultDialog(toolName, result.content);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toolName} failed: ${result?.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _showResultDialog(String tool, dynamic content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$tool Result'),
        content: SingleChildScrollView(
          child: SelectableText(
            content.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// Represents a browser page/tab
class BrowserPage {
  final String id;
  final String title;
  final String url;
  final bool active;

  BrowserPage({
    required this.id,
    required this.title,
    required this.url,
    this.active = false,
  });

  factory BrowserPage.fromJson(Map<String, dynamic> json) {
    return BrowserPage(
      id: json['id'] ?? json['pageId'] ?? json['tabId'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Untitled',
      url: json['url'] ?? '',
      active: json['active'] ?? false,
    );
  }
}