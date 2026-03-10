import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../models/agent_session.dart';
import '../services/gateway_service.dart';

/// Detail screen for a single agent
/// Accepts either AgentPersonality (static profile) or AgentSession (live session)
class AgentDetailScreen extends StatelessWidget {
  final AgentPersonality? agent;
  final AgentSession? session;
  final GatewayService? gatewayService;
  final VoidCallback? onActivate;

  const AgentDetailScreen({
    super.key,
    this.agent,
    this.session,
    this.gatewayService,
    this.onActivate,
  }) : assert(agent != null || session != null, 'Must provide either agent or session');

  // Helper getters to unify access
  String get _name => agent?.name ?? session?.name ?? 'Unknown';
  String get _emoji => agent?.emoji ?? session?.emoji ?? '🤖';
  String get _description => agent?.shortDescription ?? session?.statusSummary ?? 'Agent session';
  String get _role => agent?.role ?? (session?.isSubagent == true ? 'Subagent' : 'Agent');
  Color get _color => agent?.division.color ?? const Color(0xFF00D4AA);
  String get _divisionName => agent?.division.displayName ?? (session?.isSubagent == true ? 'Subagent' : 'Primary Agent');
  String get _divisionEmoji => agent?.division.emoji ?? (session?.isSubagent == true ? '👥' : '🤖');

  @override
  Widget build(BuildContext context) {
    final isSession = session != null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_emoji),
            const SizedBox(width: 8),
            Expanded(child: Text(_name)),
          ],
        ),
        actions: [
          if (!isSession)
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$_name added to favorites!')),
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
                            color: _color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _emoji,
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
                                _role,
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
                                  color: _color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_divisionEmoji $_divisionName',
                                  style: TextStyle(
                                    color: _color,
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
                      _description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Session-specific info
            if (isSession && session != null) ...[
              _buildSessionInfoCard(context, session!),
              const SizedBox(height: 16),
            ],

            // Personality-specific sections
            if (agent != null) ...[
              // Communication style
              _buildSection(
                context,
                '💬 Communication Style',
                agent!.communicationStyle,
              ),

              // Specialties
              _buildSection(
                context,
                '🎯 Specialties',
                agent!.specialties.map((s) => '• $s').join('\n'),
              ),

              // Workflows
              _buildSection(
                context,
                '🔄 Workflow',
                agent!.workflows.join('\n'),
              ),

              // Deliverables
              _buildSection(
                context,
                '📦 Deliverables',
                agent!.deliverables.map((d) => '• $d').join('\n'),
              ),

              // Success metrics
              _buildSection(
                context,
                '✅ Success Metrics',
                agent!.successMetrics.map((m) => '• $m').join('\n'),
              ),

              // Example phrases
              if (agent!.examplePhrases.isNotEmpty)
                _buildSection(
                  context,
                  '🗣️ Example Phrases',
                  agent!.examplePhrases.entries
                      .map((e) => '"${e.key}": ${e.value}')
                      .join('\n'),
                ),
            ],

            const SizedBox(height: 24),

            // Action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (onActivate != null) {
                    onActivate!();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$_name activated!'),
                      backgroundColor: _color,
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(isSession ? 'Chat with Agent' : 'Activate Agent'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _color,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard(BuildContext context, AgentSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Info',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Model', session.model),
            _buildInfoRow('Channel', session.channel),
            _buildInfoRow('Kind', session.kind),
            if (session.currentToolName != null)
              _buildInfoRow('Current Tool', session.currentToolName!),
            if (session.usageKnown) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Input Tokens', '${session.inputTokens}'),
              _buildInfoRow('Output Tokens', '${session.outputTokens}'),
              _buildInfoRow('Total Tokens', '${session.totalTokens}'),
            ],
            _buildInfoRow('Active', session.isActive ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
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
