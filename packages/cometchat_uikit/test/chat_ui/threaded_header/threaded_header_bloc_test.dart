/// [ThreadedHeaderBloc] — the header above a thread: who the conversation is
/// with, how many replies it has, and whether the logged-in user follows it.
///
/// `thread_subscription_test.dart` covers the follow toggle in isolation; this
/// file covers initialization (four sender/receiver combinations that decide
/// whether the header is a user or a group header) and the UI-event listeners
/// the bloc registers, driven through the public [CometChatMessageEvents]
/// statics.
///
/// The SDK-side `MessageListener` callbacks are NOT exercised: `CometChat`
/// keeps its listener map private and only fans out from a live realtime
/// socket, so there is no in-process way to deliver one.
///
///   flutter test test/chat_ui/threaded_header/threaded_header_bloc_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/threaded_header/bloc/threaded_header_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/threaded_header/bloc/threaded_header_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/threaded_header/bloc/threaded_header_state.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/data/models/interactive_message/scheduler_message.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/domain/events/message_events/cometchat_message_events.dart';

class FakeUser extends Fake implements User {
  FakeUser([this._uid = 'me']);
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String get name => 'User $_uid';
}

class FakeGroup extends Fake implements Group {
  FakeGroup([this._guid = 'team']);
  final String _guid;
  @override
  String get guid => _guid;
  @override
  String get name => 'Group $_guid';
}

class FakeMessage extends Fake implements BaseMessage {
  FakeMessage({
    this.id = 100,
    User? sender,
    AppEntity? receiver,
    this.replyCount = 0,
    this.parentMessageId = 0,
    bool threadSubscribed = false,
  }) : _sender = sender,
       _receiver = receiver,
       _threadSubscribed = threadSubscribed;

  @override
  final int id;
  @override
  final int replyCount;
  @override
  final int parentMessageId;
  final User? _sender;
  final AppEntity? _receiver;
  bool _threadSubscribed;

  @override
  User? get sender => _sender;
  @override
  AppEntity? get receiver => _receiver;
  @override
  bool get threadSubscribed => _threadSubscribed;
  @override
  set threadSubscribed(bool value) => _threadSubscribed = value;
}

class FakeScheduler extends Fake implements SchedulerMessage {
  FakeScheduler(this.parentMessageId);
  @override
  final int parentMessageId;
}

