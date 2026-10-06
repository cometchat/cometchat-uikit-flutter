/// Regression tests for ENG-39486 — after the callee declined, tapping End on
/// the caller's screen raised "Something went wrong".
///
/// Measured against the Kotlin UIKit (v6 / dev-v6), which this now follows:
///
/// * A decline disables End. It used to leave End live for the whole close
///   transition, so a tap sent a cancel for a call that was already over.
/// * A cancel that fails closes the screen quietly (or hands the error to the
///   app's onError). It used to raise a red snackbar about a call that had
///   simply finished.
/// * The screen closes once, and only itself. Two close paths could race and
///   each did a bare Navigator.pop, so the second popped the chat underneath.
/// * A server-ended call (unanswered, busy, system) for this session closes
///   the screen; one for a different session does not.
/// * A decline or busy that the chat SDK delivers as onIncomingCallCancelled
///   (it does, for every 1-on-1 decline) closes the screen like a rejection.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_decline_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart'
    show NullSessionCall, SoundChannelSpy;

/// Only rejectCall is reachable from the paths under test; anything else
/// throws, so a change that widens the path fails loudly.
class _FakeDataSource extends Fake implements CallOperationsDataSource {
  int rejectCalls = 0;
  bool fail = false;

  @override
  Future<void> waitForCallsSdk() async {}

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    rejectCalls++;
    if (fail) {
      throw CometChatException('ERR_CALL_ENDED', 'The call is ended', '');
    }
    return _call(status: status);
  }
}

Call _call({String session = 'session_1', String status = 'initiated'}) => Call(
  id: 42,
  sessionId: session,
  callStatus: status,
  receiverUid: 'peer',
  type: 'audio',
  receiverType: 'user',
);

