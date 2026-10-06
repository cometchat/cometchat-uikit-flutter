/// CometChatUIKit init / login / loginWithAuthToken wait for the Calls SDK
/// before the host's onSuccess (round 1a, P1-C03).
///
/// * With `enableCalls`, onSuccess comes after the Calls SDK init and, for a
///   logged-in user, the Calls login, as in the Android UI Kit.
/// * The wait is bounded: init 10 s, the whole set-up 22 s.
/// * A Calls failure or timeout never becomes onError: onSuccess is called
///   exactly once anyway.
/// * Without `enableCalls` nothing is waited for and nothing is started.
/// * The returned future completes after the host's callback has run.
///
/// The chat SDK is replaced through `ChatAuthGateway` (a fake that calls
/// onSuccess without awaiting it, then returns, as the SDK does) and the
/// Calls SDK through `CallsSdkGateway`.
///
///   flutter test test/call_ui/uikit_login_calls_order_test.dart
library;

import 'dart:async';
import 'dart:convert';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/ui_kit_settings.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';
import 'package:cometchat_chat_uikit/src/chat_auth_gateway.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';
import 'helpers/fake_chat_auth_gateway.dart';

final _me = User(uid: 'uid-1', name: 'One');

UIKitSettings _settings({bool enableCalls = true}) =>
    (UIKitSettingsBuilder()
          ..appId = 'app-1'
          ..region = 'eu'
          ..authKey = 'auth-key'
          ..enableCalls = enableCalls)
        .build();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;
  late FakeChatAuthGateway chat;
  late FakeCallsSdkGateway calls;
  late Map<String, CallListener> chatCallListeners;
  late Map<String, CometChatCallEventListener> savedBus;

  void onSuccessLogger(User user) => log.add('onSuccess:${user.uid}');
  void onErrorLogger(CometChatException e) => log.add('onError:${e.code}');

  /// Starts [call] and logs 'returned' when its future completes.
  void track(Future<Object?> call) {
    unawaited(call.then((_) => log.add('returned')));
  }

  setUp(() async {
    log = <String>[];
    chat = FakeChatAuthGateway(log);
    ChatAuthGateway.debugInstance = chat;

    calls = FakeCallsSdkGateway(chatToken: 'chat-token-uid-1');
    installCallsSdk(calls, settings: CallsSdkSettings.fromUIKit);

    savedBus = Map.of(CometChatCallEvents.callEventsListener);
    CometChatCallEvents.callEventsListener.clear();
    chatCallListeners = <String, CallListener>{};
    CallsLifecycle.addChatCallListener = (id, listener) =>
        chatCallListeners[id] = listener;
    CallsLifecycle.removeChatCallListener = (id) =>
        chatCallListeners.remove(id);

    CometChatUIKit.authenticationSettings = _settings();
    await CallOperationsServiceLocator.instance.reset();
  });

  tearDown(() async {
    CallsLifecycle.debugReset();
    uninstallCallsSdk();
    ChatAuthGateway.debugInstance = null;
    CometChat.removeMessageListener('__CometChatConstantListenerID__');
    CometChatUIKit.loggedInUser = null;
    CometChatUIKit.authenticationSettings = null;
    CometChatUIKit.initializedFromSettings = false;
    await CallOperationsServiceLocator.instance.reset();
    CometChatCallEvents.callEventsListener
      ..clear()
      ..addAll(savedBus);
  });

  group('login', () {
    testWidgets('onSuccess waits for the Calls SDK init and login; the '
        'listeners are up before either', (tester) async {
      final initGate = Completer<void>();
      final loginGate = Completer<void>();
      calls.onInit = () => initGate.future;
      calls.onLogin = (_) => loginGate.future;

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, <String>['chat login:uid-1', 'chat login returned']);
      expect(CometChatUIKit.loggedInUser?.uid, 'uid-1');
      expect(CallsLifecycle.uid, 'uid-1', reason: 'listeners first');
      expect(calls.initCount, 1);

      initGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.loginCount, 1);
      expect(log, isNot(contains('onSuccess:uid-1')));

      loginGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>[
        'chat login:uid-1',
        'chat login returned',
        'onSuccess:uid-1',
        'returned',
      ]);
      expect(CallsSdkSession.instance.isReady, isTrue);
    });

    testWidgets('the out-of-band login listener and the UI Kit share one '
        'Calls init and one Calls login', (tester) async {
      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, contains('onSuccess:uid-1'));
      expect(calls.initCount, 1);
      expect(calls.loginCount, 1);
    });

    testWidgets('a Calls init that never answers delays onSuccess by 10 s, '
        'no more, and is not an error', (tester) async {
      calls.onInit = () => Completer<void>().future;

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(seconds: 9));
      expect(log, isNot(contains('onSuccess:uid-1')));

      await tester.pump(const Duration(seconds: 1));
      expect(
        log.where((e) => e.startsWith('onSuccess') || e.startsWith('onError')),
        <String>['onSuccess:uid-1'],
      );
      expect(log.last, 'returned');
      expect(CallsSdkSession.instance.initPhase, CallsSdkPhase.failed);
    });

    testWidgets('a logout while onSuccess waits for the Calls SDK turns the '
        'login into onError, never a late onSuccess', (tester) async {
      final initGate = Completer<void>();
      calls.onInit = () => initGate.future;

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, isNot(contains('onSuccess:uid-1')));

      // The host logs out (here through the chat SDK's login listener, as a
      // raw CometChat.logout would) before the Calls SDK answers.
      CallsLifecycle.debugLoginListener.logoutSuccess();
      initGate.complete();
      await tester.pump(const Duration(seconds: 25));

      expect(log.where((e) => e.startsWith('on')), <String>[
        'onError:ERR_LOGGED_OUT_DURING_LOGIN',
      ]);
      expect(log.last, 'returned');
      expect(CometChatUIKit.loggedInUser, isNull);
    });

    testWidgets('another user logging in while the first login waits: the '
        'first login gets onError, the second onSuccess', (tester) async {
      final initGate = Completer<void>();
      calls.onInit = () => initGate.future;

      unawaited(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      // A second login for another user supersedes the first before the
      // Calls SDK answers.
      CometChatUIKit.loggedInUser = User(uid: 'uid-3', name: 'Three');
      initGate.complete();
      await tester.pump(const Duration(seconds: 25));

      expect(log.where((e) => e.startsWith('on')), <String>[
        'onError:ERR_LOGGED_OUT_DURING_LOGIN',
      ]);
    });

    testWidgets('a slow init and a Calls login that never answers: '
        'onSuccess at the 22 s limit, exactly once', (tester) async {
      calls.onInit = () => Future<void>.delayed(const Duration(seconds: 5));
      calls.onLogin = (_) => Completer<void>().future;

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(seconds: 21));
      expect(log, isNot(contains('onSuccess:uid-1')));

      await tester.pump(const Duration(seconds: 1));
      expect(log.where((e) => e.startsWith('on')), <String>['onSuccess:uid-1']);
      expect(log.last, 'returned');

      // The second login attempt still times out later; nothing more
      // reaches the host.
      await tester.pump(const Duration(seconds: 10));
      expect(log.where((e) => e.startsWith('on')), <String>['onSuccess:uid-1']);
      expect(CallsSdkSession.instance.isReady, isFalse);
    });

    testWidgets('a failing Calls login is not an error: onSuccess once, and '
        'the next ensureReady tries again', (tester) async {
      calls.onLogin = (_) async => throw Exception('calls login failed');

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(log.where((e) => e.startsWith('on')), <String>['onSuccess:uid-1']);
      expect(calls.loginCount, 2, reason: 'two attempts');
      expect(CallsSdkSession.instance.loginPhase, CallsSdkPhase.failed);

      calls.onLogin = null;
      final ready = CallsSdkSession.instance.ensureReady();
      await tester.pump(const Duration(milliseconds: 1));
      expect(await ready, isTrue);
      expect(calls.loginCount, 3);
    });

    testWidgets('without enableCalls onSuccess runs inside the chat SDK '
        'callback, as before, and nothing is started', (tester) async {
      CometChatUIKit.authenticationSettings = _settings(enableCalls: false);

      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, <String>[
        'chat login:uid-1',
        'onSuccess:uid-1',
        'chat login returned',
        'returned',
      ]);
      expect(calls.calls, isEmpty);
      expect(CallsLifecycle.isStarted, isFalse);
      expect(chatCallListeners, isEmpty);
    });

    testWidgets('same uid already logged in: no chat login, onSuccess with '
        'that user once the Calls SDK is ready', (tester) async {
      chat
        ..loggedInUser = _me
        ..authToken = 'chat-token-uid-1';
      final loginGate = Completer<void>();
      calls.onLogin = (_) => loginGate.future;

      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, isEmpty);
      expect(CallsLifecycle.uid, 'uid-1');

      loginGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>['onSuccess:uid-1', 'returned']);
    });

    testWidgets('same uid already logged in: bounded too', (tester) async {
      chat
        ..loggedInUser = _me
        ..authToken = 'chat-token-uid-1';
      calls.onInit = () => Completer<void>().future;

      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(seconds: 10));

      expect(log, <String>['onSuccess:uid-1', 'returned']);
    });

    testWidgets('a user switch: onSuccess once the Calls SDK has logged the '
        'previous user out and the new one in', (tester) async {
      chat
        ..loggedInUser = User(uid: 'uid-2', name: 'Two')
        ..authToken = 'chat-token-uid-2';
      calls
        ..initialized = true
        ..callsToken = 'chat-token-uid-2';
      final logoutGate = Completer<void>();
      calls.onLogout = () => logoutGate.future;

      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>['chat login:uid-1', 'chat login returned']);
      expect(calls.calls.last, 'logout');

      logoutGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log.sublist(2), <String>['onSuccess:uid-1', 'returned']);
      expect(calls.calls.last, 'login:chat-token-uid-1');
      expect(CallsLifecycle.uid, 'uid-1');
    });

    testWidgets('a chat login error goes to onError; the Calls SDK is not '
        'touched', (tester) async {
      chat.loginError = CometChatException('ERR_UID_NOT_FOUND', 'd', 'm');

      track(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, <String>[
        'chat login:uid-1',
        'onError:ERR_UID_NOT_FOUND',
        'returned',
      ]);
      expect(calls.calls, isEmpty);
      expect(CallsLifecycle.isStarted, isFalse);
    });

    testWidgets('a host onSuccess that throws does not break the login', (
      tester,
    ) async {
      User? returned;
      unawaited(
        CometChatUIKit.login(
          'uid-1',
          onSuccess: (_) => throw StateError('host bug'),
        ).then((user) => returned = user),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(returned?.uid, 'uid-1');
    });
  });

  group('loginWithAuthToken', () {
    testWidgets('nobody logged in: onSuccess after the Calls SDK is ready', (
      tester,
    ) async {
      chat.usersByToken['chat-token-uid-1'] = _me;
      final loginGate = Completer<void>();
      calls.onLogin = (_) => loginGate.future;

      track(
        CometChatUIKit.loginWithAuthToken(
          'chat-token-uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>[
        'chat loginWithAuthToken:chat-token-uid-1',
        'chat login returned',
      ]);

      loginGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log.sublist(2), <String>['onSuccess:uid-1', 'returned']);
      expect(calls.calls, contains('login:chat-token-uid-1'));
    });

    testWidgets('a Calls failure is not an error', (tester) async {
      chat.usersByToken['chat-token-uid-1'] = _me;
      calls.onInit = () async => throw Exception('calls init failed');

      track(
        CometChatUIKit.loginWithAuthToken(
          'chat-token-uid-1',
          onSuccess: onSuccessLogger,
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(log.where((e) => e.startsWith('on')), <String>['onSuccess:uid-1']);
    });

    group('someone already logged in', () {
      User? returned;

      void run(String token) {
        returned = null;
        unawaited(
          CometChatUIKit.loginWithAuthToken(
            token,
            onSuccess: onSuccessLogger,
            onError: onErrorLogger,
          ).then((user) {
            returned = user;
            log.add('returned');
          }),
        );
      }

      setUp(() {
        chat
          ..loggedInUser = _me
          ..authToken = 'chat-token-uid-1';
      });

      testWidgets('with the same token: onSuccess with that user, after the '
          'Calls SDK is ready (it used to never be called)', (tester) async {
        final loginGate = Completer<void>();
        calls.onLogin = (_) => loginGate.future;

        run('chat-token-uid-1');
        await tester.pump(const Duration(milliseconds: 1));
        expect(log, isEmpty);
        expect(CallsLifecycle.uid, 'uid-1');

        loginGate.complete();
        await tester.pump(const Duration(milliseconds: 1));
        expect(log, <String>['onSuccess:uid-1', 'returned']);
        expect(returned?.uid, 'uid-1');
        expect(CometChatUIKit.loggedInUser?.uid, 'uid-1');
      });

      testWidgets('with the same token: bounded like a login', (tester) async {
        calls.onInit = () => Completer<void>().future;

        run('chat-token-uid-1');
        await tester.pump(const Duration(seconds: 9));
        expect(log, isEmpty);

        await tester.pump(const Duration(seconds: 1));
        expect(log, <String>['onSuccess:uid-1', 'returned']);
      });

      testWidgets('with the same token and no enableCalls: onSuccess at once', (
        tester,
      ) async {
        CometChatUIKit.authenticationSettings = _settings(enableCalls: false);

        run('chat-token-uid-1');
        await tester.pump(const Duration(milliseconds: 1));

        expect(log, <String>['onSuccess:uid-1', 'returned']);
        expect(calls.calls, isEmpty);
      });

      testWidgets('with another token: ERR_USER_ALREADY_LOGGED_IN, null, and '
          'nothing logged in or started', (tester) async {
        CometChatException? error;
        unawaited(
          CometChatUIKit.loginWithAuthToken(
            'chat-token-uid-2',
            onSuccess: onSuccessLogger,
            onError: (e) => error = e,
          ).then((user) {
            returned = user;
            log.add('returned');
          }),
        );
        await tester.pump(const Duration(milliseconds: 1));

        expect(error?.code, 'ERR_USER_ALREADY_LOGGED_IN');
        expect(error?.message, contains('Log out first'));
        expect(log, <String>['returned']);
        expect(returned, isNull);
        expect(chat.loggedInUser?.uid, 'uid-1', reason: 'no chat login');
        expect(calls.calls, isEmpty);
        expect(CallsLifecycle.isStarted, isFalse);
      });

      testWidgets('when the chat SDK has no token to compare: the error too', (
        tester,
      ) async {
        chat.authToken = null;

        run('chat-token-uid-1');
        await tester.pump(const Duration(milliseconds: 1));

        expect(log, <String>['onError:ERR_USER_ALREADY_LOGGED_IN', 'returned']);
        expect(returned, isNull);
      });
    });
  });

  group('init', () {
    testWidgets('a restored session: onSuccess after the Calls SDK init and '
        'login, with loggedInUser already set', (tester) async {
      chat
        ..loggedInUser = _me
        ..authToken = 'chat-token-uid-1';
      final initGate = Completer<void>();
      calls.onInit = () => initGate.future;
      String? userAtSuccess;

      track(
        CometChatUIKit.init(
          uiKitSettings: _settings(),
          onSuccess: (message) {
            userAtSuccess = CometChatUIKit.loggedInUser?.uid;
            log.add('onSuccess');
          },
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>['chat init', 'chat init returned']);
      expect(CallsLifecycle.uid, 'uid-1', reason: 'listeners first');
      expect(calls.calls, <String>['init:app-1:eu']);

      initGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log.sublist(2), <String>['onSuccess', 'returned']);
      expect(userAtSuccess, 'uid-1');
      expect(calls.calls, <String>['init:app-1:eu', 'login:chat-token-uid-1']);
    });

    testWidgets('nobody logged in: onSuccess after the Calls SDK init only', (
      tester,
    ) async {
      final initGate = Completer<void>();
      calls.onInit = () => initGate.future;

      track(
        CometChatUIKit.init(
          uiKitSettings: _settings(),
          onSuccess: (_) => log.add('onSuccess'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, <String>['chat init', 'chat init returned']);

      initGate.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(log.sublist(2), <String>['onSuccess', 'returned']);
      expect(calls.calls, <String>['init:app-1:eu']);
      expect(CallsLifecycle.isStarted, isFalse);
      expect(CallsSdkSession.instance.isInitialized, isTrue);
    });

    testWidgets('a re-init that restores no session (another app id) stops '
        'the previous user\'s call handling and logs the Calls SDK out', (
      tester,
    ) async {
      track(CometChatUIKit.login('uid-1', onSuccess: onSuccessLogger));
      await tester.pump(const Duration(milliseconds: 1));
      expect(CallsLifecycle.uid, 'uid-1');
      expect(calls.callsToken, 'chat-token-uid-1');
      log.clear();
      calls.calls.clear();

      // The chat SDK logs the user out, without telling any login listener,
      // when it is initialised with another app id.
      chat
        ..loggedInUser = null
        ..authToken = null;
      calls.chatToken = null;
      track(
        CometChatUIKit.init(
          uiKitSettings:
              (UIKitSettingsBuilder()
                    ..appId = 'app-2'
                    ..region = 'eu'
                    ..authKey = 'auth-key'
                    ..enableCalls = true)
                  .build(),
          onSuccess: (_) => log.add('onSuccess'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(CallsLifecycle.isStarted, isFalse);
      expect(chatCallListeners, isEmpty);
      expect(calls.calls, <String>['logout', 'init:app-2:eu']);
      expect(calls.callsToken, isNull);
      expect(log, contains('onSuccess'));
    });

    testWidgets('nobody logged in and the Calls init never answers: '
        'onSuccess at 10 s', (tester) async {
      calls.onInit = () => Completer<void>().future;

      track(
        CometChatUIKit.init(
          uiKitSettings: _settings(),
          onSuccess: (_) => log.add('onSuccess'),
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(seconds: 9));
      expect(log, isNot(contains('onSuccess')));

      await tester.pump(const Duration(seconds: 1));
      expect(log.sublist(2), <String>['onSuccess', 'returned']);
    });

    testWidgets('without enableCalls the Calls SDK is not touched', (
      tester,
    ) async {
      chat.loggedInUser = _me;

      track(
        CometChatUIKit.init(
          uiKitSettings: _settings(enableCalls: false),
          onSuccess: (_) => log.add('onSuccess'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, contains('onSuccess'));
      expect(log.last, 'returned');
      expect(calls.calls, isEmpty);
      expect(CallsLifecycle.isStarted, isFalse);
    });

    testWidgets('a chat init error goes to onError; the Calls SDK is not '
        'touched', (tester) async {
      chat.initError = CometChatException('ERR_APP_ID', 'd', 'm');

      track(
        CometChatUIKit.init(
          uiKitSettings: _settings(),
          onSuccess: (_) => log.add('onSuccess'),
          onError: onErrorLogger,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(log, <String>['chat init', 'onError:ERR_APP_ID', 'returned']);
      expect(calls.calls, isEmpty);
    });

    group('from cometchat-settings.json', () {
      const settingsFile = 'cometchat-settings.json';

      setUp(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (ByteData? message) async {
              final key = utf8.decode(message!.buffer.asUint8List());
              if (key != settingsFile) return null;
              final json = jsonEncode(<String, Object?>{
                'appId': 'app-9',
                'region': 'in',
                'uiKit': <String, Object?>{'enableCalling': true},
              });
              return ByteData.sublistView(utf8.encode(json));
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
        rootBundle.evict(settingsFile);
      });

      testWidgets('initFromSettings sets the Calls SDK up from the file '
          'before onSuccess', (tester) async {
        final initGate = Completer<void>();
        calls.onInit = () => initGate.future;

        track(
          CometChatUIKit.initFromSettings(
            onSuccess: (_) => log.add('onSuccess'),
            onError: onErrorLogger,
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(CometChatUIKit.initializedFromSettings, isTrue);
        expect(calls.calls, <String>['initFromSettings']);
        expect(log, isNot(contains('onSuccess')));

        initGate.complete();
        await tester.pump(const Duration(milliseconds: 1));
        expect(log.sublist(2), <String>['onSuccess', 'returned']);
      });

      testWidgets('a plain init afterwards clears the flag and initialises '
          'the Calls SDK the plain way again', (tester) async {
        track(CometChatUIKit.initFromSettings());
        await tester.pump(const Duration(milliseconds: 1));
        expect(calls.calls, <String>['initFromSettings']);

        track(CometChatUIKit.init(uiKitSettings: _settings()));
        await tester.pump(const Duration(milliseconds: 1));

        expect(CometChatUIKit.initializedFromSettings, isFalse);
        expect(calls.calls, <String>['initFromSettings', 'init:app-1:eu']);
      });
    });
  });
}
