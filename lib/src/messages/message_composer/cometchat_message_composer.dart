import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/debouncer.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import '../../utils/media_picker.dart';
import 'cometchat_sticker_keyboard.dart';

enum PreviewMessageMode { edit, reply, none }

///
/// [CometChatMessageComposer] component allows users to
/// send messages and attachments to the chat, participating in the conversation.
///
/// ```dart
///  CometChatMessageComposer(
///        user: 'user id',
///        stateCallBack: (CometChatMessageComposerState state) {},
///        enableTypingIndicator: true,
///        customOutgoingMessageSound: 'asset url',
///        excludeMessageTypes: [MessageTypeConstants.image],
///        messageTypes: [
///          TemplateUtils.getDefaultAudioTemplate(),
///          TemplateUtils.getDefaultTextTemplate(),
///          CometChatMessageTemplate(type: 'custom', name: 'custom')
///        ],
///        enableSoundForMessages: true,
///        hideEmoji: false,
///        hideAttachment: false,
///        hideLiveReaction: false,
///        showSendButton: true,
///        placeholderText: 'Message',
///        style: MessageComposerStyle(
///          cornerRadius: 8,
///          background: Colors.white,
///          border: Border.all(),
///          gradient: LinearGradient(colors: []),
///        ),
///      )
///
/// ```
///

class CometChatMessageComposer extends StatefulWidget {
  const CometChatMessageComposer(
      {Key? key,
      this.user,
      this.group,
      this.style = const MessageComposerStyle(),
      this.placeholderText,
      this.hideAttachment = false,
      this.hideMicrophone = false,
      this.hideLiveReaction = false,
      this.hideEmoji = false,
      this.showSendButton = true,
      this.enableTypingIndicator = true,
      this.enableSoundForMessages = true,
      this.messageTypes,
      this.onSendButtonClick,
      this.theme,
      this.stateCallBack,
      this.threadParentMessageId = 0,
      this.customOutgoingMessageSound,
      this.excludeMessageTypes})
      : super(key: key);

  ///[user] user id
  final String? user;

  ///[group] group id
  final String? group;

  ///[threadParentMessageId] parent message id for in thread messages
  final int threadParentMessageId;

  ///[style] message composer style
  final MessageComposerStyle style;

  ///[placeholderText] hint text
  final String? placeholderText;

  ///[hideAttachment] if true hides attachments options
  final bool hideAttachment;

  ///[hideMicrophone] if true hides microphone option
  final bool hideMicrophone;

  ///[hideLiveReaction] if true hides live reaction option
  final bool hideLiveReaction;

  ///[hideEmoji] if true hides emoji option
  final bool hideEmoji;

  ///[showSendButton] show back button
  final bool showSendButton;

  ///[enableTypingIndicator] if true then enables is typing indicator
  final bool enableTypingIndicator;

  ///[enableSoundForMessages] if true then enables outgoing message sound
  final bool enableSoundForMessages;

  ///[customOutgoingMessageSound] custom outgoing message sound assets url
  final String? customOutgoingMessageSound;

  ///[messageTypes] message types
  final List<CometChatMessageTemplate>? messageTypes;

  ///[excludeMessageTypes]
  final List<String>? excludeMessageTypes;

  ///[onSendButtonClick] on send button click
  final void Function()? onSendButtonClick;

  ///[theme] custom theme object
  final CometChatTheme? theme;

  ///[stateCallBack]
  final void Function(CometChatMessageComposerState)? stateCallBack;

  @override
  CometChatMessageComposerState createState() =>
      CometChatMessageComposerState();
}

class CometChatMessageComposerState extends State<CometChatMessageComposer> {
  User loggedInUser = User(name: '', uid: '');

  PreviewMessageMode previewMessageMode = PreviewMessageMode.none;
  String? messagePreviewTitle;
  String? messagePreviewSubtitle;
  BaseMessage? oldMessage;
  late FocusNode focusNode;
  final List<ActionItem> _actionItems = [];
  List<CometChatMessageTemplate> _messageTypes = [];
  String receiverID = "";
  String receiverType = "";
  bool _hideTextField = true;
  bool _hideSticker = true;
  bool _hideImage = true;
  bool _hideVideo = true;
  bool _isStickerKeyboardOpen = false;
  bool _getMessageCategoryCalled = false;
  bool _hideLiveReaction = false;
  CometChatTheme theme = cometChatTheme;

