import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../flutter_chat_ui_kit.dart';

class CometChatThreadedMessageController extends GetxController
    with
        CometChatMessageEventListener,
        MessageListener,
        CometChatGroupEventListener {
  //--------------------Constructor-----------------------
  CometChatThreadedMessageController(this.parentMessage, this.loggedInUser,
      {this.parentMessageContentView}) {
    if (parentMessage.sender!.uid == loggedInUser.uid) {
      if (parentMessage.receiver is Group) {
        group = (parentMessage.receiver as Group);
      } else {
        user = (parentMessage.receiver as User);
      }
    } else {
      if (parentMessage.receiver is Group) {
        group = (parentMessage.receiver as Group);
      } else {
        user = parentMessage.sender!;
      }
    }

    tag = "tag$counter";
    replyCount = parentMessage.replyCount;
  }

  //-------------------------Variable Declaration-----------------------------
  ///[parentMessageContentView] content view for parent message
  final Widget? parentMessageContentView;
  late BaseMessage parentMessage;
  User? user;
  Group? group;
  User loggedInUser;
  late String _dateString;
  late String _uiMessageListener;
  late String _messageListener;
  late String _uiGroupListener;
  CometChatMessageComposerController? composerState;
  static int counter = 0;
  late String tag;
  late int replyCount;

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    super.onInit();
    counter++;
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiMessageListener = "${_dateString}UI_message_listener";
    _messageListener = "${_dateString}message_listener";
    _uiGroupListener = "${_dateString}UI_group_listener";
    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    CometChat.addMessageListener(_messageListener, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    CometChat.removeMessageListener(_messageListener);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
    super.onClose();
  }

  //------------------------SDK Message Event Listeners------------------------------
  @override
  void onMessageDeleted(BaseMessage message) {
    if (message.id == parentMessage.id) {
      parentMessage = message;
      update();
    }
  }

  @override
  void onMessageEdited(BaseMessage message) {
    if (message.id == parentMessage.id) {
      parentMessage = message;
      update();
    }
  }

  //------------------------UI Message Event Listeners------------------------------
  @override
  ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    if (messageStatus == MessageStatus.sent) {
      replyCount++;
      update();
    }
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (message.id == parentMessage.id) {
      update();
    }
  }

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (message.id == parentMessage.id && status == MessageEditStatus.success) {
      update();
    }
  }
}
