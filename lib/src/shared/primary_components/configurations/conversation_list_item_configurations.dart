import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatConversationListItem]
///
/// this Configuration object can be used to configure [CometChatConversationListItem] properties
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
class ConversationListItemConfigurations extends CometChatConfigurations {
  const ConversationListItemConfigurations(
      {this.showTypingIndicator = true,
      this.hideThreadIndicator = false,
      this.hideReceipt = false,
      this.inputData = const ConversationInputData(),
      this.conversationOptions});

  final bool showTypingIndicator;
  final bool hideThreadIndicator;
  final bool hideReceipt;
  final ConversationInputData inputData;

  final CometChatMenuList Function(
      int index, CometChatConversationListState listState)? conversationOptions;
}
