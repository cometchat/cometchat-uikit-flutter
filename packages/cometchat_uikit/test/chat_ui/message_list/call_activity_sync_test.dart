/// Ringing v2 on Android and iOS: the other side's call messages reach an
/// open chat live.
///
/// The chat SDK's call listener (deprecated) is registered on web only. On
/// Android and iOS the Calls SDK's incoming call listener says when a call
/// starts or stops ringing, on either side, and the list pulls what the
/// backend wrote, as Android's UI Kit does (`onCallActivity`): it syncs the
/// newer messages, and re-reads the call's bubbles already on screen, since a
/// call message keeps its ID while its status moves on.
///
///   flutter test test/chat_ui/message_list/call_activity_sync_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show IncomingCallListener, InitiatedCall;
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
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/src/call_activity_listener.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageListRepository {}

class _FakeMessagesRequest extends Fake implements MessagesRequest {}

class _FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_peer';

  @override
  int get unreadMessageCount => 0;

  @override
  int? get lastReadMessageId => null;
}

const _me = 'me';
const _peer = 'peer';

final _meUser = User(uid: _me, name: 'Me');
final _peerUser = User(uid: _peer, name: 'Peer');

/// The peer's call to me, message [id], in [status].
Call _call({int id = 501, required String status}) => Call(
  id: id,
  sessionId: 'session_1',
  callStatus: status,
  action: status,
  callInitiator: _peerUser,
  sender: _peerUser,
  receiverUid: _me,
  type: 'audio',
  receiverType: 'user',
  category: 'call',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

/// A call from [from] to me, as the Calls SDK reports it from a push.
InitiatedCall _pushed({String from = _peer, String session = 'session_1'}) =>
    InitiatedCall(
      sessionId: session,
      messageId: '501',
      sender: from,
      receiver: _me,
      receiverType: 'user',
      type: 'audio',
    );

MessageListBloc _bloc(_MockRepo repo, {int? parentMessageId}) =>
    MessageListBloc(
      getMessagesUseCase: GetMessagesUseCase(repo),
      loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
      loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
      markAsReadUseCase: MarkAsReadUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
      markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      user: _peerUser,
      parentMessageId: parentMessageId,
    );

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

Future<void> _load(MessageListBloc bloc, {int? parentMessageId}) async {
  bloc.add(
    LoadMessages(
      conversationWith: _peer,
      conversationType: 'user',
      parentMessageId: parentMessageId,
    ),
  );
  await _settle();
}

List<Call> _calls(MessageListBloc bloc) =>
    bloc.state.messages.whereType<Call>().toList();

void main() {
  late _MockRepo repo;
  late Map<String, IncomingCallListener> callsSdkListeners;
  late List<int> fetched;
  late Map<int, BaseMessage> server;

  setUpAll(() {
    registerFallbackValue(_FakeMessagesRequest());
    registerFallbackValue(_FakeConversation());
    registerFallbackValue(
      TextMessage(
        text: '',
        receiverUid: '',
        type: 'text',
        receiverType: 'user',
      ),
    );
  });

  setUp(() {
    CometChatUIKit.loggedInUser = _meUser;
    repo = _MockRepo();
    callsSdkListeners = {};
    CallActivityListener.addIncomingCallListener = (id, listener) =>
        callsSdkListeners[id] = listener;
    CallActivityListener.removeIncomingCallListener = callsSdkListeners.remove;
    fetched = [];
    server = {};
    CallActivityListener.debugFetchMessage = (id) async {
      fetched.add(id);
      return server[id];
    };
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(_meUser));
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
    ).thenAnswer((_) async => Success([_call(status: 'initiated')]));
    when(
      () => repo.fetchNextMessages(request: any(named: 'request')),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    ).thenAnswer((_) async => Success(_FakeConversation()));
    when(
      () => repo.markAsRead(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.markAsDelivered(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  tearDown(() {
    CallActivityListener.debugReset();
    CometChatUIKit.loggedInUser = null;
  });

  test('a call of this chat that stops ringing updates its bubble from the '
      'server and syncs the newer messages', () async {
    final bloc = _bloc(repo);
    await _load(bloc);
    expect(_calls(bloc).single.callStatus, 'initiated');
    server[501] = _call(status: 'rejected');
    final newer = _call(id: 502, status: 'initiated');
    when(
      () => repo.fetchNextMessages(request: any(named: 'request')),
    ).thenAnswer((_) async => Success([newer]));

    callsSdkListeners.values.single.onIncomingCallEnded(_pushed(), 'rejected');
    await _settle();

    expect(fetched, [501]);
    verify(
      () => repo.fetchNextMessages(request: any(named: 'request')),
    ).called(1);
    expect(_calls(bloc).map((c) => (c.id, c.callStatus)), [
      (501, 'rejected'),
      (502, 'initiated'),
    ]);
    await bloc.close();
  }, skip: kIsWeb ? 'Android and iOS only' : false);

  test(
    'a call of this chat that starts ringing syncs the newer messages',
    () async {
      final bloc = _bloc(repo);
      await _load(bloc);

      callsSdkListeners.values.single.onIncomingCallReceived(
        _pushed(session: 'session_2'),
      );
      await _settle();

      verify(
        () => repo.fetchNextMessages(request: any(named: 'request')),
      ).called(1);
      // No bubble of session_2 on screen to re-read.
      expect(fetched, isEmpty);
      await bloc.close();
    },
    skip: kIsWeb ? 'Android and iOS only' : false,
  );

  test(
    'a call of another chat, or a thread\'s list, fetches nothing',
    () async {
      final bloc = _bloc(repo);
      await _load(bloc);
      callsSdkListeners.values.single.onIncomingCallEnded(
        _pushed(from: 'someone-else'),
        'rejected',
      );
      await _settle();
      await bloc.close();

      final thread = _bloc(repo, parentMessageId: 77);
      await _load(thread, parentMessageId: 77);
      callsSdkListeners.values.single.onIncomingCallEnded(
        _pushed(),
        'rejected',
      );
      await _settle();
      await thread.close();

      verifyNever(() => repo.fetchNextMessages(request: any(named: 'request')));
      expect(fetched, isEmpty);
    },
    skip: kIsWeb ? 'Android and iOS only' : false,
  );

  test(
    'close() removes the Calls SDK listener',
    () async {
      final bloc = _bloc(repo);
      await _load(bloc);
      expect(callsSdkListeners, hasLength(1));
      final listener = callsSdkListeners.values.single;

      await bloc.close();

      expect(callsSdkListeners, isEmpty);
      listener.onIncomingCallEnded(_pushed(), 'rejected');
      await _settle();
      verifyNever(() => repo.fetchNextMessages(request: any(named: 'request')));
    },
    skip: kIsWeb ? 'Android and iOS only' : false,
  );
}
