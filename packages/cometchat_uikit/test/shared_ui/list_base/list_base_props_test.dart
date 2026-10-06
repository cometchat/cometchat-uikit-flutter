/// Render-verified prop matrix for [CometChatListBase] and [ListBaseStyle] —
/// Track 3 PROP1 (ENG-38922).
///
///   flutter test test/shared_ui/list_base/list_base_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('container and header', () {
    testWidgets('container renders the body', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatListBase(container: Text('BODY'))),
      );
      await _settle(tester);
      expect(find.text('BODY'), findsOneWidget);
    });

    testWidgets('title renders in the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            title: 'LIST_TITLE',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('LIST_TITLE'), findsOneWidget);
    });

    testWidgets('titleView replaces the title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            title: 'LIST_TITLE',
            titleView: Text('TITLE_SLOT'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('TITLE_SLOT'), findsOneWidget);
      expect(find.text('LIST_TITLE'), findsNothing);
    });

    testWidgets('hideAppBar removes the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            title: 'LIST_TITLE',
            hideAppBar: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('LIST_TITLE'), findsNothing);
    });

    testWidgets('menuOptions render in the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            menuOptions: [Text('MENU_OPTION')],
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('MENU_OPTION'), findsOneWidget);
    });

    testWidgets('titleSpacing and leadingWidth size the app bar slots', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            title: 'T',
            titleSpacing: 21,
            leadingWidth: 71,
          ),
        ),
      );
      await _settle(tester);
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.titleSpacing, 21);
      expect(bar.leadingWidth, 71);
    });
  });

  group('back control', () {
    testWidgets('showBackButton adds the back control', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            showBackButton: true,
          ),
        ),
      );
      await _settle(tester);
      expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNotNull);
    });

    testWidgets('backIcon replaces the back control', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            showBackButton: true,
            backIcon: Icon(Icons.close, key: Key('BACK')),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('BACK')), findsOneWidget);
    });

    testWidgets('onBack fires from the back control', (tester) async {
      var backed = false;
      await tester.pumpWidget(
        _wrap(
          CometChatListBase(
            container: const SizedBox.shrink(),
            showBackButton: true,
            onBack: () => backed = true,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await _settle(tester);
      expect(backed, isTrue);
    });

    testWidgets('leadingIconPadding pads the back control', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            showBackButton: true,
            leadingIconPadding: EdgeInsets.all(13),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
        contains(const EdgeInsets.all(13)),
      );
    });
  });

  group('search row', () {
    testWidgets('hideSearch removes the search field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('placeholder sets the search hint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: false,
            placeholder: 'FIND_SOMETHING',
          ),
        ),
      );
      await _settle(tester);
      expect(_field(tester).decoration?.hintText, 'FIND_SOMETHING');
    });

    testWidgets('searchText seeds the search field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: false,
            searchText: 'SEEDED',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('SEEDED'), findsOneWidget);
    });

    testWidgets('searchBoxIcon replaces the search icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: false,
            searchBoxIcon: Icon(Icons.travel_explore, key: Key('SEARCH')),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('SEARCH')), findsOneWidget);
    });

    testWidgets('onSearch fires as the query changes', (tester) async {
      String? typed;
      await tester.pumpWidget(
        _wrap(
          CometChatListBase(
            container: const SizedBox.shrink(),
            hideSearch: false,
            onSearch: (q) => typed = q,
          ),
        ),
      );
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'hello');
      await _settle(tester);
      expect(typed, 'hello');
    });

    testWidgets('searchReadOnly and onSearchTap make the field a button', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          CometChatListBase(
            container: const SizedBox.shrink(),
            hideSearch: false,
            searchReadOnly: true,
            onSearchTap: () => tapped = true,
          ),
        ),
      );
      await _settle(tester);
      expect(_field(tester).readOnly, isTrue);
      await tester.tap(find.byType(TextField));
      await _settle(tester);
      expect(tapped, isTrue);
    });

    testWidgets('searchBoxHeight, searchPadding and searchContentPadding '
        'shape the search row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: false,
            searchBoxHeight: 44,
            searchPadding: EdgeInsets.all(8),
            searchContentPadding: EdgeInsets.all(9),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _field(tester).decoration?.contentPadding,
        const EdgeInsets.all(9),
      );
      expect(
        tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
        contains(const EdgeInsets.all(8)),
      );
    });
  });

  group('ListBaseStyle', () {
    testWidgets('titleStyle, appBarBackground and appBarShape style the bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            title: 'STYLED',
            style: ListBaseStyle(
              titleStyle: TextStyle(fontSize: 21),
              appBarBackground: Color(0xFF0A0101),
              appBarShape: Border(
                bottom: BorderSide(color: Color(0xFF0A0202), width: 4),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.widget<Text>(find.text('STYLED')).style?.fontSize, 21.0);
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, const Color(0xFF0A0101));
      expect((bar.shape as Border).bottom.color, const Color(0xFF0A0202));
    });

    testWidgets('searchTextStyle, searchPlaceholderStyle, searchBoxBackground, '
        'searchIconTint, borderSide and searchTextFieldRadius style the search '
        'row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            hideSearch: false,
            style: ListBaseStyle(
              searchTextStyle: TextStyle(
                fontSize: 17,
                color: Color(0xFF0A0303),
              ),
              searchPlaceholderStyle: TextStyle(
                fontSize: 15,
                color: Color(0xFF0A0404),
              ),
              searchBoxBackground: Color(0xFF0A0505),
              searchIconTint: Color(0xFF0A0606),
              borderSide: BorderSide(color: Color(0xFF0A0707), width: 2),
              searchTextFieldRadius: BorderRadius.all(Radius.circular(17)),
            ),
          ),
        ),
      );
      await _settle(tester);
      final field = _field(tester);
      expect(field.style?.fontSize, 17.0);
      expect(field.decoration?.hintStyle?.color, const Color(0xFF0A0404));
      expect(field.decoration?.fillColor, const Color(0xFF0A0505));
      final border = field.decoration?.enabledBorder as OutlineInputBorder;
      expect(border.borderSide.color, const Color(0xFF0A0707));
      expect(border.borderRadius, const BorderRadius.all(Radius.circular(17)));
    });

    testWidgets('backIconTint tints the back control', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            showBackButton: true,
            style: ListBaseStyle(backIconTint: Color(0xFF0A0808)),
          ),
        ),
      );
      await _settle(tester);
      // The tint colours the IconButton and the asset image, not an Icon.
      expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .map((b) => b.color),
        contains(const Color(0xFF0A0808)),
      );
    });

    testWidgets('padding pads the whole list base', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatListBase(
            container: SizedBox.shrink(),
            style: ListBaseStyle(padding: EdgeInsets.all(19)),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
        contains(const EdgeInsets.all(19)),
      );
    });
  });
}
