import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cometchat/models/action.dart' as action;
import '../../shared/utility_components/cometchat_action_sheet/message_option_sheet.dart';
import '../message_bubbles/bubble_utils.dart';

///The [CometChatMessageList] renders a list of messages and passes each individual message
/// object into a [CometChatMessageBubble]. More messages are fetched from the backend and loaded into the DOM on scrolling up the list.
/// Customization of the messages rendered within the list is handled by the [CometChatMessageTemplate] component.
///
/// ```dart
///CometChatMessageList(
///     user: 'superhero1',
///     limit: 30,
///     onlyUnread: false,
///     hideDeletedMessages: false,
///     hideThreadReplies: false,
///     tags: [],
///     excludeMessageTypes: [CometChatUIMessageTypes.image],
///     emptyText: 'No message here yet',
///     errorText: 'Something went wrong',
///     hideError: false,
///     customView: CustomView(),
///     scrollToBottomOnNewMessage: false,
///     enableSoundForMessages: true,
///     customIncomingMessageSound: 'asset url',
///     messageTypes: [
///       TemplateUtils.getDefaultAudioTemplate(),
///       TemplateUtils.getDefaultTextTemplate(),
///       CometChatMessageTemplate(type: 'custom', name: 'custom')
///     ],
///     stateCallBack: (CometChatMessageListState state) {},
///     messageBubbleConfiguration: MessageBubbleConfiguration(),
///     excludedMessageOptions: [
///       MessageOptionConstants.editMessage
///     ],
///     alignment: ChatAlignment.standard,
///     hideMessagesFromBlockedUsers: false,
///     receivedMessageInputData:
///         MessageInputData(title: true, thumbnail: true),
///     sentMessageInputData:
///         MessageInputData(title: false, thumbnail: false),
///   )
///
/// ```

class CometChatMessageList extends StatefulWidget {
  const CometChatMessageList(
      {Key? key,
      this.limit = 30,
      this.onlyUnread = false,
      this.hideMessagesFromBlockedUsers = true,
      this.hideDeletedMessages = false,
      this.threadParentMessageId = 0,
      this.hideThreadReplies = false,
      this.tags,
      this.user,
      this.group,
      this.theme,
      this.stateCallBack,
      this.alignment = ChatAlignment.standard,
      this.sentMessageInputData,
      this.receivedMessageInputData,
      this.excludeMessageTypes,
      this.emptyText,
      this.errorText,
      this.hideError = false,
      this.customView = const CustomView(),
      //this.onErrorCallBack,
      this.scrollToBottomOnNewMessage = false,
      this.messageTypes,
      this.enableSoundForMessages = true,
      this.customIncomingMessageSound,
      this.showEmojiInLargerSize = true,
      this.messageBubbleConfiguration = const MessageBubbleConfiguration(),
      this.excludedMessageOptions,
      this.style = const MessageListStyle(),
      this.notifyParent})
      : super(key: key);

  ///[user] user uid for user message list
  final String? user;

  ///[group] group guid for group message list
  final String? group;

  ///[limit] message limit to be fetched
  final int limit;

  ///[onlyUnread] if true then shows only unread messages
  final bool onlyUnread;

  ///[hideMessagesFromBlockedUsers] if true then hides messages from blocked users
  final bool hideMessagesFromBlockedUsers;

  ///[hideDeletedMessages] if true then hides deleted messages
  final bool hideDeletedMessages;

  ///[threadParentMessageId] parent message id for in thread messages
  final int threadParentMessageId;

  ///[hideThreadReplies] if true then hides thread replies
  final bool hideThreadReplies;

