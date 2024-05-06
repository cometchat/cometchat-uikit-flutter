import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

///[CometChatConversationsController] is the view model for [CometChatConversations]
///it contains all the business logic involved in changing the state of the UI of [CometChatConversations]
class CometChatConversationsController
    extends CometChatListController<Conversation, String>
    with
        CometChatSelectable,
        CometChatMessageEventListener,
        CometChatGroupEventListener,
        UserListener,
        GroupListener,
        CometChatUserEventListener,
        CallListener,
        CometChatCallEventListener,
        ConnectionListener
    implements CometChatConversationsControllerProtocol {
  //Constructor
  CometChatConversationsController(
      {required this.conversationsBuilderProtocol,
      SelectionMode? mode,
      required this.theme,
      this.disableSoundForMessages = false,
      this.customSoundForMessages,
      this.disableUsersPresence = false,
      this.disableReceipt = false,
      this.disableTyping,
      this.deleteConversationDialogStyle,
      OnError? onError,
      this.textFormatters,
      this.disableMentions
      })
      : super(conversationsBuilderProtocol.getRequest(), onError: onError) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();

    groupSDKListenerID = "${dateStamp}_group_sdk_listener";
    groupUIListenerID = "${dateStamp}_ui_group_listener";
    messageSDKListenerID = "${dateStamp}_message_sdk_listener";
    messageUIListenerID = "${dateStamp}_ui_message_listener";
    userSDKListenerID = "${dateStamp}_user_sdk_listener";
    _uiUserListener = "${dateStamp}UI_user_listener";
    _conversationListenerId = "${dateStamp}_conversation_listener";
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
  late String _conversationListenerId;

  Map<String, TypingIndicator> typingMap = {};
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
      activeConversation; //active user or groupID, null when no message list is active

  ConversationsStyle? style;

  bool? disableUsersPresence;

  ///[disableTyping] if true stops indicating if a participant in a conversation is typing
  final bool? disableTyping;

  ///[deleteConversationDialogStyle] provides customization for the dialog box that pops up when tapping the delete conversation option
  final ConfirmDialogStyle? deleteConversationDialogStyle;

  ///[textFormatters] is a list of [CometChatTextFormatter] which is used to format the text
  List<CometChatTextFormatter>? textFormatters;

  ///[disableMentions] if true will disable mentions in the conversation
  bool? disableMentions;


  @override
  void onInit() {
    CometChatMessageEvents.addMessagesListener(messageUIListenerID, this);
    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);
    if (!(disableUsersPresence ?? false)) {
      CometChat.addUserListener(userSDKListenerID, this);
    }
    CometChat.addGroupListener(groupSDKListenerID, this);

    CometChatUserEvents.addUsersListener(_uiUserListener, this);
    CometChatCallEvents.addCallEventsListener(_conversationListenerId, this);
    CometChat.addCallListener(_conversationListenerId, this);
    CometChat.addConnectionListener(_conversationListenerId, this);
    initializeTextFormatters();
    super.onInit();
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(messageUIListenerID);
    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    CometChat.removeMessageListener(messageSDKListenerID);
    if (!(disableUsersPresence ?? false)) {
      CometChat.removeUserListener(userSDKListenerID);
    }
    //CometChat.removeGroupListener(groupSDKListenerID);
    CometChatUserEvents.removeUsersListener(_uiUserListener);
    CometChatCallEvents.removeCallEventsListener(_conversationListenerId);
    CometChat.removeCallListener(_conversationListenerId);
    CometChat.removeConnectionListener(_conversationListenerId);
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
    if (disableTyping != true) {
      setTypingIndicator(typingIndicator, true);
    }
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    if (disableTyping != true) {
      setTypingIndicator(typingIndicator, false);
    }
  }

  @override
  void onFormMessageReceived(FormMessage formMessage) {
    _onMessageReceived(formMessage, false);
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    _onMessageReceived(cardMessage, false);
  }

  @override
  void onCustomInteractiveMessageReceived(CustomInteractiveMessage cardMessage) {
    _onMessageReceived(cardMessage, false);
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
    int matchingIndex = list.indexWhere((Conversation conversation) =>
        (conversation.conversationType == ReceiverTypeConstants.user &&
            (conversation.conversationWith as User).uid == user.uid));
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

  @override
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

  @override
  deleteConversation(Conversation conversation) {
    int matchingIndex = getMatchingIndex(conversation);

    deleteConversationFromIndex(matchingIndex);
  }

  @override
  resetUnreadCount(BaseMessage message) {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);
    if (matchingIndex != -1) {
      list[matchingIndex].unreadMessageCount = 0;
      update();
    }
  }

  @override
  updateLastMessage(BaseMessage message) async {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);

    if (matchingIndex != -1) {
      Conversation conversation = list[matchingIndex];
      conversation.lastMessage = message;
      conversation.unreadMessageCount = 0;
      removeElementAt(matchingIndex);
      addElement(conversation);
    } else {
      CometChat.getConversationFromMessage(message,
          onSuccess: (Conversation conversation) {
        addElement(conversation);
      }, onError: (_) {});
    }
  }

  @override
  updateGroup(Group group) {
    int matchingIndex = list.indexWhere((element) =>
        ((element.conversationWith is Group) &&
            ((element.conversationWith as Group).guid == group.guid)));

    if (matchingIndex != -1) {
      list[matchingIndex].conversationWith = group;
      update();
    }
  }

  @override
  removeGroup(String guid) {
    int matchingIndex = list.indexWhere((element) =>
        ((element.conversationWith is Group) &&
            ((element.conversationWith as Group).guid == guid)));

    if (matchingIndex != -1) {
      removeElementAt(matchingIndex);
    }
  }

  @override
  updateLastMessageOnEdited(BaseMessage message) async {
    int matchingIndex = getMatchingIndexFromKey(message.conversationId!);

    if (matchingIndex != -1) {
      if (list[matchingIndex].lastMessage?.id == message.id) {
        list[matchingIndex].lastMessage = message;
        update();
      }
    }
  }

  @override
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
  @override
  updateConversation(Conversation conversation) {
    int matchingIndex = getMatchingIndex(conversation);

    Map<String, dynamic>? metaData = conversation.lastMessage!.metadata;
    bool incrementUnreadCount = false;
    bool isCategoryMessage = (conversation.lastMessage!.category == MessageCategoryConstants.message) ||
        (conversation.lastMessage!.category == MessageCategoryConstants.interactive);
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
  @override
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

  @override
  setTypingIndicator(
      TypingIndicator typingIndicator, bool isTypingStarted) async {
    int matchingIndex;
    if (typingIndicator.receiverType == ReceiverTypeConstants.user) {
      matchingIndex = list.indexWhere((Conversation conversation) =>
          (conversation.conversationType == ReceiverTypeConstants.user &&
              (conversation.conversationWith as User).uid ==
                  typingIndicator.sender.uid));
    } else {
      matchingIndex = list.indexWhere((Conversation conversation) =>
          (conversation.conversationType == ReceiverTypeConstants.group &&
              (conversation.conversationWith as Group).guid ==
                  typingIndicator.receiverId));
    }
    if (matchingIndex != -1) {
      if (isTypingStarted == true) {
          typingMap[list[matchingIndex].conversationId!] = typingIndicator;
      } else {
        if(typingMap.containsKey(list[matchingIndex].conversationId!)){
          typingMap.remove(list[matchingIndex].conversationId!);
        }
      }
      update();
    }
  }

  @override
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
              backgroundColor: deleteConversationDialogStyle?.backgroundColor ??
                  (theme?.palette.mode == PaletteThemeModes.light
                      ? theme?.palette.getBackground()
                      : Color.alphaBlend(theme!.palette.getAccent200(),
                          theme!.palette.getBackground())),
              shadowColor: deleteConversationDialogStyle?.shadowColor ??
                  theme?.palette.getAccent300(),
              confirmButtonTextStyle: TextStyle(
                      fontSize: theme?.typography.text2.fontSize,
                      fontWeight: theme?.typography.text2.fontWeight,
                      color: theme?.palette.getPrimary())
                  .merge(deleteConversationDialogStyle?.confirmButtonTextStyle),
              cancelButtonTextStyle: TextStyle(
                      fontSize: theme?.typography.text2.fontSize,
                      fontWeight: theme?.typography.text2.fontWeight,
                      color: theme?.palette.getPrimary())
                  .merge(deleteConversationDialogStyle?.cancelButtonTextStyle)),
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

  @override
  playNotificationSound(BaseMessage message) {
    //Write all conditions here to stop sound
    if (message.type == MessageTypeConstants.custom &&
        (message.metadata?["incrementUnreadCount"] != true)) {
      return;
    } //not playing sound in case message type is custom and increment counter is not true

    ///checking if [CometChatConversations] is at the top of the navigation stack
    if (context != null && ModalRoute.of(context!)!.isCurrent) {
      //reset active conversation
      if (activeConversation != null) {
        activeConversation = null;
      }
    }
    if (activeConversation == null) {
      //if no message list is open
      CometChatUIKit.soundManager.play(
          sound: Sound.incomingMessageFromOther,
          customSound: customSoundForMessages);
    } else {
      if (activeConversation != message.conversationId) {
        //if open message list has different conversation id then message received conversation id
        CometChatUIKit.soundManager.play(
            sound: Sound.incomingMessage, customSound: customSoundForMessages);
      }
    }
  }

  @override
  bool getHideThreadIndicator(Conversation conversation) {
    if (conversation.lastMessage?.parentMessageId == null) {
      return true;
    } else if (conversation.lastMessage?.parentMessageId == 0) {
      return true;
    } else {
      return false;
    }
  }

  @override
  bool getHideReceipt(Conversation conversation, bool? disableReadReceipt) {
    if (disableReadReceipt == true || conversation.lastMessage == null) {
      return true;
    } else if (conversation.lastMessage!.category ==
        MessageCategoryConstants.call) {
      return true;
    } else if (conversation.lastMessage!.sender!.uid == loggedInUser?.uid) {
      return false;
    } else {
      return true;
    }
  }

  //----------- get last message text-----------

  void initializeTextFormatters(){
    List<CometChatTextFormatter> textFormatters = this.textFormatters ?? [];

    if((textFormatters.isEmpty || textFormatters.indexWhere((element) => element is CometChatMentionsFormatter)==-1) && disableMentions!=true){
      textFormatters.add(CometChatMentionsFormatter());
    }

    this.textFormatters = textFormatters;

  }

  List<CometChatTextFormatter> getTextFormatters(BaseMessage message, CometChatTheme theme){
    List<CometChatTextFormatter> textFormatters = this.textFormatters ?? [];
    if(message is TextMessage){
      for(CometChatTextFormatter textFormatter in textFormatters){
        textFormatter.message = message;
        textFormatter.theme = theme;
      }
    }
    return textFormatters;
  }


  /// ----------------------------EVENT LISTENERS -----------------------------------

  @override
  void onConnected() {
    if(!isLoading) {
      request = conversationsBuilderProtocol.getRequest();
      list = [];
      loadMoreElements(
        isIncluded: (element) => getMatchingIndex(element) != -1,
      );
    }
  }

  @override
  void ccCallAccepted(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void ccOutgoingCall(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void ccCallRejected(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void ccCallEnded(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onIncomingCallReceived(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onOutgoingCallAccepted(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onOutgoingCallRejected(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onIncomingCallCancelled(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onCallEndedMessageReceived(Call call) {
    refreshSingleConversation(call, true);
  }

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    _onMessageReceived(schedulerMessage, false);
  }
}
