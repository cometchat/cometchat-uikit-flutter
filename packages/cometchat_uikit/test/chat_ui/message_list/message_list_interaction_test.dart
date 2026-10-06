import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockMessageListRepository extends Mock implements MessageListRepository {}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_user';
}

class FakeGroup extends Fake implements Group {
  @override
  String get guid => 'test_group';
}

class FakeTextMessage extends Fake implements TextMessage {
  final int _id;
  final String _muid;
  final int _parentMessageId;
  // Mutable — bloc writes during MessageDeleted/MessageEdited
  DateTime? _deletedAt;
  String? _deletedBy;
  BaseMessage? _quotedMessage;
  int _quotedMessageId = 0;
  ModerationStatusEnum? _moderationStatus;

  FakeTextMessage(this._id, {String? muid, int parentMessageId = 0})
    : _muid = muid ?? 'muid_$_id',
      _parentMessageId = parentMessageId;

  @override
  int get id => _id;

  @override
  String get muid => _muid;

  @override
  int get parentMessageId => _parentMessageId;

  @override
  String get type => 'text';

  @override
  String get category => 'message';

  @override
  DateTime? get sentAt => DateTime.now();

  @override
  DateTime? get readAt => null;

  @override
  DateTime? get deliveredAt => null;

  @override
  User? get sender => FakeUser();

  @override
  int get replyCount => 0;

  @override
  set replyCount(int value) {}

  @override
  String get receiverUid => 'test_user';

  @override
  String get receiverType => 'user';

  @override
  String? get conversationId => 'user_test_user';

  @override
  BaseMessage? get quotedMessage => _quotedMessage;

  @override
  String get text => 'hello';

  @override
  List<ReactionCount> get reactions => [];

  @override
  Map<String, dynamic>? get metadata => null;

  @override
  ModerationStatusEnum? get moderationStatus => _moderationStatus;

  @override
  set moderationStatus(ModerationStatusEnum? value) =>
      _moderationStatus = value;

  @override
  set quotedMessage(BaseMessage? value) => _quotedMessage = value;

  @override
  int get quotedMessageId => _quotedMessageId;

  @override
  set quotedMessageId(int value) => _quotedMessageId = value;

  @override
  DateTime? get deletedAt => _deletedAt;

  @override
  set deletedAt(DateTime? value) => _deletedAt = value;

  @override
  String? get deletedBy => _deletedBy;

  @override
  set deletedBy(String? value) => _deletedBy = value;
}

class FakeBaseMessage extends Fake implements BaseMessage {
  final int _id;
  FakeBaseMessage(this._id);

  @override
  int get id => _id;

  @override
  String get muid => 'muid_$_id';

  @override
  int get parentMessageId => 0;

  @override
  String get type => 'text';

  @override
  String get category => 'message';

  @override
  DateTime? get sentAt => DateTime.now();

  @override
  DateTime? get readAt => null;

  @override
  DateTime? get deliveredAt => null;

  @override
  User? get sender => FakeUser();

  @override
  int get replyCount => 0;

  @override
  set replyCount(int value) {}
}