  ///[tags] Search the message with following tags
  final List<String>? tags;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatMessageListState)? stateCallBack;

  ///[alignment] chat alignment left aligned or standard
  final ChatAlignment alignment;

  ///[sentMessageInputData] customise sent message format.
  ///
  /// ```dart
  /// MessageInputData obj = MessageInputData<BaseMessage>(
  ///    title: true,  //Show name of sender
  ///    thumbnail: true, //Show avatar for sender
  ///   readReceipt: true, //show readReceipt for sender
  ///   timestamp: true //Show timestamp for sender
  ///   );
  /// ```
  final MessageInputData? sentMessageInputData;

  ///[receivedMessageInputData] customise received message format.
  ///
  /// ```dart
  /// MessageInputData obj = MessageInputData<BaseMessage>(
  ///    title: true,  //Show name of receiver
  ///    thumbnail: true, //Show avatar for receiver
  ///   readReceipt: true, //show readReceipt for receiver
  ///   timestamp: true //Show timestamp for receiver
  ///   );
  /// ```
  ///
  final MessageInputData? receivedMessageInputData;

  ///[excludeMessageTypes] exclude the types of message that can be to be shown , ideally should be kept same in [CometChatMessageList] and [CometChatMessageComposer]
  /// ```dart
  ///List<String> _excludedTypes = [
  ///  CometChatUIMessageTypes.audio,
  ///  CometChatUIMessageTypes.image
  ///];
  /// ```
  ///
  final List<String>? excludeMessageTypes;

  ///[emptyText] String to be shown when nothing is visible in list
  final String? emptyText;

  ///[errorText] Text to be shown in case of any error
  final String? errorText;

  ///[hideError] to hide the error while fetching data
  final bool hideError;

  ///[customView] allows you to embed a custom view/component for loading, empty and error state.
  ///If no value is set, default view will be rendered.
  final CustomView customView;

  ///[scrollToBottomOnNewMessage]if  true will scroll to bottom on every new message received,
  /// default true
  final bool scrollToBottomOnNewMessage;

  ///[enableSoundForMessages] enable sound for message received , default true
  ///asset sound URL  passed in [customIncomingMessageSound] will be played or default sound will be played
  final bool enableSoundForMessages;

  ///[customIncomingMessageSound] assets url of incoming message custom sound
  final String? customIncomingMessageSound;

  ///[showEmojiInLargerSize] will be in future release
  final bool showEmojiInLargerSize;

  ///[messageTypes] if want to allow specific messages types to be shown.
  ///
  /// ```dart
  ///List<String> _excludedTypes = [
  ///  CometChatUIMessageTypes.audio,
  ///  CometChatUIMessageTypes.image
  ///];
  /// ```
  final List<CometChatMessageTemplate>? messageTypes;

  ///[messageBubbleConfiguration]Configuration related to different bubbles
  final MessageBubbleConfiguration messageBubbleConfiguration;

  ///[excludedMessageOptions] list of options to be excluded.
  ///
  /// ```dart
  ///List<String> _excludedOptions = [
  ///  MessageOptionConstants.editMessage,
  ///  MessageOptionConstants.deleteMessage
  ///];
  /// ```
  final List<String>? excludedMessageOptions;

  ///[style] set styling properties for list
  final MessageListStyle style;

  ///[notifyParent] method to tell parent message List is active
  ///
  ///returns conversationId in id parameter when message renders , and return null as soon as page is destroyed
  ///
  /// can be helpful for parent to know what conversation is open
  final Function(String? id)? notifyParent;

  @override
  CometChatMessageListState createState() => CometChatMessageListState();
}

