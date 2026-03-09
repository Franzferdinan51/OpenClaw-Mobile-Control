import 'package:flutter/material.dart';

/// Predefined action button styles
enum ActionButtonStyle {
  primary,
  secondary,
  danger,
  success,
  warning,
  ghost,
}

/// A Material 3 styled action button with multiple variants.
/// 
/// Features:
/// - Multiple style variants (primary, secondary, danger, etc.)
/// - Icon support (leading or trailing)
/// - Loading state
/// - Disabled state
/// - Compact mode
/// 
/// Usage:
/// ```dart
/// ActionButton(
///   label: 'Start Agent',
///   icon: Icons.play_arrow,
///   onPressed: () => _startAgent(),
/// ),
/// ```
class ActionButton extends StatelessWidget {
  /// Button label text
  final String label;
  
  /// Optional icon
  final IconData? icon;
  
  /// Icon position (leading or trailing)
  final bool iconTrailing;
  
  /// Callback when pressed
  final VoidCallback? onPressed;
  
  /// Button style variant
  final ActionButtonStyle style;
  
  /// Whether the button is in loading state
  final bool isLoading;
  
  /// Whether to use compact sizing
  final bool compact;
  
  /// Whether to fill available width
  final bool expanded;
  
  /// Custom background color (overrides style)
  final Color? backgroundColor;
  
  /// Custom foreground color (overrides style)
  final Color? foregroundColor;
  
  /// Tooltip text
  final String? tooltip;

  const ActionButton({
    super.key,
    required this.label,
    this.icon,
    this.iconTrailing = false,
    this.onPressed,
    this.style = ActionButtonStyle.primary,
    this.isLoading = false,
    this.compact = false,
    this.expanded = false,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final buttonStyle = _getButtonStyle(context);
    final isDisabled = onPressed == null || isLoading;
    
    Widget buttonWidget = _buildButton(context, theme, colorScheme, buttonStyle, isDisabled);
    
    if (tooltip != null) {
      buttonWidget = Tooltip(
        message: tooltip!,
        child: buttonWidget,
      );
    }
    
    if (expanded) {
      buttonWidget = SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }
    
    return buttonWidget;
  }

  Widget _buildButton(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    ButtonStyle buttonStyle,
    bool isDisabled,
  ) {
    final content = _buildContent(theme, colorScheme, isDisabled);
    
    switch (style) {
      case ActionButtonStyle.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle,
          child: content,
        );
      case ActionButtonStyle.secondary:
        return FilledButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle,
          child: content,
        );
      case ActionButtonStyle.danger:
      case ActionButtonStyle.success:
      case ActionButtonStyle.warning:
        return FilledButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle,
          child: content,
        );
      case ActionButtonStyle.ghost:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle,
          child: content,
        );
    }
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme, bool isDisabled) {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foregroundColor ?? _getDefaultForegroundColor(colorScheme),
        ),
      );
    }
    
    final hasIcon = icon != null;
    final hasLeadingIcon = hasIcon && !iconTrailing;
    final hasTrailingIcon = hasIcon && iconTrailing;
    
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasLeadingIcon) ...[
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: 8),
        ],
        Text(label),
        if (hasTrailingIcon) ...[
          const SizedBox(width: 8),
          Icon(icon, size: _getIconSize()),
        ],
      ],
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultStyle = _getDefaultStyle(colorScheme);
    
    return ButtonStyle(
      backgroundColor: backgroundColor != null
          ? WidgetStatePropertyAll(backgroundColor!)
          : defaultStyle.backgroundColor,
      foregroundColor: foregroundColor != null
          ? WidgetStatePropertyAll(foregroundColor!)
          : defaultStyle.foregroundColor,
      padding: WidgetStatePropertyAll(_getPadding()),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 8 : 12)),
      ),
    );
  }

  ButtonStyle _getDefaultStyle(ColorScheme colorScheme) {
    switch (style) {
      case ActionButtonStyle.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        );
      case ActionButtonStyle.secondary:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        );
      case ActionButtonStyle.danger:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        );
      case ActionButtonStyle.success:
        return FilledButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        );
      case ActionButtonStyle.warning:
        return FilledButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        );
      case ActionButtonStyle.ghost:
        return TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        );
    }
  }

  Color _getDefaultForegroundColor(ColorScheme colorScheme) {
    switch (style) {
      case ActionButtonStyle.primary:
        return colorScheme.onPrimary;
      case ActionButtonStyle.secondary:
        return colorScheme.onSecondaryContainer;
      case ActionButtonStyle.danger:
        return colorScheme.onError;
      case ActionButtonStyle.success:
        return Colors.white;
      case ActionButtonStyle.warning:
        return Colors.white;
      case ActionButtonStyle.ghost:
        return colorScheme.primary;
    }
  }

  EdgeInsets _getPadding() {
    if (compact) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  }

  double _getIconSize() {
    return compact ? 16 : 18;
  }
}

