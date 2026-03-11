import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/agent_session.dart';
import '../widgets/pixel_agent_avatar.dart';

class OfficePreviewScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const OfficePreviewScreen({super.key, this.gatewayService});

  @override
  State<OfficePreviewScreen> createState() => _OfficePreviewScreenState();
}

class _OfficePreviewScreenState extends State<OfficePreviewScreen> {
  GatewayService? _service;
  List<AgentSession> _agents = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Office zones (simplified positions for mobile)
  final List<OfficeZone> _zones = [
    OfficeZone(id: 'desk1', name: 'Desk 1', x: 0.25, y: 0.3),
    OfficeZone(id: 'desk2', name: 'Desk 2', x: 0.5, y: 0.3),
    OfficeZone(id: 'desk3', name: 'Desk 3', x: 0.75, y: 0.3),
    OfficeZone(id: 'lounge', name: 'Lounge', x: 0.25, y: 0.7),
    OfficeZone(id: 'kitchen', name: 'Kitchen', x: 0.75, y: 0.7),
    OfficeZone(id: 'meeting', name: 'Meeting', x: 0.5, y: 0.55),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (widget.gatewayService != null) {
      setState(() => _service = widget.gatewayService);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final gatewayUrl =
          prefs.getString('gateway_url') ?? 'http://localhost:18789';
      final token = prefs.getString('gateway_token');
      setState(
          () => _service = GatewayService(baseUrl: gatewayUrl, token: token));
    }
    await _refreshAgents();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refreshAgents());
  }

  Future<void> _refreshAgents() async {
    if (_service == null) return;

    try {
      final agents = await _service!.getAgents();
      if (mounted) {
        setState(() {
          _agents = agents ?? [];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getZoneForAgent(AgentSession agent) {
    // Assign agents to zones based on their name or index
    final mainAgents = _agents.where((a) => !a.isSubagent).toList();
    final index = mainAgents.indexOf(agent);

    if (index < _zones.length - 1) {
      return _zones[index].name;
    }
    return 'Working';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAgents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Connection Error',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshAgents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final activeCount = _agents.where((a) => a.isActive).length;
    final idleCount = _agents.where((a) => !a.isActive).length;

    return Column(
      children: [
        // Office visualization
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Stack(
              children: [
                // Office floor background
                CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(),
                ),

                // Zones
                ..._zones.map((zone) => _buildZone(zone)),

                // Agent indicators
                ..._buildAgentIndicators(),
              ],
            ),
          ),
        ),

        // Status summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusBadge('Working', activeCount, Colors.green),
                _buildStatusBadge('Idle', idleCount, Colors.grey),
                _buildStatusBadge(
                    'Total', _agents.length, const Color(0xFF00D4AA)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZone(OfficeZone zone) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * zone.x - 30,
                top: constraints.maxHeight * zone.y - 20,
                child: Column(
                  children: [
                    Icon(
                      _getZoneIcon(zone.id),
                      color: Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zone.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getZoneIcon(String zoneId) {
    switch (zoneId) {
      case 'desk1':
      case 'desk2':
      case 'desk3':
        return Icons.desk;
      case 'lounge':
        return Icons.weekend;
      case 'kitchen':
        return Icons.kitchen;
      case 'meeting':
        return Icons.meeting_room;
      default:
        return Icons.location_on;
    }
  }

  List<Widget> _buildAgentIndicators() {
    final mainAgents = _agents.where((a) => !a.isSubagent).toList();
    final widgets = <Widget>[];

    for (var i = 0; i < mainAgents.length && i < _zones.length - 1; i++) {
      final agent = mainAgents[i];
      final zone = _zones[i];

      widgets.add(
        LayoutBuilder(
          builder: (context, constraints) {
            return Positioned(
              left: constraints.maxWidth * zone.x - 28,
              top: constraints.maxHeight * zone.y - 2,
              child: _buildAgentDot(agent),
            );
          },
        ),
      );
    }

    // Overflow agents
    if (mainAgents.length > _zones.length - 1) {
      widgets.add(
        LayoutBuilder(
          builder: (context, constraints) {
            return Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${mainAgents.length - (_zones.length - 1)} more',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            );
          },
        ),
      );
    }

    return widgets;
  }

  Widget _buildAgentDot(AgentSession agent) {
    final isActive = agent.isActive;
    final statusColor = isActive ? Colors.green : Colors.grey;

    return GestureDetector(
      onTap: () => _showAgentInfo(agent),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (isActive)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.25),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Container(
                      width: 34 * value,
                      height: 34 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.18),
                      ),
                    );
                  },
                ),
              PixelAgentAvatar(
                seed: agent.name,
                emoji: agent.emoji,
                model: agent.model,
                kind: agent.kind,
                identityTheme: agent.identityTheme,
                isActive: agent.isActive,
                isSubagent: agent.isSubagent,
                status: agent.agentStatus ?? agent.statusSummary,
                statusColor: statusColor,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              agent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  void _showAgentInfo(AgentSession agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                PixelAgentAvatar(
                  seed: agent.name,
                  emoji: agent.emoji,
                  model: agent.model,
                  kind: agent.kind,
                  identityTheme: agent.identityTheme,
                  isActive: agent.isActive,
                  isSubagent: agent.isSubagent,
                  status: agent.agentStatus ?? agent.statusSummary,
                  size: 56,
                  showEmojiBadge: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  agent.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            agent.isActive ? 'Working' : 'Idle',
                            style: TextStyle(
                              color:
                                  agent.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (agent.statusSummary != null)
              _buildInfoRow('Status', agent.statusSummary!),
            if (agent.currentToolName != null)
              _buildInfoRow('Tool', agent.currentToolName!),
            _buildInfoRow('Zone', _getZoneForAgent(agent)),
            _buildInfoRow('Model', agent.model),
            _buildInfoRow('Tokens', _formatTokens(agent.totalTokens)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }
}

class OfficeZone {
  final String id;
  final String name;
  final double x;
  final double y;

  OfficeZone({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0A0A0F);
    canvas.drawRect(Offset.zero & size, bgPaint);

    const cols = 24;
    const rows = 20;
    final tileWidth = size.width / cols;
    final tileHeight = size.height / rows;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final tilePaint = Paint()..color = _floorColor(col, row);
        canvas.drawRect(
          Rect.fromLTWH(
            col * tileWidth,
            row * tileHeight,
            tileWidth + 0.5,
            tileHeight + 0.5,
          ),
          tilePaint,
        );
      }
    }

    final wallPaint = Paint()
      ..color = const Color(0xFF232733)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF3B4354)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final roomRects = [
      Rect.fromLTWH(
          tileWidth * 12, tileHeight * 1, tileWidth * 5, tileHeight * 4),
      Rect.fromLTWH(
          tileWidth * 12, tileHeight * 6, tileWidth * 5, tileHeight * 4),
      Rect.fromLTWH(
          tileWidth * 18, tileHeight * 1, tileWidth * 5, tileHeight * 5),
      Rect.fromLTWH(
          tileWidth * 18, tileHeight * 7, tileWidth * 5, tileHeight * 4),
      Rect.fromLTWH(
          tileWidth * 18, tileHeight * 12, tileWidth * 5, tileHeight * 5),
    ];

    for (final rect in roomRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = Colors.black.withValues(alpha: 0.08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6)),
        wallPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6)),
        borderPaint,
      );
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(
        Offset(tileWidth * i, 0),
        Offset(tileWidth * i, size.height),
        gridPaint,
      );
    }
    for (var i = 1; i < rows; i++) {
      canvas.drawLine(
        Offset(0, tileHeight * i),
        Offset(size.width, tileHeight * i),
        gridPaint,
      );
    }
  }

  Color _floorColor(int col, int row) {
    final even = (col + row).isEven;
    if (col >= 12 && col <= 16 && row >= 1 && row <= 4) {
      return even ? const Color(0xFFA1887F) : const Color(0xFF8D6E63);
    }
    if (col >= 12 && col <= 16 && row >= 6 && row <= 9) {
      return even ? const Color(0xFFB3C5D7) : const Color(0xFFA4B8CC);
    }
    if (col >= 18 && col <= 22 && row >= 1 && row <= 5) {
      return even ? const Color(0xFFE8D5B7) : const Color(0xFFDDC9AB);
    }
    if (col >= 18 && col <= 22 && row >= 7 && row <= 10) {
      return even ? const Color(0xFF455A64) : const Color(0xFF37474F);
    }
    if (col >= 18 && col <= 22 && row >= 12 && row <= 16) {
      return even ? const Color(0xFFD1C4E9) : const Color(0xFFC5B6DF);
    }
    return even ? const Color(0xFFD7CCC8) : const Color(0xFFCFBFB5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
