import 'dart:async';
import 'package:cometchat_chat_uikit/src/message_composer/emoji_keyboard_style.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../cometchat_chat_uikit.dart';
import '../../cometchat_chat_uikit.dart' as cc;
import 'messages_builder_protocol.dart';
import 'dart:math' as math;

typedef ThreadRepliesClick = void Function(
    BaseMessage message, BuildContext context,
    {Widget Function(BaseMessage, BuildContext)? bubbleView});

///[CometChatMessageList] is a component that lists all messages with the help of appropriate message bubbles
///messages are fetched using [MessagesBuilderProtocol] and [MessagesRequestBuilder]
///fetched messages are listed down in way such that the most recent message will appear at the bottom of the list
///and the user would have to scroll up to see the previous messages sent or received
///and as user scrolls up, messages will be fetched again using [MessagesBuilderProtocol] and [MessagesRequestBuilder] if available
///when a new message is sent it will automatically scroll to the bottom of the list if the user has scrolled to the top
///and when a new message is received then a sticky UI element displaying [newMessageIndicatorText] will show up at the top of the screen if the user has scrolled to the top
///
/// ```dart
///   CometChatMessageList(
///    user: User(uid: 'uid', name: 'name'),
///    group: Group(guid: 'guid', name: 'name', type: 'public'),
///    messageListStyle: MessageListStyle(),
///  );
/// ```
class CometChatMessageList extends StatefulWidget {
  const CometChatMessageList(
      {Key? key,
      this.errorStateText,
      this.emptyStateText,
      this.stateCallBack,
      this.messagesRequestBuilder,
      this.hideError,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.avatarStyle,
      this.messageListStyle = const MessageListStyle(),
      this.footerView,
      this.headerView,
      this.alignment = ChatAlignment.standard,
      this.group,
      this.user,
      this.customSoundForMessages,
      this.datePattern,
      this.deliveredIcon,
      this.disableSoundForMessages,
      this.hideTimestamp,
      this.templates,
      this.newMessageIndicatorText,
      this.onThreadRepliesClick,
      this.readIcon,
      this.scrollToBottomOnNewMessages,
      this.sentIcon,
      this.showAvatar = true,
      this.timestampAlignment = TimeAlignment.bottom,
      this.waitIcon,
      this.customSoundForMessagePackage,
      this.dateSeparatorPattern,
      this.controller,
      this.onError,
      this.theme,
      this.disableReceipt = false,
        this.messageInformationConfiguration,
        this.dateSeparatorStyle,
        this.reactionListConfiguration,
        this.reactionsConfiguration,
        this.disableReactions = false,
        this.addReactionIcon,
        this.addReactionIconTap,
        this.reactionsStyle,
        this.favoriteReactions,
        this.emojiKeyboardStyle
      })
      : assert(user != null || group != null,
            "One of user or group should be passed"),
        assert(user == null || group == null,
            "Only one of user or group should be passed"),
        super(key: key);

  ///[user] user object  for user message list
  final User? user;

  ///[group] group object  for group message list
  final Group? group;

  ///[messagesRequestBuilder] set  custom request builder which will be passed to CometChat's SDK
  final MessagesRequestBuilder? messagesRequestBuilder;

  ///[messageListStyle] sets style
  final MessageListStyle messageListStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatUsersController object
  final Function(CometChatMessageListController controller)? stateCallBack;

  ///[avatarStyle] set style for avatar visible in leading view of message bubble
  final AvatarStyle? avatarStyle;

  ///disables sound for messages sent/received
  final bool? disableSoundForMessages;

  ///asset url to Sound for outgoing message
  final String? customSoundForMessages;

  ///if sending sound url from other package pass package name here
  final String? customSoundForMessagePackage;

  ///custom read icon visible at read receipt
  final Widget? readIcon;

  ///custom delivered icon visible at read receipt
  final Widget? deliveredIcon;

  /// custom sent icon visible at read receipt
  final Widget? sentIcon;

  ///custom wait icon visible at read receipt
  final Widget? waitIcon;

  ///Chat alignments
  final ChatAlignment alignment;

