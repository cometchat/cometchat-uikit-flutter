import '../../../../cometchat_uikit_shared.dart'
    show
        CometChatCallButtonsStyle,
        CometChatCollaborativeBubbleStyle,
        CometChatMessageTranslationBubbleStyle,
        CometChatPollsBubbleStyle,
        CometChatStickerBubbleStyle,
        CometChatTextFormatter,
        CometChatTextBubbleStyle,
        CometChatImageBubbleStyle,
        CometChatVideoBubbleStyle,
        CometChatVoiceNoteBubbleStyle,
        CometChatFileBubbleStyle,
        CometChatAttachmentOptionSheetStyle,
        CometChatMessageOptionSheetStyle,
        CometChatActionBubbleStyle,
        CometChatDeletedBubbleStyle,
        CometChatLinkPreviewBubbleStyle,
        CometChatCallBubbleStyle;

///[AdditionalConfigurations] is a class that can be used to add additional configurations to the UI Kit
/// ```dart
/// AdditionalConfigurations(
///    textFormatters: [
///    CometChatPhoneNumberFormatter(
///    pattern: RegExp(RegexConstants.phoneNumberRegexPattern),
///    onSearch: (phoneNumber) async {
///    await launchUrl(Uri.parse(('tel:$phoneNumber')));
///    },
///    messageBubbleTextStyle: (theme, alignment,{forConversation}) {
///    return TextStyle(
///    color: Colors.pink,
///    );
///    },
///    ),
///    CometChatEmailFormatter(
///    pattern: RegExp(RegexConstants.emailRegexPattern),
///    onSearch: (email) async {
///    await launchUrl(Uri.parse(('mailto:$email')));
///    },
///    messageBubbleTextStyle: (theme, alignment,{forConversation}) {
///    return TextStyle(
///    color: Colors.red,
///    );
///    },
///    ),
///    ],
///    );
///    ```
class AdditionalConfigurations {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Style for the call buttons.
  @Deprecated(
    'Has no effect. Style the call buttons through CometChatMessageHeaderStyle.callButtonsStyle. Will be removed in 7.0.0.',
  )
  final CometChatCallButtonsStyle? callButtonsStyle;

  /// Whether the video call button is hidden.
  @Deprecated(
    'Has no effect. Use CometChatMessageHeader.hideVideoCallButton. Will be removed in 7.0.0.',
  )
  final bool? hideVideoCallButton;

  /// Whether the voice call button is hidden.
  @Deprecated(
    'Has no effect. Use CometChatMessageHeader.hideVoiceCallButton. Will be removed in 7.0.0.',
  )
  final bool? hideVoiceCallButton;

  /// Whether the stickers button is hidden.
  @Deprecated(
    'Has no effect. Use CometChatMessageComposer.hideStickersButton. Will be removed in 7.0.0.',
  )
  final bool? hideStickersButton;

  /// Whether the reaction option is hidden.
  @Deprecated(
    'Has no effect. Use CometChatMessageList.hideReactionOption. Will be removed in 7.0.0.',
  )
  final bool? hideReactionOption;

  /// Creates an [AdditionalConfigurations]. Every property is optional; an
  /// unset one leaves the kit's default in place.
  AdditionalConfigurations({
    this.textFormatters,
    this.textBubbleStyle,
    this.imageBubbleStyle,
    this.videoBubbleStyle,
    @Deprecated('Use voiceNoteBubbleStyle instead.') this.audioBubbleStyle,
    this.voiceNoteBubbleStyle,
    this.fileBubbleStyle,
    this.attachmentOptionSheetStyle,
    this.messageOptionSheetStyle,
    this.actionBubbleStyle,
    this.deletedBubbleStyle,
    this.linkPreviewBubbleStyle,
    this.voiceCallBubbleStyle,
    this.videoCallBubbleStyle,
    this.hideImageAttachmentOption,
    this.hideVideoAttachmentOption,
    this.hideAudioAttachmentOption,
    this.hideFileAttachmentOption,
    this.hidePollsOption,
    this.hideCollaborativeDocumentOption,
    this.hideCollaborativeWhiteboardOption,
    this.hideTakPhotoOption,
    this.hideCopyMessageOption,
    this.hideDeleteMessageOption,
    this.hideEditMessageOption,
    this.hideMessagePrivatelyOption,
    this.hideTranslateMessageOption,
    this.hideMessageInfoOption,
    this.hideReplyInThreadOption,
    this.hideThreadSubscriptionOption,
    this.hidePinMessageOption,
    this.hideUnpinMessageOption,
    this.hideSaveMessageOption,
    this.hideUnsaveMessageOption,
    this.hideReplyOption,
    this.hideShareMessageOption,
    this.showMarkAsUnreadOption,
    this.hideFlagOption,
    this.enableMultipleAttachments,
    this.collaborativeDocumentBubbleStyle,
    this.collaborativeWhiteboardBubbleStyle,
    this.pollsBubbleStyle,
    this.messageTranslationBubbleStyle,
    this.stickerBubbleStyle,
    this.callButtonsStyle,
    this.hideVideoCallButton,
    this.hideVoiceCallButton,
    this.hideStickersButton,
    this.hideReactionOption,
  });

