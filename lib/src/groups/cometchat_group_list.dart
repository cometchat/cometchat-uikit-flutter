import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/utils/loading_indicator.dart';
import '../../../../flutter_chat_ui_kit.dart';
import '../utils/utils.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as kit;

///[CometChatGroupList] component renders a scrollable list of
///groups that has been created in   CometChat app
///
///```dart
/// CometChatGroupList(
///      limit: 30,
///      joinedOnly: false,
///      tags: ['abc'],
///      hideError: false,
///      searchKeyword: '',
///      errorText: 'Something went wrong',
///      emptyText: 'No Groups',
///      style: ListStyle(
///          error: TextStyle(),
///          empty: TextStyle(),
///          loadingIconTint: Colors.black,
///          background: Colors.white,
///          gradient: LinearGradient(colors: [])),
///      customView: CustomView(
///          loading: Center(child: CircularProgressIndicator()),
///          empty: Center(
///            child: Text('No Groups'),
///          ),
///          error: Center(
///            child: Text('Something went wrong'),
///          )),
///      dataItemConfiguration: DataItemConfiguration(
///          avatarConfiguration: AvatarConfiguration(),
///          statusIndicatorConfiguration:
///              StatusIndicatorConfiguration(),
///          inputData: InputData(
///              status: true,
///              thumbnail: true,
///              title: true,
///              subtitle: (Group group) {
///                return group.membersCount.toString();
///              })),
///    );
///```
class CometChatGroupList extends StatefulWidget {
  const CometChatGroupList(
      {Key? key,
      this.limit = 30,
      this.theme,
      this.style = const ListStyle(),
      this.searchKeyword,
      this.tags = const [],
      this.emptyText,
      this.errorText,
      this.customView = const CustomView(),
      this.hideError = false,
      this.joinedOnly = false,
      this.activeGroup,
      this.dataItemConfiguration = const DataItemConfiguration<Group>(),
      this.stateCallBack})
      : super(key: key);

  ///[limit] number of groups that should be fetched in a single iteration
  final int limit;

  ///[searchKeyword] fetch users based on the search string
  final String? searchKeyword;

  ///[tags] list of tags based on which the list of groups is to be fetched
  final List<String> tags;

  ///[emptyText]text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when the list has encountered any error
  final String? errorText;

  ///[customView] custom widgets for loading,error,empty
  ///allows you to embed a custom view/component for loading, empty and error state.
  ///If no value is set, default view will be rendered.
  ///CustomView(
  ///   loading: Center(child: CircularProgressIndicator()),
  ///   empty: Center(
  ///     child: Text('No Groups'),
  ///   ),
  ///   error: Center(
  ///     child: Text('Something went wrong'),
  ///   )),
  final CustomView customView;

  ///[hideError] text to be displayed when the list has encountered any error
  final bool hideError;

  ///[joinedOnly] return the groups that the logged-in user has joined or is a part of
  final bool joinedOnly;

  ///[activeGroup] selected group
  final String? activeGroup;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[style] consists of all styling properties
  final ListStyle style;

  ///[dataItemConfiguration] data item configuration
  ///DataItemConfiguration(
  ///   avatarConfiguration: AvatarConfiguration(),
  ///   statusIndicatorConfiguration:
  ///       StatusIndicatorConfiguration(),
  ///   inputData: InputData(
  ///       status: true,
  ///       thumbnail: true,
  ///       title: true,
  ///       subtitle: (Group group) {
  ///         return group.membersCount.toString();
  ///       }))
  ///
  final DataItemConfiguration<Group> dataItemConfiguration;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatGroupListState)? stateCallBack;

  @override
  CometChatGroupListState createState() => CometChatGroupListState();
}

