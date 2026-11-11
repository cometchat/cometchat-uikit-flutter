/// The Chats list and this device's own calls (P1-C13; owner's P1-D10 A,
/// adopted in round 5).
///
/// The list heard calls only through the chat SDK, which never tells the
/// caller about the call it just placed ("initiated"), so the caller's row
/// did not move. It now also hears the UI Kit's call events (ccOutgoingCall,
/// ccCallAccepted, ccCallRejected, ccCallEnded), as Android's conversations
/// view model does. Both paths follow the dashboard's "call activities"
/// conversation-update setting, which was fetched and never read.
///
/// Ringing v2 registers the chat SDK's call listener on web only; its tests
/// are skipped off web (run them with `--platform chrome`). On Android and
/// iOS the Calls SDK's incoming call listener says when a call starts or
/// stops ringing, on either side, and the call's row is updated, as Android's
/// UI Kit does; those tests are skipped on web.
///
///   flutter test test/chat_ui/conversations/conversations_call_activities_test.dart
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
    show CometChatCallEvents, CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/src/call_activity_listener.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show IncomingCallListener, InitiatedCall;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConversationsRepository extends Mock
    implements ConversationsRepository {}

final _me = User(uid: 'me', name: 'Me');

Conversation _conversation(String uid, {required DateTime at}) => Conversation(
  conversationId: 'me_user_$uid',
  conversationType: 'user',
  conversationWith: User(uid: uid, name: uid),
  updatedAt: at,
);

/// A 1:1 call between me and [uid]; [byMe] says who sent it.
Call _call(String uid, {bool byMe = true, String status = 'initiated'}) => Call(
  sessionId: 'session-$uid',
  callStatus: status,
  receiverUid: byMe ? uid : 'me',
  receiverType: 'user',
  type: 'audio',
  sender: byMe ? _me : User(uid: uid, name: uid),
  sentAt: DateTime(2026, 10, 1, 12),
  updatedAt: DateTime(2026, 10, 1, 12),
);

/// [uid]'s 1:1 call to me, as the Calls SDK reports it from a push.
InitiatedCall _pushed(String uid) => InitiatedCall(
  sessionId: 'session-$uid',
  messageId: '901',
  sender: uid,
  receiver: 'me',
  receiverType: 'user',
  type: 'audio',
);

Future<void> _flush() => pumpEventQueue(times: 50);

