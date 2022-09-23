import 'package:flutter/material.dart';
import '../../../../flutter_chat_ui_kit.dart';
import '../utils/section_separator.dart';
import '../utils/utils.dart';

/// Gives Users List
///
///   ```dart
///      CometChatUserList(
///          limit: 30,
///          customView: CustomView(),
///          emptyText: 'No Users',
///         errorText: 'Something went wrong',
///          friendsOnly: false,
///          hideBlockedUsers: false,
///          hideError: false,
///          roles: [],
///          tags: [],
///          uids: [],
///          status: CometChatUserStatus.online,
///          style: ListStyle(
///             background: Colors.white,
///              error: TextStyle(),
///              empty: TextStyle(),
///              loadingIconTint: Colors.blue,
///              gradient: LinearGradient(colors: [])),
///          stateCallBack: (CometChatUserListState userListState) {},
///          searchKeyword: 'search keywords',
///          dataItemConfiguration: DataItemConfiguration(),
///        )
///```
///
///

class CometChatUserList extends StatefulWidget {
  const CometChatUserList(
      {Key? key,
      this.limit = 30,
      this.theme,
      this.style = const ListStyle(),
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
      this.dataItemConfiguration = const DataItemConfiguration<User>(),
      this.stateCallBack})
      : super(key: key);

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

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[style] user list style
  final ListStyle style;

  ///[dataItemConfiguration] data item configuration
  final DataItemConfiguration<User> dataItemConfiguration;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatUserListState)? stateCallBack;

  @override
  CometChatUserListState createState() => CometChatUserListState();
}

