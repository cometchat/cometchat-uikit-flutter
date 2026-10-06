/// Bloc events, use cases and repository impls across four features —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Sixteen exported classes that no test had ever constructed, spread over the
/// threaded header, message information, notification feed and the shared
/// entity repositories. They are one-line classes each, which is exactly why
/// they were skipped and exactly why they are worth a cheap pass:
///
///   * **Events** are `Equatable`, and a bloc drops a duplicate event when it
///     compares equal to the last one. A field missing from `props` is a
///     dropped user action, not a cosmetic slip.
///   * **Use cases** are one-line delegations, so the only thing that can be
///     wrong is which method they call and whether they forward every
///     argument. Both are asserted against a recording fake.
///   * **Repository impls** are pass-throughs except in the notification feed,
///     where each method wraps the data source in a try/catch that maps
///     exceptions onto `Result`. That mapping is real behaviour and has three
///     branches — success, the typed remote exception, and anything else.
///
///   flutter test test/chat_ui/feature_plumbing_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
  @override
  String get name => 'Alice';
}

class _FakeMessage extends Fake implements BaseMessage {
  _FakeMessage(this.id);
  @override
  final int id;
}

class _FakeReceipt extends Fake implements MessageReceipt {
  _FakeReceipt(this.messageId);
  @override
  final int messageId;
}

class _FakeTemplate extends Fake implements CometChatMessageTemplate {
  _FakeTemplate(this.type);
  @override
  final String type;
}

/// The SDK model requires eleven fields and a builder; the plumbing under test
/// only ever reads identity, so a fake keeps the cases about the plumbing.
class _FakeFeedItem extends Fake implements NotificationFeedItem {
  _FakeFeedItem(this.id);
  @override
  final String id;
}

class _FakeFeedRequest extends Fake implements NotificationFeedRequest {}

class _RecordingThreadedHeaderDataSource implements ThreadedHeaderDataSource {
  final List<String> calls = [];
  CometChatMessageTemplate? returns;
  List<CometChatMessageTemplate> returnsAll = const [];

  @override
  CometChatMessageTemplate? getMessageTemplate({
    required String category,
    required String type,
  }) {
    calls.add('getMessageTemplate($category,$type)');
    return returns;
  }

  @override
  List<CometChatMessageTemplate> getAllMessageTemplates() {
    calls.add('getAllMessageTemplates');
    return returnsAll;
  }
}

/// Fails every call with whatever [error] is set to.
class _ThrowingFeedDataSource extends Fake
    implements NotificationFeedRemoteDataSource {
  _ThrowingFeedDataSource(this.error);
  final Object error;

  @override
  Future<List<NotificationFeedItem>> fetchFeedItems(
    NotificationFeedRequest request,
  ) async => throw error;

  @override
  Future<void> markAsDelivered(NotificationFeedItem feedItem) async =>
      throw error;
}

class _EmptyFeedDataSource extends Fake
    implements NotificationFeedRemoteDataSource {
  int fetchCalls = 0;

  @override
  Future<List<NotificationFeedItem>> fetchFeedItems(
    NotificationFeedRequest request,
  ) async {
    fetchCalls++;
    return const <NotificationFeedItem>[];
  }

  @override
  Future<void> markAsDelivered(NotificationFeedItem feedItem) async {}
}

