/// Behaviour tests for [CallLogsLocalDataSourceImpl] — the in-memory cache that
/// sits behind `CallLogsRepositoryImpl`'s offline fallback.
///
/// It is a pure `Map<String, CallLog>`, no SDK calls, so every branch is
/// reachable from a VM test. The parts worth pinning are the ones a caller can
/// actually be surprised by:
///
///   * `cacheCallLogs` REPLACES the cache rather than merging into it, and
///     silently drops any log with a null `sessionId`;
///   * a later log with the same `sessionId` overwrites the earlier one;
///   * `getCachedCallLogs` THROWS on an empty cache instead of returning `[]`
///     — that is the signal the repository turns into a cache miss;
///   * the returned list is sorted by `initiatedAt` descending, with a null
///     `initiatedAt` treated as 0 (so it sorts last);
///   * every method wraps an unexpected failure in
///     `CallLogsLocalDataSourceException`, keeping the original exception.
///
///   flutter test test/call_ui/call_logs/call_logs_local_datasource_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

CallLog _log(String? sessionId, {int? initiatedAt = 0}) =>
    CallLog(sessionId: sessionId, initiatedAt: initiatedAt);

/// A [CallLog] whose `sessionId` getter blows up, used to drive the `catch`
/// arms that otherwise only fire on a corrupt model.
class _ExplodingCallLog implements CallLog {
  @override
  String? get sessionId => throw const FormatException('bad session id');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [CallLog] that survives caching but blows up while being sorted.
class _ExplodingSortCallLog implements CallLog {
  @override
  String? get sessionId => 'boom';

  @override
  int? get initiatedAt => throw const FormatException('bad timestamp');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late CallLogsLocalDataSourceImpl local;

  setUp(() => local = CallLogsLocalDataSourceImpl());

  // =========================================================================
  group('CallLogsLocalDataSourceException', () {
    test('toString names the message but not the wrapped exception', () {
      const e = CallLogsLocalDataSourceException(
        message: 'Cache miss',
        originalException: FormatException('inner'),
      );
      expect(
        e.toString(),
        'CallLogsLocalDataSourceException(message: Cache miss)',
      );
      expect(e.message, 'Cache miss');
      expect(e.originalException, isA<FormatException>());
    });

    test('originalException defaults to null', () {
      const e = CallLogsLocalDataSourceException(message: 'x');
      expect(e.originalException, isNull);
    });

    test('is an Exception, so a caller can catch it as one', () {
      expect(
        const CallLogsLocalDataSourceException(message: 'x'),
        isA<Exception>(),
      );
    });
  });

  // =========================================================================
  group('cacheCallLogs', () {
    test('stores each log under its own sessionId', () async {
      await local.cacheCallLogs([_log('a'), _log('b')]);

      expect(await local.getCachedCallLog('a'), isNotNull);
      expect((await local.getCachedCallLog('b'))!.sessionId, 'b');
      expect(await local.hasCachedData(), isTrue);
    });

    test('replaces the previous contents rather than merging', () async {
      await local.cacheCallLogs([_log('a')]);
      await local.cacheCallLogs([_log('b')]);

      expect(await local.getCachedCallLog('a'), isNull);
      expect(await local.getCachedCallLog('b'), isNotNull);
      expect(await local.getCachedCallLogs(), hasLength(1));
    });

    test('drops a log with a null sessionId instead of throwing', () async {
      await local.cacheCallLogs([_log(null), _log('a')]);

      expect(await local.getCachedCallLogs(), hasLength(1));
      expect((await local.getCachedCallLogs()).single.sessionId, 'a');
    });

    test('a later log with the same sessionId wins', () async {
      await local.cacheCallLogs([
        _log('a', initiatedAt: 1),
        _log('a', initiatedAt: 2),
      ]);

      final cached = await local.getCachedCallLogs();
      expect(cached, hasLength(1));
      expect(cached.single.initiatedAt, 2);
    });

    test('an empty list clears the cache', () async {
      await local.cacheCallLogs([_log('a')]);
      await local.cacheCallLogs(const []);

      expect(await local.hasCachedData(), isFalse);
    });

    test('wraps a failure while reading sessionId', () async {
      await expectLater(
        local.cacheCallLogs([_ExplodingCallLog()]),
        throwsA(
          isA<CallLogsLocalDataSourceException>()
              .having(
                (e) => e.message,
                'message',
                startsWith('Failed to cache call logs:'),
              )
              .having(
                (e) => e.originalException,
                'originalException',
                isA<FormatException>(),
              ),
        ),
      );
    });
  });

