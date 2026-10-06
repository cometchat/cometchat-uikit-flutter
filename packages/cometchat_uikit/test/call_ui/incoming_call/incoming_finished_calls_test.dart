/// What the end of an incoming call's ringing releases and remembers (round
/// 3 review: P3-C23, the review's PROBE-1, PROBE-3, PROBE-4 and FS6).
///
/// Before:
/// * the bloc's cancel path released the active call too, so the "ongoing"
///   echo of a call answered outside the banner (CallKit, a host calling
///   `CometChatUIKitCalls.acceptCall`), taken for an answer on another
///   device, cleared the record of the call in progress;
/// * only that release remembered a finished call, so a call dismissed by a
///   push cancel, or answered on another device while no banner was up,
///   rang again on a late "initiated" after a socket reconnect;
/// * a cancel of a call with no session dismissed whatever banner was up
///   and cleared every record.
///
///   flutter test test/call_ui/incoming_call/incoming_finished_calls_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
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
    ActiveCallTracker.busyRejectDelay = Duration.zero;
    ActiveCallTracker.forgetFinishedCalls();
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
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  Future<void> mountApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: CallNavigationContext.navigatorKey,
      localizationsDelegates: Translations.localizationsDelegates,
      home: const SizedBox.shrink(),
    ),
  );

  group('the active call is never the cancel\'s to release', () {
    test('PROBE-1: a call answered outside the banner keeps its record when '
        'its own "ongoing" echo reaches the banner\'s bloc', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      // master_app's VoipCallHandler, or a host calling
      // CometChatUIKitCalls.acceptCall: the accept lands, then the UI Kit
      // hears of it.
      service.ccCallAccepted(buildCall());
      expect(service.activeCall, isNotNull);

      // Its echo, before the banner's widget has gone.
      bloc.onOutgoingCallAccepted(byMe(buildCall()));
      await pumpEventQueue();

      expect(bloc.state.status, IncomingCallStatus.cancelled);
      expect((service.activeCall as Call?)?.sessionId, 'session_1');
      expect(ActiveCallTracker.hasActiveCall, isTrue);
    });

    test('FS6: the 60 s give-up of a call answered outside the banner '
        'leaves its record too', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      service.ccCallAccepted(buildCall());

      // What the ring timeout adds.
      bloc.add(const CallCancelled());
      await pumpEventQueue();

      expect((service.activeCall as Call?)?.sessionId, 'session_1');
    });

    test(
      'a cancel of a call with no session releases only a record holding '
      'that very call: not the call ringing, not the call in progress',
      () async {
        final NullSessionCall nameless = NullSessionCall();
        final Call ringing = buildCall(sessionId: 'ringing');
        final Call inProgress = buildCall(sessionId: 'in_progress');
        ActiveCallTracker.ringingCall = ringing;
        service.activeCall = inProgress;
        final IncomingCallBloc bloc = IncomingCallBloc(
          call: nameless,
          disableSoundForCalls: true,
        );
        addTearDown(bloc.close);

        bloc.add(const CallCancelled());
        await pumpEventQueue();

        expect(bloc.state.status, IncomingCallStatus.cancelled);
        expect(ActiveCallTracker.ringingCall, same(ringing));
        expect(service.activeCall, same(inProgress));
      },
    );

    test('a cancel of a call with no session releases the ringing record '
        'when it holds that very call', () async {
      final NullSessionCall nameless = NullSessionCall();
      ActiveCallTracker.ringingCall = nameless;
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: nameless,
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);

      bloc.add(const CallCancelled());
      await pumpEventQueue();

      expect(ActiveCallTracker.ringingCall, isNull);
    });

    testWidgets('a cancel of a call with no session leaves the banner of the '
        'call ringing on screen', (WidgetTester tester) async {
      await mountApp(tester);
      final Call ringing = buildCall(sessionId: 'ringing');
      ActiveCallTracker.ringingCall = ringing;
      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: ringing,
        disableSoundForCalls: true,
      );
      await tester.pump();
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: NullSessionCall(),
        disableSoundForCalls: true,
      );

      bloc.add(const CallCancelled());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      expect(ActiveCallTracker.incomingCallSessionId, 'ringing');
      await tester.runAsync(bloc.close);
      IncomingCallOverlay.dismiss();
      await tester.pump();
    });
  });

  // Round 3 review (SD1): the cancel's dismiss was never shown to be
  // scoped: one taking down whatever banner was up passed every test.
  testWidgets('the cancel of a call shown elsewhere (a host\'s own screen) '
      'leaves the banner of the call ringing on it', (
    WidgetTester tester,
  ) async {
    await mountApp(tester);
    final Call ringing = buildCall(sessionId: 'Y');
    ActiveCallTracker.ringingCall = ringing;
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: ringing,
      disableSoundForCalls: true,
    );
    await tester.pump();
    final IncomingCallBloc other = IncomingCallBloc(
      call: buildCall(sessionId: 'X'),
      disableSoundForCalls: true,
    );

    other.add(const CallCancelled());
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.byType(CometChatIncomingCall), findsOneWidget);
    expect(ActiveCallTracker.incomingCallSessionId, 'Y');
    expect(ActiveCallTracker.ringingCall, same(ringing));
    await tester.runAsync(other.close);
    IncomingCallOverlay.dismiss();
    await tester.pump();
  });

  group('every way ringing ends remembers the call (P3-C23)', () {
    testWidgets('PROBE-3: a push cancel (a dismiss naming the call) and then '
        'a late "initiated" for it: it does not ring again', (
      WidgetTester tester,
    ) async {
      await mountApp(tester);
      final Call x = buildCall(sessionId: 'X');
      service.onIncomingCallReceived(x);
      await tester.pump(const Duration(milliseconds: 50));
      expect(ActiveCallTracker.incomingCallSessionId, 'X');

      // master_app's FCM / APNs cancel handler.
      IncomingCallOverlay.dismiss(sessionId: 'X');
      await tester.pump();
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.finishedLately('X'), isTrue);

      service.onIncomingCallReceived(x);
      await tester.pump(const Duration(milliseconds: 50));

      expect(ActiveCallTracker.incomingCallSessionId, isNull);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(dataSource.rejectCallCount, 0);
    });

    testWidgets('a dismiss naming a call while another one\'s banner is up '
        'leaves that banner, and still remembers the call it names', (
      WidgetTester tester,
    ) async {
      await mountApp(tester);
      final Call ringing = buildCall(sessionId: 'ringing');
      ActiveCallTracker.ringingCall = ringing;
      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: ringing,
        disableSoundForCalls: true,
      );
      await tester.pump();

      IncomingCallOverlay.dismiss(sessionId: 'Z');
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      expect(ActiveCallTracker.ringingCall, same(ringing));
      expect(ActiveCallTracker.finishedLately('Z'), isTrue);
      expect(ActiveCallTracker.finishedLately('ringing'), isFalse);
      IncomingCallOverlay.dismiss();
      await tester.pump();
    });

    test('a dismiss with no session (a host taking the banner down) '
        'remembers nothing', () {
      ActiveCallTracker.ringingCall = buildCall(sessionId: 'H');

      IncomingCallOverlay.dismiss();

      expect(ActiveCallTracker.finishedLately('H'), isFalse);
    });

    test('PROBE-4: "ongoing" by this user on another device, for a ringing '
        'record with no banner: released and remembered', () {
      ActiveCallTracker.ringingCall = buildCall(sessionId: 'Y');

      service.onOutgoingCallAccepted(byMe(buildCall(sessionId: 'Y')));

      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.finishedLately('Y'), isTrue);
    });

    test('FS6: a call given up at the 60 s timeout is remembered, and a '
        'late "initiated" for it neither rings nor is answered busy', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(sessionId: 'T'),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      ActiveCallTracker.ringingCall = buildCall(sessionId: 'T');

      bloc.add(const CallCancelled());
      await pumpEventQueue();
      expect(ActiveCallTracker.finishedLately('T'), isTrue);

      service.onIncomingCallReceived(buildCall(sessionId: 'T'));
      await pumpEventQueue();

      expect(ActiveCallTracker.ringingCall, isNull);
      expect(dataSource.rejectCallCount, 0);
    });

    test('FS3: remembering a call again makes it the newest, so it outlives '
        'the 20 calls remembered after its first time', () {
      ActiveCallTracker.release('A');
      for (int i = 1; i < 20; i++) {
        ActiveCallTracker.release('B$i');
      }
      // 20 remembered, A the oldest. A ends again (a second banner for it).
      ActiveCallTracker.release('A');
      ActiveCallTracker.release('C');

      expect(ActiveCallTracker.finishedLately('A'), isTrue);
      expect(ActiveCallTracker.finishedLately('B1'), isFalse);
      expect(ActiveCallTracker.finishedLately('C'), isTrue);
    });
  });
}
