import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

// Trailing Toolbar Buttons DD — Flutter acceptance (§8.1 structural +
// §8.2 S1–S4 exercised at the controller level, where the enablers live).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RichTextSpanManager inline style ranges (DD §8.3)', () {
    test('apply stores a range; same-id re-apply replaces, not stacks', () {
      final manager = RichTextSpanManager();
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      manager.applyInlineStyle(
        2,
        4,
        const TextStyle(color: Color(0xFF00FF00)),
        id: 'color',
      );

      // 0-2 red, 2-4 green, 4-5 red — carved, not doubled.
      final covering = manager.stylesInRange(2, 4, id: 'color');
      expect(covering.length, 1);
      expect(covering.single.style.color, const Color(0xFF00FF00));
      expect(manager.stylesInRange(0, 5, id: 'color').length, 3);
    });

    test('different ids coexist on the same range', () {
      final manager = RichTextSpanManager();
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(backgroundColor: Color(0xFF0000FF)),
        id: 'highlight',
      );
      expect(manager.stylesInRange(0, 5).length, 2);

      manager.removeInlineStyle(0, 5, id: 'color');
      final left = manager.stylesInRange(0, 5);
      expect(left.length, 1);
      expect(left.single.id, 'highlight');
    });

    test('ranges shift on insert and delete like format spans', () {
      final manager = RichTextSpanManager();
      manager.applyInlineStyle(
        5,
        10,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );

      manager.onTextInserted(0, 3);
      expect(manager.styleRanges.single.start, 8);
      expect(manager.styleRanges.single.end, 13);

      manager.onTextDeleted(0, 3);
      expect(manager.styleRanges.single.start, 5);
      expect(manager.styleRanges.single.end, 10);

      // Deleting the styled text entirely drops the range.
      manager.onTextDeleted(5, 10);
      expect(manager.styleRanges, isEmpty);
    });

    test('format spans are untouched by style operations', () {
      final manager = RichTextSpanManager();
      manager.addFormat(0, 5, FormatType.bold);
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      manager.removeInlineStyle(0, 5, id: 'color');
      expect(manager.spans.single.formats, {FormatType.bold});
    });
  });

  group('RichTextEditingController inline styles survive rebuilds (S1–S3)', () {
    TextSpan buildSpan(
      RichTextEditingController controller,
      BuildContext context,
    ) {
      return controller.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
    }

    List<TextSpan> flatten(InlineSpan span) {
      final out = <TextSpan>[];
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) out.add(child);
        return true;
      });
      return out;
    }

    testWidgets('S1: applied colour renders and survives a rebuild', (
      tester,
    ) async {
      final controller = RichTextEditingController(text: 'hello world');
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      controller.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );

      TextSpan span = buildSpan(controller, ctx);
      bool hasRed(TextSpan root) =>
          flatten(root).any((s) => s.style?.color == const Color(0xFFFF0000));
      expect(
        hasRed(span),
        isTrue,
        reason: 'colour must render immediately (S1)',
      );

      // Force the re-derivation path the DD flags: buildTextSpan rebuilds
      // everything from tracked state every frame.
      controller.value = controller.value.copyWith();
      span = buildSpan(controller, ctx);
      expect(hasRed(span), isTrue, reason: 'colour must survive rebuild (S1)');
    });

    testWidgets('S2: removal clears the colour', (tester) async {
      final controller = RichTextEditingController(text: 'hello world');
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      controller.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      controller.removeInlineStyle(0, 5, id: 'color');

      final span = buildSpan(controller, ctx);
      final red = flatten(
        span,
      ).where((s) => s.style?.color == const Color(0xFFFF0000));
      expect(red, isEmpty, reason: 'removed colour must not render (S2)');
    });

    testWidgets('S3: colour composes with bold in BOTH orders', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // bold then colour
      final a = RichTextEditingController(text: 'hello world');
      a.spanManager.addFormat(0, 5, FormatType.bold);
      a.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      final aSegs = flatten(
        buildSpan(a, ctx),
      ).where((s) => s.style?.color == const Color(0xFFFF0000));
      expect(aSegs, isNotEmpty);
      expect(
        aSegs.every((s) => s.style?.fontWeight == FontWeight.bold),
        isTrue,
        reason: 'bold→colour: both attributes must hold (S3)',
      );

      // colour then bold
      final b = RichTextEditingController(text: 'hello world');
      b.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      b.spanManager.addFormat(0, 5, FormatType.bold);
      final bSegs = flatten(
        buildSpan(b, ctx),
      ).where((s) => s.style?.color == const Color(0xFFFF0000));
      expect(bSegs, isNotEmpty);
      expect(
        bSegs.every((s) => s.style?.fontWeight == FontWeight.bold),
        isTrue,
        reason: 'colour→bold: both attributes must hold (S3)',
      );
    });

    test(
      'S4 enabler: getMentionRanges is empty without a mentions formatter',
      () {
        final controller = RichTextEditingController(text: 'hello @world');
        expect(controller.getMentionRanges(), isEmpty);
      },
    );

    test('collapsed range no-ops apply and remove', () {
      final controller = RichTextEditingController(text: 'hello');
      controller.applyInlineStyle(
        3,
        3,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      expect(controller.spanManager.styleRanges, isEmpty);
      controller.removeInlineStyle(3, 3, id: 'color');
      expect(controller.spanManager.styleRanges, isEmpty);
    });
  });

  group('CometChatRichTextToolbar trailing slot (DD §8.1 structural)', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('no trailing actions → no trailing divider or buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(CometChatRichTextToolbar(onFormatTap: (_) {})),
      );
      // Baseline divider count: exactly the two group dividers.
      final dividers = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 1.0,
      );
      final baseline = tester.widgetList(dividers).length;

      await tester.pumpWidget(
        host(
          CometChatRichTextToolbar(
            onFormatTap: (_) {},
            trailingActions: const [],
          ),
        ),
      );
      expect(
        tester.widgetList(dividers).length,
        baseline,
        reason: 'empty list must render byte-identical (DD §7)',
      );
    });

    testWidgets(
      'with actions → one more divider, buttons last, tap gets controller',
      (tester) async {
        final controller = RichTextEditingController(text: 'hi');
        TextEditingController? tapped;

        await tester.pumpWidget(
          host(
            CometChatRichTextToolbar(
              onFormatTap: (_) {},
              trailingTapController: controller,
              trailingActions: [
                CometChatMessageComposerAction(
                  id: 'demo',
                  title: 'Demo action',
                  icon: const Icon(Icons.palette, key: Key('trailing_demo')),
                  onToolbarTap: (context, c) => tapped = c,
                ),
              ],
            ),
          ),
        );

        expect(find.byKey(const Key('trailing_demo')), findsOneWidget);
        await tester.tap(find.byKey(const Key('trailing_demo')));
        expect(
          tapped,
          same(controller),
          reason: 'tap must receive the live controller (DD §1.1)',
        );
      },
    );

    testWidgets('no controller → trailing button renders inert', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(
        host(
          CometChatRichTextToolbar(
            onFormatTap: (_) {},
            trailingActions: [
              CometChatMessageComposerAction(
                id: 'demo',
                title: 'Demo action',
                icon: const Icon(Icons.palette, key: Key('trailing_demo')),
                onToolbarTap: (context, c) => fired = true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('trailing_demo')));
      expect(
        fired,
        isFalse,
        reason: 'without a controller the tap must be inert (B3)',
      );
    });
  });

  group('Colour tag wire format (<color=#RRGGBB>)', () {
    test('plain coloured range serializes to a colour tag', () {
      final manager = RichTextSpanManager();
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      expect(
        manager.toMarkdown('hello world'),
        '<color=#FF0000>hello</color> world',
      );
    });

    test('colour wraps OUTSIDE the format markers', () {
      final manager = RichTextSpanManager();
      manager.addFormat(0, 5, FormatType.bold);
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFF00FF00)),
        id: 'color',
      );
      // Markers are inserted first, so the colour range must be shifted to
      // cover them — otherwise the tag lands mid-marker.
      expect(
        manager.toMarkdown('hello world'),
        '<color=#00FF00>**hello**</color> world',
      );
    });

    test('a colour after bold text accounts for the inserted markers', () {
      final manager = RichTextSpanManager();
      manager.addFormat(0, 5, FormatType.bold);
      manager.applyInlineStyle(
        6,
        11,
        const TextStyle(color: Color(0xFF0000FF)),
        id: 'color',
      );
      expect(
        manager.toMarkdown('hello world'),
        '**hello** <color=#0000FF>world</color>',
      );
    });

    test('styles without a colour are not serialized', () {
      final manager = RichTextSpanManager();
      manager.applyInlineStyle(
        0,
        5,
        const TextStyle(backgroundColor: Color(0xFF00FF00)),
        id: 'highlight',
      );
      expect(manager.toMarkdown('hello world'), 'hello world');
    });

    test('no spans and no styles round-trips untouched', () {
      expect(RichTextSpanManager().toMarkdown('hello world'), 'hello world');
    });
  });
}
