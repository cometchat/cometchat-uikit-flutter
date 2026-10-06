/// The branches of [CometChatGroupMembers] the prop matrices do not reach:
/// the member-option actions, the selection state machine, and the callbacks
/// and events each gesture dispatches.
///
/// `group_members_data_props_test.dart` pins which widget appears for which
/// prop. This pins which *bloc event* each gesture raises — kick, ban, scope
/// change, search, paging, retry, clear-selection — because those are the
/// lines where a wrong wire is silent: the dialog still opens and the sheet
/// still closes, only nothing happens to the group.
///
///   flutter test test/chat_ui/group_members/widget/group_members_branches_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupMembersBloc
    extends MockBloc<GroupMembersEvent, GroupMembersState>
    implements GroupMembersBloc {}

class _FakeBuildContext extends Fake implements BuildContext {}

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public')
  ..owner = 'owner-uid';

GroupMember _member(String uid, String name) =>
    GroupMember(uid: uid, name: name, scope: GroupMemberScope.participant);

final _alice = _member('u1', 'Alice');
final _bob = _member('u2', 'Bob');

/// The option metadata the bloc hands back after permission filtering. The
/// widget re-wraps each entry with its own onClick, which is the wiring under
/// test here.
CometChatGroupMemberOption _opt(String id, String title) =>
    CometChatGroupMemberOption(id: id, title: title);

