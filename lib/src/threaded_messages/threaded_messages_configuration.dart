import 'package:flutter/material.dart';
import '../../cometchat_chat_uikit.dart';

///[ThreadedMessagesConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatThreadedMessages]
/// ```dart
/// ThreadedMessagesConfiguration(
///      threadedMessagesStyle: ThreadedMessageStyle(),
///      messageComposerConfiguration: MessageComposerConfiguration(),
///      messageListConfiguration: MessageListConfiguration()
///    );
/// ```
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
      this.theme,
      this.messageComposerView,
      this.messageListView});

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

  ///[messageComposerView] to set custom message composer
  final Widget Function(User? user, Group? group, BuildContext context,
      BaseMessage parentMessage)? messageComposerView;

  ///[messageListView] to set custom message list
  final Widget Function(User? user, Group? group, BuildContext context,
      BaseMessage parentMessage)? messageListView;
}
