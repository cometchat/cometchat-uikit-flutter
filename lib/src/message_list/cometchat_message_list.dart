import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../flutter_chat_ui_kit.dart';
import '../../flutter_chat_ui_kit.dart' as cc;
import '../utils/utils.dart';
import 'messages_builder_protocol.dart';

typedef ThreadRepliesClick = void Function(
    BaseMessage message, BuildContext context,
    {Widget Function(BaseMessage, BuildContext)? bubbleView});

///[CometChatMessageList] is a component that the lists all messages with the help of appropriate message bubbles
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
      this.disableReceipt = false})
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
  final WidgetBuilder? headerView;

  ///[footerView] sets custom widget to footer
  final WidgetBuilder? footerView;

  ///[dateSeparatorPattern] pattern for  date separator
  final String Function(DateTime)? dateSeparatorPattern;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onError] callback triggered in case any error happens when fetching users
  final CometChatTheme? theme;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

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

    if (widget.templates != null) {
      widget.templates?.forEach((element) {
        types.add(element.type);
        categories.add(element.category);
      });
    } else {
      categories = ChatConfigurator.getDataSource().getAllMessageCategories();
      types = ChatConfigurator.getDataSource().getAllMessageTypes();
    }

    if (widget.user != null) {
      messagesRequestBuilder.uid = widget.user!.uid;
    } else {
      messagesRequestBuilder.guid = widget.group!.guid;
    }

    messagesRequestBuilder.types = types;
    messagesRequestBuilder.categories = categories;
    messagesRequestBuilder.hideReplies ??= true;

    messageListController = CometChatMessageListController(
        customIncomingMessageSound: widget.customSoundForMessages,
        customIncomingMessageSoundPackage: widget.customSoundForMessagePackage,
        disableSoundForMessages: widget.disableSoundForMessages ?? false,
        messagesBuilderProtocol: UIMessagesBuilder(messagesRequestBuilder
            // widget.messagesRequestBuilder ??
            //     (widget.user != null
            //         ? (MessagesRequestBuilder()
            //           ..uid = widget.user?.uid
            //           ..guid = ''
            //           ..types =
            //               ChatConfigurator.getDataSource().getAllMessageTypes()
            //           ..categories = ChatConfigurator.getDataSource()
            //               .getAllMessageCategories()
            //           ..hideReplies = true)
            //         : (MessagesRequestBuilder()
            //           ..guid = widget.group!.guid
            //           ..uid = ''
            //           ..types =
            //               ChatConfigurator.getDataSource().getAllMessageTypes()
            //           ..categories = ChatConfigurator.getDataSource()
            //               .getAllMessageCategories()
            //           ..hideReplies = true)),
            ),
        user: widget.user,
        group: widget.group,
        stateCallBack: widget.stateCallBack,
        messageTypes: widget.templates,
        disableReceipt: widget.disableReceipt,
        theme: widget.theme ?? cometChatTheme);

    _theme = widget.theme ?? cometChatTheme;

    super.initState();
  }

  Color _getBubbleBackgroundColor(BaseMessage messageObject,
      CometChatMessageListController _controller, CometChatTheme _theme) {
    if (messageObject.deletedAt != null) {
      return _theme.palette.getPrimary().withOpacity(0);
    } else if (messageObject.type == MessageTypeConstants.text &&
        messageObject.sender?.uid == _controller.loggedInUser?.uid) {
      if (widget.alignment == ChatAlignment.leftAligned) {
        return _theme.palette.getAccent100();
      } else {
        return _theme.palette.getPrimary();
      }
    } else if (messageObject.category == MessageCategoryConstants.custom) {
      return Colors.transparent;
    } else {
      return _theme.palette.getAccent100();
    }
  }

  Widget getMessageWidget(BaseMessage messageObject, BuildContext context) {
    return _getMessageWidget(
        messageObject, messageListController, _theme, context,
        hideThreadView: true,
        overridingAlignment: BubbleAlignment.left,
        hideOptions: true);
  }

  Widget _getMessageWidget(
      BaseMessage messageObject,
      CometChatMessageListController _controller,
      CometChatTheme _theme,
      BuildContext context,
      {bool? hideThreadView,
      BubbleAlignment? overridingAlignment,
      bool? hideOptions}) {
    if (_controller
            .templateMap["${messageObject.category}_${messageObject.type}"]
            ?.bubbleView !=
        null) {
      return _controller
              .templateMap["${messageObject.category}_${messageObject.type}"]
              ?.bubbleView!(messageObject, context, BubbleAlignment.left) ??
          const SizedBox();
    }

    BubbleContentVerifier _contentVerifier =
        _controller.checkBubbleContent(messageObject, widget.alignment);
    Color _backgroundColor =
        _getBubbleBackgroundColor(messageObject, _controller, _theme);
    Widget? _headerView;
    Widget? _contentView;
    Widget? _bottomView;

    if (_contentVerifier.showName == true) {
      _headerView = getHeaderView(messageObject, _theme, context, _controller,
          _contentVerifier.alignment);
    }

    _bottomView = getBottomView(messageObject, _theme, context, _controller,
        _contentVerifier.alignment);

    Widget? _footerView;

    if (_contentVerifier.showFooterView != false) {
      _footerView = _getFooterView(
          _contentVerifier.alignment,
          _theme,
          messageObject,
          _contentVerifier.showReadReceipt,
          _controller,
          context);
    }

    _contentView = _getSuitableContentView(messageObject, _theme, context,
        _backgroundColor, _controller, _contentVerifier.alignment);

    Widget? leadingView;
    if (_contentVerifier.showThumbnail == true && widget.showAvatar != false) {
      leadingView =
          getAvatar(messageObject, _theme, context, messageObject.sender);
    }

    return Row(
      mainAxisAlignment: overridingAlignment == BubbleAlignment.left ||
              _contentVerifier.alignment == BubbleAlignment.left
          ? MainAxisAlignment.start
          : _contentVerifier.alignment == BubbleAlignment.center
              ? MainAxisAlignment.center
              : MainAxisAlignment.end,
      children: [
        GestureDetector(
          onLongPress: () async {
            if (hideOptions == true) return;
            await _showOptions(messageObject, _theme, _controller, context);
          },
          child: CometChatMessageBubble(
            style: MessageBubbleStyle(background: _backgroundColor),
            headerView: _headerView,
            alignment: _contentVerifier.alignment,
            contentView: _contentView,
            footerView: _footerView,
            leadingView: leadingView,
            bottomView: _bottomView,
            // replyView: replyView,
            threadView:
                messageObject.deletedAt == null && hideThreadView != true
                    ? getViewReplies(
                        messageObject,
                        _theme,
                        context,
                        _backgroundColor,
                        _controller,
                        _contentVerifier.alignment)
                    : null,
          ),
        )
      ],
    );
  }

  bool _isSameDate({DateTime? dt1, DateTime? dt2}) {
    if (dt1 == null || dt2 == null) return true;
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  Widget _getDateSeparator(CometChatMessageListController _controller,
      int index, BuildContext context, CometChatTheme _theme) {
    String? customDateString;
    if (widget.dateSeparatorPattern != null &&
        _controller.list[index].sentAt != null) {
      customDateString =
          widget.dateSeparatorPattern!(_controller.list[index].sentAt!);
    }
    if ((index == _controller.list.length - 1) ||
        !(_isSameDate(
          dt1: _controller.list[index].sentAt,
          dt2: _controller.list[index + 1].sentAt,
        ))) {
      return CometChatDate(
        date: _controller.list[index].sentAt,
        pattern: DateTimePattern.dayDateFormat,
        customDateString: customDateString,
        style: DateStyle(
            background: _theme.palette.getAccent50(),
            textStyle: TextStyle(
                fontSize: _theme.typography.subtitle2.fontSize,
                fontWeight: _theme.typography.subtitle2.fontWeight,
                color: _theme.palette.getAccent600())),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget? getHeaderView(
      BaseMessage _message,
      CometChatTheme _theme,
      BuildContext context,
      CometChatMessageListController _controller,
      BubbleAlignment alignment) {
    if (_controller
            .templateMap["${_message.category}_${_message.type}"]?.headerView !=
        null) {
      return _controller.templateMap["${_message.category}_${_message.type}"]
          ?.headerView!(_message, context, alignment);
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            getName(_message, _theme),
            if (widget.timestampAlignment == TimeAlignment.top &&
                widget.hideTimestamp != true)
              getTime(_theme, _message),
            if (widget.timestampAlignment != TimeAlignment.top)
              const SizedBox.shrink()
          ],
        ),
      );
    }
  }

  Widget? getBottomView(
      BaseMessage _message,
      CometChatTheme _theme,
      BuildContext context,
      CometChatMessageListController _controller,
      BubbleAlignment alignment) {
    if (_controller
            .templateMap["${_message.category}_${_message.type}"]?.bottomView !=
        null) {
      return _controller.templateMap["${_message.category}_${_message.type}"]
          ?.bottomView!(_message, context, alignment);
    } else {
      return null;
    }
  }

  Widget getName(BaseMessage message, CometChatTheme _theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, left: 8.0),
      child: Text(
        message.sender!.name,
        style: TextStyle(
            fontSize: _theme.typography.text2.fontSize,
            color: _theme.palette.getAccent600(),
            fontWeight: _theme.typography.text2.fontWeight,
            fontFamily: _theme.typography.text2.fontFamily),
      ),
    );
  }

  Widget? getViewReplies(
      BaseMessage _messageObject,
      CometChatTheme _theme,
      BuildContext context,
      Color background,
      CometChatMessageListController _controller,
      BubbleAlignment alignment) {
    if (_messageObject.replyCount != 0) {
      return GestureDetector(
        onTap: () {
          if (widget.onThreadRepliesClick != null) {
            widget.onThreadRepliesClick!(_messageObject, context,
                bubbleView: getMessageWidget);
          }
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 5, right: 5),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: _theme.palette.getAccent200(), width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${cc.Translations.of(context).view} ${_messageObject.replyCount} ${cc.Translations.of(context).replies}",
                style: TextStyle(
                    fontSize: _theme.typography.body.fontSize,
                    fontWeight: _theme.typography.caption1.fontWeight,
                    color: alignment == BubbleAlignment.left ||
                            _messageObject.type != MessageTypeConstants.text
                        ? _theme.palette.getPrimary()
                        : _theme.palette.getSecondary()),
              ),
              const SizedBox(
                width: 10,
              ),
              Icon(
                Icons.navigate_next,
                size: 16,
                color: _theme.palette.getAccent400(),
              )
            ],
          ),
        ),
      );
    } else {
      return null;
    }
  }

  Widget? _getFooterView(
      BubbleAlignment _alignment,
      CometChatTheme _theme,
      BaseMessage _message,
      bool _readReceipt,
      CometChatMessageListController _controller,
      BuildContext context) {
    if (_controller
            .templateMap["${_message.category}_${_message.type}"]?.footerView !=
        null) {
      return _controller.templateMap["${_message.category}_${_message.type}"]
          ?.footerView!(_message, context, _alignment);
    } else {
      return Row(
        mainAxisAlignment: _alignment == BubbleAlignment.right
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (widget.timestampAlignment == TimeAlignment.bottom &&
              widget.hideTimestamp != true)
            getTime(_theme, _message),
          if (_readReceipt != false) getReceiptIcon(_theme, _message),
        ],
      );
    }
  }

  Widget getTime(CometChatTheme _theme, BaseMessage messageObject) {
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
        background: _theme.palette.getBackground(),
        textStyle: TextStyle(
            color: _theme.palette.getAccent500(),
            fontSize: _theme.typography.caption1.fontSize,
            fontWeight: _theme.typography.caption1.fontWeight,
            fontFamily: _theme.typography.caption1.fontFamily),
        border: Border.all(
          color: _theme.palette.getBackground(),
          width: 0,
        ),
      ),
    );
  }

  Widget getReceiptIcon(CometChatTheme _theme, BaseMessage _message) {
    ReceiptStatus _status = MessageReceiptUtils.getReceiptStatus(_message);
    return CometChatReceipt(
        status: _status,
        deliveredIcon: widget.deliveredIcon ??
            Image.asset(
              AssetConstants.messageReceived,
              package: UIConstants.packageName,
              color: _theme.palette.getAccent(),
            ),
        readIcon: widget.readIcon ??
            Image.asset(
              AssetConstants.messageReceived,
              package: UIConstants.packageName,
              color: _theme.palette.getPrimary(),
            ),
        sentIcon: widget.sentIcon ??
            Image.asset(
              AssetConstants.messageSent,
              package: UIConstants.packageName,
              color: _theme.palette.getAccent(),
            ),
        waitIcon: widget.waitIcon);
  }

  Widget? _getSuitableContentView(
      BaseMessage _messageObject,
      CometChatTheme _theme,
      BuildContext context,
      Color background,
      CometChatMessageListController _controller,
      BubbleAlignment alignment) {
    if (_controller
            .templateMap["${_messageObject.category}_${_messageObject.type}"]
            ?.contentView !=
        null) {
      return _controller
          .templateMap["${_messageObject.category}_${_messageObject.type}"]
          ?.contentView!(
        _messageObject,
        context,
        alignment,
      );
    } else {
      return null;
    }
  }

  // Widget _getPlaceholderBubble(BaseMessage _messageObject,
  //     CometChatTheme _theme, BuildContext _context, Color _background) {
  //   return CometChatPlaceholderBubble(
  //       message: _messageObject,
  //       style: PlaceholderBubbleStyle(
  //         background: _background,
  //         headerTextStyle: TextStyle(
  //             color: _theme.palette.getAccent800(),
  //             fontSize: _theme.typography.heading.fontSize,
  //             fontFamily: _theme.typography.heading.fontFamily,
  //             fontWeight: _theme.typography.heading.fontWeight),
  //         textStyle: TextStyle(
  //             color: _theme.palette.getAccent800(),
  //             fontSize: _theme.typography.subtitle2.fontSize,
  //             fontFamily: _theme.typography.subtitle2.fontFamily,
  //             fontWeight: _theme.typography.subtitle2.fontWeight),
  //       ));
  // }

  Widget getAvatar(BaseMessage _messageObject, CometChatTheme _theme,
      BuildContext _context, User? userObject) {
    return userObject == null
        ? const SizedBox()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
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
      CometChatMessageListController _controller, BuildContext context) async {
    List<CometChatMessageOption>? _options = _controller
            .templateMap["${message.category}_${message.type}"]?.options!(
        _controller.loggedInUser!, message, context, _controller.group);

    if (_options != null && _options.isNotEmpty) {
      List<ActionItem>? _actionOptions = [];
      for (var element in _options) {
        Function(BaseMessage message, CometChatMessageListController state)? fn;

        if (element.onClick == null) {
          fn = _controller.getActionFunction(element.id);
        } else {
          fn = element.onClick;
        }

        _actionOptions.add(element.toActionItemFromFunction(fn));
      }
      if (_actionOptions.isNotEmpty) {
        ActionItem? _item = await showMessageOptionSheet(
          context: context,
          actionItems: _actionOptions,
          message: message,
          state: _controller,
          backgroundColor: theme.palette.getBackground(),
          theme: theme,
        );

        if (_item != null) {
          if (_item.id == MessageOptionConstants.replyInThreadMessage) {
            if (widget.onThreadRepliesClick != null) {
              widget.onThreadRepliesClick!(message, context,
                  bubbleView: getMessageWidget);
            }
            return;
          }
          _item.onItemClick(message, _controller);
        }
      }
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme _theme) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: widget.messageListStyle.loadingIconTint ??
              _theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoUserIndicator(BuildContext context, CometChatTheme _theme) {
    if (widget.emptyStateView != null) {
      return Center(child: widget.emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          widget.emptyStateText ??
              cc.Translations.of(context).no_messages_found,
          style: widget.messageListStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight,
                  color: _theme.palette.getAccent400()),
        ),
      );
    }
  }

  _showErrorDialog(String _errorText, BuildContext context,
      CometChatTheme _theme, CometChatMessageListController _controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          widget.errorStateText ?? _errorText,
          style: widget.messageListStyle.errorTextStyle ??
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
                : Color.alphaBlend(_theme.palette.getAccent200(),
                    _theme.palette.getBackground()),
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

  _showError(CometChatMessageListController _controller, BuildContext context,
      CometChatTheme _theme) {
    if (widget.hideError == true) return;
    String _error;
    if (_controller.error != null && _controller.error is CometChatException) {
      _error = Utils.getErrorTranslatedText(
          context, (_controller.error as CometChatException).code);
    } else {
      _error = cc.Translations.of(context).no_messages_found;
    }
    if (widget.errorStateView != null) {}
    _showErrorDialog(_error, context, _theme, _controller);
  }

  Widget _getNewMessageBanner(CometChatMessageListController _controller,
      BuildContext context, CometChatTheme theme) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          _controller.messageListScrollController.jumpTo(0.0);
          _controller.markAsRead(_controller.list[0]);
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
                  "${_controller.newUnreadMessageCount} ${cc.Translations.of(context).new_messages}"),
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
              ?.addPostFrameCallback((_) => _showError(value, context, _theme));

          if (widget.errorStateView != null) {
            return widget.errorStateView!(context);
          }

          return _getLoadingIndicator(context, _theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, _theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          return _getNoUserIndicator(context, _theme);
        } else {
          return Stack(
            children: [
              ListView.builder(
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
