import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';

import '../helpers/call_bloc_harness.dart';

// ===========================================================================
// Fakes
// ===========================================================================

/// Records the events the bloc processes, so a test can assert that the
/// auto-teardown did — or did not — queue an [EndCallButtonPressed].
///
/// A [BlocObserver] cannot be used for this: `bloc_test` swaps in its own
/// observer that forwards only `onError`, so `onEvent` never reaches a
/// user-supplied one.
class _SpyOngoingCallBloc extends OngoingCallBloc {
  _SpyOngoingCallBloc({
    required super.sessionSettingsBuilder,
    required super.sessionId,
    super.callWorkFlow,
  });

  final List<OngoingCallEvent> seen = [];

  @override
  void onEvent(OngoingCallEvent event) {
    super.onEvent(event);
    seen.add(event);
  }

  int get endCallPresses => seen.whereType<EndCallButtonPressed>().length;
}

// ===========================================================================
// Helpers
// ===========================================================================

const _myUid = 'me';
const _peerUid = 'peer';

Call _call({required String receiverType}) => Call(
  sessionId: 'session_1',
  receiverUid: _peerUid,
  type: 'audio',
  receiverType: receiverType,
);

Participant _participant(String uid) => Participant(uid: uid);

/// The peer in the session, as the Calls SDK lists it: what arms the rule.
ParticipantListChanged _peerPresent() =>
    ParticipantListChanged([_participant(_myUid), _participant(_peerUid)]);

/// Hands [participant] joining to the bloc's listeners, as the Calls SDK
/// does (`onParticipantJoined`).
void _sdkParticipantJoined(Participant participant) {
  for (final ParticipantEventListeners listener in List.of(
    CallSession.getInstance()!.participantEventListeners,
  )) {
    listener.onParticipantJoined(participant);
  }
}

