/// Call use cases, services and events —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Fifteen exported classes under `call_ui/` that no test had ever
/// constructed. The use cases are the interesting half: six of the ten
/// validate their argument before touching the repository and return a typed
/// `Failure` when it is empty, so each has two branches and only one of them
/// involves the SDK. That guard is the difference between a clear
/// `MISSING_SESSION_ID` and an SDK call with an empty string.
///
/// The rest are two process-wide services and the three events that carry
/// call state around.
///
///   flutter test test/call_ui/call_operations_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the use cases ask for and hands back a fixed answer, so a
/// call that reaches the repository is distinguishable from one the guard
/// stopped.
class _RecordingRepository extends Fake implements CallOperationsRepository {
  final List<String> calls = [];

  @override
  Future<Result<Call>> initiateCall(Call call) async {
    calls.add('initiateCall(${call.receiverUid})');
    return Success(call);
  }

  @override
  Future<Result<Call>> acceptCall(String sessionId) async {
    calls.add('acceptCall($sessionId)');
    return const Failure(message: 'unused');
  }

  @override
  Future<Result<String>> generateCallToken(String sessionId) async {
    calls.add('generateCallToken($sessionId)');
    return const Success('token');
  }

  @override
  Future<Result<Widget>> startSession(
    String sessionId,
    SessionSettings settings,
  ) async {
    calls.add('startSession($sessionId)');
    return const Success(SizedBox());
  }

  @override
  Future<Result<void>> endSession() async {
    calls.add('endSession');
    return const Success(null);
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    calls.add('getLoggedInUser');
    return const Success(null);
  }

  @override
  Future<Result<String?>> getUserAuthToken() async {
    calls.add('getUserAuthToken');
    return const Success('auth-token');
  }

  @override
  Future<Result<CustomMessage>> sendCustomMessage(CustomMessage message) async {
    calls.add('sendCustomMessage(${message.receiverUid})');
    return Success(message);
  }
}

class _FakeCall extends Fake implements Call {
  _FakeCall(this.receiverUid);
  @override
  final String receiverUid;
}

class _FakeCustomMessage extends Fake implements CustomMessage {
  _FakeCustomMessage(this.receiverUid);
  @override
  final String receiverUid;
}

class _FakeSessionSettings extends Fake implements SessionSettings {}

class _FakeCallLog extends Fake implements CallLog {
  _FakeCallLog(this.sessionId);
  @override
  final String? sessionId;
}

