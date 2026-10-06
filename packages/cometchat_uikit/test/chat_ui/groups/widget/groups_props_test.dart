/// Render-verified prop matrix for [CometChatGroups] — ENG-38688 (Track 3
/// PROP1, coverage part 2).
///
/// Fixtures follow `conversations_props_test.dart` and `users_props_test.dart`:
/// a mock bloc injected through the component's own `groupsBloc` parameter and
/// seeded with fake SDK groups, so every row renders real CometChatGroups UI
/// without touching the SDK.
///
/// One table, one row per prop. Each row pumps the component twice inside a
/// single test body, both times through the matrix construction: first with
/// only the row's context applied ([_Case.base], usually nothing), which is
/// the component with the prop ignored, then with the row's sentinel on top.
/// It asserts:
///
///  * the sentinel reached the rendered tree,
///  * the default pass did not already render it, and
///  * where the row pins it ([_Case.atDefault]), exactly what the default pass
///    rendered: both states of every flag, and the presence of whatever a
///    replacement slot replaces.
///
/// The second assertion is what lets every row fail: if the widget ignored the
/// prop, the sentinel pass would render exactly what the default pass did, and
/// the default pass is proven not to match.
///
/// One of the 39 props is deliberately not forwarded by the matrix
/// construction: `groupsRequestBuilder`. It shapes the fetch rather than the
/// pixels, so no row here could observe it; its limit, search and paging are
/// covered against the real bloc and data source in
/// test/chat_ui/groups/groups_request_builder_paging_test.dart.
///
///   flutter test test/chat_ui/groups/widget/groups_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class _MockGroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {
  /// Everything the component dispatched. It talks to its bloc only through
  /// `add`, so this is the whole of its outbound side.
  final events = <GroupsEvent>[];

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) => events.add(event);

  /// Derived from the seeded state the way the real bloc derives it from its
  /// list, so the submit button hands onSelection what production would.
  @override
  List<Group> getSelectedGroups() {
    final loaded = state;
    if (loaded is! GroupsLoaded) return [];
    return [
      for (final g in loaded.groups)
        if (loaded.selectedGroups.contains(g.guid)) g,
    ];
  }
}

class _FakeGroup extends Fake implements Group {
  _FakeGroup(this.guid, this.name, this.type, this.membersCount);

  @override
  final String guid;
  @override
  final String name;
  @override
  final String type;
  @override
  final int membersCount;
  @override
  String? get icon => null;
}

/// One group of each type. The public row carries no type badge; the private
/// and password rows each carry their own, so a badge prop routed to the wrong
/// row is visible.
List<Group> _groups() => [
  _FakeGroup('g1', 'Alpha Guild', CometChatGroupType.public, 1),
  _FakeGroup('g2', 'Beta Circle', CometChatGroupType.private, 7),
  _FakeGroup('g3', 'Gamma Vault', CometChatGroupType.password, 12),
];

const _names = ['Alpha Guild', 'Beta Circle', 'Gamma Vault'];
const _memberCounts = ['1 Member', '7 Members', '12 Members'];

GroupsState _loaded() => GroupsLoaded(groups: _groups(), hasMore: false);

GroupsState _betaSelected() => GroupsLoaded(
  groups: _groups(),
  hasMore: false,
  selectedGroups: const {'g2'},
);

GroupsState _loading() => const GroupsLoading();

GroupsState _empty() => const GroupsEmpty();

GroupsState _loadedButEmpty() => const GroupsLoaded(groups: [], hasMore: false);

GroupsState _error() => const GroupsError(message: 'quota-exceeded-5Z');

