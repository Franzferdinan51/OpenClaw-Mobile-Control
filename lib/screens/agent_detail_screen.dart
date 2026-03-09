import 'package:flutter/material.dart';
import '../models/agent_personality.dart';

/// Detail screen for a single agent
class AgentDetailScreen extends StatelessWidget {
  final AgentPersonality agent;
  final VoidCallback? onActivate;

  const AgentDetailScreen({
    super.key,
    required this.agent,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(agent.emoji),
            const SizedBox(width: 8),
            Expanded(child: Text(agent.name)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${agent.name} added to favorites!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: agent.division.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              agent.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agent.role,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: agent.division.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${agent.division.emoji} ${agent.division.displayName}',
                                  style: TextStyle(
                                    color: agent.division.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      agent.shortDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Communication style
            _buildSection(
              context,
              '💬 Communication Style',
              agent.communicationStyle,
            ),

            // Specialties
            _buildSection(
              context,
              '🎯 Specialties',
              agent.specialties.map((s) => '• $s').join('\n'),
            ),

            // Workflows
            _buildSection(
              context,
              '🔄 Workflow',
              agent.workflows.join('\n'),
            ),

            // Deliverables
            _buildSection(
              context,
              '📦 Deliverables',
              agent.deliverables.map((d) => '• $d').join('\n'),
            ),

            // Success metrics
            _buildSection(
              context,
              '✅ Success Metrics',
              agent.successMetrics.map((m) => '• $m').join('\n'),
            ),

            // Example phrases
            if (agent.examplePhrases.isNotEmpty)
              _buildSection(
                context,
                '🗣️ Example Phrases',
                agent.examplePhrases.entries
                    .map((e) => '"${e.key}": ${e.value}')
                    .join('\n'),
              ),

            const SizedBox(height: 24),

            // Activate button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (onActivate != null) {
                    onActivate!();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${agent.name} activated!'),
                      backgroundColor: agent.division.color,
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Activate Agent'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: agent.division.color,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}