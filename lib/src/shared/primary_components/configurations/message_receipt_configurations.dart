import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatDataItem]
///
/// this Configuration object can be used to configure [CometChatDataItem] properties
/// from parents

/// {@tool snippet}
/// ```dart
///CometChatUsers(
///       title: "Users",
///       showBackButton: true,
///       hideSearch:false,
///       searchPlaceholder:'Search',
///       searchBoxIcon: Icon(Icons.search),
///       backButton: Icon(Icons.arrow_back_rounded),
///       style: UsersStyle(
///         background: Colors.white,
///         titleStyle: TextStyle(),
///         gradient: LinearGradient(colors: [Colors.redAccent,Colors.purpleAccent])
///       ),
///       userListConfiguration: UserListConfiguration(
///       )
///     );
///```
/// {@end-tool}
class MessageReceiptConfiguration extends CometChatConfigurations {
  ///message receipt configurations
  const MessageReceiptConfiguration(
      {this.waitIcon,
      this.sentIcon,
      this.deliveredIcon,
      this.errorIcon,
      this.readIcon});

  ///[waitIcon] widget visible while sentAt and deliveredAt is null in message. If blank will load default waitIcon
  final Widget? waitIcon;

  ///[sentIcon] widget visible while sentAt != null and deliveredAt is null in message. If blank will load default sentIcon
  final Widget? sentIcon;

  ///[deliveredIcon] widget visible while  deliveredAt != null  in message. If blank will load default deliveredIcon
  final Widget? deliveredIcon;

  ///[errorIcon] widget visible while sentAt and deliveredAt is null in message. If blank will load default errorIcon
  final Widget? errorIcon;

  ///[readIcon] widget visible when readAt != null in message. If blank will load default readIcon
  final Widget? readIcon;
}