void main() {
  late _RecordingRepository repository;

  setUp(() => repository = _RecordingRepository());

  // ===========================================================================
  group('use cases that guard their argument', () {
    test('InitiateDirectCallUseCase rejects a call with no receiver', () async {
      final result = await InitiateDirectCallUseCase(repository)(_FakeCall(''));

      expect(result.isFailure, isTrue);
      result.fold((f) {
        expect(f.code, 'MISSING_RECEIVER_UID');
        expect(f.message, isNotEmpty);
      }, (_) => fail('expected a Failure'));
      expect(
        repository.calls,
        isEmpty,
        reason: 'the guard must stop before the SDK, not after',
      );
    });

    test(
      'InitiateDirectCallUseCase forwards a call that has a receiver',
      () async {
        final result = await InitiateDirectCallUseCase(repository)(
          _FakeCall('u2'),
        );

        expect(result.isSuccess, isTrue);
        expect(repository.calls, ['initiateCall(u2)']);
      },
    );

    test('StartSessionUseCase rejects an empty session id', () async {
      final result = await StartSessionUseCase(repository)(
        '',
        _FakeSessionSettings(),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        (f) => expect(f.code, 'MISSING_SESSION_ID'),
        (_) => fail('expected a Failure'),
      );
      expect(repository.calls, isEmpty);
    });

    test('StartSessionUseCase forwards a real session id', () async {
      final result = await StartSessionUseCase(repository)(
        's1',
        _FakeSessionSettings(),
      );

      expect(result.isSuccess, isTrue);
      expect(repository.calls, ['startSession(s1)']);
    });

    test('every guarded use case uses the same code, so a caller can switch '
        'on it', () async {
      // Four use cases guard a session id and all four must agree on the code
      // or a caller has to match four spellings of the same condition.
      final codes = <String?>[];
      for (final result in <Result<Object?>>[
        await AcceptCallUseCase(repository)(''),
        await EndCallUseCase(repository)(''),
        await GenerateCallTokenUseCase(repository)(''),
        await StartSessionUseCase(repository)('', _FakeSessionSettings()),
      ]) {
        result.fold((f) => codes.add(f.code), (_) => fail('expected Failure'));
      }

      expect(codes, everyElement('MISSING_SESSION_ID'));
      expect(repository.calls, isEmpty);
    });
  });

  // ===========================================================================
  group('use cases that delegate unconditionally', () {
    test(
      'EndSessionUseCase takes no argument and always calls through',
      () async {
        final result = await EndSessionUseCase(repository)();

        expect(result.isSuccess, isTrue);
        expect(repository.calls, ['endSession']);
      },
    );

    test(
      'GetCallLoggedInUserUseCase passes a null user through as success',
      () async {
        // Not-logged-in is a Success carrying null, not a Failure. A caller that
        // treats a Failure as "no user" would miss the difference between a
        // logged-out state and a broken one.
        final result = await GetCallLoggedInUserUseCase(repository)();

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), isNull);
        expect(repository.calls, ['getLoggedInUser']);
      },
    );

    test('GetUserAuthTokenUseCase returns the token', () async {
      final result = await GetUserAuthTokenUseCase(repository)();

      expect(result.getOrNull(), 'auth-token');
      expect(repository.calls, ['getUserAuthToken']);
    });

    test('SendMeetingMessageUseCase forwards the message unguarded', () async {
      // No validation here, deliberately or otherwise: an empty receiver goes
      // straight to the SDK, unlike InitiateDirectCallUseCase above.
      final result = await SendMeetingMessageUseCase(repository)(
        _FakeCustomMessage(''),
      );

      expect(result.isSuccess, isTrue);
      expect(repository.calls, ['sendCustomMessage()']);
    });

    test('each use case calls exactly one repository method', () async {
      await EndSessionUseCase(repository)();
      await GetCallLoggedInUserUseCase(repository)();
      await GetUserAuthTokenUseCase(repository)();

      expect(repository.calls, [
        'endSession',
        'getLoggedInUser',
        'getUserAuthToken',
      ]);
    });
  });

  // ===========================================================================
  group('CallStateService', () {
    tearDown(() {
      CallStateService.instance
        ..setActiveCallValue(false)
        ..setActiveIncomingValue(false)
        ..setActiveOutgoingValue(false);
    });

    test('is a singleton and starts with every flag false', () {
      expect(CallStateService.instance, same(CallStateService.instance));
      expect(CallStateService.instance.isActiveCall.value, isFalse);
      expect(CallStateService.instance.isActiveIncomingCall.value, isFalse);
      expect(CallStateService.instance.isActiveOutgoingCall.value, isFalse);
    });

    test('the three flags are independent', () {
      CallStateService.instance.setActiveIncomingValue(true);

      expect(CallStateService.instance.isActiveIncomingCall.value, isTrue);
      expect(CallStateService.instance.isActiveCall.value, isFalse);
      expect(CallStateService.instance.isActiveOutgoingCall.value, isFalse);
    });

    test('each flag notifies its listeners on change', () {
      var notified = 0;
      void listener() => notified++;
      CallStateService.instance.isActiveCall.addListener(listener);
      addTearDown(
        () => CallStateService.instance.isActiveCall.removeListener(listener),
      );

      CallStateService.instance.setActiveCallValue(true);
      expect(notified, 1);

      // A ValueNotifier does not re-notify for the same value, which is what
      // keeps a repeated SDK callback from rebuilding the call screen.
      CallStateService.instance.setActiveCallValue(true);
      expect(notified, 1);

      CallStateService.instance.setActiveCallValue(false);
      expect(notified, 2);
    });
  });

  // ===========================================================================
  group('CallEventService', () {
    test('is a singleton with no active call before init', () {
      // init() needs a logged-in user and a live Calls SDK, so only the
      // pre-init surface is reachable headless — which is exactly the state a
      // freshly-launched app is in.
      expect(CallEventService.instance, same(CallEventService.instance));
      expect(CallEventService.instance.activeCall, isNull);
    });

    test('activeCall is writable — the listeners set it', () {
      addTearDown(() => CallEventService.instance.activeCall = null);

      CallEventService.instance.activeCall = null;
      expect(CallEventService.instance.activeCall, isNull);
    });
  });

  // ===========================================================================
  group('call events', () {
    testWidgets('InitiateCallFromLog carries the log and the context it was '
        'tapped in', (tester) async {
      // The context is in props, so two taps from different screens are
      // different events even for the same log — which is right, because the
      // handler navigates with it.
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final log = _FakeCallLog('s1');
      final event = InitiateCallFromLog(callLog: log, context: context);

      expect(event.callLog, same(log));
      expect(event.context, same(context));
      expect(event.props, [log, context]);
      expect(event, InitiateCallFromLog(callLog: log, context: context));
    });

    test('UserListChanged compares its list by value', () {
      expect(
        const UserListChanged(<RTCUser>[]),
        const UserListChanged(<RTCUser>[]),
      );
      expect(const UserListChanged(<RTCUser>[]).props, [<RTCUser>[]]);
    });

    test('ParticipantListChanged compares its list by value', () {
      expect(
        const ParticipantListChanged(<Participant>[]),
        const ParticipantListChanged(<Participant>[]),
      );
    });

    test('the two list events are distinct types over an empty list', () {
      // Same trap as the receipt and reaction pairs: identical props, and only
      // the type separates a participant change from a user change.
      expect(
        const UserListChanged(<RTCUser>[]).props,
        const ParticipantListChanged(<Participant>[]).props,
      );
      expect(
        const UserListChanged(<RTCUser>[]),
        isNot(const ParticipantListChanged(<Participant>[])),
      );
    });
  });
}
