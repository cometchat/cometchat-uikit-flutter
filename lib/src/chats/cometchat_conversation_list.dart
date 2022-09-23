import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

//----------- fetch items like conversation list,user list ,etc.-----------
class ItemFetcher<T> {
  Future<List<T>> fetch(dynamic request) async {
    final list = <T>[];

    List<T> res = await request.fetchNext(
        onSuccess: (List<T> conversations) {},
        onError: (CometChatException e) {
          debugPrint('$e');
        });

    list.addAll(res);
    return list;
  }

  Future<List<T>> fetchPrevious(dynamic request) async {
    final list = <T>[];

    List<T> res = await request.fetchPrevious(
        onSuccess: (List<T> messages) {}, onError: (CometChatException e) {});

    list.addAll(res);
    return list;
  }
}

class CometChatConversationList extends StatefulWidget with MessageListener {
  const CometChatConversationList(
      {Key? key,
      this.limit = 30,
      this.conversationType = ConversationTypes.both,
      this.userAndGroupTags,
      this.tags,
      this.style = const ListStyle(),
      this.customView = const CustomView(),
      this.emptyText,
      this.errorText,
      this.hideError = false,
      //this.onErrorCallBack,
      this.theme,
      this.avatarConfiguration,
      this.statusIndicatorConfiguration,
      this.badgeCountConfiguration,
      this.dateConfiguration,
      this.messageReceiptConfiguration,
      this.conversationListItemConfiguration,
      this.stateCallBack,
      this.enableSoundForMessages = true,
      this.customIncomingMessageSound})
      : super(key: key);

  ///[limit] no of conversations to be fetch at once
  final int? limit;

  ///[conversationType] conversation type user/group/both
  final ConversationTypes conversationType;

  ///[userAndGroupTags]
  final bool? userAndGroupTags;

  ///[tags] list of tags
  final List<String>? tags;

  ///[style]
  final ListStyle style;

  ///[customView] custom widgets for loading,error,empty
  final CustomView customView;

  ///[emptyText] text shown on empty list
  final String? emptyText;

  ///[errorText] text shown on error
  final String? errorText;

  ///[hideError] hides error
  final bool hideError;

  ///[onErrorCallBack] on error callback function
  final bool enableSoundForMessages;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  ///[customIncomingMessageSound] URL of the audio file to be played upon receiving messages
  final String? customIncomingMessageSound;

  ///[avatarConfigurations]
  final AvatarConfiguration? avatarConfiguration;

  ///[statusIndicatorConfiguration]
  final StatusIndicatorConfiguration? statusIndicatorConfiguration;

  ///[badgeCountConfiguration]
  final BadgeCountConfiguration? badgeCountConfiguration;

  ///[dateConfiguration]
  final DateConfiguration? dateConfiguration;

  ///[messageReceiptConfiguration]
  final MessageReceiptConfiguration? messageReceiptConfiguration;

  ///[conversationListItemConfigurations]
  final ConversationListItemConfigurations? conversationListItemConfiguration;

  ///[stateCallBack]
  final void Function(CometChatConversationListState)? stateCallBack;

  @override
  CometChatConversationListState createState() =>
      CometChatConversationListState();
}

