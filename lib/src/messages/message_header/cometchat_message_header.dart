import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:cometchat/models/action.dart' as action;

/// [CometChatMessageHeader] component displays the name of the user / group, the number of members for a group.
/// By default, we display the name and the typing indicator below.
///
/// ```dart
/// CometChatMessageHeader(
///         user:'user id',
///         enableTypingIndicator: true,
///         showBackButton: true,
///         backButton: Icon(Icons.arrow_back_rounded),
///         style: MessageHeaderStyle(
///           background: Colors.white,
///           gradient: LinearGradient(colors: []),
///           height: 56,
///           border: Border.all(color: Colors.red),
///           cornerRadius: 8
///         ),
///       )
///
///
/// ```
class CometChatMessageHeader extends StatefulWidget
    implements PreferredSizeWidget {
  ///creates a widget that gives message header
  const CometChatMessageHeader(
      {Key? key,
      this.style = const MessageHeaderStyle(),
      this.user,
      this.group,
      this.showBackButton = true,
      this.backButton,
      this.enableTypingIndicator = true,
      this.theme,
      this.avatarConfiguration,
      this.statusIndicatorConfiguration})
      : super(key: key);

  ///[user] user object if conversation with is User
  final String? user;

  ///[group] group object if conversation with is Group
  final String? group;

  ///[showBackButton] if true it shows back button
  final bool showBackButton;

  ///[backButton] custom back button widget
  final Widget? backButton;

  ///[enableTypingIndicator] if true then enables is typing indicator
  final bool enableTypingIndicator;

  ///[style] message header style object
  final MessageHeaderStyle style;

  ///[theme] can pass custom theme class or dark theme as defaultDarkTheme object from CometChatTheme class,  default  is light theme
  final CometChatTheme? theme;

  ///[avatarConfigurations]  set configuration property for [CometChatAvatar] used inside [CometChatMessageHeader]
  final AvatarConfiguration? avatarConfiguration;

  ///[statusIndicatorConfiguration] set configuration property for [CometChatStatusIndicator] used inside [CometChatMessageHeader]
  final StatusIndicatorConfiguration? statusIndicatorConfiguration;

  @override
  State<CometChatMessageHeader> createState() => _CometChatMessageHeaderState();

  @override
  Size get preferredSize => Size.fromHeight(style.height ?? 65);
}

