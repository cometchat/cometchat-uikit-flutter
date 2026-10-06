/// The Android ongoing-call service ("Call in progress"): who starts it and
/// who stops it (round 4 review: API 3, regression 7, test gaps R12-R14).
/// The tests run as Android, the flutter_test default.
///
/// * `CometChatUIKitCalls.startSession` starts it once joined, with the
///   session's type, unless `launchOngoingCallService` is false.
/// * The UI Kit's data source (`CallOperationsDataSourceImpl.startSession`,
///   and through it the repository and `StartSessionUseCase`) passes false
///   since 6.2.0: the call screen starts the service itself once its call
///   view is back and it is still the screen on show.
/// * The call screen stops the service it started when it leaves, in the
///   same layer. A host data source (`CallOperationsServiceLocator.setup`)
///   whose `endSession` only leaves left the notification up.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_service_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource_impl.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/cometchat_uikit_calls.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_session_settings.dart';
import 'package:cometchat_chat_uikit/src/calls_join.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';

import '../helpers/call_bloc_harness.dart';

/// One `CometChatCalls.joinSession` the seam caught.
typedef _Join = ({
  String sessionId,
  SessionSettings settings,
  void Function(Widget?) onSuccess,
  void Function(CometChatCallsException) onError,
});

/// A host data source whose `endSession` only leaves (it never stops the
/// service), recording what the plugin had been asked when it was called.
class _LeaveOnly extends FakeCallOperationsDataSource {
  final List<List<String>> pluginCallsAtLeave = <List<String>>[];

  @override
  Future<void> endSession() {
    pluginCallsAtLeave.add(List<String>.of(CallsPluginChannelRecorder.methods));
    return super.endSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CometChatUIKitCalls.startSession and the data source (R12-R14)', () {
    late List<_Join> joins;

    setUp(() {
      CallsPluginChannelRecorder.install();
      joins = <_Join>[];
      CallsJoin.joinSession =
          ({
            required String sessionId,
            required SessionSettings sessionSettings,
            required void Function(Widget?) onSuccess,
            required void Function(CometChatCallsException) onError,
          }) => joins.add((
            sessionId: sessionId,
            settings: sessionSettings,
            onSuccess: onSuccess,
            onError: onError,
          ));
    });

    tearDown(() {
      CallsJoin.debugReset();
      CallsPluginChannelRecorder.remove();
      ActiveCallTracker.mayHaveMediaSession = false;
    });

    List<Object?> launches() =>
        CallsPluginChannelRecorder.argumentsOf('launchOngoingCallService');

    test('R13/R14: by default it starts the service once joined, with the '
        "session's type", () async {
      CometChatUIKitCalls.startSession(
        'voice',
        CallSessionSettings.forCall(isVideo: false).build(),
      );
      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);
      expect(launches(), isEmpty, reason: 'not before the join answers');
      joins.single.onSuccess(null);
      await pumpEventQueue();
      expect(launches(), <Object?>[
        <Object?, Object?>{'isVideo': false},
      ]);

      CometChatUIKitCalls.startSession(
        'video',
        CallSessionSettings.forCall(isVideo: true).build(),
      );
      joins.last.onSuccess(null);
      await pumpEventQueue();
      expect(launches().last, <Object?, Object?>{'isVideo': true});
    });

    test('R13: launchOngoingCallService: false starts nothing', () async {
      CometChatUIKitCalls.startSession(
        'voice',
        CallSessionSettings.forCall(isVideo: false).build(),
        launchOngoingCallService: false,
      );
      joins.single.onSuccess(null);
      await pumpEventQueue();

      expect(CallsPluginChannelRecorder.methods, isEmpty);
    });

    test(
      "R12: the UI Kit's data source joins without starting the service",
      () async {
        final Future<Widget> view = CallOperationsDataSourceImpl().startSession(
          'session_1',
          CallSessionSettings.forCall(isVideo: true).build(),
        );
        expect(joins.single.sessionId, 'session_1');
        joins.single.onSuccess(const FakeCallingWidget());

        expect(await view, isA<FakeCallingWidget>());
        await pumpEventQueue();
        expect(CallsPluginChannelRecorder.methods, isEmpty);
      },
    );

