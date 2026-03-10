import 'package:flutter/material.dart';

/// Context window progress indicator
class ContextProgress extends StatefulWidget {
  final int currentTokens;
  final int maxTokens;
  final bool showWarning;
  final double warningThreshold;
  final double criticalThreshold;
  final VoidCallback? onCompactSuggested;

  const ContextProgress({
    super.key,
    required this.currentTokens,
    required this.maxTokens,
    this.showWarning = true,
    this.warningThreshold = 0.8,
    this.criticalThreshold = 0.95,
    this.onCompactSuggested,
  });

  @override
  State<ContextProgress> createState() => _ContextProgressState();
}

class _ContextProgressState extends State<ContextProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _percentage {
    if (widget.maxTokens <= 0) return 0;
    return (widget.currentTokens / widget.maxTokens).clamp(0.0, 1.0);
  }

  bool get _isWarning => _percentage >= widget.warningThreshold;
  bool get _isCritical => _percentage >= widget.criticalThreshold;

  @override
  Widget build(BuildContext context) {
    // Pulse animation when critical
    if (_isCritical && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_isCritical && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return ScaleTransition(
      scale: _isCritical ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
          border: _isWarning
              ? Border.all(color: _getProgressColor(), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getIcon(),
                      size: 16,
                      color: _getProgressColor(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Context Window',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isWarning ? _getProgressColor() : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(_percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getProgressColor(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Progress bar
            Stack(
              children: [
                // Background
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress
                FractionallySizedBox(
                  widthFactor: _percentage,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getProgressColor(),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: _isWarning
                          ? [
                              BoxShadow(
                                color: _getProgressColor().withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Token count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatTokens(widget.currentTokens)} / ${_formatTokens(widget.maxTokens)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  '${_formatTokens(widget.maxTokens - widget.currentTokens)} remaining',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isWarning ? _getProgressColor() : Colors.grey[500],
                  ),
                ),
              ],
            ),
            
            // Warning message
            if (widget.showWarning && _isWarning) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getProgressColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCritical ? Icons.warning : Icons.info_outline,
                      size: 14,
                      color: _getProgressColor(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCritical
                            ? 'Context nearly full! Compact or reset to continue.'
                            : 'Context approaching limit. Consider compacting.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getProgressColor(),
                        ),
                      ),
                    ),
                    if (widget.onCompactSuggested != null)
                      TextButton(
                        onPressed: widget.onCompactSuggested,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: Text(
                          'Compact',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getProgressColor(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_isCritical) return Colors.red.withOpacity(0.05);
    if (_isWarning) return Colors.orange.withOpacity(0.05);
    return Colors.grey[850]!;
  }

  Color _getProgressColor() {
    if (_isCritical) return Colors.red;
    if (_isWarning) return Colors.orange;
    return const Color(0xFF00D4AA);
  }

  IconData _getIcon() {
    if (_isCritical) return Icons.warning;
    if (_isWarning) return Icons.info_outline;
    return Icons.memory;
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K';
    }
    return tokens.toString();
  }
}

/// Compact context indicator for headers/toolbars
class ContextIndicator extends StatelessWidget {
  final int currentTokens;
  final int maxTokens;
  final double warningThreshold;

  const ContextIndicator({
    super.key,
    required this.currentTokens,
    required this.maxTokens,
    this.warningThreshold = 0.8,
  });

  double get _percentage {
    if (maxTokens <= 0) return 0;
    return (currentTokens / maxTokens).clamp(0.0, 1.0);
  }

  bool get _isWarning => _percentage >= warningThreshold;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Context: ${_formatTokens(currentTokens)} / ${_formatTokens(maxTokens)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isWarning ? Colors.orange.withOpacity(0.1) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini progress bar
            SizedBox(
              width: 32,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _percentage,
                  backgroundColor: Colors.grey[700],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isWarning ? Colors.orange : const Color(0xFF00D4AA),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(_percentage * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _isWarning ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K';
    }
    return tokens.toString();
  }
}