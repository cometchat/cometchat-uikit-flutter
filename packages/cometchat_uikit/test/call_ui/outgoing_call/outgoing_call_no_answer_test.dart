/// The caller gives up on a call nobody answers (round 2, P2-C07).
///
/// The Dart SDK has no caller-side timer, so an unanswered call rang until
/// the caller tapped End. The outgoing call screen now sends `unanswered`
/// after 45 s (the owner's choice; the change text said 30 s) and closes,
/// as Android does when its SDK's timer fires.
///
/// Every test mounts the real CometChatOutgoingCall as a route and runs on
/// the test's fake clock: nothing waits 45 real seconds.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_no_answer_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/outgoing_call_launcher.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// The bloc behind the outgoing call screen on show.
OutgoingCallBloc _screenBloc() => CometChatCallEvents.callEventsListener.values
    .whereType<OutgoingCallBloc>()
    .single;

/// Closes [bloc] after the test, giving up after a second: a bloc made on
/// the test's fake clock may never finish closing on the real one, and a
/// failing test must not hang the run.
Future<void> _closeSoon(OutgoingCallBloc bloc) =>
    bloc.close().timeout(const Duration(seconds: 1), onTimeout: () {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    events = CallEventRecorder('outgoing_call_no_answer_test');
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    CallEventService.instance.activeCall = null;
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    ActiveCallTracker.outgoingCallTimeout = const Duration(seconds: 45);
  });

  /// Mounts the app with the real outgoing call screen on top, ringing.
  Future<void> ring(
    WidgetTester tester, {
    OnError? onError,
    OutgoingCallBloc? bloc,
    void Function(BuildContext, Call)? onCancelled,
  }) async {
    await mountCallNavigator(tester);
    CallEventService.instance.activeCall = buildCall();
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOutgoingCall(
            call: buildCall(),
            user: User(uid: 'peer', name: 'Peer'),
            onError: onError,
            onCancelled: onCancelled,
            bloc: bloc,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
  }

  List<String> unanswered() => dataSource.calls
      .where((String c) => c == 'rejectCall:session_1:unanswered')
      .toList();

  test('the caller gives up after 45 s', () {
    expect(ActiveCallTracker.outgoingCallTimeout, const Duration(seconds: 45));
  });

  testWidgets('P2-N08: nothing at 44 s; at 45 s the call is given up as '
      'unanswered and the screen closes', (WidgetTester tester) async {
    await ring(tester);

    await tester.pump(const Duration(seconds: 44));
    expect(dataSource.calls, isEmpty);
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(dataSource.calls, <String>['rejectCall:session_1:unanswered']);
    expect(events.ordered, <String>['rejected:session_1']);
    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(CallEventService.instance.activeCall, isNull);
    // The ringback stops with it.
    expect(
      SoundChannelSpy.methods.where((String m) => m.endsWith('CallTone')),
      <String>['playCallTone', 'stopCallTone'],
    );
  });

  testWidgets('an accept whose permission prompt is still up at 45 s is not '
      'given up on', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;

    await tester.pump(const Duration(seconds: 10));
    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();
    expect(_screenBloc().state.status, OutgoingCallStatus.accepted);

    await tester.pump(const Duration(seconds: 40));
    expect(unanswered(), isEmpty);

    PermissionChannelStub.install(granted: false);
    prompt.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a decline at 10 s stops the timer', (WidgetTester tester) async {
    // A bloc of the test's own: the screen does not close it, so a timer
    // left running would still be pending when the test ends.
    final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
    addTearDown(() => _closeSoon(bloc));
    await ring(tester, bloc: bloc);

    await tester.pump(const Duration(seconds: 10));
    bloc.onOutgoingCallRejected(buildCall());
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(bloc.state.status, OutgoingCallStatus.rejected);
  });

  testWidgets('End at 10 s stops the timer', (WidgetTester tester) async {
    final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
    addTearDown(() => _closeSoon(bloc));
    await ring(tester, bloc: bloc);

    await tester.pump(const Duration(seconds: 10));
    bloc.add(const CancelCall());
    await tester.pumpAndSettle();

    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
    expect(find.byType(CometChatOutgoingCall), findsNothing);
  });

  testWidgets('a logout closing the screen stops the timer and the '
      'ringback', (WidgetTester tester) async {
    final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
    addTearDown(() => _closeSoon(bloc));
    await ring(tester, bloc: bloc);
    SoundChannelSpy.methods.clear();

    // What CallsLifecycle.tearDownLocalCalls does to an outgoing screen.
    ActiveCallTracker.closeOutgoingScreens();
    await tester.pumpAndSettle();
    expect(SoundChannelSpy.methods, <String>['stopCallTone']);

    await tester.pump(const Duration(seconds: 45));
    expect(dataSource.calls, isEmpty);
  });

  testWidgets('the unanswered reject fails: onError gets the SDK code, a '
      'best-effort endCall goes out, and the screen still closes', (
    WidgetTester tester,
  ) async {
    final CometChatException sdkError = CometChatException(
      'ERR_CALL_ACCEPTED',
      'The call was already accepted.',
      'Call already accepted',
    );
    dataSource.rejectError = CallOperationsException(
      message: 'Call already accepted',
      code: 'ERR_CALL_ACCEPTED',
      originalException: sdkError,
    );
    final List<Exception> errors = <Exception>[];
    await ring(tester, onError: errors.add);

    await tester.pump(const Duration(seconds: 45));
    await tester.pumpAndSettle();

    expect(dataSource.calls, <String>[
      'rejectCall:session_1:unanswered',
      'endCall:session_1',
    ]);
    expect(errors.single, same(sdkError));
    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(CallEventService.instance.activeCall, isNull);
  });

  testWidgets("a host's onCancelledCallTap that took End over but left the "
      'call ringing: still given up at 45 s', (WidgetTester tester) async {
    int taps = 0;
    await ring(tester, onCancelled: (BuildContext _, Call _) => taps++);

    await tester.pump(const Duration(seconds: 5));
    _screenBloc().add(const CancelCall());
    await tester.pump();
    expect(taps, 1);
    expect(dataSource.calls, isEmpty);

    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();

    expect(dataSource.calls, <String>['rejectCall:session_1:unanswered']);
    expect(find.byType(CometChatOutgoingCall), findsNothing);
  });

  // Round 2 review: an app in the background right after placing a call
  // builds the outgoing screen only when it comes back; its timer used to
  // start then.
  group('counted from the placement (round 2 review)', () {
    late DateTime clock;

    setUp(() {
      clock = DateTime(2026, 10, 1, 12);
      ActiveCallTracker.now = () => clock;
    });

    tearDown(() => ActiveCallTracker.now = DateTime.now);

    Future<void> ringFor(WidgetTester tester, Call call) async {
      await mountCallNavigator(tester);
      CallEventService.instance.activeCall = call;
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => CometChatOutgoingCall(call: call),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a screen built 40 s after the placement gives up 5 s later', (
      WidgetTester tester,
    ) async {
      final Call call = buildCall();
      ActiveCallTracker.markPlaced(call);
      clock = clock.add(const Duration(seconds: 40));
      await ringFor(tester, call);

      await tester.pump(const Duration(seconds: 4));
      expect(unanswered(), isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(unanswered(), hasLength(1));
      expect(find.byType(CometChatOutgoingCall), findsNothing);
    });

    testWidgets(
      'a screen built after the timeout has passed gives up at once',
      (WidgetTester tester) async {
        final Call call = buildCall();
        ActiveCallTracker.markPlaced(call);
        clock = clock.add(const Duration(minutes: 2));
        await ringFor(tester, call);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(unanswered(), hasLength(1));
      },
    );

    testWidgets('a call the UI Kit did not place gets the whole 45 s', (
      WidgetTester tester,
    ) async {
      await ringFor(tester, buildCall());
      clock = clock.add(const Duration(minutes: 2));

      await tester.pump(const Duration(seconds: 44));
      expect(unanswered(), isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(unanswered(), hasLength(1));
    });
  });

  testWidgets('the launcher records when the call was placed', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    DateTime clock = DateTime(2026, 10, 1, 12);
    ActiveCallTracker.now = () => clock;
    addTearDown(() => ActiveCallTracker.now = DateTime.now);
    final Call call = buildCall();

    unawaited(OutgoingCallLauncher.show(call, epoch: CallsLifecycle.callEpoch));
    clock = clock.add(const Duration(seconds: 30));

    expect(
      ActiveCallTracker.remainingOf(call, const Duration(seconds: 45)),
      const Duration(seconds: 15),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a shorter timeout (tests) is honoured', (
    WidgetTester tester,
  ) async {
    ActiveCallTracker.outgoingCallTimeout = const Duration(seconds: 3);
    await ring(tester);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(unanswered(), hasLength(1));
  });

  testWidgets('with the timeout off, it rings until something ends it', (
    WidgetTester tester,
  ) async {
    ActiveCallTracker.outgoingCallTimeout = null;
    final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
    addTearDown(() => _closeSoon(bloc));
    await ring(tester, bloc: bloc);

    await tester.pump(const Duration(minutes: 5));

    expect(dataSource.calls, isEmpty);
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
  });
  // Round 2 review (probe B): a logout cancels a ringing call itself, and
  // anything the screen sends after it began goes out as a user on their
  // way out, or as the next one.
  testWidgets('the timer firing while a logout cleans up sends no second '
      'request (round 2 review)', (WidgetTester tester) async {
    addTearDown(CallsLifecycle.debugReset);
    ActiveCallTracker.outgoingCallTimeout = const Duration(seconds: 3);
    final List<Exception> errors = <Exception>[];
    await ring(tester, onError: errors.add);
    await tester.pump(const Duration(seconds: 2));
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;

    unawaited(CallsLifecycle.prepareForLogout());
    await tester.pump();
    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);

    // The timer fires while the logout's cancel is still in flight.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);

    server.complete();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(errors, isEmpty);
  });
  // Round 2 review (probe A): a bloc the host hands the screen outlives it.
  group('a host bloc whose screen has gone (round 2 review)', () {
    /// Mounts the app with a conversation, and the outgoing screen driven
    /// by [bloc] on top of it.
    Future<void> ringOverConversation(
      WidgetTester tester,
      OutgoingCallBloc bloc,
    ) async {
      await mountCallNavigator(tester);
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('conversation')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CometChatOutgoingCall(call: buildCall(), bloc: bloc),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
    }

    testWidgets('a host onCancelled that closes the screen: 45 s later '
        'nothing is sent, the ringback has stopped, and the host\'s screen '
        'stays', (WidgetTester tester) async {
      final List<Exception> errors = <Exception>[];
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        errorCallback: errors.add,
        onCancelledCallTap: (BuildContext context, Call _) {
          dataSource.calls.add('host-cancel');
          Navigator.of(context).pop();
        },
      );
      addTearDown(() => _closeSoon(bloc));
      await ringOverConversation(tester, bloc);
      SoundChannelSpy.methods.clear();

      bloc.add(const CancelCall());
      await tester.pumpAndSettle();
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(find.text('conversation'), findsOneWidget);
      // The screen went: its ringback with it.
      expect(SoundChannelSpy.methods, <String>['stopCallTone']);

      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      expect(dataSource.calls, <String>['host-cancel']);
      expect(find.text('conversation'), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('a rejection after the host popped the screen closes '
        'nothing else', (WidgetTester tester) async {
      ActiveCallTracker.outgoingCallTimeout = null;
      final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
      addTearDown(() => _closeSoon(bloc));
      await ringOverConversation(tester, bloc);

      CallNavigationContext.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('conversation'), findsOneWidget);

      bloc.onOutgoingCallRejected(buildCall());
      await tester.pumpAndSettle();

      expect(find.text('conversation'), findsOneWidget);
      expect(bloc.state.status, OutgoingCallStatus.rejected);
    });
  });
}
