// Message-list reads on the offline ON path (W2, ENG-41092): two-phase reads,
// the windowed reconcile, open newest first, cursors, refreshNewestWindow.
//
// The real MessageListBloc runs over a fake datasource that implements the
// two-phase interface, so every phase is driven by hand.

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/data/datasources/message_list_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/data/repositories/message_list_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/utils/message_operation.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_reads.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_sync.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'alice', name: 'Alice');
final _bob = User(uid: 'bob', name: 'Bob');

/// A received message with server [id], sent at second [id].
TextMessage _m(int id, {int? updatedAtMs, String text = ''}) => TextMessage(
  id: id,
  text: text.isEmpty ? 'm$id' : text,
  sender: _bob,
  receiverUid: 'alice',
  type: 'text',
  receiverType: 'user',
  conversationId: 'alice_user_bob',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000),
  updatedAt: updatedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
);

/// An own message: un-acked when [id] is 0.
TextMessage _own({int id = 0, String lid = 'L1', String muid = 'M1'}) =>
    TextMessage(
      id: id,
      text: 'own',
      sender: _alice,
      receiverUid: 'bob',
      type: 'text',
      receiverType: 'user',
      conversationId: 'alice_user_bob',
      muid: muid,
      sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + 999000),
    )..localMessageId = lid;

List<TextMessage> _range(int from, int to) => [
  for (var i = from; i <= to; i++) _m(i),
];

/// One two-phase call the bloc made.
class _Call {
  _Call(this.request, this.previous);
  final MessagesRequest request;
  final bool previous;
  final StreamController<TwoPhaseResult<BaseMessage>> ctl =
      StreamController<TwoPhaseResult<BaseMessage>>();

  void cached(List<BaseMessage> rows) => ctl.add(Cached(rows));
  void server(List<BaseMessage> rows) {
    ctl.add(Server(rows));
    ctl.close();
  }

  void error(String code) {
    ctl.add(PhaseError(CometChatException(code, code, code)));
    ctl.close();
  }
}

class _FakeDataSource extends Fake
    implements MessageListRemoteDataSource, MessageListTwoPhaseDataSource {
  final List<_Call> calls = [];
  int singlePhaseLoads = 0;
  Conversation? conversation;

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchPreviousTwoPhase(
    MessagesRequest request,
  ) {
    final c = _Call(request, true);
    calls.add(c);
    return c.ctl.stream;
  }

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchNextTwoPhase(
    MessagesRequest request,
  ) {
    final c = _Call(request, false);
    calls.add(c);
    return c.ctl.stream;
  }

  @override
  Future<GetMessagesResult> getMessages({
    required String conversationWith,
    required String conversationType,
    int limit = 30,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    bool hideReplies = true,
    bool withParent = true,
  }) async {
    singlePhaseLoads++;
    final request = MessagesRequestBuilder().build();
    return GetMessagesResult(request: request, messages: _range(1, 3));
  }

  @override
  Future<Conversation> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async {
    final c = conversation;
    if (c == null) {
      throw MessageListRemoteDataSourceException(message: 'none');
    }
    return c;
  }
}

/// One two-phase conversation read the bloc made.
class _ConvCall {
  final StreamController<TwoPhaseResult<Conversation>> ctl =
      StreamController<TwoPhaseResult<Conversation>>();

  void cached(Conversation c) => ctl.add(Cached([c]));
  void server(Conversation c) {
    ctl.add(Server([c]));
    ctl.close();
  }

  void error(String code) {
    ctl.add(PhaseError(CometChatException(code, code, code)));
    ctl.close();
  }
}

/// A datasource that also reads the conversation in two phases, as the kit's
/// own datasource does through the SDK (D60).
class _ConvDataSource extends _FakeDataSource
    implements ConversationTwoPhaseDataSource {
  final List<_ConvCall> convCalls = [];

  @override
  Stream<TwoPhaseResult<Conversation>> getConversationTwoPhase({
    required String conversationWith,
    required String conversationType,
  }) {
    final c = _ConvCall();
    convCalls.add(c);
    return c.ctl.stream;
  }
}

class _Harness {
  _Harness({int? parentMessageId, _FakeDataSource? dataSource})
    : ds = dataSource ?? _FakeDataSource() {
    bloc = MessageListBloc(
      disableSDKListeners: true,
      disableReceipts: true,
      user: _bob,
      parentMessageId: parentMessageId,
      getMessagesUseCase: GetMessagesUseCase(
        MessageListRepositoryImpl(remoteDataSource: ds),
      ),
    );
    opsSub = bloc.operationsStream.listen(ops.add);
  }

  final _FakeDataSource ds;
  late final MessageListBloc bloc;
  final List<MessageOperation> ops = [];
  late final StreamSubscription<MessageOperation> opsSub;

  _Call get last => ds.calls.last;
  List<int> get ids => bloc.state.messages.map((m) => m.id).toList();
  MessageListReadsView get view => messageListReadsViewOf(bloc);

  Future<void> load() async {
    bloc.add(
      const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
    );
    await pumpEventQueue();
  }

  /// Loads the newest page [from]..[to] through both phases.
  Future<void> loaded(int from, int to) async {
    await load();
    last.cached(_range(from, to));
    last.server(_range(from, to));
    await pumpEventQueue();
  }

  Future<void> close() async {
    await opsSub.cancel();
    await bloc.close();
  }
}

Future<void> _settle() => pumpEventQueue();

