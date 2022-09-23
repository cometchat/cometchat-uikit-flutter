import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometchatConversationList]
///
/// this Configuration object can be used to configure [CometchatConversationList] properties
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
class ConversationListConfigurations extends CometChatConfigurations {
  const ConversationListConfigurations(
      {this.limit,
      this.userAndGroupTags,
      this.tags,
      this.customView,
      this.hideError,
      this.onErrorCallBack});

  ///[limit] no of conversations to be fetch at once
  final int? limit;

  ///[userAndGroupTags]
  final bool? userAndGroupTags;

  ///[tags] list of tags
  final List<String>? tags;

  ///[customView] custom widgets for loading,error,empty
  final CustomView? customView;

  ///[hideError] hides error
  final bool? hideError;

  ///[onErrorCallBack] on error callback function
  final void Function(Object)? onErrorCallBack;
}
