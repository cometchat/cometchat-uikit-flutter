/// Span-building behaviour of [CustomTextEditingController] — the controller
/// the composer's input field paints with.
///
/// The controller turns a formatter chain's [AttributedText] ranges into
/// [InlineSpan]s: gap text between ranges, an attributed span per range,
/// trailing text, plus overlap merging and gesture-recognizer lifetime. All of
/// that is pure (given a [BuildContext] for the theme), so it is asserted here
/// directly rather than through a rendered field.
///
///   flutter test test/shared_ui/message_input/custom_text_editing_controller_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A formatter that answers a fixed set of attributions, whatever the text.
class _StubFormatter extends CometChatTextFormatter {
  _StubFormatter(this.attributes);

  final List<AttributedText> attributes;

  @override
  List<AttributedText> buildInputFieldText({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
    required String text,
    List<AttributedText>? existingAttributes,
  }) => attributes;

  @override
  void init() {}

  @override
  void handlePreMessageSend(BuildContext context, BaseMessage baseMessage) {}

  @override
  void onScrollToBottom(TextEditingController textEditingController) {}

  @override
  void onChange(
    TextEditingController textEditingController,
    String previousText,
  ) {}

  @override
  TextStyle getMessageInputTextStyle(BuildContext context) => const TextStyle();

  @override
  List<AttributedText> getAttributedText(
    String text,
    BuildContext context,
    BubbleAlignment? alignment, {
    List<AttributedText>? existingAttributes,
    Function(String)? onTap,
    bool forConversation = false,
  }) => attributes;
}

/// Pumps a bare app and hands back a [BuildContext] the controller can read the
/// theme from.
Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ctx;
}

List<InlineSpan> _children(TextSpan span) => span.children!.cast<InlineSpan>();