  ///toggle visibility for avatar
  final bool? showAvatar;

  ///datePattern custom date pattern visible in receipts , returned string will be visible in receipt's date place
  final String Function(BaseMessage message)? datePattern;

  ///[hideTimestamp] toggle visibility for timestamp
  final bool? hideTimestamp;

  ///[timestampAlignment] set receipt's time stamp alignment .can be either [TimeAlignment.top] or [TimeAlignment.bottom]
  final TimeAlignment timestampAlignment;

  ///[templates]Set templates for message list
  final List<CometChatMessageTemplate>? templates;

  ///[newMessageIndicatorText] set new message indicator text
  final String? newMessageIndicatorText;

  ///Should scroll to bottom on new message?, by default false
  final bool? scrollToBottomOnNewMessages;

  ///call back for click on thread indicator
  final ThreadRepliesClick? onThreadRepliesClick;

  ///[headerView] sets custom widget to header
  final Widget? Function(BuildContext,
      {User? user, Group? group, int? parentMessageId})? headerView;

  ///[footerView] sets custom widget to footer
  final Widget? Function(BuildContext,
      {User? user, Group? group, int? parentMessageId})? footerView;

  ///[dateSeparatorPattern] pattern for  date separator
  final String Function(DateTime)? dateSeparatorPattern;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onError] callback triggered in case any error happens when fetching users
  final CometChatTheme? theme;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

  ///[messageInformationConfiguration] sets configuration properties for message information
  final MessageInformationConfiguration? messageInformationConfiguration;

  ///[dateSeparatorStyle] sets style for date separator
  final DateStyle? dateSeparatorStyle;

  ///[reactionListConfiguration] sets configuration properties for reaction list
  final ReactionListConfiguration? reactionListConfiguration;

  ///[reactionsConfiguration] sets configuration properties for reactions
  final ReactionsConfiguration? reactionsConfiguration;

  ///[disableReactions] toggle visibility of reactions
  final bool? disableReactions;

  ///[addReactionIcon] sets custom icon for adding reaction
  final Widget? addReactionIcon;

  ///[addReactionIconTap] sets custom onTap for adding reaction
  final Function(BaseMessage)? addReactionIconTap;

  ///[reactionsStyle] is a parameter used to set the style for the reactions
  final ReactionsStyle? reactionsStyle;

  ///[favoriteReactions] is a list of frequently used reactions
  final List<String>? favoriteReactions;

  ///[emojiKeyboardStyle] is a parameter used to set the style for the emoji keyboard
  final EmojiKeyboardStyle? emojiKeyboardStyle;

  @override
  State<CometChatMessageList> createState() => _CometChatMessageListState();
}

class _CometChatMessageListState extends State<CometChatMessageList> {
  late CometChatMessageListController messageListController;
  late CometChatTheme _theme;

  @override
  void initState() {
    MessagesRequestBuilder messagesRequestBuilder =
        widget.messagesRequestBuilder ?? MessagesRequestBuilder();

    List<String> categories = [];
    List<String> types = [];

    // if (widget.templates != null) {
    //   widget.templates?.forEach((element) {
    //     types.add(element.type);
    //     categories.add(element.category);
    //   });

    //only set types and categories when coming from default
    if (widget.messagesRequestBuilder == null) {
      categories = CometChatUIKit.getDataSource().getAllMessageCategories();
      types = CometChatUIKit.getDataSource().getAllMessageTypes();
      messagesRequestBuilder.types = types;
      messagesRequestBuilder.categories = categories;
    }

    if (widget.messagesRequestBuilder == null) {
      messagesRequestBuilder.hideReplies ??= true;
    }

    if (widget.user != null) {
      messagesRequestBuilder.uid = widget.user!.uid;
    } else {
      messagesRequestBuilder.guid = widget.group!.guid;
    }

    //altering message request builder if not coming from props

    messageListController = CometChatMessageListController(
        customIncomingMessageSound: widget.customSoundForMessages,
        customIncomingMessageSoundPackage: widget.customSoundForMessagePackage,
        disableSoundForMessages: widget.disableSoundForMessages ?? false,
        messagesBuilderProtocol: UIMessagesBuilder(messagesRequestBuilder),
        user: widget.user,
        group: widget.group,
        stateCallBack: widget.stateCallBack,
        messageTypes: widget.templates,
        disableReceipt: widget.disableReceipt,
        theme: widget.theme ?? cometChatTheme,
        // snackBarConfiguration: widget.snackBarConfiguration,
        messageInformationConfiguration: widget.messageInformationConfiguration,
      emojiKeyboardStyle: widget.emojiKeyboardStyle,
      disableReactions: widget.disableReactions ?? false
    );

    _theme = widget.theme ?? cometChatTheme;

    super.initState();
  }

