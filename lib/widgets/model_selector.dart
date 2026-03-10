import 'package:flutter/material.dart';
import '../services/model_service.dart';

/// Dropdown widget for selecting models
class ModelSelector extends StatefulWidget {
  final ModelService modelService;
  final Function(ModelInfo)? onModelSelected;
  final bool showInfo;
  final bool compact;

  const ModelSelector({
    super.key,
    required this.modelService,
    this.onModelSelected,
    this.showInfo = true,
    this.compact = false,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ModelInfo?>(
      stream: widget.modelService.selectedModelStream,
      initialData: widget.modelService.selectedModel,
      builder: (context, snapshot) {
        final selectedModel = snapshot.data;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main selector button
            InkWell(
              onTap: () => _showModelPicker(context),
              borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
              child: Container(
                padding: EdgeInsets.all(widget.compact ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Model icon
                    Container(
                      width: widget.compact ? 28 : 36,
                      height: widget.compact ? 28 : 36,
                      decoration: BoxDecoration(
                        color: (selectedModel?.speedColor ?? Colors.grey).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        selectedModel?.speedIcon ?? Icons.psychology,
                        size: widget.compact ? 16 : 20,
                        color: selectedModel?.speedColor ?? Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Model name and info
                    if (!widget.compact) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedModel?.name ?? 'Select Model',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (selectedModel != null && widget.showInfo)
                              Text(
                                '${selectedModel.contextWindowDisplay} context • ${selectedModel.speed ?? 'Unknown'} speed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          selectedModel?.name ?? 'Select Model',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            
            // Quick info bar (if not compact)
            if (!widget.compact && selectedModel != null && widget.showInfo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickInfo(
                    Icons.memory,
                    selectedModel.contextWindowDisplay,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickInfo(
                    selectedModel.speedIcon,
                    selectedModel.speed ?? 'Unknown',
                    color: selectedModel.speedColor,
                  ),
                  if (selectedModel.costPer1kTokens != null) ...[
                    const SizedBox(width: 12),
                    _buildQuickInfo(
                      Icons.attach_money,
                      selectedModel.costDisplay,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildQuickInfo(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color ?? Colors.grey[500],
          ),
        ),
      ],
    );
  }

  void _showModelPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Model',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => widget.modelService.fetchAvailableModels(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Recent models
              if (widget.modelService.recentModels.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: widget.modelService.recentModels.length,
                    itemBuilder: (context, index) {
                      final model = widget.modelService.recentModels[index];
                      final isSelected = widget.modelService.selectedModel?.id == model.id;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            widget.modelService.selectModel(model.id);
                            widget.onModelSelected?.call(model);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00D4AA).withOpacity(0.1)
                                  : Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF00D4AA))
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  model.speedIcon,
                                  size: 20,
                                  color: model.speedColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  model.name,
                                  style: TextStyle(
                                    fontSize: 10,
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
                    },
                  ),
                ),
                const Divider(height: 24),
              ],
              
              // All models
              Expanded(
                child: StreamBuilder<List<ModelInfo>>(
                  stream: widget.modelService.modelsStream,
                  initialData: widget.modelService.availableModels,
                  builder: (context, snapshot) {
                    final models = snapshot.data ?? [];
                    
                    if (models.isEmpty) {
                      return const Center(
                        child: Text('No models available'),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        final model = models[index];
                        final isSelected = widget.modelService.selectedModel?.id == model.id;
                        
                        return _ModelPickerItem(
                          model: model,
                          isSelected: isSelected,
                          onTap: () {
                            widget.modelService.selectModel(model.id);
                            widget.onModelSelected?.call(model);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelPickerItem extends StatelessWidget {
  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelPickerItem({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: model.speedColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(model.speedIcon, color: model.speedColor),
      ),
      title: Text(
        model.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(
        '${model.provider ?? "Unknown"} • ${model.contextWindowDisplay}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF00D4AA))
          : null,
      selected: isSelected,
      selectedTileColor: const Color(0xFF00D4AA).withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}