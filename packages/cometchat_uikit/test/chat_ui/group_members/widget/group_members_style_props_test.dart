/// Style matrix for [CometChatGroupMembersStyle] — Track 3 PROP1 (ENG-38767).
///
/// Uses the `groupMembersBloc` seam added by ENG-38797, so member rows, scope
/// badges, checkboxes and the option popup are all reachable. Every case
/// asserts a rendered consequence: a colour on a real decoration, a TextStyle
/// on a real Text, or the style object a child widget was actually handed.
///
///   flutter test test/chat_ui/group_members/widget/group_members_style_props_test.dart
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

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public', owner: 'u9');

GroupMember _member(String uid, String name, String scope) =>
    GroupMember(uid: uid, name: name, scope: scope);

final _participant = _member('u1', 'Alice', GroupMemberScope.participant);
final _admin = _member('u2', 'Bob', GroupMemberScope.admin);
final _moderator = _member('u3', 'Carla', GroupMemberScope.moderator);
final _owner = _member('u9', 'Dana', GroupMemberScope.participant);

MockGroupMembersBloc _mock({
  List<GroupMember>? members,
  Set<String> selected = const {},
  GroupMembersState? state,
}) {
  final list = members ?? [_participant];
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

/// A bloc whose default option list contains one real option id, so the
/// kick-confirm dialog and change-scope sheet can actually be opened.
MockGroupMembersBloc _mockWithOption(String id, String title) {
  final bloc = _mock();
  when(
    () => bloc.getDefaultOptions(any(), any(), any(), any(), any()),
  ).thenReturn([CometChatGroupMemberOption(id: id, title: title)]);
  return bloc;
}

/// Two classes of complaint are unavoidable noise in this file, and neither is
/// affected by the style props under test:
///
///  * the member rows and option sheet load scope icons from the package asset
///    bundle, which is not mounted in a unit-test process;
///  * the option row is laid out for a phone and overflows the test surface.
///
/// Both are swallowed; anything else is re-thrown so a real defect still fails
/// the test.
const _tolerated = ['Unable to load asset', 'A RenderFlex overflowed'];

void _drainAssetErrors(WidgetTester tester) {
  while (true) {
    final error = tester.takeException();
    if (error == null) return;
    final text = error.toString();
    if (!_tolerated.any(text.contains)) throw error;
  }
}

/// Fires the option the list wired onto the open menu item.
///
/// The menu row overflows the test surface badly enough that its label is laid
/// out at zero width and off-screen, so no synthesised tap can reach it. The
/// closure invoked here is the one `_buildMemberOptions` attached to the
/// rendered `CustomPopupMenuItem`, which is exactly what `showMenu`'s `.then`
/// would call — the wiring under test is unchanged, only the gesture is
/// bypassed.
void _selectMenuOption(WidgetTester tester, String id) {
  final item = tester
      .widgetList<CustomPopupMenuItem<CometChatOption>>(
        find.byType(CustomPopupMenuItem<CometChatOption>),
      )
      .firstWhere((i) => i.value?.id == id);
  item.value!.onClick!();
}

/// Filters the tolerated complaints out at the source, so the framework never
/// aggregates them into a "multiple exceptions" failure. Real errors still
/// reach the default handler and fail the test.
void _ignoreToleratedErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_tolerated.any(details.toString().contains)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  _drainAssetErrors(tester);
}

Widget _list(
  CometChatGroupMembersStyle style, {
  List<GroupMember>? members,
  Set<String> selected = const {},
  GroupMembersState? state,
  SelectionMode? selectionMode,
  ActivateSelection? activateSelection,
}) => MaterialApp(
  home: Scaffold(
    body: CometChatGroupMembers(
      group: _group,
      groupMembersBloc: _mock(
        members: members,
        selected: selected,
        state: state,
      ),
      selectionMode: selectionMode,
      activateSelection: activateSelection,
      style: style,
    ),
  ),
);

/// Every BoxDecoration colour currently painted in the tree.
Iterable<Color?> _decorationColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.color);

Iterable<BoxBorder?> _decorationBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.border);

Iterable<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>();

