/// `showCometChatAiOptionSheet` — the bottom sheet listing the AI actions.
///
/// It is a bare function rather than a widget, so nothing had ever opened it.
/// These tests open it from a real tap and assert on the sheet it builds: the
/// per-action rows, the styling precedence between an action's own style, the
/// sheet style and the palette, and what a tap on a row does.
///
///   flutter test test/shared_ui/views/ai_option_sheet_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sheetBg = Color(0xFF111111);
const _actionBg = Color(0xFF222222);
const _actionBorder = Color(0xFF333333);
const _sheetIcon = Color(0xFF444444);
const _actionIcon = Color(0xFF555555);
const _actionTitle = Color(0xFF666666);
const _paletteIcon = Color(0xFF777777);

final _user = User(uid: 'u1', name: 'Alice');
final _group = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);

/// Opens the sheet from a real tap so it gets a route to pop.
Future<void> _open(
  WidgetTester tester, {
  required List<CometChatMessageComposerAction> actions,
  CometChatAiOptionSheetStyle? style,
  User? user,
  Group? group,
  CometChatColorPalette? palette,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCometChatAiOptionSheet(
              context: context,
              actionItems: actions,
              user: user,
              group: group,
              style: style,
              colorPalette:
                  palette ?? CometChatThemeHelper.getColorPalette(context),
              typography: CometChatThemeHelper.getTypography(context),
              spacing: CometChatThemeHelper.getSpacing(context),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every action becomes a row with its title and icon', (
    tester,
  ) async {
    await _open(
      tester,
      actions: [
        const CometChatMessageComposerAction(
          id: 'a',
          title: 'Smart replies',
          icon: Icon(Icons.bolt),
        ),
        const CometChatMessageComposerAction(id: 'b', title: 'Summarise'),
      ],
    );

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('Smart replies'), findsOneWidget);
    expect(find.text('Summarise'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets('an empty action list still opens an empty sheet', (
    tester,
  ) async {
    await _open(tester, actions: const []);

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('tapping an action closes the sheet and reports the target', (
    tester,
  ) async {
    User? gotUser;
    Group? gotGroup;
    var calls = 0;

    await _open(
      tester,
      user: _user,
      group: _group,
      actions: [
        CometChatMessageComposerAction(
          id: 'a',
          title: 'Smart replies',
          onItemClick: (_, u, g) {
            calls++;
            gotUser = u;
            gotGroup = g;
          },
        ),
      ],
    );

    await tester.tap(find.text('Smart replies'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(gotUser, same(_user));
    expect(gotGroup, same(_group));
    expect(find.text('Smart replies'), findsNothing, reason: 'sheet dismissed');
  });

  testWidgets('an action with no callback still dismisses the sheet', (
    tester,
  ) async {
    await _open(
      tester,
      actions: const [CometChatMessageComposerAction(id: 'a', title: 'Noop')],
    );

    await tester.tap(find.text('Noop'));
    await tester.pumpAndSettle();

    expect(find.text('Noop'), findsNothing);
  });

  testWidgets('the sheet style paints the background and the corner radius', (
    tester,
  ) async {
    await _open(
      tester,
      style: CometChatAiOptionSheetStyle(
        backgroundColor: _sheetBg,
        borderRadius: BorderRadius.circular(31),
        border: const BorderSide(color: _actionBorder, width: 2),
      ),
      actions: const [CometChatMessageComposerAction(id: 'a', title: 'Item')],
    );

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, _sheetBg);
    final shape = sheet.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(31));
    expect(shape.side.color, _actionBorder);
    expect(shape.side.width, 2);
  });

  testWidgets("an action's own style decorates its row", (tester) async {
    await _open(
      tester,
      actions: [
        CometChatMessageComposerAction(
          id: 'a',
          title: 'Item',
          style: CometChatAttachmentOptionSheetStyle(
            backgroundColor: _actionBg,
            border: Border.all(color: _actionBorder, width: 3),
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ],
    );

    final row = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color == _actionBg);
    expect((row.border! as Border).top.color, _actionBorder);
    expect((row.border! as Border).top.width, 3);
    expect(row.borderRadius, BorderRadius.circular(11));
  });

  testWidgets("the action's icon colour beats the sheet's, which beats the "
      'palette', (tester) async {
    await _open(
      tester,
      palette: CometChatColorPalette(iconHighlight: _paletteIcon),
      style: const CometChatAiOptionSheetStyle(iconColor: _sheetIcon),
      actions: [
        const CometChatMessageComposerAction(
          id: 'a',
          title: 'Own icon colour',
          style: CometChatAttachmentOptionSheetStyle(iconColor: _actionIcon),
        ),
        const CometChatMessageComposerAction(id: 'b', title: 'Sheet colour'),
      ],
    );

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles[0].iconColor, _actionIcon);
    expect(tiles[1].iconColor, _sheetIcon);
  });

  testWidgets('with neither set the icon falls back to the palette', (
    tester,
  ) async {
    await _open(
      tester,
      palette: CometChatColorPalette(iconHighlight: _paletteIcon),
      actions: const [CometChatMessageComposerAction(id: 'a', title: 'Item')],
    );

    expect(
      tester.widget<ListTile>(find.byType(ListTile)).iconColor,
      _paletteIcon,
    );
  });

  testWidgets('titleColor overrides whatever the merged text style says', (
    tester,
  ) async {
    await _open(
      tester,
      style: const CometChatAiOptionSheetStyle(
        textStyle: TextStyle(color: _sheetIcon, fontSize: 23),
      ),
      actions: [
        const CometChatMessageComposerAction(
          id: 'a',
          title: 'Coloured',
          style: CometChatAttachmentOptionSheetStyle(titleColor: _actionTitle),
        ),
      ],
    );

    final title = tester.widget<Text>(find.text('Coloured')).style;
    // The sheet's textStyle is merged in, but titleColor is copied over it.
    expect(title?.fontSize, 23);
    expect(title?.color, _actionTitle);
  });

  testWidgets("an action's titleTextStyle beats the sheet's textStyle", (
    tester,
  ) async {
    await _open(
      tester,
      style: const CometChatAiOptionSheetStyle(
        textStyle: TextStyle(fontSize: 23, letterSpacing: 4),
      ),
      actions: [
        const CometChatMessageComposerAction(
          id: 'a',
          title: 'Own text style',
          style: CometChatAttachmentOptionSheetStyle(
            titleTextStyle: TextStyle(fontSize: 15),
          ),
        ),
      ],
    );

    final title = tester.widget<Text>(find.text('Own text style')).style;
    expect(title?.fontSize, 15);
    expect(
      title?.letterSpacing,
      isNull,
      reason: 'the sheet style is replaced, not combined',
    );
  });

  testWidgets('the call itself resolves to null — the sheet result is not '
      'plumbed back', (tester) async {
    Future<CometChatMessageComposerAction?>? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                result = showCometChatAiOptionSheet(
                  context: context,
                  actionItems: const [
                    CometChatMessageComposerAction(id: 'a', title: 'Item'),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet opened…
    expect(find.text('Item'), findsOneWidget);
    // …but the function returns null rather than the sheet's future, so a
    // caller cannot await the chosen action.
    expect(result, isNull);
  });
}
