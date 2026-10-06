/// Golden pins for the reactions row under a bubble — the real
/// [CometChatReactions] in the `footerView` slot of a real
/// [CometChatMessageBubble], lifted 5dp the way
/// `CometChatMessageList._getReactionsView` lifts it so the chips overlap the
/// bubble's bottom edge.
///
/// The emoji themselves render as blocks in the CI variant; what these pin is
/// the chip: its fill, its border, how the logged-in user's own reaction is
/// highlighted, and where the "+N" overflow chip takes over.
///
///   flutter test test/shared_ui/bubbles/goldens/                  # verify
///   flutter test test/shared_ui/bubbles/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_message_harness.dart';

const _incoming = BubbleAlignment.left;
const _outgoing = BubbleAlignment.right;

ReactionCount _r(String emoji, int count, {bool mine = false}) =>
    ReactionCount(reaction: emoji, count: count, reactedByMe: mine);

void _reactions(
  String fileName,
  String description, {
  required List<ReactionCount> Function() reactions,
  BubbleAlignment alignment = _incoming,
}) {
  goldenLightDark(
    fileName,
    description,
    size: const Size(375, 130),
    alignment: goldenRowAlignment(alignment),
    build: () => CometChatMessageBubble(
      alignment: alignment,
      contentView: CometChatTextBubble(
        text: 'Release is tagged and out the door',
        alignment: alignment,
      ),
      statusInfoView: goldenStatusInfo(alignment),
      footerView: Transform.translate(
        offset: const Offset(0, -5),
        child: CometChatReactions(
          reactionList: reactions(),
          alignment: alignment,
        ),
      ),
    ),
  );
}

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _reactions(
        'reactions_single_incoming',
        'reactions row — one reaction from someone else',
        reactions: () => [_r('\u{1F44D}', 1)],
      );
      _reactions(
        'reactions_several_incoming',
        'reactions row — three reactions, none mine',
        reactions: () => [
          _r('\u{1F44D}', 4),
          _r('\u{1F389}', 2),
          _r('\u{2764}\u{FE0F}', 12),
        ],
      );
      _reactions(
        'reactions_own_highlighted_incoming',
        'reactions row — my own reaction takes the active fill and border',
        reactions: () => [
          _r('\u{1F44D}', 4, mine: true),
          _r('\u{1F389}', 2),
          _r('\u{1F602}', 1),
        ],
      );
      _reactions(
        'reactions_own_highlighted_outgoing',
        'reactions row — right-aligned under an outgoing bubble, one mine',
        reactions: () => [_r('\u{1F525}', 3), _r('\u{1F64F}', 1, mine: true)],
        alignment: _outgoing,
      );
      _reactions(
        'reactions_overflow_incoming',
        'reactions row — six reactions collapse to three chips and "+3"',
        reactions: () => [
          _r('\u{1F44D}', 9, mine: true),
          _r('\u{1F389}', 5),
          _r('\u{2764}\u{FE0F}', 4),
          _r('\u{1F602}', 2),
          _r('\u{1F525}', 1),
          _r('\u{1F440}', 1),
        ],
      );
    },
  );
}
