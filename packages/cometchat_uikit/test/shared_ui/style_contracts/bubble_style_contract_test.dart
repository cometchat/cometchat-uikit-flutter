/// Table-driven `copyWith` / `merge` / `lerp` contract for the message-bubble style classes.
///
/// These classes are pure data bags, so the bugs they carry are mechanical: a
/// `copyWith` that forgets a field, a `merge` that drops one (an integrator's
/// explicit value silently ignored), a `lerp` that interpolates the wrong
/// field into a slot. `test/helpers/style_contract.dart` pins each of those —
/// see the doc there for the exact list of checks. The render-verified prop
/// matrices under `test/chat_ui` and `test/shared_ui/*_props_test.dart` cover
/// the other half — that a set property reaches the pixels — and are not
/// repeated here.
///
///   flutter test test/shared_ui/style_contracts/bubble_style_contract_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/style_contract.dart';

void main() {
  group('bubble style contracts', () {
    test(
      'CometChatMediaGridStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatMediaGridStyle>(
          label: 'CometChatMediaGridStyle',
          empty: const CometChatMediaGridStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatMediaGridStyle, double>(
              'cellBorderRadius',
              4.5,
              5.5,
              (s, v) => s.copyWith(cellBorderRadius: v),
              (s) => s.cellBorderRadius,
            ),
            Fld<CometChatMediaGridStyle, Color>(
              'placeholderColor',
              const Color(0xFF2F201A),
              const Color(0xFF39251D),
              (s, v) => s.copyWith(placeholderColor: v),
              (s) => s.placeholderColor,
            ),
            Fld<CometChatMediaGridStyle, Color>(
              'playBadgeBackgroundColor',
              const Color(0xFF432A20),
              const Color(0xFF4D2F23),
              (s, v) => s.copyWith(playBadgeBackgroundColor: v),
              (s) => s.playBadgeBackgroundColor,
            ),
            Fld<CometChatMediaGridStyle, Color>(
              'playBadgeIconColor',
              const Color(0xFF573426),
              const Color(0xFF613929),
              (s, v) => s.copyWith(playBadgeIconColor: v),
              (s) => s.playBadgeIconColor,
            ),
            Fld<CometChatMediaGridStyle, Color>(
              'durationChipBackgroundColor',
              const Color(0xFF6B3E2C),
              const Color(0xFF75432F),
              (s, v) => s.copyWith(durationChipBackgroundColor: v),
              (s) => s.durationChipBackgroundColor,
            ),
            Fld<CometChatMediaGridStyle, TextStyle>(
              'durationChipTextStyle',
              const TextStyle(fontSize: 14.5),
              const TextStyle(fontSize: 15.5),
              (s, v) => s.copyWith(durationChipTextStyle: v),
              (s) => s.durationChipTextStyle,
            ),
            Fld<CometChatMediaGridStyle, TextStyle>(
              'nameTextStyle',
              const TextStyle(fontSize: 16.5),
              const TextStyle(fontSize: 17.5),
              (s, v) => s.copyWith(nameTextStyle: v),
              (s) => s.nameTextStyle,
            ),
            Fld<CometChatMediaGridStyle, TextStyle>(
              'overflowTextStyle',
              const TextStyle(fontSize: 18.5),
              const TextStyle(fontSize: 19.5),
              (s, v) => s.copyWith(overflowTextStyle: v),
              (s) => s.overflowTextStyle,
            ),
            Fld<CometChatMediaGridStyle, Color>(
              'overflowScrimColor',
              const Color(0xFFBB6644),
              const Color(0xFFC56B47),
              (s, v) => s.copyWith(overflowScrimColor: v),
              (s) => s.overflowScrimColor,
            ),
            Fld<CometChatMediaGridStyle, bool>(
              'showVideoDuration',
              true,
              false,
              (s, v) => s.copyWith(showVideoDuration: v),
              (s) => s.showVideoDuration,
            ),
            Fld<CometChatMediaGridStyle, MediaGridTripleLayout>(
              'tripleLayout',
              MediaGridTripleLayout.auto,
              MediaGridTripleLayout.heroTop,
              (s, v) => s.copyWith(tripleLayout: v),
              (s) => s.tripleLayout,
            ),
            Fld<CometChatMediaGridStyle, double>(
              'heroFraction',
              22.5,
              23.5,
              (s, v) => s.copyWith(heroFraction: v),
              (s) => s.heroFraction,
            ),
          ],
        );
      },
    );

    test(
      'CometChatPollsBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatPollsBubbleStyle>(
          label: 'CometChatPollsBubbleStyle',
          empty: const CometChatPollsBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatPollsBubbleStyle, TextStyle>(
              'questionTextStyle',
              const TextStyle(fontSize: 24.5),
              const TextStyle(fontSize: 25.5),
              (s, v) => s.copyWith(questionTextStyle: v),
              (s) => s.questionTextStyle,
            ),
            Fld<CometChatPollsBubbleStyle, TextStyle>(
              'voteCountTextStyle',
              const TextStyle(fontSize: 26.5),
              const TextStyle(fontSize: 27.5),
              (s, v) => s.copyWith(voteCountTextStyle: v),
              (s) => s.voteCountTextStyle,
            ),
            Fld<CometChatPollsBubbleStyle, TextStyle>(
              'pollOptionsTextStyle',
              const TextStyle(fontSize: 28.5),
              const TextStyle(fontSize: 29.5),
              (s, v) => s.copyWith(pollOptionsTextStyle: v),
              (s) => s.pollOptionsTextStyle,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'radioButtonColor',
              const Color(0xFF1F9862),
              const Color(0xFF299D65),
              (s, v) => s.copyWith(radioButtonColor: v),
              (s) => s.radioButtonColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'pollOptionsBackgroundColor',
              const Color(0xFF33A268),
              const Color(0xFF3DA76B),
              (s, v) => s.copyWith(pollOptionsBackgroundColor: v),
              (s) => s.pollOptionsBackgroundColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'selectedOptionColor',
              const Color(0xFF47AC6E),
              const Color(0xFF51B171),
              (s, v) => s.copyWith(selectedOptionColor: v),
              (s) => s.selectedOptionColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'unSelectedOptionColor',
              const Color(0xFF5BB674),
              const Color(0xFF65BB77),
              (s, v) => s.copyWith(unSelectedOptionColor: v),
              (s) => s.unSelectedOptionColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF6FC07A),
              const Color(0xFF79C57D),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'iconColor',
              const Color(0xFF83CA80),
              const Color(0xFF8DCF83),
              (s, v) => s.copyWith(iconColor: v),
              (s) => s.iconColor,
            ),
            Fld<CometChatPollsBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 42.5),
              Border.all(width: 43.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatPollsBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(44.5),
              BorderRadius.circular(45.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'progressColor',
              const Color(0xFFBFE892),
              const Color(0xFFC9ED95),
              (s, v) => s.copyWith(progressColor: v),
              (s) => s.progressColor,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'progressBackgroundColor',
              const Color(0xFFD3F298),
              const Color(0xFFDDF79B),
              (s, v) => s.copyWith(progressBackgroundColor: v),
              (s) => s.progressBackgroundColor,
            ),
            Fld<CometChatPollsBubbleStyle, CometChatAvatarStyle>(
              'voterAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(voterAvatarStyle: v),
              (s) => s.voterAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatPollsBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatPollsBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatPollsBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a53')),
              const DecorationImage(image: AssetImage('a54')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatPollsBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 58.5),
              const TextStyle(fontSize: 59.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatPollsBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF4C2EBC),
              const Color(0xFF5633BF),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatPollsBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 62.5),
              const TextStyle(fontSize: 63.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatPollsBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatOutgoingMessageBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatOutgoingMessageBubbleStyle>(
          label: 'CometChatOutgoingMessageBubbleStyle',
          empty: const CometChatOutgoingMessageBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          fields: [
            Fld<CometChatOutgoingMessageBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a63')),
              const DecorationImage(image: AssetImage('a64')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF9C56D4),
              const Color(0xFFA65BD7),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 70.5),
              Border.all(width: 71.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(72.5),
              BorderRadius.circular(73.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 74.5),
              const TextStyle(fontSize: 75.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFFEC7EEC),
              const Color(0xFFF683EF),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatMessageReceiptStyle
            >(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatReactionsStyle>(
              'messageBubbleReactionStyle',
              CometChatReactionsStyle(),
              CometChatReactionsStyle(),
              (s, v) => s.copyWith(messageBubbleReactionStyle: v),
              (s) => s.messageBubbleReactionStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatTextBubbleStyle>(
              'textBubbleStyle',
              CometChatTextBubbleStyle(),
              CometChatTextBubbleStyle(),
              (s, v) => s.copyWith(textBubbleStyle: v),
              (s) => s.textBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatImageBubbleStyle>(
              'imageBubbleStyle',
              CometChatImageBubbleStyle(),
              CometChatImageBubbleStyle(),
              (s, v) => s.copyWith(imageBubbleStyle: v),
              (s) => s.imageBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatVideoBubbleStyle>(
              'videoBubbleStyle',
              CometChatVideoBubbleStyle(),
              CometChatVideoBubbleStyle(),
              (s, v) => s.copyWith(videoBubbleStyle: v),
              (s) => s.videoBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatVoiceNoteBubbleStyle
            >(
              'audioBubbleStyle',
              CometChatVoiceNoteBubbleStyle(),
              CometChatVoiceNoteBubbleStyle(),
              (s, v) => s.copyWith(audioBubbleStyle: v),
              (s) => s.audioBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatVoiceNoteBubbleStyle
            >(
              'voiceNoteBubbleStyle',
              CometChatVoiceNoteBubbleStyle(),
              CometChatVoiceNoteBubbleStyle(),
              (s, v) => s.copyWith(voiceNoteBubbleStyle: v),
              (s) => s.voiceNoteBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatFileBubbleStyle>(
              'fileBubbleStyle',
              CometChatFileBubbleStyle(),
              CometChatFileBubbleStyle(),
              (s, v) => s.copyWith(fileBubbleStyle: v),
              (s) => s.fileBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatCollaborativeBubbleStyle
            >(
              'collaborativeDocumentBubbleStyle',
              CometChatCollaborativeBubbleStyle(),
              CometChatCollaborativeBubbleStyle(),
              (s, v) => s.copyWith(collaborativeDocumentBubbleStyle: v),
              (s) => s.collaborativeDocumentBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatCollaborativeBubbleStyle
            >(
              'collaborativeWhiteboardBubbleStyle',
              CometChatCollaborativeBubbleStyle(),
              CometChatCollaborativeBubbleStyle(),
              (s, v) => s.copyWith(collaborativeWhiteboardBubbleStyle: v),
              (s) => s.collaborativeWhiteboardBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatLinkPreviewBubbleStyle
            >(
              'linkPreviewBubbleStyle',
              CometChatLinkPreviewBubbleStyle(),
              CometChatLinkPreviewBubbleStyle(),
              (s, v) => s.copyWith(linkPreviewBubbleStyle: v),
              (s) => s.linkPreviewBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatPollsBubbleStyle>(
              'pollsBubbleStyle',
              CometChatPollsBubbleStyle(),
              CometChatPollsBubbleStyle(),
              (s, v) => s.copyWith(pollsBubbleStyle: v),
              (s) => s.pollsBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatDeletedBubbleStyle
            >(
              'deletedBubbleStyle',
              CometChatDeletedBubbleStyle(),
              CometChatDeletedBubbleStyle(),
              (s, v) => s.copyWith(deletedBubbleStyle: v),
              (s) => s.deletedBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatMessageTranslationBubbleStyle
            >(
              'messageTranslationBubbleStyle',
              CometChatMessageTranslationBubbleStyle(),
              CometChatMessageTranslationBubbleStyle(),
              (s, v) => s.copyWith(messageTranslationBubbleStyle: v),
              (s) => s.messageTranslationBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatOutgoingMessageBubbleStyle,
              CometChatStickerBubbleStyle
            >(
              'stickerBubbleStyle',
              CometChatStickerBubbleStyle(),
              CometChatStickerBubbleStyle(),
              (s, v) => s.copyWith(stickerBubbleStyle: v),
              (s) => s.stickerBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatCallBubbleStyle>(
              'voiceCallBubbleStyle',
              CometChatCallBubbleStyle(),
              CometChatCallBubbleStyle(),
              (s, v) => s.copyWith(voiceCallBubbleStyle: v),
              (s) => s.voiceCallBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatCallBubbleStyle>(
              'videoCallBubbleStyle',
              CometChatCallBubbleStyle(),
              CometChatCallBubbleStyle(),
              (s, v) => s.copyWith(videoCallBubbleStyle: v),
              (s) => s.videoCallBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatOutgoingMessageBubbleStyle, CometChatModerationStyle>(
              'moderationStyle',
              CometChatModerationStyle(),
              CometChatModerationStyle(),
              (s, v) => s.copyWith(moderationStyle: v),
              (s) => s.moderationStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatIncomingMessageBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatIncomingMessageBubbleStyle>(
          label: 'CometChatIncomingMessageBubbleStyle',
          empty: const CometChatIncomingMessageBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          fields: [
            Fld<CometChatIncomingMessageBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a115')),
              const DecorationImage(image: AssetImage('a116')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFA55B70),
              const Color(0xFFAF6073),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 122.5),
              Border.all(width: 123.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(124.5),
              BorderRadius.circular(125.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 126.5),
              const TextStyle(fontSize: 127.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFFF58388),
              const Color(0xFFFF888B),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatReactionsStyle>(
              'messageBubbleReactionStyle',
              CometChatReactionsStyle(),
              CometChatReactionsStyle(),
              (s, v) => s.copyWith(messageBubbleReactionStyle: v),
              (s) => s.messageBubbleReactionStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatTextBubbleStyle>(
              'textBubbleStyle',
              CometChatTextBubbleStyle(),
              CometChatTextBubbleStyle(),
              (s, v) => s.copyWith(textBubbleStyle: v),
              (s) => s.textBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatImageBubbleStyle>(
              'imageBubbleStyle',
              CometChatImageBubbleStyle(),
              CometChatImageBubbleStyle(),
              (s, v) => s.copyWith(imageBubbleStyle: v),
              (s) => s.imageBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatVideoBubbleStyle>(
              'videoBubbleStyle',
              CometChatVideoBubbleStyle(),
              CometChatVideoBubbleStyle(),
              (s, v) => s.copyWith(videoBubbleStyle: v),
              (s) => s.videoBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatVoiceNoteBubbleStyle
            >(
              'audioBubbleStyle',
              CometChatVoiceNoteBubbleStyle(),
              CometChatVoiceNoteBubbleStyle(),
              (s, v) => s.copyWith(audioBubbleStyle: v),
              (s) => s.audioBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatVoiceNoteBubbleStyle
            >(
              'voiceNoteBubbleStyle',
              CometChatVoiceNoteBubbleStyle(),
              CometChatVoiceNoteBubbleStyle(),
              (s, v) => s.copyWith(voiceNoteBubbleStyle: v),
              (s) => s.voiceNoteBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatFileBubbleStyle>(
              'fileBubbleStyle',
              CometChatFileBubbleStyle(),
              CometChatFileBubbleStyle(),
              (s, v) => s.copyWith(fileBubbleStyle: v),
              (s) => s.fileBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatCollaborativeBubbleStyle
            >(
              'collaborativeDocumentBubbleStyle',
              CometChatCollaborativeBubbleStyle(),
              CometChatCollaborativeBubbleStyle(),
              (s, v) => s.copyWith(collaborativeDocumentBubbleStyle: v),
              (s) => s.collaborativeDocumentBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatCollaborativeBubbleStyle
            >(
              'collaborativeWhiteboardBubbleStyle',
              CometChatCollaborativeBubbleStyle(),
              CometChatCollaborativeBubbleStyle(),
              (s, v) => s.copyWith(collaborativeWhiteboardBubbleStyle: v),
              (s) => s.collaborativeWhiteboardBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatPollsBubbleStyle>(
              'pollsBubbleStyle',
              CometChatPollsBubbleStyle(),
              CometChatPollsBubbleStyle(),
              (s, v) => s.copyWith(pollsBubbleStyle: v),
              (s) => s.pollsBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatDeletedBubbleStyle
            >(
              'deletedBubbleStyle',
              CometChatDeletedBubbleStyle(),
              CometChatDeletedBubbleStyle(),
              (s, v) => s.copyWith(deletedBubbleStyle: v),
              (s) => s.deletedBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatLinkPreviewBubbleStyle
            >(
              'linkPreviewBubbleStyle',
              CometChatLinkPreviewBubbleStyle(),
              CometChatLinkPreviewBubbleStyle(),
              (s, v) => s.copyWith(linkPreviewBubbleStyle: v),
              (s) => s.linkPreviewBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatMessageTranslationBubbleStyle
            >(
              'messageTranslationBubbleStyle',
              CometChatMessageTranslationBubbleStyle(),
              CometChatMessageTranslationBubbleStyle(),
              (s, v) => s.copyWith(messageTranslationBubbleStyle: v),
              (s) => s.messageTranslationBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<
              CometChatIncomingMessageBubbleStyle,
              CometChatStickerBubbleStyle
            >(
              'stickerBubbleStyle',
              CometChatStickerBubbleStyle(),
              CometChatStickerBubbleStyle(),
              (s, v) => s.copyWith(stickerBubbleStyle: v),
              (s) => s.stickerBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 162.5),
              const TextStyle(fontSize: 163.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatCallBubbleStyle>(
              'voiceCallBubbleStyle',
              CometChatCallBubbleStyle(),
              CometChatCallBubbleStyle(),
              (s, v) => s.copyWith(voiceCallBubbleStyle: v),
              (s) => s.voiceCallBubbleStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatIncomingMessageBubbleStyle, CometChatCallBubbleStyle>(
              'videoCallBubbleStyle',
              CometChatCallBubbleStyle(),
              CometChatCallBubbleStyle(),
              (s, v) => s.copyWith(videoCallBubbleStyle: v),
              (s) => s.videoCallBubbleStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatCallBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatCallBubbleStyle>(
          label: 'CometChatCallBubbleStyle',
          empty: const CometChatCallBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatCallBubbleStyle, TextStyle>(
              'titleStyle',
              const TextStyle(fontSize: 168.5),
              const TextStyle(fontSize: 169.5),
              (s, v) => s.copyWith(titleStyle: v),
              (s) => s.titleStyle,
            ),
            Fld<CometChatCallBubbleStyle, TextStyle>(
              'subtitleStyle',
              const TextStyle(fontSize: 170.5),
              const TextStyle(fontSize: 171.5),
              (s, v) => s.copyWith(subtitleStyle: v),
              (s) => s.subtitleStyle,
            ),
            Fld<CometChatCallBubbleStyle, TextStyle>(
              'buttonTextStyle',
              const TextStyle(fontSize: 172.5),
              const TextStyle(fontSize: 173.5),
              (s, v) => s.copyWith(buttonTextStyle: v),
              (s) => s.buttonTextStyle,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'buttonBackgroundColor',
              const Color(0xFFC26A12),
              const Color(0xFFCC6F15),
              (s, v) => s.copyWith(buttonBackgroundColor: v),
              (s) => s.buttonBackgroundColor,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'iconColor',
              const Color(0xFFD67418),
              const Color(0xFFE0791B),
              (s, v) => s.copyWith(iconColor: v),
              (s) => s.iconColor,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFEA7E1E),
              const Color(0xFFF48321),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatCallBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 180.5),
              Border.all(width: 181.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatCallBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(182.5),
              BorderRadius.circular(183.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'iconBackgroundColor',
              const Color(0xFF269C30),
              const Color(0xFF30A133),
              (s, v) => s.copyWith(iconBackgroundColor: v),
              (s) => s.iconBackgroundColor,
            ),
            Fld<CometChatCallBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatCallBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatCallBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a187')),
              const DecorationImage(image: AssetImage('a188')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatCallBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 192.5),
              const TextStyle(fontSize: 193.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF8ACE4E),
              const Color(0xFF94D351),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatCallBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 196.5),
              const TextStyle(fontSize: 197.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatCallBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatCallBubbleStyle, Color>(
              'dividerColor',
              const Color(0xFFC6EC60),
              const Color(0xFFD0F163),
              (s, v) => s.copyWith(dividerColor: v),
              (s) => s.dividerColor,
            ),
          ],
        );
      },
    );

    test(
      'CometChatAudiosBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatAudiosBubbleStyle>(
          label: 'CometChatAudiosBubbleStyle',
          empty: const CometChatAudiosBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatAudiosBubbleStyle, Color>(
              'rowBackgroundColor',
              const Color(0xFFDAF666),
              const Color(0xFFE4FB69),
              (s, v) => s.copyWith(rowBackgroundColor: v),
              (s) => s.rowBackgroundColor,
            ),
            Fld<CometChatAudiosBubbleStyle, double>(
              'rowBorderRadius',
              204.5,
              205.5,
              (s, v) => s.copyWith(rowBorderRadius: v),
              (s) => s.rowBorderRadius,
            ),
            Fld<CometChatAudiosBubbleStyle, double>(
              'rowSpacing',
              206.5,
              207.5,
              (s, v) => s.copyWith(rowSpacing: v),
              (s) => s.rowSpacing,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'playIconBackgroundColor',
              const Color(0xFF171478),
              const Color(0xFF21197B),
              (s, v) => s.copyWith(playIconBackgroundColor: v),
              (s) => s.playIconBackgroundColor,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'playIconColor',
              const Color(0xFF2B1E7E),
              const Color(0xFF352381),
              (s, v) => s.copyWith(playIconColor: v),
              (s) => s.playIconColor,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'sliderActiveColor',
              const Color(0xFF3F2884),
              const Color(0xFF492D87),
              (s, v) => s.copyWith(sliderActiveColor: v),
              (s) => s.sliderActiveColor,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'sliderInactiveColor',
              const Color(0xFF53328A),
              const Color(0xFF5D378D),
              (s, v) => s.copyWith(sliderInactiveColor: v),
              (s) => s.sliderInactiveColor,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'sliderThumbColor',
              const Color(0xFF673C90),
              const Color(0xFF714193),
              (s, v) => s.copyWith(sliderThumbColor: v),
              (s) => s.sliderThumbColor,
            ),
            Fld<CometChatAudiosBubbleStyle, TextStyle>(
              'nameTextStyle',
              const TextStyle(fontSize: 218.5),
              const TextStyle(fontSize: 219.5),
              (s, v) => s.copyWith(nameTextStyle: v),
              (s) => s.nameTextStyle,
            ),
            Fld<CometChatAudiosBubbleStyle, TextStyle>(
              'durationTextStyle',
              const TextStyle(fontSize: 220.5),
              const TextStyle(fontSize: 221.5),
              (s, v) => s.copyWith(durationTextStyle: v),
              (s) => s.durationTextStyle,
            ),
            Fld<CometChatAudiosBubbleStyle, Color>(
              'downloadIconColor',
              const Color(0xFFA35AA2),
              const Color(0xFFAD5FA5),
              (s, v) => s.copyWith(downloadIconColor: v),
              (s) => s.downloadIconColor,
            ),
            Fld<CometChatAudiosBubbleStyle, TextStyle>(
              'captionTextStyle',
              const TextStyle(fontSize: 224.5),
              const TextStyle(fontSize: 225.5),
              (s, v) => s.copyWith(captionTextStyle: v),
              (s) => s.captionTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatCollaborativeBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatCollaborativeBubbleStyle>(
          label: 'CometChatCollaborativeBubbleStyle',
          empty: const CometChatCollaborativeBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          lerpNullReturnsSelf: false,
          fields: [
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'titleStyle',
              const TextStyle(fontSize: 226.5),
              const TextStyle(fontSize: 227.5),
              (s, v) => s.copyWith(titleStyle: v),
              (s) => s.titleStyle,
            ),
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'subtitleStyle',
              const TextStyle(fontSize: 228.5),
              const TextStyle(fontSize: 229.5),
              (s, v) => s.copyWith(subtitleStyle: v),
              (s) => s.subtitleStyle,
            ),
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'buttonTextStyle',
              const TextStyle(fontSize: 230.5),
              const TextStyle(fontSize: 231.5),
              (s, v) => s.copyWith(buttonTextStyle: v),
              (s) => s.buttonTextStyle,
            ),
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'webViewTitleStyle',
              const TextStyle(fontSize: 232.5),
              const TextStyle(fontSize: 233.5),
              (s, v) => s.copyWith(webViewTitleStyle: v),
              (s) => s.webViewTitleStyle,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'webViewBackIconColor',
              const Color(0xFF1B96C6),
              const Color(0xFF259BC9),
              (s, v) => s.copyWith(webViewBackIconColor: v),
              (s) => s.webViewBackIconColor,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'webViewAppBarColor',
              const Color(0xFF2FA0CC),
              const Color(0xFF39A5CF),
              (s, v) => s.copyWith(webViewAppBarColor: v),
              (s) => s.webViewAppBarColor,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'iconTint',
              const Color(0xFF43AAD2),
              const Color(0xFF4DAFD5),
              (s, v) => s.copyWith(iconTint: v),
              (s) => s.iconTint,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF57B4D8),
              const Color(0xFF61B9DB),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'dividerColor',
              const Color(0xFF6BBEDE),
              const Color(0xFF75C3E1),
              (s, v) => s.copyWith(dividerColor: v),
              (s) => s.dividerColor,
            ),
            Fld<CometChatCollaborativeBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 244.5),
              Border.all(width: 245.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatCollaborativeBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(246.5),
              BorderRadius.circular(247.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatCollaborativeBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatCollaborativeBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatCollaborativeBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a249')),
              const DecorationImage(image: AssetImage('a250')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 254.5),
              const TextStyle(fontSize: 255.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatCollaborativeBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFFF80508),
              const Color(0xFF020A0B),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatCollaborativeBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 258.5),
              const TextStyle(fontSize: 259.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<
              CometChatCollaborativeBubbleStyle,
              CometChatMessageReceiptStyle
            >(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatVideosBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatVideosBubbleStyle>(
          label: 'CometChatVideosBubbleStyle',
          empty: const CometChatVideosBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatVideosBubbleStyle, double>(
              'tileBorderRadius',
              262.5,
              263.5,
              (s, v) => s.copyWith(tileBorderRadius: v),
              (s) => s.tileBorderRadius,
            ),
            Fld<CometChatVideosBubbleStyle, double>(
              'gridSpacing',
              264.5,
              265.5,
              (s, v) => s.copyWith(gridSpacing: v),
              (s) => s.gridSpacing,
            ),
            Fld<CometChatVideosBubbleStyle, Color>(
              'placeholderColor',
              const Color(0xFF5C3726),
              const Color(0xFF663C29),
              (s, v) => s.copyWith(placeholderColor: v),
              (s) => s.placeholderColor,
            ),
            Fld<CometChatVideosBubbleStyle, Color>(
              'playIconBackgroundColor',
              const Color(0xFF70412C),
              const Color(0xFF7A462F),
              (s, v) => s.copyWith(playIconBackgroundColor: v),
              (s) => s.playIconBackgroundColor,
            ),
            Fld<CometChatVideosBubbleStyle, Color>(
              'playIconColor',
              const Color(0xFF844B32),
              const Color(0xFF8E5035),
              (s, v) => s.copyWith(playIconColor: v),
              (s) => s.playIconColor,
            ),
            Fld<CometChatVideosBubbleStyle, TextStyle>(
              'nameTextStyle',
              const TextStyle(fontSize: 272.5),
              const TextStyle(fontSize: 273.5),
              (s, v) => s.copyWith(nameTextStyle: v),
              (s) => s.nameTextStyle,
            ),
            Fld<CometChatVideosBubbleStyle, Color>(
              'durationChipBackgroundColor',
              const Color(0xFFAC5F3E),
              const Color(0xFFB66441),
              (s, v) => s.copyWith(durationChipBackgroundColor: v),
              (s) => s.durationChipBackgroundColor,
            ),
            Fld<CometChatVideosBubbleStyle, TextStyle>(
              'durationChipTextStyle',
              const TextStyle(fontSize: 276.5),
              const TextStyle(fontSize: 277.5),
              (s, v) => s.copyWith(durationChipTextStyle: v),
              (s) => s.durationChipTextStyle,
            ),
            Fld<CometChatVideosBubbleStyle, bool>(
              'showVideoDuration',
              true,
              false,
              (s, v) => s.copyWith(showVideoDuration: v),
              (s) => s.showVideoDuration,
            ),
            Fld<CometChatVideosBubbleStyle, Color>(
              'overflowScrimColor',
              const Color(0xFFD4734A),
              const Color(0xFFDE784D),
              (s, v) => s.copyWith(overflowScrimColor: v),
              (s) => s.overflowScrimColor,
            ),
            Fld<CometChatVideosBubbleStyle, TextStyle>(
              'overflowTextStyle',
              const TextStyle(fontSize: 280.5),
              const TextStyle(fontSize: 281.5),
              (s, v) => s.copyWith(overflowTextStyle: v),
              (s) => s.overflowTextStyle,
            ),
            Fld<CometChatVideosBubbleStyle, TextStyle>(
              'captionTextStyle',
              const TextStyle(fontSize: 282.5),
              const TextStyle(fontSize: 283.5),
              (s, v) => s.copyWith(captionTextStyle: v),
              (s) => s.captionTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatVoiceNoteBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatVoiceNoteBubbleStyle>(
          label: 'CometChatVoiceNoteBubbleStyle',
          empty: const CometChatVoiceNoteBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'playIconColor',
              const Color(0xFF10915C),
              const Color(0xFF1A965F),
              (s, v) => s.copyWith(playIconColor: v),
              (s) => s.playIconColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF249B62),
              const Color(0xFF2EA065),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 288.5),
              Border.all(width: 289.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(290.5),
              BorderRadius.circular(291.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'playIconBackgroundColor',
              const Color(0xFF60B974),
              const Color(0xFF6ABE77),
              (s, v) => s.copyWith(playIconBackgroundColor: v),
              (s) => s.playIconBackgroundColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'downloadIconColor',
              const Color(0xFF74C37A),
              const Color(0xFF7EC87D),
              (s, v) => s.copyWith(downloadIconColor: v),
              (s) => s.downloadIconColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'audioBarColor',
              const Color(0xFF88CD80),
              const Color(0xFF92D283),
              (s, v) => s.copyWith(audioBarColor: v),
              (s) => s.audioBarColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a299')),
              const DecorationImage(image: AssetImage('a300')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 304.5),
              const TextStyle(fontSize: 305.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFFECFF9E),
              const Color(0xFFF704A1),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 308.5),
              const TextStyle(fontSize: 309.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, Color>(
              'durationTextColor',
              const Color(0xFF291DB0),
              const Color(0xFF3322B3),
              (s, v) => s.copyWith(durationTextColor: v),
              (s) => s.durationTextColor,
            ),
            Fld<CometChatVoiceNoteBubbleStyle, TextStyle>(
              'durationTextStyle',
              const TextStyle(fontSize: 314.5),
              const TextStyle(fontSize: 315.5),
              (s, v) => s.copyWith(durationTextStyle: v),
              (s) => s.durationTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatFileBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatFileBubbleStyle>(
          label: 'CometChatFileBubbleStyle',
          empty: const CometChatFileBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatFileBubbleStyle, TextStyle>(
              'titleTextStyle',
              const TextStyle(fontSize: 316.5),
              const TextStyle(fontSize: 317.5),
              (s, v) => s.copyWith(titleTextStyle: v),
              (s) => s.titleTextStyle,
            ),
            Fld<CometChatFileBubbleStyle, TextStyle>(
              'subtitleTextStyle',
              const TextStyle(fontSize: 318.5),
              const TextStyle(fontSize: 319.5),
              (s, v) => s.copyWith(subtitleTextStyle: v),
              (s) => s.subtitleTextStyle,
            ),
            Fld<CometChatFileBubbleStyle, Color>(
              'downloadIconTint',
              const Color(0xFF7945C8),
              const Color(0xFF834ACB),
              (s, v) => s.copyWith(downloadIconTint: v),
              (s) => s.downloadIconTint,
            ),
            Fld<CometChatFileBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF8D4FCE),
              const Color(0xFF9754D1),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatFileBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 324.5),
              Border.all(width: 325.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatFileBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(326.5),
              BorderRadius.circular(327.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatFileBubbleStyle, Color>(
              'titleColor',
              const Color(0xFFC96DE0),
              const Color(0xFFD372E3),
              (s, v) => s.copyWith(titleColor: v),
              (s) => s.titleColor,
            ),
            Fld<CometChatFileBubbleStyle, Color>(
              'subtitleColor',
              const Color(0xFFDD77E6),
              const Color(0xFFE77CE9),
              (s, v) => s.copyWith(subtitleColor: v),
              (s) => s.subtitleColor,
            ),
            Fld<CometChatFileBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatFileBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatFileBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a333')),
              const DecorationImage(image: AssetImage('a334')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatFileBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 338.5),
              const TextStyle(fontSize: 339.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatFileBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF41AA04),
              const Color(0xFF4BAF07),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatFileBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 342.5),
              const TextStyle(fontSize: 343.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatFileBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatVideoBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatVideoBubbleStyle>(
          label: 'CometChatVideoBubbleStyle',
          empty: const CometChatVideoBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatVideoBubbleStyle, Color>(
              'playIconColor',
              const Color(0xFF7DC816),
              const Color(0xFF87CD19),
              (s, v) => s.copyWith(playIconColor: v),
              (s) => s.playIconColor,
            ),
            Fld<CometChatVideoBubbleStyle, Color>(
              'playIconBackgroundColor',
              const Color(0xFF91D21C),
              const Color(0xFF9BD71F),
              (s, v) => s.copyWith(playIconBackgroundColor: v),
              (s) => s.playIconBackgroundColor,
            ),
            Fld<CometChatVideoBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFA5DC22),
              const Color(0xFFAFE125),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatVideoBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 352.5),
              Border.all(width: 353.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatVideoBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(354.5),
              BorderRadius.circular(355.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatVideoBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatVideoBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatVideoBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a357')),
              const DecorationImage(image: AssetImage('a358')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatVideoBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 362.5),
              const TextStyle(fontSize: 363.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatVideoBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF32224C),
              const Color(0xFF3C274F),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatVideoBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 366.5),
              const TextStyle(fontSize: 367.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatVideoBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatDeletedBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatDeletedBubbleStyle>(
          label: 'CometChatDeletedBubbleStyle',
          empty: const CometChatDeletedBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatDeletedBubbleStyle, TextStyle>(
              'textStyle',
              const TextStyle(fontSize: 370.5),
              const TextStyle(fontSize: 371.5),
              (s, v) => s.copyWith(textStyle: v),
              (s) => s.textStyle,
            ),
            Fld<CometChatDeletedBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF824A64),
              const Color(0xFF8C4F67),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatDeletedBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 374.5),
              Border.all(width: 375.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatDeletedBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(376.5),
              BorderRadius.circular(377.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatDeletedBubbleStyle, Color>(
              'iconColor',
              const Color(0xFFBE6876),
              const Color(0xFFC86D79),
              (s, v) => s.copyWith(iconColor: v),
              (s) => s.iconColor,
            ),
            Fld<CometChatDeletedBubbleStyle, Color>(
              'textColor',
              const Color(0xFFD2727C),
              const Color(0xFFDC777F),
              (s, v) => s.copyWith(textColor: v),
              (s) => s.textColor,
            ),
            Fld<CometChatDeletedBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatDeletedBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatDeletedBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a383')),
              const DecorationImage(image: AssetImage('a384')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatDeletedBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 388.5),
              const TextStyle(fontSize: 389.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatDeletedBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF36A49A),
              const Color(0xFF40A99D),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatDeletedBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 392.5),
              const TextStyle(fontSize: 393.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatDeletedBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatTextBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatTextBubbleStyle>(
          label: 'CometChatTextBubbleStyle',
          empty: const CometChatTextBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          lerpNullReturnsSelf: false,
          fields: [
            Fld<CometChatTextBubbleStyle, TextStyle>(
              'textStyle',
              const TextStyle(fontSize: 396.5),
              const TextStyle(fontSize: 397.5),
              (s, v) => s.copyWith(textStyle: v),
              (s) => s.textStyle,
            ),
            Fld<CometChatTextBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 398.5),
              Border.all(width: 399.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatTextBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(400.5),
              BorderRadius.circular(401.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatTextBubbleStyle, Color>(
              'textColor',
              const Color(0xFFAEE0BE),
              const Color(0xFFB8E5C1),
              (s, v) => s.copyWith(textColor: v),
              (s) => s.textColor,
            ),
            Fld<CometChatTextBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFC2EAC4),
              const Color(0xFFCCEFC7),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatTextBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatTextBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatTextBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a407')),
              const DecorationImage(image: AssetImage('a408')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatTextBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 412.5),
              const TextStyle(fontSize: 413.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatTextBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF271CE2),
              const Color(0xFF3121E5),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatTextBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 416.5),
              const TextStyle(fontSize: 417.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatTextBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatCallButtonsStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatCallButtonsStyle>(
          label: 'CometChatCallButtonsStyle',
          empty: const CometChatCallButtonsStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatCallButtonsStyle, Color>(
              'voiceCallIconColor',
              const Color(0xFF633AF4),
              const Color(0xFF6D3FF7),
              (s, v) => s.copyWith(voiceCallIconColor: v),
              (s) => s.voiceCallIconColor,
            ),
            Fld<CometChatCallButtonsStyle, Color>(
              'videoCallIconColor',
              const Color(0xFF7744FA),
              const Color(0xFF8149FD),
              (s, v) => s.copyWith(videoCallIconColor: v),
              (s) => s.videoCallIconColor,
            ),
            Fld<CometChatCallButtonsStyle, Color>(
              'voiceCallButtonColor',
              const Color(0xFF8B4F00),
              const Color(0xFF955403),
              (s, v) => s.copyWith(voiceCallButtonColor: v),
              (s) => s.voiceCallButtonColor,
            ),
            Fld<CometChatCallButtonsStyle, Color>(
              'videoCallButtonColor',
              const Color(0xFF9F5906),
              const Color(0xFFA95E09),
              (s, v) => s.copyWith(videoCallButtonColor: v),
              (s) => s.videoCallButtonColor,
            ),
            Fld<CometChatCallButtonsStyle, BorderSide>(
              'voiceCallButtonBorder',
              const BorderSide(width: 428.5),
              const BorderSide(width: 429.5),
              (s, v) => s.copyWith(voiceCallButtonBorder: v),
              (s) => s.voiceCallButtonBorder,
            ),
            Fld<CometChatCallButtonsStyle, BorderSide>(
              'videoCallButtonBorder',
              const BorderSide(width: 430.5),
              const BorderSide(width: 431.5),
              (s, v) => s.copyWith(videoCallButtonBorder: v),
              (s) => s.videoCallButtonBorder,
            ),
            Fld<CometChatCallButtonsStyle, BorderRadiusGeometry>(
              'voiceCallButtonBorderRadius',
              BorderRadius.circular(432.5),
              BorderRadius.circular(433.5),
              (s, v) => s.copyWith(voiceCallButtonBorderRadius: v),
              (s) => s.voiceCallButtonBorderRadius,
            ),
            Fld<CometChatCallButtonsStyle, BorderRadiusGeometry>(
              'videoCallButtonBorderRadius',
              BorderRadius.circular(434.5),
              BorderRadius.circular(435.5),
              (s, v) => s.copyWith(videoCallButtonBorderRadius: v),
              (s) => s.videoCallButtonBorderRadius,
            ),
          ],
        );
      },
    );

    test(
      'CometChatStickerBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatStickerBubbleStyle>(
          label: 'CometChatStickerBubbleStyle',
          empty: const CometChatStickerBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          lerpNullReturnsSelf: false,
          fields: [
            Fld<CometChatStickerBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a433')),
              const DecorationImage(image: AssetImage('a434')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatStickerBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF17952A),
              const Color(0xFF219A2D),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatStickerBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 440.5),
              Border.all(width: 441.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatStickerBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(442.5),
              BorderRadius.circular(443.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatStickerBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 444.5),
              const TextStyle(fontSize: 445.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatStickerBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF67BD42),
              const Color(0xFF71C245),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatStickerBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatStickerBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatStickerBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatStickerBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 454.5),
              const TextStyle(fontSize: 455.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatImageBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatImageBubbleStyle>(
          label: 'CometChatImageBubbleStyle',
          empty: const CometChatImageBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatImageBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFCBEF60),
              const Color(0xFFD5F463),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatImageBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 458.5),
              Border.all(width: 459.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatImageBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(460.5),
              BorderRadius.circular(461.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
            Fld<CometChatImageBubbleStyle, CometChatAvatarStyle>(
              'messageBubbleAvatarStyle',
              CometChatAvatarStyle(),
              CometChatAvatarStyle(),
              (s, v) => s.copyWith(messageBubbleAvatarStyle: v),
              (s) => s.messageBubbleAvatarStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatImageBubbleStyle, CometChatDateStyle>(
              'messageBubbleDateStyle',
              CometChatDateStyle(),
              CometChatDateStyle(),
              (s, v) => s.copyWith(messageBubbleDateStyle: v),
              (s) => s.messageBubbleDateStyle,
              lerpsByValue: false,
            ),
            Fld<CometChatImageBubbleStyle, DecorationImage>(
              'messageBubbleBackgroundImage',
              const DecorationImage(image: AssetImage('a463')),
              const DecorationImage(image: AssetImage('a464')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.messageBubbleBackgroundImage,
            ),
            Fld<CometChatImageBubbleStyle, TextStyle>(
              'threadedMessageIndicatorTextStyle',
              const TextStyle(fontSize: 468.5),
              const TextStyle(fontSize: 469.5),
              (s, v) => s.copyWith(threadedMessageIndicatorTextStyle: v),
              (s) => s.threadedMessageIndicatorTextStyle,
            ),
            Fld<CometChatImageBubbleStyle, Color>(
              'threadedMessageIndicatorIconColor',
              const Color(0xFF58358A),
              const Color(0xFF623A8D),
              (s, v) => s.copyWith(threadedMessageIndicatorIconColor: v),
              (s) => s.threadedMessageIndicatorIconColor,
            ),
            Fld<CometChatImageBubbleStyle, TextStyle>(
              'senderNameTextStyle',
              const TextStyle(fontSize: 472.5),
              const TextStyle(fontSize: 473.5),
              (s, v) => s.copyWith(senderNameTextStyle: v),
              (s) => s.senderNameTextStyle,
            ),
            Fld<CometChatImageBubbleStyle, CometChatMessageReceiptStyle>(
              'messageReceiptStyle',
              CometChatMessageReceiptStyle(),
              CometChatMessageReceiptStyle(),
              (s, v) => s.copyWith(messageReceiptStyle: v),
              (s) => s.messageReceiptStyle,
              lerpsByValue: false,
            ),
          ],
        );
      },
    );

    test(
      'CometChatImagesBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatImagesBubbleStyle>(
          label: 'CometChatImagesBubbleStyle',
          empty: const CometChatImagesBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatImagesBubbleStyle, double>(
              'tileBorderRadius',
              476.5,
              477.5,
              (s, v) => s.copyWith(tileBorderRadius: v),
              (s) => s.tileBorderRadius,
            ),
            Fld<CometChatImagesBubbleStyle, double>(
              'gridSpacing',
              478.5,
              479.5,
              (s, v) => s.copyWith(gridSpacing: v),
              (s) => s.gridSpacing,
            ),
            Fld<CometChatImagesBubbleStyle, Color>(
              'placeholderColor',
              const Color(0xFFBC67A8),
              const Color(0xFFC66CAB),
              (s, v) => s.copyWith(placeholderColor: v),
              (s) => s.placeholderColor,
            ),
            Fld<CometChatImagesBubbleStyle, Color>(
              'overflowScrimColor',
              const Color(0xFFD071AE),
              const Color(0xFFDA76B1),
              (s, v) => s.copyWith(overflowScrimColor: v),
              (s) => s.overflowScrimColor,
            ),
            Fld<CometChatImagesBubbleStyle, TextStyle>(
              'overflowTextStyle',
              const TextStyle(fontSize: 484.5),
              const TextStyle(fontSize: 485.5),
              (s, v) => s.copyWith(overflowTextStyle: v),
              (s) => s.overflowTextStyle,
            ),
            Fld<CometChatImagesBubbleStyle, TextStyle>(
              'captionTextStyle',
              const TextStyle(fontSize: 486.5),
              const TextStyle(fontSize: 487.5),
              (s, v) => s.copyWith(captionTextStyle: v),
              (s) => s.captionTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatFilesBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatFilesBubbleStyle>(
          label: 'CometChatFilesBubbleStyle',
          empty: const CometChatFilesBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatFilesBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF0C8FC0),
              const Color(0xFF1694C3),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatFilesBubbleStyle, double>(
              'cardBorderRadius',
              490.5,
              491.5,
              (s, v) => s.copyWith(cardBorderRadius: v),
              (s) => s.cardBorderRadius,
            ),
            Fld<CometChatFilesBubbleStyle, double>(
              'cardSpacing',
              492.5,
              493.5,
              (s, v) => s.copyWith(cardSpacing: v),
              (s) => s.cardSpacing,
            ),
            Fld<CometChatFilesBubbleStyle, Color>(
              'iconPlateColor',
              const Color(0xFF48ADD2),
              const Color(0xFF52B2D5),
              (s, v) => s.copyWith(iconPlateColor: v),
              (s) => s.iconPlateColor,
            ),
            Fld<CometChatFilesBubbleStyle, TextStyle>(
              'titleTextStyle',
              const TextStyle(fontSize: 496.5),
              const TextStyle(fontSize: 497.5),
              (s, v) => s.copyWith(titleTextStyle: v),
              (s) => s.titleTextStyle,
            ),
            Fld<CometChatFilesBubbleStyle, TextStyle>(
              'subtitleTextStyle',
              const TextStyle(fontSize: 498.5),
              const TextStyle(fontSize: 499.5),
              (s, v) => s.copyWith(subtitleTextStyle: v),
              (s) => s.subtitleTextStyle,
            ),
            Fld<CometChatFilesBubbleStyle, Color>(
              'downloadIconTint',
              const Color(0xFF84CBE4),
              const Color(0xFF8ED0E7),
              (s, v) => s.copyWith(downloadIconTint: v),
              (s) => s.downloadIconTint,
            ),
            Fld<CometChatFilesBubbleStyle, TextStyle>(
              'toggleTextStyle',
              const TextStyle(fontSize: 502.5),
              const TextStyle(fontSize: 503.5),
              (s, v) => s.copyWith(toggleTextStyle: v),
              (s) => s.toggleTextStyle,
            ),
            Fld<CometChatFilesBubbleStyle, TextStyle>(
              'captionTextStyle',
              const TextStyle(fontSize: 504.5),
              const TextStyle(fontSize: 505.5),
              (s, v) => s.copyWith(captionTextStyle: v),
              (s) => s.captionTextStyle,
            ),
          ],
        );
      },
    );

    test(
      'CometChatLinkPreviewBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatLinkPreviewBubbleStyle>(
          label: 'CometChatLinkPreviewBubbleStyle',
          empty: const CometChatLinkPreviewBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          lerpNullReturnsSelf: false,
          fields: [
            Fld<CometChatLinkPreviewBubbleStyle, TextStyle>(
              'titleStyle',
              const TextStyle(fontSize: 506.5),
              const TextStyle(fontSize: 507.5),
              (s, v) => s.copyWith(titleStyle: v),
              (s) => s.titleStyle,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, TextStyle>(
              'urlStyle',
              const TextStyle(fontSize: 508.5),
              const TextStyle(fontSize: 509.5),
              (s, v) => s.copyWith(urlStyle: v),
              (s) => s.urlStyle,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, Color>(
              'tileColor',
              const Color(0xFFE8FE02),
              const Color(0xFFF30305),
              (s, v) => s.copyWith(tileColor: v),
              (s) => s.tileColor,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFFD0808),
              const Color(0xFF070D0B),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, TextStyle>(
              'descriptionStyle',
              const TextStyle(fontSize: 514.5),
              const TextStyle(fontSize: 515.5),
              (s, v) => s.copyWith(descriptionStyle: v),
              (s) => s.descriptionStyle,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 516.5),
              Border.all(width: 517.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatLinkPreviewBubbleStyle, BorderRadius>(
              'borderRadius',
              BorderRadius.circular(518.5),
              BorderRadius.circular(519.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
          ],
        );
      },
    );

    test(
      'CometChatModerationStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatModerationStyle>(
          label: 'CometChatModerationStyle',
          empty: const CometChatModerationStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          lerpNullReturnsSelf: false,
          fields: [
            Fld<CometChatModerationStyle, Color>(
              'moderationBackgroundColor',
              const Color(0xFF4D3020),
              const Color(0xFF573523),
              (s, v) => s.copyWith(moderationBackgroundColor: v),
              (s) => s.moderationBackgroundColor,
            ),
            Fld<CometChatModerationStyle, TextStyle>(
              'moderationTextStyle',
              const TextStyle(fontSize: 522.5),
              const TextStyle(fontSize: 523.5),
              (s, v) => s.copyWith(moderationTextStyle: v),
              (s) => s.moderationTextStyle,
            ),
            Fld<CometChatModerationStyle, Color>(
              'moderationIconTint',
              const Color(0xFF75442C),
              const Color(0xFF7F492F),
              (s, v) => s.copyWith(moderationIconTint: v),
              (s) => s.moderationIconTint,
            ),
          ],
        );
      },
    );

    test(
      'CometChatMessageTranslationBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatMessageTranslationBubbleStyle>(
          label: 'CometChatMessageTranslationBubbleStyle',
          empty: CometChatMessageTranslationBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatMessageTranslationBubbleStyle, TextStyle>(
              'infoTextStyle',
              const TextStyle(fontSize: 526.5),
              const TextStyle(fontSize: 527.5),
              (s, v) => s.copyWith(infoTextStyle: v),
              (s) => s.infoTextStyle,
            ),
            Fld<CometChatMessageTranslationBubbleStyle, TextStyle>(
              'translatedTextStyle',
              const TextStyle(fontSize: 528.5),
              const TextStyle(fontSize: 529.5),
              (s, v) => s.copyWith(translatedTextStyle: v),
              (s) => s.translatedTextStyle,
            ),
            Fld<CometChatMessageTranslationBubbleStyle, Color>(
              'dividerColor',
              const Color(0xFFB1623E),
              const Color(0xFFBB6741),
              (s, v) => s.copyWith(dividerColor: v),
              (s) => s.dividerColor,
            ),
          ],
        );
      },
    );

    test(
      'CometChatMessageBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatMessageBubbleStyle>(
          label: 'CometChatMessageBubbleStyle',
          empty: const CometChatMessageBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatMessageBubbleStyle, DecorationImage>(
              'backgroundImage',
              const DecorationImage(image: AssetImage('a529')),
              const DecorationImage(image: AssetImage('a530')),
              (s, v) => s.copyWith(messageBubbleBackgroundImage: v),
              (s) => s.backgroundImage,
              lerpsByValue: false,
            ),
            Fld<CometChatMessageBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFFD9764A),
              const Color(0xFFE37B4D),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatMessageBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 536.5),
              Border.all(width: 537.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatMessageBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(538.5),
              BorderRadius.circular(539.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
          ],
        );
      },
    );

    test(
      'CometChatActionBubbleStyle keeps every field through copyWith/merge/lerp',
      () {
        expectStyleContract<CometChatActionBubbleStyle>(
          label: 'CometChatActionBubbleStyle',
          empty: const CometChatActionBubbleStyle(),
          copyWithNothing: (s) => s.copyWith(),
          merge: (s, o) => s.merge(o),
          lerp: (s, o, t) => s.lerp(o, t),
          fields: [
            Fld<CometChatActionBubbleStyle, TextStyle>(
              'textStyle',
              const TextStyle(fontSize: 540.5),
              const TextStyle(fontSize: 541.5),
              (s, v) => s.copyWith(textStyle: v),
              (s) => s.textStyle,
            ),
            Fld<CometChatActionBubbleStyle, Color>(
              'backgroundColor',
              const Color(0xFF299E62),
              const Color(0xFF33A365),
              (s, v) => s.copyWith(backgroundColor: v),
              (s) => s.backgroundColor,
            ),
            Fld<CometChatActionBubbleStyle, BoxBorder>(
              'border',
              Border.all(width: 544.5),
              Border.all(width: 545.5),
              (s, v) => s.copyWith(border: v),
              (s) => s.border,
            ),
            Fld<CometChatActionBubbleStyle, BorderRadiusGeometry>(
              'borderRadius',
              BorderRadius.circular(546.5),
              BorderRadius.circular(547.5),
              (s, v) => s.copyWith(borderRadius: v),
              (s) => s.borderRadius,
            ),
          ],
        );
      },
    );
  });
}