_MockGroupsBloc _blocIn(GroupsState state) {
  final bloc = _MockGroupsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

/// A fresh app per pass. Keying it by pass stops the sentinel pump inheriting
/// the default pass's State — CometChatGroups reads its bloc and its search
/// seed once, in initState — or its navigator.
Widget _wrap(String pass, Widget child) => MaterialApp(
  key: ValueKey(pass),
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// What a row's callbacks record into, plus a controller for the one row that
/// needs an object it can later interrogate.
class _Probe {
  final calls = <Object?>[];
  final controller = ScrollController();

  void dispose() => controller.dispose();
}

/// Every prop the matrix construction forwards, all unset. A row's [_Case.base]
/// and [_Case.apply] set only the props it needs.
class _Props {
  Widget? Function(BuildContext, Group)? subtitleView;
  Widget Function(Group)? listItemView;
  CometChatGroupsStyle? groupsStyle;
  ScrollController? scrollController;
  String? searchPlaceholder;
  Widget? backButton;
  bool? showBackButton;
  Widget? searchBoxIcon;
  bool? hideSearch;
  SelectionMode? selectionMode;
  Function(List<Group>?)? onSelection;
  String? title;
  WidgetBuilder? loadingStateView;
  WidgetBuilder? emptyStateView;
  WidgetBuilder? errorStateView;
  List<Widget> Function(BuildContext)? appBarOptions;
  Widget? passwordGroupIcon;
  Widget? privateGroupIcon;
  ActivateSelection? activateSelection;
  VoidCallback? onBack;
  Function(BuildContext, Group)? onItemTap;
  Function(BuildContext, Group)? onItemLongPress;
  OnError? onError;
  Widget? submitIcon;
  bool? hideAppbar;
  double? height;
  double? width;
  String? searchKeyword;
  OnLoad<Group>? onLoad;
  OnEmpty? onEmpty;
  bool? groupTypeVisibility;
  Widget? Function(BuildContext, Group)? titleView;
  Widget? Function(BuildContext, Group)? leadingView;
  Widget? Function(BuildContext, Group)? trailingView;
  bool? hideError;
  _GroupOptions? setOptions;
  _GroupOptions? addOptions;
}

typedef _GroupOptions =
    List<CometChatOption>? Function(
      Group group,
      GroupsBloc bloc,
      BuildContext context,
    );

/// The props the matrix construction in [main] forwards — every public prop
/// except the defect named in the library comment.
const _forwarded = {
  'hideError',
  'groupsBloc',
  'subtitleView',
  'listItemView',
  'groupsStyle',
  'scrollController',
  'searchPlaceholder',
  'backButton',
  'showBackButton',
  'searchBoxIcon',
  'hideSearch',
  'selectionMode',
  'onSelection',
  'title',
  'loadingStateView',
  'emptyStateView',
  'errorStateView',
  'appBarOptions',
  'passwordGroupIcon',
  'privateGroupIcon',
  'activateSelection',
  'onBack',
  'onItemTap',
  'onItemLongPress',
  'setOptions',
  'addOptions',
  'onError',
  'submitIcon',
  'hideAppbar',
  'height',
  'width',
  'searchKeyword',
  'onLoad',
  'onEmpty',
  'groupTypeVisibility',
  'titleView',
  'leadingView',
  'trailingView',
};

typedef _Observe =
    Object? Function(WidgetTester tester, _Probe probe, _MockGroupsBloc bloc);

/// The [_Case.atDefault] of a row that pins no default observation.
const _unpinned = Object();

class _Case {
  const _Case(
    this.prop,
    this.effect, {
    required this.apply,
    required this.observe,
    required this.expected,
    this.base,
    this.atDefault = _unpinned,
    this.state = _loaded,
    this.defaultState,
    this.act,
  });

  /// The CometChatGroups prop this row is about.
  final String prop;

  /// What the sentinel should do to the rendered tree.
  final String effect;

  /// Sets this row's sentinel on the matrix construction.
  final void Function(_Props props, _Probe probe) apply;

  /// Reads the part of the rendered tree [prop] controls. Runs once per pass.
  final _Observe observe;

  /// What [observe] must return with the sentinel applied — a value or a
  /// Matcher. The default pass must not match it.
  final Object? expected;

  /// Props both passes set because [prop] only shows alongside them. The
  /// default pass is then still exactly the construction with [prop] ignored.
  final void Function(_Props props, _Probe probe)? base;

  /// What [observe] must return on the default pass, for rows that pin it.
  final Object? atDefault;

  /// The bloc state both passes render.
  final GroupsState Function() state;

  /// Overrides [state] for the default pass only.
  final GroupsState Function()? defaultState;

  /// An interaction run after each pump, before [observe].
  final Future<void> Function(WidgetTester tester)? act;
}

// ─── Finders ─────────────────────────────────────────────────────────────────

int _count(Finder f) => f.evaluate().length;

Finder get _appBar => find.descendant(
  of: find.byType(CometChatGroups),
  matching: find.byType(AppBar),
);

Finder _inAppBar(Finder f) => find.descendant(of: _appBar, matching: f);

/// The heading is the app bar's first Text: its leading slot holds only icons.
Text _heading(WidgetTester t) =>
    t.widget<Text>(_inAppBar(find.byType(Text)).first);

TextField _searchField(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField));

/// The Column CometChatListBase sizes with ListBaseStyle.height and .width —
/// the nearest Column above the search field.
Finder get _listBody => find
    .ancestor(of: find.byType(TextField), matching: find.byType(Column))
    .first;

Finder _row(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(CometChatGroupListItem),
);

/// The subset of [texts] currently on screen, in order.
List<String> _shown(List<String> texts) => [
  for (final s in texts)
    if (_count(find.text(s)) > 0) s,
];

/// The subset of [texts] currently on screen, top to bottom.
List<String> _topToBottom(WidgetTester t, List<String> texts) => _shown(texts)
  ..sort(
    (a, b) =>
        t.getTopLeft(find.text(a)).dy.compareTo(t.getTopLeft(find.text(b)).dy),
  );

List<String> _toggled(_MockGroupsBloc bloc) => [
  for (final e in bloc.events.whereType<ToggleGroupSelection>()) e.guid,
];

/// Long-presses the row showing [row], lets any menu open, then taps
/// [option] when the menu offers it.
Future<void> _longPressAndChoose(
  WidgetTester t,
  String row,
  String? option,
) async {
  await t.longPress(find.text(row));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  if (option != null && _count(find.text(option)) > 0) {
    await t.tap(find.text(option));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text));
  await t.pump();
}

