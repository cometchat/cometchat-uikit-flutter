import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/debouncer.dart';

///[CometChatUsers] is a container component that wraps and formats the [CometChatListBase] and [CometChatUserList] component
///
/// it list down users according to different parameter set in order of recent activity
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
///

class CometChatUsers extends StatefulWidget {
  const CometChatUsers(
      {Key? key,
      this.title,
      this.style = const UsersStyle(),
      this.theme,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchBoxIcon,
      this.hideSearch = false,
      this.activeUser,
      this.userListConfiguration = const UserListConfiguration()})
      : super(key: key);

  ///[title] Title of the user list component
  final String? title;

  ///[style] consists of all styling properties
  final UsersStyle style;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[activeUser] selected user
  final String? activeUser;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[userListConfiguration] user list configuration
  final UserListConfiguration userListConfiguration;

  @override
  State<CometChatUsers> createState() => _CometChatUsersState();
}

class _CometChatUsersState extends State<CometChatUsers> {
  CometChatUserListState? userListState;

  userListStateCallBack(CometChatUserListState _userListState) {
    userListState = _userListState;
  }

  final _deBouncer = Debouncer(milliseconds: 500);

  onSearch(String val) {
    _deBouncer.run(() {
      userListState?.buildRequest(searchKeyword: val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CometChatListBase(
        title: widget.title ?? Translations.of(context).users,
        hideSearch: widget.hideSearch,
        backIcon: widget.backButton,
        placeholder: widget.searchPlaceholder,
        showBackButton: widget.showBackButton,
        searchBoxIcon: widget.searchBoxIcon,
        onSearch: onSearch,
        searchText: widget.userListConfiguration.searchKeyword,
        theme: widget.theme,
        style: ListBaseStyle(
            background: widget.style.gradient == null
                ? widget.style.background
                : Colors.transparent,
            titleStyle: widget.style.titleStyle,
            gradient: widget.style.gradient),
        container: CometChatUserList(
          dataItemConfiguration:
              widget.userListConfiguration.dataItemConfiguration ??
                  const DataItemConfiguration<User>(),
          theme: widget.theme,
          style: ListStyle(
            background: widget.style.gradient == null
                ? widget.style.background
                : Colors.transparent,
          ),
          activeUser: widget.activeUser,
          stateCallBack: userListStateCallBack,
          searchKeyword: widget.userListConfiguration.searchKeyword,
          limit: widget.userListConfiguration.limit,
          customView: widget.userListConfiguration.customView,
          emptyText: widget.userListConfiguration.emptyText,
          errorText: widget.userListConfiguration.errorText,
          friendsOnly: widget.userListConfiguration.friendsOnly,
          hideBlockedUsers: widget.userListConfiguration.hideBlockedUsers,
          hideError: widget.userListConfiguration.hideError,
          roles: widget.userListConfiguration.roles,
          tags: widget.userListConfiguration.tags,
          uids: widget.userListConfiguration.uids,
          status: widget.userListConfiguration.status,
        ));
  }
}

class UsersStyle {
  const UsersStyle(
      {this.width,
      this.height,
      this.background,
      this.border,
      this.cornerRadius,
      this.titleStyle,
      this.gradient});

  ///[width] width
  final double? width;

  ///[height] height
  final double? height;

  ///[background] background color
  final Color? background;

  ///[border] border
  final BoxBorder? border;

  ///[cornerRadius] corner radius for list
  final double? cornerRadius;

  ///[titleStyle] TextStyle for title
  final TextStyle? titleStyle;

  ///[gradient]
  final Gradient? gradient;
}
