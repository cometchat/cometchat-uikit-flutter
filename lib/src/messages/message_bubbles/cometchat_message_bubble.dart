import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/messages/message_bubbles/cometchat_audio_bubble.dart';
import 'package:flutter_chat_ui_kit/src/messages/message_bubbles/cometchat_location_bubble.dart';
import 'package:cometchat/models/action.dart' as action;
import 'image_viewer.dart';
import 'video_player.dart';

///Parent View class of different type of bubbles
///
/// Message bubble is the term used by CometChat team to denote to all type of messages visible in message list
/// eg [CometChatFileBubble] , [CometChatImageBubble]..etc
/// [CometChatMessageBubble] is the view class that sets background for different bubbles
/// all types of bubble visible under message_bubble folder
///
/// ```dart
/// CometChatMessageBubble(
///     messageObject: baseMessageObject,
///     loggedInUserId: 'loggedInUserId',
///     messageInputData: MessageInputData<BaseMessage>(
///         thumbnail: true,
///         readReceipt: true,
///         title: true,
///         timestamp: true),
///     alignment: BubbleAlignment.right,
///     receiverUserId: 'receiverUserID',
///   customView: (BaseMessage baseMessage){
///       ///custom view for message bubble
///       return Container();
///   },
///     style: MessageBubbleStyle(
///         background: Colors.blue,
///         cornerRadius: 8,
///         border: Border.all(color: Colors.red, width: 1),
///         width: 1,
///         nameTextStyle: TextStyle(),
///         gradient: LinearGradient(colors: [])),
///     avatarConfiguration: const AvatarConfiguration(),
///     messageReceiptConfiguration:
///         const MessageReceiptConfiguration(),
///     dateConfiguration: const DateConfiguration(),
///     timeAlignment: TimeAlignment.bottom,
///     reactions: true,
///     threadReplies: true,
///     theme: CometChatTheme(
///         palette: Palette(),
///         typography: fl.Typography.fromDefault()),
///   )
///
///
/// ```
class CometChatMessageBubble extends StatelessWidget {
  const CometChatMessageBubble(
      {Key? key,
      this.messageInputData = const MessageInputData(),
      this.style = const MessageBubbleStyle(),
      this.alignment = BubbleAlignment.left,
      this.timeAlignment = TimeAlignment.bottom,
      required this.messageObject,
      this.loggedInUserId = '',
      this.threadReplies = true,
      this.reactions = true,
      this.avatarConfiguration = const AvatarConfiguration(),
      this.dateConfiguration = const DateConfiguration(),
      this.messageReceiptConfiguration = const MessageReceiptConfiguration(),
      this.theme,
      this.receiverUserId,
      this.receiverGroupId,
      this.customView})
      : super(key: key);

  ///[messageBubbleData] message bubble data
  final MessageInputData messageInputData;

  /// for messages delivered to user [receiverUserId] will be used to fetch receiver's data
  /// for messages delivered to Group [receiverGroupId] will be used to fetch group's data
  final String? receiverUserId;

  final String? receiverGroupId;

  ///[style] message bubble style
  final MessageBubbleStyle style;

  ///[alignment] bubble alignment left/center/right
  final BubbleAlignment alignment;

  ///[timeAlignment] time alignment top/bottom
  final TimeAlignment timeAlignment;

  ///[messageObject] base massage object
  final BaseMessage messageObject;

  ///[threadReplies] hide or show thread replies option
  final bool threadReplies;

  ///[reactions] hide or show reactions
  final bool reactions;

  ///[loggedInUserId] logged in user uid
  final String loggedInUserId;

  ///[dateConfiguration]
  final DateConfiguration dateConfiguration;

  ///set Receipt configuration from[messageReceiptConfiguration]
  final MessageReceiptConfiguration messageReceiptConfiguration;

  ///set avatar configuration from [avatarConfigurations]
  final AvatarConfiguration avatarConfiguration;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  final Widget? Function(BaseMessage)? customView;