class CometChatConversationListState extends State<CometChatConversationList>
    with MessageListener, UserListener, GroupListener {
  final conversationList = <Conversation>[];
  final itemFetcher = ItemFetcher<Conversation>();

  bool isLoading = true;
  bool hasMoreItems = true;
  late ConversationsRequest conversationRequest;
  bool _isListItemConfigurationPassed = false;
  late ConversationListItemConfigurations _conversationListItemConfiguration;
  bool _showCustomError = false;
  CometChatTheme theme = cometChatTheme;

  Set<String> typingIndicatorMap = {}; //index, isTypingBool

  String loggedInUserId = "";
  String?
      activeID; //active user or groupID, null when no message list is active

  getLoggedInUser() async {
    User? user = await CometChat.getLoggedInUser();
    if (user != null) {
      loggedInUserId = user.uid;
    }
  }

  @override
  void initState() {
    super.initState();
    theme = widget.theme ?? cometChatTheme;
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }
    if (widget.conversationListItemConfiguration == null) {
      _conversationListItemConfiguration =
          const ConversationListItemConfigurations();
      _isListItemConfigurationPassed = false;
    } else {
      _isListItemConfigurationPassed = true;
      _conversationListItemConfiguration =
          widget.conversationListItemConfiguration!;
    }
    getLoggedInUser();
    String _conversationType = '';
    if (widget.conversationType == ConversationTypes.user) {
      _conversationType = ReceiverTypeConstants.user;
    } else if (widget.conversationType == ConversationTypes.group) {
      _conversationType = ReceiverTypeConstants.group;
    }

    conversationRequest = (ConversationsRequestBuilder()
          ..limit = widget.limit
          ..tags = widget.tags ?? []
          ..withUserAndGroupTags = widget.userAndGroupTags ?? true
          ..conversationType = _conversationType)
        .build();

    CometChat.addMessageListener("conversationListener", this);
    CometChat.addUserListener(
        "cometchat_conversation_list_user_listener", this);
    CometChat.addGroupListener(
        "cometchat_conversation_list_group_listener", this);
    _loadMore();
  }

  @override
  void dispose() {
    CometChat.removeMessageListener("conversationListener");
    CometChat.removeUserListener("cometchat_conversation_list_user_listener");
    CometChat.removeGroupListener("cometchat_conversation_list_group_listener");
    super.dispose();
  }

  //-----------Message Listeners------------------------------------------------

  _onMessageReceived(BaseMessage message, bool isActionMessage) {
    if (message.sender!.uid != loggedInUserId) {
      CometChat.markAsDelivered(message, onSuccess: (_) {}, onError: (_) {});
    }
    if (widget.enableSoundForMessages == true) {
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
    if (messageReceipt.receiverType == ReceiverTypeConstants.user) {
      setReceipts(messageReceipt);
    }
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    if (messageReceipt.receiverType == ReceiverTypeConstants.user) {
      setReceipts(messageReceipt);
    }
  }

  @override
  void onMessageEdited(BaseMessage message) {
    updateLastMessageOnEdited(message);
  }

  @override
  void onMessageDeleted(BaseMessage message) {
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
  //----------------Group Listeners end----------------------------------------------

  updateUserStatus(User user, String status) {
    int matchingIndex = conversationList.indexWhere((element) =>
        (element.conversationType == ReceiverTypeConstants.user &&
            (element.conversationWith as User).uid == user.uid));

    if (matchingIndex != -1) {
      (conversationList[matchingIndex].conversationWith as User).status =
          status;
      setState(() {});
    }
  }

  //------------------------------------------------------------------------

  //----------------Public Methods -----------------------------------------------------
  removeConversation(Conversation conversation) {
    int _matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == conversation.conversationId));

    if (_matchingIndex != -1) {
      conversationList.removeAt(_matchingIndex);
      setState(() {});
    }
  }

  deleteConversation(Conversation conversation) {
    int _matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == conversation.conversationId));

    deleteConversationFromIndex(_matchingIndex);
  }

  resetUnreadCount(BaseMessage message) {
    int matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == message.conversationId));

    if (matchingIndex != -1) {
      conversationList[matchingIndex].unreadMessageCount = 0;
      setState(() {});
    }
  }

  updateLastMessage(BaseMessage message) {
    int matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == message.conversationId));

    if (matchingIndex != -1) {
      Conversation conversation = conversationList[matchingIndex];
      conversation.lastMessage = message;
      conversation.unreadMessageCount = 0;
      conversationList.removeAt(matchingIndex);
      conversationList.insert(0, conversation);
      setState(() {});
    }
  }

  updateLastMessageOnEdited(BaseMessage message) async {
    int matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == message.conversationId));

    if (matchingIndex != -1) {
      if (conversationList[matchingIndex].lastMessage?.id == message.id) {
        conversationList[matchingIndex].lastMessage = message;
        setState(() {});
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
        removeConversation(conversation);
      } else {
        updateConversation(conversation, isActionMessage);
      }
    }, onError: (_) {});
  }

  ///Update the conversation with new conversation Object matched according to conversation id ,  if not matched inserted at top
  updateConversation(Conversation conversation, bool isActionMessage) {
    int matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == conversation.conversationId));

    Map<String, dynamic>? metaData = conversation.lastMessage!.metadata;
    bool incrementUnreadCount = true;
    bool isCategoryMessage = (conversation.lastMessage!.category == "message");
    if (metaData != null) {
      debugPrint("${conversation.lastMessage?.metadata}");
      if (metaData.containsKey("incrementUnreadCount")) {
        incrementUnreadCount = metaData["incrementUnreadCount"] as bool;
      }
    }

    if (matchingIndex != -1) {
      Conversation oldConversation = conversationList[matchingIndex];

      if (isActionMessage) {
        conversation.unreadMessageCount = oldConversation.unreadMessageCount;
      } else if ((incrementUnreadCount || isCategoryMessage) &&
          conversation.lastMessage?.sender?.uid != loggedInUserId) {
        conversation.unreadMessageCount =
            (oldConversation.unreadMessageCount ?? 0) + 1;
      }
      conversationList.removeAt(matchingIndex);
      conversationList.insert(0, conversation);
    } else {
      if ((incrementUnreadCount || isCategoryMessage) &&
          conversation.lastMessage?.sender?.uid != loggedInUserId) {
        int oldCount = conversation.unreadMessageCount ?? 0;
        conversation.unreadMessageCount = oldCount + 1;
      }
      conversationList.insert(0, conversation);
    }

    setState(() {});
  }

