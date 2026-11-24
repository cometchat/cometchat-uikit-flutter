/// D84 (ENG-41552): the list rules. With offline on, a list that shows
/// nothing and fails offline shows the offline state ("Connect to load ...",
/// no Retry; the app's error view instead when it passed one) and fires
/// `onError` once (3); a real error there shows the error view and fires
/// `onError` (4); a real error over cached rows kept fires `onError` (5); an
/// empty answer shows the empty view (6); an offline search with no saved
/// match shows "Connect to search" and no `onError` (7). Users, Groups, Group
/// Members and Conversations.
///
///   flutter test test/shared_ui/offline/offline_error_view_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_offline.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_offline.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/conversations_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/notification_feed_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _UsersBloc extends MockBloc<UsersEvent, UsersState> implements UsersBloc {
  @override
  ValueNotifier<String> getStatusNotifier(String uid) =>
      ValueNotifier<String>('offline');

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {}
}

class _GroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {
  @override
  List<Group> getSelectedGroups() => const [];

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) {}
}

class _MembersBloc extends MockBloc<GroupMembersEvent, GroupMembersState>
    implements GroupMembersBloc {
  @override
  // ignore: must_call_super
  void add(GroupMembersEvent event) {}
}

class _ConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

class _FeedBloc extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

class _ReactionsBloc extends MockBloc<ReactionListEvent, ReactionListState>
    implements ReactionListBloc {}

final _en = TranslationsEn();
const _appError = 'app error view D84';
const _appEmpty = 'app empty view D84';
final _offline = CometChatException('ERR_CONNECTION', 'offline', 'offline');

/// What the list's bloc emits after loading.
enum _Kind {
  /// Nothing: it stays loading.
  none,

  /// A real error with nothing shown (D84 (4)).
  error,

  /// The server answered nothing (D84 (6)).
  empty,

  /// Offline with nothing shown (D84 (3)).
  offline,

  /// Offline search with no saved match (D84 (7)).
  search,
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// What a list under test reports.
class _Calls {
  int errors = 0;
  int empties = 0;
}

/// Builds one list around [bloc], with or without the app's views.
typedef _Build =
    Widget Function(
      Object bloc,
      _Calls calls, {
      WidgetBuilder? errorView,
      WidgetBuilder? emptyView,
    });

/// One list under test.
class _List {
  const _List(this.name, this.bloc, this.build, this.connectToLoad);

  final String name;

  /// A bloc that goes from loading to the state of [_Kind].
  final Object Function(_Kind kind) bloc;

  /// The list's "Connect to load ..." text.
  final String Function(Translations t) connectToLoad;

