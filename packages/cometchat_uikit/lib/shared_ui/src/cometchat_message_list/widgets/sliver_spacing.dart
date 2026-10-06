import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/composer_height_notifier.dart';
import '../../logging/cometchat_log.dart';

/// A sliver that provides dynamic spacing at the bottom of the message list
///
/// This sliver handles:
/// - Bottom padding
/// - Safe area insets
/// - Composer height (via [ComposerHeightNotifier] or fixed [composerHeight])
/// - Keyboard height (only when user is at bottom of list)
///
/// When user has scrolled up to read older messages, the list stays in place
/// and only the composer moves up with the keyboard.
class SliverSpacing extends StatefulWidget {
  /// Fixed bottom padding
  final double? bottomPadding;

  /// Whether to handle safe area
  final bool? handleSafeArea;

  /// Notifier for composer height changes (dynamic)
  final ComposerHeightNotifier? composerHeightNotifier;

  /// Fixed composer height (used when composerHeightNotifier is null)
  /// Default is 80.0 which includes typical composer height + internal padding
  final double composerHeight;

  /// Callback when keyboard height changes (for scroll adjustment)
  final void Function(double height)? onKeyboardHeightChanged;

  /// Whether to include keyboard height in the spacing
  /// Set to false when using resizeToAvoidBottomInset: true
  final bool includeKeyboardHeight;

  /// Scroll controller - used to check if user is at bottom
  final ScrollController? scrollController;

  /// Threshold for considering user "at bottom" (in pixels)
  /// Default is 50 pixels from the bottom
  final double atBottomThreshold;

  const SliverSpacing({
    super.key,
    this.bottomPadding,
    this.handleSafeArea,
    this.composerHeightNotifier,
    this.composerHeight = 80.0,
    this.onKeyboardHeightChanged,
    this.includeKeyboardHeight = true,
    this.scrollController,
    this.atBottomThreshold = 50.0,
  });

  @override
  State<SliverSpacing> createState() => _SliverSpacingState();
}

