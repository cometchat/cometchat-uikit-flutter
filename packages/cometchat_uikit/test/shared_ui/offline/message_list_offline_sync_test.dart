// W5 (ENG-41095): message-list reconnect and sync, cache reset,
// effective-offline transitions and own pin/save echo, driven through the real
// MessageListBloc with offline forced on/off by the SDK override.

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/utils/message_operation.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_sync.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageListRepository {}

class _FakeRequest extends Fake implements MessagesRequest {}

final _me = User(uid: 'me-w5', name: 'Me');
final _bob = User(uid: 'bob-w5', name: 'Bob');
final _carol = User(uid: 'carol-w5', name: 'Carol');

const _channel = MethodChannel('cometchat_chat_uikit');
final _played = <String?>[];

DateTime _t(int ms) => DateTime.fromMillisecondsSinceEpoch(1700000000000 + ms);

TextMessage _text(
  int id, {
  int at = 0,
  User? sender,
  String? to,
  String? source,
  String? localId,
  String? sendState,
}) {
  final m = TextMessage(
    id: id,
    muid: 'muid-w5-$id-$at',
    text: 'hello $id',
    sender: sender ?? _bob,
    receiverUid: to ?? _me.uid,
    type: 'text',
    receiverType: 'user',
    category: 'message',
    sentAt: _t(at == 0 ? id : at),
  );
  m.localMessageId = localId;
  m.source = source;
  m.sendState = sendState;
  return m;
}

Action _action(
  int id, {
  required int at,
  String receiverType = 'user',
  String? receiverUid,
  String action = 'joined',
  User? on,
}) => Action(
  id: id,
  muid: 'muid-w5-a$id',
  action: action,
  sender: _bob,
  receiverUid: receiverUid ?? _me.uid,
  type: 'groupMember',
  receiverType: receiverType,
  category: 'action',
  sentAt: _t(at),
  actionBy: _bob,
  actionOn: on ?? _bob,
);

_MockRepo _repo({List<BaseMessage> page = const []}) {
  final repo = _MockRepo();
  when(
    () => repo.getMessages(
      conversationWith: any(named: 'conversationWith'),
      conversationType: any(named: 'conversationType'),
      limit: any(named: 'limit'),
      parentMessageId: any(named: 'parentMessageId'),
      types: any(named: 'types'),
      categories: any(named: 'categories'),
      hideReplies: any(named: 'hideReplies'),
      withParent: any(named: 'withParent'),
    ),
  ).thenAnswer((_) async => Success(List<BaseMessage>.of(page)));
  when(
    () => repo.fetchNextMessages(request: any(named: 'request')),
  ).thenAnswer((_) async => const Success(<BaseMessage>[]));
  // A failed markAsRead (as offline) keeps the SDK out of these tests.
  when(
    () => repo.markAsRead(any()),
  ).thenAnswer((_) async => const Failure(message: 'offline'));
  when(
    () => repo.markAsDelivered(any()),
  ).thenAnswer((_) async => const Success(null));
  when(
    () => repo.getConversation(
      conversationWith: any(named: 'conversationWith'),
      conversationType: any(named: 'conversationType'),
    ),
  ).thenAnswer((_) async => const Failure(message: 'not needed'));
  return repo;
}

MessageListBloc _bloc(
  _MockRepo repo, {
  User? user,
  Group? group,
  bool disableReceipts = false,
}) => MessageListBloc(
  getMessagesUseCase: GetMessagesUseCase(repo),
  loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
  loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
  markAsReadUseCase: MarkAsReadUseCase(repo),
  markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
  markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
  getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
  user: group == null ? (user ?? _bob) : null,
  group: group,
  disableReceipts: disableReceipts,
  disableSDKListeners: true,
);

Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<MessageListBloc> _loaded(
  _MockRepo repo, {
  Group? group,
  bool disableReceipts = false,
}) async {
  final bloc = _bloc(repo, group: group, disableReceipts: disableReceipts);
  addTearDown(bloc.close);
  bloc.add(
    LoadMessages(
      conversationWith: group?.guid ?? _bob.uid,
      conversationType: group == null ? 'user' : 'group',
    ),
  );
  await _drain();
  return bloc;
}

/// Runs [body] on [bloc]'s event loop with a live seam context.
Future<void> _onLoop(
  MessageListBloc bloc,
  Future<void> Function(MessageListSeamContext ctx) body,
) async {
  messageListSeamHostOf(bloc)!.run(body);
  await _drain();
}

