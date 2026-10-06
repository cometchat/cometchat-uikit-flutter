/// Behaviour tests for [CometChatUIKitHelper] — the public façade an
/// integrator uses to raise UI Kit events from their own code.
///
/// Every method is a one-line forward onto one of the five event buses, so the
/// contract worth pinning is exactly that: which bus each helper lands on,
/// which event on that bus, and that the arguments arrive in the right order
/// and unchanged. A silent transposition of two `User` arguments (banned /
/// bannedBy, kicked / kickedBy) would be invisible without this.
///
/// It also pins the one place where the façade is NOT lossless:
/// `onLiveReaction` takes a `receiverId` that the bus drops on the floor.
///
///   flutter test test/shared_ui/events/ui_kit_helper_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc show Action;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _team = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);
final _sentAt = DateTime.utc(2024, 1, 1, 12);

TextMessage _text([String body = 'hello']) => TextMessage(
  id: 1,
  text: body,
  sender: _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

cc.Action _action() => cc.Action(
  id: 5,
  receiverUid: 'g1',
  type: MessageTypeConstants.groupActions,
  receiverType: ReceiverTypeConstants.group,
  sender: _alice,
  conversationId: 'group_g1',
  action: 'added',
);

GroupMember _member() =>
    GroupMember(uid: 'u2', name: 'Bob', scope: GroupMemberScope.admin);

Conversation _conversation() => Conversation(
  conversationId: 'u1_user_u2',
  conversationType: ReceiverTypeConstants.user,
  conversationWith: _bob,
);

// ─── Recorders ───────────────────────────────────────────────────────────────

class _Call {
  _Call(this.name, this.args);

  final String name;
  final List<Object?> args;

  @override
  String toString() => '$name$args';
}

mixin _Records {
  final List<_Call> calls = [];

  _Call get only {
    expect(calls, hasLength(1));
    return calls.single;
  }
}

class _MsgRec with CometChatMessageEventListener, _Records {
  @override
  void ccMessageSent(BaseMessage message, MessageSendStatus messageStatus) =>
      calls.add(_Call('ccMessageSent', [message, messageStatus]));

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) =>
      calls.add(_Call('ccMessageEdited', [message, status]));

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) =>
      calls.add(_Call('ccMessageDeleted', [message, messageStatus]));

  @override
  void ccMessageRead(BaseMessage message) =>
      calls.add(_Call('ccMessageRead', [message]));

  @override
  void ccLiveReaction(String reaction) =>
      calls.add(_Call('ccLiveReaction', [reaction]));

  @override
  void onMessageModerated(BaseMessage message) =>
      calls.add(_Call('onMessageModerated', [message]));
}

class _UserRec with CometChatUserEventListener, _Records {
  @override
  void ccUserBlocked(User user) => calls.add(_Call('ccUserBlocked', [user]));

  @override
  void ccUserUnblocked(User user) =>
      calls.add(_Call('ccUserUnblocked', [user]));
}

class _GroupRec with CometChatGroupEventListener, _Records {
  @override
  void ccGroupCreated(Group group) =>
      calls.add(_Call('ccGroupCreated', [group]));

  @override
  void ccGroupDeleted(Group group) =>
      calls.add(_Call('ccGroupDeleted', [group]));

  @override
  void ccGroupLeft(cc.Action message, User leftUser, Group leftGroup) =>
      calls.add(_Call('ccGroupLeft', [message, leftUser, leftGroup]));

  @override
  void ccGroupMemberScopeChanged(
    cc.Action message,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) => calls.add(
    _Call('ccGroupMemberScopeChanged', [
      message,
      updatedUser,
      scopeChangedTo,
      scopeChangedFrom,
      group,
    ]),
  );

  @override
  void ccGroupMemberBanned(
    cc.Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) => calls.add(
    _Call('ccGroupMemberBanned', [message, bannedUser, bannedBy, bannedFrom]),
  );

  @override
  void ccGroupMemberKicked(
    cc.Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) => calls.add(
    _Call('ccGroupMemberKicked', [message, kickedUser, kickedBy, kickedFrom]),
  );

  @override
  void ccGroupMemberUnbanned(
    cc.Action message,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) => calls.add(
    _Call('ccGroupMemberUnbanned', [
      message,
      unbannedUser,
      unbannedBy,
      unbannedFrom,
    ]),
  );

