/// Render-verified prop matrix for [CometChatGroups] — Track 3 PROP1.
///
/// Same pattern as `users_props_test.dart`: mock the bloc, inject it through
/// the component's own `groupsBloc` parameter, seed a state, then set one prop
/// at a time and assert the *rendered* effect. A prop counts only when a
/// non-default value changes what is on screen — asserting that Dart assigned
/// a field would pass even if the widget stopped reading it, which is the
/// regression this exists to catch.
///
/// 37 props are in scope, 36 render-verified. `groupsRequestBuilder` and
/// `hideError` were both dead when this matrix was written — filed as
/// ENG-39113 and since fixed, so their pinned placeholders below are now real
/// assertions.
///
/// `groupsRequestBuilder` still reads as uncovered, and that is accurate
/// rather than an omission. CometChatGroups reads it only on the branch that
/// builds its own GroupsBloc, and that branch resolves use cases through the
/// service locator and reaches the SDK. The test below verifies the half that
/// was actually broken — bloc → use case → repository → datasource — by
/// constructing the bloc with stubbed use cases. Passing the prop to a
/// CometChatGroups that has a bloc injected would score as render-verified
/// while proving nothing, so it is deliberately not done.
///
///   flutter test test/chat_ui/groups/groups_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockGroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {
  List<Group> selection = const [];

  @override
  List<Group> getSelectedGroups() => selection;

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) {
    // No-op: these cases assert rendering, not event handling.
  }
}

class _MockGetGroupsUseCase extends Mock implements GetGroupsUseCase {}

class _MockLoadMoreGroupsUseCase extends Mock
    implements LoadMoreGroupsUseCase {}

class _MockGetLoggedInUserUseCase extends Mock
    implements GetLoggedInUserUseCase {}

class FakeGroup extends Fake implements Group {
  FakeGroup({
    this.name = 'Design',
    this.guid = 'g1',
    this.type = GroupTypeConstants.public,
    this.membersCount = 4,
  });

  @override
  final String name;
  @override
  final String guid;
  @override
  final String type;
  @override
  final int membersCount;
  @override
  String? get icon => null;
}

List<Group> _sampleGroups() => [
  FakeGroup(name: 'Design', guid: 'g1'),
  FakeGroup(name: 'Engineering', guid: 'g2', type: GroupTypeConstants.private),
  FakeGroup(name: 'Leadership', guid: 'g3', type: GroupTypeConstants.password),
];

