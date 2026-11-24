/// Notification feed on session end and cache reset (G8, ENG-41569).
///
/// The feed reads through a scripted two-phase use case with offline on, and
/// through the mocked repository with offline off. The hub is driven the way
/// a logout produces it: offline on during the session, the SDK then reports
/// offline off, and only then do the logout signals arrive.
///
///   flutter test test/chat_ui/notification_feed/notification_feed_session_end_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/repositories/notification_feed_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/get_categories_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/get_feed_item_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/get_feed_items_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/get_unread_count_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/mark_feed_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/mark_feed_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/domain/usecases/report_feed_engagement_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/notification_feed_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements NotificationFeedRepository {}

NotificationFeedItem _item(String id) => NotificationFeedItem(
  id: id,
  category: 'promotions',
  content: const {'type': 'test'},
  sentAt: 1700000000,
  sender: 'server',
  receiver: 'user1',
  receiverType: 'user',
);

/// Answers each two-phase read with the next scripted stream.
class _TwoPhaseUseCase extends GetFeedItemsUseCase
    implements NotificationFeedTwoPhaseSource {
  _TwoPhaseUseCase(super.repository);

  final answers = <Stream<TwoPhaseResult<NotificationFeedItem>>>[];
  int reads = 0;

  @override
  Stream<TwoPhaseResult<NotificationFeedItem>> fetchFeedItemsTwoPhase(
    NotificationFeedRequest request,
  ) {
    reads++;
    return answers.removeAt(0);
  }
}

Stream<TwoPhaseResult<NotificationFeedItem>> _phases(
  List<TwoPhaseResult<NotificationFeedItem>> events,
) => Stream.fromIterable(events);

final _hub = OfflineHub.instance;

void _logout() {
  CometChat.debugSetOfflineEnabledOverride(false);
  _hub.onKitLogout();
  _hub.debugLogout();
}

void _cacheReset() =>
    _hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);

