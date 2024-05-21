import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart';

///[AIAssistBotController] is the view model for [AIAssistBotView]
class AIAssistBotController
    extends CometChatListController<AIAssistBotMessage, int> {
  //--------------------Constructor-----------------------
  AIAssistBotController(
      {OnError? onError,
      this.user,
      this.group,
      required this.aiBot,
      this.apiConfiguration})
      : super(null, onError: onError);

  static int messageId = 1;

  late BuildContext context;
  User? user;
  Group? group;
  User aiBot;
  Map<String, dynamic>? apiConfiguration;

  ///[textEditingController] controls the state of the text field
  late TextEditingController textEditingController;

  ///[_previousText] holds the state of the last typed text
  String _previousText = "";

  int getUniqueMessageId() {
    messageId++;
    return messageId;
  }

  //-------------------------Variable Declaration-----------------------------
  late UsersBuilderProtocol usersBuilderProtocol;

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    const String constText =
        "How can I help you with this conversation? Please ask me a question, and I will give advice to you 😄.";

    super.onInit();
    AIAssistBotMessage message = AIAssistBotMessage(
        id: messageId,
        message: constText,
        sentStatus: AIMessageStatus.sent,
        isSentByMe: false,
        sentAt: DateTime.now());
    messageId++;
    list.add(message);
    update();
    textEditingController = TextEditingController(text: null);
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }

  @override
  loadMoreElements({bool Function(AIAssistBotMessage element)? isIncluded}) {
    //no function should be performed
  }

  //-------------------------Parent List overriding Methods-----------------------------
  @override
  bool match(AIAssistBotMessage elementA, AIAssistBotMessage elementB) {
    return elementA.id == elementB.id;
  }

  @override
  int getKey(AIAssistBotMessage element) {
    return element.id;
  }

  onChanged(val) {
    _onTyping();
  }

  _onTyping() {
    if ((_previousText.isEmpty && textEditingController.text.isNotEmpty) ||
        (_previousText.isNotEmpty && textEditingController.text.isEmpty)) {
      update();
    }
    if (_previousText.length > textEditingController.text.length) {
      _previousText = textEditingController.text;
      return;
    }
  }

  sendTextMessage() {
    String controllerText = textEditingController.text;
    AIAssistBotMessage botMessage = AIAssistBotMessage(
        message: textEditingController.text,
        sentStatus: AIMessageStatus.inProgress,
        id: getUniqueMessageId(),
        isSentByMe: true,
        sentAt: DateTime.now());

    textEditingController.clear();
    update();

    addElement(botMessage);

    CometChat.askBot(
        user != null ? user!.uid : group!.guid,
        user != null ? ReceiverTypeConstants.user : ReceiverTypeConstants.group,
        aiBot.uid,
        controllerText,
        configuration: apiConfiguration, onSuccess: (String val) {
      botMessage.sentStatus = AIMessageStatus.sent;
      updateElement(botMessage);
      AIAssistBotMessage retMessage = AIAssistBotMessage(
          message: val,
          sentStatus: AIMessageStatus.sent,
          id: getUniqueMessageId(),
          isSentByMe: false,
          sentAt: DateTime.now());
      addElement(retMessage);
    }, onError: (_) {
      botMessage.sentStatus = AIMessageStatus.error;
      updateElement(botMessage);
    });
  }
}