  /// A copy of this configuration with the given bubble styles replaced.
  /// Every other field — deprecated ones included — carries over unchanged,
  /// so the copy can be adjusted without touching this instance.
  ///
  /// The message list fills the per-message bubble styles on a copy, so an
  /// app-supplied configuration shared by every row is never written to.
  AdditionalConfigurations copyWith({
    CometChatPollsBubbleStyle? pollsBubbleStyle,
    CometChatStickerBubbleStyle? stickerBubbleStyle,
    CometChatCollaborativeBubbleStyle? collaborativeDocumentBubbleStyle,
    CometChatCollaborativeBubbleStyle? collaborativeWhiteboardBubbleStyle,
    CometChatLinkPreviewBubbleStyle? linkPreviewBubbleStyle,
    CometChatMessageTranslationBubbleStyle? messageTranslationBubbleStyle,
  }) {
    return AdditionalConfigurations(
      textFormatters: textFormatters,
      textBubbleStyle: textBubbleStyle,
      imageBubbleStyle: imageBubbleStyle,
      videoBubbleStyle: videoBubbleStyle,
      // ignore: deprecated_member_use_from_same_package
      audioBubbleStyle: audioBubbleStyle,
      voiceNoteBubbleStyle: voiceNoteBubbleStyle,
      fileBubbleStyle: fileBubbleStyle,
      attachmentOptionSheetStyle: attachmentOptionSheetStyle,
      messageOptionSheetStyle: messageOptionSheetStyle,
      actionBubbleStyle: actionBubbleStyle,
      deletedBubbleStyle: deletedBubbleStyle,
      linkPreviewBubbleStyle:
          linkPreviewBubbleStyle ?? this.linkPreviewBubbleStyle,
      voiceCallBubbleStyle: voiceCallBubbleStyle,
      videoCallBubbleStyle: videoCallBubbleStyle,
      hideImageAttachmentOption: hideImageAttachmentOption,
      hideVideoAttachmentOption: hideVideoAttachmentOption,
      hideAudioAttachmentOption: hideAudioAttachmentOption,
      hideFileAttachmentOption: hideFileAttachmentOption,
      hidePollsOption: hidePollsOption,
      hideCollaborativeDocumentOption: hideCollaborativeDocumentOption,
      hideCollaborativeWhiteboardOption: hideCollaborativeWhiteboardOption,
      hideTakPhotoOption: hideTakPhotoOption,
      hideCopyMessageOption: hideCopyMessageOption,
      hideDeleteMessageOption: hideDeleteMessageOption,
      hideEditMessageOption: hideEditMessageOption,
      hideMessagePrivatelyOption: hideMessagePrivatelyOption,
      hideTranslateMessageOption: hideTranslateMessageOption,
      hideMessageInfoOption: hideMessageInfoOption,
      hideReplyInThreadOption: hideReplyInThreadOption,
      hideThreadSubscriptionOption: hideThreadSubscriptionOption,
      hidePinMessageOption: hidePinMessageOption,
      hideUnpinMessageOption: hideUnpinMessageOption,
      hideSaveMessageOption: hideSaveMessageOption,
      hideUnsaveMessageOption: hideUnsaveMessageOption,
      hideReplyOption: hideReplyOption,
      hideShareMessageOption: hideShareMessageOption,
      showMarkAsUnreadOption: showMarkAsUnreadOption,
      hideFlagOption: hideFlagOption,
      enableMultipleAttachments: enableMultipleAttachments,
      collaborativeDocumentBubbleStyle:
          collaborativeDocumentBubbleStyle ??
          this.collaborativeDocumentBubbleStyle,
      collaborativeWhiteboardBubbleStyle:
          collaborativeWhiteboardBubbleStyle ??
          this.collaborativeWhiteboardBubbleStyle,
      pollsBubbleStyle: pollsBubbleStyle ?? this.pollsBubbleStyle,
      messageTranslationBubbleStyle:
          messageTranslationBubbleStyle ?? this.messageTranslationBubbleStyle,
      stickerBubbleStyle: stickerBubbleStyle ?? this.stickerBubbleStyle,
      // ignore: deprecated_member_use_from_same_package
      callButtonsStyle: callButtonsStyle,
      // ignore: deprecated_member_use_from_same_package
      hideVideoCallButton: hideVideoCallButton,
      // ignore: deprecated_member_use_from_same_package
      hideVoiceCallButton: hideVoiceCallButton,
      // ignore: deprecated_member_use_from_same_package
      hideStickersButton: hideStickersButton,
      // ignore: deprecated_member_use_from_same_package
      hideReactionOption: hideReactionOption,
    );
  }