class CometChatUserListState extends State<CometChatUserList>
    with UserListener {
  List<User> _usersList = [];
  bool _isLoading = true;
  bool _hasMoreItems = true;
  bool _showCustomError = false;
  late UsersRequest usersRequest;
  CometChatTheme _theme = cometChatTheme;
  final String _uiUserListenerId = "cometchat_groups_group_listener";

  @override
  void initState() {
    _theme = widget.theme ?? cometChatTheme;
    buildRequest(searchKeyword: widget.searchKeyword);
    CometChat.addUserListener(_uiUserListenerId, this);
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }
    super.initState();
  }

  @override
  void dispose() {
    CometChat.removeUserListener(_uiUserListenerId);
    super.dispose();
  }

  buildRequest({String? searchKeyword}) {
    _hasMoreItems = true;
    _usersList = [];
    setState(() {});

    usersRequest = (UsersRequestBuilder()
          ..limit = widget.limit
          ..friendsOnly = widget.friendsOnly
          ..hideBlockedUsers = widget.hideBlockedUsers
          ..roles = widget.roles
          ..tags = widget.tags
          ..withTags = true // widget.tags.isNotEmpty
          ..uids = widget.uids
          ..userStatus = widget.status
          ..searchKeyword = searchKeyword)
        .build();
    _loadMore();
  }

  void _loadMore() {
    _isLoading = true;

    try {
      usersRequest.fetchNext(onSuccess: (List<User> fetchedList) {
        if (!mounted) return;
        if (fetchedList.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasMoreItems = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _usersList.addAll(fetchedList);
          });
        }
      }, onError: (CometChatException e) {
        debugPrint('$e');
        CometChatUserEvents.onError(e);
        // if (widget.onErrorCallBack != null) {
        //   widget.onErrorCallBack!(e);
        // } else
        if (widget.hideError == false && widget.customView.error != null) {
          _showCustomError = true;
          setState(() {});
        } else if (widget.hideError == false) {
          String _error = Utils.getErrorTranslatedText(context, e.code);
          _showErrorDialog(_error);
        }
      });
    } catch (e) {
      // if (widget.onErrorCallBack != null) {
      //   widget.onErrorCallBack!(e);
      // } else
      if (widget.hideError == false && widget.customView.error != null) {
        _showCustomError = true;
        setState(() {});
      } else if (widget.hideError == false) {
        _showErrorDialog(
            widget.errorText ?? Translations.of(context).cant_load_chats);
      }
    }
  }

  int _getMatchingIndex(User user) {
    int matchingIndex =
        _usersList.indexWhere((element) => element.uid == user.uid);
    return matchingIndex;
  }

  ///updating user
  updateUser(User user) {
    int matchingIndex = _getMatchingIndex(user);
    if (matchingIndex != -1) {
      _usersList[matchingIndex] = user;
      setState(() {});
    }
  }

  @override
  void onUserOffline(User user) {
    updateUser(user);
  }

  @override
  void onUserOnline(User user) {
    updateUser(user);
  }

  _showErrorDialog(String errorText) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          widget.errorText ?? errorText,
          style: TextStyle(
              fontSize: _theme.typography.title2.fontSize,
              fontWeight: _theme.typography.title2.fontWeight,
              color: _theme.palette.getAccent(),
              fontFamily: _theme.typography.title2.fontFamily),
        ),
        confirmButtonText: Translations.of(context).try_again,
        cancelButtonText: Translations.of(context).cancel_capital,
        style: ConfirmDialogStyle(
            backgroundColor:
                widget.style.background ?? _theme.palette.getBackground(),
            shadowColor: _theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: _theme.typography.text2.fontSize,
                fontWeight: _theme.typography.text2.fontWeight,
                color: _theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: _theme.typography.text2.fontSize,
                fontWeight: _theme.typography.text2.fontWeight,
                color: _theme.palette.getPrimary())),
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onConfirm: () {
          Navigator.pop(context);
          _loadMore();
        });
  }

  Widget _getUserItem(User user) {
    return GestureDetector(
      onLongPress: () {
        CometChatUserEvents.onUserLongPress(user);
      },
      onTap: () {
        CometChatUserEvents.onUserTap(user);
      },
      child: CometChatDataItem(
        isActive: false,
        user: user,
        inputData:
            widget.dataItemConfiguration.inputData ?? const InputData<User>(),
        avatarConfiguration: widget.dataItemConfiguration.avatarConfiguration ??
            const AvatarConfiguration(),
        statusIndicatorConfiguration:
            widget.dataItemConfiguration.statusIndicatorConfiguration ??
                const StatusIndicatorConfiguration(height: 12, width: 12),
        options: widget.dataItemConfiguration.options,
        theme: widget.theme,
        style: DataItemStyle(
          height: 56,
          background: widget.style.background,
        ),
      ),
    );
  }

  Widget _getLoadingIndicator() {
    return widget.customView.loading ??
        Center(
          child: widget.customView.loading ??
              Image.asset(
                "assets/icons/spinner.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent600(),
              ),
        );
  }

  Widget _getNoUserIndicator() {
    return widget.customView.empty ??
        Center(
          child: Text(
            widget.emptyText ?? Translations.of(context).no_users_found,
            style: widget.style.empty ??
                TextStyle(
                    fontSize: _theme.typography.title1.fontSize,
                    fontWeight: _theme.typography.title1.fontWeight,
                    color: _theme.palette.getAccent400()),
          ),
        );
  }

  Widget _getUserListDivider(int index) {
    if (index == 0 ||
        _usersList[index].name.substring(0, 1) !=
            _usersList[index - 1].name.substring(0, 1)) {
      return SectionSeparator(
        text: _usersList[index].name.substring(0, 1),
        dividerColor: _theme.palette.getAccent100(),
        textStyle: TextStyle(
            color: _theme.palette.getAccent500(),
            fontSize: _theme.typography.text2.fontSize,
            fontWeight: _theme.typography.text2.fontWeight),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget _getBody() {
    if (_showCustomError) {
      //-----------custom error widget-----------
      return widget.customView.error!;
    } else if (_isLoading) {
      //-----------loading widget -----------
      return _getLoadingIndicator();
    } else if (_usersList.isEmpty) {
      //----------- empty list widget-----------
      return _getNoUserIndicator();
    } else {
      return ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        itemCount: _hasMoreItems ? _usersList.length + 1 : _usersList.length,
        itemBuilder: (BuildContext context, int index) {
          if (index >= _usersList.length) {
            _loadMore();
            return _getLoadingIndicator();
          }

          return Column(
            children: [
              _getUserListDivider(index),
              _getUserItem(_usersList[index]),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: widget.style.background ?? _theme.palette.getBackground(),
          gradient: widget.style.gradient,
          borderRadius: BorderRadius.all(
              Radius.circular(widget.style.cornerRadius ?? 7.0)),
          border: widget.style.border),
      child: _getBody(),
    );
  }
}
