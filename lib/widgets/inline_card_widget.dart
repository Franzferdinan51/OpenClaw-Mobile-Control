import 'package:flutter/material.dart';
import '../models/inline_widget.dart';

/// Inline Card Widget - ChatGPT-style inline info cards in chat
/// 
/// Displays info cards directly in the message stream.
/// Supports titles, descriptions, icons, colors, and actions.
class InlineCardWidget extends StatefulWidget {
  final InfoCardWidgetData data;
  final VoidCallback? onTap;
  final bool compact;
  
  const InlineCardWidget({
    super.key,
    required this.data,
    this.onTap,
    this.compact = false,
  });
  
  @override
  State<InlineCardWidget> createState() => _InlineCardWidgetState();
}

class _InlineCardWidgetState extends State<InlineCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.compact
            ? _buildCompactCard(context)
            : _buildFullCard(context),
      ),
    );
  }
  
  Widget _buildFullCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _parseColor(widget.data.color);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.data.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.data.icon!,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.data.title ?? 'Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (widget.onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                  ],
                ),
              ),
              
              // Description
              if (widget.data.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.data.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
              
              // Actions
              if (widget.data.actions != null && widget.data.actions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.data.actions!.map((action) {
                      return _buildActionButton(context, action, accentColor);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCompactCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _parseColor(widget.data.color);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.data.icon != null) ...[
              Text(widget.data.icon!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.data.title ?? 'Info',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (widget.data.description.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.data.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context,
    InfoCardAction action,
    Color accentColor,
  ) {
    return InkWell(
      onTap: () {
        // Handle action
        // In a real app, this would trigger the action
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[
              Text(action.icon!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _parseColor(String? colorStr) {
    if (colorStr == null) return const Color(0xFF00D4AA);
    
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      if (colorStr.startsWith('0x')) {
        return Color(int.parse(colorStr));
      }
      // Named colors
      const namedColors = {
        'red': Colors.red,
        'green': Colors.green,
        'blue': Colors.blue,
        'orange': Colors.orange,
        'purple': Colors.purple,
        'teal': Colors.teal,
        'pink': Colors.pink,
        'cyan': Colors.cyan,
        'yellow': Colors.yellow,
        'grey': Colors.grey,
      };
      return namedColors[colorStr.toLowerCase()] ?? const Color(0xFF00D4AA);
    } catch (e) {
      return const Color(0xFF00D4AA);
    }
  }
}

/// Inline Status Widget - For quick status indicators in chat
class InlineStatusWidget extends StatefulWidget {
  final StatusWidgetData data;
  final VoidCallback? onTap;
  
  const InlineStatusWidget({
    super.key,
    required this.data,
    this.onTap,
  });
  
  @override
  State<InlineStatusWidget> createState() => _InlineStatusWidgetState();
}

class _InlineStatusWidgetState extends State<InlineStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(widget.data.status);
    
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_animation),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status header
                Row(
                  children: [
                    _buildStatusIndicator(widget.data.status, statusColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.data.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (widget.data.message != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.data.message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Status items
                if (widget.data.items != null && widget.data.items!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: widget.data.items!.map((item) {
                        return _buildStatusItem(context, item, isDark);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusIndicator(String status, Color color) {
    final isLoading = status.toLowerCase() == 'loading' ||
        status.toLowerCase() == 'processing';
    
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isLoading ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          : null,
    );
  }
  
  Widget _buildStatusItem(BuildContext context, StatusItem item, bool isDark) {
    final color = _parseColor(item.color);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Text(item.icon!, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
        ],
        Text(
          '${item.label}:',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          item.value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'complete':
      case 'done':
        return Colors.green;
      case 'error':
      case 'failed':
        return Colors.red;
      case 'warning':
      case 'pending':
        return Colors.orange;
      case 'loading':
      case 'processing':
        return Colors.blue;
      case 'idle':
      case 'paused':
        return Colors.grey;
      default:
        return const Color(0xFF00D4AA);
    }
  }
  
  Color _parseColor(String? colorStr) {
    if (colorStr == null) return Colors.white;
    
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      return Color(int.parse(colorStr));
    } catch (e) {
      return Colors.white;
    }
  }
}