// Offline off = today (W1 §4 invariant 1, G1): with the SDK reporting offline
// off, both list blocs and the three `CometChatUIKit.send*` statics make
// exactly today's calls and emit today's events, and the hub stays silent.

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
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatUIKit,
        CometChatMessageEvents,
        CometChatMessageEventListener,
        CometChatMessageSendState;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_upload_sdk.dart';

class _MessageRepo extends Fake implements MessageListRepository {
  int getMessagesCalls = 0;

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
  }) async {
    getMessagesCalls++;
    return Success(<BaseMessage>[
      TextMessage(
        id: 1,
        text: 'hi',
        sender: User(uid: 'bob', name: 'Bob'),
        receiverUid: 'alice',
        type: 'text',
        receiverType: 'user',
        sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ),
    ]);
  }

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

class _EventRecorder with CometChatMessageEventListener {
  final List<core_enums.MessageStatus> sent = [];
  final List<CometChatMessageSendState> sendStates = [];

  @override
  void ccMessageSent(BaseMessage message, core_enums.MessageStatus status) =>
      sent.add(status);

  @override
  void ccMessageSendStateChanged(
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) => sendStates.add(state);
}

void main() {
  final hubEvents = <OfflineHubEvent>[];
  late StreamSubscription<OfflineHubEvent> hubSub;

  setUpAll(() => registerFallbackValue(_FakeConversation('')));

  setUp(() {
    OfflineHub.instance.debugReset();
    CometChat.debugSetOfflineEnabledOverride(false);
    hubEvents.clear();
    hubSub = OfflineHub.instance.events.listen(hubEvents.add);
  });

  tearDown(() async {
    await hubSub.cancel();
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  test('ConversationsBloc: one fetch, [Loading, Loaded], hub silent', () async {
    final repo = _ConversationsRepo();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(_FakeUser()));
    when(
      () => repo.getConversations(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success([_FakeConversation('a')]));
    final bloc = ConversationsBloc(
      getConversationsUseCase: GetConversationsUseCase(repo),
      loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
      deleteConversationUseCase: DeleteConversationUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      getConversationUseCase: GetConversationUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
      disableSDKListeners: true,
    );
    addTearDown(bloc.close);
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    bloc.add(const LoadConversations());
    await pumpEventQueue();

    verify(() => repo.getConversations(limit: any(named: 'limit'))).called(1);
    expect(states.first, isA<ConversationsLoading>());
    expect(states.last, isA<ConversationsLoaded>());
    expect(hubEvents, isEmpty);
  });

  test('MessageListBloc: one fetch, loading then loaded, hub silent', () async {
    final repo = _MessageRepo();
    final bloc = MessageListBloc(
      disableSDKListeners: true,
      user: User(uid: 'bob', name: 'Bob'),
      getMessagesUseCase: GetMessagesUseCase(repo),
    );
    addTearDown(bloc.close);
    final states = <MessageListState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    bloc.add(
      const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
    );
    await pumpEventQueue();

    expect(repo.getMessagesCalls, 1);
    expect(states.first.status, MessageListStatus.loading);
    expect(bloc.state.messages, hasLength(1));
    expect(hubEvents, isEmpty);
  });

  group('CometChatUIKit.send* statics', () {
    late FakeUploadSdkClient sdkClient;
    late _EventRecorder recorder;

    setUp(() async {
      sdkClient = await registerFakeUploadSdk();
      recorder = _EventRecorder();
      CometChatMessageEvents.addMessagesListener('w1_off_baseline', recorder);
    });

    tearDown(() async {
      CometChatMessageEvents.removeMessagesListener('w1_off_baseline');
      await clearFakeUploadSdk();
    });

    void expectToday() {
      expect(sdkClient.messageRepo.sent, hasLength(1)); // one SDK send
      expect(recorder.sent, [
        core_enums.MessageStatus.inProgress,
        core_enums.MessageStatus.sent,
      ]);
      expect(recorder.sendStates, isEmpty); // no offline event
      expect(hubEvents, isEmpty);
    }

    test('sendTextMessage', () async {
      await CometChatUIKit.sendTextMessage(
        TextMessage(
          text: 'hi',
          receiverUid: 'bob',
          type: 'text',
          receiverType: 'user',
        ),
      );
      await pumpEventQueue();
      expectToday();
    });

    test('sendCustomMessage', () async {
      await CometChatUIKit.sendCustomMessage(
        CustomMessage(
          receiverUid: 'bob',
          type: 'custom_type',
          receiverType: 'user',
          customData: const {'k': 'v'},
        ),
      );
      await pumpEventQueue();
      expectToday();
    });

    test('sendMediaMessage', () async {
      await CometChatUIKit.sendMediaMessage(
        MediaMessage(
          receiverUid: 'bob',
          type: 'image',
          receiverType: 'user',
          file: '/tmp/w1.png',
        ),
        replacePathForIOS: false,
      );
      await pumpEventQueue();
      expectToday();
    });
  });
}
