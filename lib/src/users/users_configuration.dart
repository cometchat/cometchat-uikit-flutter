import '../../../../flutter_chat_ui_kit.dart';

///
///  ```dart
///     UsersConfiguration(
///               hideSearch: false,
///               showBackButton: true,
///               searchPlaceholder: "search",
///               title: "Users",
///               userListConfiguration: UserListConfiguration(),
///             )
///   ```
///
class UsersConfiguration {
  const UsersConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.showBackButton = true,
      this.hideSearch = false,
      this.activeUser,
      this.userListConfiguration = const UserListConfiguration()});

  ///[title] Title of the user list component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[activeUser] selected user
  final String? activeUser;

  ///[userListConfiguration] CometChatUserList configurations
  final UserListConfiguration userListConfiguration;
}
