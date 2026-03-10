import 'package:flutter/material.dart';
import '../models/prompt_template.dart';
import '../services/prompt_templates_service.dart';

/// Callback type when a template is selected
typedef TemplateSelectedCallback = void Function(PromptTemplate template, String filledPrompt);

/// Screen for browsing and selecting prompt templates
class PromptTemplatesScreen extends StatefulWidget {
  final bool selectionMode;
  final TemplateSelectedCallback? onTemplateSelected;

  const PromptTemplatesScreen({
    super.key,
    this.selectionMode = false,
    this.onTemplateSelected,
  });

  @override
  State<PromptTemplatesScreen> createState() => _PromptTemplatesScreenState();
}

class _PromptTemplatesScreenState extends State<PromptTemplatesScreen> {
  late PromptTemplatesService _service;
  List<PromptTemplate> _templates = [];
  List<PromptTemplate> _filteredTemplates = [];
  Map<PromptCategory, int> _categoryCounts = {};
  PromptCategory? _selectedCategory;
  String _searchQuery = '';
  bool _loading = true;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    _service = await PromptTemplatesService.getInstance();
    
    final templates = await _service.getTemplates();
    final categoryCounts = await _service.getCategories();
    
    setState(() {
      _templates = templates;
      _categoryCounts = categoryCounts;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _templates.toList();
    
    // Filter by category
    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }
    
    // Filter by favorites
    if (_showFavoritesOnly) {
      filtered = filtered.where((t) => t.isFavorite).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.prompt.toLowerCase().contains(query) ||
            (t.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Sort by usage count (most used first)
    filtered.sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));
    
    setState(() {
      _filteredTemplates = filtered;
    });
  }

  Future<void> _toggleFavorite(PromptTemplate template) async {
    await _service.toggleFavorite(template.id);
    await _loadTemplates();
  }

