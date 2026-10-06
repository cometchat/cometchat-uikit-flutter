/// A fake SDK backend for the AI assistant chat history module.
///
/// The module's remote datasource wraps `MessagesRequest.fetchPrevious`,
/// `CometChat.deleteMessage`, `CometChat.getLoggedInUser` and
/// `CometChat.getConversation`; every one of them resolves its repository
/// through `SdkRegistry`. Registering this client there answers all four from
/// the closures below — the same seam `golden_fake_sdk.dart` and
/// `fake_sdk_moderation.dart` use.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; they are the only seam these wrappers leave.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/auth/auth_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

final _fallbackUser = User(uid: 'u2', name: 'Bob');

BaseMessage _fallbackMessage(int id) => TextMessage(
  id: id,
  text: 'row $id',
  sender: _fallbackUser,
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime(2023, 11, 15, 9),
);

// --------------------------------------------------------------------------
// The fake backend. Each closure is what the matching SDK call answers with;
// throwing an SdkException drives the wrapper's failure branch.
// --------------------------------------------------------------------------

List<BaseMessage> Function() fakeMessagePage = () => const [];
BaseMessage Function(String id) fakeDeleteMessage = (_) => _fallbackMessage(1);
User? Function() fakeLoggedInUser = () => null;
Conversation Function(String with_, bool isUser) fakeConversation = (_, _) =>
    Conversation(
      conversationId: 'c1',
      conversationType: 'user',
      conversationWith: _fallbackUser,
    );

class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  @override
  Future<BaseMessage> deleteMessage(String messageId) async =>
      fakeDeleteMessage(messageId);

  /// fetchPrevious routes to getUserMessages / getGroupMessages / getMessages.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages ||
        name == #getGroupMessages ||
        name == #getMessages) {
      return Future<sdk.MessagesResult>.sync(
        () => sdk.MessagesResult(messages: fakeMessagePage(), hasMore: false),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeAuthRepository extends Fake implements sdk.AuthRepository {
  @override
  User? getLoggedInUser() => fakeLoggedInUser();
}

class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  @override
  Future<Conversation> getUserConversation(String uid) async =>
      fakeConversation(uid, true);

  @override
  Future<Conversation> getGroupConversation(String guid) async =>
      fakeConversation(guid, false);
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessageRepository();

  @override
  final sdk.AuthRepository auth = _FakeAuthRepository();

  @override
  final sdk.ConversationRepository conversations =
      _FakeConversationRepository();

  @override
  Future<void> dispose() async {}
}

/// Point every chat-history SDK call at the closures above. Call from `setUp`,
/// and [clearFakeChatHistoryBackend] from `tearDown`.
Future<void> registerFakeChatHistoryBackend() async {
  await sdk.SdkRegistry.clear();
  sdk.SdkRegistry.register(_FakeSdkClient());
}

Future<void> clearFakeChatHistoryBackend() async {
  fakeMessagePage = () => const [];
  fakeDeleteMessage = (_) => _fallbackMessage(1);
  fakeLoggedInUser = () => null;
  fakeConversation = (_, _) => Conversation(
    conversationId: 'c1',
    conversationType: 'user',
    conversationWith: _fallbackUser,
  );
  await sdk.SdkRegistry.clear();
}
