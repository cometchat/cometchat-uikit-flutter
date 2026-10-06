/// The audio the ringback or the ringtone handed to a call is given back on
/// every way a call screen that owns the call closes before the native join
/// (round 4 review: API 5, correctness 4, native 3, regression 1, probes A1
/// and A2).
///
/// Round 4 gave it back only from the failed-join exit. Back on
/// "Connecting...", End before the call view had joined natively, a remote
/// end or a timeout during the join, and a screen taken down from outside
/// all left it with the call: on Android the phone stayed in communication
/// mode with the earpiece routed (voice notes then played from the
/// earpiece), on iOS the session stayed active and music never resumed. It
/// is given back once the screen's own leave (if any) is done, or after
/// 2 s, and only while the call has not joined natively: once it has, the
/// Calls engine has the audio and the hand-over is only forgotten.
///
/// A participant event that the leave itself causes is not a join: it must
/// not forget the audio the close is about to give back (correctness 12).
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_audio_handback_test.dart
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
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

/// A datasource whose leave can be held ([leaveGate]) and that can answer
/// it with a native participant event ([onLeave]).
class _HeldLeave extends FakeCallOperationsDataSource {
  Completer<void>? leaveGate;
  void Function()? onLeave;

  @override
  Future<void> endSession() async {
    onLeave?.call();
    await leaveGate?.future;
    await super.endSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late _HeldLeave dataSource;

  /// What happened, in order: `leave` when the leave is asked for, and
  /// `restore` or `forget` for each hand-over release.
  late List<String> order;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _HeldLeave();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = buildCall();
    CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me');
    order = <String>[];
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    SoundChannelSpy.remove();
    removeCallJoinDefaults();
    service.activeCall = null;
    CometChatUIKit.loggedInUser = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Mounts the app and records the hand-over releases and the leaves.
  Future<void> mount(WidgetTester tester) async {
    await mountCallNavigator(tester);
    SoundChannelSpy.onCall = (MethodCall c) async {
      if (c.method == 'releaseHandedOverCallAudio') {
        final bool restore =
            (c.arguments as Map<Object?, Object?>)['restore']! as bool;
        order.add(restore ? 'restore' : 'forget');
      }
    };
    final void Function()? previous = dataSource.onLeave;
    dataSource.onLeave = () {
      order.add('leave');
      previous?.call();
    };
  }

  /// Shows `session_1`'s call screen; with [joinHeld] its join stays on its
  /// way (the screen on "Connecting...").
  Future<Completer<Widget>?> show(
    WidgetTester tester, {
    bool joinHeld = false,
    CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
  }) async {
    Completer<Widget>? join;
    if (joinHeld) {
      join = Completer<Widget>();
      dataSource.onStartSession = (_) => join!.future;
    }
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: workFlow,
    );
    await tester.pump();
    await tester.pump();
    return join;
  }

  void sdkSessionJoined() {
    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      l.onSessionJoined();
    }
  }

  void sdkSessionLeft() {
    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      l.onSessionLeft();
    }
  }

  void sdkEndTapped() {
    for (final ButtonClickListeners l in List.of(
      CallSession.getInstance()!.buttonClickListeners,
    )) {
      l.onLeaveSessionButtonClicked();
    }
  }

  testWidgets('probe A1: back while connecting gives the audio back (nothing '
      'joined, so nothing to leave first)', (WidgetTester tester) async {
    await mount(tester);
    final Completer<Widget> join = (await show(tester, joinHeld: true))!;
    expect(find.text('Connecting...'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(Duration.zero);
    await tester.pump();
    join.complete(const FakeCallingWidget());
    await tester.pump(const Duration(seconds: 3));

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(order, <String>['restore']);
  });

  testWidgets('probe A2: the remote end before the native join gives the '
      'audio back once the session was left', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);
    expect(find.byType(FakeCallingWidget), findsOneWidget);

    service.onCallEndedMessageReceived(buildCall());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(order, <String>['restore']);
  });

  testWidgets('End after the call view appeared, before the native join: the '
      'leave first, the audio given back only once it is done', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    await show(tester);
    dataSource.leaveGate = Completer<void>();

    sdkEndTapped();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(order, <String>['leave']);

    dataSource.leaveGate!.complete();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(order, <String>['leave', 'restore']);
    expect(dataSource.endCallCount, 1);
  });

  testWidgets('a leave that never returns: the audio is given back after 2 s '
      '(R08)', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);
    dataSource.leaveGate = Completer<void>();

    sdkEndTapped();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(order, <String>['leave']);

    await tester.pump(const Duration(milliseconds: 200));
    expect(order, <String>['leave', 'restore']);
    dataSource.leaveGate!.complete();
  });

  testWidgets('a meeting left with End before its native join: given back '
      'after the leave', (WidgetTester tester) async {
    await mount(tester);
    await show(tester, workFlow: CallWorkFlow.directCalling);
    dataSource.leaveGate = Completer<void>();

    sdkEndTapped();
    await tester.pump(Duration.zero);
    expect(order, <String>['leave']);

    dataSource.leaveGate!.complete();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(order, <String>['leave', 'restore']);
    expect(CallScreenOverlay.isShowing, isFalse);
  });

  testWidgets("the session's own end before the native join (a 1-on-1 call "
      'the other side ended): given back after the leave', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    await show(tester);

    sdkSessionLeft();
    await tester.pump(Duration.zero);
    await tester.pump();
    await tester.pump();

    expect(order, <String>['leave', 'restore']);
    expect(CallScreenOverlay.isShowing, isFalse);
  });

  testWidgets("the screen taken down while the session's own end is still "
      'leaving: the audio waits for that leave', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);
    dataSource.leaveGate = Completer<void>();

    sdkSessionLeft();
    await tester.pump(Duration.zero);
    CallScreenOverlay.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(order, <String>['leave'], reason: 'the leave has not returned');

    dataSource.leaveGate!.complete();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(order, <String>['leave', 'restore']);
  });

  testWidgets('a session timeout before the native join: given back after '
      'the leave', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);

    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      l.onSessionTimedOut();
    }
    await tester.pump(Duration.zero);
    await tester.pump();
    await tester.pump();

    expect(order, <String>['leave', 'restore']);
  });

  testWidgets('a screen taken down from outside before the native join: '
      'given back after the safety-net leave', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);

    CallScreenOverlay.dismiss();
    await tester.pump();
    await tester.pump();

    expect(order, <String>['leave', 'restore']);
  });

  testWidgets('once the call joined natively, End gives nothing back: the '
      'hand-over was only forgotten', (WidgetTester tester) async {
    await mount(tester);
    await show(tester);
    sdkSessionJoined();
    await tester.pump();

    sdkEndTapped();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 3));

    expect(order, <String>['forget', 'leave']);
  });

  testWidgets('correctness 12: a participant event the leave causes is not a '
      'join, and does not forget the audio the close gives back', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    dataSource.onLeave = () {
      order.add('leave');
      for (final ParticipantEventListeners l in List.of(
        CallSession.getInstance()!.participantEventListeners,
      )) {
        l.onParticipantListChanged(<Participant>[Participant(uid: 'me')]);
      }
    };
    ActiveCallTracker.nativeJoinTimeout = const Duration(seconds: 30);
    await show(tester);

    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(order, <String>['leave', 'restore']);
  });
}