// ===========================================================================
// Tests — auto-teardown when the remote party leaves a 1-on-1 session
//
// Covers ParticipantListChanged / ParticipantLeft -> _evaluatePeerLeft, and
// the four guards it applies: workflow, 1-on-1, locally-ended, and the
// _otherCount participant arithmetic (including excludeUid).
// ===========================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;

  /// The bloc joins as on a device: the harness's ready fake Calls SDK, a
  /// granted permission channel and the fake datasource's `startSession`.
  /// The participant handlers under test are driven directly.
  _SpyOngoingCallBloc buildBloc({
    CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
  }) => _SpyOngoingCallBloc(
    sessionSettingsBuilder: SessionSettingsBuilder(),
    sessionId: 'session_1',
    callWorkFlow: workFlow,
  );

  /// Waits until [bloc] has joined: participant events only arrive once the
  /// call view is up (the bloc registers its session listeners then).
  Future<void> joined(OngoingCallBloc bloc) async {
    if (bloc.state.status == OngoingCallStatus.active) return;
    await bloc.stream.firstWhere(
      (OngoingCallState s) => s.status == OngoingCallStatus.active,
    );
  }

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();

    CometChatUIKit.loggedInUser = User(uid: _myUid, name: 'Me');
    CallEventService.instance.activeCall = _call(receiverType: 'user');
  });

  tearDown(() async {
    removeCallJoinDefaults();
    CallEventService.instance.activeCall = null;
    CometChatUIKit.loggedInUser = null;
    await CallOperationsServiceLocator.instance.reset();
  });

  // =========================================================================
  // ParticipantListChanged — the signal iOS actually delivers
  // =========================================================================

  group('ParticipantListChanged', () {
    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'ends the call when the list empties on a 1-on-1 call',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 1);
        expect(dataSource.endSessionCount, 1);
        expect(dataSource.endCallCount, 1);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'does not end the call while the peer is still present',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(
          ParticipantListChanged([
            _participant(_myUid),
            _participant(_peerUid),
          ]),
        );
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 0);
        expect(dataSource.endCallCount, 0);
        expect(bloc.state.participantsList.length, 2);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'ends the call when only the local user remains',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(ParticipantListChanged([_participant(_myUid)]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 1),
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'a peer-present update followed by an empty one ends the call once',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(
          ParticipantListChanged([
            _participant(_myUid),
            _participant(_peerUid),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 1),
    );
  });

  // =========================================================================
  // ParticipantLeft — platforms that deliver a discrete leave event
  // =========================================================================

  group('ParticipantLeft', () {
    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'ends the call even when the list has not refreshed yet',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        // The list still shows both parties; only excludeUid discounts the
        // leaver, so without it this update would look like a live call.
        bloc.add(
          ParticipantListChanged([
            _participant(_myUid),
            _participant(_peerUid),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(ParticipantLeft(_participant(_peerUid)));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 1);
        expect(dataSource.endCallCount, 1);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'does not end the call while another participant remains',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(
          ParticipantListChanged([
            _participant(_myUid),
            _participant(_peerUid),
            _participant('third'),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(ParticipantLeft(_participant(_peerUid)));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 0),
    );
  });

  // =========================================================================
  // Guards
  // =========================================================================

  group('_evaluatePeerLeft guards', () {
    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'directCalling (meetings) never auto-ends',
      build: () => buildBloc(workFlow: CallWorkFlow.directCalling),
      act: (bloc) async {
        await joined(bloc);
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 0);
        expect(dataSource.endCallCount, 0);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'P4-C10: a group call never auto-ends, even with no other record',
      build: () {
        CallEventService.instance.activeCall = _call(receiverType: 'group');
        return buildBloc();
      },
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 0),
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'P4-C10: no call record: a 1-on-1 call screen (defaultCalling) still '
      'ends when the peer leaves',
      build: () {
        CallEventService.instance.activeCall = null;
        return buildBloc();
      },
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 1);
        expect(dataSource.endCallCount, 1);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'P4-C10: the record of another call does not stop it either',
      build: () {
        CallEventService.instance.activeCall = Call(
          sessionId: 'another',
          receiverUid: 'group-1',
          type: 'audio',
          receiverType: 'group',
        );
        return buildBloc();
      },
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 1),
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      '_peerLeftHandled latches — a burst of updates ends the call once',
      build: buildBloc,
      // Deliberately no awaits between the adds: they all land before the
      // first teardown completes and sets isCallEndedByMe, so _peerLeftHandled
      // is the only thing that can stop a second end-call sequence.
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        bloc.add(const ParticipantListChanged([]));
        bloc.add(const ParticipantListChanged([]));
        bloc.add(ParticipantLeft(_participant(_peerUid)));
      },
      wait: const Duration(milliseconds: 80),
      verify: (bloc) {
        expect(bloc.endCallPresses, 1);
        expect(dataSource.endSessionCount, 1);
        expect(dataSource.endCallCount, 1);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'a locally-ended call does not auto-end a second time',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(_peerPresent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const EndCallButtonPressed());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 80),
      verify: (bloc) {
        // The one press is the local hangup; the empty list adds no second.
        expect(bloc.endCallPresses, 1);
        expect(dataSource.endCallCount, 1);
      },
    );
  });

  // =========================================================================
  // Pre-join behaviour (owner, round 4)
  //
  // An empty participant list is ambiguous: "the peer left" or "the peer has
  // not joined the media yet". After the accept each side joins on its own
  // (the caller may still be on a permission prompt, then waits for the
  // Calls SDK, the token and the native join), so the first side in used to
  // see a list with only itself and end the call at once. The rule is armed
  // only once another participant has been seen: in a list, joining, or
  // leaving. There is no "peer never joined" timer (owner); the native 1:1
  // auto-end and the idle timeout remain the fallbacks.
  // =========================================================================

  group('pre-join behaviour: armed only once the peer was seen', () {
    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'P4-E13/P4-E90: an empty list before the peer was ever seen does not '
      'end the call',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(const ParticipantListChanged([]));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(ParticipantListChanged([_participant(_myUid)]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.endCallPresses, 0);
        expect(dataSource.endCallCount, 0);
        expect(bloc.state.status, OngoingCallStatus.active);
      },
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'P4-E90: the peer joining (onParticipantJoined) arms it: an empty list '
      'after that ends the call',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        _sdkParticipantJoined(_participant(_peerUid));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 1),
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'the logged-in user joining does not arm it',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        _sdkParticipantJoined(_participant(_myUid));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ParticipantListChanged([]));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 0),
    );

    blocTest<_SpyOngoingCallBloc, OngoingCallState>(
      'a peer leaving was in the session: it ends the call even with no list '
      'seen first',
      build: buildBloc,
      act: (bloc) async {
        await joined(bloc);
        bloc.add(ParticipantLeft(_participant(_peerUid)));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.endCallPresses, 1),
    );
  });
}
