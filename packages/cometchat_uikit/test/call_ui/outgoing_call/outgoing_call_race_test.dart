/// End (or the no-answer timeout) racing an accept, and a cancel the server
/// is slow to answer (round 2, P2-C08).
///
/// The owner's rules:
///  * End wins: once End was tapped or the timer fired, an accept for this
///    call is not joined, and a best-effort endCall lets the callee go.
///  * Every failed cancel or `unanswered` reject sends that endCall too, and
///    still reaches onError with the SDK's code (report everything).
///  * The screen closes on the cancel's answer or after 10 s at most; the
///    request carries on, and what it comes to is still handled.
///
/// Every test mounts the real CometChatOutgoingCall as a route and runs on
/// the test's fake clock.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_race_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// The bloc behind the outgoing call screen on show.
OutgoingCallBloc _screenBloc() => CometChatCallEvents.callEventsListener.values
    .whereType<OutgoingCallBloc>()
    .single;

final CometChatException _alreadyAccepted = CometChatException(
  'ERR_CALL_ACCEPTED',
  'The call was already accepted.',
  'Call already accepted',
);

/// Closes [bloc] after the test, giving up after a second: a bloc made on
/// the test's fake clock may never finish closing on the real one, and a
/// failing test must not hang the run.
Future<void> _closeSoon(OutgoingCallBloc bloc) =>
    bloc.close().timeout(const Duration(seconds: 1), onTimeout: () {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;
  late List<Exception> errors;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    events = CallEventRecorder('outgoing_call_race_test');
    errors = <Exception>[];
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    CallEventService.instance.activeCall = null;
    CallScreenOverlay.dismiss();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Mounts the app with the real outgoing call screen on top, ringing.
  Future<void> ring(WidgetTester tester, {OutgoingCallBloc? bloc}) async {
    await mountCallNavigator(tester);
    CallEventService.instance.activeCall = buildCall();
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOutgoingCall(
            call: buildCall(),
            user: User(uid: 'peer', name: 'Peer'),
            onError: errors.add,
            bloc: bloc,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
  }

  int count(String call) =>
      dataSource.calls.where((String c) => c == call).length;

  bool onlyTheChatLeft() =>
      find.byType(CometChatOutgoingCall).evaluate().isEmpty &&
      find.text('chat').evaluate().isNotEmpty &&
      !CallNavigationContext.navigatorKey.currentState!.canPop();

  testWidgets('P2-E04: End, then the accept while the cancel is in flight: '
      'not joined, the callee is freed, and the screen closes once when the '
      'cancel is answered', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    _screenBloc().add(const CancelCall());
    await tester.pump();
    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(PermissionChannelStub.requested, isEmpty, reason: 'nothing joins');
    expect(count('endCall:session_1'), 1);
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);

    server.complete();
    await tester.pumpAndSettle();

    expect(onlyTheChatLeft(), isTrue);
    expect(events.ordered, containsAll(<String>['rejected:session_1']));
    expect(errors, isEmpty);
  });

  testWidgets('P2-E04: the cancel fails because the callee won: the callee '
      'is freed once, and onError hears the SDK code', (
    WidgetTester tester,
  ) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource
      ..rejectGate = server
      ..rejectError = CallOperationsException(
        message: 'Call already accepted',
        code: 'ERR_CALL_ACCEPTED',
        originalException: _alreadyAccepted,
      );

    _screenBloc().add(const CancelCall());
    await tester.pump();
    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();
    server.complete();
    await tester.pumpAndSettle();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(count('endCall:session_1'), 1);
    expect(errors.single, same(_alreadyAccepted));
    expect(onlyTheChatLeft(), isTrue);
    expect(CallEventService.instance.activeCall, isNull);
  });

  testWidgets('a failed cancel frees the callee even when no accept arrives', (
    WidgetTester tester,
  ) async {
    await ring(tester);
    dataSource.rejectError = CallOperationsException(
      message: 'Call already accepted',
      code: 'ERR_CALL_ACCEPTED',
      originalException: _alreadyAccepted,
    );

    _screenBloc().add(const CancelCall());
    await tester.pumpAndSettle();

    expect(dataSource.calls, <String>[
      'rejectCall:session_1:cancelled',
      'endCall:session_1',
    ]);
    expect(errors.single, same(_alreadyAccepted));
    expect(onlyTheChatLeft(), isTrue);
  });

  testWidgets('P2-E35: the server never answers the cancel: the ringback '
      'stops at once, the screen closes after 10 s and the record is '
      'released', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;
    SoundChannelSpy.methods.clear();

    _screenBloc().add(const CancelCall());
    await tester.pump();
    expect(SoundChannelSpy.methods, <String>['stopCallTone']);

    await tester.pump(const Duration(seconds: 9));
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
    expect(CallEventService.instance.activeCall, isNotNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);
    expect(CallEventService.instance.activeCall, isNull);
    expect(errors, isEmpty);

    // It finally goes through: announced as ever.
    server.complete();
    await tester.pumpAndSettle();
    expect(events.ordered, <String>['rejected:session_1']);
  });

  testWidgets('a cancel that fails after the 10 s close still reaches '
      'onError and frees the callee (owner: report everything)', (
    WidgetTester tester,
  ) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource
      ..rejectGate = server
      ..rejectError = CallOperationsException(
        message: 'Call already accepted',
        code: 'ERR_CALL_ACCEPTED',
        originalException: _alreadyAccepted,
      );

    _screenBloc().add(const CancelCall());
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);
    expect(errors, isEmpty);

    server.complete();
    await tester.pumpAndSettle();

    expect(errors.single, same(_alreadyAccepted));
    expect(count('endCall:session_1'), 1);
  });

  testWidgets('an accept after the 10 s close is not joined either', (
    WidgetTester tester,
  ) async {
    // A bloc of the test's own, which the screen does not close: it still
    // hears the SDK after its screen has gone.
    final OutgoingCallBloc bloc = OutgoingCallBloc(
      call: buildCall(),
      errorCallback: errors.add,
    );
    addTearDown(() => _closeSoon(bloc));
    await ring(tester, bloc: bloc);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    bloc.add(const CancelCall());
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);

    bloc.onOutgoingCallAccepted(buildCall());
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(count('endCall:session_1'), 1);

    server.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the no-answer timeout, then the accept: not joined, the '
      'callee is freed', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    await tester.pump(const Duration(seconds: 45));
    expect(count('rejectCall:session_1:unanswered'), 1);
    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(count('endCall:session_1'), 1);

    server.complete();
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);
  });

  // The chat SDK hands the caller a 1-on-1 decline as
  // onIncomingCallCancelled (it takes the callee, who acted, for the
  // initiator): that is the callback a real decline arrives on.
  testWidgets('P2-E05: End and a decline together: the decline closes the '
      'screen at once; the cancel that then fails reaches onError, and no '
      'endCall goes out', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    final CometChatException rejected = CometChatException(
      'ERR_CALL_REJECTED',
      'The call was already rejected.',
      'Call already rejected',
    );
    dataSource
      ..rejectGate = server
      ..rejectError = CallOperationsException(
        message: 'Call already rejected',
        code: 'ERR_CALL_REJECTED',
        originalException: rejected,
      )
      ..endCallError = const CallOperationsException(message: 'not ongoing');

    _screenBloc().add(const CancelCall());
    await tester.pump();
    _screenBloc().onIncomingCallCancelled(
      buildCall()..callStatus = CallStatusConstants.rejected,
    );
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);

    server.complete();
    await tester.pumpAndSettle();
    expect(errors.single, same(rejected));
    expect(count('endCall:session_1'), 0);
  });

  testWidgets('End, then our own cancel coming back: nothing changes until '
      'the cancel is answered', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    _screenBloc().add(const CancelCall());
    await tester.pump();
    _screenBloc().onIncomingCallCancelled(
      buildCall()..callStatus = CallStatusConstants.cancelled,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);

    server.complete();
    await tester.pumpAndSettle();
    expect(onlyTheChatLeft(), isTrue);
    expect(errors, isEmpty);
  });

  // Owner decision (round 2 review): a screen that went away is not the
  // user hanging up, so no endCall follows its failed cancel, whatever the
  // reason it failed; only End and the no-answer timeout free the callee.
  testWidgets('a screen removed while ringing whose cancel fails sends no '
      'endCall; onError hears the SDK code', (WidgetTester tester) async {
    await ring(tester);
    dataSource.rejectError = CallOperationsException(
      message: 'Call already accepted',
      code: 'ERR_CALL_ACCEPTED',
      originalException: _alreadyAccepted,
    );

    // A host's own navigation takes the screen away.
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('elsewhere')),
        ),
        (Route<dynamic> _) => false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);

    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
    expect(errors.single, same(_alreadyAccepted));
    expect(CallEventService.instance.activeCall, isNull);
  });

  testWidgets('a screen removed while its cancel is in flight leaves no '
      'timer behind', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    _screenBloc().add(const CancelCall());
    await tester.pump();
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('elsewhere')),
        ),
        (Route<dynamic> _) => false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOutgoingCall), findsNothing);
    // Its cancel is already on its way: no second one. It is left
    // unanswered, so any timer the closed screen left running would still
    // be pending when the test ends.
    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
    expect(server.isCompleted, isFalse);
  });

  test('the screen closes 10 s after a cancel at the latest', () {
    expect(
      ActiveCallTracker.outgoingEndCloseAfter,
      const Duration(seconds: 10),
    );
  });
  // Round 2 review: a request still in flight when a logout begins lands
  // after it (a slow network retries for up to a minute). The logout owns
  // the call by then: nothing more is sent, and nothing reaches onError.
  group('a logout while End is in flight (round 2 review)', () {
    setUp(() {
      dataSource.rejectError = CallOperationsException(
        message: 'Call already accepted',
        code: 'ERR_CALL_ACCEPTED',
        originalException: _alreadyAccepted,
      );
    });
    tearDown(CallsLifecycle.debugReset);

    testWidgets('the cancel failing after the logout began: no endCall, no '
        'onError', (WidgetTester tester) async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        errorCallback: errors.add,
      );
      addTearDown(() => _closeSoon(bloc));
      await ring(tester, bloc: bloc);
      // Placed and not answered: the logout cancels it (an endCall would be
      // the logout's own, for an answered call).
      CallEventService.instance.activeCall = buildCall()
        ..callStatus = CallStatusConstants.initiated;
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;

      bloc.add(const CancelCall());
      await tester.pump();
      unawaited(CallsLifecycle.prepareForLogout());
      await tester.pump();
      server.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(count('endCall:session_1'), 0);
      expect(errors, isEmpty);
    });

    testWidgets('an accept after End once the logout began: no endCall', (
      WidgetTester tester,
    ) async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        errorCallback: errors.add,
      );
      addTearDown(() => _closeSoon(bloc));
      await ring(tester, bloc: bloc);
      // Placed and not answered: the logout cancels it (an endCall would be
      // the logout's own, for an answered call).
      CallEventService.instance.activeCall = buildCall()
        ..callStatus = CallStatusConstants.initiated;
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;

      bloc.add(const CancelCall());
      await tester.pump();
      unawaited(CallsLifecycle.prepareForLogout());
      await tester.pump();
      bloc.onOutgoingCallAccepted(buildCall());
      await tester.pump();

      expect(count('endCall:session_1'), 0);
      expect(CallScreenOverlay.isShowing, isFalse);
      server.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(count('endCall:session_1'), 0);
      expect(errors, isEmpty);
    });

    testWidgets('an accept while the logout cleans up is not joined', (
      WidgetTester tester,
    ) async {
      dataSource.rejectError = null;
      await ring(tester);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;

      unawaited(CallsLifecycle.prepareForLogout());
      await tester.pump();
      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();

      expect(PermissionChannelStub.requested, isEmpty);
      expect(CallScreenOverlay.isShowing, isFalse);
      server.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(errors, isEmpty);
    });

    testWidgets('a logout beginning during the accept\'s permission prompt: '
        'not joined', (WidgetTester tester) async {
      dataSource.rejectError = null;
      await ring(tester);
      final Completer<void> prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      // The logout's clean-up (it ends the call, answered by now) is still
      // running when the prompt is answered.
      final Completer<void> cleanUp = Completer<void>();
      dataSource.endCallGate = cleanUp;

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();
      expect(PermissionChannelStub.requested, isNotEmpty);
      unawaited(CallsLifecycle.prepareForLogout());
      await tester.pump();
      prompt.complete();
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      cleanUp.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(errors, isEmpty);
    });

    testWidgets('a lost screen\'s cancel failing after the logout began '
        'reaches no onError', (WidgetTester tester) async {
      await ring(tester);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;

      unawaited(
        CallNavigationContext.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('elsewhere')),
          ),
          (Route<dynamic> _) => false,
        ),
      );
      await tester.pumpAndSettle();
      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);

      unawaited(CallsLifecycle.prepareForLogout());
      await tester.pump();
      server.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
    });
  });
}
