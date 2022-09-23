import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessageHeader]
///
/// ```dart
///  MessageHeaderConfiguration(
///          avatarConfiguration: AvatarConfiguration(),
///          statusIndicatorConfiguration: StatusIndicatorConfiguration(),
///          showBackButton: true
///        )
/// ```
///
class MessageHeaderConfiguration {
  const MessageHeaderConfiguration(
      {this.showBackButton = true,
      this.backButton,
      this.avatarConfiguration,
      this.statusIndicatorConfiguration});

  ///[showBackButton] if true it shows back button
  final bool showBackButton;

  ///[backButton] custom back button widget
  final Widget? backButton;

  ///[avatarConfigurations] set configuration property for [CometChatAvatar] used inside [CometChatMessageHeader]
  final AvatarConfiguration? avatarConfiguration;

  ///[statusIndicatorConfiguration] set configuration property for [CometChatStatusIndicator] used inside [CometChatMessageHeader]
  final StatusIndicatorConfiguration? statusIndicatorConfiguration;
}
