import '../../../../flutter_chat_ui_kit.dart';

/// Validates different widgets visible in [CometChatConversationListItem]
///
/// Contains parameters to alter visibility for different widgets in  [CometChatConversationListItem]

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
class InputData<T> {
  const InputData({
    this.thumbnail = true,
    this.status = true,
    this.title = true,
    this.subtitle,
    // this.time = true,
    // this.unreadCount = true,
    this.id = true,
  });

  ///[id]  id
  final bool? id;

  ///[thumbnail] avatar
  final bool thumbnail;

  ///[status] status indicator
  final bool status;

  ///[title] title of list item User name or group name
  final bool title;

  ///[subtitle] subtitle of list item ,last message
  final String? Function(T)? subtitle;
}

/// Validates different widgets visible in [CometChatConversationListItem]
///
/// Contains parameters to alter visibility for different widgets in  [CometChatConversationListItem]

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
class ConversationInputData<T> extends InputData<Conversation> {
  final bool unreadCount;

  final bool readReceipt;

  final bool timestamp;

  const ConversationInputData({
    this.unreadCount = true,
    this.readReceipt = true,
    this.timestamp = true,
    bool? id,
    bool thumbnail = true,
    bool status = true,
    bool title = true,
    String Function(Conversation)? subtitle,
  }) : super(
            title: title,
            thumbnail: thumbnail,
            status: status,
            subtitle: subtitle
            //have to add subtitle
            );
}

/// Validates different widgets visible in [CometChatMessageBubble]
///
/// Contains parameters to alter visibility for different widgets in  [CometChatMessageBubble]
///
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

class MessageInputData<T extends BaseMessage> extends InputData<T> {
  final bool timestamp;

  final bool readReceipt;

  const MessageInputData({
    this.readReceipt = true,
    this.timestamp = true,
    bool? id,
    bool thumbnail = false,
    bool title = true,
  }) : super(
          id: id,
          thumbnail: thumbnail,
          title: title,
          status: false,
        );
}
