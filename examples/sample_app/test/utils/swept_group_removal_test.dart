import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/utils/swept_group_removal.dart';

final _me = cc.User(uid: 'me', name: 'Me');
final _admin = cc.User(uid: 'admin', name: 'Admin');
final _bob = cc.User(uid: 'bob', name: 'Bob');
final _group = cc.Group(guid: 'g1', name: 'G', type: 'public');

cc.Action _action(String kind, {cc.User? on}) => cc.Action(
  id: 1,
  muid: 'm1',
  action: kind,
  sender: _admin,
  receiverUid: 'g1',
  type: 'groupMember',
  receiverType: 'group',
  category: 'action',
  actionBy: _admin,
  actionOn: on ?? _me,
  actionFor: _group,
);

/// The messages screen hands its live GroupListener handlers to this
/// listener (`onGroupMemberKicked` / `onGroupMemberBanned`, which disable the
/// composer for the logged-in user) and its own self-leave handler.
void main() {
  late List<String> calls;
  late SweptGroupRemovalListener listener;

  setUp(() {
    calls = [];
    listener = SweptGroupRemovalListener(
      loggedInUid: () => _me.uid,
      onKicked: (a, u, by, g) =>
          calls.add('kicked:${u.uid}:${by.uid}:${g.guid}'),
      onBanned: (a, u, by, g) =>
          calls.add('banned:${u.uid}:${by.uid}:${g.guid}'),
      onLeft: (a, u, by, g) => calls.add('left:${u.uid}:${g.guid}'),
    );
  });

  test('a swept self kick, ban and leave reach the live handlers', () {
    listener.onMessageSyncCompleted([
      _action('kicked'),
      _action('banned'),
      _action('left'),
    ], cc.SyncOutcome.caughtUp);
    expect(calls, ['kicked:me:admin:g1', 'banned:me:admin:g1', 'left:me:g1']);
  });

  test('another member\'s removal and other actions are ignored', () {
    listener.onMessageSyncCompleted([
      _action('kicked', on: _bob),
      _action('joined'),
      _action('scopeChanged'),
    ], cc.SyncOutcome.partial);
    expect(calls, isEmpty);
  });
}
