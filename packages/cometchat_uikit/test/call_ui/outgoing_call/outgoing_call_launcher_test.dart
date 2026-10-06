/// The one launch point for the outgoing call screen (round 2, P2-C03):
/// every call this device places — from the call buttons, the call logs'
/// call-back, or what a host builds on them — opens its screen here.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_launcher_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call_configuration.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show SessionSettingsBuilder;
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/outgoing_call_launcher.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;
  late List<Exception> errors;
  final service = CallEventService.instance;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    events = CallEventRecorder('outgoing_call_launcher_test');
    errors = <Exception>[];
    // The UI Kit's own listener, so ccOutgoingCall records the call.
    CometChatCallEvents.addCallEventsListener('CallEventService', service);
  });

  tearDown(() async {
    events.dispose();
    CometChatCallEvents.removeCallEventsListener('CallEventService');
    SoundChannelSpy.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    service.activeCall = null;
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  Call placed({AppEntity? callReceiver, AppEntity? receiver}) {
    final call = buildCall(sessionId: 'placed-1', receiverUid: 'bob');
    call.callReceiver = callReceiver;
    if (receiver != null) call.receiver = receiver;
    return call;
  }

  /// Follows [shown] without awaiting it: it completes on the test's fake
  /// clock, so an `await` of it hangs the run (widget tests ignore
  /// --timeout) instead of failing when the launcher never completes. Read
  /// `.value` after pumping.
  _Outcome follow(Future<bool> shown) {
    final _Outcome outcome = _Outcome();
    unawaited(shown.then((bool value) => outcome.value = value));
    return outcome;
  }

  CometChatOutgoingCall screen(WidgetTester tester) =>
      tester.widget<CometChatOutgoingCall>(find.byType(CometChatOutgoingCall));

  testWidgets('announces the call and pushes the screen on the next frame, '
      'not after 300 ms', (WidgetTester tester) async {
    await mountCallNavigator(tester);
    final call = placed();

    final shown = follow(
      OutgoingCallLauncher.show(
        call,
        epoch: CallsLifecycle.callEpoch,
        user: User(uid: 'bob', name: 'Bob'),
      ),
    );
    expect(events.ordered, <String>['outgoing:placed-1']);
    expect((service.activeCall as Call?)?.sessionId, 'placed-1');

    await tester.pump();
    expect(shown.value, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
    expect(screen(tester).user?.name, 'Bob');
    expect(screen(tester).call, same(call));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with no user given, the title is the receiver the server sent '
      'back', (WidgetTester tester) async {
    await mountCallNavigator(tester);

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(
          callReceiver: User(uid: 'bob', name: 'Bob Callee'),
          receiver: User(uid: 'bob', name: 'Bob Receiver'),
        ),
        epoch: CallsLifecycle.callEpoch,
      ),
    );
    await tester.pump();
    expect(shown.value, isTrue);
    await tester.pumpAndSettle();

    expect(screen(tester).user?.name, 'Bob Callee');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("then the call's receiver; with neither, no user", (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);

    final first = follow(
      OutgoingCallLauncher.show(
        placed(
          receiver: User(uid: 'bob', name: 'Bob Receiver'),
        ),
        epoch: CallsLifecycle.callEpoch,
      ),
    );
    await tester.pump();
    expect(first.value, isTrue);
    await tester.pumpAndSettle();
    expect(screen(tester).user?.name, 'Bob Receiver');

    CallNavigationContext.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    final second = follow(
      OutgoingCallLauncher.show(placed(), epoch: CallsLifecycle.callEpoch),
    );
    await tester.pump();
    expect(second.value, isTrue);
    await tester.pumpAndSettle();
    expect(screen(tester).user, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the whole configuration reaches the screen', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    void onError(Exception e) {}
    void onCancelled(BuildContext context, Call call) {}
    Widget subtitle(BuildContext context, Call call) => const Text('sub');
    Widget avatar(BuildContext context, Call call) => const Text('avatar');
    Widget title(BuildContext context, Call call) => const Text('title');
    Widget cancelled(BuildContext context, Call call) => const Text('end');
    const Widget icon = Icon(Icons.close);
    final SessionSettingsBuilder fromConfig = SessionSettingsBuilder();
    final configuration = CometChatOutgoingCallConfiguration(
      onError: onError,
      onCancelled: onCancelled,
      subtitleView: subtitle,
      avatarView: avatar,
      titleView: title,
      cancelledView: cancelled,
      declineButtonIcon: icon,
      disableSoundForCalls: true,
      customSoundForCalls: 'ring.mp3',
      customSoundForCallsPackage: 'host',
      sessionSettingsBuilder: fromConfig,
      height: 500,
      width: 300,
    );

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        configuration: configuration,
      ),
    );
    await tester.pump();
    expect(shown.value, isTrue);
    await tester.pumpAndSettle();

    final CometChatOutgoingCall s = screen(tester);
    expect(s.onError, same(onError));
    expect(s.onCancelled, same(onCancelled));
    expect(s.subtitleView, same(subtitle));
    expect(s.avatarView, same(avatar));
    expect(s.titleView, same(title));
    expect(s.cancelledView, same(cancelled));
    expect(s.declineButtonIcon, same(icon));
    expect(s.disableSoundForCalls, isTrue);
    expect(s.customSoundForCalls, 'ring.mp3');
    expect(s.customSoundForCallsPackage, 'host');
    expect(s.sessionSettingsBuilder, same(fromConfig));
    expect(s.height, 500);
    expect(s.width, 300);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("the caller's session settings win over the configuration's", (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    final SessionSettingsBuilder own = SessionSettingsBuilder();

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        configuration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
          sessionSettingsBuilder: SessionSettingsBuilder(),
        ),
        sessionSettingsBuilder: own,
      ),
    );
    await tester.pump();
    expect(shown.value, isTrue);
    await tester.pumpAndSettle();

    expect(screen(tester).sessionSettingsBuilder, same(own));
    await tester.pumpWidget(const SizedBox());
  });

  // Round 2 review: the call screen after an accept goes in the
  // navigatorKey's overlay, so a call shown on any other navigator rang and
  // could never be joined.
  testWidgets('no app navigator: another navigator on screen is not used; '
      'the call is cancelled and onError gets NO_NAVIGATOR', (
    WidgetTester tester,
  ) async {
    SoundChannelSpy.install();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        home: const Text('call logs'),
      ),
    );

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        onError: errors.add,
      ),
    );
    await tester.pump();
    expect(shown.value, isFalse);
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);

    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect((errors.first as CometChatException).code, 'NO_NAVIGATOR');
    expect(dataSource.calls, <String>['rejectCall:placed-1:cancelled']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no navigator at all: the call is released and cancelled, and '
      'onError gets NO_NAVIGATOR', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        onError: errors.add,
      ),
    );
    await tester.pump();
    expect(shown.value, isFalse);
    await tester.runAsync(pumpEventQueue);

    expect(service.activeCall, isNull);
    expect(dataSource.calls, <String>['rejectCall:placed-1:cancelled']);
    expect(events.ordered, <String>['outgoing:placed-1', 'rejected:placed-1']);
    expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
  });

  testWidgets('no navigator and the cancel fails: NO_NAVIGATOR first, then '
      "the SDK's code", (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    dataSource.rejectError = const CallOperationsException(
      message: 'Call already ended',
      code: 'ERR_CALL_ENDED',
    );

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        onError: errors.add,
      ),
    );
    await tester.pump();
    expect(shown.value, isFalse);
    await tester.runAsync(pumpEventQueue);

    expect(
      errors.map((Exception e) => (e as CometChatException).code),
      <String>['NO_NAVIGATOR', 'ERR_CALL_ENDED'],
    );
    // No event says it is over, so the record is released right here.
    expect(service.activeCall, isNull);
  });

  testWidgets('calls torn down while it waited for the frame (a logout): '
      'nothing shown, nothing sent, the record released', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);
    addTearDown(CallsLifecycle.debugReset);

    final shown = follow(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
        onError: errors.add,
      ),
    );
    CallsLifecycle.tearDownLocalCalls();
    service.activeCall = placed();
    await tester.pump();
    expect(shown.value, isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(dataSource.calls, isEmpty);
    expect(service.activeCall, isNull);
    expect(errors, isEmpty);
  });

  testWidgets('an app drawing no frames (in the background) still gets the '
      'screen, after a short wait', (WidgetTester tester) async {
    await mountCallNavigator(tester);

    bool? result;
    unawaited(
      OutgoingCallLauncher.show(
        placed(),
        epoch: CallsLifecycle.callEpoch,
      ).then((bool shown) => result = shown),
    );
    // Time passes with no frame drawn.
    await tester.binding.delayed(OutgoingCallLauncher.frameWaitLimit);
    await tester.idle();

    expect(result, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

/// What a launch completed with, once it has: see `follow`.
class _Outcome {
  bool? value;
}