class CometChatGroupListState extends State<CometChatGroupList>
    with GroupListener {
  List<Group> _groupList = [];
  bool _isLoading = true;
  bool _hasMoreItems = true;
  bool _showCustomError = false;
  late GroupsRequest groupsRequest;
  CometChatTheme theme = cometChatTheme;
  final String _groupListenerId = "cometchat_group_list_group_listener";

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    buildRequest(searchKeyword: widget.searchKeyword);
    CometChat.addGroupListener(_groupListenerId, this);
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }
    super.initState();
  }

  @override
  void dispose() {
    CometChat.removeGroupListener(_groupListenerId);
    super.dispose();
  }

  @override
  onGroupMemberKicked(
      kit.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    updateGroup(kickedFrom);
  }

  @override
  onGroupMemberJoined(kit.Action action, User joinedUser, Group joinedGroup) {
    updateGroup(joinedGroup);
  }

  @override
  onGroupMemberLeft(kit.Action action, User leftUser, Group leftGroup) {
    updateGroup(leftGroup);
  }

  @override
  onGroupMemberBanned(
      kit.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    updateGroup(bannedFrom);
  }

  @override
  onGroupMemberScopeChanged(kit.Action action, User updatedBy, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    //updateGroup(kickedFrom);
  }

  @override
  onMemberAddedToGroup(
      kit.Action action, User addedby, User userAdded, Group addedTo) {
    updateGroup(addedTo);
  }

  buildRequest({String? searchKeyword}) {
    _hasMoreItems = true;
    _groupList = [];
    setState(() {});

    groupsRequest = (GroupsRequestBuilder()
          ..limit = widget.limit
          ..tags = widget.tags
          ..searchKeyword = searchKeyword
          ..joinedOnly = widget.joinedOnly
          ..withTags = widget.tags.isEmpty ? false : true)
        .build();
    _loadMore();
  }

  void _loadMore() {
    _isLoading = true;

    try {
      groupsRequest.fetchNext(onSuccess: (List<Group> fetchedList) {
        if (fetchedList.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasMoreItems = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _groupList.addAll(fetchedList);
          });
        }
      }, onError: (CometChatException e) {
        debugPrint('$e');
        // if (widget.onErrorCallBack != null) {
        //   widget.onErrorCallBack!(e);
        // } else

        CometChatGroupEvents.onGroupError(e);
        if (widget.hideError == false && widget.customView.error != null) {
          _showCustomError = true;
          setState(() {});
        } else if (widget.hideError == false) {
          String _error =
              widget.errorText ?? Utils.getErrorTranslatedText(context, e.code);
          showCometChatConfirmDialog(
            context: context,
            messageText: Text(
              _error,
              style: TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
            ),
            confirmButtonText: Translations.of(context).try_again,
            cancelButtonText: Translations.of(context).cancel_capital,
            onCancel: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            onConfirm: () {
              Navigator.pop(context);
              _loadMore();
            },
            style: ConfirmDialogStyle(
                backgroundColor:
                    widget.style.background ?? theme.palette.getBackground(),
                shadowColor: theme.palette.getAccent300(),
                confirmButtonTextStyle: TextStyle(
                    fontSize: theme.typography.text2.fontSize,
                    fontWeight: theme.typography.text2.fontWeight,
                    color: theme.palette.getPrimary()),
                cancelButtonTextStyle: TextStyle(
                    fontSize: theme.typography.text2.fontSize,
                    fontWeight: theme.typography.text2.fontWeight,
                    color: theme.palette.getPrimary())),
          );
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
        showCometChatConfirmDialog(
          context: context,
          messageText: Text(
            widget.errorText ?? Translations.of(context).cant_load_chats,
            style: TextStyle(
                fontSize: theme.typography.title2.fontSize,
                fontWeight: theme.typography.title2.fontWeight,
                color: theme.palette.getAccent(),
                fontFamily: theme.typography.title2.fontFamily),
          ),
          cancelButtonText: Translations.of(context).cancel_capital,
          confirmButtonText: Translations.of(context).try_again,
          onCancel: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          onConfirm: () {
            Navigator.pop(context);
            _loadMore();
          },
          style: ConfirmDialogStyle(
              backgroundColor:
                  widget.style.background ?? theme.palette.getBackground(),
              shadowColor: theme.palette.getAccent300(),
              confirmButtonTextStyle: TextStyle(
                  fontSize: theme.typography.text2.fontSize,
                  fontWeight: theme.typography.text2.fontWeight,
                  color: theme.palette.getPrimary()),
              cancelButtonTextStyle: TextStyle(
                  fontSize: theme.typography.text2.fontSize,
                  fontWeight: theme.typography.text2.fontWeight,
                  color: theme.palette.getPrimary())),
        );
      }
    }
  }

  int getMatchingIndex(Group group) {
    int matchingIndex =
        _groupList.indexWhere((element) => element.guid == group.guid);
    return matchingIndex;
  }

  updateGroup(Group group) {
    int matchingIndex = getMatchingIndex(group);
    if (matchingIndex != -1) {
      //Todo: currently it is a temporary fix, fix this in next release
      if (group.hasJoined == false) {
        group.hasJoined = _groupList[matchingIndex].hasJoined;
      }

      _groupList[matchingIndex] = group;
      if (mounted) {
        setState(() {});
      }
    }
  }

  add(Group group) {
    _groupList.add(group);
    setState(() {});
  }

  insert(Group group, {int at = 0}) {
    _groupList.insert(at, group);
    setState(() {});
  }

  remove(Group group) {
    int matchingIndex = getMatchingIndex(group);
    if (matchingIndex != -1) {
      _groupList.removeAt(matchingIndex);
      setState(() {});
    }
  }

  _joinGroup(
      {required String guid, required String groupType, String password = ""}) {
    showLoadingIndicatorDialog(context,
        background: theme.palette.getBackground(),
        progressIndicatorColor: theme.palette.getPrimary(),
        shadowColor: theme.palette.getAccent300());

    CometChat.joinGroup(guid, groupType, password: password,
        onSuccess: (Group group) async {
      User? user = await CometChat.getLoggedInUser();
      debugPrint("Group Joined Successfully : $group ");
      Navigator.pop(context); //pop loading dialog

      //ToDo: remove after sdk issue solve
      group.hasJoined = true;

      CometChatGroupEvents.onGroupMemberJoin(user!, group);
    }, onError: (CometChatException e) {
      Navigator.pop(context); //pop loading dialog

      showCometChatConfirmDialog(
          context: context,
          style: ConfirmDialogStyle(
              backgroundColor:
                  widget.style.background ?? theme.palette.getBackground(),
              shadowColor: theme.palette.getAccent300(),
              confirmButtonTextStyle: TextStyle(
                  fontSize: theme.typography.text2.fontSize,
                  fontWeight: theme.typography.text2.fontWeight,
                  color: theme.palette.getPrimary())),
          title: Text(Translations.of(context).something_went_wrong_error,
              style: TextStyle(
                  fontSize: theme.typography.name.fontSize,
                  fontWeight: theme.typography.name.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.name.fontFamily)),
          confirmButtonText: Translations.of(context).okay,
          onConfirm: () {
            Navigator.pop(context); //pop confirm dialog
          });

      debugPrint("Group Joining failed with exception: ${e.message}");
      CometChatGroupEvents.onGroupError(e);
    });
  }

  Widget _getGroupItem(Group group, int index) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: GestureDetector(
        onLongPress: () {
          CometChatGroupEvents.onGroupLongPress(group, index);
        },
        onTap: () {
          CometChatGroupEvents.onGroupTap(group, index);
          if (!group.hasJoined) {
            if (group.type == GroupTypeConstants.public) {
              _joinGroup(guid: group.guid, groupType: group.type);
            } else if (group.type == GroupTypeConstants.password) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CometChatJoinProtectedGroup(
                            group: group,
                            theme: widget.theme,
                          )));
            }
          }
        },
        child: CometChatDataItem(
          isActive: false,
          group: group,
          inputData: widget.dataItemConfiguration.inputData ??
              InputData<Group>(subtitle: (Group group) {
                return "${group.membersCount} ${Translations.of(context).members}";
              }),
          avatarConfiguration:
              widget.dataItemConfiguration.avatarConfiguration ??
                  const AvatarConfiguration(),
          statusIndicatorConfiguration:
              widget.dataItemConfiguration.statusIndicatorConfiguration ??
                  const StatusIndicatorConfiguration(),
          options: widget.dataItemConfiguration.options,
          theme: widget.theme,
          style: const DataItemStyle(height: 72),
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
                color: theme.palette.getAccent600(),
              ),
        );
  }

  Widget _getNoGroupIndicator() {
    return widget.customView.empty ??
        Center(
          child: Text(
            widget.emptyText ?? Translations.of(context).no_groups_found,
            style: widget.style.empty ??
                TextStyle(
                    fontSize: theme.typography.title1.fontSize,
                    fontWeight: theme.typography.title1.fontWeight,
                    color: theme.palette.getAccent400()),
          ),
        );
  }

  Widget _getDivider() {
    return Divider(
      indent: 72,
      height: 1,
      thickness: 1,
      color: theme.palette.getAccent100(),
    );
  }

  Widget _getBody() {
    if (_showCustomError) {
      //-----------custom error widget-----------

      return widget.customView.error!;
    } else if (_isLoading) {
      //-----------loading widget -----------
      return _getLoadingIndicator();
    } else if (_groupList.isEmpty) {
      //----------- empty list widget-----------
      return _getNoGroupIndicator();
    } else {
      return ListView.builder(
        itemCount: _hasMoreItems ? _groupList.length + 1 : _groupList.length,
        itemBuilder: (BuildContext context, int index) {
          if (index >= _groupList.length) {
            _loadMore();
            return _getLoadingIndicator();
          }

          return Column(
            children: [_getGroupItem(_groupList[index], index), _getDivider()],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: widget.style.background ?? theme.palette.getBackground(),
          gradient: widget.style.gradient,
          borderRadius: BorderRadius.all(
              Radius.circular(widget.style.cornerRadius ?? 7.0)),
          border: widget.style.border),
      child: _getBody(),
    );
  }
}
