import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../cometchat_chat_uikit.dart';

///[CometchatMessageInformationController] is the view model for [CometChatMessageInformation]
///it contains all the business logic involved in changing the state of the UI of [CometChatMessageInformation]
class CometchatMessageInformationController extends GetxController
    with CometChatMessageEventListener, CometChatGroupEventListener {
  //--------------------Constructor-----------------------
  CometchatMessageInformationController(
    this.parentMessage,
    this.theme,
    this.onError,
  ) {
    if (parentMessage.receiver is Group) {
      group = (parentMessage.receiver as Group);
    } else {
      user = (parentMessage.receiver as User);
    }
  }

  //-------------------------Variable Declaration-----------------------------

  late BaseMessage parentMessage;
  late CometChatTheme theme;
  User? user;
  Group? group;
  List<MessageReceipt> messageReceiptList = [];
  bool isLoading = true;
  bool hasError = false;
  Exception? error;
  final Function(Exception)? onError;
  late String _dateString;
  late String _uiMessageListener;
  late String _uiGroupListener;

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    super.onInit();
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
    messageReceiptList.clear();
    super.onClose();
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    if (isForSameMessage(messageReceipt)) {
      if (messageReceiptList.isEmpty) {
        messageReceipt.deliveredAt ??= messageReceipt.readAt;
        messageReceiptList.add(messageReceipt);
      } else {
        if (parentMessage.receiver is User) {
          messageReceiptList[0].deliveredAt ??= messageReceipt.readAt;
          messageReceiptList[0].readAt = messageReceipt.readAt;
        } else {
          bool add =
              updateMessageList(messageReceiptList, messageReceipt, "read");
          if (add == false) {
            messageReceiptList.add(messageReceipt);
          }
        }
      }
      update();
    }
  }

  bool isForSameMessage(MessageReceipt messageReceipt) {
    if ((messageReceipt.receiverType == ReceiverTypeConstants.group &&
            messageReceipt.receiverId == group?.guid) ||
        (messageReceipt.receiverType == ReceiverTypeConstants.user &&
            messageReceipt.sender.uid == user?.uid)) {
      return true;
    }
    return false;
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    if (isForSameMessage(messageReceipt)) {
      if (messageReceiptList.isEmpty) {
        messageReceiptList.add(messageReceipt);
      } else {
        if (parentMessage.receiver is User) {
          messageReceiptList[0].deliveredAt = messageReceipt.deliveredAt;
        } else {
          bool add = updateMessageList(
              messageReceiptList, messageReceipt, "delivered");
          if (add == false) {
            messageReceiptList.add(messageReceipt);
          }
        }
      }
      update();
    }
  }

  bool updateMessageList(
      List<MessageReceipt> list, MessageReceipt messageReceipt, String type) {
    bool isMatchFound = false;
    for (int i = 0; i < messageReceiptList.length; i++) {
      if (messageReceiptList[i].sender.uid == messageReceipt.sender.uid) {
        if (type == "read") {
          messageReceiptList[i].deliveredAt ??= messageReceipt.readAt;
          messageReceiptList[i].readAt = messageReceipt.readAt;
        } else {
          messageReceiptList[i].deliveredAt = messageReceipt.deliveredAt;
        }
        update();
        isMatchFound = true;
        break;
      }
    }
    return isMatchFound;
  }

  void fetchMessageRecipients(Group? group, BaseMessage baseMessage) {
    messageReceiptList.clear();
    if (parentMessage.receiver is User) {
      messageReceiptList.add(
        MessageReceipt(
          messageId: parentMessage.parentMessageId,
          sender: parentMessage.receiver as User,
          receiverType: parentMessage.receiverType,
          receiverId: parentMessage.receiverUid,
          timestamp: parentMessage.sentAt!,
          receiptType: "",
          deliveredAt: parentMessage.deliveredAt,
          readAt: parentMessage.readAt,
        ),
      );
    } else {
      CometChat.getMessageReceipts(
        baseMessage.id,
        onSuccess: (recipientList) {
          messageReceiptList = recipientList;
          messageReceiptList.removeWhere(
              (element) => element.sender.uid == baseMessage.sender?.uid);
          update();
        },
        onError: onError ??
            (CometChatException e) {
              hasError = true;
              error = e;
              update();
              debugPrint(
                  "Error while retrieving group member recipient list ${e.message}");
            },
      );
    }
    isLoading = false;
    update();
  }
}
