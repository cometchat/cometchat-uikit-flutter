import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'dart:io';

///[CometChatMessageComposerController] is the view model for [CometChatMessageComposer]
///it contains all the business logic involved in changing the state of the UI of [CometChatMessageComposer]
class CometChatMessageComposerController extends GetxController
    with CometChatMessageEventListener, CometChatUIEventListener {
  CometChatMessageComposerController(
      {this.user,
      this.group,
      this.text,
      this.parentMessageId = 0,
      this.disableSoundForMessages = false,
      this.customSoundForMessage,
      this.customSoundForMessagePackage,
      this.disableTypingEvents = false,
      this.hideLiveReaction = false,
      this.attachmentOptions,
      this.liveReactionIconURL,
      this.stateCallBack,
      this.headerView,
      this.footerView,
      this.onSendButtonTap,
      this.onError,
      this.aiOptionStyle,
      this.disableMentions = false,
      this.previewView,
      this.theme,
      this.textFormatters,
        this.textEditingController,
      }) {
    tag = "tag$counter";
    counter++;
  }

  //-------------------------Variable Declaration-----------------------------

  ///[previewMessageMode] controls the visibility of message preview above input field
  PreviewMessageMode previewMessageMode = PreviewMessageMode.none;

  ///[messagePreviewTitle] title text of message preview
  String? messagePreviewTitle;

  ///[messagePreviewSubtitle] subtitle text of message preview
  String? messagePreviewSubtitle;

  ///[oldMessage] the message to edit
  BaseMessage? oldMessage;

  ///[receiverID] the uid of the user or guid of the group
  String receiverID = "";

  ///[receiverType] type of AppEntity

  String receiverType = "";

  ///[textEditingController] controls the state of the text field
  TextEditingController? textEditingController;

  ///[loggedInUser] is the user the message is being sent from
  User loggedInUser = User(name: '', uid: '');
  final _deBouncer = Debouncer(milliseconds: 1000);

  ///[_previousText] holds the state of the last typed text
  String _previousText = "";

  ///[headerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? footerView;

  ///[previewView] ui component to be forwarded to message composer component, to be shown in place of the message preview bubble
  final ComposerWidgetBuilder? previewView;

  ///[_actionItems] show up in attachment options
  final List<ActionItem> _actionItems = [];

  ///[user] user object to send messages to
  final User? user;

  ///[text] initial text for the input field
  final String? text;

  ///[parentMessageId] parent message id for in thread messages
  final int parentMessageId;

  ///[disableSoundForMessages] if true then disables outgoing message sound
  final bool disableSoundForMessages;

  ///[customSoundForMessage] custom outgoing message sound assets url
  final String? customSoundForMessage;

  ///[group] group object to send messages to
  final Group? group;

  ///[disableTypingEvents] if true then disables is typing indicator
  final bool disableTypingEvents;

  ///[hideLiveReaction] if true hides live reaction option
  bool hideLiveReaction;

  ///[attachmentOptions] options to display on tapping attachment button
  final ComposerActionsBuilder? attachmentOptions;

  ///[liveReactionIconURL] is the path of the icon to show in the live reaction button
  final String? liveReactionIconURL;

  ///if sending sound url from other package pass package name here
  final String? customSoundForMessagePackage;

  ///[stateCallBack] retrieves the state of the composer
  final void Function(CometChatMessageComposerController)? stateCallBack;

  ///[onSendButtonTap] some task to execute if user presses the primary/send button
  final Function(BuildContext, BaseMessage, PreviewMessageMode?)?
      onSendButtonTap;

  ///[onError] callback triggered in case any error happens when sending a message
  final OnError? onError;

  ///[_isTyping] state of typing events
  bool _isTyping = false;

  ///[getAttachmentOptionsCalled] is used to call attachment options only once
  bool getAttachmentOptionsCalled = false;

  late BuildContext context;

  static int counter = 0;
  late String tag;

  late String _dateString;
  late String _uiMessageListener;
  late String _uiEventListener;

  ///[header] shown in header view
  Widget? header;

  ///[footer] shown in footer view
  Widget? footer;

  ///[preview] shown in preview view
  Widget? preview;

  Map<String, dynamic> composerId = {};

  AIOptionsStyle? aiOptionStyle;

  late FocusNode focusNode;

  List<SuggestionListItem> suggestions = [];
  late StreamSubscription<List<SuggestionListItem>> _subscription;

  /// Create a stream controller
  final StreamController<List<SuggestionListItem>> _suggestionListController =
      StreamController<List<SuggestionListItem>>();

  /// Create a stream from the controller
  late Stream<List<SuggestionListItem>> _suggestionListStream;

  /// Create a stream controller
  final StreamController<String> _previousTextController =
      StreamController<String>();

  /// Create a stream from the controller
  late Stream<String> _previousTextStream;

  bool _isMyController = true;

  String? _currentSearchKeyword;
  bool _searcKeywordChanged = true;
  bool disableMentions;

  CometChatTheme? theme;

  List<CometChatTextFormatter> _formatters = [];

  ///[textFormatters] is a list of [CometChatTextFormatter] which is used to format the text
  List<CometChatTextFormatter>? textFormatters;

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    if(textEditingController != null) {
      _isMyController = false;
    }
    populateComposerId();
    _suggestionListStream = _suggestionListController.stream;
    _previousTextStream = _previousTextController.stream;

    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiMessageListener = "${_dateString}UI_message_listener";
    _uiEventListener = "${_dateString}UI_event_listener";

    /// Subscribe to the stream
    _subscription =
        _suggestionListStream.listen((List<SuggestionListItem> value) {
      bool shouldScrollDown = false;
      if (value.isNotEmpty && _currentSearchKeyword != null) {
        if (_searcKeywordChanged) {
          suggestions = value;
          _searcKeywordChanged = false;
        } else {
          for (var element in value) {
            if (!suggestions.contains(element)) {
              suggestions.add(element);
            }
          }

          shouldScrollDown = true;
        }
        hasMore = true;
        update();

        CometChatUIEvents.showPanel(
            composerId,
            CustomUIPosition.composerPreview,
            (context) => getList(context, textEditingController!));
        if (shouldScrollDown) {
          _scrollDown();
        }
      } else {
        if (_searcKeywordChanged) {
          CometChatUIEvents.hidePanel(
              composerId, CustomUIPosition.composerPreview);
          suggestions.clear();
        }
        /// suggestions.clear();
        /// CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerPreview);
        hasMore = false;
        update();
      }
    });

    _previousTextStream.listen((String value) {
      _previousText = value;
    });

    initializeFormatters();
    textEditingController ??= CustomTextEditingController(
          text: text, theme: cometChatTheme, formatters: _formatters);

    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    CometChatUIEvents.addUiListener(_uiEventListener, this);

    if (stateCallBack != null) {
      stateCallBack!(this);
    }

    if (user != null) {
      receiverID = user!.uid;
      receiverType = ReceiverTypeConstants.user;
    } else if (group != null) {
      receiverID = group!.guid;
      receiverType = ReceiverTypeConstants.group;
    }

    _getLoggedInUser();

    focusNode = FocusNode();

    focusNode.addListener(_onFocusChange);

    super.onInit();
  }

  void initializeFormatters() {
    _formatters = textFormatters ?? [];

    if ((_formatters.isEmpty ||
            _formatters.indexWhere(
                    (element) => element is CometChatMentionsFormatter) ==
                -1) &&
        disableMentions != true) {
      _formatters.add(CometChatMentionsFormatter());
    }

    for (var element in _formatters) {
      element.theme = theme ?? cometChatTheme;
      element.composerId = composerId;
      element.suggestionListEventSink = _suggestionListController.sink;
      element.previousTextEventSink = _previousTextController.sink;
      element.onSearch = _onFormatterSearch;
      element.user = user;
      element.group = group;
      element.init();
    }
  }

  void _onFormatterSearch(String? searchKeyword) {
    _searcKeywordChanged = _currentSearchKeyword != searchKeyword;
    _currentSearchKeyword = searchKeyword;

    if (_currentSearchKeyword == null) {
      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerPreview);
      suggestions.clear();
    }
    update();

    return;
  }

  final ScrollController _controller = ScrollController();

  /// This is what you're looking for!
  void _scrollDown() {
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  populateComposerId() {
    if (parentMessageId != 0) {
      composerId['parentMessageId'] = parentMessageId;
    }
    if (group != null) {
      composerId['guid'] = group!.guid;
    } else if (user != null) {
      composerId['uid'] = user!.uid;
    }
  }

  @override
  void onClose() {
    if(_isMyController) {
      textEditingController?.dispose();
    }
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    CometChatUIEvents.removeUiListener(_uiEventListener);
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    _subscription.cancel();
    super.onClose();
  }

  bool hasMore = true;

  Widget getList(
      BuildContext context, TextEditingController textEditingController) {
    CometChatTheme theme = cometChatTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: suggestions.length > 4
            ? 220
            : suggestions.isEmpty
                ? 50
                : suggestions.length * 55.0,
      ),
      decoration: BoxDecoration(
        color: theme.palette.backGroundColor.light,
        border: Border(
            top: BorderSide(color: theme.palette.getAccent100(), width: .72)),
      ),
      child: ListView.separated(
        controller: _controller,
        itemCount: hasMore ? suggestions.length + 1 : suggestions.length,
        itemBuilder: (context, index) {
          if (hasMore && index >= suggestions.length) {
            for (var element in _formatters) {
              if (_currentSearchKeyword != null &&
                  _currentSearchKeyword!.isNotEmpty &&
                  element.trackingCharacter == _currentSearchKeyword![0]) {
                element.onScrollToBottom(textEditingController);
              }
            }

            return const SizedBox();
          }

          return index < suggestions.length
              ? getListItem(suggestions[index], theme)
              : const SizedBox();
        },
        separatorBuilder: (BuildContext context, int index) {
          if (index >= suggestions.length - 1) {
            return const SizedBox();
          }
          return Divider(
            height: 1,
            thickness: 1,
            color: theme.palette.getAccent100(),
          );
        },
      ),
    );
  }

  Widget getListItem(SuggestionListItem item, CometChatTheme theme) {
    ListTile tile = ListTile(
      onTap: () {
        if (item.onTap != null) {
          item.onTap!();
        }
        suggestions.clear();
        _currentSearchKeyword = null;
        _searcKeywordChanged = true;
      },
      title: Text(
        item.title ?? "",
        style: TextStyle(
            fontSize: theme.typography.body.fontSize,
            fontWeight: theme.typography.body.fontWeight,
            fontFamily: theme.typography.body.fontFamily,
            color: theme.palette.getAccent()),
      ),
      leading: item.avatarName == null && item.avatarUrl == null
          ? null
          : CometChatAvatar(
              name: item.avatarName,
              image: item.avatarUrl,
            ),
    );

    return tile;
  }

  //------------------------Message UI Event Listeners------------------------------

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.inProgress &&
        message.parentMessageId == parentMessageId) {
      previewMessage(message, PreviewMessageMode.edit);
    }
  }

  @override
  void ccComposeMessage(String text, MessageEditStatus status) {
    textEditingController?.text = text;
    _previousText = text;
    update();
  }

  @override
  void showPanel(Map<String, dynamic>? id, CustomUIPosition uiPosition,
      WidgetBuilder child) {
    if (kDebugMode) {
      print("is for this ID $id ${isForThisWidget(id)}");
    }
    if (isForThisWidget(id) == false) return;
    if (uiPosition == CustomUIPosition.composerBottom) {
      footer = child(context);
    } else if (uiPosition == CustomUIPosition.composerTop) {
      header = child(context);
    } else if (uiPosition == CustomUIPosition.composerPreview) {
      preview = child(context);
    }
    update();
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    if (isForThisWidget(id) == false) return;
    if (uiPosition == CustomUIPosition.composerBottom) {
      footer = null;
    } else if (uiPosition == CustomUIPosition.composerTop) {
      header = null;
    } else if (uiPosition == CustomUIPosition.composerPreview) {
      preview = null;
    }
    update();
  }

  bool isSameConversation(BaseMessage message) {
    return true;
  }

  //-----------------------Internal Dependency Initialization-------------------------
  initializeHeaderAndFooterView() {
    if (headerView != null) {
      header = headerView!(context, user, group, composerId);
    }

    if (footerView != null) {
      footer = footerView!(context, user, group, composerId);
    }
  }

  _getLoggedInUser() async {
    User? user = await CometChat.getLoggedInUser();
    if (user != null) {
      loggedInUser = user;
    }
  }

  getAttachmentOptions(CometChatTheme theme, BuildContext context) {
    if (attachmentOptions != null) {
      List<CometChatMessageComposerAction> actionList =
          attachmentOptions!(context, user, group, {});

      for (CometChatMessageComposerAction attachmentOption in actionList) {
        _actionItems.add(ActionItem(
            id: attachmentOption.id,
            title: attachmentOption.title,
            iconUrl: attachmentOption.iconUrl,
            iconUrlPackageName: attachmentOption.iconUrlPackageName,
            titleStyle: attachmentOption.titleStyle ??
                TextStyle(
                    color: theme.palette.getAccent(),
                    fontSize: theme.typography.subtitle1.fontSize,
                    fontWeight: theme.typography.subtitle1.fontWeight),
            iconTint: attachmentOption.iconTint ?? theme.palette.getAccent700(),
            background: attachmentOption.background,
            cornerRadius: attachmentOption.cornerRadius,
            iconBackground: attachmentOption.iconBackground,
            iconCornerRadius: attachmentOption.iconCornerRadius,
            onItemClick: attachmentOption.onItemClick));
      }
    } else {
      final defaultOptions = CometChatUIKit.getDataSource()
          .getAttachmentOptions(theme, context, composerId);

      for (CometChatMessageComposerAction attachmentOption in defaultOptions) {
        _actionItems.add(ActionItem(
            id: attachmentOption.id,
            title: attachmentOption.title,
            iconUrl: attachmentOption.iconUrl,
            iconUrlPackageName: attachmentOption.iconUrlPackageName,
            titleStyle: attachmentOption.titleStyle ??
                TextStyle(
                    color: theme.palette.getAccent(),
                    fontSize: theme.typography.subtitle1.fontSize,
                    fontWeight: theme.typography.subtitle1.fontWeight),
            iconTint: attachmentOption.iconTint ?? theme.palette.getAccent700(),
            background: attachmentOption.background,
            cornerRadius: attachmentOption.cornerRadius,
            iconBackground: attachmentOption.iconBackground,
            iconCornerRadius: attachmentOption.iconCornerRadius,
            onItemClick: attachmentOption.onItemClick));
      }
    }
  }

  //-----------------------methods performing API calls-----------------------------

  _checkFormatter() {
    for (var element in _formatters) {
      if (_currentSearchKeyword == null ||
          (_currentSearchKeyword != null &&
              _currentSearchKeyword!.isNotEmpty &&
              element.trackingCharacter == _currentSearchKeyword![0])) {
        try {
          element.onChange(textEditingController!, _previousText);
        } catch (err) {
          if (kDebugMode) {
            print("error caught in message composer onchange $err");
          }
        }
      }
    }
  }

  _onTyping() {
    if(textEditingController == null) return;
    if ((_previousText.isEmpty && textEditingController!.text.isNotEmpty) ||
        (_previousText.isNotEmpty &&  textEditingController!.text.isEmpty)) {
      update();
    }

    if ( _previousText.length > textEditingController!.text.length) {
      _checkFormatter();
      _previousText = textEditingController!.text;
      return;
    }

    _checkFormatter();
    _previousText = textEditingController!.text;

    if (disableTypingEvents == false) {
      if (_isTyping == false) {
        CometChat.startTyping(
            receaverUid: receiverID, receiverType: receiverType);
        _isTyping = true;
      }
      //turns off emitting typing events if user doesn't types something in the last 1000 milliseconds
      _deBouncer.run(() {
        if (_isTyping) {
          CometChat.endTyping(
              receaverUid: receiverID, receiverType: receiverType);
          _isTyping = false;
        }
      });
    }
  }

  handlePreMessageSend(BaseMessage baseMessage) {
    for (var element in _formatters) {
      element.handlePreMessageSend(context, baseMessage);
    }
  }

  sendTextMessage({Map<String, dynamic>? metadata}) {
    if(textEditingController == null) return;
    String messagesText = textEditingController!.text;
    String type = MessageTypeConstants.text;

    TextMessage textMessage = TextMessage(
      sender: loggedInUser,
      text: messagesText,
      receiverUid: receiverID,
      receiverType: receiverType,
      type: type,
      metadata: metadata,
      parentMessageId: parentMessageId,
      muid: DateTime.now().microsecondsSinceEpoch.toString(),
      category: CometChatMessageCategory.message,
    );

    handlePreMessageSend(textMessage);

    oldMessage = null;
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    textEditingController?.clear();
    _previousText = '';
    update();
    if (onSendButtonTap != null) {
      onSendButtonTap!(context, textMessage, previewMessageMode);
    } else {
      CometChatMessageEvents.ccMessageSent(
          textMessage, MessageStatus.inProgress);

      CometChat.sendMessage(textMessage, onSuccess: (TextMessage message) {
        debugPrint("Message sent successfully:  ${message.text}");
        if (disableSoundForMessages == false) {
          CometChatUIKit.soundManager.play(
              sound: Sound.outgoingMessage,
              customSound: customSoundForMessage,
              packageName:
                  customSoundForMessage == null || customSoundForMessage == ""
                      ? UIConstants.packageName
                      : customSoundForMessagePackage);
        }
        CometChatMessageEvents.ccMessageSent(message, MessageStatus.sent);
      },
          onError: onError ??
              (CometChatException e) {
                if (textMessage.metadata != null) {
                  textMessage.metadata!["error"] = e;
                } else {
                  textMessage.metadata = {"error": e};
                }
                CometChatMessageEvents.ccMessageSent(
                    textMessage, MessageStatus.error);
                debugPrint(
                    "Message sending failed with exception:  ${e.message}");
              });
    }
  }

  sendMediaMessage(
      {required String path,
      required String messageType,
      Map<String, dynamic>? metadata}) async {
    String muid = DateTime.now().microsecondsSinceEpoch.toString();

    MediaMessage mediaMessage = MediaMessage(
      receiverType: receiverType,
      type: messageType,
      receiverUid: receiverID,
      file: path,
      metadata: metadata,
      sender: loggedInUser,
      parentMessageId: parentMessageId,
      muid: muid,
      category: CometChatMessageCategory.message,
    );

    CometChatMessageEvents.ccMessageSent(
        mediaMessage, MessageStatus.inProgress);

    //for sending files
    MediaMessage mediaMessage2 = MediaMessage(
      receiverType: receiverType,
      type: messageType,
      receiverUid: receiverID,
      //file: Platform.isIOS ? 'file://${pickedFile.path}' : pickedFile.path,

      file: (Platform.isIOS && (!path.startsWith('file://')))
          ? 'file://$path'
          : path,
      metadata: metadata,
      sender: loggedInUser,
      parentMessageId: parentMessageId,
      muid: muid,
      category: CometChatMessageCategory.message,
    );

    if (textEditingController != null && textEditingController!.text.isNotEmpty) {
      textEditingController?.clear();
      _previousText = '';
      update();
    }

    await CometChat.sendMediaMessage(mediaMessage2,
        onSuccess: (MediaMessage message) async {
      debugPrint("Media message sent successfully: ${mediaMessage.muid}");

      if (Platform.isIOS) {
        if (message.file != null) {
          message.file = message.file?.replaceAll("file://", '');
        }
      } else {
        message.file = path;
      }

      _playSound();

      CometChatMessageEvents.ccMessageSent(message, MessageStatus.sent);
    },
        onError: onError ??
            (e) {
              if (mediaMessage.metadata != null) {
                mediaMessage.metadata!["error"] = e;
              } else {
                mediaMessage.metadata = {"error": e};
              }
              CometChatMessageEvents.ccMessageSent(
                  mediaMessage, MessageStatus.error);
              debugPrint(
                  "Media message sending failed with exception: ${e.message}");
            });
  }

  editTextMessage() {
    if(textEditingController == null) return;
    TextMessage editedMessage = oldMessage as TextMessage;
    editedMessage.text = textEditingController!.text;
    handlePreMessageSend(editedMessage);
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    textEditingController?.clear();
    _previousText = '';
    update();
    editedMessage.reactions = [];
    editedMessage.mentionedUsers = [];

    CometChat.editMessage(editedMessage,
        onSuccess: (BaseMessage updatedMessage) {
      _playSound();

      CometChatMessageEvents.ccMessageEdited(
          updatedMessage, MessageEditStatus.success);
    },
        onError: onError ??
            (CometChatException e) {
              if (editedMessage.metadata != null) {
                editedMessage.metadata!["error"] = e;
              } else {
                editedMessage.metadata = {"error": e};
              }
              CometChatMessageEvents.ccMessageSent(
                  editedMessage, MessageStatus.error);

              if (kDebugMode) {
                debugPrint(
                    "Message editing failed with exception: ${e.message}");
              }
            });

    update();
  }

  sendCustomMessage(Map<String, String> customData, String type) {
    CustomMessage customMessage = CustomMessage(
        receiverUid: receiverID,
        type: type,
        customData: customData,
        receiverType: receiverType,
        sender: loggedInUser,
        parentMessageId: parentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CometChatMessageCategory.custom);

    CometChatMessageEvents.ccMessageSent(
        customMessage, MessageStatus.inProgress);

    CometChat.sendCustomMessage(customMessage,
        onSuccess: (CustomMessage message) {
      debugPrint("Custom Message Sent Successfully : $message");

      _playSound();

      CometChatMessageEvents.ccMessageSent(message, MessageStatus.sent);
    },
        onError: onError ??
            (CometChatException e) {
              if (customMessage.metadata != null) {
                customMessage.metadata!["error"] = e;
              } else {
                customMessage.metadata = {"error": e};
              }
              CometChatMessageEvents.ccMessageSent(
                  customMessage, MessageStatus.error);
              debugPrint(
                  "Custom message sending failed with exception: ${e.message}");
            });
  }

  sendLiveReaction() {
    CometChatMessageEvents.ccLiveReaction(
        liveReactionIconURL ?? AssetConstants.heart,
        user?.uid ?? group?.guid ?? '');
    TransientMessage transientMessage = TransientMessage(
        receiverType: receiverType,
        data: {
          "type": "live_reaction",
          'reaction': "heart",
          "packageName": UIConstants.packageName
        },
        receiverId: receiverID);
    CometChat.sendTransientMessage(transientMessage, onSuccess: () {
      debugPrint("Success");
    },
        onError: onError ??
            (CometChatException e) {
              debugPrint(e.message);
            });
  }

  //----------------------------methods used internally----------------------------
  //triggered if developer doesn't pass their onChange handler
  onChange(val) {
    //we are not exposing our internal onChange handler
    //hence allowing a to interact with our controller only through a limited interface
    _onTyping();
  }

  //triggers message preview view of the message composer view
  previewMessage(BaseMessage message, PreviewMessageMode mode) {
    if (mode == PreviewMessageMode.edit) {
      messagePreviewTitle = cc.Translations.of(context).editMessage;
    } else if (mode == PreviewMessageMode.reply) {
      messagePreviewTitle = message.sender?.name;
    }
    if (message is TextMessage) {
      String previewText = message.text;
      if (message.mentionedUsers.isNotEmpty) {
        previewText = CometChatMentionsFormatter.getTextWithMentions(
            message.text, message.mentionedUsers);
      }
      messagePreviewSubtitle = previewText;
    } else {
      messagePreviewSubtitle = CometChatUIKit.getDataSource()
          .getMessageTypeToSubtitle(message.type, context);
    }

    if (mode == PreviewMessageMode.edit && message is TextMessage) {
      textEditingController?.text = message.text;

      _previousText = message.text;

      if (message.mentionedUsers.isNotEmpty) {
        int mentionFormatterIndex = _formatters
            .indexWhere((element) => element.trackingCharacter == '@');
        if (textEditingController != null && mentionFormatterIndex != -1) {
          CometChatMentionsFormatter mentionsFormatter =
              _formatters[mentionFormatterIndex] as CometChatMentionsFormatter;
          mentionsFormatter.onMessageEdit(textEditingController!,
              mentionedUsers: message.mentionedUsers);
        }
      }
    }
    previewMessageMode = mode;
    oldMessage = message;

    update();
  }

  //shows attachment options
  showBottomActionSheet(CometChatTheme theme, BuildContext context) async {
    ActionItem? item = await showCometChatActionSheet(
        context: context,
        actionItems: _actionItems,
        titleStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: theme.palette.getAccent()),
        backgroundColor: theme.palette.getBackground(),
        iconBackground: theme.palette.getAccent100(),
        layoutIconColor: theme.palette.getPrimary());

    if (item == null) {
      return;
    }
    if (item.onItemClick != null &&
        item.onItemClick is Function(BuildContext, User?, Group?)) {
      try {
        if (context.mounted) {
          item.onItemClick(context, user, group);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("the option could not be executed");
        }
      }
    } else {
      PickedFile? pickedFile;
      String? type;

      if (item.id == 'photoAndVideo') {
        pickedFile = await MediaPicker.pickImageVideo();
        type = pickedFile?.fileType;
      } else if (item.id == 'takePhoto') {
        pickedFile = await MediaPicker.takePhoto();
        type = MessageTypeConstants.image;
      } else if (item.id == MessageTypeConstants.file) {
        pickedFile = await MediaPicker.pickAnyFile();
        type = MessageTypeConstants.file;
      } else if (item.id == MessageTypeConstants.audio) {
        pickedFile = await MediaPicker.pickAudio();
        type = MessageTypeConstants.audio;
      } else if (item.id == MessageTypeConstants.image) {
        pickedFile = await MediaPicker.pickImage();
        type = MessageTypeConstants.image;
      } else if (item.id == MessageTypeConstants.video) {
        pickedFile = await MediaPicker.pickVideo();
        type = MessageTypeConstants.video;
      }

      if (pickedFile != null && type != null) {
        if (kDebugMode) {
          debugPrint("File Path is: ${pickedFile.path}");
        }
        sendMediaMessage(path: pickedFile.path, messageType: type);
      }
    }
  }

  //shows CometChat's emoji keyboard
  useEmojis(BuildContext context, CometChatTheme theme) async {
    String? emoji = await showCometChatEmojiKeyboard(
        context: context,
        backgroundColor: theme.palette.getBackground(),
        titleStyle: TextStyle(
            fontSize: 17,
            fontWeight: theme.typography.name.fontWeight,
            color: theme.palette.getAccent()),
        categoryLabel: TextStyle(
            fontSize: theme.typography.caption1.fontSize,
            fontWeight: theme.typography.caption1.fontWeight,
            color: theme.palette.getAccent600()),
        dividerColor: theme.palette.getAccent100(),
        selectedCategoryIconColor: theme.palette.getPrimary(),
        unselectedCategoryIconColor: theme.palette.getAccent600());
    if (emoji != null) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
        CometChatUIEvents.hidePanel(
            composerId, CustomUIPosition.composerBottom);
      }
      _addEmojiToText(emoji);
    }
  }

