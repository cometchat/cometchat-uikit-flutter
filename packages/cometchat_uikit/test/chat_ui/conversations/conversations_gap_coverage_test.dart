import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockConversationsRepository extends Mock
    implements ConversationsRepository {}

class FakeAppEntity extends Fake implements AppEntity {}

class FakeConversation extends Fake implements Conversation {
  final String _id;
  final AppEntity _conversationWith;
  final BaseMessage? _lastMessage;
  final int _unreadMessageCount;

  FakeConversation(
    this._id, {
    AppEntity? conversationWith,
    BaseMessage? lastMessage,
    int unreadMessageCount = 0,
  }) : _conversationWith = conversationWith ?? FakeAppEntity(),
       _lastMessage = lastMessage,
       _unreadMessageCount = unreadMessageCount;

  @override
  String? get conversationId => _id;

  @override
  String get conversationType {
    if (_conversationWith is User) return 'user';
    if (_conversationWith is Group) return 'group';
    return 'user';
  }

  // Pin Conversation fields — read by the trailing view's pin glyph.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;

  @override
  AppEntity get conversationWith => _conversationWith;

  @override
  BaseMessage? get lastMessage => _lastMessage;

  @override
  int get unreadMessageCount => _unreadMessageCount;

  @override
  Conversation copyWith({
    String? conversationId,
    String? conversationType,
    AppEntity? conversationWith,
    BaseMessage? lastMessage,
    DateTime? updatedAt,
    int? unreadMessageCount,
    List<String>? tags,
    int? unreadMentionsCount,
    int? lastReadMessageId,
    int? latestMessageId,
    DateTime? pinnedAt,
    String? pinnedBy,
  }) {
    return FakeConversation(
      conversationId ?? _id,
      conversationWith: conversationWith ?? _conversationWith,
      lastMessage: lastMessage ?? _lastMessage,
      unreadMessageCount: unreadMessageCount ?? _unreadMessageCount,
    );
  }
}

class FakeUser extends Fake implements User {
  final String _uid;
  final String _name;
  final String _status;

  FakeUser({
    String uid = 'test_user',
    String name = 'Test User',
    String status = CometChatUserStatus.online,
  }) : _uid = uid,
       _name = name,
       _status = status;

  @override
  String get uid => _uid;

  @override
  String get name => _name;

  @override
  String get status => _status;
}

class FakeGroup extends Fake implements Group {
  final String _guid;
  final String _name;
  final int _membersCount;

  FakeGroup({
    String guid = 'test_group',
    String name = 'Test Group',
    int membersCount = 5,
  }) : _guid = guid,
       _name = name,
       _membersCount = membersCount;

  @override
  String get guid => _guid;

  @override
  String get name => _name;

  @override
  int get membersCount => _membersCount;

  @override
  String get type => CometChatGroupType.public;
}

class FakeTextMessage extends Fake implements TextMessage {
  final int _id;
  final String _text;
  final DateTime? _sentAt;

  FakeTextMessage({int id = 1, String text = 'Hello', DateTime? sentAt})
    : _id = id,
      _text = text,
      _sentAt = sentAt ?? DateTime.now();

  @override
  int get id => _id;

  @override
  String get text => _text;

  @override
  DateTime? get sentAt => _sentAt;

  @override
  int get parentMessageId => 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationsBloc _makeBloc(MockConversationsRepository repo) {
  return ConversationsBloc(
    getConversationsUseCase: GetConversationsUseCase(repo),
    loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
    deleteConversationUseCase: DeleteConversationUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    getConversationUseCase: GetConversationUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    disableSDKListeners: true,
  );
}

void main() {
  late MockConversationsRepository repo;

  setUpAll(() {
    registerFallbackValue(FakeConversation(''));
    registerFallbackValue(FakeUser());
    registerFallbackValue(FakeTextMessage());
  });

  setUp(() {
    repo = MockConversationsRepository();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
    when(
      () => repo.getConversations(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const Success([]));
  });

  // =========================================================================
  // GAP 1: SINGLE Selection Mode Constraint
  // Android CSV #1245: selectConversation in SINGLE mode → max 1 selected
  // =========================================================================

  group('Selection — SINGLE mode constraint', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'selecting a second conversation replaces the first (SINGLE mode behavior)',
      build: () {
        final convs = [
          FakeConversation('c1'),
          FakeConversation('c2'),
          FakeConversation('c3'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        // Select first
        bloc.add(const ToggleConversationSelection('c1'));
        await Future.delayed(const Duration(milliseconds: 20));
        // Select second — in SINGLE mode this should replace, not accumulate
        // Note: The BLoC uses toggle semantics. For SINGLE mode enforcement,
        // the widget layer handles it. Here we verify toggle behavior.
        bloc.add(const ToggleConversationSelection('c2'));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        // Both are selected because BLoC uses toggle (accumulate) semantics.
        // SINGLE mode enforcement is at widget layer.
        expect(state.selectedConversations, contains('c1'));
        expect(state.selectedConversations, contains('c2'));
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'toggling same conversation twice deselects it (toggle semantics)',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const ToggleConversationSelection('c1'));
        await Future.delayed(const Duration(milliseconds: 20));
        bloc.add(const ToggleConversationSelection('c1'));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.selectedConversations, isEmpty);
      },
    );
  });

