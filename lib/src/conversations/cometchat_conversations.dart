import 'package:flutter/material.dart';
// import 'package:flutter_chat_ui_kit/src/utils/section_separator.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import 'package:get/get.dart';

import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

///[CometChatConversations] is a  component that wraps the list  in [CometChatListBase] and format it with help of [CometChatListItem]
///
/// it list down conversations according to different parameter set in order of recent activity
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
      this.errorText,
      this.emptyText,
      this.stateCallBack,
      this.conversationsRequestBuilder,
      this.hideError,
      this.loadingView,
      this.emptyView,
      this.errorView,
      this.listItemStyle,
      this.tailView,
      this.options,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.badgeStyle,
      this.receiptStyle,
      this.hideHeader = false,
      this.hideSearch = true,
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
      OnError? onError})
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
      Conversation, CometChatConversationsController controller, BuildContext context)? options;

  ///[hideSearch] toggle visibility of search bar
  final bool hideSearch;

  ///[hideHeader] toggle visibility of header
  final bool hideHeader;

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

  ///[emptyText] text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when error occur
  final String? errorText;

  ///[loadingView] returns view fow loading state
  final WidgetBuilder? loadingView;

  ///[emptyView] returns view fow empty state
  final WidgetBuilder? emptyView;

  ///[errorView] returns view fow error state behind the dialog
  final WidgetBuilder? errorView;

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

  final RxBool _isSelectionOn = false.obs;

  Widget getDefaultItem(Conversation _conversation, CometChatConversationsController _controller,
      CometChatTheme _theme, BuildContext context) {
    Widget? _subtitle;
    Widget? _tail;
    Color? backgroundColor;
    Widget? icon;

    if (subtitleView != null) {
      _subtitle = subtitleView!(context, _conversation);
    } else {
      _subtitle = getDefaultSubtitle(_theme,
          context: context,
          conversation: _conversation,
          showTypingIndicator:
              _controller.typingIndicatorMap.contains(_conversation.conversationId),
          hideThreadIndicator: _controller.getHideThreadIndicator(_conversation),
          controller: _controller);
    }
    if (tailView != null) {
      _tail = tailView!(_conversation);
    } else {
      _tail = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: getTime(_theme, _conversation)),
          Flexible(child: getUnreadCount(_theme, _conversation)),
        ],
      );
    }

    User? conversationWithUser;
    Group? conversationWithGroup;
    if (_conversation.conversationWith is User) {
      conversationWithUser = _conversation.conversationWith as User;
    } else {
      conversationWithGroup = _conversation.conversationWith as Group;
    }

    StatusIndicatorUtils statusIndicatorUtils = StatusIndicatorUtils.getStatusIndicatorFromParams(
        isSelected: _controller.selectionMap[_conversation.conversationId] != null,
        theme: _theme,
        user: conversationWithUser,
        group: conversationWithGroup,
        onlineStatusIndicatorColor:
            conversationsStyle.onlineStatusColor ?? _theme.palette.getSuccess(),
        privateGroupIcon: privateGroupIcon,
        protectedGroupIcon: protectedGroupIcon,
        privateGroupIconBackground: conversationsStyle.privateGroupIconBackground,
        protectedGroupIconBackground: conversationsStyle.protectedGroupIconBackground,
        disableUsersPresence: disableUsersPresence);

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    _controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null || selectionMode == SelectionMode.none)) {
          _controller.onTap(_conversation);
          if (_controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              _controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (onItemTap != null) {
          onItemTap!(_conversation);
        }
      },
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            _controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          _controller.onTap(_conversation);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(_conversation);
        }
      },
      child: CometChatListItem(
        id: _conversation.conversationId,
        avatarName: conversationWithUser?.name ?? conversationWithGroup?.name,
        avatarURL: conversationWithUser?.avatar ?? conversationWithGroup?.icon,
        title: conversationWithUser?.name ?? conversationWithGroup?.name,
        key: UniqueKey(),
        subtitleView: _subtitle,
        tailView: _tail,
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: backgroundColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle: statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: _theme,
        hideSeparator: hideSeparator,
        style: ListItemStyle(
            background: listItemStyle?.background ?? Colors.transparent,
            titleStyle: listItemStyle?.titleStyle ??
                TextStyle(
                    fontSize: _theme.typography.name.fontSize,
                    fontWeight: _theme.typography.name.fontWeight,
                    fontFamily: _theme.typography.name.fontFamily,
                    color: _theme.palette.getAccent()),
            height: listItemStyle?.height ?? 72,
            border: listItemStyle?.border,
            borderRadius: listItemStyle?.borderRadius,
            gradient: listItemStyle?.gradient,
            separatorColor: listItemStyle?.separatorColor,
            width: listItemStyle?.width),
        options: options != null
            ? options!(_conversation, _controller, context)
            : ConversationUtils.getDefaultOptions(_conversation, _controller, context, theme),
      ),
    );
  }

  Widget getListItem(Conversation _conversation, CometChatConversationsController _controller,
      CometChatTheme _theme, BuildContext context) {
    if (listItemView != null) {
      return listItemView!(_conversation);
    } else {
      return getDefaultItem(_conversation, _controller, _theme, context);
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme _theme) {
    if (loadingView != null) {
      return Center(child: loadingView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: conversationsStyle.loadingIconTint ?? _theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoConversationIndicator(BuildContext context, CometChatTheme _theme) {
    if (emptyView != null) {
      return Center(child: emptyView!(context));
    } else {
      return Center(
        child: Text(
          emptyText ?? cc.Translations.of(context).no_chats_found,
          style: conversationsStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight,
                  color: _theme.palette.getAccent400()),
        ),
      );
    }
  }

  _showErrorDialog(String _errorText, BuildContext context, CometChatTheme _theme,
      CometChatConversationsController _controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorText ?? _errorText,
          style: conversationsStyle.errorTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title2.fontSize,
                  fontWeight: _theme.typography.title2.fontWeight,
                  color: _theme.palette.getAccent(),
                  fontFamily: _theme.typography.title2.fontFamily),
        ),
        confirmButtonText: cc.Translations.of(context).try_again,
        cancelButtonText: cc.Translations.of(context).cancel_capital,
        style: ConfirmDialogStyle(
            backgroundColor: _theme.palette.mode == PaletteThemeModes.light
                ? _theme.palette.getBackground()
                : Color.alphaBlend(_theme.palette.getAccent200(), _theme.palette.getBackground()),
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
          _controller.loadMoreElements();
        });
  }

  _showError(
      CometChatConversationsController _controller, BuildContext context, CometChatTheme _theme) {
    if (hideError == true) return;
    String _error;
    if (_controller.error != null && _controller.error is CometChatException) {
      _error =
          Utils.getErrorTranslatedText(context, (_controller.error as CometChatException).code);
    } else {
      _error = cc.Translations.of(context).no_chats_found;
    }
    if (errorView != null) {}
    _showErrorDialog(_error, context, _theme, _controller);
  }

  Widget _getList(
      CometChatConversationsController _controller, BuildContext context, CometChatTheme _theme) {
    return GetBuilder(
      init: _controller,
      global: false,
      dispose: (GetBuilderState<CometChatConversationsController> state) =>
          state.controller?.onClose(),
      builder: (CometChatConversationsController value) {
        value.context = context;
        if (value.hasError == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showError(value, context, _theme));

          if (errorView != null) {
            return errorView!(context);
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
            itemCount: value.hasMoreItems ? value.list.length + 1 : value.list.length,
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
      CometChatConversationsController _conversationsController, CometChatTheme _theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<Conversation>? conversations = _conversationsController.getSelectedList();
            if (onSelection != null) {
              onSelection!(conversations);
            }
          },
          icon: Image.asset(AssetConstants.checkmark,
              package: UIConstants.packageName, color: _theme.palette.getPrimary()));
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
      WidgetsBinding.instance.addPostFrameCallback((_) => stateCallBack!(conversationsController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).chats,
        hideHeader: hideHeader,
        hideSearch: hideSearch,
        backIcon: backButton,
        showBackButton: showBackButton,
        onBack: onBack,
        theme: theme,
        menuOptions: [
          if (appBarOptions != null && appBarOptions!.isNotEmpty) ...appBarOptions!,
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
  Widget getDefaultSubtitle(CometChatTheme _theme,
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
                    color: _theme.palette.getPrimary(),
                    fontWeight: _theme.typography.subtitle1.fontWeight,
                    fontSize: _theme.typography.subtitle1.fontSize,
                    fontFamily: _theme.typography.subtitle1.fontFamily),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            getReceiptIcon(_theme,
                conversation: conversation,
                hideReceipt: controller.getHideReceipt(conversation, disableReceipt)),
            if (showTypingIndicator)
              Text(
                typingIndicatorText ?? cc.Translations.of(context).is_typing,
                style: conversationsStyle.typingIndicatorStyle ??
                    TextStyle(
                        color: _theme.palette.getPrimary(),
                        fontWeight: _theme.typography.subtitle1.fontWeight,
                        fontSize: _theme.typography.subtitle1.fontSize,
                        fontFamily: _theme.typography.subtitle1.fontFamily),
              )
            else
              Expanded(child: getSubtitle(_theme, context, conversation, controller))
          ],
        ),
      ],
    );
  }

  Widget getReceiptIcon(CometChatTheme _theme,
      {required Conversation conversation, bool? hideReceipt}) {
    if (hideReceipt ?? false) {
      return const SizedBox();
    } else if (conversation.lastMessage != null &&
        conversation.lastMessage?.sender != null &&
        conversation.lastMessage!.deletedAt == null &&
        conversation.lastMessage!.type != "groupMember") {
      ReceiptStatus _status = MessageReceiptUtils.getReceiptStatus(conversation.lastMessage!);

      return Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: CometChatReceipt(
          status: _status,
          deliveredIcon: deliveredIcon ??
              Image.asset(
                AssetConstants.messageReceived,
                package: UIConstants.packageName,
                color: receiptStyle?.deliveredIconTint ?? _theme.palette.getAccent(),
              ),
          readIcon: readIcon ??
              Image.asset(
                AssetConstants.messageReceived,
                package: UIConstants.packageName,
                color: receiptStyle?.readIconTint ?? _theme.palette.getPrimary(),
              ),
          sentIcon: sentIcon ??
              Image.asset(
                AssetConstants.messageSent,
                package: UIConstants.packageName,
                color: receiptStyle?.sentIconTint ?? _theme.palette.getAccent(),
              ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getSubtitle(CometChatTheme _theme, BuildContext context, Conversation conversation,
      CometChatConversationsController controller) {
    TextStyle _subtitleStyle = conversationsStyle.lastMessageStyle ??
        TextStyle(
            color: _theme.palette.getAccent600(),
            fontSize: _theme.typography.subtitle1.fontSize,
            fontWeight: _theme.typography.subtitle1.fontWeight,
            fontFamily: _theme.typography.subtitle1.fontFamily);

    String? _text;

    _text = controller.getLastMessage(conversation, context);

    return Text(
      _text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _subtitleStyle,
    );
  }

//----------- last message update time and unread message count -----------
  Widget getTime(CometChatTheme _theme, Conversation conversation) {
    DateTime? lastMessageTime =
        conversation.lastMessage?.updatedAt ?? conversation.lastMessage?.sentAt;
    if (lastMessageTime == null) return const SizedBox();

    String? _customDateString;

    if (datePattern != null) {
      _customDateString = datePattern!(conversation);
    }

    return CometChatDate(
      date: lastMessageTime,
      style: DateStyle(
          background: dateStyle?.background ?? _theme.palette.getBackground(),
          textStyle: dateStyle?.textStyle ??
              TextStyle(
                  color: _theme.palette.getAccent500(),
                  fontSize: _theme.typography.subtitle1.fontSize,
                  fontWeight: _theme.typography.subtitle1.fontWeight,
                  fontFamily: _theme.typography.subtitle1.fontFamily),
          border: dateStyle?.border ?? Border.all(color: _theme.palette.getBackground(), width: 0),
          borderRadius: dateStyle?.borderRadius,
          contentPadding: dateStyle?.contentPadding,
          gradient: dateStyle?.gradient,
          height: dateStyle?.height,
          isTransparentBackground: dateStyle?.isTransparentBackground,
          width: dateStyle?.width),
      customDateString: _customDateString,
      pattern: DateTimePattern.dayDateTimeFormat,
    );
  }

  Widget getUnreadCount(CometChatTheme _theme, Conversation conversation) {
    return CometChatBadge(
      count: conversation.unreadMessageCount ?? 0,
      style: BadgeStyle(
        width: badgeStyle?.width ?? 25,
        height: badgeStyle?.height ?? 25,
        borderRadius: badgeStyle?.borderRadius ?? 100,
        textStyle: TextStyle(
                fontSize: _theme.typography.subtitle1.fontSize, color: _theme.palette.getAccent())
            .merge(badgeStyle?.textStyle),
        background: badgeStyle?.background ?? _theme.palette.getPrimary(),
      ),
    );
  }
}
