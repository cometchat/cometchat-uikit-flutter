import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

///[CometChatConversations] is a component that shows all conversations involving the logged in user with the help of [CometChatListBase] and [CometChatListItem]
///By default, for each conversation that will be listed, the name of the user or group the logged in user is having conversation with will be displayed in the title of every list item,
///the subtitle will contain the last message in that conversation along with its receipt status, the leading view will contain the avatars of the user and groups and
///status indicator will indicate if users are online and icons for indicating a private or password protected group,
///and the trailing view will contain the time of the last message in that conversation and the number of unread messages.
///
///fetched conversations are listed down according to the order of recent activity
///conversations are fetched using [ConversationsBuilderProtocol] and [ConversationsRequestBuilder]
///
/// ```dart
///   CometChatConversations(
///    avatarStyle: AvatarStyle(),
///    dateStyle: DateStyle(),
///    badgeStyle: BadgeStyle(),
///    conversationsStyle: ConversationsStyle(),
///    receiptStyle: ReceiptStyle(),
///    listItemStyle: ListItemStyle(),
///    statusIndicatorStyle: StatusIndicatorStyle(),
///    deleteConversationDialogStyle: ConfirmDialogStyle(),
///  );
/// ```
class CometChatConversations extends StatelessWidget {
  CometChatConversations(
      {Key? key,
      this.conversationsProtocol,
      this.subtitleView,
      this.listItemView,
      this.conversationsStyle = const ConversationsStyle(),
      this.controller,
      this.theme,
      this.backButton,
      this.showBackButton = true,
      this.selectionMode,
      this.onSelection,
      this.title,
      this.errorStateText,
      this.emptyStateText,
      this.stateCallBack,
      this.conversationsRequestBuilder,
      this.hideError,
      this.loadingStateText,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.tailView,
      this.options,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.badgeStyle,
      this.receiptStyle,
      this.appBarOptions,
      this.hideSeparator = false,
      this.disableUsersPresence = false,
      this.disableReceipt = false,
      this.protectedGroupIcon,
      this.privateGroupIcon,
      this.readIcon,
      this.deliveredIcon,
      this.sentIcon,
      this.activateSelection,
      this.datePattern,
      String? customSoundForMessages,
      bool? disableSoundForMessages = false,
      this.typingIndicatorText,
      this.dateStyle,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      bool? disableTyping,
      ConfirmDialogStyle? deleteConversationDialogStyle,
      OnError? onError,
        this.hideAppbar = false,
      })
      : conversationsController = CometChatConversationsController(
            conversationsBuilderProtocol: conversationsProtocol ??
                UIConversationsBuilder(
                  conversationsRequestBuilder ?? ConversationsRequestBuilder(),
                ),
            mode: selectionMode,
            theme: theme ?? cometChatTheme,
            disableSoundForMessages: disableSoundForMessages,
            customSoundForMessages: customSoundForMessages,
            disableUsersPresence: disableUsersPresence,
            disableReceipt: disableReceipt,
            disableTyping: disableTyping,
            deleteConversationDialogStyle: deleteConversationDialogStyle,
            onError: onError),
        super(key: key);

  ///property to be set internally by using passed parameters [conversationsProtocol] ,[selectionMode] ,[options]
  ///these are passed to the [CometChatConversationsController] which is responsible for the business logic
  final CometChatConversationsController conversationsController;

  ///[conversationsProtocol] set custom conversations request builder protocol
  final ConversationsBuilderProtocol? conversationsProtocol;

  ///[conversationsRequestBuilder] set custom conversations request builder
  final ConversationsRequestBuilder? conversationsRequestBuilder;

  ///[subtitleView] to set subtitle for each conversation
  final Widget? Function(BuildContext, Conversation)? subtitleView;

  ///[tailView] to set tailView for each conversation
  final Widget? Function(Conversation)? tailView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each conversation
  final Widget Function(Conversation)? listItemView;

