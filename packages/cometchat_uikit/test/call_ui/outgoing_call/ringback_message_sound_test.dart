/// A message arriving while an outgoing call rings (round 2, P2-C12;
/// checklist P2-E27).
///
/// The ringback used to share the native player with message sounds, so the
/// message tone replaced it and the caller went silent. Now the ringback is
/// the call tone (playCallTone) and message sounds keep their own player
/// (playCustomSound): a message plays its sound and never stops the call
/// tone.
///
/// Both places a message sound comes from are driven for real: the open
/// chat's MessageListBloc and the conversation list's ConversationsBloc (the
/// latter through the chat SDK's own listener, fed by a fake socket).
///
///   flutter test test/call_ui/outgoing_call/ringback_message_sound_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart'
    as conversations;
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart'
    as conversations;
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart'
    as conversations;
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatUIKit,
        MessageCategoryConstants,
        MessageTypeConstants,
        ReceiverTypeConstants;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
// The chat SDK's seams, as the conversations prop tests use them: a fake
// client whose realtime stream is the socket CometChat's listeners hear.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/analytics/sdk_identification.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/models/presence/connection_state.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/auth/auth_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/realtime/realtime_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/call_bloc_harness.dart';

final User _me = User(uid: 'me-ring', name: 'Me');
final User _bob = User(uid: 'bob-ring', name: 'Bob');

TextMessage _fromBob(int id) => TextMessage(
  id: id,
  muid: 'muid-ring-$id',
  text: 'are you there? $id',
  sender: _bob,
  receiverUid: _me.uid,
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: DateTime(2026, 9, 30, 10, 15),
  conversationId: 'user_${_bob.uid}',
);

/// Rings a voice call to Bob and checks the call tone started.
Future<OutgoingCallBloc> _ringing() async {
  final OutgoingCallBloc call = OutgoingCallBloc(
    call: buildCall(receiverUid: _bob.uid),
  );
  await pumpEventQueue();
  expect(SoundChannelSpy.methods, <String>['playCallTone']);
  return call;
}

/// What a message arriving meanwhile must have done: its own sound on the
/// message player, and nothing to the call tone.
void _expectMessageSoundBesideRingback() {
  expect(
    SoundChannelSpy.methods,
    <String>['playCallTone', 'playCustomSound'],
    reason:
        'the message plays on the message player; the ringback goes on '
        '(P2-E27)',
  );
  expect(SoundChannelSpy.methods, isNot(contains('stopCallTone')));
  expect(SoundChannelSpy.methods, isNot(contains('stopPlayer')));
  expect(
    SoundChannelSpy.lastArgumentsOf('playCustomSound')?['assetAudioPath'],
    'assets/sound/incoming_message.wav',
  );
}

// ─── Message list ────────────────────────────────────────────────────────────

class _MockMessageListRepository extends Mock
    implements MessageListRepository {}

Future<MessageListBloc> _openChatWithBob() async {
  final _MockMessageListRepository repo = _MockMessageListRepository();
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
  ).thenAnswer((_) async => const Success(<BaseMessage>[]));
  final MessageListBloc bloc = MessageListBloc(
    getMessagesUseCase: GetMessagesUseCase(repo),
    loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
    loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
    markAsReadUseCase: MarkAsReadUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    user: _bob,
    disableReceipts: true,
    disableSDKListeners: true,
    types: <String>[MessageTypeConstants.text],
    categories: <String>[MessageCategoryConstants.message],
  );
  bloc.add(LoadMessages(conversationWith: _bob.uid, conversationType: 'user'));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc;
}

// ─── Conversation list, over a fake socket ───────────────────────────────────

class _MockConversationsRepository extends Mock
    implements ConversationsRepository {}

class _FakeRealtime extends Fake implements sdk.RealtimeRepository {
  _FakeRealtime(this.messages);

  final StreamController<BaseMessage> messages;

  @override
  Stream<BaseMessage> get messageStream => messages.stream;

