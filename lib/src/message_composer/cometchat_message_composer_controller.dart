import 'package:get/get_state_manager/get_state_manager.dart';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/debouncer.dart';
import 'dart:io';
import '../utils/media_picker.dart';

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
      this.onError}) {
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
  late TextEditingController textEditingController;

  ///[loggedInUser] is the user the message is being sent from
  User loggedInUser = User(name: '', uid: '');
  final _deBouncer = Debouncer(milliseconds: 1000);

  ///[_previousText] holds the state of the last typed text
  String _previousText = "";

  ///[headerView] ui component to be forwarded to message input component
  final Widget? Function(BuildContext, {User? user, Group? group})? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final Widget? Function(BuildContext, {User? user, Group? group})? footerView;

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
  final List<CometChatMessageComposerAction>? attachmentOptions;

  ///[liveReactionIconURL] is the path of the icon to show in the live reaction button
  final String? liveReactionIconURL;

  ///if sending sound url from other package pass package name here
  final String? customSoundForMessagePackage;

  ///[stateCallBack]
  final void Function(CometChatMessageComposerController)? stateCallBack;

  ///[onError] callback triggered in case any error happens when fetching users
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

  Map<String, dynamic> composerId = {};

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiMessageListener = "${_dateString}UI_message_listener";
    _uiEventListener = "${_dateString}UI_event_listener";
    textEditingController = TextEditingController(text: text);

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
    populateComposerId();

    super.onInit();
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
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    CometChatUIEvents.removeUiListener(_uiEventListener);
    textEditingController.dispose();
    super.onClose();
  }

  //------------------------Message UI Event Listeners------------------------------

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.inProgress &&
        message.parentMessageId == parentMessageId) {
      previewMessage(message, PreviewMessageMode.edit);
    }
  }

  // @override
  // void onMessageReply(BaseMessage message) {
  //   if (message.parentMessageId==parentMessageId) {
  //     previewMessage(message, PreviewMessageMode.reply);
  //   }
  // }

  @override
  void showPanel(
      Map<String, dynamic>? id, alignment align, WidgetBuilder child) {
    // print("listen show panel");
    if (isForThisWidget(id) == false) return;
    if (align == alignment.composerBottom) {
      footer = child(context);
    } else if (align == alignment.composerTop) {
      header = child(context);
    }
    update();
  }

  @override
  void hidePanel(Map<String, dynamic>? id, alignment align) {
    if (isForThisWidget(id) == false) return;
    if (align == alignment.composerBottom) {
      footer = null;
    } else if (align == alignment.composerTop) {
      header = null;
    }
    update();
  }

  bool isSameConversation(BaseMessage message) {
    return true;
  }

  //-----------------------Internal Dependency Initialization-------------------------
  initializeHeaderAndFooterView() {
    if (headerView != null) {
      header = headerView!(context, user: user, group: group);
    }

    if (footerView != null) {
      footer = footerView!(context, user: user, group: group);
    }
  }

  _getLoggedInUser() async {
    User? user = await CometChat.getLoggedInUser();
    if (user != null) {
      loggedInUser = user;
    }
  }

  getAttachmentOptions(CometChatTheme _theme, BuildContext context) {
    if (attachmentOptions != null && attachmentOptions!.isNotEmpty) {
      for (CometChatMessageComposerAction attachmentOption
          in attachmentOptions!) {
        _actionItems.add(ActionItem(
            id: attachmentOption.id,
            title: attachmentOption.title,
            iconUrl: attachmentOption.iconUrl,
            iconUrlPackageName: attachmentOption.iconUrlPackageName,
            titleStyle: attachmentOption.titleStyle ??
                TextStyle(
                    color: _theme.palette.getAccent(),
                    fontSize: _theme.typography.subtitle1.fontSize,
                    fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint:
                attachmentOption.iconTint ?? _theme.palette.getAccent700(),
            background: attachmentOption.background,
            cornerRadius: attachmentOption.cornerRadius,
            iconBackground: attachmentOption.iconBackground,
            iconCornerRadius: attachmentOption.iconCornerRadius,
            onItemClick: attachmentOption.onItemClick));
      }
    } else {
      final defaultOptions = ChatConfigurator.getDataSource()
          .getAttachmentOptions(_theme, context, composerId);

      for (CometChatMessageComposerAction attachmentOption in defaultOptions) {
        _actionItems.add(ActionItem(
            id: attachmentOption.id,
            title: attachmentOption.title,
            iconUrl: attachmentOption.iconUrl,
            iconUrlPackageName: attachmentOption.iconUrlPackageName,
            titleStyle: attachmentOption.titleStyle ??
                TextStyle(
                    color: _theme.palette.getAccent(),
                    fontSize: _theme.typography.subtitle1.fontSize,
                    fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint:
                attachmentOption.iconTint ?? _theme.palette.getAccent700(),
            background: attachmentOption.background,
            cornerRadius: attachmentOption.cornerRadius,
            iconBackground: attachmentOption.iconBackground,
            iconCornerRadius: attachmentOption.iconCornerRadius,
            onItemClick: attachmentOption.onItemClick));
      }
    }
  }

  //-----------------------methods performing API calls-----------------------------

  _onTyping() {
    if ((_previousText.isEmpty && textEditingController.text.isNotEmpty) ||
        (_previousText.isNotEmpty && textEditingController.text.isEmpty)) {
      update();
    }
    if (_previousText.length > textEditingController.text.length) {
      _previousText = textEditingController.text;
      return;
    }

    _previousText = textEditingController.text;
    //emits typing events
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

  sendTextMessage({Map<String, dynamic>? metadata}) {
    String messagesText = textEditingController.text;
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
        category: CometChatMessageCategory.message);

    oldMessage = null;
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    // textEditingController.text = '';
    textEditingController.clear();
    _previousText = '';
    update();

    CometChatMessageEvents.ccMessageSent(textMessage, MessageStatus.inProgress);

    CometChat.sendMessage(textMessage, onSuccess: (TextMessage message) {
      debugPrint("Message sent successfully:  ${message.text}");
      if (disableSoundForMessages == false) {
        SoundManager.play(
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

  sendMediaMessage(
      {required PickedFile pickedFile,
      required String messageType,
      Map<String, dynamic>? metadata}) async {
    String muid = DateTime.now().microsecondsSinceEpoch.toString();

    MediaMessage _mediaMessage = MediaMessage(
      receiverType: receiverType,
      type: messageType,
      receiverUid: receiverID,
      file: pickedFile.path,
      metadata: metadata,
      sender: loggedInUser,
      parentMessageId: parentMessageId,
      muid: muid,
      category: CometChatMessageCategory.message,
    );

    CometChatMessageEvents.ccMessageSent(
        _mediaMessage, MessageStatus.inProgress);

    //for sending files
    MediaMessage _mediaMessage2 = MediaMessage(
      receiverType: receiverType,
      type: messageType,
      receiverUid: receiverID,
      //file: Platform.isIOS ? 'file://${pickedFile.path}' : pickedFile.path,

      file: (Platform.isIOS && (!pickedFile.path.startsWith('file://')))
          ? 'file://${pickedFile.path}'
          : pickedFile.path,
      metadata: metadata,
      sender: loggedInUser,
      parentMessageId: parentMessageId,
      muid: muid,
      category: CometChatMessageCategory.message,
    );

    if (textEditingController.text.isNotEmpty) {
      textEditingController.clear();
      _previousText = '';
      update();
    }

    await CometChat.sendMediaMessage(_mediaMessage2,
        onSuccess: (MediaMessage message) async {
      debugPrint("Media message sent successfully: ${_mediaMessage.muid}");

      if (Platform.isIOS) {
        if (message.file != null) {
          message.file = message.file?.replaceAll("file://", '');
        }
      } else {
        message.file = pickedFile.path;
      }

      _playSound();

      CometChatMessageEvents.ccMessageSent(message, MessageStatus.sent);
    },
        onError: onError ??
            (e) {
              if (_mediaMessage.metadata != null) {
                _mediaMessage.metadata!["error"] = e;
              } else {
                _mediaMessage.metadata = {"error": e};
              }
              CometChatMessageEvents.ccMessageSent(
                  _mediaMessage, MessageStatus.error);
              debugPrint(
                  "Media message sending failed with exception: ${e.message}");
            });
  }

  editTextMessage() {
    TextMessage editedMessage = oldMessage as TextMessage;
    editedMessage.text = textEditingController.text;
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    textEditingController.clear();
    _previousText = '';
    update();

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
    TransientMessage _transientMessage = TransientMessage(
        receiverType: receiverType,
        data: {
          "type": "live_reaction",
          'reaction': "heart",
          "packageName": UIConstants.packageName
        },
        receiverId: receiverID);
    CometChat.sendTransientMessage(_transientMessage, onSuccess: () {
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
      messagePreviewTitle = Translations.of(context).edit_message;
    } else if (mode == PreviewMessageMode.reply) {
      messagePreviewTitle = message.sender?.name;
    }
    if (message is TextMessage) {
      messagePreviewSubtitle = message.text;
    } else {
      messagePreviewSubtitle = ChatConfigurator.getDataSource()
          .getMessageTypeToSubtitle(message.type, context);
    }

    if (mode == PreviewMessageMode.edit && message is TextMessage) {
      textEditingController.text = message.text;
      _previousText = message.text;
    }
    previewMessageMode = mode;
    oldMessage = message;

    update();
  }

  //shows attachment options
  showBottomActionSheet(CometChatTheme _theme, BuildContext context) async {
    ActionItem? item = await showCometChatActionSheet(
        context: context,
        actionItems: _actionItems,
        titleStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: _theme.palette.getAccent()),
        backgroundColor: _theme.palette.getBackground(),
        iconBackground: _theme.palette.getAccent100(),
        layoutIconColor: _theme.palette.getPrimary());

    if (item == null) {
      return;
    }
    if (item.onItemClick != null) {
      item.onItemClick(user?.uid, group?.guid);
    } else {
      PickedFile? _pickedFile;
      String? _type;

      if (item.id == 'photoAndVideo') {
        _pickedFile = await MediaPicker.pickImageVideo();
        _type = _pickedFile?.fileType;
      } else if (item.id == 'takePhoto') {
        _pickedFile = await MediaPicker.takePhoto();
        _type = MessageTypeConstants.image;
      } else if (item.id == MessageTypeConstants.file) {
        _pickedFile = await MediaPicker.pickAnyFile();
        _type = MessageTypeConstants.file;
      } else if (item.id == MessageTypeConstants.audio) {
        _pickedFile = await MediaPicker.pickAudio();
        _type = MessageTypeConstants.audio;
      } else if (item.id == MessageTypeConstants.image) {
        _pickedFile = await MediaPicker.pickImage();
        _type = MessageTypeConstants.image;
      } else if (item.id == MessageTypeConstants.video) {
        _pickedFile = await MediaPicker.pickVideo();
        _type = MessageTypeConstants.video;
      }

      if (_pickedFile != null && _type != null) {
        debugPrint(_pickedFile.path);
        sendMediaMessage(pickedFile: _pickedFile, messageType: _type);
      }
    }
  }

  //shows CometChat's emoji keyboard
  useEmojis(BuildContext context, CometChatTheme _theme) async {
    String? emoji = await showCometChatEmojiKeyboard(
        context: context,
        backgroundColor: _theme.palette.getBackground(),
        titleStyle: TextStyle(
            fontSize: 17,
            fontWeight: _theme.typography.name.fontWeight,
            color: _theme.palette.getAccent()),
        categoryLabel: TextStyle(
            fontSize: _theme.typography.caption1.fontSize,
            fontWeight: _theme.typography.caption1.fontWeight,
            color: _theme.palette.getAccent600()),
        dividerColor: _theme.palette.getAccent100(),
        selectedCategoryIconColor: _theme.palette.getPrimary(),
        unselectedCategoryIconColor: _theme.palette.getAccent600());
    if (emoji != null) {
      _addEmojiToText(emoji);
    }
  }

//triggered if developer doesn't pass their onSendButtonClick handler
  onSendButtonClick() {
    if (textEditingController.text.isNotEmpty) {
      if (previewMessageMode == PreviewMessageMode.none) {
        sendTextMessage();
      } else if (previewMessageMode == PreviewMessageMode.edit) {
        editTextMessage();
      } else if (previewMessageMode == PreviewMessageMode.reply) {
        Map<String, dynamic> _metadata = {};
        _metadata["reply-message"] = oldMessage!.toJson();

        sendTextMessage(metadata: _metadata);
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
      SoundManager.play(
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
    int cursorPosition = textEditingController.selection.base.offset;

    //get the text on the right side of cursor
    String textRightOfCursor =
        textEditingController.text.substring(cursorPosition);

    //get the text on the left side of cursor
    String textLeftOfCursor =
        textEditingController.text.substring(0, cursorPosition);

    //insert the emoji in the correct order
    textEditingController.text = textLeftOfCursor + emoji + textRightOfCursor;

    //move the cursor to the end of the added emoji
    textEditingController.selection = TextSelection(
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
}
