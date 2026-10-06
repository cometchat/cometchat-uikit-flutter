/// The branches of [CometChatConversations] the prop matrix does not reach:
/// the long-press context menu, the selection chrome, the delete confirmation
/// and the route-visibility hooks.
///
/// The prop matrices pin that each slot renders. This pins the behaviour
/// around the row: which menu entries a conversation gets and in what order,
/// what a long press does when there is nothing to show, that a tap dismisses
/// an open menu instead of opening the chat, what the delete dialog dispatches
/// on confirm versus cancel, and that the `routeObserver` hook actually tracks
/// visibility. None of that is observable from a prop table.
///
///   flutter test test/chat_ui/conversations/widget/conversations_branches_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Unlike the prop matrix's mock, this one lets `add` through so the events a
/// gesture dispatches can be verified.
class MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  final _typing = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier(const []));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => const [];
}

class FakeUser extends Fake implements User {
  FakeUser({this.name = 'Alice', this.uid = 'u1'});

  @override
  final String name;
  @override
  final String uid;
  @override
  String? get avatar => null;
  @override
  String get status => 'online';
  @override
  String? get role => 'default';
  @override
  String? get link => null;
}

class FakeConversation extends Fake implements Conversation {
  FakeConversation({
    this.conversationId = 'user_u1',
    this.unreadMessageCount = 0,
    this.pinnedBy,
    AppEntity? with_,
  }) : conversationWith = with_ ?? FakeUser();

  @override
  final String conversationId;
  @override
  final AppEntity conversationWith;
  @override
  final int unreadMessageCount;
  @override
  BaseMessage? get lastMessage => null;
  @override
  String get conversationType => 'user';
  @override
  DateTime? get pinnedAt => null;
  @override
  final String? pinnedBy;
}

final _alice = FakeConversation();
final _bob = FakeConversation(
  conversationId: 'user_u2',
  with_: FakeUser(name: 'Bob', uid: 'u2'),
);

