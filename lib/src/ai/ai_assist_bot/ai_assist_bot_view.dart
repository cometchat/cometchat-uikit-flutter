import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get.dart';

///[AIAssistBotView] is a widget that is rendered as the content view for [AIAssistBotExtension]
///```dart
/// AIAssistBotView(
///   style: AIAssistBotStyle(),
///   user: User(),
///   emptyStateText: Text("Error occurred"),
///   loadingStateView: Text("Loading..."),
///   theme: CometChatTheme(),
///   loggedInUser: loggedInUser
///   )
/// ```

class AIAssistBotView extends StatefulWidget {
  const AIAssistBotView(
      {super.key,
      this.user,
      this.group,
      this.assistBotStyle,
      this.title,
      this.errorIconUrl,
      this.theme,
      this.loadingStateText,
      this.loadingIconUrl,
      this.loadingStateView,
      this.errorStateView,
      this.emptyStateView,
      this.emptyIconUrl,
      this.onCloseIconTap,
      required this.aiBot,
      this.controllerTag,
      required this.loggedInUser,
      this.apiConfiguration});

  /// set [User] object, one is mandatory either [user] or [group]
  final User? user;

  ///set [Group] object, one is mandatory either [user] or [group]
  final Group? group;

  ///set [title] set the tile for assist bot
  final String? title;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[loadingStateText] text to be displayed when loading occur
  final String? loadingStateText;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[loadingStateView] returns view for loading state
  final WidgetBuilder? loadingStateView;

  ///[errorStateView] returns view for error state
  final WidgetBuilder? errorStateView;

  ///[errorIconUrl] used to set the error icon
  final String? errorIconUrl;

  ///[emptyIconUrl] used to set the empty icon
  final String? emptyIconUrl;

  ///[loadingIconUrl] used to set the loading icon
  final String? loadingIconUrl;

  ///[onCloseIconTap] used to set custom action on close of view
  final Function()? onCloseIconTap;

  ///[loggedInUser] instance of logged in user
  final User loggedInUser;

  ///[aiBot] instance of bot in conversation
  final User aiBot;

  ///[controllerTag] tag to create from , if this is passed its parent responsibility to close this
  final String? controllerTag;

  ///[assistBotStyle] passes style
  final AIAssistBotStyle? assistBotStyle;

  ///[apiConfiguration] sets the configuration for ask bot api call
  final Map<String, dynamic>? apiConfiguration;

  @override
  State<AIAssistBotView> createState() => _AIAssistBotViewState();
}

class _AIAssistBotViewState extends State<AIAssistBotView> {
  late AIAssistBotController aiBotController;
  late String dateString;
  late String tag;
  late CometChatTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    dateString = DateTime.now().microsecondsSinceEpoch.toString();

