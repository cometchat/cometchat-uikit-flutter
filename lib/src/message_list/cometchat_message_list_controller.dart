import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cometchat_chat_uikit/src/message_list/messages_builder_protocol.dart';
import 'package:get/get.dart';

import '../../cometchat_chat_uikit.dart';
import '../../cometchat_chat_uikit.dart' as cc;

///[CometChatMessageListController] is the view model for [CometChatMessageList]
///it contains all the business logic involved in changing the state of the UI of [CometChatMessageList]
class CometChatMessageListController
    extends CometChatSearchListController<BaseMessage, int>
    with
        GroupListener,
        CometChatGroupEventListener,
        CometChatMessageEventListener,
        CometChatUIEventListener,
        CometChatCallEventListener,
        CallListener,
        ConnectionListener
    implements CometChatMessageListControllerProtocol {
  //--------------------Constructor-----------------------
  CometChatMessageListController({
    required this.messagesBuilderProtocol,
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
    this.theme,
    // this.snackBarConfiguration,
    this.messageInformationConfiguration,
    this.emojiKeyboardStyle,
    this.disableReactions
  }) : super(
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
    _uiEventListener = "${dateStamp}UI_Event_listener";
    _uiCallListener = "${dateStamp}UI_Call_listener";
    _sdkCallListenerId = "${dateStamp}sdk_Call_listener";

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

  // final SnackBarConfiguration? snackBarConfiguration;

  MessageInformationConfiguration? messageInformationConfiguration;

  bool inInitialized = false;
  CometChatTheme? theme;

  ///[emojiKeyboardStyle] is a parameter used to set the style for the emoji keyboard
  final EmojiKeyboardStyle? emojiKeyboardStyle;

  ///[disableReceipt] controls visibility of read receipts
  ///and also disables logic executed inside onMessagesRead and onMessagesDelivered listeners
  final bool? disableReceipt;

  late String _uiEventListener;
  late String _uiCallListener;
  late String _sdkCallListenerId;

  ///[headerView] shown in header view
  Widget? Function(BuildContext,
      {User? user, Group? group, int? parentMessageId})? headerView;

  ///[footerView] shown in footer view
  Widget? Function(BuildContext,
      {User? user, Group? group, int? parentMessageId})? footerView;

  final bool? disableReactions;

  Widget? header;
  Widget? footer;

  int? initialUnreadCount;

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
    CometChatUIKit.getDataSource().getAllMessageTemplates(theme: theme);

    messageTypes?.forEach((element) {
      templateMap["${element.category}_${element.type}"] = element;
    });

    for (var element in localTypes) {
      String key = "${element.category}_${element.type}";

      CometChatMessageTemplate? localTemplate = templateMap[key];

      if (localTemplate == null) {
        templateMap[key] = element;
      } else {
        if (localTemplate.footerView == null) {
          templateMap[key]?.footerView = element.footerView;
        }

        if (localTemplate.headerView == null) {
          templateMap[key]?.headerView = element.headerView;
        }

        if (localTemplate.bottomView == null) {
          templateMap[key]?.bottomView = element.bottomView;
        }

        if (localTemplate.bubbleView == null) {
          templateMap[key]?.bubbleView = element.bubbleView;
        }

        if (localTemplate.contentView == null) {
          templateMap[key]?.contentView = element.contentView;
        }

        if (localTemplate.options == null) {
          templateMap[key]?.options = element.options;
        }
      }
    }
  }

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    CometChat.addGroupListener(_groupListenerId, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    CometChatUIEvents.addUiListener(_uiEventListener, this);
    CometChatCallEvents.addCallEventsListener(_uiCallListener, this);
    CometChat.addCallListener(_sdkCallListenerId, this);
    CometChat.addConnectionListener(_messageListenerId, this);
    initializeHeaderAndFooterView();
    super.onInit();
  }

  @override
  void onClose() {
    //  CometChat.removeMessageListener(_messageListenerId);
    CometChat.removeGroupListener(_groupListenerId);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    CometChatUIEvents.removeUiListener(_uiEventListener);
    CometChatCallEvents.removeCallEventsListener(_uiCallListener);
    CometChat.removeCallListener(_sdkCallListenerId);
    CometChat.removeConnectionListener(_messageListenerId);
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

  Future<Null> getUnreadCount() async {
    if (initialUnreadCount == null) {
      Map<String, Map<String, int>>? resultMap =
      await CometChat.getUnreadMessageCount();

      if (resultMap != null) {
        Map<String, int> countMap = {};

        if (user != null) {
          countMap = resultMap["user"] ?? {};
        } else if (group != null) {
          countMap = resultMap["group"] ?? {};
        }
        if (countMap[user?.uid ?? group?.guid] != null) {
          initialUnreadCount = (countMap[user?.uid ?? group?.guid] as int) ?? 0;
        } else {
          initialUnreadCount = 0;
        }
      }
    }
  }

  @override
  loadMoreElements({bool Function(BaseMessage element)? isIncluded}) async {
    // "Fetching again"
    isLoading = true;
    BaseMessage? lastMessage;
    loggedInUser ??= await CometChat.getLoggedInUser();
    await getUnreadCount();
    conversation ??= (await CometChat.getConversation(
        conversationWithId, conversationType, onSuccess: (conversation) {
      if (conversation.lastMessage != null) {
        // "Marking as read"
        if (kDebugMode) {
          debugPrint("Marking as read from here");
        }
        markAsRead(conversation.lastMessage!);
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
          for (var element in fetchedList.reversed) {
            if (element is InteractiveMessage) {
              element = InteractiveMessageUtils
                  .getSpecificMessageFromInteractiveMessage(element);
            }
            if (isIncluded != null && isIncluded(element) == true) {
              list.add(element);
            } else {
              list.add(element);
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
      CometChatUIEvents.ccActiveChatChanged(
          messageListId, lastMessage, user, group, initialUnreadCount ?? 0);
    }
  }

  //------------------------UI Message Event Listeners------------------------------

  @override
  void onTextMessageReceived(TextMessage textMessage) async {
    if (_messageCategoryTypeCheck(textMessage)) {
      _onMessageReceived(textMessage);
    }
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    if (_messageCategoryTypeCheck(mediaMessage)) {
      _onMessageReceived(mediaMessage);
    }
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    if (_messageCategoryTypeCheck(customMessage)) {
      _onMessageReceived(customMessage);
    }
  }

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    if (_messageCategoryTypeCheck(schedulerMessage)) {
      _onMessageReceived(schedulerMessage);
    }
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    if (disableReceipt != true) {
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
      for (int i = 0; i < list.length; i++) {
        if (list[i].sender?.uid == loggedInUser?.uid) {
          if (i == 0 || list[i].readAt == null) {
            list[i].readAt = messageReceipt.readAt;
            list[i].deliveredAt ??= messageReceipt.readAt;
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

  @override
  void onFormMessageReceived(FormMessage formMessage) {
    if (_messageCategoryTypeCheck(formMessage)) {
      _onMessageReceived(formMessage);
    }
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    if (_messageCategoryTypeCheck(cardMessage)) {
      _onMessageReceived(cardMessage);
    }
  }

  @override
  void onCustomInteractiveMessageReceived(
      CustomInteractiveMessage cardMessage) {
    if (_messageCategoryTypeCheck(cardMessage)) {
      _onMessageReceived(cardMessage);
    }
  }

  @override
  void onInteractionGoalCompleted(InteractionReceipt receipt) {
    debugPrint("interaction completed ${receipt}");
    if (receipt.sender.uid == loggedInUser?.uid) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == receipt.messageId) {
          try {
            (list[i] as InteractiveMessage).interactions = receipt.interactions;
          } on Exception {
            debugPrint("error in converting interactin receipt");
          }
        }
      }
      update();
    }
  }

  //------------------------SDK Group Event Listeners------------------------------
  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == addedTo.guid) {
        _onMessageReceived(action);
      }
    }
  }

  @override
  void onGroupMemberJoined(
      cc.Action action, User joinedUser, Group joinedGroup) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == joinedGroup.guid) {
        _onMessageReceived(action);
      }
    }
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == leftGroup.guid) {
        _onMessageReceived(action, markRead: false, playSound: false);
      }
    }
  }

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == kickedFrom.guid) {
        _onMessageReceived(action, markRead: false, playSound: false);
      }
    }
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == bannedFrom.guid) {
        _onMessageReceived(action, markRead: false, playSound: false);
      }
    }
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (_messageCategoryTypeCheck(message)) {
      if (group?.guid == bannedFrom.guid) {
        _onMessageFromLoggedInUser(message);
      }
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (_messageCategoryTypeCheck(message)) {
      if (group?.guid == kickedFrom.guid) {
        _onMessageFromLoggedInUser(message);
      }
    }
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    if (group?.guid == groupAddedIn.guid) {
      for (var message in messages) {
        if (_messageCategoryTypeCheck(message)) {
          _onMessageFromLoggedInUser(message);
        }
      }
    }
  }

  @override
  void ccGroupMemberUnbanned(cc.Action message, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    if (_messageCategoryTypeCheck(message)) {
      if (group?.guid == unbannedFrom.guid) {
        _onMessageFromLoggedInUser(message);
      }
    }
  }

  @override
  void onGroupMemberUnbanned(cc.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    if (_messageCategoryTypeCheck(action)) {
      if (group?.guid == unbannedFrom.guid) {
        _onMessageReceived(action);
      }
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
    if (_messageCategoryTypeCheck(action)) {
      if (group.guid == this.group?.guid) {
        if (loggedInUser?.uid == updatedUser.uid) {
          //TODO: use scopeChangedTo instead of scopeChangedFrom when the bug in SDK is fixed
          this.group?.scope = scopeChangedFrom;
          debugPrint(
              'scope of ${updatedUser
                  .name} changed to $scopeChangedFrom from $scopeChangedTo');
        }
        _onMessageReceived(action);
      }
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
        } else {}
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
    if ((_checkIfSameConversationForReceivedMessage(message) || _checkIfSameConversationForSenderMessage(message)) &&
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
  @override
  addMessage(BaseMessage message) {
    if (list.isNotEmpty) {
      markAsRead(list[0]);
    }
    if (messageListScrollController.hasClients) {
      messageListScrollController.jumpTo(0.0);
    }
    addElement(message);
  }

  @override
  updateMessageWithMuid(BaseMessage message) {
    int matchingIndex =
    list.indexWhere((element) => (element.muid == message.muid));
    if (matchingIndex != -1) {
      list[matchingIndex] = message;
      update();
    }
  }

  @override
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

  @override
  updateMessageThreadCount(int parentMessageId) {
    int matchingIndex = list.indexWhere((item) => item.id == parentMessageId);
    if (matchingIndex != -1) {
      list[matchingIndex].replyCount++;
      update();
    }
  }

  _playSound() {
    if (!disableSoundForMessages) {
      CometChatUIKit.soundManager.play(
          sound: Sound.incomingMessage,
          customSound: customIncomingMessageSound,
          packageName: customIncomingMessageSound == null ||
              customIncomingMessageSound == ""
              ? UIConstants.packageName
              : customIncomingMessageSoundPackage);
    }
  }

  markAsRead(BaseMessage message) {
    if (disableReceipt != true &&
        message.sender?.uid != loggedInUser?.uid &&
        message.readAt == null) {
      CometChat.markAsRead(message, onSuccess: (String res) {
        CometChatMessageEvents.ccMessageRead(message);
      }, onError: (e) {});
    }
  }

  _onMessageReceived(BaseMessage message,
      {bool playSound = true, bool markRead = true}) {
    if ((message.conversationId == conversationId ||
        _checkIfSameConversationForReceivedMessage(message) ||
        _checkIfSameConversationForSenderMessage(message)) &&
        message.parentMessageId == threadMessageParentId) {
      addElement(message);
      if (playSound) {
        _playSound();
      }

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
      if (playSound) {
        _playSound();
      }
      int matchingIndex =
      list.indexWhere((element) => (element.id == message.parentMessageId));
      if (matchingIndex != -1) {
        list[matchingIndex].replyCount++;
      }
      update();
    }
  }

  _onMessageFromLoggedInUser(BaseMessage message,
      {bool playSound = true, bool markRead = true}) {
    if ((message.conversationId == conversationId ||
        _checkIfSameConversationForSenderMessage(message)) &&
        message.parentMessageId == threadMessageParentId) {
      addElement(message);
      debugPrint("playSound  = $playSound");
      if (playSound) {
        _playSound();
      }

      if (scrollToBottomOnNewMessage) {
        if (markRead) {
          markAsRead(message);
        }

        if (messageListScrollController.hasClients) {
          messageListScrollController.jumpTo(0.0);
        }
      } else if (markRead) {
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
      if (playSound) {
        _playSound();
      }

      int matchingIndex =
      list.indexWhere((element) => (element.id == message.parentMessageId));
      if (matchingIndex != -1) {
        list[matchingIndex].replyCount++;
      }
      update();
    }
  }

  //-----message option methods-----

  _messageEdit(
      BaseMessage message, CometChatMessageListControllerProtocol state) {
    if (message.deletedAt == null) {
      CometChatMessageEvents.ccMessageEdited(
          message, MessageEditStatus.inProgress);
    }
  }

  _delete(BaseMessage message, CometChatMessageListControllerProtocol state) {
    if (message.deletedAt == null) {
      CometChatMessageEvents.ccMessageDeleted(message, EventStatus.inProgress);
      deleteMessage(message);
    }
  }

  // _replyMessage(BaseMessage message, CometChatMessageListControllerProtocol state) {
  //   CometChatMessageEvents.onMessageReply(message);
  // }

  _shareMessage(
      BaseMessage message, CometChatMessageListControllerProtocol state) async {
    // List<String> types = CometChatUIKit.getDataSource().getAllMessageTypes();
    //share
    if (message is TextMessage) {
      await UIConstants.channel.invokeMethod(
        "shareMessage",
        {'message': message.text, "type": "text"},
      );
    } else if (message is MediaMessage) {
      await UIConstants.channel.invokeMethod(
        "shareMessage",
        {
          "message": message.attachment?.fileName, // For ios
          'mediaName': message.attachment?.fileName,
          "type": "media",
          "subtype": message.type.toString(),
          "fileUrl": message.attachment?.fileUrl,
          "mimeType": message.attachment?.fileMimeType
        },
      );
    }
  }

  _copyMessage(
      BaseMessage message, CometChatMessageListControllerProtocol state) {
    if (message is TextMessage) {
      Clipboard.setData(ClipboardData(text: message.text));
    }
  }

  _messageInformation(
      BaseMessage message, CometChatMessageListControllerProtocol state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CometChatMessageInformation(
          message: message,
          bubbleView: messageInformationConfiguration?.bubbleView,
          template: templateMap["${message.category}_${message.type}"],
          title: messageInformationConfiguration?.title,
          receiptDatePattern:
          messageInformationConfiguration?.receiptDatePattern,
          readIcon: messageInformationConfiguration?.readIcon,
          listItemView: messageInformationConfiguration?.listItemView,
          listItemStyle: messageInformationConfiguration?.listItemStyle,
          deliveredIcon: messageInformationConfiguration?.deliveredIcon,
          onError: messageInformationConfiguration?.onError,
          closeIcon: messageInformationConfiguration?.closeIcon,
          onClose: messageInformationConfiguration?.onClose,
          theme: messageInformationConfiguration?.theme ?? theme,
          messageInformationStyle:
          messageInformationConfiguration?.messageInformationStyle,
          subTitleView: messageInformationConfiguration?.subTitleView,
          emptyStateText: messageInformationConfiguration?.emptyStateText,
          emptyStateView: messageInformationConfiguration?.emptyStateView,
          errorStateText: messageInformationConfiguration?.errorStateText,
          loadingIconUrl: messageInformationConfiguration?.loadingIconUrl,
          loadingStateView: messageInformationConfiguration?.loadingStateView,
          errorStateView: messageInformationConfiguration?.errorStateView,
        ),
      ),
    );
  }

  _sendMessagePrivately(
      BaseMessage message, CometChatMessageListControllerProtocol state) async {
    if (message.receiver is Group) {
      User? user = await CometChat.getUser(
        message.sender!.uid,
        onSuccess: (user) {
          debugPrint("User fetched successfully $user");
        },
        onError: (excep) {
          debugPrint("Error fetching user ${excep.message}");
        },
      );
      if (context.mounted) {
        if (message.parentMessageId != 0) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
        }
      }
      CometChatUIEvents.openChat(user, null);
    }
  }

  createMessage(BaseMessage copyFromMessage, User? user, Group? group) async {
    if (copyFromMessage is TextMessage) {
      TextMessage message = TextMessage(
        text: copyFromMessage.text,
        receiverUid: user?.uid ?? group?.guid ?? "",
        type: MessageTypeConstants.text,
        category: MessageCategoryConstants.message,
        receiverType: user != null
            ? ReceiverTypeConstants.user
            : ReceiverTypeConstants.group,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: loggedInUser,
        parentMessageId: 0,
      );
      await CometChatUIKit.sendTextMessage(message,
          onSuccess: (BaseMessage returnedMessage) {},
          onError: (CometChatException excep) {
            // Get.showSnackbar(snackbar)
          });
    } else if (copyFromMessage is MediaMessage) {
      if (copyFromMessage.attachment == null) return;

      String fileUrl = copyFromMessage.attachment!.fileUrl;
      String fileName = copyFromMessage.attachment!.fileName;
      String fileExtension = copyFromMessage.attachment!.fileExtension;
      String fileMimeType = copyFromMessage.attachment!.fileMimeType;

      Attachment attachment =
      Attachment(fileUrl, fileName, fileExtension, fileMimeType, null);

      MediaMessage message = MediaMessage(
          receiverUid: user?.uid ?? group?.guid ?? "",
          type: copyFromMessage.type,
          category: MessageCategoryConstants.message,
          receiverType: user != null
              ? ReceiverTypeConstants.user
              : ReceiverTypeConstants.group,
          muid: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: loggedInUser,
          parentMessageId: 0,
          attachment: attachment);

      await CometChatUIKit.sendMediaMessage(message,
          onSuccess: (BaseMessage returnedMessage) {},
          onError: (CometChatException excep) {
            // Get.showSnackbar(snackbar)
          });
    } else if (copyFromMessage is CustomMessage) {
      CustomMessage message = CustomMessage(
        customData: copyFromMessage.customData,
        receiverUid: user?.uid ?? group?.guid ?? "",
        type: copyFromMessage.type,
        category: MessageCategoryConstants.custom,
        receiverType: user != null
            ? ReceiverTypeConstants.user
            : ReceiverTypeConstants.group,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: loggedInUser,
        parentMessageId: 0,
      );

      await CometChatUIKit.sendCustomMessage(message,
          onSuccess: (BaseMessage returnedMessage) {},
          onError: (CometChatException excep) {
            // Get.showSnackbar(snackbar)
          });
    }
  }


  Function(BaseMessage message, CometChatMessageListControllerProtocol state)?
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
    // case MessageOptionConstants.forwardMessage:
    //   {
    //     return _forwardMessage;
    //   }
    // case MessageOptionConstants.replyInThreadMessage:
    //   {
    //     return _replyInThread;
    //   }
      case MessageOptionConstants.messageInformation:
        {
          return _messageInformation;
        }
      case MessageOptionConstants.sendMessagePrivately:
        {
          return _sendMessagePrivately;
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
      if (loggedInUser?.uid == updatedUser.uid) {
        this.group?.scope = scopeChangedTo;
      }
      debugPrint(
          'scope of ${updatedUser.name} changed to $scopeChangedTo from $scopeChangedFrom');
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

    BubbleAlignment alignment0 = BubbleAlignment.right;
    bool thumbnail = false;
    bool name = false;
    bool readReceipt = true;
    bool enableStatusInfoView = true;

    if (alignment == ChatAlignment.standard) {
      //-----if message is group action-----
      if ((messageObject.category == MessageCategoryConstants.action) ||
          (messageObject.category == MessageCategoryConstants.call &&
              messageObject.receiver is User)) {
        thumbnail = false;
        name = false;
        readReceipt = false;
        alignment0 = BubbleAlignment.center;
        enableStatusInfoView = false;
      }
      //-----if message sent by me-----
      else if (isMessageSentByMe) {
        thumbnail = false;
        name = false;
        readReceipt = true;
        alignment0 = BubbleAlignment.right;
      }
      //-----if message received in user conversation-----
      else if (user != null) {
        thumbnail = false;
        name = false;
        readReceipt = false;
        alignment0 = BubbleAlignment.left;
      }
      //-----if message received in group conversation-----
      else if (group != null) {
        thumbnail = true;
        name = true;
        readReceipt = false;
        alignment0 = BubbleAlignment.left;
      }
    } else if (alignment == ChatAlignment.leftAligned) {
      //-----if message is  action message -----
      if ((messageObject.category == MessageCategoryConstants.action) ||
          (messageObject.category == MessageCategoryConstants.call &&
              messageObject.receiver is User)) {
        thumbnail = false;
        name = false;
        readReceipt = false;
        alignment0 = BubbleAlignment.center;
        enableStatusInfoView = false;
      }
      //-----if message sent by me-----
      else if (isMessageSentByMe) {
        thumbnail = true;
        name = true;
        readReceipt = true;
        alignment0 = BubbleAlignment.left;
      }
      //-----if message received in user conversation-----
      else if (user != null) {
        thumbnail = true;
        name = true;
        readReceipt = false;
        alignment0 = BubbleAlignment.left;
      }
      //-----if message received in group conversation-----
      else if (group != null) {
        thumbnail = true;
        name = true;
        readReceipt = false;
        alignment0 = BubbleAlignment.left;
      }
    }

    if (disableReceipt == true) {
      readReceipt = false;
    }


    return BubbleContentVerifier(
        showThumbnail: thumbnail,
        showStatusInfoView: enableStatusInfoView,
        showName: name,
        showReadReceipt: readReceipt,
        alignment: alignment0,
    );
  }

  @override
  initializeHeaderAndFooterView() {
    if (headerView != null) {
      header = headerView!(context, user: user, group: group);
    }

    if (footerView != null) {
      footer = footerView!(context, user: user, group: group);
    }
  }

  @override
  void showPanel(Map<String, dynamic>? id, CustomUIPosition uiPosition,
      WidgetBuilder child) {
    if (isForThisWidget(id) == false) return;
    if (uiPosition == CustomUIPosition.messageListBottom) {
      footer = child(context);
    } else if (uiPosition == CustomUIPosition.messageListTop) {
      header = child(context);
    }
    update();
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    if (isForThisWidget(id) == false) return;
    if (uiPosition == CustomUIPosition.messageListBottom) {
      footer = null;
    } else if (uiPosition == CustomUIPosition.messageListBottom) {
      header = null;
    }
    update();
  }

  bool isForThisWidget(Map<String, dynamic>? id) {
    if (id == null) {
      return true; //if passed id is null , that means for all composer
    }
    if ((id['uid'] != null &&
        id['uid'] ==
            user?.uid) //checking if uid or guid match composer's uid or guid
        ||
        (id['guid'] != null && id['guid'] == group?.guid)) {
      if (id['parentMessageId'] != null) {
        return (threadMessageParentId == id['parentMessageId']);
      }

      return true;
    }
    return false;
  }

//--------------SDK Call listeners-----------------------------------------------

  @override
  void onIncomingCallReceived(Call call) {
    call.category = MessageCategoryConstants.call;
    _onMessageReceived(call, playSound: false, markRead: false);
  }

  @override
  void onOutgoingCallAccepted(Call call) {
    call.category = MessageCategoryConstants.call;
    _onMessageReceived(call, playSound: false, markRead: false);
  }

  @override
  void onOutgoingCallRejected(Call call) {
    call.category = MessageCategoryConstants.call;
    _onMessageReceived(call, playSound: false, markRead: false);
  }

  @override
  void onIncomingCallCancelled(Call call) {
    call.category = MessageCategoryConstants.call;
    _onMessageReceived(call);
  }

  @override
  void onCallEndedMessageReceived(Call call) {
    call.category = MessageCategoryConstants.call;
    _onMessageReceived(call);
  }

//----------------- UI Call Listeners---------------

  bool _checkCallInSameConversation(Call call) {
    if (kDebugMode) {
      print(" $threadMessageParentId ${user?.uid} ${call.receiverUid} ");
    }

    return (threadMessageParentId == 0 &&
        user != null &&
        (call.sender?.uid == user?.uid || call.receiverUid == user?.uid));
  }

  @override
  void ccOutgoingCall(Call call) {
    if (_checkCallInSameConversation(call)) {
      _onMessageFromLoggedInUser(call, markRead: false, playSound: false);
    }
  }

  @override
  void ccCallAccepted(Call call) {
    if (_checkCallInSameConversation(call)) {
      _onMessageFromLoggedInUser(call, markRead: false, playSound: false);
    }
  }

  @override
  void ccCallRejected(Call call) {
    if (_checkCallInSameConversation(call)) {
      _onMessageFromLoggedInUser(call, markRead: false, playSound: false);
    }
  }

  @override
  void ccCallEnded(Call call) {
    if (_checkCallInSameConversation(call)) {
      _onMessageFromLoggedInUser(call, markRead: false, playSound: false);
    }
  }

  @override
  String getConversationId() {
    return conversationWithId;
  }

  @override
  BuildContext getCurrentContext() {
    return context;
  }

  @override
  Group? getGroup() {
    return group;
  }

  @override
  int? getParentMessageId() {
    return threadMessageParentId;
  }

  @override
  ScrollController getScrollController() {
    return messageListScrollController;
  }

  @override
  Map<String, CometChatMessageTemplate> getTemplateMap() {
    return templateMap;
  }

  @override
  User? getUser() {
    return user;
  }

  @override
  void onConnected() {
    _updateUserAndGroup();
    _fetchNewMessages();
  }

  /// [_fetchNewMessages] method fetches the new messages from the server after a web socket connection is re-established.
  void _fetchNewMessages() async {
    int? lastMessageId;
    for (int i = 0; i < list.length; i++) {
      if (list[i].id != 0) {
        lastMessageId = list[i].id;
        break;
      }
    }
    bool hasMoreItems = true;
    int messageId = lastMessageId ?? 1;
    List<String> categories =
        messagesBuilderProtocol.requestBuilder.categories ??
            CometChatUIKit.getDataSource().getAllMessageCategories();
    List<String> types = messagesBuilderProtocol.requestBuilder.types ??
        CometChatUIKit.getDataSource().getAllMessageTypes();

    // used to fetch the old messages from the server starting from the last message in the list that have been edited or deleted
    types.add(MessageTypeConstants.message);

    while (hasMoreItems) {
      //the following message request fetches the new messages received after the last message sent or received recorded in the list.
      MessagesRequest messageRequest = (MessagesRequestBuilder()
        ..uid = user?.uid
        ..guid = group?.guid
        ..categories = categories
        ..types = types
        ..messageId = messageId)
          .build();
      try {
        await messageRequest.fetchNext(
            onSuccess: (List<BaseMessage> fetchedList) {
              //if fetched messages list is empty, it means there are no new messages and hence stop proceeding.
              if (fetchedList.isNotEmpty) {
                hasMoreItems = true;
                for (BaseMessage message in fetchedList) {
                  if (message is InteractiveMessage) {
                    message = InteractiveMessageUtils
                        .getSpecificMessageFromInteractiveMessage(message);
                  }
                  if (message.parentMessageId != 0) {
                    updateMessageThreadCount(message.parentMessageId);
                  } else if (message is cc.Action) {
                    if (message.type == MessageTypeConstants.message &&
                        (message.action == ActionMessageTypeConstants.edited ||
                            message.action == ActionMessageTypeConstants.deleted) &&
                        message.actionOn is BaseMessage) {
                      BaseMessage actionOn = message.actionOn as BaseMessage;
                      int matchingIndex =
                      list.indexWhere((element) => (element.id == actionOn.id));
                      if (matchingIndex != -1) {
                        list[matchingIndex] = actionOn;
                        update();
                      }
                    } else if (message.sender?.uid != null &&
                        loggedInUser?.uid != null &&
                        message.sender?.uid == loggedInUser?.uid) {
                      updateMessageWithMuid(message);
                    } else {
                      addElement(message);
                      newUnreadMessageCount++;
                      update();
                    }
                  } else {
                    for(int i = 0; i < list.length; i++){
                      if(list[i].muid == message.muid){
                        list.removeAt(i);
                        update();
                        break;
                      }
                    }
                    addElement(message);
                      newUnreadMessageCount++;
                      update();
                  }
                }
                messageId = fetchedList.last.id;
                return;
              } else {
                hasMoreItems = false;
                update();
              }
            }, onError: (CometChatException e) {
          hasMoreItems = false;
        });
      } catch (e, _) {
        hasMoreItems = false;
      }
    }
  }

  ///[_updateUserAndGroup] method updates the user and group details if the user or group is updated while the web socket connection is lost.
  _updateUserAndGroup() async {
    if (user != null) {
      user = await CometChat.getUser(
        user!.uid,
        onSuccess: (user) {},
        onError: (excep) {},
      );
    }
    if (group != null) {
      group = await CometChat.getGroup(
        group!.guid,
        onSuccess: (group) {},
        onError: (excep) {},
      );
    }
    update();
  }

  //  event listeners for message reaction

  @override
  void onMessageReactionAdded(ReactionEvent reactionEvent) {
    if(disableReactions!=true){
      _updateMessageOnReaction(reactionEvent, ReactionAction.reactionAdded);
    }
  }

  @override
  void onMessageReactionRemoved(ReactionEvent reactionEvent) {
    if(disableReactions!=true) {
      _updateMessageOnReaction(reactionEvent, ReactionAction.reactionRemoved);
    }
  }

  _updateMessageOnReaction(ReactionEvent reactionEvent,String reactionAction){
    Reaction? messageReaction = reactionEvent.reaction;
    if(messageReaction!=null){
      int? messageId = messageReaction.messageId;
      if (messageId == null) return;
      BaseMessage? message =
          list.firstWhereOrNull((element) => element.id == messageId);
      if (message == null) return;
      CometChatHelper.updateMessageWithReactionInfo(
              message, messageReaction, reactionAction)
          .then((reactedMessage) {
        if (reactedMessage == null) return;
        updateElement(reactedMessage);
      });
    }
  }

  handleReactionPress(BaseMessage message, String? reaction, List<ReactionCount> reactionList){
    if(reaction==null || reaction.isEmpty) return;
    int reactionIndex = reactionList.indexWhere((reactionCount) => reactionCount.reaction==reaction && reactionCount.reactedByMe==true);
    if(reactionIndex!=-1) {
      updateElement(updateReactionsOnMessage(message, reaction, false));
      // remove reaction
      CometChatUIKit.removeReaction(message.id, reaction,
      onError: (error) {
        updateElement(updateReactionsOnMessage(message, reaction, true));
      },
      );
    }else{
      // add reaction
      updateElement(updateReactionsOnMessage(message, reaction, true));
      CometChatUIKit.addReaction(message.id, reaction,
        onError: (error) {
          updateElement(updateReactionsOnMessage(message, reaction, false));
        },
      );
    }
  }

  void addReactionIconTap(BaseMessage message) async{
    Navigator.of(context).pop();
    String? reaction =
        await showCometChatEmojiKeyboard(
      context: context,
          unselectedCategoryIconColor: emojiKeyboardStyle?.unselectedCategoryIconColor,
          selectedCategoryIconColor: emojiKeyboardStyle?.selectedCategoryIconColor,
          dividerColor: emojiKeyboardStyle?.dividerColor,
          categoryLabel: emojiKeyboardStyle?.categoryLabelStyle,
          titleStyle: emojiKeyboardStyle?.titleStyle,
          backgroundColor: emojiKeyboardStyle?.backgroundColor
    );

    if (reaction != null) {

      handleReactionPress(message, reaction, message.reactions);
    }
  }



  void onReactionTap(BaseMessage message, String? reaction) async{
  if(reaction==null ||reaction.isEmpty) return;

  handleReactionPress(message, reaction, message.reactions);
  }

  BaseMessage updateReactionsOnMessage(BaseMessage message, String reaction, bool add){
    ReactionCount reactionCount = ReactionCount(
      reaction: reaction,
      count: 1,
      reactedByMe: true
    );
    int match = message.reactions.indexWhere((element) => element?.reaction==reaction);
    if(add){
      if(match==-1){
        message.reactions.add(reactionCount);
      } else if(message.reactions[match].reactedByMe==false){
        message.reactions[match].reactedByMe =true;
        if(message.reactions[match].count!=null) {
          message.reactions[match].count = message.reactions[match].count! + 1;
        }
      }
    }else{
      if(match!=-1 && message.reactions[match].reactedByMe==true) {
        if(message.reactions[match].count==1) {
          message.reactions.remove(reactionCount);
        } else {
          message.reactions[match].reactedByMe = false;
          if (message.reactions[match].count != null) {
            message.reactions[match].count =
                message.reactions[match].count! - 1;
          }
        }
      }
    }

    return message;
  }


  // Validates if the message's category and type match allowed values.
  // This method checks against categories and types from the request builder,
  // falling back to default values from the data source if none are provided.
  // @param message The message to validate.
  // @return True if both category and type are allowed, false otherwise.
  bool _messageCategoryTypeCheck(BaseMessage message) {
    List<String> categories =
        messagesBuilderProtocol.requestBuilder.categories ??
            CometChatUIKit.getDataSource().getAllMessageCategories();
    List<String> types = messagesBuilderProtocol.requestBuilder.types ??
        CometChatUIKit.getDataSource().getAllMessageTypes();

    return categories.contains(message.category) && types.contains(message.type);
  }
}

class BubbleContentVerifier {
  bool showThumbnail;
  bool showName;
  bool showReadReceipt;
  bool showFooterView;
  BubbleAlignment alignment;
  bool showStatusInfoView;

  BubbleContentVerifier(
      {this.showThumbnail = false,
      this.showName = false,
      this.showReadReceipt = true,
      this.showFooterView = true,
      this.alignment = BubbleAlignment.right,
      this.showStatusInfoView = true
      });
}

