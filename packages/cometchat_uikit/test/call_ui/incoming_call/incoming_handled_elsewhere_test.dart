/// An incoming call answered, declined or bounced busy on another device of
/// the same user stops ringing here (round 3: P3-C08, and the review's
/// "ringing record without a live bloc").
///
/// Before: with B logged in on two devices, answering or declining on one
/// left the other ringing; after "rejected" its record was released while
/// the banner stayed, and after "ongoing" a record with no banner stayed,
/// so every later call was answered busy.
///
/// The Dart SDK delivers that "ongoing" / "rejected" / "busy" to the user's
/// devices as onOutgoingCallAccepted / onOutgoingCallRejected (the server
/// names the actor as the initiator), and these tests drive those
/// callbacks. Whether the server sends them to the user's other devices at
/// all is a device check (P3-E32, P3-E33).
///
///   flutter test test/call_ui/incoming_call/incoming_handled_elsewhere_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    CometChatUIKit.loggedInUser = testMe;
  });

  tearDown(() async {
    CometChatUIKit.loggedInUser = null;
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  /// Closes [bloc] at the end of the test, after opening every gate a test
  /// may have left shut (an expectation that failed before the test opened
  /// it). Not awaited, and nothing is lost by that: the bloc's close() does
  /// what matters (listeners, timer, the ringtone) before its first await,
  /// and bloc 9.2.1's close() does not wait for a handler in flight (it
  /// cancels the handler's emitter). A handler that never finishes is caught
  /// by the file's timeout instead.
  void closeAtEnd(IncomingCallBloc bloc) {
    addTearDown(() {
      for (final Completer<void>? gate in <Completer<void>?>[
        dataSource.acceptGate,
        dataSource.rejectGate,
        PermissionChannelStub.gate,
      ]) {
        if (gate != null && !gate.isCompleted) gate.complete();
      }
      unawaited(bloc.close());
    });
  }

  Future<void> showBanner(WidgetTester tester, Call call) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: const SizedBox.shrink(),
      ),
    );
    ActiveCallTracker.ringingCall = call;
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: call,
    );
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
  }

  for (final String event in <String>['ongoing', 'rejected']) {
    void deliver(Call call) => event == 'ongoing'
        ? service.onOutgoingCallAccepted(call)
        : service.onOutgoingCallRejected(call);

    // The user's own action on another device: the server names them as
    // the actor.
    void deliverByMe(Call call) => deliver(byMe(call));

    final String row = event == 'ongoing' ? 'P3-E32' : 'P3-E33';

    testWidgets('$row: "$event" for the call ringing here closes its banner, '
        'stops the ringtone and releases it; nothing is sent', (
      WidgetTester tester,
    ) async {
      final Call ringing = buildCall();
      await showBanner(tester, ringing);
      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      SoundChannelSpy.methods.clear();

      deliverByMe(buildCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.incomingCallSessionId, isNull);
      expect(SoundChannelSpy.methods, contains('stopRingtone'));
      expect(dataSource.calls, isEmpty);
    });

    test('$row: "$event" for a ringing record with no banner (no bloc) '
        'releases it, so the next call is not answered busy', () {
      ActiveCallTracker.ringingCall = buildCall();

      deliverByMe(buildCall());

      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.isBusy, isFalse);
    });

    test('$row: "$event" for another call leaves the ringing one', () {
      ActiveCallTracker.ringingCall = buildCall();

      deliverByMe(buildCall(sessionId: 'someone_else'));

      expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1');
    });

    testWidgets('$row: "$event" while this device answers or declines the '
        'call is its own echo: the banner stays for the bloc to close', (
      WidgetTester tester,
    ) async {
      await showBanner(tester, buildCall());
      ActiveCallTracker.respondingTo('session_1');
      addTearDown(() => ActiveCallTracker.doneResponding('session_1'));

      deliverByMe(buildCall());
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      expect(ActiveCallTracker.incomingCallSessionId, 'session_1');
      if (event == 'ongoing') {
        // An accept turns the ringing call into the active one itself.
        expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1');
      }
      IncomingCallOverlay.dismiss();
      await tester.pump();
    });
  }

  // Round 3 review: in a group call, every member gets the "ongoing" of
  // whoever joins. It released every other member's ringing record and
  // closed their banner. ("Rejected" by someone else never reaches these
  // callbacks: the SDK sends it there only when the logged-in user acted.)
  testWidgets('"ongoing" for a group call ringing here, by another member, '
      'leaves its banner and its record', (WidgetTester tester) async {
    final Call group = buildCall(receiverType: ReceiverTypeConstants.group);
    await showBanner(tester, group);

    service.onOutgoingCallAccepted(
      byOther(buildCall(receiverType: ReceiverTypeConstants.group)),
    );
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.byType(CometChatIncomingCall), findsOneWidget);
    expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1');
    expect(ActiveCallTracker.incomingCallSessionId, 'session_1');
    IncomingCallOverlay.dismiss();
    await tester.pump();
  });

  test('"ongoing" by another member, for a group call\'s ringing record '
      'with no banner, leaves the record', () {
    ActiveCallTracker.ringingCall = buildCall(
      receiverType: ReceiverTypeConstants.group,
    );

    service.onOutgoingCallAccepted(
      byOther(buildCall(receiverType: ReceiverTypeConstants.group)),
    );

    expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1');
  });

  // Round 3 review: the mark used to start at the tap. While the
  // permission prompt was up, the same user answering on another device was
  // taken for this device's own echo, and the accept went out after the
  // prompt for a call already answered.
  test('an accept marks the call as this device\'s own from its request, '
      'not during the permission prompt, until it lands', () async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    final Completer<void> server = Completer<void>();
    dataSource.acceptGate = server;
    dataSource.acceptError = const CallOperationsException(message: 'down');
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    closeAtEnd(bloc);

    bloc.add(const AcceptCall());
    await pumpEventQueue();
    expect(ActiveCallTracker.isRespondingTo('session_1'), isFalse);
    prompt.complete();
    await pumpEventQueue();
    expect(dataSource.acceptCallCount, 1);
    expect(ActiveCallTracker.isRespondingTo('session_1'), isTrue);
    server.complete();
    await pumpEventQueue();

    expect(ActiveCallTracker.isRespondingTo('session_1'), isFalse);
  });

  test('the same user answering on another device during the permission '
      'prompt: the accept is not sent, the call is given up here', () async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    closeAtEnd(bloc);

    bloc.add(const AcceptCall());
    await pumpEventQueue();
    bloc.onOutgoingCallAccepted(byMe(buildCall()));
    await pumpEventQueue();
    expect(bloc.state.status, IncomingCallStatus.cancelled);
    prompt.complete();
    await pumpEventQueue();

    expect(dataSource.acceptCallCount, 0);
    expect(dataSource.rejectCallCount, 0);
  });

  testWidgets('the same, through CallEventService: the banner closes during '
      'the prompt, and nothing is sent after it', (WidgetTester tester) async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    await showBanner(tester, buildCall());
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);

    service.onOutgoingCallAccepted(byMe(buildCall()));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.byType(CometChatIncomingCall), findsNothing);
    expect(ActiveCallTracker.finishedLately('session_1'), isTrue);

    prompt.complete();
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(dataSource.acceptCallCount, 0);
    expect(dataSource.rejectCallCount, 0);
  });

  test('"ongoing" once the accept request is out is this device\'s own '
      'echo: the accept goes on', () async {
    final Completer<void> server = Completer<void>();
    dataSource.acceptGate = server;
    dataSource.acceptError = const CallOperationsException(message: 'down');
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    closeAtEnd(bloc);

    bloc.add(const AcceptCall());
    await pumpEventQueue();
    expect(dataSource.acceptCallCount, 1);
    bloc.onOutgoingCallAccepted(byMe(buildCall()));
    await pumpEventQueue();

    expect(bloc.state.status, IncomingCallStatus.accepting);
  });

  test(
    'a decline marks the call as this device\'s own until it lands',
    () async {
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);

      bloc.add(const RejectCall());
      await pumpEventQueue();
      expect(ActiveCallTracker.isRespondingTo('session_1'), isTrue);
      server.complete();
      await pumpEventQueue();

      expect(ActiveCallTracker.isRespondingTo('session_1'), isFalse);
    },
  );
}
