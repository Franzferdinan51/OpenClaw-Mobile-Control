import 'package:flutter/material.dart';
import '../services/gateway_service.dart';

/// Canvas & A2UI Screen
/// Canvas viewer, A2UI rendering, Image generation (ComfyUI), Image analysis
class CanvasScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const CanvasScreen({super.key, this.gatewayService});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CanvasInfo> _activeCanvases = [];
  List<ImageGeneration> _recentGenerations = [];
  bool _isLoading = true;
  
  // Image Generation Settings
  String _selectedModel = 'seedream';
  String _prompt = '';
  String _negativePrompt = '';
  int _width = 1024;
  int _height = 1024;
  int _steps = 20;
  double _guidance = 7.5;
  
  final List<String> _availableModels = [
    'seedream',
    'sdxl',
    'sdxl-turbo',
    'sd-1.5',
    'flux-schnell',
    'flux-dev',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Simulate loading
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _activeCanvases = [
        CanvasInfo(
          id: 'canvas-1',
          title: 'Agent Dashboard',
          type: CanvasType.a2ui,
          status: CanvasStatus.active,
          url: 'http://localhost:3001',
          lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
          dimensions: const Size(1920, 1080),
        ),
        CanvasInfo(
          id: 'canvas-2',
          title: 'Voice Control UI',
          type: CanvasType.a2ui,
          status: CanvasStatus.active,
          url: 'http://localhost:8080',
          lastUpdated: DateTime.now().subtract(const Duration(minutes: 2)),
          dimensions: const Size(800, 600),
        ),
        CanvasInfo(
          id: 'canvas-3',
          title: 'ComfyUI Workflow',
          type: CanvasType.image,
          status: CanvasStatus.idle,
          url: 'http://100.116.54.125:8188',
          lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
          dimensions: const Size(1024, 1024),
        ),
      ];

      _recentGenerations = [
        ImageGeneration(
          id: 'gen-1',
          prompt: 'A serene mountain landscape at sunset',
          model: 'seedream',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          seed: 12345,
        ),
        ImageGeneration(
          id: 'gen-2',
          prompt: 'Cyberpunk city street at night',
          model: 'sdxl',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          seed: 67890,
        ),
        ImageGeneration(
          id: 'gen-3',
          prompt: 'Abstract geometric patterns in vibrant colors',
          model: 'flux-schnell',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          seed: 11111,
        ),
      ];
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas & A2UI'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Active'),
            Tab(icon: Icon(Icons.image), text: 'Generate'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveCanvases(),
                _buildImageGeneration(),
                _buildHistory(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCanvasOptions(),
        icon: const Icon(Icons.add),
        label: const Text('New Canvas'),
      ),
    );
  }

  Widget _buildActiveCanvases() {
    if (_activeCanvases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active canvases'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeCanvases.length,
      itemBuilder: (context, index) {
        final canvas = _activeCanvases[index];
        return _CanvasCard(
          canvas: canvas,
          onTap: () => _openCanvas(canvas),
          onClose: () => _closeCanvas(canvas),
          onRefresh: () => _refreshCanvas(canvas),
        );
      },
    );
  }

  Widget _buildImageGeneration() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ComfyUI Status
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.computer, color: Colors.green),
              ),
              title: const Text('ComfyUI Status'),
              subtitle: const Text('Connected to 100.116.54.125:8188'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('ONLINE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Model Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableModels.map((model) => ChoiceChip(
                      label: Text(model),
                      selected: _selectedModel == model,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedModel = model);
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Prompt Input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prompt', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Describe what you want to generate...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _prompt = value,
                  ),
                  const SizedBox(height: 12),
                  Text('Negative Prompt', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'What to avoid...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _negativePrompt = value,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Dimensions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dimensions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Width: ${_width}px'),
                            Slider(
                              value: _width.toDouble(),
                              min: 512,
                              max: 2048,
                              divisions: 5,
                              onChanged: (value) => setState(() => _width = value.toInt()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Height: ${_height}px'),
                            Slider(
                              value: _height.toDouble(),
                              min: 512,
                              max: 2048,
                              divisions: 5,
                              onChanged: (value) => setState(() => _height = value.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Advanced Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Advanced', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.expand_more),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Steps: $_steps'),
                            Slider(
                              value: _steps.toDouble(),
                              min: 10,
                              max: 50,
                              divisions: 8,
                              onChanged: (value) => setState(() => _steps = value.toInt()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Guidance: ${_guidance.toStringAsFixed(1)}'),
                            Slider(
                              value: _guidance,
                              min: 1.0,
                              max: 15.0,
                              divisions: 14,
                              onChanged: (value) => setState(() => _guidance = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Generate Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _prompt.isNotEmpty ? _generateImage : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Image'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Image Analysis Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _analyzeImage,
              icon: const Icon(Icons.image_search),
              label: const Text('Analyze Image'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_recentGenerations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No recent generations'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentGenerations.length,
      itemBuilder: (context, index) {
        final gen = _recentGenerations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showGenerationDetails(gen),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gen.prompt,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${gen.model} • ${_formatTime(gen.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _regenerate(gen),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCanvas(CanvasInfo canvas) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${canvas.title}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _closeCanvas(CanvasInfo canvas) {
    setState(() {
      _activeCanvases.removeWhere((c) => c.id == canvas.id);
    });
  }

  void _refreshCanvas(CanvasInfo canvas) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshing ${canvas.title}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _generateImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Generating image...'),
          ],
        ),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 30),
      ),
    );
  }

  void _analyzeImage() {
    // Show image picker
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _doAnalyze('camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _doAnalyze('gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.paste),
              title: const Text('Paste from Clipboard'),
              onTap: () {
                Navigator.pop(context);
                _doAnalyze('clipboard');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _doAnalyze(String source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analyzing image from $source...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _regenerate(ImageGeneration gen) {
    setState(() {
      _prompt = gen.prompt;
      _selectedModel = gen.model;
    });
    _tabController.animateTo(1); // Switch to Generate tab
  }

  void _showGenerationDetails(ImageGeneration gen) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prompt:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(gen.prompt),
            const SizedBox(height: 12),
            Text('Model: ${gen.model}'),
            Text('Seed: ${gen.seed}'),
            Text('Created: ${_formatTime(gen.createdAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _regenerate(gen);
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _showCanvasOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('A2UI Canvas'),
              subtitle: const Text('Render interactive AI UI'),
              onTap: () {
                Navigator.pop(context);
                _createCanvas(CanvasType.a2ui);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image Canvas'),
              subtitle: const Text('Display generated images'),
              onTap: () {
                Navigator.pop(context);
                _createCanvas(CanvasType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('Web Canvas'),
              subtitle: const Text('Embed web content'),
              onTap: () {
                Navigator.pop(context);
                _createCanvas(CanvasType.web);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createCanvas(CanvasType type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating ${type.name} canvas...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _CanvasCard extends StatelessWidget {
  final CanvasInfo canvas;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _CanvasCard({
    required this.canvas,
    required this.onTap,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getTypeIcon(), color: _getTypeColor()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          canvas.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${canvas.type.name.toUpperCase()} • ${canvas.url}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: canvas.status == CanvasStatus.active ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      canvas.status.name.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.aspect_ratio, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${canvas.dimensions.width.toInt()}x${canvas.dimensions.height.toInt()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.update, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(canvas.lastUpdated),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (canvas.type) {
      case CanvasType.a2ui:
        return Icons.dashboard;
      case CanvasType.image:
        return Icons.image;
      case CanvasType.web:
        return Icons.web;
    }
  }

  Color _getTypeColor() {
    switch (canvas.type) {
      case CanvasType.a2ui:
        return Colors.purple;
      case CanvasType.image:
        return Colors.blue;
      case CanvasType.web:
        return Colors.green;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

// Data Models
enum CanvasType { a2ui, image, web }
enum CanvasStatus { active, idle, error }

class CanvasInfo {
  final String id;
  final String title;
  final CanvasType type;
  final CanvasStatus status;
  final String url;
  final DateTime lastUpdated;
  final Size dimensions;

  CanvasInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.url,
    required this.lastUpdated,
    required this.dimensions,
  });
}

class ImageGeneration {
  final String id;
  final String prompt;
  final String model;
  final DateTime createdAt;
  final int seed;

  ImageGeneration({
    required this.id,
    required this.prompt,
    required this.model,
    required this.createdAt,
    required this.seed,
  });
}