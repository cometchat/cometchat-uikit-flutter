/// Ending a 1-on-1 call from here (round 4, P4-C05 with the owner's end
/// order): the media session is left first, the screen closes at once, and
/// the server's endCall goes out in the background once the leave is done.
/// ccCallEnded fires when the server confirms, whether or not the screen
/// and its bloc are still there. Repeat taps are ignored.
///
/// Before: the screen waited for endCall to come back before it closed. On
/// the Android plugin the local leave fired the native onSessionLeft, whose
/// OngoingCallEnded closed the screen and the bloc while endCall was still
/// on its way, and the bloc's `if (isClosed) return` then dropped
/// ccCallEnded: the ender's chat bubble stayed on "Call accepted". A double
/// tap, or the peer-left rule plus a tap, ran a second leave and endCall and
/// raised a false error.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_end_order_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';

import '../helpers/call_bloc_harness.dart';

/// A datasource whose `endSession` hands the bloc the native "left" before
/// it returns, as the Android plugin does on a local leave; and whose leave
/// can be held ([leaveGate]).
class _AndroidLikeDataSource extends FakeCallOperationsDataSource {
  OngoingCallBloc? bloc;
  Completer<void>? leaveGate;

  @override
  Future<void> endSession() async {
    await leaveGate?.future;
    final OngoingCallBloc? b = bloc;
    if (b != null && !b.isClosed) b.add(const OngoingCallEnded());
    await super.endSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late _AndroidLikeDataSource dataSource;
  late CallEventRecorder events;
  late List<Exception> errors;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _AndroidLikeDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    events = CallEventRecorder('ongoing_call_end_order_test');
    errors = <Exception>[];
    service.activeCall = buildCall();
    CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me');
  });

  tearDown(() async {
    events.dispose();
    CallScreenOverlay.dismiss();
    removeCallJoinDefaults();
    service.activeCall = null;
    CometChatUIKit.loggedInUser = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  OngoingCallBloc buildBloc() {
    final OngoingCallBloc bloc = OngoingCallBloc(
      sessionSettingsBuilder: SessionSettingsBuilder(),
      sessionId: 'session_1',
      callWorkFlow: CallWorkFlow.defaultCalling,
      errorCallback: errors.add,
    );
    dataSource.bloc = bloc;
    addTearDown(bloc.close);
    return bloc;
  }

  Future<void> joined(OngoingCallBloc bloc) async {
    if (bloc.state.status == OngoingCallStatus.active) return;
    await bloc.stream.firstWhere(
      (OngoingCallState s) => s.status == OngoingCallStatus.active,
    );
  }

  /// Shows `session_1`'s call screen in the overlay and lets it join; the
  /// overlay's own bloc is the one returned.
  Future<OngoingCallBloc> showJoined(WidgetTester tester) async {
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      onError: errors.add,
    );
    await tester.pump();
    await tester.pump();
    final OngoingCallBloc bloc = overlayBloc(tester);
    dataSource.bloc = bloc;
    expect(bloc.state.status, OngoingCallStatus.active);
    return bloc;
  }

  test('P4-N01: the leave comes first, then endCall', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);

    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();

    expect(
      dataSource.calls.where((String c) => c.startsWith('end')).toList(),
      <String>['endSession', 'endCall:session_1'],
    );
  });

  test('endCall waits for the leave to finish', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);
    dataSource.leaveGate = Completer<void>();

    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();
    expect(dataSource.endCallCount, 0);

    dataSource.leaveGate!.complete();
    await pumpEventQueue();
    expect(dataSource.endCallCount, 1);
  });

  testWidgets('P4-E02 (Android plugin race): the native "left" during the '
      'local end: one endCall, one ccCallEnded, the screen closed once', (
    WidgetTester tester,
  ) async {
    final OngoingCallBloc bloc = await showJoined(tester);
    int dismissals = 0;
    CallStateService.instance.isActiveCall.addListener(() {
      if (!CallStateService.instance.isActiveCall.value) dismissals++;
    });

    bloc.add(const EndCallButtonPressed());
    await tester.pump(Duration.zero);
    await tester.pump();
    await tester.pump();

    expect(dataSource.endCallCount, 1);
    expect(dataSource.endSessionCount, 1);
    expect(events.ended.map((Call c) => c.sessionId), <String?>['session_1']);
    expect(events.ended.single.category, MessageCategoryConstants.call);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(dismissals, 1);
    expect(errors, isEmpty);
  });

  testWidgets('the screen closes at once, before endCall answers; '
      'ccCallEnded still fires once it does, after the bloc has closed', (
    WidgetTester tester,
  ) async {
    final OngoingCallBloc bloc = await showJoined(tester);
    dataSource.endCallGate = Completer<void>();

    bloc.add(const EndCallButtonPressed());
    await tester.pump(Duration.zero);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
    expect(CallStateService.instance.isActiveCall.value, isFalse);
    expect(dataSource.endCallCount, 1);
    expect(events.ended, isEmpty, reason: 'endCall has not answered yet');

    // The widget is gone, so its bloc closes.
    await tester.pump();
    expect(bloc.isClosed, isTrue);

    dataSource.endCallGate!.complete();
    await tester.pump(Duration.zero);
    expect(events.ended.map((Call c) => c.sessionId), <String?>['session_1']);
  });

  testWidgets('a failed endCall after the screen closed still reaches '
      "onError with the SDK's code (the owner: report everything)", (
    WidgetTester tester,
  ) async {
    final OngoingCallBloc bloc = await showJoined(tester);
    final CometChatException sdkError = CometChatException(
      'ERR_CALL_ENDED',
      'The call has already ended.',
      'Call already ended',
    );
    dataSource.endCallGate = Completer<void>();
    dataSource.endCallError = CallOperationsException(
      message: 'Call already ended',
      code: 'ERR_CALL_ENDED',
      originalException: sdkError,
    );

    bloc.add(const EndCallButtonPressed());
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(bloc.isClosed, isTrue);

    dataSource.endCallGate!.complete();
    await tester.pump(Duration.zero);

    expect(errors.single, same(sdkError));
    expect(events.ended, isEmpty);
  });

  test('two End taps: one leave, one endCall, no false error', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);

    bloc.add(const EndCallButtonPressed());
    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();

    expect(dataSource.endCallCount, 1);
    expect(dataSource.endSessionCount, 1);
    expect(errors, isEmpty);
  });

  test('the peer-left rule and an End tap: one endCall', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);
    bloc.add(
      ParticipantListChanged(<Participant>[
        Participant(uid: 'me'),
        Participant(uid: 'peer'),
      ]),
    );
    await pumpEventQueue();

    bloc.add(const ParticipantListChanged(<Participant>[]));
    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();

    expect(dataSource.endCallCount, 1);
    expect(dataSource.endSessionCount, 1);
  });

  test('the end goes out as a call request a logout waits for', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);
    dataSource.endCallGate = Completer<void>();

    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();
    expect(ActiveCallTracker.callRequestsInFlight, hasLength(1));

    dataSource.endCallGate!.complete();
    await pumpEventQueue();
    expect(ActiveCallTracker.callRequestsInFlight, isEmpty);
  });

  test('a logout that began while endCall was on its way owns the call: a '
      'failure is only logged', () async {
    final OngoingCallBloc bloc = buildBloc();
    await joined(bloc);
    dataSource.endCallGate = Completer<void>();
    dataSource.endCallError = const CallOperationsException(
      message: 'logged out',
      code: 'ERR_NOT_LOGGED_IN',
    );

    bloc.add(const EndCallButtonPressed());
    await pumpEventQueue();
    CallsLifecycle.tearDownLocalCalls();
    dataSource.endCallGate!.complete();
    await pumpEventQueue();

    expect(errors, isEmpty);
  });

  test(
    'the state: ending at once, then ended when the server confirms',
    () async {
      final OngoingCallBloc bloc = buildBloc();
      await joined(bloc);
      dataSource.endCallGate = Completer<void>();

      bloc.add(const EndCallButtonPressed());
      await pumpEventQueue();
      expect(bloc.state.status, OngoingCallStatus.ending);
      expect(bloc.state.isCallEndedByMe, isTrue);

      dataSource.endCallGate!.complete();
      await pumpEventQueue();
      expect(bloc.state.status, OngoingCallStatus.ended);
    },
  );
}

/// The [OngoingCallBloc] the overlay's call screen built: its call view
/// sits under the screen's BlocProvider.
OngoingCallBloc overlayBloc(WidgetTester tester) =>
    BlocProvider.of<OngoingCallBloc>(
      tester.element(find.byType(FakeCallingWidget)),
    );
