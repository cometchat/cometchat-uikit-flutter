// W7 (ENG-41130): the notification feed reads in two rounds when offline is on
// (PR #23 README §3.9). Cached page at once, then the server page in its place;
// "load more" never repeats an item; a server error after cached rows keeps
// them with no error. Offline off keeps today's single read.

import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/bloc/notification_feed_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/data/datasources/notification_feed_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/data/repositories/notification_feed_repository_impl.dart';
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

/// A custom items use case that reads in two rounds from a script (one entry
/// per read; the last repeats).
class _TwoPhaseUseCase extends GetFeedItemsUseCase
    implements NotificationFeedTwoPhaseSource {
  _TwoPhaseUseCase(super.repository, this.script);

  final List<List<TwoPhaseResult<NotificationFeedItem>>> script;
  int reads = 0;

  @override
  Stream<TwoPhaseResult<NotificationFeedItem>> fetchFeedItemsTwoPhase(
    NotificationFeedRequest request,
  ) {
    final read = script[reads < script.length ? reads : script.length - 1];
    reads++;
    return Stream.fromIterable(read);
  }
}

final _offline = CometChatException('ERR_CONNECTION', 'offline', 'offline');

void main() {
  late _Repo repo;
  NotificationFeedBloc? bloc;

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
  });

  tearDown(() async {
    await bloc?.close();
    bloc = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  // The bloc loads the first page itself at construction.
  NotificationFeedBloc make(GetFeedItemsUseCase items) =>
      bloc = NotificationFeedBloc(
        getFeedItemsUseCase: items,
        getCategoriesUseCase: GetCategoriesUseCase(repo),
        markFeedDeliveredUseCase: MarkFeedDeliveredUseCase(repo),
        markFeedReadUseCase: MarkFeedReadUseCase(repo),
        reportFeedEngagementUseCase: ReportFeedEngagementUseCase(repo),
        getUnreadCountUseCase: GetUnreadCountUseCase(repo),
        getFeedItemUseCase: GetFeedItemUseCase(repo),
        disableSDKListeners: true,
      );

  List<String> ids(NotificationFeedState s) => [for (final i in s.items) i.id];

  test('sourceFor: custom two-phase use case, the SDK wiring, else null', () {
    final custom = _TwoPhaseUseCase(repo, const []);
    expect(NotificationFeedOffline.sourceFor(custom), same(custom));
    final standard = GetFeedItemsUseCase(
      NotificationFeedRepositoryImpl(
        remoteDataSource: NotificationFeedRemoteDataSourceImpl(),
      ),
    );
    expect(NotificationFeedOffline.sourceFor(standard), isNotNull);
    expect(
      NotificationFeedOffline.sourceFor(GetFeedItemsUseCase(repo)),
      isNull,
    );
  });

  test('ON: cached page at once, then the server page in its place', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        Cached([_item('a'), _item('stale')]),
        Server([_item('a'), _item('b')]),
      ],
    ]);
    final b = make(items);
    final states = <NotificationFeedState>[];
    final sub = b.stream.listen(states.add);
    await pumpEventQueue();
    await sub.cancel();

    final loaded = states
        .where((s) => s.screenState == NotificationFeedScreenState.loaded)
        .toList();
    expect(ids(loaded.first), ['a', 'stale']);
    expect(ids(b.state), ['a', 'b']);
    expect(b.state.hasMorePages, isTrue);
    verifyNever(() => repo.fetchFeedItems(any()));
  });

  test('ON: load more never repeats; a page adding nothing ends it', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        const Cached([]),
        Server([_item('a'), _item('b')]),
      ],
      [
        Cached([_item('b')]),
        Server([_item('b'), _item('c')]),
      ],
      // Re-delivery past the last page.
      [
        Cached([_item('c')]),
        Server([_item('c')]),
      ],
    ]);
    final b = make(items);
    await pumpEventQueue();
    b.add(const LoadMoreFeedItems());
    await pumpEventQueue();
    expect(ids(b.state), ['a', 'b', 'c']);
    expect(b.state.hasMorePages, isTrue);
    expect(b.state.isLoadingMore, isFalse);

    b.add(const LoadMoreFeedItems());
    await pumpEventQueue();
    expect(ids(b.state), ['a', 'b', 'c']);
    expect(b.state.hasMorePages, isFalse);
  });

  test('ON: a server error after cached rows keeps them, no error', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        Cached([_item('a')]),
        PhaseError(_offline),
      ],
      [
        Cached([_item('b')]),
        PhaseError(_offline),
      ],
    ]);
    final b = make(items);
    await pumpEventQueue();
    expect(b.state.screenState, NotificationFeedScreenState.loaded);
    expect(ids(b.state), ['a']);
    expect(b.state.error, isNull);

    b.add(const LoadMoreFeedItems());
    await pumpEventQueue();
    expect(ids(b.state), ['a', 'b']);
    expect(b.state.isLoadingMore, isFalse);

    // Refresh offline keeps the rows shown, with no error.
    b.add(const RefreshFeed());
    await pumpEventQueue();
    expect(ids(b.state), ['a', 'b']);
    expect(b.state.isRefreshing, isFalse);
    expect(b.state.screenState, NotificationFeedScreenState.loaded);
  });

  test('D84 (3) ON: an empty cached page then a not-connected error is the '
      'offline state', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [const Cached([]), PhaseError(_offline)],
    ]);
    final b = make(items);
    await pumpEventQueue();
    expect(b.state.screenState, NotificationFeedScreenState.error);
    expect(NotificationFeedOffline.showsOfflineState(b), isTrue);
  });

  test('D84 (4) ON: an empty cached page then a real error is today\'s '
      'error view', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        const Cached([]),
        PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x')),
      ],
    ]);
    final b = make(items);
    await pumpEventQueue();
    expect(b.state.screenState, NotificationFeedScreenState.error);
    expect(NotificationFeedOffline.showsOfflineState(b), isFalse);
  });

  test('OFF: today\'s single read, the two-phase read is never used', () async {
    CometChat.debugSetOfflineEnabledOverride(false);
    final items = _TwoPhaseUseCase(repo, [
      [
        Cached([_item('x')]),
        Server([_item('x')]),
      ],
    ]);
    final b = make(items);
    await pumpEventQueue();
    expect(items.reads, 0);
    expect(ids(b.state), ['legacy']);
    verify(() => repo.fetchFeedItems(any())).called(1);
  });

  test('D84 (2) ON: cached rows and a not-connected error keep the rows and '
      'do not reach onError', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        Cached([_item('a')]),
        PhaseError(_offline),
      ],
    ]);
    final b = make(items);
    final errors = <CometChatException>[];
    OfflineListErrors.listen(b, errors.add);
    await pumpEventQueue();
    expect(ids(b.state), ['a']);
    expect(b.state.screenState, NotificationFeedScreenState.loaded);
    expect(errors, isEmpty);
  });

  test('D84 (5) ON: cached rows and a real server error keep the rows and '
      'reach onError once', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        Cached([_item('a')]),
        PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x')),
      ],
    ]);
    final b = make(items);
    final errors = <CometChatException>[];
    OfflineListErrors.listen(b, errors.add);
    await pumpEventQueue();
    expect(ids(b.state), ['a']);
    expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
  });

  test('D84 (6) ON: an empty server page shows the empty view', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [const Cached([]), const Server([])],
    ]);
    final b = make(items);
    await pumpEventQueue();
    expect(b.state.screenState, NotificationFeedScreenState.empty);
  });

  test(
    'D84 (8) ON: the offline state is replaced by the one reconnect refresh',
    () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final items = _TwoPhaseUseCase(repo, [
        [const Cached([]), PhaseError(_offline)],
        [
          Server([_item('a')]),
        ],
      ]);
      final b = make(items);
      await pumpEventQueue();
      expect(b.state.screenState, NotificationFeedScreenState.error);
      expect(NotificationFeedOffline.showsOfflineState(b), isTrue);

      b.add(const ConnectionStateChanged(false));
      await pumpEventQueue();
      expect(items.reads, 2);
      expect(ids(b.state), ['a']);
      expect(b.state.screenState, NotificationFeedScreenState.loaded);
    },
  );

  test('D84 (2), (5) ON: a refresh failing offline over items shown stays '
      'silent, the reconnect one and pull-to-refresh alike', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final items = _TwoPhaseUseCase(repo, [
      [
        Server([_item('a')]),
      ],
      [
        Cached([_item('a')]),
        PhaseError(_offline),
      ],
      [
        Cached([_item('a')]),
        PhaseError(_offline),
      ],
    ]);
    final b = make(items);
    final errors = <CometChatException>[];
    OfflineListErrors.listen(b, errors.add);
    await pumpEventQueue();
    expect(ids(b.state), ['a']);

    b.add(const ConnectionStateChanged(false));
    await pumpEventQueue();
    expect(items.reads, 2);
    expect(ids(b.state), ['a']);
    expect(b.state.screenState, NotificationFeedScreenState.loaded);
    expect(b.state.isRefreshing, isFalse);
    expect(errors, isEmpty);

    b.add(const RefreshFeed());
    await pumpEventQueue();
    expect(items.reads, 3);
    expect(ids(b.state), ['a']);
    expect(errors, isEmpty);
  });

  test('D84 (5) ON: a real error over items shown reaches onError on '
      'pull-to-refresh, not on the reconnect refresh', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final real = CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x');
    final items = _TwoPhaseUseCase(repo, [
      [
        Server([_item('a')]),
      ],
      [
        Cached([_item('a')]),
        PhaseError(real),
      ],
      [
        Cached([_item('a')]),
        PhaseError(real),
      ],
    ]);
    final b = make(items);
    final errors = <CometChatException>[];
    OfflineListErrors.listen(b, errors.add);
    await pumpEventQueue();

    b.add(const ConnectionStateChanged(false));
    await pumpEventQueue();
    expect(items.reads, 2);
    expect(errors, isEmpty);

    b.add(const RefreshFeed());
    await pumpEventQueue();
    expect(items.reads, 3);
    expect(ids(b.state), ['a']);
    expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
  });
}