// ─── Rows ────────────────────────────────────────────────────────────────────

const _backKey = ValueKey('back-sentinel');
const _optionKey = ValueKey('option-sentinel');
const _searchIconKey = ValueKey('search-icon-sentinel');
const _privateKey = ValueKey('private-icon-sentinel');
const _passwordKey = ValueKey('password-icon-sentinel');
const _submitKey = ValueKey('submit-sentinel');

const _surfaceColour = Color(0xFF1A2B3C);
const _headingColour = Color(0xFF2B3C4D);
const _rowTitleColour = Color(0xFF3C4D5E);

final _cases = <_Case>[
  // ── the injected bloc ──────────────────────────────────────────────────────
  // groupsBloc is forwarded on both passes (without it the component builds a
  // real SDK-backed bloc), so this row varies the injected bloc's state
  // instead: the default pass injects an empty bloc, the sentinel pass a
  // loaded one. A component that ignored the prop could show neither list.
  _Case(
    'groupsBloc',
    'renders from, and sends its first load to, the injected bloc',
    defaultState: _empty,
    apply: (p, _) {},
    observe: (t, _, bloc) => [
      _shown(_names),
      bloc.events.whereType<LoadGroups>().length,
    ],
    expected: [_names, 1],
  ),

  // ── app bar ────────────────────────────────────────────────────────────────
  _Case(
    'title',
    'replaces the localized heading',
    apply: (p, _) => p.title = 'Guild Directory 7Q',
    observe: (t, _, _) => _heading(t).data,
    expected: 'Guild Directory 7Q',
  ),
  _Case(
    'hideError',
    'true removes the error view',
    state: _error,
    apply: (p, _) => p.hideError = true,
    observe: (t, _, _) => _count(find.byType(ElevatedButton)),
    expected: 0,
    atDefault: 1,
  ),
  _Case(
    'hideAppbar',
    'true removes the app bar',
    apply: (p, _) => p.hideAppbar = true,
    observe: (t, _, _) => _count(_appBar),
    expected: 0,
    atDefault: 1,
  ),
  _Case(
    'showBackButton',
    'false removes the back arrow',
    apply: (p, _) => p.showBackButton = false,
    observe: (t, _, _) => _count(_inAppBar(find.byIcon(Icons.arrow_back))),
    expected: 0,
    atDefault: 1,
  ),
  _Case(
    'backButton',
    'replaces the default back arrow',
    apply: (p, _) =>
        p.backButton = const Icon(Icons.u_turn_left, key: _backKey),
    observe: (t, _, _) => [
      _count(_inAppBar(find.byKey(_backKey))),
      _count(find.byIcon(Icons.arrow_back)),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),
  _Case(
    'onBack',
    'fires from the default back arrow',
    apply: (p, probe) => p.onBack = () => probe.calls.add('back'),
    act: (t) async {
      await t.tap(find.byIcon(Icons.arrow_back));
      await t.pump();
    },
    observe: (t, probe, _) => [...probe.calls],
    expected: ['back'],
  ),
  _Case(
    'appBarOptions',
    'adds widgets to the app bar actions',
    apply: (p, _) => p.appBarOptions = (context) => const <Widget>[
      Icon(Icons.tune, key: _optionKey),
    ],
    observe: (t, _, _) => _count(_inAppBar(find.byKey(_optionKey))),
    expected: 1,
  ),

  // ── search row ─────────────────────────────────────────────────────────────
  _Case(
    'hideSearch',
    'true removes the search field',
    apply: (p, _) => p.hideSearch = true,
    observe: (t, _, _) => _count(find.byType(TextField)),
    expected: 0,
    atDefault: 1,
  ),
  _Case(
    'searchPlaceholder',
    'becomes the search hint',
    apply: (p, _) => p.searchPlaceholder = 'Find a guild 4R',
    observe: (t, _, _) => _searchField(t).decoration?.hintText,
    expected: 'Find a guild 4R',
  ),
  _Case(
    'searchBoxIcon',
    'replaces the magnifier inside the search field',
    apply: (p, _) =>
        p.searchBoxIcon = const Icon(Icons.manage_search, key: _searchIconKey),
    observe: (t, _, _) => [
      _count(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byKey(_searchIconKey),
        ),
      ),
      _count(find.byIcon(Icons.search)),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),
  _Case(
    'searchKeyword',
    'seeds the search field and the first load',
    apply: (p, _) => p.searchKeyword = 'gam',
    observe: (t, _, bloc) => [
      _searchField(t).controller?.text,
      [for (final e in bloc.events.whereType<LoadGroups>()) e.searchKeyword],
    ],
    expected: [
      'gam',
      ['gam'],
    ],
  ),

  // ── size and scrolling ─────────────────────────────────────────────────────
  _Case(
    'height',
    'sets the rendered height of the list body',
    apply: (p, _) => p.height = 333,
    observe: (t, _, _) => t.getSize(_listBody).height,
    expected: 333.0,
  ),
  _Case(
    'width',
    'sets the rendered width of the list body',
    apply: (p, _) => p.width = 277,
    observe: (t, _, _) => t.getSize(_listBody).width,
    expected: 277.0,
  ),
  _Case(
    'scrollController',
    'attaches to the groups list',
    apply: (p, probe) => p.scrollController = probe.controller,
    observe: (t, probe, _) => [
      probe.controller.hasClients,
      identical(
        t.widget<ListView>(find.byType(ListView)).controller,
        probe.controller,
      ),
    ],
    expected: [true, true],
  ),

  // ── style ──────────────────────────────────────────────────────────────────
  _Case(
    'groupsStyle',
    'paints the surface, the heading and the row titles',
    apply: (p, _) => p.groupsStyle = const CometChatGroupsStyle(
      backgroundColor: _surfaceColour,
      titleTextColor: _headingColour,
      itemTitleTextColor: _rowTitleColour,
    ),
    observe: (t, _, _) => [
      t
          .widget<Scaffold>(
            find.descendant(
              of: find.byType(CometChatGroups),
              matching: find.byType(Scaffold),
            ),
          )
          .backgroundColor,
      _heading(t).style?.color,
      t.widget<Text>(find.text('Alpha Guild')).style?.color,
    ],
    expected: [_surfaceColour, _headingColour, _rowTitleColour],
  ),

  // ── state views ────────────────────────────────────────────────────────────
  _Case(
    'loadingStateView',
    'replaces the shimmer while loading',
    state: _loading,
    apply: (p, _) =>
        p.loadingStateView = (context) => const Text('loading-sentinel-9K'),
    observe: (t, _, _) => [
      _count(find.text('loading-sentinel-9K')),
      _count(find.byType(CometChatShimmerEffect)),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),
  _Case(
    'emptyStateView',
    'replaces the empty state',
    state: _empty,
    apply: (p, _) =>
        p.emptyStateView = (context) => const Text('empty-sentinel-3M'),
    observe: (t, _, _) => [
      _count(find.text('empty-sentinel-3M')),
      _count(find.text('No groups found')),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),
  _Case(
    'errorStateView',
    'replaces the error state and its retry button',
    state: _error,
    apply: (p, _) =>
        p.errorStateView = (context) => const Text('error-sentinel-8P'),
    observe: (t, _, _) => [
      _count(find.text('error-sentinel-8P')),
      _count(find.byType(ElevatedButton)),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),

  // ── row slots ──────────────────────────────────────────────────────────────
  _Case(
    'listItemView',
    'replaces every row',
    apply: (p, _) => p.listItemView = (g) => Text('row-${g.guid}'),
    observe: (t, _, _) => [
      _shown(['row-g1', 'row-g2', 'row-g3']),
      _count(find.byType(CometChatGroupListItem)),
    ],
    expected: [
      ['row-g1', 'row-g2', 'row-g3'],
      0,
    ],
    atDefault: [<String>[], 3],
  ),
  _Case(
    'titleView',
    'replaces the group name in every row',
    apply: (p, _) => p.titleView = (context, g) => Text('title-${g.guid}'),
    observe: (t, _, _) => [
      _shown(['title-g1', 'title-g2', 'title-g3']),
      _shown(_names),
    ],
    expected: [
      ['title-g1', 'title-g2', 'title-g3'],
      <String>[],
    ],
    atDefault: [<String>[], _names],
  ),
  _Case(
    'subtitleView',
    'replaces the member count in every row',
    apply: (p, _) => p.subtitleView = (context, g) => Text('sub-${g.guid}'),
    observe: (t, _, _) => [
      _shown(['sub-g1', 'sub-g2', 'sub-g3']),
      _shown(_memberCounts),
    ],
    expected: [
      ['sub-g1', 'sub-g2', 'sub-g3'],
      <String>[],
    ],
    atDefault: [<String>[], _memberCounts],
  ),
  _Case(
    'leadingView',
    'replaces the avatar in every row',
    apply: (p, _) => p.leadingView = (context, g) => Text('lead-${g.guid}'),
    observe: (t, _, _) => [
      _shown(['lead-g1', 'lead-g2', 'lead-g3']),
      _count(find.byType(CometChatAvatar)),
    ],
    expected: [
      ['lead-g1', 'lead-g2', 'lead-g3'],
      0,
    ],
    atDefault: [<String>[], 3],
  ),
  _Case(
    'trailingView',
    'adds a trailing widget to every row',
    apply: (p, _) => p.trailingView = (context, g) => Text('trail-${g.guid}'),
    observe: (t, _, _) => _shown(['trail-g1', 'trail-g2', 'trail-g3']),
    expected: ['trail-g1', 'trail-g2', 'trail-g3'],
  ),

  // ── group-type badges ──────────────────────────────────────────────────────
  _Case(
    'groupTypeVisibility',
    'false removes the private and password badges',
    apply: (p, _) => p.groupTypeVisibility = false,
    observe: (t, _, _) => _count(find.byType(CometChatStatusIndicator)),
    expected: 0,
    atDefault: 2,
  ),
  _Case(
    'privateGroupIcon',
    'replaces the shield on the private row, and only there',
    apply: (p, _) =>
        p.privateGroupIcon = const Icon(Icons.vpn_lock, key: _privateKey),
    observe: (t, _, _) => [
      _count(
        find.descendant(
          of: _row('Beta Circle'),
          matching: find.byKey(_privateKey),
        ),
      ),
      _count(find.byIcon(Icons.shield)),
      _count(
        find.descendant(
          of: _row('Gamma Vault'),
          matching: find.byIcon(Icons.lock),
        ),
      ),
    ],
    expected: [1, 0, 1],
    atDefault: [0, 1, 1],
  ),
  _Case(
    'passwordGroupIcon',
    'replaces the lock on the password row, and only there',
    apply: (p, _) =>
        p.passwordGroupIcon = const Icon(Icons.key, key: _passwordKey),
    observe: (t, _, _) => [
      _count(
        find.descendant(
          of: _row('Gamma Vault'),
          matching: find.byKey(_passwordKey),
        ),
      ),
      _count(find.byIcon(Icons.lock)),
      _count(
        find.descendant(
          of: _row('Beta Circle'),
          matching: find.byIcon(Icons.shield),
        ),
      ),
    ],
    expected: [1, 0, 1],
    atDefault: [0, 1, 1],
  ),

  // ── selection ──────────────────────────────────────────────────────────────
  _Case(
    'selectionMode',
    'multiple puts a checkbox on every row',
    apply: (p, _) => p.selectionMode = SelectionMode.multiple,
    observe: (t, _, _) => _count(find.byType(Checkbox)),
    expected: 3,
    atDefault: 0,
  ),
  _Case(
    'activateSelection',
    'onClick turns a row tap into a selection toggle instead of onItemTap',
    // A toggle needs a selection mode, and the counterfactual needs a tap
    // handler to fall through to, so both passes get them. The default pass
    // is then the component with activateSelection ignored: the tap reaches
    // onItemTap and nothing toggles.
    base: (p, probe) => p
      ..selectionMode = SelectionMode.multiple
      ..onItemTap = (context, g) => probe.calls.add('tap:${g.guid}'),
    apply: (p, _) => p.activateSelection = ActivateSelection.onClick,
    act: (t) => _tapText(t, 'Alpha Guild'),
    observe: (t, probe, bloc) => [
      _toggled(bloc),
      [...probe.calls],
    ],
    expected: [
      ['g1'],
      <Object?>[],
    ],
    atDefault: [
      <String>[],
      ['tap:g1'],
    ],
  ),
  _Case(
    'onSelection',
    'receives the selection when the submit tick is tapped',
    state: _betaSelected,
    apply: (p, probe) => p.onSelection = (groups) =>
        probe.calls.add([for (final g in groups ?? const <Group>[]) g.guid]),
    act: (t) async {
      await t.tap(find.byIcon(Icons.check));
      await t.pump();
    },
    observe: (t, probe, _) => [...probe.calls],
    expected: [
      ['g2'],
    ],
  ),
  _Case(
    'submitIcon',
    'replaces the default submit tick',
    state: _betaSelected,
    apply: (p, _) => p.submitIcon = const Icon(Icons.done_all, key: _submitKey),
    observe: (t, _, _) => [
      _count(_inAppBar(find.byKey(_submitKey))),
      _count(find.byIcon(Icons.check)),
    ],
    expected: [1, 0],
    atDefault: [0, 1],
  ),

  // ── row interaction ────────────────────────────────────────────────────────
  _Case(
    'onItemTap',
    'fires with the tapped group',
    apply: (p, probe) => p.onItemTap = (context, g) => probe.calls.add(g.guid),
    act: (t) => _tapText(t, 'Alpha Guild'),
    observe: (t, probe, _) => [...probe.calls],
    expected: ['g1'],
  ),
  _Case(
    'onItemLongPress',
    'fires with the long-pressed group',
    apply: (p, probe) =>
        p.onItemLongPress = (context, g) => probe.calls.add(g.guid),
    act: (t) async {
      await t.longPress(find.text('Beta Circle'));
      await t.pump();
    },
    observe: (t, probe, _) => [...probe.calls],
    expected: ['g2'],
  ),

  // ── long-press options ─────────────────────────────────────────────────────
  _Case(
    'setOptions',
    'opens a menu on the long-pressed group and runs the chosen option',
    apply: (p, probe) => p.setOptions = (g, bloc, context) => [
      CometChatOption(
        id: 'mute',
        title: 'Mute ${g.name}',
        onClick: () => probe.calls.add('mute:${g.guid}'),
      ),
    ],
    act: (t) => _longPressAndChoose(t, 'Beta Circle', 'Mute Beta Circle'),
    observe: (t, probe, _) => [...probe.calls],
    expected: ['mute:g2'],
  ),
  _Case(
    'addOptions',
    'opens a menu on the long-pressed group and runs the chosen option',
    apply: (p, probe) => p.addOptions = (g, bloc, context) => [
      CometChatOption(
        id: 'star',
        title: 'Star ${g.name}',
        onClick: () => probe.calls.add('star:${g.guid}'),
      ),
    ],
    act: (t) => _longPressAndChoose(t, 'Gamma Vault', 'Star Gamma Vault'),
    observe: (t, probe, _) => [...probe.calls],
    expected: ['star:g3'],
  ),
  // Android's CometChatGroups joins the two lists, setOptions first
  // (preparePopupMenu). CometChatUsers differs: there setOptions wins.
  _Case(
    'setOptions',
    'goes ahead of addOptions in the menu when both are set',
    base: (p, probe) => p.addOptions = (g, bloc, context) => [
      CometChatOption(id: 'added', title: 'ADDED-5Z'),
    ],
    apply: (p, probe) => p.setOptions = (g, bloc, context) => [
      CometChatOption(id: 'set', title: 'SET-5Z'),
    ],
    act: (t) => _longPressAndChoose(t, 'Alpha Guild', null),
    observe: (t, probe, _) => _topToBottom(t, const ['SET-5Z', 'ADDED-5Z']),
    expected: ['SET-5Z', 'ADDED-5Z'],
    atDefault: ['ADDED-5Z'],
  ),
  _Case(
    'addOptions',
    'is appended after setOptions in the menu when both are set',
    base: (p, probe) => p.setOptions = (g, bloc, context) => [
      CometChatOption(id: 'set', title: 'SET-5Z'),
    ],
    apply: (p, probe) => p.addOptions = (g, bloc, context) => [
      CometChatOption(id: 'added', title: 'ADDED-5Z'),
    ],
    act: (t) => _longPressAndChoose(t, 'Alpha Guild', null),
    observe: (t, probe, _) => _topToBottom(t, const ['SET-5Z', 'ADDED-5Z']),
    expected: ['SET-5Z', 'ADDED-5Z'],
    atDefault: ['SET-5Z'],
  ),
  _Case(
    'onItemLongPress',
    'takes the long press ahead of the options menu',
    base: (p, probe) => p.setOptions = (g, bloc, context) => [
      CometChatOption(id: 'set', title: 'SET-5Z'),
    ],
    apply: (p, probe) =>
        p.onItemLongPress = (context, g) => probe.calls.add(g.guid),
    act: (t) => _longPressAndChoose(t, 'Beta Circle', null),
    observe: (t, probe, _) => [
      ...probe.calls,
      if (_count(find.text('SET-5Z')) > 0) 'menu',
    ],
    expected: ['g2'],
    atDefault: ['menu'],
  ),

  // ── state reporting ────────────────────────────────────────────────────────
  _Case(
    'onLoad',
    'reports the loaded groups exactly once',
    apply: (p, probe) =>
        p.onLoad = (groups) =>
            probe.calls.add([for (final g in groups) g.guid]),
    observe: (t, probe, _) => [...probe.calls],
    expected: [
      ['g1', 'g2', 'g3'],
    ],
  ),
  _Case(
    'onEmpty',
    'reports the empty state exactly once',
    state: _empty,
    apply: (p, probe) => p.onEmpty = () => probe.calls.add('empty'),
    observe: (t, probe, _) => [...probe.calls],
    expected: ['empty'],
  ),
  _Case(
    'onEmpty',
    'also reports a loaded list with no groups',
    state: _loadedButEmpty,
    apply: (p, probe) => p.onEmpty = () => probe.calls.add('empty'),
    observe: (t, probe, _) => [...probe.calls],
    expected: ['empty'],
  ),
  _Case(
    'onError',
    'reports the failure with its message',
    state: _error,
    apply: (p, probe) => p.onError = (e) => probe.calls.add('$e'),
    observe: (t, probe, _) => [...probe.calls],
    expected: [contains('quota-exceeded-5Z')],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatGroups prop matrix', () {
    for (final c in _cases) {
      testWidgets('${c.prop}: ${c.effect}', (tester) async {
        // Pass 1 renders the construction with only the row's base applied,
        // which is the component with this prop ignored. Pass 2 adds the
        // row's sentinel.
        final seen = <String, Object?>{};
        for (final pass in const ['default', 'sentinel']) {
          final isSentinel = pass == 'sentinel';
          final probe = _Probe();
          addTearDown(probe.dispose);
          final p = _Props();
          c.base?.call(p, probe);
          if (isSentinel) c.apply(p, probe);
          final bloc = _blocIn(
            isSentinel ? c.state() : (c.defaultState ?? c.state)(),
          );
          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                pass,
                CometChatGroups(
                  groupsBloc: bloc,
                  subtitleView: p.subtitleView,
                  listItemView: p.listItemView,
                  groupsStyle: p.groupsStyle,
                  scrollController: p.scrollController,
                  searchPlaceholder: p.searchPlaceholder,
                  backButton: p.backButton,
                  showBackButton: p.showBackButton ?? true,
                  searchBoxIcon: p.searchBoxIcon,
                  hideSearch: p.hideSearch ?? false,
                  selectionMode: p.selectionMode,
                  onSelection: p.onSelection,
                  title: p.title,
                  loadingStateView: p.loadingStateView,
                  emptyStateView: p.emptyStateView,
                  errorStateView: p.errorStateView,
                  hideError: p.hideError,
                  appBarOptions: p.appBarOptions,
                  passwordGroupIcon: p.passwordGroupIcon,
                  privateGroupIcon: p.privateGroupIcon,
                  activateSelection: p.activateSelection,
                  onBack: p.onBack,
                  onItemTap: p.onItemTap,
                  onItemLongPress: p.onItemLongPress,
                  setOptions: p.setOptions,
                  addOptions: p.addOptions,
                  onError: p.onError,
                  submitIcon: p.submitIcon,
                  hideAppbar: p.hideAppbar ?? false,
                  height: p.height,
                  width: p.width,
                  searchKeyword: p.searchKeyword,
                  onLoad: p.onLoad,
                  onEmpty: p.onEmpty,
                  groupTypeVisibility: p.groupTypeVisibility ?? true,
                  titleView: p.titleView,
                  leadingView: p.leadingView,
                  trailingView: p.trailingView,
                ),
              ),
            ),
          );
          await tester.pump();
          await c.act?.call(tester);
          seen[pass] = c.observe(tester, probe, bloc);
        }

        expect(
          seen['sentinel'],
          c.expected,
          reason: '${c.prop} did not reach the rendered tree',
        );
        expect(
          seen['default'],
          isNot(c.expected),
          reason:
              'the default already renders the ${c.prop} sentinel, so this '
              'row could not fail',
        );
        if (!identical(c.atDefault, _unpinned)) {
          expect(
            seen['default'],
            c.atDefault,
            reason: 'the default pass did not render what ${c.prop} changes',
          );
        }
      });
    }
  });

  test('every prop the matrix construction forwards has a row', () {
    expect(_cases.map((c) => c.prop).toSet(), _forwarded);
  });
}
