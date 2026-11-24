/// The Chats list hides presence while the SDK is not connected (D84 (10),
/// D-349). A lost network makes the SDK report a connection error, not a
/// disconnect, so the list's connection listener treats both the same.
///
///   flutter test test/chat_ui/conversations/conversations_presence_offline_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_presence.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConversationsRepository extends Mock
    implements ConversationsRepository {}

final _me = User(uid: 'me', name: 'Me');

Conversation _conversation(String uid) => Conversation(
  conversationId: 'me_user_$uid',
  conversationType: 'user',
  conversationWith: User(uid: uid, name: uid, status: 'online'),
  updatedAt: DateTime(2026, 11, 18, 10),
);

CometChatException _wsError() =>
    CometChatException('ERROR_CONNECTION_FAILED', 'WebSocket error', '');

void main() {
  late _MockConversationsRepository repo;
  late Map<String, ConnectionListener> listeners;
  final blocs = <ConversationsBloc>[];

  Future<ConnectionListener> loaded() async {
    final bloc = ConversationsBloc(
      getConversationsUseCase: GetConversationsUseCase(repo),
      loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
      deleteConversationUseCase: DeleteConversationUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      getConversationUseCase: GetConversationUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    );
    blocs.add(bloc);
    bloc.add(const LoadConversations());
    await pumpEventQueue(times: 50);
    return listeners.values.single;
  }

  setUp(() {
    repo = _MockConversationsRepository();
    listeners = {};
    ChatSdkListeners.debugAddConnectionListener = (id, l) => listeners[id] = l;
    ChatSdkListeners.debugRemoveConnectionListener = listeners.remove;
    // Connected at start: the open-time read must not hide presence.
    OfflinePresence.debugReadConnectionStatus = () async =>
        CometChatWSState.connected;
    when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(_me));
    when(
      () => repo.getConversations(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success([_conversation('bob')]));
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    blocs.clear();
    ChatSdkListeners.debugReset();
    OfflinePresence.debugReset();
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  test('D-349: offline on, a connection error hides presence; the reconnect '
      'restores it', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final listener = await loaded();
    expect(OfflinePresence.hidden, isFalse);

    listener.onConnectionError(_wsError());
    expect(OfflinePresence.hidden, isTrue);

    listener.onConnected();
    expect(OfflinePresence.hidden, isFalse);
  });

  test('D-349: offline off, a connection error never hides presence', () async {
    CometChat.debugSetOfflineEnabledOverride(false);
    final listener = await loaded();
    listener.onConnectionError(_wsError());
    expect(OfflinePresence.hidden, isFalse);
  });

  test('the bloc removes its connection listener on close', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    await loaded();
    await blocs.single.close();
    expect(listeners, isEmpty);
  });
}
