import 'package:flutter/material.dart';
import '../services/model_service.dart';

/// Screen for selecting and managing AI models
class ModelSelectionScreen extends StatefulWidget {
  final ModelService modelService;
  final Function(ModelInfo)? onModelSelected;

  const ModelSelectionScreen({
    super.key,
    required this.modelService,
    this.onModelSelected,
  });

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedProvider;
  
  List<String> get _providers {
    final providers = widget.modelService.availableModels
        .map((m) => m.provider)
        .whereType<String>()
        .toSet()
        .toList();
    providers.sort();
    return providers;
  }

  List<ModelInfo> get _filteredModels {
    var models = widget.modelService.availableModels;
    
    // Filter by provider
    if (_selectedProvider != null) {
      models = models.where((m) => m.provider == _selectedProvider).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      models = models.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.id.toLowerCase().contains(query) ||
            (m.provider?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    return models;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search models...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Select Model'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.modelService.fetchAvailableModels(),
          ),
        ],
      ),
      body: StreamBuilder<List<ModelInfo>>(
        stream: widget.modelService.modelsStream,
        initialData: widget.modelService.availableModels,
        builder: (context, snapshot) {
          if (widget.modelService.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.modelService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${widget.modelService.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => widget.modelService.fetchAvailableModels(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final models = _filteredModels;

          if (models.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty || _selectedProvider != null
                        ? Icons.search_off
                        : Icons.psychology_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _selectedProvider != null
                        ? 'No models match your filters'
                        : 'No models available',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Provider filter chips
              if (_providers.isNotEmpty)
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedProvider == null,
                        onSelected: (selected) {
                          setState(() => _selectedProvider = null);
                        },
                      ),
                      ..._providers.map((provider) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(provider),
                          selected: _selectedProvider == provider,
                          onSelected: (selected) {
                            setState(() => _selectedProvider = selected ? provider : null);
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              
              // Recent models section
              if (widget.modelService.recentModels.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: widget.modelService.recentModels.length,
                    itemBuilder: (context, index) {
                      final model = widget.modelService.recentModels[index];
                      final isSelected = widget.modelService.selectedModel?.id == model.id;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _RecentModelCard(
                          model: model,
                          isSelected: isSelected,
                          onTap: () => _selectModel(model),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
              ],
              
              // All models list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = widget.modelService.selectedModel?.id == model.id;
                    
                    return _ModelCard(
                      model: model,
                      isSelected: isSelected,
                      onTap: () => _selectModel(model),
                      onLongPress: () => _showModelDetails(model),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _selectModel(ModelInfo model) {
    widget.modelService.selectModel(model.id);
    widget.onModelSelected?.call(model);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${model.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showModelDetails(ModelInfo model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (model.provider != null)
                          Text(
                            model.provider!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Model info cards
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.memory,
                    label: '${model.contextWindowDisplay} context',
                  ),
                  _InfoChip(
                    icon: model.speedIcon,
                    label: model.speed ?? 'Unknown speed',
                    color: model.speedColor,
                  ),
                  if (model.costPer1kTokens != null)
                    _InfoChip(
                      icon: Icons.attach_money,
                      label: model.costDisplay,
                    ),
                  _InfoChip(
                    icon: model.isAvailable ? Icons.check_circle : Icons.cancel,
                    label: model.isAvailable ? 'Available' : 'Unavailable',
                    color: model.isAvailable ? Colors.green : Colors.red,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Capabilities
              if (model.capabilities != null && model.capabilities!.isNotEmpty) ...[
                Text(
                  'Capabilities',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: model.capabilities!.map((cap) => Chip(
                    label: Text(cap),
                    backgroundColor: const Color(0xFF00D4AA).withOpacity(0.1),
                  )).toList(),
                ),
                const SizedBox(height: 24),
              ],
              
              // Model ID
              ListTile(
                title: const Text('Model ID'),
                subtitle: SelectableText(model.id),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 16),
              
              // Select button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _selectModel(model);
                },
                icon: const Icon(Icons.check),
                label: const Text('Select this model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? const Color(0xFF00D4AA).withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Color(0xFF00D4AA), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: model.speedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(model.speedIcon, color: model.speedColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00D4AA),
                          ),
                      ],
                    ),
                    if (model.provider != null)
                      Text(
                        model.provider!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.memory, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          model.contextWindowDisplay,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(model.speedIcon, size: 14, color: model.speedColor),
                        const SizedBox(width: 4),
                        Text(
                          model.speed ?? 'Unknown',
                          style: TextStyle(fontSize: 12, color: model.speedColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecentModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF00D4AA).withOpacity(0.1) : Colors.grey[800],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(model.speedIcon, color: model.speedColor),
              const SizedBox(height: 8),
              Text(
                model.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}