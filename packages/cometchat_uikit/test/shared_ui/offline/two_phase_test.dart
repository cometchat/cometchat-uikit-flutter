import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  test('cached then server -> Cached, Server, then close', () async {
    final events = <TwoPhaseResult<BaseMessage>>[];
    final stream = messageFetchStream((listener) {
      listener.onCachedMessages([msg(id: 1)]);
      listener.onServerMessages([msg(id: 1), msg(id: 2)]);
    });
    await for (final e in stream) {
      events.add(e);
    }
    expect(events, hasLength(2));
    expect(events[0], isA<Cached<BaseMessage>>());
    expect(events[1], isA<Server<BaseMessage>>());
    expect((events[1] as Server).rows, hasLength(2));
  });

  test('error terminal -> PhaseError then close; no further events', () async {
    final events = <TwoPhaseResult<BaseMessage>>[];
    final stream = messageFetchStream((listener) {
      listener.onCachedMessages([msg(id: 1)]);
      listener.onError(CometChatException('E', 'x', 'x'));
      // A late server page after the terminal must be ignored.
      listener.onServerMessages([msg(id: 9)]);
    });
    await for (final e in stream) {
      events.add(e);
    }
    expect(events, hasLength(2));
    expect(events[0], isA<Cached<BaseMessage>>());
    expect(events[1], isA<PhaseError<BaseMessage>>());
  });

  test('conversation stream closes after the server terminal', () async {
    final events = <TwoPhaseResult<Conversation>>[];
    final stream = conversationFetchStream((listener) {
      listener.onServerConversations(const []);
    });
    await for (final e in stream) {
      events.add(e);
    }
    expect(events, hasLength(1));
    expect(events.single, isA<Server<Conversation>>());
  });
}