MockConversationsBloc _loaded({
  List<Conversation>? conversations,
  Set<String> selected = const {},
}) {
  final bloc = MockConversationsBloc();
  final state = ConversationsLoaded(
    conversations: conversations ?? [_alice, _bob],
    hasMore: false,
    selectedConversations: selected,
  );
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.fromIterable([state]), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    mockNetworkImagesFor(() async {
      await tester.pumpWidget(child);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

/// Long-press a row and let the context menu animate in.
Future<void> _openMenu(WidgetTester tester, [String on = 'Alice']) async {
  await tester.longPress(find.text(on));
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClearConversationSelection());
  });

  // =========================================================================
  group('the long-press context menu', () {
    testWidgets('with nothing to show, a long press opens no menu', (
      tester,
    ) async {
      // No custom options and delete hidden: the handler must bail before it
      // stores a menu, or the row would flash an empty popup.
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: false,
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('delete is offered when its visibility flag is on', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: true,
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('addOptions entries sit in front of the defaults', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: true,
            addOptions: (_, _, _) => [
              CometChatOption(id: 'x', title: 'Archive'),
            ],
          ),
        ),
      );
      await _openMenu(tester);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(labels, contains('Archive'));
      expect(labels.indexOf('Archive'), lessThan(labels.indexOf('Delete')));
    });

    testWidgets('setOptions replaces the defaults entirely', (tester) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: true,
            setOptions: (_, _, _) => [
              CometChatOption(id: 'x', title: 'Archive'),
            ],
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('a setOptions builder returning null opens no menu', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: false,
            setOptions: (_, _, _) => null,
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.byType(MenuAnchor), findsWidgets);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('choosing a custom option closes the menu and runs it', (
      tester,
    ) async {
      var clicks = 0;

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'x',
                title: 'Archive',
                onClick: () => clicks++,
              ),
            ],
          ),
        ),
      );
      await _openMenu(tester);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(clicks, 1);
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('an option with an iconWidget renders it in the menu', (
      tester,
    ) async {
      const probe = Key('opt-icon');

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'x',
                title: 'Archive',
                iconWidget: const Icon(Icons.archive, key: probe),
              ),
            ],
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.byKey(probe), findsOneWidget);
    });

    testWidgets('an option with an empty icon asset renders no glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(id: 'x', title: 'Archive', icon: ''),
            ],
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Archive'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });

    testWidgets('an option with an icon asset renders a tinted glyph', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'x',
                title: 'Archive',
                icon: AssetConstants.deleteIcon,
                iconTint: const Color(0xFF884422),
              ),
            ],
          ),
        ),
      );
      await _openMenu(tester);

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.byType(Image),
        ),
      );
      expect(image.color, const Color(0xFF884422));
      expect(image.width, 24);
      while (tester.takeException() != null) {}
    });

    testWidgets('a second long press on the same row closes the menu', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: true,
          ),
        ),
      );
      await _openMenu(tester);
      expect(find.text('Delete'), findsOneWidget);

      await _openMenu(tester);

      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('a tap while the menu is open dismisses it instead of opening '
        'the chat', (tester) async {
      Conversation? tapped;

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            deleteConversationOptionVisibility: true,
            onItemTap: (c) => tapped = c,
          ),
        ),
      );
      await _openMenu(tester);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(tapped, isNull, reason: 'the first tap only dismisses');
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(tapped?.conversationId, 'user_u1');
    });
  });

  // =========================================================================
  group('the pin entry', () {
    testWidgets('an unpinned conversation is offered Pin', (tester) async {
      await _pump(
        tester,
        _wrap(CometChatConversations(conversationsBloc: _loaded())),
      );
      await _openMenu(tester);

      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Unpin'), findsNothing);
    });

    testWidgets('a conversation I pinned is offered Unpin', (tester) async {
      CometChatUIKit.loggedInUser = User(uid: 'u-me', name: 'Me');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(
              conversations: [FakeConversation(pinnedBy: 'u-me')],
            ),
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Unpin'), findsOneWidget);
    });

    testWidgets('a conversation someone else pinned offers neither', (
      tester,
    ) async {
      // Only the pinner may unpin, so the entry is withheld rather than
      // offered and then rejected by the server.
      CometChatUIKit.loggedInUser = User(uid: 'u-me', name: 'Me');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(
              conversations: [FakeConversation(pinnedBy: 'someone-else')],
            ),
            deleteConversationOptionVisibility: true,
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Pin'), findsNothing);
      expect(find.text('Unpin'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('pinConversationOptionVisibility:false withholds the entry', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            pinConversationOptionVisibility: false,
            deleteConversationOptionVisibility: true,
          ),
        ),
      );
      await _openMenu(tester);

      expect(find.text('Pin'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping Pin closes the menu and reports the failure', (
      tester,
    ) async {
      // With no SDK the pin call fails; what must still happen is that the
      // menu closes and the user is told, rather than the row silently
      // appearing pinned.
      await _pump(
        tester,
        _wrap(CometChatConversations(conversationsBloc: _loaded())),
      );
      await _openMenu(tester);

      await tester.tap(find.text('Pin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      while (tester.takeException() != null) {}

      expect(find.text('Pin'), findsNothing);
      expect(
        find.textContaining("Couldn't update"),
        findsOneWidget,
        reason: 'the failure is surfaced, not swallowed',
      );

      // Let the toast's own dismissal timer run out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
    });

    testWidgets('a group conversation pins by its guid, not a uid', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(conversations: [_GroupConversation()]),
          ),
        ),
      );
      await _openMenu(tester, 'Dev Team');

      await tester.tap(find.text('Pin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      while (tester.takeException() != null) {}

      // Reaching the toast at all means the guid branch resolved a target;
      // an unresolved counterpart returns before the SDK call and says
      // nothing.
      expect(find.textContaining("Couldn't update"), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
    });

    testWidgets('tapping Unpin also closes the menu cleanly', (tester) async {
      CometChatUIKit.loggedInUser = User(uid: 'u-me', name: 'Me');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(
              conversations: [FakeConversation(pinnedBy: 'u-me')],
            ),
          ),
        ),
      );
      await _openMenu(tester);

      await tester.tap(find.text('Unpin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      while (tester.takeException() != null) {}

      expect(find.text('Unpin'), findsNothing);
      expect(find.textContaining("Couldn't update"), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
    });
  });

  // =========================================================================
  group('delete confirmation', () {
    Future<void> openDelete(WidgetTester tester, MockConversationsBloc bloc) =>
        mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: bloc,
                deleteConversationOptionVisibility: true,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.longPress(find.text('Alice'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          while (tester.takeException() != null) {}
        });

    testWidgets('choosing delete asks to confirm before dispatching', (
      tester,
    ) async {
      final bloc = _loaded();
      await openDelete(tester, bloc);

      expect(find.text('Delete this conversation?'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<DeleteConversation>())));
    });

    testWidgets('confirming dispatches DeleteConversation for that row', (
      tester,
    ) async {
      final bloc = _loaded();
      await openDelete(tester, bloc);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      final captured = verify(
        () => bloc.add(captureAny(that: isA<DeleteConversation>())),
      ).captured;
      expect((captured.single as DeleteConversation).conversationId, 'user_u1');
    });

    testWidgets('cancelling closes the dialog and dispatches nothing', (
      tester,
    ) async {
      final bloc = _loaded();
      await openDelete(tester, bloc);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      expect(find.text('Delete this conversation?'), findsNothing);
      verifyNever(() => bloc.add(any(that: isA<DeleteConversation>())));
    });
  });

  // =========================================================================
  group('selection chrome', () {
    testWidgets('with a selection the back arrow becomes a clear button', (
      tester,
    ) async {
      final bloc = _loaded(selected: const {'user_u1'});

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: bloc,
            showBackButton: true,
            selectionMode: SelectionMode.multiple,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      verify(
        () => bloc.add(any(that: isA<ClearConversationSelection>())),
      ).called(1);
    });

    testWidgets('with a selection the submit control reports the selected '
        'conversations', (tester) async {
      List<Conversation>? submitted;

      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(selected: const {'user_u2'}),
            selectionMode: SelectionMode.multiple,
            onSelection: (c) => submitted = c,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      expect(submitted?.map((c) => c.conversationId), ['user_u2']);
    });

    testWidgets('with no selection there is no submit control', (tester) async {
      await _pump(
        tester,
        _wrap(
          CometChatConversations(
            conversationsBloc: _loaded(),
            selectionMode: SelectionMode.multiple,
            onSelection: (_) {},
          ),
        ),
      );

      expect(find.byTooltip('Done'), findsNothing);
    });
  });

  // =========================================================================
  group('route visibility', () {
    testWidgets('a supplied routeObserver tracks pushes and pops', (
      tester,
    ) async {
      final observer = RouteObserver<ModalRoute<void>>();

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            navigatorObservers: [observer],
            home: Scaffold(
              body: CometChatConversations(
                conversationsBloc: _loaded(),
                routeObserver: observer,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final state = tester.state(find.byType(CometChatConversations));
      expect(state, isA<RouteAware>());
      expect(find.text('Alice'), findsOneWidget);

      // Cover the route, then uncover it. The widget has to survive both
      // transitions and come back rendering its list.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('COVER')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('COVER'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('popping the observed route itself is handled', (tester) async {
      final observer = RouteObserver<ModalRoute<void>>();

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: CometChatConversations(
                          conversationsBloc: _loaded(),
                          routeObserver: observer,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
      });

      expect(find.text('Alice'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      expect(find.text('go'), findsOneWidget);
      expect(find.byType(CometChatConversations), findsNothing);
    });

    testWidgets('without a routeObserver the list still renders', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(CometChatConversations(conversationsBloc: _loaded())),
      );

      expect(find.text('Alice'), findsOneWidget);
    });
  });
}

/// A group-backed conversation, so the pin handler takes its `guid` branch.
class _GroupConversation extends Fake implements Conversation {
  @override
  String get conversationId => 'group_g1';
  @override
  AppEntity get conversationWith =>
      Group(guid: 'g1', name: 'Dev Team', type: 'public');
  @override
  int get unreadMessageCount => 0;
  @override
  BaseMessage? get lastMessage => null;
  @override
  String get conversationType => 'group';
  @override
  DateTime? get pinnedAt => null;
  @override
  String? get pinnedBy => null;
}
