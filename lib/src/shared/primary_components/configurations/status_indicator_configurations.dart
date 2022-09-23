import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/shared/primary_components/configurations/cometchat_configurations.dart';

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
class StatusIndicatorConfiguration extends CometChatConfigurations {
  ///status indicator configurations
  const StatusIndicatorConfiguration(
      {this.width, this.height, this.cornerRadius, this.border});

  ///[width] width of container
  final double? width;

  ///[height] of container
  final double? height;

  ///[cornerRadius] of container
  final double? cornerRadius;

  ///[border] border
  final BoxBorder? border;
}
