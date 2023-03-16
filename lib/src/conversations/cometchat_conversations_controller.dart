import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

///[CometChatConversationsController] is the View Model for the [CometChatConversations] component
///it handles the business logic
class CometChatConversationsController
    extends CometChatListController<Conversation, String>
    with
        CometChatSelectable,
        CometChatMessageEventListener,
        CometChatGroupEventListener,
        MessageListener,
        UserListener,
        GroupListener,
        CometChatUserEventListener {
  //Constructor
  CometChatConversationsController(
      {required this.conversationsBuilderProtocol,
      SelectionMode? mode,
      required this.theme,
      this.disableSoundForMessages = false,
      this.customSoundForMessages,
      this.disableUsersPresence,
      this.disableReceipt = false,
      OnError? onError})
      : super(conversationsBuilderProtocol.getRequest(), onError: onError) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();

    groupSDKListenerID = "${dateStamp}_group_sdk_listener";
    groupUIListenerID = "${dateStamp}_ui_group_listener";
    messageSDKListenerID = "${dateStamp}_message_sdk_listener";
    messageUIListenerID = "${dateStamp}_ui_message_listener";
    userSDKListenerID = "${dateStamp}_user_sdk_listener";
    _uiUserListener = "${dateStamp}UI_user_listener";
  }

  late ConversationsBuilderProtocol conversationsBuilderProtocol;
  late String dateStamp;
  BuildContext? context;
  late String groupSDKListenerID;
  late String groupUIListenerID;
  late String messageSDKListenerID;
  late String messageUIListenerID;
  late String userSDKListenerID;
  late String _uiUserListener;

  Set<String> typingIndicatorMap = {};
  User? loggedInUser;

  ///[disableSoundForMessages] if true will disable sound for messages
  final bool? disableSoundForMessages;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  ///[customSoundForMessages] URL of the audio file to be played upon receiving messages
  final String? customSoundForMessages;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

  String loggedInUserId = "";
  String?
      activeID; //active user or groupID, null when no message list is active

  ConversationsStyle? style;

  bool? disableUsersPresence;

  @override
  void onInit() {
    CometChatMessageEvents.addMessagesListener(messageUIListenerID, this);

    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);

    CometChat.addMessageListener(messageSDKListenerID, this);
    if (disableUsersPresence == false) {
      CometChat.addUserListener(userSDKListenerID, this);
    }
    CometChat.addGroupListener(groupSDKListenerID, this);

    CometChatUserEvents.addUsersListener(_uiUserListener, this);
    super.onInit();
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(messageUIListenerID);
    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    CometChat.removeMessageListener(messageSDKListenerID);
    if (disableUsersPresence == false) {
      CometChat.removeUserListener(userSDKListenerID);
    }
    CometChat.removeGroupListener(groupSDKListenerID);
    CometChatUserEvents.removeUsersListener(_uiUserListener);
    super.onClose();
  }

  @override
  bool match(Conversation elementA, Conversation elementB) {
    return elementA.conversationId == elementB.conversationId;
  }

  @override
  String getKey(Conversation element) {
    return element.conversationId!;
  }

  @override
  loadMoreElements({bool Function(Conversation element)? isIncluded}) async {
    loggedInUser ??= await CometChat.getLoggedInUser();
    if (loggedInUser != null) {
      loggedInUserId = loggedInUser!.uid;
    }
    await super.loadMoreElements();
  }

  @override
  void ccMessageRead(BaseMessage message) {
    resetUnreadCount(message);
  }

  @override
  void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    if (messageStatus == MessageStatus.sent) {
      updateLastMessage(message);
    }
  }

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.success) {
      updateLastMessageOnEdited(message);
    }
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    updateLastMessageOnEdited(message);
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (messageStatus == EventStatus.success) {
      updateLastMessageOnEdited(message);
    }
  }

  @override
  ccOwnershipChanged(Group group, GroupMember newOwner) {
    updateGroup(group);
  }

  @override
  ccGroupLeft(cc.Action message, User leftUser, Group leftGroup) {
    removeGroup(leftGroup.guid);
  }

  @override
  void ccGroupDeleted(Group group) {
    removeGroup(group.guid);
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    refreshSingleConversation(messages.last, true);
  }

  //-----------Message Listeners------------------------------------------------

  _onMessageReceived(BaseMessage message, bool isActionMessage) {
    if (message.sender!.uid != loggedInUserId && disableReceipt != true) {
      CometChat.markAsDelivered(message, onSuccess: (_) {}, onError: (_) {});
    }
    if (disableSoundForMessages == false) {
      playNotificationSound(message);
    }

    refreshSingleConversation(message, isActionMessage);
  }

  @override
  void onTextMessageReceived(TextMessage textMessage) async {
    _onMessageReceived(textMessage, false);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) async {
    _onMessageReceived(mediaMessage, false);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) async {
    _onMessageReceived(customMessage, false);
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    if (messageReceipt.receiverType == ReceiverTypeConstants.user &&
        disableReceipt != true) {
      setReceipts(messageReceipt);
    }
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    if (messageReceipt.receiverType == ReceiverTypeConstants.user &&
        disableReceipt != true) {
      setReceipts(messageReceipt);
    }
  }

  @override
  void onMessageEdited(BaseMessage message) {
    updateLastMessageOnEdited(message);
  }

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    setTypingIndicator(typingIndicator, true);
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    setTypingIndicator(typingIndicator, false);
  }

  //----------------Message Listeners end----------------------------------------------

  //----------------User Listeners-----------------------------------------------------
  @override
  void onUserOnline(User user) {
    updateUserStatus(user, UserStatusConstants.online);
  }

  @override
  void onUserOffline(User user) {
    updateUserStatus(user, UserStatusConstants.offline);
  }

  @override
  void ccUserBlocked(User user) {
    int matchingIndex = list.indexWhere((Conversation _conversation) =>
        (_conversation.conversationType == ReceiverTypeConstants.user &&
            (_conversation.conversationWith as User).uid == user.uid));
    removeElementAt(matchingIndex);
  }

  //----------------User Listeners end----------------------------------------------
  //----------------Group Listeners-----------------------------------------------------

  @override
  onGroupMemberJoined(cc.Action action, User joinedUser, Group joinedGroup) {
    refreshSingleConversation(action, true);
  }

  @override
  onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (loggedInUserId == leftUser.uid) {
      refreshSingleConversation(action, true, remove: true);
    } else {
      refreshSingleConversation(action, true);
    }
  }

  @override
  onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    if (loggedInUserId == kickedUser.uid) {
      refreshSingleConversation(action, true, remove: true);
    } else {
      refreshSingleConversation(action, true);
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (loggedInUserId == kickedUser.uid) {
      refreshSingleConversation(message, true, remove: true);
    } else {
      refreshSingleConversation(message, true);
    }
  }

  @override
  onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (loggedInUserId == bannedUser.uid) {
      refreshSingleConversation(action, true, remove: true);
    } else {
      refreshSingleConversation(action, true);
    }
  }

  @override
  onGroupMemberUnbanned(cc.Action action, User unbannedUser, User unbannedBy,
      Group unbannedFrom) {
    refreshSingleConversation(action, true);
  }

  @override
  onGroupMemberScopeChanged(cc.Action action, User updatedBy, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    refreshSingleConversation(action, true);
  }

  @override
  onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    refreshSingleConversation(action, true);
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (loggedInUserId == bannedUser.uid) {
      refreshSingleConversation(message, true, remove: true);
    } else {
      refreshSingleConversation(message, true);
    }
  }
  //----------------Group Listeners end----------------------------------------------

  updateUserStatus(User user, String status) {
    int matchingIndex = list.indexWhere((element) =>
        (element.conversationType == ReceiverTypeConstants.user &&
            (element.conversationWith as User).uid == user.uid));

    if (matchingIndex != -1) {
      (list[matchingIndex].conversationWith as User).status = status;
      update();
    }
  }

  //------------------------------------------------------------------------

  //----------------Public Methods -----------------------------------------------------

  deleteConversation(Conversation conversation) {
    int _matchingIndex = getMatchingIndex(conversation);

    deleteConversationFromIndex(_matchingIndex);
  }

  resetUnreadCount(BaseMessage message) {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);
    if (matchingIndex != -1) {
      list[matchingIndex].unreadMessageCount = 0;
      update();
    }
  }

  updateLastMessage(BaseMessage message) {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);

    if (matchingIndex != -1) {
      Conversation conversation = list[matchingIndex];
      conversation.lastMessage = message;
      conversation.unreadMessageCount = 0;
      removeElementAt(matchingIndex);
      addElement(conversation);
    }
  }

  updateGroup(Group group) {
    int matchingIndex = list.indexWhere((element) =>
        ((element.conversationWith is Group) &&
            ((element.conversationWith as Group).guid == group.guid)));

    if (matchingIndex != -1) {
      list[matchingIndex].conversationWith = group;
      update();
    }
  }

  removeGroup(String guid) {
    int matchingIndex = list.indexWhere((element) =>
        ((element.conversationWith is Group) &&
            ((element.conversationWith as Group).guid == guid)));

    if (matchingIndex != -1) {
      removeElementAt(matchingIndex);
    }
  }

  updateLastMessageOnEdited(BaseMessage message) async {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);

    if (matchingIndex != -1) {
      if (list[matchingIndex].lastMessage?.id == message.id) {
        list[matchingIndex].lastMessage = message;
        update();
      }
    }
  }

  refreshSingleConversation(BaseMessage message, bool isActionMessage,
      {bool? remove}) async {
    CometChat.getConversationFromMessage(message,
        onSuccess: (Conversation conversation) {
      conversation.lastMessage = message;
      conversation.updatedAt = message.updatedAt;
      if (remove == true) {
        removeElement(conversation);
      } else {
        updateConversation(conversation);
      }
    }, onError: (_) {});
  }

  ///Update the conversation with new conversation Object matched according to conversation id ,  if not matched inserted at top
  updateConversation(Conversation conversation) {
    int matchingIndex = getMatchingIndex(conversation);

    Map<String, dynamic>? metaData = conversation.lastMessage!.metadata;
    bool incrementUnreadCount = false;
    bool isCategoryMessage = (conversation.lastMessage!.category == "message");
    if (metaData != null) {
      if (metaData.containsKey("incrementUnreadCount")) {
        incrementUnreadCount = metaData["incrementUnreadCount"] as bool;
      }
    }

    if (matchingIndex != -1) {
      Conversation oldConversation = list[matchingIndex];

      if ((incrementUnreadCount || isCategoryMessage) &&
          conversation.lastMessage?.sender?.uid != loggedInUserId) {
        conversation.unreadMessageCount =
            (oldConversation.unreadMessageCount ?? 0) + 1;
      } else {
        conversation.unreadMessageCount = oldConversation.unreadMessageCount;
      }
      removeElementAt(matchingIndex);
      addElement(conversation);
    } else {
      if ((incrementUnreadCount || isCategoryMessage) &&
          conversation.lastMessage?.sender?.uid != loggedInUserId) {
        int oldCount = conversation.unreadMessageCount ?? 0;
        conversation.unreadMessageCount = oldCount + 1;
      }
      addElement(conversation);
    }

    update();
  }

