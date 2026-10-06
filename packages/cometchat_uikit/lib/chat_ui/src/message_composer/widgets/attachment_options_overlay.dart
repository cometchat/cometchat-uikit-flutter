import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Displays attachment options in an overlay popup above the attachment button.
///
/// This widget renders a list of [ActionItem]s in a floating popup that
/// appears above the message composer when the attachment button is tapped.
///
/// The overlay supports:
/// - Vertical list of action items with icons and titles
/// - Custom styling via [CometChatAttachmentOptionSheetStyle]
/// - Rounded corners and elevation/shadow
/// - Dynamic height based on item count
/// - Scrolling when content exceeds maximum height
/// - Smooth fade-in/scale-up animation on appear
/// - Smooth fade-out animation on dismiss
///
/// Example usage:
/// ```dart
/// AttachmentOptionsOverlay(
///   actionItems: [
///     ActionItem(id: 'image', title: 'Image', icon: Icon(Icons.image)),
///     ActionItem(id: 'video', title: 'Video', icon: Icon(Icons.videocam)),
///   ],
///   onItemSelected: (item) => handleSelection(item),
///   onDismiss: () => hideOverlay(),
///   isVisible: true,
/// )
/// ```
class AttachmentOptionsOverlay extends StatefulWidget {
  /// Creates an attachment options overlay widget.
  ///
  /// The [actionItems], [onItemSelected], and [onDismiss] parameters are required.
  const AttachmentOptionsOverlay({
    super.key,
    required this.actionItems,
    required this.onItemSelected,
    required this.onDismiss,
    this.style,
    this.maxHeight,
    this.minWidth,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.isVisible = true,
    this.animationDuration = const Duration(milliseconds: 400),
  });

  /// List of attachment options to display.
  ///
  /// Each [ActionItem] contains an id, title, optional icon, and optional
  /// onItemClick callback.
  final List<ActionItem> actionItems;

  /// Callback invoked when an item is selected.
  ///
  /// The selected [ActionItem] is passed to this callback.
  final void Function(ActionItem item) onItemSelected;

  /// Callback invoked when the overlay should be dismissed.
  ///
  /// This is called when the user taps outside the overlay.
  final VoidCallback onDismiss;

  /// Custom styling for the overlay.
  ///
  /// If not provided, uses theme-based defaults from [CometChatThemeHelper].
  final CometChatAttachmentOptionSheetStyle? style;

  /// Maximum height constraint for the overlay.
  ///
  /// Defaults to 50% of available screen height if not specified.
  /// When content exceeds this height, the overlay becomes scrollable.
  final double? maxHeight;

  /// Minimum width of the overlay.
  ///
  /// Defaults to 200 logical pixels if not specified.
  final double? minWidth;

  /// Color palette for theming.
  ///
  /// If not provided, uses [CometChatThemeHelper.getColorPalette].
  final CometChatColorPalette? colorPalette;

  /// Spacing configuration.
  ///
  /// If not provided, uses [CometChatThemeHelper.getSpacing].
  final CometChatSpacing? spacing;

  /// Typography configuration.
  ///
  /// If not provided, uses [CometChatThemeHelper.getTypography].
  final CometChatTypography? typography;

  /// Controls the visibility state for animations.
  ///
  /// When [isVisible] changes from false to true, the overlay animates in
  /// with a fade-in and scale-up effect. When it changes from true to false,
  /// the overlay animates out with a fade-out effect.
  ///
  /// Defaults to true.
  final bool isVisible;

  /// Duration of the appear/dismiss animations.
  ///
  /// Defaults to 800 milliseconds to allow the elastic bounce to complete.
  final Duration animationDuration;

  /// Height of each action item in logical pixels.
  static const double _itemHeight = 36.0;

  /// Vertical padding for the overlay container.
  static const double _verticalPadding = 4.0;

  /// Icon size for action items.
  static const double _iconSize = 18.0;

  @override
  State<AttachmentOptionsOverlay> createState() =>
      _AttachmentOptionsOverlayState();
}

