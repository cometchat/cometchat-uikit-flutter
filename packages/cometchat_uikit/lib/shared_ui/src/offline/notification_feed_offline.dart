import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

import '../../../chat_ui/src/notification_feed/data/datasources/notification_feed_remote_datasource.dart';
import '../../../chat_ui/src/notification_feed/data/repositories/notification_feed_repository_impl.dart';
import '../../../chat_ui/src/notification_feed/domain/usecases/get_feed_items_usecase.dart';
import 'message_list_offline_reads.dart' show isNotConnectedError;
import 'two_phase.dart';

/// A feed-items source that can read in two rounds (cached page, then server
/// page). Internal: a custom [GetFeedItemsUseCase] that implements it is read
/// in two rounds too; one that does not keeps today's single read.
abstract interface class NotificationFeedTwoPhaseSource {
  /// One two-phase read of [request]: zero or one [Cached], then one [Server]
  /// or [PhaseError]; the stream closes after its terminal.
  Stream<TwoPhaseResult<NotificationFeedItem>> fetchFeedItemsTwoPhase(
    NotificationFeedRequest request,
  );
}

/// W7's seam: the notification feed read in two rounds when offline is on
/// (PR #23 README §3.9 "Reactions list, notification feed").
///
/// Each read shows the cached page at once, then replaces it with the server
/// page in server order; "load more" appends only items not already shown, so
/// a re-delivery past the last page never repeats one.
abstract final class NotificationFeedOffline {
  static final Expando<bool> _offlineState = Expando<bool>(
    'NotificationFeedOffline.offlineState',
  );

  /// Whether [e] is the not-connected error: never an error view or
  /// `onError` over items (D84 (2)).
  static bool isOffline(CometChatException e) => isNotConnectedError(e);

  /// Whether the error state of the feed owned by [bloc] is the offline state
  /// (D84 (3)): a first read with nothing to show failed because the device
  /// is offline. The widget shows "Connect to load notifications" (no Retry)
  /// for it instead of the error view.
  static bool showsOfflineState(Object bloc) => _offlineState[bloc] ?? false;

  /// Records whether [bloc]'s next error state is the offline state; the
  /// widget clears it when the feed leaves the error state.
  static void setOfflineState(Object bloc, bool value) =>
      _offlineState[bloc] = value ? true : null;

  /// The two-phase source behind [useCase]: the use case itself when it
  /// implements [NotificationFeedTwoPhaseSource], the SDK read when it is the
  /// kit's standard wiring, else null (today's single read).
  static NotificationFeedTwoPhaseSource? sourceFor(
    GetFeedItemsUseCase useCase,
  ) {
    if (useCase is NotificationFeedTwoPhaseSource) {
      return useCase as NotificationFeedTwoPhaseSource;
    }
    final repository = useCase.repository;
    if (repository is NotificationFeedRepositoryImpl &&
        repository.remoteDataSource is NotificationFeedRemoteDataSourceImpl) {
      return const _SdkFeedTwoPhase();
    }
    return null;
  }

  /// [before] plus the items of [page] whose id is not already in it, in page
  /// order. Returns a new list.
  static List<NotificationFeedItem> append(
    List<NotificationFeedItem> before,
    List<NotificationFeedItem> page,
  ) {
    final seen = {for (final i in before) i.id};
    return [
      ...before,
      for (final i in page)
        if (seen.add(i.id)) i,
    ];
  }
}

class _SdkFeedTwoPhase implements NotificationFeedTwoPhaseSource {
  const _SdkFeedTwoPhase();

  @override
  Stream<TwoPhaseResult<NotificationFeedItem>> fetchFeedItemsTwoPhase(
    NotificationFeedRequest request,
  ) {
    final controller = StreamController<TwoPhaseResult<NotificationFeedItem>>();
    var closed = false;
    void terminal(TwoPhaseResult<NotificationFeedItem> event) {
      if (closed) return;
      closed = true;
      controller.add(event);
      controller.close();
    }

    controller.onListen = () {
      request.fetchNext(
        onSuccess: null,
        onError: null,
        listener: _FeedListener(
          onCached: (rows) {
            if (!closed) controller.add(Cached(rows));
          },
          onServer: (rows) => terminal(Server(rows)),
          onError: (e) => terminal(PhaseError(e)),
        ),
      );
    };
    return controller.stream;
  }
}

class _FeedListener implements NotificationFeedFetchListener {
  _FeedListener({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;

  final void Function(List<NotificationFeedItem>) onCached;
  final void Function(List<NotificationFeedItem>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedNotificationFeedItems(List<NotificationFeedItem> items) =>
      onCached(items);

  @override
  void onServerNotificationFeedItems(List<NotificationFeedItem> items) =>
      onServer(items);

  @override
  void onError(CometChatException e) => _onError(e);
}