  /// Whether the list has a "Connect to search" state.
  bool get hasSearch => name != 'Conversations';
  final _Build build;
}

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public');

final _lists = <_List>[
  _List(
    'Users',
    (kind) {
      final bloc = _UsersBloc();
      whenListen(
        bloc,
        kind == _Kind.none
            ? const Stream<UsersState>.empty()
            : Stream<UsersState>.value(switch (kind) {
                _Kind.error => const UsersError(message: 'offline'),
                _Kind.empty => const UsersEmpty(),
                _Kind.offline => UsersConnectToLoad(_offline),
                _Kind.search => const UsersConnectToSearch(),
                _Kind.none => throw StateError('none'),
              }),
        initialState: const UsersLoading(),
      );
      return bloc;
    },
    (bloc, calls, {errorView, emptyView}) => CometChatUsers(
      usersBloc: bloc as UsersBloc,
      errorStateView: errorView,
      emptyStateView: emptyView,
      onError: (_) => calls.errors++,
      onEmpty: () => calls.empties++,
    ),
    (t) => t.connectToLoadUsers,
  ),
  _List(
    'Groups',
    (kind) {
      final bloc = _GroupsBloc();
      whenListen(
        bloc,
        kind == _Kind.none
            ? const Stream<GroupsState>.empty()
            : Stream<GroupsState>.value(switch (kind) {
                _Kind.error => const GroupsError(message: 'offline'),
                _Kind.empty => const GroupsEmpty(),
                _Kind.offline => GroupsConnectToLoad(_offline),
                _Kind.search => const GroupsConnectToSearch(),
                _Kind.none => throw StateError('none'),
              }),
        initialState: const GroupsLoading(),
      );
      return bloc;
    },
    (bloc, calls, {errorView, emptyView}) => CometChatGroups(
      groupsBloc: bloc as GroupsBloc,
      errorStateView: errorView,
      emptyStateView: emptyView,
      onError: (_) => calls.errors++,
      onEmpty: () => calls.empties++,
    ),
    (t) => t.connectToLoadGroups,
  ),
  _List(
    'Group Members',
    (kind) {
      final bloc = _MembersBloc();
      whenListen(
        bloc,
        kind == _Kind.none
            ? const Stream<GroupMembersState>.empty()
            : Stream<GroupMembersState>.value(switch (kind) {
                _Kind.error => const GroupMembersError(message: 'offline'),
                _Kind.empty => const GroupMembersEmpty(),
                _Kind.offline => GroupMembersConnectToLoad(_offline),
                _Kind.search => const GroupMembersConnectToSearch(),
                _Kind.none => throw StateError('none'),
              }),
        initialState: const GroupMembersLoading(),
      );
      when(() => bloc.loggedInUser).thenReturn(User(uid: 'me', name: 'Me'));
      when(() => bloc.getSelectedList()).thenReturn(const []);
      return bloc;
    },
    (bloc, calls, {errorView, emptyView}) => CometChatGroupMembers(
      group: _group,
      groupMembersBloc: bloc as GroupMembersBloc,
      errorStateView: errorView,
      emptyStateView: emptyView,
      onError: (_) => calls.errors++,
      onEmpty: () => calls.empties++,
    ),
    (t) => t.connectToLoadMembers,
  ),
  _List(
    'Conversations',
    (kind) {
      final bloc = _ConversationsBloc();
      whenListen(
        bloc,
        kind == _Kind.none
            ? const Stream<ConversationsState>.empty()
            : Stream<ConversationsState>.value(switch (kind) {
                _Kind.error => const ConversationsError(message: 'offline'),
                _Kind.empty => const ConversationsEmpty(),
                _Kind.offline => ConversationsConnectToLoad(_offline),
                _Kind.search => throw StateError('no search'),
                _Kind.none => throw StateError('none'),
              }),
        initialState: const ConversationsLoading(),
      );
      return bloc;
    },
    (bloc, calls, {errorView, emptyView}) => CometChatConversations(
      conversationsBloc: bloc as ConversationsBloc,
      errorStateView: errorView,
      emptyStateView: emptyView,
      onError: (_) => calls.errors++,
      onEmpty: () => calls.empties++,
    ),
    (t) => t.connectToLoadChats,
  ),
];

void main() {
  setUp(() => CometChat.debugSetOfflineEnabledOverride(true));
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  for (final list in _lists) {
    group('D84 ${list.name}', () {
      Future<_Calls> pump(
        WidgetTester tester,
        Object bloc, {
        bool appError = false,
        bool appEmpty = false,
      }) async {
        final calls = _Calls();
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              list.build(
                bloc,
                calls,
                errorView: appError ? (_) => const Text(_appError) : null,
                emptyView: appEmpty ? (_) => const Text(_appEmpty) : null,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        });
        return calls;
      }

      testWidgets('(4) a real error, nothing shown: the app error view, and '
          'onError', (tester) async {
        final calls = await pump(
          tester,
          list.bloc(_Kind.error),
          appError: true,
        );
        expect(find.text(_appError), findsOneWidget);
        expect(calls.errors, 1);
      });

      testWidgets(
        '(4) without an app error view: the kit error view, and onError',
        (tester) async {
          final calls = await pump(tester, list.bloc(_Kind.error));
          expect(find.text(_en.oops), findsOneWidget);
          expect(find.text(_appError), findsNothing);
          expect(calls.errors, 1);
        },
      );

      testWidgets('(6) an empty answer: the app empty view, and onEmpty', (
        tester,
      ) async {
        final calls = await pump(
          tester,
          list.bloc(_Kind.empty),
          appEmpty: true,
        );
        expect(find.text(_appEmpty), findsOneWidget);
        expect(calls.empties, 1);
        expect(calls.errors, 0);
      });

      testWidgets('(5) a real error over cached rows kept reaches onError', (
        tester,
      ) async {
        final bloc = list.bloc(_Kind.none);
        final calls = await pump(tester, bloc);
        expect(calls.errors, 0);
        OfflineListErrors.report(
          bloc,
          CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x'),
        );
        expect(calls.errors, 1);
        expect(find.text(_en.oops), findsNothing);
      });

      testWidgets('(3) offline, nothing shown: the kit offline state with no '
          'Retry, and onError once', (tester) async {
        final calls = await pump(tester, list.bloc(_Kind.offline));
        expect(find.text(list.connectToLoad(_en)), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.text(_en.retry), findsNothing);
        expect(find.text(_en.oops), findsNothing);
        expect(calls.errors, 1);
        expect(calls.empties, 0);
      });

      testWidgets('(3) offline, nothing shown, with an app error view: that '
          'view instead, and onError once', (tester) async {
        final calls = await pump(
          tester,
          list.bloc(_Kind.offline),
          appError: true,
          appEmpty: true,
        );
        expect(find.text(_appError), findsOneWidget);
        expect(find.text(_appEmpty), findsNothing);
        expect(find.text(list.connectToLoad(_en)), findsNothing);
        expect(calls.errors, 1);
        expect(calls.empties, 0);
      });

      if (list.hasSearch) {
        testWidgets('(7) offline search, no saved match: "Connect to search" '
            'with its subtitle, and no onError', (tester) async {
          final calls = await pump(
            tester,
            list.bloc(_Kind.search),
            appError: true,
          );
          expect(find.text(_en.connectToSearch), findsOneWidget);
          expect(find.text(_en.connectToSearchSubtitle), findsOneWidget);
          expect(
            _en.connectToSearchSubtitle,
            'Search needs an internet connection.',
          );
          expect(find.text(_appError), findsNothing);
          expect(find.text(_en.retry), findsNothing);
          expect(calls.errors, 0);
          expect(calls.empties, 0);
        });
      }
    });
  }

