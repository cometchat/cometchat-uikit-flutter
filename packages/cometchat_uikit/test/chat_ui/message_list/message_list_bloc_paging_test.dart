/// MessageListBloc / AnimatedMessageListBloc — the paging flags and the
/// pin-vs-save scope rule. Track 3 TEST3 (ENG-38684).
///
/// `message_list_bloc.dart` sat at 44.5% line / 30.2% branch. The three
/// existing suites cover loading, real-time receive/edit/delete and most of
/// the event surface; this covers what they left:
///
///   * the animated bloc's four paging flags, which nothing constructed,
///   * `MessagePinSaveChanged`, which nothing dispatched at all.
///
/// The pin/save rule is the reason this file exists. A pin event carries no
/// save state and a save event carries no pin state, so each one has to
/// preserve the other's field off the row it is replacing. `isPinScope` names
/// which of the two arrived — it is NOT "is now pinned", which is the reading
/// that makes `onMessageUnpinned` passing `true` look like a bug. Both
/// pin and unpin pass `true` because both are pin-scope events. Tests below
/// pin that, so the "obvious fix" fails loudly.
///
///   flutter test test/chat_ui/message_list/message_list_bloc_paging_test.dart
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

class FakeBase extends Fake implements BaseMessage {
  @override
  int get id => 0;
}

class FakeMessagesRequest extends Fake implements MessagesRequest {}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_test_user';
  @override
  int get unreadMessageCount => 0;
  @override
  int? get lastReadMessageId => 1;
}

/// A message whose pin and save marks are readable and writable, which is the
/// whole subject of the scope tests below.
class MarkableMsg extends Fake implements TextMessage {
  MarkableMsg(this._id, {this.pinnedAt, this.pinnedBy, this.savedAt});

  final int _id;

  @override
  DateTime? pinnedAt;
  @override
  String? pinnedBy;
  @override
  DateTime? savedAt;

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
  DateTime? get sentAt => DateTime(2026, 1, 1);
  @override
  DateTime? get deletedAt => null;
  @override
  List<ReactionCount> get reactions => const [];
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  int get quotedMessageId => 0;
  @override
  set quotedMessageId(int v) {}
  // Fake throws UnimplementedError for anything not overridden, and the edit
  // path this event funnels through reads the reply counters.
  @override
  int get replyCount => 0;
  @override
  int get unreadRepliesCount => 0;
  @override
  List<User> get mentionedUsers => const [];
  @override
  User? get sender => FakeUser();
  @override
  DateTime? get editedAt => null;
  @override
  DateTime? get readAt => null;
  @override
  DateTime? get deliveredAt => null;
  @override
  ModerationStatusEnum? get moderationStatus => null;
  @override
  String? get deletedBy => null;
  @override
  BaseMessage? quotedMessage;
}

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

  // ==========================================================================
  // The four paging flags live on the animated bloc. Nothing constructed them.
  group('AnimatedMessageListBloc — paging flags', () {
    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetLoadingOlder toggles isLoadingOlder and nothing else',
      build: makeAnimated,
      act: (bloc) => bloc.add(const SetLoadingOlder(true)),
      expect: () => [
        isA<AnimatedMessageListState>()
            .having((s) => s.isLoadingOlder, 'isLoadingOlder', true)
            .having((s) => s.isLoadingNewer, 'isLoadingNewer', false),
      ],
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetLoadingNewer toggles isLoadingNewer and nothing else',
      build: makeAnimated,
      act: (bloc) => bloc.add(const SetLoadingNewer(true)),
      expect: () => [
        isA<AnimatedMessageListState>()
            .having((s) => s.isLoadingNewer, 'isLoadingNewer', true)
            .having((s) => s.isLoadingOlder, 'isLoadingOlder', false),
      ],
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetHasMoreOlder carries the flag through',
      build: makeAnimated,
      act: (bloc) => bloc.add(const SetHasMoreOlder(false)),
      expect: () => [
        isA<AnimatedMessageListState>().having(
          (s) => s.hasMoreOlder,
          'hasMoreOlder',
          false,
        ),
      ],
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'SetHasMoreNewer carries the flag through',
      build: makeAnimated,
      act: (bloc) => bloc.add(const SetHasMoreNewer(true)),
      expect: () => [
        isA<AnimatedMessageListState>().having(
          (s) => s.hasMoreNewer,
          'hasMoreNewer',
          true,
        ),
      ],
    );

    blocTest<AnimatedMessageListBloc, AnimatedMessageListState>(
      'the two loading flags are independent, not one flag in disguise',
      build: makeAnimated,
      act: (bloc) => bloc
        ..add(const SetLoadingOlder(true))
        ..add(const SetLoadingNewer(true))
        ..add(const SetLoadingOlder(false)),
      expect: () => [
        isA<AnimatedMessageListState>().having(
          (s) => s.isLoadingOlder,
          'older',
          true,
        ),
        isA<AnimatedMessageListState>().having(
          (s) => s.isLoadingNewer,
          'newer',
          true,
        ),
        isA<AnimatedMessageListState>()
            .having((s) => s.isLoadingOlder, 'older', false)
            .having((s) => s.isLoadingNewer, 'newer', true),
      ],
    );
  });

  // ==========================================================================
  group('MessagePinSaveChanged — scope preserves the other mark', () {
    late MockMessageListRepository repo;

    setUp(() => repo = MockMessageListRepository());

    blocTest<MessageListBloc, MessageListState>(
      'a pin event keeps the save mark the row already had',
      build: () {
        // The row on screen is saved but not pinned.
        seed(repo, [MarkableMsg(1, savedAt: DateTime(2026, 5, 1))]);
        return makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        // A pin arrives. It carries pinnedAt but knows nothing about saves.
        bloc.add(
          MessagePinSaveChanged(
            MarkableMsg(1, pinnedAt: DateTime(2026, 5, 2), pinnedBy: 'u9'),
            isPinScope: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        final row = bloc.state.messages.firstWhere((m) => m.id == 1);
        expect(row.pinnedAt, isNotNull, reason: 'the pin should have landed');
        expect(
          row.savedAt,
          isNotNull,
          reason: 'a pin event must not wipe the save mark',
        );
      },
    );

    blocTest<MessageListBloc, MessageListState>(
      'a save event keeps the pin mark the row already had',
      build: () {
        seed(repo, [
          MarkableMsg(1, pinnedAt: DateTime(2026, 5, 1), pinnedBy: 'u9'),
        ]);
        return makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        bloc.add(
          MessagePinSaveChanged(
            MarkableMsg(1, savedAt: DateTime(2026, 5, 2)),
            isPinScope: false,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        final row = bloc.state.messages.firstWhere((m) => m.id == 1);
        expect(row.savedAt, isNotNull, reason: 'the save should have landed');
        expect(
          row.pinnedAt,
          isNotNull,
          reason: 'a save event must not wipe the pin mark',
        );
        expect(row.pinnedBy, 'u9', reason: 'pinnedBy is preserved too');
      },
    );

    blocTest<MessageListBloc, MessageListState>(
      'an event for a message not in the list is a no-op, not a crash',
      build: () {
        seed(repo, [MarkableMsg(1)]);
        return makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(_load);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        bloc.add(
          MessagePinSaveChanged(
            MarkableMsg(4242, pinnedAt: DateTime(2026, 5, 2)),
            isPinScope: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        expect(bloc.state.messages.length, 1);
        expect(bloc.state.messages.single.id, 1);
      },
    );
  });
}