  ///[enableMultipleAttachments] routes media messages to the multi-attachment
  ///bubble family (images / videos / audios / voice note / files) when true
  ///(the default); false falls back to the deprecated single-attachment
  ///bubbles. Mutable so the message list can inject its widget-level flag into
  ///an app-provided configurations object.
  bool? enableMultipleAttachments;

  ///[pollsBubbleStyle] styles `CometChatPollsBubble`. Filled per message
  ///from the Incoming/Outgoing message bubble style by alignment; set it to
  ///override.
  CometChatPollsBubbleStyle? pollsBubbleStyle;

  ///[stickerBubbleStyle] styles `CometChatStickerBubble`. Filled per message
  ///from the Incoming/Outgoing message bubble style by alignment; set it to
  ///override.
  CometChatStickerBubbleStyle? stickerBubbleStyle;

  ///[collaborativeDocumentBubbleStyle] styles the collaborative document
  ///`CometChatCollaborativeBubble`. Filled per message from the
  ///Incoming/Outgoing message bubble style by alignment; set it to override.
  CometChatCollaborativeBubbleStyle? collaborativeDocumentBubbleStyle;

  ///[collaborativeWhiteboardBubbleStyle] styles the collaborative whiteboard
  ///`CometChatCollaborativeBubble`. Filled per message from the
  ///Incoming/Outgoing message bubble style by alignment; set it to override.
  CometChatCollaborativeBubbleStyle? collaborativeWhiteboardBubbleStyle;

  ///[messageTranslationBubbleStyle] styles `MessageTranslationBubble`, the
  ///translation shown under a translated text message. Filled per message
  ///from the Incoming/Outgoing message bubble style by alignment; set it to
  ///override.
  CometChatMessageTranslationBubbleStyle? messageTranslationBubbleStyle;

  ///[textFormatters] is a list of [CometChatTextFormatter] that can be used to format text
  final List<CometChatTextFormatter>? textFormatters;

  ///[textBubbleStyle] is a [CometChatTextBubbleStyle] that can be used to style text bubble
  final CometChatTextBubbleStyle? textBubbleStyle;

  ///[imageBubbleStyle] is a [CometChatImageBubbleStyle] that can be used to style image bubble
  final CometChatImageBubbleStyle? imageBubbleStyle;

  ///[videoBubbleStyle] is a [CometChatVideoBubbleStyle] that can be used to style video bubble
  final CometChatVideoBubbleStyle? videoBubbleStyle;

  ///[audioBubbleStyle] is a [CometChatVoiceNoteBubbleStyle] that can be used to style audio bubble
  @Deprecated('Use voiceNoteBubbleStyle instead.')
  final CometChatVoiceNoteBubbleStyle? audioBubbleStyle;

  ///[voiceNoteBubbleStyle] styles [CometChatVoiceNoteBubble] — voice notes on
  ///either value of `enableMultipleAttachments`, and audio files when it is
  ///false. Takes precedence over the deprecated [audioBubbleStyle].
  final CometChatVoiceNoteBubbleStyle? voiceNoteBubbleStyle;

  /// The style to apply, preferring [voiceNoteBubbleStyle] and falling back to
  /// the deprecated [audioBubbleStyle] so existing integrations keep working.
  CometChatVoiceNoteBubbleStyle? get effectiveVoiceNoteBubbleStyle =>
      // ignore: deprecated_member_use_from_same_package
      voiceNoteBubbleStyle ?? audioBubbleStyle;

  ///[fileBubbleStyle] is a [CometChatFileBubbleStyle] that can be used to style file bubble
  final CometChatFileBubbleStyle? fileBubbleStyle;

  ///[attachmentOptionSheetStyle] is a [CometChatAttachmentOptionSheetStyle] that can be used to style attachment option sheet
  final CometChatAttachmentOptionSheetStyle? attachmentOptionSheetStyle;

  ///[messageOptionSheetStyle] is a [CometChatMessageOptionSheetStyle] that can be used to style message option sheet
  final CometChatMessageOptionSheetStyle? messageOptionSheetStyle;

  ///[actionBubbleStyle] is a [CometChatActionBubbleStyle] that can be used to style action bubble
  final CometChatActionBubbleStyle? actionBubbleStyle;

