/// The AI agent view builders — the widgets `CometChatAIAssistantBubble`
/// hands to `GptMarkdown` for tables, code blocks, links and highlights, plus
/// the two intrinsic-blocking render objects they are wrapped in.
///
/// `misc_widgets_props_test.dart` already pins the plain-text table and the
/// code block header. What runs here is everything underneath: the markdown
/// cell paths (links, non-link markdown, the "bold" strip), cell alignment,
/// the copy affordances, the syntax-highlight branches, and the intrinsic
/// dimensions the wrappers report.
///
///   flutter test test/shared_ui/views/ai_agent_view_builders_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// Not exported from the barrel; the bubbles reach it by relative path.
import 'package:cometchat_chat_uikit/shared_ui/src/views/no_intrinsic_card_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _border = Color(0xFF445566);
const _headerBg = Color(0xFF223344);
const _textPrimary = Color(0xFF101010);
const _textSecondary = Color(0xFF202020);
const _highlight = Color(0xFF0066FF);
const _success = Color(0xFF00AA00);
const _warning = Color(0xFFAA8800);
const _info = Color(0xFF0088AA);

CometChatColorPalette _palette(BuildContext context) =>
    CometChatThemeHelper.getColorPalette(context).copyWith(
      borderDark: _border,
      background4: _headerBg,
      textPrimary: _textPrimary,
      textSecondary: _textSecondary,
      textHighlight: _highlight,
      success: _success,
      warning: _warning,
      info: _info,
    );

Widget _host(WidgetBuilder builder) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: Builder(
      builder: (context) => SizedBox(width: 600, child: builder(context)),
    ),
  ),
);

/// Same, but with the child's width left unconstrained — what the bubble's
/// `Column` gives the intrinsic wrappers.
Widget _looseHost(WidgetBuilder builder) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: Builder(builder: builder),
    ),
  ),
);

CustomTableRow _row(
  List<String> cells, {
  bool header = false,
  TextAlign align = TextAlign.left,
}) => CustomTableRow(
  isHeader: header,
  fields: [for (final c in cells) CustomTableField(data: c, alignment: align)],
);

Widget _table(BuildContext context, List<CustomTableRow> rows) =>
    CometChatAiAssistantTableBuilder(
      tableRows: rows,
      colorPalette: _palette(context),
      spacing: CometChatThemeHelper.getSpacing(context),
      typography: CometChatThemeHelper.getTypography(context),
      config: const GptMarkdownConfig(textDirection: TextDirection.ltr),
    );

