import 'package:flutter/material.dart';
import '../services/token_service.dart';

/// Real-time token counter widget
class TokenCounter extends StatefulWidget {
  final TokenService tokenService;
  final bool showCost;
  final bool showBreakdown;
  final TokenCounterStyle style;

  const TokenCounter({
    super.key,
    required this.tokenService,
    this.showCost = true,
    this.showBreakdown = false,
    this.style = TokenCounterStyle.compact,
  });

  @override
  State<TokenCounter> createState() => _TokenCounterState();
}

enum TokenCounterStyle {
  compact,
  detailed,
  minimal,
}

class _TokenCounterState extends State<TokenCounter> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TokenUsage?>(
      stream: widget.tokenService.sessionUsageStream,
      initialData: widget.tokenService.currentSessionUsage,
      builder: (context, snapshot) {
        final usage = snapshot.data;
        
        switch (widget.style) {
          case TokenCounterStyle.compact:
            return _buildCompact(usage);
          case TokenCounterStyle.detailed:
            return _buildDetailed(usage);
          case TokenCounterStyle.minimal:
            return _buildMinimal(usage);
        }
      },
    );
  }

  Widget _buildCompact(TokenUsage? usage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.token,
            size: 16,
            color: _getTokenColor(usage?.totalTokens ?? 0),
          ),
          const SizedBox(width: 6),
          Text(
            _formatTokens(widget.tokenService.sessionTotalTokens),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _getTokenColor(usage?.totalTokens ?? 0),
            ),
          ),
          if (widget.showCost && widget.tokenService.sessionEstimatedCost > 0) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              '\$${widget.tokenService.sessionEstimatedCost.toStringAsFixed(3)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailed(TokenUsage? usage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Token Usage',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTokens(widget.tokenService.sessionTotalTokens),
                  style: const TextStyle(
                    color: Color(0xFF00D4AA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          if (widget.showBreakdown) ...[
            const SizedBox(height: 12),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _getQuotaPercentage() / 100,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getTokenColor(widget.tokenService.sessionTotalTokens),
                ),
                minHeight: 6,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildBreakdownItem(
                    'Prompt',
                    widget.tokenService.sessionPromptTokens,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBreakdownItem(
                    'Completion',
                    widget.tokenService.sessionCompletionTokens,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
          
          if (widget.showCost && widget.tokenService.sessionEstimatedCost > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Cost',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '\$${widget.tokenService.sessionEstimatedCost.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimal(TokenUsage? usage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.token,
          size: 14,
          color: _getTokenColor(usage?.totalTokens ?? 0),
        ),
        const SizedBox(width: 4),
        Text(
          _formatTokens(widget.tokenService.sessionTotalTokens),
          style: TextStyle(
            fontSize: 12,
            color: _getTokenColor(usage?.totalTokens ?? 0),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            _formatTokens(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTokenColor(int tokens) {
    // Default colors based on usage thresholds
    if (tokens < 1000) return Colors.grey;
    if (tokens < 10000) return const Color(0xFF00D4AA);
    if (tokens < 50000) return Colors.orange;
    return Colors.red;
  }

  double _getQuotaPercentage() {
    final quota = widget.tokenService.quota;
    if (quota == null) return 0;
    return quota.monthPercentage;
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

/// Animated token counter that shows changes
class AnimatedTokenCounter extends StatefulWidget {
  final TokenService tokenService;
  final Duration animationDuration;

  const AnimatedTokenCounter({
    super.key,
    required this.tokenService,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedTokenCounter> createState() => _AnimatedTokenCounterState();
}

class _AnimatedTokenCounterState extends State<AnimatedTokenCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _lastTokenCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TokenUsage?>(
      stream: widget.tokenService.sessionUsageStream,
      builder: (context, snapshot) {
        final currentTokens = widget.tokenService.sessionTotalTokens;
        
        // Animate on change
        if (currentTokens != _lastTokenCount && _lastTokenCount > 0) {
          _controller.forward(from: 0);
        }
        _lastTokenCount = currentTokens;
        
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.token, size: 14, color: Color(0xFF00D4AA)),
                const SizedBox(width: 4),
                Text(
                  _formatTokens(currentTokens),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF00D4AA),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }
}