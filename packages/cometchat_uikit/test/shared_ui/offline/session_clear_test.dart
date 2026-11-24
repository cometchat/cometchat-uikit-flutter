// Session clear and list generation (W1 §2.7, G8) on both list blocs.
//
// Every test drives the real order a logout produces: offline is on during
// the session, the SDK then reports offline off, and only then do the logout
// signals arrive. No override is forced on at logout time.

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/utils/message_operation.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MessageRepo extends Fake implements MessageListRepository {
  final Completer<Result<List<BaseMessage>>> page = Completer();

  @override
  Future<Result<List<BaseMessage>>> getMessages({
    required String conversationWith,
    required String conversationType,
    int limit = 30,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    bool hideReplies = true,
    bool withParent = true,
  }) => page.future;

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async => const Failure(message: 'not needed');
}

class _ConversationsRepo extends Mock implements ConversationsRepository {}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation(this._id);
  final String _id;
  @override
  String? get conversationId => _id;
  @override
  DateTime? get pinnedAt => null;
  @override
  String? get pinnedBy => null;
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'alice';
}

TextMessage _text(int id) => TextMessage(
  id: id,
  text: 'm$id',
  sender: User(uid: 'bob', name: 'Bob'),
  receiverUid: 'alice',
  type: 'text',
  receiverType: 'user',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id),
);

ConversationsBloc _conversationsBloc(_ConversationsRepo repo) =>
    ConversationsBloc(
      getConversationsUseCase: GetConversationsUseCase(repo),
      loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
      deleteConversationUseCase: DeleteConversationUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      getConversationUseCase: GetConversationUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
      disableSDKListeners: true,
    );

/// Logs in with offline on, then logs out the way the SDK does: offline reads
/// false first, then the kit and SDK logout signals arrive.
Future<void> _logoutAfterOfflineSession() async {
  CometChat.debugSetOfflineEnabledOverride(false);
  OfflineHub.instance.onKitLogout();
  OfflineHub.instance.debugLogout();
  await pumpEventQueue();
}

