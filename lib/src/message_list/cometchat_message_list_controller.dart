import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/src/message_list/messages_builder_protocol.dart';
import 'package:share_plus/share_plus.dart';

import '../../flutter_chat_ui_kit.dart';
import '../../flutter_chat_ui_kit.dart' as cc;

///controller class for [CometChatMessageList]
class CometChatMessageListController
    extends CometChatSearchListController<BaseMessage, int>
    with
        MessageListener,
        GroupListener,
        CometChatGroupEventListener,
        CometChatMessageEventListener {
  //--------------------Constructor-----------------------
  CometChatMessageListController(
      {required this.messagesBuilderProtocol,
      this.user,
      this.group,
      this.customIncomingMessageSound,
      this.customIncomingMessageSoundPackage,
      this.disableSoundForMessages = false,
      this.hideDeletedMessage = false,
      this.scrollToBottomOnNewMessage = false,
      ScrollController? scrollController,
      this.stateCallBack,
      OnError? onError,
      this.onThreadRepliesClick,
      this.messageTypes,
      this.disableReceipt,
      this.theme})
      : super(
            builderProtocol: user != null
                ? (messagesBuilderProtocol
                  ..requestBuilder.uid = user.uid
                  ..requestBuilder.guid = '')
                : (messagesBuilderProtocol
                  ..requestBuilder.guid = group!.guid
                  ..requestBuilder.uid = ''),
            onError: onError) {
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    _messageListenerId = "${dateStamp}user_listener";
    _groupListenerId = "${dateStamp}group_listener";
    _uiGroupListener = "${dateStamp}UIGroupListener";
    _uiMessageListener = "${dateStamp}UI_message_listener";
    createTemplateMap();

    if (user != null) {
      conversationWithId = user!.uid;
      conversationType = ReceiverTypeConstants.user;
    } else {
      conversationWithId = group!.guid;
      conversationType = ReceiverTypeConstants.group;
    }

    if (scrollController != null) {
      messageListScrollController = scrollController;
    } else {
      messageListScrollController = ScrollController();
    }
    messageListScrollController.addListener(_scrollControllerListener);
    tag = "tag$counter";
    counter++;

    threadMessageParentId =
        messagesBuilderProtocol.getRequest().parentMessageId ?? 0;
    isThread = threadMessageParentId > 0;

    messageListId = {};

    if (user != null) {
      messageListId['uid'] = user?.uid;
    }
    if (group != null) {
      messageListId['guid'] = group?.guid;
    }

    if (threadMessageParentId > 0) {
      messageListId['parentMessageId'] = threadMessageParentId;
    }
  }

  //-------------------------Variable Declaration-----------------------------
  late MessagesBuilderProtocol messagesBuilderProtocol;
  late String dateStamp;
  late String _messageListenerId;
  late String _groupListenerId;
  User? loggedInUser;
  User? user;
  Group? group;
  Map<String, CometChatMessageTemplate> templateMap = {};
  List<CometChatMessageTemplate>? messageTypes;
  String conversationWithId = "";
  String conversationType = "";
  String? conversationId;
  Conversation? conversation;
  String? customIncomingMessageSound;
  String? customIncomingMessageSoundPackage;
  late bool disableSoundForMessages;
  int threadMessageParentId = 0;
  late bool hideDeletedMessage;
  late bool scrollToBottomOnNewMessage;
  late ScrollController messageListScrollController;
  int newUnreadMessageCount = 0;
  Function(CometChatMessageListController controller)? stateCallBack;
  static int counter = 0;
  late String tag;
  bool isThread = false;
  late String _uiGroupListener;
  late String _uiMessageListener;
  late BuildContext context;
  final Function(BaseMessage message, BuildContext context,
      {Widget bubbleView})? onThreadRepliesClick;

  late Map<String, dynamic> messageListId;

  bool inInitialized = false;
  CometChatTheme? theme;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

  void _scrollControllerListener() {
    double offset = messageListScrollController.offset;
    if (offset.clamp(0, 10) == offset && newUnreadMessageCount != 0) {
      markAsRead(list[0]);
      newUnreadMessageCount = 0;
      update();
    }
  }

  createTemplateMap() {
    List<CometChatMessageTemplate> localTypes =
        ChatConfigurator.getDataSource().getAllMessageTemplates(theme: theme);

    messageTypes?.forEach((element) {
      templateMap["${element.category}_${element.type}"] = element;
    });

    localTypes.forEach((element) {
      String _key = "${element.category}_${element.type}";

      CometChatMessageTemplate? _localTemplate = templateMap[_key];

      if (_localTemplate == null) {
        templateMap[_key] = element;
      } else {
        if (_localTemplate.footerView == null) {
          templateMap[_key]?.footerView = element.footerView;
        }

        if (_localTemplate.headerView == null) {
          templateMap[_key]?.headerView = element.headerView;
        }

        if (_localTemplate.bottomView == null) {
          templateMap[_key]?.bottomView = element.bottomView;
        }

        if (_localTemplate.bubbleView == null) {
          templateMap[_key]?.bubbleView = element.bubbleView;
        }

        if (_localTemplate.contentView == null) {
          templateMap[_key]?.contentView = element.contentView;
        }

        if (_localTemplate.options == null) {
          templateMap[_key]?.options = element.options;
        }
      }
    });
  }

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    CometChat.addMessageListener(_messageListenerId, this);
    CometChat.addGroupListener(_groupListenerId, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    super.onInit();
  }

  @override
  void onClose() {
    CometChat.removeMessageListener(_messageListenerId);
    CometChat.removeGroupListener(_groupListenerId);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    // removing listeners
    super.onClose();
  }

  //-------------------------Parent List overriding Methods-----------------------------
  @override
  bool match(BaseMessage elementA, BaseMessage elementB) {
    return elementA.id == elementB.id;
  }

  @override
  int getKey(BaseMessage element) {
    return element.id;
  }

  @override
  loadMoreElements({bool Function(BaseMessage element)? isIncluded}) async {
    // "Fetching again"
    isLoading = true;
    BaseMessage? lastMessage;
    loggedInUser ??= await CometChat.getLoggedInUser();
    conversation ??= (await CometChat.getConversation(
        conversationWithId, conversationType, onSuccess: (_conversation) {
      if (_conversation.lastMessage != null) {
        // "Marking as read"
        markAsRead(_conversation.lastMessage!);
      }
    }, onError: (_) {}));
    conversationId ??= conversation?.conversationId;

    try {
      await request.fetchPrevious(onSuccess: (List<BaseMessage> fetchedList) {
        if (fetchedList.isEmpty) {
          isLoading = false;
          hasMoreItems = false;
        } else {
          isLoading = false;
          hasMoreItems = true;

          if (isIncluded == null) {
            list.addAll(fetchedList.reversed);
          } else {
            for (var element in fetchedList.reversed) {
              if (isIncluded(element) == true) {
                list.add(element);
              }
            }
          }
          if (inInitialized == false) {
            lastMessage = fetchedList[0];
          }
          // update();
        }
        update();
      }, onError: (CometChatException e) {
        if (onError != null) {
          onError!(e);
        } else {
          error = e;
          hasError = true;
        }

        update();
      });
    } catch (e, s) {
      error = CometChatException("ERR", s.toString(), "Error");
      hasError = true;
      isLoading = false;
      hasMoreItems = false;
      update();
    }

    if (inInitialized == false) {
      inInitialized = true;
      CometChatUIEvents.onConversationChanged(
          messageListId, lastMessage, user, group);
    }
  }

  //------------------------SDK Message Event Listeners------------------------------

  @override
  void onTextMessageReceived(TextMessage textMessage) async {
    _onMessageReceived(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    _onMessageReceived(mediaMessage);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    _onMessageReceived(customMessage);
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    if (disableReceipt != true) {
      if (group != null) return;

      for (int i = 0; i < list.length; i++) {
        if (list[i].sender?.uid == loggedInUser?.uid) {
          if (i == 0 || list[i].deliveredAt == null) {
            list[i].deliveredAt = messageReceipt.deliveredAt;
          } else {
            break;
          }
        }
      }
      update();
    }
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    if (disableReceipt != true) {
      if (group != null) return;

      for (int i = 0; i < list.length; i++) {
        if (list[i].sender?.uid == loggedInUser?.uid) {
          if (i == 0 || list[i].readAt == null) {
            list[i].readAt = messageReceipt.readAt;
          } else {
            break;
          }
        }
      }
      update();
    }
  }

  @override
  void onMessageEdited(BaseMessage message) {
    if (conversationId == message.conversationId ||
        _checkIfSameConversationForReceivedMessage(message)) {
      updateElement(message);
    }
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    if (conversationId == message.conversationId ||
        _checkIfSameConversationForReceivedMessage(message)) {
      if (request.hideDeleted == true) {
        removeElement(message);
      } else {
        updateElement(message);
      }
    }
  }

  //------------------------SDK Group Event Listeners------------------------------
  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    if (group?.guid == addedTo.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void onGroupMemberJoined(
      cc.Action action, User joinedUser, Group joinedGroup) {
    if (group?.guid == joinedGroup.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (group?.guid == leftGroup.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    if (group?.guid == kickedFrom.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (group?.guid == bannedFrom.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (group?.guid == bannedFrom.guid) {
      _onMessageFromLoggedInUser(message);
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (group?.guid == kickedFrom.guid) {
      _onMessageFromLoggedInUser(message);
    }
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    if (group?.guid == groupAddedIn.guid) {
      for (var message in messages) {
        _onMessageFromLoggedInUser(message);
      }
    }
  }

  @override
  void ccGroupMemberUnbanned(cc.Action message, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    if (group?.guid == unbannedFrom.guid) {
      _onMessageFromLoggedInUser(message);
    }
  }

  @override
  void onGroupMemberUnbanned(cc.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    if (group?.guid == unbannedFrom.guid) {
      _onMessageReceived(action);
    }
  }

  @override
  void onGroupMemberScopeChanged(
      cc.Action action,
      User updatedBy,
      User updatedUser,
      String scopeChangedTo,
      String scopeChangedFrom,
      Group group) {
    if (group.guid == this.group?.guid) {
      _onMessageReceived(action);
    }
  }

  //------------------------UI Message Event Listeners------------------------------

  @override
  ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    //checking if same conversation
    if (_checkIfSameConversationForSenderMessage(message)) {
      //checking if same thread
      if (message.parentMessageId == threadMessageParentId) {
        //adding the message to list for optimistic ui
        if (messageStatus == MessageStatus.inProgress) {
          addMessage(message);
        } else if (messageStatus == MessageStatus.sent ||
            messageStatus == MessageStatus.error) {
          //updating the status of the message that was previously added to list
          //while in progress
          updateMessageWithMuid(message);
        }
      } else {
        //check if same conversation but different thread
        if (messageStatus == MessageStatus.sent) {
          updateMessageThreadCount(message.parentMessageId);
        }
      }
    }
  }

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (_checkIfSameConversationForSenderMessage(message) &&
        status == MessageEditStatus.success) {
      updateElement(message);
    }
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (_checkIfSameConversationForSenderMessage(message) &&
        messageStatus == EventStatus.success) {
      if (request.hideDeleted == true) {
        removeElement(message);
      } else {
        updateElement(message);
      }
    }
  }

  //---------------Public Methods----------------------
  addMessage(BaseMessage message) {
    if (list.isNotEmpty) {
      markAsRead(list[0]);
    }
    if (messageListScrollController.hasClients) {
      messageListScrollController.jumpTo(0.0);
    }
    addElement(message);
  }

  updateMessageWithMuid(BaseMessage message) {
    int matchingIndex =
        list.indexWhere((element) => (element.muid == message.muid));
    if (matchingIndex != -1) {
      list[matchingIndex] = message;
      update();
    }
  }

  deleteMessage(BaseMessage message) async {
    await CometChat.deleteMessage(message.id, onSuccess: (updatedMessage) {
      updatedMessage.deletedAt ??= DateTime.now();
      // CometChatMessageEvents.ccMessageDeleted(
      //     updatedMessage, EventStatus.success);
      message.deletedAt = DateTime.now();
      message.deletedBy = loggedInUser?.uid;
      CometChatMessageEvents.ccMessageDeleted(
          updatedMessage, EventStatus.success);
    }, onError: (_) {});
  }

  updateMessageThreadCount(int parentMessageId) {
    int matchingIndex = list.indexWhere((item) => item.id == parentMessageId);
    if (matchingIndex != -1) {
      list[matchingIndex].replyCount++;
      update();
    }
  }

  _playSound() {
    if (!disableSoundForMessages) {
      SoundManager.play(
          sound: Sound.incomingMessage,
          customSound: customIncomingMessageSound,
          packageName: customIncomingMessageSound == null ||
                  customIncomingMessageSound == ""
              ? UIConstants.packageName
              : customIncomingMessageSoundPackage);
    }
  }

  markAsRead(BaseMessage _message) {
    if (disableReceipt != true &&
        _message.sender?.uid != loggedInUser?.uid &&
        _message.readAt == null) {
      CometChat.markAsRead(_message, onSuccess: (String res) {
        CometChatMessageEvents.ccMessageRead(_message);
      }, onError: (e) {});
    }
  }

  _onMessageReceived(BaseMessage message) {
    if ((message.conversationId == conversationId ||
            _checkIfSameConversationForReceivedMessage(message) ||
            _checkIfSameConversationForSenderMessage(message)) &&
        message.parentMessageId == threadMessageParentId) {
      addElement(message);
      _playSound();

      if (scrollToBottomOnNewMessage) {
        markAsRead(message);
        if (messageListScrollController.hasClients) {
          messageListScrollController.jumpTo(0.0);
        }
      } else {
        if (messageListScrollController.hasClients &&
            messageListScrollController.offset > 100) {
          newUnreadMessageCount++;
        } else {
          markAsRead(message);
        }
      }
    } else if (message.conversationId == conversationId ||
        _checkIfSameConversationForReceivedMessage(message)) {
      //incrementing reply count
      _playSound();
      int matchingIndex =
          list.indexWhere((element) => (element.id == message.parentMessageId));
      if (matchingIndex != -1) {
        list[matchingIndex].replyCount++;
      }
      update();
    }
  }

  _onMessageFromLoggedInUser(BaseMessage message) {
    if ((message.conversationId == conversationId ||
            _checkIfSameConversationForSenderMessage(message)) &&
        message.parentMessageId == threadMessageParentId) {
      addElement(message);
      _playSound();

      if (scrollToBottomOnNewMessage) {
        markAsRead(message);
        if (messageListScrollController.hasClients) {
          messageListScrollController.jumpTo(0.0);
        }
      } else {
        if (messageListScrollController.hasClients &&
            messageListScrollController.offset > 100) {
          newUnreadMessageCount++;
        } else {
          markAsRead(message);
        }
      }
    } else if (message.conversationId == conversationId ||
        _checkIfSameConversationForSenderMessage(message)) {
      //incrementing reply count
      _playSound();
      int matchingIndex =
          list.indexWhere((element) => (element.id == message.parentMessageId));
      if (matchingIndex != -1) {
        list[matchingIndex].replyCount++;
      }
      update();
    }
  }

  //-----message option methods-----

  _messageEdit(BaseMessage message, CometChatMessageListController state) {
    if (message.deletedAt == null) {
      CometChatMessageEvents.ccMessageEdited(
          message, MessageEditStatus.inProgress);
    }
  }

  _delete(BaseMessage message, CometChatMessageListController state) {
    if (message.deletedAt == null) {
      CometChatMessageEvents.ccMessageDeleted(message, EventStatus.inProgress);
      deleteMessage(message);
    }
  }

  // _replyMessage(BaseMessage message, CometChatMessageListController state) {
  //   CometChatMessageEvents.onMessageReply(message);
  // }

  _shareMessage(BaseMessage message, CometChatMessageListController state) {
    //share
    if (message is TextMessage) {
      Share.share(message.text);
    } else if (message is MediaMessage) {
      //Share.shareFiles(['${directory.path}/image.jpg']);
    }
  }

  _copyMessage(BaseMessage message, CometChatMessageListController state) {
    if (message is TextMessage) {
      Clipboard.setData(ClipboardData(text: message.text));
    }
  }

  _forwardMessage(BaseMessage message, CometChatMessageListController state) {
    //forward
  }

  _replyInThread(BaseMessage message, CometChatMessageListController state) {
    // CometChatMessageEvents.onReplyInThread(message);
    //
    // if(onThreadRepliesClick!=null){
    //   onThreadRepliesClick(message, context ,  )
    //
    // }
    // Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => CometChatThreadedMessages(
    //               parentMessage: message, loggedInUser: loggedInUser!,
    //               //bubbleView: ,
    //             )));
  }

  Function(BaseMessage message, CometChatMessageListController state)?
      getActionFunction(String id) {
    switch (id) {
      case MessageOptionConstants.editMessage:
        {
          return _messageEdit;
        }
      case MessageOptionConstants.deleteMessage:
        {
          return _delete;
        }
      // case MessageOptionConstants.replyMessage:
      //   {
      //     return _replyMessage;
      //   }
      case MessageOptionConstants.shareMessage:
        {
          return _shareMessage;
        }
      case MessageOptionConstants.copyMessage:
        {
          return _copyMessage;
        }
      case MessageOptionConstants.forwardMessage:
        {
          return _forwardMessage;
        }
      case MessageOptionConstants.replyInThreadMessage:
        {
          return _replyInThread;
        }
      default:
        {
          return null;
        }
    }
  }

  @override
  void ccGroupMemberScopeChanged(cc.Action message, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    if (group.guid == this.group?.guid) {
      _onMessageFromLoggedInUser(message);
    }
  }

  bool _checkIfSameConversationForReceivedMessage(BaseMessage message) {
    return (message.receiverType == CometChatReceiverType.user &&
            user?.uid == message.sender?.uid) ||
        (message.receiverType == CometChatReceiverType.group &&
            group?.guid == message.receiverUid);
  }

  bool _checkIfSameConversationForSenderMessage(BaseMessage message) {
    return (message.receiverType == CometChatReceiverType.user &&
            user?.uid == message.receiverUid) ||
        (message.receiverType == CometChatReceiverType.group &&
            group?.guid == message.receiverUid);
  }

  BubbleContentVerifier checkBubbleContent(
      BaseMessage messageObject, ChatAlignment alignment) {
    bool isMessageSentByMe = messageObject.sender?.uid == loggedInUser?.uid;

    BubbleAlignment _alignment = BubbleAlignment.right;
    bool _thumbnail = false;
    bool _name = false;
    bool _readReceipt = true;
    bool _enableFooterView = true;

    if (alignment == ChatAlignment.standard) {
      //-----if message is group action-----
      if (messageObject.category == MessageCategoryConstants.action) {
        _thumbnail = false;
        _name = false;
        _readReceipt = false;
        _alignment = BubbleAlignment.center;
        _enableFooterView = false;
      }
      //-----if message sent by me-----
      else if (isMessageSentByMe) {
        _thumbnail = false;
        _name = false;
        _readReceipt = true;
        _alignment = BubbleAlignment.right;
      }
      //-----if message received in user conversation-----
      else if (user != null) {
        _thumbnail = false;
        _name = false;
        _readReceipt = false;
        _alignment = BubbleAlignment.left;
      }
      //-----if message received in group conversation-----
      else if (group != null) {
        _thumbnail = true;
        _name = true;
        _readReceipt = false;
        _alignment = BubbleAlignment.left;
      }
    } else if (alignment == ChatAlignment.leftAligned) {
      //-----if message is  action message -----
      if (messageObject.category == MessageCategoryConstants.action) {
        _thumbnail = false;
        _name = false;
        _readReceipt = false;
        _alignment = BubbleAlignment.center;
        _enableFooterView = false;
      }
      //-----if message sent by me-----
      else if (isMessageSentByMe) {
        _thumbnail = true;
        _name = true;
        _readReceipt = true;
        _alignment = BubbleAlignment.left;
      }
      //-----if message received in user conversation-----
      else if (user != null) {
        _thumbnail = true;
        _name = true;
        _readReceipt = false;
        _alignment = BubbleAlignment.left;
      }
      //-----if message received in group conversation-----
      else if (group != null) {
        _thumbnail = true;
        _name = true;
        _readReceipt = false;
        _alignment = BubbleAlignment.left;
      }
    }

    if (disableReceipt == true) {
      _readReceipt = false;
    }

    return BubbleContentVerifier(
        showThumbnail: _thumbnail,
        showFooterView: _enableFooterView,
        showName: _name,
        showReadReceipt: _readReceipt,
        alignment: _alignment);
  }
}

class BubbleContentVerifier {
  bool showThumbnail;
  bool showName;
  bool showReadReceipt;
  bool showFooterView;
  BubbleAlignment alignment;

  BubbleContentVerifier(
      {this.showThumbnail = false,
      this.showName = false,
      this.showReadReceipt = true,
      this.showFooterView = true,
      this.alignment = BubbleAlignment.right});
}
