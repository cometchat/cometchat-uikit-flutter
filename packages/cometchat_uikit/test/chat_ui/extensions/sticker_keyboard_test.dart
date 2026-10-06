/// Behaviour tests for [CometChatStickerKeyboard].
///
/// The keyboard fetches its sets through `CometChat.callExtension`, which
/// resolves its repository via `SdkRegistry`, so
/// `test/helpers/fake_sdk_moderation.dart` answers it and the real widget runs
/// its loading, error, empty and populated states.
///
///   flutter test test/chat_ui/extensions/sticker_keyboard_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sdk_moderation.dart';

Map<String, dynamic> _sticker({
  required String id,
  required String name,
  required String setName,
  required int setOrder,
  int order = 1,
}) => <String, dynamic>{
  'id': id,
  'stickerName': name,
  'stickerUrl': 'https://example.invalid/$id.png',
  'stickerSetId': 'set-$setOrder',
  'stickerSetName': setName,
  'stickerSetOrder': '$setOrder',
  'stickerOrder': '$order',
  'createdAt': '1700000000',
  'modifiedAt': '1700000001',
};

/// The inner payload the SDK wraps as `{'data': ...}`.
void _serveStickers({
  List<Map<String, dynamic>> defaults = const [],
  List<Map<String, dynamic>> custom = const [],
}) {
  fakeCallExtension = (_, _, _, _) => <String, dynamic>{
    'defaultStickers': defaults,
    'customStickers': custom,
  };
}

/// Two sets, so the tab bar has a selected and an unselected tab.
final _twoSets = [
  _sticker(id: 'd1', name: 'Wave', setName: 'Hands', setOrder: 1),
  _sticker(id: 'd2', name: 'Cat', setName: 'Animals', setOrder: 2),
];

/// The colours of the keyboard's decorated boxes, in tree order: the
/// keyboard itself, the tab bar, then each set tab.
List<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(CometChatStickerKeyboard),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((d) => (d.decoration as BoxDecoration).color)
    .toList();

/// The opt-in 1px line between the sticker grid and the tab bar.
bool _isSeparator(Widget w) =>
    w is Container &&
    w.constraints ==
        const BoxConstraints.tightFor(width: double.infinity, height: 1);

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SizedBox(height: 400, child: child)),
);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