    tag = widget.controllerTag ?? "default_tag_for_bots_$dateString";
    aiBotController = Get.put<AIAssistBotController>(
        AIAssistBotController(
            aiBot: widget.aiBot,
            user: widget.user,
            group: widget.group,
            apiConfiguration: widget.apiConfiguration),
        tag: tag);
  }

  @override
  void dispose() {
    Get.delete<CometChatUsersController>(tag: tag);
    super.dispose();
  }

  Widget getHeaderView() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, left: 8.0),
      child: Text(
        widget.aiBot.name,
        style: TextStyle(
            fontSize: _theme.typography.text2.fontSize,
            color: _theme.palette.getAccent600(),
            fontWeight: _theme.typography.text2.fontWeight,
            fontFamily: _theme.typography.text2.fontFamily),
      ),
    );
  }

  Widget getAvatar() {
    return CometChatAvatar(
      image: widget.aiBot.avatar,
      name: widget.aiBot.name,
      style: AvatarStyle(
          width: 36,
          height: 36,
          background: _theme.palette.getAccent700(),
          nameTextStyle: TextStyle(
              color: _theme.palette.getBackground(),
              fontSize: _theme.typography.name.fontSize,
              fontWeight: _theme.typography.name.fontWeight,
              fontFamily: _theme.typography.name.fontFamily)),
    );
  }

  Widget _getSuitableContentView(AIAssistBotMessage botMessage) {
    return CometChatTextBubble(
      text: botMessage.message,
      alignment: botMessage.isSentByMe == true
          ? BubbleAlignment.right
          : BubbleAlignment.left,
      theme: _theme,
    );
  }

  Widget getTime(CometChatTheme theme, AIAssistBotMessage messageObject) {
    if (messageObject.sentAt == null) {
      return const SizedBox();
    }

    DateTime lastMessageTime = messageObject.sentAt!;
    return CometChatDate(
      date: lastMessageTime,
      pattern: DateTimePattern.timeFormat,
      style: DateStyle(
        background: theme.palette.getBackground(),
        textStyle: TextStyle(
            color: theme.palette.getAccent500(),
            fontSize: theme.typography.caption1.fontSize,
            fontWeight: theme.typography.caption1.fontWeight,
            fontFamily: theme.typography.caption1.fontFamily),
        border: Border.all(
          color: theme.palette.getBackground(),
          width: 0,
        ),
      ),
    );
  }

  Widget _getReceiptIcon(AIAssistBotMessage message) {
    if (message.sentStatus == AIMessageStatus.sent) {
      return getTime(_theme, message);
    }
    ReceiptStatus status = message.sentStatus == AIMessageStatus.inProgress
        ? ReceiptStatus.waiting
        : ReceiptStatus.error;
    return CometChatReceipt(status: status);
  }

  Widget _getMessageWidget(AIAssistBotMessage botMessage,
      AIAssistBotController controller, CometChatTheme theme) {
    BubbleContentVerifier contentVerifier = BubbleContentVerifier(
        showFooterView: true,
        showName: !botMessage.isSentByMe,
        showThumbnail: !botMessage.isSentByMe,
        alignment: botMessage.isSentByMe
            ? BubbleAlignment.right
            : BubbleAlignment.left);
    Color backgroundColor = botMessage.isSentByMe == true
        ? theme.palette.getPrimary()
        : theme.palette.getAccent100();
    Widget? headerView;
    Widget? contentView;

    if (contentVerifier.showName == true) {
      headerView = getHeaderView();
    }

    Widget? footerView;

    footerView = _getReceiptIcon(botMessage);

    contentView = _getSuitableContentView(botMessage);

    Widget? leadingView;

    return Row(
      mainAxisAlignment: contentVerifier.alignment == BubbleAlignment.left
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        GestureDetector(
          child: CometChatMessageBubble(
            style:
                MessageBubbleStyle(background: backgroundColor, widthFlex: 0.8),
            headerView: headerView,
            alignment: contentVerifier.alignment,
            contentView: contentView,
            footerView: footerView,
            leadingView: leadingView,
          ),
        )
      ],
    );
  }

  Widget _getList(AIAssistBotController value, BuildContext context,
      CometChatTheme listTheme) {
    value.context = context;
    return ListView.builder(
      itemCount: value.list.length,
      shrinkWrap: true,
      reverse: true,
      itemBuilder: (context, index) {
        return _getMessageWidget(value.list[index], value, listTheme);
      },
    );
  }

  Widget getMessageInput(AIAssistBotController controller) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: CometChatMessageInput(
                textEditingController: controller.textEditingController,
                hideBottomView: true,
                style: MessageInputStyle(
                    background: _theme.palette.getAccent100(),
                    borderRadius: 20.0),
                onChange: (String val) {
                  controller.onChanged(val);
                }),
          ),
        ),
        Transform.scale(
          scale: 1.4,
          child: IconButton(
              padding: const EdgeInsets.all(1),
              constraints: const BoxConstraints(),
              icon: Image.asset(
                AssetConstants.send,
                package: UIConstants.packageName,
                color: controller.textEditingController.text.isEmpty
                    ? _theme.palette.getAccent400()
                    : _theme.palette.getPrimary(),
              ),
              onPressed: () {
                if (controller.textEditingController.text.isNotEmpty) {
                  controller.sendTextMessage();
                }
              }),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color:
            widget.assistBotStyle?.background ?? _theme.palette.getBackground(),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GetBuilder(
                tag: tag,
                builder: (AIAssistBotController value) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Row(
                              children: [
                                getAvatar(),
                                const SizedBox(
                                  width: 10,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      widget.aiBot.name,
                                      style: TextStyle(
                                              fontSize: _theme
                                                  .typography.heading.fontSize,
                                              fontFamily: _theme.typography
                                                  .heading.fontFamily,
                                              fontWeight: _theme.typography
                                                  .heading.fontWeight,
                                              color: _theme.palette.getAccent())
                                          .merge(widget
                                              .assistBotStyle?.titleStyle),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                                onPressed: () {
                                  if (widget.onCloseIconTap != null) {
                                    widget.onCloseIconTap!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: Icon(
                                  Icons.close,
                                  color: widget.assistBotStyle?.closeIconTint ??
                                      _theme.palette.getAccent(),
                                ))
                          ],
                        ),
                      ),
                      Container(
                          alignment: Alignment.topCenter,
                          height: MediaQuery.of(context).size.height / 3,
                          child: _getList(value, context, _theme)),
                      Divider(
                        color: _theme.palette.getAccent200(),
                      ),
                      getMessageInput(value)
                    ],
                  );
                }),
          ],
        ),
      ),
    );
  }
}