void main() {
  final me = FakeUser('me');
  final them = FakeUser('them');

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  /// Builds a bloc already initialized on [parentMessage].
  Future<ThreadedHeaderBloc> initialized(BaseMessage parentMessage) async {
    final bloc = ThreadedHeaderBloc();
    bloc.add(
      InitializeThreadedHeader(parentMessage: parentMessage, loggedInUser: me),
    );
    await settle();
    return bloc;
  }

  // =========================================================================
  // InitializeThreadedHeader
  // =========================================================================

  group('InitializeThreadedHeader', () {
    test('goes loading, then loaded', () async {
      final bloc = ThreadedHeaderBloc();
      expect(bloc.state.status, ThreadedHeaderStatus.initial);

      final seen = <ThreadedHeaderStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.status));

      bloc.add(
        InitializeThreadedHeader(
          parentMessage: FakeMessage(sender: me, receiver: them),
          loggedInUser: me,
        ),
      );
      await settle();

      expect(seen, [ThreadedHeaderStatus.loading, ThreadedHeaderStatus.loaded]);
      await sub.cancel();
      await bloc.close();
    });

    test(
      'my own message to a user: the header is about the receiver',
      () async {
        final bloc = await initialized(
          FakeMessage(sender: me, receiver: them, replyCount: 3),
        );

        expect(bloc.state.user?.uid, 'them');
        expect(bloc.state.group, isNull);
        expect(bloc.state.loggedInUser?.uid, 'me');
        expect(bloc.state.replyCount, 3);
        await bloc.close();
      },
    );

    test('my own message to a group: the header is about the group', () async {
      final bloc = await initialized(
        FakeMessage(sender: me, receiver: FakeGroup('team')),
      );

      expect(bloc.state.group?.guid, 'team');
      expect(bloc.state.user, isNull);
      await bloc.close();
    });

    test(
      "somebody else's DM: the header is about the sender, not the receiver",
      () async {
        // The receiver of an incoming DM is me — showing that would name the
        // wrong person, so the header must use the sender.
        final bloc = await initialized(FakeMessage(sender: them, receiver: me));

        expect(bloc.state.user?.uid, 'them');
        expect(bloc.state.group, isNull);
        await bloc.close();
      },
    );

    test("somebody else's group message still resolves to the group", () async {
      final bloc = await initialized(
        FakeMessage(sender: them, receiver: FakeGroup('team')),
      );

      expect(bloc.state.group?.guid, 'team');
      expect(bloc.state.user, isNull);
      await bloc.close();
    });

    test('threadSubscribed is read off the parent message', () async {
      final subscribed = await initialized(
        FakeMessage(sender: me, receiver: them, threadSubscribed: true),
      );
      expect(subscribed.state.threadSubscribed, isTrue);
      await subscribed.close();

      final unsubscribed = await initialized(
        FakeMessage(sender: me, receiver: them),
      );
      expect(unsubscribed.state.threadSubscribed, isFalse);
      await unsubscribed.close();
    });
  });

  // =========================================================================
  // Plain event handlers
  // =========================================================================

  group('reply count and parent message', () {
    test('IncrementReplyCount adds one each time', () async {
      final bloc = await initialized(
        FakeMessage(sender: me, receiver: them, replyCount: 5),
      );

      bloc.add(const IncrementReplyCount());
      await settle();
      expect(bloc.state.replyCount, 6);

      bloc.add(const IncrementReplyCount());
      await settle();
      expect(bloc.state.replyCount, 7);
      await bloc.close();
    });

    test('UpdateParentMessage swaps the message and keeps the rest', () async {
      final bloc = await initialized(
        FakeMessage(sender: me, receiver: them, replyCount: 5),
      );

      final edited = FakeMessage(id: 100, sender: me, receiver: them);
      bloc.add(UpdateParentMessage(edited));
      await settle();

      expect(bloc.state.parentMessage, same(edited));
      expect(bloc.state.replyCount, 5, reason: 'the count is untouched');
      expect(bloc.state.user?.uid, 'them');
      await bloc.close();
    });

    test(
      'UpdateThreadSubscription stamps the message, not just the state',
      () async {
        final parent = FakeMessage(sender: me, receiver: them);
        final bloc = await initialized(parent);
        expect(bloc.state.threadSubscribed, isFalse);

        bloc.add(const UpdateThreadSubscription(true));
        await settle();
        expect(bloc.state.threadSubscribed, isTrue);
        expect(
          parent.threadSubscribed,
          isTrue,
          reason: 'the message is the source the next reader consults',
        );

        bloc.add(const UpdateThreadSubscription(false));
        await settle();
        expect(bloc.state.threadSubscribed, isFalse);
        expect(parent.threadSubscribed, isFalse);
        await bloc.close();
      },
    );
  });

  // =========================================================================
  // UI event listeners
  // =========================================================================

  group('UI event listeners', () {
    test('no listener is registered until initialization', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final bloc = ThreadedHeaderBloc();
      expect(CometChatMessageEvents.messagesListener.length, before);

      bloc.add(
        InitializeThreadedHeader(
          parentMessage: FakeMessage(sender: me, receiver: them),
          loggedInUser: me,
        ),
      );
      await settle();
      expect(CometChatMessageEvents.messagesListener.length, before + 1);

      await bloc.close();
      expect(
        CometChatMessageEvents.messagesListener.length,
        before,
        reason: 'close() must deregister, or the bloc leaks',
      );
    });

    test('ccMessageSent counts only a successful send', () async {
      final bloc = await initialized(
        FakeMessage(sender: me, receiver: them, replyCount: 1),
      );
      final reply = FakeMessage(id: 200, parentMessageId: 100);

      CometChatMessageEvents.ccMessageSent(reply, MessageStatus.inProgress);
      await settle();
      expect(bloc.state.replyCount, 1, reason: 'in-flight is not a reply yet');

      CometChatMessageEvents.ccMessageSent(reply, MessageStatus.error);
      await settle();
      expect(bloc.state.replyCount, 1);

      CometChatMessageEvents.ccMessageSent(reply, MessageStatus.sent);
      await settle();
      expect(bloc.state.replyCount, 2);
      await bloc.close();
    });

    test(
      'ccMessageEdited only takes a successful edit of the parent',
      () async {
        final bloc = await initialized(FakeMessage(sender: me, receiver: them));
        final original = bloc.state.parentMessage;

        final other = FakeMessage(id: 999);
        CometChatMessageEvents.ccMessageEdited(
          other,
          MessageEditStatus.success,
        );
        await settle();
        expect(bloc.state.parentMessage, same(original), reason: 'wrong id');

        final parentEdit = FakeMessage(id: 100);
        CometChatMessageEvents.ccMessageEdited(
          parentEdit,
          MessageEditStatus.inProgress,
        );
        await settle();
        expect(
          bloc.state.parentMessage,
          same(original),
          reason: 'an in-flight edit must not be shown yet',
        );

        CometChatMessageEvents.ccMessageEdited(
          parentEdit,
          MessageEditStatus.success,
        );
        await settle();
        expect(bloc.state.parentMessage, same(parentEdit));
        await bloc.close();
      },
    );

    test('ccMessageDeleted takes any delete of the parent by id', () async {
      final bloc = await initialized(FakeMessage(sender: me, receiver: them));
      final original = bloc.state.parentMessage;

      CometChatMessageEvents.ccMessageDeleted(
        FakeMessage(id: 999),
        EventStatus.success,
      );
      await settle();
      expect(bloc.state.parentMessage, same(original), reason: 'wrong id');

      // Unlike edit, delete is accepted while still in progress — the row must
      // show as deleted immediately.
      final deleted = FakeMessage(id: 100);
      CometChatMessageEvents.ccMessageDeleted(deleted, EventStatus.inProgress);
      await settle();
      expect(bloc.state.parentMessage, same(deleted));
      await bloc.close();
    });

    test(
      'onSchedulerMessageReceived counts only replies to this thread',
      () async {
        final bloc = await initialized(
          FakeMessage(sender: me, receiver: them, replyCount: 4),
        );

        CometChatMessageEvents.onSchedulerMessageReceived(FakeScheduler(999));
        await settle();
        expect(bloc.state.replyCount, 4);

        CometChatMessageEvents.onSchedulerMessageReceived(FakeScheduler(100));
        await settle();
        expect(bloc.state.replyCount, 5);
        await bloc.close();
      },
    );

    test('ccThreadSubscriptionChanged only follows this thread', () async {
      final bloc = await initialized(FakeMessage(sender: me, receiver: them));

      CometChatMessageEvents.ccThreadSubscriptionChanged(999, true);
      await settle();
      expect(bloc.state.threadSubscribed, isFalse);

      CometChatMessageEvents.ccThreadSubscriptionChanged(100, true);
      await settle();
      expect(bloc.state.threadSubscribed, isTrue);
      await bloc.close();
    });

    test('a closed bloc ignores every UI event', () async {
      final bloc = await initialized(
        FakeMessage(sender: me, receiver: them, replyCount: 1),
      );
      await bloc.close();

      expect(() {
        CometChatMessageEvents.ccMessageSent(
          FakeMessage(id: 200, parentMessageId: 100),
          MessageStatus.sent,
        );
        CometChatMessageEvents.ccThreadSubscriptionChanged(100, true);
        CometChatMessageEvents.onSchedulerMessageReceived(FakeScheduler(100));
      }, returnsNormally);
      expect(bloc.state.replyCount, 1);
    });

    test('two initialized blocs get distinct listener keys', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final a = await initialized(
        FakeMessage(id: 1, sender: me, receiver: them),
      );
      final b = await initialized(
        FakeMessage(id: 2, sender: me, receiver: them),
      );
      expect(CometChatMessageEvents.messagesListener.length, before + 2);

      await a.close();
      await b.close();
      expect(CometChatMessageEvents.messagesListener.length, before);
    });
  });
}
