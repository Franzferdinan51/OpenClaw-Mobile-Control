import 'package:flutter/material.dart';
import 'info_card.dart';

/// Action card with buttons for user interactions
/// 
/// Features:
/// - Action buttons with icons
/// - Confirm actions
/// - Toggle switches
/// - Quick action chips
class ActionCard extends InfoCard {
  final List<ActionItem> actionItems;
  final ActionCardLayout layout;
  final String? confirmMessage;
  final ActionItem? primaryAction;

  const ActionCard({
    super.key,
    super.title,
    super.subtitle,
    super.leading,
    super.trailing,
    super.accentColor,
    super.onTap,
    super.onLongPress,
    super.actions,
    super.isLoading,
    super.errorMessage,
    super.padding,
    super.margin,
    super.enableSwipe,
    super.swipeLeftAction,
    super.swipeRightAction,
    required this.actionItems,
    this.layout = ActionCardLayout.horizontal,
    this.confirmMessage,
    this.primaryAction,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary action (if provided)
        if (primaryAction != null) ...[
          _PrimaryActionButton(action: primaryAction!),
          const SizedBox(height: 16),
        ],
        
        // Action items
        switch (layout) {
          ActionCardLayout.horizontal => _buildHorizontalLayout(context),
          ActionCardLayout.vertical => _buildVerticalLayout(context),
          ActionCardLayout.grid => _buildGridLayout(context),
          ActionCardLayout.chips => _buildChipsLayout(context),
        },
      ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    return Row(
      children: actionItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index > 0 ? 8 : 0),
            child: _ActionButton(action: item),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: actionItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
          child: _ActionButton(action: item, expanded: true),
        );
      }).toList(),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: actionItems.map((item) => _ActionButton(action: item)).toList(),
    );
  }

  Widget _buildChipsLayout(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actionItems.map((item) => _ActionChip(action: item)).toList(),
    );
  }
}

/// Action card layout types
enum ActionCardLayout {
  horizontal,
  vertical,
  grid,
  chips,
}

/// Action item configuration
class ActionItem {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isEnabled;
  final bool isLoading;
  final String? confirmTitle;
  final String? confirmMessage;

  const ActionItem({
    required this.label,
    required this.icon,
    this.color,
    this.onTap,
    this.isDestructive = false,
    this.isEnabled = true,
    this.isLoading = false,
    this.confirmTitle,
    this.confirmMessage,
  });
}

/// Action button widget
class _ActionButton extends StatefulWidget {
  final ActionItem action;
  final bool expanded;

  const _ActionButton({required this.action, this.expanded = false});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.action.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.action.color ?? 
        (widget.action.isDestructive ? Colors.red : const Color(0xFF00D4AA));
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.action.isEnabled && !_isLoading 
            ? () => _handleTap(context)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(widget.action.isEnabled ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(widget.action.isEnabled ? 0.3 : 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded 
                ? MainAxisAlignment.start 
                : MainAxisAlignment.center,
            children: [
              if (_isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(
                  widget.action.icon,
                  size: 18,
                  color: widget.action.isEnabled ? color : color.withOpacity(0.5),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.action.label,
                  style: TextStyle(
                    color: widget.action.isEnabled ? color : color.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    // Check if confirmation is needed
    if (widget.action.confirmTitle != null || widget.action.confirmMessage != null) {
      final confirmed = await _showConfirmationDialog(context);
      if (!confirmed) return;
    }
    
    if (widget.action.onTap == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      widget.action.onTap!();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.action.confirmTitle ?? 'Confirm Action',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          widget.action.confirmMessage ?? 'Are you sure you want to continue?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: TextStyle(
                color: widget.action.isDestructive ? Colors.red : const Color(0xFF00D4AA),
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
}

/// Primary action button (larger, more prominent)
class _PrimaryActionButton extends StatefulWidget {
  final ActionItem action;

  const _PrimaryActionButton({required this.action});

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.action.color ?? const Color(0xFF00D4AA);
    
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.action.isEnabled && !_isLoading 
          ? () => _handleTap(context)
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  else
                    Icon(
                      widget.action.icon,
                      color: Colors.black,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    widget.action.label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (widget.action.confirmTitle != null || widget.action.confirmMessage != null) {
      final confirmed = await _showConfirmationDialog(context);
      if (!confirmed) return;
    }
    
    if (widget.action.onTap == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      widget.action.onTap!();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.action.confirmTitle ?? 'Confirm'),
        content: Text(widget.action.confirmMessage ?? 'Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
}

/// Action chip widget
class _ActionChip extends StatefulWidget {
  final ActionItem action;

  const _ActionChip({required this.action});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.action.color ?? const Color(0xFF00D4AA);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.action.isEnabled && !_isLoading 
            ? _handleTap
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(widget.action.icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                widget.action.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.action.onTap == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      widget.action.onTap!();
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    }
  }
}

/// Quick actions card - specialized for quick actions
class QuickActionsCard extends StatelessWidget {
  final List<ActionItem> actions;
  final String? title;

  const QuickActionsCard({
    super.key,
    required this.actions,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: title ?? 'Quick Actions',
      actionItems: actions,
      layout: ActionCardLayout.chips,
    );
  }
}

/// Confirmation card - specialized for confirming actions
class ConfirmationCard extends StatelessWidget {
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final IconData? icon;

  const ConfirmationCard({
    super.key,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      leading: icon != null
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : const Color(0xFF00D4AA)).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : const Color(0xFF00D4AA),
              ),
            )
          : null,
      actionItems: [
        ActionItem(
          label: cancelLabel,
          icon: Icons.close,
          color: Colors.grey,
          onTap: onCancel,
        ),
        ActionItem(
          label: confirmLabel,
          icon: Icons.check,
          color: isDestructive ? Colors.red : const Color(0xFF00D4AA),
          onTap: onConfirm,
          isDestructive: isDestructive,
        ),
      ],
      layout: ActionCardLayout.horizontal,
    );
  }
}