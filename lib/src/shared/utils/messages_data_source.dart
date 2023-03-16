import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as cc;

///Utils class related to message template
class MessagesDataSource implements DataSource {
  CometChatMessageOption getEditOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.editMessage,
        title: Translations.of(context).edit,
        icon: AssetConstants.edit,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getDeleteOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.deleteMessage,
        title: Translations.of(context).delete_message,
        icon: AssetConstants.delete,
        titleStyle: const TextStyle(
          color: Colors.red,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        iconTint: Colors.red,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getReplyOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.replyMessage,
        title: Translations.of(context).reply,
        icon: AssetConstants.reply,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getReplyInThreadOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.replyInThreadMessage,
        title: Translations.of(context).reply,
        icon: AssetConstants.thread,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getShareOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.shareMessage,
        title: Translations.of(context).share,
        icon: AssetConstants.share,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getCopyOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.copyMessage,
        title: Translations.of(context).copy_text,
        icon: AssetConstants.copy,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getForwardOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.forwardMessage,
        title: Translations.of(context).forward,
        icon: AssetConstants.forward,
        packageName: UIConstants.packageName);
  }

  CometChatMessageOption getInformationOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.messageInformation,
        title: Translations.of(context).information,
        icon: AssetConstants.info,
        packageName: UIConstants.packageName);
  }

  bool isSentByMe(User loggedInUser, BaseMessage message) {
    return loggedInUser.uid == message.sender?.uid;
  }

  @override
  List<CometChatMessageOption> getTextMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    bool _isSentByMe = isSentByMe(loggedInUser, messageObject);
    bool _isModerator = false;
    if (group?.scope == GroupMemberScope.moderator) _isModerator = true;

    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(ChatConfigurator.getDataSource()
        .getCommonOptions(loggedInUser, messageObject, context, group));

    if (_isSentByMe || _isModerator) {
      messageOptionList.add(getEditOption(context));
    }
    messageOptionList.add(getCopyOption(context));
    return messageOptionList;
  }

  @override
  List<CometChatMessageOption> getImageMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(ChatConfigurator.getDataSource()
        .getCommonOptions(loggedInUser, messageObject, context, group));
    return messageOptionList;
  }

  @override
  List<CometChatMessageOption> getVideoMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(ChatConfigurator.getDataSource()
        .getCommonOptions(loggedInUser, messageObject, context, group));
    return messageOptionList;
  }

  @override
  List<CometChatMessageOption> getAudioMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(ChatConfigurator.getDataSource()
        .getCommonOptions(loggedInUser, messageObject, context, group));
    return messageOptionList;
  }

  @override
  List<CometChatMessageOption> getFileMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(ChatConfigurator.getDataSource()
        .getCommonOptions(loggedInUser, messageObject, context, group));
    return messageOptionList;
  }

  @override
  Widget getDeleteMessageBubble(
      BaseMessage _messageObject, CometChatTheme _theme) {
    return CometChatDeleteMessageBubble(
      style: DeletedBubbleStyle(
        textStyle: TextStyle(
            color: _theme.palette.getAccent400(),
            fontSize: _theme.typography.body.fontSize,
            fontWeight: _theme.typography.body.fontWeight),
        borderColor: _theme.palette.getAccent200(),
      ),
    );
  }

  Widget getGroupActionBubble(
      BaseMessage _messageObject, CometChatTheme _theme) {
    cc.Action actionMessage = _messageObject as cc.Action;
    return CometChatGroupActionBubble(
      text: actionMessage.message,
      style: GroupActionBubbleStyle(
          textStyle: TextStyle(
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight,
              color: _theme.palette.getAccent600())),
    );
  }

  @override
  Widget getBottomView(
      BaseMessage message, BuildContext context, BubbleAlignment _alignment) {
    return const SizedBox();
  }

  @override
  CometChatMessageTemplate getTextMessageTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        // name: MessageTypeConstants.text,
        type: MessageTypeConstants.text,
        category: MessageCategoryConstants.message,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment _alignment) {
          TextMessage textMessage = message as TextMessage;
          if (message.deletedAt != null) {
            return getDeleteMessageBubble(message, theme);
          }
          return ChatConfigurator.getDataSource().getTextMessageContentView(
              textMessage, context, _alignment, theme);
        },
        options: ChatConfigurator.getDataSource().getMessageOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  @override
  Widget getTextMessageContentView(TextMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return ChatConfigurator.getDataSource().getTextMessageBubble(
        message.text, message, context, _alignment, theme, null);
  }

  @override
  CometChatMessageTemplate getAudioMessageTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        type: MessageTypeConstants.audio,
        category: MessageCategoryConstants.message,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {
          MediaMessage audioMessage = message as MediaMessage;
          if (message.deletedAt != null) {
            return getDeleteMessageBubble(message, theme);
          }

          return ChatConfigurator.getDataSource().getAudioMessageContentView(
              audioMessage, context, alignment, theme);
        },
        options: ChatConfigurator.getDataSource().getMessageOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  @override
  CometChatMessageTemplate getVideoMessageTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        type: MessageTypeConstants.video,
        category: MessageCategoryConstants.message,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {

          if (message.deletedAt != null) {
            return getDeleteMessageBubble(message, theme);
          }

          return ChatConfigurator.getDataSource()
              .getVideoMessageContentView(message as MediaMessage, context, alignment, theme);
        },
        options: ChatConfigurator.getDataSource().getMessageOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  @override
  CometChatMessageTemplate getImageMessageTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        type: MessageTypeConstants.image,
        category: MessageCategoryConstants.message,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {

          if (message.deletedAt != null) {
            return getDeleteMessageBubble(message, theme);
          }

          return ChatConfigurator.getDataSource()
              .getImageMessageContentView(message as MediaMessage, context, alignment, theme);
        },
        options: ChatConfigurator.getDataSource().getMessageOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  @override
  CometChatMessageTemplate getGroupActionTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {
          return getGroupActionBubble(message, theme);
        });
  }

  CometChatMessageTemplate getDefaultMessageActionsTemplate(
      CometChatTheme theme) {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.message,
      category: MessageCategoryConstants.action,
    );
  }

  @override
  CometChatMessageTemplate getFileMessageTemplate(CometChatTheme theme) {
    return CometChatMessageTemplate(
        type: MessageTypeConstants.file,
        category: MessageCategoryConstants.message,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {
          if (message.deletedAt != null) {
            return getDeleteMessageBubble(message, theme);
          }

          return ChatConfigurator.getDataSource()
              .getFileMessageContentView(message as MediaMessage, context, alignment, theme);
        },
        options: ChatConfigurator.getDataSource().getMessageOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  @override
  List<CometChatMessageTemplate> getAllMessageTemplates(
      {CometChatTheme? theme}) {
    CometChatTheme _theme = theme ?? cometChatTheme;
    return [
      ChatConfigurator.getDataSource().getTextMessageTemplate(_theme),
      ChatConfigurator.getDataSource().getImageMessageTemplate(_theme),
      ChatConfigurator.getDataSource().getVideoMessageTemplate(_theme),
      ChatConfigurator.getDataSource().getAudioMessageTemplate(_theme),
      ChatConfigurator.getDataSource().getFileMessageTemplate(_theme),
      ChatConfigurator.getDataSource().getGroupActionTemplate(_theme),
    ];
  }

  @override
  CometChatMessageTemplate? getMessageTemplate(
      {required String messageType,
      required String messageCategory,
      CometChatTheme? theme}) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    CometChatMessageTemplate? template;
    if (messageCategory != MessageCategoryConstants.call) {
      switch (messageType) {
        case MessageTypeConstants.text:
          template =
              ChatConfigurator.getDataSource().getTextMessageTemplate(_theme);
          break;
        case MessageTypeConstants.image:
          template =
              ChatConfigurator.getDataSource().getImageMessageTemplate(_theme);
          break;
        case MessageTypeConstants.video:
          template =
              ChatConfigurator.getDataSource().getVideoMessageTemplate(_theme);
          break;
        case MessageTypeConstants.groupActions:
          template =
              ChatConfigurator.getDataSource().getGroupActionTemplate(_theme);
          break;
        case MessageTypeConstants.file:
          template =
              ChatConfigurator.getDataSource().getFileMessageTemplate(_theme);
          break;
        case MessageTypeConstants.audio:
          template =
              ChatConfigurator.getDataSource().getAudioMessageTemplate(_theme);
          break;
      }
    }

    return template;
  }

  @override
  List<CometChatMessageOption> getMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> _optionList = [];

    bool _isSentByMe = false;
    if (loggedInUser.uid == messageObject.sender?.uid) {
      _isSentByMe = true;
    }

    if (messageObject.category == MessageCategoryConstants.message) {
      switch (messageObject.type) {
        case MessageTypeConstants.text:
          _optionList = ChatConfigurator.getDataSource().getTextMessageOptions(
              loggedInUser, messageObject, context, group);
          break;
        case MessageTypeConstants.image:
          _optionList = ChatConfigurator.getDataSource().getImageMessageOptions(
              loggedInUser, messageObject, context, group);
          break;
        case MessageTypeConstants.video:
          _optionList = ChatConfigurator.getDataSource().getVideoMessageOptions(
              loggedInUser, messageObject, context, group);
          break;
        case MessageTypeConstants.groupActions:
          _optionList = [];
          break;
        case MessageTypeConstants.file:
          _optionList = ChatConfigurator.getDataSource().getFileMessageOptions(
              loggedInUser, messageObject, context, group);
          break;
        case MessageTypeConstants.audio:
          _optionList = ChatConfigurator.getDataSource().getAudioMessageOptions(
              loggedInUser, messageObject, context, group);
          break;
      }
    } else if (messageObject.category == MessageCategoryConstants.custom) {
      _optionList = ChatConfigurator.getDataSource()
          .getCommonOptions(loggedInUser, messageObject, context, group);
    }
    return _optionList;
  }

  @override
  List<CometChatMessageOption> getCommonOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    bool _isSentByMe = isSentByMe(loggedInUser, messageObject);
    bool _isModerator = false;
    if (group?.scope == GroupMemberScope.moderator) _isModerator = true;

    List<CometChatMessageOption> messageOptionList = [];

    if (_isSentByMe == true || _isModerator == true) {
      messageOptionList.add(getDeleteOption(context));
    }
    if (messageObject.parentMessageId == 0) {
      messageOptionList.add(getReplyInThreadOption(context));
    }
    return messageOptionList;
  }

  @override
  String getMessageTypeToSubtitle(String messageType, BuildContext context) {
    String subtitle = messageType;
    switch (messageType) {
      case MessageTypeConstants.text:
        subtitle = Translations.of(context).text;
        break;
      case MessageTypeConstants.image:
        subtitle = Translations.of(context).message_image;
        break;
      case MessageTypeConstants.video:
        subtitle = Translations.of(context).message_video;
        break;
      case MessageTypeConstants.file:
        subtitle = Translations.of(context).message_file;
        break;
      case MessageTypeConstants.audio:
        subtitle = Translations.of(context).message_audio;
        break;
      default:
        subtitle = messageType;
        break;
    }
    return subtitle;
  }

  // @override
  // List<CometChatMessageComposerAction> getAttachmentOptions(
  //     CometChatTheme theme, BuildContext context,
  //     {User? user, Group? group}) {
  //   List<CometChatMessageComposerAction> actions = [
  //     CometChatMessageComposerAction(
  //       id: MessageTypeConstants.takePhoto,
  //       title: Translations.of(context).take_photo,
  //       iconUrl: AssetConstants.photoLibrary,
  //       iconUrlPackageName: UIConstants.packageName,
  //       titleStyle: TextStyle(
  //           color: theme.palette.getAccent(),
  //           fontSize: theme.typography.subtitle1.fontSize,
  //           fontWeight: theme.typography.subtitle1.fontWeight),
  //       iconTint: theme.palette.getAccent700(),
  //     ),
  //     CometChatMessageComposerAction(
  //       id: MessageTypeConstants.photoAndVideo,
  //       title: Translations.of(context).photo_and_video_library,
  //       iconUrl: AssetConstants.photoLibrary,
  //       iconUrlPackageName: UIConstants.packageName,
  //       titleStyle: TextStyle(
  //           color: theme.palette.getAccent(),
  //           fontSize: theme.typography.subtitle1.fontSize,
  //           fontWeight: theme.typography.subtitle1.fontWeight),
  //       iconTint: theme.palette.getAccent700(),
  //     ),
  //     CometChatMessageComposerAction(
  //       id: MessageTypeConstants.file,
  //       title: Translations.of(context).file,
  //       iconUrl: AssetConstants.audio,
  //       iconUrlPackageName: UIConstants.packageName,
  //       titleStyle: TextStyle(
  //           color: theme.palette.getAccent(),
  //           fontSize: theme.typography.subtitle1.fontSize,
  //           fontWeight: theme.typography.subtitle1.fontWeight),
  //       iconTint: theme.palette.getAccent700(),
  //     ),
  //     CometChatMessageComposerAction(
  //       id: MessageTypeConstants.audio,
  //       title: Translations.of(context).audio,
  //       iconUrl: AssetConstants.attachmentFile,
  //       iconUrlPackageName: UIConstants.packageName,
  //       titleStyle: TextStyle(
  //           color: theme.palette.getAccent(),
  //           fontSize: theme.typography.subtitle1.fontSize,
  //           fontWeight: theme.typography.subtitle1.fontWeight),
  //       iconTint: theme.palette.getAccent700(),
  //     )
  //   ];

  //   return actions;
  // }

  @override
  List<String> getAllMessageTypes() {
    return [
      CometChatMessageType.text,
      CometChatMessageType.image,
      CometChatMessageType.audio,
      CometChatMessageType.video,
      CometChatMessageType.file,
      MessageTypeConstants.groupActions
    ];
  }

  
  String addList() {
    return "<Message Utils>";
  }

  @override
  List<String> getAllMessageCategories() {
    return [CometChatMessageCategory.message, CometChatMessageCategory.action];
  }

  @override
  Widget getAuxiliaryOptions(User? user, Group? group, BuildContext context,
      Map<String, dynamic>? id) {
    return SizedBox();
  }

  @override
  String getId() {
    return "messageUtils";
  }

  @override
  Widget getAudioMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return ChatConfigurator.getDataSource().getAudioMessageBubble(
        message.attachment?.fileUrl,
        message.attachment?.fileName,
        null,
        message,
        context,
        theme);
  }

  @override
  Widget getFileMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return ChatConfigurator.getDataSource().getFileMessageBubble(
        message.attachment?.fileUrl,
        message.attachment?.fileMimeType,
        message.attachment?.fileName,
        message.id,
        null,
        message,
        theme);
  }

  @override
  Widget getImageMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return ChatConfigurator.getDataSource().getImageMessageBubble(
        message.attachment?.fileUrl,
        AssetConstants.imagePlaceholder,
        message.caption,
        null,
        message,
        null,
        context,
        theme);
  }

  @override
  Widget getVideoMessageBubble(
      String? videoUrl,
      String? thumbnailUrl,
      MediaMessage message,
      Function()? onClick,
      BuildContext context,
      CometChatTheme theme,
      VideoBubbleStyle? style) {
    return CometChatVideoBubble(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      style: style,
    );
  }

  @override
  Widget getVideoMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return ChatConfigurator.getDataSource().getVideoMessageBubble(
        message.attachment?.fileUrl, null, message, null, context, theme, null);
  }

  CometChatMessageComposerAction takePhotoOption(
      CometChatTheme theme, BuildContext context) {
    return CometChatMessageComposerAction(
      id: MessageTypeConstants.takePhoto,
      title: Translations.of(context).take_photo,
      iconUrl: AssetConstants.photoLibrary,
      iconUrlPackageName: UIConstants.packageName,
      titleStyle: TextStyle(
          color: theme.palette.getAccent(),
          fontSize: theme.typography.subtitle1.fontSize,
          fontWeight: theme.typography.subtitle1.fontWeight),
      iconTint: theme.palette.getAccent700(),
    );
  }

  CometChatMessageComposerAction photoAndVideoLibraryOption(
      CometChatTheme theme, BuildContext context) {
    return CometChatMessageComposerAction(
      id: MessageTypeConstants.photoAndVideo,
      title: Translations.of(context).photo_and_video_library,
      iconUrl: AssetConstants.photoLibrary,
      iconUrlPackageName: UIConstants.packageName,
      titleStyle: TextStyle(
          color: theme.palette.getAccent(),
          fontSize: theme.typography.subtitle1.fontSize,
          fontWeight: theme.typography.subtitle1.fontWeight),
      iconTint: theme.palette.getAccent700(),
    );
  }

  CometChatMessageComposerAction audioAttachmentOption(
      CometChatTheme theme, BuildContext context) {
    return CometChatMessageComposerAction(
      id: MessageTypeConstants.audio,
      title: Translations.of(context).audio,
      iconUrl: AssetConstants.audio,
      iconUrlPackageName: UIConstants.packageName,
      titleStyle: TextStyle(
          color: theme.palette.getAccent(),
          fontSize: theme.typography.subtitle1.fontSize,
          fontWeight: theme.typography.subtitle1.fontWeight),
      iconTint: theme.palette.getAccent700(),
    );
  }

  CometChatMessageComposerAction fileAttachmentOption(
      CometChatTheme theme, BuildContext context) {
    return CometChatMessageComposerAction(
      id: MessageTypeConstants.file,
      title: Translations.of(context).file,
      iconUrl: AssetConstants.attachmentFile,
      iconUrlPackageName: UIConstants.packageName,
      titleStyle: TextStyle(
          color: theme.palette.getAccent(),
          fontSize: theme.typography.subtitle1.fontSize,
          fontWeight: theme.typography.subtitle1.fontWeight),
      iconTint: theme.palette.getAccent700(),
    );
  }

  @override
  List<CometChatMessageComposerAction> getAttachmentOptions(
      CometChatTheme theme, BuildContext context, Map<String, dynamic>? id) {
    List<CometChatMessageComposerAction> actions = [
      takePhotoOption(theme, context),
      photoAndVideoLibraryOption(theme, context),
      audioAttachmentOption(theme, context),
      fileAttachmentOption(theme, context)
    ];

    return actions;
  }

  @override
  Widget getTextMessageBubble(
      String messageText,
      TextMessage message,
      BuildContext context,
      BubbleAlignment alignment,
      CometChatTheme theme,
      TextBubbleStyle? style) {
    return CometChatTextBubble(
      text: messageText,
      alignment: alignment,
      theme: theme,
      style: style ??
          TextBubbleStyle(
            background: style?.background,
            border: style?.border,
            borderRadius: style?.borderRadius,
            gradient: style?.gradient,
            height: style?.height,
            width: style?.width,
            textStyle: TextStyle(
                    color: alignment == BubbleAlignment.right
                        ? Colors.white
                        : theme.palette.getAccent(),
                    fontWeight: theme.typography.body.fontWeight,
                    fontSize: theme.typography.body.fontSize,
                    fontFamily: theme.typography.body.fontFamily)
                .merge(style?.textStyle),
          ),
    );
  }

  @override
  Widget getAudioMessageBubble(
      String? audioUrl,
      String? title,
      AudioBubbleStyle? style,
      MediaMessage message,
      BuildContext context,
      CometChatTheme theme) {
    return CometChatAudioBubble(
      style: AudioBubbleStyle(
          background: style?.background,
          border: style?.border,
          borderRadius: style?.borderRadius,
          gradient: style?.gradient,
          height: style?.height,
          width: style?.width,
          pauseIconTint: style?.pauseIconTint,
          playIconTint: style?.playIconTint,
          titleStyle: TextStyle(
                  fontSize: theme.typography.name.fontSize,
                  fontWeight: theme.typography.name.fontWeight,
                  fontFamily: theme.typography.name.fontFamily,
                  color: theme.palette.getAccent())
              .merge(style?.titleStyle),
          subtitleStyle: TextStyle(
                  fontSize: theme.typography.subtitle2.fontSize,
                  fontWeight: theme.typography.subtitle2.fontWeight,
                  fontFamily: theme.typography.subtitle2.fontFamily,
                  color: theme.palette.getAccent600())
              .merge(style?.subtitleStyle)),
      audioUrl: audioUrl,
      title: title,
      key: UniqueKey(),
    );
  }

  @override
  Widget getFileMessageBubble(
      String? fileUrl,
      String? fileMimeType,
      String? title,
      int? id,
      FileBubbleStyle? style,
      MediaMessage message,
      CometChatTheme theme) {
    return CometChatFileBubble(
      key: UniqueKey(),
      fileUrl: fileUrl,
      fileMimeType: fileMimeType,
      style: FileBubbleStyle(
        background: style?.background,
        border: style?.border,
        borderRadius: style?.borderRadius,
        downloadIconTint: style?.downloadIconTint,
        gradient: style?.gradient,
        height: style?.height,
        width: style?.width,
        titleStyle: TextStyle(
                fontSize: theme.typography.name.fontSize,
                fontWeight: theme.typography.name.fontWeight,
                fontFamily: theme.typography.name.fontFamily,
                color: theme.palette.getAccent())
            .merge(style?.titleStyle),
        subtitleStyle: TextStyle(
                fontSize: theme.typography.subtitle2.fontSize,
                fontWeight: theme.typography.subtitle2.fontWeight,
                fontFamily: theme.typography.subtitle2.fontFamily,
                color: theme.palette.getAccent600())
            .merge(style?.subtitleStyle),
      ),
      title: title ?? "",
      id: id,
      theme: theme,
    );
  }

  @override
  Widget getImageMessageBubble(
      String? imageUrl,
      String? placeholderImage,
      String? caption,
      ImageBubbleStyle? style,
      MediaMessage message,
      Function()? onClick,
      BuildContext context,
      CometChatTheme theme) {
    return CometChatImageBubble(
      key: UniqueKey(),
      imageUrl: imageUrl,
      placeholderImage: placeholderImage,
      caption: caption,
      theme: theme,
      style: style ?? const ImageBubbleStyle(),
      onClick: onClick,
    );
  }

  @override
  String getLastConversationMessage(
      Conversation conversation, BuildContext context) {
    return ConversationUtils.getLastConversationMessage(conversation, context);
  }
}
