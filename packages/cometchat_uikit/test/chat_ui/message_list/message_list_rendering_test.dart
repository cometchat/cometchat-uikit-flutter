import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart'
    show CometChatUIKit;
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

class FakeTextMessage extends Fake implements TextMessage {
  final int _id;
  final String _muid;

  FakeTextMessage(this._id, {String? muid}) : _muid = muid ?? 'muid_$_id';

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
  BaseMessage? get quotedMessage => null;

  @override
  String get text => 'hello';

  @override
  List<ReactionCount> get reactions => [];

  @override
  Map<String, dynamic>? get metadata => null;
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

  // Read on load once a logged-in user is known (the unread anchor).
  @override
  int? get lastReadMessageId => null;
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

  group('MessageList Rendering Tests', () {
    late MockMessageListRepository repo;

    setUp(() {
      repo = MockMessageListRepository();
      _stubDefaults(repo);
    });

    // =====================================================================
    // State Transitions: Initial → Loading → Loaded
    // =====================================================================

    group('Initial → Loading → Loaded', () {
      test('initial state has status initial and empty messages', () {
        final bloc = _makeBloc(repo);
        expect(bloc.state.status, MessageListStatus.initial);
        expect(bloc.state.messages, isEmpty);
        expect(bloc.state.isLoadingOlder, isFalse);
        expect(bloc.state.isLoadingNewer, isFalse);
        expect(bloc.state.hasMoreOlder, isTrue);
        expect(bloc.state.hasMoreNewer, isFalse);
        expect(bloc.state.errorMessage, isNull);
        bloc.close();
      });

      blocTest<MessageListBloc, MessageListState>(
        'emits [loading, loaded] when messages are returned',
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
          return _makeBloc(repo);
        },
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        expect: () => [
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.loading,
          ),
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.loaded,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.messages.length, 3);
          expect(bloc.state.errorMessage, isNull);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'loaded state contains correct message count',
        build: () {
          final msgs = List.generate(15, (i) => FakeTextMessage(i + 1));
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
          expect(bloc.state.messageCount, 15);
          expect(bloc.state.isNotEmpty, isTrue);
          expect(bloc.state.isEmpty, isFalse);
        },
      );
    });

    // =====================================================================
    // State Transitions: Initial → Loading → Empty
    // =====================================================================

