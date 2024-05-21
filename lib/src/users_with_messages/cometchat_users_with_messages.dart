import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

///[CometChatUsersWithMessages] is a component that uses [CometChatUsers] to display a list of users and allows to access the [CometChatMessages] component for each user
///
/// it list down users according to different parameter set in order of recent activity and opens message by default on click
///
/// ```dart
///       CometChatUsersWithMessages(
///           user: User(
///               uid: 'superhero2',
///               name: 'Captain America',
///               avatar:
///                   'https://data-us.cometchat.io/assets/images/avatars/captainamerica.png',
///               ),
///               usersConfiguration: UsersConfiguration(
///               usersProtocol: UsersBuilderProtocol()
///               usersRequestBuilder: UsersRequestBuilder(),
///               usersStyle: UsersStyle(),
///               listItemStyle: ListItemStyle()),
///           messageConfiguration: MessageConfiguration(
///               messageHeaderConfiguration:
///                   MessageHeaderConfiguration(),
///               messageListConfiguration:
///                   MessageListConfiguration(),
///               messageComposerConfiguration:
///                   MessageComposerConfiguration(),
///               detailsConfiguration:
///                   DetailsConfiguration(),
///               messagesStyle: MessagesStyle()),
///           theme: CometChatTheme(
///               palette: Palette(),
///               typography: Typography()),
///         )
///
/// ```

class CometChatUsersWithMessages extends StatefulWidget {
  const CometChatUsersWithMessages(
      {super.key,
      this.theme,
      this.usersConfiguration = const UsersConfiguration(),
      this.messageConfiguration = const MessageConfiguration(),
      this.user});

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[usersConfiguration] CometChatUsers configurations
  final UsersConfiguration? usersConfiguration;

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[user] if null will return [CometChatUsers] screen else will navigate to [CometChatMessages]
  final User? user;

  @override
  State<CometChatUsersWithMessages> createState() =>
      _CometChatUsersWithMessagesState();
}

class _CometChatUsersWithMessagesState
    extends State<CometChatUsersWithMessages> {
  late CometChatUsersWithMessagesController
      _cometChatUsersWithMessagesController;

  @override
  void initState() {
    super.initState();
    _cometChatUsersWithMessagesController =
        CometChatUsersWithMessagesController(
            messageConfiguration: widget.messageConfiguration,
            theme: widget.theme);
    if (widget.user != null && widget.user?.hasBlockedMe == false) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _cometChatUsersWithMessagesController.navigateToMessagesScreen(
            user: widget.user, context: context);
      });
    }
  }

  @override
  void dispose() {
    _cometChatUsersWithMessagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: _cometChatUsersWithMessagesController,
        tag: _cometChatUsersWithMessagesController.tag,
        key: ValueKey(_cometChatUsersWithMessagesController.tag),
        builder:
            (CometChatUsersWithMessagesController usersWithMessagesController) {
          usersWithMessagesController.context = context;

          return CometChatUsers(
            usersRequestBuilder: widget.usersConfiguration?.usersRequestBuilder,
            title: widget.usersConfiguration?.title,
            theme: widget.usersConfiguration?.theme ?? widget.theme,
            showBackButton: widget.usersConfiguration?.showBackButton ?? true,
            hideSearch: widget.usersConfiguration?.hideSearch ?? false,
            searchPlaceholder: widget.usersConfiguration?.searchPlaceholder,
            activateSelection: widget.usersConfiguration?.activateSelection,
            appBarOptions: widget.usersConfiguration?.appBarOptions,
            controller: widget.usersConfiguration?.controller,
            hideError: widget.usersConfiguration?.hideError,
            stateCallBack: widget.usersConfiguration?.stateCallBack,
            usersProtocol: widget.usersConfiguration?.usersProtocol,
            backButton: widget.usersConfiguration?.backButton,
            disableUsersPresence:
                widget.usersConfiguration?.disableUsersPresence,
            emptyStateText: widget.usersConfiguration?.emptyStateText,
            emptyStateView: widget.usersConfiguration?.emptyStateView,
            errorStateText: widget.usersConfiguration?.errorStateText,
            errorStateView: widget.usersConfiguration?.errorStateView,
            hideSectionSeparator:
                widget.usersConfiguration?.hideSectionSeparator,
            hideSeparator: widget.usersConfiguration?.hideSeparator,
            loadingStateView: widget.usersConfiguration?.loadingStateView,
            onSelection: widget.usersConfiguration?.onSelection,
            options: widget.usersConfiguration?.options,
            searchBoxIcon: widget.usersConfiguration?.searchBoxIcon,
            selectionMode: widget.usersConfiguration?.selectionMode,
            subtitleView: widget.usersConfiguration?.subtitleView,
            statusIndicatorStyle:
                widget.usersConfiguration?.statusIndicatorStyle,
            listItemView: widget.usersConfiguration?.listItemView,
            listItemStyle: widget.usersConfiguration?.listItemStyle,
            avatarStyle: widget.usersConfiguration?.avatarStyle,
            usersStyle:
                widget.usersConfiguration?.usersStyle ?? const UsersStyle(),
            onItemTap: widget.usersConfiguration?.onItemTap ??
                usersWithMessagesController.onItemTap,
            onItemLongPress: widget.usersConfiguration?.onItemLongPress,
            onBack: widget.usersConfiguration?.onBack,
            onError: widget.usersConfiguration?.onError,
            selectionIcon: widget.usersConfiguration?.selectionIcon,
            submitIcon: widget.usersConfiguration?.submitIcon,
            hideAppbar: widget.usersConfiguration?.hideAppbar,
          );
        });
  }
}
