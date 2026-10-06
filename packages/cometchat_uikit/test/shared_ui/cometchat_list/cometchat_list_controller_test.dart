/// Behaviour tests for `CometChatListController` — the generic pagination /
/// mutation base every list controller in the kit extends.
///
/// The class was at 0.9% line coverage: nothing in the suite constructed it,
/// because every concrete subclass drags in an SDK request builder. It does
/// not need one — `request` is `dynamic`, so anything with `fetchNext` /
/// `fetchPrevious` taking `onSuccess` / `onError` satisfies it. That is the
/// seam these tests use.
///
/// What is pinned: the loading/error/has-more flag machine across the four
/// outcomes of a page fetch (page, empty page, reported error, thrown error),
/// the `isFetching` re-entrancy guard, the `isFetchNext` direction switch, the
/// `isIncluded` filter, and each of the list mutators including the index
/// misses that must NOT notify.
///
///   flutter test test/shared_ui/cometchat_list/cometchat_list_controller_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_list/cometchat_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Test doubles ────────────────────────────────────────────────────────────

/// A request builder with the two methods the controller calls. Each fetch
/// answers from a queue of scripted outcomes, so one controller can be driven
/// through several pages.
class _FakeRequest {
  _FakeRequest({
    this.pages = const [],
    this.failWith,
    this.throwOnCall = false,
  });

  /// Pages handed to `onSuccess`, in order. Running out yields an empty page,
  /// which is how the real builders signal the end of a list.
  final List<List<String>> pages;

  /// When set, every fetch reports this through `onError` instead.
  final CometChatListException? failWith;

  /// When true, the fetch throws synchronously — the controller's `catch`.
  final bool throwOnCall;

  int nextCalls = 0;
  int previousCalls = 0;
  int _page = 0;

  List<String> _take() {
    if (_page >= pages.length) return const [];
    return pages[_page++];
  }

  Future<void> _run({
    required void Function(List<String>) onSuccess,
    required void Function(CometChatListException) onError,
  }) async {
    if (throwOnCall) throw StateError('request builder blew up');
    if (failWith != null) {
      onError(failWith!);
      return;
    }
    onSuccess(_take());
  }

  Future<void> fetchNext({
    required void Function(List<String>) onSuccess,
    required void Function(CometChatListException) onError,
  }) {
    nextCalls++;
    return _run(onSuccess: onSuccess, onError: onError);
  }

  Future<void> fetchPrevious({
    required void Function(List<String>) onSuccess,
    required void Function(CometChatListException) onError,
  }) {
    previousCalls++;
    return _run(onSuccess: onSuccess, onError: onError);
  }
}

/// A request whose `fetchNext` never completes until the test releases it.
/// Used to hold the controller inside a fetch so the re-entrancy guard can be
/// observed.
class _BlockingRequest {
  final _gate = Completer<void>();
  int nextCalls = 0;

  Future<void> fetchNext({
    required void Function(List<String>) onSuccess,
    required void Function(CometChatListException) onError,
  }) async {
    nextCalls++;
    await _gate.future;
    onSuccess(const ['late']);
  }

  Future<void> fetchPrevious({
    required void Function(List<String>) onSuccess,
    required void Function(CometChatListException) onError,
  }) async {}

  void release() => _gate.complete();
}

/// Smallest possible concrete controller: strings keyed by themselves.
class _StringController extends CometChatListController<String, String> {
  _StringController(
    super.request, {
    super.onError,
    super.isFetchNext,
    super.onLoad,
    super.onEmpty,
  });

  int closeCalls = 0;

  @override
  bool match(String a, String b) => a == b;

  @override
  String getKey(String element) => element;

  @override
  void onClose() {
    closeCalls++;
    super.onClose();
  }
}