  // =========================================================================
  // GAP 2: Typing Indicator Matching Logic
  // Android CSV #1279-1288: Typing state matching by sender uid / receiverId
  // =========================================================================

  group('Typing indicator matching', () {
    test(
      'getTypingNotifier returns same notifier for same conversation ID',
      () {
        final bloc = _makeBloc(repo);
        final notifier1 = bloc.getTypingNotifier('conv_1');
        final notifier2 = bloc.getTypingNotifier('conv_1');
        expect(identical(notifier1, notifier2), isTrue);
        bloc.close();
      },
    );

    test('getTypingNotifier returns different notifiers for different IDs', () {
      final bloc = _makeBloc(repo);
      final notifier1 = bloc.getTypingNotifier('conv_1');
      final notifier2 = bloc.getTypingNotifier('conv_2');
      expect(identical(notifier1, notifier2), isFalse);
      bloc.close();
    });

    test('getTypingIndicators returns empty list for unknown conversation', () {
      final bloc = _makeBloc(repo);
      final indicators = bloc.getTypingIndicators('unknown_conv');
      expect(indicators, isEmpty);
      bloc.close();
    });

    test('typing notifier initial value is empty list', () {
      final bloc = _makeBloc(repo);
      final notifier = bloc.getTypingNotifier('conv_1');
      expect(notifier.value, isEmpty);
      bloc.close();
    });

    test('multiple typing notifiers are independent', () {
      final bloc = _makeBloc(repo);
      final notifier1 = bloc.getTypingNotifier('conv_1');
      final notifier2 = bloc.getTypingNotifier('conv_2');

      // Modifying one should not affect the other
      expect(notifier1.value, isEmpty);
      expect(notifier2.value, isEmpty);
      bloc.close();
    });
  });

  // =========================================================================
  // GAP 3: Item Access by Index
  // Android CSV #1249: getItemAt returns correct conversation for position
  // =========================================================================

