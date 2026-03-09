import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../data/agency_agents.dart';
import 'agent_detail_screen.dart';

/// Screen for selecting an agent for current task
class AgentSelectorScreen extends StatefulWidget {
  final Function(AgentPersonality) onAgentSelected;
  final String? title;

  const AgentSelectorScreen({
    super.key,
    required this.onAgentSelected,
    this.title,
  });

  @override
  State<AgentSelectorScreen> createState() => _AgentSelectorScreenState();
}

class _AgentSelectorScreenState extends State<AgentSelectorScreen> {
  String _searchQuery = '';
  AgentDivision? _selectedDivision;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AgentPersonality> _getFilteredAgents() {
    var agents = AgencyAgentsData.allAgents;

    if (_selectedDivision != null) {
      agents = agents.where((a) => a.division == _selectedDivision).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      agents = agents.where((a) {
        return a.name.toLowerCase().contains(query) ||
            a.shortDescription.toLowerCase().contains(query) ||
            a.specialties.any((s) => s.toLowerCase().contains(query));
      }).toList();
    }

    return agents;
  }

  @override
  Widget build(BuildContext context) {
    final filteredAgents = _getFilteredAgents();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🎯 '),
            Text(widget.title ?? 'Select Agent'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for an agent...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
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
              },
            ),
          ),

          // Division chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDivisionChip(null, 'All'),
                ...AgentDivision.values.map((d) => _buildDivisionChip(d, d.displayName)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick suggestions
          if (_searchQuery.isEmpty && _selectedDivision == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Select',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickChip('Frontend Developer', '🎨'),
                      _buildQuickChip('Backend Architect', '🏗️'),
                      _buildQuickChip('Growth Hacker', '🚀'),
                      _buildQuickChip('AI Engineer', '🤖'),
                      _buildQuickChip('Security Engineer', '🔒'),
                      _buildQuickChip('UI Designer', '🎯'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

          // Agent list
          Expanded(
            child: filteredAgents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No agents found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAgents.length,
                    itemBuilder: (context, index) {
                      final agent = filteredAgents[index];
                      return _buildAgentTile(agent);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionChip(AgentDivision? division, String label) {
    final isSelected = _selectedDivision == division;
    final count = division == null
        ? 61
        : AgencyAgentsData.getByDivision(division).length;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (division != null) ...[
              Text(division.emoji),
              const SizedBox(width: 4),
            ],
            Text('$label ($count)'),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedDivision = selected ? division : null;
          });
        },
        selectedColor: division?.color.withValues(alpha: 0.3) ?? Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  Widget _buildQuickChip(String name, String emoji) {
    return ActionChip(
      avatar: Text(emoji),
      label: Text(name),
      onPressed: () {
        final agent = AgencyAgentsData.allAgents.firstWhere(
          (a) => a.name == name,
          orElse: () => AgencyAgentsData.allAgents.first,
        );
        _selectAgent(agent);
      },
    );
  }

  Widget _buildAgentTile(AgentPersonality agent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: agent.division.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              agent.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          agent.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent.shortDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: agent.division.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    agent.division.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: agent.division.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _selectAgent(agent);
        },
      ),
    );
  }

  void _selectAgent(AgentPersonality agent) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(agent.emoji),
            const SizedBox(width: 8),
            Text(agent.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(agent.shortDescription),
            const SizedBox(height: 16),
            const Text(
              'This agent will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...agent.deliverables.take(3).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onAgentSelected(agent);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Activate'),
            style: FilledButton.styleFrom(
              backgroundColor: agent.division.color,
            ),
          ),
        ],
      ),
    );
  }
}