void main() {
  late _Repo repo;

  setUpAll(() {
    registerFallbackValue(NotificationFeedRequestBuilder().build());
    registerFallbackValue(NotificationCategoriesRequestBuilder().build());
    registerFallbackValue(_item('fallback'));
  });

  setUp(() {
    repo = _Repo();
    when(
      () => repo.fetchCategories(any()),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repo.fetchFeedItems(any()),
    ).thenAnswer((_) async => Success([_item('legacy')]));
    when(
      () => repo.markAsDelivered(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => repo.getUnreadCount()).thenAnswer((_) async => const Success(0));
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  NotificationFeedBloc make(GetFeedItemsUseCase items) {
    final bloc = NotificationFeedBloc(
      getFeedItemsUseCase: items,
      getCategoriesUseCase: GetCategoriesUseCase(repo),
      markFeedDeliveredUseCase: MarkFeedDeliveredUseCase(repo),
      markFeedReadUseCase: MarkFeedReadUseCase(repo),
      reportFeedEngagementUseCase: ReportFeedEngagementUseCase(repo),
      getUnreadCountUseCase: GetUnreadCountUseCase(repo),
      getFeedItemUseCase: GetFeedItemUseCase(repo),
      disableSDKListeners: true,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  List<String> ids(NotificationFeedState s) => [for (final i in s.items) i.id];

  test('sessionEnded clears rows and resets paging', () async {
    final items = _TwoPhaseUseCase(repo)
      ..answers.add(
        _phases([
          Server([_item('a'), _item('b')]),
        ]),
      );
    final bloc = make(items);
    await pumpEventQueue();
    expect(ids(bloc.state), ['a', 'b']);
    expect(bloc.state.hasMorePages, isTrue);

    _logout();
    await pumpEventQueue();

    expect(bloc.state.items, isEmpty);
    expect(bloc.state.screenState, NotificationFeedScreenState.empty);
    expect(bloc.state.hasMorePages, isFalse);
    expect(bloc.state.totalUnreadCount, 0);
    // Paging is closed: nothing is read past the cleared page.
    bloc.add(const LoadMoreFeedItems());
    await pumpEventQueue();
    expect(items.reads, 1);

    // The next user's load reads page one again.
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('bob');
    items.answers.add(
      _phases([
        Server([_item('c')]),
      ]),
    );
    bloc.add(const LoadNotificationFeed());
    await pumpEventQueue();
    expect(items.reads, 2);
    expect(ids(bloc.state), ['c']);
  });

  test('sessionEnded drops the result of a read in flight', () async {
    final pending = StreamController<TwoPhaseResult<NotificationFeedItem>>();
    final items = _TwoPhaseUseCase(repo)
      ..answers.add(
        _phases([
          Server([_item('a')]),
        ]),
      )
      ..answers.add(pending.stream);
    final bloc = make(items);
    await pumpEventQueue();
    bloc.add(const LoadMoreFeedItems());
    await pumpEventQueue();
    expect(items.reads, 2); // the load-more is waiting

    _logout();
    await pumpEventQueue();
    pending.add(Server([_item('b')]));
    await pending.close();
    await pumpEventQueue();

    expect(bloc.state.items, isEmpty);
    expect(bloc.state.isLoadingMore, isFalse);
  });

  test('stale event is ignored', () async {
    final items = _TwoPhaseUseCase(repo)
      ..answers.add(
        _phases([
          Server([_item('a')]),
        ]),
      );
    final bloc = make(items);
    await pumpEventQueue();

    // Published, then the session ends before it is delivered: it belongs to
    // the old session, so it must not reload.
    _cacheReset();
    _logout();
    await pumpEventQueue();

    expect(items.reads, 1);
    expect(bloc.state.items, isEmpty);
  });

  test('cacheReset clears then reloads once', () async {
    final items = _TwoPhaseUseCase(repo)
      ..answers.add(
        _phases([
          Server([_item('a')]),
        ]),
      )
      ..answers.add(
        _phases([
          Server([_item('b')]),
        ]),
      );
    final bloc = make(items);
    await pumpEventQueue();
    final states = <NotificationFeedState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _cacheReset();
    await pumpEventQueue();

    expect(states.first.items, isEmpty);
    expect(items.reads, 2);
    expect(ids(bloc.state), ['b']);
  });

  test('cacheReset reload failure over rows is quiet', () async {
    final items = _TwoPhaseUseCase(repo)
      ..answers.add(
        _phases([
          Server([_item('a')]),
        ]),
      )
      ..answers.add(
        _phases([
          Cached([_item('c')]),
          PhaseError(CometChatException('ERR_INTERNAL_SERVER', 'x', 'x')),
        ]),
      );
    final bloc = make(items);
    final errors = <CometChatException>[];
    void sink(CometChatException e) => errors.add(e);
    OfflineListErrors.listen(bloc, sink);
    addTearDown(() => OfflineListErrors.cancel(bloc, sink));
    await pumpEventQueue();

    _cacheReset();
    await pumpEventQueue();

    expect(ids(bloc.state), ['c']);
    expect(errors, isEmpty);
  });

  test('offline off: no change', () async {
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(false);
    _hub.debugLoginSuccess('alice');
    final bloc = make(GetFeedItemsUseCase(repo));
    await pumpEventQueue();
    expect(ids(bloc.state), ['legacy']);

    _cacheReset();
    _hub.onKitLogout();
    _hub.debugLogout();
    await pumpEventQueue();

    expect(ids(bloc.state), ['legacy']);
    verify(() => repo.fetchFeedItems(any())).called(1);
  });

  test('close cancels the hub subscription', () async {
    final bloc = make(_TwoPhaseUseCase(repo)..answers.add(_phases([])));
    expect(_hub.debugHasListeners, isTrue);
    await bloc.close();
    expect(_hub.debugHasListeners, isFalse);
  });
}