  @override
  sdk.ConnectionState get connectionState => sdk.ConnectionState.connected;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter &&
        invocation.memberName.toString().contains('Stream')) {
      return const Stream<Never>.empty();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeAuth extends Fake implements sdk.AuthRepository {
  @override
  Future<User> loginWithApiKey(String uid, String apiKey) async => _me;

  @override
  User? getLoggedInUser() => _me;
}

class _FakeIdentification extends Fake implements sdk.SdkIdentification {
  @override
  Future<void> sendIfNeeded() async {}
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(StreamController<BaseMessage> messages)
    : realtime = _FakeRealtime(messages);

  @override
  final sdk.RealtimeRepository realtime;

  @override
  final sdk.AuthRepository auth = _FakeAuth();

  @override
  final sdk.SdkIdentification sdkIdentification = _FakeIdentification();

  @override
  Future<void> dispose() async {}
}

/// The conversation list, loaded with the chat with Bob and listening to
/// the chat SDK. Returns it with the socket that feeds it.
Future<(ConversationsBloc, StreamController<BaseMessage>)>
_conversationListListening() async {
  final StreamController<BaseMessage> socket =
      StreamController<BaseMessage>.broadcast();
  addTearDown(socket.close);
  await sdk.SdkRegistry.clear();
  sdk.SdkRegistry.register(_FakeSdkClient(socket));
  addTearDown(sdk.SdkRegistry.clear);
  // Login is what wires CometChat's listener maps to the fake's streams.
  // ignore: deprecated_member_use
  await CometChat.login('me-ring', 'test-key', onSuccess: null, onError: null);

  final _MockConversationsRepository repo = _MockConversationsRepository();
  when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(_me));
  when(
    () => repo.getConversations(
      limit: any(named: 'limit'),
      fromId: any(named: 'fromId'),
      requestBuilder: any(named: 'requestBuilder'),
    ),
  ).thenAnswer(
    (_) async => Success(<Conversation>[
      Conversation(
        conversationId: 'user_${_bob.uid}',
        conversationType: ConversationType.user,
        conversationWith: _bob,
      ),
    ]),
  );
  when(
    () => repo.markAsDelivered(any()),
  ).thenAnswer((_) async => const Success<void>(null));

  final ConversationsBloc bloc = ConversationsBloc(
    getConversationsUseCase: conversations.GetConversationsUseCase(repo),
    loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
    deleteConversationUseCase: DeleteConversationUseCase(repo),
    getLoggedInUserUseCase: conversations.GetLoggedInUserUseCase(repo),
    getConversationUseCase: GetConversationUseCase(repo),
    markAsDeliveredUseCase: conversations.MarkAsDeliveredUseCase(repo),
    usersStatusVisibility: false,
  );
  bloc.add(const LoadConversations());
  await Future<void>.delayed(const Duration(milliseconds: 20));
  expect(bloc.state, isA<ConversationsLoaded>());
  return (bloc, socket);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_fromBob(0));
  });

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    CallOperationsServiceLocator.instance.setup(
      dataSource: FakeCallOperationsDataSource(),
    );
    CometChatUIKit.loggedInUser = _me;
    SoundChannelSpy.install();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    CometChatUIKit.loggedInUser = null;
    CallStateService.instance.setActiveOutgoingValue(false);
    await CallOperationsServiceLocator.instance.reset();
  });

  test('a message in the open chat plays its sound; the ringback goes '
      'on', () async {
    final MessageListBloc chat = await _openChatWithBob();
    addTearDown(chat.close);
    final OutgoingCallBloc call = await _ringing();

    chat.add(MessageReceived(_fromBob(1)));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    _expectMessageSoundBesideRingback();
    await call.close();
    expect(SoundChannelSpy.methods.last, 'stopCallTone');
  });

  test('a message reaching the conversation list plays its sound; the '
      'ringback goes on', () async {
    final (ConversationsBloc list, StreamController<BaseMessage> socket) =
        await _conversationListListening();
    addTearDown(list.close);
    final OutgoingCallBloc call = await _ringing();

    socket.add(_fromBob(2));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    _expectMessageSoundBesideRingback();
    await call.close();
    expect(SoundChannelSpy.methods.last, 'stopCallTone');
  });
}
