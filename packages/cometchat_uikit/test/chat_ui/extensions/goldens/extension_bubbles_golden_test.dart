/// Golden pins for the two extension bubbles that carry the most layout of
/// their own: the polls bubble and the link-preview bubble.
///
/// * Polls render the real [CometChatPollsBubble] with hand-built
///   [PollOptions] — the shape `MessageTemplateUtils` hands it after parsing
///   the extension payload.
/// * Link previews go through `MessageTemplateUtils.getTextMessageContentView`
///   with a [TextMessage] whose metadata carries the `link-preview` extension
///   block, so the golden covers the real detection path and the text bubble
///   nested under the card, not just the card widget in isolation.
///
/// Both sit in a real [CometChatMessageBubble]. The preview image is served by
/// the in-memory network in `golden_message_harness.dart`.
///
///   flutter test test/chat_ui/extensions/goldens/                  # verify
///   flutter test test/chat_ui/extensions/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_message_harness.dart';

const _incoming = BubbleAlignment.left;
const _outgoing = BubbleAlignment.right;

final _me = User(uid: 'golden-me', name: 'Morgan Reyes');
final _priya = User(uid: 'golden-priya', name: 'Priya Nair');
final _tomas = User(uid: 'golden-tomas', name: 'Tomas Lindqvist');
final _aiko = User(uid: 'golden-aiko', name: 'Aiko Tanaka');
final _dele = User(uid: 'golden-dele', name: 'Dele Okafor');

Widget _bubble(Widget content, BubbleAlignment alignment) {
  return CometChatMessageBubble(
    alignment: alignment,
    contentView: content,
    statusInfoView: goldenStatusInfo(alignment),
  );
}

// ---------------------------------------------------------------------------
// Polls
// ---------------------------------------------------------------------------

PollOptions _option(String id, String text, [List<User> voters = const []]) =>
    PollOptions(
      id: id,
      optionText: text,
      voteCount: voters.length,
      votersUid: [for (final v in voters) v.uid],
      voters: voters,
    );

void _poll(
  String fileName,
  String description, {
  required String question,
  required List<PollOptions> Function() options,
  BubbleAlignment alignment = _incoming,
  double height = 300,
}) {
  goldenLightDark(
    fileName,
    description,
    size: Size(375, height),
    alignment: goldenRowAlignment(alignment),
    build: () => _bubble(
      CometChatPollsBubble(
        pollQuestion: question,
        options: options(),
        pollId: 'golden-poll',
        loggedInUser: _me.uid,
        senderUid: alignment == _outgoing ? _me.uid : _priya.uid,
        alignment: alignment,
        choosePoll: (_, _) async {},
      ),
      alignment,
    ),
  );
}

// ---------------------------------------------------------------------------
// Link preview
// ---------------------------------------------------------------------------

TextMessage _linkMessage({required bool withImage, required User sender}) {
  return TextMessage(
    text: 'Worth a read before Thursday: https://example.com/field-notes',
    receiverUid: _priya.uid,
    receiverType: ReceiverTypeConstants.user,
    type: MessageTypeConstants.text,
    sender: sender,
    sentAt: DateTime(2024, 3, 14, 12, 30),
    metadata: {
      '@injected': {
        'extensions': {
          'link-preview': {
            'links': [
              {
                'url': 'https://example.com/field-notes',
                'title': 'Field notes on shipping chat',
                'description': 'What we learned running it for a year.',
                if (withImage)
                  'image': goldenImageUrl(
                    'og.png',
                    0x3FB8AF,
                    width: 232,
                    height: 120,
                  ),
              },
            ],
          },
        },
      },
    },
  );
}

void _link(
  String fileName,
  String description, {
  required bool withImage,
  required BubbleAlignment alignment,
  required double height,
}) {
  goldenLightDark(
    fileName,
    description,
    size: Size(375, height),
    alignment: goldenRowAlignment(alignment),
    build: () => _bubble(
      Builder(
        builder: (context) => MessageTemplateUtils.getTextMessageContentView(
          _linkMessage(
            withImage: withImage,
            sender: alignment == _outgoing ? _me : _priya,
          ),
          context,
          alignment,
        ),
      ),
      alignment,
    ),
  );
}

void main() {
  installGoldenImageNetwork();

  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _poll(
        'poll_unvoted_incoming',
        'polls bubble — nobody has voted: empty bars, no counts, no avatars',
        question: 'Where should the offsite be?',
        options: () => [
          _option('1', 'Lisbon'),
          _option('2', 'Kyoto'),
          _option('3', 'Cape Town'),
        ],
      );
      _poll(
        'poll_uneven_split_incoming',
        'polls bubble — 3/1/0 split, own vote ticked on the leading option',
        question: 'Where should the offsite be?',
        options: () => [
          _option('1', 'Lisbon', [_me, _tomas, _aiko]),
          _option('2', 'Kyoto', [_dele]),
          _option('3', 'Cape Town'),
        ],
      );
      _poll(
        'poll_uneven_split_outgoing',
        'polls bubble — uneven split on the outgoing (primary) background',
        question: 'Where should the offsite be?',
        options: () => [
          _option('1', 'Lisbon', [_tomas]),
          _option('2', 'Kyoto', [_me, _aiko, _dele]),
          _option('3', 'Cape Town'),
        ],
        alignment: _outgoing,
      );
      _poll(
        'poll_two_options_incoming',
        'polls bubble — two options, one vote each, not voted by me',
        question: 'Ship on Friday?',
        options: () => [
          _option('1', 'Yes', [_tomas]),
          _option('2', 'No', [_aiko]),
        ],
        height: 220,
      );

      _link(
        'link_preview_image_incoming',
        'link preview — image, title, description, url, text below; incoming',
        withImage: true,
        alignment: _incoming,
        height: 420,
      );
      _link(
        'link_preview_image_outgoing',
        'link preview — image, title, description, url, text below; outgoing',
        withImage: true,
        alignment: _outgoing,
        height: 440,
      );
      _link(
        'link_preview_no_image_incoming',
        'link preview — no image, card collapses to the text tile',
        withImage: false,
        alignment: _incoming,
        height: 300,
      );
    },
  );
}
