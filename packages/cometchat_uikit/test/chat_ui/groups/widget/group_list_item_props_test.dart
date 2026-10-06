/// Render-verified prop matrix for [CometChatGroupListItem] and
/// [CometChatGroupListItemStyle] — Track 3 PROP1 (ENG-38688, coverage
/// part 2).
///
/// Follows `conversations_props_test.dart` and `users_props_test.dart`: each
/// case sets one prop (or one tightly coupled pair) to a sentinel no theme
/// uses, pumps the item, and asserts at the render site the prop is routed
/// to: the row Container, the title or subtitle Text, the Checkbox, the
/// CometChatAvatar or the CometChatStatusIndicator. Every assertion fails if
/// the item stopped reading the prop.
///
/// [CometChatGroupListItemStyle] is plain data with one reader, so its cases
/// go through [CometChatGroupListItem.style].
///
///   flutter test test/chat_ui/groups/widget/group_list_item_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class FakeGroup extends Fake implements Group {
  FakeGroup({
    this.name = 'Harbor Crew',
    this.guid = 'g1',
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

BuildContext _itemContext(WidgetTester tester) =>
    tester.element(find.byType(CometChatGroupListItem));

Translations _l10n(WidgetTester tester) =>
    Translations.of(_itemContext(tester));

/// The row's own box: the Container whose child is the item's Row.
Finder _rowBox() =>
    find.byWidgetPredicate((w) => w is Container && w.child is Row);

Container _row(WidgetTester tester) => tester.widget<Container>(_rowBox());

Finder _rowContent() =>
    find.descendant(of: _rowBox(), matching: find.byType(Row)).first;

InkWell _inkWell(WidgetTester tester) => tester.widget<InkWell>(
  find
      .descendant(
        of: find.byType(CometChatGroupListItem),
        matching: find.byType(InkWell),
      )
      .first,
);

BoxDecoration _avatarBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(CometChatAvatar),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Finder _avatarClip() => find.descendant(
  of: find.byType(CometChatAvatar),
  matching: find.byType(ClipRRect),
);

Text _initials(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byType(CometChatAvatar),
    matching: find.byType(Text),
  ),
);

BoxDecoration _badgeBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(CometChatStatusIndicator),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Checkbox _checkbox(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox));

