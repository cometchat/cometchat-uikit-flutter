import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///
///```dart
///UserListConfiguration(
///         friendsOnly: false,
///           status: CometChatUserStatus.online,
///           customView: CustomView(),
///           hideError: false,
///           uids: [],
///           hideBlockedUsers: false,
///          errorText: "Something went wrong",
///           emptyText: "No users",
///           limit: 30,
///           searchKeyword: "",
///           roles: [],
///           tags: [],
///           dataItemConfiguration:
///               DataItemConfiguration<User>(
///                   inputData: InputData(
///                       subtitle: (User user) {
///             return user.uid;
///           })))
/// ```
///
///
class UserListConfiguration {
  const UserListConfiguration(
      {this.limit = 30,
      this.searchKeyword,
      this.status,
      this.friendsOnly,
      this.hideBlockedUsers,
      this.roles = const [],
      this.tags = const [],
      this.uids = const [],
      this.emptyText,
      this.errorText,
      this.customView = const CustomView(),
      this.hideError = false,
      this.activeUser,
      this.dataItemConfiguration = const DataItemConfiguration<User>()});

  ///[limit] number of users that should be fetched in a single iteration
  final int limit;

  ///[searchKeyword] fetch users based on the search string
  final String? searchKeyword;

  ///[status] fetch users based on status. Can contain one of the two values
  /// CometChatUserStatus.online;
  /// CometChatUserStatus.offline
  final String? status;

  ///[friendsOnly] return only the friends of the logged-in user
  final bool? friendsOnly;

  ///[hideBlockedUsers] allows you to determine if the blocked users should be returned as a part of the user list.
  ///If set to true, the user list will not contain the users blocked by the logged in user.
  final bool? hideBlockedUsers;

  ///[roles] fetch the users based on multiple roles
  final List<String> roles;

  ///[tags] list of tags based on which the list of users is to be fetched
  final List<String> tags;

  ///[uids] list of UIDs based on which the list of users is fetched. A maximum of 25 uids are allowed.
  final List<String> uids;

  ///[emptyText] text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when error occur
  final String? errorText;

  ///[customView] allows you to embed a custom view/component for loading, empty and error state.
  ///If no value is set, default view will be rendered.
  final CustomView customView;

  ///[hideError] if set to false, error will not be shown in the UI, which means, user will handle error at his end
  final bool hideError;

  ///[activeUser] selected user
  final String? activeUser;

  ///[dataItemConfiguration] data item configuration
  final DataItemConfiguration<User>? dataItemConfiguration;
}
