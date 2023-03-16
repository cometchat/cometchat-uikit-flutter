/*
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatDate]
///
/// this Configuration object can be used to configure [CometChatDate] properties
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
class DateConfiguration extends CometChatConfigurations {
  const DateConfiguration(
      {
        // this.format,
      this.pattern,
      this.timeFormat,
      this.dateFormat,
      this.style});

  ///[format] gives format to supplied date.
  // final String? format;

  final DateTimePattern? pattern;

  final String? timeFormat;

  final String? dateFormat;

  ///[style] contains properties that affects the appearance of date widget
  final DateStyle? style;

}
*/