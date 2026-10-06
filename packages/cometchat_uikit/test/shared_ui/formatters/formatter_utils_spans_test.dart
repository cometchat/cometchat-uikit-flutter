/// `FormatterUtils` — how one attributed range turns into one span.
/// Track 3 TEST3 (ENG-38684).
///
/// `formatter_utils_test.dart` drives this layer end to end through the real
/// markdown and mention formatters, which only ever produces a few of the
/// shapes `buildTextSpan` knows how to render. This file goes the other way:
/// it hands the layer one hand-built [AttributedText] at a time and pins what
/// comes out — a plain span, a tappable span, a boxed inline widget, a
/// full-width block, or the flattened one-line form a conversation subtitle
/// gets — plus the URL shortening the subtitle path applies.
///
///   flutter test test/shared_ui/formatters/formatter_utils_spans_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A formatter that contributes exactly the attributes it is given, so a test
/// can state the shape it cares about instead of coaxing it out of markdown.
class _FixedFormatter extends CometChatTextFormatter {
  _FixedFormatter(this.attributes, {this.once = false});

  final List<AttributedText> attributes;

  /// When set, only the first call contributes anything. Block rendering
  /// re-runs the formatter chain over the block's own content; a formatter
  /// that answered the same ranges again would nest itself forever.
  final bool once;

  int _calls = 0;

  @override
  void init() {}

  @override
  void handlePreMessageSend(BuildContext context, dynamic baseMessage) {}

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
  }) => (once && _calls++ > 0) ? const [] : attributes;
}

Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
}

/// Every `Text` widget reachable from [spans], in order.
List<Text> textsIn(List<InlineSpan> spans, BuildContext context) {
  final out = <Text>[];
  void walkWidget(Widget? w) {
    if (w == null) return;
    w = unwrapNoTextScaling(w, context);
    if (w is Text) {
      out.add(w);
    } else if (w is SingleChildRenderObjectWidget) {
      walkWidget(w.child);
    } else if (w is GestureDetector) {
      walkWidget(w.child);
    } else if (w is Container) {
      walkWidget(w.child);
    }
  }

  void walk(InlineSpan s) {
    if (s is TextSpan) {
      s.children?.forEach(walk);
    } else if (s is WidgetSpan) {
      walkWidget(s.child);
    }
  }

  spans.forEach(walk);
  return out;
}

/// Every inline widget is wrapped in `MediaQuery.withNoTextScaling`, so its
/// text is not scaled a second time by the paragraph it sits in (ENG-39492).
/// That wrapper is a [Builder] around a [MediaQuery]; this builds it with
/// [context] and returns the widget inside, or [w] itself if unwrapped.
Widget unwrapNoTextScaling(Widget w, BuildContext context) {
  final built = w is Builder ? w.builder(context) : w;
  return built is MediaQuery ? built.child : w;
}

/// The widget an inline [span] shows, through its text-scaling wrapper.
Widget spanChild(InlineSpan span, BuildContext context) =>
    unwrapNoTextScaling((span as WidgetSpan).child, context);

List<String> plainTextsOf(List<InlineSpan> spans) => [
  for (final s in spans)
    if (s is TextSpan && s.text != null) s.text!,
];