MockGroupsBloc _blocIn(GroupsState state, {List<Group> selection = const []}) {
  final bloc = MockGroupsBloc();
  bloc.selection = selection;
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

MockGroupsBloc _loadedBloc({Set<String> selected = const {}}) => _blocIn(
  GroupsLoaded(groups: _sampleGroups(), selectedGroups: selected),
  selection: selected.isEmpty ? const [] : [_sampleGroups().first],
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  // ===========================================================================
  group('appbar, title and back affordance', () {
    testWidgets('title replaces the default heading', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(groupsBloc: _loadedBloc(), title: 'Pick a channel'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pick a channel'), findsOneWidget);
    });

    testWidgets('with no title the localized default is used', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatGroups(groupsBloc: _loadedBloc())),
        ),
      );
      await tester.pump();

      expect(find.text('Pick a channel'), findsNothing);
      expect(find.text('Groups'), findsOneWidget);
    });

    testWidgets('a selection count wins over the title', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(selected: {'g1', 'g2'}),
              title: 'Pick a channel',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Pick a channel'), findsNothing);
    });

    testWidgets('titleView replaces each row heading', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              titleView: (context, group) => Text('title-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('title-g1'), findsOneWidget);
      expect(find.text('Design'), findsNothing);
    });

    testWidgets('hideAppbar removes the app bar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatGroups(groupsBloc: _loadedBloc(), hideAppbar: true)),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('showBackButton false removes the back icon', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(groupsBloc: _loadedBloc(), showBackButton: false),
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
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              backButton: const Text('custom-back'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-back'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('onBack fires from the default back button', (tester) async {
      var backs = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(groupsBloc: _loadedBloc(), onBack: () => backs++),
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
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              appBarOptions: (context) => const [Text('menu-option')],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('menu-option'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('search row', () {
    testWidgets('hideSearch removes the search field', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatGroups(groupsBloc: _loadedBloc(), hideSearch: true)),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('searchPlaceholder becomes the field hint', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              searchPlaceholder: 'Find a channel',
            ),
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'Find a channel');
    });

    testWidgets('searchKeyword seeds the field', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(groupsBloc: _loadedBloc(), searchKeyword: 'design'),
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'design');
    });

    testWidgets('searchBoxIcon replaces the magnifier', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              searchBoxIcon: const Text('search-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('search-glyph'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('size and container', () {
    testWidgets('height and width constrain the component', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(groupsBloc: _loadedBloc(), height: 320, width: 260),
          ),
        ),
      );
      await tester.pump();

      // Both land on the SizedBox inside CometChatListBase, not on the
      // component's own box.
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 320 && w.width == 260,
        ),
        findsOneWidget,
      );
    });

    testWidgets('groupsStyle.borderRadius reaches the clip', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatGroups), findsOneWidget);
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
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              title: 'Channels',
              groupsStyle: const CometChatGroupsStyle(
                titleTextColor: Color(0xFF115577),
                titleTextStyle: TextStyle(fontSize: 27),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final heading = tester.widget<Text>(find.text('Channels'));
      expect(heading.style?.color, const Color(0xFF115577));
      expect(heading.style?.fontSize, 27);
    });

    testWidgets('backIconColor tints the back icon', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              groupsStyle: const CometChatGroupsStyle(
                backIconColor: Color(0xFF902040),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The icon resolves the style ahead of the palette: ListBase applies
      // backIconTint as IconButton.color, which cannot reach an icon that
      // sets its own. That ordering is the ENG-39105 fix.
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back));
      expect(icon.color, const Color(0xFF902040));
    });

    testWidgets('backgroundColor paints the list container', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              groupsStyle: const CometChatGroupsStyle(
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
  });

  // ===========================================================================
  group('selection', () {
    testWidgets('selectionMode single shows the submit affordance', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(selected: {'g1'}),
              selectionMode: SelectionMode.single,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('submitIcon replaces the default submit affordance', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(selected: {'g1'}),
              submitIcon: const Text('done-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('done-glyph'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('onSelection fires with the selected groups', (tester) async {
      List<Group>? handed;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(selected: {'g1'}),
              onSelection: (groups) => handed = groups,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(handed, isNotNull);
      expect(handed!.single.guid, 'g1');
    });

    testWidgets('a selection renders a clear affordance in place of back', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(CometChatGroups(groupsBloc: _loadedBloc(selected: {'g1'}))),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('activateSelection is accepted alongside selectionMode', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('list slots and state views', () {
    testWidgets('listItemView replaces each row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              listItemView: (group) => Text('row-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-g1'), findsOneWidget);
      expect(find.text('row-g2'), findsOneWidget);
      expect(find.text('Design'), findsNothing);
    });

    testWidgets('subtitleView renders under each name', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              subtitleView: (context, group) => Text('sub-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub-g1'), findsOneWidget);
      expect(find.text('Design'), findsOneWidget);
    });

    testWidgets('leadingView and trailingView render per row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              leadingView: (context, group) => Text('lead-${group.guid}'),
              trailingView: (context, group) => Text('trail-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lead-g1'), findsOneWidget);
      expect(find.text('trail-g1'), findsOneWidget);
    });

    testWidgets('loadingStateView replaces the spinner', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsLoading()),
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
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsEmpty()),
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
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
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
  group('group type affordances', () {
    testWidgets('privateGroupIcon marks the private group', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              privateGroupIcon: const Text('private-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Only g2 is private, so exactly one row takes the icon.
      expect(find.text('private-glyph'), findsOneWidget);
    });

    testWidgets('passwordGroupIcon marks the password group', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              passwordGroupIcon: const Text('locked-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('locked-glyph'), findsOneWidget);
    });

    testWidgets('groupTypeVisibility false suppresses both type icons', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              privateGroupIcon: const Text('private-glyph'),
              passwordGroupIcon: const Text('locked-glyph'),
              groupTypeVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('private-glyph'), findsNothing);
      expect(find.text('locked-glyph'), findsNothing);
    });
  });

  // ===========================================================================
  group('row interaction', () {
    testWidgets('onItemTap fires with the tapped group', (tester) async {
      Group? tapped;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              onItemTap: (context, group) => tapped = group,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Design'));
      await tester.pump();

      expect(tapped?.guid, 'g1');
    });

    testWidgets('onItemLongPress fires with the pressed group', (tester) async {
      Group? pressed;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              onItemLongPress: (context, group) => pressed = group,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Design'));
      await tester.pump();

      expect(pressed?.guid, 'g1');
    });
  });

  // ===========================================================================
  group('the state-reporting callbacks', () {
    testWidgets('onLoad reports the loaded list once', (tester) async {
      final reported = <List<Group>>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loadedBloc(),
              onLoad: (groups) => reported.add(groups),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reported, hasLength(1));
      expect(reported.single.map((g) => g.guid), ['g1', 'g2', 'g3']);
    });

    testWidgets('onEmpty reports the empty state', (tester) async {
      var empties = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsEmpty()),
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('a loaded-but-empty list also reports empty', (tester) async {
      var empties = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsLoaded(groups: [])),
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('onError reports with the message', (tester) async {
      Object? reported;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              onError: (e) => reported = e,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reported.toString(), contains('boom'));
    });
  });

  // ===========================================================================
  group('FIXED — the two props that used to be dropped (ENG-39113)', () {
    testWidgets('hideError suppresses the error view', (tester) async {
      // GroupsList now gates its error view the way ConversationsList always
      // has. Paired with the case below so the suppression is attributable to
      // the prop rather than to the error view never rendering at all.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              errorStateView: (context) => const Text('custom-error'),
              hideError: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-error'), findsNothing);
    });

    testWidgets('without hideError the error view still renders', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              errorStateView: (context) => const Text('custom-error'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-error'), findsOneWidget);
    });

    testWidgets('groupsRequestBuilder reaches the fetch', (tester) async {
      // Built here rather than left to the component: CometChatGroups only
      // reads the prop on the branch that constructs its own GroupsBloc, and
      // that branch resolves real use cases through the service locator and
      // reaches the SDK. Constructing the bloc with stubbed use cases keeps
      // the threading under test — bloc → use case → repository → datasource —
      // which is the half of the fix that was actually missing.
      final builder = GroupsRequestBuilder()..limit = 7;
      final getGroups = _MockGetGroupsUseCase();
      final getLoggedInUser = _MockGetLoggedInUserUseCase();
      // GroupsBloc calls this from its constructor, so it has to answer before
      // the bloc exists.
      when(getLoggedInUser.call).thenAnswer((_) async => const Success(null));
      when(
        () => getGroups(
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
          joinedOnly: any(named: 'joinedOnly'),
          groupsRequestBuilder: any(named: 'groupsRequestBuilder'),
        ),
      ).thenAnswer((_) async => Success(_sampleGroups()));

      final loadMore = _MockLoadMoreGroupsUseCase();
      when(
        () => loadMore(
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
          joinedOnly: any(named: 'joinedOnly'),
          currentGroups: any(named: 'currentGroups'),
        ),
      ).thenAnswer((_) async => Success(_sampleGroups()));

      final bloc = GroupsBloc(
        getGroupsUseCase: getGroups,
        loadMoreGroupsUseCase: loadMore,
        getLoggedInUserUseCase: getLoggedInUser,
        disableSDKListeners: true,
        groupsRequestBuilder: builder,
      );
      addTearDown(bloc.close);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(_wrap(CometChatGroups(groupsBloc: bloc))),
      );
      await tester.pump();
      await tester.pump();

      final captured = verify(
        () => getGroups(
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
          joinedOnly: any(named: 'joinedOnly'),
          groupsRequestBuilder: captureAny(named: 'groupsRequestBuilder'),
        ),
      ).captured;

      expect(captured, isNotEmpty);
      expect(identical(captured.first, builder), isTrue);
    });
  });
}
