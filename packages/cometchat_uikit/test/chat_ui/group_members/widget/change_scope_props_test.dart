/// Render-verified prop matrix for [CometChatChangeScopeStyle] and
/// [CometChatChangeScope] — Track 3 PROP1/PROP2 (ENG-38929).
///
/// The sheet renders every branch it has in a single pump: the header icon,
/// the three scope tiles (one of them selected, since the member arrives with
/// a scope), and the Cancel/Save pair. So every property is reachable from one
/// fixture, varying only the style.
///
///   flutter test test/chat_ui/group_members/widget/change_scope_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _group = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);

/// A participant, so exactly one of the three scope tiles renders selected and
/// the other two render unselected — both branches in one pump.
final _member = GroupMember(
  uid: 'u2',
  name: 'Bob',
  scope: GroupMemberScope.participant,
);

Widget _sheet(CometChatChangeScopeStyle style, {EdgeInsetsGeometry? padding}) =>
    MaterialApp(
      home: Scaffold(
        body: CometChatChangeScope(
          group: _group,
          member: _member,
          style: style,
          padding: padding,
        ),
      ),
    );

Iterable<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.color);

Iterable<BoxBorder?> _boxBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.border);

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

/// The radio fill is a WidgetStatePropertyAll, so resolve it to a plain colour.
Iterable<Color?> _radioFills(WidgetTester tester) => tester
    .widgetList<Radio<String>>(find.byType(Radio<String>))
    .map((r) => r.fillColor?.resolve(<WidgetState>{}));

Iterable<TextButton> _buttons(WidgetTester tester) =>
    tester.widgetList<TextButton>(find.byType(TextButton));

Iterable<Color?> _buttonBackgrounds(WidgetTester tester) => _buttons(
  tester,
).map((b) => b.style?.backgroundColor?.resolve(<WidgetState>{}));

Iterable<Color?> _buttonSideColors(WidgetTester tester) =>
    _buttons(tester).map((b) => b.style?.side?.resolve(<WidgetState>{})?.color);

Iterable<BorderRadiusGeometry?> _buttonRadii(WidgetTester tester) =>
    _buttons(tester).map((b) {
      final shape = b.style?.shape?.resolve(<WidgetState>{});
      return shape is RoundedRectangleBorder ? shape.borderRadius : null;
    });