class CometChatMessageListState extends State<CometChatMessageList>
    with MessageListener, GroupListener {
  final List<BaseMessage> _messageList = <BaseMessage>[];

  final String _messageListenerId = "cometchat_message_list_message_listener";
  final String _groupListenerId = "cometchat_message_list_group_listener";
  ScrollController messageListScrollController = ScrollController();
  bool _isLoading = true;
  bool _hasMore = true;
  bool _showSmartReplies = true;
  bool _showCustomError = false;
  MessagesRequest? messageRequest;
  int newUnreadMessageCount = 0;
  String conversationWithId = "";
  Conversation? conversation;
  String conversationType = "";
  User? loggedInUser;
  late Map<String, List<ActionItem>> _senderTemplateMap;
  late Map<String, List<ActionItem>> _receiverTemplateMap;
  late List<CometChatMessageTemplate> _messageTypes;
  List<String> _messageTypesList = [];
  final List<String> _categoryList = [];
  CometChatTheme theme = cometChatTheme;
  BuildContext? contextForLocalization;

  Map<String, Widget? Function(BaseMessage)?> _templateMapWithView =
      {}; //{text ,  },

  final Map<String, String> _categoryMap = {
    MessageTypeConstants.text: MessageCategoryConstants.message,
    MessageTypeConstants.image: MessageCategoryConstants.message,
    MessageTypeConstants.video: MessageCategoryConstants.message,
    MessageTypeConstants.audio: MessageCategoryConstants.message,
    MessageTypeConstants.file: MessageCategoryConstants.message,
    MessageTypeConstants.custom: MessageCategoryConstants.custom,
    MessageTypeConstants.poll: MessageCategoryConstants.custom,
    MessageTypeConstants.sticker: MessageCategoryConstants.custom,
    MessageTypeConstants.whiteboard: MessageCategoryConstants.custom,
    MessageTypeConstants.document: MessageCategoryConstants.custom,
    MessageTypeConstants.location: MessageCategoryConstants.custom,
    MessageTypeConstants.groupActions: MessageCategoryConstants.action,
  };

  String _getCategory(String type) {
    String? _category = _categoryMap[type];
    return _category ?? MessageCategoryConstants.custom;
  }

  //---------------Public Methods----------------------
  addMessage(BaseMessage message) {
    if (message.parentMessageId == widget.threadParentMessageId) {
      if (_messageList.isNotEmpty) {
        _markAsRead(_messageList[0]);
        messageListScrollController.jumpTo(0.0);
      }
      _messageList.insert(0, message);
      setState(() {});
    }
  }

  updateMessage(BaseMessage message) {
    int matchingIndex =
        _messageList.indexWhere((element) => (element.id == message.id));
    if (matchingIndex != -1) {
      _messageList[matchingIndex] = message;
    }
    setState(() {});
  }

  updateMessageWithMuid(BaseMessage message) {
    int matchingIndex =
        _messageList.indexWhere((element) => (element.muid == message.muid));

    if (matchingIndex != -1) {
      _messageList[matchingIndex] = message;
    }
    setState(() {});
  }

  removeMessage(BaseMessage message) {
    int matchingIndex =
        _messageList.indexWhere((element) => (element.id == message.id));
    if (matchingIndex != -1) {
      _messageList.removeAt(matchingIndex);
    }
    setState(() {});
  }

  deleteMessage(BaseMessage message) async {
    CometChat.deleteMessage(message.id, onSuccess: (updatedMessage) {
      updatedMessage.deletedAt ??= DateTime.now();
      CometChatMessageEvents.onMessageDeleted(updatedMessage);
      if (widget.hideDeletedMessages == true) {
        _messageList.remove(message);
      } else {
        updateMessage(updatedMessage);
      }
      setState(() {});
    }, onError: (_) {});
  }

  reactToMessage(BaseMessage message, String emoji) async {
    _addRemoveReaction(message, emoji);
    CometChat.callExtension(ExtensionConstants.reactions, 'POST',
        ExtensionUrls.reaction, {'msgId': message.id, 'emoji': emoji},
        onSuccess: (Map<String, dynamic> res) {
      debugPrint('$res');
      CometChatMessageEvents.onMessageReact(message, emoji, MessageStatus.sent);
    }, onError: (CometChatException e) {
      _addRemoveReaction(message, emoji);
    });
  }

  //---------------Public Methods end ----------------------

  @override
  void initState() {
    super.initState();
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }

    messageListScrollController.addListener(_scrollControllerListener);
    CometChat.addMessageListener(_messageListenerId, this);
    CometChat.addGroupListener(_groupListenerId, this);
    theme = widget.theme ?? cometChatTheme;
    _setMessageTemplate();
    BubbleUtils.setDownloadFilePath();

    _receiverTemplateMap = _getActionMap(_messageTypes, OptionFor.receiver);
    _senderTemplateMap = _getActionMap(_messageTypes, OptionFor.sender);
    if (widget.user != null) {
      conversationWithId = widget.user!;
      conversationType = ReceiverTypeConstants.user;
    } else {
      conversationWithId = widget.group!;
      conversationType = ReceiverTypeConstants.group;
    }
    _buildMessageRequest();
    _isLoading = true;
    _hasMore = true;
    _loadMore(true);
  }

  @override
  void dispose() {
    super.dispose();
    messageListScrollController.dispose();
    CometChat.removeMessageListener(_messageListenerId);
    CometChat.removeGroupListener(_groupListenerId);
    if (widget.notifyParent != null) {
      widget.notifyParent!(null);
    }
  }

  void _scrollControllerListener() {
    double offset = messageListScrollController.offset;
    if (offset.clamp(0, 10) == offset && newUnreadMessageCount != 0) {
      _markAsRead(_messageList[0]);
      setState(() {
        newUnreadMessageCount = 0;
      });
    }
  }

  _buildMessageRequest() {
    if (widget.user != null) {
      messageRequest = (MessagesRequestBuilder()
            ..uid = widget.user
            ..limit = widget.limit
            ..hideDeleted = widget.hideDeletedMessages
            ..hideMessagesFromBlockedUsers = widget.hideMessagesFromBlockedUsers
            ..tags = widget.tags
            ..hideReplies = widget.hideThreadReplies
            ..unread = widget.onlyUnread
            ..parentMessageId = widget.threadParentMessageId
            ..categories = _categoryList
            ..types = _messageTypesList)
          .build();
    } else {
      messageRequest = (MessagesRequestBuilder()
            ..guid = widget.group
            ..limit = widget.limit
            ..hideDeleted = widget.hideDeletedMessages
            ..hideMessagesFromBlockedUsers = widget.hideMessagesFromBlockedUsers
            ..tags = widget.tags
            ..hideReplies = widget.hideThreadReplies
            ..unread = widget.onlyUnread
            ..parentMessageId = widget.threadParentMessageId
            ..categories = _categoryList
            ..types = _messageTypesList)
          .build();
    }
  }

  // Triggers fetch() and then add new items or change _hasMore flag
  void _loadMore([bool? init]) async {
    _isLoading = true;

    if (init == true) {
      await _getLoggedInUser();
      _getConversationId(conversationWithId, conversationType);
    }

    try {
      messageRequest!.fetchPrevious(onSuccess: (List<BaseMessage> fetchedList) {
        if (fetchedList.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            for (BaseMessage _message in fetchedList.reversed) {
              if (_message is TextMessage) {
                debugPrint(
                    "Message is ${_message.text} ${_message.readAt} ${_message.deletedAt}");
              }
              if (_message.type == MessageCategoryConstants.message &&
                  _message.category == MessageCategoryConstants.action) {
              } else if (_message.parentMessageId ==
                  widget.threadParentMessageId) {
                _messageList.add(_message);
              }
            }
            //_messageList.addAll(fetchedList.reversed);
          });
        }
      }, onError: (CometChatException e) {
        debugPrint('$e');
        if (!mounted) return;
        CometChatMessageEvents.onMessageError(e, null);
        // if (widget.onErrorCallBack != null) {
        //   widget.onErrorCallBack!(e);
        // } else
        if (widget.hideError == false && widget.customView.error != null) {
          _showCustomError = true;
          setState(() {});
        } else if (widget.hideError == false) {
          String _error = Utils.getErrorTranslatedText(context, e.code);
          showCometChatConfirmDialog(
              context: context,
              messageText: Text(widget.errorText ?? _error),
              confirmButtonText: Translations.of(context).try_again,
              cancelButtonText: Translations.of(context).cancel_capital,
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
              onCancel: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              onConfirm: () {
                Navigator.pop(context);
                _loadMore(true);
              });
        }
      });
    } catch (exception) {
      // if (widget.onErrorCallBack != null) {
      //   widget.onErrorCallBack!(exception);
      // } else
      if (widget.hideError == false && widget.customView.error != null) {
        _showCustomError = true;
        setState(() {});
      } else if (widget.hideError == false) {
        showCometChatConfirmDialog(
            context: context,
            messageText: Text(widget.errorText ??
                Translations.of(context).cant_load_messages),
            cancelButtonText: Translations.of(context).cancel_capital,
            confirmButtonText: Translations.of(context).try_again,
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
            onCancel: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            onConfirm: () {
              Navigator.pop(context);
              _loadMore(true);
            });
      }
    }
  }

  _addRemoveReaction(BaseMessage message, String emoji) {
    //---giving reactions first time---
    Map<String, dynamic> metadata = message.metadata ?? <String, dynamic>{};

    if (!metadata.containsKey("@injected")) {
      metadata["@injected"] = <String, dynamic>{};
    }
    Map<String, dynamic> injected = metadata["@injected"];

    if (!injected.containsKey("extensions")) {
      metadata["@injected"]["extensions"] = <String, dynamic>{};
    }
    Map<String, dynamic> extensions = metadata["@injected"]["extensions"];

    if (!extensions.containsKey("reactions")) {
      metadata["@injected"]["extensions"]["reactions"] = <String, dynamic>{};
    }
    Map<String, dynamic> reactions =
        metadata["@injected"]["extensions"]["reactions"];

    if (!reactions.containsKey(emoji)) {
      metadata["@injected"]["extensions"]["reactions"]
          [emoji] = <String, dynamic>{};
    }

    Map<String, dynamic> reactedUsers =
        metadata["@injected"]["extensions"]["reactions"][emoji];

    if (!reactedUsers.containsKey(loggedInUser!.uid)) {
      metadata["@injected"]["extensions"]["reactions"][emoji]
          [loggedInUser!.uid] = {
        "name": loggedInUser!.name,
        "avatar": loggedInUser!.avatar
      };
    } else {
      reactedUsers.remove(loggedInUser!.uid);
      if (reactedUsers.isEmpty) {
        reactions.remove(emoji);
        metadata["@injected"]["extensions"]["reactions"] = reactions;
      } else {
        metadata["@injected"]["extensions"]["reactions"][emoji] = reactedUsers;
      }
    }

    message.metadata = metadata;
    updateMessage(message);
  }

  void _setMessageTemplate() {
    if (widget.messageTypes != null) {
      _messageTypes = widget.messageTypes!;
    } else {
      _messageTypes = TemplateUtils.getDefaultTemplate();
    }
    if (widget.excludeMessageTypes != null) {
      _messageTypes.removeWhere(
          (element) => widget.excludeMessageTypes!.contains(element.type));
    }

    _messageTypesList = _messageTypes.map((e) => e.type).toList();
  }

  _getLoggedInUser() async {
    User? user = await CometChat.getLoggedInUser();
    if (user != null) {
      loggedInUser = user;
    }
  }

  _getConversationId(String conversationWith, String conversationType) {
    CometChat.getConversation(conversationWith, conversationType,
        onSuccess: (Conversation _conversation) {
      conversation = _conversation;
      if (widget.notifyParent != null) {
        widget.notifyParent!(_conversation.conversationId);
      }
      if (conversation?.lastMessage != null) {
        _markAsRead(conversation!.lastMessage!);
      }
    }, onError: (e) {});
  }

  _markAsRead(BaseMessage _message) {
    if (_message.sender?.uid != loggedInUser?.uid && _message.readAt == null) {
      CometChat.markAsRead(_message, onSuccess: (String res) {
        CometChatMessageEvents.onMessageRead(_message);
      }, onError: (e) {});
    }
  }

  Map<String, List<ActionItem>> _getActionMap(
      List<CometChatMessageTemplate> templateList, OptionFor optionFor) {
    Map<String, List<ActionItem>> actionMap = {};

    for (CometChatMessageTemplate template in templateList) {
      template.category ??= _getCategory(template.type);
      _templateMapWithView[template.type] = template.customView;
      String _category = TemplateUtils.getMessageCategory(template.type);
      if (!_categoryList.contains(_category)) _categoryList.add(_category);

      List<ActionItem> actionList = [];
      if (template.options != null) {
        for (CometChatMessageOptions options in template.options!) {
          if (widget.excludedMessageOptions != null) {
            if (widget.excludedMessageOptions!.contains(options.id)) {
              continue;
            } //Excluding Options
          }

          if (options.optionFor != OptionFor.both &&
              options.optionFor != optionFor) {
            continue;
          }
          late ActionItem item;

          if (options.onClick == null) {
            item = options.toActionItemfromFunction(
                _getActionFunction(options.id),
                options.iconTint ??
                    (options.id != MessageOptionConstants.deleteMessage
                        ? theme.palette.getAccent600()
                        : theme.palette.getError()),
                TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: options.id != MessageOptionConstants.deleteMessage
                        ? theme.palette.getAccent()
                        : theme.palette.getError()),
                options.packageName);
          } else {
            item = options.toActionItem();
          }

          actionList.add(item);
        }
      }
      actionMap[template.type] = actionList;
    }
    return actionMap;
  }