void main() {
  final hub = OfflineHub.instance;

  setUpAll(() {
    registerFallbackValue(_FakeConversation(''));
  });

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  group('MessageListBloc', () {
    test('SessionEnded clears the rows before the next state', () async {
      final repo = _MessageRepo();
      final bloc = MessageListBloc(
        disableSDKListeners: true,
        user: User(uid: 'bob', name: 'Bob'),
        getMessagesUseCase: GetMessagesUseCase(repo),
      );
      addTearDown(bloc.close);
      final ops = <MessageOperation>[];
      final sub = bloc.operationsStream.listen(ops.add);
      addTearDown(sub.cancel);

      bloc.add(
        const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
      );
      await pumpEventQueue();
      repo.page.complete(Success([_text(1), _text(2)]));
      await pumpEventQueue();
      expect(bloc.state.messages, isNotEmpty);

      await _logoutAfterOfflineSession();

      expect(bloc.state.status, MessageListStatus.empty);
      expect(bloc.state.messages, isEmpty);
      expect(ops.last.type, MessageOperationType.set);
      expect(ops.last.messages, isEmpty);
    });

    test('a load in flight across a clear emits nothing after it', () async {
      final repo = _MessageRepo();
      final bloc = MessageListBloc(
        disableSDKListeners: true,
        user: User(uid: 'bob', name: 'Bob'),
        getMessagesUseCase: GetMessagesUseCase(repo),
      );
      addTearDown(bloc.close);
      final states = <MessageListState>[];
      final ops = <MessageOperation>[];
      final s1 = bloc.stream.listen(states.add);
      final s2 = bloc.operationsStream.listen(ops.add);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);

      bloc.add(
        const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
      );
      await pumpEventQueue(); // loading emitted; the fetch is pending
      await _logoutAfterOfflineSession();
      expect(bloc.state.status, MessageListStatus.empty);
      final statesAtClear = states.length;
      final opsAtClear = ops.length;

      repo.page.complete(Success([_text(1)])); // the old user's page lands
      await pumpEventQueue();

      expect(states.length, statesAtClear);
      expect(ops.length, opsAtClear);
      expect(bloc.state.messages, isEmpty);
    });

    test('a hub event handled after a newer session end is dropped', () async {
      final repo = _MessageRepo();
      final bloc = MessageListBloc(
        disableSDKListeners: true,
        user: User(uid: 'bob', name: 'Bob'),
        getMessagesUseCase: GetMessagesUseCase(repo),
      );
      addTearDown(bloc.close);
      final ops = <MessageOperation>[];
      final s1 = bloc.operationsStream.listen(ops.add);
      addTearDown(s1.cancel);
      final s2 = _endAgainWhenDelivered(1);
      addTearDown(s2.cancel);

      await _logoutAfterOfflineSession();

      // SessionEnded(1) passed the bloc's listener before gen moved to 2, so
      // only its handler can drop it: one clear (from gen 2), not two.
      expect(hub.gen, 2);
      final clears = ops.where(
        (o) =>
            o.type == MessageOperationType.set &&
            (o.messages ?? const []).isEmpty,
      );
      expect(clears, hasLength(1));
    });
  });

  group('ConversationsBloc', () {
    late _ConversationsRepo repo;

    setUp(() {
      repo = _ConversationsRepo();
      when(
        () => repo.getLoggedInUser(),
      ).thenAnswer((_) async => Success(_FakeUser()));
    });

    test('SessionEnded clears the rows before the next state', () async {
      when(() => repo.getConversations(limit: any(named: 'limit'))).thenAnswer(
        (_) async => Success([_FakeConversation('a'), _FakeConversation('b')]),
      );
      final bloc = _conversationsBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const LoadConversations());
      await pumpEventQueue();
      expect(bloc.state, isA<ConversationsLoaded>());

      await _logoutAfterOfflineSession();

      expect(bloc.state, isA<ConversationsEmpty>());
      expect(bloc.items, isEmpty);
    });

    test('a load in flight across a clear emits nothing after it', () async {
      final page = Completer<Result<List<Conversation>>>();
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) => page.future);
      final bloc = _conversationsBloc(repo);
      addTearDown(bloc.close);
      final states = <ConversationsState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(const LoadConversations());
      await pumpEventQueue(); // loading emitted; the fetch is pending
      await _logoutAfterOfflineSession();
      expect(bloc.state, isA<ConversationsEmpty>());
      final atClear = states.length;

      page.complete(Success([_FakeConversation('old')]));
      await pumpEventQueue();

      expect(states.length, atClear);
      expect(bloc.items, isEmpty);
      expect(bloc.state, isA<ConversationsEmpty>());
    });

    test('a hub event handled after a newer session end is dropped', () async {
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Success([_FakeConversation('a')]));
      final bloc = _CountingConversationsBloc(repo);
      addTearDown(bloc.close);
      bloc.add(const LoadConversations());
      await pumpEventQueue();
      final sub = _endAgainWhenDelivered(1);
      addTearDown(sub.cancel);

      await _logoutAfterOfflineSession();

      // SessionEnded(1) passed the bloc's listener before gen moved to 2, so
      // only its handler can drop it: one clear (from gen 2), not two.
      expect(hub.gen, 2);
      expect(bloc.clears, 1);
      expect(bloc.items, isEmpty);
    });
  });
}

/// Counts list clears (each handled SessionEnded clears once).
class _CountingConversationsBloc extends ConversationsBloc {
  _CountingConversationsBloc(_ConversationsRepo repo)
    : super(
        getConversationsUseCase: GetConversationsUseCase(repo),
        loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
        deleteConversationUseCase: DeleteConversationUseCase(repo),
        getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
        getConversationUseCase: GetConversationUseCase(repo),
        markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
        disableSDKListeners: true,
      );

  int clears = 0;

  @override
  void onListCleared(List<Conversation> previousList) {
    clears++;
    super.onListCleared(previousList);
  }
}

/// Subscribes after the bloc, so it runs right after the bloc's hub listener
/// has queued the event: when `SessionEnded(gen)` arrives it ends a second
/// session at once, leaving the queued event one generation behind.
StreamSubscription<Object> _endAgainWhenDelivered(int gen) {
  final hub = OfflineHub.instance;
  return hub.events.listen((e) {
    if (e is SessionEnded && e.gen == gen) {
      hub.noteOfflineOn();
      hub.onKitLogout();
    }
  });
}
