// W5 (ENG-41095), G7/B2: a self kick, ban or leave found by the reconnect
// sweep (delivered only in onMessageSyncCompleted) runs the message header's
// live group-listener handlers; with offline off nothing changes.

import 'package:cometchat_chat_uikit/chat_ui/src/message_header/bloc/message_header_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_header/bloc/message_header_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_header/domain/repositories/message_header_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_header/domain/usecases/get_group_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_header/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_header/domain/usecases/get_user_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_group_removal.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageHeaderRepository {}

final _me = User(uid: 'me-w5g', name: 'Me');
final _admin = User(uid: 'admin-w5g', name: 'Admin');
final _bob = User(uid: 'bob-w5g', name: 'Bob');

Group _group({int members = 5}) =>
    Group(guid: 'g-w5g', name: 'G', type: 'public', membersCount: members);

Action _removal(String kind, {User? on, Group? group, int id = 1}) => Action(
  id: id,
  muid: 'muid-w5g-$id',
  action: kind,
  sender: _admin,
  receiverUid: 'g-w5g',
  type: 'groupMember',
  receiverType: 'group',
  category: 'action',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id),
  actionBy: _admin,
  actionOn: on ?? _me,
  actionFor: group ?? _group(members: 4),
);

Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hub = OfflineHub.instance;

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess(_me.uid);
    CometChatUIKit.loggedInUser = _me;
  });

  tearDown(() {
    CometChat.debugSetOfflineEnabledOverride(null);
    CometChatUIKit.loggedInUser = null;
  });

  group('SweptSelfRemoval.of', () {
    test('reads a kick, ban or leave of the logged-in user', () {
      for (final kind in ['kicked', 'banned', 'left']) {
        final r = SweptSelfRemoval.of(_removal(kind), _me.uid)!;
        expect(r.kind, kind);
        expect(r.removedUser.uid, _me.uid);
        expect(r.by.uid, _admin.uid);
        expect(r.group.guid, 'g-w5g');
      }
    });

    test('ignores another member, other actions and a missing uid', () {
      expect(
        SweptSelfRemoval.of(_removal('kicked', on: _bob), _me.uid),
        isNull,
      );
      expect(SweptSelfRemoval.of(_removal('joined'), _me.uid), isNull);
      expect(SweptSelfRemoval.of(_removal('unbanned'), _me.uid), isNull);
      expect(SweptSelfRemoval.of(_removal('kicked'), null), isNull);
    });
  });

  group('message header', () {
    Future<MessageHeaderBloc> mounted() async {
      final repo = _MockRepo();
      final bloc = MessageHeaderBloc(
        getUserUseCase: GetUserUseCase(repo),
        getGroupUseCase: GetGroupUseCase(repo),
        getLoggedInUserUseCase: GetMessageHeaderLoggedInUserUseCase(repo),
        disableSDKListeners: true,
      );
      addTearDown(bloc.close);
      bloc.add(SetGroup(_group()));
      await _drain();
      expect(bloc.state.memberCount, 5);
      return bloc;
    }

    for (final kind in ['kicked', 'banned', 'left']) {
      test(
        'a swept self-$kind updates the header like the live event',
        () async {
          final bloc = await mounted();
          hub.debugMessageSyncCompleted([
            _removal(kind, group: _group(members: 4)),
          ], SyncOutcome.caughtUp);
          await _drain();
          expect(bloc.state.memberCount, 4);
        },
      );
    }

    test('another member\'s swept removal is not routed', () async {
      final bloc = await mounted();
      hub.debugMessageSyncCompleted([
        _removal('kicked', on: _bob, group: _group(members: 4)),
      ], SyncOutcome.caughtUp);
      await _drain();
      expect(bloc.state.memberCount, 5);
    });

    test(
      'offline off: the hub stays silent and the header is unchanged',
      () async {
        CometChat.debugSetOfflineEnabledOverride(false);
        final bloc = await mounted();
        hub.debugMessageSyncCompleted([
          _removal('kicked', group: _group(members: 4)),
        ], SyncOutcome.caughtUp);
        await _drain();
        expect(bloc.state.memberCount, 5);
      },
    );
  });
}