//-----message option methods-----

  _reactToMessage(BaseMessage message, String reaction, State state,
      MessageStatus messageStatus) {
    CometChatMessageEvents.onMessageReact(message, reaction, messageStatus);
  }

  _messageEdit(BaseMessage message, State state) {
    CometChatMessageEvents.onMessageEdit(message, MessageEditStatus.inProgress);
  }

  _delete(BaseMessage message, State state) {
    CometChatMessageEvents.onMessageDelete(message);
    deleteMessage(message);
  }

  _replyMessage(BaseMessage message, State state) {
    CometChatMessageEvents.onMessageReply(message);
  }

  _shareMessage(BaseMessage message, State state) {
    //share
    if (message is TextMessage) {
      Share.share(message.text);
    } else if (message is MediaMessage) {
      //Share.shareFiles(['${directory.path}/image.jpg']);
    }
  }

  _copyMessage(BaseMessage message, State state) {
    if (message is TextMessage) {
      Clipboard.setData(ClipboardData(text: message.text));
    }
  }

  _forwardMessage(BaseMessage message, State state) {
    //forward
  }

  _replyInThread(BaseMessage message, State state) {
    CometChatTheme theme = widget.theme ?? cometChatTheme;

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatMessageThread(
                  message: message,
                  theme: theme,
                  group: widget.group,
                  user: widget.user,
                )));
  }

  _translateMessage(BaseMessage message, State state) {
    if (message is TextMessage) {
      CometChat.callExtension(
          'message-translation', 'POST', ExtensionUrls.translate, {
        "msgId": message.id,
        "text": message.text,
        "languages": [Localizations.localeOf(context).languageCode]
      }, onSuccess: (Map<String, dynamic> res) {
        Map<String, dynamic>? data = res["data"];
        if (data != null && data.containsKey('translations')) {
          String? translatedMessage =
              data['translations']?[0]?['message_translated'];

          if (translatedMessage != null && translatedMessage.isNotEmpty) {
            Map<String, dynamic> metadata =
                message.metadata ?? <String, dynamic>{};
            metadata.addAll({'translated_message': translatedMessage});
            updateMessage(message);
          }
        }
      }, onError: (CometChatException e) {
        String _error = Utils.getErrorTranslatedText(context, e.code);
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
            style: ConfirmDialogStyle(
                backgroundColor:
                    widget.style.background ?? theme.palette.getBackground(),
                shadowColor: theme.palette.getAccent300(),
                confirmButtonTextStyle: TextStyle(
                    fontSize: theme.typography.text2.fontSize,
                    fontWeight: theme.typography.text2.fontWeight,
                    color: theme.palette.getPrimary())),
            confirmButtonText: Translations.of(context).okay,
            onConfirm: () {
              Navigator.pop(context);
            });
      });
    }
  }

  Function? _getActionFunction(String id) {
    switch (id) {
      case MessageOptionConstants.editMessage:
        {
          return _messageEdit;
        }
      case MessageOptionConstants.deleteMessage:
        {
          return _delete;
        }
      case MessageOptionConstants.replyMessage:
        {
          return _replyMessage;
        }
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
      case MessageOptionConstants.reactToMessage:
        {
          return _reactToMessage;
        }
      case MessageOptionConstants.translateMessage:
        {
          return _translateMessage;
        }

      default:
        {
          return null;
        }
    }
  }

  _onMessageReceived(BaseMessage message) {
    if (message.conversationId == conversation?.conversationId &&
        message.parentMessageId == widget.threadParentMessageId) {
      _messageList.insert(0, message);
      setState(() {});
      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.incomingMessage,
            customSound: widget.customIncomingMessageSound,
            packageName: widget.customIncomingMessageSound == null ||
                    widget.customIncomingMessageSound == ""
                ? UIConstants.packageName
                : null);
      }

      if (widget.scrollToBottomOnNewMessage) {
        _markAsRead(message);
        messageListScrollController.jumpTo(0.0);
      } else {
        if (messageListScrollController.offset > 100) {
          newUnreadMessageCount++;
        } else {
          _markAsRead(message);
        }
      }
    } else if (message.conversationId == conversation?.conversationId) {
      //incrementing reply count
      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.incomingMessage,
            customSound: widget.customIncomingMessageSound,
            packageName: widget.customIncomingMessageSound == null ||
                    widget.customIncomingMessageSound == ""
                ? UIConstants.packageName
                : null);
      }
      int matchingIndex = _messageList
          .indexWhere((element) => (element.id == message.parentMessageId));
      if (matchingIndex != -1) {
        _messageList[matchingIndex].replyCount++;
      }
      setState(() {});
    }
  }

