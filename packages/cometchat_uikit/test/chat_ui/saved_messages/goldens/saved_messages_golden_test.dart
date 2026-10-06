/// Golden pins for [CometChatSavedMessages]: the saved-message row (1-1 and
/// group) and the empty state.
///
/// The screen takes no bloc, so the real widget runs against a fake message
/// store registered where the SDK resolves its repositories (see
/// test/helpers/golden_fake_sdk.dart). No network is involved.
///
///   flutter test test/chat_ui/saved_messages/goldens/                  # verify
///   flutter test test/chat_ui/saved_messages/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_fake_sdk.dart';
import '../../../helpers/golden_harness.dart';

final _me = User(uid: 'u-me', name: 'Sam Carter');

/// Old enough that the row prints an absolute date whatever day the test
/// runs on; local, so the printed string is the same in every zone.
final _sentAt = DateTime(2024, 3, 14, 9, 30);
final _savedAt = DateTime(2024, 3, 15, 18, 45);

/// A 1-1 text, titled by its sender, and a group text, titled by the group
/// with the sender prefixed to the preview.
List<BaseMessage> _saved() => [
  TextMessage(
    id: 101,
    text: 'The venue is booked for the 22nd',
    sender: User(uid: 'u-priya', name: 'Priya Raman'),
    receiver: _me,
    receiverUid: _me.uid,
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.user,
    category: MessageCategoryConstants.message,
    sentAt: _sentAt,
  )..savedAt = _savedAt,
  TextMessage(
    id: 102,
    text: 'Final logo files are in the drive',
    sender: User(uid: 'u-marcus', name: 'Marcus Webb'),
    receiver: Group(
      guid: 'g-design',
      name: 'Design Review',
      type: GroupTypeConstants.public,
    ),
    receiverUid: 'g-design',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.group,
    category: MessageCategoryConstants.message,
    sentAt: _sentAt,
  )..savedAt = _savedAt,
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
        'saved message rows: a 1-1 message and a group message',
        fileName: 'saved_messages_loaded',
        size: _size,
        builder: () {
          fakeMessagePage = _saved;
          return const CometChatSavedMessages();
        },
      );

      lightDarkGolden(
        'saved messages empty state',
        fileName: 'saved_messages_state_empty',
        size: _size,
        builder: () {
          fakeMessagePage = () => const [];
          return const CometChatSavedMessages();
        },
      );
    },
  );
}
