/// NotificationFeedRepositoryImpl — the Result wrapper over the remote
/// data source.
///
/// Every method has the same three outcomes: pass the payload through, turn a
/// [NotificationFeedRemoteException] into a [Failure] that keeps its message,
/// code and original exception, or turn anything else into a per-method
/// "Unexpected error while ..." message. The per-method message is the part
/// that is easy to copy-paste wrong, so each one is pinned by text.
///
///   flutter test test/chat_ui/notification_feed/notification_feed_repository_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/data/datasources/notification_feed_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/data/repositories/notification_feed_repository_impl.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

class MockRemote extends Mock implements NotificationFeedRemoteDataSource {}

class FakeItem extends Fake implements NotificationFeedItem {
  FakeItem([this._id = 'n1']);
  final String _id;
  @override
  String get id => _id;
}

class FakeCategory extends Fake implements NotificationCategory {
  FakeCategory([this._id = 'c1']);
  final String _id;
  @override
  String get id => _id;
}

class FakeFeedRequest extends Fake implements NotificationFeedRequest {}

class FakeCategoriesRequest extends Fake
    implements NotificationCategoriesRequest {}

/// A non-[Exception] throwable, to reach the `exception: null` arm of the
/// catch-all handler.
class Boom extends Error {
  @override
  String toString() => 'Boom!';
}

