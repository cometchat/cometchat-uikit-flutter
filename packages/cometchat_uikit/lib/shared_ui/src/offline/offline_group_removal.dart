import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'offline_hub.dart';
import 'offline_hub_event.dart';

/// A self kick, ban or leave found by the reconnect sweep (W5, G7, B2).
///
/// The sweep delivers group actions only in `onMessageSyncCompleted`
/// (BEH-SYNC-25/31), never on the group listener, so a component that reacts
/// to the live `onGroupMemberKicked` / `onGroupMemberBanned` /
/// `onGroupMemberLeft` for the logged-in user routes this into the same
/// handler. The arguments match what the SDK passes to those callbacks.
class SweptSelfRemoval {
  /// Creates a removal.
  const SweptSelfRemoval({
    required this.kind,
    required this.action,
    required this.removedUser,
    required this.by,
    required this.group,
  });

  /// `kicked`, `banned` or `left` (the SDK's action value).
  final String kind;

  /// The action message.
  final Action action;

  /// The logged-in user (the action's `actionOn`).
  final User removedUser;

  /// Who acted (`actionBy`); an empty user when the action does not say, as
  /// the SDK's live dispatch does.
  final User by;

  /// The group (`actionFor`).
  final Group group;

  /// Kick.
  static const String kicked = 'kicked';

  /// Ban.
  static const String banned = 'banned';

  /// Leave.
  static const String left = 'left';

  /// [message] as a removal of [myUid] from a group, else null. Mirrors the
  /// SDK's live group-action dispatch: an `action` message whose `action` is
  /// kicked/banned/left, `actionOn` a user with [myUid] and `actionFor` a
  /// group. An action that names no uid is never read as a self-removal.
  static SweptSelfRemoval? of(BaseMessage message, String? myUid) {
    if (message is! Action || myUid == null || myUid.isEmpty) return null;
    final kind = message.action;
    if (kind != kicked && kind != banned && kind != left) return null;
    final on = message.actionOn;
    final group = message.actionFor;
    if (on is! User || on.uid != myUid || group is! Group) return null;
    final by = message.actionBy;
    return SweptSelfRemoval(
      kind: kind!,
      action: message,
      removedUser: on,
      by: by is User ? by : User(uid: '', name: ''),
      group: group,
    );
  }

  /// Calls [onRemoval] for every self-removal in each current-session hub
  /// `MessageSyncCompleted`. The hub publishes only while offline is on, so
  /// with offline off this never fires. The caller cancels the subscription.
  static StreamSubscription<OfflineHubEvent> listen(
    String? Function() myUid,
    void Function(SweptSelfRemoval removal) onRemoval,
  ) {
    return OfflineHub.instance.events.listen((event) {
      if (event is! MessageSyncCompleted) return;
      if (event.gen < OfflineHub.instance.gen) return;
      final uid = myUid();
      for (final m in event.messages) {
        final removal = of(m, uid);
        if (removal != null) onRemoval(removal);
      }
    });
  }
}