void main() {
  group('CustomTextEditingController — span assembly', () {
    testWidgets('no formatters falls through to the plain TextEditingController'
        ' span', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(text: 'hello world');
      addTearDown(controller.dispose);

      final span = controller.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 21),
        withComposing: false,
      );

      // The base class emits the whole text as one span with the given style.
      expect(span.toPlainText(), 'hello world');
      expect(span.style?.fontSize, 21);
      expect(span.children, anyOf(isNull, isEmpty));
    });

    testWidgets('an empty formatter list also falls through', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'abc',
        formatters: <CometChatTextFormatter>[],
      );
      addTearDown(controller.dispose);

      final span = controller.buildTextSpan(
        context: ctx,
        style: null,
        withComposing: false,
      );
      expect(span.toPlainText(), 'abc');
      expect(span.children, anyOf(isNull, isEmpty));
    });

    testWidgets('leading gap, attributed range and trailing tail become three'
        ' spans', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'say hello there',
        formatters: [
          _StubFormatter([
            AttributedText(
              start: 4,
              end: 9,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final span = controller.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 17),
        withComposing: false,
      );
      final kids = _children(span);

      expect(kids.length, 3);
      expect((kids[0] as TextSpan).text, 'say ');
      expect((kids[1] as TextSpan).text, 'hello');
      expect((kids[2] as TextSpan).text, ' there');
      expect(span.toPlainText(), 'say hello there');

      // Only the attributed range carries the formatter's style; the gap and
      // the tail keep the default (which already merged the passed-in style).
      expect((kids[1] as TextSpan).style?.fontWeight, FontWeight.bold);
      expect((kids[0] as TextSpan).style?.fontWeight, isNot(FontWeight.bold));
      expect((kids[0] as TextSpan).style?.fontSize, 17);
      expect((kids[1] as TextSpan).style?.fontSize, 17);
    });

    testWidgets('a range starting at 0 emits no leading gap span', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'hey you',
        formatters: [
          _StubFormatter([AttributedText(start: 0, end: 3)]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect(kids.length, 2);
      expect((kids[0] as TextSpan).text, 'hey');
      expect((kids[1] as TextSpan).text, ' you');
    });

    testWidgets('a range covering the whole text emits exactly one span', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'whole',
        formatters: [
          _StubFormatter([AttributedText(start: 0, end: 5)]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect(kids.length, 1);
      expect((kids[0] as TextSpan).text, 'whole');
    });

    testWidgets('underlyingText replaces the rendered text of a range', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'hi @u123 !',
        formatters: [
          _StubFormatter([
            AttributedText(start: 3, end: 8, underlyingText: '@Alice'),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect((kids[1] as TextSpan).text, '@Alice');
      // The tail still resumes at the range's `end` in the RAW text.
      expect((kids[2] as TextSpan).text, ' !');
    });
  });

  group('CustomTextEditingController — background and block elements', () {
    testWidgets('an inline range keeps its backgroundColor', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'code here',
        formatters: [
          _StubFormatter([
            AttributedText(
              start: 0,
              end: 4,
              backgroundColor: const Color(0xFF112233),
            ),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect(
        (kids[0] as TextSpan).style?.backgroundColor,
        const Color(0xFF112233),
      );
    });

    testWidgets('a block element renders as a decorated WidgetSpan and drops'
        ' the text backgroundColor', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'quote me',
        formatters: [
          _StubFormatter([
            AttributedText(
              start: 0,
              end: 5,
              isBlockElement: true,
              backgroundColor: const Color(0xFF445566),
              borderRadius: 7,
              border: Border.all(color: const Color(0xFF778899)),
              padding: const EdgeInsets.all(3),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      final block = kids[0] as WidgetSpan;
      expect(block.alignment, PlaceholderAlignment.baseline);
      expect(block.baseline, TextBaseline.alphabetic);

      final container = block.child as Container;
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF445566));
      expect(decoration.borderRadius, BorderRadius.circular(7));
      expect(decoration.border, isNotNull);
      expect(container.padding, const EdgeInsets.all(3));

      final text = container.child! as Text;
      expect(text.data, 'quote');
      expect(text.style?.fontStyle, FontStyle.italic);
      // The colour lives on the container, NOT on the text run.
      expect(text.style?.backgroundColor, isNull);
    });

    testWidgets('a block element with no border and no background stays a'
        ' TextSpan', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'plain block',
        formatters: [
          _StubFormatter([
            AttributedText(start: 0, end: 5, isBlockElement: true),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect(kids[0], isA<TextSpan>());
      expect((kids[0] as TextSpan).text, 'plain');
    });

    testWidgets('a block element with only a borderRadius still stays a'
        ' TextSpan', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'radius only',
        formatters: [
          _StubFormatter([
            AttributedText(
              start: 0,
              end: 6,
              isBlockElement: true,
              borderRadius: 4,
            ),
          ]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      expect(kids[0], isA<TextSpan>());
    });
  });

  group('CustomTextEditingController — tap recognizers', () {
    testWidgets('a range with onTap gets a live recognizer carrying its text', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final tapped = <String>[];
      final controller = CustomTextEditingController(
        text: 'ping @bob now',
        formatters: [
          _StubFormatter([AttributedText(start: 5, end: 9, onTap: tapped.add)]),
        ],
      );
      addTearDown(controller.dispose);

      final kids = _children(
        controller.buildTextSpan(
          context: ctx,
          style: null,
          withComposing: false,
        ),
      );
      final span = kids[1] as TextSpan;
      expect(span.recognizer, isA<TapGestureRecognizer>());
      (span.recognizer! as TapGestureRecognizer).onTap!();
      expect(tapped, ['@bob']);

      // A range without onTap gets no recognizer at all.
      expect((kids[0] as TextSpan).recognizer, isNull);
    });

    testWidgets(
      'the recognizer reports underlyingText when the range has one',
      (tester) async {
        final ctx = await _context(tester);
        final tapped = <String>[];
        final controller = CustomTextEditingController(
          text: 'ping @u77 now',
          formatters: [
            _StubFormatter([
              AttributedText(
                start: 5,
                end: 9,
                underlyingText: '@Bob',
                onTap: tapped.add,
              ),
            ]),
          ],
        );
        addTearDown(controller.dispose);

        final span =
            _children(
                  controller.buildTextSpan(
                    context: ctx,
                    style: null,
                    withComposing: false,
                  ),
                )[1]
                as TextSpan;
        (span.recognizer! as TapGestureRecognizer).onTap!();
        expect(tapped, ['@Bob']);
      },
    );

    testWidgets('rebuilding disposes the previous recognizers instead of'
        ' leaking them', (tester) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'ping @bob now',
        formatters: [
          _StubFormatter([AttributedText(start: 5, end: 9, onTap: (_) {})]),
        ],
      );

      final disposed = <Object>[];
      void listener(ObjectEvent event) {
        if (event is ObjectDisposed) disposed.add(event.object);
      }

      FlutterMemoryAllocations.instance.addListener(listener);
      addTearDown(
        () => FlutterMemoryAllocations.instance.removeListener(listener),
      );

      TextSpan build() => controller.buildTextSpan(
        context: ctx,
        style: null,
        withComposing: false,
      );

      final first = _children(build())[1] as TextSpan;
      expect(disposed, isEmpty);

      final second = _children(build())[1] as TextSpan;
      expect(
        second.recognizer,
        isNot(same(first.recognizer)),
        reason: 'each build makes fresh recognizers',
      );
      expect(
        disposed,
        contains(first.recognizer),
        reason: 'the previous build\'s recognizer is disposed on rebuild',
      );

      // Disposing the controller releases the live one too.
      controller.dispose();
      expect(disposed, contains(second.recognizer));
    });
  });

  group('CustomTextEditingController — attribution merging', () {
    late BuildContext ctx;

    Future<List<AttributedText>> collect(
      WidgetTester tester,
      String text,
      List<AttributedText> attrs,
    ) async {
      ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: text,
        formatters: [_StubFormatter(attrs)],
      );
      addTearDown(controller.dispose);
      return controller.collectAttributions(ctx, null, false);
    }

    testWidgets('no attributions merges to an empty list', (tester) async {
      expect(await collect(tester, 'abc', []), isEmpty);
    });

    testWidgets('disjoint ranges survive untouched, in start order', (
      tester,
    ) async {
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(start: 5, end: 8),
        AttributedText(start: 0, end: 3),
      ]);
      expect(merged.length, 2);
      expect([merged[0].start, merged[0].end], [0, 3]);
      expect([merged[1].start, merged[1].end], [5, 8]);
    });

    testWidgets('overlapping ranges collapse into one spanning range', (
      tester,
    ) async {
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(
          start: 0,
          end: 5,
          style: const TextStyle(fontWeight: FontWeight.bold),
          borderRadius: 3,
          padding: const EdgeInsets.all(1),
        ),
        AttributedText(
          start: 3,
          end: 8,
          style: const TextStyle(fontStyle: FontStyle.italic),
          borderRadius: 9,
          padding: const EdgeInsets.all(2),
        ),
      ]);

      expect(merged.length, 1);
      expect(merged.single.start, 0);
      expect(merged.single.end, 8);
      // The merged label is the raw text under the union of the two ranges.
      expect(merged.single.underlyingText, 'abcdefgh');
      // Both styles survive; the later one wins on conflicts.
      expect(merged.single.style?.fontWeight, FontWeight.bold);
      expect(merged.single.style?.fontStyle, FontStyle.italic);
      // The FIRST range's box properties win.
      expect(merged.single.borderRadius, 3);
      expect(merged.single.padding, const EdgeInsets.all(1));
    });

    testWidgets('exactly adjacent ranges (end == start) also merge', (
      tester,
    ) async {
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 4),
        AttributedText(start: 4, end: 7),
      ]);
      expect(merged.length, 1);
      expect([merged.single.start, merged.single.end], [0, 7]);
    });

    testWidgets('a range fully inside another does not shrink it', (
      tester,
    ) async {
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 9),
        AttributedText(start: 2, end: 4),
      ]);
      expect(merged.length, 1);
      expect([merged.single.start, merged.single.end], [0, 9]);
    });

    testWidgets('three ranges: two merge, the third stays separate', (
      tester,
    ) async {
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 3),
        AttributedText(start: 2, end: 5),
        AttributedText(start: 7, end: 9),
      ]);
      expect(merged.length, 2);
      expect([merged[0].start, merged[0].end], [0, 5]);
      expect([merged[1].start, merged[1].end], [7, 9]);
    });

    testWidgets('a null style on either side is taken from the other', (
      tester,
    ) async {
      final leftNull = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5),
        AttributedText(start: 3, end: 8, style: const TextStyle(fontSize: 19)),
      ]);
      expect(leftNull.single.style?.fontSize, 19);

      final rightNull = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5, style: const TextStyle(fontSize: 23)),
        AttributedText(start: 3, end: 8),
      ]);
      expect(rightNull.single.style?.fontSize, 23);
    });

    testWidgets('two backgrounds alpha-blend, one background wins alone', (
      tester,
    ) async {
      const a = Color(0x80FF0000);
      const b = Color(0xFF0000FF);

      final both = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5, backgroundColor: a),
        AttributedText(start: 3, end: 8, backgroundColor: b),
      ]);
      expect(both.single.backgroundColor, Color.alphaBlend(a, b));

      final onlySecond = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5),
        AttributedText(start: 3, end: 8, backgroundColor: b),
      ]);
      expect(onlySecond.single.backgroundColor, b);

      final onlyFirst = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5, backgroundColor: a),
        AttributedText(start: 3, end: 8),
      ]);
      expect(onlyFirst.single.backgroundColor, a);
    });

    testWidgets('the surviving onTap is the first range that had one', (
      tester,
    ) async {
      final tapped = <String>[];
      final merged = await collect(tester, 'abcdefghij', [
        AttributedText(start: 0, end: 5),
        AttributedText(start: 3, end: 8, onTap: tapped.add),
      ]);
      merged.single.onTap!('x');
      expect(tapped, ['x']);
    });

    testWidgets('attributions from several formatters are pooled then merged', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final controller = CustomTextEditingController(
        text: 'abcdefghij',
        formatters: [
          _StubFormatter([AttributedText(start: 0, end: 4)]),
          _StubFormatter([AttributedText(start: 3, end: 9)]),
        ],
      );
      addTearDown(controller.dispose);

      final merged = controller.collectAttributions(ctx, null, false);
      expect(merged.length, 1);
      expect([merged.single.start, merged.single.end], [0, 9]);
    });
  });
}
