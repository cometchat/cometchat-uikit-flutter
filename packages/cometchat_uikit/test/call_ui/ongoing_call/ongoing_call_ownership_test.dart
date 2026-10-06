/// The call screen's ownership token and what closing a screen touches
/// (round 4: P4-C11 as corrected, P5-C08, the session-scoped
/// CallStateService flag, P4-C07). The orientation (P4-C16) has its own
/// file: ongoing_call_orientation_test.dart.
///
/// The Calls SDK has one media session for the app, and `CallScreenOverlay`
/// one screen. A screen replaced by a newer one (another call, or the same
/// call shown again) is closed a frame after the newer screen was built, and
/// its clean-up used to run under the new call: CallStateService said no
/// call, the orientation was unlocked. Now each screen takes a token when it
/// is built (`ActiveCallTracker.callScreenGeneration`, bumped by every
/// `CallScreenOverlay.show`) and only the screen that still owns the call
/// touches what the app shares.
///
/// The owner's close is also a safety net: a screen taken down from outside
/// without its call being ended leaves the session it joined and releases
/// the record, as Android's call activity does when it is destroyed.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_ownership_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;

  /// Every `SystemChrome.setPreferredOrientations`, as the orientations'
  /// names, in order.
  final List<List<String>> orientations = <List<String>>[];

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = null;
    orientations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add(
              List<String>.from(call.arguments as List<Object?>),
            );
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    CallScreenOverlay.dismiss();
    service.activeCall = null;
    removeCallJoinDefaults();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Shows [sessionId]'s call screen in the overlay and lets it join.
  Future<void> showJoined(
    WidgetTester tester,
    String sessionId, {
    CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
  }) async {
    CallScreenOverlay.show(
      sessionId: sessionId,
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: workFlow,
    );
    await tester.pump();
    await tester.pump();
    expect(
      dataSource.calls,
      contains('startSession:$sessionId'),
      reason: 'the call screen joined',
    );
  }

  group('P4-C11: a screen taken down from outside leaves its session', () {
    testWidgets('joined, then dismissed without its call ended: the session '
        'is left once and the record released', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      service.activeCall = buildCall();
      await showJoined(tester, 'session_1');
      expect(dataSource.endSessionCount, 0);

      // A host taking it down itself.
      CallScreenOverlay.dismiss();
      await tester.pump();

      expect(dataSource.endSessionCount, 1);
      expect(service.activeCall, isNull);
      expect(CallStateService.instance.isActiveCall.value, isFalse);
      expect(dataSource.endCallCount, 0, reason: 'nothing to the server');
    });

    testWidgets('a newer call screen for another call shown before the old '
        "bloc closes: nothing of the new call's is touched", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      await showJoined(tester, 'session_1');
      service.activeCall = buildCall(sessionId: 'session_2');

      CallScreenOverlay.show(
        sessionId: 'session_2',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      orientations.clear();
      await tester.pump();
      await tester.pump();

      // The old screen closed (its bloc too) without leaving: the session
      // is session_2's now.
      expect(dataSource.endSessionCount, 0);
      expect((service.activeCall as Call?)?.sessionId, 'session_2');
      expect(CallStateService.instance.isActiveCall.value, isTrue);
      expect(orientations, isNot(contains(isEmpty)));
      expect(ActiveCallTracker.hasActiveCall, isTrue);
    });

    testWidgets('the same call shown again (the refuted guard): the old '
        "screen's close neither leaves nor releases the live call", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      service.activeCall = buildCall();
      await showJoined(tester, 'session_1');

      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();

      expect(dataSource.endSessionCount, 0);
      expect((service.activeCall as Call?)?.sessionId, 'session_1');
      expect(ActiveCallTracker.hasActiveCall, isTrue);
      expect(CallStateService.instance.isActiveCall.value, isTrue);
    });
  });

  testWidgets("a replaced screen's own end arriving before it closes (the "
      'same call shown again) closes nothing of the screen that replaced it', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    service.activeCall = buildCall();
    await showJoined(tester, 'session_1');
    final List<SessionStatusListeners> oldListeners = List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    );

    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    // The old screen's session reports it left before a frame closes it.
    for (final SessionStatusListeners l in oldListeners) {
      l.onSessionLeft();
    }
    await tester.pump(Duration.zero);
    await tester.pump();
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isTrue);
    expect(ActiveCallTracker.callScreenSessionId, 'session_1');
    expect((service.activeCall as Call?)?.sessionId, 'session_1');
    expect(CallStateService.instance.isActiveCall.value, isTrue);
    // Correctness 13: nor does it leave the session, which is the newer
    // screen's.
    expect(dataSource.endSessionCount, 0);
  });

  testWidgets('probe C: a newer call screen taken down before it was built: '
      'the screen it replaced still gives up the call flag, the orientation '
      'and its session', (WidgetTester tester) async {
    await mountCallNavigator(tester);
    final List<String> orientation = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('cometchat_chat_uikit'), (
          MethodCall call,
        ) async {
          if (call.method.endsWith('CallOrientation')) {
            orientation.add(call.method);
          }
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('cometchat_chat_uikit'),
            null,
          ),
    );
    await showJoined(tester, 'meeting', workFlow: CallWorkFlow.directCalling);
    expect(CallStateService.instance.isActiveCall.value, isTrue);

    // A newer screen, taken down again before a frame builds it (the app
    // in the background, say).
    CallScreenOverlay.show(
      sessionId: 'session_2',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    CallScreenOverlay.dismiss(sessionId: 'session_2');
    await tester.pump();
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(CallStateService.instance.isActiveCall.value, isFalse);
    expect(orientation, <String>[
      'holdCallOrientation',
      'releaseCallOrientation',
    ]);
    expect(dataSource.endSessionCount, 1, reason: "the meeting's session");
  });

  group('P5-C08: a live screen closed without an end leaves its session', () {
    test('a meeting (directCalling) that joined and is closed with no end '
        'event leaves exactly once', () async {
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'meeting',
        callWorkFlow: CallWorkFlow.directCalling,
      );
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.active,
      );

      await bloc.close();
      await pumpEventQueue();

      expect(dataSource.endSessionCount, 1);
    });

    test('a call ended with End does not leave again on close', () async {
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.active,
      );
      bloc.add(const EndCallButtonPressed());
      await pumpEventQueue();

      await bloc.close();
      await pumpEventQueue();

      expect(dataSource.endSessionCount, 1);
      expect(dataSource.endCallCount, 1);
    });

    test('a screen closed while still connecting leaves nothing (no view '
        'was mounted) and takes the "maybe in a session" mark back', () async {
      final Completer<Widget> join = Completer<Widget>();
      dataSource.onStartSession = (_) => join.future;
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      while (dataSource.startSessionCount == 0) {
        await pumpEventQueue();
      }
      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);

      await bloc.close();
      join.complete(const FakeCallingWidget());
      await pumpEventQueue();

      expect(dataSource.endSessionCount, 0);
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      expect(CallsPluginChannelRecorder.methods, isEmpty);
    });
  });

  group('P4-C07: a call screen closes only its own screen', () {
    testWidgets('P4-E94: the overlay taken down from outside, then the '
        "session's own end arrives before a frame (the app in the "
        "background): the app's screens are left as they were", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('chat-route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await showJoined(tester, 'session_1');

      // The remote end: CallEventService dismisses the overlay; no frame
      // runs, so the bloc is still open when the Calls SDK says it left.
      CallScreenOverlay.dismiss(sessionId: 'session_1');
      CallSession.getInstance()!.sessionStatusListeners.toList().forEach(
        (SessionStatusListeners l) => l.onSessionLeft(),
      );
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();

      expect(find.text('chat-route'), findsOneWidget);
      expect(find.text('chat'), findsNothing);
    });
  });
}
