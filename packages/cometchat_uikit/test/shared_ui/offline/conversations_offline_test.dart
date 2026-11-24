// W3 (ENG-41093): the conversation list on the offline ON path — two-phase
// reads, the sync-slice reconcile, the pending/failed preview, swept
// self-removal, swept messages and the conversation pin (PR #23 §3.7).
import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/datasources/conversations_local_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/datasources/conversations_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/repositories/conversations_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/conversations_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/conversations_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_send_state.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A kit datasource that reads two-phase. Each call takes the next script;
/// a script may be a [StreamController] the test drives.
class _Remote extends Fake
    implements ConversationsRemoteDataSource, ConversationsTwoPhaseDataSource {
  final List<Object> scripts = [];
  final List<ConversationsRequest> requests = [];
  int singlePhaseCalls = 0;

  /// What each single-phase (offline off) read returns.
  List<Conversation> singlePhaseRows = const [];

  int get twoPhaseCalls => requests.length;

  @override
  Stream<TwoPhaseResult<Conversation>> fetchNextTwoPhase(
    ConversationsRequest request,
  ) {
    requests.add(request);
    final script = scripts.isEmpty ? null : scripts.removeAt(0);
    if (script is StreamController<TwoPhaseResult<Conversation>>) {
      return script.stream;
    }
    final phases =
        (script as List<TwoPhaseResult<Conversation>>?) ??
        const [Server<Conversation>([])];
    return Stream.fromIterable(phases);
  }

  @override
  Future<List<Conversation>> getConversations({
    int limit = 30,
    String? fromId,
    ConversationsRequestBuilder? requestBuilder,
  }) async {
    singlePhaseCalls++;
    return singlePhaseRows;
  }
}

class _Local extends Fake implements ConversationsLocalDataSource {
  @override
  Future<void> cacheConversations(List<Conversation> conversations) async {}
}

class _Repo extends Fake implements ConversationsRepository {
  @override
  Future<Result<User?>> getLoggedInUser() async => Success(_alice);

  @override
  Future<Result<void>> markAsDelivered(BaseMessage message) async =>
      const Success(null);

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async => const Failure(message: 'not needed');
}

/// The list's context as seen by a handler created before the list
/// generation moved on: its reconcile is dropped unapplied.
class _StaleCtx implements ConversationsSeamContext {
  _StaleCtx(this._ctx);
  final ConversationsSeamContext _ctx;

  @override
  int get opGen => _ctx.listGen - 1;
  @override
  int get listGen => _ctx.listGen;
  @override
  bool get isStale => true;
  @override
  Object get owner => _ctx.owner;
  @override
  ConversationsState get state => _ctx.state;
  @override
  void emit(ConversationsState state) => _ctx.emit(state);
  @override
  void replaceRows(List<Conversation> rows) => _ctx.replaceRows(rows);
  @override
  List<Conversation> get rows => _ctx.rows;
  @override
  void add(ConversationsEvent event) => _ctx.add(event);
  @override
  void postNotice(OfflineNotice notice) => _ctx.postNotice(notice);
  @override
  bool get isClosed => _ctx.isClosed;
  @override
  User? get loggedInUser => _ctx.loggedInUser;
  @override
  Map<String, int> get conversationIndexMap => _ctx.conversationIndexMap;
  @override
  ConversationsRequest? get conversationsRequest => _ctx.conversationsRequest;
  @override
  set conversationsRequest(ConversationsRequest? request) =>
      _ctx.conversationsRequest = request;
  @override
  ConversationsRequestBuilder? get requestBuilder => _ctx.requestBuilder;
  @override
  int get pageSize => _ctx.pageSize;
  @override
  ConversationsRemoteDataSource? get remoteDataSource => _ctx.remoteDataSource;
}

final _alice = User(uid: 'alice', name: 'Alice');
const _t0 = 1700000000000;

TextMessage _msg({
  int id = 1,
  String from = 'bob',
  String to = 'alice',
  int at = 0,
  String? lid,
  String? sendState,
  String? source,
  String receiverType = 'user',
  String? conversationId,
}) {
  final m = TextMessage(
    id: id,
    text: 'hi',
    sender: User(uid: from, name: from),
    receiverUid: to,
    type: 'text',
    receiverType: receiverType,
    sentAt: DateTime.fromMillisecondsSinceEpoch(_t0 + at),
    muid: 'muid-$id-$at',
  );
  m.localMessageId = lid;
  m.sendState = sendState;
  m.source = source;
  m.conversationId = conversationId;
  m.receiver = receiverType == 'user'
      ? User(uid: to, name: to)
      : Group(guid: to, name: to, type: 'public');
  return m;
}

Conversation _conv(
  String peer, {
  int at = 0,
  BaseMessage? last,
  int unread = 0,
  String type = 'user',
  DateTime? pinnedAt,
  String? pinnedBy,
}) => Conversation(
  conversationId: type == 'user' ? 'alice_user_$peer' : 'group_$peer',
  conversationType: type,
  conversationWith: type == 'user'
      ? User(uid: peer, name: peer)
      : Group(guid: peer, name: peer, type: 'public'),
  lastMessage: last,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(_t0 + at),
  unreadMessageCount: unread,
  pinnedAt: pinnedAt,
  pinnedBy: pinnedBy,
);

