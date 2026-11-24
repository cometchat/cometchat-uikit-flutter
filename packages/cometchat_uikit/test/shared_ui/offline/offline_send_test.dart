// W4 (ENG-41094): sends, Retry/Delete, option and receipt gating.
// One send helper, one state machine, one public event per transition
// (PR #23 §3.4 as corrected by G4; BEH-SEND-01/10/30/31/32/33/35/36).

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as kit;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatMessageEventListener,
        CometChatMessageEvents,
        CometChatMessageOption,
        CometChatUIKit,
        MessageReceiptUtils,
        ReceiptStatus;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_sync.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_send_state.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_send.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_upload_sdk.dart';

final User _me = User(uid: 'me', name: 'Me');

class _Recorder with CometChatMessageEventListener {
  final List<core_enums.MessageStatus> sent = [];
  final List<BaseMessage> sentMessages = [];
  final List<CometChatMessageSendState> states = [];

  @override
  void ccMessageSent(BaseMessage message, core_enums.MessageStatus status) {
    sent.add(status);
    sentMessages.add(message);
  }

  @override
  void ccMessageSendStateChanged(
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) => states.add(state);
}

class _Repo extends Fake implements MessageListRepository {
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
  }) async => const Success(<BaseMessage>[]);

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async => const Failure(message: 'not needed');
}

/// The composer's repository: real sends (datasource → helper), a fixed
/// logged-in user, nothing else.
class _ComposerRepo extends Fake implements kit.MessageComposerRepository {
  final kit.MessageComposerRepository _real = kit.MessageComposerRepositoryImpl(
    dataSource: kit.MessageComposerDataSourceImpl(),
  );

  @override
  Future<Result<User?>> getLoggedInUser() async => Success(_me);

  @override
  Future<Result<TextMessage>> sendTextMessage(TextMessage message) =>
      _real.sendTextMessage(message);
}

class _FakeContext extends Fake implements BuildContext {}

