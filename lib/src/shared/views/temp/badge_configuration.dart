/*
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatBadge]
///
/// this Configuration object can be used to configure [CometChatBadge] properties
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
class BadgeConfiguration extends CometChatConfigurations {
  const BadgeConfiguration({this.count, this.style});

  ///[count] shows the value inside badge if less then 0 then only size box will be displayed
  ///if [count] > 999 the 999+ will be displayed
  final int? count;

  ///[style] contains properties that affects the appearance of this widget
  final BadgeStyle? style;
}
*/