import 'package:flutter/material.dart';
import '../../../../../cometchat_uikit_shared.dart'
    show
        CometChatExceptionStyle,
        CometChatAvatarStyle,
        CometChatMessageReceiptStyle,
        CometChatReactionsStyle,
        CometChatDateStyle,
        CometChatTextBubbleStyle,
        CometChatImageBubbleStyle,
        CometChatVideoBubbleStyle,
        CometChatVoiceNoteBubbleStyle,
        CometChatFileBubbleStyle,
        CometChatCollaborativeBubbleStyle,
        CometChatPollsBubbleStyle,
        CometChatDeletedBubbleStyle,
        CometChatLinkPreviewBubbleStyle,
        CometChatMessageTranslationBubbleStyle,
        CometChatStickerBubbleStyle,
        CometChatCallBubbleStyle,
        CometChatModerationStyle;
import '../../../../../../chat_ui/src/message_composer/cometchat_message_preview.dart'
    show CometChatMessagePreviewStyle;

///[CometChatOutgoingMessageBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of the outgoing message bubble
///
/// ```dart
/// CometChatOutgoingMessageBubbleStyle(
///  backgroundColor: Colors.white,
///  border: Border.all(color: Colors.red),
///  borderRadius: BorderRadius.circular(10),
///  messageBubbleAvatarStyle: CometChatAvatarStyle(),
///  messageReceiptStyle: CometChatMessageReceiptStyle(),
///  messageBubbleDateStyle: CometChatDateStyle(),
///  textBubbleStyle: CometChatTextBubbleStyle(),
///  imageBubbleStyle: CometChatImageBubbleStyle(),
///  videoBubbleStyle: CometChatVideoBubbleStyle(),
///  voiceNoteBubbleStyle: CometChatVoiceNoteBubbleStyle(),
///  fileBubbleStyle: CometChatFileBubbleStyle(),
/// );
/// ```
class CometChatOutgoingMessageBubbleStyle
    extends ThemeExtension<CometChatOutgoingMessageBubbleStyle> {
  /// Style for the quoted-message preview inside an outgoing bubble that is
  /// a reply. Each property set here overrides the kit's default for it.
  final CometChatMessagePreviewStyle? messagePreviewStyle;

  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Style for the exception view of a sent message.
  @Deprecated(
    'Has no effect. The outgoing bubble has no exception view: style the moderation banner with moderationStyle, and attachment-size errors surface in the composer (CometChatMessageComposer.attachmentErrorAlertStyle). Will be removed in 7.0.0.',
  )
  final CometChatExceptionStyle? exceptionStyle;

  const CometChatOutgoingMessageBubbleStyle({
    this.messageBubbleBackgroundImage,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.threadedMessageIndicatorTextStyle,
    this.threadedMessageIndicatorIconColor,
    this.messageBubbleAvatarStyle,
    this.messageReceiptStyle,
    this.messageBubbleReactionStyle,
    this.messageBubbleDateStyle,
    this.textBubbleStyle,
    this.imageBubbleStyle,
    this.videoBubbleStyle,
    @Deprecated('Use voiceNoteBubbleStyle instead.') this.audioBubbleStyle,
    this.voiceNoteBubbleStyle,
    this.fileBubbleStyle,
    this.collaborativeDocumentBubbleStyle,
    this.collaborativeWhiteboardBubbleStyle,
    this.pollsBubbleStyle,
    this.deletedBubbleStyle,
    this.linkPreviewBubbleStyle,
    this.messageTranslationBubbleStyle,
    this.stickerBubbleStyle,
    this.voiceCallBubbleStyle,
    this.videoCallBubbleStyle,
    this.moderationStyle,
    this.messagePreviewStyle,
    this.exceptionStyle,
  });

  ///[messageBubbleBackgroundImage] provides background image to the message bubble of the sent message
  final DecorationImage? messageBubbleBackgroundImage;

  ///[backgroundColor] provides background color to the message bubble of the sent message
  final Color? backgroundColor;

  ///[border] provides border to the message bubble of the sent message
  final BoxBorder? border;

  ///[borderRadius] provides border radius to the message bubble of the sent message
  final BorderRadiusGeometry? borderRadius;

  ///[threadedMessageIndicatorTextStyle] provides text style to the threaded message indicator
  final TextStyle? threadedMessageIndicatorTextStyle;

  ///[threadedMessageIndicatorIconColor] provides color to the threaded message icon
  final Color? threadedMessageIndicatorIconColor;

  ///[messageBubbleAvatarStyle] provides style to the avatar of the sender
  final CometChatAvatarStyle? messageBubbleAvatarStyle;

  ///[messageReceiptStyle] provides style to the message receipt
  final CometChatMessageReceiptStyle? messageReceiptStyle;

  ///[messageBubbleReactionStyle] provides style to the reactions of the message bubble
  final CometChatReactionsStyle? messageBubbleReactionStyle;

  ///[messageBubbleDateStyle] provides style to the date of the message bubble
  final CometChatDateStyle? messageBubbleDateStyle;

  ///[textBubbleStyle] provides style to the text bubble of the sent message
  final CometChatTextBubbleStyle? textBubbleStyle;

  ///[imageBubbleStyle] provides style to the image bubble of the sent message
  final CometChatImageBubbleStyle? imageBubbleStyle;

  ///[videoBubbleStyle] provides style to the video bubble of the sent message
  final CometChatVideoBubbleStyle? videoBubbleStyle;

  ///[audioBubbleStyle] provides style to the audio bubble of the sent message
  @Deprecated('Use voiceNoteBubbleStyle instead.')
  final CometChatVoiceNoteBubbleStyle? audioBubbleStyle;

  ///[voiceNoteBubbleStyle] provides style to the voice note bubble of the
  ///sent message. Takes precedence over the deprecated [audioBubbleStyle].
  final CometChatVoiceNoteBubbleStyle? voiceNoteBubbleStyle;

  /// The style to apply, preferring [voiceNoteBubbleStyle] and falling back to
  /// the deprecated [audioBubbleStyle] so existing integrations keep working.
  CometChatVoiceNoteBubbleStyle? get effectiveVoiceNoteBubbleStyle =>
      // ignore: deprecated_member_use_from_same_package
      voiceNoteBubbleStyle ?? audioBubbleStyle;

  ///[fileBubbleStyle] provides style to the file bubble of the sent message
  final CometChatFileBubbleStyle? fileBubbleStyle;

  ///[collaborativeDocumentBubbleStyle] provides style to the collaborative document bubble of the sent message
  final CometChatCollaborativeBubbleStyle? collaborativeDocumentBubbleStyle;

  ///[collaborativeWhiteboardBubbleStyle] provides style to the collaborative whiteboard bubble of the sent message
  final CometChatCollaborativeBubbleStyle? collaborativeWhiteboardBubbleStyle;

  ///[pollsBubbleStyle] provides style to the polls bubble of the sent message
  final CometChatPollsBubbleStyle? pollsBubbleStyle;

  ///[deletedBubbleStyle] provides style to the deleted bubble of the sent message
  final CometChatDeletedBubbleStyle? deletedBubbleStyle;

  ///[linkPreviewBubbleStyle] provides style to the link preview bubble of the sent message
  final CometChatLinkPreviewBubbleStyle? linkPreviewBubbleStyle;

  ///[messageTranslationBubbleStyle] provides style to the message translation bubble of the sent message
  final CometChatMessageTranslationBubbleStyle? messageTranslationBubbleStyle;

  ///[stickerBubbleStyle] provides style to the sticker bubble of the sent message
  final CometChatStickerBubbleStyle? stickerBubbleStyle;

  ///[voiceCallBubbleStyle] is a [CometChatCallBubbleStyle] that can be used to style voice call bubble
  final CometChatCallBubbleStyle? voiceCallBubbleStyle;

  ///[videoCallBubbleStyle] is a [CometChatCallBubbleStyle] that can be used to style video call bubble
  final CometChatCallBubbleStyle? videoCallBubbleStyle;

  ///[moderationStyle] provides style to the moderated view of the sent message
  final CometChatModerationStyle? moderationStyle;

  static CometChatOutgoingMessageBubbleStyle of(BuildContext context) =>
      const CometChatOutgoingMessageBubbleStyle();

  @override
  CometChatOutgoingMessageBubbleStyle copyWith({
    DecorationImage? messageBubbleBackgroundImage,
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    TextStyle? threadedMessageIndicatorTextStyle,
    Color? threadedMessageIndicatorIconColor,
    CometChatAvatarStyle? messageBubbleAvatarStyle,
    CometChatMessageReceiptStyle? messageReceiptStyle,
    CometChatReactionsStyle? messageBubbleReactionStyle,
    CometChatDateStyle? messageBubbleDateStyle,
    CometChatTextBubbleStyle? textBubbleStyle,
    CometChatImageBubbleStyle? imageBubbleStyle,
    CometChatVideoBubbleStyle? videoBubbleStyle,
    @Deprecated('Use voiceNoteBubbleStyle instead.')
    CometChatVoiceNoteBubbleStyle? audioBubbleStyle,
    CometChatVoiceNoteBubbleStyle? voiceNoteBubbleStyle,
    CometChatFileBubbleStyle? fileBubbleStyle,
    CometChatCollaborativeBubbleStyle? collaborativeDocumentBubbleStyle,
    CometChatCollaborativeBubbleStyle? collaborativeWhiteboardBubbleStyle,
    CometChatLinkPreviewBubbleStyle? linkPreviewBubbleStyle,
    CometChatPollsBubbleStyle? pollsBubbleStyle,
    CometChatDeletedBubbleStyle? deletedBubbleStyle,
    CometChatMessageTranslationBubbleStyle? messageTranslationBubbleStyle,
    CometChatStickerBubbleStyle? stickerBubbleStyle,
    TextStyle? senderNameTextStyle,
    CometChatCallBubbleStyle? voiceCallBubbleStyle,
    CometChatCallBubbleStyle? videoCallBubbleStyle,
    CometChatModerationStyle? moderationStyle,
    CometChatMessagePreviewStyle? messagePreviewStyle,
  }) {
    return CometChatOutgoingMessageBubbleStyle(
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? this.messageBubbleBackgroundImage,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      threadedMessageIndicatorTextStyle:
          threadedMessageIndicatorTextStyle ??
          this.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          threadedMessageIndicatorIconColor ??
          this.threadedMessageIndicatorIconColor,
      messageBubbleAvatarStyle:
          messageBubbleAvatarStyle ?? this.messageBubbleAvatarStyle,
      messageReceiptStyle: messageReceiptStyle ?? this.messageReceiptStyle,
      messageBubbleReactionStyle:
          messageBubbleReactionStyle ?? this.messageBubbleReactionStyle,
      messageBubbleDateStyle:
          messageBubbleDateStyle ?? this.messageBubbleDateStyle,
      textBubbleStyle: textBubbleStyle ?? this.textBubbleStyle,
      imageBubbleStyle: imageBubbleStyle ?? this.imageBubbleStyle,
      videoBubbleStyle: videoBubbleStyle ?? this.videoBubbleStyle,
      // ignore: deprecated_member_use_from_same_package
      audioBubbleStyle: audioBubbleStyle ?? this.audioBubbleStyle,
      voiceNoteBubbleStyle: voiceNoteBubbleStyle ?? this.voiceNoteBubbleStyle,
      fileBubbleStyle: fileBubbleStyle ?? this.fileBubbleStyle,
      collaborativeDocumentBubbleStyle:
          collaborativeDocumentBubbleStyle ??
          this.collaborativeDocumentBubbleStyle,
      collaborativeWhiteboardBubbleStyle:
          collaborativeWhiteboardBubbleStyle ??
          this.collaborativeWhiteboardBubbleStyle,
      pollsBubbleStyle: pollsBubbleStyle ?? this.pollsBubbleStyle,
      deletedBubbleStyle: deletedBubbleStyle ?? this.deletedBubbleStyle,
      messageTranslationBubbleStyle:
          messageTranslationBubbleStyle ?? this.messageTranslationBubbleStyle,
      linkPreviewBubbleStyle:
          linkPreviewBubbleStyle ?? this.linkPreviewBubbleStyle,
      stickerBubbleStyle: stickerBubbleStyle ?? this.stickerBubbleStyle,
      voiceCallBubbleStyle: voiceCallBubbleStyle ?? this.voiceCallBubbleStyle,
      videoCallBubbleStyle: videoCallBubbleStyle ?? this.videoCallBubbleStyle,
      moderationStyle: moderationStyle ?? this.moderationStyle,
      messagePreviewStyle: messagePreviewStyle ?? this.messagePreviewStyle,
    );
  }

  CometChatOutgoingMessageBubbleStyle merge(
    CometChatOutgoingMessageBubbleStyle? style,
  ) {
    if (style == null) return this;
    return copyWith(
      messageBubbleBackgroundImage: style.messageBubbleBackgroundImage,
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      // ignore: deprecated_member_use_from_same_package
      audioBubbleStyle: style.audioBubbleStyle,
      voiceNoteBubbleStyle: style.voiceNoteBubbleStyle,
      messageBubbleAvatarStyle: style.messageBubbleAvatarStyle,
      fileBubbleStyle: style.fileBubbleStyle,
      imageBubbleStyle: style.imageBubbleStyle,
      messageBubbleDateStyle: style.messageBubbleDateStyle,
      messageBubbleReactionStyle: style.messageBubbleReactionStyle,
      messageReceiptStyle: style.messageReceiptStyle,
      textBubbleStyle: style.textBubbleStyle,
      threadedMessageIndicatorIconColor:
          style.threadedMessageIndicatorIconColor,
      threadedMessageIndicatorTextStyle:
          style.threadedMessageIndicatorTextStyle,
      videoBubbleStyle: style.videoBubbleStyle,
      collaborativeDocumentBubbleStyle: style.collaborativeDocumentBubbleStyle,
      collaborativeWhiteboardBubbleStyle:
          style.collaborativeWhiteboardBubbleStyle,
      pollsBubbleStyle: style.pollsBubbleStyle,
      deletedBubbleStyle: style.deletedBubbleStyle,
      linkPreviewBubbleStyle: style.linkPreviewBubbleStyle,
      messageTranslationBubbleStyle: style.messageTranslationBubbleStyle,
      stickerBubbleStyle: style.stickerBubbleStyle,
      voiceCallBubbleStyle: style.voiceCallBubbleStyle,
      videoCallBubbleStyle: style.videoCallBubbleStyle,
      moderationStyle: style.moderationStyle,
      messagePreviewStyle: style.messagePreviewStyle,
    );
  }

  @override
  CometChatOutgoingMessageBubbleStyle lerp(
    covariant CometChatOutgoingMessageBubbleStyle? other,
    double t,
  ) {
    if (other is! CometChatOutgoingMessageBubbleStyle) {
      return this;
    }
    return CometChatOutgoingMessageBubbleStyle(
      messageBubbleBackgroundImage: DecorationImage.lerp(
        messageBubbleBackgroundImage,
        other.messageBubbleBackgroundImage,
        t,
      ),
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      border: Border.lerp(border as Border?, other.border as Border?, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      threadedMessageIndicatorTextStyle: TextStyle.lerp(
        threadedMessageIndicatorTextStyle,
        other.threadedMessageIndicatorTextStyle,
        t,
      ),
      threadedMessageIndicatorIconColor: Color.lerp(
        threadedMessageIndicatorIconColor,
        other.threadedMessageIndicatorIconColor,
        t,
      ),
      messageBubbleAvatarStyle: messageBubbleAvatarStyle?.lerp(
        other.messageBubbleAvatarStyle,
        t,
      ),
      messageReceiptStyle: messageReceiptStyle?.lerp(
        other.messageReceiptStyle,
        t,
      ),
      messageBubbleDateStyle: messageBubbleDateStyle?.lerp(
        other.messageBubbleDateStyle,
        t,
      ),
      textBubbleStyle: textBubbleStyle?.lerp(other.textBubbleStyle, t),
      imageBubbleStyle: imageBubbleStyle?.lerp(other.imageBubbleStyle, t),
      videoBubbleStyle: videoBubbleStyle?.lerp(other.videoBubbleStyle, t),
      // ignore: deprecated_member_use_from_same_package
      audioBubbleStyle: audioBubbleStyle?.lerp(other.audioBubbleStyle, t),
      voiceNoteBubbleStyle: voiceNoteBubbleStyle?.lerp(
        other.voiceNoteBubbleStyle,
        t,
      ),
      fileBubbleStyle: fileBubbleStyle?.lerp(other.fileBubbleStyle, t),
      collaborativeDocumentBubbleStyle: collaborativeDocumentBubbleStyle?.lerp(
        other.collaborativeDocumentBubbleStyle,
        t,
      ),
      collaborativeWhiteboardBubbleStyle: collaborativeWhiteboardBubbleStyle
          ?.lerp(other.collaborativeWhiteboardBubbleStyle, t),
      pollsBubbleStyle: pollsBubbleStyle?.lerp(other.pollsBubbleStyle, t),
      deletedBubbleStyle: deletedBubbleStyle?.lerp(other.deletedBubbleStyle, t),
      linkPreviewBubbleStyle: linkPreviewBubbleStyle?.lerp(
        other.linkPreviewBubbleStyle,
        t,
      ),
      messageBubbleReactionStyle: messageBubbleReactionStyle?.lerp(
        other.messageBubbleReactionStyle,
        t,
      ),
      messageTranslationBubbleStyle: messageTranslationBubbleStyle?.lerp(
        other.messageTranslationBubbleStyle,
        t,
      ),
      stickerBubbleStyle: stickerBubbleStyle?.lerp(other.stickerBubbleStyle, t),
      voiceCallBubbleStyle: voiceCallBubbleStyle?.lerp(
        other.voiceCallBubbleStyle,
        t,
      ),
      videoCallBubbleStyle: videoCallBubbleStyle?.lerp(
        other.videoCallBubbleStyle,
        t,
      ),
      moderationStyle: moderationStyle?.lerp(other.moderationStyle, t),
      messagePreviewStyle: messagePreviewStyle?.lerp(
        other.messagePreviewStyle,
        t,
      ),
    );
  }
}
