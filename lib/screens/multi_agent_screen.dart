import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../data/agency_agents.dart';
import 'agent_library_screen.dart';

/// Screen for orchestrating multiple agents
class MultiAgentScreen extends StatefulWidget {
  final Function(List<AgentPersonality>)? onTeamActivated;
  final List<AgentPersonality>? initialAgents;

  const MultiAgentScreen({
    super.key,
    this.onTeamActivated,
    this.initialAgents,
  });

  @override
  State<MultiAgentScreen> createState() => _MultiAgentScreenState();
}

class _MultiAgentScreenState extends State<MultiAgentScreen> {
  late List<AgentPersonality> _selectedAgents;
  final TextEditingController _taskController = TextEditingController();
  String _taskDescription = '';

  @override
  void initState() {
    super.initState();
    _selectedAgents = widget.initialAgents?.toList() ?? [];
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _addAgent(AgentPersonality agent) {
    if (!_selectedAgents.any((a) => a.id == agent.id)) {
      setState(() {
        _selectedAgents.add(agent);
      });
    }
  }

  void _removeAgent(String agentId) {
    setState(() {
      _selectedAgents.removeWhere((a) => a.id == agentId);
    });
  }

  void _showAgentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Add Agent to Team',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AgentLibraryScreen(
                    selectionMode: true,
                    onAgentSelected: (agent) {
                      _addAgent(agent);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a Template',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...AgencyAgentsData.templates.map((template) {
              return ListTile(
                leading: Text(
                  template.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(template.name),
                subtitle: Text('${template.agentIds.length} agents • ${template.useCase}'),
                onTap: () {
                  final agents = template.agentIds
                      .map((id) => AgencyAgentsData.getById(id))
                      .where((a) => a != null)
                      .cast<AgentPersonality>()
                      .toList();
                  setState(() {
                    _selectedAgents.addAll(
                      agents.where((a) => !_selectedAgents.any((s) => s.id == a.id)),
                    );
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _activateTeam() {
    if (_selectedAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one agent to your team!'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('🚀 '),
            Text('Activate Team'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your team of ${_selectedAgents.length} agents:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAgents.map((a) {
                return Chip(
                  avatar: Text(a.emoji),
                  label: Text(a.name),
                  backgroundColor: a.division.color.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            if (_taskDescription.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Task:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_taskDescription),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onTeamActivated?.call(_selectedAgents);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🚀 ${_selectedAgents.length} agents activated!',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🎭 '),
            Text('Multi-Agent Team'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _showTemplatePicker,
            icon: const Icon(Icons.bookmark),
            label: const Text('Templates'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Task description
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _taskController,
              decoration: InputDecoration(
                hintText: 'Describe your task... (optional)',
                prefixIcon: const Icon(Icons.task),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  _taskDescription = value;
                });
              },
            ),
          ),

          // Team members header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Team Members (${_selectedAgents.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAgentPicker,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),

          // Selected agents
          Expanded(
            child: _selectedAgents.isEmpty
                ? _buildEmptyState()
                : _buildAgentGrid(),
          ),

          // Division breakdown
          if (_selectedAgents.isNotEmpty) _buildDivisionBreakdown(),
        ],
      ),
      floatingActionButton: _selectedAgents.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _activateTeam,
              icon: const Icon(Icons.play_arrow),
              label: Text('Activate (${_selectedAgents.length})'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '👥',
            style: TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'Build Your Team',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add agents to create a multi-agent team',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showAgentPicker,
                icon: const Icon(Icons.add),
                label: const Text('Add Agent'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showTemplatePicker,
                icon: const Icon(Icons.bookmark),
                label: const Text('Use Template'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Quick templates
          Text(
            'Quick Start Templates',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AgencyAgentsData.templates.take(3).map((t) {
              return ActionChip(
                avatar: Text(t.emoji),
                label: Text(t.name),
                onPressed: () {
                  final agents = t.agentIds
                      .map((id) => AgencyAgentsData.getById(id))
                      .where((a) => a != null)
                      .cast<AgentPersonality>()
                      .toList();
                  setState(() {
                    _selectedAgents.addAll(agents);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _selectedAgents.length,
      itemBuilder: (context, index) {
        final agent = _selectedAgents[index];
        return _buildAgentCard(agent);
      },
    );
  }

  Widget _buildAgentCard(AgentPersonality agent) {
    return Card(
      child: InkWell(
        onTap: () {
          // Show agent details
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(agent.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              agent.division.displayName,
                              style: TextStyle(color: agent.division.color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(agent.shortDescription),
                  const SizedBox(height: 16),
                  const Text(
                    'Specialties:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: agent.specialties.map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _removeAgent(agent.id),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: agent.division.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        agent.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeAgent(agent.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                agent.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                agent.shortDescription,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionBreakdown() {
    final divisionCounts = <AgentDivision, int>{};
    for (final agent in _selectedAgents) {
      divisionCounts[agent.division] = (divisionCounts[agent.division] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: divisionCounts.entries.map((e) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.key.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  '${e.value}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}