void main() {
  // ===========================================================================
  group('CometChatGroupListItem', () {
    testWidgets('group: its name, initials, member count and type render', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(
                name: 'Quartz Lagoon',
                type: CometChatGroupType.private,
                membersCount: 7,
              ),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quartz Lagoon'), findsOneWidget);
      expect(find.text('7 ${_l10n(tester).members}'), findsOneWidget);
      expect(_initials(tester).data, 'QL');
      // A private group carries the type badge.
      expect(find.byType(CometChatStatusIndicator), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(name: 'Solo Cove', membersCount: 1),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quartz Lagoon'), findsNothing);
      expect(find.text('Solo Cove'), findsOneWidget);
      expect(find.text('1 ${_l10n(tester).member}'), findsOneWidget);
      expect(_initials(tester).data, 'SC');
      // A public group carries none.
      expect(find.byType(CometChatStatusIndicator), findsNothing);
    });

    testWidgets('onItemClick: a tap reports the group', (tester) async {
      Group? clicked;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-click'),
              onItemClick: (g) => clicked = g,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(clicked, isNull);

      await tester.tap(find.byType(CometChatGroupListItem));
      await tester.pump();

      expect(clicked?.guid, 'g-click');
    });

    testWidgets(
      'onItemLongClick: unwired by default, reports the group when set',
      (tester) async {
        var clicks = 0;
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(guid: 'g-long'),
                onItemClick: (_) => clicks++,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_inkWell(tester).onLongPress, isNull);

        Group? pressed;
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(guid: 'g-long'),
                onItemClick: (_) => clicks++,
                onItemLongClick: (g) => pressed = g,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.longPress(find.byType(CometChatGroupListItem));
        await tester.pump();

        expect(pressed?.guid, 'g-long');
        expect(clicks, 0);
      },
    );

    testWidgets('onSelectionToggle: the checkbox fires it, not onItemClick', (
      tester,
    ) async {
      var toggles = 0;
      var clicks = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) => clicks++,
              selectionMode: SelectionMode.multiple,
              onSelectionToggle: () => toggles++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(toggles, 1);
      expect(clicks, 0);
    });

    testWidgets(
      'isSelected: swaps background4 in for background1 and ticks the box',
      (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
              ),
            ),
          ),
        );
        await tester.pump();
        final palette = CometChatThemeHelper.getColorPalette(
          _itemContext(tester),
        );
        final unselected = _row(tester).color;
        expect(unselected, palette.background1);
        expect(_checkbox(tester).value, isFalse);

        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                isSelected: true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_row(tester).color, palette.background4);
        expect(_row(tester).color, isNot(unselected));
        expect(_checkbox(tester).value, isTrue);
      },
    );

    testWidgets('selectionMode: none hides the checkbox, single and multiple '
        'show it', (tester) async {
      const expected = {
        SelectionMode.none: 0,
        SelectionMode.single: 1,
        SelectionMode.multiple: 1,
      };
      for (final entry in expected.entries) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: entry.key,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byType(Checkbox).evaluate().length,
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    testWidgets('hideGroupTypeIcon: the private and password badges show by '
        'default and hide when set', (tester) async {
      for (final type in [
        CometChatGroupType.private,
        CometChatGroupType.password,
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: type),
                onItemClick: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CometChatStatusIndicator), findsOneWidget);

        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: type),
                onItemClick: (_) {},
                hideGroupTypeIcon: true,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CometChatStatusIndicator), findsNothing);
      }
    });

    testWidgets('style: replaces the theme-derived style', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(group: FakeGroup(), onItemClick: (_) {}),
          ),
        ),
      );
      await tester.pump();
      final themed = _row(tester).color;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              style: const CometChatGroupListItemStyle(
                backgroundColor: Color(0xFF1A2B3C),
                titleTextColor: Color(0xFF2C1B0A),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(themed, isNot(const Color(0xFF1A2B3C)));
      expect(_row(tester).color, const Color(0xFF1A2B3C));
      expect(
        tester.widget<Text>(find.text('Harbor Crew')).style?.color,
        const Color(0xFF2C1B0A),
      );
    });

    testWidgets('avatarStyle: paints the avatar and wins over '
        'style.avatarStyle', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              avatarStyle: CometChatAvatarStyle(
                backgroundColor: const Color(0xFF3E4F60),
                border: Border.all(color: const Color(0xFF605F4E), width: 2),
                placeHolderTextColor: const Color(0xFF4E3F2D),
              ),
              style: const CometChatGroupListItemStyle(
                avatarStyle: CometChatAvatarStyle(
                  backgroundColor: Color(0xFF0D0E0F),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_avatarBox(tester).color, const Color(0xFF3E4F60));
      expect(
        _avatarBox(tester).border,
        Border.all(color: const Color(0xFF605F4E), width: 2),
      );
      expect(_initials(tester).style?.color, const Color(0xFF4E3F2D));
    });

    testWidgets('statusIndicatorStyle: its border reaches the badge and wins '
        'over style.statusIndicatorStyle', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              onItemClick: (_) {},
              statusIndicatorStyle: CometChatStatusIndicatorStyle(
                border: Border.all(color: const Color(0xFF718293), width: 3),
              ),
              style: CometChatGroupListItemStyle(
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  border: Border.all(color: const Color(0xFF0E0D0C)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _badgeBox(tester).border,
        Border.all(color: const Color(0xFF718293), width: 3),
      );
    });

    testWidgets('avatarHeight and avatarWidth size the avatar (default '
        '48x48)', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(group: FakeGroup(), onItemClick: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(CometChatAvatar)), const Size(48, 48));

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              avatarHeight: 63,
              avatarWidth: 57,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(CometChatAvatar)), const Size(57, 63));
    });

    testWidgets('avatarPadding insets the avatar content inside its box', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(group: FakeGroup(), onItemClick: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(_avatarClip()), const Size(48, 48));

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              avatarPadding: const EdgeInsets.fromLTRB(3, 5, 7, 9),
            ),
          ),
        ),
      );
      await tester.pump();

      // The box keeps its 48x48; the content shrinks by the padding.
      expect(tester.getSize(find.byType(CometChatAvatar)), const Size(48, 48));
      expect(tester.getSize(_avatarClip()), const Size(38, 34));
    });

    testWidgets('avatarMargin adds space outside the avatar box', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              avatarMargin: const EdgeInsets.fromLTRB(2, 4, 6, 8),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(CometChatAvatar)), const Size(56, 60));
      expect(tester.getSize(_avatarClip()), const Size(48, 48));
      expect(
        tester.getTopLeft(_avatarClip()) -
            tester.getTopLeft(find.byType(CometChatAvatar)),
        const Offset(2, 4),
      );
    });

    testWidgets('statusIndicatorHeight and statusIndicatorWidth size the '
        'badge (default 14x14)', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(CometChatStatusIndicator)),
        const Size(14, 14),
      );

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              onItemClick: (_) {},
              statusIndicatorHeight: 17,
              statusIndicatorWidth: 19,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(CometChatStatusIndicator)),
        const Size(19, 17),
      );
    });

    testWidgets('leadingView replaces the avatar and receives the group; a '
        'null result falls back to it', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-lead'),
              onItemClick: (_) {},
              leadingView: (g) => Text('lead-${g.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('lead-g-lead'), findsOneWidget);
      expect(find.byType(CometChatAvatar), findsNothing);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-lead'),
              onItemClick: (_) {},
              leadingView: (_) => null,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatAvatar), findsOneWidget);
    });

    testWidgets('titleView replaces the group name', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-title'),
              onItemClick: (_) {},
              titleView: (g) => Text('title-${g.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('title-g-title'), findsOneWidget);
      expect(find.text('Harbor Crew'), findsNothing);
    });

    testWidgets('subtitleView replaces the member count', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-sub'),
              onItemClick: (_) {},
              subtitleView: (g) => Text('sub-${g.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub-g-sub'), findsOneWidget);
      expect(find.text('5 ${_l10n(tester).members}'), findsNothing);
      expect(find.text('Harbor Crew'), findsOneWidget);
    });

    testWidgets('trailingView adds a widget after the text column', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(guid: 'g-trail'),
              onItemClick: (_) {},
              trailingView: (g) => Text('trail-${g.guid}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('trail-g-trail'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('trail-g-trail')).dx,
        greaterThan(tester.getTopRight(find.text('Harbor Crew')).dx),
      );
    });

    testWidgets('colorPalette colours the badge: warning for private, success '
        'for password, background1 for the glyph and ring', (tester) async {
      for (final entry in {
        CometChatGroupType.private: (const Color(0xFFA1B2C3), Icons.shield),
        CometChatGroupType.password: (const Color(0xFFC3B2A1), Icons.lock),
      }.entries) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: entry.key),
                onItemClick: (_) {},
                colorPalette: CometChatColorPalette(
                  warning: const Color(0xFFA1B2C3),
                  success: const Color(0xFFC3B2A1),
                  background1: const Color(0xFFB2A1C3),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final (badge, glyph) = entry.value;
        expect(_badgeBox(tester).color, badge, reason: entry.key);
        expect(
          _badgeBox(tester).border?.top.color,
          const Color(0xFFB2A1C3),
          reason: entry.key,
        );
        expect(
          tester.widget<Icon>(find.byIcon(glyph)).color,
          const Color(0xFFB2A1C3),
          reason: entry.key,
        );
      }
    });

    testWidgets('spacing pads the row: padding4 across, padding3 down', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(group: FakeGroup(), onItemClick: (_) {}),
          ),
        ),
      );
      await tester.pump();
      final themed =
          tester.getTopLeft(_rowContent()) - tester.getTopLeft(_rowBox());

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              spacing: CometChatSpacing(padding3: 11, padding4: 23),
            ),
          ),
        ),
      );
      await tester.pump();

      final inset =
          tester.getTopLeft(_rowContent()) - tester.getTopLeft(_rowBox());
      expect(inset, const Offset(23, 11));
      expect(inset, isNot(themed));
    });

    testWidgets('typography sizes the avatar initials from heading2.bold', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              typography: const CometChatTypography(
                heading2: CometChatTextStyleHeading2(
                  bold: TextStyle(fontSize: 31.5),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_initials(tester).style?.fontSize, 31.5);
    });

    testWidgets('privateGroupIcon replaces the shield on a private group', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.shield), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              onItemClick: (_) {},
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
          of: find.byType(CometChatStatusIndicator),
          matching: find.byKey(const ValueKey('private-glyph')),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shield), findsNothing);
    });

    testWidgets('protectedGroupIcon replaces the lock on a password group', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.password),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.lock), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.password),
              onItemClick: (_) {},
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
          of: find.byType(CometChatStatusIndicator),
          matching: find.byKey(const ValueKey('protected-glyph')),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock), findsNothing);
    });
  });

  // ===========================================================================
  group(
    'CometChatGroupListItemStyle, through CometChatGroupListItem.style',
    () {
      testWidgets('backgroundColor paints an unselected row', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  backgroundColor: Color(0xFF123456),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_row(tester).color, const Color(0xFF123456));
      });

      testWidgets('selectedBackgroundColor paints a selected row, and only a '
          'selected one', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                isSelected: true,
                style: const CometChatGroupListItemStyle(
                  selectedBackgroundColor: Color(0xFF234567),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_row(tester).color, const Color(0xFF234567));

        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  selectedBackgroundColor: Color(0xFF234567),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_row(tester).color, isNot(const Color(0xFF234567)));
      });

      testWidgets('titleTextStyle styles the group name', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  titleTextStyle: TextStyle(
                    fontSize: 21.5,
                    letterSpacing: 1.75,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final title = tester.widget<Text>(find.text('Harbor Crew'));
        expect(title.style?.fontSize, 21.5);
        expect(title.style?.letterSpacing, 1.75);
      });

      testWidgets('titleTextColor colours the group name', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  titleTextColor: Color(0xFF345678),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.widget<Text>(find.text('Harbor Crew')).style?.color,
          const Color(0xFF345678),
        );
      });

      testWidgets('subtitleTextStyle styles the member count', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  subtitleTextStyle: TextStyle(
                    fontSize: 13.5,
                    letterSpacing: 0.85,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final subtitle = tester.widget<Text>(
          find.text('5 ${_l10n(tester).members}'),
        );
        expect(subtitle.style?.fontSize, 13.5);
        expect(subtitle.style?.letterSpacing, 0.85);
      });

      testWidgets('subtitleTextColor colours the member count', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  subtitleTextColor: Color(0xFF456789),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester
              .widget<Text>(find.text('5 ${_l10n(tester).members}'))
              .style
              ?.color,
          const Color(0xFF456789),
        );
      });

      testWidgets('avatarStyle reaches the avatar when the item sets none', (
        tester,
      ) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                style: const CometChatGroupListItemStyle(
                  avatarStyle: CometChatAvatarStyle(
                    backgroundColor: Color(0xFF56789A),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_avatarBox(tester).color, const Color(0xFF56789A));
        expect(
          _avatarBox(tester).borderRadius,
          const BorderRadius.all(Radius.circular(6)),
        );
      });

      testWidgets('statusIndicatorStyle border reaches the badge when the item '
          'sets none', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: CometChatGroupType.password),
                onItemClick: (_) {},
                style: CometChatGroupListItemStyle(
                  statusIndicatorStyle: CometChatStatusIndicatorStyle(
                    border: Border.all(
                      color: const Color(0xFF6789AB),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          _badgeBox(tester).border,
          Border.all(color: const Color(0xFF6789AB), width: 2.5),
        );
      });

      testWidgets('checkBoxBackgroundColor fills an unticked checkbox only', (
        tester,
      ) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                style: const CometChatGroupListItemStyle(
                  checkBoxBackgroundColor: Color(0xFF789ABC),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final fill = _checkbox(tester).fillColor!;
        expect(fill.resolve(<WidgetState>{}), const Color(0xFF789ABC));
        expect(
          fill.resolve({WidgetState.selected}),
          isNot(const Color(0xFF789ABC)),
        );
      });

      testWidgets('checkBoxCheckedBackgroundColor fills a ticked checkbox', (
        tester,
      ) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                isSelected: true,
                style: const CometChatGroupListItemStyle(
                  checkBoxCheckedBackgroundColor: Color(0xFF89ABCD),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final checkbox = _checkbox(tester);
        expect(checkbox.value, isTrue);
        expect(
          checkbox.fillColor!.resolve({WidgetState.selected}),
          const Color(0xFF89ABCD),
        );
      });

      testWidgets('checkBoxBorderRadius rounds the checkbox', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                style: const CometChatGroupListItemStyle(
                  checkBoxBorderRadius: BorderRadius.all(Radius.circular(5.5)),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          (_checkbox(tester).shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(5.5)),
        );
      });

      testWidgets('checkBoxStrokeColor colours the checkbox side', (
        tester,
      ) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                style: const CometChatGroupListItemStyle(
                  checkBoxStrokeColor: Color(0xFF9ABCDE),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_checkbox(tester).side?.color, const Color(0xFF9ABCDE));
      });

      testWidgets('checkBoxStrokeWidth sets the checkbox side width', (
        tester,
      ) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                selectionMode: SelectionMode.multiple,
                style: const CometChatGroupListItemStyle(
                  checkBoxStrokeWidth: 2.75,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_checkbox(tester).side?.width, 2.75);
      });
    },
  );

  group('status dot and check mark', () {
    testWidgets('statusIndicatorBorderRadius rounds the status dot', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: CometChatGroupType.private),
              statusIndicatorBorderRadius: const BorderRadius.all(
                Radius.circular(5),
              ),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(
        dot.style?.borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
    });
    testWidgets('style.checkBoxCheckColor colours the check mark', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              selectionMode: SelectionMode.multiple,
              isSelected: true,
              style: const CometChatGroupListItemStyle(
                checkBoxCheckColor: Color(0xFFF1E2D3),
              ),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_checkbox(tester).checkColor, const Color(0xFFF1E2D3));
    });
    testWidgets(
      'style.privateGroupIconBackground paints the dot of a private group',
      (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: CometChatGroupType.private),
                style: const CometChatGroupListItemStyle(
                  privateGroupIconBackground: Color(0xFFE2D3C4),
                ),
                onItemClick: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        final dot = tester.widget<CometChatStatusIndicator>(
          find.byType(CometChatStatusIndicator),
        );
        expect(dot.style?.backgroundColor, const Color(0xFFE2D3C4));
      },
    );
    testWidgets(
      'style.protectedGroupIconBackground paints the dot of a password group',
      (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatGroupListItem(
                group: FakeGroup(type: CometChatGroupType.password),
                style: const CometChatGroupListItemStyle(
                  protectedGroupIconBackground: Color(0xFFD3C4B5),
                ),
                onItemClick: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        final dot = tester.widget<CometChatStatusIndicator>(
          find.byType(CometChatStatusIndicator),
        );
        expect(dot.style?.backgroundColor, const Color(0xFFD3C4B5));
      },
    );
  });
}
