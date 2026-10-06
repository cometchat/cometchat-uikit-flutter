import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// A widget that displays the send button for the message composer.
///
/// This widget handles multiple visual states:
/// - Normal state: Primary colored background with send icon
/// - Disabled state: Muted background when text is empty or no meaningful changes
///
/// The widget supports full customization through style parameters and
/// allows complete replacement via the [customSendButtonView] parameter.
///
/// Example usage:
/// ```dart
/// MessageComposerSendButton(
///   onPressed: () => sendMessage(),
///   isDisabled: textController.text.isEmpty,
/// )
/// ```
class MessageComposerSendButton extends StatelessWidget {
  const MessageComposerSendButton({
    super.key,
    required this.onPressed,
    required this.isDisabled,
    this.hideSendButton = false,
    this.customSendButtonView,
    this.sendButtonIcon,
    this.sendButtonIconColor,
    this.sendButtonIconBackgroundColor,
    this.sendButtonBorderRadius,
    this.colorPalette,
    this.spacing,
  });

  /// Callback invoked when the send button is tapped.
  final VoidCallback onPressed;

  /// Whether the send button should appear disabled.
  /// When true, the button shows a muted background color.
  final bool isDisabled;

  /// Whether to hide the send button entirely.
  /// When true, returns an empty SizedBox.
  final bool hideSendButton;

  /// Custom widget to replace the default send button.
  /// When provided, this widget is wrapped in a GestureDetector
  /// that invokes [onPressed] on tap.
  final Widget? customSendButtonView;

  /// Custom icon for the send button.
  /// Overrides the default send icon.
  final Widget? sendButtonIcon;

  /// Color for the send button icon.
  /// Only applies to the default send icon asset.
  final Color? sendButtonIconColor;

  /// Background color for the send button container.
  /// Overrides the theme-based background color.
  final Color? sendButtonIconBackgroundColor;

  /// Border radius for the send button container.
  /// Defaults to a circular border radius.
  final BorderRadiusGeometry? sendButtonBorderRadius;

  /// Color palette for theming.
  /// If not provided, uses CometChatThemeHelper.getColorPalette(context).
  final CometChatColorPalette? colorPalette;

  /// Spacing configuration.
  /// If not provided, uses CometChatThemeHelper.getSpacing(context).
  final CometChatSpacing? spacing;

  @override
  Widget build(BuildContext context) {
    if (hideSendButton) {
      return const SizedBox();
    }

    if (customSendButtonView != null) {
      return GestureDetector(
        onTap: isDisabled ? null : onPressed,
        child: customSendButtonView,
      );
    }

    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);

    final Color backgroundColor =
        sendButtonIconBackgroundColor ??
        (isDisabled
            ? effectiveColorPalette.background4 ?? Colors.grey
            : effectiveColorPalette.primary ?? Colors.blue);

    final BorderRadiusGeometry borderRadius =
        sendButtonBorderRadius ??
        BorderRadius.circular(effectiveSpacing.radiusMax ?? 20);

    const double buttonSize = 32;

    return Semantics(
      label: isDisabled ? 'Send button disabled' : 'Send message',
      button: true,
      enabled: !isDisabled,
      child: kIsWeb
          ? GestureDetector(
              // [isDisabled] must actually block the tap — it previously only
              // greyed the fill, so a "disabled" button still sent (e.g. while
              // attachments were mid-upload).
              onTap: isDisabled ? null : onPressed,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: borderRadius,
                ),
                alignment: Alignment.center,
                height: buttonSize,
                width: buttonSize,
                child: _buildIcon(effectiveColorPalette),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: borderRadius,
              ),
              alignment: Alignment.center,
              height: buttonSize,
              width: buttonSize,
              child: IconButton(
                tooltip: Translations.of(context).sendMessage,
                padding: const EdgeInsets.all(0),
                icon: _buildIcon(effectiveColorPalette),
                // Null disables the IconButton for real; passing the callback
                // regardless made the greyed-out button still fire.
                onPressed: isDisabled ? null : onPressed,
              ),
            ),
    );
  }

  Widget _buildIcon(CometChatColorPalette colorPalette) {
    if (sendButtonIcon != null) {
      return sendButtonIcon!;
    }

    return Image.asset(
      AssetConstants.send,
      package: UIConstants.packageName,
      height: 20,
      width: 20,
      color: sendButtonIconColor ?? colorPalette.iconWhite,
    );
  }
}