  group('D84 Notification feed', () {
    _FeedBloc feedBloc(String code, {required bool offline}) {
      final bloc = _FeedBloc();
      whenListen(
        bloc,
        Stream<NotificationFeedState>.value(
          NotificationFeedState(
            screenState: NotificationFeedScreenState.error,
            error: code,
          ),
        ),
        initialState: NotificationFeedState(
          screenState: NotificationFeedScreenState.loading,
        ),
      );
      when(() => bloc.isClosed).thenReturn(false);
      NotificationFeedOffline.setOfflineState(bloc, offline);
      return bloc;
    }

    Future<List<String>> pump(
      WidgetTester tester,
      NotificationFeedBloc bloc, {
      bool appError = false,
    }) async {
      final errors = <String>[];
      await tester.pumpWidget(
        _wrap(
          CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            errorStateView: appError ? const Text(_appError) : null,
            onError: errors.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return errors;
    }

    testWidgets('(3) offline, nothing shown: "Connect to load notifications" '
        'with no Retry, and onError', (tester) async {
      final errors = await pump(tester, feedBloc('offline', offline: true));
      expect(find.text(_en.connectToLoadNotifications), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text(_en.retry), findsNothing);
      expect(errors, hasLength(1));
    });

    testWidgets('(3) offline, nothing shown, with an app error view: that '
        'view instead', (tester) async {
      final errors = await pump(
        tester,
        feedBloc('offline', offline: true),
        appError: true,
      );
      expect(find.text(_appError), findsOneWidget);
      expect(find.text(_en.connectToLoadNotifications), findsNothing);
      expect(errors, hasLength(1));
    });

    testWidgets('(4) a real error, nothing shown: the error view', (
      tester,
    ) async {
      final errors = await pump(tester, feedBloc('boom', offline: false));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text(_en.connectToLoadNotifications), findsNothing);
      expect(errors, hasLength(1));
    });
  });

  group('D84 Reactions', () {
    TextMessage message() => TextMessage(
      id: 1,
      text: 'hi',
      sender: User(uid: 'u1', name: 'Alice'),
      receiverUid: 'u2',
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
    );

    _ReactionsBloc reactionsBloc(String code) {
      final state = ReactionListError(
        error: CometChatException(code, 'x', 'x'),
        messageReactions: const {},
        selectedReaction: 'all',
      );
      final bloc = _ReactionsBloc();
      whenListen(
        bloc,
        Stream<ReactionListState>.value(state),
        initialState: state,
      );
      return bloc;
    }

    Future<void> pump(
      WidgetTester tester,
      ReactionListBloc bloc, {
      bool appError = false,
    }) async {
      await tester.pumpWidget(
        _wrap(
          CometChatReactionList(
            message: message(),
            reactionListBloc: bloc,
            errorStateView: appError ? (_) => const Text(_appError) : null,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('(3) offline, nothing shown: "Connect to load reactions" '
        'with no Retry', (tester) async {
      await pump(tester, reactionsBloc('ERR_CONNECTION'));
      expect(find.text(_en.connectToLoadReactions), findsOneWidget);
      expect(find.text(_en.retry), findsNothing);
      expect(find.text(_en.oops), findsNothing);
    });

    testWidgets('(3) offline, with an app error view: that view instead', (
      tester,
    ) async {
      await pump(tester, reactionsBloc('ERR_CONNECTION'), appError: true);
      expect(find.text(_appError), findsOneWidget);
      expect(find.text(_en.connectToLoadReactions), findsNothing);
    });

    testWidgets('(4) a real error: the error view', (tester) async {
      await pump(tester, reactionsBloc('ERR_TOO_MANY_REQUESTS'));
      expect(find.text(_en.oops), findsOneWidget);
      expect(find.text(_en.connectToLoadReactions), findsNothing);
    });

    testWidgets('(11) offline off: a not-connected error is the error view', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      await pump(tester, reactionsBloc('ERR_CONNECTION'));
      expect(find.text(_en.oops), findsOneWidget);
      expect(find.text(_en.connectToLoadReactions), findsNothing);
    });
  });
}
