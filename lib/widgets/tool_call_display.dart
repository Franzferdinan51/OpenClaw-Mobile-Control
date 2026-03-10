import 'dart:convert';
import 'package:flutter/material.dart';

/// Tool call visualization widget
class ToolCallDisplay extends StatefulWidget {
  final String toolName;
  final Map<String, dynamic>? parameters;
  final dynamic result;
  final String? error;
  final Duration? duration;
  final bool isExpanded;
  final bool showTimestamp;
  final DateTime? timestamp;

  const ToolCallDisplay({
    super.key,
    required this.toolName,
    this.parameters,
    this.result,
    this.error,
    this.duration,
    this.isExpanded = false,
    this.showTimestamp = true,
    this.timestamp,
  });

  @override
  State<ToolCallDisplay> createState() => _ToolCallDisplayState();
}

class _ToolCallDisplayState extends State<ToolCallDisplay> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final toolType = _getToolType(widget.toolName);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: toolType.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: toolType.color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Tool icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: toolType.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      toolType.icon,
                      size: 16,
                      color: toolType.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Tool name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.toolName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: toolType.color,
                              ),
                            ),
                            if (widget.duration != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatDuration(widget.duration!),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.showTimestamp && widget.timestamp != null)
                          Text(
                            _formatTime(widget.timestamp!),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Status icon
                  Icon(
                    widget.error != null
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: widget.error != null ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  
                  // Expand icon
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parameters
                  if (widget.parameters != null && widget.parameters!.isNotEmpty) ...[
                    _buildSection(
                      'Parameters',
                      _prettyPrintJson(widget.parameters),
                      Icons.input,
                      Colors.blue,
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Result or error
                  if (widget.error != null)
                    _buildSection(
                      'Error',
                      widget.error!,
                      Icons.error_outline,
                      Colors.red,
                    )
                  else if (widget.result != null)
                    _buildSection(
                      'Result',
                      _prettyPrintJson(widget.result),
                      Icons.output,
                      Colors.green,
                    ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  ToolType get _toolType => _getToolType(widget.toolName);

  ToolType _getToolType(String toolName) {
    final name = toolName.toLowerCase();
    
    if (name.contains('read') || name.contains('write') || name.contains('edit')) {
      return ToolType.file;
    } else if (name.contains('exec') || name.contains('process')) {
      return ToolType.shell;
    } else if (name.contains('web') || name.contains('fetch') || name.contains('search')) {
      return ToolType.web;
    } else if (name.contains('browser')) {
      return ToolType.browser;
    } else if (name.contains('message') || name.contains('send')) {
      return ToolType.message;
    } else if (name.contains('image') || name.contains('pdf')) {
      return ToolType.media;
    } else if (name.contains('node') || name.contains('canvas')) {
      return ToolType.node;
    } else {
      return ToolType.other;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _prettyPrintJson(dynamic json) {
    if (json is String) return json;
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}

enum ToolType {
  file(Icons.folder, Colors.orange),
  shell(Icons.terminal, Colors.green),
  web(Icons.language, Colors.blue),
  browser(Icons.open_in_browser, Colors.purple),
  message(Icons.message, Colors.teal),
  media(Icons.image, Colors.pink),
  node(Icons.devices, Colors.cyan),
  other(Icons.build, Colors.grey);

  final IconData icon;
  final Color color;

  const ToolType(this.icon, this.color);
}