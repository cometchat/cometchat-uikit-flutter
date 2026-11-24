/// Offline on, Android and iOS: a call of the open chat that starts or stops
/// ringing brings its new call message into the list.
///
/// A call message reaches no message listener (BEH-SYNC-25) and, with offline
/// on, `SyncMessages` fetches nothing, so the list reads the newest page from
/// the server and merges it by message id: the call bubble is added once,
/// rows not yet sent stay, and a read that fails offline changes nothing.
///
///   flutter test test/shared_ui/offline/call_activity_offline_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show IncomingCallListener, InitiatedCall;
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/data/datasources/message_list_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/data/repositories/message_list_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_reads.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_chat_uikit/src/call_activity_listener.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'alice', name: 'Alice');
final _bob = User(uid: 'bob', name: 'Bob');

DateTime _at(int id) =>
    DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000);

/// Bob's message with server [id], sent at second [id].
TextMessage _m(int id) => TextMessage(
  id: id,
  text: 'm$id',
  sender: _bob,
  receiverUid: 'alice',
  type: 'text',
  receiverType: 'user',
  conversationId: 'alice_user_bob',
  sentAt: _at(id),
);

/// Alice's message not sent yet (no server id).
TextMessage _unsent() => TextMessage(
  id: 0,
  text: 'own',
  sender: _alice,
  receiverUid: 'bob',
  type: 'text',
  receiverType: 'user',
  conversationId: 'alice_user_bob',
  muid: 'M1',
  sentAt: _at(999),
)..localMessageId = 'L1';

/// Bob's call to Alice, message [id], in [status].
Call _call({int id = 3, String status = 'initiated'}) => Call(
  id: id,
  sessionId: 'session_1',
  callStatus: status,
  action: status,
  callInitiator: _bob,
  sender: _bob,
  receiverUid: 'alice',
  type: 'audio',
  receiverType: 'user',
  category: 'call',
  conversationId: 'alice_user_bob',
  sentAt: _at(id),
);

/// Bob's call to Alice, as the Calls SDK reports it.
InitiatedCall _pushed() => InitiatedCall(
  sessionId: 'session_1',
  messageId: '3',
  sender: 'bob',
  receiver: 'alice',
  receiverType: 'user',
  type: 'audio',
);

/// One two-phase read the bloc made.
class _Read {
  _Read(this.request);
  final MessagesRequest request;
  final StreamController<TwoPhaseResult<BaseMessage>> ctl =
      StreamController<TwoPhaseResult<BaseMessage>>();

  void cached(List<BaseMessage> rows) => ctl.add(Cached(rows));
  void server(List<BaseMessage> rows) {
    ctl.add(Server(rows));
    ctl.close();
  }

  void error(String code) {
    ctl.add(PhaseError(CometChatException(code, code, code)));
    ctl.close();
  }
}

class _FakeDataSource extends Fake
    implements MessageListRemoteDataSource, MessageListTwoPhaseDataSource {
  final List<_Read> reads = [];

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchPreviousTwoPhase(
    MessagesRequest request,
  ) {
    final r = _Read(request);
    reads.add(r);
    return r.ctl.stream;
  }

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchNextTwoPhase(
    MessagesRequest request,
  ) {
    final r = _Read(request);
    reads.add(r);
    return r.ctl.stream;
  }
}

void main() {
  final hub = OfflineHub.instance;
  late Map<String, IncomingCallListener> callsSdk;
  late Map<int, BaseMessage> server;
  late _FakeDataSource ds;
  late MessageListBloc bloc;

  List<int> ids() => bloc.state.messages.map((m) => m.id).toList();
  List<Call> calls() => bloc.state.messages.whereType<Call>().toList();
  _Read last() => ds.reads.last;

  /// Opens the chat on [rows] (cached and server), plus a row not yet sent.
  Future<void> open(List<BaseMessage> rows) async {
    bloc.add(
      const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
    );
    await pumpEventQueue();
    last().cached([...rows, _unsent()]);
    last().server(rows);
    await pumpEventQueue();
  }

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('alice');
    CometChatUIKit.loggedInUser = _alice;
    callsSdk = {};
    CallActivityListener.addIncomingCallListener = (id, l) => callsSdk[id] = l;
    CallActivityListener.removeIncomingCallListener = callsSdk.remove;
    server = {};
    CallActivityListener.debugFetchMessage = (id) async => server[id];
    ds = _FakeDataSource();
    bloc = MessageListBloc(
      disableReceipts: true,
      user: _bob,
      getMessagesUseCase: GetMessagesUseCase(
        MessageListRepositoryImpl(remoteDataSource: ds),
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    CallActivityListener.debugReset();
    CometChat.debugSetOfflineEnabledOverride(null);
    CometChatUIKit.loggedInUser = null;
  });

  const skip = kIsWeb ? 'Android and iOS only' : false;

  test('a call activity reads the newest page from the server and adds the '
      'new call bubble once, keeping the row not yet sent', () async {
    await open([_m(1), _m(2)]);
    expect(ids(), [1, 2, 0]);
    final readsBefore = ds.reads.length;

    callsSdk.values.single.onIncomingCallReceived(_pushed());
    await pumpEventQueue();

    expect(ds.reads, hasLength(readsBefore + 1));
    expect(last().request.messageId, isNull); // the newest page
    // The cache cannot know the call: its page is not applied.
    last().cached([_m(1), _m(2), _m(7)]);
    await pumpEventQueue();
    expect(ids(), [1, 2, 0]);

    last().server([_m(1), _m(2), _call()]);
    await pumpEventQueue();
    expect(ids(), [1, 2, 3, 0]);
    expect(calls().single.callStatus, 'initiated');
    expect(messageListReadsViewOf(bloc).connectToLoadMore.value, isFalse);
  }, skip: skip);

  test('repeated activity for the same call never adds it twice', () async {
    await open([_m(1), _m(2)]);
    callsSdk.values.single.onIncomingCallReceived(_pushed());
    await pumpEventQueue();
    last().server([_m(1), _m(2), _call()]);
    await pumpEventQueue();

    server[3] = _call(status: 'rejected');
    callsSdk.values.single.onIncomingCallEnded(_pushed(), 'rejected');
    await pumpEventQueue();
    last().server([_m(1), _m(2), _call(status: 'rejected')]);
    await pumpEventQueue();

    expect(ids(), [1, 2, 3, 0]);
    expect(calls().single.callStatus, 'rejected');
  }, skip: skip);

  test('offline, a failed read changes nothing', () async {
    await open([_m(1), _m(2)]);
    final before = List<BaseMessage>.of(bloc.state.messages);

    callsSdk.values.single.onIncomingCallReceived(_pushed());
    await pumpEventQueue();
    last().cached([_m(1), _m(2)]);
    last().error('err_connection');
    await pumpEventQueue();

    expect(bloc.state.messages, before);
    expect(messageListReadsViewOf(bloc).connectToLoadMore.value, isFalse);
  }, skip: skip);
}
