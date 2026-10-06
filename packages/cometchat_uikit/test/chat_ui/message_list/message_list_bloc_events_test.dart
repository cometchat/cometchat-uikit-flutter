/// MessageListBloc — the event handlers the existing suites do not reach.
/// Track 3 TEST3 (ENG-38684).
///
/// `message_list_bloc.dart` holds two blocs over one shared event type.
/// `MessageListBloc` owns 23 events — loading, receipts, reactions, unread —
/// and `AnimatedMessageListBloc` owns 9: the list-mutation family
/// (Insert/Update/Remove/Set) and the paging flags. Adding a mutation event to
/// the wrong one throws `add(X) was called without a registered event
/// handler`, which is worth knowing before reading the split below.
///
/// The three existing bloc suites cover the load path and real-time
/// receive/edit/delete; this covers the rest of both blocs.
///
/// Every use case is injectable on the constructor, so the whole bloc runs
/// against a mock repository with no SDK and no network.
///
///   flutter test test/chat_ui/message_list/message_list_bloc_events_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

class MockMessageListRepository extends Mock implements MessageListRepository {}

class FakeUser extends Fake implements User {
  FakeUser([this._uid = 'test_user']);
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String get name => 'Test $_uid';
}

class FakeMsg extends Fake implements TextMessage {
  FakeMsg(this._id, {String? muid, DateTime? sentAt, List<ReactionCount>? r})
    : _muid = muid ?? 'muid_$_id',
      _sentAt = sentAt ?? DateTime(2026, 1, 1),
      _reactions = r ?? const [];
  final int _id;
  final String _muid;
  final DateTime _sentAt;
  List<ReactionCount> _reactions;

  @override
  int get id => _id;
  @override
  String get muid => _muid;
  @override
  int get parentMessageId => 0;
  @override
  String get type => 'text';
  @override
  String get category => 'message';
  @override
  DateTime? get sentAt => _sentAt;
  @override
  DateTime? get readAt => null;
  @override
  DateTime? get deliveredAt => null;
  @override
  DateTime? get deletedAt => null;
  @override
  User? get sender => FakeUser();
  @override
  int get replyCount => 0;
  @override
  set replyCount(int v) {}
  @override
  String get receiverUid => 'test_user';
  @override
  String get receiverType => 'user';
  @override
  String? get conversationId => 'user_test_user';
  @override
  BaseMessage? get quotedMessage => null;
  @override
  String get text => 'msg $_id';
  @override
  List<ReactionCount> get reactions => _reactions;
  @override
  set reactions(List<ReactionCount> v) => _reactions = v;
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  int get quotedMessageId => 0;
  @override
  set quotedMessageId(int v) {}
}

class FakeBase extends Fake implements BaseMessage {
  @override
  int get id => 0;
}

class FakeMessagesRequest extends Fake implements MessagesRequest {}

class FakeConversation extends Fake implements Conversation {
  FakeConversation([this._unread = 0]);
  final int _unread;
  @override
  String? get conversationId => 'user_test_user';
  @override
  int get unreadMessageCount => _unread;
  @override
  int? get lastReadMessageId => 1;
}

class FakeReceipt extends Fake implements MessageReceipt {
  FakeReceipt(this._messageId);
  final int _messageId;
  @override
  int? get messageId => _messageId;
  @override
  User get sender => FakeUser('someone_else');
}

/// Seeds [repo] so a LoadMessages returns [msgs]. MessageListBloc has no
/// SetMessages handler — that belongs to the animated bloc — so the only way
/// to give it a populated list is to run its real load path.
void seed(MockMessageListRepository repo, List<BaseMessage> msgs) {
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
  ).thenAnswer((_) async => Success(msgs));
}

const _load = LoadMessages(
  conversationWith: 'test_user',
  conversationType: 'user',
);

/// The animated bloc owns list mutation and paging; it takes no use cases.
AnimatedMessageListBloc makeAnimated() => AnimatedMessageListBloc();

