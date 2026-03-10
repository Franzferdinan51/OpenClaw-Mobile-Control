import 'package:flutter/material.dart';

/// Base info card widget - ChatGPT-like generative UI component
/// 
/// Provides common functionality for all info cards:
/// - Animated transitions
/// - Swipe actions
/// - Long-press menu
/// - Consistent styling
/// - Loading/error states
abstract class InfoCard extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<InfoCardAction>? actions;
  final bool isLoading;
  final String? errorMessage;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableSwipe;
  final InfoCardSwipeAction? swipeLeftAction;
  final InfoCardSwipeAction? swipeRightAction;

  const InfoCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.accentColor,
    this.onTap,
    this.onLongPress,
    this.actions,
    this.isLoading = false,
    this.errorMessage,
    this.padding,
    this.margin,
    this.enableSwipe = true,
    this.swipeLeftAction,
    this.swipeRightAction,
  });

  /// Build the card content (implemented by subclasses)
  Widget buildContent(BuildContext context);

  @override
  State<InfoCard> createState() => InfoCardState();
}

class InfoCardState extends State<InfoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  double _swipeOffset = 0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: _buildSwipeableCard(context),
    );
  }

  Widget _buildSwipeableCard(BuildContext context) {
    if (!widget.enableSwipe || 
        (widget.swipeLeftAction == null && widget.swipeRightAction == null)) {
      return _buildCardContent(context);
    }

    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _isSwiping = true),
      onHorizontalDragUpdate: (details) {
        setState(() {
          _swipeOffset += details.delta.dx;
          _swipeOffset = _swipeOffset.clamp(-150.0, 150.0);
        });
      },
      onHorizontalDragEnd: (_) => _handleSwipeEnd(),
      child: Stack(
        children: [
          // Background actions
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Left swipe background
                  if (widget.swipeRightAction != null)
                    Expanded(
                      child: Container(
                        color: widget.swipeRightAction!.color.withOpacity(0.8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.swipeRightAction!.icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.swipeRightAction!.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Right swipe background
                  if (widget.swipeLeftAction != null)
                    Expanded(
                      child: Container(
                        color: widget.swipeLeftAction!.color.withOpacity(0.8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.swipeLeftAction!.icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.swipeLeftAction!.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Card content with offset
          Transform.translate(
            offset: Offset(_swipeOffset, 0),
            child: _buildCardContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final accentColor = widget.accentColor ?? const Color(0xFF00D4AA);
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onTap,
          onLongPress: widget.isLoading ? null : () => _handleLongPress(context),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
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
                  // Header (if title or leading provided)
                  if (widget.title != null || widget.leading != null)
                    _buildHeader(context, accentColor),
                  
                  // Content
                  if (widget.isLoading)
                    _buildLoadingState(context)
                  else if (widget.errorMessage != null)
                    _buildErrorState(context)
                  else
                    Padding(
                      padding: widget.padding ?? const EdgeInsets.all(16),
                      child: widget.buildContent(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF00D4AA),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.errorMessage!,
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSwipeEnd() {
    final threshold = 100.0;
    
    if (_swipeOffset > threshold && widget.swipeRightAction != null) {
      widget.swipeRightAction!.onAction();
    } else if (_swipeOffset < -threshold && widget.swipeLeftAction != null) {
      widget.swipeLeftAction!.onAction();
    }
    
    setState(() {
      _swipeOffset = 0;
      _isSwiping = false;
    });
  }

  void _handleLongPress(BuildContext context) {
    if (widget.actions == null || widget.actions!.isEmpty) {
      widget.onLongPress?.call();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Actions
              ...widget.actions!.map((action) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(action.icon, color: action.color),
                ),
                title: Text(action.label),
                subtitle: action.description != null ? Text(action.description!) : null,
                onTap: () {
                  Navigator.pop(context);
                  action.onAction();
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swipe action configuration
class InfoCardSwipeAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onAction;

  const InfoCardSwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onAction,
  });
}

/// Action configuration for long-press menu
class InfoCardAction {
  final IconData icon;
  final String label;
  final String? description;
  final Color color;
  final VoidCallback onAction;

  const InfoCardAction({
    required this.icon,
    required this.label,
    this.description,
    this.color = const Color(0xFF00D4AA),
    required this.onAction,
  });
}

/// Card state enum for status cards
enum CardState {
  loading,
  success,
  warning,
  error,
  idle,
}

/// Extension for CardState styling
extension CardStateExtension on CardState {
  Color get color {
    switch (this) {
      case CardState.loading:
        return Colors.blue;
      case CardState.success:
        return Colors.green;
      case CardState.warning:
        return Colors.orange;
      case CardState.error:
        return Colors.red;
      case CardState.idle:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case CardState.loading:
        return Icons.hourglass_empty;
      case CardState.success:
        return Icons.check_circle;
      case CardState.warning:
        return Icons.warning;
      case CardState.error:
        return Icons.error;
      case CardState.idle:
        return Icons.pause_circle;
    }
  }

  String get label {
    switch (this) {
      case CardState.loading:
        return 'Loading';
      case CardState.success:
        return 'Success';
      case CardState.warning:
        return 'Warning';
      case CardState.error:
        return 'Error';
      case CardState.idle:
        return 'Idle';
    }
  }
}