OutgoingCallBloc _bloc({List<Exception>? errors}) => OutgoingCallBloc(
  call: _call(),
  disableSoundForCalls: true,
  errorCallback: errors == null ? null : (e) => errors.add(e),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

/// Pushes a stand-in outgoing screen over a stand-in chat and hands the
/// bloc that route — what CometChatOutgoingCall does in didChangeDependencies.
/// With [sound], the bloc plays its ringback.
///
/// The app's navigator is `CallNavigationContext.navigatorKey`, as in a host
/// app, so a call screen the bloc wrongly opened would really show
/// (`CallScreenOverlay.isShowing`) instead of failing for want of an
/// overlay.
Future<(OutgoingCallBloc, GlobalKey<NavigatorState>)> pushOutgoing(
  WidgetTester tester, {
  bool dialogOnTop = false,
  bool sound = false,
}) async {
  final navigatorKey = CallNavigationContext.navigatorKey;
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('chat')),
    ),
  );
  final route = MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('outgoing')),
  );
  // Pushed routes complete only when popped, so nothing awaits them.
  unawaited(navigatorKey.currentState!.push(route));
  await tester.pumpAndSettle();
  if (dialogOnTop) {
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('dialog')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
  final bloc = sound ? OutgoingCallBloc(call: _call()) : _bloc();
  ActiveCallTracker.attachOutgoingCallRoute(bloc, route);
  return (bloc, navigatorKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _FakeDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  group('the callee declines', () {
    test(
      'End goes dead, so the caller cannot cancel a finished call',
      () async {
        final bloc = _bloc();

        bloc.onOutgoingCallRejected(_call(status: 'rejected'));
        await _settle();
        expect(bloc.state.status, OutgoingCallStatus.rejected);
        expect(
          bloc.state.isCallRejected,
          isTrue,
          reason: 'isCallRejected is what disables End',
        );

        // The tap QA made after the decline.
        bloc.add(const CancelCall());
        await _settle();
        expect(
          dataSource.rejectCalls,
          0,
          reason:
              'a cancel for an already-declined call is what the server '
              'refused, raising "Something went wrong" — ENG-39486',
        );
        await bloc.close();
      },
    );
  });

  // The chat SDK takes a realtime call's callInitiator from whoever performed
  // the action, so on a decline it names the callee. Its dispatch then decides
  // the caller is not the initiator and delivers the decline (and busy) as
  // onIncomingCallCancelled — never onOutgoingCallRejected, which the group
  // above drives. On device that left the caller on "Calling…" after the
  // callee had declined.
  group('the decline as the chat SDK delivers it', () {
    for (final status in ['rejected', 'busy']) {
      test(
        '$status arriving as onIncomingCallCancelled closes the screen',
        () async {
          final bloc = _bloc();

          bloc.onIncomingCallCancelled(_call(status: status));
          await _settle();

          expect(bloc.state.status, OutgoingCallStatus.rejected);
          expect(bloc.state.isCallRejected, isTrue);

          bloc.add(const CancelCall());
          await _settle();
          expect(
            dataSource.rejectCalls,
            0,
            reason: 'End must be dead once the callee has declined',
          );
          await bloc.close();
        },
      );
    }

    test('a cancel for a different call leaves this one alone', () async {
      final bloc = _bloc();

      bloc.onIncomingCallCancelled(
        _call(session: 'someone_elses', status: 'rejected'),
      );
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(bloc.state.isCallRejected, isFalse);
      await bloc.close();
    });

    test('the echo of our own cancel changes nothing', () async {
      // Cancelling sends 'cancelled', which the SDK also delivers back here
      // as onIncomingCallCancelled for this session.
      final bloc = _bloc();

      bloc.add(const CancelCall());
      await _settle();
      final afterCancel = bloc.state;

      bloc.onIncomingCallCancelled(_call(status: 'cancelled'));
      await _settle();

      expect(bloc.state, afterCancel);
      expect(dataSource.rejectCalls, 1);
      await bloc.close();
    });
  });

  // Round 2, P2-C05: the chat SDK hands onOutgoingCallRejected and
  // onOutgoingCallAccepted to every call listener, so each is only this
  // screen's business when it is about this screen's call.
  group('accept and reject for another call (round 2, P2-C05)', () {
    setUp(SoundChannelSpy.install);
    tearDown(() {
      SoundChannelSpy.remove();
      CallEventService.instance.activeCall = null;
    });

    testWidgets('a rejection of another call leaves the screen, its record '
        'and its ringback alone', (tester) async {
      final (bloc, _) = await pushOutgoing(tester, sound: true);
      CallEventService.instance.activeCall = _call();
      SoundChannelSpy.methods.clear();

      await tester.runAsync(() async {
        bloc.onOutgoingCallRejected(
          _call(session: 'someone_elses', status: 'busy'),
        );
        await _settle();
      });
      await tester.pumpAndSettle();

      expect(find.text('outgoing'), findsOneWidget);
      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(bloc.state.isCallRejected, isFalse);
      expect(
        (CallEventService.instance.activeCall as Call?)?.sessionId,
        'session_1',
      );
      expect(SoundChannelSpy.methods, isNot(contains('stopCallTone')));
      await tester.runAsync(bloc.close);
    });

    testWidgets('an accept of another call opens no call screen', (
      tester,
    ) async {
      final (bloc, _) = await pushOutgoing(tester);

      await tester.runAsync(() async {
        bloc.onOutgoingCallAccepted(
          _call(session: 'someone_elses', status: 'ongoing'),
        );
        await _settle();
      });
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(find.text('outgoing'), findsOneWidget);
      await tester.runAsync(bloc.close);
    });

    test('with no session of its own, no callback is this call\'s', () async {
      final bloc = OutgoingCallBloc(
        call: NullSessionCall(),
        disableSoundForCalls: true,
      );

      bloc.onOutgoingCallRejected(_call(status: 'rejected'));
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.idle);
      await bloc.close();
    });

    // Round 2 review (R11): two unknown sessions are not the same call.
    test('with no session of its own, a callback with no session either is '
        'not this call\'s', () async {
      final bloc = OutgoingCallBloc(
        call: NullSessionCall(),
        disableSoundForCalls: true,
      );

      bloc
        ..onOutgoingCallRejected(NullSessionCall())
        ..onCallEndedMessageReceived(NullSessionCall())
        ..onIncomingCallCancelled(NullSessionCall());
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(bloc.state.isCallRejected, isFalse);
      await bloc.close();
    });
  });

  group('the caller taps End', () {
    test(
      'a failed cancel closes quietly instead of raising an error',
      () async {
        final errors = <Exception>[];
        final bloc = _bloc(errors: errors);
        dataSource.fail = true;

        bloc.add(const CancelCall());
        await _settle();

        expect(
          bloc.state.status,
          OutgoingCallStatus.rejected,
          reason:
              'status error is what the screen turns into the red snackbar; a '
              'failed cancel is a call that already finished',
        );
        expect(bloc.state.isCallRejected, isTrue);
        expect(
          errors,
          hasLength(1),
          reason: "the app's own onError still hears about it, as in Kotlin",
        );
        await bloc.close();
      },
    );

    test('End stays dead after a cancel, so a second tap is ignored', () async {
      final bloc = _bloc();

      bloc.add(const CancelCall());
      await _settle();
      bloc.add(const CancelCall());
      await _settle();

      expect(dataSource.rejectCalls, 1);
      expect(bloc.state.isCallRejected, isTrue);
      await bloc.close();
    });
  });

  group('the server ends the call (unanswered, busy, system)', () {
    test('this call ending closes the screen', () async {
      final bloc = _bloc();

      bloc.onCallEndedMessageReceived(_call(status: 'unanswered'));
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.rejected);
      expect(bloc.state.isCallRejected, isTrue);
      await bloc.close();
    });

    test('a different call ending leaves this one alone', () async {
      final bloc = _bloc();

      bloc.onCallEndedMessageReceived(
        _call(session: 'someone_elses_call', status: 'ended'),
      );
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(bloc.state.isCallRejected, isFalse);
      await bloc.close();
    });
  });

  group('closing the screen', () {
    testWidgets('two close paths racing pop the screen once, not the chat', (
      tester,
    ) async {
      final (bloc, _) = await pushOutgoing(tester);

      // The callee declines, and a server-ended event for the same call
      // arrives too — both close the screen.
      await tester.runAsync(() async {
        bloc.onOutgoingCallRejected(_call(status: 'rejected'));
        bloc.onCallEndedMessageReceived(_call(status: 'ended'));
        await _settle();
      });
      await tester.pumpAndSettle();

      expect(find.text('outgoing'), findsNothing);
      expect(
        find.text('chat'),
        findsOneWidget,
        reason: 'a second bare Navigator.pop used to take the chat with it',
      );
      await tester.runAsync(bloc.close);
    });

    testWidgets('with something pushed on top, only this screen is removed', (
      tester,
    ) async {
      final (bloc, _) = await pushOutgoing(tester, dialogOnTop: true);

      await tester.runAsync(() async {
        bloc.onOutgoingCallRejected(_call(status: 'rejected'));
        await _settle();
      });
      await tester.pumpAndSettle();

      expect(find.text('dialog'), findsOneWidget, reason: 'not ours to close');
      // skipOffstage: false — the screen sits under the dialog, so the default
      // finder would miss it whether or not it was removed.
      expect(find.text('outgoing', skipOffstage: false), findsNothing);
      expect(find.text('chat', skipOffstage: false), findsOneWidget);
      await tester.runAsync(bloc.close);
    });
  });
}
