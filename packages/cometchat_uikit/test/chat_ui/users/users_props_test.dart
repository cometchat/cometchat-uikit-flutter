/// Render-verified prop matrix for [CometChatUsers] — Track 3 PROP1
/// (ENG-38919).
///
/// Built on the pattern `conversations_props_test.dart` establishes and that
/// PROP2 names as the correct one: mock the bloc, inject it through the
/// component's own `usersBloc` parameter, seed a loaded state, then set one
/// prop at a time and assert the *rendered* effect. A prop counts only when a
/// non-default value changes what is on screen — asserting that Dart assigned
/// a field would pass even if the widget stopped reading it, which is the
/// regression this exists to catch.
///
/// 35 props are in scope. Three of them — `onLoad`, `onEmpty` and `onError` —
/// cannot be covered: they are declared, never read, and never forwarded to
/// `UsersList`, which has no parameter to receive them. They are pinned below
/// as DEFECT and filed on ENG-39104. The matrix therefore caps at 32/35 until
/// that lands.
///
///   flutter test test/chat_ui/users/users_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  /// UsersList reads a per-user notifier for the presence dot, so the mock has
  /// to supply real ones — MockBloc would otherwise return null into a
  /// non-nullable ValueNotifier and every row would throw while building.
  final _statusNotifiers = <String, ValueNotifier<String>>{};

  @override
  ValueNotifier<String> getStatusNotifier(String uid) =>
      _statusNotifiers.putIfAbsent(uid, () => ValueNotifier<String>('online'));

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {
    // No-op: these cases assert rendering, not event handling.
  }
}

class FakeUser extends Fake implements User {
  FakeUser({this.name = 'Alice', this.uid = 'u1', this.status = 'online'});

  @override
  final String name;
  @override
  final String uid;
  @override
  final String status;
  @override
  String? get avatar => null;
  @override
  String? get role => 'default';
  @override
  String? get link => null;
  @override
  bool? get blockedByMe => false;
  @override
  bool? get hasBlockedMe => false;
  @override
  DateTime? get lastActiveAt => null;
}

List<User> _sampleUsers() => [
  FakeUser(name: 'Alice', uid: 'u1'),
  FakeUser(name: 'Bob', uid: 'u2', status: 'offline'),
  FakeUser(name: 'Carla', uid: 'u3'),
];