  void _showTemplateDetail(PromptTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateDetailScreen(
          template: template,
          selectionMode: widget.selectionMode,
          onTemplateSelected: widget.onTemplateSelected,
          onFavoriteToggled: () => _loadTemplates(),
        ),
      ),
    );
  }

  void _showCreateTemplate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateEditScreen(
          onSave: () => _loadTemplates(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Select Template' : 'Prompt Templates'),
        actions: [
          if (!widget.selectionMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateTemplate,
              tooltip: 'Create Template',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                
                // Category chips
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      // All categories chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: _selectedCategory == null && !_showFavoritesOnly,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = null;
                              _showFavoritesOnly = false;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      // Favorites chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: const Icon(Icons.star, size: 18),
                          label: const Text('Favorites'),
                          selected: _showFavoritesOnly,
                          onSelected: (_) {
                            setState(() {
                              _showFavoritesOnly = !_showFavoritesOnly;
                              if (_showFavoritesOnly) {
                                _selectedCategory = null;
                              }
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      // Category chips
                      ...PromptCategory.values.map((category) {
                        final count = _categoryCounts[category] ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Text(category.emoji),
                            label: Text('${category.displayName} ($count)'),
                            selected: _selectedCategory == category,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = 
                                    _selectedCategory == category ? null : category;
                                _showFavoritesOnly = false;
                              });
                              _applyFilters();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Templates list
                Expanded(
                  child: _filteredTemplates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No templates found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = _filteredTemplates[index];
                            return _TemplateCard(
                              template: template,
                              onTap: () => _showTemplateDetail(template),
                              onFavoriteTap: () => _toggleFavorite(template),
                              selectionMode: widget.selectionMode,
                              onSelect: widget.onTemplateSelected != null
                                  ? () => _showTemplateDetail(template)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Card widget for displaying a template
class _TemplateCard extends StatelessWidget {
  final PromptTemplate template;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final bool selectionMode;
  final VoidCallback? onSelect;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onFavoriteTap,
    this.selectionMode = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: template.category.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(template.category.emoji),
                        const SizedBox(width: 4),
                        Text(
                          template.category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: template.category.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      template.isFavorite ? Icons.star : Icons.star_border,
                      color: template.isFavorite ? Colors.amber : null,
                    ),
                    onPressed: onFavoriteTap,
                    tooltip: template.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                  // Usage count badge
                  if ((template.usageCount ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up, size: 12, color: Colors.blue),
                          const SizedBox(width: 2),
                          Text(
                            '${template.usageCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                template.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (template.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  template.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Variables indicator
              if (template.hasVariables)
                Row(
                  children: [
                    Icon(Icons.edit_note, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${template.variables.length} variable${template.variables.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen for viewing template details and filling variables
class TemplateDetailScreen extends StatefulWidget {
  final PromptTemplate template;
  final bool selectionMode;
  final TemplateSelectedCallback? onTemplateSelected;
  final VoidCallback? onFavoriteToggled;

  const TemplateDetailScreen({
    super.key,
    required this.template,
    this.selectionMode = false,
    this.onTemplateSelected,
    this.onFavoriteToggled,
  });

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  final Map<String, TextEditingController> _variableControllers = {};
  bool _isFavorite = false;
  late PromptTemplate _template;

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    _isFavorite = _template.isFavorite;
    
    // Initialize controllers for variables
    for (final variable in _template.variables) {
      _variableControllers[variable.name] = TextEditingController(
        text: variable.defaultValue ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _variableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getFilledPrompt() {
    final values = <String, String>{};
    for (final entry in _variableControllers.entries) {
      values[entry.key] = entry.value.text;
    }
    return _template.fillVariables(values);
  }

  Future<void> _toggleFavorite() async {
    final service = await PromptTemplatesService.getInstance();
    await service.toggleFavorite(_template.id);
    setState(() {
      _isFavorite = !_isFavorite;
    });
    widget.onFavoriteToggled?.call();
  }

  void _insertTemplate() {
    final prompt = _getFilledPrompt();
    widget.onTemplateSelected?.call(_template, prompt);
    Navigator.pop(context);
    Navigator.pop(context);
  }

  void _copyPrompt() {
    final prompt = _getFilledPrompt();
    
    // Copy to clipboard (requires clipboard package or manual)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Prompt copied to clipboard'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Filled Prompt'),
                content: SingleChildScrollView(
                  child: SelectableText(prompt),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_template.title),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
          if (!_template.isDefault)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TemplateEditScreen(
                      template: _template,
                      onSave: () async {
                        final service = await PromptTemplatesService.getInstance();
                        final updated = await service.getTemplateById(_template.id);
                        if (updated != null && mounted) {
                          setState(() {
                            _template = updated;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
              tooltip: 'Edit template',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _template.category.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_template.category.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    _template.category.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      color: _template.category.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            if (_template.description != null) ...[
              Text(
                _template.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Variables section
            if (_template.hasVariables) ...[
              Text(
                'Variables',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._template.variables.map((variable) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _variableControllers[variable.name],
                    decoration: InputDecoration(
                      labelText: variable.name,
                      hintText: variable.description,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    maxLines: variable.name.toLowerCase().contains('code') ? 5 : 1,
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            
            // Prompt preview
            Text(
              'Prompt Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getFilledPrompt(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            if (widget.selectionMode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _insertTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('Insert into Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyPrompt,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Return the filled prompt to caller
                        Navigator.pop(context, _getFilledPrompt());
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Use in Chat'),
                    ),
                  ),
                ],
              ),
            
            // Usage stats
            if ((_template.usageCount ?? 0) > 0) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    'Used ${_template.usageCount} times',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Screen for creating/editing templates
class TemplateEditScreen extends StatefulWidget {
  final PromptTemplate? template; // null for new template
  final VoidCallback? onSave;

  const TemplateEditScreen({
    super.key,
    this.template,
    this.onSave,
  });

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _promptController;
  PromptCategory _selectedCategory = PromptCategory.custom;
  List<PromptVariable> _variables = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _descriptionController = TextEditingController(text: template?.description ?? '');
    _promptController = TextEditingController(text: template?.prompt ?? '');
    
    if (template != null) {
      _selectedCategory = template.category;
      _variables = List.from(template.variables);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _extractVariablesFromPrompt() {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    final matches = regex.allMatches(_promptController.text);
    final existingNames = _variables.map((v) => v.name).toSet();
    
    for (final match in matches) {
      final name = match.group(1)!;
      if (!existingNames.contains(name)) {
        _variables.add(PromptVariable(
          name: name,
          description: 'Value for $name',
        ));
        existingNames.add(name);
      }
    }
    
    setState(() {});
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _saving = true;
    });
    
    final service = await PromptTemplatesService.getInstance();
    
    final template = PromptTemplate(
      id: widget.template?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      prompt: _promptController.text.trim(),
      category: _selectedCategory,
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      variables: _variables,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isDefault: false,
    );
    
    final success = await service.saveTemplate(template);
    
    setState(() {
      _saving = false;
    });
    
    if (success && mounted) {
      widget.onSave?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.template != null 
              ? 'Template updated successfully' 
              : 'Template created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save template'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTemplate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final service = await PromptTemplatesService.getInstance();
      final success = await service.deleteTemplate(widget.template!.id);
      
      if (success && mounted) {
        widget.onSave?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'Create Template'),
        actions: [
          if (isEditing && !widget.template!.isDefault)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteTemplate,
              tooltip: 'Delete template',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., Code Review',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of this template',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // Category dropdown
            DropdownButtonFormField<PromptCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: PromptCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(category.emoji),
                      const SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Prompt
            TextFormField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: 'Prompt Template *',
                hintText: 'Use {{variable_name}} for variables',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: _extractVariablesFromPrompt,
                  tooltip: 'Extract variables from prompt',
                ),
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a prompt';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Tip: Use {{variable_name}} syntax to create variables',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Variables section
            if (_variables.isNotEmpty) ...[
              Text(
                'Variables',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._variables.map((variable) {
                final index = _variables.indexOf(variable);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '{{${variable.name}}}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () {
                                setState(() {
                                  _variables.removeAt(index);
                                });
                              },
                              tooltip: 'Remove variable',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: variable.description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _variables[index] = variable.copyWith(
                              description: value,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
            
            // Save button
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveTemplate,
              icon: _saving 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving 
                  ? 'Saving...' 
                  : isEditing 
                      ? 'Update Template' 
                      : 'Create Template'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

