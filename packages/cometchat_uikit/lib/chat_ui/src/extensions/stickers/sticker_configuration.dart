import 'package:flutter/material.dart';

///[StickerConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of `StickersExtension`
///
///Has no effect in v6. Set the sticker button on the composer instead:
///`CometChatMessageComposer.stickerIcon` and
///`CometChatMessageComposer.stickerActiveIcon` replace [stickerButtonIcon]
///and [keyboardButtonIcon];
///`CometChatMessageComposerStyle.stickerIconColor` and
///`CometChatMessageComposerStyle.stickerActiveIconColor` replace
///[stickerIconTint] and [keyboardIconTint]. Style the sticker keyboard with
///`CometChatMessageComposerStyle.stickerKeyboardStyle` or a
///`CometChatStickerKeyboardStyle` theme extension.
///[errorIcon], [errorStateText] and [emptyStateText] have no replacement.
///
/// ```dart
///
/// final stickerConfig = StickerConfiguration(
///   errorIcon: Icon(Icons.error),
///   emptyStateView: (context) => Text('No stickers available.'),
///   errorStateView: (context) => Text('Failed to load stickers.'),
///   loadingStateView: (context) => CircularProgressIndicator(),
///   errorStateText: 'Error fetching stickers',
///   emptyStateText: 'No stickers available',
///   stickerButtonIcon: Icon(Icons.sticky_note_2),
///   keyboardButtonIcon: Icon(Icons.keyboard),
///   stickerBubbleHeight: 100,
///   stickerBubbleWidth: 100,
/// );
///
/// ```
@Deprecated(
  'Has no effect: no API in v6 accepts an extension configuration object. '
  'Use CometChatMessageComposer.stickerIcon / stickerActiveIcon for the '
  'sticker button icons, CometChatMessageComposerStyle.stickerIconColor / '
  'stickerActiveIconColor for their tints, and '
  'CometChatMessageComposerStyle.stickerKeyboardStyle or the '
  'CometChatStickerKeyboardStyle theme extension for the sticker keyboard, '
  'and stickerBubbleStyle on CometChatIncomingMessageBubbleStyle / '
  'CometChatOutgoingMessageBubbleStyle for the sticker bubble. Custom '
  'loading, empty and error views exist only on a standalone '
  'CometChatStickerKeyboard. errorIcon, errorStateText, emptyStateText, '
  'stickerBubbleHeight, stickerBubbleWidth and stickerUrl have no '
  'replacement. '
  'Will be removed in 7.0.0.',
)
class StickerConfiguration {
  /// Creates a [StickerConfiguration].
  StickerConfiguration({
    this.errorIcon,
    this.emptyStateView,
    this.errorStateView,
    this.loadingStateView,
    this.errorStateText,
    this.emptyStateText,
    this.stickerButtonIcon,
    this.keyboardButtonIcon,
    this.stickerIconTint,
    this.keyboardIconTint,
    this.stickerBubbleHeight,
    this.stickerBubbleWidth,
    this.stickerUrl,
  });

  ///[stickerButtonIcon] shows stickers keyboard
  final Widget? stickerButtonIcon;

  ///[keyboardButtonIcon] hides stickers keyboard
  final Widget? keyboardButtonIcon;

  ///[errorIcon] icon to be shown in case of any error
  final Widget? errorIcon;

  ///[emptyStateView] to be shown when there are no stickers
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] to be shown when some error occurs on fetching the sticker
  final WidgetBuilder? errorStateView;

  ///[loadingStateView] view at loading state
  final WidgetBuilder? loadingStateView;

  ///[errorStateText] text to be show in error state
  final String? errorStateText;

  ///[emptyStateText] text to be shown at empty state
  final String? emptyStateText;

  ///[stickerIconTint] provides color to the sticker Icon/widget
  final Color? stickerIconTint;

  ///[keyboardIconTint] provides color to the keyboard Icon/widget
  final Color? keyboardIconTint;

  ///[stickerBubbleHeight] height of the sticker
  final double? stickerBubbleHeight;

  ///[stickerBubbleWidth] width of the sticker
  final double? stickerBubbleWidth;

  ///[stickerUrl] if message object is not passed then sticker url should be passed
  final String? stickerUrl;
}