    group('Initial → Loading → Empty', () {
      blocTest<MessageListBloc, MessageListState>(
        'emits [loading, empty] when no messages returned',
        build: () => _makeBloc(repo),
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        expect: () => [
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.loading,
          ),
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.empty,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.messages, isEmpty);
          expect(bloc.state.messageCount, 0);
          expect(bloc.state.isEmpty, isTrue);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'ForceEmptyState transitions directly to empty without loading',
        build: () => _makeBloc(repo),
        act: (bloc) => bloc.add(const ForceEmptyState()),
        expect: () => [
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.empty,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.messages, isEmpty);
        },
      );
    });

    // =====================================================================
    // State Transitions: Initial → Loading → Error
    // =====================================================================

    group('Initial → Loading → Error', () {
      blocTest<MessageListBloc, MessageListState>(
        'emits [loading, error] when repository returns failure',
        build: () {
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
          ).thenAnswer(
            (_) async =>
                const Failure(message: 'Network error', code: 'NET_ERR'),
          );
          return _makeBloc(repo);
        },
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        expect: () => [
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.loading,
          ),
          isA<MessageListState>().having(
            (s) => s.status,
            'status',
            MessageListStatus.error,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.errorMessage, 'Network error');
          expect(bloc.state.messages, isEmpty);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'error state preserves error message',
        build: () {
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
          ).thenAnswer(
            (_) async =>
                const Failure(message: 'Server timeout', code: 'TIMEOUT'),
          );
          return _makeBloc(repo);
        },
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.status, MessageListStatus.error);
          expect(bloc.state.errorMessage, 'Server timeout');
        },
      );
    });

    // =====================================================================
    // Content State — Messages with various properties
    // =====================================================================

    group('Content States', () {
      blocTest<MessageListBloc, MessageListState>(
        'loaded state has hasMoreOlder=true when full page returned',
        build: () {
          // 30 messages = full page → hasMoreOlder should be true
          final msgs = List.generate(30, (i) => FakeTextMessage(i + 1));
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
          expect(bloc.state.hasMoreOlder, isTrue);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'loaded state has hasMoreOlder=false when partial page returned',
        build: () {
          // Less than limit → no more older messages
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
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.hasMoreOlder, isFalse);
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'state tracks activeConversationId',
        build: () => _makeBloc(repo),
        act: (bloc) => bloc.add(const SetActiveConversation('user_test_user')),
        verify: (bloc) {
          expect(bloc.state.activeConversationId, 'user_test_user');
        },
      );

      blocTest<MessageListBloc, MessageListState>(
        'state tracks loggedInUser after load',
        build: () {
          // The bloc takes the logged-in user from the UIKit-level cache, not
          // the injected getLoggedInUserUseCase: ENG-34111 swapped them to
          // avoid a platform-channel call per load (see _onLoadMessages).
          // Seed that cache directly, and restore it afterwards.
          final previous = CometChatUIKit.loggedInUser;
          CometChatUIKit.loggedInUser = FakeUser();
          addTearDown(() => CometChatUIKit.loggedInUser = previous);
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
        act: (bloc) => bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.loggedInUser, isNotNull);
          expect(bloc.state.loggedInUser?.uid, 'test_user');
        },
      );
    });

    // =====================================================================
    // State Equatable — copyWith behavior
    // =====================================================================

    group('MessageListState copyWith', () {
      test('copyWith preserves unchanged fields', () {
        const state = MessageListState(
          status: MessageListStatus.loaded,
          errorMessage: 'test error',
          hasMoreOlder: false,
        );
        final copied = state.copyWith(status: MessageListStatus.error);
        expect(copied.status, MessageListStatus.error);
        expect(copied.errorMessage, 'test error');
        expect(copied.hasMoreOlder, isFalse);
      });

      test('copyWith replaces specified fields', () {
        const state = MessageListState(
          status: MessageListStatus.initial,
          unreadCount: 5,
        );
        final copied = state.copyWith(
          status: MessageListStatus.loaded,
          unreadCount: 10,
        );
        expect(copied.status, MessageListStatus.loaded);
        expect(copied.unreadCount, 10);
      });

      test('copyWithCleared clears nullable fields', () {
        const state = MessageListState(
          status: MessageListStatus.loaded,
          errorMessage: 'some error',
          activeConversationId: 'user_abc',
          unreadCount: 3,
          markedAsUnreadInSession: true,
        );
        final cleared = state.copyWithCleared(
          clearErrorMessage: true,
          clearActiveConversationId: true,
          clearUnreadState: true,
        );
        expect(cleared.errorMessage, isNull);
        expect(cleared.activeConversationId, isNull);
        expect(cleared.unreadCount, 0);
        expect(cleared.markedAsUnreadInSession, isFalse);
      });

      test('MessageListState props includes all fields for equality', () {
        const state1 = MessageListState(
          status: MessageListStatus.loaded,
          unreadCount: 5,
        );
        const state2 = MessageListState(
          status: MessageListStatus.loaded,
          unreadCount: 5,
        );
        const state3 = MessageListState(
          status: MessageListStatus.loaded,
          unreadCount: 10,
        );
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('MessageListState toString includes key fields', () {
        const state = MessageListState(
          status: MessageListStatus.loaded,
          unreadCount: 3,
        );
        final str = state.toString();
        expect(str, contains('MessageListState'));
        expect(str, contains('loaded'));
        expect(str, contains('unreadCount: 3'));
      });
    });

    // =====================================================================
    // Unread State
    // =====================================================================

    group('Unread State', () {
      blocTest<MessageListBloc, MessageListState>(
        'ResetUnreadState clears unread anchor and count',
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
          bloc.add(const ResetUnreadState());
        },
        verify: (bloc) {
          expect(bloc.state.unreadMessageAnchor, isNull);
          expect(bloc.state.unreadMessageAnchorId, isNull);
          expect(bloc.state.unreadCount, 0);
          expect(bloc.state.markedAsUnreadInSession, isFalse);
          expect(bloc.state.newUnreadMessageCount, 0);
        },
      );
    });

    // =====================================================================
    // Computed Properties
    // =====================================================================

    group('Computed Properties', () {
      test('conversationId returns user_uid for user conversations', () {
        final bloc = _makeBloc(repo);
        expect(bloc.conversationId, 'user_test_user');
        bloc.close();
      });

      test('conversationType returns user for user conversations', () {
        final bloc = _makeBloc(repo);
        expect(bloc.conversationType, 'user');
        bloc.close();
      });

      test('conversationWith returns uid for user conversations', () {
        final bloc = _makeBloc(repo);
        expect(bloc.conversationWith, 'test_user');
        bloc.close();
      });

      test('conversationId returns group_guid for group conversations', () {
        final bloc = MessageListBloc(
          getMessagesUseCase: GetMessagesUseCase(repo),
          loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
          loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
          markAsReadUseCase: MarkAsReadUseCase(repo),
          markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
          markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
          getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
          group: FakeGroup(),
          disableSDKListeners: true,
        );
        expect(bloc.conversationId, 'group_test_group');
        expect(bloc.conversationType, 'group');
        expect(bloc.conversationWith, 'test_group');
        bloc.close();
      });
    });
  });
}

class FakeGroup extends Fake implements Group {
  @override
  String get guid => 'test_group';
}