void main() {
  // ==========================================================================
  group('buildTextSpan — a range with no decoration', () {
    testWidgets('renders as a plain TextSpan carrying its own style', (
      tester,
    ) async {
      const style = TextStyle(fontSize: 33);
      final f = _FixedFormatter([
        AttributedText(start: 3, end: 7, underlyingText: 'BOLD', style: style),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hi word there',
          [f],
          context,
          BubbleAlignment.left,
        );
        expect(plainTextsOf(spans), ['hi ', 'BOLD', ' there']);
        expect((spans[1] as TextSpan).style, style);
      });
    });

    testWidgets('with no style of its own it inherits the bubble default, '
        'which differs by alignment', (tester) async {
      List<InlineSpan> build(BuildContext context, BubbleAlignment a) =>
          FormatterUtils.buildTextSpan(
            'hi word',
            [
              _FixedFormatter([AttributedText(start: 3, end: 7)]),
            ],
            context,
            a,
          );

      await withContext(tester, (context) {
        final left = build(context, BubbleAlignment.left);
        final right = build(context, BubbleAlignment.right);
        // No underlyingText: the raw slice of the source text is shown.
        expect(plainTextsOf(left), ['hi ', 'word', '']);
        expect(
          (left[1] as TextSpan).style?.color,
          isNot((right[1] as TextSpan).style?.color),
        );
      });
    });

    testWidgets('a tappable range becomes a widget span whose tap fires with '
        'the display text', (tester) async {
      final taps = <String>[];
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 4,
          underlyingText: '@Bob',
          onTap: taps.add,
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'word here',
          [f],
          context,
          BubbleAlignment.left,
        );
        final detector = spanChild(spans[1], context) as GestureDetector;
        detector.onTap!();
      });

      expect(taps, ['@Bob']);
    });
  });

  // ==========================================================================
  group('buildTextSpan — a decorated inline range', () {
    testWidgets('gets a padded, rounded, coloured box around it', (
      tester,
    ) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 4,
          underlyingText: '@Bob',
          backgroundColor: const Color(0xFF112233),
          borderRadius: 7,
          padding: const EdgeInsets.all(3),
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'word here',
          [f],
          context,
          BubbleAlignment.left,
        );
        final box = spanChild(spans[1], context) as Container;
        expect(box.padding, const EdgeInsets.all(3));
        expect(
          (box.decoration as BoxDecoration).color,
          const Color(0xFF112233),
        );
        expect(textsIn(spans, context).single.data, '@Bob');
      });
    });

    testWidgets('with no underlyingText it shows the slice of source text it '
        'covers', (tester) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 3,
          end: 7,
          backgroundColor: const Color(0xFF445566),
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hi code there',
          [f],
          context,
          BubbleAlignment.left,
        );
        expect(textsIn(spans, context).single.data, 'code');
      });
    });

    testWidgets('a tappable decorated range fires with the SOURCE text, not '
        'the displayed text', (tester) async {
      // The bubble shows "@Bob" but the tap handler is handed the marker it
      // replaced, which is how the mention formatter finds the uid again.
      final taps = <String>[];
      final f = _FixedFormatter([
        AttributedText(
          start: 3,
          end: 12,
          underlyingText: '@Bob',
          backgroundColor: const Color(0xFF112233),
          onTap: taps.add,
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hi <@uid:u2> there',
          [f],
          context,
          BubbleAlignment.left,
        );
        final box = spanChild(spans[1], context) as Container;
        (box.child! as GestureDetector).onTap!();
        expect(textsIn(spans, context).single.data, '@Bob');
      });

      expect(taps, ['<@uid:u2>']);
    });

    testWidgets('a decorated range with a bad tap range is not dispatched', (
      tester,
    ) async {
      final taps = <String>[];
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 4,
          underlyingText: '@Bob',
          backgroundColor: const Color(0xFF112233),
          onTap: taps.add,
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'word here',
          [f],
          context,
          BubbleAlignment.left,
        );
        final box = spanChild(spans[1], context) as Container;
        // Move the range out of the text's bounds behind the span's back, the
        // way a formatter working off a stale copy of the text would.
        f.attributes.single.end = 99;
        (box.child! as GestureDetector).onTap!();
      });

      expect(taps, isEmpty);
    });
  });

  // ==========================================================================
  group('buildTextSpan — a block range', () {
    AttributedText block({Function(String)? onTap}) => AttributedText(
      start: 0,
      end: 9,
      underlyingText: 'line one\nline two',
      isBlockElement: true,
      border: const Border(left: BorderSide(width: 3)),
      backgroundColor: const Color(0xFF223344),
      padding: const EdgeInsets.all(8),
      onTap: onTap,
    );

    testWidgets('keeps its border and its multi-line content', (tester) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'code here',
          [
            _FixedFormatter([block()], once: true),
          ],
          context,
          BubbleAlignment.left,
        );
        final box = spanChild(spans[1], context) as Container;
        expect((box.decoration as BoxDecoration).border, isNotNull);
        expect(textsIn(spans, context).single.data, 'line one\nline two');
      });
    });

    testWidgets('a tappable block wraps its content in a detector', (
      tester,
    ) async {
      final taps = <String>[];
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'code here',
          [
            _FixedFormatter([block(onTap: taps.add)], once: true),
          ],
          context,
          BubbleAlignment.left,
        );
        final box = spanChild(spans[1], context) as Container;
        (box.child! as GestureDetector).onTap!();
      });
      expect(taps, ['code here']);
    });
  });

  // ==========================================================================
  group('buildTextSpan — forConversation flattens everything', () {
    testWidgets(
      'a multi-line block is cut to its first line plus an ellipsis',
      (tester) async {
        final f = _FixedFormatter([
          AttributedText(
            start: 0,
            end: 9,
            underlyingText: '  first  \n\n  second  ',
            isBlockElement: true,
            backgroundColor: const Color(0xFF222222),
          ),
        ]);

        await withContext(tester, (context) {
          final spans = FormatterUtils.buildTextSpan(
            'code here',
            [f],
            context,
            BubbleAlignment.left,
            forConversation: true,
          );
          final text = textsIn(spans, context).single;
          expect(text.data, 'first ...');
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
        });
      },
    );

    testWidgets('a single-line block keeps its line and loses the ellipsis', (
      tester,
    ) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 9,
          underlyingText: 'only line',
          isBlockElement: true,
          backgroundColor: const Color(0xFF222222),
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'code here',
          [f],
          context,
          BubbleAlignment.left,
          forConversation: true,
        );
        expect(textsIn(spans, context).single.data, 'only line');
      });
    });

    testWidgets('an undecorated range collapses its newlines into spaces and '
        'keeps its tap as a recognizer', (tester) async {
      final taps = <String>[];
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 9,
          underlyingText: ' one\n\ntwo ',
          onTap: taps.add,
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'code here',
          [f],
          context,
          BubbleAlignment.left,
          forConversation: true,
        );
        // A TextSpan, not a WidgetSpan: the subtitle's maxLines has to be able
        // to truncate it.
        final span = spans[1] as TextSpan;
        expect(span.text, 'one two');
        (span.recognizer! as TapGestureRecognizer).onTap!();
      });

      expect(taps, ['code here']);
    });
  });

  // ==========================================================================
  group('buildConversationTextSpan', () {
    testWidgets('an attributed range becomes a tappable, single-line span', (
      tester,
    ) async {
      final taps = <String>[];
      final f = _FixedFormatter([
        AttributedText(
          start: 3,
          end: 12,
          underlyingText: '@Bob\nsecond',
          onTap: taps.add,
        ),
      ]);

      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          'hi <@uid:u2> there',
          [f],
          context,
          null,
        );
        final span = spans[1] as TextSpan;
        expect(span.text, '@Bob second');
        expect(span.style?.color, isNotNull);
        (span.recognizer! as TapGestureRecognizer).onTap!();
      });

      expect(taps, ['@Bob\nsecond']);
    });

    /// The subtitle text produced for a single attributed range covering
    /// [text] in full — the shape the link formatter hands over.
    String shown(BuildContext context, String text) =>
        (FormatterUtils.buildConversationTextSpan(
                  text,
                  [
                    _FixedFormatter([
                      AttributedText(
                        start: 0,
                        end: text.length,
                        underlyingText: text,
                      ),
                    ]),
                  ],
                  context,
                  null,
                )[1]
                as TextSpan)
            .text!;

    testWidgets('a long URL is shortened to domain plus a clipped path', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final out = shown(
          context,
          'https://www.example.com/a/very/long/path/here',
        );
        expect(out, 'example.com/a/very/lon...');
        expect(out, isNot(contains('https://')), reason: 'www. goes too');
        expect(out.length, lessThanOrEqualTo(25));
      });
    });

    testWidgets('a path that already fits is kept whole', (tester) async {
      await withContext(tester, (context) {
        expect(
          shown(context, 'https://www.example.com/abc?q=looooooooooong'),
          'example.com/abc',
        );
      });
    });

    testWidgets('a URL whose host alone is too long is cut at the host', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          shown(
            context,
            'https://an-extremely-long-hostname-indeed.example.com/x',
          ),
          'an-extremely-long-host...',
        );
      });
    });

    testWidgets('a bare host with no path still gets an ellipsis', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          shown(context, 'https://www.shorter-host.io?a=bbbbbbbbbbbbbbbb'),
          'shorter-host.io...',
        );
      });
    });

    testWidgets('a URL that cannot be parsed is cut at the raw text', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(
          shown(context, 'https://[not-an-ipv6-literal/aaaaaaaaaaaaaaaaaa'),
          'https://[not-an-ipv6-l...',
        );
      });
    });

    testWidgets('a short URL and a non-URL are both left alone', (
      tester,
    ) async {
      await withContext(tester, (context) {
        expect(shown(context, 'https://a.io/x'), 'https://a.io/x');
        expect(
          shown(context, 'a very long sentence that is not a url at all'),
          'a very long sentence that is not a url at all',
        );
      });
    });
  });

  // ==========================================================================
  group('buildTextContent', () {
    testWidgets('an outgoing bubble with no block elements is one RichText, '
        'styled for the right side', (tester) async {
      await withContext(tester, (context) {
        final left = FormatterUtils.buildTextContent(
          'hello',
          [_FixedFormatter([])],
          context,
          BubbleAlignment.left,
        );
        final right = FormatterUtils.buildTextContent(
          'hello',
          [_FixedFormatter([])],
          context,
          BubbleAlignment.right,
        );
        expect(left.single, isA<RichText>());
        expect(
          (left.single as RichText).text.style?.color,
          isNot((right.single as RichText).text.style?.color),
        );
      });
    });

    testWidgets('a block splits the text into before / block / after widgets', (
      tester,
    ) async {
      const text = 'intro CODE outro';
      final f = _FixedFormatter([
        AttributedText(
          start: 6,
          end: 10,
          underlyingText: 'CODE',
          isBlockElement: true,
          border: const Border(left: BorderSide(width: 3)),
          backgroundColor: const Color(0xFF334455),
        ),
      ]);

      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          text,
          [f],
          context,
          BubbleAlignment.left,
        );
        expect(widgets, hasLength(3));
        expect(widgets[0], isA<Padding>());
        expect(widgets[2], isA<Padding>());
        final blockBox =
            ((widgets[1] as Padding).child! as Container).child! as Padding;
        expect((blockBox.child! as Text).data, 'CODE');
      });
    });

    testWidgets('a block with no border falls back to a filled box', (
      tester,
    ) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 4,
          underlyingText: 'CODE',
          isBlockElement: true,
        ),
      ]);

      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          'CODE tail',
          [f],
          context,
          BubbleAlignment.right,
        );
        final box = (widgets.first as Padding).child! as Container;
        expect((box.decoration as BoxDecoration).border, isNull);
        expect((box.child! as Text).data, 'CODE');
        expect((box.child! as Text).style?.fontFamily, 'monospace');
      });
    });

    testWidgets('a blockquote block is italic rather than monospaced', (
      tester,
    ) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 0,
          end: 5,
          underlyingText: 'quote',
          isBlockElement: true,
          border: const Border(left: BorderSide(width: 3)),
          // The style carries only the italic marker the block renderer reads;
          // it is not used verbatim because `attr.style` wins when present, so
          // this asserts through a style-free attribute instead.
        ),
      ]);

      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          'quote',
          [f],
          context,
          BubbleAlignment.left,
        );
        final inner =
            ((widgets.single as Padding).child! as Container).child! as Padding;
        expect((inner.child! as Text).style?.fontFamily, 'monospace');
      });
    });

    testWidgets('inline ranges inside the text before a block are still '
        'boxed', (tester) async {
      const text = 'hi @Bob CODE';
      final f = _FixedFormatter([
        AttributedText(
          start: 3,
          end: 7,
          underlyingText: '@Bob',
          backgroundColor: const Color(0xFF556677),
          padding: const EdgeInsets.all(2),
        ),
        AttributedText(
          start: 8,
          end: 12,
          underlyingText: 'CODE',
          isBlockElement: true,
          border: const Border(left: BorderSide(width: 3)),
        ),
      ]);

      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          text,
          [f],
          context,
          BubbleAlignment.left,
        );
        final before = (widgets.first as Padding).child! as RichText;
        final children = (before.text as TextSpan).children!;
        expect(children.first, isA<TextSpan>());
        expect(children.any((c) => c is WidgetSpan), isTrue);
      });
    });

    testWidgets('a block whose indices are nonsense is skipped', (
      tester,
    ) async {
      final f = _FixedFormatter([
        AttributedText(
          start: 40,
          end: 90,
          underlyingText: 'CODE',
          isBlockElement: true,
        ),
      ]);

      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          'short',
          [f],
          context,
          BubbleAlignment.left,
        );
        // Nothing but the trailing text survives.
        expect(widgets, hasLength(1));
        expect(widgets.single, isA<Padding>());
      });
    });
  });
}
