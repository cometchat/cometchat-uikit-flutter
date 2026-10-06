import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// A widget that displays the secondary action button (attachment).
///
/// This widget renders the attachment button on the left side of the text input
/// in the single-row message composer layout.
///
/// The button can be hidden via [hideAttachmentButton] and supports custom icons.
/// The entire widget can be replaced via [customSecondaryButtonView].
/// Returns empty SizedBox when attachment button is hidden.
///
/// Example usage:
/// ```dart
/// MessageComposerSecondaryButtons(
///   onAttachmentTap: () => showAttachmentSheet(),
/// )
/// ```
class MessageComposerSecondaryButtons extends StatelessWidget {
  const MessageComposerSecondaryButtons({
    super.key,
    required this.onAttachmentTap,
    this.hideAttachmentButton = false,
    this.customSecondaryButtonView,
    this.attachmentIcon,
    this.attachmentIconURL,
    this.secondaryButtonIconColor,
    this.secondaryButtonIconBackgroundColor,
    this.secondaryButtonBorderRadius,
    this.colorPalette,
    this.spacing,
    this.attachmentButtonLink,
    this.attachmentOpenNotifier,
    this.disabled = false,
  });

  /// Callback invoked when the attachment button is tapped.
  final VoidCallback onAttachmentTap;

  /// When true, the button is dimmed and ignores taps — used while editing an
  /// existing message's text, where adding new attachments isn't meaningful.
  final bool disabled;

  /// Whether to hide the attachment button.
  final bool hideAttachmentButton;

  /// Custom widget to replace the default secondary buttons.
  /// When provided, this widget is rendered instead of the default buttons.
  final Widget? customSecondaryButtonView;

  /// Custom icon for the attachment button.
  final Widget? attachmentIcon;

  /// Asset URL for the attachment icon.
  /// Used when [attachmentIcon] is not provided.
  final String? attachmentIconURL;

  /// Color for the secondary button icons.
  /// Overrides the theme-based icon color.
  final Color? secondaryButtonIconColor;

  /// Background color for the secondary buttons container.
  final Color? secondaryButtonIconBackgroundColor;

  /// Border radius for the secondary buttons container.
  final BorderRadiusGeometry? secondaryButtonBorderRadius;

  /// Color palette for theming.
  /// If not provided, uses CometChatThemeHelper.getColorPalette(context).
  final CometChatColorPalette? colorPalette;

  /// Spacing configuration.
  /// If not provided, uses CometChatThemeHelper.getSpacing(context).
  final CometChatSpacing? spacing;

  /// LayerLink for positioning the attachment overlay relative to the button.
  ///
  /// When provided, the attachment button is wrapped with a [CompositedTransformTarget]
  /// to enable precise positioning of an overlay popup using [CompositedTransformFollower].
  /// When null, the button renders without the transform target wrapper.
  final LayerLink? attachmentButtonLink;

  /// Notifier that tracks whether the attachment overlay is open.
  /// When provided, the + icon animates: clockwise on open, anti-clockwise on close.
  final ValueNotifier<bool>? attachmentOpenNotifier;

  @override
  Widget build(BuildContext context) {
    if (customSecondaryButtonView != null) {
      return customSecondaryButtonView!;
    }

    if (hideAttachmentButton) {
      return const SizedBox();
    }

    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);

    final Color iconColor =
        secondaryButtonIconColor ??
        effectiveColorPalette.iconSecondary ??
        Colors.grey;

    return Semantics(
      label: Translations.of(context).attachmentButton,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: secondaryButtonIconBackgroundColor,
          borderRadius: secondaryButtonBorderRadius,
        ),
        child: _buildAttachmentButton(
          context,
          effectiveColorPalette,
          effectiveSpacing,
          iconColor,
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    Color iconColor,
  ) {
    Widget icon =
        attachmentIcon ??
        Image.asset(
          AssetConstants.add,
          package: UIConstants.packageName,
          height: 22,
          width: 22,
          color: iconColor,
        );

    // Wrap default icon with rotation animation when notifier is provided
    // and no custom attachmentIcon is set (custom icons manage their own look)
    if (attachmentOpenNotifier != null && attachmentIcon == null) {
      icon = ValueListenableBuilder<bool>(
        valueListenable: attachmentOpenNotifier!,
        builder: (context, isOpen, child) {
          return AnimatedRotation(
            turns: isOpen ? 0.25 : 0.0, // 0.25 turns = 90° clockwise
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: child,
          );
        },
        child: icon,
      );
    }

    if (disabled) {
      icon = Opacity(opacity: 0.4, child: icon);
    }

    final button = Semantics(
      label: Translations.of(context).addAttachment,
      button: true,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onAttachmentTap,
        child: icon,
      ),
    );

    // Wrap with CompositedTransformTarget when LayerLink is provided
    // to enable overlay positioning relative to this button
    if (attachmentButtonLink != null) {
      return CompositedTransformTarget(
        link: attachmentButtonLink!,
        child: button,
      );
    }

    return button;
  }
}
