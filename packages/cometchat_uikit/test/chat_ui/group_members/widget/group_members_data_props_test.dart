/// Data-driven prop matrix for [CometChatGroupMembers] — the props that only
/// render once member data exists (Track 3 PROP1, ENG-38767).
///
/// These were previously out of reach: the component built its bloc in
/// initState with no way to supply one, so a test could only ever observe the
/// error state. ENG-38797 added a `groupMembersBloc` parameter mirroring
/// [CometChatConversations.conversationsBloc]; this file uses it, so no SDK is
/// touched and no `runZonedGuarded` is needed.
///
/// The chrome-only matrix stays in group_members_props_test.dart.
///
///   flutter test test/chat_ui/group_members/widget/group_members_data_props_test.dart
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

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public');

GroupMember _member(String uid, String name) =>
    GroupMember(uid: uid, name: name, scope: GroupMemberScope.participant);

final _alice = _member('u1', 'Alice');
final _bob = _member('u2', 'Bob');

MockGroupMembersBloc _mock({
  List<GroupMember>? members,
  Set<String> selected = const {},
  GroupMembersState? state,
}) {
  final list = members ?? [_alice, _bob];
  final resolved =
      state ??
      GroupMembersLoaded(
        members: list,
        hasMore: false,
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
  ).thenReturn(<CometChatGroupMemberOption>[]);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The member-option sheet renders scope icons from the package asset bundle,
/// which is not mounted in a unit-test process. Those image-codec errors are
/// noise here — the option list itself is what is under test.
void _drainAssetErrors(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(_alice);
    registerFallbackValue(_group);
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(CometChatColorPalette());
    registerFallbackValue(CometChatTypography());
    registerFallbackValue(CometChatSpacing());
  });

  group('per-member slot views', () {
    testWidgets('listItemView replaces the whole row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              listItemView: (member) => Text('ROW_${member.uid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('ROW_u1'), findsOneWidget);
      expect(find.text('ROW_u2'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('titleView replaces the row title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              titleView: (context, member) => Text('TITLE_${member.uid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('TITLE_u1'), findsOneWidget);
    });

    testWidgets('subtitleView renders under the title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              subtitleView: (context, member) => Text('SUB_${member.uid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('SUB_u1'), findsOneWidget);
      expect(find.text('SUB_u2'), findsOneWidget);
    });

    testWidgets('leadingView replaces the avatar slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              leadingView: (context, member) => Text('LEAD_${member.uid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('LEAD_u1'), findsOneWidget);
    });

    testWidgets('trailingView replaces the tail slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              trailingView: (context, member) => Text('TAIL_${member.uid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('TAIL_u1'), findsOneWidget);
    });

    testWidgets('emptyStateView renders on the empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(state: GroupMembersEmpty()),
              emptyStateView: (context) => const Text('EMPTY_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('EMPTY_SLOT'), findsOneWidget);
    });
  });

  group('interaction callbacks', () {
    testWidgets('onItemTap fires with the tapped member', (tester) async {
      GroupMember? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              onItemTap: (member) => tapped = member,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(tapped?.uid, 'u1');
    });

    testWidgets('onItemLongPress fires with the pressed member', (
      tester,
    ) async {
      GroupMember? held;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              onItemLongPress: (member) => held = member,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      expect(held?.uid, 'u1');
    });

    testWidgets('onSelection receives the selected members', (tester) async {
      List<GroupMember>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
              onSelection: (members) => submitted = members,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);
      final submit = find.byType(IconButton);
      await tester.tap(submit.last);
      await _settle(tester);
      expect(submitted, isNotNull);
    });
  });

  group('selection chrome', () {
    testWidgets('selectIcon is used for the row selection control', (
      tester,
    ) async {
      const icon = Icon(Icons.radio_button_unchecked, key: Key('SELECT_ICON'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(selected: const {'u1'}),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
              selectIcon: icon,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('SELECT_ICON')), findsWidgets);
    });

    testWidgets('submitIcon replaces the default submit control', (
      tester,
    ) async {
      const icon = Icon(Icons.send, key: Key('SUBMIT_ICON'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
              submitIcon: icon,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(find.byKey(const Key('SUBMIT_ICON')), findsOneWidget);
    });
  });

  group('options', () {
    testWidgets('setOptions replaces the per-member option set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              setOptions: (group, member, controller, context) => [
                CometChatOption(id: 'SET_OPT', title: 'SetOption'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(find.text('SetOption'), findsOneWidget);
    });

    testWidgets('options replaces the per-member option set outright', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              options: (group, member, controller, context) => [
                CometChatOption(id: 'LEGACY_OPT', title: 'LegacyOption'),
              ],
              // options is the v4 hook and wins over setOptions
              setOptions: (group, member, controller, context) => [
                CometChatOption(id: 'SET_OPT', title: 'SetOption'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(find.text('LegacyOption'), findsOneWidget);
      expect(find.text('SetOption'), findsNothing);
    });

    testWidgets('addOptions appends to the per-member option set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              addOptions: (group, member, controller, context) => [
                CometChatOption(id: 'ADD_OPT', title: 'AddedOption'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(find.text('AddedOption'), findsOneWidget);
    });
  });

  group('scrolling', () {
    testWidgets('controller is attached to the member list', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              controller: controller,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(controller.hasClients, isTrue);
    });
  });
}
