import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/src/cometchat_ui/tab_item.dart';
import 'package:cometchat_chat_uikit/src/cometchat_ui/ui_style.dart';

enum TabAlignment { top, bottom }

enum Visibility { onTap, always }

class CometChatUI extends StatefulWidget {
  const CometChatUI(
      {super.key,
      this.tabAlignment,
      this.tabSeparatorColor,
      this.style,
      this.conversationsWithMessagesConfiguration =
          const ConversationsWithMessagesConfiguration(),
      this.usersWithMessagesConfiguration =
          const UsersWithMessagesConfiguration(),
      this.groupsWithMessagesConfiguration =
          const GroupsWithMessagesConfiguration(),
      this.showTitle,
      this.tabs,
      this.theme});

  ///[tabAlignment] sets the alignment of the tab navigation bar. By default it is set to bottom
  final TabAlignment? tabAlignment;

  ///[tabSeparatorColor] sets custom color for the divider separating the tab menu items
  final Color? tabSeparatorColor;

  ///[style] used to override default style of the widget
  final UIStyle? style;

  ///[conversationsWithMessagesConfiguration] used to customize  CometChatConversationsWithMessages being used internally
  final ConversationsWithMessagesConfiguration?
      conversationsWithMessagesConfiguration;

  ///[usersWithMessagesConfiguration] used to customize  CometChatUsersWithMessages being used internally
  final UsersWithMessagesConfiguration usersWithMessagesConfiguration;

  ///[groupsWithMessagesConfiguration] used to customize  CometChatGroupsWithMessages being used internally
  final GroupsWithMessagesConfiguration groupsWithMessagesConfiguration;

  ///[showTitle] controls visibility of title, which can be onTap or always
  final Visibility? showTitle;

  ///[tabs] used to override the default tab list
  final List<TabItem>? tabs;

  ///[theme] used to set custom theme for CometChatUI
  final CometChatTheme? theme;

  @override
  State<CometChatUI> createState() => _CometChatUIState();
}

class _CometChatUIState extends State<CometChatUI> {
  List<TabItem> _tabList = [];
  TabAlignment _tabAlignment = TabAlignment.bottom;
  late CometChatTheme _theme;

  @override
  void initState() {
    super.initState();

    _theme = widget.theme ?? cometChatTheme;

    _tabAlignment = widget.tabAlignment ?? TabAlignment.bottom;
  }

  @override
  void didChangeDependencies() {
    if (widget.tabs == null || widget.tabs!.isEmpty) {
      _tabList = _getDefaultTabList();
    } else {
      _tabList = widget.tabs!;
    }

    super.didChangeDependencies();
  }

  List<TabItem> _getDefaultTabList() {
    return [
      _getConversationWithMessagesTab(),
      _getUserWithMessagesTab(),
      _getGroupWithMessagesTab(),
    ];
  }

  TabItem _getUserWithMessagesTab() {
    return TabItem(
        id: UITabNameConstants.userWithMessages,
        title: Translations.of(context).users,
        icon: Icon(
          Icons.account_circle_outlined,
          color: widget.tabAlignment == TabAlignment.top
              ? (widget.style?.iconTint ?? _theme.palette.getAccent500())
              : null,
        ),
        childView: _getUserWithMessages());
  }

  TabItem _getGroupWithMessagesTab() {
    return TabItem(
        id: UITabNameConstants.groupWithMessages,
        title: Translations.of(context).groups,
        icon: Icon(
          Icons.supervisor_account_rounded,
          color: widget.tabAlignment == TabAlignment.top
              ? (widget.style?.iconTint ?? _theme.palette.getAccent500())
              : null,
        ),
        childView: _getGroupsWithMessage());
  }

  TabItem _getConversationWithMessagesTab() {
    return TabItem(
        id: UITabNameConstants.conversationWithMessages,
        title: Translations.of(context).chats,
        icon: Icon(
          Icons.message,
          color: widget.tabAlignment == TabAlignment.top
              ? (widget.style?.iconTint ?? _theme.palette.getAccent500())
              : null,
        ),
        childView: _getConversationWithMessages());
  }

  _getUserWithMessages() {
    return CometChatUsersWithMessages(
      messageConfiguration:
          widget.usersWithMessagesConfiguration.messageConfiguration,
      usersConfiguration:
          widget.usersWithMessagesConfiguration.usersConfiguration,
    );
  }

  _getConversationWithMessages() {
    return CometChatConversationsWithMessages(
      messageConfiguration:
          widget.conversationsWithMessagesConfiguration?.messageConfiguration ??
              const MessageConfiguration(),
      conversationsConfiguration: widget.conversationsWithMessagesConfiguration
              ?.conversationConfigurations ??
          const ConversationsConfiguration(),
      theme: widget.conversationsWithMessagesConfiguration?.theme ?? _theme,
    );
  }