List<int> _ids(MessageListBloc b) => b.state.messages.map((m) => m.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hub = OfflineHub.instance;
  final sync = MessageListOfflineSync.instance;

  setUpAll(() {
    registerFallbackValue(_FakeRequest());
    registerFallbackValue(_text(0));
  });

  setUp(() {
    hub.debugReset();
    sync.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess(_me.uid);
    CometChatUIKit.loggedInUser = _me;
    _played.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'playCustomSound') {
            _played.add((call.arguments as Map)['assetAudioPath'] as String?);
          }
          return null;
        });
  });

  tearDown(() {
    CometChat.debugSetOfflineEnabledOverride(null);
    CometChatUIKit.loggedInUser = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('reconnect and resume (invariant 1)', () {
    test('connected/resume hooks suppress the kit fetch with offline on', () {
      final repo = _repo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      final host = messageListSeamHostOf(bloc)!;
      expect(sync.handleConnected(host), isTrue);
      expect(sync.handleResume(host), isTrue);
    });

    test('SyncMessages with offline on fetches nothing', () async {
      final repo = _repo(page: [_text(1), _text(2)]);
      final bloc = await _loaded(repo);
      bloc.add(const SyncMessages());
      await _drain();
      verifyNever(() => repo.fetchNextMessages(request: any(named: 'request')));
      expect(_ids(bloc), [1, 2]);
    });

    test('SyncMessages with offline off runs today\'s newer fetch', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final repo = _repo(page: [_text(1), _text(2)]);
      final bloc = await _loaded(repo);
      bloc.add(const SyncMessages());
      await _drain();
      verify(
        () => repo.fetchNextMessages(request: any(named: 'request')),
      ).called(1);
    });
  });

  group('messages delivered by the sweep', () {
    test('a SYNC message goes in sorted place with no sound and no '
        'per-message receipt; a live one still plays and appends', () async {
      final repo = _repo(page: [_text(10), _text(30)]);
      final bloc = await _loaded(repo);
      clearInteractions(repo);

      bloc.add(MessageReceived(_text(20, source: 'SYNC')));
      await _drain();
      expect(_ids(bloc), [10, 20, 30]);
      expect(_played, isEmpty);
      verifyNever(() => repo.markAsRead(any()));

      bloc.add(MessageReceived(_text(40)));
      await _drain();
      expect(_ids(bloc), [10, 20, 30, 40]);
      expect(_played, hasLength(1));
      verify(() => repo.markAsRead(any())).called(1);
    });

    test('MessageSyncCompleted upserts action and call rows in sorted '
        'place and does not re-insert rows already delivered', () async {
      final repo = _repo(page: [_text(10), _text(30)]);
      final bloc = await _loaded(repo, disableReceipts: true);

      hub.debugMessageSyncCompleted([
        _action(20, at: 20),
        _text(30, source: 'SYNC'), // already shown: not inserted again
      ], SyncOutcome.caughtUp);
      await _drain();

      expect(_ids(bloc), [10, 20, 30]);
      expect(_played, isEmpty);
    });

    test(
      'a swept self-kick runs the live received path for the group',
      () async {
        final group = Group(guid: 'g-w5', name: 'G', type: 'public');
        final repo = _repo();
        final bloc = await _loaded(repo, group: group, disableReceipts: true);

        final kick = _action(
          77,
          at: 77,
          receiverType: 'group',
          receiverUid: group.guid,
          action: 'kicked',
          on: _me,
        );
        hub.debugMessageSyncCompleted([kick], SyncOutcome.caughtUp);
        await _drain();

        expect(_ids(bloc), [77]);
        expect((bloc.state.messages.single as Action).action, 'kicked');
      },
    );

    test('one cumulative read receipt after the sync, for the newest '
        'incoming message', () async {
      final repo = _repo(page: [_text(10)]);
      final bloc = await _loaded(repo);
      clearInteractions(repo);

      bloc.add(MessageReceived(_text(20, source: 'SYNC')));
      bloc.add(MessageReceived(_text(30, source: 'SYNC')));
      await _drain();
      verifyNever(() => repo.markAsRead(any()));

      hub.debugMessageSyncCompleted([
        _text(20, source: 'SYNC'),
        _text(30, source: 'SYNC'),
      ], SyncOutcome.caughtUp);
      await _drain();

      final read = verify(() => repo.markAsRead(captureAny())).captured;
      expect(read, hasLength(1));
      expect((read.single as BaseMessage).id, 30);
    });

    test('a chat read while offline gets one markAsRead after the next '
        'sync, even with two lists mounted', () async {
      final repo = _repo();
      final bloc = await _loaded(repo, disableReceipts: false);
      final second = await _loaded(_repo(), disableReceipts: true);
      expect(second.isClosed, isFalse);
      final marked = <BaseMessage>[];
      sync.debugMarkAsRead = marked.add;

      // Carol's chat was read while offline: markAsRead failed.
      bloc.add(MarkMessageAsRead(_text(50, sender: _carol)));
      await _drain();
      expect(sync.debugReadOffline.keys, contains('user:${_carol.uid}'));

      hub.debugMessageSyncCompleted([
        _text(60, sender: _carol, source: 'SYNC'),
      ], SyncOutcome.caughtUp);
      await _drain();

      expect(marked.map((m) => m.id), [60]);
      expect(sync.debugReadOffline, isEmpty);
    });

    test('a chat read offline and backed out of still gets its markAsRead '
        'after the next sync, with no list mounted', () async {
      final bloc = _bloc(_repo());
      bloc.add(
        LoadMessages(conversationWith: _bob.uid, conversationType: 'user'),
      );
      await _drain();
      final marked = <BaseMessage>[];
      sync.debugMarkAsRead = marked.add;

      bloc.add(MarkMessageAsRead(_text(50, sender: _carol)));
      await _drain();
      await bloc.close(); // the user backed out of the chat

      hub.debugMessageSyncCompleted(const [], SyncOutcome.caughtUp);
      await _drain();

      expect(marked.map((m) => m.id), contains(50));
      expect(sync.debugReadOffline, isEmpty);
    });

    test('the open chat at the bottom gets one receipt, on the list\'s '
        'path, even when it was also read offline', () async {
      final repo = _repo(page: [_text(10)]);
      final bloc = await _loaded(repo);
      final marked = <BaseMessage>[];
      sync.debugMarkAsRead = marked.add;
      bloc.add(MarkMessageAsRead(_text(10)));
      await _drain();
      expect(sync.debugReadOffline.keys, contains('user:${_bob.uid}'));
      clearInteractions(repo);

      hub.debugMessageSyncCompleted([
        _text(20, source: 'SYNC'),
      ], SyncOutcome.caughtUp);
      await _drain();

      final read = verify(() => repo.markAsRead(captureAny())).captured;
      expect(read.map((m) => (m as BaseMessage).id), [20]);
      expect(marked, isEmpty);
      expect(bloc.isClosed, isFalse);
    });

    test('PARTIAL and a sync error each trigger one newest-window '
        'read', () async {
      final repo = _repo(page: [_text(1)]);
      final bloc = await _loaded(repo, disableReceipts: true);
      var refreshes = 0;
      sync.debugOnRefreshNewestWindow = () => refreshes++;

      hub.debugMessageSyncCompleted(const [], SyncOutcome.caughtUp);
      await _drain();
      expect(refreshes, 0);

      hub.debugMessageSyncCompleted(const [], SyncOutcome.partial);
      await _drain();
      expect(refreshes, 1);

      await _onLoop(
        bloc,
        (ctx) => sync.onHubEvent(
          ctx,
          MessageSyncFailed(hub.gen, CometChatException('E', 'm', 'd')),
        ),
      );
      expect(refreshes, 2);
      verifyNever(() => repo.fetchNextMessages(request: any(named: 'request')));
    });
  });

  group('MessagesUpdated (invariant 2)', () {
    test('updates rows shown and never inserts', () async {
      final repo = _repo(page: [_text(1), _text(2)]);
      final bloc = await _loaded(repo, disableReceipts: true);

      final edited = _text(2)..text = 'edited';
      hub.debugMessagesSynced([edited, _text(99)]);
      await _drain();

      expect(_ids(bloc), [1, 2]);
      expect((bloc.state.messages[1] as TextMessage).text, 'edited');
    });
  });

  group('cache reset (G8)', () {
    test('notice for each branch', () {
      const r = OfflineCacheResetReason.corrupted;
      const enc = OfflineCacheResetReason.encryptionChanged;
      expect(OfflineHub.cacheResetNotice(r, 3), isA<UnsentLost>());
      expect((OfflineHub.cacheResetNotice(r, 3) as UnsentLost).count, 3);
      expect(OfflineHub.cacheResetNotice(r, null), isA<UnsentMaybeLost>());
      expect(OfflineHub.cacheResetNotice(r, 0), isNull);
      expect(OfflineHub.cacheResetNotice(enc, null), isNull);
      expect(OfflineHub.cacheResetNotice(enc, 2), isA<UnsentLost>());
    });

    test('clears, reloads and posts one notice across two lists', () async {
      final repo = _repo(page: [_text(1)]);
      final bloc = await _loaded(repo, disableReceipts: true);
      await _loaded(_repo(page: [_text(1)]), disableReceipts: true);
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      addTearDown(() => hub.detachNoticeSink(notices.add));
      final ops = <MessageOperation>[];
      final sub = bloc.operationsStream.listen(ops.add);
      addTearDown(sub.cancel);

      hub.debugCacheReset(OfflineCacheResetReason.corrupted, 2);
      await _drain();

      expect(notices, hasLength(1));
      expect((notices.single as UnsentLost).count, 2);
      expect(
        ops.any(
          (o) =>
              o.type == MessageOperationType.set && (o.messages ?? []).isEmpty,
        ),
        isTrue,
      );
      verify(
        () => repo.getMessages(
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
          limit: any(named: 'limit'),
          parentMessageId: any(named: 'parentMessageId'),
          types: any(named: 'types'),
          categories: any(named: 'categories'),
          hideReplies: any(named: 'hideReplies'),
          withParent: any(named: 'withParent'),
        ),
      ).called(2);
      expect(_ids(bloc), [1]);
    });

    test('with no list mounted, the notice waits in the hub queue and shows '
        'once when a list attaches', () async {
      hub.debugCacheReset(OfflineCacheResetReason.corrupted, null);
      await _drain();
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      addTearDown(() => hub.detachNoticeSink(notices.add));
      expect(notices.single, isA<UnsentMaybeLost>());
    });

    test(
      'an encryption change with an unknown count shows no notice',
      () async {
        await _loaded(_repo(), disableReceipts: true);
        final notices = <OfflineNotice>[];
        hub.attachNoticeSink(notices.add);
        addTearDown(() => hub.detachNoticeSink(notices.add));
        hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, null);
        await _drain();
        expect(notices, isEmpty);
      },
    );
  });

  group('effective-offline transitions (C6)', () {
    test('switch-off turns un-acked rows failed with one notice', () async {
      final repo = _repo(
        page: [
          _text(1),
          _text(
            0,
            at: 5,
            sender: _me,
            to: _bob.uid,
            localId: 'l1',
            sendState: 'PENDING',
          ),
          _text(
            0,
            at: 6,
            sender: _me,
            to: _bob.uid,
            localId: 'l2',
            sendState: 'SENDING',
          ),
        ],
      );
      final bloc = await _loaded(repo, disableReceipts: true);
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      addTearDown(() => hub.detachNoticeSink(notices.add));
      // The outbox reported the queued send while offline was on.
      hub.debugOutboxPending(bloc.state.messages[1]);
      await _drain();

      CometChat.debugSetOfflineEnabledOverride(false);
      bloc.add(const SyncMessages()); // the next connection event
      await _drain();

      final unacked = bloc.state.messages.where((m) => m.id == 0).toList();
      expect(unacked, hasLength(2));
      expect(
        unacked.every((m) => m.status == CometChatMessageStatus.failed),
        isTrue,
      );
      expect(unacked.every(sync.isDirectFailure), isTrue);
      expect(notices, hasLength(1));
      expect((notices.single as MessagesNotSent).count, 2);
      expect(bloc.state.messages, hasLength(3)); // no reload

      bloc.add(const SyncMessages());
      await _drain();
      expect(notices, hasLength(1)); // nothing left to turn
    });

    test('main list and thread both mounted: one notice for both lists\' '
        'rows, posted once through the hub', () async {
      BaseMessage unacked(String lid, int at, {int parent = 0}) => _text(
        0,
        at: at,
        sender: _me,
        to: _bob.uid,
        localId: lid,
        sendState: 'PENDING',
      )..parentMessageId = parent;
      final main = await _loaded(
        _repo(page: [_text(1), unacked('m1', 5)]),
        disableReceipts: true,
      );
      final threadBloc = _bloc(
        _repo(page: [unacked('t1', 6, parent: 1), unacked('t2', 7, parent: 1)]),
        disableReceipts: true,
      );
      addTearDown(threadBloc.close);
      threadBloc.add(
        LoadMessages(
          conversationWith: _bob.uid,
          conversationType: 'user',
          parentMessageId: 1,
        ),
      );
      await _drain();
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      hub.attachNoticeSink(notices.add); // a second sink: still one delivery
      addTearDown(() {
        hub.detachNoticeSink(notices.add);
        hub.detachNoticeSink(notices.add);
      });
      hub.debugMessageSyncCompleted(const [], SyncOutcome.caughtUp); // ON seen
      await _drain();

      CometChat.debugSetOfflineEnabledOverride(false);
      main.add(const SyncMessages());
      threadBloc.add(const SyncMessages());
      await _drain();

      expect(notices, hasLength(1));
      expect((notices.single as MessagesNotSent).count, 3);
      for (final b in [main, threadBloc]) {
        expect(
          b.state.messages.where((m) => m.id == 0).every(sync.isDirectFailure),
          isTrue,
        );
      }

      // A list that checks later in the same switch-off adds no notice.
      main.add(MessageReceived(_text(9)));
      await _drain();
      expect(notices, hasLength(1));
    });

    test('a received message with offline off is an operation that turns '
        'stranded rows failed', () async {
      final bloc = await _loaded(
        _repo(
          page: [
            _text(1),
            _text(
              0,
              at: 5,
              sender: _me,
              to: _bob.uid,
              localId: 'l1',
              sendState: 'PENDING',
            ),
          ],
        ),
        disableReceipts: true,
      );
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      addTearDown(() => hub.detachNoticeSink(notices.add));
      bloc.add(const SyncMessages()); // ON path seen
      await _drain();

      CometChat.debugSetOfflineEnabledOverride(false);
      bloc.add(MessageReceived(_text(9)));
      await _drain();

      expect(
        bloc.state.messages.firstWhere((m) => m.id == 0).status,
        CometChatMessageStatus.failed,
      );
      expect((notices.single as MessagesNotSent).count, 1);
    });

    test('with offline never on, a connection event changes no row', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final repo = _repo(
        page: [
          _text(1),
          _text(0, sender: _me, to: _bob.uid),
        ],
      );
      final bloc = await _loaded(repo, disableReceipts: true);
      final notices = <OfflineNotice>[];
      hub.attachNoticeSink(notices.add);
      addTearDown(() => hub.detachNoticeSink(notices.add));
      bloc.add(const SyncMessages());
      bloc.add(MessageReceived(_text(9)));
      await _drain();
      expect(notices, isEmpty);
      expect(bloc.state.messages.last.status, CometChatMessageStatus.sent);
    });

    test(
      'a late switch-on takes the offline path at the next operation',
      () async {
        CometChat.debugSetOfflineEnabledOverride(false);
        final repo = _repo(page: [_text(1)]);
        final bloc = await _loaded(repo, disableReceipts: true);
        CometChat.debugSetOfflineEnabledOverride(true);
        bloc.add(const SyncMessages());
        await _drain();
        verifyNever(
          () => repo.fetchNextMessages(request: any(named: 'request')),
        );
      },
    );
  });

  group('own pin/save echo (G11)', () {
    test(
      'an echo matching the row is a no-op; a real change applies',
      () async {
        final pinned = _text(5)
          ..pinnedAt = _t(100)
          ..pinnedBy = _me.uid;
        final repo = _repo(page: [pinned]);
        final bloc = await _loaded(repo, disableReceipts: true);
        final ops = <MessageOperation>[];
        final sub = bloc.operationsStream.listen(ops.add);
        addTearDown(sub.cancel);

        final echo = _text(5)
          ..pinnedAt = _t(101)
          ..pinnedBy = _me.uid;
        bloc.add(MessagePinSaveChanged(echo, isPinScope: true));
        await _drain();
        expect(ops, isEmpty);
        expect(identical(bloc.state.messages.single, pinned), isTrue);

        final unpinned = _text(5);
        bloc.add(MessagePinSaveChanged(unpinned, isPinScope: true));
        await _drain();
        expect(
          ops.where((o) => o.type == MessageOperationType.update),
          isNotEmpty,
        );
        expect(bloc.state.messages.single.pinnedAt, isNull);
      },
    );
  });

  group('sorted insert', () {
    test('by (sentAt, id) with un-acked rows last', () {
      final rows = <BaseMessage>[
        _text(10, at: 10),
        _text(30, at: 30),
        _text(0, at: 5, localId: 'l'),
      ];
      expect(MessageListOfflineSync.sortedIndexFor(rows, _text(20, at: 20)), 1);
      expect(MessageListOfflineSync.sortedIndexFor(rows, _text(40, at: 40)), 2);
      expect(MessageListOfflineSync.sortedIndexFor(rows, _text(5, at: 1)), 0);
      expect(MessageListOfflineSync.sortedIndexFor(rows, _text(0, at: 1)), 3);
    });
  });
}