void main() {
  group('the sheet header', () {
    testWidgets('backgroundColor', (tester) async {
      await tester.pumpWidget(
        _sheet(CometChatChangeScopeStyle(backgroundColor: Color(0xFF150101))),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF150101)));
    });

    testWidgets('border', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF150202), width: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF150202), width: 3),
          ),
        ),
      );
    });

    testWidgets('borderRadius', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            borderRadius: BorderRadius.all(Radius.circular(35)),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .map((c) => c.borderRadius),
        contains(const BorderRadius.all(Radius.circular(35))),
      );
    });

    testWidgets('titleTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(titleTextStyle: TextStyle(fontSize: 31)),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(31.0));
    });

    testWidgets('subtitleTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(subtitleTextStyle: TextStyle(fontSize: 17)),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(17.0));
    });

    testWidgets('iconBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(iconBackgroundColor: Color(0xFF150303)),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF150303)));
    });

    testWidgets('iconColor', (tester) async {
      await tester.pumpWidget(
        _sheet(CometChatChangeScopeStyle(iconColor: Color(0xFF150404))),
      );
      await tester.pump();
      expect(
        tester.widgetList<Image>(find.byType(Image)).map((i) => i.color),
        contains(const Color(0xFF150404)),
      );
    });
  });

  group('the scope tiles', () {
    testWidgets('scopeSectionBorder', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            scopeSectionBorder: Border.fromBorderSide(
              BorderSide(color: Color(0xFF150505), width: 4),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF150505), width: 4),
          ),
        ),
      );
    });

    testWidgets('tileColor', (tester) async {
      await tester.pumpWidget(
        _sheet(CometChatChangeScopeStyle(tileColor: Color(0xFF150606))),
      );
      await tester.pump();
      // the two unselected tiles take tileColor
      expect(_boxColors(tester), contains(const Color(0xFF150606)));
    });

    testWidgets('selectedTileColor', (tester) async {
      await tester.pumpWidget(
        _sheet(CometChatChangeScopeStyle(selectedTileColor: Color(0xFF150707))),
      );
      await tester.pump();
      // Participant is the member's current scope, so its tile is the selected one
      expect(_boxColors(tester), contains(const Color(0xFF150707)));
    });

    testWidgets('scopeTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(scopeTextStyle: TextStyle(fontSize: 19)),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(19.0));
    });

    testWidgets('selectedScopeTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            selectedScopeTextStyle: TextStyle(color: Color(0xFF150808)),
          ),
        ),
      );
      await tester.pump();
      expect(_textColors(tester), contains(const Color(0xFF150808)));
    });

    testWidgets('radioButtonColor', (tester) async {
      await tester.pumpWidget(
        _sheet(CometChatChangeScopeStyle(radioButtonColor: Color(0xFF150909))),
      );
      await tester.pump();
      expect(_radioFills(tester), contains(const Color(0xFF150909)));
    });

    testWidgets('radioButtonSelectedColor', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            radioButtonSelectedColor: Color(0xFF150A0A),
          ),
        ),
      );
      await tester.pump();
      expect(_radioFills(tester), contains(const Color(0xFF150A0A)));
    });
  });

  group('the Cancel and Save buttons', () {
    testWidgets('saveButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            saveButtonBackgroundColor: Color(0xFF150B0B),
          ),
        ),
      );
      await tester.pump();
      expect(_buttonBackgrounds(tester), contains(const Color(0xFF150B0B)));
    });

    testWidgets('saveButtonBorder', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            saveButtonBorder: BorderSide(color: Color(0xFF150C0C), width: 5),
          ),
        ),
      );
      await tester.pump();
      expect(_buttonSideColors(tester), contains(const Color(0xFF150C0C)));
    });

    testWidgets('saveButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            saveButtonBorderRadius: BorderRadius.all(Radius.circular(37)),
          ),
        ),
      );
      await tester.pump();
      expect(
        _buttonRadii(tester),
        contains(const BorderRadius.all(Radius.circular(37))),
      );
    });

    testWidgets('saveButtonTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            saveButtonTextStyle: TextStyle(fontSize: 21),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(21.0));
    });

    testWidgets('cancelButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            cancelButtonBackgroundColor: Color(0xFF150D0D),
          ),
        ),
      );
      await tester.pump();
      expect(_buttonBackgrounds(tester), contains(const Color(0xFF150D0D)));
    });

    testWidgets('cancelButtonBorder', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            cancelButtonBorder: BorderSide(color: Color(0xFF150E0E), width: 6),
          ),
        ),
      );
      await tester.pump();
      expect(_buttonSideColors(tester), contains(const Color(0xFF150E0E)));
    });

    testWidgets('cancelButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            cancelButtonBorderRadius: BorderRadius.all(Radius.circular(39)),
          ),
        ),
      );
      await tester.pump();
      expect(
        _buttonRadii(tester),
        contains(const BorderRadius.all(Radius.circular(39))),
      );
    });

    testWidgets('cancelButtonTextStyle', (tester) async {
      await tester.pumpWidget(
        _sheet(
          CometChatChangeScopeStyle(
            cancelButtonTextStyle: TextStyle(fontSize: 23),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(23.0));
    });
  });

  group('CometChatChangeScope own props', () {
    testWidgets('group and member drive the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatChangeScope(group: _group, member: _member),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Moderator'), findsOneWidget);
      expect(find.text('Participant'), findsOneWidget);
    });

    testWidgets('style reaches the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatChangeScope(
              group: _group,
              member: _member,
              style: CometChatChangeScopeStyle(
                backgroundColor: const Color(0xFF151010),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF151010)));
    });

    testWidgets('padding wraps the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatChangeScope(
              group: _group,
              member: _member,
              padding: const EdgeInsets.only(left: 41),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.padding),
        contains(const EdgeInsets.only(left: 41)),
      );
    });

    testWidgets('onSave fires with the newly picked scope', (tester) async {
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatChangeScope(
              group: _group,
              member: _member,
              onSave: (group, member, newScope, oldScope) async {
                saved = newScope;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      // the tile's own radio is what commits the selection
      await tester.tap(find.byType(Radio<String>).at(1));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, 'moderator');
    });
  });
}
