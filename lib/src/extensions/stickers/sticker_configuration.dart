import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

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
      this.stickerKeyboardStyle});

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
}
