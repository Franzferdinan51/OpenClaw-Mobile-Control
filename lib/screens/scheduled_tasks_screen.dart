import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/browseros_service.dart';

class ScheduledTasksScreen extends StatefulWidget {
  const ScheduledTasksScreen({super.key});

  @override
  State<ScheduledTasksScreen> createState() => _ScheduledTasksScreenState();
}

class _ScheduledTasksScreenState extends State<ScheduledTasksScreen> {
  final BrowserOsService _service = BrowserOsService();
  final Uuid _uuid = const Uuid();
  
  List<ScheduledTask> _tasks = [];
  List<BrowserWorkflow> _workflows = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize();
      final tasks = await _service.getScheduledTasks();
      final workflows = await _service.getWorkflows();
      
      // Add presets to workflows
      for (final preset in WorkflowTemplates.presets) {
        if (!workflows.any((w) => w.id == preset.id)) {
          workflows.insert(0, preset);
        }
      }
      
      setState(() {
        _tasks = tasks;
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
        title: const Text('Scheduled Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : _buildTaskList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
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
            const Icon(Icons.schedule, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No Scheduled Tasks', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Schedule workflows to run automatically'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    final enabledTasks = _tasks.where((t) => t.enabled).toList();
    final disabledTasks = _tasks.where((t) => !t.enabled).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (enabledTasks.isNotEmpty) ...[
          Text('Active (${enabledTasks.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...enabledTasks.map((t) => _buildTaskCard(t)),
          const SizedBox(height: 16),
        ],
        if (disabledTasks.isNotEmpty) ...[
          Text('Disabled (${disabledTasks.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...disabledTasks.map((t) => _buildTaskCard(t)),
        ],
      ],
    );
  }

  Widget _buildTaskCard(ScheduledTask task) {
    final workflow = _workflows.firstWhere(
      (w) => w.id == task.workflowId,
      orElse: () => BrowserWorkflow(
        id: 'unknown',
        name: 'Unknown Workflow',
        createdAt: DateTime.now(),
        steps: [],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: task.enabled ? null : Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        workflow.name,
                        style: TextStyle(
                          color: task.enabled ? Colors.green[300] : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: task.enabled,
                  onChanged: (v) => _toggleTask(task.id, v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: task.enabled ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  task.scheduleDescription,
                  style: TextStyle(
                    color: task.enabled ? Colors.blue[300] : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (task.lastRun != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Last run: ${DateFormat.yMd().add_jm().format(task.lastRun!)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _runNow(task),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run Now'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteTask(task),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    if (_workflows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a workflow first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    String? selectedWorkflowId = _workflows.first.id;
    String scheduleType = 'interval';
    int intervalMinutes = 15;
    String dailyTime = '09:00';
    String weeklyDay = 'monday';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Scheduled Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Run Workflow:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedWorkflowId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _workflows.map((w) => DropdownMenuItem(
                    value: w.id,
                    child: Text(w.name, style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => selectedWorkflowId = v,
                ),
                const SizedBox(height: 16),
                const Text('Schedule:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Interval'),
                      selected: scheduleType == 'interval',
                      onSelected: (s) => setDialogState(() => scheduleType = 'interval'),
                    ),
                    ChoiceChip(
                      label: const Text('Daily'),
                      selected: scheduleType == 'daily',
                      onSelected: (s) => setDialogState(() => scheduleType = 'daily'),
                    ),
                    ChoiceChip(
                      label: const Text('Weekly'),
                      selected: scheduleType == 'weekly',
                      onSelected: (s) => setDialogState(() => scheduleType = 'weekly'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (scheduleType == 'interval') ...[
                  Row(
                    children: [
                      const Text('Every '),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          controller: TextEditingController(text: intervalMinutes.toString()),
                          onChanged: (v) => intervalMinutes = int.tryParse(v) ?? 15,
                        ),
                      ),
                      const Text(' minutes'),
                    ],
                  ),
                ],
                if (scheduleType == 'daily') ...[
                  const Text('Time:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _parseTimeToSlider(dailyTime),
                          min: 0,
                          max: 1439,
                          divisions: 24 * 60 - 1,
                          label: dailyTime,
                          onChanged: (v) => setDialogState(() {
                            dailyTime = _sliderToTime(v);
                          }),
                        ),
                      ),
                      Text(dailyTime),
                    ],
                  ),
                ],
                if (scheduleType == 'weekly') ...[
                  DropdownButtonFormField<String>(
                    value: weeklyDay,
                    decoration: const InputDecoration(
                      labelText: 'Day',
                      border: OutlineInputBorder(),
                    ),
                    items: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d[0].toUpperCase() + d.substring(1)))).toList(),
                    onChanged: (v) => weeklyDay = v ?? 'monday',
                  ),
                  const SizedBox(height: 12),
                  const Text('Time:'),
                  Slider(
                    value: _parseTimeToSlider(dailyTime),
                    min: 0,
                    max: 1439,
                    divisions: 24 * 60 - 1,
                    label: dailyTime,
                    onChanged: (v) => setDialogState(() {
                      dailyTime = _sliderToTime(v);
                    }),
                  ),
                ],
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
                if (nameController.text.isEmpty || selectedWorkflowId == null) return;
                
                String schedule;
                if (scheduleType == 'interval') {
                  schedule = 'interval:$intervalMinutes';
                } else if (scheduleType == 'daily') {
                  schedule = 'daily:$dailyTime';
                } else {
                  schedule = 'weekly:$weeklyDay:$dailyTime';
                }
                
                final task = ScheduledTask(
                  id: _uuid.v4(),
                  name: nameController.text,
                  workflowId: selectedWorkflowId!,
                  schedule: schedule,
                  createdAt: DateTime.now(),
                );
                
                _saveTask(task);
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  double _parseTimeToSlider(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]) * 60 + int.parse(parts[1])).toDouble();
  }

  String _sliderToTime(double value) {
    final mins = value.round();
    final hours = mins ~/ 60;
    final minutes = mins % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> _saveTask(ScheduledTask task) async {
    await _service.saveScheduledTask(task);
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _toggleTask(String id, bool enabled) async {
    await _service.toggleScheduledTask(id, enabled);
    await _loadData();
  }

  Future<void> _runNow(ScheduledTask task) async {
    final workflow = _workflows.firstWhere(
      (w) => w.id == task.workflowId,
      orElse: () => BrowserWorkflow(
        id: 'unknown',
        name: 'Unknown',
        createdAt: DateTime.now(),
        steps: [],
      ),
    );

    try {
      await _service.connect();
      await _service.runWorkflow(workflow);
      
      // Update last run
      final updatedTask = task.copyWith(lastRun: DateTime.now());
      await _service.saveScheduledTask(updatedTask);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task executed'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTask(ScheduledTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
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
      await _service.deleteScheduledTask(task.id);
      await _loadData();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}