void main() {
  // =========================================================================
  group('CometChatAiAssistantTableBuilder — cell content', () {
    testWidgets('no rows renders nothing at all', (tester) async {
      await tester.pumpWidget(_host((c) => _table(c, const [])));
      await tester.pump();

      expect(find.byType(Table), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('a plain header cell takes the header colour and weight, a '
        'body cell the secondary one', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['Region'], header: true),
            _row(['EMEA']),
          ]),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Region')).style?.color,
        _textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('EMEA')).style?.color,
        _textSecondary,
      );
    });

    testWidgets('a cell is trimmed before it is rendered', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['   padded   ']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('padded'), findsOneWidget);
    });

    testWidgets('a markdown link becomes a tappable span with the '
        'surrounding text kept', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['see [the docs](https://example.invalid/d) for more']),
          ]),
        ),
      );
      await tester.pump();

      // The link text is its own tappable widget span…
      final link = tester.widget<Text>(find.text('the docs'));
      expect(link.style?.color, _highlight);
      expect(link.style?.decoration, TextDecoration.underline);

      // …and the text on both sides of it survives as plain spans.
      final rich = tester.widget<RichText>(
        find
            .ancestor(
              of: find.text('the docs'),
              matching: find.byType(RichText),
            )
            .first,
      );
      final plain = (rich.text as TextSpan).children!
          .whereType<TextSpan>()
          .toList();
      expect(plain.map((s) => s.text), ['see ', ' for more']);
      expect(plain.first.style?.color, _textSecondary);
    });

    testWidgets('a link that opens the cell emits no leading span', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['[only](https://example.invalid/x)']),
          ]),
        ),
      );
      await tester.pump();

      final rich = tester.widget<RichText>(
        find
            .ancestor(of: find.text('only'), matching: find.byType(RichText))
            .first,
      );
      final children = (rich.text as TextSpan).children!;
      expect(children, hasLength(1));
      expect(children.single, isA<WidgetSpan>());
    });

    testWidgets('a header link takes the header weight for its plain text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['head [link](https://example.invalid/h)'], header: true),
          ]),
        ),
      );
      await tester.pump();

      final rich = tester.widget<RichText>(
        find
            .ancestor(of: find.text('link'), matching: find.byType(RichText))
            .first,
      );
      final lead = (rich.text as TextSpan).children!.first as TextSpan;
      expect(
        lead.style?.color,
        _textPrimary,
        reason: 'header uses textPrimary',
      );
    });

    testWidgets('text after a link in a header cell keeps the header style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['[link](https://example.invalid/h) tail'], header: true),
            _row(['[link2](https://example.invalid/b) tail']),
          ]),
        ),
      );
      await tester.pump();

      TextSpan trailing(String label) {
        final rich = tester.widget<RichText>(
          find
              .ancestor(of: find.text(label), matching: find.byType(RichText))
              .first,
        );
        return (rich.text as TextSpan).children!.last as TextSpan;
      }

      expect(trailing('link').text, ' tail');
      expect(trailing('link').style?.color, _textPrimary, reason: 'header');
      expect(trailing('link2').style?.color, _textSecondary, reason: 'body');
    });

    testWidgets('markdown that is not a link goes through MdWidget with the '
        'link syntax stripped', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['- a bullet item']),
          ]),
        ),
      );
      await tester.pump();

      // The table builder renders MdWidget, which gpt_markdown 1.3.0 deprecates;
      // see cometchat_table_builder.dart.
      // ignore: deprecated_member_use
      expect(find.byType(MdWidget), findsOneWidget);
      expect(
        // ignore: deprecated_member_use
        tester.widget<MdWidget>(find.byType(MdWidget)).exp,
        '- a bullet item',
      );
    });

    testWidgets('a stray link inside other markdown is reduced to its label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['- see [docs](https://example.invalid/d)']),
          ]),
        ),
      );
      await tester.pump();

      // Both the bullet and the link match, but `matches.isNotEmpty` wins, so
      // this stays on the RichText path rather than the MdWidget one.
      // ignore: deprecated_member_use
      expect(find.byType(MdWidget), findsNothing);
      expect(find.text('docs'), findsOneWidget);
    });

    // FINDING: `_stripBoldMarkdown` calls
    // `text.replaceAll(RegExp(...), r'$1')`. Dart's `String.replaceAll` takes a
    // LITERAL replacement — it does no group substitution — so a `*emphasis*`
    // cell renders as the two characters `$1` instead of its own text. Only
    // `replaceAllMapped` would do what the `$1` was meant to do. This pins the
    // current behaviour.
    testWidgets('an emphasised cell is replaced by the literal "\$1"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row([r'*Total*']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Total'), findsNothing);
      expect(find.text(r'$1'), findsOneWidget);
      // The emphasis branch does pick the primary colour, not the secondary.
      expect(tester.widget<Text>(find.text(r'$1')).style?.color, _textPrimary);
    });

    testWidgets('an emphasised cell with no textPrimary falls back to '
        'textSecondary', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => CometChatAiAssistantTableBuilder(
            tableRows: [
              _row([r'*Total*']),
            ],
            // A palette that names a secondary colour but no primary one.
            colorPalette: CometChatColorPalette(textSecondary: _textSecondary),
            spacing: CometChatThemeHelper.getSpacing(c),
            typography: CometChatThemeHelper.getTypography(c),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text(r'$1')).style?.color,
        _textSecondary,
      );
    });
  });

  // =========================================================================
  group('CometChatAiAssistantTableBuilder — alignment', () {
    testWidgets('a centred field is centred', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['mid'], align: TextAlign.center),
          ]),
        ),
      );
      await tester.pump();

      expect(
        find.ancestor(of: find.text('mid'), matching: find.byType(Center)),
        findsOneWidget,
      );
      expect(tester.widget<Text>(find.text('mid')).textAlign, TextAlign.center);
    });

    testWidgets('a right-aligned field aligns to centreRight', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['end'], align: TextAlign.right),
          ]),
        ),
      );
      await tester.pump();

      final align = tester
          .widgetList<Align>(
            find.ancestor(of: find.text('end'), matching: find.byType(Align)),
          )
          .firstWhere((a) => a.alignment == Alignment.centerRight);
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('a justified field falls through to the left default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['just'], align: TextAlign.justify),
          ]),
        ),
      );
      await tester.pump();

      expect(
        find
            .ancestor(of: find.text('just'), matching: find.byType(Align))
            .evaluate()
            .map((e) => (e.widget as Align).alignment),
        contains(Alignment.centerLeft),
      );
    });
  });

  // =========================================================================
  group('CometChatAiAssistantTableBuilder — opening a cell link', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              calls.add(call);
              return true;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          );
    });

    testWidgets('tapping the link launches its url externally', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['[docs](https://example.invalid/d)']),
          ]),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('docs'));
      await tester.pumpAndSettle();

      expect(calls.map((c) => c.method), ['canLaunch', 'launch']);
      expect((calls.last.arguments as Map)['url'], 'https://example.invalid/d');
    });

    testWidgets('a url the platform cannot open is not launched', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              calls.add(call);
              return call.method == 'canLaunch' ? false : true;
            },
          );

      await tester.pumpWidget(
        _host(
          (c) => _table(c, [
            _row(['[nope](weirdscheme://x)']),
          ]),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('nope'));
      await tester.pumpAndSettle();

      expect(calls.map((c) => c.method), ['canLaunch']);
    });
  });

  // =========================================================================
  group('CometChatAiAssistantCodeBlock', () {
    Widget block(BuildContext c, String code) => CometChatAiAssistantCodeBlock(
      language: 'dart',
      codes: code,
      colorPalette: _palette(c),
      spacing: CometChatThemeHelper.getSpacing(c),
      typography: CometChatThemeHelper.getTypography(c),
    );

    testWidgets('each line is coloured by its syntax class', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => block(c, '// a comment\nfinal x = 1;\nprint("hi");\nplain\n'),
        ),
      );
      await tester.pump();

      Color? colourOf(String line) =>
          tester.widget<Text>(find.text(line)).style?.color;

      expect(colourOf('// a comment'), _success, reason: 'comment');
      expect(colourOf('final x = 1;'), _warning, reason: 'keyword');
      expect(colourOf('print("hi");'), _info, reason: 'string literal');
      expect(colourOf('plain'), _textPrimary, reason: 'no rule matches');
    });

    testWidgets('the copy button puts the code on the clipboard and says so', (
      tester,
    ) async {
      final copied = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') copied.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(_host((c) => block(c, 'void main() {}\n')));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(copied, hasLength(1));
      expect((copied.single.arguments as Map)['text'], 'void main() {}\n');
      expect(find.text('Code copied to clipboard'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Code copied to clipboard')).style?.color,
        _textPrimary,
      );
    });
  });

  // =========================================================================
  group('CometchatLinkBuilder', () {
    testWidgets('tapping the link launches it', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              calls.add(call);
              return true;
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            ),
      );

      await tester.pumpWidget(
        _host(
          (c) => CometchatLinkBuilder(
            url: 'https://example.invalid/page',
            style: const TextStyle(),
            colorPalette: _palette(c),
            typography: CometChatThemeHelper.getTypography(c),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(calls.map((c) => c.method), contains('launch'));
      expect(
        (calls.last.arguments as Map)['url'],
        'https://example.invalid/page',
      );
    });

    testWidgets('a launch the platform refuses raises', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async => false,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            ),
      );

      await tester.pumpWidget(
        _host(
          (c) => CometchatLinkBuilder(
            url: 'https://example.invalid/page',
            style: const TextStyle(),
            colorPalette: _palette(c),
            typography: CometChatThemeHelper.getTypography(c),
          ),
        ),
      );
      await tester.pump();

      Object? raised;
      await runZonedGuarded(() async {
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();
      }, (e, _) => raised = e);

      expect(
        (raised ?? tester.takeException()).toString(),
        contains('Could not launch https://example.invalid/page'),
      );
    });
  });

  // =========================================================================
  group('the intrinsic-blocking wrappers', () {
    testWidgets('NoIntrinsicCardWrapper reports its fixed width and lays the '
        'child out tight to it', (tester) async {
      await tester.pumpWidget(
        _looseHost(
          (_) => IntrinsicWidth(
            child: NoIntrinsicCardWrapper(
              width: 180,
              child: Container(height: 40, color: const Color(0xFF123456)),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(NoIntrinsicCardWrapper)).width, 180);
      expect(tester.getSize(find.byType(NoIntrinsicCardWrapper)).height, 40);
      // The wrapper answers the IntrinsicWidth query with its fixed width
      // instead of letting the query reach the child.
      expect(tester.getSize(find.byType(IntrinsicWidth)).width, 180);
    });

    testWidgets('the intrinsic width it answers with is its fixed width, and '
        'the intrinsic height is always zero', (tester) async {
      await tester.pumpWidget(
        _looseHost(
          (_) => NoIntrinsicCardWrapper(
            width: 120,
            child: Container(height: 90, color: const Color(0xFF123456)),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(
        find.byType(NoIntrinsicCardWrapper),
      );
      expect(box.getMinIntrinsicWidth(double.infinity), 120);
      expect(box.getMaxIntrinsicWidth(double.infinity), 120);
      // Zero whatever the 90-high child would have answered.
      expect(box.getMinIntrinsicHeight(double.infinity), 0);
      expect(box.getMaxIntrinsicHeight(double.infinity), 0);
      expect(box.size, const Size(120, 90));
    });

    testWidgets('changing the width relays out the child', (tester) async {
      Widget at(double w) => _looseHost(
        (_) => IntrinsicWidth(
          child: NoIntrinsicCardWrapper(
            width: w,
            child: Container(height: 40, color: const Color(0xFF123456)),
          ),
        ),
      );

      await tester.pumpWidget(at(180));
      await tester.pump();
      expect(tester.getSize(find.byType(NoIntrinsicCardWrapper)).width, 180);

      await tester.pumpWidget(at(260));
      await tester.pump();
      expect(tester.getSize(find.byType(NoIntrinsicCardWrapper)).width, 260);

      // Re-pumping the same width takes the early return in the setter.
      await tester.pumpWidget(at(260));
      await tester.pump();
      expect(tester.getSize(find.byType(NoIntrinsicCardWrapper)).width, 260);
    });

    // FINDING: `_RenderNoIntrinsicSize.performLayout` sizes itself from the
    // child alone and never reconciles that with its own incoming
    // constraints, so under a parent that constrains the width tightly it
    // fails the debug "does not meet its constraints" assertion instead of
    // clamping. A `constraints.constrain(...)` would be the usual shape here.
    testWidgets('a tightly constrained parent trips the constraints assert', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: NoIntrinsicCardWrapper(
                width: 180,
                child: Container(height: 40, color: const Color(0xFF123456)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect('$error', contains('does not meet its constraints'));
    });

    testWidgets('NoIntrinsicScroll answers every intrinsic query with zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _looseHost(
          (_) => NoIntrinsicScroll(
            child: Container(
              width: 400,
              height: 120,
              color: const Color(0xFF123456),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(
        find.byType(NoIntrinsicScroll),
      );
      expect(box.getMinIntrinsicWidth(double.infinity), 0);
      expect(box.getMaxIntrinsicWidth(double.infinity), 0);
      expect(box.getMinIntrinsicHeight(double.infinity), 0);
      expect(box.getMaxIntrinsicHeight(double.infinity), 0);
      // It is a pass-through for real layout, though: the child keeps its size.
      expect(box.size, const Size(400, 120));
    });

    testWidgets('NoIntrinsicScroll reports no baseline for its child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _looseHost(
          (_) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text('anchor'),
              NoIntrinsicScroll(child: Text('inside')),
            ],
          ),
        ),
      );
      await tester.pump();

      // With no baseline the row falls back to aligning the box's top edge,
      // so the wrapped text sits above the anchor's baseline, not on it.
      expect(find.text('inside'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('inside')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('anchor')).dy),
      );
    });
  });
}