class _SliverSpacingState extends State<SliverSpacing>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  double _keyboardHeight = 0;
  double _dynamicComposerHeight = 0;
  double _previousRawKeyboardHeight = 0;
  double _safeAreaBottom = 0;
  double _initialSafeArea = 0;
  bool _initialized = false;

  // Track if user was at bottom when keyboard started opening
  bool _shouldPushList = true;

  // Store the height we had before keyboard opened (to restore when not pushing)
  double _heightBeforeKeyboard = 0;

  // Track last known scroll offset (updated continuously via listener)
  double _lastKnownScrollOffset = 0;
  bool _scrollListenerAttached = false;

  // Animation controller for smooth keyboard height transitions
  late final AnimationController _animationController;
  late Animation<double> _heightAnimation;
  double _currentAnimatedHeight = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _heightAnimation = const AlwaysStoppedAnimation<double>(0);
    _animationController.addListener(() {
      setState(() {
        _currentAnimatedHeight = _heightAnimation.value;
      });
    });
    if (widget.includeKeyboardHeight) {
      WidgetsBinding.instance.addObserver(this);
    }
    widget.composerHeightNotifier?.addListener(_onComposerHeightChanged);
    _attachScrollListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _safeAreaBottom = MediaQuery.paddingOf(context).bottom;
      _initialSafeArea = _safeAreaBottom;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _detachScrollListener();
    if (widget.includeKeyboardHeight) {
      WidgetsBinding.instance.removeObserver(this);
    }
    widget.composerHeightNotifier?.removeListener(_onComposerHeightChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(SliverSpacing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composerHeightNotifier != widget.composerHeightNotifier) {
      oldWidget.composerHeightNotifier?.removeListener(
        _onComposerHeightChanged,
      );
      widget.composerHeightNotifier?.addListener(_onComposerHeightChanged);
    }
    if (oldWidget.includeKeyboardHeight != widget.includeKeyboardHeight) {
      if (widget.includeKeyboardHeight) {
        WidgetsBinding.instance.addObserver(this);
      } else {
        WidgetsBinding.instance.removeObserver(this);
        _keyboardHeight = 0;
      }
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollListener();
      _attachScrollListener();
    }
  }

  void _attachScrollListener() {
    final controller = widget.scrollController;
    if (controller != null && !_scrollListenerAttached) {
      controller.addListener(_onScrollChanged);
      _scrollListenerAttached = true;
      // Initialize with current offset if available
      if (controller.hasClients) {
        _lastKnownScrollOffset = controller.offset;
      }
    }
  }

  void _detachScrollListener() {
    final controller = widget.scrollController;
    if (controller != null && _scrollListenerAttached) {
      controller.removeListener(_onScrollChanged);
      _scrollListenerAttached = false;
    }
  }

  void _onScrollChanged() {
    final controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      _lastKnownScrollOffset = controller.offset;
    }
  }

  void _onComposerHeightChanged() {
    final newHeight = widget.composerHeightNotifier?.height ?? 0;
    if (_dynamicComposerHeight != newHeight) {
      setState(() {
        _dynamicComposerHeight = newHeight;
      });
    }
  }

  /// Check if user is at the bottom of the list using last known scroll offset
  /// For reversed lists, bottom means scroll offset near 0
  bool _isAtBottom() {
    return _lastKnownScrollOffset <= widget.atBottomThreshold;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (widget.includeKeyboardHeight) {
      _updateKeyboardHeight();
    }
  }

  void _updateKeyboardHeight() {
    if (!mounted) return;

    // Skip keyboard updates when this route is not current (e.g. navigated to image viewer).
    // Without this, stale viewInsets from the overlaying route can corrupt our keyboard state.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final rawKeyboardHeight = View.of(context).viewInsets.bottom;

    if (rawKeyboardHeight != _previousRawKeyboardHeight) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final adjustedHeight = max(
        rawKeyboardHeight / pixelRatio - _initialSafeArea,
        0.0,
      );

      // Debug: Print bottom inset as keyboard opens/closes
      ccLog('🔵 [SliverSpacing] Bottom Inset Changed:');
      ccLog('   Raw viewInsets.bottom: $rawKeyboardHeight');
      ccLog('   Pixel ratio: $pixelRatio');
      ccLog('   Initial safe area: $_initialSafeArea');
      ccLog('   Adjusted keyboard height: $adjustedHeight');
      ccLog('   Previous keyboard height: $_keyboardHeight');

      // Detect keyboard state transitions
      final wasKeyboardFullyClosed = _keyboardHeight == 0;
      final isKeyboardOpening = wasKeyboardFullyClosed && adjustedHeight > 0;
      final isKeyboardFullyClosed = adjustedHeight == 0 && _keyboardHeight > 0;

      _previousRawKeyboardHeight = rawKeyboardHeight;

      // When keyboard is STARTING to open (was fully closed, now opening)
      if (isKeyboardOpening) {
        _shouldPushList = _isAtBottom();
        // Store current height before keyboard
        _heightBeforeKeyboard = _calculateBaseHeight();
        ccLog('   🟢 Keyboard OPENING - shouldPushList: $_shouldPushList');
      }

      // When keyboard is fully closed, reset for next time
      if (isKeyboardFullyClosed) {
        _shouldPushList = true;
        ccLog('   🔴 Keyboard CLOSED');
      }

      if (_keyboardHeight != adjustedHeight) {
        final oldKeyboardHeight = _keyboardHeight;

        // Only trigger rebuild if we should push the list OR keyboard is closing
        if (_shouldPushList || adjustedHeight < oldKeyboardHeight) {
          final oldTotalHeight = _computeTotalHeight();
          _keyboardHeight = adjustedHeight;
          final newTotalHeight = _computeTotalHeight();

          // Animate the height transition
          _heightAnimation =
              Tween<double>(begin: oldTotalHeight, end: newTotalHeight).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOut,
                ),
              );
          _animationController.forward(from: 0);
        } else {
          // Just update the value without rebuilding - list stays still
          _keyboardHeight = adjustedHeight;
        }

        if (_shouldPushList && widget.onKeyboardHeightChanged != null) {
          widget.onKeyboardHeightChanged!(adjustedHeight - oldKeyboardHeight);
        }
      }
    }
  }

  double _calculateBaseHeight() {
    double height = widget.bottomPadding ?? 0;

    final composerHeight = widget.composerHeightNotifier != null
        ? _dynamicComposerHeight
        : widget.composerHeight;
    height += composerHeight;

    // Add safe area when keyboard is closed
    // When keyboard is open, keyboard height replaces safe area
    if (widget.handleSafeArea == true && _keyboardHeight == 0) {
      height += _safeAreaBottom;
    }

    return height;
  }

  /// Compute the target total height based on current state (no animation)
  double _computeTotalHeight() {
    double totalHeight;

    if (!_shouldPushList && _keyboardHeight > 0) {
      totalHeight = _heightBeforeKeyboard;
    } else {
      totalHeight = _calculateBaseHeight();

      if (widget.includeKeyboardHeight && _shouldPushList) {
        totalHeight += _keyboardHeight;
      }
    }
    return totalHeight;
  }

  @override
  Widget build(BuildContext context) {
    // Use animated height when animation is running, otherwise compute directly
    final double totalHeight = _animationController.isAnimating
        ? _currentAnimatedHeight
        : _computeTotalHeight();

    return SliverPadding(padding: EdgeInsets.only(bottom: totalHeight));
  }
}