  _getGroupsWithMessage() {
    return CometChatGroupsWithMessages(
      messageConfiguration:
          widget.groupsWithMessagesConfiguration.messageConfiguration ??
              const MessageConfiguration(),
      groupsConfiguration:
          widget.groupsWithMessagesConfiguration.groupsConfiguration ??
              const GroupsConfiguration(),
      theme: widget.groupsWithMessagesConfiguration.theme ?? _theme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: widget.style?.border,
          gradient: widget.style?.gradient,
          color:
              widget.style?.gradient == null ? widget.style?.background : null),
      child: _tabAlignment == TabAlignment.bottom
          ? BottomBar(
              tabItems: _tabList,
              style: widget.style,
              theme: _theme,
              tabSeparatorColor: widget.tabSeparatorColor,
            )
          : TopTab(
              tabItems: _tabList,
              style: widget.style,
              theme: _theme,
              tabSeparatorColor: widget.tabSeparatorColor,
            ),
    );
  }
}

class BottomBar extends StatefulWidget {
  const BottomBar(
      {super.key,
      required this.tabItems,
      this.style,
      this.theme,
      this.tabSeparatorColor});
  final List<TabItem> tabItems;
  final UIStyle? style;
  final CometChatTheme? theme;
  final Color? tabSeparatorColor;

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _selectedIndex = 0;
  final List _widgetOptions = [];
  final List<BottomNavigationBarItem> _bottomItemList = [];
  late CometChatTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    for (var element in widget.tabItems) {
      _widgetOptions.add(element.childView);
      _bottomItemList.add(
        BottomNavigationBarItem(
          icon: Container(
              decoration: widget.tabSeparatorColor == null
                  ? null
                  : BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: widget.tabSeparatorColor!,
                              width: 1,
                              style: BorderStyle.solid))),
              child: Center(child: element.icon)),
          label: element.title,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:
            widget.style?.barBackgroundColor ?? _theme.palette.getBackground(),
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        unselectedIconTheme: IconThemeData(
            color: widget.style?.iconTint ?? _theme.palette.getAccent500()),
        selectedIconTheme: IconThemeData(
            color:
                widget.style?.activeIconColor ?? _theme.palette.getPrimary()),
        selectedLabelStyle: widget.style?.activeTitleStyle ??
            TextStyle(
                color: _theme.palette.getPrimary(),
                fontWeight: _theme.typography.caption1.fontWeight,
                fontFamily: _theme.typography.caption1.fontFamily,
                fontSize: _theme.typography.caption1.fontSize),
        items: _bottomItemList,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class TopTab extends StatefulWidget {
  const TopTab(
      {super.key,
      required this.tabItems,
      this.style,
      this.theme,
      this.tabSeparatorColor});
  final List<TabItem> tabItems;
  final UIStyle? style;
  final CometChatTheme? theme;
  final Color? tabSeparatorColor;

  @override
  State<TopTab> createState() => _TopTabState();
}

class _TopTabState extends State<TopTab> {
  final List<Widget> _nativeTabs = [];
  final List<Widget> _tabBodyList = [];
  late CometChatTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
  }

  @override
  void didChangeDependencies() {
    for (var element in widget.tabItems) {
      _nativeTabs.add(Container(
        decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: widget.tabSeparatorColor ?? Colors.transparent,
                    width: 1,
                    style: BorderStyle.solid))),
        height: 50 + MediaQuery.of(context).padding.bottom,
        padding: const EdgeInsets.all(0),
        width: double.infinity,
        child: Tab(
          icon: element.icon,
          text: element.title,
        ),
      ));
      _tabBodyList.add(element.childView);
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _nativeTabs.length,
      child: Scaffold(
        backgroundColor:
            widget.style?.barBackgroundColor ?? _theme.palette.getBackground(),
        appBar: TabBar(
          labelColor:
              widget.style?.activeIconColor ?? _theme.palette.getAccent500(),
          indicatorColor:
              widget.style?.activeIconColor ?? _theme.palette.getAccent500(),
          tabs: _nativeTabs,
          padding: EdgeInsets.zero,
          indicatorPadding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          labelStyle: widget.style?.activeTitleStyle ??
              TextStyle(
                  color: _theme.palette.getPrimary(),
                  fontWeight: _theme.typography.caption1.fontWeight,
                  fontFamily: _theme.typography.caption1.fontFamily,
                  fontSize: _theme.typography.caption1.fontSize),
          unselectedLabelStyle:
              const TextStyle(color: Colors.transparent, fontSize: 1),
          unselectedLabelColor: Colors.transparent,
        ),
        body: TabBarView(
          children: _tabBodyList,
        ),
      ),
    );
  }
}
