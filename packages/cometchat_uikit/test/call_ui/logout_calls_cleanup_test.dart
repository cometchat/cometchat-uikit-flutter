/// CometChatUIKit.logout ends this device's calls on the server first, then
/// takes them down locally, then logs the chat SDK out (round 1b: P1-C09,
/// P3-C22, P4-C20).
///
/// It used to tear call handling down first and send nothing: the caller
/// kept ringing for a callee who had logged out, the other party of a call
/// in progress sat alone in it, a call screen could stay above the login
/// screen (iOS never reports the session left after a local leave), and a
/// logout that failed still left the user without call listeners.
///
/// Owner decisions: best effort within ~3 s — decline a ringing incoming
/// call ("rejected"), cancel my ringing outgoing call ("cancelled"), end an
/// active 1-on-1 call, only leave a meeting — then local teardown, then the
/// chat logout. On success call handling stops and the Calls SDK logs out;
/// on failure the call listeners stay.
///
/// The chat SDK is a fake behind `ChatAuthGateway` that writes into the same
/// log as the fake call operations, so their order can be checked.
///
///   flutter test test/call_ui/logout_calls_cleanup_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/ui_kit_settings.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';
import 'package:cometchat_chat_uikit/src/chat_auth_gateway.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';
import 'helpers/fake_chat_auth_gateway.dart';

final _me = User(uid: 'uid-1', name: 'One');