  ///[conversationsStyle] sets style
  final ConversationsStyle conversationsStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options] custom options to show on sliding a conversation item
  final List<CometChatOption>? Function(
      Conversation,
      CometChatConversationsController controller,
      BuildContext context)? options;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode conversations module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<Conversation>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateText] returns view fow loading state
  final WidgetBuilder? loadingStateText;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatConversationsController object
  final Function(CometChatConversationsController controller)? stateCallBack;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[badgeStyle] used to customize the unread messages count indicator
  final BadgeStyle? badgeStyle;

  ///[receiptStyle] sets the style for the receipts shown in the subtitle
  final ReceiptStyle? receiptStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[disableUsersPresence] controls visibility of status indicator shown if a user is online
  final bool? disableUsersPresence;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

  ///[protectedGroupIcon] provides icon in status indicator for protected group
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] provides icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[readIcon] provides icon in read receipts if a message is read
  final Widget? readIcon;

  ///[deliveredIcon] provides icon in read receipts if a message is delivered
  final Widget? deliveredIcon;

  ///[sentIcon] provides icon in read receipts if a message is sent
  final Widget? sentIcon;

  ///[activateSelection] lets the widget know if conversations are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[datePattern] is used to generate customDateString for CometChatDate
  final String Function(Conversation conversation)? datePattern;

  ///[typingIndicatorText] if not null is visible instead of default text shown when another user is typing
  final String? typingIndicatorText;

  ///[dateStyle] provides styling for CometChatDate
  final DateStyle? dateStyle;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a conversation item
  final Function(Conversation)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a conversation item
  final Function(Conversation)? onItemLongPress;

  ///[hideAppbar] toggle visibility for app bar
  final bool? hideAppbar;

  final RxBool _isSelectionOn = false.obs;

  Widget getDefaultItem(
      Conversation conversation,
      CometChatConversationsController controller,
      CometChatTheme theme,
      BuildContext context) {
    Widget? subtitle;
    Widget? tail;
    Color? backgroundColor;
    Widget? icon;

    if (subtitleView != null) {
      subtitle = subtitleView!(context, conversation);
    } else {
      subtitle = getDefaultSubtitle(theme,
          context: context,
          conversation: conversation,
          showTypingIndicator: controller.typingIndicatorMap
              .contains(conversation.conversationId),
          hideThreadIndicator: controller.getHideThreadIndicator(conversation),
          controller: controller);
    }
    if (tailView != null) {
      tail = tailView!(conversation);
    } else {
      tail = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: getTime(theme, conversation)),
          Flexible(child: getUnreadCount(theme, conversation)),
        ],
      );
    }

    User? conversationWithUser;
    Group? conversationWithGroup;
    if (conversation.conversationWith is User) {
      conversationWithUser = conversation.conversationWith as User;
    } else {
      conversationWithGroup = conversation.conversationWith as Group;
    }

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
            isSelected:
                controller.selectionMap[conversation.conversationId] != null,
            theme: theme,
            user: conversationWithUser,
            group: conversationWithGroup,
            onlineStatusIndicatorColor: conversationsStyle.onlineStatusColor ??
                theme.palette.getSuccess(),
            privateGroupIcon: privateGroupIcon,
            protectedGroupIcon: protectedGroupIcon,
            privateGroupIconBackground:
                conversationsStyle.privateGroupIconBackground,
            protectedGroupIconBackground:
                conversationsStyle.protectedGroupIconBackground,
            disableUsersPresence: disableUsersPresence);

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null ||
                    selectionMode == SelectionMode.none)) {
          controller.onTap(conversation);
          if (controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (onItemTap != null) {
          onItemTap!(conversation);
          controller.activeConversation = conversation.conversationId;
        }
      },
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          controller.onTap(conversation);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(conversation);

          controller.activeConversation = conversation.conversationId;
        }
      },
      child: CometChatListItem(
        id: conversation.conversationId,
        avatarName: conversationWithUser?.name ?? conversationWithGroup?.name,
        avatarURL: conversationWithUser?.avatar ?? conversationWithGroup?.icon,
        title: conversationWithUser?.name ?? conversationWithGroup?.name,
        key: UniqueKey(),
        subtitleView: subtitle,
        tailView: tail,
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: backgroundColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: theme,
        hideSeparator: hideSeparator,
        style: ListItemStyle(
            background: listItemStyle?.background ?? Colors.transparent,
            titleStyle: listItemStyle?.titleStyle ??
                TextStyle(
                    fontSize: theme.typography.name.fontSize,
                    fontWeight: theme.typography.name.fontWeight,
                    fontFamily: theme.typography.name.fontFamily,
                    color: theme.palette.getAccent()),
            height: listItemStyle?.height ?? 72,
            border: listItemStyle?.border,
            borderRadius: listItemStyle?.borderRadius,
            gradient: listItemStyle?.gradient,
            separatorColor: listItemStyle?.separatorColor,
            width: listItemStyle?.width,
            margin: listItemStyle?.margin,
          padding: listItemStyle?.padding,
        ),
        options: options != null
            ? options!(conversation, controller, context)
            : ConversationUtils.getDefaultOptions(
                conversation, controller, context, theme),
      ),
    );
  }

  Widget getListItem(
      Conversation conversation,
      CometChatConversationsController controller,
      CometChatTheme theme,
      BuildContext context) {
    if (listItemView != null) {
      return listItemView!(conversation);
    } else {
      return getDefaultItem(conversation, controller, theme, context);
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme theme) {
    if (loadingStateText != null) {
      return Center(child: loadingStateText!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: conversationsStyle.loadingIconTint ??
              theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoConversationIndicator(
      BuildContext context, CometChatTheme theme) {
    if (emptyStateView != null) {
      return Center(child: emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          emptyStateText ?? cc.Translations.of(context).no_chats_found,
          style: conversationsStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title1.fontSize,
                  fontWeight: theme.typography.title1.fontWeight,
                  color: theme.palette.getAccent400()),
        ),
      );
    }
  }

  _showErrorDialog(String errorText, BuildContext context, CometChatTheme theme,
      CometChatConversationsController controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorStateText ?? errorText,
          style: conversationsStyle.errorTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
        ),
        confirmButtonText: cc.Translations.of(context).try_again,
        cancelButtonText: cc.Translations.of(context).cancel_capital,
        style: ConfirmDialogStyle(
            backgroundColor: theme.palette.mode == PaletteThemeModes.light
                ? theme.palette.getBackground()
                : Color.alphaBlend(theme.palette.getAccent200(),
                    theme.palette.getBackground()),
            shadowColor: theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary())),
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onConfirm: () {
          Navigator.pop(context);
          controller.loadMoreElements();
        });
  }

  _showError(CometChatConversationsController controller, BuildContext context,
      CometChatTheme theme) {
    if (hideError == true) return;
    String error;
    if (controller.error != null && controller.error is CometChatException) {
      error = Utils.getErrorTranslatedText(
          context, (controller.error as CometChatException).code);
    } else {
      error = cc.Translations.of(context).no_chats_found;
    }
    if (errorStateView != null) {}
    _showErrorDialog(error, context, theme, controller);
  }

  Widget _getList(CometChatConversationsController _controller,
      BuildContext context, CometChatTheme _theme) {
    return GetBuilder(
      init: _controller,
      global: false,
      dispose: (GetBuilderState<CometChatConversationsController> state) =>
          state.controller?.onClose(),
      builder: (CometChatConversationsController value) {
        value.context = context;
        if (value.hasError == true) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showError(value, context, _theme));

          if (errorStateView != null) {
            return errorStateView!(context);
          }

          return _getLoadingIndicator(context, _theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, _theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          return _getNoConversationIndicator(context, _theme);
        } else {
          return ListView.builder(
            controller: controller,
            itemCount:
                value.hasMoreItems ? value.list.length + 1 : value.list.length,
            itemBuilder: (context, index) {
              if (index >= value.list.length) {
                value.loadMoreElements();
                return _getLoadingIndicator(context, _theme);
              }

              return Column(
                children: [
                  getListItem(value.list[index], value, _theme, context),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget getSelectionWidget(
      CometChatConversationsController conversationsController,
      CometChatTheme theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<Conversation>? conversations =
                conversationsController.getSelectedList();
            if (onSelection != null) {
              onSelection!(conversations);
            }
          },
          icon: Image.asset(AssetConstants.checkmark,
              package: UIConstants.packageName,
              color: theme.palette.getPrimary()));
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    if (stateCallBack != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => stateCallBack!(conversationsController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).chats,
        hideSearch: true,
        hideAppBar: hideAppbar,
        backIcon: backButton,
        showBackButton: showBackButton,
        onBack: onBack,
        theme: theme,
        menuOptions: [
          if (appBarOptions != null && appBarOptions!.isNotEmpty)
            ...appBarOptions!,
          Obx(
            () => getSelectionWidget(conversationsController, _theme),
          )
        ],
        style: ListBaseStyle(
            background: conversationsStyle.gradient == null
                ? conversationsStyle.background
                : Colors.transparent,
            titleStyle: conversationsStyle.titleStyle,
            gradient: conversationsStyle.gradient,
            height: conversationsStyle.height,
            width: conversationsStyle.width,
            backIconTint: conversationsStyle.backIconTint,
            border: conversationsStyle.border,
            borderRadius: conversationsStyle.borderRadius),
        container: _getList(conversationsController, context, _theme));
  }

//----------- default subtitle
  Widget getDefaultSubtitle(CometChatTheme theme,
      {required BuildContext context,
      required Conversation conversation,
      required bool showTypingIndicator,
      bool? hideThreadIndicator = true,
      String? threadIndicatorText,
      required CometChatConversationsController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hideThreadIndicator != null && hideThreadIndicator == false)
          Text(
            cc.Translations.of(context).in_a_thread,
            style: conversationsStyle.threadIndicatorStyle ??
                TextStyle(
                    color: theme.palette.getPrimary(),
                    fontWeight: theme.typography.subtitle1.fontWeight,
                    fontSize: theme.typography.subtitle1.fontSize,
                    fontFamily: theme.typography.subtitle1.fontFamily),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            getReceiptIcon(theme,
                conversation: conversation,
                hideReceipt:
                    controller.getHideReceipt(conversation, disableReceipt)),
            if (showTypingIndicator)
              Text(
                typingIndicatorText ?? cc.Translations.of(context).is_typing,
                style: conversationsStyle.typingIndicatorStyle ??
                    TextStyle(
                        color: theme.palette.getPrimary(),
                        fontWeight: theme.typography.subtitle1.fontWeight,
                        fontSize: theme.typography.subtitle1.fontSize,
                        fontFamily: theme.typography.subtitle1.fontFamily),
              )
            else
              Expanded(
                  child: getSubtitle(theme, context, conversation, controller))
          ],
        ),
      ],
    );
  }

  Widget getReceiptIcon(CometChatTheme theme,
      {required Conversation conversation, bool? hideReceipt}) {
    if (hideReceipt ?? false) {
      return const SizedBox();
    } else if (conversation.lastMessage != null &&
        conversation.lastMessage?.sender != null &&
        conversation.lastMessage!.deletedAt == null &&
        conversation.lastMessage!.type != "groupMember") {
      ReceiptStatus status =
          MessageReceiptUtils.getReceiptStatus(conversation.lastMessage!);

      return Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: CometChatReceipt(
          status: status,
          deliveredIcon: deliveredIcon ??
              Image.asset(
                AssetConstants.messageReceived,
                package: UIConstants.packageName,
                color: receiptStyle?.deliveredIconTint ??
                    theme.palette.getAccent(),
              ),
          readIcon: readIcon ??
              Image.asset(
                AssetConstants.messageReceived,
                package: UIConstants.packageName,
                color: receiptStyle?.readIconTint ?? theme.palette.getPrimary(),
              ),
          sentIcon: sentIcon ??
              Image.asset(
                AssetConstants.messageSent,
                package: UIConstants.packageName,
                color: receiptStyle?.sentIconTint ?? theme.palette.getAccent(),
              ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getSubtitle(CometChatTheme theme, BuildContext context,
      Conversation conversation, CometChatConversationsController controller) {
    TextStyle subtitleStyle = conversationsStyle.lastMessageStyle ??
        TextStyle(
            color: theme.palette.getAccent600(),
            fontSize: theme.typography.subtitle1.fontSize,
            fontWeight: theme.typography.subtitle1.fontWeight,
            fontFamily: theme.typography.subtitle1.fontFamily);

    String? text;

    text = controller.getLastMessage(conversation, context);

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: subtitleStyle,
    );
  }

//----------- last message update time and unread message count -----------
  Widget getTime(CometChatTheme theme, Conversation conversation) {
    DateTime? lastMessageTime =
        conversation.lastMessage?.updatedAt ?? conversation.lastMessage?.sentAt;
    if (lastMessageTime == null) return const SizedBox();

    String? customDateString;

    if (datePattern != null) {
      customDateString = datePattern!(conversation);
    }

    return CometChatDate(
      date: lastMessageTime,
      style: DateStyle(
          background: dateStyle?.background ?? theme.palette.getBackground(),
          textStyle: dateStyle?.textStyle ??
              TextStyle(
                  color: theme.palette.getAccent500(),
                  fontSize: theme.typography.subtitle1.fontSize,
                  fontWeight: theme.typography.subtitle1.fontWeight,
                  fontFamily: theme.typography.subtitle1.fontFamily),
          border: dateStyle?.border ??
              Border.all(color: theme.palette.getBackground(), width: 0),
          borderRadius: dateStyle?.borderRadius,
          contentPadding: dateStyle?.contentPadding,
          gradient: dateStyle?.gradient,
          height: dateStyle?.height,
          isTransparentBackground: dateStyle?.isTransparentBackground,
          width: dateStyle?.width),
      customDateString: customDateString,
      pattern: DateTimePattern.dayDateTimeFormat,
    );
  }

  Widget getUnreadCount(CometChatTheme theme, Conversation conversation) {
    return CometChatBadge(
      count: conversation.unreadMessageCount ?? 0,
      style: BadgeStyle(
        width: badgeStyle?.width ?? 25,
        height: badgeStyle?.height ?? 25,
        borderRadius: badgeStyle?.borderRadius ?? 100,
        textStyle: TextStyle(
                fontSize: theme.typography.subtitle1.fontSize,
                color: theme.palette.getAccent())
            .merge(badgeStyle?.textStyle),
        background: badgeStyle?.background ?? theme.palette.getPrimary(),
      ),
    );
  }
}
