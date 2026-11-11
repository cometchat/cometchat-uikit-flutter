/// Direct tests for [IncomingCallGate]: the checks every incoming call goes
/// through before it rings, whichever way it arrived (the chat SDK's call
/// listener on web, the Calls SDK's incoming call listener from a push).
///
///   flutter test test/call_ui/incoming_call/incoming_call_gate_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/incoming_call_gate.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'me', name: 'Me');
final _peer = User(uid: 'peer', name: 'Peer');

/// A call ringing here, from [from], in [sessionId].
Call _incoming({String sessionId = 'session_1', User? from}) => Call(
  sessionId: sessionId,
  callStatus: 'initiated',
  receiverUid: 'me',
  receiverType: 'user',
  type: 'audio',
  callInitiator: from ?? _peer,
  sender: from ?? _peer,
);

void main() {
  final service = CallEventService.instance;

  setUp(() {
    CometChatUIKit.loggedInUser = _me;
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.callScreenSessionId = null;
    ActiveCallTracker.callScreenWorkFlow = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.forgetFinishedCalls();
  });

  test('a call from someone else, with nothing going on here, rings', () {
    expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ring);
  });

  test('the logged-in user\'s own call (an echo) is ignored', () {
    expect(
      IncomingCallGate.admit(_incoming(from: _me)),
      IncomingVerdict.ignore,
    );
  });

  test('with no logged-in user known, a call is not taken for an echo', () {
    CometChatUIKit.loggedInUser = null;
    expect(IncomingCallGate.admit(_incoming(from: _me)), IncomingVerdict.ring);
  });

  group('a call this device is already handling is ignored', () {
    test('the active call', () {
      service.activeCall = _incoming();
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    });

    test('the call ringing here (a duplicate push)', () {
      ActiveCallTracker.ringingCall = _incoming();
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    });

    test('the call on the call screen (answered from the system call UI)', () {
      ActiveCallTracker.callScreenSessionId = 'session_1';
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    });

    test('the incoming call screen\'s call', () {
      ActiveCallTracker.incomingCallSessionId = 'session_1';
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    });
  });

  test('a late copy of a call this device finished lately is ignored', () {
    ActiveCallTracker.ringingEnded('session_1');
    expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    // Another call still rings.
    expect(
      IncomingCallGate.admit(_incoming(sessionId: 'session_2')),
      IncomingVerdict.ring,
    );
  });

  group('a second call while busy is answered busy', () {
    test('during a call in progress', () {
      service.activeCall = _incoming(sessionId: 'in_progress');
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.busy);
    });

    test('while another call rings', () {
      ActiveCallTracker.ringingCall = _incoming(sessionId: 'ringing');
      expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.busy);
    });

    test('and the call in progress is left untouched', () {
      final inProgress = _incoming(sessionId: 'in_progress');
      service.activeCall = inProgress;
      IncomingCallGate.admit(_incoming());
      expect(service.activeCall, same(inProgress));
    });
  });

  test('an echo or a duplicate wins over busy: neither is answered busy', () {
    ActiveCallTracker.ringingCall = _incoming();
    expect(IncomingCallGate.admit(_incoming()), IncomingVerdict.ignore);
    expect(
      IncomingCallGate.admit(_incoming(from: _me, sessionId: 'x')),
      IncomingVerdict.ignore,
    );
  });

  group('isHandling', () {
    test('is false for no session', () {
      ActiveCallTracker.callScreenSessionId = '';
      expect(IncomingCallGate.isHandling(null), isFalse);
      expect(IncomingCallGate.isHandling(''), isFalse);
    });

    test('is false for a session nothing here holds', () {
      ActiveCallTracker.ringingCall = _incoming(sessionId: 'other');
      expect(IncomingCallGate.isHandling('session_1'), isFalse);
    });
  });
}
