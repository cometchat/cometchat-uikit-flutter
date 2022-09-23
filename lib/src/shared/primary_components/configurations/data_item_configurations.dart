import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

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
class DataItemConfiguration<T> {
  ///User list item configurations
  const DataItemConfiguration(
      {this.inputData,
      this.options = const [],
      this.avatarConfiguration,
      this.statusIndicatorConfiguration});

  ///[inputData]
  final InputData<T>? inputData;

  ///[userOptions]
  final List<Widget> options;

  final AvatarConfiguration? avatarConfiguration;

  final StatusIndicatorConfiguration? statusIndicatorConfiguration;
}