  @override
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) =>
      calls.add(_Call('ccGroupMemberJoined', [joinedUser, joinedGroup]));

  @override
  void ccGroupMemberAdded(
    List<cc.Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) => calls.add(
    _Call('ccGroupMemberAdded', [messages, usersAdded, groupAddedIn, addedBy]),
  );

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) =>
      calls.add(_Call('ccOwnershipChanged', [group, newOwner]));
}

class _ConvRec with CometChatConversationEventListener, _Records {
  @override
  void ccConversationDeleted(Conversation conversation) =>
      calls.add(_Call('ccConversationDeleted', [conversation]));

  @override
  void ccUpdateConversation(Conversation conversation) =>
      calls.add(_Call('ccUpdateConversation', [conversation]));
}

class _UiRec with CometChatUIEventListener, _Records {
  @override
  void showPanel(
    Map<String, dynamic>? id,
    CustomUIPosition uiPosition,
    WidgetBuilder child,
  ) => calls.add(_Call('showPanel', [id, uiPosition, child]));

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) =>
      calls.add(_Call('hidePanel', [id, uiPosition]));

  @override
  void ccActiveChatChanged(
    Map<String, dynamic>? id,
    BaseMessage? lastMessage,
    User? user,
    Group? group,
    int unreadMessageCount,
  ) => calls.add(
    _Call('ccActiveChatChanged', [
      id,
      lastMessage,
      user,
      group,
      unreadMessageCount,
    ]),
  );

  @override
  void openChat(User? user, Group? group) =>
      calls.add(_Call('openChat', [user, group]));

  @override
  void ccComposeMessage(String text, MessageEditStatus status) =>
      calls.add(_Call('ccComposeMessage', [text, status]));
}