Call _call(String sessionId, {String status = 'ongoing'}) => Call(
  sessionId: sessionId,
  receiverUid: 'peer',
  receiverType: 'user',
  type: 'audio',
  callStatus: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;
  late FakeChatAuthGateway chat;
  late FakeCallsSdkGateway calls;
  late Map<String, CallListener> chatListeners;
  late Map<String, CometChatCallEventListener> savedBus;
  late CallEventRecorder events;
  late List<String> host;

  /// Runs CometChatUIKit.logout, recording the host callbacks in [host].
  Future<void> logout() => CometChatUIKit.logout(
    onSuccess: (_) => host.add('onSuccess'),
    onError: (e) => host.add('onError:${e.code}'),
  );

  /// Lets every fake answer and whatever it starts run, without moving the
  /// clock.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    // The chat SDK logs into the same list as the call operations.
    chat = FakeChatAuthGateway(dataSource.calls)
      ..loggedInUser = _me
      ..authToken = 'chat-token-uid-1';
    ChatAuthGateway.debugInstance = chat;
    calls = await installReadyCallsSdk(
      gateway: FakeCallsSdkGateway(chatToken: 'chat-token-uid-1'),
    );

    savedBus = Map.of(CometChatCallEvents.callEventsListener);
    CometChatCallEvents.callEventsListener.clear();
    chatListeners = <String, CallListener>{};
    CallsLifecycle.addChatCallListener = (id, listener) =>
        chatListeners[id] = listener;
    CallsLifecycle.removeChatCallListener = (id) => chatListeners.remove(id);

    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()
              ..appId = 'app-1'
              ..region = 'eu'
              ..authKey = 'auth-key'
              ..enableCalls = true)
            .build();
    CometChatUIKit.loggedInUser = _me;
    await CallsLifecycle.start(_me);
    // After the start: stop() on a logout resets the locator, and the tests
    // read what reached this one.
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    events = CallEventRecorder('logout_calls_cleanup_test');
    host = <String>[];
    PermissionChannelStub.install(granted: true);
    dataSource.calls.clear();
  });

  tearDown(() async {
    events.dispose();
    PermissionChannelStub.remove();
    SoundChannelSpy.remove();
    CallsLifecycle.debugReset();
    uninstallCallsSdk();
    ChatAuthGateway.debugInstance = null;
    CometChatUIKit.loggedInUser = null;
    CometChatUIKit.authenticationSettings = null;
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CometChatCallEvents.callEventsListener
      ..clear()
      ..addAll(savedBus);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  group('server clean-up comes before the chat logout', () {
    test('an incoming call still ringing is declined', () async {
      ActiveCallTracker.ringingCall = _call('ring-1', status: 'initiated');

      await logout();

      expect(dataSource.calls, <String>[
        'rejectCall:ring-1:rejected',
        'chat logout',
      ]);
      expect(events.ordered, <String>['rejected:ring-1']);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(host, <String>['onSuccess']);
    });

    test('my outgoing call still ringing is cancelled, and its screen closes '
        'without a second cancel', () async {
      final placed = _call('placed-1', status: 'initiated');
      service.activeCall = placed;
      final bloc = OutgoingCallBloc(call: placed, disableSoundForCalls: true);

      await logout();
      await bloc.close();
      await pumpEventQueue();

      expect(dataSource.calls, <String>[
        'rejectCall:placed-1:cancelled',
        'chat logout',
      ]);
      expect(service.activeCall, isNull);
    });

    test('a placed call with no screen, still ringing, is cancelled', () async {
      service.activeCall = _call('placed-2', status: 'initiated');

      await logout();

      expect(dataSource.calls, <String>[
        'rejectCall:placed-2:cancelled',
        'chat logout',
      ]);
    });

    test('an answered 1-on-1 call is ended', () async {
      service.activeCall = _call('call-1');

      await logout();

      expect(dataSource.calls, <String>['endCall:call-1', 'chat logout']);
      expect(events.ordered, <String>['ended:call-1']);
      expect(service.activeCall, isNull);
    });

    test('one request per call, whichever record holds it', () async {
      final placed = _call('placed-3', status: 'initiated');
      service.activeCall = placed;
      ActiveCallTracker.ringingCall = _call('ring-2', status: 'initiated');
      final bloc = OutgoingCallBloc(call: placed, disableSoundForCalls: true);
      addTearDown(bloc.close);

      await logout();

      expect(dataSource.calls, <String>[
        'rejectCall:ring-2:rejected',
        'rejectCall:placed-3:cancelled',
        'chat logout',
      ]);
    });

    test('with no calls nothing is sent but the chat logout', () async {
      await logout();

      expect(dataSource.calls, <String>['chat logout']);
      expect(host, <String>['onSuccess']);
    });

    testWidgets('a hung network holds the chat logout back 3 s at most', (
      tester,
    ) async {
      dataSource.rejectGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-3', status: 'initiated');

      unawaited(logout());
      await tester.pump(const Duration(milliseconds: 2900));
      expect(dataSource.calls, <String>['rejectCall:ring-3:rejected']);

      await tester.pump(const Duration(milliseconds: 200));
      expect(dataSource.calls.last, 'chat logout');
      await tester.pump();
      expect(host, <String>['onSuccess']);
      // The local teardown happened anyway.
      expect(ActiveCallTracker.ringingCall, isNull);
    });
  });

  group('local teardown', () {
    testWidgets('a 1-on-1 call screen is ended on the server and closed', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      service.activeCall = _call('call-2');
      CallScreenOverlay.show(
        sessionId: 'call-2',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();

      await tester.runAsync(logout);
      await tester.pump();

      // The call screen joined first; then the end, then the chat logout.
      final log = dataSource.calls;
      expect(log, contains('endCall:call-2'));
      expect(log.last, 'chat logout');
      expect(
        log.indexOf('endCall:call-2'),
        lessThan(log.indexOf('chat logout')),
      );
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(find.text('chat'), findsOneWidget);
    });

    testWidgets('a meeting on screen is only left: nothing is sent, the '
        'screen is closed', (tester) async {
      await mountCallNavigator(tester);
      CallScreenOverlay.show(
        sessionId: 'group-1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
        callWorkFlow: CallWorkFlow.directCalling,
      );
      await tester.pump();

      await tester.runAsync(logout);
      await tester.pump();

      expect(
        dataSource.calls.where((c) => !c.startsWith('startSession')),
        <String>['waitForCallsSdk', 'chat logout'],
      );
      expect(CallScreenOverlay.isShowing, isFalse);
    });

    testWidgets('an accept that lands after the logout began opens no call '
        'screen and ends the call', (tester) async {
      await mountCallNavigator(tester);
      dataSource.acceptGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-4', status: 'initiated');
      final bloc = IncomingCallBloc(
        call: _call('ring-4', status: 'initiated'),
        disableSoundForCalls: true,
      );

      bloc.add(const AcceptCall());
      await tester.pump();
      await tester.pump();
      expect(dataSource.calls, contains('acceptCall:ring-4'));

      // The logout starts while the accept is on the wire, and the accept
      // then goes through. (Only the logout's call clean-up runs here: the
      // chat logout that follows resets the call operations this test
      // watches.)
      final preparing = CallsLifecycle.prepareForLogout();
      dataSource.acceptGate!.complete();
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => preparing);
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.calls, contains('endCall:ring-4'));
      expect(service.activeCall, isNull);

      await tester.runAsync(bloc.close);
    });
  });

  group('the logout window (round 1b review)', () {
    // A logout takes up to 3 s to clean up before the chat logout. Anything
    // placed or accepted around then used to slip through: a call being
    // placed was never cancelled, an accept on the wire was declined by the
    // logout and then ended, and a tap during the clean-up opened a call
    // nothing ended.

    testWidgets('a call being placed when the logout starts is waited for, '
        'cancelled before the chat logout, and never shown', (tester) async {
      await mountCallNavigator(tester);
      dataSource.initiateGate = Completer<void>();
      final bloc = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );
      bloc.add(const InitiateVoiceCall());
      await settle(tester);
      expect(dataSource.calls, <String>['initiateCall:peer']);

      unawaited(logout());
      await settle(tester);
      expect(dataSource.calls, <String>['initiateCall:peer']);

      dataSource.initiateGate!.complete();
      await settle(tester);
      // Past the 300 ms push, and a frame more for a pushed route to come on
      // stage.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(dataSource.calls, <String>[
        'initiateCall:peer',
        'rejectCall:placed:cancelled',
        'chat logout',
      ]);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(events.outgoing, isEmpty);
      expect(bloc.state.isDisabled, isFalse);
      expect(host, <String>['onSuccess']);
      await tester.runAsync(bloc.close);
    });

    testWidgets('a call placed just before the logout is cancelled by it, '
        'and its screen, due 300 ms later, is not shown', (tester) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );
      bloc.add(const InitiateVoiceCall());
      await settle(tester);
      expect((service.activeCall as Call?)?.sessionId, 'placed');

      unawaited(logout());
      await settle(tester);
      // Past the 300 ms push, and a frame more for a pushed route to come on
      // stage.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(dataSource.calls, <String>[
        'initiateCall:peer',
        'rejectCall:placed:cancelled',
        'chat logout',
      ]);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(bloc.state.isCallInProgress, isFalse);
      await tester.runAsync(bloc.close);
    });

    testWidgets('an accept on the wire when the logout starts: its call is '
        'ended, not declined as well, before the chat logout', (tester) async {
      await mountCallNavigator(tester);
      dataSource.acceptGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-7', status: 'initiated');
      final bloc = IncomingCallBloc(
        call: _call('ring-7', status: 'initiated'),
        disableSoundForCalls: true,
      );
      bloc.add(const AcceptCall());
      await settle(tester);
      expect(dataSource.calls, <String>['acceptCall:ring-7']);

      unawaited(logout());
      await settle(tester);
      expect(dataSource.calls, <String>['acceptCall:ring-7']);

      dataSource.acceptGate!.complete();
      await settle(tester);

      expect(dataSource.calls, <String>[
        'acceptCall:ring-7',
        'endCall:ring-7',
        'chat logout',
      ]);
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(host, <String>['onSuccess']);
      await tester.runAsync(bloc.close);
    });

    testWidgets('an accept that fails after the logout began is not reported', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      dataSource
        ..acceptGate = Completer<void>()
        ..acceptError = const CallOperationsException(
          message: 'The call was rejected.',
          code: 'ERR_CALL_REJECTED',
        );
      ActiveCallTracker.ringingCall = _call('ring-8', status: 'initiated');
      final errors = <Exception>[];
      final bloc = IncomingCallBloc(
        call: _call('ring-8', status: 'initiated'),
        disableSoundForCalls: true,
        errorCallback: errors.add,
      );
      bloc.add(const AcceptCall());
      await settle(tester);

      unawaited(logout());
      await settle(tester);
      dataSource.acceptGate!.complete();
      await settle(tester);

      expect(dataSource.calls, <String>['acceptCall:ring-8', 'chat logout']);
      expect(errors, isEmpty);
      expect(ActiveCallTracker.ringingCall, isNull);
      await tester.runAsync(bloc.close);
    });

    testWidgets('Accept tapped while the logout cleans up does nothing', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      dataSource.rejectGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-9', status: 'initiated');
      final bloc = IncomingCallBloc(
        call: _call('ring-9', status: 'initiated'),
        disableSoundForCalls: true,
      );

      unawaited(logout());
      await settle(tester);
      expect(dataSource.calls, <String>['rejectCall:ring-9:rejected']);

      bloc.add(const AcceptCall());
      await settle(tester);
      expect(dataSource.calls, <String>['rejectCall:ring-9:rejected']);

      dataSource.rejectGate!.complete();
      await settle(tester);
      expect(dataSource.calls, <String>[
        'rejectCall:ring-9:rejected',
        'chat logout',
      ]);
      await tester.runAsync(bloc.close);
    });

    testWidgets('a call tapped while the logout cleans up is not placed', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      dataSource.rejectGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-10', status: 'initiated');
      final bloc = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );

      unawaited(logout());
      await settle(tester);
      bloc.add(const InitiateVoiceCall());
      await settle(tester);

      dataSource.rejectGate!.complete();
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(dataSource.calls, <String>[
        'rejectCall:ring-10:rejected',
        'chat logout',
      ]);
      expect(bloc.state.isDisabled, isFalse);
      await tester.runAsync(bloc.close);
    });

    testWidgets('an accept waiting on the permission prompt when the logout '
        'starts is not sent', (tester) async {
      await mountCallNavigator(tester);
      PermissionChannelStub.gate = Completer<void>();
      dataSource.rejectGate = Completer<void>();
      ActiveCallTracker.ringingCall = _call('ring-11', status: 'initiated');
      final bloc = IncomingCallBloc(
        call: _call('ring-11', status: 'initiated'),
        disableSoundForCalls: true,
      );
      bloc.add(const AcceptCall());
      await settle(tester);

      // The user answers the prompt while the logout is still declining.
      unawaited(logout());
      await settle(tester);
      PermissionChannelStub.gate!.complete();
      await settle(tester);
      expect(dataSource.calls, <String>['rejectCall:ring-11:rejected']);

      dataSource.rejectGate!.complete();
      await settle(tester);
      expect(dataSource.calls, <String>[
        'rejectCall:ring-11:rejected',
        'chat logout',
      ]);
      expect(CallScreenOverlay.isShowing, isFalse);
      await tester.runAsync(bloc.close);
    });

    testWidgets('an outgoing screen the host takes down during the clean-up '
        'sends no second cancel', (tester) async {
      dataSource.rejectGate = Completer<void>();
      final placed = _call('placed-5', status: 'initiated');
      service.activeCall = placed;
      final bloc = OutgoingCallBloc(call: placed, disableSoundForCalls: true);

      unawaited(logout());
      await settle(tester);
      expect(dataSource.calls, <String>['rejectCall:placed-5:cancelled']);

      // The host navigates away while the logout's cancel is on the wire.
      await tester.runAsync(bloc.close);
      await settle(tester);
      dataSource.rejectGate!.complete();
      await settle(tester);

      expect(dataSource.calls, <String>[
        'rejectCall:placed-5:cancelled',
        'chat logout',
      ]);
    });
  });

  group('what the local teardown takes down', () {
    testWidgets('the outgoing call screen on the navigator', (tester) async {
      await mountCallNavigator(tester);
      final placed = _call('placed-4', status: 'initiated');
      service.activeCall = placed;
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CometChatOutgoingCall(call: placed, disableSoundForCalls: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);

      unawaited(logout());
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(find.text('chat'), findsOneWidget);
      // Cancelled once, by the logout; closing the screen sends nothing.
      expect(dataSource.calls, <String>[
        'rejectCall:placed-4:cancelled',
        'chat logout',
      ]);
    });

    testWidgets('the incoming call banner', (tester) async {
      await mountCallNavigator(tester);
      final ringing = _call('ring-12', status: 'initiated');
      ActiveCallTracker.ringingCall = ringing;
      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: ringing,
        user: User(uid: 'peer', name: 'Peer'),
        disableSoundForCalls: true,
      );
      await tester.pump();
      expect(find.byType(CometChatIncomingCall), findsOneWidget);

      unawaited(logout());
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(ActiveCallTracker.incomingCallSessionId, isNull);
    });
  });

  group('after the chat logout', () {
    test('success: call handling stops and the Calls SDK logs out before '
        "the host's onSuccess", () async {
      late bool startedAtSuccess;
      late int callsLogoutsAtSuccess;
      late User? userAtSuccess;

      await CometChatUIKit.logout(
        onSuccess: (_) {
          startedAtSuccess = CallsLifecycle.isStarted;
          callsLogoutsAtSuccess = calls.logoutCount;
          userAtSuccess = CometChatUIKit.loggedInUser;
        },
      );

      expect(startedAtSuccess, isFalse);
      expect(callsLogoutsAtSuccess, 1);
      expect(userAtSuccess, isNull);
      expect(chatListeners, isEmpty);
      expect(
        CometChatCallEvents.callEventsListener.containsKey(
          CallsLifecycle.callListenerId,
        ),
        isFalse,
      );
    });

    testWidgets('a Calls SDK logout stuck behind a Calls login in flight '
        "holds the host's onSuccess back 5 s at most (round 1b review)", (
      tester,
    ) async {
      final stuck = FakeCallsSdkGateway(chatToken: 'chat-token-uid-1')
        ..onLogin = ((_) => Completer<void>().future)
        ..onLogout = (() => Completer<void>().future);
      installCallsSdk(stuck);
      // A Calls login is on its way when the user logs out.
      unawaited(CallsSdkSession.instance.ensureReady());
      await settle(tester);
      expect(stuck.loginCount, 1);

      unawaited(logout());
      await settle(tester);
      expect(dataSource.calls, <String>['chat logout']);

      await tester.pump(const Duration(milliseconds: 4900));
      expect(host, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(host, <String>['onSuccess']);

      // Let the rest run out (the login, the Calls logout, ensureReady).
      await tester.pump(const Duration(seconds: 30));
    });

    test('failure: onError, and the call listeners stay for the user who is '
        'still logged in', () async {
      chat.logoutError = CometChatException('ERR_NETWORK', 'offline', 'x');
      ActiveCallTracker.ringingCall = _call('ring-5', status: 'initiated');

      await logout();

      expect(host, <String>['onError:ERR_NETWORK']);
      expect(CallsLifecycle.isStarted, isTrue);
      expect(chatListeners[CallsLifecycle.callListenerId], same(service));
      expect(
        CometChatCallEvents.callEventsListener[CallsLifecycle.callListenerId],
        same(service),
      );
      expect(calls.logoutCount, 0);
      expect(CometChatUIKit.loggedInUser, same(_me));
      // The clean-up still ran: the call was declined while the user could
      // be heard.
      expect(dataSource.calls.first, 'rejectCall:ring-5:rejected');
    });
  });

  group('a user switch through CometChatUIKit.login (round 1b)', () {
    test("the previous user's calls are cleaned up, as them, before the new "
        'chat login', () async {
      ActiveCallTracker.ringingCall = _call('ring-6', status: 'initiated');
      service.activeCall = _call('call-4');
      calls.chatToken = 'chat-token-uid-2';

      await CometChatUIKit.login(
        'uid-2',
        onSuccess: (user) => host.add('onSuccess:${user.uid}'),
      );

      expect(dataSource.calls.take(3), <String>[
        'rejectCall:ring-6:rejected',
        'endCall:call-4',
        'chat login:uid-2',
      ]);
      expect(host, <String>['onSuccess:uid-2']);
      expect(CallsLifecycle.uid, 'uid-2');
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(service.activeCall, isNull);
    });

    testWidgets('an accept that lands after another user logged in does not '
        'end the call as them', (tester) async {
      await mountCallNavigator(tester);
      dataSource.acceptGate = Completer<void>();
      calls.chatToken = 'chat-token-uid-2';
      ActiveCallTracker.ringingCall = _call('ring-13', status: 'initiated');
      final bloc = IncomingCallBloc(
        call: _call('ring-13', status: 'initiated'),
        disableSoundForCalls: true,
      );
      bloc.add(const AcceptCall());
      await settle(tester);

      // The clean-up gives up on the accept after 3 s; uid-2 logs in.
      unawaited(CometChatUIKit.login('uid-2'));
      await settle(tester);
      await tester.pump(CallsLifecycle.logoutCleanupTimeout);
      await settle(tester);
      expect(CallsLifecycle.uid, 'uid-2');
      // The switch reset the call operations; watch the new ones too.
      await CallOperationsServiceLocator.instance.reset();
      CallOperationsServiceLocator.instance.setup(dataSource: dataSource);

      dataSource.acceptGate!.complete();
      await settle(tester);

      expect(dataSource.calls, <String>[
        'acceptCall:ring-13',
        'chat login:uid-2',
        'chat login returned',
      ]);
      expect(CallScreenOverlay.isShowing, isFalse);
      await tester.runAsync(bloc.close);
    });

    testWidgets('a call placed that lands after another user logged in is not '
        'cancelled as them', (tester) async {
      await mountCallNavigator(tester);
      dataSource.initiateGate = Completer<void>();
      calls.chatToken = 'chat-token-uid-2';
      final bloc = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );
      bloc.add(const InitiateVoiceCall());
      await settle(tester);

      unawaited(CometChatUIKit.login('uid-2'));
      await settle(tester);
      await tester.pump(CallsLifecycle.logoutCleanupTimeout);
      await settle(tester);
      expect(CallsLifecycle.uid, 'uid-2');
      // The switch reset the call operations; watch the new ones too.
      await CallOperationsServiceLocator.instance.reset();
      CallOperationsServiceLocator.instance.setup(dataSource: dataSource);

      dataSource.initiateGate!.complete();
      await settle(tester);
      // Past the 300 ms push, and a frame more for a pushed route to come on
      // stage.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(dataSource.calls, <String>[
        'initiateCall:peer',
        'chat login:uid-2',
        'chat login returned',
      ]);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      await tester.runAsync(bloc.close);
    });

    test('the same user logging in again cleans nothing up', () async {
      service.activeCall = _call('call-5');

      await CometChatUIKit.login('uid-1');

      expect(dataSource.calls, isEmpty);
      expect((service.activeCall as Call?)?.sessionId, 'call-5');
    });
  });

  testWidgets('CallEventService.dispose() closes the call screen and frees '
      'the device', (tester) async {
    await mountCallNavigator(tester);
    service.activeCall = _call('call-3');
    CallScreenOverlay.show(
      sessionId: 'call-3',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();
    expect(CallScreenOverlay.isShowing, isTrue);

    service.dispose();
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(ActiveCallTracker.callScreenSessionId, isNull);
    expect(service.activeCall, isNull);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
    // Local only: nothing reached the server.
    expect(dataSource.calls.where((c) => c.startsWith('endCall')), isEmpty);
    await tester.runAsync(pumpEventQueue);
  });
}