  Widget getTime(CometChatTheme _theme) {
    if (messageObject.sentAt == null) {
      return const SizedBox();
    } else if (messageInputData.timestamp) {
      DateTime lastMessageTime = messageObject.sentAt!;
      return CometChatDate(
        date: lastMessageTime,
        pattern: dateConfiguration.pattern ?? DateTimePattern.timeFormat,
        dateFormat: dateConfiguration.dateFormat,
        timeFormat: dateConfiguration.timeFormat,
        contentPadding: dateConfiguration.contentPadding,
        isTransparentBackground: dateConfiguration.isTransparentBackground,
        cornerRadius: dateConfiguration.cornerRadius,
        borderColor:
            dateConfiguration.borderColor ?? _theme.palette.getBackground(),
        backgroundColor:
            dateConfiguration.backgroundColor ?? _theme.palette.getBackground(),
        textStyle: dateConfiguration.textStyle ??
            TextStyle(
                color: _theme.palette.getAccent500(),
                fontSize: _theme.typography.caption1.fontSize,
                fontWeight: _theme.typography.caption1.fontWeight,
                fontFamily: _theme.typography.caption1.fontFamily),
        borderWidth: dateConfiguration.borderWidth ?? 0,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getReceiptIcon(CometChatTheme _theme) {
    if (messageInputData.readReceipt == true) {
      return CometChatMessageReceipt(
        message: messageObject,
        deliveredIcon: messageReceiptConfiguration.deliveredIcon ??
            Image.asset(
              "assets/icons/message_received.png",
              package: UIConstants.packageName,
              color: _theme.palette.getAccent(),
            ),
        errorIcon: messageReceiptConfiguration.errorIcon,
        readIcon: messageReceiptConfiguration.readIcon ??
            Image.asset(
              "assets/icons/message_received.png",
              package: UIConstants.packageName,
              color: _theme.palette.getPrimary(),
            ),
        sentIcon: messageReceiptConfiguration.sentIcon ??
            Image.asset(
              "assets/icons/message_sent.png",
              package: UIConstants.packageName,
              color: _theme.palette.getAccent(),
            ),
        waitIcon: messageReceiptConfiguration.waitIcon,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getName(CometChatTheme _theme) {
    if (messageInputData.title) {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0, left: 8.0),
        child: Text(
          messageObject.sender!.name,
          style: style.nameTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.text2.fontSize,
                  color: _theme.palette.getAccent600(),
                  fontWeight: _theme.typography.text2.fontWeight,
                  fontFamily: _theme.typography.text2.fontFamily),
        ),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget getAvatar(CometChatTheme _theme, User userObject) {
    if (messageInputData.thumbnail) {
      return Padding(
        padding: const EdgeInsets.only(top: 15),
        child: CometChatAvatar(
          image: userObject.avatar,
          name: userObject.name,
          width: avatarConfiguration.width ?? 36,
          height: avatarConfiguration.height ?? 36,
          backgroundColor: avatarConfiguration.backgroundColor ??
              _theme.palette.getAccent700(),
          cornerRadius: avatarConfiguration.cornerRadius,
          outerCornerRadius: avatarConfiguration.outerCornerRadius,
          border: avatarConfiguration.border,
          outerViewBackgroundColor:
              avatarConfiguration.outerViewBackgroundColor,
          nameTextStyle: avatarConfiguration.nameTextStyle ??
              TextStyle(
                  color: _theme.palette.getBackground(),
                  fontSize: _theme.typography.name.fontSize,
                  fontWeight: _theme.typography.name.fontWeight,
                  fontFamily: _theme.typography.name.fontFamily),
          outerViewBorder: avatarConfiguration.outerViewBorder,
          outerViewSpacing: avatarConfiguration.outerViewSpacing,
          outerViewWidth: avatarConfiguration.outerViewWidth,
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getTextBubble(CometChatTheme _theme, BuildContext context) {
    TextMessage textMessage = messageObject as TextMessage;
    return GestureDetector(
      child: CometChatTextBubble(
        messageObject: textMessage,
        loggedInUserId: loggedInUserId,
        textStyle: TextStyle(
            color: _theme.palette.getAccent(),
            fontWeight: _theme.typography.name.fontWeight,
            fontSize: _theme.typography.name.fontSize,
            fontFamily: _theme.typography.name.fontFamily),
      ),
    );
  }

  Widget getImageBubble(CometChatTheme _theme, BuildContext context) {
    MediaMessage imageMessage = messageObject as MediaMessage;
    ConfirmDialogConfiguration _dialogConfiguration =
        ConfirmDialogConfiguration(
            title: Row(
              children: [
                Image.asset(
                  "assets/icons/messages_unsafe.png",
                  package: UIConstants.packageName,
                  color: _theme.palette.getAccent(),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(Translations.of(context).unsafe_content,
                    style: TextStyle(
                        fontSize: _theme.typography.name.fontSize,
                        fontWeight: _theme.typography.name.fontWeight,
                        color: _theme.palette.getAccent(),
                        fontFamily: _theme.typography.name.fontFamily))
              ],
            ),
            messageText: Text(
              Translations.of(context).are_you_sure_unsafe_content,
              style: TextStyle(
                  fontSize: _theme.typography.title2.fontSize,
                  fontWeight: _theme.typography.title2.fontWeight,
                  color: _theme.palette.getAccent(),
                  fontFamily: _theme.typography.title2.fontFamily),
            ),
            confirmButtonText: Translations.of(context).yes,
            cancelButtonText: Translations.of(context).no,
            confirmDialogStyle: ConfirmDialogStyle(
              backgroundColor: _theme.palette.getBackground(),
            ));

    return GestureDetector(
      onTap: () {
        if (imageMessage.attachment != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ImageViewer(
                        messageObject: imageMessage,
                        backgroundColor: _theme.palette.getBackground(),
                        backIconColor: _theme.palette.getPrimary(),
                      )));
        }
      },
      child: SizedBox(
        height: style.height ?? 225,
        width: style.width ?? 225,
        child: CometChatImageBubble(
          key: UniqueKey(),
          messageObject: imageMessage,
          loggedInUser: loggedInUserId,
          confirmDialogConfiguration: _dialogConfiguration,
          style: ImageBubbleStyle(
            moderationFilterColor: _theme.palette.getAccent(),
            moderationTextStyle: TextStyle(
                fontSize: _theme.typography.subtitle2.fontSize,
                fontWeight: _theme.typography.subtitle2.fontWeight,
                fontFamily: _theme.typography.subtitle2.fontFamily,
                color: _theme.palette.getBackground()),
            moderationImageColor: _theme.palette.getBackground(),
          ),
        ),
      ),
    );
  }

  Widget getVideoBubble(CometChatTheme _theme, BuildContext context) {
    MediaMessage videoMessage = messageObject as MediaMessage;

    return GestureDetector(
      onTap: () {
        String? _videoUrl = videoMessage.attachment?.fileUrl;
        if (_videoUrl != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => VideoPlayer(
                        backIcon: _theme.palette.getPrimary(),
                        fullScreenBackground: _theme.palette.getBackground(),
                        videoUrl: _videoUrl,
                      )));
        }
      },
      child: SizedBox(
        height: style.height ?? 225,
        width: style.width ?? 225,
        child: CometChatVideoBubble(
          messageObject: videoMessage,
        ),
      ),
    );
  }

  Widget getPollBubble(CometChatTheme _theme, BuildContext context) {
    CustomMessage _customMessage = messageObject as CustomMessage;
    return CometChatPollBubble(
      key: ValueKey(messageObject.id),
      messageObject: _customMessage,
      loggedInUser: loggedInUserId,
      style: PollBubbleStyle(
          pollOptionsBackgroundColor: _theme.palette.getBackground(),
          pollOptionsTextStyle: TextStyle(
              fontSize: _theme.typography.subtitle1.fontSize,
              fontWeight: _theme.typography.subtitle1.fontWeight,
              fontFamily: _theme.typography.fontBasics.fontFamily,
              color: _theme.palette.getAccent()),
          radioButtonColor: _theme.palette.getAccent100(),
          questionTextStyle: TextStyle(
              fontSize: _theme.typography.name.fontSize,
              fontWeight: _theme.typography.name.fontWeight,
              fontFamily: _theme.typography.name.fontFamily,
              color: _theme.palette.getAccent()),
          pollResultTextStyle: TextStyle(
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight,
              fontFamily: _theme.typography.subtitle2.fontFamily,
              color: _theme.palette.getAccent600()),
          voteCountTextStyle: TextStyle(
              fontSize: _theme.typography.subtitle1.fontSize,
              fontWeight: _theme.typography.subtitle1.fontWeight,
              fontFamily: _theme.typography.subtitle1.fontFamily,
              color: _theme.palette.getAccent600()),
          selectedOptionColor: _theme.palette.getPrimary200(),
          unSelectedOptionColor: _theme.palette.getAccent100()),
    );
  }

  Widget getFileBubble(CometChatTheme _theme) {
    MediaMessage fileMessage = messageObject as MediaMessage;
    return CometChatFileBubble(
      key: UniqueKey(),
      messageObject: fileMessage,
      style: FileBubbleStyle(
        titleStyle: TextStyle(
            fontSize: _theme.typography.name.fontSize,
            fontWeight: _theme.typography.name.fontWeight,
            fontFamily: _theme.typography.name.fontFamily,
            color: _theme.palette.getAccent()),
        subtitleStyle: TextStyle(
            fontSize: _theme.typography.subtitle2.fontSize,
            fontWeight: _theme.typography.subtitle2.fontWeight,
            fontFamily: _theme.typography.subtitle2.fontFamily,
            color: _theme.palette.getAccent600()),
      ),
    );
  }

  Widget getAudioBubble() {
    MediaMessage fileMessage = messageObject as MediaMessage;
    return Container(
        decoration: BoxDecoration(
            color:
                style.background ?? const Color(0xffF8F8F8).withOpacity(0.92),
            border: style.border,
            borderRadius: BorderRadius.circular(style.cornerRadius ?? 8)),
        child: CometChatAudioBubble(
          messageObject: fileMessage,
          key: UniqueKey(),
        ));
  }

  Widget getLocationBubble() {
    CustomMessage _message = messageObject as CustomMessage;
    return Container(
        //height: style.height ?? 190,
        width: style.width ?? 225,
        decoration: BoxDecoration(
            color:
                style.background ?? const Color(0xffF8F8F8).withOpacity(0.92),
            border: style.border,
            borderRadius: BorderRadius.circular(style.cornerRadius ?? 8)),
        child: CometChatLocationBubble(
          messageObject: _message,
          googleApiKey: "",
          key: UniqueKey(),
        ));
  }

  Widget getStickerBubble() {
    CustomMessage stickerMessage = messageObject as CustomMessage;
    return Container(
      constraints: BoxConstraints(
          maxHeight: style.height ?? 225, maxWidth: style.width ?? 225),
      child: CometChatStickerBubble(
        messageObject: stickerMessage,
      ),
    );
  }

  Widget getGroupActionBubble(CometChatTheme _theme) {
    action.Action actionMessage = messageObject as action.Action;
    return CometChatGroupActionBubble(
      messageObject: actionMessage,
      style: GroupActionBubbleStyle(
          textStyle: TextStyle(
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight,
              color: _theme.palette.getAccent600())),
    );
  }

  Widget getWhiteBoardBubble(BuildContext context, CometChatTheme _theme) {
    CustomMessage whiteboardMessage = messageObject as CustomMessage;
    return CometChatCollaborativeWhiteBoardBubble(
      messageObject: whiteboardMessage,
      style: WhiteBoardBubbleStyle(
          buttonTextStyle: TextStyle(
              color: _theme.palette.getPrimary(),
              fontSize: _theme.typography.name.fontSize,
              fontWeight: _theme.typography.name.fontWeight),
          subtitleStyle: TextStyle(
              color: _theme.palette.getAccent600(),
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight),
          titleStyle: TextStyle(
              color: _theme.palette.getAccent(),
              fontSize: _theme.typography.text1.fontSize,
              fontWeight: _theme.typography.text1.fontWeight),
          iconTint: _theme.palette.getAccent700(),
          webViewAppBarColor: _theme.palette.getBackground(),
          webViewBackIconColor: _theme.palette.getPrimary(),
          webViewTitleStyle: TextStyle(
              color: _theme.palette.getAccent(),
              fontSize: 20,
              fontWeight: _theme.typography.heading.fontWeight)),
    );
  }

  Widget getDocumentBubble(BuildContext context, CometChatTheme _theme) {
    CustomMessage documentMessage = messageObject as CustomMessage;
    return CometChatCollaborativeDocumentBubble(
      messageObject: documentMessage,
      style: DocumentBubbleStyle(
          buttonTextStyle: TextStyle(
              color: _theme.palette.getPrimary(),
              fontSize: _theme.typography.name.fontSize,
              fontWeight: _theme.typography.name.fontWeight),
          subtitleStyle: TextStyle(
              color: _theme.palette.getAccent600(),
              fontSize: _theme.typography.subtitle2.fontSize,
              fontWeight: _theme.typography.subtitle2.fontWeight),
          titleStyle: TextStyle(
              color: _theme.palette.getAccent(),
              fontSize: _theme.typography.text1.fontSize,
              fontWeight: _theme.typography.text1.fontWeight),
          iconTint: _theme.palette.getAccent700(),
          webViewAppBarColor: _theme.palette.getBackground(),
          webViewBackIconColor: _theme.palette.getPrimary(),
          webViewTitleStyle: TextStyle(
              color: _theme.palette.getAccent(),
              fontSize: _theme.typography.title1.fontSize,
              fontWeight: _theme.typography.title1.fontWeight)),
    );
  }

  Widget getDeleteMessageBubble(CometChatTheme _theme) {
    return CometChatDeleteMessageBubble(
      textStyle: TextStyle(
          color: _theme.palette.getAccent400(),
          fontSize: _theme.typography.body.fontSize,
          fontWeight: _theme.typography.body.fontWeight),
      borderColor: _theme.palette.getAccent200(),
    );
  }

  Widget getPlaceholderBubble(CometChatTheme _theme) {
    return CometChatPlaceholderBubble(
        message: messageObject,
        style: PlaceholderBubbleStyle(
          headerTextStyle: TextStyle(
              color: _theme.palette.getAccent800(),
              fontSize: _theme.typography.heading.fontSize,
              fontFamily: _theme.typography.heading.fontFamily,
              fontWeight: _theme.typography.heading.fontWeight),
          textStyle: TextStyle(
              color: _theme.palette.getAccent800(),
              fontSize: _theme.typography.subtitle2.fontSize,
              fontFamily: _theme.typography.subtitle2.fontFamily,
              fontWeight: _theme.typography.subtitle2.fontWeight),
        ));
  }

  Widget getSuitableBubble(
      CometChatTheme _theme, double width, BuildContext context) {
    if (customView != null && messageObject.deletedAt == null) {
      if (customView != null) {
        return customView!(messageObject) ?? const SizedBox();
      }
    }

    if (((messageObject.deletedBy != null &&
                messageObject.deletedBy!.trim() != "") ||
            messageObject.deletedAt != null) &&
        messageObject.type != MessageTypeConstants.groupActions) {
      return getDeleteMessageBubble(_theme);
    }
    if (messageObject.type == MessageTypeConstants.text) {
      return getTextBubble(_theme, context);
    } else if (messageObject.type == MessageTypeConstants.image) {
      return getImageBubble(_theme, context);
    } else if (messageObject.type == MessageTypeConstants.video) {
      return getVideoBubble(_theme, context);
    } else if (messageObject.type == MessageTypeConstants.poll) {
      return getPollBubble(_theme, context);
    } else if (messageObject.type == MessageTypeConstants.file) {
      return getFileBubble(_theme);
    } else if (messageObject.type == MessageTypeConstants.audio) {
      return getAudioBubble();
    } else if (messageObject.type == MessageTypeConstants.location) {
      return getLocationBubble();
    } else if (messageObject.type == MessageTypeConstants.sticker) {
      return getStickerBubble();
    } else if (messageObject.category == MessageCategoryConstants.action &&
        messageObject.type == MessageTypeConstants.groupActions) {
      return getGroupActionBubble(_theme);
    } else if (messageObject.type == MessageTypeConstants.document) {
      return getDocumentBubble(context, _theme);
    } else if (messageObject.type == MessageTypeConstants.whiteboard) {
      return getWhiteBoardBubble(context, _theme);
    } else if (messageObject.category == MessageCategoryConstants.action) {
      action.Action message = messageObject as action.Action;

      return GestureDetector(
          onTap: () {
            debugPrint(
                "-----type ${messageObject.type}  and category ${messageObject.category} , id ${messageObject.id}");
            debugPrint("-----type $message");
          },
          child: const Text("action message"));
    } else {
      return getPlaceholderBubble(_theme);

      // debugPrint(
      //     "for no match ${messageObject.id} ${messageObject.type}  and category ${messageObject.category} and deleted at ${messageObject.deletedAt} ${messageObject.deletedBy}");
      // return GestureDetector(
      //     onTap: () {
      //       debugPrint(
      //           "-----type ${messageObject.type}  and category ${messageObject.category}");
      //       debugPrint("-----type ${messageObject.toJson()}");
      //     },
      //     child: const Text("No Match"));
    }
  }

  MainAxisAlignment getBubbleAlignment() {
    if (alignment == BubbleAlignment.right) {
      return MainAxisAlignment.end;
    } else if (alignment == BubbleAlignment.center) {
      return MainAxisAlignment.center;
    } else {
      return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment getCrossAxisAlignment() {
    if (alignment == BubbleAlignment.right) {
      return CrossAxisAlignment.end;
    } else if (alignment == BubbleAlignment.center) {
      return CrossAxisAlignment.center;
    } else {
      return CrossAxisAlignment.start;
    }
  }

  Widget getMessagePreview(CometChatTheme _theme, BuildContext context) {
    if (messageObject.metadata != null &&
        messageObject.metadata!.containsKey("reply-message")) {
      String senderUserName = '';
      String messagePreviewSubtitle = '';
      try {
        Map<String, dynamic> replyMetadata =
            messageObject.metadata!["reply-message"];

        senderUserName = replyMetadata["sender"]["name"];

        if (replyMetadata["type"] == MessageTypeConstants.text) {
          messagePreviewSubtitle = replyMetadata["text"];
        } else {
          messagePreviewSubtitle = TemplateUtils.getMessageTypeToSubtitle(
              replyMetadata["type"], context);

          // messagePreviewSubtitle =
          //     messageTypeToSubtitle[replyMetadata["type"]] ??
          //         replyMetadata["type"];
        }
      } catch (e) {
        debugPrint('$e');
      }

      return CometChatMessagePreview(
        messagePreviewTitle: senderUserName,
        messagePreviewSubtitle: messagePreviewSubtitle,
        hideCloseButton: true,
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
                    color: _theme.palette.getAccent100(), width: 3))),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget getTranslationView(CometChatTheme _theme) {
    if (messageObject.metadata != null &&
        messageObject.metadata!.containsKey('translated_message')) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        alignment: Alignment.bottomLeft,
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: messageObject.metadata!['translated_message'],
                style: TextStyle(
                  fontSize: _theme.typography.subtitle2.fontSize,
                  fontWeight: _theme.typography.subtitle2.fontWeight,
                  color: _theme.palette.getAccent(),
                )),
            const TextSpan(
              text: '\n\n',
            ),
            TextSpan(
                text: 'Translated Message',
                style: TextStyle(
                  fontSize: _theme.typography.caption2.fontSize,
                  fontWeight: _theme.typography.caption2.fontWeight,
                  color: _theme.palette.getAccent(),
                ))
          ]),
        ),
      );
    }
    return const SizedBox(
      height: 0,
      width: 0,
    );
  }

  Widget getMessageReactions(CometChatTheme _theme) {
    return CometChatReactions(
      messageObject: messageObject,
      loggedInUserId: loggedInUserId,
      theme: _theme,
    );
  }

  Widget getViewReplies(CometChatTheme _theme, BuildContext context) {
    if (messageObject.replyCount != 0 && threadReplies) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CometChatMessageThread(
                        message: messageObject,
                        theme: _theme,
                        group: receiverGroupId,
                        user: receiverUserId,
                      )));
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 12, right: 12),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: _theme.palette.getAccent200(), width: 1))),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${Translations.of(context).view} ${messageObject.replyCount} ${Translations.of(context).replies}",
                  style: TextStyle(
                      fontSize: _theme.typography.body.fontSize,
                      fontWeight: _theme.typography.body.fontWeight,
                      //color: _theme.palette.getPrimary()
                      color: _theme.palette.getAccent()),
                ),
                Icon(
                  Icons.navigate_next,
                  size: 16,
                  color: _theme.palette.getAccent400(),
                )
              ],
            ),
          ),
        ),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: getBubbleAlignment(),
        children: [
          if (alignment == BubbleAlignment.left)
            getAvatar(_theme, messageObject.sender!),
          Column(
            crossAxisAlignment: getCrossAxisAlignment(),
            children: [
              Row(
                children: [
                  getName(_theme),
                  if (timeAlignment == TimeAlignment.top) getTime(_theme),
                ],
              ),

              //-----bubble-----

              Padding(
                padding: const EdgeInsets.only(
                    right: 8.0, top: 3, left: 8, bottom: 3),
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: style.width ??
                          MediaQuery.of(context).size.width * 65 / 100),
                  decoration: BoxDecoration(
                      color: style.background ??
                          const Color(0xffF8F8F8).withOpacity(0.92),
                      borderRadius: BorderRadius.all(
                          Radius.circular(style.cornerRadius ?? 8)),
                      border: style.border,
                      gradient: style.gradient),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(
                        Radius.circular(style.cornerRadius ?? 8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        getMessagePreview(_theme, context),
                        getSuitableBubble(
                            _theme, MediaQuery.of(context).size.width, context),

                        //----translated message----
                        getTranslationView(_theme),

                        //-----message reactions-----
                        getMessageReactions(_theme),

                        //-----thread replies-----
                        getViewReplies(_theme, context),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),
              Row(
                mainAxisAlignment: alignment == BubbleAlignment.right
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (timeAlignment == TimeAlignment.bottom) getTime(_theme),
                  getReceiptIcon(_theme)
                ],
              )
            ],
          ),
          if (alignment == BubbleAlignment.right)
            getAvatar(_theme, messageObject.sender!),
        ],
      ),
    );
  }
}

class MessageBubbleData {
  ///message bubble data
  const MessageBubbleData(
      {this.thumbnail = false,
      this.name = false,
      this.timeStamp = true,
      this.readReceipt = true});

  ///[thumbnail] show or hide thumbnail
  final bool thumbnail;

  ///[name] show or hide name
  final bool name;

  ///[timeStamp] show or hide time stamp
  final bool timeStamp;

  ///[readReceipt] show or hide read receipt
  final bool readReceipt;
}

class MessageBubbleStyle {
  ///message bubble style
  const MessageBubbleStyle({
    this.height,
    this.width,
    this.background,
    this.cornerRadius,
    this.border,
    this.nameTextStyle,
    this.gradient,
  });

  ///[height] height of bubble
  final double? height;

  ///[width] width of bubble
  final double? width;

  ///[background] background color
  final Color? background;

  ///[cornerRadius] corner radius
  final double? cornerRadius;

  ///[border] border
  final BoxBorder? border;

  ///[nameTextStyle] name text style
  final TextStyle? nameTextStyle;

  final Gradient? gradient;
}
