import 'package:flutter/material.dart';
import '../../flutter_chat_ui_kit.dart';
import 'message_composer/live_reaction_animation.dart';

///
///[CometChatMessages] component encompasses [CometChatMessageHeader], [CometChatMessageList], [CometChatMessageComposer] component.
///It handles communication between these components.
///
///```dart
/// CometChatMessages(
///        user:'user id',
///        enableTypingIndicator:true,
///        enableSoundForMessages:true,
///        hideMessageComposer:false,
///        messageHeaderConfiguration:MessageHeaderConfiguration(),
///        messageBubbleConfiguration:MessageBubbleConfiguration(),
///        messageListConfiguration:MessageListConfiguration(),
///        messageComposerConfiguration:MessageComposerConfiguration(),
///      )
///
///
/// ```

class CometChatMessages extends StatefulWidget {
  const CometChatMessages(
      {Key? key,
      this.user,
      this.group,
      this.hideMessageComposer = false,
      this.theme,
      this.messageListConfiguration = const MessageListConfiguration(),
      this.messageHeaderConfiguration = const MessageHeaderConfiguration(),
      this.messageComposerConfiguration = const MessageComposerConfiguration(),
      this.enableTypingIndicator = true,
      this.enableSoundForMessages = true,
      this.stateCallBack,
      this.messageTypes,
      this.excludeMessageTypes,
      this.notifyParent})
      : super(key: key);

  ///[user] user uid for user message list
  final String? user;

  ///[group] group guid for group message list
  final String? group;

  ///[hideMessageComposer] hides the composer , default false
  final bool hideMessageComposer;

  ///[enableTypingIndicator] if true then show typing indicator for composer
  final bool enableTypingIndicator;

  ///[enableSoundForMessages] enables sound for sending message
  final bool enableSoundForMessages;

  ///[theme] customTheme can be passed inorder to change view
  final CometChatTheme? theme;

  ///To set the configuration  of message list [messageListConfiguration] is used
  final MessageListConfiguration messageListConfiguration;

  ///To set the configuration  of message list [messageHeaderConfiguration] is used
  final MessageHeaderConfiguration messageHeaderConfiguration;

  ///To set the configuration  of message list [messageComposerConfiguration] is used
  final MessageComposerConfiguration messageComposerConfiguration;

  ///[stateCallBack] used to give state to parent
  ///here we can set the state reference to its parent
  final Function(CometChatMessagesState)? stateCallBack;

  final List<CometChatMessageTemplate>? messageTypes;

  final List<String>? excludeMessageTypes;

  ///[notifyParent] method to tell parent message List is active
  final Function(String? id)? notifyParent;

  @override
  State<CometChatMessages> createState() => CometChatMessagesState();
}