class _CometChatMessageHeaderState extends State<CometChatMessageHeader>
    with MessageListener, UserListener, GroupListener {
  User? userObject;
  Group? groupObject;
  bool isTyping = false;
  User? typingUser;

  final String messageListenerId = "cometchat_message_header_message_listener";
  final String groupListenerId = "cometchat_message_header_group_listener";
  final String userListenerId = "cometchat_message_header_user_listener";

  @override
  void initState() {
    super.initState();

    if (widget.enableTypingIndicator) {
      CometChat.addMessageListener(messageListenerId, this);
    }
    CometChat.addUserListener(groupListenerId, this);
    CometChat.addGroupListener(userListenerId, this);
    if (widget.user != null) {
      CometChat.getUser(widget.user!, onSuccess: (User fetchedUser) {
        userObject = fetchedUser;
        if (mounted) setState(() {});
      }, onError: (CometChatException e) {});
    } else if (widget.group != null) {
      CometChat.getGroup(widget.group!, onSuccess: (Group fetchedGroup) {
        groupObject = fetchedGroup;
        if (mounted) setState(() {});
      }, onError: (CometChatException e) {});
    }
  }

  @override
  void dispose() {
    CometChat.removeMessageListener(messageListenerId);
    CometChat.removeUserListener(userListenerId);
    CometChat.removeGroupListener(groupListenerId);

    super.dispose();
  }

  @override
  void onUserOnline(User user) {
    if (userObject != null && user.uid == userObject!.uid) {
      userObject!.status = UserStatusConstants.online;
      if (mounted) setState(() {});
    }
  }

  @override
  void onUserOffline(User user) {
    if (userObject != null && user.uid == userObject!.uid) {
      userObject!.status = UserStatusConstants.offline;
      if (mounted) setState(() {});
    }
  }

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    if (userObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == userObject!.uid) {
      isTyping = true;
      typingUser = typingIndicator.sender;
      if (mounted) setState(() {});
    } else if (groupObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == groupObject!.guid) {
      isTyping = true;
      typingUser = typingIndicator.sender;
      if (mounted) setState(() {});
    }
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    if (userObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == userObject!.uid) {
      isTyping = false;
      typingUser = null;
      if (mounted) setState(() {});
    } else if (groupObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == groupObject!.guid) {
      isTyping = false;
      typingUser = typingIndicator.sender;
      if (mounted) setState(() {});
    }
  }

  incrementMemberCount(Group _group) {
    if (groupObject != null && groupObject!.guid == _group.guid) {
      groupObject!.membersCount++;
      if (mounted) setState(() {});
    }
  }

  decrementMemberCount(Group _group) {
    if (groupObject != null && groupObject!.guid == _group.guid) {
      groupObject!.membersCount--;
      if (mounted) setState(() {});
    }
  }

  @override
  void onGroupMemberJoined(
      action.Action action, User joinedUser, Group joinedGroup) {
    incrementMemberCount(joinedGroup);
  }

  @override
  void onGroupMemberLeft(action.Action action, User leftUser, Group leftGroup) {
    decrementMemberCount(leftGroup);
  }

  @override
  void onGroupMemberKicked(
      action.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    decrementMemberCount(kickedFrom);
  }

  @override
  void onGroupMemberBanned(
      action.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    decrementMemberCount(bannedFrom);
  }

  @override
  void onGroupMemberUnbanned(action.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {}

  @override
  void onMemberAddedToGroup(
      action.Action action, User addedby, User userAdded, Group addedTo) {
    incrementMemberCount(addedTo);
  }

  Widget getListItem(CometChatTheme _theme) {
    if (userObject != null) {
      return CometChatDataItem(
        theme: widget.theme,
        style: DataItemStyle(
          background: Colors.transparent,
          height: widget.style.height,
          subtitleStyle: TextStyle(
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight,
              color: isTyping ||
                      (userObject != null &&
                          userObject!.status == UserStatusConstants.online)
                  ? _theme.palette.getPrimary()
                  : _theme.palette.getAccent600()),
        ),
        avatarConfiguration: widget.avatarConfiguration ??
            const AvatarConfiguration(width: 32, height: 32),
        statusIndicatorConfiguration: widget.statusIndicatorConfiguration ??
            const StatusIndicatorConfiguration(width: 10, height: 10),
        inputData: InputData<User>(
            thumbnail: true,
            status: true,
            title: true,
            subtitle: (User? user) {
              return isTyping
                  ? Translations.of(context).is_typing
                  : user?.status ?? '';
            }),
        user: userObject,
      );
    } else if (groupObject != null) {
      return CometChatDataItem(
        theme: widget.theme,
        style: DataItemStyle(
          background: Colors.transparent,
          height: widget.style.height,
          subtitleStyle: TextStyle(
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight,
              color: isTyping ||
                      (userObject != null &&
                          userObject!.status == UserStatusConstants.online)
                  ? _theme.palette.getPrimary()
                  : _theme.palette.getAccent600()),
        ),
        avatarConfiguration: const AvatarConfiguration(width: 32, height: 32),
        inputData: InputData<Group>(
            thumbnail: true,
            status: true,
            title: true,
            subtitle: (Group? group) {
              return isTyping
                  ? '${typingUser?.name ?? ''} ${Translations.of(context).is_typing}'
                  : '${group?.membersCount ?? 0} ${Translations.of(context).members}';
            }),
        group: groupObject,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getBackButton(BuildContext context, CometChatTheme _theme) {
    if (widget.showBackButton) {
      return Padding(
        padding: const EdgeInsets.only(left: 20.0),
        child: widget.backButton ??
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Image.asset(
                "assets/icons/back.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent(),
              ),
            ),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    return Container(
      height: widget.style.height ?? 65,
      width: widget.style.width ?? MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
          color: widget.style.background ?? _theme.palette.getBackground(),
          border: widget.style.border,
          gradient: widget.style.gradient,
          borderRadius: BorderRadius.circular(widget.style.cornerRadius ?? 0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          getBackButton(context, _theme),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 16),
            child: getListItem(_theme),
          ))
        ],
      ),
    );
  }
}

class MessageHeaderStyle {
  ///message header style components
  const MessageHeaderStyle(
      {this.height,
      this.width,
      this.border,
      this.cornerRadius,
      this.background,
      this.gradient});

  ///[height] height of header
  final double? height;

  ///[width] width of header
  final double? width;

  ///[border] border of header
  final BoxBorder? border;

  ///[cornerRadius] corner radius of header
  final double? cornerRadius;

  ///[background] background color of header
  final Color? background;

  final Gradient? gradient;
}
