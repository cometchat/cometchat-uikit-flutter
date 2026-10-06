/// Back on the call screen (round 4: the owner's "back does nothing during
/// an active call" and "back while Connecting cancels the call", P4-C18
/// adapted to the back gesture; there is no End button on "Connecting...").
///
/// While the call still connects, back cancels it as End would: the join is
/// given up, a 1-on-1 call is ended on the server (the user ended it), the
/// screen closes; a join that lands later starts nothing. "Connecting" lasts
/// until the native side reports the join, not only until the call view is
/// back (round 4 review, correctness 8: on the iPad's slow view mount back
/// did nothing for up to 30 s). Once the call is up, back does nothing, on
/// the overlay and on a standalone screen alike (R25).
///
/// A screen a newer one replaced acts on nothing (correctness 13): back,
/// End on its view and its session's events in the frame before it closes
/// used to end the call on the screen that replaced it.
///
/// Back used to reach the app's own navigator first: the call screen sits in
/// that navigator's overlay, not in one of its routes, so back closed the
/// app's screen (the chat the call was placed from) behind the call. The
/// call screen now turns that pop down while it is up.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_back_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/cometchat_ongoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;

  /// Holds the join on its way: the screen stays on "Connecting...". Made
  /// in the test's body (its fake-time zone): a completer made in setUp
  /// delivers its result on the real event loop, after the body.
  late Completer<Widget> join;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = buildCall();
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    removeCallJoinDefaults();
    service.activeCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// The app, with the chat the call was placed from pushed over its home.
  Future<void> mountChat(WidgetTester tester) async {
    await mountCallNavigator(tester);
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('chat-route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Shows the call screen with its join held, so it stays connecting.
  Future<void> showConnecting(
    WidgetTester tester, {
    CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
  }) async {
    join = Completer<Widget>();
    dataSource.onStartSession = (_) => join.future;
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: workFlow,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Connecting...'), findsOneWidget);
  }

  /// The system back button (Android) / back gesture, as the engine sends it.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  /// The Calls SDK reports the native join.
  void sdkSessionJoined() {
    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      l.onSessionJoined();
    }
  }

  group('back while the call is connecting cancels it', () {
    testWidgets('a 1-on-1 call: the screen closes, endCall goes out (the '
        "user ended it), the record is released, the app's chat stays", (
      WidgetTester tester,
    ) async {
      await mountChat(tester);
      await showConnecting(tester);

      await pressBack(tester);

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endCallCount, 1);
      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.hasActiveCall, isFalse);
      expect(find.text('chat-route'), findsOneWidget);
      // Nothing joined, so nothing to leave.
      expect(dataSource.endSessionCount, 0);
    });

    testWidgets('the join that lands afterwards starts nothing (P4-C04)', (
      WidgetTester tester,
    ) async {
      await mountChat(tester);
      await showConnecting(tester);
      await pressBack(tester);

      join.complete(const FakeCallingWidget());
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(CallsPluginChannelRecorder.methods, isEmpty);
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      expect(CallScreenOverlay.isShowing, isFalse);
    });

    testWidgets('a meeting (directCalling): closed, no endCall', (
      WidgetTester tester,
    ) async {
      await mountChat(tester);
      await showConnecting(tester, workFlow: CallWorkFlow.directCalling);

      await pressBack(tester);

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endCallCount, 0);
      expect(find.text('chat-route'), findsOneWidget);
    });

    testWidgets('with the app on its first screen too (the back reaches the '
        "call screen's own navigator)", (WidgetTester tester) async {
      await mountCallNavigator(tester);
      await showConnecting(tester);

      await pressBack(tester);

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endCallCount, 1);
      expect(find.text('chat'), findsOneWidget);
    });
  });

  testWidgets('correctness 8: the call view is back but the native side has '
      'not joined yet: back still cancels it', (WidgetTester tester) async {
    await mountChat(tester);
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(FakeCallingWidget), findsOneWidget);

    await pressBack(tester);

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(dataSource.endSessionCount, 1);
    expect(dataSource.endCallCount, 1);
    expect(find.text('chat-route'), findsOneWidget);
  });

  group('back once the call is up does nothing', () {
    testWidgets("the call stays, and the app's chat under it stays", (
      WidgetTester tester,
    ) async {
      await mountChat(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(FakeCallingWidget), findsOneWidget);
      sdkSessionJoined();
      await tester.pump();

      await pressBack(tester);
      await tester.pumpAndSettle();

      expect(CallScreenOverlay.isShowing, isTrue);
      expect(dataSource.endCallCount, 0);
      expect(dataSource.endSessionCount, 0);
      expect(find.text('chat-route', skipOffstage: false), findsOneWidget);
    });

    testWidgets('once the call screen is gone, back closes the chat again', (
      WidgetTester tester,
    ) async {
      await mountChat(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      CallScreenOverlay.dismiss(sessionId: 'session_1');
      await tester.pump();

      await pressBack(tester);
      await tester.pumpAndSettle();

      expect(find.text('chat-route', skipOffstage: false), findsNothing);
      expect(find.text('chat'), findsOneWidget);
    });
  });

  testWidgets('a standalone CometChatOngoingCall (a route the host pushed): '
      'back while connecting cancels it and closes that route', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    join = Completer<Widget>();
    dataSource.onStartSession = (_) => join.future;
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOngoingCall(
            sessionId: 'session_1',
            sessionSettingsBuilder: SessionSettingsBuilder(),
            callWorkFlow: CallWorkFlow.defaultCalling,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connecting...'), findsOneWidget);

    await pressBack(tester);
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOngoingCall), findsNothing);
    expect(dataSource.endCallCount, 1);
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('R25: a standalone CometChatOngoingCall whose call is up: back '
      'does nothing', (WidgetTester tester) async {
    await mountCallNavigator(tester);
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOngoingCall(
            sessionId: 'session_1',
            sessionSettingsBuilder: SessionSettingsBuilder(),
            callWorkFlow: CallWorkFlow.defaultCalling,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FakeCallingWidget), findsOneWidget);
    sdkSessionJoined();
    await tester.pump();

    await pressBack(tester);
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOngoingCall), findsOneWidget);
    expect(dataSource.endCallCount, 0);
    expect(dataSource.endSessionCount, 0);
  });

  testWidgets('R25: a standalone screen whose call view is back but not '
      'joined natively: back cancels it and closes its route', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOngoingCall(
            sessionId: 'session_1',
            sessionSettingsBuilder: SessionSettingsBuilder(),
            callWorkFlow: CallWorkFlow.defaultCalling,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FakeCallingWidget), findsOneWidget);

    await pressBack(tester);
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOngoingCall), findsNothing);
    expect(dataSource.endCallCount, 1);
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('a standalone screen an overlay call screen has replaced: back '
      'reaches both, and only the one on top acts', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    // The standalone call still connecting; the overlay's joins at once.
    final Completer<Widget> standaloneJoin = Completer<Widget>();
    dataSource.onStartSession = (String sid) => sid == 'standalone'
        ? standaloneJoin.future
        : Future<Widget>.value(const FakeCallingWidget());
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOngoingCall(
            sessionId: 'standalone',
            sessionSettingsBuilder: SessionSettingsBuilder(),
            callWorkFlow: CallWorkFlow.defaultCalling,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    CallScreenOverlay.show(
      sessionId: 'session_2',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();
    await tester.pump();
    sdkSessionJoined();
    await tester.pump();

    await pressBack(tester);
    await tester.pumpAndSettle();

    expect(dataSource.calls, isNot(contains('endCall:standalone')));
    expect(find.byType(CometChatOngoingCall), findsNWidgets(2));
    standaloneJoin.complete(const FakeCallingWidget());
  });

  group('correctness 13: a replaced screen acts on nothing', () {
    /// `session_1` on screen and joined, then shown again (a host's second
    /// show for the same call). The old screen closes on the next frame;
    /// until then only its listeners hear the session.
    Future<void> showTwice(WidgetTester tester) async {
      await mountChat(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
    }

    /// The live call is still on: the newer screen up, nothing ended.
    Future<void> expectCallLive(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      expect(dataSource.endCallCount, 0);
      expect(dataSource.endSessionCount, 0);
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(ActiveCallTracker.hasActiveCall, isTrue);
    }

    testWidgets('End tapped on the old view before it closes', (
      WidgetTester tester,
    ) async {
      await showTwice(tester);

      for (final ButtonClickListeners l in List.of(
        CallSession.getInstance()!.buttonClickListeners,
      )) {
        l.onLeaveSessionButtonClicked();
      }
      await tester.pump(Duration.zero);

      await expectCallLive(tester);
    });

    testWidgets('back between the newer show and the old screen\'s close', (
      WidgetTester tester,
    ) async {
      await showTwice(tester);

      await tester.binding.handlePopRoute();
      await tester.pump(Duration.zero);

      await expectCallLive(tester);
    });

    testWidgets("the old session's timeout before it closes", (
      WidgetTester tester,
    ) async {
      await showTwice(tester);

      for (final SessionStatusListeners l in List.of(
        CallSession.getInstance()!.sessionStatusListeners,
      )) {
        l.onSessionTimedOut();
      }
      await tester.pump(Duration.zero);

      await expectCallLive(tester);
    });
  });
}