MessageListBloc makeBloc(MockMessageListRepository repo) => MessageListBloc(
  getMessagesUseCase: GetMessagesUseCase(repo),
  loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
  loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
  markAsReadUseCase: MarkAsReadUseCase(repo),
  markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
  markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
  getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
  user: FakeUser(),
  disableSDKListeners: true,
);

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBase());
    registerFallbackValue(FakeMessagesRequest());
    registerFallbackValue(FakeConversation());
  });

  late MockMessageListRepository repo;

  setUp(() {
    repo = MockMessageListRepository();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
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
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    ).thenAnswer((_) async => Success(FakeConversation()));
    when(
      () => repo.markAsRead(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.markAsDelivered(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.markMessageAsUnread(any()),
    ).thenAnswer((_) async => Success(FakeConversation()));
  });

  // -------------------------------------------------------------------------
  group('AnimatedMessageListBloc — list mutation', () {
    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetMessages replaces the whole list',
      build: () => makeAnimated(),
      act: (b) => b.add(SetMessages([FakeMsg(1), FakeMsg(2)])),
      verify: (b) {
        expect(b.state.messages, hasLength(2));
        expect(b.state.messages.first.id, 1);
      },
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetMessages with an empty list clears it',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(SetMessages([FakeMsg(1)]));
        await Future<void>.delayed(Duration.zero);
        b.add(SetMessages(const []));
      },
      verify: (b) => expect(b.state.messages, isEmpty),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'InsertMessage adds one',
      build: () => makeAnimated(),
      act: (b) => b.add(InsertMessage(FakeMsg(7))),
      verify: (b) {
        expect(b.state.messages, hasLength(1));
        expect(b.state.messages.single.id, 7);
      },
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'InsertMessage honours an explicit index',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(SetMessages([FakeMsg(1), FakeMsg(2)]));
        await Future<void>.delayed(Duration.zero);
        b.add(InsertMessage(FakeMsg(99), index: 0));
      },
      verify: (b) {
        expect(b.state.messages, hasLength(3));
        expect(b.state.messages.first.id, 99);
      },
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'InsertAllMessages adds every one',
      build: () => makeAnimated(),
      act: (b) =>
          b.add(InsertAllMessages([FakeMsg(1), FakeMsg(2), FakeMsg(3)])),
      verify: (b) => expect(b.state.messages, hasLength(3)),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'InsertAllMessages with an empty list is a no-op',
      build: () => makeAnimated(),
      act: (b) => b.add(InsertAllMessages(const [])),
      verify: (b) => expect(b.state.messages, isEmpty),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'UpdateMessage swaps the matching entry in place',
      build: () => makeAnimated(),
      act: (b) async {
        final original = FakeMsg(5);
        b.add(SetMessages([FakeMsg(4), original, FakeMsg(6)]));
        await Future<void>.delayed(Duration.zero);
        b.add(UpdateMessage(original, FakeMsg(5, muid: 'edited')));
      },
      verify: (b) {
        expect(b.state.messages, hasLength(3), reason: 'no growth');
        expect(b.state.messages[1].muid, 'edited');
      },
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'UpdateMessage for an absent message does not grow the list',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(SetMessages([FakeMsg(1)]));
        await Future<void>.delayed(Duration.zero);
        b.add(UpdateMessage(FakeMsg(404), FakeMsg(404, muid: 'x')));
      },
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'RemoveMessage drops the matching entry',
      build: () => makeAnimated(),
      act: (b) async {
        final victim = FakeMsg(2);
        b.add(SetMessages([FakeMsg(1), victim, FakeMsg(3)]));
        await Future<void>.delayed(Duration.zero);
        b.add(RemoveMessage(victim));
      },
      verify: (b) {
        expect(b.state.messages, hasLength(2));
        expect(b.state.messages.map((m) => m.id), isNot(contains(2)));
      },
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'RemoveMessage for an absent message leaves the list alone',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(SetMessages([FakeMsg(1)]));
        await Future<void>.delayed(Duration.zero);
        b.add(RemoveMessage(FakeMsg(404)));
      },
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );
  });

  // -------------------------------------------------------------------------
  group('AnimatedMessageListBloc — paging flags', () {
    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetLoadingOlder toggles both ways',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(const SetLoadingOlder(true));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.isLoadingOlder, isTrue);
        b.add(const SetLoadingOlder(false));
      },
      verify: (b) => expect(b.state.isLoadingOlder, isFalse),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetLoadingNewer toggles both ways',
      build: () => makeAnimated(),
      act: (b) async {
        b.add(const SetLoadingNewer(true));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.isLoadingNewer, isTrue);
        b.add(const SetLoadingNewer(false));
      },
      verify: (b) => expect(b.state.isLoadingNewer, isFalse),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetHasMoreOlder records the flag',
      build: () => makeAnimated(),
      act: (b) => b.add(const SetHasMoreOlder(false)),
      verify: (b) => expect(b.state.hasMoreOlder, isFalse),
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetHasMoreNewer records the flag',
      build: () => makeAnimated(),
      act: (b) => b.add(const SetHasMoreNewer(true)),
      verify: (b) => expect(b.state.hasMoreNewer, isTrue),
    );
  });

  // -------------------------------------------------------------------------
  group('receipts', () {
    blocTest<MessageListBloc, MessageListState>(
      'a delivery receipt against a loaded list is handled',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(DeliveryReceiptReceived(FakeReceipt(1)));
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<MessageListBloc, MessageListState>(
      'a read receipt against a loaded list is handled',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(ReadReceiptReceived(FakeReceipt(1)));
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<MessageListBloc, MessageListState>(
      'a receipt for an unknown message is ignored',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(ReadReceiptReceived(FakeReceipt(9999)));
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<MessageListBloc, MessageListState>(
      'MarkMessageAsRead reaches the repository',
      build: () => makeBloc(repo),
      act: (b) => b.add(MarkMessageAsRead(FakeMsg(1))),
      wait: const Duration(milliseconds: 60),
      verify: (_) => verify(() => repo.markAsRead(any())).called(1),
    );
  });

  // -------------------------------------------------------------------------
  group('the unread cycle', () {
    blocTest<MessageListBloc, MessageListState>(
      'MarkMessageAsUnread reaches the repository',
      build: () => makeBloc(repo),
      act: (b) => b.add(MarkMessageAsUnread(FakeMsg(3))),
      wait: const Duration(milliseconds: 60),
      verify: (_) => verify(() => repo.markMessageAsUnread(any())).called(1),
    );

    blocTest<MessageListBloc, MessageListState>(
      'ResetUnreadState does not throw',
      build: () => makeBloc(repo),
      act: (b) => b.add(ResetUnreadState()),
      wait: const Duration(milliseconds: 40),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );

    blocTest<MessageListBloc, MessageListState>(
      'LoadFromUnread runs the load path',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) => b.add(
        const LoadFromUnread(
          conversationWith: 'test_user',
          conversationType: 'user',
        ),
      ),
      wait: const Duration(milliseconds: 100),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );
  });

  // -------------------------------------------------------------------------
  group('reactions from the SDK', () {
    blocTest<MessageListBloc, MessageListState>(
      'ReactionAddedFromSDK for a known message is handled',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(
          ReactionAddedFromSDK(
            messageId: 1,
            reaction: Reaction(reaction: '👍'),
          ),
        );
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<MessageListBloc, MessageListState>(
      'ReactionRemovedFromSDK for a known message is handled',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(
          ReactionRemovedFromSDK(
            messageId: 1,
            reaction: Reaction(reaction: '👍'),
          ),
        );
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );

    blocTest<MessageListBloc, MessageListState>(
      'a reaction for an unknown message is ignored',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(
          ReactionAddedFromSDK(
            messageId: 4040,
            reaction: Reaction(reaction: '🔥'),
          ),
        );
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, hasLength(1)),
    );
  });

  // -------------------------------------------------------------------------
  group('refresh, sync, jump and force-empty', () {
    blocTest<MessageListBloc, MessageListState>(
      'RefreshMessages runs without a prior load',
      build: () => makeBloc(repo),
      act: (b) => b.add(RefreshMessages()),
      wait: const Duration(milliseconds: 100),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );

    blocTest<MessageListBloc, MessageListState>(
      'SyncMessages runs without a prior load',
      build: () => makeBloc(repo),
      act: (b) => b.add(SyncMessages()),
      wait: const Duration(milliseconds: 100),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );

    blocTest<MessageListBloc, MessageListState>(
      'JumpToMessage for a loaded message is handled',
      build: () {
        seed(repo, [FakeMsg(1), FakeMsg(2)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(const JumpToMessage(messageId: 2));
      },
      wait: const Duration(milliseconds: 100),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );

    blocTest<MessageListBloc, MessageListState>(
      'ForceEmptyState empties the list',
      build: () {
        seed(repo, [FakeMsg(1)]);
        return makeBloc(repo);
      },
      act: (b) async {
        b.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        b.add(ForceEmptyState());
      },
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state.messages, isEmpty),
    );

    blocTest<MessageListBloc, MessageListState>(
      'SetActiveConversation is handled',
      build: () => makeBloc(repo),
      act: (b) => b.add(const SetActiveConversation('user_test_user')),
      wait: const Duration(milliseconds: 60),
      verify: (b) => expect(b.state, isA<MessageListState>()),
    );
  });

  // -------------------------------------------------------------------------
  group('lifecycle', () {
    test('close() is safe immediately after construction', () async {
      final b = makeBloc(repo);
      await expectLater(b.close(), completes);
    });

    test('close() is safe after events have been processed', () async {
      final b = makeBloc(repo);
      b.add(_load);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await expectLater(b.close(), completes);
    });
  });
}