MockUsersBloc _blocIn(UsersState state) {
  final bloc = MockUsersBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

MockUsersBloc _loadedBloc({Set<String> selected = const {}}) =>
    _blocIn(UsersLoaded(users: _sampleUsers(), selectedUsers: selected));

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

void main() {
  // ===========================================================================
  group('appbar, title and back affordance', () {
    testWidgets('title replaces the default heading', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              title: 'Choose a colleague',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Choose a colleague'), findsOneWidget);
    });

    testWidgets('with no title the localized default is used', (tester) async {
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatUsers(usersBloc: _loadedBloc()))),
      );
      await tester.pump();

      expect(find.text('Choose a colleague'), findsNothing);
      expect(_texts(tester).contains('Users'), isTrue);
    });

    testWidgets('a selection count wins over the title', (tester) async {
      // The heading is shared between the title and the selection counter, so
      // this is the branch that decides which one an integrator sees.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(selected: {'u1', 'u2'}),
              title: 'Choose a colleague',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Choose a colleague'), findsNothing);
    });

    testWidgets('titleView replaces the whole heading widget', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              titleView: (context, user) => const Text('custom-title-view'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatUsers), findsOneWidget);
    });

    testWidgets('hideAppbar removes the app bar', (tester) async {
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatUsers(usersBloc: _loadedBloc()))),
      );
      await tester.pump();
      final withBar = find.byType(AppBar).evaluate().length;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatUsers(usersBloc: _loadedBloc(), hideAppbar: true)),
        ),
      );
      await tester.pump();

      expect(withBar, greaterThan(0));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('showBackButton false removes the back icon', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatUsers(usersBloc: _loadedBloc(), showBackButton: true)),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(usersBloc: _loadedBloc(), showBackButton: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('backButton replaces the default back icon', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              showBackButton: true,
              backButton: const Icon(Icons.close),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('onBack fires from the default back button', (tester) async {
      var backs = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              showBackButton: true,
              onBack: () => backs++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('appBarOptions adds menu widgets', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              appBarOptions: (context) => const [Icon(Icons.filter_alt)],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    });
  });

  // ===========================================================================
  group('search row', () {
    testWidgets('hideSearch removes the search field', (tester) async {
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatUsers(usersBloc: _loadedBloc()))),
      );
      await tester.pump();
      expect(find.byType(TextField), findsWidgets);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatUsers(usersBloc: _loadedBloc(), hideSearch: true)),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('searchPlaceholder becomes the field hint', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              searchPlaceholder: 'Find someone',
            ),
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration?.hintText, 'Find someone');
    });

    testWidgets('searchKeyword seeds the field', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatUsers(usersBloc: _loadedBloc(), searchKeyword: 'ali')),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'ali');
    });

    testWidgets('searchBoxIcon replaces the magnifier', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              searchBoxIcon: const Icon(Icons.travel_explore),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.travel_explore), findsOneWidget);
    });
  });

  // ===========================================================================
  group('size and container', () {
    testWidgets('height and width constrain the component', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(usersBloc: _loadedBloc(), height: 300, width: 250),
          ),
        ),
      );
      await tester.pump();

      // Both land on the SizedBox inside CometChatListBase, not on the
      // component's own box.
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 300 && w.width == 250,
        ),
        findsOneWidget,
      );
    });

    testWidgets('usersStyle.borderRadius reaches the clip', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              usersStyle: const CometChatUsersStyle(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
      expect(clip.borderRadius, const BorderRadius.all(Radius.circular(18)));
    });

    testWidgets('scrollController is accepted and attaches', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatUsers), findsOneWidget);
    });
  });

  // ===========================================================================
  group('style — the props that reach the heading and the search row', () {
    testWidgets('titleTextColor and titleTextStyle apply to the heading', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              title: 'Directory',
              usersStyle: const CometChatUsersStyle(
                titleTextColor: Color(0xFF0C5F66),
                titleTextStyle: TextStyle(fontSize: 27),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final heading = tester.widget<Text>(find.text('Directory'));
      expect(heading.style?.color, const Color(0xFF0C5F66));
      expect(heading.style?.fontSize, 27);
    });

    testWidgets('FIXED — backIconColor tints the back icon', (tester) async {
      // Was inert: CometChatListBase applies backIconTint as the IconButton's
      // `color`, which only reaches an icon that sets none of its own, and
      // CometChatUsers handed it a pre-built icon carrying an explicit palette
      // colour. _buildBackIcon now resolves the style first. ENG-39105.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              showBackButton: true,
              usersStyle: const CometChatUsersStyle(
                backIconColor: Color(0xFFA3382B),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
        const Color(0xFFA3382B),
      );
    });

    testWidgets('backgroundColor paints the list container', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              usersStyle: const CometChatUsersStyle(
                backgroundColor: Color(0xFFEDF2F2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // It reaches Scaffold.backgroundColor inside CometChatListBase.
      final scaffolds = tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .map((s) => s.backgroundColor);
      expect(scaffolds, contains(const Color(0xFFEDF2F2)));
    });

    testWidgets('search styling reaches the field', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              searchPlaceholder: 'Find someone',
              usersStyle: const CometChatUsersStyle(
                searchInputTextColor: Color(0xFF121A1C),
                searchInputTextStyle: TextStyle(fontSize: 19),
                searchPlaceHolderTextColor: Color(0xFF7A898F),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.style?.color, const Color(0xFF121A1C));
      expect(field.style?.fontSize, 19);
      expect(field.decoration?.hintStyle?.color, const Color(0xFF7A898F));
    });

    testWidgets('a style set on the theme is picked up without the prop', (
      tester,
    ) async {
      // CometChatUsersStyle is a ThemeExtension, so an integrator may set it
      // globally instead of per-component. Both routes must work, and the prop
      // must win where both are present.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: ThemeData(
              extensions: const [
                CometChatUsersStyle(titleTextColor: Color(0xFF1C7549)),
              ],
            ),
            home: Scaffold(
              body: CometChatUsers(usersBloc: _loadedBloc(), title: 'Themed'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Themed')).style?.color,
        const Color(0xFF1C7549),
      );
    });
  });

  // ===========================================================================
  group('selection', () {
    testWidgets('selectionMode single shows the submit affordance', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(selected: {'u1'}),
              selectionMode: SelectionMode.single,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatUsers), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('submitIcon replaces the default submit affordance', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(selected: {'u1'}),
              selectionMode: SelectionMode.multiple,
              submitIcon: const Icon(Icons.done_all),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('a selection renders a clear affordance in place of back', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(selected: {'u1'}),
              showBackButton: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('activateSelection and onSelection are accepted together', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              activateSelection: ActivateSelection.onClick,
              selectionMode: SelectionMode.multiple,
              onSelection: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatUsers), findsOneWidget);
    });
  });

  // ===========================================================================
  group('list slots and state views', () {
    testWidgets('listItemView replaces each row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              listItemView: (user) => Text('row-${user.uid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-u1'), findsOneWidget);
      expect(find.text('row-u2'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('subtitleView renders under each name', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              subtitleView: (context, user) => Text('sub-${user.uid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub-u1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('leadingView and trailingView render per row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              leadingView: (context, user) => Text('lead-${user.uid}'),
              trailingView: (context, user) => Text('trail-${user.uid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lead-u1'), findsOneWidget);
      expect(find.text('trail-u1'), findsOneWidget);
    });

    testWidgets('usersStatusVisibility false hides the presence dot', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatUsers(usersBloc: _loadedBloc()))),
      );
      await tester.pump();
      final withStatus = find
          .byType(CometChatStatusIndicator)
          .evaluate()
          .length;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              usersStatusVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(withStatus, greaterThan(0));
      expect(find.byType(CometChatStatusIndicator), findsNothing);
    });

    testWidgets('stickyHeaderVisibility swaps the inline initial dividers out', (
      tester,
    ) async {
      // Reads the other way round than the name suggests: the inline
      // per-initial divider renders only when stickyHeaderVisibility is *not*
      // true, because a sticky header replaces it. Sample users are Alice, Bob
      // and Carla, so each row starts a new initial.
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatUsers(usersBloc: _loadedBloc()))),
      );
      await tester.pump();
      expect(_texts(tester).contains('A'), isTrue);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              stickyHeaderVisibility: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_texts(tester).contains('A'), isFalse);
    });

    testWidgets('loadingStateView replaces the spinner', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersLoading()),
              loadingStateView: (context) => const Text('custom-loading'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-loading'), findsOneWidget);
    });

    testWidgets('emptyStateView replaces the empty state', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersEmpty()),
              emptyStateView: (context) => const Text('custom-empty'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-empty'), findsOneWidget);
    });

    testWidgets('errorStateView replaces the error state', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersError(message: 'boom')),
              errorStateView: (context) => const Text('custom-error'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-error'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('row interaction', () {
    testWidgets('onItemTap fires with the tapped user', (tester) async {
      User? tapped;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              onItemTap: (context, user) => tapped = user,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pump();
      expect(tapped?.uid, 'u1');
    });

    testWidgets('onItemLongPress fires with the pressed user', (tester) async {
      User? pressed;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              onItemLongPress: (context, user) => pressed = user,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Bob'));
      await tester.pump();
      expect(pressed?.uid, 'u2');
    });
  });

  // ===========================================================================
  group('the state-reporting callbacks', () {
    testWidgets('FIXED — onLoad reports the loaded list once', (tester) async {
      // Was dead: declared, read nowhere, and not forwarded to UsersList,
      // which had no parameter to receive it. ENG-39104.
      List<User>? loaded;
      var calls = 0;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loadedBloc(),
              onLoad: (users) {
                loaded = users;
                calls++;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(calls, 1);
      expect(loaded?.map((u) => u.uid), ['u1', 'u2', 'u3']);
    });

    testWidgets('FIXED — onEmpty reports the empty state', (tester) async {
      var empties = 0;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersEmpty()),
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('FIXED — a loaded-but-empty list also reports empty', (
      tester,
    ) async {
      // UsersLoaded with no users is the same thing to a caller as UsersEmpty,
      // and the bloc can produce either, so both routes report.
      var empties = 0;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersLoaded(users: [], hasMore: false)),
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('FIXED — onError reports with the message', (tester) async {
      Exception? seen;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersError(message: 'boom')),
              onError: (e) => seen = e,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(seen.toString(), contains('boom'));
    });

    testWidgets('reports once per transition, not once per rebuild', (
      tester,
    ) async {
      // The guard is keyed on the state's runtime type: a loaded state that
      // gains a user is still loaded, and re-reporting would turn onLoad into
      // a per-frame callback.
      var calls = 0;
      final widget = CometChatUsers(
        usersBloc: _loadedBloc(),
        onLoad: (_) => calls++,
      );

      await mockNetworkImagesFor(() => tester.pumpWidget(_wrap(widget)));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(calls, 1);
    });
  });
}
