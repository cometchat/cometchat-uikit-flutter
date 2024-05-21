import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../cometchat_chat_uikit.dart';

///[CometChatThreadedMessageController] is the view model for [CometChatThreadedMessages]
///it contains all the business logic involved in changing the state of the UI of [CometChatThreadedMessages]
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
  late String _uiGroupListener;
  CometChatMessageComposerController? composerState;
  static int counter = 0;
  late String tag;
  late int replyCount;

  final GlobalKey messageComposerKey = GlobalKey();

  Widget? composerPlaceHolder;
  void getComposerPlaceHolder() {
    BuildContext? context = messageComposerKey.currentContext;
    if (context == null) {
      composerPlaceHolder = const SizedBox();
    } else {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;

      composerPlaceHolder = SizedBox(
        height: size.height,
      );
    }
    update();
  }

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    super.onInit();
    counter++;
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiMessageListener = "${_dateString}UI_message_listener";
    _uiGroupListener = "${_dateString}UI_group_listener";
    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
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

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    if (textMessage.parentMessageId == parentMessage.id) {
      replyCount++;
      update();
    }
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    if (mediaMessage.parentMessageId == parentMessage.id) {
      replyCount++;
      update();
    }
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    if (customMessage.parentMessageId == parentMessage.id) {
      replyCount++;
      update();
    }
  }

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    if (schedulerMessage.parentMessageId == parentMessage.id) {
      replyCount++;
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
