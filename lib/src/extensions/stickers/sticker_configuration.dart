import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[StickerConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [StickersExtension]
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
///   theme: CometChatTheme(),
///   stickerKeyboardStyle: StickerKeyboardStyle(),
/// );
///
/// ```
class StickerConfiguration {
  StickerConfiguration(
      {this.errorIcon,
      this.emptyStateView,
      this.errorStateView,
      this.loadingStateView,
      this.errorStateText,
      this.emptyStateText,
      this.stickerButtonIcon,
      this.keyboardButtonIcon,
      this.theme,
      this.stickerKeyboardStyle,
      this.stickerIconTint,
      this.keyboardIconTint});

  ///[stickerKeyboardStyle] style for the sticker keyboard
  final StickerKeyboardStyle? stickerKeyboardStyle;

  ///[stickerButtonIcon] shows stickers keyboard
  final Widget? stickerButtonIcon;

  ///[keyboardButtonIcon] hides stickers keyboard
  final Widget? keyboardButtonIcon;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

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
}