    test('a refused join takes the "maybe in a session" mark back and starts '
        'nothing', () async {
      CometChatUIKitCalls.startSession(
        'voice',
        CallSessionSettings.forCall(isVideo: false).build(),
      );
      joins.single.onError(
        CometChatCallsException('ERR', 'refused', 'refused'),
      );
      await pumpEventQueue();

      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      expect(CallsPluginChannelRecorder.methods, isEmpty);
    });
  });

  group('the call screen stops the service it started (API 3)', () {
    final CallEventService service = CallEventService.instance;
    late _LeaveOnly dataSource;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      dataSource = _LeaveOnly();
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

    Future<void> showJoined(
      WidgetTester tester, {
      CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
    }) async {
      await mountCallNavigator(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
        callWorkFlow: workFlow,
      );
      await tester.pump();
      await tester.pump();
      expect(CallsPluginChannelRecorder.methods, <String>[
        'launchOngoingCallService',
      ]);
    }

    void sdk(void Function(SessionStatusListeners l) event) {
      for (final SessionStatusListeners l in List.of(
        CallSession.getInstance()!.sessionStatusListeners,
      )) {
        event(l);
      }
    }

    testWidgets('End: stopped before the leave, with a data source that only '
        'leaves', (WidgetTester tester) async {
      await showJoined(tester);

      for (final ButtonClickListeners l in List.of(
        CallSession.getInstance()!.buttonClickListeners,
      )) {
        l.onLeaveSessionButtonClicked();
      }
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(dataSource.pluginCallsAtLeave, <List<String>>[
        <String>['launchOngoingCallService', 'abortOngoingCallService'],
      ]);
    });

    testWidgets("the session's own end (a remote end): stopped, then left", (
      WidgetTester tester,
    ) async {
      await showJoined(tester);

      sdk((SessionStatusListeners l) => l.onSessionLeft());
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(
        dataSource.pluginCallsAtLeave.single.last,
        'abortOngoingCallService',
      );
    });

    testWidgets('a meeting left from its screen: stopped, then left', (
      WidgetTester tester,
    ) async {
      await showJoined(tester, workFlow: CallWorkFlow.directCalling);

      for (final ButtonClickListeners l in List.of(
        CallSession.getInstance()!.buttonClickListeners,
      )) {
        l.onLeaveSessionButtonClicked();
      }
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(
        dataSource.pluginCallsAtLeave.single.last,
        'abortOngoingCallService',
      );
    });

    testWidgets('a screen taken down from outside: stopped by its safety-net '
        'leave', (WidgetTester tester) async {
      await showJoined(tester);

      CallScreenOverlay.dismiss();
      await tester.pump();
      await tester.pump();

      expect(
        dataSource.pluginCallsAtLeave.single.last,
        'abortOngoingCallService',
      );
    });

    testWidgets('a call view that never reports the join (the watchdog): '
        'stopped before the leave', (WidgetTester tester) async {
      ActiveCallTracker.nativeJoinTimeout = const Duration(seconds: 30);
      await showJoined(tester);

      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect(
        dataSource.pluginCallsAtLeave.single.last,
        'abortOngoingCallService',
      );
    });

    testWidgets('stopped once: a second leave asks nothing more', (
      WidgetTester tester,
    ) async {
      await showJoined(tester);
      for (final ButtonClickListeners l in List.of(
        CallSession.getInstance()!.buttonClickListeners,
      )) {
        l.onLeaveSessionButtonClicked();
      }
      await tester.pump(Duration.zero);
      await tester.pump();
      CallScreenOverlay.dismiss();
      await tester.pump();

      expect(
        CallsPluginChannelRecorder.methods.where(
          (String m) => m == 'abortOngoingCallService',
        ),
        hasLength(1),
      );
    });

    testWidgets('a screen that never started it stops nothing', (
      WidgetTester tester,
    ) async {
      installCallsSdk(
        FakeCallsSdkGateway()
          ..onInit = () async => throw StateError('Calls init failed'),
      );
      expect(await CallsSdkSession.instance.ensureReady(), isFalse);
      await mountCallNavigator(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(CallsPluginChannelRecorder.methods, isEmpty);
    });

    testWidgets('the same call shown again: the replaced screen stops '
        "nothing (the service is the newer screen's now)", (
      WidgetTester tester,
    ) async {
      await showJoined(tester);

      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();

      expect(
        CallsPluginChannelRecorder.methods,
        isNot(contains('abortOngoingCallService')),
      );
      expect(dataSource.endSessionCount, 0);
    });
  });
}