//-----message listener methods----------------

  @override
  void onTextMessageReceived(TextMessage textMessage) async {
    _showSmartReplies = true;
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
    if (widget.group != null && widget.group!.trim() != '') return;

    for (int i = 0; i < _messageList.length; i++) {
      if (_messageList[i].sender?.uid == loggedInUser?.uid) {
        if (i == 0 || _messageList[i].deliveredAt == null) {
          _messageList[i].deliveredAt = messageReceipt.deliveredAt;
        } else {
          break;
        }
      }
    }
    setState(() {});
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    if (widget.group != null && widget.group!.trim() != '') return;

    for (int i = 0; i < _messageList.length; i++) {
      if (_messageList[i].sender?.uid == loggedInUser?.uid) {
        if (i == 0 || _messageList[i].readAt == null) {
          _messageList[i].readAt = messageReceipt.readAt;
        } else {
          break;
        }
      }
    }
    setState(() {});
  }

  @override
  void onMessageEdited(BaseMessage message) {
    debugPrint("Message Edit call ${message.id}");
    updateMessage(message);
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    int matchingIndex =
        _messageList.indexWhere((element) => (element.id == message.id));
    if (matchingIndex != -1) {
      if (widget.hideDeletedMessages == true) {
        _messageList.removeAt(matchingIndex);
      } else {
        updateMessage(message);
      }
    }
    setState(() {});
  }

  //-----message listener method  end----------------
  //-----group listener methods-----------------------
  @override
  void onMemberAddedToGroup(
      action.Action action, User addedby, User userAdded, Group addedTo) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberJoined(
      action.Action action, User joinedUser, Group joinedGroup) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberLeft(action.Action action, User leftUser, Group leftGroup) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberKicked(
      action.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberBanned(
      action.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberUnbanned(action.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    _onMessageReceived(action);
  }

  @override
  void onGroupMemberScopeChanged(
      action.Action action,
      User updatedBy,
      User updatedUser,
      String scopeChangedTo,
      String scopeChangedFrom,
      Group group) {
    _onMessageReceived(action);
  }

  //-----group listener methods end-----------------------

  _sendSmartReply(String messageText) {
    String receiverID;
    String receiverType;
    if (widget.user != null) {
      receiverID = widget.user!;
      receiverType = ReceiverTypeConstants.user;
    } else if (widget.group != null) {
      receiverID = widget.group!;
      receiverType = ReceiverTypeConstants.group;
    } else {
      return;
    }

    TextMessage textMessage = TextMessage(
        sender: loggedInUser ?? User(name: '', uid: ''),
        text: messageText,
        receiverUid: receiverID,
        receiverType: receiverType,
        type: MessageTypeConstants.text,
        parentMessageId: widget.threadParentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString());

    CometChatMessageEvents.onMessageSent(textMessage, MessageStatus.inProgress);

    CometChat.sendMessage(textMessage, onSuccess: (TextMessage message) {
      debugPrint("Message sent successfully:  ${message.text}");
      if (widget.enableSoundForMessages) {
        SoundManager.play(
          sound: Sound.outgoingMessage,
        );
      }
      CometChatMessageEvents.onMessageSent(message, MessageStatus.sent);
    }, onError: (CometChatException e) {
      if (textMessage.metadata != null) {
        textMessage.metadata!["error"] = true;
      } else {
        textMessage.metadata = {"error": true};
      }
      CometChatMessageEvents.onMessageError(e, textMessage);
      debugPrint("Message sending failed with exception:  ${e.message}");
    });
  }

  Widget _getMessageWidget(BaseMessage messageObject) {
    BubbleAlignment _alignment = BubbleAlignment.right;
    bool _thumbnail = false;
    bool _name = false;
    bool _readReceipt = true;
    bool _timeStamp = true;
    bool isMessageSentByMe = messageObject.sender?.uid == loggedInUser?.uid;

    //-----if message is group action-----
    if (messageObject.category == MessageCategoryConstants.action &&
        messageObject.type == MessageTypeConstants.groupActions) {
      _thumbnail = false;
      _name = false;
      _readReceipt = false;
      _alignment = BubbleAlignment.center;
      _timeStamp = false;
    }
    //-----if message sent by me-----
    else if (isMessageSentByMe) {
      _thumbnail = false;
      _name = false;
      _readReceipt = true;
      _alignment = BubbleAlignment.right;
    }
    //-----if message received in user conversation-----
    else if (widget.user != null) {
      _thumbnail = false;
      _name = false;
      _readReceipt = false;
      _alignment = BubbleAlignment.left;
    }
    //-----if message received in group conversation-----
    else if (widget.group != null) {
      _thumbnail = true;
      _name = true;
      _readReceipt = false;
      _alignment = BubbleAlignment.left;
    }

    Color _backgroundColor = _getBubbleBackgroundColor(messageObject);

    //TODO update after done with message Configuration
    if (widget.alignment == ChatAlignment.leftAligned) {
      _alignment = BubbleAlignment.left;
    }

    MessageInputData _messageBubbleData = MessageInputData(
      thumbnail: _thumbnail,
      title: _name,
      readReceipt: _readReceipt,
      timestamp: _timeStamp,
    );

    if (isMessageSentByMe && widget.sentMessageInputData != null) {
      _messageBubbleData = widget.sentMessageInputData!;
    } else if (!isMessageSentByMe && widget.receivedMessageInputData != null) {
      _messageBubbleData = widget.receivedMessageInputData!;
    }

    return GestureDetector(
      onLongPress: () async {
        CometChatMessageEvents.onMessageLongPress(messageObject);
        await _showOptions(messageObject, theme);
      },
      onTap: () {
        CometChatMessageEvents.onMessageTap(messageObject);
      },
      child: CometChatMessageBubble(
        customView: _templateMapWithView[messageObject.type],
        messageObject: messageObject,
        loggedInUserId: loggedInUser?.uid ?? '',
        messageInputData: _messageBubbleData,
        alignment: _alignment,
        theme: widget.theme,
        receiverGroupId: widget.group,
        receiverUserId: widget.user,
        style: MessageBubbleStyle(
          background: _backgroundColor,
        ),
        avatarConfiguration:
            widget.messageBubbleConfiguration.avatarConfiguration ??
                const AvatarConfiguration(),
        messageReceiptConfiguration:
            widget.messageBubbleConfiguration.messageReceiptConfiguration ??
                const MessageReceiptConfiguration(),
        dateConfiguration:
            widget.messageBubbleConfiguration.dateConfiguration ??
                const DateConfiguration(),
        timeAlignment: widget.messageBubbleConfiguration.timeAlignment ??
            TimeAlignment.bottom,
      ),
    );
  }

  Future<ActionItem?> _showOptions(
    BaseMessage message,
    CometChatTheme theme,
  ) async {
    Map<String, List<ActionItem>> _templateMap;

    if (message.sender?.uid == loggedInUser?.uid) {
      _templateMap = _senderTemplateMap;
    } else {
      _templateMap = _receiverTemplateMap;
    }

    if (_templateMap[message.type] == null ||
        _templateMap[message.type]!.isEmpty ||
        message.deletedAt != null) {
      return null;
    }
    return await showMessageOptionSheet(
        context: context,
        actionItems: _templateMap[message.type]!,
        message: message,
        state: this,
        backgroundColor: theme.palette.getBackground(),
        theme: theme);
  }

  Color _getBubbleBackgroundColor(BaseMessage messageObject) {
    if (messageObject.deletedBy != null && messageObject.deletedBy != '') {
      return theme.palette.getPrimary().withOpacity(0);
    } else if (messageObject.type == MessageTypeConstants.text &&
        messageObject.sender?.uid == loggedInUser?.uid) {
      return theme.palette.getPrimary();
    } else if (messageObject.type == ExtensionType.sticker) {
      return Colors.transparent;
    } else {
      return theme.palette.getSecondary900();
    }
  }

  Widget _getNoChatIndicator() {
    return widget.customView.empty ??
        Center(
          child: Text(
            Translations.of(context).no_messages_here_yet,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: theme.palette.getAccent400()),
          ),
        );
  }

  Widget _getLoadingIndicator() {
    return widget.customView.loading ??
        Center(
          child: Image.asset(
            "assets/icons/spinner.png",
            package: UIConstants.packageName,
            color: theme.palette.getAccent600(),
          ),
        );
  }

  Widget _getNewMessageBanner() {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          messageListScrollController.jumpTo(0.0);
          _markAsRead(_messageList[0]);
        },
        child: Container(
          height: 30,
          width: 160,
          decoration: BoxDecoration(
              color: theme.palette.getPrimary(),
              borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                  "$newUnreadMessageCount ${Translations.of(context).new_messages}"),
              const Icon(
                Icons.arrow_downward,
                size: 18,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _getBody() {
    if (_showCustomError) {
      //-----------custom error widget-----------
      return widget.customView.error!;
    } else if (_isLoading) {
      //-----------loading widget -----------
      return _getLoadingIndicator();
    } else if (_messageList.isEmpty) {
      //----------- empty list widget-----------
      return _getNoChatIndicator();
    } else {
      return Stack(
        children: [
          Column(
            children: [
              Expanded(
                //--------message list--------
                child: ListView.builder(
                  reverse: true,
                  controller: messageListScrollController,
                  itemCount:
                      _hasMore ? _messageList.length + 1 : _messageList.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (index >= _messageList.length) {
                      // Don't trigger if one async loading is already under way
                      if (!_isLoading) {
                        _loadMore();
                      }
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return _getMessageWidget(_messageList[index]);
                  },
                ),
              ),
              if (_showSmartReplies &&
                  _messageList.isNotEmpty &&
                  loggedInUser?.uid != _messageList[0].sender?.uid)
                CometChatSmartReplies(
                  messageObject: _messageList[0],
                  onCloseTap: () {
                    setState(() {
                      _showSmartReplies = false;
                    });
                  },
                  onClick: _sendSmartReply,
                  style: SmartReplyStyle(
                      closeIconColor: theme.palette.getAccent400(),
                      replyBackgroundColor: theme.palette.getBackground(),
                      replyTextStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: theme.palette.getAccent())),
                )
            ],
          ),
          if (newUnreadMessageCount != 0) _getNewMessageBanner()
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: widget.style.gradient == null
              ? widget.style.background ?? theme.palette.getBackground()
              : null,
          gradient: widget.style.gradient),
      child: _getBody(),
    );
  }
}

class MessageListStyle {
  const MessageListStyle({this.background, this.gradient});

  final Color? background;

  final Gradient? gradient;
}
