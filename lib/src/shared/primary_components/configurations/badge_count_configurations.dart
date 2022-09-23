import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatBadgeCount]
///
/// this Configuration object can be used to configure [CometChatBadgeCount] properties
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
class BadgeCountConfiguration extends CometChatConfigurations {
  const BadgeCountConfiguration(
      {this.background,
      this.textStyle,
      this.cornerRadius,
      this.borderWidth,
      this.borderColor,
      this.height,
      this.width});

  ///[background] gives background color to badge
  final Color? background;

  ///[textStyle] gives style to count
  final TextStyle? textStyle;

  ///[cornerRadius] of wrapping container
  final double? cornerRadius;

  ///[borderWidth] of wrapping container
  final double? borderWidth;

  ///[borderColor] of wrapping container
  final Color? borderColor;

  ///[height] of container
  final double? height;

  ///[width] of container
  final double? width;
}
