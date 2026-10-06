/// CallEventService start/stop (round 1a, P1-C02, with P3-C01/C02 kit side).
///
/// * The call listeners are registered first, synchronously, before the
///   Calls SDK is waited for, so an incoming call rings while the Calls SDK
///   is still initialising.
/// * init() is re-entrant: concurrent calls share one start.
/// * dispose() during a start leaves nothing behind, and the start's late
///   results are dropped.
/// * A start for another user stops the previous one first (locally), and
///   the echo filter reads the user at event time.
/// * A host's direct CometChat.login/logout is followed.
///
///   flutter test test/call_ui/call_event_service_lifecycle_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/calling_configuration.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/ui_kit_settings.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calling_configuration_resolver.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';
import 'package:cometchat_chat_uikit/src/chat_auth_gateway.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';

final _me = User(uid: 'uid-1', name: 'One');
final _three = User(uid: 'uid-3', name: 'Three');
final _peer = User(uid: 'peer', name: 'Peer');

Call _incoming(String sessionId, {User? from}) => Call(
  sessionId: sessionId,
  receiverUid: 'uid-1',
  type: 'audio',
  receiverType: 'user',
  callInitiator: from ?? _peer,
);

class _OtherListener with CometChatCallEventListener {}

/// A chat SDK that is initialised and answers `getLoggedInUser` with
/// [user] (null: nobody is logged in), without an error.
class _AnsweringChatGateway implements ChatAuthGateway {
  _AnsweringChatGateway(this.user);

  final User? user;

