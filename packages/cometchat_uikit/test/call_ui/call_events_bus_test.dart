/// CometChatCallEvents dispatch (round 1a, P1-C12): synchronous, in
/// registration order, over a snapshot of the listeners, with each listener
/// isolated from the others (a throw is reported through FlutterError).
///
///   flutter test test/call_ui/call_events_bus_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every event into a shared log as `id:event`, and runs an optional
/// hook first.
class _Listener with CometChatCallEventListener {
  _Listener(this.id, this.log, {this.onEvent});

  final String id;
  final List<String> log;
  final void Function(String event)? onEvent;

  void _record(String event) {
    onEvent?.call(event);
    log.add('$id:$event');
  }

  @override
  void ccOutgoingCall(Call call) => _record('outgoing');

  @override
  void ccCallAccepted(Call call) => _record('accepted');

  @override
  void ccCallRejected(Call call) => _record('rejected');

  @override
  void ccCallEnded(Call call) => _record('ended');
}

Call _call() => Call(
  sessionId: 's1',
  receiverUid: 'peer',
  type: 'audio',
  receiverType: 'user',
);

void main() {
  late Map<String, CometChatCallEventListener> saved;
  final log = <String>[];

  setUp(() {
    saved = Map.of(CometChatCallEvents.callEventsListener);
    CometChatCallEvents.callEventsListener.clear();
    log.clear();
  });

  tearDown(() {
    CometChatCallEvents.callEventsListener
      ..clear()
      ..addAll(saved);
  });

  void add(_Listener listener) =>
      CometChatCallEvents.addCallEventsListener(listener.id, listener);

  test('delivers synchronously, in registration order', () {
    add(_Listener('a', log));
    add(_Listener('b', log));
    add(_Listener('c', log));

    CometChatCallEvents.ccCallAccepted(_call());

    // Nothing awaited: the event has already reached every listener.
    expect(log, ['a:accepted', 'b:accepted', 'c:accepted']);
  });

  test('a listener removing itself inside ccCallEnded does not throw, and '
      'every listener is called', () {
    add(
      _Listener(
        'a',
        log,
        onEvent: (_) => CometChatCallEvents.removeCallEventsListener('a'),
      ),
    );
    add(_Listener('b', log));
    add(_Listener('c', log));

    expect(() => CometChatCallEvents.ccCallEnded(_call()), returnsNormally);

    expect(log, ['a:ended', 'b:ended', 'c:ended']);
    expect(CometChatCallEvents.callEventsListener.keys, ['b', 'c']);
  });

  test('a listener adding another inside a handler does not throw; the new '
      'one hears the next event', () {
    final lateListener = _Listener('late', log);
    add(
      _Listener(
        'a',
        log,
        onEvent: (_) {
          if (!CometChatCallEvents.callEventsListener.containsKey('late')) {
            add(lateListener);
          }
        },
      ),
    );
    add(_Listener('b', log));

    expect(() => CometChatCallEvents.ccOutgoingCall(_call()), returnsNormally);
    expect(log, ['a:outgoing', 'b:outgoing']);

    log.clear();
    CometChatCallEvents.ccCallRejected(_call());
    expect(log, ['a:rejected', 'b:rejected', 'late:rejected']);
  });

  test('a listener removed by an earlier one during the dispatch is skipped '
      '(as before the snapshot)', () {
    add(
      _Listener(
        'a',
        log,
        onEvent: (_) => CometChatCallEvents.removeCallEventsListener('b'),
      ),
    );
    add(_Listener('b', log));
    add(_Listener('c', log));

    CometChatCallEvents.ccCallEnded(_call());

    expect(log, ['a:ended', 'c:ended']);
  });

  test('a throwing listener does not stop the next one, and is reported '
      'through FlutterError', () {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    add(_Listener('a', log));
    add(
      _Listener(
        'boom',
        log,
        onEvent: (_) => throw StateError('host listener bug'),
      ),
    );
    add(_Listener('c', log));

    for (final dispatch in <void Function(Call)>[
      CometChatCallEvents.ccOutgoingCall,
      CometChatCallEvents.ccCallAccepted,
      CometChatCallEvents.ccCallRejected,
      CometChatCallEvents.ccCallEnded,
    ]) {
      expect(() => dispatch(_call()), returnsNormally);
    }

    expect(log, [
      'a:outgoing',
      'c:outgoing',
      'a:accepted',
      'c:accepted',
      'a:rejected',
      'c:rejected',
      'a:ended',
      'c:ended',
    ]);
    expect(reported, hasLength(4));
    expect(reported.first.exception, isA<StateError>());
    expect(reported.first.library, 'cometchat_chat_uikit');
    expect(
      reported.first.context.toString(),
      contains('ccOutgoingCall to CometChatCallEvents listener "boom"'),
    );
  });
}
