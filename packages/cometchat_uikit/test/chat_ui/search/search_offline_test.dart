/// W8 (ENG-41131): search and message filters with offline support.
///
/// Keyword means server: offline, a keyword search shows "Connect to search"
/// (D84 (7)) and runs again once on reconnect (D84 (8)). No keyword means cache
/// first: a filter page reads in two rounds, deduped by key; cached rows stay
/// when the server fails, and only a real error reaches `onError` (D84 (2),
/// (5)). With offline off everything is today's.
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/search_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/errors/sdk_exception.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// The code the fake repositories throw, or null to answer.
String? failCode;
int messageCalls = 0;
int conversationCalls = 0;
List<BaseMessage> messagePage = const [];

class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages ||
        name == #getGroupMessages ||
        name == #getMessages) {
      messageCalls++;
      return Future<sdk.MessagesResult>.sync(() {
        if (failCode != null) throw sdk.SdkException(failCode!, 'offline');
        return sdk.MessagesResult(messages: messagePage, hasMore: false);
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getConversations) {
      conversationCalls++;
      return Future<sdk.ConversationsResult>.sync(() {
        if (failCode != null) throw sdk.SdkException(failCode!, 'offline');
        return sdk.ConversationsResult(
          conversations: const [],
          hasMore: false,
          totalPages: 1,
          currentPage: 1,
        );
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessageRepository();

  @override
  final sdk.ConversationRepository conversations =
      _FakeConversationRepository();

  @override
  Future<void> dispose() async {}
}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

TextMessage text(int id, {String sender = 'u1'}) => TextMessage(
  id: id,
  text: 'm$id',
  sender: User(uid: sender, name: sender),
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..sentAt = DateTime.utc(2026, 1, 1, 0, 0, id);

Stream<TwoPhaseResult<T>> phases<T>(List<TwoPhaseResult<T>> events) =>
    Stream<TwoPhaseResult<T>>.fromIterable(events);

CometChatException offline() =>
    CometChatException('ERR_CONNECTION', 'offline', 'offline');

void main() {
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  group('SearchOffline.runSearchPageTwoPhase', () {
    final kept = <CometChatException>[];
    final hasMores = <bool>[];
    var unreachable = 0;

    Future<(List<List<String>>, List<CometChatException>)> run(
      List<TwoPhaseResult<String>> events, {
      List<String> base = const [],
      bool Function()? isCurrent,
    }) async {
      kept.clear();
      hasMores.clear();
      unreachable = 0;
      final rounds = <List<String>>[];
      final errors = <CometChatException>[];
      await SearchOffline.runSearchPageTwoPhase<String>(
        stream: phases(events),
        base: base,
        keyOf: (r) => r,
        limit: 2,
        isCurrent: isCurrent ?? () => true,
        emitRows: (rows, hasMore) {
          rounds.add(rows);
          hasMores.add(hasMore);
        },
        emitError: errors.add,
        onKeptRowsError: kept.add,
        onUnreachable: (_) => unreachable++,
      );
      return (rounds, errors);
    }

    test(
      'a filter with no keyword: cached, then server replacing it',
      () async {
        final (rounds, errors) = await run(
          [
            const Cached(['a', 'b']),
            const Server(['b', 'c']),
          ],
          base: ['x', 'b'],
        );
        expect(rounds, [
          ['x', 'b', 'a'],
          ['x', 'b', 'c'],
        ]);
        expect(errors, isEmpty);
      },
    );

    test('D84 (2): offline after a cached round keeps the rows and does not '
        'reach onError', () async {
      final (rounds, errors) = await run([
        const Cached(['a']),
        PhaseError(offline()),
      ]);
      expect(rounds, [
        ['a'],
      ]);
      expect(errors, isEmpty);
      expect(kept, isEmpty);
      expect(unreachable, 0);
    });

    test('D84 (5): a non-connection error after a cached round keeps the '
        'rows and reports the error to onError', () async {
      final (rounds, errors) = await run([
        const Cached(['a']),
        PhaseError(CometChatException('ERR_X', 'x', 'x')),
      ]);
      expect(rounds, [
        ['a'],
      ]);
      expect(errors, isEmpty);
      expect(kept.single.code, 'ERR_X');
    });

    test('D84 (7): offline with no cached round (empty or unavailable store, '
        'or a server-only filter) is "Connect to search"', () async {
      final (rounds, errors) = await run([PhaseError(offline())]);
      expect(rounds, isEmpty);
      expect(errors, isEmpty);
      expect(kept, isEmpty);
      expect(unreachable, 1);
    });

    test(
      'D84 (7): offline after an empty cached round is "Connect to search"',
      () async {
        final (rounds, errors) = await run([
          const Cached(<String>[]),
          PhaseError(offline()),
        ]);
        expect(rounds, [<String>[]]);
        expect(errors, isEmpty);
        expect(kept, isEmpty);
        expect(unreachable, 1);
      },
    );

    test(
      'offline on a later page keeps the rows shown and stops paging',
      () async {
        final (rounds, errors) = await run(
          [PhaseError(offline())],
          base: ['x'],
        );
        expect(rounds, [
          ['x'],
        ]);
        expect(hasMores, [false]);
        expect(errors, isEmpty);
        expect(kept, isEmpty);
      },
    );

    test('a non-connection error with no cached round is reported', () async {
      final (rounds, errors) = await run([
        PhaseError(CometChatException('ERR_X', 'x', 'x')),
      ]);
      expect(rounds, isEmpty);
      expect(errors.single.code, 'ERR_X');
      expect(kept, isEmpty);
      expect(unreachable, 0);
    });

    test('the not-connected codes are connectivity errors', () {
      for (final code in [
        'ERR_CONNECTION',
        'ERR_NETWORK_TIMEOUT',
        'ERROR_INTERNET_UNAVAILABLE',
        'ERROR_IO_EXCEPTION',
      ]) {
        expect(
          SearchOffline.isSearchConnectivityError(
            CometChatException(code, 'x', 'x'),
          ),
          isTrue,
          reason: code,
        );
      }
      expect(
        SearchOffline.isSearchConnectivityError(
          CometChatException('ERR_SERVER', 'x', 'x'),
        ),
        isFalse,
      );
    });

    // Review fix (D84): ERR_NETWORK is the SDK's catch-all for an unexpected
    // failure, not a lost connection (that is ERR_CONNECTION).
    test('review: ERR_NETWORK is not a connectivity error', () {
      expect(
        SearchOffline.isSearchConnectivityError(
          CometChatException('ERR_NETWORK', 'x', 'x'),
        ),
        isFalse,
      );
    });

    test('review: ERR_NETWORK with no cached round is the error (Retry, '
        'onError), not "Connect to search"', () async {
      final (rounds, errors) = await run([
        PhaseError(CometChatException('ERR_NETWORK', 'x', 'x')),
      ]);
      expect(rounds, isEmpty);
      expect(errors.single.code, 'ERR_NETWORK');
      expect(kept, isEmpty);
      expect(unreachable, 0);
    });

    test('review: ERR_NETWORK after a cached round keeps the rows and reaches '
        'onError once', () async {
      final (rounds, errors) = await run([
        const Cached(['a']),
        PhaseError(CometChatException('ERR_NETWORK', 'x', 'x')),
      ]);
      expect(rounds, [
        ['a'],
      ]);
      expect(errors, isEmpty);
      expect(kept.single.code, 'ERR_NETWORK');
      expect(unreachable, 0);
    });

    test('review: ERR_CONNECTION stays not-connected: no onError over a '
        'cached round, and "Connect to search" with nothing shown', () async {
      final connection = CometChatException('ERR_CONNECTION', 'x', 'x');
      var (rounds, errors) = await run([
        const Cached(['a']),
        PhaseError(connection),
      ]);
      expect(rounds, [
        ['a'],
      ]);
      expect(errors, isEmpty);
      expect(kept, isEmpty);
      (rounds, errors) = await run([PhaseError(connection)]);
      expect(errors, isEmpty);
      expect(kept, isEmpty);
      expect(unreachable, 1);
    });

    test('a superseded search emits nothing', () async {
      final (rounds, errors) = await run([
        const Cached(['a']),
        const Server(['b']),
      ], isCurrent: () => false);
      expect(rounds, isEmpty);
      expect(errors, isEmpty);
    });

    test('readSettledRows falls back to the cache only when offline, '
        'quietly (D84 (2))', () async {
      expect(
        await SearchOffline.readSettledRows(
          phases([
            const Cached(['a']),
            PhaseError<String>(offline()),
          ]),
        ),
        ['a'],
      );
      expect(
        await SearchOffline.readSettledRows(
          phases([
            const Cached(['a']),
            const Server(['b']),
          ]),
        ),
        ['b'],
      );
      expect(
        () => SearchOffline.readSettledRows(
          phases([
            const Cached(['a']),
            PhaseError<String>(CometChatException('ERR_X', 'x', 'x')),
          ]),
        ),
        throwsA(isA<CometChatException>()),
      );
      // An empty cached round showed nothing: the error is thrown.
      expect(
        () => SearchOffline.readSettledRows(
          phases([const Cached(<String>[]), PhaseError<String>(offline())]),
        ),
        throwsA(isA<CometChatException>()),
      );
    });
  });

  group('SearchBloc', () {
    setUp(() async {
      failCode = null;
      messageCalls = 0;
      conversationCalls = 0;
      messagePage = const [];
      await sdk.SdkRegistry.clear();
      sdk.SdkRegistry.register(_FakeSdkClient());
    });

    tearDown(() async {
      CometChat.debugSetOfflineEnabledOverride(null);
      await sdk.SdkRegistry.clear();
    });

    Future<SearchBloc> keywordSearch() async {
      final bloc = SearchBloc();
      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await settle();
      return bloc;
    }

    void expectConnectToSearch(SearchBloc bloc) {
      expect(bloc.state.connectToSearch, isTrue);
      expect(bloc.state.conversationsStatus, isNot(SearchStatus.error));
      expect(bloc.state.messagesStatus, isNot(SearchStatus.error));
    }

    test(
      'D84 (7) ON: a keyword search offline shows "Connect to search"',
      () async {
        CometChat.debugSetOfflineEnabledOverride(true);
        failCode = 'ERR_CONNECTION';
        final bloc = await keywordSearch();
        expectConnectToSearch(bloc);
        await bloc.close();
      },
    );

    test('review: ON, a keyword search failing with ERR_NETWORK is the '
        'error, not "Connect to search"', () async {
      CometChatUIKit.loggedInUser = null;
      CometChat.debugSetOfflineEnabledOverride(true);
      failCode = 'ERR_NETWORK';
      final bloc = await keywordSearch();
      expect(bloc.state.connectToSearch, isFalse);
      expect(bloc.state.messagesStatus, SearchStatus.error);
      await bloc.close();
    });

    Future<SearchBloc> filterOffline(List<String> chips) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      failCode = 'ERR_CONNECTION';
      final bloc = SearchBloc(initialScope: SearchScope.messages);
      for (final chip in chips) {
        bloc.add(SearchFilterToggled(chip));
        await settle();
      }
      return bloc;
    }

    // Filters with no keyword: the offline state with an empty keyword,
    // which the widget shows as the plain list's "Connect to load …" and
    // reports to onError with the carried error (D84 (3)).
    void expectMessagesConnectToSearch(SearchBloc bloc) {
      expect(bloc.state.connectToSearch, isTrue);
      expect(bloc.state.searchText, isEmpty);
      expect(bloc.state.errorMessage, contains('ERR_CONNECTION'));
      expect(bloc.state.messagesStatus, SearchStatus.empty);
      expect(bloc.state.messages, isEmpty);
    }

    test('D84 (3) ON: the Links chip offline (server-only, no cache round) '
        'shows the offline state', () async {
      final bloc = await filterOffline(['Links']);
      expect(messageCalls, greaterThanOrEqualTo(1));
      expectMessagesConnectToSearch(bloc);
      await bloc.close();
    });

    test('D84 (3) ON: a filter with no keyword over an empty store offline '
        'shows the offline state', () async {
      final bloc = await filterOffline(['Photos']);
      expectMessagesConnectToSearch(bloc);
      await bloc.close();
    });

    test('D84 (3) ON: several attachment filters offline (merged read) show '
        'the offline state', () async {
      final bloc = await filterOffline(['Photos', 'Videos']);
      expect(bloc.state.selectedFilters, containsAll(['Photos', 'Videos']));
      expectMessagesConnectToSearch(bloc);
      await bloc.close();
    });

    test('D84 (3) ON: a conversation filter offline over an empty store '
        'shows the offline state', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      failCode = 'ERR_CONNECTION';
      final bloc = SearchBloc(initialScope: SearchScope.conversations);
      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      expect(conversationCalls, greaterThanOrEqualTo(1));
      expect(bloc.state.connectToSearch, isTrue);
      expect(bloc.state.searchText, isEmpty);
      expect(bloc.state.errorMessage, contains('ERR_CONNECTION'));
      expect(bloc.state.conversationsStatus, SearchStatus.empty);
      await bloc.close();
    });

    test('OFF: the Links chip offline errors as today', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      failCode = 'ERR_CONNECTION';
      final bloc = SearchBloc(initialScope: SearchScope.messages);
      bloc.add(const SearchFilterToggled('Links'));
      await settle();
      expect(bloc.state.messagesStatus, SearchStatus.error);
      await bloc.close();
    });

    test('ON: a keyword search paging offline keeps the rows shown and '
        'stops paging', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      messagePage = [for (var i = 1; i <= 30; i++) text(i)];
      final bloc = SearchBloc(initialScope: SearchScope.messages);
      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await settle();
      expect(bloc.state.messages, hasLength(30));
      expect(bloc.state.hasMoreMessages, isTrue);
      failCode = 'ERR_CONNECTION';
      bloc.add(const LoadMoreMessageResults());
      await settle();
      expect(bloc.state.messagesStatus, SearchStatus.loaded);
      expect(bloc.state.messages, hasLength(30));
      expect(bloc.state.hasMoreMessages, isFalse);
      await bloc.close();
    });

    test('ON: a non-connection failure is still an error', () async {
      CometChatUIKit.loggedInUser = null;
      CometChat.debugSetOfflineEnabledOverride(true);
      failCode = 'ERR_SERVER';
      final bloc = await keywordSearch();
      expect(bloc.state.messagesStatus, SearchStatus.error);
      await bloc.close();
    });

    test('OFF: a keyword search offline errors as today', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      failCode = 'ERR_CONNECTION';
      final bloc = await keywordSearch();
      expect(bloc.state.messagesStatus, SearchStatus.error);
      expect(bloc.state.conversationsStatus, SearchStatus.error);
      await bloc.close();
    });

    group('D84 (8) reconnect', () {
      final listeners = <String, ConnectionListener>{};

      setUp(() {
        listeners.clear();
        ChatSdkListeners.debugAddConnectionListener = (id, l) =>
            listeners[id] = l;
        ChatSdkListeners.debugRemoveConnectionListener = listeners.remove;
      });

      tearDown(ChatSdkListeners.debugReset);

      test('ON: "Connect to search" runs the search again, once, on '
          'reconnect', () async {
        CometChat.debugSetOfflineEnabledOverride(true);
        failCode = 'ERR_CONNECTION';
        final bloc = await keywordSearch();
        expect(bloc.state.connectToSearch, isTrue);
        final before = messageCalls;
        failCode = null;
        messagePage = [text(1)];

        listeners.values.single.onConnected();
        await settle();
        listeners.values.single.onConnected();
        await settle();
        expect(messageCalls, before + 1);
        expect(bloc.state.messagesStatus, SearchStatus.loaded);
        expect(bloc.state.connectToSearch, isFalse);
        await bloc.close();
        expect(listeners, isEmpty);
      });

      test('ON: a server error (not offline) is not run again', () async {
        CometChatUIKit.loggedInUser = null;
        CometChat.debugSetOfflineEnabledOverride(true);
        failCode = 'ERR_SERVER';
        final bloc = await keywordSearch();
        final before = messageCalls;
        listeners.values.single.onConnected();
        await settle();
        expect(messageCalls, before);
        await bloc.close();
      });

      group('the SDK\'s empty cached page first', () {
        var reads = 0;
        var online = false;

        setUp(() {
          reads = 0;
          online = false;
          // The real SDK sends an EMPTY cached page first whenever the
          // offline store is open, then the server round or its error.
          SearchOffline.debugFetchOverride = (_) {
            reads++;
            return phases([
              const Cached(<BaseMessage>[]),
              online ? Server([text(1)]) : PhaseError(offline()),
            ]);
          };
        });

        tearDown(() => SearchOffline.debugFetchOverride = null);

        Future<void> expectConnectToSearchThenReload(List<String> chips) async {
          CometChat.debugSetOfflineEnabledOverride(true);
          final bloc = SearchBloc(initialScope: SearchScope.messages);
          final kept = <CometChatException>[];
          OfflineListErrors.listen(bloc, kept.add);
          for (final chip in chips) {
            bloc.add(SearchFilterToggled(chip));
            await settle();
          }
          expect(bloc.state.connectToSearch, isTrue);
          expect(bloc.state.messagesStatus, SearchStatus.empty);
          expect(bloc.state.messages, isEmpty);
          // An offline state, not a kept-rows report.
          expect(kept, isEmpty);

          final before = reads;
          online = true;
          listeners.values.single.onConnected();
          await settle();
          listeners.values.single.onConnected();
          await settle();
          expect(reads, before + chips.length);
          expect(bloc.state.messagesStatus, SearchStatus.loaded);
          expect(bloc.state.messages.map((m) => m.id), [1]);
          await bloc.close();
        }

        test(
          'D84 (7), (8) ON: several attachment filters offline (merged '
          'read) show "Connect to search" and reload once on reconnect',
          () async {
            await expectConnectToSearchThenReload(['Photos', 'Videos']);
          },
        );

        test('D84 (7), (8) ON: one filter offline shows "Connect to search" '
            'and reloads once on reconnect', () async {
          await expectConnectToSearchThenReload(['Photos']);
        });
      });

      test('OFF: no connection listener, as today', () async {
        CometChat.debugSetOfflineEnabledOverride(false);
        final bloc = SearchBloc();
        expect(listeners, isEmpty);
        await bloc.close();
      });
    });

    test('ON: a filter with no keyword reads through the two-phase listener '
        'and shows the server round', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      messagePage = [text(1), text(2)];
      final bloc = SearchBloc(initialScope: SearchScope.messages);
      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      expect(messageCalls, 1);
      expect(bloc.state.messagesStatus, SearchStatus.loaded);
      // Newest first, as today.
      expect(bloc.state.messages.map((m) => m.id), [2, 1]);
      await bloc.close();
    });
  });

  group('CometChatSearch', () {
    Future<(int, int)> pumpSearch(
      WidgetTester tester,
      SearchState state, {
      MockSearchBloc? bloc,
      WidgetBuilder? errorView,
    }) async {
      final b = bloc ?? MockSearchBloc();
      when(() => b.state).thenReturn(state);
      when(() => b.isClosed).thenReturn(false);
      whenListen(b, Stream<SearchState>.value(state), initialState: state);
      var errors = 0;
      var empties = 0;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: CometChatSearch(
              searchBloc: b,
              errorStateView: errorView,
              onError: (_) => errors++,
              onEmpty: () => empties++,
            ),
          ),
        );
        await tester.pump();
      });
      return (errors, empties);
    }

    const realError = SearchState(
      searchText: 'hello',
      conversationsStatus: SearchStatus.error,
      messagesStatus: SearchStatus.error,
      errorMessage: 'boom',
    );

    const connectToSearch = SearchState(
      searchText: 'hello',
      conversationsStatus: SearchStatus.empty,
      messagesStatus: SearchStatus.empty,
      connectToSearch: true,
    );

    testWidgets('D84 (7): an offline search with no saved match shows '
        '"Connect to search", with no onError and no onEmpty', (tester) async {
      final (errors, empties) = await pumpSearch(
        tester,
        connectToSearch,
        errorView: (_) => const Text('app error view'),
      );
      expect(find.text(TranslationsEn().connectToSearch), findsOneWidget);
      expect(
        find.text(TranslationsEn().connectToSearchSubtitle),
        findsOneWidget,
      );
      expect(find.text('app error view'), findsNothing);
      expect(find.text(TranslationsEn().retry), findsNothing);
      expect(errors, 0);
      expect(empties, 0);
    });

    // D84: a filter with no keyword is a plain list.
    const conversationFilterOnly = SearchState(
      selectedFilters: {'Unread'},
      conversationsStatus: SearchStatus.empty,
      showMessages: false,
      errorMessage: 'ERR_CONNECTION',
      connectToSearch: true,
    );
    const messageFilterOnly = SearchState(
      selectedFilters: {'Photos'},
      messagesStatus: SearchStatus.empty,
      showConversations: false,
      errorMessage: 'ERR_CONNECTION',
      connectToSearch: true,
    );

    testWidgets('D84 (3): a conversation filter with no keyword, offline with '
        'nothing saved, shows "Connect to load chats" and fires onError '
        'once', (tester) async {
      final (errors, empties) = await pumpSearch(
        tester,
        conversationFilterOnly,
      );
      expect(find.text(TranslationsEn().connectToLoadChats), findsOneWidget);
      expect(find.text(TranslationsEn().connectToSearch), findsNothing);
      expect(find.text(TranslationsEn().connectToSearchSubtitle), findsNothing);
      expect(find.text(TranslationsEn().retry), findsNothing);
      expect(errors, 1);
      expect(empties, 0);
    });

    testWidgets('D84 (3): a message filter with no keyword shows "Connect to '
        'load messages"', (tester) async {
      final (errors, _) = await pumpSearch(tester, messageFilterOnly);
      expect(find.text(TranslationsEn().connectToLoadMessages), findsOneWidget);
      expect(find.text(TranslationsEn().connectToSearch), findsNothing);
      expect(errors, 1);
    });

    // D84 review fix 2: a hidden section keeps the rows it had before the
    // Photos chip hid it (the bloc clears only visible sections). Those
    // stale rows must not block the offline states.
    final staleChat = Conversation(
      conversationId: 'c1',
      conversationType: ReceiverTypeConstants.user,
      conversationWith: User(uid: 'bob', name: 'Bob'),
    );

    testWidgets('D84 (7): stale rows in the hidden chats section still show '
        '"Connect to search" for a keyword search', (tester) async {
      final (errors, empties) = await pumpSearch(
        tester,
        SearchState(
          searchText: 'hi',
          selectedFilters: const {'Photos'},
          conversations: [staleChat],
          conversationsStatus: SearchStatus.loaded,
          messagesStatus: SearchStatus.empty,
          showConversations: false,
          errorMessage: 'ERR_CONNECTION',
          connectToSearch: true,
        ),
      );
      expect(find.text(TranslationsEn().connectToSearch), findsOneWidget);
      expect(
        find.text(TranslationsEn().connectToSearchSubtitle),
        findsOneWidget,
      );
      expect(errors, 0);
      expect(empties, 0);
    });

    testWidgets('D84 (3): stale rows in the hidden chats section still show '
        '"Connect to load messages" for a filter-only list, with onError '
        'once', (tester) async {
      final (errors, empties) = await pumpSearch(
        tester,
        SearchState(
          selectedFilters: const {'Photos'},
          conversations: [staleChat],
          conversationsStatus: SearchStatus.loaded,
          messagesStatus: SearchStatus.empty,
          showConversations: false,
          errorMessage: 'ERR_CONNECTION',
          connectToSearch: true,
        ),
      );
      expect(find.text(TranslationsEn().connectToLoadMessages), findsOneWidget);
      expect(find.text(TranslationsEn().connectToSearch), findsNothing);
      expect(errors, 1);
      expect(empties, 0);
    });

    testWidgets('D84 (3): a filter with no keyword and an app error view shows '
        'that view instead', (tester) async {
      final (errors, _) = await pumpSearch(
        tester,
        conversationFilterOnly,
        errorView: (_) => const Text('app error view'),
      );
      expect(find.text('app error view'), findsOneWidget);
      expect(find.text(TranslationsEn().connectToLoadChats), findsNothing);
      expect(errors, 1);
    });

    testWidgets('D84 (4): a real error shows the app error view and fires '
        'onError', (tester) async {
      final (errors, empties) = await pumpSearch(
        tester,
        realError,
        errorView: (_) => const Text('app error view'),
      );
      expect(find.text('app error view'), findsOneWidget);
      expect(errors, 1);
      expect(empties, 0);
    });

    testWidgets('D84 (4): without an app error view a real error shows the '
        'kit error view', (tester) async {
      final (errors, _) = await pumpSearch(tester, realError);
      expect(find.text(TranslationsEn().connectToSearch), findsNothing);
      expect(
        find.text(TranslationsEn().somethingWentWrongError),
        findsOneWidget,
      );
      expect(errors, 1);
    });

    testWidgets(
      'D84 (5): a real error reported over kept rows reaches onError',
      (tester) async {
        const state = SearchState(searchText: 'hello');
        final bloc = MockSearchBloc();
        when(() => bloc.state).thenReturn(state);
        when(() => bloc.isClosed).thenReturn(false);
        whenListen(bloc, Stream<SearchState>.value(state), initialState: state);
        var errors = 0;
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: Translations.localizationsDelegates,
              supportedLocales: const [Locale('en')],
              home: CometChatSearch(searchBloc: bloc, onError: (_) => errors++),
            ),
          );
          await tester.pump();
        });
        expect(errors, 0);
        OfflineListErrors.report(bloc, CometChatException('ERR_X', 'x', 'x'));
        expect(errors, 1);
      },
    );
  });
}
