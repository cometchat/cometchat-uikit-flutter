// W7 (ENG-41130): a thread's reply count while own replies wait to be sent
// (PR #23 README §3.9 "Thread header reply count", BEH-MUT-10). +1 at a
// first enqueue (never on a Retry), −1 once on discard (counted here or
// already in the parent value), a fresher SDK parent replaces the value, and
// no reply is ever counted twice. Offline off keeps today's count.

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/threaded_header/bloc/threaded_header_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/threaded_header/bloc/threaded_header_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/domain/events/message_events/cometchat_message_events.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_send_state.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/thread_reply_count_offline.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const _parentId = 10;
final _me = User(uid: 'me', name: 'me');
final _bob = User(uid: 'bob', name: 'bob');

BaseMessage _parent({int replyCount = 3}) => BaseMessage(
  id: _parentId,
  muid: 'p',
  receiverUid: 'bob',
  type: 'text',
  receiverType: 'user',
  sender: _me,
  receiver: _bob,
  replyCount: replyCount,
);

/// Composed long before any ledger in these tests started.
final _old = DateTime(2020);

BaseMessage _reply(
  String? lid, {
  String muid = '',
  int parent = _parentId,
  DateTime? sentAt,
}) => BaseMessage(
  id: 0,
  muid: muid,
  receiverUid: 'bob',
  type: 'text',
  receiverType: 'user',
  sender: _me,
  receiver: _bob,
  parentMessageId: parent,
  localMessageId: lid,
  sentAt: sentAt,
);

SendStateEvent _state(
  BaseMessage m,
  CometChatMessageSendState s, [
  MessageFailureReason? reason,
]) => SendStateEvent(
  OfflineHub.instance.gen,
  m.localMessageId ?? '',
  m,
  s,
  reason,
);

SendStateEvent _discard(BaseMessage m) =>
    _state(m, CometChatMessageSendState.failed, MessageFailureReason.discarded);

const _minute = Duration(minutes: 1);

/// The few members of the seam context the reply-count collector reads.
class _Ctx extends Fake implements MessageListSeamContext {
  _Ctx(this.rows, {this.parentMessageId});

  final List<BaseMessage> rows;
  final Map<int, int> seeded = {};

  @override
  final int? parentMessageId;

  @override
  MessageListState get state => MessageListState(messages: rows);

  @override
  int? findMessageIndex(int messageId) {
    final i = rows.indexWhere((m) => m.id == messageId);
    return i < 0 ? null : i;
  }

  @override
  void initializeThreadReplyCount(int parentMessageId, int replyCount) =>
      seeded[parentMessageId] = replyCount;
}

