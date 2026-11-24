import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_send_state.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub_event.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  final hub = OfflineHub.instance;

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
  });
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  Future<List<OfflineHubEvent>> collect(void Function() act) async {
    final events = <OfflineHubEvent>[];
    final sub = hub.events.listen(events.add);
    act();
    await pumpEventQueue();
    await sub.cancel();
    return events;
  }

  test('start registers the SDK listeners once (idempotent)', () {
    hub.start();
    hub.start();
    expect(hub.debugStartRegistrations, 1);
  });

  test('each SDK callback maps to its hub event', () async {
    final m = msg(localMessageId: 'l1', senderUid: 'me');
    final events = await collect(() {
      hub.debugOutboxPending(m);
      hub.debugMessagesSynced([m]);
      hub.debugMessageSyncCompleted([m], SyncOutcome.partial);
      hub.debugCacheReset(OfflineCacheResetReason.corrupted, 2);
      hub.debugMediaDownloaded('l1', 'att-9', '/tmp/x');
    });
    expect(
      events.whereType<SendStateEvent>().single.state,
      CometChatMessageSendState.sending,
    );
    expect(events.whereType<MessagesUpdated>(), hasLength(1));
    expect(
      events.whereType<MessageSyncCompleted>().single.outcome,
      SyncOutcome.partial,
    );
    expect(events.whereType<CacheReset>().single.pendingMessagesLost, 2);
    final media = events.whereType<MediaReady>().single;
    expect(media.attachmentId, 'att-9');
    expect(media.localMessageId, 'l1');
    expect(media.localPath, '/tmp/x');
  });

  test('one SendStateEvent per transition per localMessageId', () async {
    final m = msg(localMessageId: 'l1', senderUid: 'me');
    final events = await collect(() {
      hub.debugOutboxPending(m); // sending
      hub.debugOutboxPending(m); // duplicate -> dropped
      hub.debugOutboxSent(m); // sent
      hub.debugOutboxSent(m); // after sent -> dropped (terminal)
    });
    expect(events.whereType<SendStateEvent>().map((e) => e.state), [
      CometChatMessageSendState.sending,
      CometChatMessageSendState.sent,
    ]);
  });

  test('OFF sends (no localMessageId) bypass the dedupe', () async {
    final m = msg(senderUid: 'me');
    final events = await collect(() {
      hub.debugOutboxPending(m);
      hub.debugOutboxPending(m);
    });
    expect(events.whereType<SendStateEvent>(), hasLength(2));
  });

  test(
    'outbox, sync, cache-reset and media handlers are inert while off',
    () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final events = await collect(() {
        hub.debugOutboxPending(msg(localMessageId: 'l1', senderUid: 'me'));
        hub.debugCacheReset(OfflineCacheResetReason.corrupted, 2);
        hub.debugMediaDownloaded(null, 'a', '/p');
      });
      expect(events, isEmpty);
    },
  );

  test('300-event burst is lossless and ordered', () async {
    final events = await collect(() {
      for (var i = 0; i < 300; i++) {
        hub.debugOutboxPending(msg(localMessageId: 'l$i', senderUid: 'me'));
      }
    });
    final sent = events.whereType<SendStateEvent>().toList();
    expect(sent, hasLength(300));
    expect(sent.first.localMessageId, 'l0');
    expect(sent.last.localMessageId, 'l299');
  });

  test(
    'logout ends the session although the SDK reports offline off by then',
    () async {
      final events = await collect(() {
        hub.debugLoginSuccess('alice'); // offline on during the session
        // The SDK answers isOfflineEnabled() == false once logged out.
        CometChat.debugSetOfflineEnabledOverride(false);
        hub.onKitLogout(); // the kit's logout
        hub.debugLogout(); // then the SDK's logoutSuccess: idempotent
      });
      expect(events.whereType<SessionEnded>(), hasLength(1));
      expect(hub.gen, 1);
    },
  );

  test('relaunch with a restored session: logout still ends it', () async {
    final events = await collect(() {
      hub.seedSession('alice'); // restored session, no loginSuccess
      CometChat.debugSetOfflineEnabledOverride(false);
      hub.debugLogout();
    });
    expect(events.whereType<SessionEnded>(), hasLength(1));
  });

  test(
    'a session that never had offline on ends without a SessionEnded',
    () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final events = await collect(() {
        hub.debugLoginSuccess('alice');
        hub.debugLogout();
      });
      expect(events, isEmpty);
      expect(hub.gen, 0);
    },
  );

  test(
    'same-uid login keeps the session; different-uid login ends it',
    () async {
      final events = await collect(() {
        hub.debugLoginSuccess('alice');
        hub.debugLoginSuccess('alice'); // token refresh
      });
      expect(events.whereType<SessionEnded>(), isEmpty);
      expect(hub.gen, 0);

      final switched = await collect(() => hub.debugLoginSuccess('bob'));
      expect(switched.whereType<SessionEnded>(), hasLength(1));
      expect(hub.gen, 1);
    },
  );

  test('a hub notice waits for a showing list, then is shown once', () {
    final shownA = <OfflineNotice>[];
    final shownB = <OfflineNotice>[];
    void sinkA(OfflineNotice n) => shownA.add(n);
    void sinkB(OfflineNotice n) => shownB.add(n);

    hub.postNotice(const QueueFull()); // no list attached: queued
    expect(shownA, isEmpty);

    hub.attachNoticeSink(sinkA); // delivered on attach
    expect(shownA, hasLength(1));

    hub.attachNoticeSink(sinkB);
    hub.postNotice(const UnsentMaybeLost()); // shown by one list only
    expect(shownA.length + shownB.length, 2);

    hub.detachNoticeSink(sinkA);
    hub.detachNoticeSink(sinkB);
  });
}