void main() {
  late _MockConversationsRepository repo;
  late Map<String, CallListener> sdkCallListeners;
  late Map<String, IncomingCallListener> callsSdkListeners;
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

  /// A loaded list: uid-1 on top, uid-2 below it.
  Future<ConversationsBloc> loaded() async {
    final bloc = build();
    bloc.add(const LoadConversations());
    await _flush();
    expect(bloc.state, isA<ConversationsLoaded>());
    return bloc;
  }

  List<String> order(ConversationsBloc bloc) =>
      (bloc.state as ConversationsLoaded).conversations
          .map((c) => (c.conversationWith as User).uid)
          .toList();

  setUp(() {
    repo = _MockConversationsRepository();
    blocs = [];
    sdkCallListeners = {};
    ChatSdkListeners.debugAddCallListener = (id, listener) =>
        sdkCallListeners[id] = listener;
    ChatSdkListeners.debugRemoveCallListener = sdkCallListeners.remove;
    callsSdkListeners = {};
    CallActivityListener.addIncomingCallListener = (id, listener) =>
        callsSdkListeners[id] = listener;
    CallActivityListener.removeIncomingCallListener = callsSdkListeners.remove;
    when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(_me));
    when(() => repo.getConversations(limit: any(named: 'limit'))).thenAnswer(
      (_) async => Success([
        _conversation('uid-1', at: DateTime(2026, 10, 1, 10)),
        _conversation('uid-2', at: DateTime(2026, 10, 1, 9)),
      ]),
    );
    when(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    ).thenAnswer((invocation) async {
      final uid = invocation.namedArguments[#conversationWith] as String;
      return Success(_conversation(uid, at: DateTime(2026, 10, 1, 9)));
    });
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    ChatSdkListeners.debugReset();
    CallActivityListener.debugReset();
    CometChatUIKit.conversationUpdateSettings = null;
  });

  test('P1-C13 / P1-N15: placing a call to uid-2 moves its row to the top, '
      'with the call as its last message', () async {
    final bloc = await loaded();
    expect(order(bloc), ['uid-1', 'uid-2']);

    final call = _call('uid-2');
    CometChatCallEvents.ccOutgoingCall(call);
    await _flush();

    expect(order(bloc), ['uid-2', 'uid-1']);
    final top = (bloc.state as ConversationsLoaded).conversations.first;
    expect(top.lastMessage, same(call));
    verify(
      () => repo.getConversation(
        conversationWith: 'uid-2',
        conversationType: 'user',
      ),
    ).called(1);
  });

  test('P1-C13: accepting, declining and ending a call here update the row '
      'too', () async {
    final bloc = await loaded();
    final events = <void Function(Call)>[
      CometChatCallEvents.ccCallAccepted,
      CometChatCallEvents.ccCallRejected,
      CometChatCallEvents.ccCallEnded,
    ];
    for (final fire in events) {
      // uid-2's call, sent by uid-2, answered here.
      final call = _call('uid-2', byMe: false, status: 'ongoing');
      fire(call);
      await _flush();
      expect(order(bloc).first, 'uid-2');
      expect(
        (bloc.state as ConversationsLoaded).conversations.first.lastMessage,
        same(call),
      );
    }
  });

  test('P1-D10 / P1-E28: with call activities off, neither this device\'s '
      'call events nor the SDK\'s move the list', () async {
    CometChatUIKit.conversationUpdateSettings = ConversationUpdateSettings(
      callActivities: false,
      groupActions: true,
      customMessages: true,
      messageReplies: true,
    );
    final bloc = await loaded();

    CometChatCallEvents.ccOutgoingCall(_call('uid-2'));
    // The chat SDK's call listener exists on web only (ringing v2).
    if (kIsWeb) {
      final sdk = sdkCallListeners.values.single;
      final fromSdk = _call('uid-2', byMe: false);
      sdk.onIncomingCallReceived(fromSdk);
      sdk.onOutgoingCallAccepted(fromSdk);
      sdk.onOutgoingCallRejected(fromSdk);
      sdk.onIncomingCallCancelled(fromSdk);
      sdk.onCallEndedMessageReceived(fromSdk);
    } else {
      final calls = callsSdkListeners.values.single;
      calls.onIncomingCallReceived(_pushed('uid-2'));
      calls.onIncomingCallEnded(_pushed('uid-2'), 'rejected');
    }
    await _flush();

    expect(order(bloc), ['uid-1', 'uid-2']);
    verifyNever(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    );
  });

  test(
    'P1-D10: with call activities on (or unknown), the chat SDK\'s call '
    'events move the list',
    () async {
      CometChatUIKit.conversationUpdateSettings = ConversationUpdateSettings(
        callActivities: true,
        groupActions: true,
        customMessages: true,
        messageReplies: true,
      );
      final bloc = await loaded();

      sdkCallListeners.values.single.onIncomingCallReceived(
        _call('uid-2', byMe: false),
      );
      await _flush();
      expect(order(bloc), ['uid-2', 'uid-1']);

      // Unknown (the setting not fetched): on, as before.
      CometChatUIKit.conversationUpdateSettings = null;
      sdkCallListeners.values.single.onCallEndedMessageReceived(
        _call('uid-1', byMe: false, status: 'ended'),
      );
      await _flush();
      expect(order(bloc), ['uid-1', 'uid-2']);
    },
    skip: kIsWeb
        ? false
        : 'web only: ringing v2 registers the chat SDK '
              'call listener on web only',
  );

  test(
    'ringing v2 on Android and iOS: the chat SDK\'s call listener is not '
    'registered, and this device\'s own call events still move the list',
    () async {
      final bloc = await loaded();

      expect(sdkCallListeners, isEmpty);
      CometChatCallEvents.ccOutgoingCall(_call('uid-2'));
      await _flush();
      expect(order(bloc).first, 'uid-2');
    },
    skip: kIsWeb ? 'Android and iOS only' : false,
  );

  test('ringing v2 on Android and iOS: a call from the other side ringing here '
      'moves its row to the top, with the call as its last message', () async {
    final bloc = await loaded();
    expect(order(bloc), ['uid-1', 'uid-2']);

    callsSdkListeners.values.single.onIncomingCallReceived(_pushed('uid-2'));
    await _flush();

    expect(order(bloc), ['uid-2', 'uid-1']);
    final last =
        (bloc.state as ConversationsLoaded).conversations.first.lastMessage
            as Call;
    expect(last.sessionId, 'session-uid-2');
    expect(last.callStatus, 'initiated');
    expect(last.id, 901);
    verify(
      () => repo.getConversation(
        conversationWith: 'uid-2',
        conversationType: 'user',
      ),
    ).called(1);
  }, skip: kIsWeb ? 'Android and iOS only' : false);

  test('ringing v2 on Android and iOS: a call that stops ringing updates its '
      'row with how it ended, on either platform\'s reasons', () async {
    final bloc = await loaded();
    final listener = callsSdkListeners.values.single;
    const reasons = {
      'rejected': 'rejected', // Android
      'declined': 'rejected', // iOS
      'cancelled': 'cancelled',
      'busy': 'busy',
      'unanswered': 'unanswered',
      'timedOut': 'unanswered', // iOS
      'ended': 'ended',
      'ongoing': 'ongoing', // Android: answered elsewhere
      'answeredElsewhere': 'ongoing', // iOS
    };
    for (final MapEntry(key: reason, value: status) in reasons.entries) {
      listener.onIncomingCallEnded(_pushed('uid-2'), reason);
      await _flush();
      final top = (bloc.state as ConversationsLoaded).conversations.first;
      expect((top.conversationWith as User).uid, 'uid-2', reason: reason);
      expect((top.lastMessage as Call).callStatus, status, reason: reason);
      // Moved back below, so the next reason moves it again.
      listener.onIncomingCallReceived(_pushed('uid-1'));
      await _flush();
    }
  }, skip: kIsWeb ? 'Android and iOS only' : false);

  test('ringing v2 on Android and iOS: an end reason that says nothing of the '
      'call (iOS\'s filtered) leaves the list alone', () async {
    final bloc = await loaded();

    callsSdkListeners.values.single.onIncomingCallEnded(
      _pushed('uid-2'),
      'filtered',
    );
    await _flush();

    expect(order(bloc), ['uid-1', 'uid-2']);
    verifyNever(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    );
  }, skip: kIsWeb ? 'Android and iOS only' : false);

  test('P1-C13: close() removes the call listeners', () async {
    final bloc = await loaded();
    final before = CometChatCallEvents.callEventsListener.length;
    // The chat SDK's call listener exists on web only (ringing v2), the
    // Calls SDK's on Android and iOS only.
    expect(sdkCallListeners, hasLength(kIsWeb ? 1 : 0));
    expect(callsSdkListeners, hasLength(kIsWeb ? 0 : 1));
    final callsListener = callsSdkListeners.values.firstOrNull;

    await bloc.close();
    blocs.remove(bloc);

    expect(sdkCallListeners, isEmpty);
    expect(callsSdkListeners, isEmpty);
    // A call the Calls SDK still reports to the old listener reaches nothing.
    callsListener?.onIncomingCallReceived(_pushed('uid-2'));
    expect(CometChatCallEvents.callEventsListener.length, before - 1);
    // A call event after close() reaches nothing.
    CometChatCallEvents.ccOutgoingCall(_call('uid-2'));
    await _flush();
    verifyNever(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    );
  });
}
