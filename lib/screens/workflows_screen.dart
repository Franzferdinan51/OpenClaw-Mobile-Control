import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/browseros_service.dart';

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  final BrowserOsService _service = BrowserOsService();
  final Uuid _uuid = const Uuid();
  
  List<BrowserWorkflow> _workflows = [];
  bool _isLoading = false;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize();
      final workflows = await _service.getWorkflows();
      
      // Add presets if not already present
      final presetIds = WorkflowTemplates.presets.map((p) => p.id).toSet();
      final userIds = workflows.map((w) => w.id).toSet();
      
      for (final preset in WorkflowTemplates.presets) {
        if (!userIds.contains(preset.id)) {
          workflows.insert(0, preset);
        }
      }
      
      setState(() {
        _workflows = workflows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkflows,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workflows.isEmpty
              ? _buildEmptyState()
              : _buildWorkflowList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No Workflows', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Create a workflow to automate browser tasks'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Workflow'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowList() {
    // Separate presets from user workflows
    final presets = _workflows.where((w) => w.isPreset).toList();
    final userWorkflows = _workflows.where((w) => !w.isPreset).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (presets.isNotEmpty) ...[
          Text('Templates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...presets.map((w) => _buildWorkflowCard(w, isPreset: true)),
          const SizedBox(height: 16),
        ],
        if (userWorkflows.isNotEmpty) ...[
          Text('My Workflows', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...userWorkflows.map((w) => _buildWorkflowCard(w)),
        ] else if (presets.isEmpty) ...[
          _buildEmptyState(),
        ],
      ],
    );
  }

  Widget _buildWorkflowCard(BrowserWorkflow workflow, {bool isPreset = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPreset ? Colors.blue : Colors.green,
          child: Icon(isPreset ? Icons.auto_awesome : Icons.account_tree, color: Colors.white, size: 20),
        ),
        title: Text(workflow.name),
        subtitle: Text(
          workflow.description.isNotEmpty 
              ? workflow.description 
              : '${workflow.steps.length} steps',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isPreset
            ? ElevatedButton(
                onPressed: _isRunning ? null : () => _runWorkflow(workflow),
                child: const Text('Run'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _isRunning ? null : () => _runWorkflow(workflow),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteWorkflow(workflow),
                  ),
                ],
              ),
        onTap: isPreset ? () => _runWorkflow(workflow) : () => _showEditDialog(workflow),
      ),
    );
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedTemplate = 'custom';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Workflow'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Start from template:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...WorkflowTemplates.presets.map((t) => RadioListTile<String>(
                title: Text(t.name, style: const TextStyle(fontSize: 14)),
                value: t.id,
                groupValue: selectedTemplate,
                onChanged: (v) {
                  selectedTemplate = v ?? 'custom';
                  (context as Element).markNeedsBuild();
                },
              )),
              RadioListTile<String>(
                title: const Text('Custom (empty)', style: TextStyle(fontSize: 14)),
                value: 'custom',
                groupValue: selectedTemplate,
                onChanged: (v) => selectedTemplate = v ?? 'custom',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              
              final workflow = BrowserWorkflow(
                id: _uuid.v4(),
                name: nameController.text,
                description: descController.text,
                createdAt: DateTime.now(),
                steps: selectedTemplate != 'custom' 
                    ? WorkflowTemplates.presets.firstWhere((t) => t.id == selectedTemplate).steps
                    : [],
              );
              
              _saveWorkflow(workflow);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BrowserWorkflow workflow) {
    final nameController = TextEditingController(text: workflow.name);
    final descController = TextEditingController(text: workflow.description);
    final stepsText = workflow.steps.map((s) => '${s['tool']}: ${s['arguments']}').join('\n');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Workflow'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Steps can be added via the API for now',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepsText.isEmpty ? 'No steps defined' : stepsText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
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

  Future<void> _saveWorkflow(BrowserWorkflow workflow) async {
    await _service.saveWorkflow(workflow);
    await _loadWorkflows();
  }

  Future<void> _runWorkflow(BrowserWorkflow workflow) async {
    if (workflow.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No steps in workflow'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isRunning = true);

    try {
      await _service.connect();
      final result = await _service.runWorkflow(workflow);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Workflow completed!' : 'Error: ${result.error}'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isRunning = false);
  }

  Future<void> _deleteWorkflow(BrowserWorkflow workflow) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workflow?'),
        content: Text('Are you sure you want to delete "${workflow.name}"?'),
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

    if (confirm == true) {
      await _service.deleteWorkflow(workflow.id);
      await _loadWorkflows();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}