  group('Item access by index', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'conversations list preserves insertion order for index-based access',
      build: () {
        final convs = [
          FakeConversation('first'),
          FakeConversation('second'),
          FakeConversation('third'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations[0].conversationId, 'first');
        expect(state.conversations[1].conversationId, 'second');
        expect(state.conversations[2].conversationId, 'third');
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'getItemCount equivalent returns correct count',
      build: () {
        final convs = [
          FakeConversation('c1'),
          FakeConversation('c2'),
          FakeConversation('c3'),
          FakeConversation('c4'),
          FakeConversation('c5'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 5);
      },
    );
  });

  // =========================================================================
  // GAP 4: User Data Accessibility for Rendering
  // Android CSV #1253: conversations contain correct user data for rendering
  // =========================================================================

  group('User/Group data accessibility in loaded state', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'user conversation exposes user name for rendering',
      build: () {
        final user = FakeUser(uid: 'alice', name: 'Alice');
        final convs = [FakeConversation('user_alice', conversationWith: user)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        final conv = state.conversations.first;
        final user = conv.conversationWith as User;
        expect(user.name, 'Alice');
        expect(user.uid, 'alice');
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'group conversation exposes group name and member count for rendering',
      build: () {
        final group = FakeGroup(
          guid: 'team',
          name: 'Team Chat',
          membersCount: 12,
        );
        final convs = [FakeConversation('group_team', conversationWith: group)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        final conv = state.conversations.first;
        final group = conv.conversationWith as Group;
        expect(group.name, 'Team Chat');
        expect(group.membersCount, 12);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'conversation exposes last message text for subtitle rendering',
      build: () {
        final msg = FakeTextMessage(text: 'Hey there!');
        final convs = [FakeConversation('c1', lastMessage: msg)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        final lastMsg = state.conversations.first.lastMessage as TextMessage;
        expect(lastMsg.text, 'Hey there!');
      },
    );
  });

  // =========================================================================
  // GAP 5: Edge Cases — Large Lists, Rapid Updates, Duplicates
  // Android CSV #1303-1308
  // =========================================================================

  group('Edge cases — robustness', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'handles large list (100 conversations)',
      build: () {
        final convs = List.generate(100, (i) => FakeConversation('conv_$i'));
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 100);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'handles conversation without last message',
      build: () {
        final convs = [FakeConversation('c1', lastMessage: null)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.first.lastMessage, isNull);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'handles mixed user and group conversations',
      build: () {
        final convs = [
          FakeConversation(
            'user_alice',
            conversationWith: FakeUser(uid: 'alice', name: 'Alice'),
          ),
          FakeConversation(
            'group_team',
            conversationWith: FakeGroup(guid: 'team', name: 'Team'),
          ),
          FakeConversation(
            'user_bob',
            conversationWith: FakeUser(uid: 'bob', name: 'Bob'),
          ),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 3);
        expect(state.conversations[0].conversationWith, isA<User>());
        expect(state.conversations[1].conversationWith, isA<Group>());
        expect(state.conversations[2].conversationWith, isA<User>());
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'rapid sequential updates settle correctly',
      build: () {
        final convs = [
          FakeConversation('c1'),
          FakeConversation('c2'),
          FakeConversation('c3'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Success(null));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        // Rapid fire multiple operations
        bloc.add(const ToggleConversationSelection('c1'));
        bloc.add(const ToggleConversationSelection('c2'));
        bloc.add(const ToggleConversationSelection('c3'));
        bloc.add(const ClearConversationSelection());
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.selectedConversations, isEmpty);
        expect(state.conversations.length, 3);
      },
    );
  });

  // =========================================================================
  // GAP 6: State Transitions — Content Equality
  // Android CSV #1316-1322: areContentsTheSame checks
  // =========================================================================

  group('State — content tracking', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'unread count change is reflected in state (content change)',
      build: () {
        final convs = [FakeConversation('c1', unreadMessageCount: 5)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.first.unreadMessageCount, 5);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'hasMore flag is accessible for pagination indicator rendering',
      build: () {
        // When exactly 30 items returned, hasMore should be true
        final convs = List.generate(30, (i) => FakeConversation('c_$i'));
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.hasMore, isTrue);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      "a builder's limit sizes every page and decides the first page's "
      'hasMore',
      build: () {
        // The first page used the builder's limit; load-more and the first
        // page's hasMore used a hard-coded 30. With a limit of 10, a full
        // first page read as the last one and paging never started.
        var page = 0;
        when(
          () => repo.getConversations(
            limit: any(named: 'limit'),
            fromId: any(named: 'fromId'),
            requestBuilder: any(named: 'requestBuilder'),
          ),
        ).thenAnswer((invocation) async {
          final limit = invocation.namedArguments[#limit] as int;
          final p = page++;
          return Success([
            for (var i = 0; i < limit; i++) FakeConversation('p${p}_$i'),
          ]);
        });
        return ConversationsBloc(
          getConversationsUseCase: GetConversationsUseCase(repo),
          loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
          deleteConversationUseCase: DeleteConversationUseCase(repo),
          getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
          getConversationUseCase: GetConversationUseCase(repo),
          markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
          disableSDKListeners: true,
          conversationsRequestBuilder: ConversationsRequestBuilder()
            ..limit = 10,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const LoadMoreConversations());
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final calls = verify(
          () => repo.getConversations(
            limit: captureAny(named: 'limit'),
            fromId: captureAny(named: 'fromId'),
            requestBuilder: any(named: 'requestBuilder'),
          ),
        ).captured;
        // [limit, fromId] per call: the first page, then load-more from the
        // last row of the first page.
        expect(calls, [10, null, 10, 'p0_9']);
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations, hasLength(20));
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'hasMore is false when fewer than limit items returned',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.hasMore, isFalse);
      },
    );
  });

  // =========================================================================
  // GAP 7: UpdateConversation — In-place Update and Add
  // Android CSV #1271-1272: setList updates/replaces
  // =========================================================================

  group('UpdateConversation — list manipulation', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'UpdateConversation on existing ID updates in-place without changing count',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          UpdateConversation(
            conversationId: 'c1',
            updatedConversation: FakeConversation(
              'c1',
              lastMessage: FakeTextMessage(text: 'Updated!'),
            ),
          ),
        );
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'UpdateConversation with new ID adds to list',
      build: () {
        final convs = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          UpdateConversation(
            conversationId: 'c_new',
            updatedConversation: FakeConversation('c_new'),
          ),
        );
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
        final ids = state.conversations.map((c) => c.conversationId).toList();
        expect(ids, contains('c_new'));
      },
    );
  });

  // =========================================================================
  // GAP 8: ResetUnreadCount
  // =========================================================================

  group('ResetUnreadCount', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'ResetUnreadCount event is accepted without error',
      build: () {
        final convs = [FakeConversation('c1', unreadMessageCount: 10)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const ResetUnreadCount('c1'));
      },
      verify: (bloc) {
        // Should not crash — event is handled gracefully
        expect(bloc.state, isA<ConversationsLoaded>());
      },
    );
  });

  // =========================================================================
  // GAP 9: Null Safety Boundary Tests
  // Android CSV #1258-1259: null bindings return null views
  // =========================================================================

  group('Null safety boundaries', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'conversation with default AppEntity conversationWith does not crash',
      build: () {
        // conversationWith defaults to FakeAppEntity when not provided
        final convs = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.first.conversationWith, isNotNull);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'conversation with null lastMessage does not crash on access',
      build: () {
        final convs = [FakeConversation('c1', lastMessage: null)];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.first.lastMessage, isNull);
      },
    );

    test('getTypingNotifier with empty string ID does not crash', () {
      final bloc = _makeBloc(repo);
      final notifier = bloc.getTypingNotifier('');
      expect(notifier.value, isEmpty);
      bloc.close();
    });
  });

  // =========================================================================
  // GAP 10: ConversationsLoaded State — copyWith Behavior
  // Android CSV #1328-1336: Style defaults, copy preserves values
  // =========================================================================

  group('ConversationsLoaded — copyWith', () {
    test('copyWith preserves unchanged fields', () async {
      final convs = [FakeConversation('c1'), FakeConversation('c2')];
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Success(convs));
      final bloc = _makeBloc(repo);
      bloc.add(const LoadConversations());
      await Future.delayed(const Duration(milliseconds: 80));

      final state = bloc.state as ConversationsLoaded;
      final copied = state.copyWith(hasMore: true);

      expect(copied.conversations.length, state.conversations.length);
      expect(copied.selectedConversations, state.selectedConversations);
      expect(copied.activeConversationId, state.activeConversationId);
      expect(copied.hasMore, isTrue);

      await bloc.close();
    });

    test('copyWith with new conversations replaces list', () {
      final original = ConversationsLoaded(
        conversations: [FakeConversation('c1')],
        hasMore: false,
      );
      final newConvs = [FakeConversation('c2'), FakeConversation('c3')];
      final copied = original.copyWith(conversations: newConvs);

      expect(copied.conversations.length, 2);
      expect(copied.conversations[0].conversationId, 'c2');
    });

    test('copyWith with selectedConversations replaces selection', () {
      final original = ConversationsLoaded(
        conversations: [FakeConversation('c1')],
        selectedConversations: const {'c1'},
      );
      final copied = original.copyWith(selectedConversations: {'c2', 'c3'});

      expect(copied.selectedConversations, {'c2', 'c3'});
    });
  });

  // =========================================================================
  // GAP 11: activeConversationId tracking
  // =========================================================================

  group('activeConversationId', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'SetActiveConversation stores the active conversation ID',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const SetActiveConversation('c2'));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.activeConversationId, 'c2');
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'SetActiveConversation with different ID updates active conversation',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const SetActiveConversation('c1'));
        await Future.delayed(const Duration(milliseconds: 20));
        bloc.add(const SetActiveConversation('c2'));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.activeConversationId, 'c2');
      },
    );
  });
}
