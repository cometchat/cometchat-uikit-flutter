/// ENG-41552 A: with offline on, no presence while the SDK is not connected —
/// no "Online" subtitle or dot in the message header, no online dots in the
/// users and conversations lists — and it comes back on reconnect. With
/// offline off nothing changes.
///
/// ENG-41552 K: a contract id is built only when its node is added, so with
/// offline off a conversation row's id string is never built.
///
///   flutter test test/shared_ui/offline/offline_presence_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/contract_ids.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_presence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockHeaderBloc extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

class _MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  final _status = <String, ValueNotifier<String>>{};

  @override
  ValueNotifier<String> getStatusNotifier(String uid) => _status.putIfAbsent(
    uid,
    () => ValueNotifier<String>(UserStatusConstants.online),
  );

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {}
}

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  final _typing = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier(const []));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => const [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

class _MockMembersBloc extends MockBloc<GroupMembersEvent, GroupMembersState>
    implements GroupMembersBloc {
  @override
  // ignore: must_call_super
  void add(GroupMembersEvent event) {}
}

final _bob = User(uid: 'u2', name: 'Bob', status: 'online');

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

_MockHeaderBloc _header() {
  final state = MessageHeaderState(
    status: MessageHeaderStatus.loaded,
    user: _bob,
  );
  final bloc = _MockHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

_MockUsersBloc _users() {
  final state = UsersLoaded(
    users: [
      User(uid: 'u1', name: 'Alice', status: 'online'),
      User(uid: 'u3', name: 'Carla', status: 'online'),
    ],
    hasMore: false,
  );
  final bloc = _MockUsersBloc();
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

_MockConversationsBloc _conversations() {
  final state = ConversationsLoaded(
    conversations: [
      Conversation(
        conversationId: 'me_user_u2',
        conversationType: 'user',
        conversationWith: _bob,
      ),
    ],
    hasMore: false,
  );
  final bloc = _MockConversationsBloc();
  whenListen(
    bloc,
    Stream<ConversationsState>.value(state),
    initialState: state,
  );
  return bloc;
}

Widget _usersList(UsersBloc bloc) => _wrap(
  UsersList(
    usersBloc: bloc,
    style: const CometChatUsersStyle(),
    colorPalette: CometChatColorPalette(
      success: const Color(0xFF09C26F),
      background1: const Color(0xFFFFFFFF),
    ),
    spacing: CometChatSpacing(),
    typography: const CometChatTypography(),
  ),
);

Widget _conversationsList(ConversationsBloc bloc) => _wrap(
  ConversationsList(
    conversationsBloc: bloc,
    style: const CometChatConversationsStyle(),
    statusStyle: const CometChatStatusIndicatorStyle(),
    typingStyle: const CometChatTypingIndicatorStyle(),
    receiptStyle: CometChatMessageReceiptStyle(),
    datesStyle: const CometChatDateStyle(),
    colorPalette: CometChatColorPalette(),
    spacing: CometChatSpacing(),
    typography: const CometChatTypography(),
  ),
);

_MockMembersBloc _members() {
  final state = GroupMembersLoaded(
    members: [
      GroupMember(uid: 'u1', name: 'Alice', scope: 'participant')
        ..status = 'online',
      GroupMember(uid: 'u3', name: 'Carla', scope: 'participant')
        ..status = 'online',
    ],
    hasMore: false,
  );
  final bloc = _MockMembersBloc();
  whenListen(bloc, Stream<GroupMembersState>.value(state), initialState: state);
  when(() => bloc.loggedInUser).thenReturn(User(uid: 'me', name: 'Me'));
  when(() => bloc.getSelectedList()).thenReturn(const []);
  return bloc;
}

Widget _membersList(GroupMembersBloc bloc) => _wrap(
  CometChatGroupMembers(
    group: Group(guid: 'g1', name: 'Dev Team', type: 'public'),
    groupMembersBloc: bloc,
  ),
);

/// The online dots the group members rows show.
int _memberDots(WidgetTester tester) => tester
    .widgetList<CometChatListItem>(find.byType(CometChatListItem))
    .where((item) => item.statusIndicatorColor != null)
    .length;

bool _rowHidesStatus(WidgetTester tester) => tester
    .widget<CometChatConversationListItem>(
      find.byType(CometChatConversationListItem),
    )
    .hideUserStatus;

void main() {
  tearDown(() {
    OfflinePresence.debugReset();
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  group('A: sync race', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(true));

    test('a connect that lands while sync() is reading wins over a stale '
        '"disconnected" answer', () async {
      final read = Completer<String>();
      OfflinePresence.debugReadConnectionStatus = () => read.future;
      OfflinePresence.disconnected();
      expect(OfflinePresence.hidden, isTrue);

      final syncing = OfflinePresence.sync();
      OfflinePresence.connected();
      read.complete(CometChatWSState.disconnected);
      await syncing;

      expect(OfflinePresence.hidden, isFalse);
    });

    test('a disconnect that lands while sync() is reading wins over a stale '
        '"connected" answer', () async {
      final read = Completer<String>();
      OfflinePresence.debugReadConnectionStatus = () => read.future;

      final syncing = OfflinePresence.sync();
      OfflinePresence.disconnected();
      read.complete(CometChatWSState.connected);
      await syncing;

      expect(OfflinePresence.hidden, isTrue);
    });

    test(
      'with no connection event in flight, sync() applies its answer',
      () async {
        OfflinePresence.debugReadConnectionStatus = () async =>
            CometChatWSState.disconnected;
        await OfflinePresence.sync();
        expect(OfflinePresence.hidden, isTrue);

        OfflinePresence.debugReadConnectionStatus = () async =>
            CometChatWSState.connected;
        await OfflinePresence.sync();
        expect(OfflinePresence.hidden, isFalse);
      },
    );
  });

  group('A: offline on', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(true));

    testWidgets('the header drops "Online" and its dot while not connected, '
        'and shows them again on reconnect', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(user: _bob, messageHeaderBloc: _header()),
          ),
        );
        await tester.pump();
      });
      CometChatListItem item() =>
          tester.widget<CometChatListItem>(find.byType(CometChatListItem));
      expect(find.text('Online'), findsOneWidget);
      expect(item().statusIndicatorColor, isNotNull);

      OfflinePresence.disconnected();
      await tester.pump();
      expect(find.text('Online'), findsNothing);
      expect(item().statusIndicatorColor, isNull);

      OfflinePresence.connected();
      await tester.pump();
      expect(find.text('Online'), findsOneWidget);
      expect(item().statusIndicatorColor, isNotNull);
    });

    testWidgets('the users list drops its online dots while not connected', (
      tester,
    ) async {
      await tester.pumpWidget(_usersList(_users()));
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsNWidgets(2));

      OfflinePresence.disconnected();
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsNothing);

      OfflinePresence.connected();
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsNWidgets(2));
    });

    testWidgets('a conversation row hides its online dot while not connected', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_conversationsList(_conversations()));
        await tester.pump();
      });
      expect(_rowHidesStatus(tester), isFalse);

      OfflinePresence.disconnected();
      await tester.pump();
      expect(_rowHidesStatus(tester), isTrue);

      OfflinePresence.connected();
      await tester.pump();
      expect(_rowHidesStatus(tester), isFalse);
    });

    testWidgets('D84 (10): the group members list drops its online dots '
        'while not connected', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_membersList(_members()));
        await tester.pump();
      });
      expect(_memberDots(tester), 2);

      OfflinePresence.disconnected();
      await tester.pump();
      expect(_memberDots(tester), 0);

      OfflinePresence.connected();
      await tester.pump();
      expect(_memberDots(tester), 2);
    });
  });

  group('A: offline off', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(false));

    testWidgets('a disconnect changes nothing in the header, the users list '
        'or a conversation row', (tester) async {
      OfflinePresence.disconnected();
      expect(OfflinePresence.hidden, isFalse);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(user: _bob, messageHeaderBloc: _header()),
          ),
        );
        await tester.pump();
      });
      expect(find.text('Online'), findsOneWidget);

      await tester.pumpWidget(_usersList(_users()));
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsNWidgets(2));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_conversationsList(_conversations()));
        await tester.pump();
      });
      expect(_rowHidesStatus(tester), isFalse);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_membersList(_members()));
        await tester.pump();
      });
      expect(_memberDots(tester), 2);
    });
  });

  group('K: lazyContractNode', () {
    for (final on in [true, false]) {
      testWidgets('builds its identifier only with offline on '
          '(offline ${on ? 'on' : 'off'})', (tester) async {
        CometChat.debugSetOfflineEnabledOverride(on);
        var built = 0;
        await tester.pumpWidget(
          _wrap(
            lazyContractNode(
              identifier: () {
                built++;
                return 'cc-conversation-row|index=0';
              },
              child: const Text('row'),
            ),
          ),
        );
        expect(built, on ? 1 : 0);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'cc-conversation-row|index=0',
          ),
          on ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
