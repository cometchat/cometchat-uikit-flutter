/// Call waiting (ringing v2): a call that rings through push during a 1-on-1
/// call on the call screen rings over it instead of being answered busy, and
/// answering it ends the call in progress before the answered one joins
/// ("End & accept"), as the push ringer's ring screen and CallKit say.
///
/// A call that arrives while another already rings is still answered busy,
/// and one answered during a call this device placed that still rings is
/// still declined.
///
///   flutter test test/call_ui/call_waiting_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show InitiatedCall, SessionSettingsBuilder;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/cometchat_call_push_bridge.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/ui_kit_settings.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/push_ringing.dart';

import 'helpers/call_bloc_harness.dart';

/// The push ringer, recording what the UI Kit asks of it.
class _FakeBridge extends CometChatCallPushBridge {
  final List<String> declined = <String>[];
  final List<String> dismissed = <String>[];
  final List<String> reportedEnded = <String>[];

  @override
  Stream<CometChatPushCall> get answered =>
      const Stream<CometChatPushCall>.empty();

  @override
  Stream<CometChatPushCallEnded> get ended =>
      const Stream<CometChatPushCallEnded>.empty();

  @override
  Future<void> answer(String sessionId) async {}

  @override
  Future<void> decline(String sessionId) async => declined.add(sessionId);

  @override
  Future<void> dismissRinging(
    String sessionId, {
    required bool answered,
  }) async => dismissed.add(sessionId);

  @override
  Future<void> reportCallEnded(String sessionId) async =>
      reportedEnded.add(sessionId);
}

Call _call(String sessionId, {String status = 'ongoing'}) => Call(
  id: 1,
  sessionId: sessionId,
  callStatus: status,
  callInitiator: User(uid: 'bob', name: 'Bob'),
  receiverUid: 'me',
  type: 'audio',
  receiverType: 'user',
);

InitiatedCall _incoming(String sessionId) => InitiatedCall(
  sessionId: sessionId,
  sender: 'carol',
  receiver: 'me',
  receiverType: 'user',
  type: 'audio',
  callerName: 'Carol',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late _FakeBridge bridge;
  final CallEventService service = CallEventService.instance;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    bridge = _FakeBridge();
    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()..callPushBridge = bridge).build();
    CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me');
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    ActiveCallTracker.busyRejectDelay = Duration.zero;
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    CometChatUIKit.authenticationSettings = null;
    CometChatUIKit.loggedInUser = null;
    removeCallJoinDefaults();
    SoundChannelSpy.remove();
    CallStateService.instance.setActiveCallValue(false);
    await CallOperationsServiceLocator.instance.reset();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// The 1-on-1 call with Bob, joined and on the call screen.
  Future<void> showLiveCall(WidgetTester tester) async {
    await mountCallNavigator(tester);
    service.activeCall = _call('live');
    CallScreenOverlay.show(
      sessionId: 'live',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: CallWorkFlow.defaultCalling,
    );
    await tester.pump();
    await tester.pump();
    expect(dataSource.calls, contains('startSession:live'));
  }

  Future<void> settle(WidgetTester tester) async {
    // The busy reject waits behind a timer (zero in tests).
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('a call during a 1-on-1 call rings over it, not busy', (
    WidgetTester tester,
  ) async {
    await showLiveCall(tester);

    PushRinging.received(_incoming('waiting'));
    await settle(tester);

    expect(ActiveCallTracker.ringingCall?.sessionId, 'waiting');
    expect(dataSource.rejectCallCount, 0);
    expect(bridge.dismissed, isEmpty);
    // The call in progress is untouched.
    expect(ActiveCallTracker.callScreenSessionId, 'live');
    expect((service.activeCall as Call).sessionId, 'live');
  });

  testWidgets('a third call, while one rings over the call, is answered busy', (
    WidgetTester tester,
  ) async {
    await showLiveCall(tester);
    PushRinging.received(_incoming('waiting'));

    PushRinging.received(_incoming('third'));
    await settle(tester);

    expect(dataSource.calls, contains('rejectCall:third:busy'));
    expect(bridge.dismissed, <String>['third']);
    expect(ActiveCallTracker.ringingCall?.sessionId, 'waiting');
  });

  group('a call whose end was never heard', () {
    // Recorded as ringing and never released, it used to answer every later
    // call busy until the user placed a call (Android and iOS).
    DateTime clock = DateTime(2026, 10, 14, 17);
    setUp(() {
      clock = DateTime(2026, 10, 14, 17);
      ActiveCallTracker.now = () => clock;
      PushRinging.debugReset();
    });
    tearDown(() => ActiveCallTracker.now = DateTime.now);

    testWidgets('stops making calls busy once its ring window is over', (
      WidgetTester tester,
    ) async {
      PushRinging.received(_incoming('cancelled'));
      clock = clock.add(
        ActiveCallTracker.incomingRingTimeout + const Duration(seconds: 1),
      );

      PushRinging.received(_incoming('next'));
      await settle(tester);

      expect(dataSource.rejectCallCount, 0);
      expect(bridge.dismissed, isEmpty);
      expect(ActiveCallTracker.ringingCall?.sessionId, 'next');
    });

    testWidgets('within its ring window, the next call is still busy', (
      WidgetTester tester,
    ) async {
      PushRinging.received(_incoming('ringing'));
      clock = clock.add(const Duration(seconds: 10));

      PushRinging.received(_incoming('next'));
      await settle(tester);

      expect(dataSource.calls, contains('rejectCall:next:busy'));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'ringing');
    });
  });

  testWidgets('answering it ends the call in progress, then joins it', (
    WidgetTester tester,
  ) async {
    await showLiveCall(tester);
    PushRinging.received(_incoming('waiting'));
    dataSource.calls.clear();

    await PushRinging.join(
      const CometChatPushCall(
        sessionId: 'waiting',
        callType: 'audio',
        callerUid: 'carol',
        callerName: 'Carol',
      ),
    );
    await settle(tester);

    // Left before the answered call joins: one session at a time.
    final int left = dataSource.calls.indexOf('endSession');
    final int joined = dataSource.calls.indexOf('startSession:waiting');
    expect(left, isNonNegative);
    expect(joined, greaterThan(left));
    expect(bridge.declined, isEmpty);
    expect(bridge.reportedEnded, contains('live'));
    expect(ActiveCallTracker.callScreenSessionId, 'waiting');
    expect((service.activeCall as Call).sessionId, 'waiting');
    expect(ActiveCallTracker.ringingCall, isNull);
    expect(ActiveCallTracker.finishedLately('live'), isTrue);
  });

  testWidgets('answered while a placed call still rings: declined', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    service.activeCall = _call('placed', status: 'initiated');

    await PushRinging.join(
      const CometChatPushCall(sessionId: 'waiting', callType: 'audio'),
    );
    await settle(tester);

    expect(bridge.declined, <String>['waiting']);
    expect(dataSource.startSessionCount, 0);
    expect((service.activeCall as Call).sessionId, 'placed');
  });
}
