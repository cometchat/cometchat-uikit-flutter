/// Golden pins for [CometChatThreadedHeader], the parent-message header above
/// a thread.
///
/// The real header is rendered, held in its loaded state through its
/// `threadedHeaderBloc` seam. The parent bubble is built by the Kit's own
/// text-message template. No network is involved.
///
///   flutter test test/chat_ui/threaded_header/goldens/                  # verify
///   flutter test test/chat_ui/threaded_header/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockThreadedHeaderBloc
    extends MockBloc<ThreadedHeaderEvent, ThreadedHeaderState>
    implements ThreadedHeaderBloc {}

final _me = User(uid: 'u-me', name: 'Sam Carter');
final _peer = User(uid: 'u-priya', name: 'Priya Raman');

/// Built from a local DateTime so the bubble's time reads the same, and is as
/// wide, in every zone.
TextMessage _parent({required User sender, required int replies}) =>
    TextMessage(
        id: 7401,
        text: 'Shall we move the launch to Thursday?',
        sender: sender,
        receiver: sender.uid == _me.uid ? _peer : _me,
        receiverUid: sender.uid == _me.uid ? _peer.uid : _me.uid,
        type: MessageTypeConstants.text,
        receiverType: ReceiverTypeConstants.user,
        category: MessageCategoryConstants.message,
        sentAt: DateTime(2025, 5, 15, 10, 30),
      )
      ..replyCount = replies
      ..threadSubscribed = true;

_MockThreadedHeaderBloc _bloc(BaseMessage parent) {
  final state = ThreadedHeaderState(
    status: ThreadedHeaderStatus.loaded,
    parentMessage: parent,
    replyCount: parent.replyCount,
    loggedInUser: _me,
    user: _peer,
    threadSubscribed: parent.threadSubscribed,
  );
  final bloc = _MockThreadedHeaderBloc();
  whenListen(
    bloc,
    Stream<ThreadedHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

const _size = Size(375, 200);

void main() {
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'thread header over an incoming parent, several replies',
        fileName: 'threaded_header_incoming_parent',
        size: _size,
        builder: () {
          final parent = _parent(sender: _peer, replies: 3);
          return CometChatThreadedHeader(
            parentMessage: parent,
            loggedInUser: _me,
            threadedHeaderBloc: _bloc(parent),
          );
        },
      );

      lightDarkGolden(
        'thread header over my own parent, one reply',
        fileName: 'threaded_header_outgoing_parent',
        size: _size,
        builder: () {
          final parent = _parent(sender: _me, replies: 1);
          return CometChatThreadedHeader(
            parentMessage: parent,
            loggedInUser: _me,
            threadedHeaderBloc: _bloc(parent),
          );
        },
      );
    },
  );
}
