/// CallsSdkSession (round 1a, P1-C01): the Calls SDK init and login run once
/// per phase however many callers ask, each within a time limit, are
/// re-checked instead of re-run, and a failed phase runs once more when the
/// next caller asks. `stop()` makes anything in flight land without effect.
///
/// Every timing test runs under testWidgets, whose clock is fake: "22 s" below
/// is fake time and the file runs in well under a second.
///
///   flutter test test/call_ui/calls_sdk_session_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show CometChatCallsException;
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';

/// Watches a future from a fake-clock test without awaiting it.
class _Watch<T> {
  _Watch(Future<T> future) {
    future.then((T v) {
      value = v;
      done = true;
    });
  }

  bool done = false;
  T? value;
}

CometChatCallsException _callsError(String code) =>
    CometChatCallsException(code, 'fake $code', 'fake $code');

Future<void> _never() => Completer<void>().future;

void main() {
  late FakeCallsSdkGateway gateway;
  late CallsSdkSettings? settings;

  CallsSdkSession build({
    CallsSdkTimeouts timeouts = const CallsSdkTimeouts(),
  }) => CallsSdkSession(
    gateway: gateway,
    settings: () => settings,
    timeouts: timeouts,
  );

  setUp(() {
    gateway = FakeCallsSdkGateway();
    settings = testCallsSdkSettings;
  });

  group('single flight', () {
    test('two concurrent ensureReady() make one init and one login', () async {
      final session = build();

      final results = await Future.wait([
        session.ensureReady(),
        session.ensureReady(),
      ]);

      expect(results, [true, true]);
      expect(gateway.calls, ['init:test-app:us', 'login:chat-token-me']);
      expect(session.isReady, isTrue);
      expect(session.isInitialized, isTrue);
    });

    test('ensureReady() while ensureInitialized() is in flight joins its '
        'init', () async {
      final gate = Completer<void>();
      gateway.onInit = () => gate.future;
      final session = build();

      final init = session.ensureInitialized();
      final ready = session.ensureReady();
      gate.complete();

      expect(await init, isTrue);
      expect(await ready, isTrue);
      expect(gateway.initCount, 1);
      expect(gateway.loginCount, 1);
    });

    test('a finished phase is re-checked, not re-run', () async {
      final session = build();
      await session.ensureReady();
      gateway.calls.clear();

      expect(await session.ensureReady(), isTrue);
      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls, isEmpty);
    });

    test('a persisted Calls login with the same token needs no login '
        'call', () async {
      gateway.callsToken = 'chat-token-me';
      final session = build();

      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls, ['init:test-app:us']);
    });

    test('initFromSettings is used when the UI Kit came from '
        'cometchat-settings.json', () async {
      settings = const CallsSdkSettings(
        appId: 'test-app',
        region: 'us',
        fromSettings: true,
      );
      final session = build();

      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls.first, 'initFromSettings');
    });
  });

  group('failure and retry on demand', () {
    test('an init error leaves the phase failed; the next ensureReady() runs '
        'it once more', () async {
      gateway.onInit = () async => throw _callsError('ERR_INIT');
      final session = build();

      expect(await session.ensureReady(), isFalse);
      expect(session.initPhase, CallsSdkPhase.failed);
      expect(gateway.initCount, 1);
      expect(gateway.loginCount, 0, reason: 'no login without an init');

      // Still failing: exactly one more attempt, no loop.
      expect(await session.ensureReady(), isFalse);
      expect(gateway.initCount, 2);

      gateway.onInit = null;
      expect(await session.ensureReady(), isTrue);
      expect(gateway.initCount, 3);
      expect(gateway.loginCount, 1);
    });

    _fakeClockTest(
      'a login error on both attempts leaves the phase failed; the next '
      'ensureReady() logs in again',
      (tick) async {
        gateway.onLogin = (_) async => throw _callsError('ERR_LOGIN');
        final session = build();

        final first = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));
        expect(first.done, isTrue);
        expect(first.value, isFalse);
        expect(gateway.loginCount, 2, reason: 'two attempts per phase');
        expect(session.loginPhase, CallsSdkPhase.failed);
        expect(session.isInitialized, isTrue);

        gateway.onLogin = null;
        final second = _Watch(session.ensureReady());
        await tick(const Duration(milliseconds: 10));
        expect(second.value, isTrue);
        expect(gateway.initCount, 1, reason: 'the init is not redone');
        expect(gateway.loginCount, 3);
      },
    );

    _fakeClockTest(
      'a failed first login attempt is retried with a refreshed chat '
      'token',
      (tick) async {
        var attempts = 0;
        gateway.onLogin = (_) async {
          attempts++;
          if (attempts == 1) {
            gateway.chatToken = 'chat-token-rotated';
            throw _callsError('ERR_LOGIN');
          }
        };
        final session = build();

        final ready = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));

        expect(ready.value, isTrue);
        expect(gateway.calls.where((c) => c.startsWith('login:')), [
          'login:chat-token-me',
          'login:chat-token-rotated',
        ]);
      },
    );

    _fakeClockTest(
      'no chat token: the login gives up after the poll, without a login '
      'call',
      (tick) async {
        gateway.chatToken = null;
        final session = build();

        final ready = _Watch(session.ensureReady());
        await tick(const Duration(milliseconds: 700));
        expect(ready.done, isFalse, reason: 'still polling for the token');
        await tick(const Duration(milliseconds: 200));

        expect(ready.value, isFalse);
        expect(gateway.loginCount, 0);
        expect(session.loginPhase, CallsSdkPhase.failed);
      },
    );

    test('no app id / region yet: not ready, and nothing is called', () async {
      settings = null;
      final session = build();

      expect(await session.ensureReady(), isFalse);
      expect(await session.ensureInitialized(), isFalse);
      expect(gateway.calls, isEmpty);
    });

    _fakeClockTest(
      'web: when both logins fail the native token fallback makes it '
      'ready',
      (tick) async {
        gateway
          ..supportsNativeAuthTokenFallback = true
          ..onLogin = (_) async => throw _callsError('ERR_LOGIN');
        final session = build();

        final ready = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));

        expect(ready.value, isTrue);
        expect(gateway.calls.last, 'setNativeAuthToken:chat-token-me');
      },
    );

    _fakeClockTest(
      'web: after the fallback, the next ensureReady() is ready at once, '
      'without logging in again',
      (tick) async {
        gateway
          ..supportsNativeAuthTokenFallback = true
          ..onLogin = (_) async => throw _callsError('ERR_LOGIN');
        final session = build();
        final first = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));
        expect(first.value, isTrue);
        expect(gateway.loginCount, 2);
        gateway.calls.clear();

        final second = _Watch(session.ensureReady());
        expect(session.isReady, isTrue);
        await tick(const Duration(milliseconds: 1));

        expect(second.value, isTrue);
        expect(session.isReady, isTrue);
        expect(gateway.calls, isEmpty);
      },
    );

    _fakeClockTest(
      'web: the fallback is forgotten on stop() and on a new chat token',
      (tick) async {
        gateway
          ..supportsNativeAuthTokenFallback = true
          ..onLogin = (_) async => throw _callsError('ERR_LOGIN');
        final session = build();
        _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));
        gateway.calls.clear();

        // Another token (a token refresh, or the next user): log in again.
        gateway.chatToken = 'chat-token-next';
        final refreshed = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));
        expect(refreshed.value, isTrue);
        expect(gateway.calls, <String>[
          'login:chat-token-next',
          'login:chat-token-next',
          'setNativeAuthToken:chat-token-next',
        ]);
        gateway.calls.clear();

        // Logout / user switch.
        session.stop();
        final afterStop = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 2));
        expect(afterStop.value, isTrue);
        expect(gateway.loginCount, 2);
      },
    );
  });

  group('bounds', () {
    _fakeClockTest('an init that never answers: not ready after 10 s', (
      tick,
    ) async {
      gateway.onInit = _never;
      final session = build();

      final ready = _Watch(session.ensureReady());
      await tick(const Duration(seconds: 9));
      expect(ready.done, isFalse);
      await tick(const Duration(seconds: 1));

      expect(ready.value, isFalse);
      expect(session.initPhase, CallsSdkPhase.failed);
      expect(gateway.loginCount, 0);
    });

    _fakeClockTest(
      'a login that never answers: ensureReady() completes not-ready '
      'within 22 s',
      (tick) async {
        gateway.onLogin = (_) => _never();
        final session = build();

        final ready = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 20));
        expect(ready.done, isFalse);
        await tick(const Duration(seconds: 2));

        expect(ready.done, isTrue);
        expect(ready.value, isFalse);
        expect(gateway.loginCount, 2);
      },
    );

    _fakeClockTest(
      'the whole ensureReady() is capped at 22 s even when the phases '
      'add up to more',
      (tick) async {
        // Init takes 9 s, then both logins hang: 9 + 10 + 1 + 10 = 30 s.
        gateway.onInit = () => Future<void>.delayed(const Duration(seconds: 9));
        gateway.onLogin = (_) => _never();
        final session = build();

        final ready = _Watch(session.ensureReady());
        await tick(const Duration(seconds: 21));
        expect(ready.done, isFalse);
        await tick(const Duration(seconds: 1));

        expect(ready.value, isFalse);

        // Let the background login run out so no timer outlives the test.
        await tick(const Duration(seconds: 10));
      },
    );
  });

  group('stop()', () {
    test('a login that lands after stop() is ignored and the login phase is '
        'idle', () async {
      final gate = Completer<void>();
      gateway.onLogin = (_) => gate.future;
      final session = build();

      final ready = session.ensureReady();
      await pumpEventQueue();
      expect(gateway.loginCount, 1);
      expect(session.loginPhase, CallsSdkPhase.running);

      session.stop();
      gate.complete();

      expect(await ready, isFalse);
      expect(session.loginPhase, CallsSdkPhase.idle);
      expect(session.isReady, isFalse);
      expect(session.isInitialized, isTrue, reason: 'the init survives');
    });

    test(
      'an init that lands after stop() is dropped: no login follows',
      () async {
        final gate = Completer<void>();
        gateway.onInit = () => gate.future;
        final session = build();

        final ready = session.ensureReady();
        await pumpEventQueue();
        session.stop();
        gate.complete();

        expect(await ready, isFalse);
        await pumpEventQueue();
        expect(gateway.loginCount, 0);
        expect(session.initPhase, CallsSdkPhase.idle);
      },
    );

    test('ensureReady() after stop() starts afresh instead of joining the old '
        'run', () async {
      final gate = Completer<void>();
      gateway.onLogin = (_) => gate.future;
      final session = build();

      final stale = session.ensureReady();
      await pumpEventQueue();
      session.stop();

      gateway.onLogin = null;
      expect(await session.ensureReady(), isTrue);
      gate.complete();
      expect(await stale, isFalse);
      expect(session.isReady, isTrue);
    });
  });

  group('re-checks', () {
    test('a changed clientHost initialises again', () async {
      final session = build();
      expect(await session.ensureReady(), isTrue);

      settings = const CallsSdkSettings(
        appId: 'test-app',
        region: 'us',
        clientHost: 'https://other.example',
      );
      expect(await session.ensureReady(), isTrue);

      expect(gateway.initCount, 2);
    });

    test('a changed app id initialises again and logs in again', () async {
      final session = build();
      expect(await session.ensureReady(), isTrue);

      settings = const CallsSdkSettings(appId: 'other-app', region: 'eu');
      // What the plugin does on an app id change: it drops the old login.
      gateway.callsToken = null;
      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls, [
        'init:test-app:us',
        'login:chat-token-me',
        'init:other-app:eu',
        'login:chat-token-me',
      ]);
    });

    test('another chat user: the old Calls login is logged out first, then the '
        'new token logs in', () async {
      final session = build();
      expect(await session.ensureReady(), isTrue);

      gateway.chatToken = 'chat-token-uid-3';
      session.stop();
      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls, [
        'init:test-app:us',
        'login:chat-token-me',
        'logout',
        'login:chat-token-uid-3',
      ]);
      expect(gateway.callsToken, 'chat-token-uid-3');
    });

    test('Calls plugin 5.0.4: a logout de-initialises it, so the next '
        'ensureReady() initialises again before logging in', () async {
      gateway.deinitOnLogout = true;
      final session = build();
      expect(await session.ensureReady(), isTrue);

      session.stop();
      await session.logout();
      expect(gateway.isInitialized, isFalse);
      expect(session.isInitialized, isFalse);

      expect(await session.ensureReady(), isTrue);
      expect(gateway.calls, [
        'init:test-app:us',
        'login:chat-token-me',
        'logout',
        'init:test-app:us',
        'login:chat-token-me',
      ]);
    });

    test('Calls plugin 5.0.4: switching users re-initialises between the '
        'explicit logout and the login', () async {
      gateway.deinitOnLogout = true;
      final session = build();
      expect(await session.ensureReady(), isTrue);

      gateway.chatToken = 'chat-token-uid-3';
      session.stop();
      expect(await session.ensureReady(), isTrue);

      expect(gateway.calls, [
        'init:test-app:us',
        'login:chat-token-me',
        'logout',
        'init:test-app:us',
        'login:chat-token-uid-3',
      ]);
    });

    test('the plugin losing its login between calls is caught', () async {
      final session = build();
      expect(await session.ensureReady(), isTrue);

      // A late logout callback from an earlier session wiped the login.
      gateway.callsToken = null;
      expect(await session.ensureReady(), isTrue);

      expect(gateway.loginCount, 2);
    });
  });

  group('logout()', () {
    test('concurrent logouts share one; a second one after it is a no-op until '
        'the next login', () async {
      final session = build();
      await session.ensureReady();

      await Future.wait([session.logout(), session.logout()]);
      await session.logout();
      expect(gateway.logoutCount, 1);

      await session.ensureReady();
      await session.logout();
      expect(gateway.logoutCount, 2);
    });

    test('does nothing when the Calls SDK was never initialised', () async {
      final session = build();

      await session.logout();

      expect(gateway.calls, isEmpty);
    });

    test(
      'a logout() during a user switch\'s explicit logout shares it',
      () async {
        final session = build();
        await session.ensureReady();
        final gate = Completer<void>();
        gateway.onLogout = () => gate.future;

        gateway.chatToken = 'chat-token-uid-3';
        session.stop();
        final ready = session.ensureReady();
        await pumpEventQueue();
        expect(gateway.logoutCount, 1, reason: 'the switch logs out first');

        final logout = session.logout();
        gate.complete();
        await logout;
        await ready;

        expect(gateway.logoutCount, 1);
      },
    );

    test('a login waits for a logout still in flight', () async {
      final session = build();
      await session.ensureReady();
      final gate = Completer<void>();
      gateway.onLogout = () => gate.future;

      session.stop();
      final logout = session.logout();
      final ready = session.ensureReady();
      await pumpEventQueue();
      expect(
        gateway.calls.last,
        'logout',
        reason: 'no login while the logout is pending',
      );

      gate.complete();
      await logout;
      expect(await ready, isTrue);
      expect(gateway.calls.last, 'login:chat-token-me');
    });

    _fakeClockTest('a logout waits for a login already sent, so the login '
        'cannot land after it', (tick) async {
      final gate = Completer<void>();
      gateway.onLogin = (_) => gate.future;
      final session = build();
      _Watch(session.ensureReady());
      await tick(const Duration(milliseconds: 1));
      expect(gateway.calls, ['init:test-app:us', 'login:chat-token-me']);

      // Logout while that login is with the plugin.
      session.stop();
      final out = _Watch(session.logout());
      await tick(const Duration(milliseconds: 1));
      expect(gateway.logoutCount, 0, reason: 'waits for the login first');

      gate.complete();
      await tick(const Duration(milliseconds: 1));

      expect(gateway.calls.last, 'logout');
      expect(gateway.callsToken, isNull);
      expect(out.done, isTrue);
      expect(session.isReady, isFalse);
      await tick(const Duration(seconds: 30));
    });

    _fakeClockTest('a login that lands after the logout stopped waiting is '
        'logged out by the next logout()', (tick) async {
      final gate = Completer<void>();
      gateway.onLogin = (_) => gate.future;
      final session = build();
      _Watch(session.ensureReady());
      await tick(const Duration(milliseconds: 1));

      session.stop();
      final out = _Watch(session.logout());
      await tick(const Duration(seconds: 5));
      await tick(const Duration(milliseconds: 1));
      expect(out.done, isTrue);
      expect(gateway.logoutCount, 1, reason: 'bounded: logs out anyway');

      // The login lands after that logout: the plugin holds it again.
      gate.complete();
      await tick(const Duration(milliseconds: 1));
      expect(gateway.callsToken, 'chat-token-me');

      final again = _Watch(session.logout());
      await tick(const Duration(milliseconds: 1));
      expect(again.done, isTrue);
      expect(gateway.logoutCount, 2);
      expect(gateway.callsToken, isNull);
      await tick(const Duration(seconds: 30));
    });
  });
}

/// A test on the fake clock testWidgets provides; [body] advances it with
/// `tick`.
void _fakeClockTest(
  String description,
  Future<void> Function(Future<void> Function(Duration by) tick) body,
) {
  testWidgets(description, (WidgetTester tester) => body(tester.pump));
}
