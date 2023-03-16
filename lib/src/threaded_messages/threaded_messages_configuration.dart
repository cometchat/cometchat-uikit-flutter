import 'package:flutter/material.dart';
import '../../flutter_chat_ui_kit.dart';

///Configuration class for [CometChatThreadedMessages]
class ThreadedMessagesConfiguration {
  const ThreadedMessagesConfiguration(
      {this.title,
      this.closeIcon,
      this.messageActionView,
      this.messageComposerConfiguration,
      this.messageListConfiguration,
      this.threadedMessagesStyle,
      this.hideMessageComposer,
      this.bubbleView,
      this.theme});

  ///[title] to be shown at head
  final String? title;

  ///to update Close Icon
  final Widget? closeIcon;

  ///[bubbleView] bubble view for parent message
  final Widget Function(BaseMessage, BuildContext context)? bubbleView;

  ///[messageActionView] custom action view
  final Function(BaseMessage message, BuildContext context)? messageActionView;

  ///[messageListConfiguration] configuration class for [CometChatMessageList]
  final MessageListConfiguration? messageListConfiguration;

  ///[messageComposerConfiguration] configuration class for [CometChatMessageComposer]
  final MessageComposerConfiguration? messageComposerConfiguration;

  ///[threadedMessagesStyle] style parameter
  final ThreadedMessageStyle? threadedMessagesStyle;

  ///[hideMessageComposer] toggle visibility for message composer
  final bool? hideMessageComposer;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;
}
