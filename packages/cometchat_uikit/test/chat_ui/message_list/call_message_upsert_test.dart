/// Regression tests for ENG-39486 — after a declined call, no call message
/// appeared in the chat on either side.
///
/// Two gaps, both parity with the Kotlin UIKit (v6 / dev-v6):
///
/// * The message list did not listen to the UI Kit's own call events. The SDK
///   never tells a device about what that device did itself — the callee is
///   not told about their own decline, the caller not about their own cancel —
///   so those calls only exist as UI Kit events, and the person who declined
///   never got a bubble at all.
/// * A call keeps one id while its status moves on (initiated → declined /
///   cancelled / ended), and the list dropped the later steps as duplicates,
///   so a bubble froze at its first status. Kotlin updates call bubbles by id.
///
///   flutter test test/chat_ui/message_list/call_message_upsert_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
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
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatCallEvents, CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageListRepository {}

class _FakeMessagesRequest extends Fake implements MessagesRequest {}

class _FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_peer';

  @override
  int get unreadMessageCount => 0;
}

const _me = 'me';
const _peer = 'peer';

final _meUser = User(uid: _me, name: 'Me');
final _peerUser = User(uid: _peer, name: 'Peer');

/// A 1:1 audio call between me and the peer, as the SDK hands it back.
///
/// [initiator] is who placed it. `sender` is deliberately left unset: the
/// Call objects returned by initiate/reject — what the UI Kit call events
/// carry — need not have one, and matching must not depend on it.
Call _call({
  int id = 501,
  required String status,
  required User initiator,
  required String receiverUid,
}) => Call(
  id: id,
  sessionId: 'session_1',
  callStatus: status,
  action: status,
  callInitiator: initiator,
  receiverUid: receiverUid,
  type: 'audio',
  receiverType: 'user',
  category: 'call',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

/// [listen] registers the bloc's listeners. The UI Kit event listeners live
/// alongside the SDK ones and are skipped with them when SDK listeners are
/// disabled, so the tests that fire UI Kit call events need it on.
MessageListBloc _bloc(_MockRepo repo, {bool listen = false}) => MessageListBloc(
  getMessagesUseCase: GetMessagesUseCase(repo),
  loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
  loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
  markAsReadUseCase: MarkAsReadUseCase(repo),
  markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
  markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
  getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
  user: _peerUser,
  disableSDKListeners: !listen,
);

/// Loads an empty conversation so the list accepts live messages — nothing
/// is merged while the list is still in its initial state.
Future<void> _load(MessageListBloc bloc) async {
  bloc.add(
    const LoadMessages(conversationWith: _peer, conversationType: 'user'),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

List<Call> _calls(MessageListBloc bloc) =>
    bloc.state.messages.whereType<Call>().toList();

void main() {
  late _MockRepo repo;

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

  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('a call keeps one bubble while its status moves on', () {
    test(
      'a later status for the same id updates the bubble in place',
      () async {
        final bloc = _bloc(repo);
        await _load(bloc);

        bloc.add(
          MessageReceived(
            _call(status: 'initiated', initiator: _meUser, receiverUid: _peer),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(
          MessageReceived(
            _call(status: 'rejected', initiator: _meUser, receiverUid: _peer),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final calls = _calls(bloc);
        expect(calls, hasLength(1), reason: 'one call, one bubble');
        expect(
          calls.single.callStatus,
          'rejected',
          reason:
              'the declined status used to be dropped as a duplicate, freezing '
              'the bubble at "initiated" — ENG-39486',
        );
        await bloc.close();
      },
    );

    test('a different call is still a new bubble', () async {
      final bloc = _bloc(repo);
      await _load(bloc);

      bloc.add(
        MessageReceived(
          _call(
            id: 501,
            status: 'ended',
            initiator: _meUser,
            receiverUid: _peer,
          ),
        ),
      );
      bloc.add(
        MessageReceived(
          _call(
            id: 502,
            status: 'initiated',
            initiator: _meUser,
            receiverUid: _peer,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(_calls(bloc).map((c) => c.id), [501, 502]);
      await bloc.close();
    });
  });

  group('calls this device acted on itself (UI Kit call events)', () {
    test(
      'declining an incoming call puts it in the decliner\'s chat',
      () async {
        final bloc = _bloc(repo, listen: true);
        await _load(bloc);

        // The peer called me and I declined. The SDK never reports my own
        // decline back to me — only this UI Kit event does.
        CometChatCallEvents.ccCallRejected(
          _call(status: 'rejected', initiator: _peerUser, receiverUid: _me),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(
          _calls(bloc),
          hasLength(1),
          reason: 'the person who declined saw no call message at all',
        );
        await bloc.close();
      },
    );

    test('a call I placed appears when I place it', () async {
      final bloc = _bloc(repo, listen: true);
      await _load(bloc);

      CometChatCallEvents.ccOutgoingCall(
        _call(status: 'initiated', initiator: _meUser, receiverUid: _peer),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(_calls(bloc), hasLength(1));
      await bloc.close();
    });

    test('cancelling updates the bubble placed a moment earlier', () async {
      final bloc = _bloc(repo, listen: true);
      await _load(bloc);

      CometChatCallEvents.ccOutgoingCall(
        _call(status: 'initiated', initiator: _meUser, receiverUid: _peer),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      CometChatCallEvents.ccCallRejected(
        _call(status: 'cancelled', initiator: _meUser, receiverUid: _peer),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final calls = _calls(bloc);
      expect(calls, hasLength(1));
      expect(calls.single.callStatus, 'cancelled');
      await bloc.close();
    });

    test('a call with someone else stays out of this chat', () async {
      final bloc = _bloc(repo, listen: true);
      await _load(bloc);

      CometChatCallEvents.ccCallRejected(
        _call(
          status: 'rejected',
          initiator: User(uid: 'stranger', name: 'Stranger'),
          receiverUid: _me,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(_calls(bloc), isEmpty);
      await bloc.close();
    });

    test('a closed list stops listening', () async {
      final bloc = _bloc(repo, listen: true);
      await _load(bloc);
      await bloc.close();

      // Would throw "Cannot add new events after calling close" if the
      // listener outlived the bloc.
      expect(
        () => CometChatCallEvents.ccCallRejected(
          _call(status: 'rejected', initiator: _peerUser, receiverUid: _me),
        ),
        returnsNormally,
      );
    });
  });

  blocTest<MessageListBloc, MessageListState>(
    'a call in a thread view is ignored',
    build: () => MessageListBloc(
      getMessagesUseCase: GetMessagesUseCase(repo),
      loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
      loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
      markAsReadUseCase: MarkAsReadUseCase(repo),
      markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
      markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
      user: _peerUser,
      parentMessageId: 99,
      disableSDKListeners: false,
    ),
    act: (bloc) async {
      bloc.add(
        const LoadMessages(
          conversationWith: _peer,
          conversationType: 'user',
          parentMessageId: 99,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      CometChatCallEvents.ccCallRejected(
        _call(status: 'rejected', initiator: _peerUser, receiverUid: _me),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
    },
    verify: (bloc) => expect(_calls(bloc), isEmpty),
  );
}
