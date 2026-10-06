import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

/// Style class for [CometChatMessageActionOverlay]
@immutable
class CometChatMessageActionOverlayStyle
    extends ThemeExtension<CometChatMessageActionOverlayStyle> {
  const CometChatMessageActionOverlayStyle({
    this.backgroundColor,
    this.overlayColor,
    this.reactionBackgroundColor,
    this.reactionBorderRadius,
    this.optionsBackgroundColor,
    this.optionsBorderRadius,
    this.optionTitleStyle,
    this.optionIconColor,
    this.dividerColor,
  });

  /// Background color of the overlay (dimmed background)
  final Color? overlayColor;

  /// Background color of the reaction row container
  final Color? reactionBackgroundColor;

  /// Border radius of the reaction row container
  final BorderRadius? reactionBorderRadius;

  /// Background color of the options container
  final Color? optionsBackgroundColor;

  /// Border radius of the options container
  final BorderRadius? optionsBorderRadius;

  /// Text style for option titles
  final TextStyle? optionTitleStyle;

  /// Icon color for options
  final Color? optionIconColor;

  /// Divider color between options
  final Color? dividerColor;

  /// Background color (unused, kept for compatibility)
  final Color? backgroundColor;

  @override
  CometChatMessageActionOverlayStyle copyWith({
    Color? backgroundColor,
    Color? overlayColor,
    Color? reactionBackgroundColor,
    BorderRadius? reactionBorderRadius,
    Color? optionsBackgroundColor,
    BorderRadius? optionsBorderRadius,
    TextStyle? optionTitleStyle,
    Color? optionIconColor,
    Color? dividerColor,
  }) {
    return CometChatMessageActionOverlayStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      overlayColor: overlayColor ?? this.overlayColor,
      reactionBackgroundColor:
          reactionBackgroundColor ?? this.reactionBackgroundColor,
      reactionBorderRadius: reactionBorderRadius ?? this.reactionBorderRadius,
      optionsBackgroundColor:
          optionsBackgroundColor ?? this.optionsBackgroundColor,
      optionsBorderRadius: optionsBorderRadius ?? this.optionsBorderRadius,
      optionTitleStyle: optionTitleStyle ?? this.optionTitleStyle,
      optionIconColor: optionIconColor ?? this.optionIconColor,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }

  CometChatMessageActionOverlayStyle merge(
    CometChatMessageActionOverlayStyle? other,
  ) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      overlayColor: other.overlayColor,
      reactionBackgroundColor: other.reactionBackgroundColor,
      reactionBorderRadius: other.reactionBorderRadius,
      optionsBackgroundColor: other.optionsBackgroundColor,
      optionsBorderRadius: other.optionsBorderRadius,
      optionTitleStyle: other.optionTitleStyle,
      optionIconColor: other.optionIconColor,
      dividerColor: other.dividerColor,
    );
  }

  @override
  ThemeExtension<CometChatMessageActionOverlayStyle> lerp(
    covariant ThemeExtension<CometChatMessageActionOverlayStyle>? other,
    double t,
  ) {
    if (other is! CometChatMessageActionOverlayStyle) return this;
    return CometChatMessageActionOverlayStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t),
      reactionBackgroundColor: Color.lerp(
        reactionBackgroundColor,
        other.reactionBackgroundColor,
        t,
      ),
      optionsBackgroundColor: Color.lerp(
        optionsBackgroundColor,
        other.optionsBackgroundColor,
        t,
      ),
      optionIconColor: Color.lerp(optionIconColor, other.optionIconColor, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
    );
  }

  static CometChatMessageActionOverlayStyle of(BuildContext context) {
    return const CometChatMessageActionOverlayStyle();
  }
}

/// A full-screen overlay that displays message actions in a modern context menu style.
///
/// Shows:
/// 1. Dimmed background
/// 2. Quick reaction emojis row above the message
/// 3. The message bubble (highlighted)
/// 4. Action options below the message
class CometChatMessageActionOverlay extends StatefulWidget {
  const CometChatMessageActionOverlay({
    super.key,
    required this.message,
    required this.bubbleWidget,
    required this.actionItems,
    required this.bubbleAlignment,
    this.favoriteReactions,
    this.onReactionTap,
    this.onAddReactionTap,
    this.addReactionIcon,
    this.hideReactions = false,
    this.style,
    this.bubbleOffset,
    this.bubbleSize,
    this.heroTag,
  });