//Set Receipt for
  setReceipts(MessageReceipt receipt) {
    for (int i = 0; i < list.length; i++) {
      Conversation conversation = list[i];
      if (conversation.conversationType == ReceiverTypeConstants.user &&
          receipt.sender.uid == ((conversation.conversationWith as User).uid)) {
        BaseMessage? lastMessage = conversation.lastMessage;

        //Check if receipt type is delivered
        if (lastMessage != null &&
            lastMessage.deliveredAt == null &&
            receipt.receiptType == ReceiptTypeConstants.delivered &&
            receipt.messageId == lastMessage.id) {
          lastMessage.deliveredAt = receipt.deliveredAt;
          list[i].lastMessage = lastMessage;
          update();
          break;
        } else if (lastMessage != null &&
            lastMessage.readAt == null &&
            receipt.receiptType == ReceiptTypeConstants.read &&
            receipt.messageId == lastMessage.id) {
          //if receipt type is read
          lastMessage.readAt = receipt.readAt;
          list[i].lastMessage = lastMessage;
          update();

          break;
        }
      }
    }
  }

  setTypingIndicator(
      TypingIndicator typingIndicator, bool isTypingStarted) async {
    int matchingIndex;
    if (typingIndicator.receiverType == ReceiverTypeConstants.user) {
      matchingIndex = list.indexWhere((Conversation _conversation) =>
          (_conversation.conversationType == ReceiverTypeConstants.user &&
              (_conversation.conversationWith as User).uid ==
                  typingIndicator.sender.uid));
    } else {
      matchingIndex = list.indexWhere((Conversation _conversation) =>
          (_conversation.conversationType == ReceiverTypeConstants.group &&
              (_conversation.conversationWith as Group).guid ==
                  typingIndicator.receiverId));
    }

    if (matchingIndex != -1) {
      if (isTypingStarted == true) {
        typingIndicatorMap.add(list[matchingIndex].conversationId!);
      } else {
        typingIndicatorMap.remove(list[matchingIndex].conversationId!);
      }
      update();
    }
  }

  void deleteConversationFromIndex(int index) async {
    late String conversationWith;
    late String conversationType;
    if (list[index].conversationType.toLowerCase() ==
        ReceiverTypeConstants.group.toLowerCase()) {
      conversationWith = (list[index].conversationWith as Group).guid;
      conversationType = ReceiverTypeConstants.group;
    } else {
      conversationWith = (list[index].conversationWith as User).uid;
      conversationType = ReceiverTypeConstants.user;
    }
    if (context != null) {
      showCometChatConfirmDialog(
          context: context!,
          confirmButtonText: Translations.of(context!).delete_capital,
          cancelButtonText: Translations.of(context!).cancel_capital,
          messageText: Text(
            Translations.of(context!).delete_confirm,
            style: TextStyle(
                fontSize: theme?.typography.title2.fontSize,
                fontWeight: theme?.typography.title2.fontWeight,
                color: theme?.palette.getAccent(),
                fontFamily: theme?.typography.title2.fontFamily),
          ),
          onCancel: () {
            Navigator.pop(context!);
          },
          style: ConfirmDialogStyle(
              backgroundColor: theme?.palette.mode == PaletteThemeModes.light
                  ? theme?.palette.getBackground()
                  : Color.alphaBlend(theme!.palette.getAccent200(),
                      theme!.palette.getBackground()),
              shadowColor: theme?.palette.getAccent300(),
              confirmButtonTextStyle: TextStyle(
                  fontSize: theme?.typography.text2.fontSize,
                  fontWeight: theme?.typography.text2.fontWeight,
                  color: theme?.palette.getPrimary()),
              cancelButtonTextStyle: TextStyle(
                  fontSize: theme?.typography.text2.fontSize,
                  fontWeight: theme?.typography.text2.fontWeight,
                  color: theme?.palette.getPrimary())),
          onConfirm: () async {
            await CometChat.deleteConversation(
                conversationWith, conversationType, onSuccess: (_) {
              removeElementAt(index);
              CometChatConversationEvents.ccConversationDeleted(list[index]);
            }, onError: onError);
            Navigator.pop(context!);
            update();
          });
    }
  }

  playNotificationSound(BaseMessage message) {
    //Write all conditions here to stop sound
    if (message.type == MessageTypeConstants.custom &&
        (message.metadata?["incrementUnreadCount"] != true)) {
      return;
    } //not playing sound in case message type is custom and increment counter is not true
    if (activeID == null) {
      //if no message list is open
      SoundManager.play(
          sound: Sound.incomingMessageFromOther,
          customSound: customSoundForMessages);
    } else {
      if (activeID != message.conversationId) {
        //if open message list has different conversation id then message received conversation id
        SoundManager.play(
            sound: Sound.incomingMessage, customSound: customSoundForMessages);
      }
    }
  }

  bool getHideThreadIndicator(Conversation conversation) {
    if (conversation.lastMessage?.parentMessageId == null) {
      return true;
    } else if (conversation.lastMessage?.parentMessageId == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool getHideReceipt(Conversation conversation, bool? disableReadReceipt) {
    if (disableReadReceipt == true || conversation.lastMessage == null) {
      return true;
    } else if (conversation.lastMessage!.sender!.uid == loggedInUser?.uid) {
      return false;
    } else {
      return true;
    }
  }

  //----------- get last message text-----------
  String getLastMessage(Conversation conversation, BuildContext context) {
    BaseMessage? lastMessage = conversation.lastMessage;
    String? messageCategory = lastMessage?.category;

    if (messageCategory == null || lastMessage == null) {
      return '';
    } else if (lastMessage.deletedBy != null &&
        lastMessage.deletedBy!.trim() != '') {
      return cc.Translations.of(context).this_message_deleted;
    } else {
      return ChatConfigurator.getDataSource()
          .getLastConversationMessage(conversation, context);

      // ConversationUtils.getLastConversationMessage(
      //   conversation, context);
    }
  }
}