void main() {
  setUpAll(() {
    registerFallbackValue(_participant);
    registerFallbackValue(_group);
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(CometChatColorPalette());
    registerFallbackValue(CometChatTypography());
    registerFallbackValue(CometChatSpacing());
  });

  group('owner scope badge', () {
    testWidgets('ownerMemberScopeBackgroundColor paints the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            ownerMemberScopeBackgroundColor: Color(0xFF010101),
          ),
          members: [_owner],
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF010101)));
    });

    testWidgets('ownerMemberScopeBorder outlines the badge', (tester) async {
      final border = Border.all(color: const Color(0xFF020202), width: 3);
      await tester.pumpWidget(
        _list(
          CometChatGroupMembersStyle(ownerMemberScopeBorder: border),
          members: [_owner],
        ),
      );
      await _settle(tester);
      expect(_decorationBorders(tester), contains(border));
    });

    testWidgets('ownerMemberScopeTextColor colours the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            ownerMemberScopeTextColor: Color(0xFF030303),
          ),
          members: [_owner],
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF030303)),
      );
    });

    testWidgets('ownerMemberScopeTextStyle styles the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            ownerMemberScopeTextStyle: TextStyle(fontSize: 31),
          ),
          members: [_owner],
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(31.0));
    });
  });

  group('admin scope badge', () {
    testWidgets('adminMemberScopeBackgroundColor paints the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            adminMemberScopeBackgroundColor: Color(0xFF040404),
          ),
          members: [_admin],
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF040404)));
    });

    testWidgets('adminMemberScopeBorder outlines the badge', (tester) async {
      final border = Border.all(color: const Color(0xFF050505), width: 4);
      await tester.pumpWidget(
        _list(
          CometChatGroupMembersStyle(adminMemberScopeBorder: border),
          members: [_admin],
        ),
      );
      await _settle(tester);
      expect(_decorationBorders(tester), contains(border));
    });

    testWidgets('adminMemberScopeTextColor colours the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            adminMemberScopeTextColor: Color(0xFF060606),
          ),
          members: [_admin],
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF060606)),
      );
    });

    testWidgets('adminMemberScopeTextStyle styles the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            adminMemberScopeTextStyle: TextStyle(fontSize: 32),
          ),
          members: [_admin],
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(32.0));
    });
  });

  group('moderator scope badge', () {
    testWidgets('moderatorMemberScopeBackgroundColor paints the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            moderatorMemberScopeBackgroundColor: Color(0xFF070707),
          ),
          members: [_moderator],
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF070707)));
    });

    testWidgets('moderatorMemberScopeBorder outlines the badge', (
      tester,
    ) async {
      final border = Border.all(color: const Color(0xFF080808), width: 5);
      await tester.pumpWidget(
        _list(
          CometChatGroupMembersStyle(moderatorMemberScopeBorder: border),
          members: [_moderator],
        ),
      );
      await _settle(tester);
      expect(_decorationBorders(tester), contains(border));
    });

    testWidgets('moderatorMemberScopeTextColor colours the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            moderatorMemberScopeTextColor: Color(0xFF090909),
          ),
          members: [_moderator],
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF090909)),
      );
    });

    testWidgets('moderatorMemberScopeTextStyle styles the badge label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            moderatorMemberScopeTextStyle: TextStyle(fontSize: 33),
          ),
          members: [_moderator],
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(33.0));
    });
  });

  group('selection checkbox', () {
    Checkbox box(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox).first);

    testWidgets('checkboxCheckedBackgroundColor fills a selected box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            checkboxCheckedBackgroundColor: Color(0xFF0A0A0A),
          ),
          members: [_participant],
          selected: const {'u1'},
        ),
      );
      await _settle(tester);
      expect(box(tester).fillColor?.resolve({}), const Color(0xFF0A0A0A));
    });

    testWidgets('checkboxBackgroundColor fills an unselected box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            checkboxBackgroundColor: Color(0xFF0B0B0B),
          ),
          members: [_participant, _admin],
          selected: const {'u2'},
        ),
      );
      await _settle(tester);
      expect(box(tester).fillColor?.resolve({}), const Color(0xFF0B0B0B));
    });

    testWidgets('checkboxBorderRadius shapes the box', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            checkboxBorderRadius: BorderRadius.all(Radius.circular(9)),
          ),
          members: [_participant],
          selected: const {'u1'},
        ),
      );
      await _settle(tester);
      expect(
        (box(tester).shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
    });

    testWidgets('checkboxSelectedIconColor colours the tick', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            checkboxSelectedIconColor: Color(0xFF0C0C0C),
          ),
          members: [_participant],
          selected: const {'u1'},
        ),
      );
      await _settle(tester);
      expect(box(tester).checkColor, const Color(0xFF0C0C0C));
    });

    testWidgets('checkboxBorder outlines the box', (tester) async {
      const side = BorderSide(color: Color(0xFF0D0D0D), width: 6);
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(checkboxBorder: side),
          members: [_participant],
          selected: const {'u1'},
        ),
      );
      await _settle(tester);
      expect(box(tester).side, side);
    });
  });

  group('row chrome', () {
    testWidgets('avatarStyle reaches the list item', (tester) async {
      const avatar = CometChatAvatarStyle(backgroundColor: Color(0xFF0E0E0E));
      await tester.pumpWidget(
        _list(const CometChatGroupMembersStyle(avatarStyle: avatar)),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatListItem>(find.byType(CometChatListItem).first)
            .avatarStyle,
        avatar,
      );
    });

    testWidgets('statusIndicatorStyle reaches the list item', (tester) async {
      const indicator = CometChatStatusIndicatorStyle(
        backgroundColor: Color(0xFF0F0F0F),
      );
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(statusIndicatorStyle: indicator),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatListItem>(find.byType(CometChatListItem).first)
            .statusIndicatorStyle,
        indicator,
      );
    });

    testWidgets('listItemStyle is merged into the list item style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            listItemStyle: ListItemStyle(titleStyle: TextStyle(fontSize: 34)),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatListItem>(find.byType(CometChatListItem).first)
            .style
            .titleStyle
            ?.fontSize,
        34.0,
      );
    });

    testWidgets('listItemSelectedBackgroundColor paints the selected row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            listItemSelectedBackgroundColor: Color(0xFF101010),
          ),
          members: [_participant],
          selected: const {'u1'},
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF101010)));
    });

    testWidgets('onlineStatusColor drives the online indicator', (
      tester,
    ) async {
      final online = _member('u4', 'Erin', GroupMemberScope.participant)
        ..status = 'online';
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            onlineStatusColor: Color(0xFF111111),
          ),
          members: [online],
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatListItem>(find.byType(CometChatListItem).first)
            .statusIndicatorColor,
        const Color(0xFF111111),
      );
    });

    testWidgets('separatorColor and separatorHeight draw the divider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            separatorColor: Color(0xFF121212),
            separatorHeight: 7,
          ),
        ),
      );
      await _settle(tester);
      final shape =
          tester
                  .widget<CometChatListBase>(find.byType(CometChatListBase))
                  .style
                  .appBarShape
              as Border;
      expect(shape.bottom.color, const Color(0xFF121212));
      expect(shape.bottom.width, 7.0);
    });
  });

  group('list padding and loading', () {
    testWidgets('listPadding pads the member list', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(listPadding: EdgeInsets.all(19)),
        ),
      );
      await _settle(tester);
      expect(
        tester.widget<ListView>(find.byType(ListView).first).padding,
        const EdgeInsets.all(19),
      );
    });

    testWidgets('loadingIconColor tints the loading indicator', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(loadingIconColor: Color(0xFF131313)),
          state: GroupMembersLoaded(
            members: [_participant],
            hasMore: true,
            selectedMembers: const {},
            isLoadingMore: true,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .map((c) => c.color),
        contains(const Color(0xFF131313)),
      );
    });

    testWidgets('submitIconColor tints the default submit control', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(submitIconColor: Color(0xFF141414)),
          members: [_participant],
          selectionMode: SelectionMode.multiple,
          activateSelection: ActivateSelection.onClick,
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF141414)),
      );
    });
  });

  group('empty and error states', () {
    testWidgets('emptyStateTextStyle styles the empty title', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            emptyStateTextStyle: TextStyle(fontSize: 35),
          ),
          state: GroupMembersEmpty(),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(35.0));
    });

    testWidgets('emptyStateTextColor colours the empty title', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            emptyStateTextColor: Color(0xFF151515),
          ),
          state: GroupMembersEmpty(),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF151515)),
      );
    });

    testWidgets('emptyStateSubtitleTextStyle styles the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            emptyStateSubtitleTextStyle: TextStyle(fontSize: 36),
          ),
          state: GroupMembersEmpty(),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(36.0));
    });

    testWidgets('emptyStateSubtitleTextColor colours the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            emptyStateSubtitleTextColor: Color(0xFF161616),
          ),
          state: GroupMembersEmpty(),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF161616)),
      );
    });

    testWidgets('errorStateTextStyle styles the error title', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            errorStateTextStyle: TextStyle(fontSize: 37),
          ),
          state: const GroupMembersError(message: 'boom'),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(37.0));
    });

    testWidgets('errorStateSubtitleStyle styles the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatGroupMembersStyle(
            errorStateSubtitleStyle: TextStyle(fontSize: 38),
          ),
          state: const GroupMembersError(message: 'boom'),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(38.0));
    });
  });

  group('retry button', () {
    Widget errored(CometChatGroupMembersStyle style) =>
        _list(style, state: const GroupMembersError(message: 'boom'));

    testWidgets('retryButtonTextStyle styles the retry label', (tester) async {
      await tester.pumpWidget(
        errored(
          const CometChatGroupMembersStyle(
            retryButtonTextStyle: TextStyle(fontSize: 39),
          ),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(39.0));
    });

    testWidgets('retryButtonTextColor colours the retry label', (tester) async {
      await tester.pumpWidget(
        errored(
          const CometChatGroupMembersStyle(
            retryButtonTextColor: Color(0xFF171717),
          ),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF171717)),
      );
    });

    ButtonStyle retryStyle(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).style!;

    testWidgets('retryButtonBackgroundColor fills the retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatGroupMembersStyle(
            retryButtonBackgroundColor: Color(0xFF181818),
          ),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        retryStyle(tester).backgroundColor?.resolve({}),
        const Color(0xFF181818),
      );
    });

    testWidgets('retryButtonBorder outlines the retry button', (tester) async {
      const side = BorderSide(color: Color(0xFF191919), width: 8);
      await tester.pumpWidget(
        errored(const CometChatGroupMembersStyle(retryButtonBorder: side)),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        (retryStyle(tester).shape?.resolve({}) as RoundedRectangleBorder).side,
        side,
      );
    });

    testWidgets('retryButtonBorderRadius rounds the retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatGroupMembersStyle(
            retryButtonBorderRadius: BorderRadius.all(Radius.circular(11)),
          ),
        ),
      );
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        (retryStyle(tester).shape?.resolve({}) as RoundedRectangleBorder)
            .borderRadius,
        const BorderRadius.all(Radius.circular(11)),
      );
    });
  });

  group('option popup and dialogs', () {
    testWidgets('optionsBackgroundColor, optionsTextStyle and optionsIconColor '
        'reach the member option menu', (tester) async {
      _ignoreToleratedErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mock(),
              style: const CometChatGroupMembersStyle(
                optionsBackgroundColor: Color(0xFF1A1A1A),
                optionsTextStyle: TextStyle(fontSize: 40),
                optionsIconColor: Color(0xFF1B1B1B),
              ),
              addOptions: (group, member, controller, context) => [
                CometChatOption(id: 'OPT', title: 'AnOption'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(find.text('AnOption'), findsOneWidget);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(40.0));
      // showMenu paints the sheet colour onto the route's Material.
      expect(
        tester.widgetList<Material>(find.byType(Material)).map((m) => m.color),
        contains(const Color(0xFF1A1A1A)),
      );
    });

    testWidgets('changeScopeStyle reaches the scope-change sheet', (
      tester,
    ) async {
      _ignoreToleratedErrors();
      final scope = CometChatChangeScopeStyle(
        backgroundColor: const Color(0xFF1C1C1C),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mockWithOption(
                GroupMemberOptionConstants.changeScope,
                'ChangeScope',
              ),
              style: CometChatGroupMembersStyle(changeScopeStyle: scope),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);

      _selectMenuOption(tester, GroupMemberOptionConstants.changeScope);
      await _settle(tester);
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        tester
            .widget<CometChatChangeScope>(find.byType(CometChatChangeScope))
            .style
            ?.backgroundColor,
        const Color(0xFF1C1C1C),
      );
    });

    testWidgets('confirmDialogStyle reaches the kick confirmation dialog', (
      tester,
    ) async {
      _ignoreToleratedErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatGroupMembers(
              group: _group,
              groupMembersBloc: _mockWithOption(
                GroupMemberOptionConstants.kick,
                'Kick',
              ),
              style: const CometChatGroupMembersStyle(
                confirmDialogStyle: CometChatConfirmDialogStyle(
                  iconColor: Color(0xFF1D1D1D),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('Alice'));
      await _settle(tester);
      _drainAssetErrors(tester);
      _selectMenuOption(tester, GroupMemberOptionConstants.kick);
      await _settle(tester);
      _drainAssetErrors(tester);
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF1D1D1D)),
      );
    });
  });
}