void main() {
  group('ThreadReplyLedger', () {
    test('+1 at pending, never again for the same reply', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1', muid: 'm1');
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 0);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sent)), 0);
      expect(ledger.claimSent(r), isFalse);
    });

    test('a discard of a counted reply gives −1 once', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1');
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
      expect(ledger.deltaFor(_discard(r)), -1);
      expect(ledger.deltaFor(_discard(r)), 0);
    });

    test('a discard of an unseen reply gives −1 once (the parent has it)', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1', sentAt: _old);
      expect(ledger.deltaFor(_discard(r)), -1);
      expect(ledger.deltaFor(_discard(r)), 0);
      // Its unknown compose time counts the same way.
      expect(ledger.deltaFor(_discard(_reply('l2'))), -1);
    });

    test(
      'a duplicate discard (user Delete, then the SDK outbox) is no change',
      () {
        final ledger = ThreadReplyLedger();
        final r = _reply('l1', muid: 'm1', sentAt: _old);
        // W4's Delete: reportRemoved → failed + discarded with the row's lid.
        final userDelete = SendStateEvent(
          OfflineHub.instance.gen,
          'l1',
          r,
          CometChatMessageSendState.failed,
          MessageFailureReason.discarded,
        );
        expect(ledger.deltaFor(userDelete), -1);
        // The SDK's outbox discard of the same row (matched by muid too).
        final sdkCopy = _reply('', muid: 'm1', sentAt: _old);
        expect(ledger.deltaFor(_discard(sdkCopy)), 0);
        expect(ledger.deltaFor(_discard(r)), 0);
      },
    );

    test('a discard the count never included is no change', () {
      final ledger = ThreadReplyLedger();
      // Never in the outbox (a direct failure, no localMessageId).
      expect(ledger.deltaFor(_discard(_reply(null, muid: 'd1'))), 0);
      // Composed after the parent value and never seen pending.
      final late = _reply('l3', sentAt: DateTime.now().add(_minute));
      expect(ledger.deltaFor(_discard(late)), 0);
    });

    test('a Retry of a reply already in the parent value adds nothing', () {
      // Empty ledger (header reopened, or a cold start); the parent the SDK
      // delivered already holds the failed reply.
      final ledger = ThreadReplyLedger();
      final r = _reply('l1', muid: 'm1', sentAt: _old);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 0);
      expect(
        ledger.deltaFor(
          _state(
            r,
            CometChatMessageSendState.failed,
            MessageFailureReason.transient,
          ),
        ),
        0,
      );
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 0);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sent)), 0);
      expect(ledger.claimSent(r), isFalse);
      // Its discard still takes it back, once.
      expect(ledger.deltaFor(_discard(r)), -1);
      expect(ledger.deltaFor(_discard(r)), 0);
    });

    test('a first enqueue after the parent value adds one', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1', sentAt: DateTime.now().add(_minute));
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
    });

    test('after a rebase, a reply composed before it is in the value', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1', sentAt: DateTime.now().add(_minute));
      ledger.rebase();
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
      final before = _reply('l2', sentAt: _old);
      ledger.rebase();
      expect(
        ledger.deltaFor(_state(before, CometChatMessageSendState.sending)),
        0,
      );
    });

    test('a retry or a transient failure does not change the count', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l1');
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
      expect(
        ledger.deltaFor(
          _state(
            r,
            CometChatMessageSendState.failed,
            MessageFailureReason.transient,
          ),
        ),
        0,
      );
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 0);
    });

    test('a reply matches by muid when the localMessageId is missing', () {
      final ledger = ThreadReplyLedger();
      expect(
        ledger.deltaFor(
          _state(_reply(null, muid: 'm1'), CometChatMessageSendState.sending),
        ),
        1,
      );
      expect(ledger.claimSent(_reply(null, muid: 'm1')), isFalse);
    });

    test('a sent reply outside the offline send path adds once', () {
      final ledger = ThreadReplyLedger();
      expect(ledger.claimSent(_reply(null, muid: 'm9')), isTrue);
      expect(ledger.claimSent(_reply(null, muid: 'm9')), isFalse);
    });

    test('a sent seen before its pending event still counts once', () {
      final ledger = ThreadReplyLedger();
      final r = _reply('l8', muid: 'm8');
      expect(ledger.claimSent(r), isFalse);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sending)), 1);
      expect(ledger.deltaFor(_state(r, CometChatMessageSendState.sent)), 0);
    });

    test('a queued reply never adds at sent (the SDK parent has it)', () {
      final ledger = ThreadReplyLedger();
      expect(ledger.claimSent(_reply('l7')), isFalse);
    });
  });

  group('main message list collector', () {
    final owner = Object();

    test('pending +1 and discard −1 move the parent row and notifier', () {
      final parent = _parent(replyCount: 2);
      final ctx = _Ctx([parent]);
      final r = _reply('l1');
      ThreadReplyCountOffline.onMessageListHubEvent(
        owner,
        ctx,
        _state(r, CometChatMessageSendState.sending),
      );
      expect(parent.replyCount, 3);
      expect(ctx.seeded[_parentId], 3);
      expect(ThreadReplyCountOffline.claimSentReply(owner, r), isFalse);

      ThreadReplyCountOffline.onMessageListHubEvent(
        owner,
        ctx,
        _state(
          r,
          CometChatMessageSendState.failed,
          MessageFailureReason.discarded,
        ),
      );
      expect(parent.replyCount, 2);
      expect(ctx.seeded[_parentId], 2);
    });

    test('a thread list keeps today\'s count', () {
      final parent = _parent(replyCount: 2);
      final ctx = _Ctx([parent], parentMessageId: _parentId);
      ThreadReplyCountOffline.onMessageListHubEvent(
        Object(),
        ctx,
        _state(_reply('l1'), CometChatMessageSendState.sending),
      );
      expect(parent.replyCount, 2);
      expect(ctx.seeded, isEmpty);
    });

    test('cold start: Retry keeps the count; discard −1 once', () {
      final o = Object();
      ThreadReplyCountOffline.attach(o); // the list opened after relaunch
      final parent = _parent(replyCount: 4); // already counts the reply
      final ctx = _Ctx([parent]);
      final r = _reply('l1', muid: 'm1', sentAt: _old);
      ThreadReplyCountOffline.onMessageListHubEvent(
        o,
        ctx,
        _state(r, CometChatMessageSendState.sending),
      );
      expect(parent.replyCount, 4);
      expect(ctx.seeded, isEmpty);

      ThreadReplyCountOffline.onMessageListHubEvent(o, ctx, _discard(r));
      ThreadReplyCountOffline.onMessageListHubEvent(o, ctx, _discard(r));
      expect(parent.replyCount, 3);
      expect(ctx.seeded[_parentId], 3);
    });

    test('session end forgets the counted replies', () {
      final o = Object();
      final r = _reply('l1');
      ThreadReplyCountOffline.ledgerFor(o).claim(r);
      ThreadReplyCountOffline.onMessageListHubEvent(
        o,
        _Ctx(const []),
        SessionEnded(OfflineHub.instance.gen),
      );
      expect(ThreadReplyCountOffline.ledgerFor(o).claim(r), isTrue);
    });
  });

  group('thread header bloc', () {
    late ThreadedHeaderBloc bloc;

    Future<void> settle() => pumpEventQueue();

    Future<void> open({required bool offline, int replyCount = 3}) async {
      CometChat.debugSetOfflineEnabledOverride(offline);
      bloc = ThreadedHeaderBloc()
        ..add(
          InitializeThreadedHeader(
            parentMessage: _parent(replyCount: replyCount),
            loggedInUser: _me,
          ),
        );
      await settle();
    }

    tearDown(() async {
      await bloc.close();
      CometChat.debugSetOfflineEnabledOverride(null);
      OfflineHub.instance.debugReset();
    });

    test('ON: +1 at pending, −1 on discard, no double count at sent', () async {
      await open(offline: true);
      expect(bloc.state.replyCount, 3);

      final r1 = _reply('l1', muid: 'm1');
      OfflineHub.instance.debugOutboxPending(r1);
      await settle();
      expect(bloc.state.replyCount, 4);

      OfflineHub.instance.debugOutboxSent(r1);
      CometChatMessageEvents.ccMessageSent(r1, core_enums.MessageStatus.sent);
      await settle();
      expect(bloc.state.replyCount, 4, reason: 'counted once, at pending');

      final r2 = _reply('l2', muid: 'm2');
      OfflineHub.instance.debugOutboxPending(r2);
      await settle();
      expect(bloc.state.replyCount, 5);
      OfflineHub.instance.debugOutboxFailed(r2, MessageFailureReason.discarded);
      await settle();
      expect(bloc.state.replyCount, 4);
    });

    test('ON: another thread\'s reply does not change the count', () async {
      await open(offline: true);
      OfflineHub.instance.debugOutboxPending(_reply('lx', parent: 99));
      CometChatMessageEvents.ccMessageSent(
        _reply(null, muid: 'mx', parent: 99),
        core_enums.MessageStatus.sent,
      );
      await settle();
      expect(bloc.state.replyCount, 3);
    });

    test('ON: a fresher parent replaces the value and the adds', () async {
      await open(offline: true);
      final r1 = _reply('l1');
      OfflineHub.instance.debugOutboxPending(r1);
      await settle();
      expect(bloc.state.replyCount, 4);

      // onMessagesSynced delivers the parent (it already has the reply).
      OfflineHub.instance.debugMessagesSynced([_parent(replyCount: 7)]);
      await settle();
      expect(bloc.state.replyCount, 7);

      // A late event for the same reply never adds it again.
      OfflineHub.instance.debugOutboxSent(r1);
      CometChatMessageEvents.ccMessageSent(r1, core_enums.MessageStatus.sent);
      await settle();
      expect(bloc.state.replyCount, 7);
    });

    test('ON: reopen, then Retry of a failed reply keeps the count', () async {
      // The reply failed in an earlier open; the parent handed to the header
      // already counts it (BEH-MUT-10).
      await open(offline: true, replyCount: 4);
      final r = _reply('l1', muid: 'm1', sentAt: _old);
      OfflineHub.instance.debugOutboxPending(r); // Retry → sending
      await settle();
      expect(bloc.state.replyCount, 4);
      OfflineHub.instance.debugOutboxSent(r);
      CometChatMessageEvents.ccMessageSent(r, core_enums.MessageStatus.sent);
      await settle();
      expect(bloc.state.replyCount, 4);
    });

    test('ON: discard of a reply the header never saw takes it back', () async {
      await open(offline: true, replyCount: 4);
      final r = _reply('l1', muid: 'm1', sentAt: _old);
      OfflineHub.instance.debugOutboxFailed(r, MessageFailureReason.discarded);
      await settle();
      expect(bloc.state.replyCount, 3);
    });

    test('OFF: today — +1 on every sent, hub events ignored', () async {
      await open(offline: false);
      OfflineHub.instance.debugOutboxPending(_reply('lx'));
      CometChatMessageEvents.ccMessageSent(
        _reply('l1'),
        core_enums.MessageStatus.sent,
      );
      CometChatMessageEvents.ccMessageSent(
        _reply('l1'),
        core_enums.MessageStatus.sent,
      );
      await settle();
      expect(bloc.state.replyCount, 5);
    });
  });
}