void main() {
  // ===========================================================================
  group('construction and defaults', () {
    test('a fresh controller starts loading with nothing fetched', () {
      final c = _StringController(_FakeRequest());
      addTearDown(c.dispose);

      expect(c.list, isEmpty);
      expect(c.getList(), same(c.list));
      expect(c.isLoading, isTrue);
      expect(c.hasMoreItems, isTrue);
      expect(c.hasMoreNext, isTrue);
      expect(c.hasError, isFalse);
      expect(c.error, isNull);
      expect(c.isFetching, isFalse);
      expect(c.isFetchNext, isTrue);
    });

    test('isFetchNext can be flipped at construction', () {
      final c = _StringController(_FakeRequest(), isFetchNext: false);
      addTearDown(c.dispose);
      expect(c.isFetchNext, isFalse);
    });
  });

  // ===========================================================================
  group('loadMoreElements — fetchNext', () {
    test(
      'a page is appended, flags cleared, and onLoad sees the whole list',
      () async {
        List<String>? loaded;
        var emptyCalls = 0;
        final c = _StringController(
          _FakeRequest(
            pages: [
              ['a', 'b'],
              ['c'],
            ],
          ),
          onLoad: (l) => loaded = List.of(l),
          onEmpty: () => emptyCalls++,
        );
        addTearDown(c.dispose);

        await c.loadMoreElements();
        expect(c.list, ['a', 'b']);
        expect(loaded, ['a', 'b']);
        expect(c.isLoading, isFalse);
        expect(c.isFetching, isFalse);
        expect(c.hasMoreItems, isTrue);
        expect(c.hasMoreNext, isTrue);

        // The second page appends rather than replaces, and onLoad is handed
        // the accumulated list, not just the new page.
        await c.loadMoreElements();
        expect(c.list, ['a', 'b', 'c']);
        expect(loaded, ['a', 'b', 'c']);
        expect(emptyCalls, 0);
      },
    );

    test('an empty page ends the list and calls onEmpty', () async {
      var emptyCalls = 0;
      var loadCalls = 0;
      final c = _StringController(
        _FakeRequest(),
        onLoad: (_) => loadCalls++,
        onEmpty: () => emptyCalls++,
      );
      addTearDown(c.dispose);

      await c.loadMoreElements();

      expect(c.list, isEmpty);
      expect(emptyCalls, 1);
      expect(loadCalls, 0);
      expect(c.isLoading, isFalse);
      expect(c.hasMoreItems, isFalse);
      expect(c.hasMoreNext, isFalse);
      expect(c.hasError, isFalse);
    });

    test('isIncluded keeps only the elements it accepts', () async {
      final c = _StringController(
        _FakeRequest(
          pages: [
            ['apple', 'banana', 'avocado'],
          ],
        ),
      );
      addTearDown(c.dispose);

      await c.loadMoreElements(isIncluded: (e) => e.startsWith('a'));

      expect(c.list, ['apple', 'avocado']);
      // A filtered-down page is still "not empty": has-more stays true even
      // though the visible list gained fewer rows than the page held.
      expect(c.hasMoreItems, isTrue);
    });

    test(
      'isIncluded rejecting everything still reports a non-empty page',
      () async {
        var emptyCalls = 0;
        final c = _StringController(
          _FakeRequest(
            pages: [
              ['x', 'y'],
            ],
          ),
          onEmpty: () => emptyCalls++,
        );
        addTearDown(c.dispose);

        await c.loadMoreElements(isIncluded: (_) => false);

        expect(c.list, isEmpty);
        expect(emptyCalls, 0, reason: 'the page was not empty, the filter was');
        expect(c.hasMoreItems, isTrue);
      },
    );

    test(
      'a reported error sets error state and reaches the onError callback',
      () async {
        final failure = CometChatListException('ERR_X', 'no network', 'socket');
        Exception? seen;
        final c = _StringController(
          _FakeRequest(failWith: failure),
          onError: (e) => seen = e,
        );
        addTearDown(c.dispose);

        await c.loadMoreElements();

        expect(c.hasError, isTrue);
        expect(c.error, same(failure));
        expect(seen, same(failure));
        expect(c.isLoading, isFalse);
        expect(c.isFetching, isFalse);
        // A reported error does not end the list — only a thrown one does.
        expect(c.hasMoreItems, isTrue);
      },
    );

    test('an error with no onError callback still sets error state', () async {
      final failure = CometChatListException('ERR_X', 'no network');
      final c = _StringController(_FakeRequest(failWith: failure));
      addTearDown(c.dispose);

      await c.loadMoreElements();

      expect(c.hasError, isTrue);
      expect(c.error, same(failure));
    });

    test('a thrown request ends the list and wraps the failure', () async {
      final c = _StringController(_FakeRequest(throwOnCall: true));
      addTearDown(c.dispose);

      await c.loadMoreElements();

      expect(c.hasError, isTrue);
      expect(c.isLoading, isFalse);
      expect(c.isFetching, isFalse);
      expect(c.hasMoreItems, isFalse);
      expect(c.hasMoreNext, isFalse);
      expect(c.error, isA<CometChatListException>());
      final e = c.error! as CometChatListException;
      expect(e.code, 'ERR');
      expect(e.details, 'Error');
      // FINDING: the catch block stores the *stack trace* as the exception
      // message — `CometChatListException("ERR", s.toString(), "Error")` — and
      // drops `e`, the thrown object, entirely. So a list that fails this way
      // reports a stack trace where an integrator's `onError` expects a
      // message, and the actual cause ("request builder blew up") is lost.
      // Pinned as-is.
      expect(e.message, isNot(contains('request builder blew up')));
      expect(e.message, contains('cometchat_list_controller.dart'));
    });

    test('a controller recovers on the next successful page', () async {
      // hasError is never cleared by a later success — pinning that, because
      // a list that errored once keeps hasError true while showing rows.
      final c = _StringController(
        _FakeRequest(failWith: CometChatListException('E', 'm')),
      );
      addTearDown(c.dispose);
      await c.loadMoreElements();
      expect(c.hasError, isTrue);

      final ok = _StringController(
        _FakeRequest(
          pages: [
            ['a'],
          ],
        ),
      );
      addTearDown(ok.dispose);
      await ok.loadMoreElements();
      expect(ok.hasError, isFalse);
    });
  });

  // ===========================================================================
  group('loadMoreElements — fetchPrevious', () {
    test(
      'isFetchNext:false routes to fetchPrevious, never fetchNext',
      () async {
        final req = _FakeRequest(
          pages: [
            ['a', 'b'],
          ],
        );
        final c = _StringController(req, isFetchNext: false);
        addTearDown(c.dispose);

        await c.loadMoreElements();

        expect(req.previousCalls, 1);
        expect(req.nextCalls, 0);
        expect(c.list, ['a', 'b']);
        expect(c.hasMoreItems, isTrue);
      },
    );

    test('an empty previous page calls onEmpty and ends hasMoreItems', () async {
      var emptyCalls = 0;
      final c = _StringController(
        _FakeRequest(),
        isFetchNext: false,
        onEmpty: () => emptyCalls++,
      );
      addTearDown(c.dispose);

      await c.loadMoreElements();

      expect(emptyCalls, 1);
      expect(c.hasMoreItems, isFalse);
      // The previous branch, unlike the next branch, leaves hasMoreNext alone.
      expect(c.hasMoreNext, isTrue);
    });

    test('isIncluded filters a previous page too', () async {
      final c = _StringController(
        _FakeRequest(
          pages: [
            ['keep', 'drop', 'keep2'],
          ],
        ),
        isFetchNext: false,
      );
      addTearDown(c.dispose);

      await c.loadMoreElements(isIncluded: (e) => e.startsWith('keep'));

      expect(c.list, ['keep', 'keep2']);
    });

    test('a previous-page error reaches onError', () async {
      final failure = CometChatListException('ERR_P', 'gone');
      Exception? seen;
      final c = _StringController(
        _FakeRequest(failWith: failure),
        isFetchNext: false,
        onError: (e) => seen = e,
      );
      addTearDown(c.dispose);

      await c.loadMoreElements();

      expect(seen, same(failure));
      expect(c.error, same(failure));
      expect(c.hasError, isTrue);
    });
  });

  // ===========================================================================
  group('the isFetching guard', () {
    test(
      'a second load while one is in flight is dropped, not queued',
      () async {
        final req = _BlockingRequest();
        final c = _StringController(req);
        addTearDown(c.dispose);

        final first = c.loadMoreElements();
        expect(c.isFetching, isTrue);

        // Re-entrant call: returns immediately and must not hit the builder.
        await c.loadMoreElements();
        expect(req.nextCalls, 1);

        req.release();
        await first;

        expect(c.list, ['late']);
        expect(c.isFetching, isFalse);

        // Once the flight lands, a further load goes through.
        await c.loadMoreElements();
        expect(req.nextCalls, 2);
      },
    );
  });

  // ===========================================================================
  group('index lookups', () {
    late _StringController c;

    setUp(() {
      c = _StringController(
        _FakeRequest(
          pages: [
            ['a', 'b', 'c'],
          ],
        ),
      );
    });

    tearDown(() => c.dispose());

    test(
      'getMatchingIndex finds by match(), and returns -1 when absent',
      () async {
        await c.loadMoreElements();
        expect(c.getMatchingIndex('b'), 1);
        expect(c.getMatchingIndex('zzz'), -1);
      },
    );

    test('getMatchingIndexFromKey finds by getKey(), -1 when absent', () async {
      await c.loadMoreElements();
      expect(c.getMatchingIndexFromKey('c'), 2);
      expect(c.getMatchingIndexFromKey('zzz'), -1);
    });

    test('both lookups return -1 on an empty list', () {
      expect(c.getMatchingIndex('a'), -1);
      expect(c.getMatchingIndexFromKey('a'), -1);
    });
  });

  // ===========================================================================
  group('mutators', () {
    late _StringController c;

    /// How many times the controller rebuilt since the list was loaded.
    late int notifications;

    setUp(() async {
      c = _StringController(
        _FakeRequest(
          pages: [
            ['a', 'b', 'c'],
          ],
        ),
      );
      await c.loadMoreElements();
      notifications = 0;
      c.addListener(() => notifications++);
    });

    tearDown(() => c.dispose());

    test('addElement inserts at the head by default', () {
      c.addElement('zero');
      expect(c.list, ['zero', 'a', 'b', 'c']);
      expect(notifications, 1);
    });

    test('addElement honours an explicit index', () {
      c.addElement('mid', index: 2);
      expect(c.list, ['a', 'b', 'mid', 'c']);
    });

    test('updateElement replaces the matching element', () {
      // 'b' matches by value; the controller swaps in the given object.
      c.updateElement('b');
      expect(c.list, ['a', 'b', 'c']);
      expect(notifications, 1);
    });

    test('updateElement with an explicit index bypasses match()', () {
      c.updateElement('B!', index: 1);
      expect(c.list, ['a', 'B!', 'c']);
      expect(notifications, 1);
    });

    test('updateElement on an absent element is a silent no-op', () {
      c.updateElement('nope');
      expect(c.list, ['a', 'b', 'c']);
      expect(notifications, 0, reason: 'a miss must not rebuild the list');
    });

    test('updateElement with index -1 is treated as a miss', () {
      c.updateElement('nope', index: -1);
      expect(c.list, ['a', 'b', 'c']);
      expect(notifications, 0);
    });

    test('updateElementAt writes at the given index', () {
      c.updateElementAt('A!', 0);
      expect(c.list, ['A!', 'b', 'c']);
      expect(notifications, 1);
    });

    test('removeElement drops the matching element', () {
      c.removeElement('b');
      expect(c.list, ['a', 'c']);
      expect(notifications, 1);
    });

    test('removeElement on an absent element is a silent no-op', () {
      c.removeElement('nope');
      expect(c.list, ['a', 'b', 'c']);
      expect(notifications, 0);
    });

    test('removeElementAt drops by position', () {
      c.removeElementAt(0);
      expect(c.list, ['b', 'c']);
      expect(notifications, 1);
    });

    test('removeElementAt past the end throws rather than no-ops', () {
      expect(() => c.removeElementAt(9), throwsRangeError);
      expect(c.list, ['a', 'b', 'c']);
    });
  });

  // ===========================================================================
  group('lifecycle', () {
    test('update() notifies listeners', () {
      final c = _StringController(_FakeRequest());
      addTearDown(c.dispose);
      var n = 0;
      c.addListener(() => n++);

      c.update();
      c.update();

      expect(n, 2);
    });

    test('onInit kicks off the first page', () async {
      final req = _FakeRequest(
        pages: [
          ['a'],
        ],
      );
      final c = _StringController(req);
      addTearDown(c.dispose);

      c.onInit();
      // loadMoreElements is not awaited by onInit; let it settle.
      await Future<void>.delayed(Duration.zero);

      expect(req.nextCalls, 1);
      expect(c.list, ['a']);
    });

    test('dispose runs onClose exactly once and stops notifications', () {
      final c = _StringController(_FakeRequest());
      var n = 0;
      c.addListener(() => n++);

      c.dispose();

      expect(c.closeCalls, 1);
      expect(n, 0);
      // A disposed ChangeNotifier rejects further notification.
      expect(c.update, throwsFlutterError);
    });
  });

  // ===========================================================================
  group('CometChatListException', () {
    test('toString includes the details when present', () {
      expect(
        CometChatListException('E1', 'boom', 'while fetching').toString(),
        'CometChatListException(E1): boom - while fetching',
      );
    });

    test('toString omits the details segment when absent', () {
      expect(
        CometChatListException('E1', 'boom').toString(),
        'CometChatListException(E1): boom',
      );
    });

    test('it is an Exception, so it can travel through onError', () {
      expect(CometChatListException('E', 'm'), isA<Exception>());
    });
  });
}