void main() {
  late _MsgRec msg;
  late _UserRec usr;
  late _GroupRec grp;
  late _ConvRec conv;
  late _UiRec ui;

  setUp(() {
    CometChatMessageEvents.messagesListener.clear();
    CometChatUserEvents.usersListener.clear();
    CometChatGroupEvents.groupsListener.clear();
    CometChatConversationEvents.conversationListListener.clear();
    CometChatUIEvents.uiListener.clear();

    msg = _MsgRec();
    usr = _UserRec();
    grp = _GroupRec();
    conv = _ConvRec();
    ui = _UiRec();

    CometChatMessageEvents.addMessagesListener('rec', msg);
    CometChatUserEvents.addUsersListener('rec', usr);
    CometChatGroupEvents.addGroupsListener('rec', grp);
    CometChatConversationEvents.addConversationListListener('rec', conv);
    CometChatUIEvents.addUiListener('rec', ui);
  });

  tearDown(() {
    CometChatMessageEvents.messagesListener.clear();
    CometChatUserEvents.usersListener.clear();
    CometChatGroupEvents.groupsListener.clear();
    CometChatConversationEvents.conversationListListener.clear();
    CometChatUIEvents.uiListener.clear();
  });

  /// Nothing the helper does may leak onto a bus it does not name.
  void expectOnlyBus(List<_Records> busesExpectedEmpty) {
    for (final b in busesExpectedEmpty) {
      expect(b.calls, isEmpty);
    }
  }

  // =========================================================================
  group('message events', () {
    test('onMessageSent reaches the message bus with the status', () {
      final m = _text();
      CometChatUIKitHelper.onMessageSent(m, MessageSendStatus.inProgress);

      expect(msg.only.name, 'ccMessageSent');
      expect(msg.only.args, [same(m), MessageSendStatus.inProgress]);
      expectOnlyBus([usr, grp, conv, ui]);
    });

    test('onMessageSent forwards each status value distinctly', () {
      final m = _text();
      CometChatUIKitHelper.onMessageSent(m, MessageSendStatus.sent);
      CometChatUIKitHelper.onMessageSent(m, MessageSendStatus.error);

      expect(msg.calls.map((c) => c.args[1]), [
        MessageSendStatus.sent,
        MessageSendStatus.error,
      ]);
    });

    test('onMessageEdited carries the edit status', () {
      final m = _text();
      CometChatUIKitHelper.onMessageEdited(m, MessageEditStatus.inProgress);

      expect(msg.only.name, 'ccMessageEdited');
      expect(msg.only.args, [same(m), MessageEditStatus.inProgress]);
    });

    test('onMessageDeleted carries the event status', () {
      final m = _text();
      CometChatUIKitHelper.onMessageDeleted(m, EventStatus.success);

      expect(msg.only.name, 'ccMessageDeleted');
      expect(msg.only.args, [same(m), EventStatus.success]);
    });

    test('onMessageRead carries the message', () {
      final m = _text();
      CometChatUIKitHelper.onMessageRead(m);

      expect(msg.only.name, 'ccMessageRead');
      expect(msg.only.args, [same(m)]);
    });

    test('onMessageModerated carries the message', () {
      final m = _text();
      CometChatUIKitHelper.onMessageModerated(m);

      expect(msg.only.name, 'onMessageModerated');
      expect(msg.only.args, [same(m)]);
    });

    test('onLiveReaction forwards the reaction but drops the receiverId', () {
      // FINDING (lossy, not a crash): the helper's `receiverId` argument has
      // no path to any listener — `CometChatMessageEvents.ccLiveReaction`
      // accepts it and then calls `listener.ccLiveReaction(reaction)` only.
      // An integrator cannot tell which conversation a live reaction was for.
      CometChatUIKitHelper.onLiveReaction('❤️', 'u2');

      expect(msg.only.name, 'ccLiveReaction');
      expect(msg.only.args, ['❤️']);
    });
  });

  // =========================================================================
  group('user events', () {
    test('onUserBlocked and onUserUnblocked stay distinct', () {
      CometChatUIKitHelper.onUserBlocked(_bob);
      CometChatUIKitHelper.onUserUnblocked(_bob);

      expect(usr.calls.map((c) => c.name), [
        'ccUserBlocked',
        'ccUserUnblocked',
      ]);
      expect(usr.calls.first.args, [same(_bob)]);
      expect(usr.calls.last.args, [same(_bob)]);
      expectOnlyBus([msg, grp, conv, ui]);
    });
  });

  // =========================================================================
  group('group events', () {
    test('onGroupCreated and onGroupDeleted stay distinct', () {
      CometChatUIKitHelper.onGroupCreated(_team);
      CometChatUIKitHelper.onGroupDeleted(_team);

      expect(grp.calls.map((c) => c.name), [
        'ccGroupCreated',
        'ccGroupDeleted',
      ]);
      expect(grp.calls.first.args, [same(_team)]);
      expectOnlyBus([msg, usr, conv, ui]);
    });

    test('onGroupLeft carries action, user and group in order', () {
      final a = _action();
      CometChatUIKitHelper.onGroupLeft(a, _bob, _team);

      expect(grp.only.name, 'ccGroupLeft');
      expect(grp.only.args, [same(a), same(_bob), same(_team)]);
    });

    test('onGroupMemberScopeChanged keeps to/from the right way round', () {
      final a = _action();
      CometChatUIKitHelper.onGroupMemberScopeChanged(
        a,
        _bob,
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        _team,
      );

      expect(grp.only.name, 'ccGroupMemberScopeChanged');
      expect(grp.only.args, [
        same(a),
        same(_bob),
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        same(_team),
      ]);
    });

    test('onGroupMemberBanned keeps bannedUser before bannedBy', () {
      final a = _action();
      CometChatUIKitHelper.onGroupMemberBanned(a, _bob, _alice, _team);

      expect(grp.only.name, 'ccGroupMemberBanned');
      expect(grp.only.args, [same(a), same(_bob), same(_alice), same(_team)]);
    });

    test('onGroupMemberKicked keeps kickedUser before kickedBy', () {
      final a = _action();
      CometChatUIKitHelper.onGroupMemberKicked(a, _bob, _alice, _team);

      expect(grp.only.name, 'ccGroupMemberKicked');
      expect(grp.only.args, [same(a), same(_bob), same(_alice), same(_team)]);
    });

    test('onGroupMemberUnbanned keeps unbannedUser before unbannedBy', () {
      final a = _action();
      CometChatUIKitHelper.onGroupMemberUnbanned(a, _bob, _alice, _team);

      expect(grp.only.name, 'ccGroupMemberUnbanned');
      expect(grp.only.args, [same(a), same(_bob), same(_alice), same(_team)]);
    });

    test('onGroupMemberJoined carries the user and the group', () {
      CometChatUIKitHelper.onGroupMemberJoined(_bob, _team);

      expect(grp.only.name, 'ccGroupMemberJoined');
      expect(grp.only.args, [same(_bob), same(_team)]);
    });

    test('onGroupMemberAdded carries both lists by identity', () {
      final actions = [_action()];
      final users = [_bob];
      CometChatUIKitHelper.onGroupMemberAdded(actions, users, _team, _alice);

      expect(grp.only.name, 'ccGroupMemberAdded');
      expect(grp.only.args, [
        same(actions),
        same(users),
        same(_team),
        same(_alice),
      ]);
    });

    test('onOwnershipChanged carries the group and the new owner', () {
      final owner = _member();
      CometChatUIKitHelper.onOwnershipChanged(_team, owner);

      expect(grp.only.name, 'ccOwnershipChanged');
      expect(grp.only.args, [same(_team), same(owner)]);
    });
  });

  // =========================================================================
  group('conversation events', () {
    test('onConversationDeleted and onConversationUpdate stay distinct', () {
      final c = _conversation();
      CometChatUIKitHelper.onConversationDeleted(c);
      CometChatUIKitHelper.onConversationUpdate(c);

      expect(conv.calls.map((e) => e.name), [
        'ccConversationDeleted',
        'ccUpdateConversation',
      ]);
      expect(conv.calls.first.args, [same(c)]);
      expect(conv.calls.last.args, [same(c)]);
      expectOnlyBus([msg, usr, grp, ui]);
    });
  });

  // =========================================================================
  group('UI events', () {
    test('showPanel forwards the builder itself, not a wrapper', () {
      Widget builder(BuildContext _) => const SizedBox.shrink();
      CometChatUIKitHelper.showPanel(
        {'uid': 'u2'},
        CustomUIPosition.messageListBottom,
        builder,
      );

      expect(ui.only.name, 'showPanel');
      expect(ui.only.args, [
        {'uid': 'u2'},
        CustomUIPosition.messageListBottom,
        same(builder),
      ]);
      expectOnlyBus([msg, usr, grp, conv]);
    });

    test(
      'hidePanel accepts a null id (a broadcast) and keeps the position',
      () {
        CometChatUIKitHelper.hidePanel(null, CustomUIPosition.messageListTop);

        expect(ui.only.name, 'hidePanel');
        expect(ui.only.args, [null, CustomUIPosition.messageListTop]);
      },
    );

    test('ccActiveChatChanged carries all five arguments in order', () {
      final m = _text();
      CometChatUIKitHelper.ccActiveChatChanged(
        {'uid': 'u2'},
        m,
        _bob,
        _team,
        7,
      );

      expect(ui.only.name, 'ccActiveChatChanged');
      expect(ui.only.args, [
        {'uid': 'u2'},
        same(m),
        same(_bob),
        same(_team),
        7,
      ]);
    });

    test('onOpenChat passes whichever of user / group was supplied', () {
      CometChatUIKitHelper.onOpenChat(null, _team);

      expect(ui.only.name, 'openChat');
      expect(ui.only.args, [null, same(_team)]);
    });

    test('ccComposeMessage carries the draft text and the edit status', () {
      CometChatUIKitHelper.ccComposeMessage(
        'draft',
        MessageEditStatus.inProgress,
      );

      expect(ui.only.name, 'ccComposeMessage');
      expect(ui.only.args, ['draft', MessageEditStatus.inProgress]);
    });
  });

  // =========================================================================
  group('fan-out', () {
    test('every registered listener on a bus is reached, not just one', () {
      final second = _GroupRec();
      CometChatGroupEvents.addGroupsListener('second', second);

      CometChatUIKitHelper.onGroupCreated(_team);

      expect(grp.only.name, 'ccGroupCreated');
      expect(second.only.name, 'ccGroupCreated');
    });

    test('with no listener registered the helper is still harmless', () {
      CometChatGroupEvents.groupsListener.clear();
      CometChatConversationEvents.conversationListListener.clear();

      expect(() => CometChatUIKitHelper.onGroupCreated(_team), returnsNormally);
      expect(
        () => CometChatUIKitHelper.onConversationDeleted(_conversation()),
        returnsNormally,
      );
    });
  });
}