  @override
  Future<User?> getLoggedInUser({
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    final current = user;
    if (current != null) onSuccess?.call(current);
    return current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = CallEventService.instance;
  late FakeCallsSdkGateway gateway;
  late FakeCallOperationsDataSource dataSource;
  late Map<String, CallListener> chatListeners;
  late Map<String, CometChatCallEventListener> savedBus;

  bool registered() =>
      identical(chatListeners[CallsLifecycle.callListenerId], service) &&
      identical(
        CometChatCallEvents.callEventsListener[CallsLifecycle.callListenerId],
        service,
      );

  bool unregistered() =>
      !chatListeners.containsKey(CallsLifecycle.callListenerId) &&
      !CometChatCallEvents.callEventsListener.containsKey(
        CallsLifecycle.callListenerId,
      );

  Future<void> useFakeDataSource() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
  }

  setUp(() async {
    savedBus = Map.of(CometChatCallEvents.callEventsListener);
    CometChatCallEvents.callEventsListener.clear();
    chatListeners = <String, CallListener>{};
    CallsLifecycle.addChatCallListener = (id, listener) =>
        chatListeners[id] = listener;
    CallsLifecycle.removeChatCallListener = (id) => chatListeners.remove(id);

    gateway = FakeCallsSdkGateway(chatToken: 'chat-token-uid-1');
    installCallsSdk(gateway);
    CometChatUIKit.loggedInUser = _me;
    ActiveCallTracker.busyRejectDelay = Duration.zero;
    await useFakeDataSource();
  });

  tearDown(() async {
    CallsLifecycle.debugReset();
    uninstallCallsSdk();
    ChatAuthGateway.debugInstance = null;
    CometChatUIKit.loggedInUser = null;
    CometChatUIKit.authenticationSettings = null;
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    await CallOperationsServiceLocator.instance.reset();
    CometChatCallEvents.callEventsListener
      ..clear()
      ..addAll(savedBus);
  });

  group('listeners first', () {
    testWidgets('both listeners are registered before the Calls SDK answers, '
        'and an incoming call rings and applies the busy rule meanwhile', (
      tester,
    ) async {
      gateway.onInit = () => Completer<void>().future;

      final started = CallsLifecycle.start(_me);

      // Synchronously: nothing awaited yet.
      expect(registered(), isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(gateway.initCount, 1);
      expect(CallsSdkSession.instance.isReady, isFalse);

      service.onIncomingCallReceived(_incoming('first'));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'first');

      // A second call while the first rings is answered with busy.
      service.onIncomingCallReceived(_incoming('second'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'first');
      expect(dataSource.calls, contains('rejectCall:second:busy'));

      // The init gives up at 10 s; the start never throws.
      var done = false;
      unawaited(started.then((_) => done = true));
      await tester.pump(const Duration(seconds: 10));
      expect(done, isTrue);
      expect(registered(), isTrue, reason: 'the listeners stay up');
    });

    test('the UI Kit\'s listener goes first on the call event bus, ahead of '
        'screens registered earlier', () {
      final other = _OtherListener();
      CometChatCallEvents.addCallEventsListener('screen', other);

      unawaited(CallsLifecycle.start(_me));

      expect(CometChatCallEvents.callEventsListener.keys, [
        CallsLifecycle.callListenerId,
        'screen',
      ]);
    });
  });

  group('re-entrant init()', () {
    test('three concurrent init() calls make one Calls init and one '
        'login', () async {
      await Future.wait([service.init(), service.init(), service.init()]);

      expect(gateway.initCount, 1);
      expect(gateway.loginCount, 1);
      expect(registered(), isTrue);
      expect(CallsLifecycle.uid, 'uid-1');
    });

    test('init() again once started only re-checks the Calls SDK', () async {
      await service.init();
      gateway.calls.clear();

      await service.init();

      expect(gateway.calls, isEmpty);
      expect(registered(), isTrue);
    });

    test('init() with no logged-in user returns without throwing and starts '
        'nothing', () async {
      CometChatUIKit.loggedInUser = null;

      await expectLater(service.init(), completes);

      expect(CallsLifecycle.isStarted, isFalse);
      expect(unregistered(), isTrue);
      expect(gateway.calls, isEmpty);
    });

    test('init() starts nothing when the chat SDK reports nobody logged in, '
        'even with a stale CometChatUIKit.loggedInUser', () async {
      // A host's direct CometChat.logout leaves the static field set.
      ChatAuthGateway.debugInstance = _AnsweringChatGateway(null);
      CometChatUIKit.loggedInUser = _me;

      await service.init();

      expect(CallsLifecycle.isStarted, isFalse);
      expect(unregistered(), isTrue);
      expect(gateway.calls, isEmpty);
    });

    test('init() follows the chat SDK\'s user over '
        'CometChatUIKit.loggedInUser', () async {
      ChatAuthGateway.debugInstance = _AnsweringChatGateway(_three);
      CometChatUIKit.loggedInUser = _me;
      gateway.chatToken = 'chat-token-uid-3';

      await service.init();

      expect(CallsLifecycle.uid, 'uid-3');
    });

    test('init(configuration:) after a user switch keeps the new user\'s '
        'configuration', () async {
      final first = CallingConfiguration();
      final second = CallingConfiguration();
      await service.init(
        // ignore: deprecated_member_use_from_same_package
        configuration: first,
      );
      expect(CallingConfigurationResolver.resolved, same(first));

      // Another user, without a logout in between: start() stops uid-1
      // first, which clears uid-1's configuration.
      CometChatUIKit.loggedInUser = _three;
      gateway.chatToken = 'chat-token-uid-3';
      await service.init(
        // ignore: deprecated_member_use_from_same_package
        configuration: second,
      );

      expect(CallsLifecycle.uid, 'uid-3');
      expect(CallingConfigurationResolver.resolved, same(second));
    });

    test('cachedAuthToken is the started user\'s chat token', () async {
      expect(service.cachedAuthToken, isNull);

      await service.init();

      expect(service.cachedAuthToken, 'chat-token-uid-1');
    });
  });

  group('cachedAuthToken', () {
    testWidgets('is set as soon as call handling starts, while the Calls SDK '
        'is still setting up', (tester) async {
      gateway.onInit = () => Completer<void>().future;

      final started = CallsLifecycle.start(_me);
      await tester.pump(const Duration(milliseconds: 1));

      expect(CallsSdkSession.instance.isReady, isFalse);
      expect(service.cachedAuthToken, 'chat-token-uid-1');

      await tester.pump(const Duration(seconds: 10));
      await started;
    });

    testWidgets('a token read that lands after a stop is dropped', (
      tester,
    ) async {
      gateway.onInit = () => Completer<void>().future;
      unawaited(CallsLifecycle.start(_me));
      CallsLifecycle.stop();
      await tester.pump(const Duration(milliseconds: 1));

      expect(service.cachedAuthToken, isNull);
      await tester.pump(const Duration(seconds: 22));
    });
  });

  group('waitForCallsSdk()', () {
    test('starts call handling when nothing has, as init() would', () async {
      await service.waitForCallsSdk();

      expect(registered(), isTrue);
      expect(CallsLifecycle.uid, 'uid-1');
      expect(CallsSdkSession.instance.isReady, isTrue);
      expect(gateway.initCount, 1);
      expect(gateway.loginCount, 1);
    });

    test('starts nothing with nobody logged in', () async {
      CometChatUIKit.loggedInUser = null;
      gateway.chatToken = null;

      await service.waitForCallsSdk();

      expect(CallsLifecycle.isStarted, isFalse);
      expect(unregistered(), isTrue);
    });

    test('does not start again, or switch users, once started', () async {
      await CallsLifecycle.start(_me);
      CometChatUIKit.loggedInUser = _three;
      gateway.calls.clear();

      await service.waitForCallsSdk();

      expect(CallsLifecycle.uid, 'uid-1');
      expect(gateway.calls, isEmpty);
    });
  });

  group('dispose() during a start', () {
    test('leaves no listener behind and no late login', () async {
      final gate = Completer<void>();
      gateway.onInit = () => gate.future;

      final started = service.init();
      await pumpEventQueue();
      expect(registered(), isTrue);

      service.dispose();
      expect(unregistered(), isTrue);

      gate.complete();
      await started;
      await pumpEventQueue();

      expect(unregistered(), isTrue);
      expect(gateway.loginCount, 0);
      expect(CallsLifecycle.isStarted, isFalse);
      expect(service.cachedAuthToken, isNull);
    });

    test('init -> dispose (mid-flight) -> init: registered once, for the new '
        'start; the old run lands without effect', () async {
      final gate = Completer<void>();
      gateway.onInit = () => gate.future;

      final first = service.init();
      await pumpEventQueue();
      service.dispose();

      gateway.onInit = null;
      await service.init();
      expect(registered(), isTrue);
      expect(gateway.loginCount, 1);

      gate.complete();
      await first;
      await pumpEventQueue();
      expect(registered(), isTrue);
      expect(gateway.loginCount, 1, reason: 'the stale run did not log in');
    });

    test('dispose() clears the records and call state, and logs the Calls '
        'SDK out once', () async {
      await service.init();
      service.activeCall = _incoming('active');
      ActiveCallTracker.ringingCall = _incoming('ringing');
      CallStateService.instance.setActiveCallValue(true);

      service.dispose();
      await pumpEventQueue();

      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(CallStateService.instance.isActiveCall.value, isFalse);
      expect(gateway.logoutCount, 1);

      // Idempotent: a second dispose neither throws nor logs out again.
      expect(service.dispose, returnsNormally);
      await pumpEventQueue();
      expect(gateway.logoutCount, 1);
    });

    test('dispose() before any start does not touch the Calls SDK', () async {
      service.dispose();
      await pumpEventQueue();

      expect(gateway.calls, isEmpty);
    });
  });

  group('user switch', () {
    test('start(uid-1) then start(uid-3): the records are cleared and the '
        'echo filter drops only calls initiated by uid-3', () async {
      await CallsLifecycle.start(_me);
      service.activeCall = _incoming('old-active');
      ActiveCallTracker.ringingCall = _incoming('old-ringing');

      gateway.chatToken = 'chat-token-uid-3';
      await CallsLifecycle.start(_three);
      await useFakeDataSource();

      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(CallsLifecycle.uid, 'uid-3');
      expect(registered(), isTrue);
      expect(service.cachedAuthToken, 'chat-token-uid-3');

      // CometChatUIKit.loggedInUser still says uid-1 (a host's direct
      // CometChat.login does not update it); the filter follows the start.
      service.onIncomingCallReceived(_incoming('echo', from: _three));
      expect(ActiveCallTracker.ringingCall, isNull);

      service.onIncomingCallReceived(_incoming('from-one', from: _me));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'from-one');
    });

    test(
      'no server-side call cleanup is sent on a switch (round 1b)',
      () async {
        await CallsLifecycle.start(_me);
        service.activeCall = _incoming('old-active');
        ActiveCallTracker.ringingCall = _incoming('old-ringing');

        await CallsLifecycle.start(_three);

        expect(dataSource.calls, isEmpty);
      },
    );

    test(
      'the Calls SDK is logged in again with the new user\'s token',
      () async {
        await CallsLifecycle.start(_me);

        gateway.chatToken = 'chat-token-uid-3';
        await CallsLifecycle.start(_three);

        expect(gateway.calls, [
          'init:test-app:us',
          'login:chat-token-uid-1',
          'logout',
          'login:chat-token-uid-3',
        ]);
      },
    );
  });

  group('echo filter', () {
    test('reads CometChatUIKit.loggedInUser at event time when nothing is '
        'started', () {
      CometChatUIKit.loggedInUser = _three;

      service.onIncomingCallReceived(_incoming('mine', from: _three));
      expect(ActiveCallTracker.ringingCall, isNull);

      service.onIncomingCallReceived(_incoming('theirs', from: _me));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'theirs');
    });
  });