//Set Receipt for
  setReceipts(MessageReceipt receipt) {
    for (int i = 0; i < conversationList.length; i++) {
      Conversation conversation = conversationList[i];
      if (conversation.conversationType == ReceiverTypeConstants.user &&
          receipt.sender.uid == ((conversation.conversationWith as User).uid)) {
        BaseMessage? lastMessage = conversation.lastMessage;

        //Check if receipt type is delivered
        if (lastMessage != null &&
            lastMessage.deliveredAt == null &&
            receipt.receiptType == ReceiptTypeConstants.delivered &&
            receipt.messageId == lastMessage.id) {
          lastMessage.deliveredAt = receipt.deliveredAt;
          conversationList[i].lastMessage = lastMessage;
          setState(() {});
          break;
        } else if (lastMessage != null &&
            lastMessage.readAt == null &&
            receipt.receiptType == ReceiptTypeConstants.read &&
            receipt.messageId == lastMessage.id) {
          //if receipt type is read
          lastMessage.readAt = receipt.readAt;
          conversationList[i].lastMessage = lastMessage;
          setState(() {});

          break;
        }
      }
    }
  }

  setTypingIndicator(
      TypingIndicator typingIndicator, bool isTypingStarted) async {
    int matchingIndex;
    if (typingIndicator.receiverType == ReceiverTypeConstants.user) {
      matchingIndex = conversationList.indexWhere(
          (Conversation _conversation) =>
              (_conversation.conversationType == ReceiverTypeConstants.user &&
                  (_conversation.conversationWith as User).uid ==
                      typingIndicator.sender.uid));
    } else {
      matchingIndex = conversationList.indexWhere(
          (Conversation _conversation) =>
              (_conversation.conversationType == ReceiverTypeConstants.group &&
                  (_conversation.conversationWith as Group).guid ==
                      typingIndicator.receiverId));
    }

    if (matchingIndex != -1) {
      if (isTypingStarted == true) {
        typingIndicatorMap.add(conversationList[matchingIndex].conversationId!);
      } else {
        typingIndicatorMap
            .remove(conversationList[matchingIndex].conversationId!);
      }
      setState(() {});
    }
  }

  void deleteConversationFromIndex(int index) async {
    late String conversationWith;
    late String conversationType;
    if (conversationList[index].conversationType.toLowerCase() ==
        ReceiverTypeConstants.group.toLowerCase()) {
      conversationWith =
          (conversationList[index].conversationWith as Group).guid;
      conversationType = ReceiverTypeConstants.group;
    } else {
      conversationWith = (conversationList[index].conversationWith as User).uid;
      conversationType = ReceiverTypeConstants.user;
    }

    showCometChatConfirmDialog(
        context: context,
        confirmButtonText: Translations.of(context).delete_capital,
        cancelButtonText: Translations.of(context).cancel_capital,
        messageText: Text(
          Translations.of(context).delete_confirm,
          style: TextStyle(
              fontSize: theme.typography.title2.fontSize,
              fontWeight: theme.typography.title2.fontWeight,
              color: theme.palette.getAccent(),
              fontFamily: theme.typography.title2.fontFamily),
        ),
        onCancel: () {
          Navigator.pop(context);
        },
        style: ConfirmDialogStyle(
            backgroundColor:
                widget.style.background ?? theme.palette.getBackground(),
            shadowColor: theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary())),
        onConfirm: () async {
          await CometChat.deleteConversation(conversationWith, conversationType,
              onSuccess: (_) {
            conversationList.removeAt(index);
          }, onError: (_) {});
          Navigator.pop(context);
          setState(() {});
        });
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
          customSound: widget.customIncomingMessageSound);
    } else {
      if (activeID != message.conversationId) {
        //if open message list has different conversation id then message received conversation id
        SoundManager.play(
            sound: Sound.incomingMessage,
            customSound: widget.customIncomingMessageSound);
      }
    }
  }

  //----------------Public Method end -----------------------------------------------------

  //Function to load more conversations
  void _loadMore() {
    isLoading = true;

    try {
      conversationRequest.fetchNext(
          onSuccess: (List<Conversation> fetchedList) {
        if (fetchedList.isEmpty) {
          setState(() {
            isLoading = false;
            hasMoreItems = false;
          });
        } else {
          setState(() {
            isLoading = false;
            conversationList.addAll(fetchedList);
          });
        }
      }, onError: (CometChatException e) {
        debugPrint('$e');
        CometChatConversationEvents.onError(e);
        // if (widget.onErrorCallBack != null) {
        //   widget.onErrorCallBack!(e);
        // } else
        if (widget.hideError == false && widget.customView.error != null) {
          _showCustomError = true;
          setState(() {});
        } else if (widget.hideError == false) {
          String _error =
              widget.errorText ?? Utils.getErrorTranslatedText(context, e.code);
          showCometChatConfirmDialog(
              context: context,
              messageText: Text(
                _error,
                style: TextStyle(
                    fontSize: theme.typography.title2.fontSize,
                    fontWeight: theme.typography.title2.fontWeight,
                    color: theme.palette.getAccent(),
                    fontFamily: theme.typography.title2.fontFamily),
              ),
              confirmButtonText: Translations.of(context).try_again,
              cancelButtonText: Translations.of(context).cancel_capital,
              onCancel: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              onConfirm: () {
                Navigator.pop(context);
                _loadMore();
              });
        }
      });
    } catch (e) {
      debugPrint('e');
      // if (widget.onErrorCallBack != null) {
      //   widget.onErrorCallBack!(e);
      // } else
      if (widget.hideError == false && widget.customView.error != null) {
        _showCustomError = true;
        setState(() {});
      } else if (widget.hideError == false) {
        showCometChatConfirmDialog(
            context: context,
            messageText: Text(
              widget.errorText ?? Translations.of(context).cant_load_chats,
              style: TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
            ),
            cancelButtonText: Translations.of(context).cancel_capital,
            confirmButtonText: Translations.of(context).try_again,
            onCancel: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            onConfirm: () {
              Navigator.pop(context);
              _loadMore();
            });
      }
    }
  }

  markMessageRead(Conversation conversation) {
    int matchingIndex = conversationList.indexWhere(
        (element) => (element.conversationId == conversation.conversationId));
    if (matchingIndex != -1) {
      if (conversationList[matchingIndex].unreadMessageCount != 0) {
        conversationList[matchingIndex].unreadMessageCount = 0;
        setState(() {});
      }
    }
  }

  //----------- last message icon -----------
  Map<String, IconData> getLastMessageIcon = {
    MessageTypeConstants.text: Icons.check,
    MessageTypeConstants.image: Icons.camera_alt,
    MessageTypeConstants.audio: Icons.music_note,
    MessageTypeConstants.video: Icons.video_camera_back,
    MessageTypeConstants.file: Icons.file_copy,
    MessageTypeConstants.custom: Icons.file_copy
  };

  refreshList() {
    conversationList.clear();
    conversationRequest = (ConversationsRequestBuilder()
          ..limit = widget.limit
          ..tags = widget.tags ?? []
          ..withUserAndGroupTags = widget.userAndGroupTags ?? true
          ..conversationType = widget.conversationType.toString().substring(18))
        .build();

    _loadMore();
  }

  Widget _getLoadingIndicator(CometChatTheme _theme) {
    return widget.customView.loading ??
        Center(
          child: widget.customView.loading ??
              Image.asset(
                "assets/icons/spinner.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent600(),
              ),
        );
  }

  Widget _getNoChatIndicator(CometChatTheme _theme) {
    return widget.customView.empty ??
        Center(
          child: Text(
            widget.emptyText ?? "No Chats yet",
            style: widget.style.empty ??
                TextStyle(
                    fontSize: _theme.typography.title1.fontSize,
                    fontWeight: _theme.typography.title1.fontWeight,
                    color: _theme.palette.getAccent400()),
          ),
        );
  }

  bool _getHideReceipt(int index) {
    if (_conversationListItemConfiguration.hideReceipt == true ||
        conversationList[index].lastMessage == null) {
      return true;
    } else if (conversationList[index].lastMessage!.sender!.uid ==
        loggedInUserId) {
      return false;
    } else {
      return true;
    }
  }

  bool _getHideThreadIndicator(int index) {
    if (conversationList[index].lastMessage?.parentMessageId == null) {
      return true;
    } else if (conversationList[index].lastMessage?.parentMessageId == 0) {
      return true;
    } else {
      return false;
    }
  }

  Widget _getConversationListItem(int index, CometChatTheme _theme) {
    CometChatMenuList? conversationOption;
    if (_isListItemConfigurationPassed == false) {
      conversationOption = _getDefaultMenu(index, this);
    } else {
      conversationOption = _conversationListItemConfiguration
                  .conversationOptions !=
              null
          ? _conversationListItemConfiguration.conversationOptions!(index, this)
          : null;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: CometChatConversationListItem(
        //key: UniqueKey(),
        inputData: _conversationListItemConfiguration.inputData,
        dateConfiguration:
            widget.dateConfiguration ?? const DateConfiguration(),
        statusIndicatorConfiguration: widget.statusIndicatorConfiguration ??
            const StatusIndicatorConfiguration(),
        badgeCountConfiguration:
            widget.badgeCountConfiguration ?? const BadgeCountConfiguration(),
        avatarConfiguration:
            widget.avatarConfiguration ?? const AvatarConfiguration(),
        messageReceiptConfiguration: widget.messageReceiptConfiguration ??
            const MessageReceiptConfiguration(),
        hideThreadIndicator: _getHideThreadIndicator(index),
        conversation: conversationList[index],
        conversationOptions: conversationOption,
        showTypingIndicator:
            typingIndicatorMap.contains(conversationList[index].conversationId),
        hideReceipt: _getHideReceipt(index),
        theme: widget.theme,
        onTap: () async {
          CometChatConversationEvents.onTap(conversationList[index]);
        },
        onLongPress: () {
          CometChatConversationEvents.onLongPress(conversationList[index]);
        },
        style: ConversationListItemStyle(
            background: widget.style.gradient != null
                ? Colors.transparent
                : widget.style.background),
      ),
    );
  }

  _getDefaultMenu(int index, CometChatConversationListState listState) {
    return CometChatMenuList(
      id: 1,
      background: Colors.redAccent,
      icon: const Icon(Icons.delete),
      label: Translations.of(context).delete,
      menuItems: <ActionItem>[
        ActionItem(
            id: "1",
            title: Translations.of(context).delete,
            iconUrlPackageName: UIConstants.packageName,
            iconUrl: "assets/icons/delete.png",
            iconTint: const Color(0xffFFFFFF),

            // icon: Image.asset(
            //   "assets/icons/delete.png",
            //   package: UIConstants.packageName,
            //   color: const Color(0xffFFFFFF),
            // ),
            background: Colors.red,
            onItemClick: () async {
              deleteConversationFromIndex(index);
            }),
      ],
    );
  }

  Widget _getBody(CometChatTheme _theme) {
    if (_showCustomError) {
      //-----------custom error widget-----------
      return widget.customView.error!;
    } else if (isLoading) {
      //-----------loading widget -----------
      return _getLoadingIndicator(_theme);
    } else if (conversationList.isEmpty) {
      //----------- empty list widget-----------
      return _getNoChatIndicator(_theme);
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(0),
        itemCount: hasMoreItems
            ? conversationList.length + 1
            : conversationList.length,
        itemBuilder: (BuildContext context, int index) {
          if (index >= conversationList.length) {
            _loadMore();
            return _getLoadingIndicator(_theme);
          }

          if (conversationList[index].conversationType ==
                  ReceiverTypeConstants.group ||
              conversationList[index].conversationWith is User) {
            return Column(
              children: [
                _getConversationListItem(index, _theme),
                Divider(
                  indent: 72,
                  height: 1,
                  thickness: 1,
                  color: _theme.palette.getAccent100(),
                )
              ],
            );
          }
          if (isLoading) {
            return _getLoadingIndicator(_theme);
          }

          return Container();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    return Container(
      decoration: BoxDecoration(
          color: widget.style.background ?? _theme.palette.getBackground(),
          gradient: widget.style.gradient,
          borderRadius: BorderRadius.all(
              Radius.circular(widget.style.cornerRadius ?? 7.0)),
          border: widget.style.border),
      child: _getBody(_theme),
    );
  }
}
