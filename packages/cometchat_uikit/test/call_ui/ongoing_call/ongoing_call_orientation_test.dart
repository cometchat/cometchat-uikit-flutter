/// The call screen's orientation: portrait during the call, and afterwards
/// what the app had before (round 4, P4-C16; round 4 review: API 4 and
/// native 8).
///
/// * Android: the UI Kit's plugin saves the activity's own requested
///   orientation before the portrait hold and puts exactly that back
///   (`holdCallOrientation` / `releaseCallOrientation`). Flutter's empty
///   list maps to "unspecified", which unlocked a manifest lock after every
///   call and lost an orientation the app set from code. Without the plugin
///   it falls back to `SystemChrome`.
/// * iOS: `SystemChrome`, the two portraits during the call and the empty
///   list (the Info.plist orientations) afterwards.
/// * The orientation is given back before `CallStateService.isActiveCall`
///   turns false, so an app that sets its own orientation then has the last
///   word. Round 4 had the order the other way round.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_orientation_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';

import '../helpers/call_bloc_harness.dart';

const MethodChannel _kitChannel = MethodChannel('cometchat_chat_uikit');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;

  /// Everything about the orientation and the call flag, in order:
  /// `portrait` / `unlocked` (SystemChrome), `hold` / `release` (the
  /// plugin), `no call` (CallStateService turning false).
  late List<String> events;

  /// What the plugin answers to hold and release; null: it is not there.
  bool? pluginAnswer;

  /// When set, the plugin answers the hold only once it completes.
  Completer<void>? holdGate;

  void Function()? flagListener;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = buildCall();
    events = <String>[];
    pluginAnswer = true;
    holdGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            events.add(
              (call.arguments as List<Object?>).isEmpty
                  ? 'unlocked'
                  : 'portrait',
            );
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kitChannel, (MethodCall call) async {
          switch (call.method) {
            case 'holdCallOrientation':
              events.add('hold');
              await holdGate?.future;
              if (pluginAnswer == null) throw MissingPluginException();
              return pluginAnswer;
            case 'releaseCallOrientation':
              events.add('release');
              if (pluginAnswer == null) throw MissingPluginException();
              return pluginAnswer;
          }
          return null;
        });
    void listener() {
      if (!CallStateService.instance.isActiveCall.value) events.add('no call');
    }

    flagListener = listener;
    CallStateService.instance.isActiveCall.addListener(listener);
  });

  tearDown(() async {
    CallStateService.instance.isActiveCall.removeListener(flagListener!);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockMethodCallHandler(_kitChannel, null);
    debugDefaultTargetPlatformOverride = null;
    CallScreenOverlay.dismiss();
    removeCallJoinDefaults();
    service.activeCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  OngoingCallBloc build() => OngoingCallBloc(
    sessionSettingsBuilder: SessionSettingsBuilder(),
    sessionId: 'session_1',
    callWorkFlow: CallWorkFlow.defaultCalling,
  );

  group('iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('portrait during the call; the empty list after it, before the call '
        'flag turns false (API 4)', () async {
      final OngoingCallBloc bloc = build();
      await pumpEventQueue();
      expect(events, <String>['portrait']);

      await bloc.close();
      await pumpEventQueue();

      expect(events, <String>['portrait', 'unlocked', 'no call']);
    });

    testWidgets('the screen of an ended call gives it back at once, before '
        'its bloc closes', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      events.clear();

      CallSession.getInstance()!.buttonClickListeners.toList().forEach(
        (ButtonClickListeners l) => l.onLeaveSessionButtonClicked(),
      );
      await tester.pump(Duration.zero);

      expect(events, <String>['unlocked', 'no call']);
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('Android', () {
    test(
      "native 8: the plugin holds the activity in portrait and puts the "
      "activity's own orientation back; nothing goes through SystemChrome",
      () async {
        final OngoingCallBloc bloc = build();
        await pumpEventQueue();
        expect(events, <String>['hold']);

        await bloc.close();
        await pumpEventQueue();

        expect(events, <String>['hold', 'release', 'no call']);
      },
    );

    test('without the plugin it falls back to SystemChrome', () async {
      pluginAnswer = null;
      final OngoingCallBloc bloc = build();
      await pumpEventQueue();
      expect(events, <String>['hold', 'portrait']);

      await bloc.close();
      await pumpEventQueue();

      expect(events, <String>[
        'hold',
        'portrait',
        'release',
        'no call',
        'unlocked',
      ]);
    });

    test('a screen that closes while the plugin is still answering the hold '
        'is not left in portrait by the fallback', () async {
      pluginAnswer = null;
      holdGate = Completer<void>();
      final OngoingCallBloc bloc = build();
      await pumpEventQueue();

      await bloc.close();
      holdGate!.complete();
      await pumpEventQueue();

      expect(events, isNot(contains('portrait')));
      expect(events.last, 'unlocked');
    });

    testWidgets('a replaced screen gives nothing back; the screen that '
        'replaced it does, once', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      // The kit channel answers again (mountCallNavigator's spy took it).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_kitChannel, (MethodCall call) async {
            if (call.method == 'holdCallOrientation') events.add('hold');
            if (call.method == 'releaseCallOrientation') events.add('release');
            return true;
          });
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      CallScreenOverlay.show(
        sessionId: 'session_2',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      expect(events, <String>['hold', 'hold']);

      CallScreenOverlay.dismiss();
      await tester.pump();

      expect(events, <String>['hold', 'hold', 'release', 'no call']);
    });
  });
}