MockGroupMembersBloc _mock({
  List<GroupMember>? members,
  Set<String> selected = const {},
  GroupMembersState? state,
  List<CometChatGroupMemberOption> defaultOptions =
      const <CometChatGroupMemberOption>[],
  bool hasMore = false,
}) {
  final list = members ?? [_alice, _bob];
  final resolved =
      state ??
      GroupMembersLoaded(
        members: list,
        hasMore: hasMore,
        selectedMembers: selected,
        isLoadingMore: false,
      );
  final bloc = MockGroupMembersBloc();
  whenListen(
    bloc,
    Stream<GroupMembersState>.value(resolved),
    initialState: resolved,
  );
  when(() => bloc.loggedInUser).thenReturn(User(uid: 'me', name: 'Me'));
  when(
    () => bloc.getSelectedList(),
  ).thenReturn(list.where((m) => selected.contains(m.uid)).toList());
  when(
    () => bloc.getDefaultOptions(any(), any(), any(), any(), any()),
  ).thenReturn(defaultOptions);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The option sheet renders scope icons from the package asset bundle, which
/// is not mounted in a unit-test process. Those codec errors are noise.
void _drainAssetErrors(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Widget _screen(CometChatGroupMembers child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// Long-press a row and settle the menu that opens.
Future<void> _openMenu(WidgetTester tester, [String on = 'Alice']) async {
  await tester.longPress(find.text(on));
  await _settle(tester);
  await tester.pumpAndSettle();
  _drainAssetErrors(tester);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_alice);
    registerFallbackValue(_group);
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(CometChatColorPalette());
    registerFallbackValue(CometChatTypography());
    registerFallbackValue(CometChatSpacing());
    registerFallbackValue(const LoadGroupMembers());
  });

  // =========================================================================
  group('member options — kick', () {
    testWidgets('choosing kick asks to confirm before doing anything', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [_opt(GroupMemberOptionConstants.kick, 'Kick')],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Kick'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      expect(find.text('Kick Alice?'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<KickMember>())));
    });

    testWidgets('confirming kick dispatches KickMember for that member', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [_opt(GroupMemberOptionConstants.kick, 'Kick')],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Kick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KICK'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      final captured = verify(
        () => bloc.add(captureAny(that: isA<KickMember>())),
      ).captured;
      expect((captured.single as KickMember).member.uid, 'u1');
      expect(find.text('Kick Alice?'), findsNothing);
    });

    testWidgets('cancelling kick closes the dialog and dispatches nothing', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [_opt(GroupMemberOptionConstants.kick, 'Kick')],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Kick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      expect(find.text('Kick Alice?'), findsNothing);
      verifyNever(() => bloc.add(any(that: isA<KickMember>())));
    });
  });

  // =========================================================================
  group('member options — ban', () {
    testWidgets('confirming ban dispatches BanMember for that member', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [_opt(GroupMemberOptionConstants.ban, 'Ban')],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Ban'));
      await tester.pumpAndSettle();
      expect(find.text('Ban Alice?'), findsOneWidget);

      await tester.tap(find.text('BAN'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      final captured = verify(
        () => bloc.add(captureAny(that: isA<BanMember>())),
      ).captured;
      expect((captured.single as BanMember).member.uid, 'u1');
    });
  });

  // =========================================================================
  group('member options — change scope', () {
    testWidgets('choosing change scope opens the scope sheet for the member', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [
          _opt(GroupMemberOptionConstants.changeScope, 'Change Scope'),
        ],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Change Scope'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      final sheet = tester.widget<CometChatChangeScope>(
        find.byType(CometChatChangeScope),
      );
      expect(sheet.member.uid, 'u1');
      expect(sheet.group.guid, 'g1');
    });

    testWidgets('saving a new scope dispatches ChangeMemberScope', (
      tester,
    ) async {
      final bloc = _mock(
        defaultOptions: [
          _opt(GroupMemberOptionConstants.changeScope, 'Change Scope'),
        ],
      );

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Change Scope'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      // Drive the sheet's own onSave, which is the widget's wiring under test.
      final sheet = tester.widget<CometChatChangeScope>(
        find.byType(CometChatChangeScope),
      );
      await sheet.onSave!(
        _group,
        _alice,
        GroupMemberScope.admin,
        GroupMemberScope.participant,
      );
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ChangeMemberScope>())),
      ).captured;
      final event = captured.single as ChangeMemberScope;
      expect(event.member.uid, 'u1');
      expect(event.newScope, GroupMemberScope.admin);
    });
  });

  // =========================================================================
  group('option builders that return null', () {
    testWidgets('a null from options opens no menu', (tester) async {
      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            options: (_, _, _, _) => null,
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);

      expect(find.byType(PopupMenuItem<CometChatOption>), findsNothing);
    });

    testWidgets('a null from setOptions opens no menu', (tester) async {
      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            setOptions: (_, _, _, _) => null,
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);

      expect(find.byType(PopupMenuItem<CometChatOption>), findsNothing);
    });

    testWidgets('a null from addOptions still shows the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(
              defaultOptions: [_opt(GroupMemberOptionConstants.kick, 'Kick')],
            ),
            addOptions: (_, _, _, _) => null,
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);

      expect(find.text('Kick'), findsOneWidget);
    });

    testWidgets('addOptions entries come before the defaults', (tester) async {
      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(
              defaultOptions: [_opt(GroupMemberOptionConstants.kick, 'Kick')],
            ),
            addOptions: (_, _, _, _) => [
              CometChatOption(id: 'extra', title: 'Extra'),
            ],
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(titles.indexOf('Extra'), lessThan(titles.indexOf('Kick')));
    });

    testWidgets('a custom option runs its own onClick when chosen', (
      tester,
    ) async {
      var clicks = 0;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            setOptions: (_, _, _, _) => [
              CometChatOption(
                id: 'x',
                title: 'Custom',
                onClick: () => clicks++,
              ),
            ],
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      _drainAssetErrors(tester);

      expect(clicks, 1);
    });
  });

  // =========================================================================
  group('selection state machine', () {
    testWidgets('a long press starts selection when activateSelection is '
        'onLongClick', (tester) async {
      final bloc = _mock();

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onLongClick,
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ToggleMemberSelection>())),
      ).captured;
      expect((captured.single as ToggleMemberSelection).uid, 'u1');
    });

    testWidgets('with onLongClick a plain tap selects once something is '
        'already selected', (tester) async {
      final bloc = _mock(selected: const {'u2'});

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onLongClick,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ToggleMemberSelection>())),
      ).captured;
      expect((captured.single as ToggleMemberSelection).uid, 'u1');
    });

    testWidgets('with onLongClick and nothing selected a tap falls through to '
        'onItemTap', (tester) async {
      final bloc = _mock();
      GroupMember? tapped;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onLongClick,
            onItemTap: (m) => tapped = m,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);

      expect(tapped?.uid, 'u1');
      verifyNever(() => bloc.add(any(that: isA<ToggleMemberSelection>())));
    });

    testWidgets('the group owner can never be selected', (tester) async {
      final owner = _member('owner-uid', 'Owner');
      final bloc = _mock(members: [owner]);
      GroupMember? tapped;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onClick,
            onItemTap: (m) => tapped = m,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Owner').first);
      await _settle(tester);

      verifyNever(() => bloc.add(any(that: isA<ToggleMemberSelection>())));
      expect(tapped?.uid, 'owner-uid', reason: 'falls through to onItemTap');
    });

    testWidgets('selectionMode none leaves taps as plain taps', (tester) async {
      final bloc = _mock();
      GroupMember? tapped;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.none,
            activateSelection: ActivateSelection.onClick,
            onItemTap: (m) => tapped = m,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);

      verifyNever(() => bloc.add(any(that: isA<ToggleMemberSelection>())));
      expect(tapped?.uid, 'u1');
    });

    testWidgets('the row checkbox toggles the same selection a tap does', (
      tester,
    ) async {
      final bloc = _mock(selected: const {'u2'});

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onClick,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byType(Checkbox).first);
      await _settle(tester);

      verify(() => bloc.add(any(that: isA<ToggleMemberSelection>()))).called(1);
    });

    testWidgets('deselecting the last selected member turns selection mode '
        'back off', (tester) async {
      // Only-one-selected is the branch that has to put the app bar back: the
      // submit control disappears and the clear-selection arrow reverts.
      final bloc = _mock(selected: const {'u1'});

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onClick,
            showBackButton: true,
          ),
        ),
      );
      await _settle(tester);

      // Tapping a second member keeps a selection alive: the submit control
      // appears.
      await tester.tap(find.text('Bob'));
      await _settle(tester);
      expect(find.byTooltip('Done'), findsOneWidget);

      // Tapping the one member the state says is selected empties it, and the
      // submit control has to go with it. (The bloc is mocked, so its state
      // does not move; the widget's own _isSelectionOn flag is under test.)
      await tester.tap(find.text('Alice'));
      await _settle(tester);

      expect(find.byTooltip('Done'), findsNothing);
      verify(() => bloc.add(any(that: isA<ToggleMemberSelection>()))).called(2);
    });

    testWidgets('clearing the selection dispatches ClearMemberSelection', (
      tester,
    ) async {
      final bloc = _mock(selected: const {'u1'});

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: bloc,
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onClick,
            showBackButton: true,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.clear));
      await _settle(tester);

      verify(() => bloc.add(any(that: isA<ClearMemberSelection>()))).called(1);
    });
  });

  // =========================================================================
  group('list plumbing', () {
    testWidgets('searching dispatches SearchGroupMembers with the text', (
      tester,
    ) async {
      final bloc = _mock();

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'ali');
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => bloc.add(captureAny(that: isA<SearchGroupMembers>())),
      ).captured;
      expect((captured.last as SearchGroupMembers).keyword, 'ali');
    });

    testWidgets('the error view retries by reloading the members', (
      tester,
    ) async {
      final bloc = _mock(state: const GroupMembersError(message: 'boom'));

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      // The screen already asked for a first page on mount; only the retry
      // that follows the tap is under test.
      clearInteractions(bloc);
      await tester.tap(find.byType(ElevatedButton));
      await _settle(tester);

      verify(() => bloc.add(any(that: isA<LoadGroupMembers>()))).called(1);
    });

    testWidgets('hideError renders nothing at all in the error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(
              state: const GroupMembersError(message: 'boom'),
            ),
            hideError: true,
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('scrolling to the bottom with hasMore asks for more', (
      tester,
    ) async {
      final many = List.generate(30, (i) => _member('u$i', 'Member $i'));
      final bloc = _mock(members: many, hasMore: true);

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await tester.fling(find.text('Member 0'), const Offset(0, -4000), 4000);
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(any(that: isA<LoadMoreGroupMembers>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('a short list never asks for more', (tester) async {
      final bloc = _mock();

      await tester.pumpWidget(
        _screen(CometChatGroupMembers(group: _group, groupMembersBloc: bloc)),
      );
      await _settle(tester);
      await tester.fling(find.text('Alice'), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<LoadMoreGroupMembers>())));
    });
  });

  // =========================================================================
  group('lifecycle callbacks', () {
    testWidgets('onLoad is handed the loaded members', (tester) async {
      List<GroupMember>? loaded;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            onLoad: (m) => loaded = m,
          ),
        ),
      );
      await _settle(tester);

      expect(loaded?.map((m) => m.uid), ['u1', 'u2']);
    });

    testWidgets('onEmpty fires for the empty state', (tester) async {
      var empties = 0;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(state: GroupMembersEmpty()),
            onEmpty: () => empties++,
          ),
        ),
      );
      await _settle(tester);

      expect(empties, 1);
    });

    testWidgets('onError is handed the bloc message as an exception', (
      tester,
    ) async {
      final seen = <CometChatException>[];

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(
              state: const GroupMembersError(message: 'boom'),
            ),
            onError: (e) => seen.add(e as CometChatException),
          ),
        ),
      );
      await _settle(tester);

      expect(seen, hasLength(1));
      expect(seen.single.message, contains('boom'));
    });
  });

  // =========================================================================
  group('legacy controller bridge', () {
    testWidgets('stateCallBack hands back a controller whose selectionMap '
        'mirrors the list', (tester) async {
      CometChatGroupMembersController? handed;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(selected: const {'u2'}),
            selectionMode: SelectionMode.multiple,
            activateSelection: ActivateSelection.onClick,
            stateCallBack: (c) => handed = c,
          ),
        ),
      );
      await _settle(tester);
      addTearDown(() => handed?.dispose());

      expect(handed, isNotNull);
      expect(handed!.selectionMap.keys, ['u2']);
      expect(handed!.selectionMap['u2']?.name, 'Bob');
    });

    testWidgets('the same controller instance is handed to the option '
        'builders', (tester) async {
      CometChatGroupMembersController? fromState;
      CometChatGroupMembersController? fromOptions;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            stateCallBack: (c) => fromState = c,
            setOptions: (_, _, c, _) {
              fromOptions = c;
              return [CometChatOption(id: 'x', title: 'Custom')];
            },
          ),
        ),
      );
      await _settle(tester);
      await _openMenu(tester);
      addTearDown(() => fromState?.dispose());

      expect(fromOptions, same(fromState));
    });
  });

  // =========================================================================
  group('app bar back button', () {
    testWidgets('the default back button pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: CometChatGroupMembers(
                        group: _group,
                        groupMembersBloc: _mock(),
                        showBackButton: true,
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
      expect(find.byType(CometChatGroupMembers), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(CometChatGroupMembers), findsNothing);
    });

    testWidgets('FINDING: onBack never fires — the arrow pops instead', (
      tester,
    ) async {
      // FINDING: the widget hands `CometChatListBase` a fully-wired
      // `IconButton` as its `backIcon`, and the list base then wraps whatever
      // it is given in ANOTHER IconButton whose onPressed is `onBack`. The
      // result is a button inside a button: the inner one absorbs the tap and
      // always calls `Navigator.pop(context)`, so the integrator's `onBack`
      // is unreachable. Only `backButton` (which replaces the inner widget)
      // can change what the arrow does.
      var backs = 0;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            showBackButton: true,
            onBack: () => backs++,
          ),
        ),
      );
      await _settle(tester);

      // Two nested back buttons: the outer carries onBack, the inner pops.
      final buttons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .toList();
      expect(buttons, hasLength(2));
      expect(buttons.first.icon, isA<IconButton>());
      expect(buttons.last.icon, isA<Icon>());

      await tester.tap(find.byIcon(Icons.arrow_back));
      await _settle(tester);

      expect(backs, 0, reason: 'the inner button swallowed the tap');
    });

    testWidgets('a custom backButton replaces the arrow and its pop', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        _screen(
          CometChatGroupMembers(
            group: _group,
            groupMembersBloc: _mock(),
            showBackButton: true,
            backButton: IconButton(
              icon: const Icon(Icons.close, key: Key('CUSTOM_BACK')),
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const Key('CUSTOM_BACK')));
      await _settle(tester);

      expect(taps, 1);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
