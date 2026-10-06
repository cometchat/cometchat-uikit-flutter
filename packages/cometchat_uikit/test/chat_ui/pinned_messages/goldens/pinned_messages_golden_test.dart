/// Golden pins for [CometChatPinnedMessages]: the pinned-message row (mine and
/// theirs) and the empty state.
///
/// The screen takes no bloc, so the real widget runs against a fake message
/// store registered where the SDK resolves its repositories (see
/// test/helpers/golden_fake_sdk.dart). No network is involved.
///
///   flutter test test/chat_ui/pinned_messages/goldens/                  # verify
///   flutter test test/chat_ui/pinned_messages/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_fake_sdk.dart';
import '../../../helpers/golden_harness.dart';

final _me = User(uid: 'u-me', name: 'Sam Carter');
final _peer = User(uid: 'u-priya', name: 'Priya Raman');

/// Old enough that the row prints an absolute date whatever day the test
/// runs on; local, so the printed string is the same in every zone.
final _sentAt = DateTime(2024, 3, 14, 9, 30);
final _pinnedAt = DateTime(2024, 3, 15, 18, 45);

TextMessage _pin(int id, {required User sender, required String text}) =>
    TextMessage(
        id: id,
        text: text,
        sender: sender,
        receiver: sender.uid == _me.uid ? _peer : _me,
        receiverUid: sender.uid == _me.uid ? _peer.uid : _me.uid,
        type: MessageTypeConstants.text,
        receiverType: ReceiverTypeConstants.user,
        category: MessageCategoryConstants.message,
        sentAt: _sentAt,
      )
      ..pinnedAt = _pinnedAt
      ..pinnedBy = _peer.uid;

List<BaseMessage> _pins() => [
  _pin(201, sender: _peer, text: 'Door code is 4417'),
  _pin(202, sender: _me, text: 'Standup moves to 9:30 from Monday'),
];

const _size = Size(375, 420);

void main() {
  setUp(() async {
    CometChatUIKit.loggedInUser = _me;
    await registerFakeMessageStore();
  });
  tearDown(() async {
    CometChatUIKit.loggedInUser = null;
    await clearFakeMessageStore();
  });

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'pinned message rows: one from the peer, one from me',
        fileName: 'pinned_messages_loaded',
        size: _size,
        builder: () {
          fakeMessagePage = _pins;
          return CometChatPinnedMessages(user: _peer);
        },
      );

      lightDarkGolden(
        'pinned messages empty state',
        fileName: 'pinned_messages_state_empty',
        size: _size,
        builder: () {
          fakeMessagePage = () => const [];
          return CometChatPinnedMessages(user: _peer);
        },
      );
    },
  );
}
