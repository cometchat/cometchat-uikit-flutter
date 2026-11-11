/// ENG-38584: CometChatConversationEvents.ccUpdateConversation must merge the
/// supplied conversation into the list, not only its unread count and last
/// message.
///
/// The event takes a whole Conversation, but the conversations bloc kept only
/// `unreadMessageCount` and `lastMessage`, so a refreshed Group (for example
/// with new metadata) never reached CometChatConversations.
///
/// Expected merge (same as Android, ENG-38583, uikit-android#893 and #897):
/// non-null reference fields (`conversationWith`, `lastMessage`, `tags`) are
/// taken, absent ones keep the existing value; counters and ids
/// (`unreadMessageCount`, `unreadMentionsCount`, `lastReadMessageId`,
/// `latestMessageId`) are taken; `updatedAt` is taken when set. A conversation
/// with a different conversationId is untouched.
///
///   flutter test test/chat_ui/conversations/regression/eng_38584_regression_test.dart
library;

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
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatConversationEvents;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConversationsRepository extends Mock
    implements ConversationsRepository {}

final _me = User(uid: 'me', name: 'Me');

const _groupConversationId = 'group_guid-1';
const _userConversationId = 'me_user_uid-2';

Group _group(String marker) => Group(
  guid: 'guid-1',
  name: 'Group One',
  type: 'public',
  metadata: {'marker': marker},
);

TextMessage _text(int id, String text, AppEntity receiver) => TextMessage(
  id: id,
  text: text,
  receiver: receiver,
  receiverUid: receiver is Group ? receiver.guid : (receiver as User).uid,
  receiverType: receiver is Group ? 'group' : 'user',
  type: 'text',
  category: 'message',
  sender: _me,
  sentAt: DateTime(2026, 10, 1, 10),
);

final _existingGroupLastMessage = _text(100, 'hello group', _group('old'));
final _existingUserLastMessage = _text(
  200,
  'hello user',
  User(uid: 'uid-2', name: 'uid-2'),
);

/// The group conversation as the server returned it when the list loaded.
Conversation _loadedGroupConversation() => Conversation(
  conversationId: _groupConversationId,
  conversationType: 'group',
  conversationWith: _group('SERVER-SIDE-VALUE'),
  lastMessage: _existingGroupLastMessage,
  updatedAt: DateTime(2026, 10, 1, 10),
  unreadMessageCount: 3,
  tags: ['old-tag'],
  unreadMentionsCount: 1,
  lastReadMessageId: 90,
  latestMessageId: 100,
);

Conversation _loadedUserConversation() => Conversation(
  conversationId: _userConversationId,
  conversationType: 'user',
  conversationWith: User(uid: 'uid-2', name: 'uid-2'),
  lastMessage: _existingUserLastMessage,
  updatedAt: DateTime(2026, 10, 1, 9),
  unreadMessageCount: 5,
);

Future<void> _flush() => pumpEventQueue(times: 50);

void main() {
  late _MockConversationsRepository repo;
  late List<ConversationsBloc> blocs;

  ConversationsBloc build() {
    final bloc = ConversationsBloc(
      getConversationsUseCase: GetConversationsUseCase(repo),
      loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
      deleteConversationUseCase: DeleteConversationUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      getConversationUseCase: GetConversationUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    );
    blocs.add(bloc);
    return bloc;
  }

  Future<ConversationsBloc> loaded() async {
    final bloc = build();
    bloc.add(const LoadConversations());
    await _flush();
    expect(bloc.state, isA<ConversationsLoaded>());
    return bloc;
  }

  Conversation row(ConversationsBloc bloc, String conversationId) =>
      (bloc.state as ConversationsLoaded).conversations.singleWhere(
        (c) => c.conversationId == conversationId,
      );

  setUp(() {
    repo = _MockConversationsRepository();
    blocs = [];
    ChatSdkListeners.debugAddCallListener = (_, _) {};
    ChatSdkListeners.debugRemoveCallListener = (_) {};
    when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(_me));
    when(() => repo.getConversations(limit: any(named: 'limit'))).thenAnswer(
      (_) async =>
          Success([_loadedGroupConversation(), _loadedUserConversation()]),
    );
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    ChatSdkListeners.debugReset();
  });

  test(
    'ccUpdateConversation with a refreshed Group puts the new group '
    'metadata on the row and keeps its unread count and last message',
    () async {
      final bloc = await loaded();
      expect(
        (row(bloc, _groupConversationId).conversationWith as Group).metadata,
        {'marker': 'SERVER-SIDE-VALUE'},
      );

      // What an integrator sends: the same conversation, a refreshed Group,
      // the row's unread count, and no last message.
      CometChatConversationEvents.ccUpdateConversation(
        Conversation(
          conversationId: _groupConversationId,
          conversationType: 'group',
          conversationWith: _group('USAGE2-PROOF'),
          unreadMessageCount: 3,
        ),
      );
      await _flush();

      final updated = row(bloc, _groupConversationId);
      expect(
        (updated.conversationWith as Group).metadata,
        {'marker': 'USAGE2-PROOF'},
        reason:
            'ENG-38584: ccUpdateConversation dropped conversationWith; the '
            'refreshed Group never reached CometChatConversations',
      );
      expect(updated.unreadMessageCount, 3);
      expect(updated.lastMessage, same(_existingGroupLastMessage));

      // A conversation with a different conversationId is untouched.
      final other = row(bloc, _userConversationId);
      expect((other.conversationWith as User).uid, 'uid-2');
      expect(other.unreadMessageCount, 5);
      expect(other.lastMessage, same(_existingUserLastMessage));
    },
  );

  test('ccUpdateConversation merges tags, unread mentions, read and latest '
      'message ids and updatedAt from the supplied conversation', () async {
    final bloc = await loaded();

    final newUpdatedAt = DateTime(2026, 10, 2, 8);
    CometChatConversationEvents.ccUpdateConversation(
      Conversation(
        conversationId: _groupConversationId,
        conversationType: 'group',
        conversationWith: _group('SERVER-SIDE-VALUE'),
        unreadMessageCount: 3,
        tags: ['new-tag'],
        unreadMentionsCount: 0,
        lastReadMessageId: 100,
        latestMessageId: 101,
        updatedAt: newUpdatedAt,
      ),
    );
    await _flush();

    final updated = row(bloc, _groupConversationId);
    expect(
      [
        updated.tags,
        updated.unreadMentionsCount,
        updated.lastReadMessageId,
        updated.latestMessageId,
        updated.updatedAt,
      ],
      [
        ['new-tag'],
        0,
        100,
        101,
        newUpdatedAt,
      ],
      reason:
          'ENG-38584: ccUpdateConversation kept only unreadMessageCount and '
          'lastMessage; [tags, unreadMentionsCount, lastReadMessageId, '
          'latestMessageId, updatedAt] from the supplied conversation were '
          'dropped',
    );
    expect(updated.lastMessage, same(_existingGroupLastMessage));
  });
}