void main() {
  late MockRemote remote;
  late NotificationFeedRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(FakeItem());
    registerFallbackValue(FakeFeedRequest());
    registerFallbackValue(FakeCategoriesRequest());
  });

  setUp(() {
    remote = MockRemote();
    repo = NotificationFeedRepositoryImpl(remoteDataSource: remote);
  });

  Failure asFailure(Result<Object?> r) {
    expect(r.isFailure, isTrue, reason: 'expected a Failure, got $r');
    return r as Failure;
  }

  /// The remote exception every method must translate verbatim.
  final remoteError = NotificationFeedRemoteException(
    message: 'remote said no',
    code: 'ERR_REMOTE',
    originalException: Exception('inner'),
  );

  // =========================================================================
  // fetchFeedItems
  // =========================================================================

  group('fetchFeedItems', () {
    test('passes the request through and returns the items', () async {
      final request = FakeFeedRequest();
      final items = [FakeItem('n1'), FakeItem('n2')];
      when(() => remote.fetchFeedItems(any())).thenAnswer((_) async => items);

      final result = await repo.fetchFeedItems(request);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull()?.map((i) => i.id), ['n1', 'n2']);
      verify(() => remote.fetchFeedItems(request)).called(1);
    });

    test('an empty page is a Success, not a Failure', () async {
      when(
        () => remote.fetchFeedItems(any()),
      ).thenAnswer((_) async => <NotificationFeedItem>[]);

      final result = await repo.fetchFeedItems(FakeFeedRequest());

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isEmpty);
    });

    test(
      'a remote exception keeps message, code and inner exception',
      () async {
        when(() => remote.fetchFeedItems(any())).thenThrow(remoteError);

        final failure = asFailure(await repo.fetchFeedItems(FakeFeedRequest()));

        expect(failure.message, 'remote said no');
        expect(failure.code, 'ERR_REMOTE');
        expect(failure.exception, same(remoteError.originalException));
      },
    );

    test('any other Exception is wrapped and carried', () async {
      final oops = Exception('oops');
      when(() => remote.fetchFeedItems(any())).thenThrow(oops);

      final failure = asFailure(await repo.fetchFeedItems(FakeFeedRequest()));

      expect(
        failure.message,
        'Unexpected error while fetching feed items: $oops',
      );
      expect(failure.code, isNull);
      expect(failure.exception, same(oops));
    });

    test('a non-Exception throwable leaves exception null', () async {
      when(() => remote.fetchFeedItems(any())).thenThrow(Boom());

      final failure = asFailure(await repo.fetchFeedItems(FakeFeedRequest()));

      expect(
        failure.message,
        'Unexpected error while fetching feed items: Boom!',
      );
      expect(failure.exception, isNull);
    });
  });

  // =========================================================================
  // fetchCategories
  // =========================================================================

  group('fetchCategories', () {
    test('passes the request through and returns the categories', () async {
      final request = FakeCategoriesRequest();
      when(
        () => remote.fetchCategories(any()),
      ).thenAnswer((_) async => [FakeCategory('c1')]);

      final result = await repo.fetchCategories(request);

      expect(result.getOrNull()?.map((c) => c.id), ['c1']);
      verify(() => remote.fetchCategories(request)).called(1);
    });

    test('a remote exception is translated', () async {
      when(() => remote.fetchCategories(any())).thenThrow(remoteError);

      final failure = asFailure(
        await repo.fetchCategories(FakeCategoriesRequest()),
      );

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
    });

    test('any other error gets the categories-specific message', () async {
      when(() => remote.fetchCategories(any())).thenThrow(Boom());

      final failure = asFailure(
        await repo.fetchCategories(FakeCategoriesRequest()),
      );

      expect(
        failure.message,
        'Unexpected error while fetching categories: Boom!',
      );
    });
  });

  // =========================================================================
  // markAsDelivered / markAsRead
  // =========================================================================

  group('markAsDelivered', () {
    test('returns Success(null) and forwards the item', () async {
      final item = FakeItem('n7');
      when(() => remote.markAsDelivered(any())).thenAnswer((_) async {});

      final result = await repo.markAsDelivered(item);

      expect(result, isA<Success<void>>());
      verify(() => remote.markAsDelivered(item)).called(1);
    });

    test('a remote exception is translated', () async {
      when(() => remote.markAsDelivered(any())).thenThrow(remoteError);

      final failure = asFailure(await repo.markAsDelivered(FakeItem()));

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
    });

    test('any other error gets the delivered-specific message', () async {
      when(() => remote.markAsDelivered(any())).thenThrow(Boom());

      final failure = asFailure(await repo.markAsDelivered(FakeItem()));

      expect(
        failure.message,
        'Unexpected error while marking as delivered: Boom!',
      );
    });
  });

  group('markAsRead', () {
    test('returns Success(null) and forwards the item', () async {
      final item = FakeItem('n8');
      when(() => remote.markAsRead(any())).thenAnswer((_) async {});

      final result = await repo.markAsRead(item);

      expect(result, isA<Success<void>>());
      verify(() => remote.markAsRead(item)).called(1);
    });

    test('a remote exception is translated', () async {
      when(() => remote.markAsRead(any())).thenThrow(remoteError);

      final failure = asFailure(await repo.markAsRead(FakeItem()));

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
    });

    test('any other error gets the read-specific message', () async {
      when(() => remote.markAsRead(any())).thenThrow(Boom());

      final failure = asFailure(await repo.markAsRead(FakeItem()));

      expect(failure.message, 'Unexpected error while marking as read: Boom!');
    });
  });

  // =========================================================================
  // reportEngagement
  // =========================================================================

  group('reportEngagement', () {
    test('forwards both the item and the interaction string', () async {
      final item = FakeItem('n9');
      when(
        () => remote.reportEngagement(any(), any()),
      ).thenAnswer((_) async {});

      final result = await repo.reportEngagement(item, 'clicked');

      expect(result, isA<Success<void>>());
      verify(() => remote.reportEngagement(item, 'clicked')).called(1);
    });

    test('a remote exception is translated', () async {
      when(() => remote.reportEngagement(any(), any())).thenThrow(remoteError);

      final failure = asFailure(await repo.reportEngagement(FakeItem(), 'x'));

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
    });

    test('any other error gets the engagement-specific message', () async {
      when(() => remote.reportEngagement(any(), any())).thenThrow(Boom());

      final failure = asFailure(await repo.reportEngagement(FakeItem(), 'x'));

      expect(
        failure.message,
        'Unexpected error while reporting engagement: Boom!',
      );
    });
  });

  // =========================================================================
  // getUnreadCount
  // =========================================================================

  group('getUnreadCount', () {
    test('returns the count as-is, including zero', () async {
      when(() => remote.getUnreadCount()).thenAnswer((_) async => 0);
      expect((await repo.getUnreadCount()).getOrNull(), 0);

      when(() => remote.getUnreadCount()).thenAnswer((_) async => 42);
      expect((await repo.getUnreadCount()).getOrNull(), 42);
    });

    test('a remote exception is translated', () async {
      when(() => remote.getUnreadCount()).thenThrow(remoteError);

      final failure = asFailure(await repo.getUnreadCount());

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
    });

    test('any other error gets the unread-count-specific message', () async {
      when(() => remote.getUnreadCount()).thenThrow(Boom());

      final failure = asFailure(await repo.getUnreadCount());

      expect(
        failure.message,
        'Unexpected error while getting unread count: Boom!',
      );
    });
  });

  // =========================================================================
  // getItem
  // =========================================================================

  group('getItem', () {
    test('forwards the id and returns the item', () async {
      when(() => remote.getItem(any())).thenAnswer((_) async => FakeItem('n5'));

      final result = await repo.getItem('n5');

      expect(result.getOrNull()?.id, 'n5');
      verify(() => remote.getItem('n5')).called(1);
    });

    test('a remote exception is translated', () async {
      when(() => remote.getItem(any())).thenThrow(remoteError);

      final failure = asFailure(await repo.getItem('n5'));

      expect(failure.message, 'remote said no');
      expect(failure.code, 'ERR_REMOTE');
      expect(failure.exception, same(remoteError.originalException));
    });

    test('any other error gets the get-item-specific message', () async {
      when(() => remote.getItem(any())).thenThrow(Boom());

      final failure = asFailure(await repo.getItem('n5'));

      expect(
        failure.message,
        'Unexpected error while getting feed item: Boom!',
      );
    });
  });

  // =========================================================================
  // The exception type itself
  // =========================================================================

  test('NotificationFeedRemoteException prints message and code', () {
    expect(
      remoteError.toString(),
      'NotificationFeedRemoteException(message: remote said no, code: ERR_REMOTE)',
    );
  });
}