//triggered if developer doesn't pass their onSendButtonClick handler
  onSendButtonClick() {
    if (textEditingController != null && textEditingController!.text.isNotEmpty) {
      if (previewMessageMode == PreviewMessageMode.none) {
        sendTextMessage();
      } else if (previewMessageMode == PreviewMessageMode.edit) {
        editTextMessage();
      } else if (previewMessageMode == PreviewMessageMode.reply) {
        Map<String, dynamic> metadata = {};
        metadata["reply-message"] = oldMessage!.toJson();

        sendTextMessage(metadata: metadata);
      }
    }
  }

  //closes message preview view
  onMessagePreviewClose() {
    previewMessageMode = PreviewMessageMode.none;
    messagePreviewTitle = "";
    messagePreviewSubtitle = "";
    update();
    debugPrint('close preview requested');
  }

//plays sound on message sent
  _playSound() {
    if (disableSoundForMessages == false) {
      CometChatUIKit.soundManager.play(
          sound: Sound.outgoingMessage,
          customSound: customSoundForMessage,
          packageName:
              customSoundForMessage == null || customSoundForMessage == ""
                  ? UIConstants.packageName
                  : customSoundForMessagePackage);
    }
  }

//inserts emojis to correct position in the text
  _addEmojiToText(String emoji) {
    if (textEditingController == null) return;
    int cursorPosition = textEditingController!.selection.base.offset;
    if (cursorPosition == -1) {
      cursorPosition = textEditingController!.text.length;
    }

    //get the text on the right side of cursor
    String textRightOfCursor =
        textEditingController!.text.substring(cursorPosition);

    //get the text on the left side of cursor
    String textLeftOfCursor =
        textEditingController!.text.substring(0, cursorPosition);

    //insert the emoji in the correct order
    textEditingController!.text = textLeftOfCursor + emoji + textRightOfCursor;

    //move the cursor to the end of the added emoji
    textEditingController?.selection = TextSelection(
      baseOffset: cursorPosition + emoji.length,
      extentOffset: cursorPosition + emoji.length,
    );

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
      if (id['parentMessageId'] != null &&
          id['parentMessageId'] != parentMessageId) {
        //Checking if parent message id exist then match or not
        return false;
      } else {
        return true;
      }
    }
    return false;
  }

  void _onFocusChange() {
    if (focusNode.hasFocus) {
      CometChatUIEvents.hidePanel(composerId, CustomUIPosition.composerBottom);
    }
  }

  void sendMediaRecording(BuildContext context, String path) {
    if (onSendButtonTap != null) {
      MediaMessage mediaMessage = MediaMessage(
        receiverType: receiverType,
        type: MessageTypeConstants.audio,
        receiverUid: receiverID,
        file: path,
        sender: loggedInUser,
        parentMessageId: parentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CometChatMessageCategory.message,
      );
      onSendButtonTap!(context, mediaMessage, previewMessageMode);
    } else {
      sendMediaMessage(path: path, messageType: MessageTypeConstants.audio);
    }
  }

  aiButtonTap(
    CometChatTheme theme,
    BuildContext context,
    id,
  ) async {
    List<CometChatMessageComposerAction> aiFeatureList =
        CometChatUIKit.getDataSource()
            .getAIOptions(user, group, theme, context, id, aiOptionStyle);

    if (aiFeatureList.isNotEmpty) {
      List<CometChatMessageComposerAction> actionList = [];

      for (int i = 0; i < aiFeatureList.length; i++) {
        actionList.add(CometChatMessageComposerAction(
            id: aiFeatureList[i].id,
            title: aiFeatureList[i].title,
            titleStyle:
                aiFeatureList[i].titleStyle ?? aiOptionStyle?.itemTextStyle,
            background:
                aiFeatureList[i].background ?? aiOptionStyle?.background,
            cornerRadius:
                aiFeatureList[i].cornerRadius ?? aiOptionStyle?.borderRadius,
            onItemClick: (BuildContext context, User? user, Group? group) {
              if (aiFeatureList[i].onItemClick != null) {
                aiFeatureList[i].onItemClick!(context, user, group);
              }
            }));
      }

      showCometChatAiOptionSheet(
        context: context,
        theme: theme,
        user: user,
        group: group,
        actionItems: actionList,
        backgroundColor: theme.palette.getBackground(),
      );

      return;
    }
  }
}
