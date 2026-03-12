import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/termux_hub_service.dart';

class TermuxHubScreen extends StatefulWidget {
  const TermuxHubScreen({super.key});

  @override
  State<TermuxHubScreen> createState() => _TermuxHubScreenState();
}

class _TermuxHubScreenState extends State<TermuxHubScreen> {
  final TermuxHubService _service = TermuxHubService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<TermuxHubTool> _tools = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tools = await _service.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _tools = tools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<TermuxHubTool> get _filteredTools {
    final query = _query.trim().toLowerCase();
    return _tools.where((tool) {
      if (query.isEmpty) {
        return true;
      }
      return tool.name.toLowerCase().contains(query) ||
          tool.description.toLowerCase().contains(query) ||
          tool.author.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _copyInstallCommand(TermuxHubTool tool) async {
    await Clipboard.setData(ClipboardData(text: tool.installCommand));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied install command for ${tool.name}')),
    );
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _filteredTools;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Catalog'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh catalog',
          ),
          IconButton(
            onPressed: () => _openUrl(TermuxHubService.repoUrl),
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open TermuxHub repo',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: 0.45),
            child: const Text(
              'Read-only view sourced live from TermuxHub metadata. DuckBot does not bundle or auto-run third-party tools here. Only a filtered non-root utility/dev subset is shown; review each upstream repo and license before using it.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search safe utility/dev tools',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load catalog.\n$_error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else if (tools.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No safe utility/dev entries matched the current filter.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tool.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(tool.description),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(tool.category)),
                              Chip(label: Text('by ${tool.author}')),
                              if (tool.license != null &&
                                  tool.license!.isNotEmpty)
                                Chip(label: Text(tool.license!)),
                              if (tool.starCount != null)
                                Chip(label: Text('${tool.starCount} stars')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              tool.installCommand,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _copyInstallCommand(tool),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Command'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openUrl(tool.repoUrl),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open Repo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