  Color _getBubbleBackgroundColor(BaseMessage messageObject,
      CometChatMessageListController controller, CometChatTheme theme) {
    if (messageObject.deletedAt != null) {
      return theme.palette.getPrimary().withOpacity(0);
    } else if (messageObject.type == MessageTypeConstants.text &&
        messageObject.sender?.uid == controller.loggedInUser?.uid) {
      if (widget.alignment == ChatAlignment.leftAligned) {
        return theme.palette.getAccent100();
      } else {
        return theme.palette.getPrimary();
      }
    } else if (messageObject.category == MessageCategoryConstants.custom) {
      if(messageObject.type == ExtensionType.sticker){
        return Colors.transparent;
      }
      return theme.palette.getAccent50();
    }else if (messageObject.category == MessageCategoryConstants.interactive) {
      return theme.palette.getSecondary();
    } else {
      return theme.palette.getAccent100();
    }
  }

  Widget getMessageWidget(BaseMessage messageObject, BuildContext context) {
    return _getMessageWidget(
        messageObject, messageListController, _theme, context,
        hideThreadView: true,
        overridingAlignment: BubbleAlignment.left,
        hideOptions: true,
        hideFooterView: true
    );
  }

  Widget _getMessageWidget(BaseMessage messageObject,
      CometChatMessageListController controller,
      CometChatTheme theme,
      BuildContext context,
      {bool? hideThreadView,
        BubbleAlignment? overridingAlignment,
        bool? hideOptions,
      bool? hideFooterView
      }) {
    BubbleContentVerifier contentVerifier =
    controller.checkBubbleContent(messageObject, widget.alignment);
    // contentVerifier.alignment = BubbleAlignment.left;
    Widget bubbleView=const SizedBox();

    if (controller
        .templateMap["${messageObject.category}_${messageObject.type}"]
        ?.bubbleView !=
        null) {
      bubbleView = controller
          .templateMap["${messageObject.category}_${messageObject.type}"]
          ?.bubbleView!(messageObject, context, contentVerifier.alignment) ??
          const SizedBox();
    } else {
      BubbleContentVerifier contentVerifier =
      controller.checkBubbleContent(messageObject, widget.alignment);
      Color backgroundColor =
      _getBubbleBackgroundColor(messageObject, controller, theme);
      Widget? headerView;
      Widget? contentView;
      Widget? bottomView;
      Widget? footerView;
      Widget? statusInfoView;
      if (contentVerifier.showName == true) {
        headerView = getHeaderView(messageObject, theme, context, controller,
            contentVerifier.alignment);
      }

      bottomView = getBottomView(
          messageObject, theme, context, controller, contentVerifier.alignment);


      if (hideFooterView != true && contentVerifier.showFooterView != false) {
        footerView = _getFooterView(contentVerifier.alignment, theme,
            messageObject, contentVerifier.showReadReceipt, controller,
            context);
      }

      if (contentVerifier.showStatusInfoView != false) {
        statusInfoView = _getStatusInfoView(contentVerifier.alignment, theme,
            messageObject, contentVerifier.showReadReceipt, controller,
            context);
      }

      contentView = _getSuitableContentView(messageObject, theme, context,
          backgroundColor, controller, contentVerifier.alignment);

      if (contentView != null && statusInfoView != null) {
        if (messageObject.category == MessageCategoryConstants.message &&
            (messageObject.type == MessageTypeConstants.image ||
                messageObject.type == MessageTypeConstants.video) &&
            (contentView != null && statusInfoView != null)) {
          contentView = Stack(
            children: [
              contentView,
              Positioned(
                bottom: 4,
                right: 12,
                child: statusInfoView,
              )
            ],
          );
        }
      }

      Widget? leadingView;
      if (contentVerifier.showThumbnail == true && widget.showAvatar != false) {
        leadingView =
            getAvatar(messageObject, theme, context, messageObject.sender);

      }

      if (contentVerifier.showFooterView != false) {
        footerView = _getFooterView(
            contentVerifier.alignment,
            theme,
            messageObject,
            contentVerifier.showReadReceipt,
            controller,
            context);
      }


        bubbleView = CometChatMessageBubble(
          style: MessageBubbleStyle(
              background: backgroundColor, widthFlex: 0.8),
          headerView: headerView,
          alignment: contentVerifier.alignment,
          contentView: contentView,
          // footerView: footerView,
          footerView: footerView,
          leadingView: leadingView,
          bottomView: bottomView,
          // replyView: replyView,
          statusInfoView: messageObject.type == MessageTypeConstants.image ||
              messageObject.type == MessageTypeConstants.video
              ? null
              : statusInfoView,
          threadView:
          messageObject.deletedAt == null && hideThreadView != true
              ? getViewReplies(messageObject, theme, context,
              backgroundColor, controller, contentVerifier.alignment)
              : null,
        );

    }

      return Row(
        mainAxisAlignment: overridingAlignment == BubbleAlignment.left ||
            contentVerifier.alignment == BubbleAlignment.left
            ? MainAxisAlignment.start
            : contentVerifier.alignment == BubbleAlignment.center
            ? MainAxisAlignment.center
            : MainAxisAlignment.end,
        children: [
          GestureDetector(
            onLongPress: () async {
              if (hideOptions == true) return;
              await _showOptions(messageObject, theme, controller, context);
            },
            child: bubbleView,
          )
        ],
      );

  }

