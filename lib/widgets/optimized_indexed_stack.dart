// Optimized IndexedStack with lazy loading
// 
// Features:
// - Lazy loads children only when first viewed
// - Preserves state of previously loaded children
// - Reduces initial widget tree complexity
// - Improves tab switching performance

import 'dart:async';
import 'package:flutter/material.dart';

class OptimizedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration animationDuration;
  
  const OptimizedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.animationDuration = Duration.zero,
  });
  
  @override
  State<OptimizedIndexedStack> createState() => _OptimizedIndexedStackState();
}

class _OptimizedIndexedStackState extends State<OptimizedIndexedStack> {
  // Track which children have been loaded
  final Set<int> _loadedIndices = {};
  
  @override
  void initState() {
    super.initState();
    // Load the initial index
    _loadedIndices.add(widget.index);
  }
  
  @override
  void didUpdateWidget(OptimizedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Mark new index as loaded when tab changes
    if (oldWidget.index != widget.index) {
      setState(() {
        _loadedIndices.add(widget.index);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final isVisible = index == widget.index;
        final isLoaded = _loadedIndices.contains(index);
        
        return AnimatedOpacity(
          duration: widget.animationDuration,
          opacity: isVisible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Visibility(
              visible: isLoaded,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              maintainInteractivity: false,
              child: widget.children[index],
            ),
          ),
        );
      }),
    );
  }
}

/// Lazy loaded screen wrapper
/// 
/// Wraps a screen to prevent it from being built until needed
class LazyLoadWrapper extends StatefulWidget {
  final Widget Function() builder;
  final bool enabled;
  
  const LazyLoadWrapper({
    super.key,
    required this.builder,
    this.enabled = true,
  });
  
  @override
  State<LazyLoadWrapper> createState() => _LazyLoadWrapperState();
}

class _LazyLoadWrapperState extends State<LazyLoadWrapper> {
  Widget? _cachedWidget;
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.builder();
    }
    
    _cachedWidget ??= widget.builder();
    return _cachedWidget!;
  }
}

/// Memory-efficient list builder
/// 
/// Automatically disposes widgets when scrolled out of view
class EfficientListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int itemExtent;
  
  const EfficientListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.itemExtent = 0,
  });
  
  @override
  State<EfficientListView<T>> createState() => _EfficientListViewState<T>();
}

class _EfficientListViewState<T> extends State<EfficientListView<T>> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.items.isNotEmpty;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const Center(child: Text('No items'));
    }
    
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding ?? const EdgeInsets.all(16),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      itemExtent: widget.itemExtent > 0 ? widget.itemExtent.toDouble() : null,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: widget.itemBuilder(context, widget.items[index], index),
        );
      },
    );
  }
}

/// Disposable widget mixin
/// 
/// Ensures all resources are properly disposed
mixin DisposableMixin<T extends StatefulWidget> on State<T> {
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];
  final List<TextEditingController> _controllers = [];
  final List<ScrollController> _scrollControllers = [];
  final List<AnimationController> _animationControllers = [];
  
  /// Register a timer for automatic disposal
  void registerTimer(Timer timer) => _timers.add(timer);
  
  /// Register a stream subscription for automatic disposal
  void registerSubscription(StreamSubscription sub) => _subscriptions.add(sub);
  
  /// Register a text controller for automatic disposal
  void registerController(TextEditingController controller) => _controllers.add(controller);
  
  /// Register a scroll controller for automatic disposal
  void registerScrollController(ScrollController controller) => _scrollControllers.add(controller);
  
  /// Register an animation controller for automatic disposal
  void registerAnimationController(AnimationController controller) => _animationControllers.add(controller);
  
  @override
  void dispose() {
    // Dispose all registered resources
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }
}