class CometChatMessagesState extends State<CometChatMessages>
    with CometChatMessageEventListener, MessageListener {
  CometChatMessageListState? messageListState;
  CometChatMessageComposerState? composerState;
  CometChatTheme _theme = cometChatTheme;
  bool _isOverlayOpen = false;
  List<Widget> _liveAnimationList = [];

  messageListStateCallBack(CometChatMessageListState _messageListState) {
    messageListState = _messageListState;
  }

  composerStateCallBack(CometChatMessageComposerState _composerState) {
    composerState = _composerState;
  }

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    if (widget.stateCallBack != null) widget.stateCallBack!(this);
    CometChatMessageEvents.addMessagesListener(
        "cometchat_message_listener", this);
    CometChat.addMessageListener("cometchat_message_listener", this);
  }

  @override
  void dispose() {
    CometChatMessageEvents.removeMessagesListener("cometchat_message_listener");
    CometChat.removeMessageListener("cometchat_message_listener");
    super.dispose();
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
  void onMessageReact(
      BaseMessage message, String reaction, MessageStatus messageStatus) {
    if (messageStatus == MessageStatus.inProgress) {
      messageListState?.reactToMessage(message, reaction);
    }
  }

  @override
  void onTransientMessageReceived(TransientMessage message) async {
    if (message.data["type"] == "live_reaction") {
      _isOverlayOpen = true;
      String reaction = message.data["reaction"];
      _addAnimations(reaction);
    }
  }

  @override
  void onLiveReaction(String reaction) async {
    _isOverlayOpen = true;
    _addAnimations(reaction);
  }

  setOverLayFalse() {
    if (_liveAnimationList.isNotEmpty) {
      _liveAnimationList.removeAt(0);
      if (_liveAnimationList.isEmpty) {
        _isOverlayOpen = false;
        setState(() {});
      }
    }
  }

  @override
  void onCreatePoll(MessageStatus messageStatus) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatCreatePoll(
                user: widget.user,
                group: widget.group,
                style: CreatePollStyle(
                    background: _theme.palette.getBackground(),
                    titleStyle: TextStyle(
                        color: _theme.palette.getAccent(),
                        fontSize: _theme.typography.title1.fontSize,
                        fontWeight: _theme.typography.title1.fontWeight),
                    closeIconColor: _theme.palette.getPrimary(),
                    createPollIconColor: _theme.palette.getPrimary(),
                    borderColor: _theme.palette.getAccent200(),
                    inputTextStyle: TextStyle(
                      color: _theme.palette.getAccent(),
                      fontSize: _theme.typography.body.fontSize,
                      fontFamily: _theme.typography.body.fontFamily,
                      fontWeight: _theme.typography.body.fontWeight,
                    ),
                    hintTextStyle: TextStyle(
                      color: _theme.palette.getAccent600(),
                      fontSize: _theme.typography.body.fontSize,
                      fontFamily: _theme.typography.body.fontFamily,
                      fontWeight: _theme.typography.body.fontWeight,
                    ),
                    addAnswerTextStyle: TextStyle(
                        color: _theme.palette.getPrimary(),
                        fontSize: _theme.typography.body.fontSize,
                        fontFamily: _theme.typography.body.fontFamily,
                        fontWeight: _theme.typography.body.fontWeight),
                    answerHelpText: TextStyle(
                        color: _theme.palette.getAccent600(),
                        fontSize: _theme.typography.text2.fontSize,
                        fontWeight: _theme.typography.text2.fontWeight)))));
  }

  @override
  void onMessageEdited(BaseMessage message) {
    messageListState?.updateMessage(message);
  }

  @override
  void onError(error, BaseMessage? message) {
    if (message != null) {
      messageListState?.updateMessage(message);
    }
  }

  //-----MessageListListener methods-----
  @override
  void onMessageEdit(BaseMessage message, MessageEditStatus status) {
    if (message.type == MessageTypeConstants.text &&
        status == MessageEditStatus.inProgress) {
      composerState?.previewMessage(message, PreviewMessageMode.edit);
    } else {
      messageListState?.updateMessage(message);
    }
  }

  @override
  void onMessageReply(BaseMessage message) {
    composerState?.previewMessage(message, PreviewMessageMode.reply);
  }

  Widget getMessageList() {
    return CometChatMessageList(
      user: widget.user,
      group: widget.group,
      theme: widget.theme,
      limit: widget.messageListConfiguration.limit,
      onlyUnread: widget.messageListConfiguration.onlyUnread,
      hideDeletedMessages: widget.messageListConfiguration.hideDeletedMessages,
      hideThreadReplies: widget.messageListConfiguration.hideThreadReplies,
      tags: widget.messageListConfiguration.tags,
      excludeMessageTypes:
          widget.messageListConfiguration.excludeMessageTypes ??
              widget.excludeMessageTypes,
      emptyText: widget.messageListConfiguration.emptyText,
      errorText: widget.messageListConfiguration.errorText,
      hideError: widget.messageListConfiguration.hideError ?? false,
      customView: widget.messageListConfiguration.customView,
      //onErrorCallBack: widget.messageListConfiguration.onErrorCallBack,
      scrollToBottomOnNewMessage:
          widget.messageListConfiguration.scrollToBottomOnNewMessage,
      enableSoundForMessages: widget.enableSoundForMessages,
      customIncomingMessageSound:
          widget.messageListConfiguration.customIncomingMessageSound ?? '',
      showEmojiInLargerSize:
          widget.messageListConfiguration.showEmojiInLargerSize,
      messageTypes:
          widget.messageListConfiguration.messageTypes ?? widget.messageTypes,
      stateCallBack: messageListStateCallBack,
      messageBubbleConfiguration:
          widget.messageListConfiguration.messageBubbleConfiguration,
      excludedMessageOptions:
          widget.messageListConfiguration.excludedMessageOptions,
      alignment: widget.messageListConfiguration.messageAlignment,
      hideMessagesFromBlockedUsers:
          widget.messageListConfiguration.hideMessagesFromBlockedUsers,
      receivedMessageInputData:
          widget.messageListConfiguration.receivedMessageInputData,
      sentMessageInputData:
          widget.messageListConfiguration.sentMessageInputData,
      notifyParent: widget.notifyParent,
    );
  }

  Widget getMessageComposer() {
    return CometChatMessageComposer(
      user: widget.user,
      group: widget.group,
      theme: widget.theme,
      stateCallBack: composerStateCallBack,
      enableTypingIndicator: widget.enableTypingIndicator,
      customOutgoingMessageSound:
          widget.messageComposerConfiguration.customOutgoingMessageSound,
      excludeMessageTypes:
          widget.messageComposerConfiguration.excludeMessageTypes ??
              widget.excludeMessageTypes,
      messageTypes: widget.messageComposerConfiguration.messageTypes ??
          widget.messageTypes,
      enableSoundForMessages: widget.enableSoundForMessages,
      hideEmoji: widget.messageComposerConfiguration.hideEmoji,
      hideAttachment: widget.messageComposerConfiguration.hideAttachment,
      hideLiveReaction: widget.messageComposerConfiguration.hideLiveReaction,
      hideMicrophone: widget.messageComposerConfiguration.hideMicrophone,
      showSendButton: widget.messageComposerConfiguration.showSendButton,
      placeholderText: widget.messageComposerConfiguration.placeholderText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: CometChatMessageHeader(
          user: widget.user,
          group: widget.group,
          enableTypingIndicator: widget.enableTypingIndicator,
          theme: widget.theme,
          showBackButton: widget.messageHeaderConfiguration.showBackButton,
          backButton: widget.messageHeaderConfiguration.backButton,
          avatarConfiguration:
              widget.messageHeaderConfiguration.avatarConfiguration,
          statusIndicatorConfiguration:
              widget.messageHeaderConfiguration.statusIndicatorConfiguration,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                //----message list-----
                Expanded(child: getMessageList()),

                //-----message composer-----
                if (widget.hideMessageComposer == false) getMessageComposer()
              ],
            ),
            if (_isOverlayOpen == true) ..._liveAnimationList
          ],
        ),
      ),
    );
  }

  _addAnimations(String reaction) async {
    //Counter to add no of live reactions
    int _counter = 2;
    for (int i = 0; i < _counter; i++) {
      _addAnimation(reaction);
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  _addAnimation(String reaction) {
    _liveAnimationList.add(
      Positioned(
          bottom: 100,
          right: 0,
          child: Container(
            child: AnimatedSwitcher(
              key: UniqueKey(),
              duration: const Duration(milliseconds: 1000),
              child: LiveReactionAnimation(
                endAnimation: setOverLayFalse,
                reaction: reaction,
              ),
            ),
          )),
    );
    if (mounted) {
      setState(() {});
    }
  }
}
