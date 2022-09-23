import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import '../utils/debouncer.dart';

/// A container component that wraps and formats the [CometChatListBase]
/// and [CometChatGroupList] component, with no behavior of its own.
///
///```dart
/// CometChatGroups(
///       hideCreateGroup: false,
///       showBackButton: true,
///       backButton: Icon(Icons.arrow_back_rounded),
///       title: 'Groups',
///       hideSearch: false,
///       searchPlaceholder: 'Search',
///       style: GroupsStyle(
///         background: Colors.white,
///         gradient: LinearGradient(colors: []),
///         titleStyle: TextStyle()
///       ),
///       searchIcon: Container(),
///       createGroupIcon: Container(),
///       groupListConfiguration: GroupListConfiguration(),
///     );
///```
class CometChatGroups extends StatefulWidget {
  const CometChatGroups(
      {Key? key,
      this.title,
      this.style = const GroupsStyle(),
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchIcon,
      this.hideSearch = false,
      this.hideCreateGroup = false,
      this.createGroupIcon,
      this.activeGroup,
      this.theme,
      this.groupListConfiguration = const GroupListConfiguration()})
      : super(key: key);

  ///[title] Title of the component
  final String? title;

  ///[style] consists of all styling properties
  final GroupsStyle style;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button widget
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[searchIcon] replace search icon
  final Widget? searchIcon;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[hideCreateGroup] switch on/off option to create group
  final bool hideCreateGroup;

  ///[createGroupIcon] replace create group icon
  final Widget? createGroupIcon;

  ///[activeGroup] selected group
  final String? activeGroup;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[groupListConfiguration] alters [CometChatGroups] configuration properties
  final GroupListConfiguration groupListConfiguration;

  @override
  State<CometChatGroups> createState() => _CometChatGroupsState();
}

class _CometChatGroupsState extends State<CometChatGroups>
    with CometChatGroupEventListener {
  CometChatTheme _theme = cometChatTheme;
  final String _uiGroupListenerId = "cometchat_groups_group_listener";
  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    CometChatGroupEvents.addGroupsListener(_uiGroupListenerId, this);
  }

  @override
  void dispose() {
    super.dispose();
    CometChatGroupEvents.removeGroupsListener(_uiGroupListenerId);
  }

  CometChatGroupListState? groupListState;

  groupListStateCallBack(CometChatGroupListState _groupListState) {
    groupListState = _groupListState;
  }

  @override
  void onCreateGroupIconClick() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatCreateGroup(
                  style: CreateGroupStyle(
                      titleStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _theme.palette.getAccent()),
                      activeColor: _theme.palette.getPrimary(),
                      selectedLabelStyle: TextStyle(
                        color: _theme.palette.getBackground(),
                        fontSize: _theme.typography.text1.fontSize,
                        fontFamily: _theme.typography.text1.fontFamily,
                        fontWeight: _theme.typography.text1.fontWeight,
                      ),
                      unSelectedLabelStyle: TextStyle(
                        color: _theme.palette.getAccent600(),
                        fontSize: _theme.typography.text1.fontSize,
                        fontFamily: _theme.typography.text1.fontFamily,
                        fontWeight: _theme.typography.text1.fontWeight,
                      ),
                      hintTextStyle: TextStyle(
                        color: _theme.palette.getAccent600(),
                        fontSize: _theme.typography.body.fontSize,
                        fontFamily: _theme.typography.body.fontFamily,
                        fontWeight: _theme.typography.body.fontWeight,
                      ),
                      backButtonIconColor: _theme.palette.getPrimary(),
                      createIconColor: _theme.palette.getPrimary(),
                      inputTextStyle: TextStyle(
                        color: _theme.palette.getAccent(),
                        fontSize: _theme.typography.body.fontSize,
                        fontFamily: _theme.typography.body.fontFamily,
                        fontWeight: _theme.typography.body.fontWeight,
                      ),
                      inActiveColor: _theme.palette.getAccent100(),
                      background: _theme.palette.getBackground(),
                      borderColor: _theme.palette.getAccent100()),
                )));
  }

  @override
  void onGroupCreate(Group group) {
    groupListState?.insert(group);
  }

  @override
  void onGroupMemberJoin(User joinedUser, Group joinedGroup) {
    groupListState?.updateGroup(joinedGroup);
  }

  final _debouncer = Debouncer(milliseconds: 500);

  onSearch(String val) {
    _debouncer.run(() {
      groupListState?.buildRequest(searchKeyword: val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CometChatListBase(
        title: widget.title ?? Translations.of(context).groups,
        hideSearch: widget.hideSearch,
        backIcon: widget.backButton,
        placeholder: widget.searchPlaceholder,
        showBackButton: widget.showBackButton,
        searchBoxIcon: widget.searchIcon,
        onSearch: onSearch,
        theme: widget.theme,
        searchText: widget.groupListConfiguration.searchKeyword,
        menuOptions: [
          if (widget.hideCreateGroup == false)
            IconButton(
              onPressed: () {
                CometChatGroupEvents.onCreateGroupIconClick();
              },
              icon: widget.createGroupIcon ??
                  Image.asset(
                    "assets/icons/write.png",
                    package: UIConstants.packageName,
                    color: _theme.palette.getPrimary(),
                  ),
            )
        ],
        container: CometChatGroupList(
            theme: widget.theme,
            dataItemConfiguration:
                widget.groupListConfiguration.dataItemConfiguration ??
                    const DataItemConfiguration<Group>(),
            stateCallBack: groupListStateCallBack,
            joinedOnly: widget.groupListConfiguration.joinedOnly,
            searchKeyword: widget.groupListConfiguration.searchKeyword,
            limit: widget.groupListConfiguration.limit,
            customView: widget.groupListConfiguration.customView,
            activeGroup: widget.activeGroup,
            emptyText: widget.groupListConfiguration.emptyText,
            errorText: widget.groupListConfiguration.errorText,
            hideError: widget.groupListConfiguration.hideError,
            tags: widget.groupListConfiguration.tags));
  }
}

class GroupsStyle {
  const GroupsStyle(
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
