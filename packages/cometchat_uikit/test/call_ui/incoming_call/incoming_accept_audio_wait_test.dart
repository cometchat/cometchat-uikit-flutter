/// An accepted incoming call waits for the ringtone's native pause before
/// the call screen opens, one second at most (round 3, P3-C04; the review's
/// AH1 and AH2: neither bound was tested).
///
/// On iOS the ringtone's audio work runs on a queue of its own, and the
/// Calls engine must not start on the session before it is done; a native
/// side that never answers must not hold the call either.
///
///   flutter test test/call_ui/incoming_call/incoming_accept_audio_wait_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    CallOperationsServiceLocator.instance.setup(
      dataSource: FakeCallOperationsDataSource(),
    );
    incomingRingtoneLoop.reset();
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    incomingRingtoneLoop.reset();
    CallScreenOverlay.dismiss();
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  /// Holds the native answer to the accept's pause until [native] completes.
  void holdThePause(Completer<void> native) {
    SoundChannelSpy.onCall = (MethodCall call) async {
      final Map<Object?, Object?>? args =
          call.arguments as Map<Object?, Object?>?;
      if (call.method == 'stopRingtone' && args?['keepAudio'] == true) {
        await native.future;
      }
    };
  }

  testWidgets('the call screen opens once the native pause is done', (
    WidgetTester tester,
  ) async {
    await installCallJoinDefaults();
    addTearDown(removeCallJoinDefaults);
    await mountCallNavigator(tester);
    final Completer<void> native = Completer<void>();
    holdThePause(native);
    final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());

    bloc.add(const AcceptCall());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(CallScreenOverlay.isShowing, isFalse);

    native.complete();
    await tester.pump();
    await tester.pump();
    expect(CallScreenOverlay.isShowing, isTrue);

    CallScreenOverlay.dismiss();
    await tester.runAsync(bloc.close);
    await tester.pumpAndSettle();
  });

  testWidgets('a native side that never answers holds the call screen one '
      'second at most', (WidgetTester tester) async {
    await installCallJoinDefaults();
    addTearDown(removeCallJoinDefaults);
    await mountCallNavigator(tester);
    final Completer<void> native = Completer<void>();
    holdThePause(native);
    final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());

    bloc.add(const AcceptCall());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(CallScreenOverlay.isShowing, isFalse);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(CallScreenOverlay.isShowing, isTrue);

    native.complete();
    CallScreenOverlay.dismiss();
    await tester.runAsync(bloc.close);
    await tester.pumpAndSettle();
  });
}
