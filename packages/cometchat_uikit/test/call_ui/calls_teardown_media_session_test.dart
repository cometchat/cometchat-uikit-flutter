/// A teardown (logout, user switch, `CallEventService.dispose`) leaves the
/// Calls SDK's media session, and stops the Android ongoing-call service,
/// only when there is a session to leave (round 1b review, regression 1).
///
/// It used to check `CallSession.getInstance() != null`, which is always
/// true: the plugin creates that instance eagerly. So every teardown sent a
/// native `leaveSession` (on iOS it also clears the plugin's listeners and
/// ends the CallKit call) and `abortOngoingCallService`, two or three times
/// per logout, even in an app that never made a call or has calls off.
///
/// The Calls plugin's method channel is recorded, so what reaches the native
/// side is what is checked.
///
///   flutter test test/call_ui/calls_teardown_media_session_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettingsBuilder;
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/cometchat_uikit_calls.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';

/// The Calls plugin's method channel (`PlatformConstants.methodChannelName`).
const MethodChannel _plugin = MethodChannel('cometchatcalls_plugin');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Methods invoked on the Calls plugin, in order.
  final native = <String>[];

  setUp(() async {
    native.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, (MethodCall call) async {
          native.add(call.method);
          return null;
        });
    ActiveCallTracker.mayHaveMediaSession = false;
    await CallOperationsServiceLocator.instance.reset();
    CallOperationsServiceLocator.instance.setup(
      dataSource: FakeCallOperationsDataSource(),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, null);
    CallScreenOverlay.dismiss();
    ActiveCallTracker.mayHaveMediaSession = false;
    CallsLifecycle.debugReset();
    removeCallJoinDefaults();
    await CallOperationsServiceLocator.instance.reset();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Runs [body] as on Android, where the ongoing-call service exists.
  Future<void> onAndroid(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  test('with no call screen and no join, a teardown sends nothing to the '
      'Calls plugin', () async {
    await onAndroid(() async {
      CallsLifecycle.tearDownLocalCalls();
      CallsLifecycle.stop();
      await pumpEventQueue();
    });

    expect(native, isEmpty);
  });

  testWidgets('a call screen up: the teardown stops the service and leaves '
      'its session', (tester) async {
    await installCallJoinDefaults();
    // The defaults answer the plugin's channel too: this test's recorder
    // takes it back.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, (MethodCall call) async {
          native.add(call.method);
          return null;
        });
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'call-1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();
    // What the call screen asked of the plugin as it joined (the ongoing-call
    // service) is not the teardown's.
    native.clear();

    await onAndroid(() async {
      CallsLifecycle.tearDownLocalCalls();
      await tester.pump();
    });

    expect(native, <String>['abortOngoingCallService', 'leaveSession']);
    expect(CallScreenOverlay.isShowing, isFalse);
  });

  test('a join asked for and not left: the teardown leaves it, once', () async {
    ActiveCallTracker.mayHaveMediaSession = true;

    await onAndroid(() async {
      CallsLifecycle.tearDownLocalCalls();
      await pumpEventQueue();
      // Left: a second teardown (the logout's stop) has nothing to leave.
      CallsLifecycle.stop();
      await pumpEventQueue();
    });

    expect(native, <String>['abortOngoingCallService', 'leaveSession']);
    expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
  });

  test('CometChatUIKitCalls.startSession marks a session to leave; the '
      'Calls SDK refusing the join clears the mark (round 3 review)', () {
    bool? markedWhenRefused;
    CometChatUIKitCalls.startSession(
      // Refused by the plugin at once, without the network.
      '',
      SessionSettingsBuilder().build(),
      onError: (_) => markedWhenRefused = ActiveCallTracker.mayHaveMediaSession,
    );

    expect(markedWhenRefused, isTrue);
    expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
  });

  test('endSession clears the mark', () async {
    ActiveCallTracker.mayHaveMediaSession = true;

    await CometChatUIKitCalls.endSession();

    expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
    expect(native, contains('leaveSession'));
  });

  test('endSession clears the mark when the leave fails too (round 3 '
      'review)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, (MethodCall call) async {
          native.add(call.method);
          if (call.method == 'leaveSession') {
            throw PlatformException(code: 'LEAVE_FAILED');
          }
          return null;
        });
    ActiveCallTracker.mayHaveMediaSession = true;
    Object? reported;

    await CometChatUIKitCalls.endSession(onError: (e) => reported = e);

    expect(native, contains('leaveSession'));
    expect(reported, isNotNull);
    expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
  });
}