ConversationsBloc _bloc(
  _Remote remote, {
  ConversationsRequestBuilder? builder,
  bool sdkListeners = false,
}) {
  final impl = ConversationsRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: _Local(),
  );
  final repo = _Repo();
  return ConversationsBloc(
    getConversationsUseCase: GetConversationsUseCase(impl),
    loadMoreConversationsUseCase: LoadMoreConversationsUseCase(impl),
    deleteConversationUseCase: DeleteConversationUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    getConversationUseCase: GetConversationUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    disableSDKListeners: !sdkListeners,
    conversationsRequestBuilder: builder,
  );
}

List<String?> _ids(ConversationsBloc bloc) {
  final s = bloc.state;
  return s is ConversationsLoaded
      ? s.conversations.map((c) => c.conversationId).toList()
      : const [];
}

Conversation _row(ConversationsBloc bloc, String id) =>
    (bloc.state as ConversationsLoaded).conversations.firstWhere(
      (c) => c.conversationId == id,
    );

/// Delivers [event] to the bloc's seam collector on its event loop, as the
/// hub subscription does.
Future<void> _hub(ConversationsBloc bloc, OfflineHubEvent event) async {
  conversationsSeamHostOf(
    bloc,
  )!.run((ctx) => ConversationsOffline.instance.onHubEvent(ctx, event));
  await pumpEventQueue();
}

