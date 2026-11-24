import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;

/// Handles a group action the way the live group listener would.
typedef GroupRemovalHandler =
    void Function(
      cc.Action action,
      cc.User removedUser,
      cc.User by,
      cc.Group group,
    );

/// Routes a self kick, ban or leave that the reconnect catch-up delivered into
/// the handlers the live group events drive.
///
/// With offline on, actions missed while away arrive only in
/// `onMessageSyncCompleted`, never on the group listener, so a screen that
/// reacts to its own removal registers this next to its `GroupListener`. It
/// never fires with offline off.
class SweptGroupRemovalListener extends cc.SyncListener {
  SweptGroupRemovalListener({
    required this.loggedInUid,
    required this.onKicked,
    required this.onBanned,
    required this.onLeft,
  });

  /// The logged-in user's uid, read when a catch-up completes.
  final String? Function() loggedInUid;

  /// The logged-in user was kicked.
  final GroupRemovalHandler onKicked;

  /// The logged-in user was banned.
  final GroupRemovalHandler onBanned;

  /// The logged-in user left (from another device).
  final GroupRemovalHandler onLeft;

  @override
  void onMessageSyncCompleted(
    List<cc.BaseMessage> messages,
    cc.SyncOutcome outcome,
  ) {
    final uid = loggedInUid();
    if (uid == null || uid.isEmpty) return;
    for (final m in messages) {
      if (m is! cc.Action) continue;
      final on = m.actionOn;
      final group = m.actionFor;
      if (on is! cc.User || on.uid != uid || group is! cc.Group) continue;
      final actor = m.actionBy;
      final by = actor is cc.User ? actor : cc.User(uid: '', name: '');
      switch (m.action) {
        case 'kicked':
          onKicked(m, on, by, group);
        case 'banned':
          onBanned(m, on, by, group);
        case 'left':
          onLeft(m, on, by, group);
      }
    }
  }
}