class _AttachmentOptionsOverlayState extends State<AttachmentOptionsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  // Spring-driven scale — driven directly via animateWith(SpringSimulation)
  // so Flutter's physics engine handles the smooth overshoot naturally.
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.isVisible) {
      _runSpringOpen();
    }
  }

  void _initializeAnimations() {
    // upperBound > 1.0 so the spring can overshoot past 1.0
    _animationController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 2.0,
      duration: widget.animationDuration,
    );

    // Opacity: quick fade over first half of the animation, independent of spring.
    // We can't use CurvedAnimation here because the spring-driven controller
    // overshoots past 1.0 (upperBound is 2.0), and CurvedAnimation passes the
    // raw parent value to Curve.transform() which asserts t ∈ [0, 1].
    // Instead, use a custom Animatable that clamps before applying the curve.
    _opacityAnimation = _animationController.drive(
      _ClampedIntervalTween(begin: 0.0, end: 0.5, curve: Curves.easeOut),
    );

    // Scale reads directly from controller value (spring drives it to ~1.0)
    _scaleAnimation = _animationController;
  }

  void _runSpringOpen() {
    // SpringDescription: mass=1, stiffness controls speed, damping controls overshoot
    // damping < 2*sqrt(stiffness*mass) = underdamped = single smooth overshoot
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 200.0, // higher = faster
      damping:
          18.0, // lower = more overshoot; 18 gives ~15% overshoot, smooth settle
    );
    final simulation = SpringSimulation(spring, 0.0, 1.0, 0.0);
    _animationController.animateWith(simulation);
  }

  @override
  void didUpdateWidget(AttachmentOptionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation duration if changed
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }

    // Handle visibility changes
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _runSpringOpen();
      } else {
        _animationController.animateTo(
          0.0,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 150),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return empty widget if no action items
    if (widget.actionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveColorPalette =
        widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        widget.spacing ?? CometChatThemeHelper.getSpacing(context);
    final effectiveTypography =
        widget.typography ?? CometChatThemeHelper.getTypography(context);

    // Merge provided style with defaults
    final effectiveStyle = CometChatAttachmentOptionSheetStyle.of(
      context,
    ).merge(widget.style);

    // Calculate effective dimensions - use IntrinsicWidth to fit content
    final effectiveMaxHeight =
        widget.maxHeight ?? _calculateDefaultMaxHeight(context);

    // Use FadeTransition and ScaleTransition for proper layout during animation
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment
            .bottomLeft, // Scale from bottom since overlay appears above
        child: Semantics(
          label: Translations.of(context).attachmentOptionsMenuOpened,
          child: IntrinsicWidth(
            child: Material(
              elevation: 12.0,
              shadowColor:
                  effectiveColorPalette.black?.withValues(alpha: 0.35) ??
                  Colors.black.withValues(alpha: 0.35),
              borderRadius: _getBorderRadius(effectiveStyle, effectiveSpacing),
              color:
                  effectiveStyle.backgroundColor ??
                  effectiveColorPalette.background1 ??
                  Colors.white,
              child: Container(
                constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
                decoration: BoxDecoration(
                  border: effectiveStyle.border,
                  borderRadius: _getBorderRadius(
                    effectiveStyle,
                    effectiveSpacing,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: _getBorderRadius(
                    effectiveStyle,
                    effectiveSpacing,
                  ),
                  child: _buildActionItemsList(
                    effectiveColorPalette,
                    effectiveSpacing,
                    effectiveTypography,
                    effectiveStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Calculates the default maximum height (50% of screen height).
  /// Uses MediaQuery.sizeOf to only subscribe to size changes, not all MediaQuery changes.
  /// This prevents unnecessary rebuilds during keyboard transitions.
  double _calculateDefaultMaxHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight * 0.5;
  }

  /// Gets the border radius from style or defaults to theme spacing.
  BorderRadius _getBorderRadius(
    CometChatAttachmentOptionSheetStyle effectiveStyle,
    CometChatSpacing spacing,
  ) {
    if (effectiveStyle.borderRadius != null) {
      return effectiveStyle.borderRadius as BorderRadius;
    }
    return BorderRadius.circular(spacing.radius2 ?? 8.0);
  }

  /// Builds the scrollable list of action items.
  Widget _buildActionItemsList(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatAttachmentOptionSheetStyle effectiveStyle,
  ) {
    // Use SingleChildScrollView + Column instead of ListView.builder
    // because IntrinsicWidth cannot compute intrinsic dimensions for viewports
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: spacing.padding2 ?? AttachmentOptionsOverlay._verticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.actionItems.map((item) {
          // Get item-specific style or use the overlay style
          final itemStyle = item.style ?? effectiveStyle;

          return _buildActionItem(
            item,
            itemStyle,
            colorPalette,
            spacing,
            typography,
          );
        }).toList(),
      ),
    );
  }

  /// Builds a single action item row.
  Widget _buildActionItem(
    ActionItem item,
    CometChatAttachmentOptionSheetStyle itemStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
  ) {
    final iconColor = itemStyle.iconColor ?? colorPalette.iconSecondary;
    final titleColor = itemStyle.titleColor ?? colorPalette.textPrimary;
    final titleTextStyle =
        itemStyle.titleTextStyle ??
        typography.caption1?.medium ??
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

    return Semantics(
      label: item.title,
      button: true,
      child: InkWell(
        onTap: () => widget.onItemSelected(item),
        child: Container(
          height: AttachmentOptionsOverlay._itemHeight,
          padding: EdgeInsets.symmetric(horizontal: spacing.padding3 ?? 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              if (item.icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: iconColor,
                    size: AttachmentOptionsOverlay._iconSize,
                  ),
                  child: item.icon!,
                ),
                SizedBox(width: spacing.padding2 ?? 8.0),
              ],
              // Title
              Text(
                item.title,
                style: titleTextStyle.copyWith(color: titleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [Animatable] that maps a sub-range of the parent animation to 0→1,
/// clamping the input so it's safe to use with controllers whose value can
/// exceed 1.0 (e.g. spring-driven controllers with upperBound > 1.0).
///
/// This replaces `CurvedAnimation` + `Interval` for cases where the parent
/// animation overshoots, because `CurvedAnimation` passes the raw parent
/// value to `Curve.transform()` which asserts `t ∈ [0, 1]`.
class _ClampedIntervalTween extends Animatable<double> {
  _ClampedIntervalTween({
    required this.begin,
    required this.end,
    this.curve = Curves.linear,
  });

  final double begin;
  final double end;
  final Curve curve;

  @override
  double transform(double t) {
    // Clamp to [0, 1] first, then map the sub-interval
    final clamped = t.clamp(0.0, 1.0);
    if (clamped <= begin) return 0.0;
    if (clamped >= end) return 1.0;
    final intervalT = (clamped - begin) / (end - begin);
    return curve.transform(intervalT.clamp(0.0, 1.0));
  }
}