Future<ConversationsBloc> _loaded(
  _Remote remote,
  List<Conversation> rows, {
  ConversationsRequestBuilder? builder,
  bool sdkListeners = false,
}) async {
  remote.scripts.add(<TwoPhaseResult<Conversation>>[Server(rows)]);
  final bloc = _bloc(remote, builder: builder, sdkListeners: sdkListeners);
  bloc.add(const LoadConversations());
  await pumpEventQueue();
  return bloc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hub = OfflineHub.instance;

  setUp(() {
    hub.debugReset();
    ConversationsOffline.instance.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('alice');
    CometChatUIKit.loggedInUser = _alice;
  });

  tearDown(() {
    CometChat.debugSetOfflineEnabledOverride(null);
    CometChatUIKit.loggedInUser = null;
  });

  group('two-phase read', () {
    test('cached rows paint first, then the server page reconciles', () async {
      final remote = _Remote();
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(phases);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsLoading>());

      phases.add(Cached([_conv('bob', at: 20), _conv('carol', at: 10)]));
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);

      // The server no longer has carol (inside its range) and adds dave.
      phases.add(Server([_conv('dave', at: 30), _conv('bob', at: 5)]));
      await phases.close();
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_dave', 'alice_user_bob']);
      expect((bloc.state as ConversationsLoaded).hasMore, isTrue);
      expect(remote.singlePhaseCalls, 0);
      await bloc.close();
    });

    test('an offline error keeps the cached rows', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Cached([_conv('bob', at: 20)]),
        PhaseError(CometChatException('ERROR_INTERNET_UNAVAILABLE', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob']);
      await bloc.close();
    });

    test('offline off keeps today\'s single fetch', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final remote = _Remote();
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(remote.singlePhaseCalls, 1);
      expect(remote.twoPhaseCalls, 0);
      await bloc.close();
    });

    test(
      'a read in flight across a session end is dropped (stale gen)',
      () async {
        final remote = _Remote();
        final phases = StreamController<TwoPhaseResult<Conversation>>();
        remote.scripts.add(phases);
        final bloc = _bloc(remote);
        bloc.add(const LoadConversations());
        await pumpEventQueue();

        hub.debugLogout(); // SessionEnded: the list generation moves on
        await pumpEventQueue();
        phases.add(Server([_conv('bob', at: 20)]));
        await phases.close();
        await pumpEventQueue();
        expect(bloc.state, isA<ConversationsEmpty>());
        expect(bloc.items, isEmpty);
        await bloc.close();
      },
    );

    test(
      'load-more past the cache while offline does not re-request',
      () async {
        final remote = _Remote();
        final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
        remote.scripts.add(<TwoPhaseResult<Conversation>>[
          PhaseError(
            CometChatException('ERROR_INTERNET_UNAVAILABLE', 'x', 'x'),
          ),
        ]);
        bloc.add(const LoadMoreConversations());
        await pumpEventQueue();
        bloc.add(const LoadMoreConversations());
        await pumpEventQueue();
        expect(remote.twoPhaseCalls, 2); // the load + one load-more
        expect(_ids(bloc), ['alice_user_bob']);
        expect((bloc.state as ConversationsLoaded).hasMore, isTrue);
        await bloc.close();
      },
    );
  });

  group('reconnect', () {
    test('offline on: the reconnect hook suppresses the kit fetch', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
      expect(
        ConversationsOffline.instance.handleReconnect(
          conversationsSeamHostOf(bloc)!,
        ),
        isTrue,
      );
      await _hub(bloc, ConversationSyncCompleted(hub.gen, [_conv('bob')]));
      expect(remote.twoPhaseCalls, 1); // the first load only
      expect(remote.singlePhaseCalls, 0);
      await bloc.close();
    });

    test(
      'a refresh asks the SDK to sync; offline not running → reload',
      () async {
        final remote = _Remote();
        final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
        bloc.add(const RefreshConversations());
        await pumpEventQueue();
        // No SDK offline runtime in a unit test: forceSyncNow answers
        // ERROR_OFFLINE_DISABLED and the list falls back to one two-phase read.
        expect(remote.twoPhaseCalls, 2);
        expect(remote.singlePhaseCalls, 0);
        await bloc.close();
      },
    );
  });

  group('sync slice', () {
    test('replaces the slice, keeps rows below and the cursor', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [
        _conv('a', at: 50),
        _conv('b', at: 40),
        _conv('c', at: 30),
        _conv('d', at: 10),
      ]);
      final cursor = remote.requests.single;
      // The page covers a..c (newest to 30) and no longer has b.
      await _hub(
        bloc,
        ConversationSyncCompleted(hub.gen, [
          _conv('a', at: 50, unread: 2),
          _conv('c', at: 30),
        ]),
      );
      expect(_ids(bloc), ['alice_user_a', 'alice_user_c', 'alice_user_d']);
      expect(_row(bloc, 'alice_user_a').unreadMessageCount, 2);
      final s = bloc.state as ConversationsLoaded;
      expect(s.hasMore, isTrue);
      // Load-more still pages the same request.
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(remote.requests.last, same(cursor));
      await bloc.close();
    });

    test(
      'never removes a row whose preview is an own unsent message',
      () async {
        final remote = _Remote();
        final unsent = _msg(
          id: 0,
          from: 'alice',
          to: 'b',
          at: 40,
          lid: 'L1',
          sendState: 'PENDING',
        );
        final bloc = await _loaded(remote, [
          _conv('a', at: 50),
          _conv('b', at: 40, last: unsent),
          _conv('c', at: 30),
        ]);
        await _hub(
          bloc,
          ConversationSyncCompleted(hub.gen, [_conv('a', at: 50), _conv('c')]),
        );
        expect(_ids(bloc), contains('alice_user_b'));
        await bloc.close();
      },
    );

    test('a filtered list re-runs its own request once', () async {
      final remote = _Remote();
      final builder = ConversationsRequestBuilder()..conversationType = 'user';
      final bloc = await _loaded(remote, [
        _conv('a', at: 50),
      ], builder: builder);
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Cached([_conv('a', at: 50)]),
        Server([_conv('a', at: 50), _conv('z', at: 60)]),
      ]);
      await _hub(bloc, ConversationSyncCompleted(hub.gen, [_conv('q')]));
      expect(remote.twoPhaseCalls, 2);
      expect(_ids(bloc), ['alice_user_z', 'alice_user_a']);
      await bloc.close();
    });

    test('a sync failure changes nothing', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('a', at: 50)]);
      await _hub(
        bloc,
        ConversationSyncFailed(hub.gen, CometChatException('E', 'x', 'x')),
      );
      expect(_ids(bloc), ['alice_user_a']);
      expect(remote.twoPhaseCalls, 1);
      await bloc.close();
    });
  });

  group('swept self-removal', () {
    Action action(String verb, {String on = 'alice'}) {
      final a = Action(
        id: 9,
        muid: 'a9',
        sender: User(uid: 'admin', name: 'admin'),
        receiverUid: 'g1',
        type: 'groupMember',
        receiverType: 'group',
        category: 'action',
        action: verb,
      );
      a.actionOn = User(uid: on, name: on);
      a.actionFor = Group(guid: 'g1', name: 'g1', type: 'public');
      return a;
    }

    for (final verb in ['kicked', 'banned', 'left']) {
      test(
        'a swept "$verb" of the logged-in user drops the group row',
        () async {
          final remote = _Remote();
          final bloc = await _loaded(remote, [
            _conv('g1', at: 50, type: 'group'),
            _conv('bob', at: 40),
          ]);
          await _hub(
            bloc,
            MessageSyncCompleted(hub.gen, [action(verb)], SyncOutcome.caughtUp),
          );
          expect(_ids(bloc), ['alice_user_bob']);
          await bloc.close();
        },
      );
    }

    test('another member\'s kick keeps the row', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('g1', at: 50, type: 'group')]);
      await _hub(
        bloc,
        MessageSyncCompleted(hub.gen, [
          action('kicked', on: 'bob'),
        ], SyncOutcome.caughtUp),
      );
      expect(_ids(bloc), ['group_g1']);
      await bloc.close();
    });
  });

  group('pending/failed preview', () {
    test('a pending send moves its row to the top, marked sending', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [
        _conv('a', at: 50),
        _conv('b', at: 40),
      ]);
      final pending = _msg(
        id: 0,
        from: 'alice',
        to: 'b',
        at: 60,
        lid: 'L1',
        sendState: 'PENDING',
        conversationId: 'alice_user_b',
      );
      await _hub(
        bloc,
        SendStateEvent(
          hub.gen,
          'L1',
          pending,
          CometChatMessageSendState.sending,
          null,
        ),
      );
      expect(_ids(bloc), ['alice_user_b', 'alice_user_a']);
      final row = _row(bloc, 'alice_user_b');
      expect(
        ConversationsOffline.previewSendState(row),
        CometChatMessageSendState.sending,
      );
      expect(
        ConversationsOffline.conversationRowId(row, 0),
        contains('previewState=sending'),
      );
      await bloc.close();
    });

    test('a failed send shows failed; a new chat is created', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('a', at: 50)]);
      final failed = _msg(
        id: 0,
        from: 'alice',
        to: 'new',
        at: 60,
        lid: 'L2',
        sendState: 'FAILED',
        conversationId: 'alice_user_new',
      );
      await _hub(
        bloc,
        SendStateEvent(
          hub.gen,
          'L2',
          failed,
          CometChatMessageSendState.failed,
          MessageFailureReason.transient,
        ),
      );
      expect(_ids(bloc).first, 'alice_user_new');
      expect(
        ConversationsOffline.previewSendState(_row(bloc, 'alice_user_new')),
        CometChatMessageSendState.failed,
      );
      await bloc.close();
    });

    test(
      'after a discard the SDK row replaces the preview on the next sync',
      () async {
        final remote = _Remote();
        final unsent = _msg(
          id: 0,
          from: 'alice',
          to: 'b',
          at: 60,
          lid: 'L3',
          sendState: 'FAILED',
        );
        final bloc = await _loaded(remote, [
          _conv('b', at: 60, last: unsent),
          _conv('a', at: 50),
        ]);
        await _hub(
          bloc,
          SendStateEvent(
            hub.gen,
            'L3',
            unsent,
            CometChatMessageSendState.failed,
            MessageFailureReason.discarded,
          ),
        );
        final older = _msg(id: 7, from: 'b', to: 'alice', at: 10);
        await _hub(
          bloc,
          ConversationSyncCompleted(hub.gen, [
            _conv('a', at: 50),
            _conv('b', at: 10, last: older),
          ]),
        );
        expect(_row(bloc, 'alice_user_b').lastMessage?.id, 7);
        expect(_ids(bloc), ['alice_user_a', 'alice_user_b']);
        await bloc.close();
      },
    );
  });

  group('swept messages', () {
    test('a SYNC message adds no unread and plays no sound', () async {
      const channel = MethodChannel('cometchat_chat_uikit');
      final played = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            played.add(call.method);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final remote = _Remote();
      final bloc = await _loaded(remote, [
        _conv('a', at: 50, unread: 3),
        _conv('bob', at: 40, unread: 1),
      ], sdkListeners: true);
      await pumpEventQueue();

      final swept = _msg(
        id: 11,
        from: 'bob',
        at: 45,
        source: 'SYNC',
        conversationId: 'alice_user_bob',
      );
      CometChat.debugOnRealtimeMessage(swept);
      await pumpEventQueue();
      expect(_row(bloc, 'alice_user_bob').unreadMessageCount, 1);
      expect(_row(bloc, 'alice_user_bob').lastMessage?.id, 11);
      // Placed by time: still below a (50).
      expect(_ids(bloc), ['alice_user_a', 'alice_user_bob']);
      expect(played, isEmpty);

      final live = _msg(
        id: 12,
        from: 'bob',
        at: 70,
        conversationId: 'alice_user_bob',
      );
      CometChat.debugOnRealtimeMessage(live);
      await pumpEventQueue();
      expect(_row(bloc, 'alice_user_bob').unreadMessageCount, 2);
      expect(played, isNotEmpty); // a live message still sounds
      await bloc.close();
    });
  });

  group('conversation pin', () {
    test('offline off: the own pin from onSuccess lands where today\'s pin '
        'handler puts it (top of its tier; an unpin back in its activity '
        'slot)', () async {
      final remote = _Remote();
      final system = _conv(
        'sys',
        at: 10,
        pinnedAt: DateTime.fromMillisecondsSinceEpoch(_t0 + 5),
        pinnedBy: 'app_system',
      );
      final userPin = _conv(
        'p',
        at: 20,
        pinnedAt: DateTime.fromMillisecondsSinceEpoch(_t0 + 6),
        pinnedBy: 'alice',
      );
      final bloc = await _loaded(remote, [
        system,
        userPin,
        _conv('a', at: 50),
        _conv('bob', at: 40),
        _conv('c', at: 30),
      ]);
      // G11/T4: applyOwnPin runs with offline off too.
      CometChat.debugSetOfflineEnabledOverride(false);

      // Pin: today's handler inserts at the top of the row's own tier (a
      // user pin below the system pins, above the other user pins).
      ConversationsOffline.instance.applyOwnPin(
        bloc,
        _conv(
          'bob',
          at: 40,
          pinnedAt: DateTime.fromMillisecondsSinceEpoch(_t0 + 100),
          pinnedBy: 'alice',
        ),
        pinned: true,
      );
      await pumpEventQueue();
      expect(_ids(bloc), [
        'alice_user_sys',
        'alice_user_bob',
        'alice_user_p',
        'alice_user_a',
        'alice_user_c',
      ]);
      expect(_row(bloc, 'alice_user_bob').pinnedBy, 'alice');

      // Unpin: back to its activity slot among the unpinned rows (first one
      // older than it), as today's handler places it.
      ConversationsOffline.instance.applyOwnPin(
        bloc,
        _conv('bob', at: 40),
        pinned: false,
      );
      await pumpEventQueue();
      expect(_ids(bloc), [
        'alice_user_sys',
        'alice_user_p',
        'alice_user_a',
        'alice_user_bob',
        'alice_user_c',
      ]);
      expect(_row(bloc, 'alice_user_bob').pinnedAt, isNull);
      await bloc.close();
    });

    test(
      'an echo of the own pin is a no-op; matched by (type, with)',
      () async {
        final remote = _Remote();
        final bloc = await _loaded(remote, [
          _conv('a', at: 50),
          _conv('bob', at: 40),
        ]);
        final pinnedAt = DateTime.fromMillisecondsSinceEpoch(_t0 + 100);
        // onSuccess (G11).
        final updated = _conv(
          'bob',
          at: 40,
          pinnedAt: pinnedAt,
          pinnedBy: 'alice',
        );
        ConversationsOffline.instance.applyOwnPin(bloc, updated, pinned: true);
        await pumpEventQueue();
        expect(_ids(bloc), ['alice_user_bob', 'alice_user_a']);
        final before = bloc.state;

        // The listener echo, with a placeholder id and different case.
        final echo = Conversation(
          conversationId: 'placeholder',
          conversationType: 'user',
          conversationWith: User(uid: 'BOB', name: 'bob'),
          pinnedAt: pinnedAt,
          pinnedBy: 'alice',
        );
        conversationsSeamHostOf(bloc)!.run((ctx) {
          expect(
            ConversationsOffline.instance.handlePinUpdate(
              ctx,
              echo,
              pinned: true,
            ),
            isTrue,
          );
        });
        await pumpEventQueue();
        expect(bloc.state, same(before));
        expect(_ids(bloc), ['alice_user_bob', 'alice_user_a']);

        // Own unpin from onSuccess, then its echo.
        final unpinned = _conv('bob', at: 40);
        ConversationsOffline.instance.applyOwnPin(
          bloc,
          unpinned,
          pinned: false,
        );
        await pumpEventQueue();
        // Today's placement: older than every loaded row with more pages out
        // there, so pagination restores it in place.
        expect(_ids(bloc), ['alice_user_a']);
        expect(bloc.items.where((c) => c.pinnedAt != null), isEmpty);
        await bloc.close();
      },
    );
  });

  // D75 (ENG-41466): a page that failed offline past the cache is read once
  // on reconnect, without a scroll, continuing only until a new chat appears.
  group('D75 reconnect read of a marked page', () {
    CometChatException offline() =>
        CometChatException('ERROR_INTERNET_UNAVAILABLE', 'x', 'x');

    /// Reads of [request] so far (the first load uses the same request).
    int readsOf(_Remote remote, ConversationsRequest request) =>
        remote.requests.where((r) => identical(r, request)).length;

    List<TwoPhaseResult<Conversation>> page(List<Conversation> rows) =>
        <TwoPhaseResult<Conversation>>[Server(rows)];

    /// A loaded list [bob] whose load-more then ended as [failure] describes.
    Future<(ConversationsBloc, ConversationsRequest)> failedLoadMore(
      _Remote remote,
      List<TwoPhaseResult<Conversation>> failure,
    ) async {
      final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
      remote.scripts.add(failure);
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      return (bloc, remote.requests.last);
    }

    Future<(ConversationsBloc, ConversationsRequest)> marked(_Remote remote) =>
        failedLoadMore(remote, [PhaseError(offline())]);

    Future<void> sync(ConversationsBloc bloc) =>
        _hub(bloc, ConversationSyncCompleted(hub.gen, [_conv('bob', at: 20)]));

    test('1/2: a load-more that fails not-connected past the cache is read '
        'once on the next sync, without a scroll', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      expect(readsOf(remote, request), 2); // the load + the failed page
      remote.scripts.add(page([_conv('carol', at: 10)]));
      await sync(bloc);
      expect(readsOf(remote, request), 3);
      expect(remote.twoPhaseCalls, 3);
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      expect((bloc.state as ConversationsLoaded).isLoadingMore, isFalse);
      await bloc.close();
    });

    test('1: a failure that is not the network marks nothing; paging resumes '
        'on the sync', () async {
      final remote = _Remote();
      final (bloc, request) = await failedLoadMore(remote, [
        PhaseError(CometChatException('ERR_HTTP_500', 'x', 'x')),
      ]);
      await sync(bloc);
      expect(readsOf(remote, request), 2); // no reconnect read
      remote.scripts.add(page([_conv('carol', at: 10)]));
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 3); // the scroll reads it
      await bloc.close();
    });

    test(
      '1: a page the cache served before the failure marks nothing',
      () async {
        final remote = _Remote();
        final (bloc, request) = await failedLoadMore(remote, [
          Cached([_conv('carol', at: 10)]),
          PhaseError(offline()),
        ]);
        await sync(bloc);
        expect(readsOf(remote, request), 2);
        await bloc.close();
      },
    );

    test('3: continues while a page adds no new chat, and stops at the first '
        'new chat', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      remote.scripts
        ..add(page([_conv('bob', at: 20)]))
        ..add(page([_conv('bob', at: 20)]))
        ..add(page([_conv('carol', at: 10)]))
        ..add(page([_conv('dave', at: 5)]));
      await sync(bloc);
      expect(readsOf(remote, request), 2 + 3);
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      await bloc.close();
    });

    test('3: stops at the end of the list', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      remote.scripts
        ..add(page([_conv('bob', at: 20)]))
        ..add(page(const []))
        ..add(page([_conv('dave', at: 5)]));
      await sync(bloc);
      expect(readsOf(remote, request), 2 + 2);
      expect((bloc.state as ConversationsLoaded).hasMore, isFalse);
      expect(_ids(bloc), ['alice_user_bob']);
      await bloc.close();
    });

    test('3: reads at most 10 pages in total', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      for (var i = 0; i < 12; i++) {
        remote.scripts.add(page([_conv('bob', at: 20)]));
      }
      await sync(bloc);
      expect(ConversationsOffline.reconnectPageCap, 10);
      expect(readsOf(remote, request), 2 + 10);
      // Paging then resumes on the user's scroll.
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 2 + 11);
      await bloc.close();
    });

    test('4: nothing marked: reconnect makes zero list fetches', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
      remote.scripts.add(page([_conv('carol', at: 10)]));
      bloc.add(const LoadMoreConversations()); // a successful load-more
      await pumpEventQueue();
      expect(remote.twoPhaseCalls, 2);
      expect(
        ConversationsOffline.instance.handleReconnect(
          conversationsSeamHostOf(bloc)!,
        ),
        isTrue,
      );
      await sync(bloc);
      await sync(bloc);
      expect(remote.twoPhaseCalls, 2);
      expect(remote.singlePhaseCalls, 0);
      await bloc.close();
    });

    test('5: a reconnect read that fails offline again stays marked for the '
        'next reconnect, with no loop', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      remote.scripts.add(<TwoPhaseResult<Conversation>>[PhaseError(offline())]);
      await sync(bloc);
      expect(readsOf(remote, request), 3);
      // Still offline: no loop, and a scroll does not re-request.
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);
      expect(_ids(bloc), ['alice_user_bob']);
      // The next reconnect reads it once more.
      remote.scripts.add(page([_conv('carol', at: 10)]));
      await sync(bloc);
      expect(readsOf(remote, request), 4);
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      await bloc.close();
    });

    test('6: a scroll, a second sync or a pull-to-refresh during the read '
        'starts no second read of the page', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(phases);
      await sync(bloc);
      expect(readsOf(remote, request), 3);
      expect((bloc.state as ConversationsLoaded).isLoadingMore, isTrue);

      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      await sync(bloc);
      // Refresh: the SDK sync request answers disabled in a unit test, so
      // the list reloads page one on a new request.
      remote.scripts.add(page([_conv('bob', at: 20), _conv('carol', at: 10)]));
      bloc.add(const RefreshConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);

      phases.add(Server([_conv('bob', at: 20)]));
      await phases.close();
      await pumpEventQueue();
      // The read stops: the list was reloaded on another request.
      expect(readsOf(remote, request), 3);
      expect(remote.twoPhaseCalls, 4);
      await bloc.close();
    });

    test('7: logout during the read stops it; the mark does not survive the '
        'session', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts
        ..add(phases)
        ..add(page([_conv('bob', at: 20)]));
      await sync(bloc);
      expect(readsOf(remote, request), 3);

      hub.debugLogout();
      await pumpEventQueue();
      phases.add(Server([_conv('bob', at: 20)]));
      await phases.close();
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);
      expect(bloc.state, isA<ConversationsEmpty>());
      expect(bloc.items, isEmpty);

      // A new session's sync reads nothing.
      hub.debugLoginSuccess('alice');
      await sync(bloc);
      expect(remote.twoPhaseCalls, 3);
      await bloc.close();
    });

    test('7: a list disposed during the read stops it', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts
        ..add(phases)
        ..add(page([_conv('bob', at: 20)]));
      await sync(bloc);
      expect(readsOf(remote, request), 3);

      final closing = bloc.close();
      await pumpEventQueue();
      phases.add(Server([_conv('bob', at: 20)]));
      await phases.close();
      await pumpEventQueue();
      await closing;
      expect(readsOf(remote, request), 3);
    });

    test('7: a reload replaces the marked request; its sync reads nothing '
        'more', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      remote.scripts.add(page([_conv('bob', at: 20)]));
      bloc.add(const LoadConversations(silent: true));
      await pumpEventQueue();
      expect(remote.twoPhaseCalls, 3);
      await sync(bloc);
      expect(remote.twoPhaseCalls, 3);
      expect(readsOf(remote, request), 2);
      await bloc.close();
    });

    test('8: offline off: load-more keeps today\'s single-phase path and the '
        'list makes no two-phase read', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final remote = _Remote()..singlePhaseRows = [_conv('bob', at: 20)];
      final bloc = _bloc(
        remote,
        builder: ConversationsRequestBuilder()..limit = 1,
      );
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob']);
      remote.singlePhaseRows = const [];
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(remote.singlePhaseCalls, 2);
      expect(remote.twoPhaseCalls, 0);
      expect((bloc.state as ConversationsLoaded).hasMore, isFalse);
      await bloc.close();
    });

    // The three in-flight guards of the reconnect read, one test each: each
    // fails with its guard removed.

    test('6: a second sync while the reconnect read is loading keeps the '
        'footer spinner; a scroll then starts no second read', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(phases);
      await sync(bloc);
      expect(readsOf(remote, request), 3);

      await sync(bloc);
      expect((bloc.state as ConversationsLoaded).isLoadingMore, isTrue);
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);

      phases.add(Server([_conv('carol', at: 10)]));
      await phases.close();
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      expect((bloc.state as ConversationsLoaded).isLoadingMore, isFalse);
      expect(readsOf(remote, request), 3);
      await bloc.close();
    });

    test('6 (scroll guard): a second sync after the reconnect read painted its '
        'page, then a scroll, starts no simultaneous read', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts
        ..add(phases)
        ..add(page([_conv('dave', at: 5)]));
      await sync(bloc);
      // The page paints; its read has not ended yet.
      phases.add(Server([_conv('carol', at: 10)]));
      await pumpEventQueue();
      expect((bloc.state as ConversationsLoaded).isLoadingMore, isFalse);

      await sync(bloc);
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 3, reason: 'no simultaneous fetchNext');

      await phases.close();
      await pumpEventQueue();
      expect(readsOf(remote, request), 3); // carol was new: the read stops
      // Paging then resumes on the user's scroll.
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      expect(readsOf(remote, request), 4);
      await bloc.close();
    });

    /// A reconnect read whose page failed offline again while its read has
    /// not ended, so the page is marked while the read still runs.
    Future<
      (
        ConversationsBloc,
        ConversationsRequest,
        StreamController<TwoPhaseResult<Conversation>>,
      )
    >
    remarkedDuringRead(_Remote remote) async {
      final (bloc, request) = await marked(remote);
      final phases = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(phases);
      await sync(bloc);
      phases.add(PhaseError(offline()));
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);
      return (bloc, request, phases);
    }

    test('6 (re-entry guard): a sync while the reconnect read runs starts no '
        'second reconnect read, even with the page marked again', () async {
      final remote = _Remote();
      final (bloc, request, phases) = await remarkedDuringRead(remote);
      remote.scripts.add(page([_conv('carol', at: 10)]));
      await sync(bloc);
      expect(readsOf(remote, request), 3);
      await phases.close();
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);
      await bloc.close();
    });

    test('5: a sync while the reconnect read runs keeps the mark that read '
        'leaves; the next sync reads the page once', () async {
      final remote = _Remote();
      final (bloc, request, phases) = await remarkedDuringRead(remote);
      await sync(bloc);
      await phases.close();
      await pumpEventQueue();
      expect(readsOf(remote, request), 3);

      remote.scripts.add(page([_conv('carol', at: 10)]));
      await sync(bloc);
      expect(readsOf(remote, request), 4);
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      await bloc.close();
    });

    test('5: a sync whose reconcile is dropped keeps the page marked; the '
        'next sync reads it once', () async {
      final remote = _Remote();
      final (bloc, request) = await marked(remote);
      remote.scripts.add(page([_conv('carol', at: 10)]));
      conversationsSeamHostOf(bloc)!.run(
        (ctx) => ConversationsOffline.instance.onHubEvent(
          _StaleCtx(ctx),
          ConversationSyncCompleted(hub.gen, [_conv('bob', at: 20)]),
        ),
      );
      await pumpEventQueue();
      expect(readsOf(remote, request), 2);

      await sync(bloc);
      expect(readsOf(remote, request), 3);
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      await bloc.close();
    });
  });

  group('ENG-41552', () {
    test('D84 (3), (8): offline on, nothing cached and a not-connected error '
        'shows "Connect to load chats"; the reconnect sync page replaces it '
        'with one read', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        const Cached<Conversation>([]),
        PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsConnectToLoad>());
      expect(
        (bloc.state as ConversationsConnectToLoad).error.code,
        'ERR_CONNECTION',
      );
      expect(errors, isEmpty, reason: 'the state itself fires onError');

      // Reconnect: the kit fetches nothing itself (G7) ...
      expect(
        ConversationsOffline.instance.handleReconnect(
          conversationsSeamHostOf(bloc)!,
        ),
        isTrue,
      );
      // ... and the SDK's sync page replaces the error view, once.
      await _hub(
        bloc,
        ConversationSyncCompleted(hub.gen, [_conv('bob', at: 20)]),
      );
      expect(_ids(bloc), ['alice_user_bob']);
      expect(bloc.state, isA<ConversationsLoaded>());
      expect(remote.twoPhaseCalls, 1);
      expect(remote.singlePhaseCalls, 0);
      await bloc.close();
    });

    test('D84 (3): a type and tag filter with no keyword, offline with '
        'nothing cached, is a plain list: "Connect to load chats"', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        const Cached<Conversation>([]),
        PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x')),
      ]);
      final bloc = _bloc(
        remote,
        builder: ConversationsRequestBuilder()
          ..conversationType = 'group'
          ..withTags = true
          ..tags = ['work'],
      );
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsConnectToLoad>());
      await bloc.close();
    });

    test('D84 (6), (8): an empty reconnect sync page over the offline state '
        'shows the empty view', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsConnectToLoad>());
      await _hub(bloc, ConversationSyncCompleted(hub.gen, const []));
      expect(bloc.state, isA<ConversationsEmpty>());
      await bloc.close();
    });

    test('D84 (2): cached rows and a not-connected error keep the rows and '
        'do not reach onError', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Cached([_conv('bob', at: 20)]),
        PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      final states = <ConversationsState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob']);
      expect(states.whereType<ConversationsError>(), isEmpty);
      expect(errors, isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('D84 (5): cached rows and a real server error on an open keep the '
        'rows and reach onError once', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Cached([_conv('bob', at: 20)]),
        PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob']);
      expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
      await bloc.close();
    });

    test('D84 (3): an own send over "Connect to load chats" adds its pending '
        'preview', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x')),
      ]);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsConnectToLoad>());
      final pending = _msg(
        id: 0,
        from: 'alice',
        to: 'new',
        at: 60,
        lid: 'L9',
        sendState: 'SENDING',
        conversationId: 'alice_user_new',
      );
      await _hub(
        bloc,
        SendStateEvent(
          hub.gen,
          'L9',
          pending,
          CometChatMessageSendState.sending,
          null,
        ),
      );
      expect(_ids(bloc), ['alice_user_new']);
      await bloc.close();
    });

    test('D84 (6): an empty server page shows the empty view', () async {
      final remote = _Remote();
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        const Cached<Conversation>([]),
        const Server<Conversation>([]),
      ]);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsEmpty>());
      await bloc.close();
    });

    test(
      'D84 (4): a server error that is not the network shows the error view',
      () async {
        final remote = _Remote();
        remote.scripts.add(<TwoPhaseResult<Conversation>>[
          PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x')),
        ]);
        final bloc = _bloc(remote);
        bloc.add(const LoadConversations());
        await pumpEventQueue();
        expect(bloc.state, isA<ConversationsError>());
        await bloc.close();
      },
    );

    test('G: a load-more asked while the first page is in flight waits, then '
        'reads the next page once that page is in', () async {
      final remote = _Remote();
      final first = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(first);
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Server([_conv('carol', at: 5)]),
      ]);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      first.add(Cached([_conv('bob', at: 20)]));
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_bob']);

      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();
      // No second read on the request while its first page is in flight.
      expect(remote.twoPhaseCalls, 1);

      first.add(Server([_conv('bob', at: 20)]));
      await first.close();
      await pumpEventQueue();
      expect(remote.twoPhaseCalls, 2);
      expect(remote.requests.last, same(remote.requests.first));
      expect(_ids(bloc), ['alice_user_bob', 'alice_user_carol']);
      await bloc.close();
    });

    test('G: a deferred load-more is dropped when the list is reloaded '
        'meanwhile', () async {
      final remote = _Remote();
      final first = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(first);
      final bloc = _bloc(remote);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      first.add(Cached([_conv('bob', at: 20)]));
      await pumpEventQueue();
      bloc.add(const LoadMoreConversations());
      await pumpEventQueue();

      // A reload replaces the request before the first page answers.
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Server([_conv('bob', at: 20)]),
      ]);
      bloc.add(const LoadConversations(silent: true));
      await pumpEventQueue();
      first.add(Server([_conv('bob', at: 20)]));
      await first.close();
      await pumpEventQueue();
      expect(remote.twoPhaseCalls, 2);
      await bloc.close();
    });
  });

  group('cache reset (G8, ENG-41569)', () {
    test('cacheReset clears then reloads once', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
      addTearDown(bloc.close);
      expect(_ids(bloc), ['alice_user_bob']);
      final reload = StreamController<TwoPhaseResult<Conversation>>();
      remote.scripts.add(reload);
      final states = <ConversationsState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);
      await pumpEventQueue();
      // Cleared before the reload's page lands, and read once from page one.
      expect(states.first, isA<ConversationsEmpty>());
      expect(_ids(bloc), isEmpty);
      expect(remote.twoPhaseCalls, 2);
      expect(identical(remote.requests[0], remote.requests[1]), isFalse);

      reload.add(Server([_conv('carol', at: 30)]));
      await reload.close();
      await pumpEventQueue();
      expect(_ids(bloc), ['alice_user_carol']);
      expect(remote.twoPhaseCalls, 2);
    });

    test('cacheReset reload failure over rows is quiet', () async {
      final remote = _Remote();
      final bloc = await _loaded(remote, [_conv('bob', at: 20)]);
      addTearDown(bloc.close);
      final errors = <CometChatException>[];
      void sink(CometChatException e) => errors.add(e);
      OfflineListErrors.listen(bloc, sink);
      addTearDown(() => OfflineListErrors.cancel(bloc, sink));
      remote.scripts.add(<TwoPhaseResult<Conversation>>[
        Cached([_conv('dave', at: 40)]),
        PhaseError(CometChatException('ERR_INTERNAL_SERVER', 'x', 'x')),
      ]);

      hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);
      await pumpEventQueue();

      expect(_ids(bloc), ['alice_user_dave']);
      expect(errors, isEmpty);
    });
  });
}
