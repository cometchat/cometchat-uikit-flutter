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
class GroupListItemConfiguration extends CometChatConfigurations {
  ///group list configurations
  GroupListItemConfiguration(
      {this.inputData = const InputData(), this.groupOptions = const []});

  ///[inputData]
  final InputData? inputData;

  ///[groupOptions]
  final List<Widget>? groupOptions;
}
