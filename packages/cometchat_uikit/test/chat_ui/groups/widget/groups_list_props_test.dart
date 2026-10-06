/// Render-verified prop matrix for [GroupsList] — Track 3 PROP1 (ENG-38688,
/// coverage part 2).
///
/// Built on the pattern `conversations_props_test.dart` sets and
/// `users_props_test.dart` follows: a MockBloc stands in for [GroupsBloc],
/// is injected through the list's own `groupsBloc` parameter and seeded with
/// one state; each case then sets one prop to a sentinel and asserts on what
/// the list renders, or on the event it dispatches back to the bloc. Every
/// assertion fails if the list stopped reading the prop.
///
/// GroupsList is the body of CometChatGroups, so the rows it renders are
/// CometChatGroupListItems; the item-level cases assert at the same render
/// sites `group_list_item_props_test.dart` uses.
///
///   flutter test test/chat_ui/groups/widget/groups_list_props_test.dart
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
  /// Every event the list dispatches, in order. The retry, pagination and
  /// selection cases assert on this.
  final List<GroupsEvent> events = [];

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) => events.add(event);
}

class FakeGroup extends Fake implements Group {
  FakeGroup({
    required this.name,
    required this.guid,
    this.type = CometChatGroupType.public,
    this.membersCount = 5,
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

/// One group of each type, so the badge cases have a private row (Bravo) and
/// a password row (Charlie) next to a public one (Alpha).
List<Group> _sampleGroups() => [
  FakeGroup(name: 'Alpha Guild', guid: 'g1', membersCount: 3),
  FakeGroup(
    name: 'Bravo Den',
    guid: 'g2',
    type: CometChatGroupType.private,
    membersCount: 1,
  ),
  FakeGroup(
    name: 'Charlie Vault',
    guid: 'g3',
    type: CometChatGroupType.password,
    membersCount: 12,
  ),
];

MockGroupsBloc _blocIn(GroupsState state) {
  final bloc = MockGroupsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

MockGroupsBloc _loadedBloc({
  List<Group>? groups,
  Set<String> selected = const {},
  bool hasMore = false,
}) => _blocIn(
  GroupsLoaded(
    groups: groups ?? _sampleGroups(),
    hasMore: hasMore,
    selectedGroups: selected,
  ),
);

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

Translations _l10n(WidgetTester tester) =>
    Translations.of(tester.element(find.byType(GroupsList)));

Finder _rowOf(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(CometChatGroupListItem),
);

Finder _rowBoxOf(String name) => find.descendant(
  of: _rowOf(name),
  matching: find.byWidgetPredicate((w) => w is Container && w.child is Row),
);

InkWell _inkWellOf(WidgetTester tester, String name) => tester.widget<InkWell>(
  find.descendant(of: _rowOf(name), matching: find.byType(InkWell)).first,
);

BoxDecoration _badgeOf(WidgetTester tester, String name) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.descendant(
                      of: _rowOf(name),
                      matching: find.byType(CometChatStatusIndicator),
                    ),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Checkbox _checkboxOf(WidgetTester tester, String name) =>
    tester.widget<Checkbox>(
      find.descendant(of: _rowOf(name), matching: find.byType(Checkbox)),
    );

Iterable<Color?> _avatarFills(WidgetTester tester) => find
    .byType(CometChatAvatar)
    .evaluate()
    .map(
      (e) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byWidget(e.widget),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color,
    );

void main() {
  // ===========================================================================
  group('GroupsList', () {
    testWidgets('groupsBloc: its loaded state is what renders, and it gets '
        'the pagination request', (tester) async {
      final bloc = _loadedBloc(hasMore: true);
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: bloc,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alpha Guild'), findsOneWidget);
      expect(find.text('Bravo Den'), findsOneWidget);
      expect(find.text('Charlie Vault'), findsOneWidget);
      // hasMore adds a loader row, and building it asks this bloc for more.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(bloc.events, contains(const LoadMoreGroups()));
    });

    testWidgets('groupsBloc: the default error view retries through it', (
      tester,
    ) async {
      final bloc = _blocIn(const GroupsError(message: 'boom'));
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: bloc,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(bloc.events, isEmpty);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(bloc.events, [const RefreshGroups()]);
    });

    testWidgets('style: the item fields reach every row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(selected: {'g2'}),
              selectionMode: SelectionMode.multiple,
              style: const CometChatGroupsStyle(
                itemTitleTextColor: Color(0xFF3D1F5A),
                itemTitleTextStyle: TextStyle(fontSize: 22.5),
                itemSubtitleTextColor: Color(0xFF5A3D1F),
                itemSubtitleTextStyle: TextStyle(fontSize: 11.5),
                listItemSelectedBackgroundColor: Color(0xFF1F5A3D),
                checkBoxBackgroundColor: Color(0xFF3D5A1F),
                checkBoxCheckedBackgroundColor: Color(0xFF5A1F3D),
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(6.5)),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Alpha Guild'));
      expect(title.style?.color, const Color(0xFF3D1F5A));
      expect(title.style?.fontSize, 22.5);

      final subtitle = tester.widget<Text>(
        find.text('3 ${_l10n(tester).members}'),
      );
      expect(subtitle.style?.color, const Color(0xFF5A3D1F));
      expect(subtitle.style?.fontSize, 11.5);

      expect(
        tester.widget<Container>(_rowBoxOf('Bravo Den')).color,
        const Color(0xFF1F5A3D),
      );
      expect(
        tester.widget<Container>(_rowBoxOf('Alpha Guild')).color,
        isNot(const Color(0xFF1F5A3D)),
      );

      expect(
        _checkboxOf(
          tester,
          'Bravo Den',
        ).fillColor!.resolve({WidgetState.selected}),
        const Color(0xFF5A1F3D),
      );
      expect(
        _checkboxOf(tester, 'Alpha Guild').fillColor!.resolve(<WidgetState>{}),
        const Color(0xFF3D5A1F),
      );
      expect(
        (_checkboxOf(tester, 'Alpha Guild').shape! as RoundedRectangleBorder)
            .borderRadius,
        const BorderRadius.all(Radius.circular(6.5)),
      );
    });

    testWidgets('style: the empty-state fields reach the default empty view', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsEmpty()),
              style: const CometChatGroupsStyle(
                emptyStateTextColor: Color(0xFF2E4A66),
                emptyStateTextStyle: TextStyle(fontSize: 25.5),
                emptyStateSubTitleTextColor: Color(0xFF4A662E),
                emptyStateSubTitleTextStyle: TextStyle(fontSize: 15.25),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      final heading = tester.widget<Text>(
        find.text(_l10n(tester).noGroupsFound),
      );
      expect(heading.style?.color, const Color(0xFF2E4A66));
      expect(heading.style?.fontSize, 25.5);

      final subtitle = tester.widget<Text>(
        find.textContaining('Create or join groups'),
      );
      expect(subtitle.style?.color, const Color(0xFF4A662E));
      expect(subtitle.style?.fontSize, 15.25);
    });

    testWidgets('style: the error-state fields reach the default error view', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              style: const CometChatGroupsStyle(
                errorStateTextColor: Color(0xFF664A2E),
                errorStateTextStyle: TextStyle(fontSize: 26.5),
                errorStateSubTitleTextColor: Color(0xFF2E664A),
                errorStateSubTitleTextStyle: TextStyle(fontSize: 13.75),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      final heading = tester.widget<Text>(find.text(_l10n(tester).oops));
      expect(heading.style?.color, const Color(0xFF664A2E));
      expect(heading.style?.fontSize, 26.5);

      final subtitle = tester.widget<Text>(
        find.textContaining(_l10n(tester).looksLikeSomethingWrong),
      );
      expect(subtitle.style?.color, const Color(0xFF2E664A));
      expect(subtitle.style?.fontSize, 13.75);
    });

    testWidgets('colorPalette: reaches the rows, the badges and the '
        'pagination loader', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(hasMore: true),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(
                primary: const Color(0xFF0B1C2D),
                warning: const Color(0xFF2D1C0B),
                success: const Color(0xFF1C2D0B),
                background1: const Color(0xFF0B2D1C),
              ),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        const Color(0xFF0B1C2D),
      );
      expect(_badgeOf(tester, 'Bravo Den').color, const Color(0xFF2D1C0B));
      expect(_badgeOf(tester, 'Charlie Vault').color, const Color(0xFF1C2D0B));
      expect(
        tester.widget<Container>(_rowBoxOf('Alpha Guild')).color,
        const Color(0xFF0B2D1C),
      );
    });

    testWidgets('spacing: pads the rows and the pagination loader', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(hasMore: true),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(padding3: 11, padding4: 23),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();

      final row = _rowBoxOf('Alpha Guild');
      final content = find
          .descendant(of: row, matching: find.byType(Row))
          .first;
      expect(
        tester.getTopLeft(content) - tester.getTopLeft(row),
        const Offset(23, 11),
      );
      expect(
        tester
            .widget<Padding>(
              find
                  .ancestor(
                    of: find.byType(CircularProgressIndicator),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding,
        const EdgeInsets.all(23),
      );
    });

    testWidgets('typography: sizes each row title and member count', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(
                heading4: CometChatTextStyleHeading4(
                  medium: TextStyle(fontSize: 24.5),
                ),
                body: CometChatTextStyleBody(
                  regular: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Alpha Guild')).style?.fontSize,
        24.5,
      );
      expect(
        tester
            .widget<Text>(find.text('12 ${_l10n(tester).members}'))
            .style
            ?.fontSize,
        12.5,
      );
    });

    testWidgets('scrollController: attaches to the list and follows it', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final many = [
        for (var i = 0; i < 30; i++) FakeGroup(name: 'Group $i', guid: 'g$i'),
      ];

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(groups: many),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.hasClients, isTrue);
      expect(controller.offset, 0);
      expect(find.text('Group 29'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(controller.offset, greaterThan(0));

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(find.text('Group 29'), findsOneWidget);
    });

    testWidgets('loadingStateView: replaces the shimmer while loading and '
        'before the first load', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsLoading()),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatShimmerEffect), findsOneWidget);

      for (final state in const <GroupsState>[
        GroupsLoading(),
        GroupsInitial(),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              GroupsList(
                groupsBloc: _blocIn(state),
                style: const CometChatGroupsStyle(),
                colorPalette: CometChatColorPalette(),
                spacing: CometChatSpacing(),
                typography: const CometChatTypography(),
                loadingStateView: (context) => const Text('custom-loading'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('custom-loading'), findsOneWidget, reason: '$state');
        expect(find.byType(CometChatShimmerEffect), findsNothing);
      }
    });

    testWidgets('emptyStateView: replaces the default empty view', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsEmpty()),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      final noGroups = _l10n(tester).noGroupsFound;
      expect(find.text(noGroups), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsEmpty()),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              emptyStateView: (context) => const Text('custom-empty'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-empty'), findsOneWidget);
      expect(find.text(noGroups), findsNothing);
    });