class FakeMessagesRequest extends Fake implements MessagesRequest {}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_test_user';

  @override
  int get unreadMessageCount => 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MessageListBloc _makeBloc(MockMessageListRepository repo) {
  return MessageListBloc(
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
}

void _stubDefaults(MockMessageListRepository repo) {
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
    () => repo.fetchPreviousMessages(request: any(named: 'request')),
  ).thenAnswer((_) async => const Success([]));
  when(
    () => repo.fetchNextMessages(request: any(named: 'request')),
  ).thenAnswer((_) async => const Success([]));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBaseMessage(0));
    registerFallbackValue(FakeMessagesRequest());
    registerFallbackValue(FakeConversation());
  });

  group('MessageList Interaction Tests', () {
    late MockMessageListRepository repo;

    setUp(() {
      repo = MockMessageListRepository();
      _stubDefaults(repo);
    });

    // =====================================================================
    // Scroll Pagination — Load Older Messages (scroll up)
    // =====================================================================

    group('Load Older Messages (scroll up)', () {
      blocTest<MessageListBloc, MessageListState>(
        'LoadOlderMessages sets isLoadingOlder then appends older messages',
        build: () {
          final initialMsgs = [FakeTextMessage(10), FakeTextMessage(20)];
          final olderMsgs = [FakeTextMessage(1), FakeTextMessage(5)];
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
          ).thenAnswer((_) async => Success(initialMsgs));
          when(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).thenAnswer((_) async => Success(olderMsgs));
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadOlderMessages());
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, greaterThanOrEqualTo(2));
          expect(bloc.state.isLoadingOlder, isFalse);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'LoadOlderMessages sets hasMoreOlder=false when empty result',
        build: () {
          final initialMsgs = [FakeTextMessage(10)];
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
          ).thenAnswer((_) async => Success(initialMsgs));
          when(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).thenAnswer((_) async => const Success([]));
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadOlderMessages());
        },
        verify: (bloc) {
          expect(bloc.state.hasMoreOlder, isFalse);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'LoadOlderMessages is no-op when already loading older',
        build: () {
          // A full page. The initial load sets hasMoreOlder from
          // `intercepted.length >= 30`, so a shorter page makes the bloc
          // conclude there is nothing older and LoadOlderMessages correctly
          // no-ops — which is not what this test is about.
          final initialMsgs = List.generate(30, (i) => FakeTextMessage(i + 1));
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
          ).thenAnswer((_) async => Success(initialMsgs));
          // Slow response to simulate in-flight request
          when(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 200));
            return const Success([]);
          });
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadOlderMessages());
          // Second call while first is in-flight
          await Future.delayed(const Duration(milliseconds: 10));
          bloc.add(const LoadOlderMessages());
          await Future.delayed(const Duration(milliseconds: 300));
        },
        verify: (bloc) {
          // fetchPreviousMessages should only be called once
          verify(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).called(1);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'LoadOlderMessages is no-op when hasMoreOlder is false',
        build: () {
          // A full page. The initial load sets hasMoreOlder from
          // `intercepted.length >= 30`, so a shorter page makes the bloc
          // conclude there is nothing older and LoadOlderMessages correctly
          // no-ops — which is not what this test is about.
          final initialMsgs = List.generate(30, (i) => FakeTextMessage(i + 1));
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
          ).thenAnswer((_) async => Success(initialMsgs));
          // First call returns empty → sets hasMoreOlder=false
          when(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).thenAnswer((_) async => const Success([]));
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadOlderMessages());
          await Future.delayed(const Duration(milliseconds: 100));
          // Second call after hasMoreOlder is false
          bloc.add(const LoadOlderMessages());
          await Future.delayed(const Duration(milliseconds: 50));
        },
        verify: (bloc) {
          verify(
            () => repo.fetchPreviousMessages(request: any(named: 'request')),
          ).called(1);
        },
      );
    });

    // =====================================================================
    // Scroll Pagination — Load Newer Messages (scroll down)
    // =====================================================================

    group('Load Newer Messages (scroll down)', () {
      blocTest<MessageListBloc, MessageListState>(
        'LoadNewerMessages appends newer messages to list',
        build: () {
          final initialMsgs = [FakeTextMessage(1), FakeTextMessage(2)];
          final newerMsgs = [FakeTextMessage(3), FakeTextMessage(4)];
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
          ).thenAnswer((_) async => Success(initialMsgs));
          when(
            () => repo.fetchNextMessages(request: any(named: 'request')),
          ).thenAnswer((_) async => Success(newerMsgs));
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadNewerMessages());
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, greaterThanOrEqualTo(2));
          expect(bloc.state.isLoadingNewer, isFalse);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'LoadNewerMessages sets hasMoreNewer=false when empty result',
        build: () {
          final initialMsgs = [FakeTextMessage(1)];
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
          ).thenAnswer((_) async => Success(initialMsgs));
          when(
            () => repo.fetchNextMessages(request: any(named: 'request')),
          ).thenAnswer((_) async => const Success([]));
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const LoadNewerMessages());
        },
        verify: (bloc) {
          expect(bloc.state.hasMoreNewer, isFalse);
        },
      );
    });

    // =====================================================================
    // Message Operations — Edit
    // =====================================================================

    group('Message Edit', () {
      blocTest<MessageListBloc, MessageListState>(
        'MessageEdited updates existing message in list',
        build: () {
          final msgs = [FakeTextMessage(1), FakeTextMessage(2)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageEdited(FakeTextMessage(1)));
        },
        verify: (bloc) {
          // Message count should remain the same (update, not add)
          expect(bloc.state.messages.length, 2);
          expect(bloc.state.status, MessageListStatus.loaded);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'MessageEdited for non-existent message does not crash',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageEdited(FakeTextMessage(999)));
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, 1);
        },
      );
    });

    // =====================================================================
    // Message Operations — Delete
    // =====================================================================

    group('Message Delete', () {
      blocTest<MessageListBloc, MessageListState>(
        'MessageDeleted removes message when hideDeletedMessages=true',
        build: () {
          final msgs = [
            FakeTextMessage(1),
            FakeTextMessage(2),
            FakeTextMessage(3),
          ];
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
          return MessageListBloc(
            getMessagesUseCase: GetMessagesUseCase(repo),
            loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
            loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
            markAsReadUseCase: MarkAsReadUseCase(repo),
            markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
            markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
            getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
            user: FakeUser(),
            hideDeletedMessages: true,
            disableSDKListeners: true,
          );
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageDeleted(FakeTextMessage(2)));
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, 2);
          expect(bloc.state.messages.any((m) => m.id == 2), isFalse);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'MessageDeleted transitions to empty when last message removed',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return MessageListBloc(
            getMessagesUseCase: GetMessagesUseCase(repo),
            loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
            loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
            markAsReadUseCase: MarkAsReadUseCase(repo),
            markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
            markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
            getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
            user: FakeUser(),
            hideDeletedMessages: true,
            disableSDKListeners: true,
          );
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageDeleted(FakeTextMessage(1)));
        },
        verify: (bloc) {
          expect(bloc.state.messages, isEmpty);
        },
      );
    });

    // =====================================================================
    // Real-time Message Handling
    // =====================================================================

    group('Real-time Message Handling', () {
      blocTest<MessageListBloc, MessageListState>(
        'MessageReceived adds message to loaded list',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageReceived(FakeTextMessage(2)));
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, 2);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'Multiple MessageReceived events add messages in order',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(MessageReceived(FakeTextMessage(2)));
          await Future.delayed(const Duration(milliseconds: 20));
          bloc.add(MessageReceived(FakeTextMessage(3)));
          await Future.delayed(const Duration(milliseconds: 20));
          bloc.add(MessageReceived(FakeTextMessage(4)));
        },
        verify: (bloc) {
          expect(bloc.state.messages.length, 4);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'MessageReceived is ignored when state is initial (not loaded)',
        build: () => _makeBloc(repo),
        act: (bloc) {
          bloc.add(MessageReceived(FakeTextMessage(1)));
        },
        verify: (bloc) {
          expect(bloc.state.status, MessageListStatus.initial);
          expect(bloc.state.messages, isEmpty);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'MessageSentByUser adds message to list',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          // Production dispatches the enum's toString(), and a new message
          // enters the list on `inProgress`; `sent` then updates that pending
          // entry in place. This test used to send the bare string 'sent',
          // which matches neither branch, and expect an insert.
          // As in production: the pending copy has no server id yet, and the
          // copy the SDK returns carries one, matched back to it by muid.
          bloc.add(
            MessageSentByUser(
              message: FakeTextMessage(0, muid: 'muid_2'),
              status: core_enums.MessageStatus.inProgress.toString(),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 20));
          bloc.add(
            MessageSentByUser(
              message: FakeTextMessage(2, muid: 'muid_2'),
              status: core_enums.MessageStatus.sent.toString(),
            ),
          );
        },
        verify: (bloc) {
          // Inserted once on inProgress, not duplicated on sent, and the
          // server copy (id 2) takes the pending entry's place.
          expect(bloc.state.messages.map((m) => m.id).toList(), [1, 2]);
        },
      );
    });

    // =====================================================================
    // Refresh
    // =====================================================================

    group('Refresh Messages', () {
      blocTest<MessageListBloc, MessageListState>(
        'RefreshMessages reloads messages without loading state',
        build: () {
          final msgs = [FakeTextMessage(1)];
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
          return _makeBloc(repo);
        },
        act: (bloc) async {
          bloc.add(
            const LoadMessages(
              conversationWith: 'test_user',
              conversationType: 'user',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const RefreshMessages());
        },
        verify: (bloc) {
          expect(bloc.state.status, MessageListStatus.loaded);
        },
      );
    });

    // =====================================================================
    // ValueNotifier Interactions
    // =====================================================================

    group('ValueNotifier Interactions', () {
      test('getReceiptNotifier returns consistent notifier for same ID', () {
        final bloc = _makeBloc(repo);
        final notifier1 = bloc.getReceiptNotifier(42);
        final notifier2 = bloc.getReceiptNotifier(42);
        expect(identical(notifier1, notifier2), isTrue);
        bloc.close();
      });

      test(
        'getReceiptNotifier returns different notifiers for different IDs',
        () {
          final bloc = _makeBloc(repo);
          final notifier1 = bloc.getReceiptNotifier(1);
          final notifier2 = bloc.getReceiptNotifier(2);
          expect(identical(notifier1, notifier2), isFalse);
          bloc.close();
        },
      );

      test(
        'getTypingNotifier returns consistent notifier for same conversation',
        () {
          final bloc = _makeBloc(repo);
          final notifier1 = bloc.getTypingNotifier('user_test');
          final notifier2 = bloc.getTypingNotifier('user_test');
          expect(identical(notifier1, notifier2), isTrue);
          expect(notifier1.value, isEmpty);
          bloc.close();
        },
      );

      test('getThreadReplyCountNotifier returns consistent notifier', () {
        final bloc = _makeBloc(repo);
        final notifier1 = bloc.getThreadReplyCountNotifier(100);
        final notifier2 = bloc.getThreadReplyCountNotifier(100);
        expect(identical(notifier1, notifier2), isTrue);
        expect(notifier1.value, 0);
        bloc.close();
      });

      test('initializeThreadReplyCount sets value on notifier', () {
        final bloc = _makeBloc(repo);
        bloc.initializeThreadReplyCount(42, 7);
        expect(bloc.getThreadReplyCount(42), 7);
        bloc.close();
      });
    });

    // =====================================================================
    // O(1) Lookup
    // =====================================================================

    group('O(1) Lookup', () {
      blocTest<MessageListBloc, MessageListState>(
        'findMessageIndex returns correct index after load',
        build: () {
          final msgs = [
            FakeTextMessage(10),
            FakeTextMessage(20),
            FakeTextMessage(30),
          ];
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
          return _makeBloc(repo);
        },
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        verify: (bloc) {
          expect(bloc.findMessageIndex(10), 0);
          expect(bloc.findMessageIndex(20), 1);
          expect(bloc.findMessageIndex(30), 2);
          expect(bloc.findMessageIndex(999), isNull);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'findMessage returns message by ID',
        build: () {
          final msgs = [FakeTextMessage(10), FakeTextMessage(20)];
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
          return _makeBloc(repo);
        },
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        verify: (bloc) {
          expect(bloc.findMessage(10)?.id, 10);
          expect(bloc.findMessage(999), isNull);
        },
      );
    });
  });
}