void main() {
  // ===========================================================================
  group('ThreadedHeader events', () {
    final parent = _FakeMessage(1);
    final user = _FakeUser('u1');

    test(
      'InitializeThreadedHeader carries the parent and the logged-in user',
      () {
        final event = InitializeThreadedHeader(
          parentMessage: parent,
          loggedInUser: user,
        );

        expect(event.parentMessage, same(parent));
        expect(event.loggedInUser, same(user));
        expect(event.props, [parent, user]);
      },
    );

    test('two initializations for the same thread compare equal', () {
      expect(
        InitializeThreadedHeader(parentMessage: parent, loggedInUser: user),
        InitializeThreadedHeader(parentMessage: parent, loggedInUser: user),
      );
    });

    test(
      'a different parent is a different event — the bloc must not drop it',
      () {
        expect(
          InitializeThreadedHeader(parentMessage: parent, loggedInUser: user),
          isNot(
            InitializeThreadedHeader(
              parentMessage: _FakeMessage(2),
              loggedInUser: user,
            ),
          ),
        );
      },
    );

    test('UpdateParentMessage distinguishes the message it carries', () {
      expect(UpdateParentMessage(parent), UpdateParentMessage(parent));
      expect(
        UpdateParentMessage(parent),
        isNot(UpdateParentMessage(_FakeMessage(2))),
      );
      expect(UpdateParentMessage(parent).props, [parent]);
    });

    test('IncrementReplyCount is a bare signal and every instance is equal', () {
      // Worth pinning: this event has no fields, so a bloc that de-duplicates
      // on equality collapses two consecutive increments into one. That is
      // correct only because the handler reads the count off state rather than
      // counting events.
      expect(const IncrementReplyCount(), const IncrementReplyCount());
      expect(const IncrementReplyCount().props, isEmpty);
    });
  });

  // ===========================================================================
  group('ThreadedHeader use cases and repository', () {
    late _RecordingThreadedHeaderDataSource dataSource;
    late ThreadedHeaderRepositoryImpl repository;

    setUp(() {
      dataSource = _RecordingThreadedHeaderDataSource();
      repository = ThreadedHeaderRepositoryImpl(dataSource: dataSource);
    });

    test('the repository forwards both arguments to the data source', () {
      repository.getMessageTemplate(category: 'message', type: 'text');

      expect(dataSource.calls, ['getMessageTemplate(message,text)']);
    });

    test('the repository returns whatever the data source returns, null '
        'included', () {
      expect(
        repository.getMessageTemplate(category: 'message', type: 'text'),
        isNull,
      );

      final template = _FakeTemplate('text');
      dataSource.returns = template;
      expect(
        repository.getMessageTemplate(category: 'message', type: 'text'),
        same(template),
      );
    });

    test('getAllMessageTemplates passes the list straight through', () {
      dataSource.returnsAll = [_FakeTemplate('text'), _FakeTemplate('image')];

      expect(repository.getAllMessageTemplates(), hasLength(2));
      expect(dataSource.calls, ['getAllMessageTemplates']);
    });

    test(
      'GetMessageTemplateUseCase calls through with its arguments intact',
      () {
        final useCase = GetMessageTemplateUseCase(repository);
        final template = _FakeTemplate('image');
        dataSource.returns = template;

        final result = useCase(category: 'message', type: 'image');

        expect(result, same(template));
        expect(dataSource.calls, ['getMessageTemplate(message,image)']);
      },
    );

    test('GetAllMessageTemplatesUseCase reaches the data source', () {
      dataSource.returnsAll = [_FakeTemplate('text')];

      expect(GetAllMessageTemplatesUseCase(repository)(), hasLength(1));
      expect(dataSource.calls, ['getAllMessageTemplates']);
    });

    test('the two use cases call different methods', () {
      GetMessageTemplateUseCase(repository)(category: 'c', type: 't');
      GetAllMessageTemplatesUseCase(repository)();

      expect(dataSource.calls, [
        'getMessageTemplate(c,t)',
        'getAllMessageTemplates',
      ]);
    });
  });

  // ===========================================================================
  group('MessageInformation events', () {
    final parent = _FakeMessage(1);

    test('InitializeMessageInformation carries the message it opened on', () {
      final event = InitializeMessageInformation(parentMessage: parent);

      expect(event.parentMessage, same(parent));
      expect(event, InitializeMessageInformation(parentMessage: parent));
      expect(
        event,
        isNot(InitializeMessageInformation(parentMessage: _FakeMessage(2))),
      );
    });

    test('ReceiptRead and ReceiptDelivered are distinct types for the same '
        'receipt', () {
      // Both wrap a MessageReceipt and both have identical props, so only the
      // runtime type separates a read from a delivery. A bloc that matched on
      // props alone would treat them as the same event.
      final receipt = _FakeReceipt(1);

      expect(ReceiptRead(receipt).props, ReceiptDelivered(receipt).props);
      expect(ReceiptRead(receipt), isNot(ReceiptDelivered(receipt)));
      expect(ReceiptRead(receipt), isA<MessageInformationEvent>());
      expect(ReceiptDelivered(receipt), isA<MessageInformationEvent>());
    });

    test('the same receipt twice compares equal within one type', () {
      final receipt = _FakeReceipt(1);

      expect(ReceiptRead(receipt), ReceiptRead(receipt));
      expect(ReceiptRead(receipt), isNot(ReceiptRead(_FakeReceipt(2))));
      expect(ReceiptDelivered(receipt), ReceiptDelivered(receipt));
    });
  });

  // ===========================================================================
  group('NotificationFeed events', () {
    test('the three engagement events are distinct types over one item', () {
      // Same shape as the receipt pair above, and the same risk: viewed,
      // clicked and delivered all carry only the feed item.
      final item = _FakeFeedItem('n1');

      expect(ReportViewed(item), isNot(ReportClicked(item)));
      expect(ReportViewed(item), isNot(ReportDelivered(item)));
      expect(ReportClicked(item), isNot(ReportDelivered(item)));

      expect(ReportViewed(item).props, [item]);
      expect(ReportClicked(item).props, [item]);
      expect(ReportDelivered(item).props, [item]);
    });

    test('the same item reported twice compares equal', () {
      final item = _FakeFeedItem('n1');
      final other = _FakeFeedItem('n2');

      expect(ReportViewed(item), ReportViewed(item));
      expect(ReportViewed(item), isNot(ReportViewed(other)));
    });
  });

  // ===========================================================================
  group('TimestampGroup', () {
    test('pairs a header label with the items under it', () {
      const group = TimestampGroup(
        label: 'Today',
        items: <NotificationFeedItem>[],
      );

      expect(group.label, 'Today');
      expect(group.items, isEmpty);
    });

    test('holds the items it is given', () {
      final items = <NotificationFeedItem>[
        _FakeFeedItem('n1'),
        _FakeFeedItem('n2'),
      ];
      final group = TimestampGroup(label: 'Yesterday', items: items);

      expect(group.items, hasLength(2));
      expect(group.items.first.id, 'n1');
    });
  });

  // ===========================================================================
  group('NotificationFeedRemoteException', () {
    test('carries a message, and code and cause are optional', () {
      const e = NotificationFeedRemoteException(message: 'boom');

      expect(e.message, 'boom');
      expect(e.code, isNull);
      expect(e.originalException, isNull);
      expect(e, isA<Exception>());
    });

    test('toString surfaces the message so a log line is useful', () {
      const e = NotificationFeedRemoteException(
        message: 'rate limited',
        code: 'ERR_429',
      );

      expect(e.toString(), contains('rate limited'));
    });

    test('wraps an original exception without losing it', () {
      final cause = Exception('socket closed');
      final e = NotificationFeedRemoteException(
        message: 'fetch failed',
        code: 'ERR_NET',
        originalException: cause,
      );

      expect(e.originalException, same(cause));
      expect(e.code, 'ERR_NET');
    });
  });

  // ===========================================================================
  group('NotificationFeedRepositoryImpl error mapping', () {
    test('a successful fetch becomes Success with the data', () async {
      final dataSource = _EmptyFeedDataSource();
      final repository = NotificationFeedRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.fetchFeedItems(_FakeFeedRequest());

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isEmpty);
      expect(dataSource.fetchCalls, 1);
    });

    test(
      'a typed remote exception keeps its message, code and cause',
      () async {
        final cause = Exception('socket closed');
        final repository = NotificationFeedRepositoryImpl(
          remoteDataSource: _ThrowingFeedDataSource(
            NotificationFeedRemoteException(
              message: 'rate limited',
              code: 'ERR_429',
              originalException: cause,
            ),
          ),
        );

        final result = await repository.fetchFeedItems(_FakeFeedRequest());

        expect(result.isFailure, isTrue);
        result.fold((failure) {
          expect(failure.message, 'rate limited');
          expect(failure.code, 'ERR_429');
          expect(failure.exception, same(cause));
        }, (_) => fail('expected a Failure'));
      },
    );

    test(
      'an untyped error is wrapped with context rather than rethrown',
      () async {
        final repository = NotificationFeedRepositoryImpl(
          remoteDataSource: _ThrowingFeedDataSource(StateError('bad state')),
        );

        final result = await repository.fetchFeedItems(_FakeFeedRequest());

        expect(result.isFailure, isTrue);
        result.fold((failure) {
          expect(failure.message, contains('Unexpected error'));
          expect(failure.message, contains('bad state'));
          // A StateError is an Error, not an Exception, so the cause slot is
          // deliberately left null rather than holding something of the wrong
          // type.
          expect(failure.exception, isNull);
        }, (_) => fail('expected a Failure'));
      },
    );

    test('markAsDelivered maps the same three branches', () async {
      final item = _FakeFeedItem('n1');

      final ok = await NotificationFeedRepositoryImpl(
        remoteDataSource: _EmptyFeedDataSource(),
      ).markAsDelivered(item);
      expect(ok.isSuccess, isTrue);

      final typed = await NotificationFeedRepositoryImpl(
        remoteDataSource: _ThrowingFeedDataSource(
          const NotificationFeedRemoteException(message: 'nope', code: 'E1'),
        ),
      ).markAsDelivered(item);
      expect(typed.isFailure, isTrue);
      typed.fold((f) => expect(f.code, 'E1'), (_) => fail('expected Failure'));

      final untyped = await NotificationFeedRepositoryImpl(
        remoteDataSource: _ThrowingFeedDataSource(StateError('bad')),
      ).markAsDelivered(item);
      expect(untyped.isFailure, isTrue);
    });
  });
}