  group('reinitializeAfterSession (deprecated)', () {
    test('does nothing once stopped (after logout)', () async {
      await CallsLifecycle.start(_me);
      service.dispose();
      await pumpEventQueue();
      gateway.calls.clear();
      gateway.initialized = false;

      // ignore: deprecated_member_use_from_same_package
      await service.reinitializeAfterSession();

      expect(gateway.calls, isEmpty);
    });

    test(
      'does nothing while the Calls SDK is initialised and logged in',
      () async {
        await CallsLifecycle.start(_me);
        gateway.calls.clear();

        // ignore: deprecated_member_use_from_same_package
        await service.reinitializeAfterSession();

        expect(gateway.calls, isEmpty);
      },
    );

    test('initialises again, exactly once, when the plugin reports it is not '
        'initialised', () async {
      await CallsLifecycle.start(_me);
      gateway.calls.clear();
      gateway.initialized = false;

      await Future.wait([
        // ignore: deprecated_member_use_from_same_package
        service.reinitializeAfterSession(),
        // ignore: deprecated_member_use_from_same_package
        service.reinitializeAfterSession(),
      ]);

      expect(gateway.calls, ['init:test-app:us']);
    });
  });

  group('direct CometChat.login / logout (out of band)', () {
    void enableCalls({bool enabled = true}) {
      CometChatUIKit.authenticationSettings =
          (UIKitSettingsBuilder()
                ..appId = 'test-app'
                ..region = 'us'
                ..enableCalls = enabled)
              .build();
    }

    test('loginSuccess starts call handling for that user', () async {
      enableCalls();

      CallsLifecycle.debugLoginListener.loginSuccess(_me);

      expect(registered(), isTrue);
      expect(CallsLifecycle.uid, 'uid-1');
      await pumpEventQueue();
      expect(CallsSdkSession.instance.isReady, isTrue);
    });

    test('nothing happens when calls are not enabled', () async {
      enableCalls(enabled: false);

      CallsLifecycle.debugLoginListener.loginSuccess(_me);
      CallsLifecycle.debugLoginListener.logoutSuccess();
      await pumpEventQueue();

      expect(CallsLifecycle.isStarted, isFalse);
      expect(gateway.calls, isEmpty);
    });

    test('the UI Kit login path after the listener is deduplicated', () async {
      enableCalls();

      // CometChat.login notifies login listeners before its onSuccess, where
      // CometChatUIKit then starts call handling itself.
      CallsLifecycle.debugLoginListener.loginSuccess(_me);
      await CallsLifecycle.start(_me);

      expect(gateway.initCount, 1);
      expect(gateway.loginCount, 1);
    });

    test(
      'logoutSuccess stops call handling and logs the Calls SDK out',
      () async {
        enableCalls();
        await CallsLifecycle.start(_me);

        CallsLifecycle.debugLoginListener.logoutSuccess();
        await pumpEventQueue();

        expect(CallsLifecycle.isStarted, isFalse);
        expect(unregistered(), isTrue);
        expect(gateway.logoutCount, 1);
      },
    );

    test('nothing thrown while starting or stopping escapes into the chat '
        'SDK\'s login or logout', () async {
      enableCalls();
      final addListener = CallsLifecycle.addChatCallListener;
      final removeListener = CallsLifecycle.removeChatCallListener;
      addTearDown(() {
        CallsLifecycle.addChatCallListener = addListener;
        CallsLifecycle.removeChatCallListener = removeListener;
      });

      CallsLifecycle.addChatCallListener = (_, _) =>
          throw StateError('listener registration failed');
      expect(
        () => CallsLifecycle.debugLoginListener.loginSuccess(_me),
        returnsNormally,
      );

      CallsLifecycle.addChatCallListener = addListener;
      CallsLifecycle.removeChatCallListener = (_) =>
          throw StateError('listener removal failed');
      expect(
        () => CallsLifecycle.debugLoginListener.logoutSuccess(),
        returnsNormally,
      );
      CallsLifecycle.removeChatCallListener = removeListener;
      await pumpEventQueue();
    });

    test('logoutSuccess clears CometChatUIKit.loggedInUser, calls enabled '
        'or not', () async {
      for (final enabled in [true, false]) {
        enableCalls(enabled: enabled);
        CometChatUIKit.loggedInUser = _me;

        CallsLifecycle.debugLoginListener.logoutSuccess();
        await pumpEventQueue();

        expect(CometChatUIKit.loggedInUser, isNull, reason: 'enabled=$enabled');
      }
    });

    test('CometChatUIKit.logout (dispose, then the SDK\'s logoutSuccess) logs '
        'the Calls SDK out once', () async {
      enableCalls();
      await CallsLifecycle.start(_me);

      service.dispose();
      CallsLifecycle.debugLoginListener.logoutSuccess();
      await pumpEventQueue();

      expect(gateway.logoutCount, 1);
    });
  });
}
