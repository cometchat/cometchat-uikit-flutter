import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatMessageThread extends StatefulWidget {
  const CometChatMessageThread(
      {Key? key, required this.message, this.theme, this.user, this.group})
      : super(key: key);

  final BaseMessage message;

  final CometChatTheme? theme;

  ///[user] user uid for user message list
  final String? user;

  ///[group] group guid for group message list
  final String? group;

  @override
  State<CometChatMessageThread> createState() => _CometChatMessageThreadState();
}

class _CometChatMessageThreadState extends State<CometChatMessageThread>
    with CometChatMessageEventListener {
  CometChatMessageListState? messageListState;
  CometChatMessageComposerState? composerState;

  messageListStateCallBack(CometChatMessageListState _messageListState) {
    messageListState = _messageListState;
  }

  composerStateCallBack(CometChatMessageComposerState _composerState) {
    composerState = _composerState;
  }

  //-----MessageComposerListener methods-----
  @override
  onMessageSent(BaseMessage message, MessageStatus messageStatus) {
    if (messageStatus == MessageStatus.inProgress) {
      messageListState?.addMessage(message);
    } else if (messageStatus == MessageStatus.sent) {
      messageListState?.updateMessageWithMuid(message);
    }
  }

  @override
  void onMessageEdited(BaseMessage message) {
    messageListState?.updateMessage(message);
  }

  //-----MessageListListener methods-----
  @override
  void onMessageEdit(BaseMessage message, MessageEditStatus status) {
    if (message.type == MessageTypeConstants.text &&
        status == MessageEditStatus.inProgress) {
      composerState?.previewMessage(message, PreviewMessageMode.edit);
    }
  }

  @override
  void onMessageReply(BaseMessage message) {
    if (message.type == MessageTypeConstants.text) {
      composerState?.previewMessage(message, PreviewMessageMode.reply);
    }
  }

  Widget threadDivider(int replyCount, CometChatTheme theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: theme.palette.getAccent100(), width: 1),
              bottom:
                  BorderSide(color: theme.palette.getAccent100(), width: 1))),
      child: Center(
        child: ListTile(
          leading: Text(
            '$replyCount ${Translations.of(context).reply}',
            style: TextStyle(
                color: theme.palette.getAccent600(),
                fontSize: theme.typography.text1.fontSize,
                fontWeight: theme.typography.text1.fontWeight),
          ),
          trailing: Image.asset(
            "assets/icons/more.png",
            package: UIConstants.packageName,
            color: theme.palette.getPrimary(),
          ),
        ),
      ),
    );
  }

  Widget getMessageComposer() {
    return CometChatMessageComposer(
      user: widget.user,
      group: widget.group,
      stateCallBack: composerStateCallBack,
      threadParentMessageId: widget.message.id,
    );
  }

  Widget getMessageList() {
    return CometChatMessageList(
      stateCallBack: messageListStateCallBack,
      threadParentMessageId: widget.message.id,
      user: widget.user,
      group: widget.group,
    );
  }

  @override
  void initState() {
    super.initState();
    CometChatMessageEvents.addMessagesListener(
        "cometchat_thread_messages_listener", this);
  }

  @override
  void dispose() {
    CometChatMessageEvents.removeMessagesListener(
        "cometchat_thread_messages_listener");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme theme = widget.theme ?? cometChatTheme;

    return CometChatListBase(
        title: Translations.of(context).thread,
        showBackButton: true,
        hideSearch: true,
        backIcon: Image.asset(
          "assets/icons/close.png",
          package: UIConstants.packageName,
          color: theme.palette.getPrimary(),
        ),
        theme: widget.theme,
        container: Column(
          children: [
            CometChatMessageBubble(
                messageObject: widget.message,
                alignment: BubbleAlignment.left,
                threadReplies: false,
                style: MessageBubbleStyle(
                    background: theme.palette.getSecondary900()),
                messageInputData: const MessageInputData(
                  thumbnail: false,
                  title: false,
                  readReceipt: false,
                  timestamp: true,
                )),
            const SizedBox(
              height: 16,
            ),
            threadDivider(widget.message.replyCount, theme),
            Expanded(child: getMessageList()),
            getMessageComposer()
          ],
        ));
  }
}