  ///[deletedBubbleStyle] is a [CometChatDeletedBubbleStyle] that can be used to style deleted bubble
  final CometChatDeletedBubbleStyle? deletedBubbleStyle;

  ///[linkPreviewBubbleStyle] styles `CometChatLinkPreviewBubble`. Filled per
  ///message from the Incoming/Outgoing message bubble style by alignment; set
  ///it to override.
  CometChatLinkPreviewBubbleStyle? linkPreviewBubbleStyle;

  ///[voiceCallBubbleStyle] is a [CometChatCallBubbleStyle] that can be used to style voice call bubble
  final CometChatCallBubbleStyle? voiceCallBubbleStyle;

  ///[videoCallBubbleStyle] is a [CometChatCallBubbleStyle] that can be used to style video call bubble
  final CometChatCallBubbleStyle? videoCallBubbleStyle;

  ///[hideImageAttachmentOption] is a [bool] that can be used to hide/display image attachment option
  final bool? hideImageAttachmentOption;

  ///[hideVideoAttachmentOption] is a [bool] that can be used to hide/display video attachment option
  final bool? hideVideoAttachmentOption;

  ///[hideAudioAttachmentOption] is a [bool] that can be used to hide/display audio attachment option
  final bool? hideAudioAttachmentOption;

  ///[hideFileAttachmentOption] is a [bool] that can be used to hide/display file attachment option
  final bool? hideFileAttachmentOption;

  ///[hidePollsOption] is a [bool] that can be used to hide/display poll option
  final bool? hidePollsOption;

  ///[hideCollaborativeDocumentOption] is a [bool] that can be used to hide/display collaborative document option
  final bool? hideCollaborativeDocumentOption;

  ///[hideCollaborativeWhiteboardOption] is a [bool] that can be used to hide/display collaborative whiteboard option
  final bool? hideCollaborativeWhiteboardOption;

  ///[hideTakPhotoOption] is a [bool] that can be used to hide/display take photo option
  final bool? hideTakPhotoOption;

  ///[hideReplyInThreadOption] This prop defines whether Reply In Thread option should be visible or not.
  final bool? hideReplyInThreadOption;

  ///[hideThreadSubscriptionOption] This prop defines whether the Follow/Unfollow
  ///thread option should be visible or not. Only takes effect when the
  ///thread-subscription feature gate ([UIKitSettings.enableThreadSubscription])
  ///is enabled; with the gate off the option never renders.
  final bool? hideThreadSubscriptionOption;

  ///[hidePinMessageOption] This prop defines whether the Pin message option
  ///should be visible or not (renders only while the message is unpinned and
  ///the server Pin feature flag is enabled).
  final bool? hidePinMessageOption;

  ///[hideUnpinMessageOption] This prop defines whether the Unpin message
  ///option should be visible or not (renders only while the message is
  ///pinned).
  final bool? hideUnpinMessageOption;

  ///[hideSaveMessageOption] This prop defines whether the Save message option
  ///should be visible or not (renders only while the message is unsaved and
  ///the server Save feature flag is enabled).
  final bool? hideSaveMessageOption;

  ///[hideUnsaveMessageOption] This prop defines whether the Unsave message
  ///option should be visible or not (renders only while the message is
  ///saved).
  final bool? hideUnsaveMessageOption;

  ///[hideReplyOption] This prop defines whether the inline Reply option should be visible or not.
  final bool? hideReplyOption;

  ///[hideEditMessageOption] This prop defines whether Edit Message option should be visible or not.
  final bool? hideEditMessageOption;

  ///[hideDeleteMessageOption] This prop defines whether Delete Message option should be visible or not.
  final bool? hideDeleteMessageOption;

  ///[hideTranslateMessageOption] hides the Translate option on text
  ///messages. The option shows only while the `message-translation`
  ///extension is enabled for the app; tapping it shows the message
  ///translated into the app language under the original.
  final bool? hideTranslateMessageOption;

  ///[hideMessagePrivatelyOption] This prop defines whether a user can privately message other member of the group or not.
  final bool? hideMessagePrivatelyOption;

  ///[hideCopyMessageOption] This prop defines whether a user can copy message or not.
  final bool? hideCopyMessageOption;

  ///[hideMessageInfoOption] This prop defines whether a user can fetch information about the message whether it's received or not.
  final bool? hideMessageInfoOption;

  ///[hideShareMessageOption] This prop defines whether share option should be visible or not.
  final bool? hideShareMessageOption;

  ///[showMarkAsUnreadOption] This prop defines whether Mark as Unread option should be visible or not.
  final bool? showMarkAsUnreadOption;

  ///[hideFlagOption] This prop defines whether the Flag/Report option should be visible or not.
  final bool? hideFlagOption;
}