  /// The message object
  final BaseMessage message;

  /// The bubble widget to display
  final Widget bubbleWidget;

  /// List of action items to show
  final List<ActionItem> actionItems;

  /// Alignment of the bubble (left/right)
  final BubbleAlignment bubbleAlignment;

  /// List of favorite reactions to show
  final List<String>? favoriteReactions;

  /// Callback when a reaction is tapped
  final Function(BaseMessage message, String reaction)? onReactionTap;

  /// Callback when add reaction icon is tapped
  final Function(BaseMessage message)? onAddReactionTap;

  /// Custom add reaction icon
  final Widget? addReactionIcon;

  /// Whether to hide reactions row
  final bool hideReactions;

  /// Style for the overlay
  final CometChatMessageActionOverlayStyle? style;

  /// Original position of the bubble (for animation)
  final Offset? bubbleOffset;

  /// Original size of the bubble
  final Size? bubbleSize;

  /// Hero tag for the bubble animation
  final String? heroTag;

  @override
  State<CometChatMessageActionOverlay> createState() =>
      _CometChatMessageActionOverlayState();
}

class _CometChatMessageActionOverlayState
    extends State<CometChatMessageActionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<String> _favoriteReactions;

  /// The first page, in this order. Anything not listed here — Save, Pin,
  /// Forward, Share, Message info, Report, Send privately, Mark as unread —
  /// falls through to the "More" page.
  ///
  /// Declared as an explicit order rather than derived from the incoming
  /// list's positions, so the page reads the same however a host reorders
  /// or injects options.
  static const List<String> _primaryActionOrder = [
    MessageOptionConstants.replyMessage,
    MessageOptionConstants.replyInThreadMessage,
    MessageOptionConstants.threadSubscription,
    MessageOptionConstants.copyMessage,
    MessageOptionConstants.editMessage,
    MessageOptionConstants.deleteMessage,
  ];

  /// Save/Pin lead the "More" page, ahead of the remaining overflow items.
  static const Set<String> _quickActionIds = {
    MessageOptionConstants.pinMessage,
    MessageOptionConstants.unpinMessage,
    MessageOptionConstants.saveMessage,
    MessageOptionConstants.unsaveMessage,
  };

  /// The "More" page: Save, Pin, then everything after the Copy option.
  late List<ActionItem> _quickActions;

  /// The first page: options up to and including Copy.
  late List<ActionItem> _listActions;

  /// Options-card page toggle: false = the primary options (…through Copy),
  /// true = the "More" page. Flipped by the row at the bottom of the card.
  bool _showMoreActions = false;

  static int _quickActionOrder(ActionItem item) =>
      (item.id == MessageOptionConstants.saveMessage ||
          item.id == MessageOptionConstants.unsaveMessage)
      ? 0
      : 1;

  @override
  void initState() {
    super.initState();
    // Quick-reaction tray is capped at 5 emojis; pin/save sit beside it.
    _favoriteReactions =
        (widget.favoriteReactions ?? ['😍', '🔥', '🤧', '👍', '😂'])
            .take(5)
            .toList();

    final items = widget.actionItems;

    // First page: the options named in _primaryActionOrder, in that order,
    // skipping any the message doesn't offer (no Edit on someone else's
    // message, no Copy on media, and so on).
    final primary = <ActionItem>[];
    for (final id in _primaryActionOrder) {
      final index = items.indexWhere((item) => item.id == id);
      if (index != -1) primary.add(items[index]);
    }

    final pinSave =
        items.where((item) => _quickActionIds.contains(item.id)).toList()..sort(
          (a, b) => _quickActionOrder(a).compareTo(_quickActionOrder(b)),
        );

    // "More": Save/Pin first, then everything the first page didn't claim,
    // in the order the host supplied it.
    final overflow = items
        .where(
          (item) =>
              !_quickActionIds.contains(item.id) &&
              !_primaryActionOrder.contains(item.id),
        )
        .toList();

    _quickActions = [...pinSave, ...overflow];
    _listActions = primary;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss([ActionItem? result]) async {
    ccLog('[Overlay] _dismiss called with result: ${result?.id}');
    // Use reverse animation only when Hero animation is active (heroTag provided)
    // This ensures smooth Hero flight back to original position
    if (widget.heroTag != null) {
      ccLog('[Overlay] Running reverse animation');
      await _animationController.reverse();
    }
    ccLog('[Overlay] mounted=$mounted, popping with result: ${result?.id}');
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final typography = CometChatThemeHelper.getTypography(context);

    final overlayStyle =
        CometChatThemeHelper.getTheme<CometChatMessageActionOverlayStyle>(
          context: context,
          defaultTheme: CometChatMessageActionOverlayStyle.of,
        ).merge(widget.style);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => _dismiss(),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blur background
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8.0 * _fadeAnimation.value,
                    sigmaY: 8.0 * _fadeAnimation.value,
                  ),
                  child: Container(
                    color: (overlayStyle.overlayColor ?? Colors.black)
                        .withValues(alpha: 0.3 * _fadeAnimation.value),
                  ),
                ),
                // Content
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildContent(
                        context,
                        colorPalette,
                        spacing,
                        typography,
                        overlayStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatMessageActionOverlayStyle overlayStyle,
  ) {
    final isLeftAligned = widget.bubbleAlignment == BubbleAlignment.left;
    // Use the same padding as message bubble (spacing.padding4)
    final bubblePadding = spacing.padding4 ?? 16;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeAreaPadding = MediaQuery.paddingOf(context);

    // On web/wide screens, constrain the overall content width
    // so the overlay doesn't feel like a full-screen takeover
    final double maxContentWidth = screenWidth > 600 ? 500 : screenWidth;

    // Calculate available height for the bubble
    // Reserve space for: reactions row (~56), options (~280 max), spacing, safe area
    final reactionsHeight = widget.hideReactions ? 0.0 : 56.0;
    const optionsMaxHeight = 280.0;
    final verticalPadding = (spacing.padding6 ?? 24) * 2;
    final spacingBetween = (spacing.padding1 ?? 4) * 2;
    final reservedHeight =
        reactionsHeight +
        optionsMaxHeight +
        verticalPadding +
        spacingBetween +
        safeAreaPadding.top +
        safeAreaPadding.bottom;
    final maxBubbleHeight = screenHeight - reservedHeight;
    final double effectiveMaxHeight = maxBubbleHeight > 100
        ? maxBubbleHeight
        : 100.0;

    // Check if bubble needs to be constrained (is larger than available space)
    final bool isLargeBubble =
        widget.bubbleSize != null &&
        widget.bubbleSize!.height > effectiveMaxHeight;

    // Build the bubble widget — no Hero animation to avoid WidgetSpan
    // reparenting issues that break formatted text (mentions, inline code)
    Widget bubbleContent = GestureDetector(
      onTap: () {}, // Prevent tap from dismissing
      child: Material(color: Colors.transparent, child: widget.bubbleWidget),
    );

    // Wrap bubble in a constrained scrollable container for large messages
    Widget constrainedBubble = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: bubbleContent,
      ),
    );

    // For small bubbles, don't constrain - just use the bubble directly
    // For large bubbles, use the constrained scrollable version
    final Widget displayBubble = isLargeBubble
        ? constrainedBubble
        : bubbleContent;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: EdgeInsets.only(
            left: bubblePadding,
            right: bubblePadding,
            top: spacing.padding6 ?? 24,
            bottom: spacing.padding6 ?? 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spacer to push content to center for small bubbles
              if (!isLargeBubble) const Spacer(),

              // Reactions row - aligned same as bubble
              if (!widget.hideReactions &&
                  !ModerationCheckUtil.instance
                      .isMessageDisapprovedFromModeration(widget.message))
                Align(
                  alignment: isLeftAligned
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: _buildReactionsRow(
                    colorPalette,
                    spacing,
                    typography,
                    overlayStyle,
                  ),
                ),

              SizedBox(height: spacing.padding1 ?? 4),

              // Message bubble - constrained and scrollable for large messages
              Align(
                alignment: isLeftAligned
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: displayBubble,
              ),

              SizedBox(height: spacing.padding1 ?? 4),

              // Action options - aligned same side as bubble
              Align(
                alignment: isLeftAligned
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: _buildOptionsContainer(
                  colorPalette,
                  spacing,
                  typography,
                  overlayStyle,
                ),
              ),

              // Spacer to push content to center for small bubbles
              if (!isLargeBubble) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatMessageActionOverlayStyle overlayStyle,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.padding3 ?? 12,
        vertical: spacing.padding2 ?? 8,
      ),
      decoration: BoxDecoration(
        color: overlayStyle.reactionBackgroundColor ?? colorPalette.background1,
        borderRadius:
            overlayStyle.reactionBorderRadius ??
            BorderRadius.circular(spacing.radiusMax ?? 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._favoriteReactions.map(
            (reaction) =>
                _buildReactionItem(reaction, colorPalette, spacing, typography),
          ),
          _buildAddReactionButton(colorPalette, spacing),
        ],
      ),
    );
  }

  Widget _buildReactionItem(
    String reaction,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
  ) {
    return GestureDetector(
      onTap: () {
        // Dismiss immediately without reverse animation to avoid jitter
        // when reaction state update triggers rebuild
        if (mounted) {
          Navigator.of(context).pop();
        }
        // Call reaction callback after overlay is dismissed
        if (widget.onReactionTap != null) {
          widget.onReactionTap!(widget.message, reaction);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.padding1 ?? 4),
        child: Text(
          reaction,
          style: TextStyle(
            fontSize: 24,
            fontFamily: typography.heading1?.regular?.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildAddReactionButton(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return GestureDetector(
      onTap: () async {
        // Show emoji keyboard and wait for selection
        final selectedEmoji = await showCometChatEmojiKeyboard(
          context: context,
          colorPalette: colorPalette,
        );

        // Dismiss immediately without reverse animation to avoid jitter
        // when reaction state update triggers rebuild
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Call reaction callback after overlay is dismissed
        if (selectedEmoji != null && selectedEmoji.isNotEmpty) {
          if (widget.onReactionTap != null) {
            widget.onReactionTap!(widget.message, selectedEmoji);
          }
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.padding1 ?? 4),
        child:
            widget.addReactionIcon ??
            Icon(
              Icons.add_circle_outline,
              size: 24,
              color: colorPalette.iconSecondary,
            ),
      ),
    );
  }

  Widget _buildOptionsContainer(
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatMessageActionOverlayStyle overlayStyle,
  ) {
    if (_listActions.isEmpty && _quickActions.isEmpty) {
      return const SizedBox.shrink();
    }
    final pageActions = _showMoreActions ? _quickActions : _listActions;

    return Container(
      constraints: kIsWeb
          ? const BoxConstraints(maxWidth: 280, maxHeight: 600)
          : BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              maxHeight: 600,
            ),
      decoration: BoxDecoration(
        color: overlayStyle.optionsBackgroundColor ?? colorPalette.background1,
        borderRadius:
            overlayStyle.optionsBorderRadius ??
            BorderRadius.circular(spacing.radius4 ?? 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            overlayStyle.optionsBorderRadius ??
            BorderRadius.circular(spacing.radius4 ?? 16),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...pageActions.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                // The More/Back row brings its own heavier separator, so the
                // last action never needs a trailing hairline.
                final isLast = index == pageActions.length - 1;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOptionItem(
                      item,
                      colorPalette,
                      spacing,
                      typography,
                      overlayStyle,
                    ),
                    if (!isLast)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color:
                            overlayStyle.dividerColor ??
                            colorPalette.borderLight,
                      ),
                  ],
                );
              }),
              // "More" opens the second page; on it, the row reads "Back"
              // with the same arrow the header back button uses. The toggle
              // never dismisses the overlay.
              if (_quickActions.isNotEmpty) ...[
                // More/Back navigates the card rather than acting on the
                // message, so it is cut off from the actions above with a
                // full-weight band instead of the hairline used between
                // peers — the break has to read at a glance.
                Container(
                  height: 3,
                  // A neutral surface, not the divider colour — even at 3dp
                  // the hairline tone would read as a heavy rule rather than
                  // the section break this is.
                  color: colorPalette.background3 ?? colorPalette.borderLight,
                ),
                _buildOptionItem(
                  ActionItem(
                    id: 'more_toggle',
                    title: _showMoreActions
                        ? Translations.of(context).backButton
                        : Translations.of(context).more,
                    icon: Icon(
                      _showMoreActions ? Icons.arrow_back : Icons.more_horiz,
                    ),
                  ),
                  colorPalette,
                  spacing,
                  typography,
                  overlayStyle,
                  onTapOverride: () =>
                      setState(() => _showMoreActions = !_showMoreActions),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    ActionItem item,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatMessageActionOverlayStyle overlayStyle, {
    VoidCallback? onTapOverride,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final iconColor =
        overlayStyle.optionIconColor ??
        item.style?.iconColor ??
        colorPalette.iconSecondary;

    final iconWidget = item.icon != null
        ? IconTheme(
            data: IconThemeData(color: iconColor, size: 22),
            child: item.icon!,
          )
        : null;

    final titleWidget = Expanded(
      child: Text(
        item.title,
        style:
            overlayStyle.optionTitleStyle ??
            TextStyle(
              fontSize: typography.body?.regular?.fontSize ?? 16,
              fontWeight: typography.body?.regular?.fontWeight,
              fontFamily: typography.body?.regular?.fontFamily,
              color: item.style?.titleColor ?? colorPalette.textPrimary,
            ),
        // Two lines before ellipsizing so longer option titles (e.g.
        // "Stop reply notifications") never truncate on narrow sheets or
        // large font scales.
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapOverride ?? () => _dismiss(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.padding4 ?? 16,
            vertical: spacing.padding3 != null ? spacing.padding3! + 2 : 14,
          ),
          child: Row(
            children: isIOS
                ? [
                    // iOS: title left, icon right
                    titleWidget,
                    if (iconWidget != null) ...[
                      SizedBox(width: spacing.padding3 ?? 12),
                      iconWidget,
                    ],
                  ]
                : [
                    // Android: icon left, title right
                    if (iconWidget != null) ...[
                      iconWidget,
                      SizedBox(width: spacing.padding3 ?? 12),
                    ],
                    titleWidget,
                  ],
          ),
        ),
      ),
    );
  }
}

/// Shows the message action overlay as a full-screen dialog.
///
/// Returns the selected [ActionItem] or null if dismissed.
Future<ActionItem?> showMessageActionOverlay({
  required BuildContext context,
  required BaseMessage message,
  required Widget bubbleWidget,
  required List<ActionItem> actionItems,
  required BubbleAlignment bubbleAlignment,
  String? heroTag,
  Size? bubbleSize,
  List<String>? favoriteReactions,
  Function(BaseMessage message, String reaction)? onReactionTap,
  Function(BaseMessage message)? onAddReactionTap,
  Widget? addReactionIcon,
  bool hideReactions = false,
  CometChatMessageActionOverlayStyle? style,
}) {
  return Navigator.of(context).push<ActionItem>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CometChatMessageActionOverlay(
          message: message,
          bubbleWidget: bubbleWidget,
          actionItems: actionItems,
          bubbleAlignment: bubbleAlignment,
          heroTag: heroTag,
          bubbleSize: bubbleSize,
          favoriteReactions: favoriteReactions,
          onReactionTap: onReactionTap,
          onAddReactionTap: onAddReactionTap,
          addReactionIcon: addReactionIcon,
          hideReactions: hideReactions,
          style: style,
        );
      },
    ),
  );
}