  Widget? getReactionsView(BaseMessage message, BubbleAlignment? alignment, CometChatMessageListController controller) {
    List<ReactionCount>? reactionList = message.reactions;

    if (reactionList == null && reactionList.isEmpty) {
      return null;
    }

    return Transform.translate(
        offset: const Offset(0, -5),
        child:CometChatReactions(reactionList: reactionList,
      alignment: alignment,
      theme: widget.reactionsConfiguration?.theme ?? _theme,
      reactionsStyle: widget.reactionsConfiguration?.reactionsStyle ?? widget.reactionsStyle,
      onReactionTap: widget.reactionsConfiguration?.onReactionTap ?? (reaction) {
        if (reaction!=null || reaction?.trim()!=""){
         controller.handleReactionPress(message, reaction, reactionList);
        }

      },
      onReactionLongPress: widget.reactionsConfiguration?.onReactionLongPress ?? (reaction)=>_launchReactionList(message, reaction: reaction),
    ));
  }

  _launchReactionList(BaseMessage message, {String? reaction}) {
    showModalBottomSheet<ActionItem>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        shape:
        const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (BuildContext context) =>
            CometChatReactionList(
              messageObject: message,
              avatarStyle: widget.reactionListConfiguration?.avatarStyle,
              emptyStateText: widget.reactionListConfiguration?.emptyStateText,
              errorStateText: widget.reactionListConfiguration?.errorStateText,
              loadingStateView: widget.reactionListConfiguration
                  ?.loadingStateView,
              errorStateView: widget.reactionListConfiguration?.errorStateView,
              emptyStateView: widget.reactionListConfiguration?.emptyStateView,
              loadingIcon: widget.reactionListConfiguration?.loadingIcon,
              onTap: widget.reactionListConfiguration?.onTap,
              reactionListStyle: widget.reactionListConfiguration
                  ?.reactionListStyle,
              selectedReaction: widget.reactionListConfiguration
                  ?.selectedReaction ?? reaction,
              listItemStyle: widget.reactionListConfiguration?.listItemStyle,
              reactionRequestBuilder: widget.reactionListConfiguration
                  ?.reactionRequestBuilder,
              theme: widget.reactionListConfiguration?.theme ?? _theme,
            ));
  }


  bool _isSameDate({DateTime? dt1, DateTime? dt2}) {
    if (dt1 == null || dt2 == null) return true;
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  Widget _getDateSeparator(CometChatMessageListController controller, int index,
      BuildContext context, CometChatTheme theme) {
    String? customDateString;
    if (widget.dateSeparatorPattern != null &&
        controller.list[index].sentAt != null) {
      customDateString =
          widget.dateSeparatorPattern!(controller.list[index].sentAt!);
    }
    if ((index == controller.list.length - 1) ||
        !(_isSameDate(
          dt1: controller.list[index].sentAt,
          dt2: controller.list[index + 1].sentAt,
        ))) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: CometChatDate(
          date: controller.list[index].sentAt,
          pattern: DateTimePattern.dayDateFormat,
          customDateString: customDateString,
          style: DateStyle(
              background: theme.palette.getAccent50(),
              textStyle: TextStyle(
                  fontSize: theme.typography.subtitle2.fontSize,
                  fontWeight: theme.typography.subtitle2.fontWeight,
                  color: theme.palette.getAccent600())).merge(widget.dateSeparatorStyle),
        ),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget? getHeaderView(
      BaseMessage message,
      CometChatTheme theme,
      BuildContext context,
      CometChatMessageListController controller,
      BubbleAlignment alignment) {
    if (controller
            .templateMap["${message.category}_${message.type}"]?.headerView !=
        null) {
      return controller.templateMap["${message.category}_${message.type}"]
          ?.headerView!(message, context, alignment);
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            getName(message, theme),
            if (widget.timestampAlignment == TimeAlignment.top &&
                widget.hideTimestamp != true)
              getTime(theme, message),
            if (widget.timestampAlignment != TimeAlignment.top)
              const SizedBox.shrink()
          ],
        ),
      );
    }
  }

  Widget? getBottomView(
      BaseMessage message,
      CometChatTheme theme,
      BuildContext context,
      CometChatMessageListController controller,
      BubbleAlignment alignment) {
    if (controller
            .templateMap["${message.category}_${message.type}"]?.bottomView !=
        null) {
      return controller.templateMap["${message.category}_${message.type}"]
          ?.bottomView!(message, context, alignment);
    } else {
      return null;
    }
  }

  Widget getName(BaseMessage message, CometChatTheme theme) {
    return Container(
      padding: const EdgeInsets.only(right: 8.0, left: 8.0),
      width: MediaQuery.of(context).size.width * 0.65,
      child: Text(
        message.sender!.name,
        style: TextStyle(
            fontSize: theme.typography.text2.fontSize,
            color: theme.palette.getAccent600(),
            fontWeight: theme.typography.text2.fontWeight,
            fontFamily: theme.typography.text2.fontFamily,),
          overflow: TextOverflow.ellipsis
      ),
    );
  }

  Widget getThreadIndicator(BaseMessage messageObject,BubbleAlignment alignment){

    Widget icon = Image.asset(
      AssetConstants.threadIndicator,
      package: UIConstants.packageName,
      height: 15,
      width: 15,
    );
    EdgeInsets padding = const EdgeInsets.only(right: 4);

    if(alignment == BubbleAlignment.right){
      icon = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: icon,
      );
      padding = const EdgeInsets.only(left: 4);
  }
    return Padding(
      padding: padding,
      child: icon,
    );
  }

  Widget? getViewReplies(
      BaseMessage messageObject,
      CometChatTheme theme,
      BuildContext context,
      Color background,
      CometChatMessageListController controller,
      BubbleAlignment alignment) {
    if (messageObject.replyCount != 0) {
      String replyText = messageObject.replyCount == 1
          ? cc.Translations.of(context).reply
          : cc.Translations.of(context).replies;
      return GestureDetector(
        onTap: () {
          if (widget.onThreadRepliesClick != null) {
            widget.onThreadRepliesClick!(messageObject, context,
                bubbleView: getMessageWidget);
          }
        },
        child: Container(
          height: 22,
          padding: const EdgeInsets.only(left: 5, right: 5,top: 4),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if(alignment == BubbleAlignment.left)
                getThreadIndicator(messageObject,alignment),
              Text(
                "${messageObject.replyCount} $replyText",
                style: TextStyle(
                    fontSize: theme.typography.text1.fontSize,
                    fontWeight: theme.typography.text1.fontWeight,
                    color: theme.palette.getAccent()),
              ),
              if(alignment == BubbleAlignment.right)
                getThreadIndicator(messageObject,alignment),
            ],
          ),
        ),
      );
    } else {
      return null;
    }
  }

  Widget? _getFooterView(
      BubbleAlignment alignment,
      CometChatTheme theme,
      BaseMessage message,
      bool readReceipt,
      CometChatMessageListController controller,
      BuildContext context) {
    if (controller
            .templateMap["${message.category}_${message.type}"]?.footerView !=
        null) {
      return controller.templateMap["${message.category}_${message.type}"]
          ?.footerView!(message, context, alignment);
    } else{
      return !(widget.disableReactions ?? message.category==MessageCategoryConstants.interactive) ? getReactionsView(
          message, alignment,controller) : null;
    }
  }

  Widget getTime(CometChatTheme theme, BaseMessage messageObject,{DateStyle? dateStyle}) {
    if (messageObject.sentAt == null) {
      return const SizedBox();
    }

    DateTime lastMessageTime = messageObject.sentAt!;
    return CometChatDate(
      date: lastMessageTime,
      pattern: DateTimePattern.timeFormat,
      customDateString: widget.datePattern != null
          ? widget.datePattern!(messageObject)
          : null,
      style: DateStyle(
        background: Colors.transparent,
        textStyle: TextStyle(
            color: theme.palette.getAccent500(),
            fontSize: theme.typography.caption1.fontSize,
            fontWeight: theme.typography.caption1.fontWeight,
            fontFamily: theme.typography.caption1.fontFamily),
        border: Border.all(
          color: Colors.transparent,
          width: 0,
        ),
      ).merge(dateStyle),
    );
  }

  Widget getReceiptIcon(CometChatTheme theme, BaseMessage message) {
    ReceiptStatus status = MessageReceiptUtils.getReceiptStatus(message);
    return CometChatReceipt(
        status: status,
        deliveredIcon: widget.deliveredIcon ??
            Image.asset(
              AssetConstants.messageReceived,
              package: UIConstants.packageName,
              color: message.category==MessageCategoryConstants.message && message.type==MessageTypeConstants.text ? theme.palette.getAccent500() : theme.palette.getAccent(),
            ),
        readIcon: widget.readIcon ??
            Image.asset(
              AssetConstants.messageReceived,
              package: UIConstants.packageName,
              color: message.category==MessageCategoryConstants.message && message.type==MessageTypeConstants.text ? theme.palette.backGroundColor.light : theme.palette.getPrimary(),
            ),
        sentIcon: widget.sentIcon ??
            Image.asset(
              AssetConstants.messageSent,
              package: UIConstants.packageName,
              color: message.category==MessageCategoryConstants.message && message.type==MessageTypeConstants.text ? theme.palette.getAccent500() : theme.palette.getAccent(),
            ),
        waitIcon: widget.waitIcon ??
      Image.asset(
      AssetConstants.waitIcon,
      package: UIConstants.packageName,
          color: message.category==MessageCategoryConstants.message && message.type==MessageTypeConstants.text ? theme.palette.getAccent500() : theme.palette.getAccent()
    ));
  }

  Widget? _getSuitableContentView(
      BaseMessage messageObject,
      CometChatTheme theme,
      BuildContext context,
      Color background,
      CometChatMessageListController controller,
      BubbleAlignment alignment) {
    if (controller
            .templateMap["${messageObject.category}_${messageObject.type}"]
            ?.contentView !=
        null) {
      return controller
          .templateMap["${messageObject.category}_${messageObject.type}"]
          ?.contentView!(
        messageObject,
        context,
        alignment,
      );
    } else {
      return null;
    }
  }


  Widget getAvatar(BaseMessage messageObject, CometChatTheme theme,
      BuildContext context, User? userObject) {
    return userObject == null
        ? const SizedBox()
        : Padding(
            padding: const EdgeInsets.only(top: 16, right: 4.5),
            child: CometChatAvatar(
              image: userObject.avatar,
              name: userObject.name,
              style: widget.avatarStyle ??
                  AvatarStyle(
                      width: 36,
                      height: 36,
                      background: _theme.palette.getAccent700(),
                      nameTextStyle: TextStyle(
                          color: _theme.palette.getBackground(),
                          fontSize: _theme.typography.name.fontSize,
                          fontWeight: _theme.typography.name.fontWeight,
                          fontFamily: _theme.typography.name.fontFamily)),
            ),
          );
  }

  Future _showOptions(BaseMessage message, CometChatTheme theme,
      CometChatMessageListController controller, BuildContext context) async {
    List<CometChatMessageOption>? options =
        controller.templateMap["${message.category}_${message.type}"]?.options!(
            controller.loggedInUser!, message, context, controller.group);

    if (options != null && options.isNotEmpty) {
      List<ActionItem>? actionOptions = [];
      for (var element in options) {
        Function(BaseMessage message, CometChatMessageListController state)? fn;

        if (element.onClick == null) {
          fn = controller.getActionFunction(element.id);
        } else {
          fn = element.onClick;
        }

        if (fn is Function(BaseMessage message,
            CometChatMessageListControllerProtocol state)?) {
          actionOptions.add(element.toActionItemFromFunction(fn));
        }
      }

      if (actionOptions.isNotEmpty) {
        ActionItem? item = await showMessageOptionSheet(
          context: context,
          actionItems: actionOptions,
          message: message,
          state: controller,
          backgroundColor: theme.palette.getBackground(),
          theme: theme,
          addReactionIcon: widget.addReactionIcon,
          addReactionIconTap: controller.addReactionIconTap,
          hideReactions: widget.disableReactions ?? message.category==MessageCategoryConstants.interactive,
          favoriteReactions:  widget.favoriteReactions,
          onReactionTap:controller.onReactionTap
        );

        if (item != null) {
          if (item.id == MessageOptionConstants.replyInThreadMessage) {
            if (widget.onThreadRepliesClick != null && mounted) {
              widget.onThreadRepliesClick!(message, context,
                  bubbleView: getMessageWidget);
            }
            return;
          }
          item.onItemClick(message, controller);
        }
      }
    }
  }


  Widget _getLoadingIndicator(BuildContext context, CometChatTheme theme) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: widget.messageListStyle.loadingIconTint ??
              theme.palette.getAccent600(),
        ),
      );
    }
  }


  _showErrorDialog(String errorText, BuildContext context, CometChatTheme theme,
      CometChatMessageListController controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          widget.errorStateText ?? errorText,
          style: widget.messageListStyle.errorTextStyle ??
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

  _showError(CometChatMessageListController controller, BuildContext context,
      CometChatTheme theme) {
    if (widget.hideError == true) return;
    String error;
    if (controller.error != null && controller.error is CometChatException) {
      error = Utils.getErrorTranslatedText(
          context, (controller.error as CometChatException).code);
    } else {
      error = cc.Translations.of(context).no_messages_found;
    }
    if (widget.errorStateView != null) {}
    _showErrorDialog(error, context, theme, controller);
  }

  Widget _getNewMessageBanner(CometChatMessageListController controller,
      BuildContext context, CometChatTheme theme) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          controller.messageListScrollController.jumpTo(0.0);
          controller.markAsRead(controller.list[0]);
        },
        child: Container(
          height: 30,
          width: 160,
          decoration: BoxDecoration(
              color: theme.palette.getPrimary(),
              borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                  "${controller.newUnreadMessageCount} ${cc.Translations.of(context).new_messages}"),
              const Icon(
                Icons.arrow_downward,
                size: 18,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _getList(CometChatMessageListController _controller,
      BuildContext context, CometChatTheme _theme) {
    return GetBuilder(
      init: _controller,
      tag: _controller.tag,
      builder: (CometChatMessageListController value) {
        value.context = context;
        if (widget.stateCallBack != null) {
          widget.stateCallBack!(value);
        }

        if (value.hasError == true) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showError(value, context, _theme));

          if (widget.errorStateView != null) {
            return widget.errorStateView!(context);
          }

          return _getLoadingIndicator(context, _theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, _theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          // return _getNoUserIndicator(context, _theme);
          return const Center();
        } else {
          return Stack(
            children: [
              Column(
                children: [
                  if (value.header != null) value.header!,
                  Expanded(
                    child: ListView.builder(
                      controller: _controller.messageListScrollController,
                      reverse: true,
                      itemCount: value.hasMoreItems
                          ? value.list.length + 1
                          : value.list.length,
                      itemBuilder: (context, index) {
                        if (index == value.list.length) {
                          // && value.hasMoreItems

                          value.loadMoreElements();
                          return _getLoadingIndicator(context, _theme);
                          // if (value.hasMoreItems) {
                          //   return Text('loadinggggg');
                          // }
                        }

                        return Column(
                          children: [
                            _getDateSeparator(
                              value,
                              index,
                              context,
                              _theme,
                            ),
                            _getMessageWidget(
                                value.list[index], value, _theme, context),
                          ],
                        );
                      },
                    ),
                  ),
                  if (value.footer != null) value.footer!,
                ],
              ),
              if (_controller.newUnreadMessageCount != 0)
                _getNewMessageBanner(
                  _controller,
                  context,
                  _theme,
                )
            ],
          );
        }
      },
    );
  }

  Widget? _getStatusInfoView(BubbleAlignment alignment,
      CometChatTheme theme,
      BaseMessage message,
      bool readReceipt,
      CometChatMessageListController controller,
      BuildContext context){
    if (controller
        .templateMap["${message.category}_${message.type}"]?.statusInfoView !=
        null) {
      return controller.templateMap["${message.category}_${message.type}"]
          ?.statusInfoView!(message, context, alignment);
    } else {
      bool contentIsMedia = message.category==MessageCategoryConstants.message  && ( message.type == MessageTypeConstants.image ||
          message.type == MessageTypeConstants.video);


      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        // mainAxisAlignment: alignment == BubbleAlignment.right
        //     ? MainAxisAlignment.end
        //     : MainAxisAlignment.start,
        // mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 10.0,right: 10,bottom: 5,top: 5),
            decoration: BoxDecoration(
              color:contentIsMedia? _theme.palette.backGroundColor.light.withOpacity(.618):null,
              borderRadius: contentIsMedia? BorderRadius.circular(20) : null,
            ),
            // width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              // mainAxisAlignment: alignment == BubbleAlignment.right
              //     ? MainAxisAlignment.end
              //     : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.timestampAlignment == TimeAlignment.bottom &&
                    widget.hideTimestamp != true)
                  getTime(
                      theme,
                      message,
                      dateStyle: DateStyle(
                        textStyle: TextStyle(
                            color: message.sender?.uid == controller.loggedInUser?.uid && message.category == MessageCategoryConstants.message && message.type == MessageTypeConstants.text ? theme.palette.backGroundColor.light : theme.palette.getAccent500(),
                            fontSize: theme.typography.caption1.fontSize,
                            fontWeight: theme.typography.caption1.fontWeight,
                            fontFamily: theme.typography.caption1.fontFamily)
                      )
                  ),
                if (readReceipt != false) getReceiptIcon(theme, message),
              ],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.messageListStyle.contentPadding ??
          const EdgeInsets.fromLTRB(16, 0, 16, 0),
      height: widget.messageListStyle.height,
      width: widget.messageListStyle.width,
      decoration: BoxDecoration(
          border: widget.messageListStyle.border,
          borderRadius:
              BorderRadius.circular(widget.messageListStyle.borderRadius ?? 0),
          color: widget.messageListStyle.gradient == null
              ? widget.messageListStyle.background ??
                  _theme.palette.getBackground()
              : null,
          gradient: widget.messageListStyle.gradient),
      child: _getList(messageListController, context, _theme),
    );
  }
}
