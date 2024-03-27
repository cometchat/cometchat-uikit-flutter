import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
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
      this.aiOptionStyle
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
  late TextEditingController textEditingController;

  ///[loggedInUser] is the user the message is being sent from
  User loggedInUser = User(name: '', uid: '');
  final _deBouncer = Debouncer(milliseconds: 1000);

  ///[_previousText] holds the state of the last typed text
  String _previousText = "";

  ///[headerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? footerView;

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

  AIOptionsStyle? aiOptionStyle;

  late FocusNode focusNode;

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

    focusNode = FocusNode();

    focusNode.addListener(_onFocusChange);

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
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();

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

  @override
  void ccComposeMessage(String text, MessageEditStatus status) {
    textEditingController.text = text;
    _previousText = text;
    update();
  }

  // @override
  // void onMessageReply(BaseMessage message) {
  //   if (message.parentMessageId==parentMessageId) {
  //     previewMessage(message, PreviewMessageMode.reply);
  //   }
  // }

  @override
  void showPanel(Map<String, dynamic>? id, CustomUIPosition uiPosition,
      WidgetBuilder child) {
    print("is for this ID ${id} ${isForThisWidget(id)}");
    if (isForThisWidget(id) == false) return;
    if (uiPosition == CustomUIPosition.composerBottom) {
      footer = child(context);
    } else if (uiPosition == CustomUIPosition.composerTop) {
      header = child(context);
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

    if (textEditingController.text.isNotEmpty) {
      textEditingController.clear();
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
      messagePreviewTitle = Translations.of(context).edit_message;
    } else if (mode == PreviewMessageMode.reply) {
      messagePreviewTitle = message.sender?.name;
    }
    if (message is TextMessage) {
      messagePreviewSubtitle = message.text;
    } else {
      messagePreviewSubtitle = CometChatUIKit.getDataSource()
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
    if (textEditingController.text.isNotEmpty) {
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
    int cursorPosition = textEditingController.selection.base.offset;
    if (cursorPosition == -1) {
      cursorPosition = textEditingController.text.length;
    }

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


  aiButtonTap(CometChatTheme theme,BuildContext context ,id,  ) async {

    List<CometChatMessageComposerAction> aiFeatureList =  CometChatUIKit.getDataSource().
    getAIOptions(user, group, theme, context, id, aiOptionStyle);



    if(aiFeatureList.isNotEmpty ){

      List<CometChatMessageComposerAction> actionList = [];


      for (int i = 0; i < aiFeatureList.length ; i++) {

        actionList.add(CometChatMessageComposerAction(
            id: aiFeatureList[i].id,
            title:  aiFeatureList[i].title,
            titleStyle: aiFeatureList[i].titleStyle?? aiOptionStyle?.itemTextStyle,
            background: aiFeatureList[i].background?? aiOptionStyle?.background,
            cornerRadius: aiFeatureList[i].cornerRadius?? aiOptionStyle?.borderRadius,

            onItemClick: (BuildContext context,  User? user, Group? group){
              if(aiFeatureList[i].onItemClick!=null){
                aiFeatureList[i].onItemClick!(context,user, group);
              }
            }
        ));
      }




      showCometChatAiOptionSheet(context: context,
          theme: theme,
          user: user,
          group: group,
          actionItems: actionList,
          backgroundColor:theme.palette.getBackground(),

      );

      return;
    }




  }

}
