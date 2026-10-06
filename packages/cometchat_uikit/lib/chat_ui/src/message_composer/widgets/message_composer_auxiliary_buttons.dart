import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// A widget that displays the auxiliary action buttons (stickers, voice recording).
///
/// This widget renders buttons on the right side of the text input in the
/// single-row message composer layout:
/// - Auxiliary options from the data source (stickers, emoji, etc.)
/// - Voice recording button (with slide-to-send animation on hide)
///
/// Example usage:
/// ```dart
/// MessageComposerAuxiliaryButtons(
///   onVoiceRecordingTap: () => showVoiceRecorder(),
/// )
/// ```
class MessageComposerAuxiliaryButtons extends StatefulWidget {
  const MessageComposerAuxiliaryButtons({
    super.key,
    required this.onVoiceRecordingTap,
    this.hideVoiceRecordingButton = false,
    this.customAuxiliaryButtonView,
    this.auxiliaryOptions,
    this.voiceRecordingIcon,
    this.auxiliaryButtonIconColor,
    this.auxiliaryButtonIconBackgroundColor,
    this.auxiliaryButtonBorderRadius,
    this.colorPalette,
    this.spacing,
    this.voiceFirst = false,
  });

  final VoidCallback onVoiceRecordingTap;
  final bool hideVoiceRecordingButton;
  final Widget? customAuxiliaryButtonView;
  final Widget? auxiliaryOptions;
  final Widget? voiceRecordingIcon;
  final Color? auxiliaryButtonIconColor;
  final Color? auxiliaryButtonIconBackgroundColor;
  final BorderRadiusGeometry? auxiliaryButtonBorderRadius;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;

  /// When true, renders the mic button BEFORE [auxiliaryOptions] (stickers).
  /// Default false keeps the existing single-line order: `[stickers][mic]`.
  /// Set this to true when the composer is in double-line layout with
  /// `auxiliaryButtonsAlignment: left` so the visual order becomes
  /// `[+][mic][stickers] ... [send]` — matching v5 and the Figma spec.
  final bool voiceFirst;

  @override
  State<MessageComposerAuxiliaryButtons> createState() =>
      _MessageComposerAuxiliaryButtonsState();
}

class _MessageComposerAuxiliaryButtonsState
    extends State<MessageComposerAuxiliaryButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  // Track visibility to drive animation direction
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _isVisible = !widget.hideVoiceRecordingButton;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _isVisible ? 1.0 : 0.0,
    );

    _sizeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Slide from right (toward send button) when hiding
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(MessageComposerAuxiliaryButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldBeVisible = !widget.hideVoiceRecordingButton;
    if (shouldBeVisible != _isVisible) {
      _isVisible = shouldBeVisible;
      if (_isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customAuxiliaryButtonView != null) {
      return widget.customAuxiliaryButtonView!;
    }

    final effectiveColorPalette =
        widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);

    final bool hasAuxOptions = widget.auxiliaryOptions != null;

    return Semantics(
      label: Translations.of(context).messageComposerAuxiliaryActions,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.auxiliaryButtonIconBackgroundColor,
          borderRadius: widget.auxiliaryButtonBorderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Default order: [stickers][mic]. When voiceFirst is true, flip to
            // [mic][stickers] so the double-line + left-alignment layout shows
            // [+][mic][stickers] ... [send] matching v5 / the Figma spec.
            if (widget.voiceFirst) ...[
              // Animated mic button first; trailing gap lives inside the
              // SizeTransition so it collapses together with the mic when text
              // is typed (no phantom spacing left behind).
              _buildAnimatedVoiceRecordingButton(
                effectiveColorPalette,
                axisAlignment: -1.0, // Collapse toward the left (+ button)
                needsLeftMargin: false,
                padding: EdgeInsets.only(right: hasAuxOptions ? 12.0 : 0.0),
              ),
              if (hasAuxOptions) widget.auxiliaryOptions!,
            ] else ...[
              if (hasAuxOptions) widget.auxiliaryOptions!,
              // Animated mic button — slides toward send button while width collapses
              _buildAnimatedVoiceRecordingButton(
                effectiveColorPalette,
                axisAlignment: 1.0, // Collapse toward the right (send button)
                needsLeftMargin: hasAuxOptions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Wraps the mic in its hide animation, and drops the subtree entirely once
  /// it has finished collapsing. Without this the button stays in the tree at
  /// zero size and zero opacity while `hideVoiceRecordingButton` is true — it
  /// is invisible, but it is still a focusable, screen-reader-announced
  /// "Record voice message" control that the integrator asked to remove.
  Widget _buildAnimatedVoiceRecordingButton(
    CometChatColorPalette colorPalette, {
    required double axisAlignment,
    required bool needsLeftMargin,
    EdgeInsetsGeometry? padding,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_isVisible && _controller.value == 0.0) {
          return const SizedBox.shrink();
        }
        Widget button = _buildVoiceRecordingButton(
          colorPalette,
          needsLeftMargin: needsLeftMargin,
        );
        if (padding != null) {
          button = Padding(padding: padding, child: button);
        }
        return SizeTransition(
          axis: Axis.horizontal,
          sizeFactor: _sizeAnimation,
          // `alignment` needs Flutter 3.41; the package floor stays at 3.38.9 (DEPR1).
          // ignore: deprecated_member_use
          axisAlignment: axisAlignment,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(opacity: _opacityAnimation, child: button),
          ),
        );
      },
    );
  }

  Widget _buildVoiceRecordingButton(
    CometChatColorPalette colorPalette, {
    bool needsLeftMargin = false,
  }) {
    final Color iconColor =
        widget.auxiliaryButtonIconColor ??
        colorPalette.iconSecondary ??
        Colors.grey;

    return Semantics(
      label: Translations.of(context).recordVoiceMessage,
      button: true,
      child: Container(
        height: 24,
        width: 24,
        margin: needsLeftMargin ? const EdgeInsets.only(left: 12) : null,
        child: IconButton(
          tooltip: Translations.of(context).recordVoiceMessage,
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(),
          icon:
              widget.voiceRecordingIcon ??
              Image.asset(
                excludeFromSemantics: true,
                AssetConstants.microphone,
                package: UIConstants.packageName,
                height: 24,
                width: 24,
                color: iconColor,
              ),
          onPressed: widget.onVoiceRecordingTap,
        ),
      ),
    );
  }
}
