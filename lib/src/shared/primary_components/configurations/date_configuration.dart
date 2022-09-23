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
      {this.format,
      this.textStyle,
      this.backgroundColor,
      this.cornerRadius,
      this.borderWidth,
      this.borderColor,
      this.isTransparentBackground,
      this.contentPadding,
      this.pattern,
      this.timeFormat,
      this.dateFormat});

  ///[format] gives format to supplied date.
  final String? format;

  ///[textStyle] Style of date to be displayed.
  final TextStyle? textStyle;

  ///[backgroundColor] background color of the container.
  final Color? backgroundColor;

  ///[cornerRadius] radius of corners of container.
  final double? cornerRadius;

  ///[borderWidth] width of border.
  final double? borderWidth;

  final Color? borderColor;

  ///set the container to be transparent.
  final bool? isTransparentBackground;

  ///[contentPadding] set the content padding.
  final EdgeInsetsGeometry? contentPadding;

  final DateTimePattern? pattern;

  final String? timeFormat;

  final String? dateFormat;
}