    testWidgets('errorStateView: replaces the default error view', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ElevatedButton), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              errorStateView: (context) => const Text('custom-error'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-error'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('listItemView: replaces each row and receives its group', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              listItemView: (group) => Text('row-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-g1'), findsOneWidget);
      expect(find.text('row-g2'), findsOneWidget);
      expect(find.text('row-g3'), findsOneWidget);
      expect(find.byType(CometChatGroupListItem), findsNothing);
      expect(find.text('Alpha Guild'), findsNothing);
    });

    testWidgets('subtitleView: replaces the member count on each row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              subtitleView: (context, group) => Text('sub-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub-g1'), findsOneWidget);
      expect(find.text('sub-g3'), findsOneWidget);
      expect(find.text('3 ${_l10n(tester).members}'), findsNothing);
      expect(find.text('Alpha Guild'), findsOneWidget);
    });

    testWidgets('trailingView: adds a trailing widget to each row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              trailingView: (context, group) => Text('trail-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: _rowOf('Bravo Den'),
          matching: find.text('trail-g2'),
        ),
        findsOneWidget,
      );
      expect(find.text('trail-g1'), findsOneWidget);
      expect(find.text('trail-g3'), findsOneWidget);
    });

    testWidgets('leadingView: replaces each avatar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              leadingView: (context, group) => Text('lead-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lead-g1'), findsOneWidget);
      expect(find.text('lead-g2'), findsOneWidget);
      expect(find.byType(CometChatAvatar), findsNothing);
    });

    testWidgets('titleView: replaces each group name', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              titleView: (context, group) => Text('title-${group.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('title-g1'), findsOneWidget);
      expect(find.text('title-g3'), findsOneWidget);
      expect(find.text('Alpha Guild'), findsNothing);
    });

    testWidgets('hideGroupTypeIcon: null and false keep the private and '
        'password badges, true removes them', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsNWidgets(2));

      for (final entry in const {false: 2, true: 0}.entries) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              GroupsList(
                groupsBloc: _loadedBloc(),
                style: const CometChatGroupsStyle(),
                colorPalette: CometChatColorPalette(),
                spacing: CometChatSpacing(),
                typography: const CometChatTypography(),
                hideGroupTypeIcon: entry.key,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byType(CometChatStatusIndicator).evaluate().length,
          entry.value,
          reason: 'hideGroupTypeIcon: ${entry.key}',
        );
      }
    });

    testWidgets('selectionMode: null hides the checkboxes; multiple shows one '
        'per row and a tick dispatches a toggle', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Checkbox), findsNothing);

      final bloc = _loadedBloc();
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: bloc,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Checkbox), findsNWidgets(3));

      await tester.tap(
        find.descendant(
          of: _rowOf('Bravo Den'),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pump();
      expect(bloc.events, [const ToggleGroupSelection('g2')]);
    });

    testWidgets('activateSelection: onClick turns a row tap into a selection '
        'toggle', (tester) async {
      final plain = _loadedBloc();
      final tapped = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: plain,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
              onItemTap: (context, group) => tapped.add(group.guid),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Alpha Guild'));
      await tester.pump();
      expect(tapped, ['g1']);
      expect(plain.events, isEmpty);

      final selecting = _loadedBloc();
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: selecting,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
              onItemTap: (context, group) => tapped.add(group.guid),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Alpha Guild'));
      await tester.pump();

      expect(selecting.events, [const ToggleGroupSelection('g1')]);
      expect(tapped, ['g1'], reason: 'onItemTap must not fire again');
    });

    testWidgets('activateSelection: onLongClick starts a selection on '
        'long-press, then taps extend it', (tester) async {
      final pressed = <String>[];
      final tapped = <String>[];
      final idle = _loadedBloc();
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: idle,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
              onItemTap: (context, group) => tapped.add(group.guid),
              onItemLongPress: (context, group) => pressed.add(group.guid),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Alpha Guild'));
      await tester.pump();
      expect(idle.events, [const ToggleGroupSelection('g1')]);
      expect(pressed, isEmpty);

      final active = _loadedBloc(selected: {'g1'});
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: active,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
              onItemTap: (context, group) => tapped.add(group.guid),
              onItemLongPress: (context, group) => pressed.add(group.guid),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Bravo Den'));
      await tester.pump();

      expect(active.events, [const ToggleGroupSelection('g2')]);
      expect(tapped, isEmpty);
    });

    testWidgets('activateSelection: onClick with no selectionMode leaves a tap '
        'to onItemTap', (tester) async {
      // The tap guard used to read `onClick || (onLongClick && any) && mode`,
      // so the selectionMode check bound to the long-click branch only and
      // onClick selected rows in a list showing no checkboxes.
      final bloc = _loadedBloc();
      final tapped = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: bloc,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              activateSelection: ActivateSelection.onClick,
              onItemTap: (context, group) => tapped.add(group.guid),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Alpha Guild'));
      await tester.pump();

      expect(tapped, ['g1']);
      expect(bloc.events, isEmpty);
    });

    testWidgets('activateSelection: onLongClick starts a selection even with '
        'no onItemLongPress', (tester) async {
      // The long-press gesture used to be wired only when onItemLongPress was
      // given, so this combination could never start a selection.
      final bloc = _loadedBloc();
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: bloc,
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Alpha Guild'));
      await tester.pump();

      expect(bloc.events, [const ToggleGroupSelection('g1')]);
    });

    testWidgets('options: a long press opens its menu on that group and runs '
        'the chosen option', (tester) async {
      final built = <String>[];
      final chosen = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              options: (context, group) {
                built.add(group.guid);
                return [
                  CometChatOption(
                    id: 'mute',
                    title: 'Mute ${group.name}',
                    onClick: () => chosen.add(group.guid),
                  ),
                ];
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mute Alpha Guild'), findsNothing);

      await tester.longPress(find.text('Alpha Guild'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(built, ['g1']);
      expect(find.text('Mute Alpha Guild'), findsOneWidget);

      await tester.tap(find.text('Mute Alpha Guild'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chosen, ['g1']);
      expect(find.text('Mute Alpha Guild'), findsNothing);
    });

    testWidgets('options: an empty list opens no menu, and onItemLongPress '
        'takes the press ahead of it', (tester) async {
      final pressed = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              options: (context, group) => const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Alpha Guild'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PopupMenuItem<CometChatOption>), findsNothing);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              key: const ValueKey('with-callback'),
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              onItemLongPress: (context, group) => pressed.add(group.guid),
              options: (context, group) => [
                CometChatOption(id: 'mute', title: 'Mute ${group.name}'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Bravo Den'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pressed, ['g2']);
      expect(find.text('Mute Bravo Den'), findsNothing);
    });

    testWidgets('style.checkBoxBorderRadius accepts a directional radius', (
      tester,
    ) async {
      // GroupsList used to cast the geometry to BorderRadius, so a
      // BorderRadiusDirectional threw during build.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(
                checkBoxBorderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(6),
                ),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              selectionMode: SelectionMode.multiple,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final shape =
          tester.widget<Checkbox>(find.byType(Checkbox).first).shape
              as RoundedRectangleBorder?;
      expect(
        shape?.borderRadius,
        const BorderRadius.only(topLeft: Radius.circular(6)),
      );
    });

    testWidgets('hideError: true replaces the error view with nothing', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              hideError: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('onItemTap: fires with the tapped group', (tester) async {
      Group? tapped;
      BuildContext? from;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              onItemTap: (context, group) {
                from = context;
                tapped = group;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tapped, isNull);

      await tester.tap(find.text('Bravo Den'));
      await tester.pump();

      expect(tapped?.guid, 'g2');
      expect(from?.mounted, isTrue);
    });

    testWidgets('onItemLongPress: unwired by default, fires with the pressed '
        'group when set', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_inkWellOf(tester, 'Charlie Vault').onLongPress, isNull);

      Group? pressed;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              onItemLongPress: (context, group) => pressed = group,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Charlie Vault'));
      await tester.pump();

      expect(pressed?.guid, 'g3');
    });

    testWidgets('avatarStyle: paints every avatar and wins over '
        'style.avatarStyle, which is the fallback', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(
                avatarStyle: CometChatAvatarStyle(
                  backgroundColor: Color(0xFF4B5A69),
                ),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_avatarFills(tester), hasLength(3));
      expect(_avatarFills(tester), everyElement(const Color(0xFF4B5A69)));

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(
                avatarStyle: CometChatAvatarStyle(
                  backgroundColor: Color(0xFF4B5A69),
                ),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              avatarStyle: const CometChatAvatarStyle(
                backgroundColor: Color(0xFF69584B),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_avatarFills(tester), hasLength(3));
      expect(_avatarFills(tester), everyElement(const Color(0xFF69584B)));
    });

    testWidgets('statusIndicatorStyle: borders the badges and wins over '
        'style.statusIndicatorStyle, which is the fallback', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: CometChatGroupsStyle(
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  border: Border.all(color: const Color(0xFF0F0E0D)),
                ),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final name in ['Bravo Den', 'Charlie Vault']) {
        expect(
          _badgeOf(tester, name).border,
          Border.all(color: const Color(0xFF0F0E0D)),
          reason: 'fallback: $name',
        );
      }

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: CometChatGroupsStyle(
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  border: Border.all(color: const Color(0xFF0F0E0D)),
                ),
              ),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              statusIndicatorStyle: CometChatStatusIndicatorStyle(
                border: Border.all(color: const Color(0xFF7A6B5C), width: 3.5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final name in ['Bravo Den', 'Charlie Vault']) {
        expect(
          _badgeOf(tester, name).border,
          Border.all(color: const Color(0xFF7A6B5C), width: 3.5),
          reason: name,
        );
      }
    });

    testWidgets('privateGroupIcon: replaces the glyph on private rows only', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              privateGroupIcon: const Icon(
                Icons.vpn_key,
                key: ValueKey('private-glyph'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: _rowOf('Bravo Den'),
          matching: find.byKey(const ValueKey('private-glyph')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('private-glyph')), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsNothing);
      // The password row keeps its own glyph.
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('protectedGroupIcon: replaces the glyph on password rows '
        'only', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            GroupsList(
              groupsBloc: _loadedBloc(),
              style: const CometChatGroupsStyle(),
              colorPalette: CometChatColorPalette(),
              spacing: CometChatSpacing(),
              typography: const CometChatTypography(),
              protectedGroupIcon: const Icon(
                Icons.password,
                key: ValueKey('protected-glyph'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: _rowOf('Charlie Vault'),
          matching: find.byKey(const ValueKey('protected-glyph')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('protected-glyph')), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
      // The private row keeps its own glyph.
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });
  });
}
