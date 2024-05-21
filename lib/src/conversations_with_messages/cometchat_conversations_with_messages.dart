import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import '../../cometchat_chat_uikit.dart';

///[CometChatConversationsWithMessages] is a component that is composed of [CometChatConversations] and [CometChatMessages] component
///
/// it is a wrapper component which provides functionality to open the [CometChatMessages] module with a click of any conversation shown in the list of conversations.
///
/// ```dart
///     CometChatConversationsWithMessages(
///       user: User(
///           uid: 'superhero2',
///           name: 'Captain America',
///           avatar:
///               'https://data-us.cometchat.io/assets/images/avatars/captainamerica.png',
///           ),
///       group: Group(
///         guid: 'guid',
///         name: 'group name',
///         type: 'group type'
///       ),
///       conversationsConfiguration: ConversationsConfiguration(
///           conversationsRequestBuilder: ConversationsRequestBuilder(),
///           conversationsStyle: ConversationsStyle(),
///           listItemStyle: ListItemStyle()),
///       messageConfiguration: MessageConfiguration(
///           messageHeaderConfiguration:
///               MessageHeaderConfiguration(),
///           messageListConfiguration:
///               MessageListConfiguration(),
///           messageComposerConfiguration:
///               MessageComposerConfiguration(),
///           detailsConfiguration:
///               DetailsConfiguration(),
///           messagesStyle: MessagesStyle()),
///       theme: CometChatTheme(
///           palette: Palette(),
///           typography: Typography()),
///     )
/// ```
///
class CometChatConversationsWithMessages extends StatefulWidget {
  const CometChatConversationsWithMessages({
    super.key,
    this.user,
    this.group,
    this.theme,
    this.conversationsConfiguration,
    this.messageConfiguration,
    this.startConversationConfiguration,
  });

  ///[user] if null will return [CometChatConversations] screen else will navigate to [CometChatMessages]
  final User? user;

  ///[group] if null will return [CometChatConversations] screen else will navigate to [CometChatMessages]
  final Group? group;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[conversationsConfiguration] CometChatConversation configurations
  final ConversationsConfiguration? conversationsConfiguration;

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[startConversationConfiguration] CometChatMessage start conversation configuration
  final ContactsConfiguration? startConversationConfiguration;

  @override
  State<CometChatConversationsWithMessages> createState() =>
      _CometChatConversationsWithMessagesState();
}

class _CometChatConversationsWithMessagesState
    extends State<CometChatConversationsWithMessages> {
  late CometChatConversationsWithMessagesController
      _cometChatConversationsWithMessagesController;
  late CometChatTheme _theme;

  //initialization methods
  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    _cometChatConversationsWithMessagesController =
        CometChatConversationsWithMessagesController(
      theme: _theme,
      messageConfiguration: widget.messageConfiguration,
      startConversationConfiguration: widget.startConversationConfiguration,
    );
    if (widget.user != null || widget.group != null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _cometChatConversationsWithMessagesController.navigateToMessagesScreen(
            user: widget.user, group: widget.group, context: context);
      });
    }
  }

  @override
  void dispose() {
    _cometChatConversationsWithMessagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: _cometChatConversationsWithMessagesController,
        global: false,
        dispose: (GetBuilderState<CometChatConversationsWithMessagesController>
                state) =>
            state.controller?.onClose(),
        builder: (CometChatConversationsWithMessagesController
            conversationsWithMessagesController) {
          conversationsWithMessagesController.context = context;
          return CometChatConversations(
            conversationsProtocol:
                widget.conversationsConfiguration?.conversationsProtocol,
            conversationsRequestBuilder:
                widget.conversationsConfiguration?.conversationsRequestBuilder,
            activateSelection:
                widget.conversationsConfiguration?.activateSelection,
            appBarOptions: widget.conversationsConfiguration?.appBarOptions ??
                [
                  IconButton(
                    onPressed: () {
                      conversationsWithMessagesController
                          .navigateToStartConversation(context: context);
                    },
                    icon: Image.asset(
                      AssetConstants.write,
                      package: UIConstants.packageName,
                      color: _theme.palette.getPrimary(),
                    ),
                  ),
                ],
            controller: widget.conversationsConfiguration?.controller,
            hideError: widget.conversationsConfiguration?.hideError,
            stateCallBack: widget.conversationsConfiguration?.stateCallBack,
            showBackButton:
                widget.conversationsConfiguration?.showBackButton ?? true,
            theme: widget.conversationsConfiguration?.theme ?? _theme,
            title: widget.conversationsConfiguration?.title,
            subtitleView: widget.conversationsConfiguration?.subtitleView,
            backButton: widget.conversationsConfiguration?.backButton,
            avatarStyle: widget.conversationsConfiguration?.avatarStyle,
            customSoundForMessages:
                widget.conversationsConfiguration?.customSoundForMessages,
            disableSoundForMessages:
                widget.conversationsConfiguration?.disableSoundForMessages ??
                    false,
            disableReceipt: widget.conversationsConfiguration?.disableReceipt,
            disableUsersPresence:
                widget.conversationsConfiguration?.disableUsersPresence,
            datePattern: widget.conversationsConfiguration?.datePattern,
            dateStyle: widget.conversationsConfiguration?.dateStyle,
            deliveredIcon: widget.conversationsConfiguration?.deliveredIcon,
            emptyStateText: widget.conversationsConfiguration?.emptyStateText,
            emptyStateView: widget.conversationsConfiguration?.emptyStateView,
            errorStateText: widget.conversationsConfiguration?.errorStateText,
            errorStateView: widget.conversationsConfiguration?.errorStateView,
            hideSeparator: widget.conversationsConfiguration?.hideSeparator,
            listItemStyle: widget.conversationsConfiguration?.listItemStyle,
            listItemView: widget.conversationsConfiguration?.listItemView,
            loadingStateText:
                widget.conversationsConfiguration?.loadingStateText,
            onSelection: widget.conversationsConfiguration?.onSelection,
            options: widget.conversationsConfiguration?.options,
            privateGroupIcon:
                widget.conversationsConfiguration?.privateGroupIcon,
            protectedGroupIcon:
                widget.conversationsConfiguration?.protectedGroupIcon,
            readIcon: widget.conversationsConfiguration?.readIcon,
            selectionMode: widget.conversationsConfiguration?.selectionMode,
            sentIcon: widget.conversationsConfiguration?.sentIcon,
            statusIndicatorStyle:
                widget.conversationsConfiguration?.statusIndicatorStyle,
            badgeStyle: widget.conversationsConfiguration?.badgeStyle,
            receiptStyle: widget.conversationsConfiguration?.receiptStyle,
            tailView: widget.conversationsConfiguration?.tailView,
            typingIndicatorText:
                widget.conversationsConfiguration?.typingIndicatorText,
            conversationsStyle:
                widget.conversationsConfiguration?.conversationsStyle ??
                    const ConversationsStyle(),
            onBack: widget.conversationsConfiguration?.onBack,
            onError: widget.conversationsConfiguration?.onError,
            onItemTap: widget.conversationsConfiguration?.onItemTap ??
                conversationsWithMessagesController.onItemTap,
            onItemLongPress: widget.conversationsConfiguration?.onItemLongPress,
            disableTyping: widget.conversationsConfiguration?.disableTyping,
            deleteConversationDialogStyle: widget
                .conversationsConfiguration?.deleteConversationDialogStyle,
            hideAppbar: widget.conversationsConfiguration?.hideAppbar,
            disableMentions: widget.conversationsConfiguration?.disableMentions,
            textFormatters: widget.conversationsConfiguration?.textFormatters,
          );
        });
  }
}