/// A row of action buttons with consistent spacing
class ActionButtonRow extends StatelessWidget {
  /// List of action buttons
  final List<ActionButton> buttons;
  
  /// Spacing between buttons
  final double spacing;
  
  /// Whether buttons should be equal width
  final bool equalWidth;
  
  /// Main axis alignment
  final MainAxisAlignment mainAxisAlignment;

  const ActionButtonRow({
    super.key,
    required this.buttons,
    this.spacing = 8,
    this.equalWidth = true,
    this.mainAxisAlignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    
    if (equalWidth && buttons.length > 1) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        children: buttons
            .map((button) => Expanded(child: button))
            .toList()
            ._interleave(SizedBox(width: spacing)),
      );
    }
    
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: mainAxisAlignment == MainAxisAlignment.end
          ? WrapAlignment.end
          : mainAxisAlignment == MainAxisAlignment.center
              ? WrapAlignment.center
              : WrapAlignment.start,
      children: buttons,
    );
  }
}

/// Extension to interleave widgets with separators
extension _ListInterleave<T> on List<Widget> {
  List<Widget> _interleave(Widget separator) {
    if (length <= 1) return this;
    
    return List<Widget>.generate(
      length * 2 - 1,
      (index) => index.isEven ? this[index ~/ 2] : separator,
    );
  }
}

/// A floating action button with label
class LabeledFloatingActionButton extends StatelessWidget {
  /// Button label
  final String label;
  
  /// Optional icon
  final IconData? icon;
  
  /// Callback when pressed
  final VoidCallback? onPressed;
  
  /// Whether the button is extended
  final bool extended;
  
  /// Custom color
  final Color? backgroundColor;
  
  /// Custom foreground color
  final Color? foregroundColor;

  const LabeledFloatingActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.extended = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (extended) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
        foregroundColor: foregroundColor ?? colorScheme.onPrimaryContainer,
        icon: icon != null ? Icon(icon) : null,
        label: Text(label),
      );
    }
    
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onPrimaryContainer,
      tooltip: label,
      child: icon != null ? Icon(icon) : Text(label[0]),
    );
  }
}

/// A segmented button group for related actions
class ActionSegmentedButton<T> extends StatelessWidget {
  /// Current selected value
  final T selected;
  
  /// List of options
  final List<SegmentedOption<T>> options;
  
  /// Callback when selection changes
  final ValueChanged<T>? onSelectionChanged;
  
  /// Whether multiple selection is allowed
  final bool multiSelectionEnabled;

  const ActionSegmentedButton({
    super.key,
    required this.selected,
    required this.options,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SegmentedButton<T>(
      segments: options.map((option) {
        return ButtonSegment<T>(
          value: option.value,
          label: option.label != null ? Text(option.label!) : null,
          icon: option.icon != null ? Icon(option.icon) : null,
          tooltip: option.tooltip,
        );
      }).toList(),
      selected: {selected},
      onSelectionChanged: (Set<T> selection) {
        if (onSelectionChanged != null && selection.isNotEmpty) {
          onSelectionChanged!(selection.first);
        }
      },
      multiSelectionEnabled: multiSelectionEnabled,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimaryContainer;
          }
          return null;
        }),
      ),
    );
  }
}

/// Represents an option in a segmented button
class SegmentedOption<T> {
  final T value;
  final String? label;
  final IconData? icon;
  final String? tooltip;

  const SegmentedOption({
    required this.value,
    this.label,
    this.icon,
    this.tooltip,
  });
}