  @override
  void initState() {
    super.initState();
    theme = widget.theme ?? cometChatTheme;
    focusNode = FocusNode();
    //focusNode.addListener(_onFocusChange);
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }

    if (widget.user != null) {
      receiverID = widget.user!;
      receiverType = ReceiverTypeConstants.user;
    } else if (widget.group != null) {
      receiverID = widget.group!;
      receiverType = ReceiverTypeConstants.group;
    }

    _getLoggedInUser();
  }

  @override
  void dispose() {
    //focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  final _deBouncer = Debouncer(milliseconds: 1000);

  bool _isTyping = false;

  String previousText = "";

  _onTyping() {
    if (previousText.length > textEditingController.text.length) {
      previousText = textEditingController.text;
      return;
    }

    previousText = textEditingController.text;

    if (_isTyping == false) {
      CometChat.startTyping(
          receaverUid: receiverID, receiverType: receiverType);
      _isTyping = true;
    }

    _deBouncer.run(() {
      if (_isTyping) {
        CometChat.endTyping(
            receaverUid: receiverID, receiverType: receiverType);
        _isTyping = false;
      }
    });
  }

  _getMessageCategory(CometChatTheme _theme, BuildContext context) {
    if (widget.messageTypes != null) {
      _messageTypes = widget.messageTypes!;
    } else {
      _messageTypes = TemplateUtils.getDefaultTemplate();
    }

    if (widget.excludeMessageTypes != null) {
      for (String templateType in widget.excludeMessageTypes!) {
        _messageTypes.removeWhere((element) => element.type == templateType);
      }
    }

    for (CometChatMessageTemplate template in _messageTypes) {
      if (template.type != MessageTypeConstants.groupActions &&
          template.type != MessageTypeConstants.custom) {
        //to hide sticker option
        if (template.type == MessageTypeConstants.sticker) {
          _hideSticker = false;
        } else if (template.type == MessageTypeConstants.text) {
          _hideTextField = false;
        } else if (template.type == MessageTypeConstants.image) {
          _hideImage = false;
        } else if (template.type == MessageTypeConstants.video) {
          _hideVideo = false;
        } else {
          _actionItems.add(ActionItem(
            id: template.type,
            title: TemplateUtils.getMessageTypeToTemplateTitle(
                template.name, template.type, context),
            iconUrl: template.iconUrl,
            iconUrlPackageName: template.iconUrlPackageName,
            titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint: _theme.palette.getAccent700(),
          ));
        }
      }
    }

    if (_hideImage == false) {
      _actionItems.insert(
          0,
          ActionItem(
            id: 'takePhoto',
            title: Translations.of(context).take_photo,
            iconUrl: "assets/icons/photo_library.png",
            iconUrlPackageName: UIConstants.packageName,
            titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint: _theme.palette.getAccent700(),
          ));
    }

    if (_hideImage == false && _hideVideo == false) {
      _actionItems.insert(
          1,
          ActionItem(
            id: 'photoAndVideo',
            title: Translations.of(context).photo_and_video_library,
            iconUrl: "assets/icons/photo_library.png",
            iconUrlPackageName: UIConstants.packageName,
            titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint: _theme.palette.getAccent700(),
          ));
    }

    if (_hideImage == false && _hideVideo == true) {
      _actionItems.insert(
          1,
          ActionItem(
            id: MessageTypeConstants.image,
            title: Translations.of(context).image_library,
            iconUrl: "assets/icons/photo_library.png",
            iconUrlPackageName: UIConstants.packageName,
            titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint: _theme.palette.getAccent700(),
          ));
    }

    if (_hideImage == true && _hideVideo == false) {
      _actionItems.insert(
          0,
          ActionItem(
            id: MessageTypeConstants.video,
            title: Translations.of(context).video_library,
            iconUrl: "assets/icons/photo_library.png",
            iconUrlPackageName: UIConstants.packageName,
            titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
            iconTint: _theme.palette.getAccent700(),
          ));
    }
  }

  _getLoggedInUser() async {
    User? user = await CometChat.getLoggedInUser();
    if (user != null) {
      loggedInUser = user;
    }
  }

  previewMessage(BaseMessage message, PreviewMessageMode mode) {
    if (mode == PreviewMessageMode.edit) {
      messagePreviewTitle = Translations.of(context).edit_message;
    } else if (mode == PreviewMessageMode.reply) {
      messagePreviewTitle = message.sender?.name;
    }
    if (message is TextMessage) {
      messagePreviewSubtitle = message.text;
    } else {
      messagePreviewSubtitle =
          TemplateUtils.getMessageTypeToSubtitle(message.type, context);
    }

    if (mode == PreviewMessageMode.edit && message is TextMessage) {
      textEditingController.text = message.text;
    }
    previewMessageMode = mode;
    oldMessage = message;
    focusNode.requestFocus();

    setState(() {});
  }

  // void _onFocusChange() {
  //   if (widget.enableTypingIndicator) {
  //     if (focusNode.hasFocus) {
  //       CometChat.startTyping(
  //         receaverUid: receiverID,
  //         receiverType: receiverType,
  //       );
  //
  //       if (_isStickerKeyboardOpen) {
  //         _isStickerKeyboardOpen = false;
  //         setState(() {});
  //       }
  //     } else if (!focusNode.hasFocus) {
  //       CometChat.endTyping(
  //         receaverUid: receiverID,
  //         receiverType: receiverType,
  //       );
  //     }
  //   }
  // }

  TextEditingController textEditingController = TextEditingController();

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
        parentMessageId: widget.threadParentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString());

    oldMessage = null;
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    textEditingController.text = '';
    setState(() {});

    CometChatMessageEvents.onMessageSent(textMessage, MessageStatus.inProgress);

    CometChat.sendMessage(textMessage, onSuccess: (TextMessage message) {
      debugPrint("Message sent successfully:  ${message.text}");
      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.outgoingMessage,
            customSound: widget.customOutgoingMessageSound,
            packageName: widget.customOutgoingMessageSound == null ||
                    widget.customOutgoingMessageSound == ""
                ? UIConstants.packageName
                : null);
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
      parentMessageId: widget.threadParentMessageId,
      muid: muid,
    );

    CometChatMessageEvents.onMessageSent(
        _mediaMessage, MessageStatus.inProgress);

    MediaMessage _mediaMessage2 = MediaMessage(
      receiverType: receiverType,
      type: messageType,
      receiverUid: receiverID,
      file: Platform.isIOS ? 'file://${pickedFile.path}' : pickedFile.path,
      metadata: metadata,
      sender: loggedInUser,
      parentMessageId: widget.threadParentMessageId,
      muid: muid,
    );

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

      // if (messageType == MessageTypeConstants.video) {
      //   await Future.delayed(const Duration(seconds: 5));
      // }

      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.outgoingMessage,
            customSound: widget.customOutgoingMessageSound);
      }
      CometChatMessageEvents.onMessageSent(message, MessageStatus.sent);
    }, onError: (e) {
      if (_mediaMessage.metadata != null) {
        _mediaMessage.metadata!["error"] = true;
      } else {
        _mediaMessage.metadata = {"error": true};
      }
      CometChatMessageEvents.onMessageError(e, _mediaMessage);
      debugPrint("Media message sending failed with exception: ${e.message}");
    });
  }

  editTextMessage() {
    TextMessage editedMessage = oldMessage as TextMessage;
    editedMessage.text = textEditingController.text;
    messagePreviewTitle = '';
    messagePreviewSubtitle = '';
    previewMessageMode = PreviewMessageMode.none;
    textEditingController.text = '';
    setState(() {});

    CometChat.editMessage(editedMessage,
        onSuccess: (BaseMessage updatedMessage) {
      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.outgoingMessage,
            customSound: widget.customOutgoingMessageSound);
      }

      //CometChatMessageEvents.onMessageEdited(updatedMessage);
      CometChatMessageEvents.onMessageEdit(
          updatedMessage, MessageEditStatus.success);
    }, onError: (CometChatException e) {
      if (editedMessage.metadata != null) {
        editedMessage.metadata!["error"] = true;
      } else {
        editedMessage.metadata = {"error": true};
      }

      CometChatMessageEvents.onMessageError(e, editedMessage);
    });

    setState(() {});
  }

  sendCollaborativeWhiteBoard() {
    CometChat.callExtension(
        ExtensionConstants.whiteboard,
        "POST",
        ExtensionUrls.whiteboard,
        {"receiver": receiverID, "receiverType": receiverType},
        onSuccess: (Map<String, dynamic> map) {
      debugPrint("Success map $map");
    }, onError: (CometChatException e) {
      debugPrint('$e');
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
        confirmButtonText: Translations.of(context).cancel_capital,
        cancelButtonText: Translations.of(context).cancel_capital,
      );
    });
  }

  sendCollaborativeDocument() {
    CometChat.callExtension(
        ExtensionConstants.document,
        "POST",
        ExtensionUrls.document,
        {"receiver": receiverID, "receiverType": receiverType},
        onSuccess: (Map<String, dynamic> map) {
      debugPrint("Success map $map");
    }, onError: (CometChatException e) {
      debugPrint('$e');
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
        confirmButtonText: Translations.of(context).cancel_capital,
        cancelButtonText: Translations.of(context).cancel_capital,
      );
    });
  }

  sendCustomMessage(Map<String, String> customData, String type) {
    CustomMessage customMessage = CustomMessage(
      receiverUid: receiverID,
      type: type,
      customData: customData,
      receiverType: receiverType,
      sender: loggedInUser,
      parentMessageId: widget.threadParentMessageId,
      muid: DateTime.now().microsecondsSinceEpoch.toString(),
    );

    CometChatMessageEvents.onMessageSent(
        customMessage, MessageStatus.inProgress);

    CometChat.sendCustomMessage(customMessage,
        onSuccess: (CustomMessage message) {
      debugPrint("Custom Message Sent Successfully : $message");

      if (widget.enableSoundForMessages) {
        SoundManager.play(
            sound: Sound.outgoingMessage,
            customSound: widget.customOutgoingMessageSound);
      }
      CometChatMessageEvents.onMessageSent(message, MessageStatus.sent);
    }, onError: (CometChatException e) {
      if (customMessage.metadata != null) {
        customMessage.metadata!["error"] = true;
      } else {
        customMessage.metadata = {"error": true};
      }

      CometChatMessageEvents.onMessageError(e, customMessage);
      debugPrint("Custom message sending failed with exception: ${e.message}");
    });
  }

  sendCurrentLocation() async {
    bool isGranted = await LocationService.getLocationPermission();

    if (!isGranted) {
      return;
    }

    Map<String, dynamic> result = await LocationService.getCurrentLocation();

    if (result["status"] == false) {
      return;
    }

    Map<String, String> customData = {};

    customData["latitude"] = result["latitude"].toString();
    customData["longitude"] = result["longitude"].toString();

    sendCustomMessage(customData, "LOCATION");
  }

  sendSticker(Sticker sticker) {
    Map<String, String> customData = {};
    customData["sticker_url"] = sticker.stickerUrl;
    customData["sticker_name"] = sticker.stickerName;
    sendCustomMessage(customData, "extension_sticker");
  }

  _showBottomActionSheet(CometChatTheme _theme, BuildContext context) async {
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

    for (var messageType in _messageTypes) {
      if (messageType.type == item.id && messageType.onActionClick != null) {
        messageType.onActionClick!(widget.user, widget.group);
        return;
      }
    }

    PickedFile? _pickedFile;
    String? _type;
    if (item.id == MessageTypeConstants.poll) {
      CometChatMessageEvents.onCreatePoll(MessageStatus.inProgress);
    } else if (item.id == MessageTypeConstants.document) {
      sendCollaborativeDocument();
    } else if (item.id == MessageTypeConstants.whiteboard) {
      sendCollaborativeWhiteBoard();
    } else if (item.id == MessageTypeConstants.location) {
      sendCurrentLocation();
    } else if (item.id == 'photoAndVideo') {
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

  Widget _getSendButton(CometChatTheme _theme) {
    if (textEditingController.text.isEmpty &&
        widget.hideLiveReaction == false) {
      return IconButton(
        padding: const EdgeInsets.all(0),
        constraints: const BoxConstraints(),
        icon: widget.style.liveReactionIcon ??
            Image.asset("assets/icons/heart.png",
                package: UIConstants.packageName,
                color: _theme.palette.getError()),
        onPressed: () async {
          if (_hideLiveReaction == false) {
            //setState(() {
            _hideLiveReaction = true;
            //});
            try {
              _sendLiveReaction();
            } catch (_) {}
            await Future.delayed(const Duration(milliseconds: 1500));
            // if (mounted) {
            //   setState(() {
            _hideLiveReaction = false;
            //   });
            // }
          }
        },
      );
    }

    if (widget.showSendButton) {
      return IconButton(
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(),
          icon: widget.style.sendButtonIcon ??
              Image.asset(
                "assets/icons/send.png",
                package: UIConstants.packageName,
                color: textEditingController.text.isEmpty
                    ? _theme.palette.getAccent400()
                    : _theme.palette.getPrimary(),
              ),
          onPressed: widget.onSendButtonClick ??
              () {
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
              });
    }

    return const SizedBox(height: 0, width: 0);
  }

  _sendLiveReaction() {
    CometChatMessageEvents.onLiveReaction(
      "assets/icons/heart.png",
    );
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
    }, onError: (CometChatException excep) {
      debugPrint(excep.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    if (_getMessageCategoryCalled == false) {
      _getMessageCategoryCalled = true;
      _getMessageCategory(_theme, context);
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isStickerKeyboardOpen) {
          _isStickerKeyboardOpen = false;
          setState(() {});
          return false;
        }
        return true;
      },
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.style.background ?? _theme.palette.getBackground(),
            ),
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
            child: Column(
              children: [
                //-----message preview container-----
                if (messagePreviewTitle != null &&
                    messagePreviewTitle!.isNotEmpty)
                  CometChatMessagePreview(
                    messagePreviewTitle: messagePreviewTitle!,
                    messagePreviewSubtitle: messagePreviewSubtitle ?? '',
                    onCloseClick: () {
                      previewMessageMode = PreviewMessageMode.none;
                      messagePreviewTitle = "";
                      messagePreviewSubtitle = "";
                      setState(() {});
                    },
                    style: CometChatMessagePreviewStyle(
                        messagePreviewTitleStyle: TextStyle(
                            color: _theme.palette.getAccent600(),
                            fontSize: _theme.typography.text2.fontSize,
                            fontWeight: _theme.typography.text2.fontWeight,
                            fontFamily: _theme.typography.text2.fontFamily),
                        messagePreviewSubtitleStyle: TextStyle(
                            color: _theme.palette.getAccent600(),
                            fontSize: _theme.typography.text2.fontSize,
                            fontWeight: _theme.typography.text2.fontWeight,
                            fontFamily: _theme.typography.text2.fontFamily),
                        closeIconColor: _theme.palette.getAccent500(),
                        messagePreviewBorder: Border(
                            left: BorderSide(
                                color: _theme.palette.getAccent100(),
                                width: 3))),
                  ),

                //-----
                Container(
                  decoration: BoxDecoration(
                      color: widget.style.gradient == null
                          ? widget.style.background ??
                              _theme.palette.getAccent100()
                          : null,
                      border: widget.style.border,
                      borderRadius: BorderRadius.all(
                          Radius.circular(widget.style.cornerRadius ?? 8.0)),
                      gradient: widget.style.gradient),
                  child: Column(
                    children: [
                      //-----text field-----
                      if (_hideTextField == false)
                        Container(
                          color: widget.style.inputBackground,
                          padding: const EdgeInsets.only(left: 12.0, right: 12),
                          child: TextFormField(
                            style: widget.style.inputTextStyle ??
                                TextStyle(
                                  color: _theme.palette.getAccent(),
                                  fontSize: _theme.typography.name.fontSize,
                                  fontWeight: _theme.typography.name.fontWeight,
                                  fontFamily: _theme.typography.name.fontFamily,
                                ),
                            onChanged: (val) {
                              _onTyping();
                              setState(() {});
                            },
                            controller: textEditingController,
                            focusNode: focusNode,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: widget.placeholderText ??
                                  Translations.of(context).message,
                              hintStyle: widget.style.placeholderTextStyle ??
                                  TextStyle(
                                    color: _theme.palette.getAccent600(),
                                    fontSize: _theme.typography.name.fontSize,
                                    fontWeight:
                                        _theme.typography.name.fontWeight,
                                    fontFamily:
                                        _theme.typography.name.fontFamily,
                                  ),
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      if (_hideTextField == false)
                        Divider(
                          height: 1,
                          color: _theme.palette.getAccent100(),
                        ),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.only(left: 10.0, right: 10),
                        child: Row(
                          children: [
                            //-----show add to chat bottom sheet-----
                            if (_actionItems.isNotEmpty)
                              IconButton(
                                  padding: const EdgeInsets.all(0),
                                  constraints: const BoxConstraints(),
                                  icon: Image.asset(
                                    "assets/icons/add.png",
                                    package: UIConstants.packageName,
                                    color: _theme.palette.getAccent700(),
                                  ),
                                  onPressed: () async {
                                    _showBottomActionSheet(_theme, context);
                                  } //do something,
                                  ),
                            const Spacer(),

                            //-----show emoji keyboard-----
                            if (widget.hideEmoji == false)
                              IconButton(
                                  padding: const EdgeInsets.only(right: 20),
                                  constraints: const BoxConstraints(),
                                  icon: Image.asset(
                                    "assets/icons/smileys.png",
                                    package: UIConstants.packageName,
                                    color: _theme.palette.getAccent700(),
                                  ),
                                  onPressed: () async {
                                    String? emoji =
                                        await showCometChatEmojiKeyboard(
                                            context: context,
                                            backgroundColor:
                                                _theme.palette.getBackground(),
                                            titleStyle: TextStyle(
                                                fontSize: 17,
                                                fontWeight: _theme
                                                    .typography.name.fontWeight,
                                                color:
                                                    _theme.palette.getAccent()),
                                            categoryLabel: TextStyle(
                                                fontSize: _theme.typography
                                                    .caption1.fontSize,
                                                fontWeight: _theme.typography
                                                    .caption1.fontWeight,
                                                color: _theme.palette
                                                    .getAccent600()),
                                            dividerColor:
                                                _theme.palette.getAccent100(),
                                            selectedCategoryIconColor:
                                                _theme.palette.getPrimary(),
                                            unselectedCategoryIconColor:
                                                _theme.palette.getAccent600());
                                    if (emoji != null) {
                                      textEditingController.text += emoji;
                                      setState(() {});
                                    }
                                  } //do something,
                                  ),

                            //-----show sticker keyboard-----
                            if (_hideSticker == false)
                              IconButton(
                                  padding: const EdgeInsets.only(right: 20),
                                  constraints: const BoxConstraints(),
                                  icon: _isStickerKeyboardOpen
                                      ? Image.asset(
                                          "assets/icons/keyboard.png",
                                          package: UIConstants.packageName,
                                          color: _theme.palette.getAccent700(),
                                        )
                                      : Image.asset(
                                          "assets/icons/smile.png",
                                          package: UIConstants.packageName,
                                          color: _theme.palette.getAccent700(),
                                        ),
                                  onPressed: () async {
                                    if (_isStickerKeyboardOpen) {
                                      focusNode.requestFocus();
                                    } else {
                                      focusNode.unfocus();
                                    }
                                    _isStickerKeyboardOpen =
                                        !_isStickerKeyboardOpen;
                                    setState(() {});
                                  } //do something,
                                  ),

                            //  -----show send or live reaction button-----
                            _getSendButton(_theme),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isStickerKeyboardOpen)
            CometChatStickerKeyboard(
              theme: _theme,
              onStickerTap: (Sticker sticker) {
                sendSticker(sticker);
              },
            )
        ],
      ),
    );
  }
}

class MessageComposerStyle {
  const MessageComposerStyle(
      {this.border,
      this.cornerRadius,
      this.background,
      this.inputBackground,
      this.inputTextStyle,
      this.placeholderTextStyle,
      this.sendButtonIcon,
      this.attachmentIcon,
      this.microphoneIcon,
      this.liveReactionIcon,
      this.height,
      this.width,
      this.gradient});

  ///[height] height of composer
  final double? height;

  ///[width] width of composer
  final double? width;

  ///[border]
  final BoxBorder? border;

  ///[cornerRadius]
  final double? cornerRadius;

  ///[background] background color of message composer
  final Color? background;

  ///[inputBackground] background color of text field
  final Color? inputBackground;

  ///[inputTextStyle]
  final TextStyle? inputTextStyle;

  ///[placeholderTextStyle] hint text style
  final TextStyle? placeholderTextStyle;

  ///[attachmentIcon] custom attachment icon
  final Widget? attachmentIcon;

  ///[microphoneIcon] custom microphone icon
  final Widget? microphoneIcon;

  ///[liveReactionIcon] custom live reaction icon
  final Widget? liveReactionIcon;

  ///[sendButtonIcon] custom send button icon
  final Widget? sendButtonIcon;

  final Gradient? gradient;
}
