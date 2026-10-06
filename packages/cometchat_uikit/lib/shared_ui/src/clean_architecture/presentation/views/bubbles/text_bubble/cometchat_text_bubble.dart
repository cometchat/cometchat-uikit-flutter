import 'package:flutter/material.dart';
import "../../../../clean_architecture.dart";

///[CometChatTextBubble] is a widget that gives text bubble
/// ```dart
/// CometChatTextBubble(
///     text: 'some text message',
///     alignment: BubbleAlignment.left,
///     style: TextBubbleStyle(
///          background: Colors.white,
///          textColor: Colors.black,
///       ),
/// );
/// ```
class CometChatTextBubble extends StatefulWidget {
  const CometChatTextBubble({
    super.key,
    this.text,
    this.style,
    this.alignment,
    this.formatters,
    this.width,
    this.height,
    this.padding,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.emojiCount = 0,
  });

  ///[text] if message object is not passed then text should be passed
  final String? text;

  ///[style] manages the styling of this widget
  final CometChatTextBubbleStyle? style;

  final double? width;
  final double? height;

  ///[alignment] of the bubble
  final BubbleAlignment? alignment;

  ///[formatters] is a list of [CometChatTextFormatter] which is used to style the text
  final List<CometChatTextFormatter>? formatters;

  ///[padding] is used to give padding to the text bubble
  final EdgeInsetsGeometry? padding;

  /// [colorPalette] optional pre-cached color palette to avoid expensive lookups during keyboard animation
  final CometChatColorPalette? colorPalette;

  /// [spacing] optional pre-cached spacing to avoid expensive lookups during keyboard animation
  final CometChatSpacing? spacing;

  /// [typography] optional pre-cached typography to avoid expensive lookups during keyboard animation
  final CometChatTypography? typography;

  /// Number of emojis when the message is emoji-only (1–3).
  /// 0 means normal text rendering. When > 0, the bubble renders
  /// emojis at a scaled-up font size with no background/padding
  /// (WhatsApp-style).
  final int emojiCount;

  @override
  State<CometChatTextBubble> createState() => _CometChatTextBubbleState();
}

class _CometChatTextBubbleState extends State<CometChatTextBubble> {
  // Cached theme values to avoid expensive lookups during rebuilds
  CometChatTextBubbleStyle? _textBubbleStyle;
  CometChatTypography? _typography;
  CometChatColorPalette? _colorPalette;
  CometChatSpacing? _spacing;
  double _cachedMaxWidth = 300; // Default fallback
  TextScaler _cachedTextScaler = TextScaler.noScaling; // Cache text scaler
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
      _textBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatTextBubbleStyle>(
            context: context,
            defaultTheme: CometChatTextBubbleStyle.of,
          ).merge(widget.style);
      // Use passed values OR fallback to lookup (for standalone usage)
      _typography =
          widget.typography ?? CometChatThemeHelper.getTypography(context);
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
      // Cache screen width ONCE to avoid MediaQuery rebuilds during keyboard animation
      _cachedMaxWidth = MediaQuery.sizeOf(context).width * (75 / 100);
      // Cache text scaler ONCE to avoid MediaQuery rebuilds during keyboard animation
      _cachedTextScaler = MediaQuery.textScalerOf(context);
      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatTextBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if it changed
    if (widget.style != oldWidget.style) {
      _textBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatTextBubbleStyle>(
            context: context,
            defaultTheme: CometChatTextBubbleStyle.of,
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
    if (widget.typography != oldWidget.typography &&
        widget.typography != null) {
      _typography = widget.typography;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? message;
    if (widget.text != null) {
      message = widget.text;
    }

    if (message == null) {
      return const SizedBox(height: 0, width: 0);
    }

    final textBubbleStyle = _textBubbleStyle!;
    final typography = _typography!;
    final colorPalette = _colorPalette!;
    final spacing = _spacing!;

    // Emoji-only rendering: large emoji text, no background, no formatters
    if (widget.emojiCount > 0) {
      final emojiFontSize = EmojiUtils.emojiFontSize(widget.emojiCount);
      return Padding(
        padding:
            widget.padding ??
            EdgeInsets.fromLTRB(
              spacing.padding2 ?? 0,
              spacing.padding1 ?? 0,
              spacing.padding2 ?? 0,
              0,
            ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: emojiFontSize,
            height: 1.3,
            letterSpacing: 2.0,
          ),
        ),
      );
    }

    final textStyle =
        TextStyle(
              color: (widget.alignment == BubbleAlignment.right
                  ? colorPalette.white
                  : colorPalette.neutral900),
              fontWeight: typography.body?.regular?.fontWeight,
              fontSize: typography.body?.regular?.fontSize,
              fontFamily: typography.body?.regular?.fontFamily,
            )
            .merge(textBubbleStyle.textStyle)
            .copyWith(color: textBubbleStyle.textColor);

    return Container(
      height: widget.height,
      constraints: BoxConstraints(maxWidth: widget.width ?? _cachedMaxWidth),
      decoration: BoxDecoration(
        border: textBubbleStyle.border,
        borderRadius:
            textBubbleStyle.borderRadius ??
            BorderRadius.circular(spacing.radius3 ?? 0),
        color: textBubbleStyle.backgroundColor ?? colorPalette.transparent,
      ),
      child: Padding(
        padding:
            widget.padding ??
            EdgeInsets.fromLTRB(
              spacing.padding2 ?? 0,
              spacing.padding2 ?? 0,
              spacing.padding2 ?? 0,
              0,
            ),
        child: RichText(
          textScaler: _cachedTextScaler,
          // Text should always be left-aligned within the bubble
          textAlign: TextAlign.left,
          text: TextSpan(
            style: textStyle,
            // Pass the bubble style down as well: the spans set their own
            // style, which would otherwise override this parent's.
            children: FormatterUtils.buildTextSpan(
              message,
              widget.formatters,
              context,
              widget.alignment,
              textStyle: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