  // =========================================================================
  group('getCachedCallLogs', () {
    test('throws a cache-miss exception when nothing is cached', () async {
      await expectLater(
        local.getCachedCallLogs(),
        throwsA(
          isA<CallLogsLocalDataSourceException>()
              .having(
                (e) => e.message,
                'message',
                'No cached call logs available',
              )
              .having((e) => e.originalException, 'originalException', isNull),
        ),
      );
    });

    test('returns most-recent-first by initiatedAt', () async {
      await local.cacheCallLogs([
        _log('old', initiatedAt: 100),
        _log('new', initiatedAt: 300),
        _log('mid', initiatedAt: 200),
      ]);

      expect((await local.getCachedCallLogs()).map((l) => l.sessionId), [
        'new',
        'mid',
        'old',
      ]);
    });

    test('a null initiatedAt sorts as 0, i.e. last', () async {
      await local.cacheCallLogs([
        _log('null-ts', initiatedAt: null),
        _log('has-ts', initiatedAt: 5),
      ]);

      expect((await local.getCachedCallLogs()).map((l) => l.sessionId), [
        'has-ts',
        'null-ts',
      ]);
    });

    test('the cache-miss exception is rethrown, not re-wrapped', () async {
      try {
        await local.getCachedCallLogs();
        fail('expected a CallLogsLocalDataSourceException');
      } on CallLogsLocalDataSourceException catch (e) {
        // A re-wrap would have produced 'Failed to get cached call logs: ...'.
        expect(e.message, 'No cached call logs available');
      }
    });

    test('wraps a failure raised while sorting', () async {
      // Two entries, so `List.sort` actually invokes the comparator.
      await local.cacheCallLog(_log('ok', initiatedAt: 1));
      await local.cacheCallLog(_ExplodingSortCallLog());

      await expectLater(
        local.getCachedCallLogs(),
        throwsA(
          isA<CallLogsLocalDataSourceException>()
              .having(
                (e) => e.message,
                'message',
                startsWith('Failed to get cached call logs:'),
              )
              .having(
                (e) => e.originalException,
                'originalException',
                isA<FormatException>(),
              ),
        ),
      );
    });
  });

  // =========================================================================
  group('cacheCallLog', () {
    test('adds to the existing cache instead of replacing it', () async {
      await local.cacheCallLogs([_log('a')]);
      await local.cacheCallLog(_log('b'));

      expect(await local.getCachedCallLogs(), hasLength(2));
    });

    test('a null sessionId is a no-op, not an error', () async {
      await local.cacheCallLog(_log(null));

      expect(await local.hasCachedData(), isFalse);
    });

    test('caching the same sessionId overwrites', () async {
      await local.cacheCallLog(_log('a', initiatedAt: 1));
      await local.cacheCallLog(_log('a', initiatedAt: 9));

      expect((await local.getCachedCallLog('a'))!.initiatedAt, 9);
    });

    test('wraps a failure while reading sessionId', () async {
      await expectLater(
        local.cacheCallLog(_ExplodingCallLog()),
        throwsA(
          isA<CallLogsLocalDataSourceException>().having(
            (e) => e.message,
            'message',
            startsWith('Failed to cache call log:'),
          ),
        ),
      );
    });
  });

  // =========================================================================
  group('getCachedCallLog / removeCachedCallLog / clearCache', () {
    test('an unknown sessionId reads back as null, not an exception', () async {
      await local.cacheCallLog(_log('a'));

      expect(await local.getCachedCallLog('missing'), isNull);
    });

    test('removing drops only the named log', () async {
      await local.cacheCallLogs([_log('a'), _log('b')]);
      await local.removeCachedCallLog('a');

      expect(await local.getCachedCallLog('a'), isNull);
      expect(await local.getCachedCallLog('b'), isNotNull);
    });

    test('removing an absent log is a no-op', () async {
      await local.cacheCallLog(_log('a'));
      await local.removeCachedCallLog('nope');

      expect(await local.getCachedCallLogs(), hasLength(1));
    });

    test('clearCache empties everything and flips hasCachedData', () async {
      await local.cacheCallLogs([_log('a'), _log('b')]);
      expect(await local.hasCachedData(), isTrue);

      await local.clearCache();

      expect(await local.hasCachedData(), isFalse);
      await expectLater(
        local.getCachedCallLogs(),
        throwsA(isA<CallLogsLocalDataSourceException>()),
      );
    });

    test('clearing an already-empty cache is a no-op', () async {
      await local.clearCache();
      expect(await local.hasCachedData(), isFalse);
    });
  });

  // =========================================================================
  group('instances do not share state', () {
    test('a second data source starts empty', () async {
      await local.cacheCallLog(_log('a'));

      final other = CallLogsLocalDataSourceImpl();
      expect(await other.hasCachedData(), isFalse);
      expect(await local.hasCachedData(), isTrue);
    });
  });
}
