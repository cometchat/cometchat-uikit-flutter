/// The AI assistant chat history data layer — remote datasource, repository,
/// use cases and the service locator that wires them.
///
/// All four files sat at 0%: the datasource wraps four `CometChat.*` statics,
/// and each of those resolves its repository through `SdkRegistry`. Registering
/// a fake client there (the seam `golden_fake_sdk.dart` and
/// `fake_sdk_moderation.dart` already use) runs both the success and the
/// failure branch of every wrapper for real.
///
///   flutter test test/chat_ui/ai_assistant_chat_history/ai_assistant_chat_history_data_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/ai_assistant_chat_history/data/datasources/ai_assistant_chat_history_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/ai_assistant_chat_history/data/repositories/ai_assistant_chat_history_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/ai_assistant_chat_history/domain/usecases/usecases.dart'
    as history;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/errors/sdk_exception.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sdk_chat_history.dart';

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');

TextMessage _message(int id) => TextMessage(
  id: id,
  text: 'row $id',
  sender: _them,
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime(2023, 11, 15, 9),
);

void main() {
  late AIAssistantChatHistoryRemoteDataSourceImpl datasource;

  setUp(() async {
    await registerFakeChatHistoryBackend();
    datasource = AIAssistantChatHistoryRemoteDataSourceImpl();
  });

  tearDown(clearFakeChatHistoryBackend);

  // =========================================================================
  group('fetchMessages', () {
    test('hands back the page the SDK fetched', () async {
      fakeMessagePage = () => [_message(1), _message(2)];

      final result = await datasource.fetchMessages(
        (MessagesRequestBuilder()..uid = 'u2').build(),
      );

      expect(result, isA<Success<List<BaseMessage>>>());
      expect((result as Success<List<BaseMessage>>).data, hasLength(2));
    });

    test('a request naming neither a uid nor a guid still fetches, through '
        'the untargeted scope', () async {
      var asked = false;
      fakeMessagePage = () {
        asked = true;
        return const <BaseMessage>[];
      };

      final result = await datasource.fetchMessages(
        MessagesRequestBuilder().build(),
      );

      expect(asked, isTrue);
      expect((result as Success<List<BaseMessage>>).data, isEmpty);
    });

    test('an SDK failure becomes a Failure carrying its code', () async {
      fakeMessagePage = () => throw sdk.SdkException('ERR_FETCH', 'boom');

      final result = await datasource.fetchMessages(
        (MessagesRequestBuilder()..uid = 'u2').build(),
      );

      expect(result, isA<Failure>());
      expect((result as Failure).code, 'ERR_FETCH');
    });
  });

  // =========================================================================
  group('deleteMessage', () {
    test('returns the message the SDK reports deleted', () async {
      fakeDeleteMessage = (_) => _message(42);

      final result = await datasource.deleteMessage(42);

      expect(result, isA<Success<BaseMessage>>());
      expect((result as Success<BaseMessage>).data.id, 42);
    });

    test('passes the id through as a string', () async {
      String? seen;
      fakeDeleteMessage = (id) {
        seen = id;
        return _message(7);
      };

      await datasource.deleteMessage(7);

      expect(seen, '7');
    });

    test('an SDK failure becomes a Failure carrying its code', () async {
      fakeDeleteMessage = (_) =>
          throw sdk.SdkException('ERR_DELETE', 'not allowed');

      final result = await datasource.deleteMessage(42);

      expect(result, isA<Failure>());
      expect((result as Failure).code, 'ERR_DELETE');
    });
  });

  // =========================================================================
  group('getLoggedInUser', () {
    test('returns the user the SDK holds', () async {
      fakeLoggedInUser = () => _me;

      final result = await datasource.getLoggedInUser();

      expect((result as Success<User?>).data?.uid, 'u1');
    });

    test(
      'no logged-in user is a success carrying null, not a failure',
      () async {
        fakeLoggedInUser = () => null;

        final result = await datasource.getLoggedInUser();

        expect(result, isA<Success<User?>>());
        expect((result as Success<User?>).data, isNull);
      },
    );

    // FINDING: `CometChat.getLoggedInUser` swallows the SdkException — with
    // no onError callback passed it converts the error, drops it and returns
    // null. So the wrapper's `on CometChatException` / `catch` branches are
    // unreachable through the shipped SDK, and a broken session is
    // indistinguishable from "nobody is signed in". This pins that.
    test(
      'an auth failure is reported as a signed-out success, not a Failure',
      () async {
        fakeLoggedInUser = () =>
            throw sdk.SdkException('ERR_AUTH', 'no session');

        final result = await datasource.getLoggedInUser();

        expect(result, isA<Success<User?>>());
        expect((result as Success<User?>).data, isNull);
      },
    );
  });

  // =========================================================================
  group('getConversation', () {
    test('a user conversation is fetched by uid', () async {
      String? seen;
      var asUser = false;
      fakeConversation = (with_, isUser) {
        seen = with_;
        asUser = isUser;
        return Conversation(
          conversationId: 'c-u2',
          conversationType: 'user',
          conversationWith: _them,
        );
      };

      final result = await datasource.getConversation('u2', 'user');

      expect(seen, 'u2');
      expect(asUser, isTrue);
      expect((result as Success<Conversation?>).data?.conversationId, 'c-u2');
    });

    test('anything else is fetched as a group conversation', () async {
      var asUser = true;
      fakeConversation = (with_, isUser) {
        asUser = isUser;
        return Conversation(
          conversationId: 'c-g1',
          conversationType: 'group',
          conversationWith: _them,
        );
      };

      await datasource.getConversation('g1', 'group');

      expect(asUser, isFalse);
    });

    test('an SDK failure becomes a Failure carrying its code', () async {
      fakeConversation = (_, _) => throw sdk.SdkException('ERR_CONV', 'gone');

      final result = await datasource.getConversation('u2', 'user');

      expect(result, isA<Failure>());
      expect((result as Failure).code, 'ERR_CONV');
    });
  });

  // =========================================================================
  group('the repository and its use cases', () {
    late AIAssistantChatHistoryRepositoryImpl repository;

    setUp(() {
      repository = AIAssistantChatHistoryRepositoryImpl(
        remoteDataSource: datasource,
      );
    });

    test('fetchChatHistory delegates straight to the datasource', () async {
      fakeMessagePage = () => [_message(1)];

      final direct = await repository.fetchMessages(
        (MessagesRequestBuilder()..uid = 'u2').build(),
      );
      final throughUseCase = await history.FetchChatHistoryUseCase(repository)(
        (MessagesRequestBuilder()..uid = 'u2').build(),
      );

      expect((direct as Success<List<BaseMessage>>).data, hasLength(1));
      expect((throughUseCase as Success<List<BaseMessage>>).data, hasLength(1));
    });

    test('deleteMessage delegates, through the use case too', () async {
      fakeDeleteMessage = (_) => _message(9);

      final direct = await repository.deleteMessage(9);
      final throughUseCase = await history.DeleteChatHistoryMessageUseCase(
        repository,
      )(9);

      expect((direct as Success<BaseMessage>).data.id, 9);
      expect((throughUseCase as Success<BaseMessage>).data.id, 9);
    });

    test('getLoggedInUser delegates, through the use case too', () async {
      fakeLoggedInUser = () => _me;

      final direct = await repository.getLoggedInUser();
      final throughUseCase = await history.GetLoggedInUserUseCase(repository)();

      expect((direct as Success<User?>).data?.uid, 'u1');
      expect((throughUseCase as Success<User?>).data?.uid, 'u1');
    });

    test('getConversation delegates', () async {
      fakeConversation = (_, _) => Conversation(
        conversationId: 'c1',
        conversationType: 'user',
        conversationWith: _them,
      );

      final result = await repository.getConversation('u2', 'user');

      expect((result as Success<Conversation?>).data?.conversationId, 'c1');
    });
  });

  // =========================================================================
  group('the service locator', () {
    tearDown(() async {
      await AIAssistantChatHistoryServiceLocator.instance.reset();
    });

    test('reading a dependency before setup is a StateError', () async {
      await AIAssistantChatHistoryServiceLocator.instance.reset();
      final locator = AIAssistantChatHistoryServiceLocator.instance;

      expect(locator.isInitialized, isFalse);
      expect(() => locator.fetchChatHistoryUseCase, throwsStateError);
      expect(() => locator.deleteChatHistoryMessageUseCase, throwsStateError);
      expect(() => locator.getLoggedInUserUseCase, throwsStateError);
      expect(() => locator.repository, throwsStateError);
    });

    test('setup wires every dependency and is the same instance each time', () {
      final locator = AIAssistantChatHistoryServiceLocator.instance;
      locator.setup();

      expect(locator.isInitialized, isTrue);
      expect(locator.repository, isA<AIAssistantChatHistoryRepositoryImpl>());
      expect(
        locator.fetchChatHistoryUseCase,
        same(locator.fetchChatHistoryUseCase),
      );
      expect(
        AIAssistantChatHistoryServiceLocator.instance,
        same(locator),
        reason: 'it is a singleton',
      );
    });

    test('a second setup does not rebuild what the first one made', () {
      final locator = AIAssistantChatHistoryServiceLocator.instance;
      locator.setup();
      final first = locator.repository;

      locator.setup();

      expect(locator.repository, same(first));
    });

    test('reset makes it uninitialised again', () async {
      final locator = AIAssistantChatHistoryServiceLocator.instance;
      locator.setup();

      await locator.reset();

      expect(locator.isInitialized, isFalse);
    });

    test('the use cases it hands out reach the real SDK seam', () async {
      fakeLoggedInUser = () => _me;
      final locator = AIAssistantChatHistoryServiceLocator.instance;
      locator.setup();

      fakeDeleteMessage = (_) => _message(3);

      final user = await locator.getLoggedInUserUseCase();
      final deleted = await locator.deleteChatHistoryMessageUseCase(3);

      expect((user as Success<User?>).data?.uid, 'u1');
      expect((deleted as Success<BaseMessage>).data.id, 3);
    });
  });

  // =========================================================================
  test('the AI feature registry is empty and cannot be instantiated', () {
    // The class documents itself as a registry that is empty until features
    // are registered; nothing may construct it.
    expect(CometChatUIKitChatAIFeatures.getDefaultAiFeatures(), isEmpty);
    expect(
      CometChatUIKitChatAIFeatures.getDefaultAiFeatures(),
      isA<List<Map<String, dynamic>>>(),
    );
  });
}
