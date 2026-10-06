import 'package:flutter/material.dart';

import '../../../../../../cometchat_uikit_shared.dart';

///[CometChatMessageBubble] is a widget that provides the skeleton structure for any message bubble
///constructed from a [CometChatMessageTemplate] which doesnt have a `bubbleView`
///it binds together the [leadingView], [headerView], [contentView], [footerView], [bottomView],
///[threadView] declared in the [CometChatMessageTemplate] to collectively form a message bubble
///
/// ```dart
///   CometChatMessageBubble(
///        alignment: BubbleAlignment.center,
///        leadingView: Container(),
///        headerView: Container(),
///        contentView: Container(),
///        footerView: Container(),
///        bottomView: Container(),
///        threadView: Container(),
///        replyView: Container(),
///        style: MessageBubbleStyle(),
///      );
/// ```
class CometChatMessageBubble extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Height of the bubble.
  @Deprecated(
    'Has no effect. The bubble sizes to its content; size it through its parent. Will be removed in 7.0.0.',
  )
  final double? height;

  /// Width of the bubble.
  @Deprecated(
    'Has no effect. The bubble sizes to its content; size it through its parent. Will be removed in 7.0.0.',
  )
  final double? width;

  const CometChatMessageBubble({
    super.key,
    this.style = const CometChatMessageBubbleStyle(),
    this.alignment,
    this.contentView,
    this.footerView,
    this.headerView,
    this.leadingView,
    this.replyView,
    this.threadView,
    this.bottomView,
    this.statusInfoView,
    this.margin,
    this.colorPalette,
    this.spacing,
    this.contentPadding,
    this.outerPadding,
    this.height,
    this.width,
  });

  ///[leadingView] widget to be shown on the left side of the bubble
  final Widget? leadingView;

  ///[headerView] widget to be shown on the top of the bubble
  final Widget? headerView;

  ///[replyView] widget to be shown on the top of the bubble
  final Widget? replyView;

  ///[contentView] widget to be shown in the center of the bubble
  final Widget? contentView;

  ///[threadView] widget to be shown in the center of the bubble
  final Widget? threadView;

  ///[footerView] widget to be shown at the bottom of the bubble
  final Widget? footerView;

  ///[alignment] alignment of the bubble
  final BubbleAlignment? alignment;

  ///[style] styling for the bubble
  final CometChatMessageBubbleStyle? style;

  ///[bottomView] widget to be shown at the bottom of the bubble
  final Widget? bottomView;

  ///[statusInfoView] widget to be shown under the [contentView] of the bubble
  final Widget? statusInfoView;

  ///[margin] sets margin for the bubble
  final EdgeInsetsGeometry? margin;

  /// [colorPalette] optional pre-cached color palette to avoid expensive lookups during keyboard animation
  final CometChatColorPalette? colorPalette;

  /// [spacing] optional pre-cached spacing to avoid expensive lookups during keyboard animation
  final CometChatSpacing? spacing;

  /// [contentPadding] sets padding inside the bubble container (around content)
  /// Use EdgeInsets.zero for media messages (images, videos) to remove padding
  final EdgeInsetsGeometry? contentPadding;

  /// [outerPadding] overrides the default outer row padding (vertical padding2,
  /// horizontal padding4). Used to tighten the gap between messages that belong
  /// to one visual group (e.g. a multi-attachment batch).
  final EdgeInsetsGeometry? outerPadding;

  @override
  State<CometChatMessageBubble> createState() => _CometChatMessageBubbleState();
}

class _CometChatMessageBubbleState extends State<CometChatMessageBubble> {
  // Cached theme values to avoid expensive lookups during rebuilds
  CometChatMessageBubbleStyle? _messageBubbleStyle;
  CometChatSpacing? _spacing;
  CometChatColorPalette? _colorPalette;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only initialize theme once to avoid expensive lookups during keyboard animation
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      _messageBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatMessageBubbleStyle>(
            context: context,
            defaultTheme: CometChatMessageBubbleStyle.of,
          ).merge(widget.style);
      // Use passed values OR fallback to lookup (for standalone usage)
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if it changed
    if (widget.style != oldWidget.style) {
      _messageBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatMessageBubbleStyle>(
            context: context,
            defaultTheme: CometChatMessageBubbleStyle.of,
          ).merge(widget.style);
    }
    // Update cached theme values if they changed
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      _colorPalette = widget.colorPalette;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      _spacing = widget.spacing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageBubbleStyle = _messageBubbleStyle!;
    final spacing = _spacing!;
    final colorPalette = _colorPalette!;

    // Build the content column that will be used in both bounded and unbounded cases
    final contentColumn = Column(
      crossAxisAlignment: widget.alignment == BubbleAlignment.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [widget.headerView ?? const SizedBox()],
        ),
        //-----bubble-----
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.alignment == BubbleAlignment.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding:
                        widget.contentPadding ??
                        EdgeInsets.fromLTRB(
                          spacing.padding1 ?? 0,
                          spacing.padding1 ?? 0,
                          spacing.padding1 ?? 0,
                          0,
                        ),
                    decoration: BoxDecoration(
                      color: _getBubbleBackgroundColor(
                        messageBubbleStyle,
                        colorPalette,
                      ),
                      borderRadius:
                          messageBubbleStyle.borderRadius ??
                          BorderRadius.all(
                            Radius.circular(spacing.radius3 ?? 0),
                          ),
                      border: messageBubbleStyle.border,
                      image: messageBubbleStyle.backgroundImage,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.replyView != null)
                          // Media bubbles set contentPadding to zero so the grid
                          // fills the bubble edge-to-edge — but the quoted reply
                          // should still be inset like it is in a text bubble.
                          // Restore that inset around just the reply here.
                          Padding(
                            padding: widget.contentPadding == EdgeInsets.zero
                                ? EdgeInsets.fromLTRB(
                                    spacing.padding1 ?? 4,
                                    spacing.padding1 ?? 4,
                                    spacing.padding1 ?? 4,
                                    0,
                                  )
                                : EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius:
                                  messageBubbleStyle.borderRadius ??
                                  BorderRadius.all(
                                    Radius.circular(spacing.radius3 ?? 0),
                                  ),
                              child: widget.replyView!,
                            ),
                          ),
                        if (widget.contentView != null) widget.contentView!,
                        if (widget.statusInfoView != null)
                          Padding(
                            padding: EdgeInsets.all(spacing.padding1 ?? 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: widget.statusInfoView!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.bottomView != null) widget.bottomView!,
                  if (widget.footerView != null)
                    Row(
                      mainAxisAlignment:
                          widget.alignment == BubbleAlignment.right
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [widget.footerView!],
                    ),
                ],
              ),
            ),
            //-----thread replies-----
            if (widget.threadView != null) widget.threadView!,
          ],
        ),
      ],
    );

    return Container(
      margin: widget.margin,
      child: Padding(
        padding:
            widget.outerPadding ??
            EdgeInsets.symmetric(
              vertical: spacing.padding2 ?? 0,
              horizontal: spacing.padding4 ?? 0,
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The leading avatar duplicates the sender already named in
            // headerView, so it is hidden from assistive technology.
            if (widget.leadingView != null)
              ExcludeSemantics(child: widget.leadingView!),
            Flexible(child: contentColumn),
          ],
        ),
      ),
    );
  }

  Color? _getBubbleBackgroundColor(
    CometChatMessageBubbleStyle style,
    CometChatColorPalette colorPalette,
  ) {
    return style.backgroundColor ??
        (widget.alignment == BubbleAlignment.right
            ? colorPalette.primary
            : colorPalette.neutral300);
  }
}
