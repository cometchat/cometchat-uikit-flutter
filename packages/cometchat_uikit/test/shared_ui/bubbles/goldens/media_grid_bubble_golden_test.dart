/// Golden pins for the multi-attachment image bubble — the real
/// [CometChatImagesBubble] (and the [CometChatMediaGrid] inside it) hosted in a
/// [CometChatMessageBubble] with zero content padding, which is how
/// `CometChatMessageList` composes a multi-attachment media message.
///
/// The grid has five genuinely different arrangements and each gets a golden:
/// one square, two side by side, three with the hero on top, three with the
/// hero on the left (chosen from the hero's decoded aspect ratio), and the
/// 2×2 — plus the "+N" overflow scrim once a message exceeds four.
///
/// Pictures come from the in-memory network in `golden_message_harness.dart`,
/// so the cells show decoded pixels rather than a placeholder and nothing
/// touches a socket.
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

/// Distinct tile colours so a golden shows which attachment landed in which
/// cell.
const _tileColors = [
  0x3A7BD5,
  0xE2725B,
  0x4CAF7A,
  0xF2B134,
  0x8E6BBF,
  0x3FB8AF,
  0xC94F7C,
];

MediaMessage _imagesMessage(
  int count, {
  String? caption,
  bool portraitHero = false,
}) {
  final message = MediaMessage(
    receiverUid: 'golden-peer',
    receiverType: ReceiverTypeConstants.user,
    type: MessageTypeConstants.image,
    muid: 'golden-images-$count',
  );
  message.attachments = [
    for (var i = 0; i < count; i++)
      Attachment(
        goldenImageUrl(
          'photo_$i.png',
          _tileColors[i % _tileColors.length],
          // The 3-up layout reads the hero's aspect ratio: portrait puts the
          // hero on the left, anything else on top.
          width: portraitHero && i == 0 ? 6 : 8,
          height: portraitHero && i == 0 ? 9 : 6,
        ),
        'photo_$i.png',
        'png',
        'image/png',
        48 * 1024,
      ),
  ];
  message.caption = caption;
  return message;
}

Widget _bubble(MediaMessage message, BubbleAlignment alignment) {
  return CometChatMessageBubble(
    alignment: alignment,
    // The multi-attachment bubbles carry their own inset; the message list
    // zeroes the outer content padding for them.
    contentPadding: EdgeInsets.zero,
    contentView: CometChatImagesBubble(message: message, alignment: alignment),
    statusInfoView: goldenStatusInfo(alignment),
  );
}

void _grid(
  String fileName,
  String description, {
  required MediaMessage Function() message,
  BubbleAlignment alignment = _incoming,
  double height = 330,
}) {
  goldenLightDark(
    fileName,
    description,
    size: Size(375, height),
    alignment: goldenRowAlignment(alignment),
    build: () => _bubble(message(), alignment),
  );
}

void main() {
  installGoldenImageNetwork();

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _grid(
        'media_grid_1_incoming',
        'images bubble — one attachment, single square cell',
        message: () => _imagesMessage(1),
      );
      _grid(
        'media_grid_2_incoming',
        'images bubble — two attachments, side by side',
        message: () => _imagesMessage(2),
        height: 200,
      );
      _grid(
        'media_grid_3_hero_top_incoming',
        'images bubble — three attachments, landscape hero on top',
        message: () => _imagesMessage(3),
      );
      _grid(
        'media_grid_3_hero_left_outgoing',
        'images bubble — three attachments, portrait hero on the left',
        message: () => _imagesMessage(3, portraitHero: true),
        alignment: _outgoing,
      );
      _grid(
        'media_grid_4_outgoing',
        'images bubble — four attachments, 2x2',
        message: () => _imagesMessage(4),
        alignment: _outgoing,
      );
      _grid(
        'media_grid_overflow_incoming',
        'images bubble — seven attachments, +3 overflow scrim on cell four',
        message: () => _imagesMessage(7),
      );
      _grid(
        'media_grid_caption_incoming',
        'images bubble — two attachments with a caption, incoming',
        message: () =>
            _imagesMessage(2, caption: 'Two from the offsite this morning'),
        height: 270,
      );
      _grid(
        'media_grid_caption_outgoing',
        'images bubble — overflow grid with a caption, outgoing',
        message: () => _imagesMessage(
          6,
          caption: 'All six shots from the launch, pick your favourite',
        ),
        alignment: _outgoing,
        height: 460,
      );
    },
  );
}
