import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Class to set configuration for  message bubbles
///
/// Message bubble is the term used by CometChat team to denote to all type of messages visible in message list
/// eg [CometChatFileBubble] , [CometChatImageBubble]..etc
/// all types of bubble visible under message_bubble folder
///
/// ```dart
/// MessageBubbleConfiguration configuration = const  MessageBubbleConfiguration();
///
/// ```
class MessageBubbleConfiguration {
  const MessageBubbleConfiguration(
      {this.dateConfiguration,
      this.messageReceiptConfiguration,
      this.avatarConfiguration,
      this.timeAlignment});

  ///[dateConfiguration]
  final DateConfiguration? dateConfiguration;

  ///[messageReceiptConfiguration]
  final MessageReceiptConfiguration? messageReceiptConfiguration;

  ///[avatarConfigurations]
  final AvatarConfiguration? avatarConfiguration;

  ///[timeAlignment] time alignment top/bottom
  final TimeAlignment? timeAlignment;
}