/// The shimmer animates forever, so `pumpAndSettle` would time out whenever
/// the keyboard is still loading. Pump a fixed number of frames instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(registerFakeSdkBackend);
  tearDown(clearFakeSdkBackend);

  group('loading', () {
    testWidgets('shows a shimmer placeholder until the fetch answers', (
      tester,
    ) async {
      final gate = Completer<Map<String, dynamic>>();
      fakeCallExtension = (_, _, _, _) => gate.future;

      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      expect(find.byType(CometChatShimmerEffect), findsOneWidget);
      expect(
        find.byType(GridView),
        findsOneWidget,
        reason: 'the shimmer draws a six-tile placeholder grid',
      );

      gate.complete(<String, dynamic>{
        'defaultStickers': [
          _sticker(id: 's1', name: 'Wave', setName: 'Hands', setOrder: 1),
        ],
        'customStickers': const <Map<String, dynamic>>[],
      });
      await _settle(tester);

      expect(find.byType(CometChatShimmerEffect), findsNothing);
      expect(_texts(tester), contains('Hands'));
    });

    testWidgets('loadingStateView replaces the shimmer', (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      fakeCallExtension = (_, _, _, _) => gate.future;

      await tester.pumpWidget(
        _wrap(
          CometChatStickerKeyboard(
            loadingStateView: (_) => const Text('fetching stickers'),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('fetching stickers'), findsOneWidget);
      expect(find.byType(CometChatShimmerEffect), findsNothing);

      gate.complete(<String, dynamic>{
        'defaultStickers': const <Map<String, dynamic>>[],
        'customStickers': const <Map<String, dynamic>>[],
      });
      await _settle(tester);
      tester.takeException();
    });
  });

  group('failure', () {
    testWidgets('a failed fetch shows the built-in error copy', (tester) async {
      fakeCallExtension = (_, _, _, _) => throw Exception('stickers offline');
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      expect(find.byType(CometChatShimmerEffect), findsNothing);
      expect(
        find.textContaining('Looks like something went wrong.'),
        findsOneWidget,
      );
      expect(find.textContaining('Please try again'), findsOneWidget);
    });

    testWidgets('FINDING: the error view hardcodes its heading in English. '
        '_getOnError paints the literal "Sticker pack name" instead of a '
        'localized string, so it stays English in every locale.', (
      tester,
    ) async {
      fakeCallExtension = (_, _, _, _) => throw Exception('offline');
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      // FINDING: a hardcoded placeholder heading, not a Translations lookup.
      expect(find.text('Sticker pack name'), findsOneWidget);
    });

    testWidgets('errorStateView replaces the built-in error view', (
      tester,
    ) async {
      fakeCallExtension = (_, _, _, _) => throw Exception('offline');
      await tester.pumpWidget(
        _wrap(
          CometChatStickerKeyboard(
            errorStateView: (_) => const Text('no stickers for you'),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('no stickers for you'), findsOneWidget);
      expect(find.text('Sticker pack name'), findsNothing);
    });
  });

  group('populated', () {
    testWidgets('renders the first set, its name and one tile per sticker', (
      tester,
    ) async {
      _serveStickers(
        defaults: [
          _sticker(id: 's1', name: 'Wave', setName: 'Hands', setOrder: 1),
          _sticker(
            id: 's2',
            name: 'Clap',
            setName: 'Hands',
            setOrder: 1,
            order: 2,
          ),
        ],
      );
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      expect(_texts(tester), contains('Hands'));
      expect(find.bySemanticsLabel('Wave'), findsOneWidget);
      expect(find.bySemanticsLabel('Clap'), findsOneWidget);
    });

    testWidgets('tapping a sticker hands it to onStickerTap', (tester) async {
      _serveStickers(
        defaults: [
          _sticker(id: 's1', name: 'Wave', setName: 'Hands', setOrder: 1),
        ],
      );
      Sticker? tapped;
      await tester.pumpWidget(
        _wrap(CometChatStickerKeyboard(onStickerTap: (s) => tapped = s)),
      );
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('Wave'));
      await _settle(tester);

      expect(tapped?.id, 's1');
      expect(tapped?.stickerName, 'Wave');
      expect(tapped?.stickerSetName, 'Hands');
      expect(tapped?.stickerSetOrder, 1);
    });

    testWidgets('custom sets are appended after the default ones', (
      tester,
    ) async {
      _serveStickers(
        defaults: [
          _sticker(id: 'd1', name: 'Wave', setName: 'Hands', setOrder: 1),
        ],
        custom: [
          _sticker(id: 'c1', name: 'Logo', setName: 'Brand', setOrder: 1),
        ],
      );
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      // One default set (order 1) plus one custom set shifted to order 2 —
      // two set buttons in the footer.
      expect(find.bySemanticsLabel('Brand'), findsOneWidget);
      // The first set is selected, so only its stickers are in the grid.
      expect(find.bySemanticsLabel('Wave'), findsOneWidget);
      expect(find.bySemanticsLabel('Logo'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Brand'));
      await _settle(tester);

      expect(find.bySemanticsLabel('Logo'), findsOneWidget);
      expect(find.bySemanticsLabel('Wave'), findsNothing);
      expect(_texts(tester), contains('Brand'));
    });

    testWidgets('two custom stickers in one set land in the same bucket', (
      tester,
    ) async {
      _serveStickers(
        defaults: [
          _sticker(id: 'd1', name: 'Wave', setName: 'Hands', setOrder: 1),
        ],
        custom: [
          _sticker(id: 'c1', name: 'Logo', setName: 'Brand', setOrder: 1),
          _sticker(
            id: 'c2',
            name: 'Mascot',
            setName: 'Brand',
            setOrder: 1,
            order: 2,
          ),
        ],
      );
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('Brand'));
      await _settle(tester);

      expect(find.bySemanticsLabel('Logo'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Mascot'),
        findsOneWidget,
        reason: 'both custom stickers share the shifted set order',
      );
    });

    testWidgets('tapping a set in the footer switches the grid', (
      tester,
    ) async {
      _serveStickers(
        defaults: [
          _sticker(id: 'd1', name: 'Wave', setName: 'Hands', setOrder: 1),
          _sticker(id: 'd2', name: 'Cat', setName: 'Animals', setOrder: 2),
        ],
      );
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);
      expect(_texts(tester), contains('Hands'));
      expect(find.bySemanticsLabel('Cat'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Animals'));
      await _settle(tester);

      expect(_texts(tester), contains('Animals'));
      expect(find.bySemanticsLabel('Cat'), findsOneWidget);
      expect(find.bySemanticsLabel('Wave'), findsNothing);
    });

    testWidgets('height sizes the loading placeholder', (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      fakeCallExtension = (_, _, _, _) => gate.future;

      await tester.pumpWidget(
        _wrap(const CometChatStickerKeyboard(height: 123)),
      );
      await _settle(tester);

      final heights = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.constraints?.maxHeight);
      expect(heights, contains(123.0));
      expect(CometChatStickerKeyboard.defaultHeight, 296.0);

      gate.complete(<String, dynamic>{
        'defaultStickers': const <Map<String, dynamic>>[],
        'customStickers': const <Map<String, dynamic>>[],
      });
      await _settle(tester);
      tester.takeException();
    });
  });

  group('no sticker sets at all', () {
    // Was a FINDING: _getStickers indexed the empty set list before clearing
    // isLoading, the RangeError reached the SDK's onError, and an account
    // with no stickers was told something went wrong.
    testWidgets('an account with zero sticker sets shows the empty state', (
      tester,
    ) async {
      _serveStickers();
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      expect(find.text('No Stickers Available'), findsOneWidget);
      expect(find.text('You don’t have any stickers yet.'), findsOneWidget);
      expect(
        find.textContaining('Looks like something went wrong.'),
        findsNothing,
      );
    });

    testWidgets('emptyStateView replaces the built-in empty view', (
      tester,
    ) async {
      _serveStickers();
      await tester.pumpWidget(
        _wrap(
          CometChatStickerKeyboard(
            emptyStateView: (_) => const Text('no stickers yet'),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('no stickers yet'), findsOneWidget);
      expect(find.text('No Stickers Available'), findsNothing);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatStickerKeyboardStyle — every field asserted on what it paints
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('CometChatStickerKeyboardStyle', () {
    const background = Color(0xFF102030);
    const separator = Color(0xFF203040);
    const activeTab = Color(0xFF304050);

    testWidgets('unset, the keyboard keeps its palette colours and no line', (
      tester,
    ) async {
      _serveStickers(defaults: _twoSets);
      await tester.pumpWidget(_wrap(const CometChatStickerKeyboard()));
      await _settle(tester);

      final palette = CometChatThemeHelper.getColorPalette(
        tester.element(find.byType(CometChatStickerKeyboard)),
      );
      expect(_boxColors(tester), [
        palette.background1, // the keyboard
        palette.background1, // the tab bar
        palette.extendedPrimary100, // the selected set
        palette.background1, // the other set
      ]);
      expect(find.byWidgetPredicate(_isSeparator), findsNothing);
    });

    testWidgets('backgroundColor, separatorColor and tabActiveIndicatorColor '
        'paint the loaded keyboard', (tester) async {
      _serveStickers(defaults: _twoSets);
      await tester.pumpWidget(
        _wrap(
          const CometChatStickerKeyboard(
            style: CometChatStickerKeyboardStyle(
              backgroundColor: background,
              separatorColor: separator,
              tabActiveIndicatorColor: activeTab,
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_boxColors(tester), [
        background, // the keyboard
        background, // the tab bar
        activeTab, // the selected set
        background, // the other set
      ]);
      final line = find.byWidgetPredicate(_isSeparator);
      expect(line, findsOneWidget);
      expect(tester.getSize(line).height, 1);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(of: line, matching: find.byType(ColoredBox)),
            )
            .color,
        separator,
      );
      // Between the sticker grid and the tab bar.
      expect(
        tester.getTopLeft(line).dy,
        greaterThan(tester.getBottomLeft(find.byType(GridView)).dy - 1),
      );
      expect(
        tester.getBottomLeft(line).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.bySemanticsLabel('Animals')).dy,
        ),
      );
    });

    testWidgets('backgroundColor fills the loading, error and empty states', (
      tester,
    ) async {
      // Never answered: the keyboard has no mounted check, so completing it
      // after the keyboard is gone would setState on a disposed state.
      final gate = Completer<Map<String, dynamic>>();
      final answers = <String, void Function()>{
        'loading': () => fakeCallExtension = (_, _, _, _) => gate.future,
        'error': () => fakeCallExtension = (_, _, _, _) => throw Exception('x'),
        'empty': _serveStickers,
      };
      final filled = <String, bool>{};
      for (final state in answers.entries) {
        state.value();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _wrap(
            const CometChatStickerKeyboard(
              height: 250,
              style: CometChatStickerKeyboardStyle(backgroundColor: background),
            ),
          ),
        );
        await _settle(tester);
        filled[state.key] = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .any((b) => b.color == background);
      }
      await tester.pumpWidget(const SizedBox.shrink());

      expect(filled, {'loading': true, 'error': true, 'empty': true});
    });

    testWidgets('the empty-state text styles reach the title and subtitle', (
      tester,
    ) async {
      _serveStickers();
      await tester.pumpWidget(
        _wrap(
          const CometChatStickerKeyboard(
            style: CometChatStickerKeyboardStyle(
              emptyStateTextStyle: TextStyle(
                letterSpacing: 3,
                color: Color(0xFF999999),
              ),
              emptyStateTextColor: Color(0xFF405060),
              emptyStateSubTitleTextStyle: TextStyle(
                letterSpacing: 5,
                color: Color(0xFF999999),
              ),
              emptyStateSubTitleTextColor: Color(0xFF506070),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _style(tester, 'No Stickers Available');
      expect(title.letterSpacing, 3);
      expect(title.color, const Color(0xFF405060), reason: 'the colour wins');
      final subtitle = _style(tester, 'You don’t have any stickers yet.');
      expect(subtitle.letterSpacing, 5);
      expect(subtitle.color, const Color(0xFF506070));
    });

    testWidgets('the error-state text style reaches the error message', (
      tester,
    ) async {
      fakeCallExtension = (_, _, _, _) => throw Exception('offline');
      await tester.pumpWidget(
        _wrap(
          const CometChatStickerKeyboard(
            style: CometChatStickerKeyboardStyle(
              errorStateTextStyle: TextStyle(
                letterSpacing: 4,
                color: Color(0xFF999999),
              ),
              errorStateTextColor: Color(0xFF607080),
            ),
          ),
        ),
      );
      await _settle(tester);

      final error = tester
          .widget<Text>(find.textContaining('Looks like something went wrong'))
          .style!;
      expect(error.letterSpacing, 4);
      expect(error.color, const Color(0xFF607080), reason: 'the colour wins');
    });

    testWidgets('a text style colour applies when no colour field is set', (
      tester,
    ) async {
      final colours = <String, Color?>{};
      for (final empty in [true, false]) {
        if (empty) {
          _serveStickers();
        } else {
          fakeCallExtension = (_, _, _, _) => throw Exception('offline');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _wrap(
            const CometChatStickerKeyboard(
              style: CometChatStickerKeyboardStyle(
                emptyStateTextStyle: TextStyle(color: Color(0xFF708090)),
                emptyStateSubTitleTextStyle: TextStyle(
                  color: Color(0xFF8090A0),
                ),
                errorStateTextStyle: TextStyle(color: Color(0xFF90A0B0)),
              ),
            ),
          ),
        );
        await _settle(tester);
        if (empty) {
          colours['title'] = _style(tester, 'No Stickers Available').color;
          colours['subtitle'] = _style(
            tester,
            'You don’t have any stickers yet.',
          ).color;
        } else {
          colours['error'] = tester
              .widget<Text>(
                find.textContaining('Looks like something went wrong'),
              )
              .style
              ?.color;
        }
      }

      expect(colours, {
        'title': const Color(0xFF708090),
        'subtitle': const Color(0xFF8090A0),
        'error': const Color(0xFF90A0B0),
      });
    });

    testWidgets(
      'a theme extension styles the keyboard; the widget style wins',
      (tester) async {
        _serveStickers(defaults: _twoSets);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: ThemeData(
              extensions: const [
                CometChatStickerKeyboardStyle(
                  backgroundColor: background,
                  separatorColor: separator,
                  tabActiveIndicatorColor: Color(0xFFABCDEF),
                ),
              ],
            ),
            home: const Scaffold(
              body: SizedBox(
                height: 400,
                child: CometChatStickerKeyboard(
                  style: CometChatStickerKeyboardStyle(
                    tabActiveIndicatorColor: activeTab,
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        expect(_boxColors(tester), [
          background, // the keyboard, from the theme
          background, // the tab bar, from the theme
          activeTab, // the selected set, from the widget
          background, // the other set
        ]);
        expect(find.byWidgetPredicate(_isSeparator), findsOneWidget);
      },
    );
  });

  group('Sticker model', () {
    test('fromJson parses the string-encoded order fields', () {
      final sticker = Sticker.fromJson(
        _sticker(
          id: 's9',
          name: 'Wave',
          setName: 'Hands',
          setOrder: 3,
          order: 7,
        ),
      );

      expect(sticker.id, 's9');
      expect(sticker.stickerName, 'Wave');
      expect(sticker.stickerSetName, 'Hands');
      expect(sticker.stickerSetId, 'set-3');
      expect(sticker.stickerSetOrder, 3, reason: 'parsed from the string "3"');
      expect(sticker.stickerOrder, 7, reason: 'parsed from the string "7"');
      expect(sticker.stickerUrl, 'https://example.invalid/s9.png');
      expect(sticker.createdAt, '1700000000');
      expect(sticker.modifiedAt, '1700000001');
    });

    test('toJson emits the parsed ints, not the original strings', () {
      final json = Sticker.fromJson(
        _sticker(
          id: 's9',
          name: 'Wave',
          setName: 'Hands',
          setOrder: 3,
          order: 7,
        ),
      ).toJson();

      expect(json['stickerSetOrder'], 3);
      expect(json['stickerOrder'], 7);
      expect(json['id'], 's9');
      expect(json['stickerName'], 'Wave');
      expect(json['stickerSetName'], 'Hands');
      expect(json['stickerSetId'], 'set-3');
      expect(json['createdAt'], '1700000000');
      expect(json['modifiedAt'], '1700000001');
    });

    test('the optional timestamps stay null when the payload omits them', () {
      final sticker = Sticker.fromJson(<String, dynamic>{
        'id': 's1',
        'stickerName': 'Wave',
        'stickerUrl': 'https://example.invalid/s1.png',
        'stickerSetId': 'set-1',
        'stickerSetName': 'Hands',
        'stickerSetOrder': '1',
        'stickerOrder': '1',
      });

      expect(sticker.createdAt, isNull);
      expect(sticker.modifiedAt, isNull);
      expect(sticker.toJson()['createdAt'], isNull);
    });
  });
}