TextMessage _text({String muid = 'mu1', String? lid, int id = 0}) {
  final m = TextMessage(
    id: id,
    muid: muid,
    text: 'hello',
    sender: _me,
    receiverUid: 'bob',
    type: 'text',
    receiverType: 'user',
    sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
  m.localMessageId = lid;
  return m;
}

/// The SDK's acked copy of [m] with server id [id].
TextMessage _acked(TextMessage m, int id) {
  final a = _text(muid: m.muid, lid: m.localMessageId, id: id);
  return a;
}

/// Captures the per-call listener the helper hands the SDK.
class _Sdk {
  final List<BaseMessage> sends = [];
  final List<MessageSentListener> listeners = [];
  final List<String> retries = [];
  MessageSentListener? retryListener;
  final List<String> discards = [];
  void Function(String id)? discardOk;
  void Function(CometChatException e)? discardErr;

  MessageSentListener get last => listeners.last;

  void install() {
    OfflineSend.instance.debugSendOverride = (m, l) async {
      sends.add(m);
      listeners.add(l);
      return null;
    };
    OfflineSend.instance.debugRetryOverride = (lid, l) async {
      retries.add(lid);
      retryListener = l;
    };
    OfflineSend.instance.debugDiscardOverride = (lid, ok, err) async {
      discards.add(lid);
      discardOk = ok;
      discardErr = err;
    };
  }
}

void main() {
  final hub = OfflineHub.instance;
  final send = OfflineSend.instance;
  late _Recorder rec;
  late _Sdk sdk;
  final hubEvents = <OfflineHubEvent>[];
  late StreamSubscription<OfflineHubEvent> hubSub;

  setUp(() {
    hub.debugReset();
    send.debugReset();
    send.start();
    CometChat.debugSetOfflineEnabledOverride(true);
    CometChatUIKit.loggedInUser = _me;
    hub.debugLoginSuccess('me');
    rec = _Recorder();
    CometChatMessageEvents.addMessagesListener('w4_test', rec);
    sdk = _Sdk()..install();
    hubEvents.clear();
    hubSub = hub.events.listen(hubEvents.add);
  });

  tearDown(() async {
    await hubSub.cancel();
    CometChatMessageEvents.removeMessagesListener('w4_test');
    CometChat.debugSetOfflineEnabledOverride(null);
    send.debugReset();
  });

  List<SendStateEvent> sendEvents() =>
      hubEvents.whereType<SendStateEvent>().toList();

  /// A static send that has gone pending as `lm_1`.
  Future<(TextMessage, Future<TextMessage?>, List<Object>)> pendingStatic({
    String muid = 'mu1',
    String lid = 'lm_1',
  }) async {
    final m = _text(muid: muid);
    final callbacks = <Object>[];
    final future = send.trySend<TextMessage>(
      m,
      onSuccess: callbacks.add,
      onError: callbacks.add,
    )!;
    m.localMessageId = lid;
    m.sendState = 'PENDING';
    sdk.last.onMessagePending(m);
    hub.debugOutboxPending(m); // the global listener fires too
    await pumpEventQueue();
    return (m, future, callbacks);
  }

  group('state machine (statics)', () {
    test('pending: one sending transition, one inProgress, through the '
        'listener', () async {
      final (m, _, _) = await pendingStatic();
      expect(sdk.sends.single, same(m));
      expect(sendEvents().map((e) => e.state), [
        CometChatMessageSendState.sending,
      ]);
      expect(rec.states, [CometChatMessageSendState.sending]);
      expect(rec.sent, [core_enums.MessageStatus.inProgress]);
    });

    test('error after pending, still PENDING: queued, no failed event, future '
        'pending', () async {
      final (_, future, callbacks) = await pendingStatic();
      var settled = false;
      unawaited(future.then((_) => settled = true));
      sdk.last.onError(
        CometChatException('ERR_CONNECTION', 'offline', 'offline'),
      );
      await pumpEventQueue();
      expect(rec.states, [CometChatMessageSendState.sending]);
      expect(rec.sent, [core_enums.MessageStatus.inProgress]);
      expect(callbacks, isEmpty);
      expect(settled, isFalse);
    });

    test('sent: per-call + outbox fire, one sent event, future resolves, '
        'onSuccess once', () async {
      final (m, future, callbacks) = await pendingStatic();
      final acked = _acked(m, 42);
      sdk.last.onMessageSent(acked);
      hub.debugOutboxSent(acked);
      await pumpEventQueue();
      expect(rec.states, [
        CometChatMessageSendState.sending,
        CometChatMessageSendState.sent,
      ]);
      expect(rec.sent, [
        core_enums.MessageStatus.inProgress,
        core_enums.MessageStatus.sent,
      ]);
      expect(await future, same(acked));
      expect(callbacks, [same(acked)]);
    });

    test('direct error (no pending): failed (direct), onError, null result, '
        'metadata error as with offline off', () async {
      final m = _text();
      final errors = <Object>[];
      final future = send.trySend<TextMessage>(m, onError: errors.add)!;
      final e = CometChatException('ERR_X', 'boom', 'boom');
      sdk.last.onError(e);
      await pumpEventQueue();
      expect(await future, isNull);
      expect(errors, [same(e)]);
      expect(m.metadata?['error'], same(e));
      expect(rec.states, [CometChatMessageSendState.failed]);
      expect(rec.sent, [
        core_enums.MessageStatus.inProgress,
        core_enums.MessageStatus.error,
      ]);
      expect(send.isFailed(m), isTrue);
      expect(send.failureKindOf(m), OfflineFailureKind.direct);
    });

    for (final reason in [
      MessageFailureReason.transient,
      MessageFailureReason.permanent,
    ]) {
      test('outbox $reason: failed (outbox), no metadata stamp, one error '
          'event', () async {
        final (m, future, callbacks) = await pendingStatic();
        final failed = _text(muid: m.muid, lid: 'lm_1')..sendState = 'FAILED';
        sdk.last.onError(CometChatException('E', 'failed', reason.name));
        hub.debugOutboxFailed(failed, reason);
        await pumpEventQueue();
        expect(await future, isNull);
        expect(callbacks, hasLength(1));
        expect(failed.metadata?['error'], isNull); // invariant 2
        expect(m.metadata?['error'], isNull);
        expect(rec.states.last, CometChatMessageSendState.failed);
        expect(
          rec.sent.where((s) => s == core_enums.MessageStatus.error),
          hasLength(1),
        );
        expect(send.isFailed(failed), isTrue);
        expect(send.failureKindOf(failed), OfflineFailureKind.outbox);
      });
    }

    for (final reason in [
      MessageFailureReason.queueFull,
      MessageFailureReason.byteOverflow,
    ]) {
      test('refused $reason: failed (direct), Retry = fresh send', () async {
        final m = _text();
        final future = send.trySend<TextMessage>(m)!;
        // The SDK refuses: per-call onError, then the global failed event,
        // with no pending first.
        m.localMessageId = 'lm_r';
        sdk.last.onError(
          CometChatException('ERROR_OUTBOX_OVERFLOW', 'x', reason.name),
        );
        m.sendState = 'FAILED';
        hub.debugOutboxFailed(m, reason);
        await pumpEventQueue();
        expect(await future, isNull);
        expect(sendEvents().single.reason, reason);
        expect(send.failureKindOf(m), OfflineFailureKind.direct);
      });
    }

    for (final reason in [
      MessageFailureReason.discarded,
      MessageFailureReason.queueOverflow,
    ]) {
      test('$reason: a removal, no ccMessageSent error', () async {
        final (m, future, _) = await pendingStatic();
        final gone = _text(muid: m.muid, lid: 'lm_1')..sendState = 'FAILED';
        hub.debugOutboxFailed(gone, reason);
        await pumpEventQueue();
        expect(await future, isNull);
        expect(rec.sent, [core_enums.MessageStatus.inProgress]);
      });
    }

    test('a send flushed with no live listener (relaunch) is bridged to '
        'ccMessageSent once', () async {
      final m = _text(muid: 'old', lid: 'lm_9', id: 9);
      hub.debugOutboxSent(m);
      await pumpEventQueue();
      expect(rec.sent, [core_enums.MessageStatus.sent]);
      expect(rec.states, [CometChatMessageSendState.sent]);
    });

    test('logout: a pending static completes null quietly (G12)', () async {
      final (_, future, callbacks) = await pendingStatic();
      hub.debugLogout();
      await pumpEventQueue();
      expect(await future, isNull);
      expect(callbacks, isEmpty);
      expect(rec.sent, [core_enums.MessageStatus.inProgress]);
    });

    test('ENG-41552 H: a cache reset the SDK reports no per-send failure '
        'for fails every open send, once', () async {
      final (_, future, callbacks) = await pendingStatic();
      final batchDone = send.sendBatchMessage(
        MediaMessage(
          receiverType: 'user',
          type: 'image',
          receiverUid: 'bob',
          muid: 'mu_b',
          sender: _me,
        ),
      );
      hub.debugCacheReset(OfflineCacheResetReason.corrupted, null);
      await pumpEventQueue();
      expect(await future, isNull);
      await batchDone; // the batch is released, not left waiting
      expect(callbacks, hasLength(1));
      expect(
        (callbacks.single as CometChatException).code,
        OfflineSendError.discarded,
      );
      // An SDK discard that still arrives finds no live send: no second
      // onError.
      final lost = _text(lid: 'lm_1')..sendState = 'FAILED';
      hub.debugOutboxFailed(lost, MessageFailureReason.discarded);
      await pumpEventQueue();
      expect(callbacks, hasLength(1));
    });
  });

  group('composer path', () {
    test('resolves on sent; the composer announces it, the helper does '
        'not', () async {
      final m = _text();
      final future = send.tryComposerSend<TextMessage>(m)!;
      m.localMessageId = 'lm_c';
      m.sendState = 'PENDING';
      sdk.last.onMessagePending(m);
      final acked = _acked(m, 7);
      sdk.last.onMessageSent(acked);
      await pumpEventQueue();
      expect(await future, same(acked));
      expect(rec.sent, isEmpty); // composer emits its own inProgress/sent
      expect(rec.states, [
        CometChatMessageSendState.sending,
        CometChatMessageSendState.sent,
      ]);
    });

    test('outbox failure: the helper announces error once, the composer '
        'future stays pending', () async {
      final m = _text();
      var settled = false;
      unawaited(
        send
            .tryComposerSend<TextMessage>(m)!
            .then((_) => settled = true, onError: (_) => settled = true),
      );
      m.localMessageId = 'lm_c';
      m.sendState = 'PENDING';
      sdk.last.onMessagePending(m);
      final failed = _text(muid: m.muid, lid: 'lm_c')..sendState = 'FAILED';
      hub.debugOutboxFailed(failed, MessageFailureReason.permanent);
      await pumpEventQueue();
      expect(rec.sent, [core_enums.MessageStatus.error]);
      expect(settled, isFalse);
      expect(failed.metadata?['error'], isNull);
    });

    test('direct error: the composer future fails (it shows the error as '
        'with offline off)', () async {
      final m = _text();
      final future = send.tryComposerSend<TextMessage>(m)!;
      sdk.last.onError(CometChatException('ERR', 'x', 'x'));
      await expectLater(future, throwsA(isA<Exception>()));
    });
  });

  group('batch path', () {
    test('completes once queued, so the batch never waits for the '
        'network', () async {
      final m = MediaMessage(
        muid: 'b1',
        sender: _me,
        receiverUid: 'bob',
        type: 'image',
        receiverType: 'user',
        file: '/tmp/a.png',
      );
      var done = false;
      unawaited(send.sendBatchMessage(m).then((_) => done = true));
      await pumpEventQueue();
      expect(done, isFalse);
      m.localMessageId = 'lm_b';
      m.sendState = 'PENDING';
      sdk.last.onMessagePending(m);
      await pumpEventQueue();
      expect(done, isTrue);
    });
  });

  group('row state and gating', () {
    test('unsent and failed derive from status; incoming never unsent', () {
      final pending = _text(lid: 'l1')..sendState = 'PENDING';
      final failed = _text(muid: 'mu2', lid: 'l2')..sendState = 'FAILED';
      final sent = _text(muid: 'mu3', id: 3);
      final incoming = TextMessage(
        text: 't',
        sender: User(uid: 'bob', name: 'Bob'),
        receiverUid: 'me',
        type: 'text',
        receiverType: 'user',
      );
      expect(send.isUnsent(pending), isTrue);
      expect(send.isFailed(pending), isFalse);
      expect(send.isUnsent(failed), isTrue);
      expect(send.isFailed(failed), isTrue);
      expect(send.isUnsent(sent), isFalse);
      expect(send.isUnsent(incoming), isFalse);
    });

    test('option lists: unsent keeps Copy only; sent keeps all', () {
      List<CometChatMessageOption> opts() => [
        for (final id in [
          'replyMessage',
          'replyInThreadMessage',
          'editMessage',
          'deleteMessage',
          'copyMessage',
          'pinMessage',
          'saveMessage',
          'markAsUnread',
          'messageInformation',
          'translateMessage',
          'reportMessage',
          'shareMessage',
        ])
          CometChatMessageOption(id: id, title: id),
      ];
      final unsent = _text(lid: 'l1')..sendState = 'PENDING';
      expect(send.filterUnsent(unsent, opts()).map((o) => o.id), [
        'copyMessage',
      ]);
      expect(send.filterUnsent(_text(id: 5), opts()), hasLength(12));
    });

    testWidgets('unsent row menu: Retry, Delete, Copy (G4)', (tester) async {
      late List<String> ids;
      final unsent = _text(lid: 'l1')..sendState = 'FAILED';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ids = send
                  .unsentOptions(context, unsent, [
                    CometChatMessageOption(id: 'replyMessage', title: 'r'),
                    CometChatMessageOption(id: 'copyMessage', title: 'c'),
                    CometChatMessageOption(id: 'editMessage', title: 'e'),
                  ])
                  .map((o) => o.id)
                  .toList();
              return const SizedBox();
            },
          ),
        ),
      );
      expect(ids, [kRetryMessageOptionId, 'deleteMessage', 'copyMessage']);
    });

    test('receipts: no server receipt on an unsent row; OFF unchanged', () {
      final pending = _text(lid: 'l1')..sendState = 'PENDING';
      final failed = _text(muid: 'mu2', lid: 'l2')..sendState = 'FAILED';
      expect(
        MessageReceiptUtils.getReceiptStatus(pending),
        ReceiptStatus.waiting,
      );
      expect(MessageReceiptUtils.getReceiptStatus(failed), ReceiptStatus.error);
      final delivered = _text(muid: 'mu3', id: 3)..deliveredAt = DateTime.now();
      expect(
        MessageReceiptUtils.getReceiptStatus(delivered),
        ReceiptStatus.delivered,
      );
      CometChat.debugSetOfflineEnabledOverride(false);
      // OFF: today's ladder for every row an offline-off send can produce
      // (no localMessageId); a row left failed when offline went off keeps
      // its failed icon.
      final offSend = _text(muid: 'mu4');
      expect(
        MessageReceiptUtils.getReceiptStatus(offSend),
        ReceiptStatus.waiting,
      );
      offSend.metadata = {'error': 'x'};
      expect(
        MessageReceiptUtils.getReceiptStatus(offSend),
        ReceiptStatus.error,
      );
      expect(MessageReceiptUtils.getReceiptStatus(failed), ReceiptStatus.error);
    });
  });

  group('message list rows', () {
    late MessageListBloc bloc;
    final notices = <OfflineNotice>[];
    StreamSubscription<OfflineNotice>? noticeSub;

    setUp(() async {
      notices.clear();
      bloc = MessageListBloc(
        disableSDKListeners: true,
        disableReceipts: true,
        hideReplies: true,
        user: User(uid: 'bob', name: 'Bob'),
        getMessagesUseCase: GetMessagesUseCase(_Repo()),
      );
      noticeSub = offlineNoticesOf(bloc)!.listen(notices.add);
      bloc.add(
        const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
      );
      await pumpEventQueue();
    });

    tearDown(() async {
      await noticeSub?.cancel();
      await bloc.close();
    });

    Future<TextMessage> optimisticRow() async {
      final m = _text();
      bloc.add(
        MessageSentByUser(
          message: m,
          status: core_enums.MessageStatus.inProgress.toString(),
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.messages, [same(m)]);
      return m;
    }

    test('pending → sent replaces the row in place, receipt follows the '
        'ack', () async {
      final m = await optimisticRow();
      final pending = _text(lid: 'lm_1')..sendState = 'PENDING';
      hub.reportSend(pending, CometChatMessageSendState.sending);
      await pumpEventQueue();
      expect(bloc.state.messages.single, same(pending));
      expect(
        bloc.getReceiptNotifierForMessage(pending).value,
        MessageReceiptStatus.sending,
      );
      final acked = _acked(pending, 50);
      hub.reportSend(acked, CometChatMessageSendState.sent);
      await pumpEventQueue();
      expect(bloc.state.messages.single, same(acked));
      expect(bloc.state.messages, hasLength(1));
      expect(m.muid, acked.muid);
      expect(
        bloc.getReceiptNotifierForMessage(acked).value,
        MessageReceiptStatus.sent,
      );
    });

    test(
      'a receipt for an id not shown is held and applied on the ack',
      () async {
        await optimisticRow();
        final receipt = MessageReceipt(
          messageId: 60,
          sender: User(uid: 'bob', name: 'Bob'),
          receiverId: 'me',
          receiverType: 'user',
          receiptType: MessageReceipt.receiptTypeDelivered,
          timestamp: DateTime.now(),
          deliveredAt: DateTime.fromMillisecondsSinceEpoch(1700000005000),
        );
        bloc.add(DeliveryReceiptReceived(receipt));
        await pumpEventQueue();
        final ctxHeld = <int>[];
        final done = Completer<void>();
        messageListSeamHostOf(bloc)!.run((ctx) {
          ctxHeld.addAll(send.debugHeldReceipts(ctx).keys);
          done.complete();
        });
        await done.future;
        expect(ctxHeld, [60]);

        final acked = _acked(_text(lid: 'lm_1'), 55);
        hub.reportSend(acked, CometChatMessageSendState.sent);
        await pumpEventQueue();
        expect(bloc.state.messages.single.deliveredAt, isNotNull);
        expect(
          bloc.getReceiptNotifierForMessage(acked).value,
          MessageReceiptStatus.delivered,
        );
      },
    );

    test('queue full: failed row + one notice', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_q';
      m.sendState = 'FAILED';
      hub.debugOutboxFailed(m, MessageFailureReason.queueFull);
      await pumpEventQueue();
      expect(notices, [isA<QueueFull>()]);
      expect(
        bloc.getReceiptNotifierForMessage(m).value,
        MessageReceiptStatus.error,
      );
    });

    test(
      'discarded by the SDK: row removed, UnsentRemoved with the text',
      () async {
        final m = await optimisticRow();
        m.localMessageId = 'lm_d';
        m.sendState = 'PENDING';
        hub.reportSend(m, CometChatMessageSendState.sending);
        await pumpEventQueue();
        hub.debugOutboxFailed(m, MessageFailureReason.discarded);
        await pumpEventQueue();
        expect(bloc.state.messages, isEmpty);
        expect(notices.single, isA<UnsentRemoved>());
        expect((notices.single as UnsentRemoved).copyText, 'hello');
      },
    );

    test('Delete success: row removed, no notice, no public event', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_x';
      m.sendState = 'FAILED';
      rec.states.clear();
      send.delete(bloc, m);
      expect(sdk.discards, ['lm_x']);
      sdk.discardOk!('lm_x');
      await pumpEventQueue();
      expect(bloc.state.messages, isEmpty);
      expect(notices, isEmpty);
      expect(rec.states, isEmpty); // BEH-SEND-36
      expect(
        sendEvents().last.reason,
        MessageFailureReason.discarded,
      ); // the conversation list hears it on the hub
    });

    test('Delete in flight: notice, row stays (D33b)', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_x';
      m.sendState = 'SENDING';
      send.delete(bloc, m);
      sdk.discardErr!(
        CometChatException(OfflineSendError.inFlight, 'in flight', ''),
      );
      await pumpEventQueue();
      expect(bloc.state.messages, hasLength(1));
      expect(notices, [isA<SendingTryAgain>()]);
    });

    test(
      'Delete not found: row kept and re-rendered from its status',
      () async {
        final m = await optimisticRow();
        m.localMessageId = 'lm_x';
        m.sendState = 'FAILED';
        send.delete(bloc, m);
        sdk.discardErr!(
          CometChatException(OfflineSendError.notFound, 'gone', ''),
        );
        await pumpEventQueue();
        expect(bloc.state.messages, hasLength(1));
        expect(notices, isEmpty);
      },
    );

    test('Delete of a direct failure removes the in-memory row', () async {
      final m = await optimisticRow();
      final future = send.trySend<TextMessage>(m)!;
      sdk.last.onError(CometChatException('E', 'x', 'x'));
      await pumpEventQueue();
      await future;
      send.delete(bloc, m);
      await pumpEventQueue();
      expect(sdk.discards, isEmpty);
      expect(bloc.state.messages, isEmpty);
    });

    test(
      'Retry (outbox) calls retryMessage and shows sending at once',
      () async {
        final m = await optimisticRow();
        m.localMessageId = 'lm_r';
        m.sendState = 'FAILED';
        hub.debugOutboxFailed(m, MessageFailureReason.transient);
        await pumpEventQueue();
        send.retry(bloc, m);
        send.retry(bloc, m); // ignored while in flight
        await pumpEventQueue();
        expect(sdk.retries, ['lm_r']);
        expect(send.isFailed(m), isFalse);
        expect(rec.states.last, CometChatMessageSendState.sending);
        final acked = _acked(m, 77);
        sdk.retryListener!.onMessageSent(acked);
        await pumpEventQueue();
        expect(rec.states.last, CometChatMessageSendState.sent);
        expect(rec.sent.last, core_enums.MessageStatus.sent);
        expect(bloc.state.messages.single.id, 77);
      },
    );

    test('Retry mid-send: "Sending… try again" notice', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_s';
      m.sendState = 'SENDING';
      send.retry(bloc, m);
      sdk.retryListener!.onError(
        CometChatException(OfflineSendError.inFlight, 'in flight', ''),
      );
      await pumpEventQueue();
      expect(notices, [isA<SendingTryAgain>()]);
      expect(bloc.state.messages, hasLength(1));
    });

    test('Retry (direct) is a fresh send of the same row', () async {
      final m = await optimisticRow();
      unawaited(send.trySend<TextMessage>(m));
      sdk.last.onError(CometChatException('E', 'x', 'x'));
      await pumpEventQueue();
      expect(sdk.sends, hasLength(1));
      send.retry(bloc, m);
      await pumpEventQueue();
      expect(sdk.retries, isEmpty);
      expect(sdk.sends, hasLength(2));
      expect(sdk.sends.last.localMessageId, isNull);
      expect(m.metadata?['error'], isNull);
      expect(send.isFailed(m), isFalse);
    });

    test('offline went off: a leftover failed row is a direct failure — Retry '
        'resends on today\'s path, never retryMessage', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_w5';
      m.sendState = 'FAILED'; // as W5 marks it on the effective-off edge
      CometChat.debugSetOfflineEnabledOverride(false);
      final resent = <BaseMessage>[];
      send.debugOfflineOffResendOverride = (msg) async {
        resent.add(msg);
        return null;
      };
      expect(send.appliesTo(m), isTrue);
      expect(send.failureKindOf(m), OfflineFailureKind.direct);
      send.retry(bloc, m);
      await pumpEventQueue();
      expect(sdk.retries, isEmpty);
      expect(sdk.sends, isEmpty);
      expect(resent, [same(m)]);
      expect(m.localMessageId, isNull);
      expect(send.appliesTo(m), isFalse); // back to today's row
    });

    test('ENG-41552 I: offline went off: Retry of a failed interactive row '
        'resends it', () async {
      final m = InteractiveMessage(
        muid: 'mu_i',
        receiverUid: 'bob',
        receiverType: 'user',
        type: 'form',
        interactiveData: const {},
        sender: _me,
      );
      bloc.add(
        MessageSentByUser(
          message: m,
          status: core_enums.MessageStatus.inProgress.toString(),
        ),
      );
      await pumpEventQueue();
      m.localMessageId = 'lm_i';
      m.sendState = 'FAILED';
      CometChat.debugSetOfflineEnabledOverride(false);
      rec.sent.clear();
      // Today's interactive send static (no SDK here, so it then fails).
      send.retry(bloc, m);
      await pumpEventQueue();
      expect(rec.sent.first, core_enums.MessageStatus.inProgress);
      expect(rec.sentMessages.first, same(m));
      expect(m.localMessageId, isNull);
    });

    test('ENG-41552 I: offline went off: Retry of a failed row of a type with '
        'no send leaves it failed, never shown as sent', () async {
      final m = await optimisticRow();
      final card = CardMessage(
        muid: 'mu_c',
        receiverUid: 'bob',
        receiverType: 'user',
        type: 'card',
        sender: _me,
      )..localMessageId = 'lm_c';
      card.sendState = 'FAILED';
      CometChat.debugSetOfflineEnabledOverride(false);
      final resent = <BaseMessage>[];
      send.debugOfflineOffResendOverride = (msg) async {
        resent.add(msg);
        return null;
      };
      expect(send.isLeftoverFailed(card), isTrue);
      send.retry(bloc, card);
      await pumpEventQueue();
      expect(resent, isEmpty);
      expect(card.localMessageId, 'lm_c');
      expect(send.isFailed(card), isTrue);
      expect(bloc.state.messages, [same(m)]);
    });

    test('offline went off: Delete of a leftover failed row removes it from '
        'memory only', () async {
      final m = await optimisticRow();
      m.localMessageId = 'lm_w5';
      m.sendState = 'FAILED';
      CometChat.debugSetOfflineEnabledOverride(false);
      send.delete(bloc, m);
      await pumpEventQueue();
      expect(sdk.discards, isEmpty);
      expect(bloc.state.messages, isEmpty);
    });

    for (final retry in [true, false]) {
      test('offline went off: ${retry ? 'Retry' : 'Delete'} of a row W5 '
          'marked failed clears its direct-failure mark', () async {
        final sync = MessageListOfflineSync.instance;
        addTearDown(sync.debugReset);
        send.debugOfflineOffResendOverride = (msg) async => null;
        final host = messageListSeamHostOf(bloc)!;
        sync.handleConnected(host); // offline seen on in this session
        final m = await optimisticRow();
        m.localMessageId = 'lm_w5';
        m.sendState = 'PENDING';
        CometChat.debugSetOfflineEnabledOverride(false);
        host.run(sync.checkEffectiveOff); // W5 turns the row failed
        await pumpEventQueue();
        expect(sync.isDirectFailure(m), isTrue);
        expect(send.isLeftoverFailed(m), isTrue);
        retry ? send.retry(bloc, m) : send.delete(bloc, m);
        await pumpEventQueue();
        // Retry clears the localMessageId; restore it to look the mark up.
        expect(sync.isDirectFailure(m..localMessageId = 'lm_w5'), isFalse);
      });
    }

    test('offline off: a row with no localMessageId is never offline UI', () {
      CometChat.debugSetOfflineEnabledOverride(false);
      final m = _text()..metadata = {'error': 'x'};
      expect(send.appliesTo(m), isFalse);
    });
  });

  group('offline off', () {
    late FakeUploadSdkClient sdkClient;

    setUp(() async {
      CometChat.debugSetOfflineEnabledOverride(false);
      sdkClient = await registerFakeUploadSdk();
    });

    tearDown(clearFakeUploadSdk);

    test('statics: today\'s path and payloads (metadata error string '
        'object), helper untouched', () async {
      sdkClient.messageRepo.failWith = sdkFailure();
      final m = TextMessage(
        text: 'hi',
        receiverUid: 'bob',
        type: 'text',
        receiverType: 'user',
      );
      final result = await CometChatUIKit.sendTextMessage(m);
      await pumpEventQueue();
      expect(result, isNull);
      expect(sdk.sends, isEmpty); // the helper never ran
      expect(rec.sent, [
        core_enums.MessageStatus.inProgress,
        core_enums.MessageStatus.error,
      ]);
      expect(m.metadata?['error'], isA<CometChatException>());
      expect(rec.states, isEmpty);
      expect(hubEvents, isEmpty);
    });
  });

  group('review fixes', () {
    group('a queued composer send settling late keeps the composer mode', () {
      late kit.MessageComposerBloc composer;

      setUp(() async {
        final repo = _ComposerRepo();
        composer = kit.MessageComposerBloc(
          context: _FakeContext(),
          user: User(uid: 'bob', name: 'Bob'),
          sendTextMessageUseCase: kit.SendTextMessageUseCase(repo),
          getLoggedInUserUseCase: kit.GetMessageComposerLoggedInUserUseCase(
            repo,
          ),
          disableTypingEvents: true,
          disableSoundForMessages: true,
        );
        await pumpEventQueue();
      });

      tearDown(() => composer.close());

      /// Sends from the composer and leaves the message queued as `lm_q`.
      Future<TextMessage> queuedComposerSend() async {
        final m = _text(muid: 'mu_q');
        composer.add(kit.SendTextMessage(processedMessage: m));
        await pumpEventQueue();
        m.localMessageId = 'lm_q';
        m.sendState = 'PENDING';
        sdk.last.onMessagePending(m);
        await pumpEventQueue();
        return m;
      }

      test('edit mode survives the ack', () async {
        final m = await queuedComposerSend();
        final editing = _text(muid: 'mu_e', id: 3);
        composer.add(kit.SetEditMessage(editing));
        await pumpEventQueue();
        expect(composer.state.isEditMode, isTrue);

        sdk.last.onMessageSent(_acked(m, 9)); // reconnect, minutes later
        await pumpEventQueue();

        expect(composer.state.isEditMode, isTrue);
        expect(composer.state.editMessage, same(editing));
        expect(rec.sent.last, core_enums.MessageStatus.sent);
      });

      test('reply mode survives the ack', () async {
        final m = await queuedComposerSend();
        final parent = _text(muid: 'mu_p', id: 4);
        composer.add(kit.SetReplyMessage(parent));
        await pumpEventQueue();
        expect(composer.state.isReplyMode, isTrue);

        sdk.last.onMessageSent(_acked(m, 9));
        await pumpEventQueue();

        expect(composer.state.isReplyMode, isTrue);
        expect(composer.state.replyMessage, same(parent));
        expect(rec.sent.last, core_enums.MessageStatus.sent);
      });

      test(
        'reply mode survives an outbox failure of an earlier send',
        () async {
          final m = await queuedComposerSend();
          composer.add(kit.SetReplyMessage(_text(muid: 'mu_p', id: 4)));
          await pumpEventQueue();

          final failed = _text(muid: m.muid, lid: 'lm_q')..sendState = 'FAILED';
          hub.debugOutboxFailed(failed, MessageFailureReason.permanent);
          await pumpEventQueue();

          expect(composer.state.isReplyMode, isTrue);
          expect(failed.metadata?['error'], isNull); // invariant 2
        },
      );

      test('an ack with nothing opened since still ends in success', () async {
        final m = await queuedComposerSend();
        sdk.last.onMessageSent(_acked(m, 9));
        await pumpEventQueue();
        expect(composer.state.status, kit.MessageComposerStatus.success);
      });
    });

    group('offline turned off before the SDK answered: the send settles', () {
      test('statics: sent with no pending resolves the future', () async {
        final m = _text();
        final callbacks = <Object>[];
        final future = send.trySend<TextMessage>(m, onSuccess: callbacks.add)!;
        CometChat.debugSetOfflineEnabledOverride(false);
        final acked = _acked(m, 5);
        sdk.last.onMessageSent(acked);
        await pumpEventQueue();
        expect(await future, same(acked));
        expect(callbacks, [same(acked)]);
        expect(rec.sent.last, core_enums.MessageStatus.sent);
      });

      test(
        'statics: error with no pending completes null with onError',
        () async {
          final m = _text();
          final errors = <Object>[];
          final future = send.trySend<TextMessage>(m, onError: errors.add)!;
          CometChat.debugSetOfflineEnabledOverride(false);
          final e = CometChatException('ERR_X', 'boom', 'boom');
          sdk.last.onError(e);
          await pumpEventQueue();
          expect(await future, isNull);
          expect(errors, [same(e)]);
          expect(m.metadata?['error'], same(e)); // today's offline-off payload
          expect(rec.sent.last, core_enums.MessageStatus.error);
        },
      );

      test(
        'statics: error after pending completes null with onError',
        () async {
          final (_, future, callbacks) = await pendingStatic();
          CometChat.debugSetOfflineEnabledOverride(false);
          final e = CometChatException('ERR_X', 'boom', 'boom');
          sdk.last.onError(e);
          await pumpEventQueue();
          expect(await future, isNull);
          expect(callbacks, [same(e)]);
        },
      );

      test('batch: an error releases the batch', () async {
        final m = MediaMessage(
          muid: 'mu_b',
          receiverUid: 'bob',
          receiverType: 'user',
          type: 'image',
          sender: _me,
        );
        var released = false;
        unawaited(send.sendBatchMessage(m).then((_) => released = true));
        CometChat.debugSetOfflineEnabledOverride(false);
        sdk.last.onError(CometChatException('ERR_X', 'boom', 'boom'));
        await pumpEventQueue();
        expect(released, isTrue);
        expect(rec.sent.last, core_enums.MessageStatus.error);
      });

      test('composer: a sent after pending resolves its future', () async {
        final m = _text();
        final future = send.tryComposerSend<TextMessage>(m)!;
        m.localMessageId = 'lm_c';
        m.sendState = 'PENDING';
        sdk.last.onMessagePending(m);
        CometChat.debugSetOfflineEnabledOverride(false);
        final acked = _acked(m, 8);
        sdk.last.onMessageSent(acked);
        await pumpEventQueue();
        expect(await future, same(acked));
      });
    });

    group('a final failure after a refused Retry reports its own error', () {
      test('outbox failure only: not the in-flight refusal', () async {
        final (m, future, callbacks) = await pendingStatic();
        m.sendState = 'SENDING';
        send.retry(Object(), m);
        sdk.retryListener!.onError(
          CometChatException(OfflineSendError.inFlight, 'in flight', ''),
        );
        final failed = _text(muid: m.muid, lid: 'lm_1')..sendState = 'FAILED';
        hub.debugOutboxFailed(failed, MessageFailureReason.transient);
        await pumpEventQueue();
        expect(await future, isNull);
        final error = callbacks.single as CometChatException;
        expect(error.code, 'ERROR_MESSAGE_SEND_FAILED');
      });

      test('per-call final error, then outbox failure: that error', () async {
        final (m, future, callbacks) = await pendingStatic();
        m.sendState = 'SENDING';
        send.retry(Object(), m);
        sdk.retryListener!.onError(
          CometChatException(OfflineSendError.inFlight, 'in flight', ''),
        );
        final finalError = CometChatException(
          'ERROR_MESSAGE_SEND_FAILED',
          'Message send failed',
          MessageFailureReason.permanent.name,
        );
        sdk.last.onError(finalError);
        final failed = _text(muid: m.muid, lid: 'lm_1')..sendState = 'FAILED';
        hub.debugOutboxFailed(failed, MessageFailureReason.permanent);
        await pumpEventQueue();
        expect(await future, isNull);
        expect(callbacks, [same(finalError)]);
      });
    });
  });
}