void main() {
  final hub = OfflineHub.instance;

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('alice');
    CometChatUIKit.loggedInUser = _alice;
  });

  tearDown(() {
    CometChat.debugSetOfflineEnabledOverride(null);
    CometChatUIKit.loggedInUser = null;
  });

  group('initial read', () {
    test(
      'cached page paints first, then the server page lands in place',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.load();
        expect(h.bloc.state.status, MessageListStatus.loading);
        expect(h.last.previous, isTrue);
        expect(h.last.request.messageId, isNull, reason: 'newest page');

        h.last.cached(_range(1, 3));
        await _settle();
        expect(h.bloc.state.status, MessageListStatus.loaded);
        expect(h.ids, [1, 2, 3]);
        final firstPaint = h.bloc.state.messages;

        h.last.server([_m(1), _m(2), _m(3, updatedAtMs: 5000, text: 'edited')]);
        await _settle();
        expect(h.ids, [1, 2, 3]);
        expect((h.bloc.state.messages[2] as TextMessage).text, 'edited');
        expect(
          identical(h.bloc.state.messages.first, firstPaint.first),
          isFalse,
        );
        // The server phase diffs in place: never a reset over rows shown.
        final last = h.ops.last;
        expect(last.type, MessageOperationType.set);
        expect(last.animated, isTrue);
        expect(last.oldMessages, isNotNull);
        expect(h.bloc.state.hasMoreNewer, isFalse);
      },
    );

    test(
      'a server omission inside its range is removed, outside kept',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.load();
        h.last.cached(_range(1, 5));
        await _settle();
        h.last.server([_m(2), _m(3), _m(5)]);
        await _settle();
        expect(h.ids, [1, 2, 3, 5]);
      },
    );

    test('an unsent row survives the server page, sorted last', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached([_m(1), _own(), _m(2)]);
      await _settle();
      h.last.server([_m(1), _m(2), _m(3)]);
      await _settle();
      expect(h.ids, [1, 2, 3, 0]);
    });

    test('an acked copy replaces its unsent row: no duplicate', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached([_m(1), _own()]);
      await _settle();
      h.last.server([_m(1), _own(id: 9)]);
      await _settle();
      expect(h.ids, [1, 9]);
    });

    test('a live edit is never reverted by an older server copy', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached([_m(1), _m(2, updatedAtMs: 9000, text: 'live edit')]);
      await _settle();
      h.last.server([_m(1), _m(2, updatedAtMs: 1000, text: 'old')]);
      await _settle();
      expect((h.bloc.state.messages[1] as TextMessage).text, 'live edit');
    });

    test('an empty cached page keeps the loader; the server answers', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached(const []);
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.loading);
      h.last.server(const []);
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.empty);
    });

    test('offline with cached rows keeps them, no error state', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached(_range(1, 3));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.hasMoreOlder, isTrue);
    });

    test('a phase of a superseded read is dropped', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      final first = h.last;
      await h.load();
      final second = h.last;
      second.cached(_range(10, 12));
      await _settle();
      first.server(_range(1, 3));
      await _settle();
      expect(h.ids, [10, 11, 12]);
      second.server(_range(10, 12));
      await _settle();
      expect(h.ids, [10, 11, 12]);
    });

    test('a phase after a session end (stale gen) is dropped', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);

      CometChat.debugSetOfflineEnabledOverride(false);
      hub.onKitLogout();
      hub.debugLogout();
      await _settle();
      expect(h.bloc.state.messages, isEmpty);
      final opsAtClear = h.ops.length;

      h.last.server(_range(1, 3));
      await _settle();
      expect(h.bloc.state.messages, isEmpty);
      expect(h.ops.length, opsAtClear);
    });
  });

  group('paging', () {
    test('an empty cached page keeps "has more"; an empty online server page '
        'ends it', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(5, 7);
      expect(h.bloc.state.hasMoreOlder, isTrue);

      h.bloc.add(const LoadOlderMessages());
      await _settle();
      expect(h.last.previous, isTrue);
      expect(h.last.request.messageId, 5, reason: 'anchored on oldest row');
      h.last.cached(const []);
      await _settle();
      expect(h.bloc.state.hasMoreOlder, isTrue);
      h.last.server(const []);
      await _settle();
      expect(h.bloc.state.hasMoreOlder, isFalse);
      expect(h.bloc.state.isLoadingOlder, isFalse);
    });

    test('an older page is prepended (today\'s paging operation)', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(5, 7);
      h.bloc.add(const LoadOlderMessages());
      await _settle();
      h.last.cached(_range(2, 4));
      await _settle();
      expect(h.ids, [2, 3, 4, 5, 6, 7]);
      expect(h.ops.last.type, MessageOperationType.insertAll);
      expect(h.ops.last.index, 0);
      h.last.server(_range(2, 4));
      await _settle();
      expect(h.ids, [2, 3, 4, 5, 6, 7]);
      expect(h.bloc.state.hasMoreOlder, isTrue);
    });

    test('offline past the cache shows "Connect to load more"; retry clears '
        'it', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(5, 7);
      h.bloc.add(const LoadOlderMessages());
      await _settle();
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.view.connectToLoadMore.value, isTrue);
      expect(h.ids, [5, 6, 7]);
      expect(h.bloc.state.hasMoreOlder, isTrue);
      expect(h.bloc.state.isLoadingOlder, isFalse);

      h.bloc.add(const LoadOlderMessages()); // tap-to-retry
      await _settle();
      expect(h.view.connectToLoadMore.value, isFalse);
      h.last.server(_range(2, 4));
      await _settle();
      expect(h.ids, [2, 3, 4, 5, 6, 7]);
    });

    test(
      'a page overtaken by a new window read is dropped, loader cleared',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.loaded(5, 7);
        h.bloc.add(const LoadOlderMessages());
        await _settle();
        final older = h.last;
        expect(h.bloc.state.isLoadingOlder, isTrue);
        await h.load();
        final window = h.last;
        older.server(_range(2, 4));
        await _settle();
        expect(h.bloc.state.isLoadingOlder, isFalse);
        expect(h.ids, [5, 6, 7]);
        window.server(_range(5, 8));
        await _settle();
        expect(h.ids, [5, 6, 7, 8]);
      },
    );

    test(
      'a server error that is not connectivity keeps rows, no footer',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.loaded(5, 7);
        h.bloc.add(const LoadOlderMessages());
        await _settle();
        h.last.error('ERR_HTTP_500');
        await _settle();
        expect(h.view.connectToLoadMore.value, isFalse);
        expect(h.ids, [5, 6, 7]);
        expect(h.bloc.state.isLoadingOlder, isFalse);
      },
    );
  });

  group('open from unread (newest first)', () {
    test('reads the newest page, then jumps to the unread anchor; the newer '
        'cursor skips unsent rows', () async {
      final h = _Harness();
      addTearDown(h.close);
      h.ds.conversation = Conversation(
        conversationType: 'user',
        conversationWith: _bob,
        lastReadMessageId: 50,
        unreadMessageCount: 80,
      );
      h.bloc.add(
        const LoadFromUnread(conversationWith: 'bob', conversationType: 'user'),
      );
      await _settle();
      final newest = h.last;
      expect(newest.previous, isTrue);
      expect(newest.request.messageId, isNull, reason: 'newest page first');
      newest.cached([..._range(100, 129), _own()]);
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.ids.first, 100);
      newest.server(_range(100, 129));
      await _settle();

      // The anchored read around the last-read message.
      final older = h.ds.calls[h.ds.calls.length - 2];
      final newer = h.last;
      expect(older.previous, isTrue);
      expect(older.request.messageId, 51);
      expect(newer.previous, isFalse);
      expect(newer.request.messageId, 50);
      older.server(_range(21, 50));
      newer.server(_range(51, 80));
      await _settle();

      expect(h.ids.first, 21);
      expect(h.ids.last, 0, reason: 'the unsent row stays, sorted last');
      expect(h.bloc.state.unreadMessageAnchorId, 51);
      expect(h.bloc.state.hasMoreNewer, isTrue, reason: 'gap loads on scroll');

      h.bloc.add(const LoadNewerMessages());
      await _settle();
      expect(h.last.previous, isFalse);
      expect(h.last.request.messageId, 80, reason: 'newest row with an id');
    });

    test(
      'no jump when the newest page reaches the last-read message',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        h.ds.conversation = Conversation(
          conversationType: 'user',
          conversationWith: _bob,
          lastReadMessageId: 110,
          unreadMessageCount: 19,
        );
        h.bloc.add(
          const LoadFromUnread(
            conversationWith: 'bob',
            conversationType: 'user',
          ),
        );
        await _settle();
        h.last.cached(_range(100, 129));
        h.last.server(_range(100, 129));
        await _settle();
        expect(h.ds.calls, hasLength(1));
        expect(h.bloc.state.unreadMessageAnchorId, 111);
        expect(h.ids.first, 100);
      },
    );
  });

  group('refreshNewestWindow', () {
    Future<void> refresh(_Harness h) async {
      final host = messageListSeamHostOf(h.bloc)!;
      host.run(MessageListOfflineReads.instance.refreshNewestWindow);
      await _settle();
    }

    test('an overlapping server page merges in place', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(1, 5);
      await refresh(h);
      expect(h.last.request.messageId, isNull);
      h.last.cached(_range(3, 8));
      h.last.server(_range(3, 8));
      await _settle();
      expect(h.ids, [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('a disjoint server page resets to that window when pinned', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(1, 5);
      await refresh(h);
      h.last.cached(_range(50, 55)); // a cached page alone never resets
      await _settle();
      expect(h.ids, [1, 2, 3, 4, 5]);
      h.last.server(_range(50, 55));
      await _settle();
      expect(h.ids, [50, 51, 52, 53, 54, 55]);
      expect(h.view.jumpToLatest.value, isFalse);
    });

    test(
      'a disjoint server page offers "Jump to latest" when scrolled up',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.loaded(1, 5);
        h.view.isAtBottom = () => false;
        await refresh(h);
        h.last.server(_range(50, 55));
        await _settle();
        expect(h.ids, [1, 2, 3, 4, 5]);
        expect(h.view.jumpToLatest.value, isTrue);
        expect(h.bloc.state.hasMoreNewer, isTrue);

        // The pill refreshes: a plain read over a non-newest window resets.
        h.bloc.add(const RefreshMessages());
        await _settle();
        h.last.server(_range(50, 55));
        await _settle();
        expect(h.ids, [50, 51, 52, 53, 54, 55]);
        expect(h.view.jumpToLatest.value, isFalse);
        expect(h.bloc.state.hasMoreNewer, isFalse);
      },
    );
  });

  group('review fixes', () {
    Future<void> refresh(_Harness h) async {
      messageListSeamHostOf(
        h.bloc,
      )!.run(MessageListOfflineReads.instance.refreshNewestWindow);
      await _settle();
    }

    /// Opens from unread with the newest page 100..129 and last-read 50, and
    /// answers the newest page; returns the two anchored calls (older, newer).
    Future<(_Call, _Call)> openFromUnread(_Harness h) async {
      h.ds.conversation = Conversation(
        conversationType: 'user',
        conversationWith: _bob,
        lastReadMessageId: 50,
        unreadMessageCount: 80,
      );
      h.bloc.add(
        const LoadFromUnread(conversationWith: 'bob', conversationType: 'user'),
      );
      await _settle();
      h.last.server(_range(100, 129));
      await _settle();
      return (h.ds.calls[h.ds.calls.length - 2], h.last);
    }

    test('an offline open shows "Connect to load more"; its tap retries the '
        'window read', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached(_range(1, 3));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.view.connectToLoadMore.value, isTrue);

      final calls = h.ds.calls.length;
      expect(h.view.retry(), isTrue); // the footer's tap
      await _settle();
      expect(h.ds.calls, hasLength(calls + 1));
      expect(h.last.previous, isTrue);
      expect(h.last.request.messageId, isNull, reason: 'the newest page again');
      expect(h.view.connectToLoadMore.value, isFalse);
      h.last.server(_range(1, 4));
      await _settle();
      expect(h.ids, [1, 2, 3, 4]);
    });

    test(
      'a newest-window refresh that fails offline shows the footer',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.loaded(1, 3);
        await refresh(h);
        h.last.error('ERR_CONNECTION');
        await _settle();
        expect(h.view.connectToLoadMore.value, isTrue);
        expect(h.ids, [1, 2, 3]);
        expect(h.bloc.state.status, MessageListStatus.loaded);
      },
    );

    test('a jump shows the page around the target and keeps unsent rows; a '
        'non-empty server newer page keeps newer history open', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached([..._range(100, 129), _own()]);
      h.last.server([..._range(100, 129)]);
      await _settle();
      expect(h.ids.last, 0);

      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      final older = h.ds.calls[h.ds.calls.length - 2];
      final newer = h.last;
      expect(older.previous, isTrue);
      expect(older.request.messageId, 51, reason: 'up to and incl. target');
      expect(newer.previous, isFalse);
      expect(newer.request.messageId, 50);
      older.server(_range(21, 50));
      newer.server(_range(51, 55)); // fewer than 30: today would end history
      await _settle();

      expect(h.ids.first, 21);
      expect(h.ids.contains(50), isTrue);
      expect(h.ids.last, 0, reason: 'the unsent row survives (BEH-READ-30)');
      expect(h.bloc.state.hasMoreNewer, isTrue);
      expect(h.bloc.state.hasMoreOlder, isTrue);
      // As today's jump: a reset the widget then scrolls to the target.
      expect(h.ops.last.type, MessageOperationType.set);
      expect(h.ops.last.animated, isFalse);

      h.bloc.add(const LoadNewerMessages());
      await _settle();
      expect(h.last.request.messageId, 55, reason: 'newest row with an id');
    });

    test('an offline jump from the cache never ends newer history', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(100, 129);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      final older = h.ds.calls[h.ds.calls.length - 2];
      final newer = h.last;
      older.cached(_range(41, 50));
      older.error('ERR_CONNECTION');
      newer.cached(_range(51, 52));
      newer.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, _range(41, 52).map((m) => m.id).toList());
      expect(h.bloc.state.hasMoreNewer, isTrue);
      expect(h.bloc.state.hasMoreOlder, isTrue);
      expect(h.view.connectToLoadMore.value, isTrue);
    });

    test('an empty online server newer page ends newer history', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(100, 129);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      h.ds.calls[h.ds.calls.length - 2].server(_range(21, 50));
      h.last.server(const []);
      await _settle();
      expect(h.ids.last, 50);
      expect(h.bloc.state.hasMoreNewer, isFalse);
    });

    test('a jump whose target nobody has leaves the rows', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(100, 129);
      final rows = h.bloc.state.messages;
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      h.ds.calls[h.ds.calls.length - 2].error('ERR_CONNECTION');
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(identical(h.bloc.state.messages, rows), isTrue);
    });

    test('a jump overtaken by a window read is dropped', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(100, 129);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      final older = h.ds.calls[h.ds.calls.length - 2];
      final newer = h.last;
      await refresh(h);
      final window = h.last;
      older.server(_range(21, 50));
      newer.server(_range(51, 80));
      await _settle();
      expect(h.ids.first, 100, reason: 'the stale jump window is dropped');
      window.server(_range(100, 130));
      await _settle();
      expect(h.ids.last, 130);
    });

    test(
      'an unread jump overtaken by a newest-window refresh is dropped',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final (older, newer) = await openFromUnread(h);
        await refresh(h);
        final window = h.last;
        older.server(_range(21, 50));
        newer.server(_range(51, 80));
        await _settle();
        expect(h.ids.first, 100, reason: 'the stale jump window is dropped');
        expect(h.bloc.state.unreadMessageAnchorId, isNull);
        window.server(_range(100, 131));
        await _settle();
        expect(h.ids.first, 100);
        expect(h.ids.last, 131);
      },
    );

    test('after an unread jump a disjoint refresh keeps the place, even at the '
        'bottom of the jumped window', () async {
      final h = _Harness();
      addTearDown(h.close);
      final (older, newer) = await openFromUnread(h);
      older.server(_range(21, 50));
      newer.server(_range(51, 80));
      await _settle();
      expect(h.bloc.state.hasMoreNewer, isTrue);
      h.view.isAtBottom = () => true;

      await refresh(h);
      h.last.server(_range(200, 229));
      await _settle();
      expect(h.ids.first, 21, reason: 'no reset: the unread place stays');
      expect(h.bloc.state.unreadMessageAnchorId, 51);
      expect(h.view.jumpToLatest.value, isTrue);
    });

    test(
      'a newer-page read with no row with a server id sends nothing',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.load();
        h.last.cached([_own()]);
        h.last.error('ERR_CONNECTION');
        await _settle();
        h.view.isAtBottom = () => false;
        await refresh(h);
        h.last.server(_range(1, 3)); // disjoint: "Jump to latest", more newer
        await _settle();
        expect(h.bloc.state.hasMoreNewer, isTrue);
        expect(h.ids, [0]);

        final calls = h.ds.calls.length;
        h.bloc.add(const LoadNewerMessages());
        await _settle();
        expect(
          h.ds.calls,
          hasLength(calls),
          reason: 'no fetchNext w/o a cursor',
        );
        expect(h.bloc.state.isLoadingNewer, isFalse);
        expect(h.bloc.state.hasMoreNewer, isTrue, reason: 'history not ended');
      },
    );

    test('window merges diff in place (never the append operation)', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(1, 5);
      await refresh(h);
      final window = h.last;
      window.cached(_range(1, 5));
      window.server([..._range(1, 5), _m(6)]);
      await _settle();
      expect(h.ids, [1, 2, 3, 4, 5, 6]);
      expect(h.ops.last.type, MessageOperationType.set);
      expect(h.ops.last.animated, isTrue);
      expect(h.ops.last.oldMessages, isNotNull);
    });
  });

  group('D60: an offline open jumps from the cache', () {
    Conversation conv(int lastRead) => Conversation(
      conversationType: 'user',
      conversationWith: _bob,
      lastReadMessageId: lastRead,
      unreadMessageCount: 80,
    );

    /// Opens from unread with the newest page 100..129; [online] answers it
    /// from the server, else from the cache only (offline).
    Future<_Harness> openFromUnread({bool online = false}) async {
      final h = _Harness(dataSource: _ConvDataSource());
      h.bloc.add(
        const LoadFromUnread(conversationWith: 'bob', conversationType: 'user'),
      );
      await _settle();
      h.last.cached(_range(100, 129));
      if (online) {
        h.last.server(_range(100, 129));
      } else {
        h.last.error('ERR_CONNECTION');
      }
      await _settle();
      return h;
    }

    _ConvCall convCall(_Harness h) =>
        (h.ds as _ConvDataSource).convCalls.single;

    test('start-from-unread offline: the cached conversation places the '
        'boundary and the anchored window comes from the cache', () async {
      final h = await openFromUnread();
      addTearDown(h.close);
      convCall(h).cached(conv(50));
      convCall(h).error('ERR_CONNECTION');
      await _settle();

      final older = h.ds.calls[h.ds.calls.length - 2];
      final newer = h.last;
      expect(older.request.messageId, 51);
      expect(newer.request.messageId, 50);
      older.cached(_range(21, 50));
      older.error('ERR_CONNECTION');
      newer.cached([..._range(51, 80), _own()]);
      newer.error('ERR_CONNECTION');
      await _settle();

      expect(h.ids.first, 21);
      expect(h.ids.last, 0, reason: 'the unsent row stays (BEH-READ-30/31)');
      expect(h.bloc.state.unreadMessageAnchorId, 51);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.errorMessage, isNull);
      expect(h.bloc.state.hasMoreNewer, isTrue, reason: 'not ended offline');
      expect(h.bloc.state.hasMoreOlder, isTrue);
    });

    test('start-from-unread offline, target not cached: stays on the newest '
        'cached page with no error and no anchor', () async {
      final h = await openFromUnread();
      addTearDown(h.close);
      convCall(h).cached(conv(50));
      convCall(h).error('ERR_CONNECTION');
      await _settle();
      final rows = h.bloc.state.messages;
      h.ds.calls[h.ds.calls.length - 2].cached(const []);
      h.ds.calls[h.ds.calls.length - 2].error('ERR_CONNECTION');
      h.last.error('ERR_CONNECTION');
      await _settle();

      expect(identical(h.bloc.state.messages, rows), isTrue);
      expect(h.ids.first, 100);
      expect(h.bloc.state.unreadMessageAnchorId, isNull);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.errorMessage, isNull);
    });

    test(
      'start-from-unread offline with no cached conversation: no jump',
      () async {
        final h = await openFromUnread();
        addTearDown(h.close);
        convCall(h).error('ERR_CONNECTION');
        await _settle();
        expect(h.ds.calls, hasLength(1));
        expect(h.ids.first, 100);
        expect(h.bloc.state.status, MessageListStatus.loaded);
      },
    );

    test('online unchanged: the server conversation places the boundary '
        '(newest page first, then the jump)', () async {
      final h = await openFromUnread(online: true);
      addTearDown(h.close);
      expect(h.ds.calls, hasLength(1), reason: 'newest page first');
      convCall(h).cached(conv(10)); // a stale cached copy is not used
      convCall(h).server(conv(50));
      await _settle();
      final older = h.ds.calls[h.ds.calls.length - 2];
      expect(older.request.messageId, 51);
      older.server(_range(21, 50));
      h.last.server(_range(51, 80));
      await _settle();
      expect(h.ids.first, 21);
      expect(h.bloc.state.unreadMessageAnchorId, 51);
    });

    test('online unchanged: a conversation error other than not-connected '
        'places no boundary, even with a cached copy', () async {
      final h = await openFromUnread(online: true);
      addTearDown(h.close);
      convCall(h).cached(conv(50));
      convCall(h).error('ERR_SOMETHING');
      await _settle();
      expect(h.ds.calls, hasLength(1));
      expect(h.bloc.state.unreadMessageAnchorId, isNull);
    });

    test('open at a message id offline: a cached target is shown', () async {
      final h = _Harness(dataSource: _ConvDataSource());
      addTearDown(h.close);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      expect(h.ds.calls, hasLength(2));
      h.ds.calls[0].cached(_range(41, 50));
      h.ds.calls[0].error('ERR_CONNECTION');
      h.ds.calls[1].cached(_range(51, 52));
      h.ds.calls[1].error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, _range(41, 52).map((m) => m.id).toList());
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.hasMoreNewer, isTrue);
    });

    test('open at a message id offline, target not cached: the newest cached '
        'page instead, with no error', () async {
      final h = _Harness(dataSource: _ConvDataSource());
      addTearDown(h.close);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      h.ds.calls[0].error('ERR_CONNECTION');
      h.ds.calls[1].cached(const []);
      h.ds.calls[1].error('ERR_CONNECTION');
      await _settle();
      expect(h.ds.calls, hasLength(3));
      expect(h.last.previous, isTrue);
      expect(h.last.request.messageId, isNull, reason: 'the newest page');
      h.last.cached(_range(100, 129));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids.first, 100);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.errorMessage, isNull);
    });

    test('open at a message id online, target missing: unchanged, no newest '
        'read', () async {
      final h = _Harness(dataSource: _ConvDataSource());
      addTearDown(h.close);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      h.ds.calls[0].server(const []);
      h.ds.calls[1].server(const []);
      await _settle();
      expect(h.ds.calls, hasLength(2));
      expect(h.ids, isEmpty);
    });

    test(
      'OFF unchanged: today\'s repository read, no two-phase call',
      () async {
        CometChat.debugSetOfflineEnabledOverride(false);
        final h = _Harness(dataSource: _ConvDataSource());
        addTearDown(h.close);
        h.bloc.add(
          const LoadFromUnread(
            conversationWith: 'bob',
            conversationType: 'user',
          ),
        );
        await _settle();
        await _settle();
        expect(h.ds.calls, isEmpty);
        expect((h.ds as _ConvDataSource).convCalls, isEmpty);
        expect(
          h.ds.singlePhaseLoads,
          1,
          reason: 'no conversation: LoadMessages',
        );
      },
    );
  });

  group('D58: reconnect reads an empty list once', () {
    final sync = MessageListOfflineSync.instance;

    Future<void> connect(_Harness h) async {
      expect(sync.handleConnected(messageListSeamHostOf(h.bloc)!), isTrue);
      await _settle();
    }

    /// Opens offline with nothing cached.
    Future<_Harness> openEmpty() async {
      final h = _Harness();
      await h.load();
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, isEmpty);
      return h;
    }

    test('an empty list reads the newest page once; the sweep\'s PARTIAL '
        'outcome does not read it again', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      await connect(h);
      expect(h.ds.calls, hasLength(2));
      expect(h.last.previous, isTrue);
      expect(h.last.request.messageId, isNull);
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);

      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _settle();
      expect(h.ds.calls, hasLength(2), reason: 'no double fetch');

      // The next reconnect, with rows: zero fetches; its PARTIAL refreshes
      // as before.
      await connect(h);
      expect(h.ds.calls, hasLength(2));
      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _settle();
      expect(h.ds.calls, hasLength(3));
    });

    test('the reconnect read\'s server page bumps serverReads; the offline '
        'open does not (conversation starters wait on it)', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      expect(h.view.connectToLoadMore.value, isTrue);
      expect(h.view.serverReads.value, 0);
      await connect(h);
      h.last.server(const []);
      await _settle();
      expect(h.view.serverReads.value, 1);
      expect(h.view.connectToLoadMore.value, isFalse);
      expect(h.bloc.state.status, MessageListStatus.empty);
    });

    test('a list with rows makes zero fetches on reconnect', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(1, 3);
      await connect(h);
      expect(h.ds.calls, hasLength(1));
    });

    test(
      'never two reads at once: a reconnect during a newest-window '
      'refresh reads nothing; a second reconnect during the read neither',
      () async {
        final h = await openEmpty();
        addTearDown(h.close);
        hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
        await _settle();
        expect(h.ds.calls, hasLength(2), reason: 'the PARTIAL refresh');
        await connect(h);
        expect(h.ds.calls, hasLength(2));
        h.last.server(_range(1, 3));
        await _settle();
        expect(h.ids, [1, 2, 3]);

        final g = await openEmpty();
        addTearDown(g.close);
        await connect(g);
        await connect(g);
        expect(g.ds.calls, hasLength(2));
        hub.debugMessageSyncCompleted(const [], SyncOutcome.caughtUp);
        await _settle();
        expect(g.ds.calls, hasLength(2));
      },
    );

    test('a connect during an in-flight first read reads nothing; the first '
        'read applies', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      await connect(h);
      expect(h.ds.calls, hasLength(1), reason: 'the first read only');
      h.last.cached(const []);
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);
    });

    test('a connect during an in-flight unread open reads nothing; the open '
        'goes on to the unread boundary', () async {
      final ds = _ConvDataSource();
      final h = _Harness(dataSource: ds);
      addTearDown(h.close);
      h.bloc.add(
        const LoadFromUnread(conversationWith: 'bob', conversationType: 'user'),
      );
      await _settle();
      await connect(h);
      expect(h.ds.calls, hasLength(1));
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(ds.convCalls, hasLength(1), reason: 'the open was not dropped');
    });

    test('a connect during an in-flight jump reads nothing; the target still '
        'shows', () async {
      final h = _Harness(dataSource: _ConvDataSource());
      addTearDown(h.close);
      h.bloc.add(const JumpToMessage(messageId: 50));
      await _settle();
      expect(h.ds.calls, hasLength(2));
      await connect(h);
      expect(h.ds.calls, hasLength(2));
      h.ds.calls[0].server(_range(41, 50));
      h.ds.calls[1].server(_range(51, 52));
      await _settle();
      expect(h.ids, _range(41, 52).map((m) => m.id).toList());
    });

    test('a list emptied by a server answer, not by a lost connection, reads '
        'nothing on connect', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.server(const []);
      await _settle();
      expect(h.ids, isEmpty);
      await connect(h);
      expect(h.ds.calls, hasLength(1));
    });

    test('a resume clears a reconnect mark no sync outcome took: a later '
        'PARTIAL refreshes', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      await connect(h);
      expect(h.ds.calls, hasLength(2));
      h.last.server(_range(1, 3));
      await _settle();
      expect(sync.handleResume(messageListSeamHostOf(h.bloc)!), isTrue);
      await _settle();
      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _settle();
      expect(h.ds.calls, hasLength(3), reason: 'not swallowed');
    });

    test('a resume during the reconnect read keeps its mark: the PARTIAL '
        'does not read again', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      await connect(h);
      expect(sync.handleResume(messageListSeamHostOf(h.bloc)!), isTrue);
      await _settle();
      h.last.server(_range(1, 3));
      await _settle();
      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _settle();
      expect(h.ds.calls, hasLength(2));
    });

    test('a cache reset clears a reconnect mark: a later PARTIAL '
        'refreshes', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      await connect(h);
      h.last.server(_range(1, 3));
      await _settle();
      hub.debugCacheReset(OfflineCacheResetReason.corrupted, null);
      await _settle();
      expect(h.ds.calls, hasLength(3), reason: 'the reload');
      h.last.server(_range(1, 3));
      await _settle();
      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _settle();
      expect(h.ds.calls, hasLength(4), reason: 'not swallowed');
    });

    test('OFF unchanged: today\'s reconnect sync, no two-phase call', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final h = _Harness();
      addTearDown(h.close);
      h.bloc.add(const SyncMessages());
      await _settle();
      expect(h.ds.calls, isEmpty);
      expect(h.ds.singlePhaseLoads, 1, reason: 'not loaded: today\'s load');
    });
  });

  test('the thread list reads the same way, scoped to its parent', () async {
    final h = _Harness(parentMessageId: 7);
    addTearDown(h.close);
    await h.load();
    expect(h.last.request.parentMessageId, 7);
    h.last.cached([_m(8), _m(9), _m(10)]);
    await _settle();
    expect(h.ids, [8, 9, 10]);
    h.last.server([_m(8), _m(10), _m(11)]);
    await _settle();
    expect(h.ids, [8, 10, 11], reason: '9 was a proven omission');
  });

  test('OFF path: today\'s single fetch, no two-phase call', () async {
    final h = _Harness();
    addTearDown(h.close);
    // Offline OFF: today's single fetch, no two-phase call.
    CometChat.debugSetOfflineEnabledOverride(false);
    await h.load();
    await _settle();
    expect(h.ds.calls, isEmpty);
    expect(h.ds.singlePhaseLoads, 1);
    expect(h.ids, [1, 2, 3]);
    expect(h.bloc.state.hasMoreOlder, isFalse, reason: 'today: length >= 30');
  });

  group('ENG-41458: review fixes', () {
    final sync = MessageListOfflineSync.instance;

    Future<void> connect(_Harness h) async {
      expect(sync.handleConnected(messageListSeamHostOf(h.bloc)!), isTrue);
      await _settle();
    }

    /// Opens offline with nothing cached.
    Future<_Harness> openEmpty() async {
      final h = _Harness();
      await h.load();
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      return h;
    }

    /// Loads 5..7, then scrolls back offline past the cache.
    Future<_Harness> atCacheEdge() async {
      final h = _Harness();
      await h.loaded(5, 7);
      h.bloc.add(const LoadOlderMessages());
      await _settle();
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      return h;
    }

    /// What the list's scroll-to-top trigger does.
    Future<void> scrollToTop(_Harness h) async {
      if (!skipOlderReadOnScroll(h.bloc)) {
        h.bloc.add(const LoadOlderMessages());
      }
      await _settle();
    }

    test('an open with a non-overlapping server page shows no gap and keeps '
        'unsent rows', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached([..._range(100, 104), _own()]);
      await _settle();
      expect(h.ids, [100, 101, 102, 103, 104, 0]);
      h.last.server(_range(350, 354));
      await _settle();
      expect(h.ids, [350, 351, 352, 353, 354, 0]);
      expect(h.bloc.state.hasMoreOlder, isTrue);
      expect(h.bloc.state.hasMoreNewer, isFalse);
      // Older pages now load from the newest page's edge: no gap.
      h.bloc.add(const LoadOlderMessages());
      await _settle();
      expect(h.last.request.messageId, 350);
    });

    test(
      'an open whose server page overlaps the cached rows merges them',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.load();
        h.last.cached(_range(100, 104));
        h.last.server(_range(103, 107));
        await _settle();
        expect(h.ids, [100, 101, 102, 103, 104, 105, 106, 107]);
      },
    );

    test('D84 (3), (8): offline open with nothing cached shows the offline '
        'state, and the reconnect read replaces it', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      expect(h.bloc.state.status, MessageListStatus.error);
      expect(h.bloc.state.errorMessage, isNotNull);
      expect(h.view.showsOfflineState, isTrue);
      expect(h.view.connectToLoadMore.value, isTrue);

      await connect(h);
      expect(h.ds.calls, hasLength(2));
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.errorMessage, isNull);
    });

    test('D84 (8): two reconnects over the offline state read once', () async {
      final h = await openEmpty();
      addTearDown(h.close);
      await connect(h);
      await connect(h);
      expect(h.ds.calls, hasLength(2), reason: 'no double read');
      h.last.server(const []);
      await _settle();
      // The server's empty page: the empty view.
      expect(h.bloc.state.status, MessageListStatus.empty);
      await connect(h);
      expect(h.ds.calls, hasLength(2));
    });

    test('D84 (3), (8): a thread opened offline with nothing cached shows the '
        'offline state and reads once on reconnect', () async {
      final h = _Harness(parentMessageId: 7);
      addTearDown(h.close);
      await h.load();
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.error);
      expect(h.view.showsOfflineState, isTrue);
      await connect(h);
      expect(h.ds.calls, hasLength(2));
      h.last.server(_range(1, 2));
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.loaded);
    });

    test('D84 (2): cached rows and a not-connected error keep the rows and '
        'the footer, and do not reach onError', () async {
      final h = _Harness();
      addTearDown(h.close);
      final errors = <CometChatException>[];
      OfflineListErrors.listen(h.bloc, errors.add);
      await h.load();
      h.last.cached(_range(1, 3));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.view.connectToLoadMore.value, isTrue);
      expect(errors, isEmpty);
    });

    test('D84 (5): cached rows and a real server error on an open keep the '
        'rows and reach onError once', () async {
      final h = _Harness();
      addTearDown(h.close);
      final errors = <CometChatException>[];
      OfflineListErrors.listen(h.bloc, errors.add);
      await h.load();
      h.last.cached(_range(1, 3));
      h.last.error('ERR_TOO_MANY_REQUESTS');
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
    });

    test(
      'D84 (4), (8): a server error that is not the network, nothing '
      'shown, is the error view and is not read again on reconnect',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.load();
        h.last.cached(const []);
        h.last.error('ERR_TOO_MANY_REQUESTS');
        await _settle();
        expect(h.bloc.state.status, MessageListStatus.error);
        expect(h.view.showsOfflineState, isFalse);
        await connect(h);
        expect(h.ds.calls, hasLength(1));
      },
    );

    test('a connect during an open that then ends not connected reads the '
        'newest page once the open ends', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      await connect(h);
      expect(h.ds.calls, hasLength(1), reason: 'never two reads at once');
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ds.calls, hasLength(2), reason: 'the connect, looked at again');
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.ids, [1, 2, 3]);
      expect(h.bloc.state.status, MessageListStatus.loaded);
    });

    test('an open with nothing shown that fails for another reason keeps '
        'today\'s error state; rows shown later clear the error', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.error('ERR_HTTP_500');
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.error);
      expect(h.bloc.state.errorMessage, isNotNull);
      expect(h.view.connectToLoadMore.value, isFalse);

      await h.load(); // today's Retry
      h.last.server(_range(1, 3));
      await _settle();
      expect(h.bloc.state.status, MessageListStatus.loaded);
      expect(h.bloc.state.errorMessage, isNull);
    });

    test('scrolling to the top while offline at the footer makes zero reads; '
        'the footer\'s tap still retries', () async {
      final h = await atCacheEdge();
      addTearDown(h.close);
      expect(h.view.connectToLoadMore.value, isTrue);
      final calls = h.ds.calls.length;
      for (var i = 0; i < 3; i++) {
        await scrollToTop(h);
      }
      expect(h.ds.calls, hasLength(calls), reason: 'no read per scroll');
      expect(h.view.connectToLoadMore.value, isTrue, reason: 'no flicker');

      expect(h.view.retry(), isTrue); // the footer's tap
      await _settle();
      expect(h.ds.calls, hasLength(calls + 1));
      expect(h.last.request.messageId, 5);
    });

    test('an older read that still added cached rows does not block the next '
        'scroll', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.loaded(5, 7);
      h.bloc.add(const LoadOlderMessages());
      await _settle();
      h.last.cached(_range(2, 4));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.ids, [2, 3, 4, 5, 6, 7]);
      expect(h.view.connectToLoadMore.value, isTrue);
      final calls = h.ds.calls.length;
      await scrollToTop(h);
      expect(h.ds.calls, hasLength(calls + 1), reason: 'more may be cached');
      expect(h.last.request.messageId, 2);
    });

    test('D-350, D84 (9): on reconnect a list with rows takes the footer '
        'down and reads the older page behind it once', () async {
      final h = await atCacheEdge();
      addTearDown(h.close);
      final calls = h.ds.calls.length;
      await connect(h);
      expect(h.view.connectToLoadMore.value, isFalse);
      expect(h.ds.calls, hasLength(calls + 1), reason: 'one page on connect');
      expect(h.last.previous, isTrue, reason: 'the older page');
      expect(h.last.request.messageId, 5, reason: 'behind the oldest row');
      h.last.cached(const []);
      h.last.server(_range(2, 4));
      await _settle();
      expect(h.ids, [2, 3, 4, 5, 6, 7]);

      await connect(h);
      expect(h.ds.calls, hasLength(calls + 1), reason: 'at most once');
    });

    test('D-350: a reconnect while the older page is offline again loads it '
        'once more, never twice per reconnect', () async {
      final h = await atCacheEdge();
      addTearDown(h.close);
      final calls = h.ds.calls.length;
      await connect(h);
      await connect(h);
      expect(h.ds.calls, hasLength(calls + 1));
      h.last.cached(const []);
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.view.connectToLoadMore.value, isTrue);
      await connect(h);
      expect(h.ds.calls, hasLength(calls + 2));
      expect(h.last.request.messageId, 5);
    });

    test('D-350: a footer raised by an open (not a page) reads no page on '
        'reconnect', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      h.last.cached(_range(5, 7));
      h.last.error('ERR_CONNECTION');
      await _settle();
      expect(h.view.connectToLoadMore.value, isTrue);
      final calls = h.ds.calls.length;
      await connect(h);
      expect(h.view.connectToLoadMore.value, isFalse);
      expect(h.ds.calls, hasLength(calls));
    });

    test('D-351: two own rows with one muid show as one row, at the first '
        'one\'s place', () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.load();
      final first = _own(id: 5);
      final again = _own(id: 9)..readAt = DateTime(2026, 11, 18);
      // Own rows sort last here (a later sentAt): [1, 7, 5, 9] before.
      h.last.cached([_m(1), _m(7), first, again]);
      await _settle();
      expect(h.ids, [1, 7, 5]);
      expect(h.bloc.state.messages[2].readAt, DateTime(2026, 11, 18));
      h.last.server([_m(1), _m(7), _own(id: 5), _own(id: 9)]);
      await _settle();
      expect(h.ids, [1, 7, 5]);
    });

    test('offline off: the scroll trigger never skips', () async {
      final h = await atCacheEdge();
      addTearDown(h.close);
      CometChat.debugSetOfflineEnabledOverride(false);
      expect(skipOlderReadOnScroll(h.bloc), isFalse);
    });

    test('a later copy without receipts keeps deliveredAt/readAt', () async {
      final h = _Harness();
      addTearDown(h.close);
      final delivered = DateTime.fromMillisecondsSinceEpoch(1700000500000);
      final read = DateTime.fromMillisecondsSinceEpoch(1700000600000);
      await h.load();
      h.last.cached([
        _m(1),
        _own(id: 9)
          ..deliveredAt = delivered
          ..readAt = read,
      ]);
      await _settle();
      // The server's copy is later (an edit) but carries no receipts.
      final later = _own(id: 9)
        ..updatedAt = DateTime.fromMillisecondsSinceEpoch(1700009000000);
      h.last.server([_m(1), later]);
      await _settle();
      final shown = h.bloc.state.messages.firstWhere((m) => m.id == 9);
      expect(shown.updatedAt, later.updatedAt, reason: 'the later copy wins');
      expect(shown.deliveredAt, delivered);
      expect(shown.readAt, read);
    });

    test(
      'keepLaterReceipts takes the later non-null receipt of either copy',
      () {
        final t1 = DateTime.fromMillisecondsSinceEpoch(1000);
        final t2 = DateTime.fromMillisecondsSinceEpoch(2000);
        final kept = _m(1)
          ..deliveredAt = t2
          ..readAt = null;
        final dropped = _m(1)
          ..deliveredAt = t1
          ..readAt = t1;
        final out = keepLaterReceipts(kept, dropped);
        expect(out, same(kept));
        expect(out.deliveredAt, t2);
        expect(out.readAt, t1);
      },
    );
  });

  group('helpers', () {
    test('not-connected codes', () {
      for (final code in [
        'ERR_CONNECTION',
        'ERR_NETWORK_TIMEOUT',
        'ERROR_INTERNET_UNAVAILABLE',
      ]) {
        expect(
          isNotConnectedError(CometChatException(code, null, null)),
          isTrue,
        );
      }
      expect(
        isNotConnectedError(CometChatException('ERR_HTTP_500', null, null)),
        isFalse,
      );
    });

    test('order: sent rows by (sentAt, id), un-acked last', () {
      final rows = [_own(), _m(3), _m(1), _m(2)]..sort(compareMessageRows);
      expect(rows.map((m) => m.id), [1, 2, 3, 0]);
    });
  });
}
