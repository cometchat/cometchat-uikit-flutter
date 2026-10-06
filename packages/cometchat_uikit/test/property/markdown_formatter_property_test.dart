/// Properties of the rich-text pipeline: `MarkdownTextFormatter` (text →
/// attributed ranges) and `FormatterUtils.buildTextSpan` (ranges → spans).
///
///   flutter test test/property/markdown_formatter_property_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

/// Letters and digits of [s], in order — what is left once every marker,
/// blank and bullet glyph is ignored.
String _contentOf(String s) => s.replaceAll(RegExp('[^$kContentLetters]'), '');

/// Markers whose formatting only ever removes the marker itself. Links are
/// deliberately absent: `[label](url)` hides the url by design.
const _lossless = [
  '*',
  '**',
  '****',
  '_',
  '__',
  '___',
  '~~',
  '~',
  '`',
  '```',
  '<u>',
  '</u>',
  '> ',
  '>',
  '- ',
  '<color=#00AA00>',
  '</color>',
];

void main() {
  testWidgets('formatting any unicode string never throws and every range '
      'lies inside the text', (tester) async {
    final context = await pumpContext(tester);
    final formatter = MarkdownTextFormatter();

    forAll((r) => genUnicode(r, maxParts: 16), (text) {
      for (final forConversation in [false, true]) {
        final attrs = formatter.getAttributedText(
          text,
          context,
          BubbleAlignment.left,
          forConversation: forConversation,
        );
        for (final a in attrs) {
          expect(a.start, greaterThanOrEqualTo(0), reason: '$a');
          expect(a.end, lessThanOrEqualTo(text.length), reason: '$a');
          expect(a.start, lessThanOrEqualTo(a.end), reason: '$a');
        }
      }
    }, cases: 200);
  });

  testWidgets('plain words with no markers produce no formatting at all', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final formatter = MarkdownTextFormatter();

    forAll(genPlainWords, (text) {
      expect(
        formatter.getAttributedText(text, context, BubbleAlignment.right),
        isEmpty,
      );
    });
  });

  testWidgets('plain words survive span building verbatim', (tester) async {
    final context = await pumpContext(tester);

    forAll(genPlainWords, (text) {
      final spans = FormatterUtils.buildTextSpan(
        text,
        [MarkdownTextFormatter()],
        context,
        BubbleAlignment.left,
      );
      expect(visibleText(spans, context), text);
    });
  });

  testWidgets('span building never throws on arbitrary unicode, for bubbles '
      'and for conversation subtitles', (tester) async {
    final context = await pumpContext(tester);

    forAll((r) => genUnicode(r, maxParts: 16), (text) {
      final formatters = [MarkdownTextFormatter()];
      FormatterUtils.buildTextSpan(
        text,
        formatters,
        context,
        BubbleAlignment.right,
      );
      FormatterUtils.buildTextSpan(
        text,
        formatters,
        context,
        BubbleAlignment.left,
        forConversation: true,
      );
      FormatterUtils.buildConversationTextSpan(text, formatters, context, null);
      expect(
        FormatterUtils.buildTextContent(
          text,
          formatters,
          context,
          BubbleAlignment.left,
        ),
        isNotEmpty,
      );
    }, cases: 200);
  });

  testWidgets('a single well-formed marker pair shows its content and hides '
      'only the markers', (tester) async {
    final context = await pumpContext(tester);
    const pairs = [
      ['**', '**'],
      ['__', '__'],
      ['_', '_'],
      ['~~', '~~'],
      ['`', '`'],
      ['<u>', '</u>'],
      ['<color=#AA00FF>', '</color>'],
    ];

    forAll(
      (r) {
        final pair = r.pick(pairs);
        return [genPlainWords(r, maxWords: 3), pair[0], pair[1]];
      },
      (input) {
        final body = input[0];
        final text = 'before ${input[1]}$body${input[2]} after';
        final spans = FormatterUtils.buildTextSpan(
          text,
          [MarkdownTextFormatter()],
          context,
          BubbleAlignment.left,
        );
        expect(visibleText(spans, context), 'before $body after');
      },
    );
  });

  testWidgets('formatting never loses or reorders a letter or digit, however '
      'the markers are nested or broken', (tester) async {
    final context = await pumpContext(tester);

    // FINDING: this invariant is FALSE for the shipped formatter.
    // `CometChatTextFormatter.mergeAttributedText` splits two overlapping
    // inline ranges into pieces, and `FormatterUtils.buildTextSpan` then
    // renders each piece's `underlyingText`. For crossing / nested markers the
    // pieces do not tile the original content, so characters are duplicated or
    // dropped on screen (e.g. an `_italic_` range crossing a `**bold**` one).
    // The property below is kept as the specification; the counter pins how
    // many of the 300 seeded inputs currently break it so that a fix (count
    // drops to 0 → tighten to `expect(broken, isEmpty)`) or a regression
    // (count rises) both fail this test.
    final broken = <String>[];
    forAll(
      (r) => genMarkdownish(r, markers: _lossless, alphabet: kContentLetters),
      (text) {
        final spans = FormatterUtils.buildTextSpan(
          text,
          [MarkdownTextFormatter()],
          context,
          BubbleAlignment.left,
        );
        if (_contentOf(visibleText(spans, context)) != _contentOf(text)) {
          broken.add(text);
        }
      },
      cases: 300,
    );

    expect(
      broken.length,
      _pinnedLossyInputs,
      reason:
          'inputs that lose or duplicate characters:\n'
          '${broken.take(8).map(showString).join('\n')}',
    );

    // The smallest reproductions, pinned verbatim. Correct output would be
    // 'a B C D e', 'a B C D e' and 'a G Z H e'.
    String render(String text) => visibleText(
      FormatterUtils.buildTextSpan(
        text,
        [MarkdownTextFormatter()],
        context,
        BubbleAlignment.left,
      ),
      context,
    );
    expect(render('a <u>B ~~C~~ D</u> e'), 'a C e');
    expect(render('a **B _C_ D** e'), 'a BCD e');
    expect(render('a <color=#00AA00>G _Z_ H</color> e'), 'a G _Z_ Z e');
  });

  test('stripping markdown for a subtitle never throws, never grows the text '
      'and leaves marker-free words untouched', () {
    forAll((r) => genUnicode(r, maxParts: 16), (text) {
      final out = ConversationUtils.stripMarkdownSyntax(text);
      expect(out.length, lessThanOrEqualTo(text.length));
      expect(out, out.trim(), reason: 'result is trimmed');
    }, cases: 200);

    forAll(genPlainWords, (text) {
      expect(ConversationUtils.stripMarkdownSyntax(text), text);
    });
  });

  test('a one-line fenced snippet is erased from the subtitle', () {
    // FINDING: `ConversationUtils.stripMarkdownSyntax` removes a code fence
    // with the pattern "```[^\n]*\n?" — i.e. the fence AND the rest of its
    // line, on the assumption that what follows the fence is a language tag.
    // For a fence opened and closed on one line the "language tag" is the
    // whole snippet, so a message that is just a one-line code block gets an
    // EMPTY conversation subtitle, and any text after an inline fence is lost.
    // Expected: 'print' and 'see print now'.
    forAll((r) => genAlnum(r, alphabet: kContentLetters), (code) {
      expect(ConversationUtils.stripMarkdownSyntax('```$code```'), '');
      expect(
        ConversationUtils.stripMarkdownSyntax('see ```$code``` now'),
        'see',
      );
    });
  });

  test('stripping markdown keeps every content letter in order', () {
    // Everything in [_lossless] except the code fence, which has its own
    // (pinned) behaviour below.
    final markers = _lossless.where((m) => m != '```').toList();
    forAll(
      (r) => genMarkdownish(r, markers: markers, alphabet: kContentLetters),
      (text) {
        expect(
          _contentOf(ConversationUtils.stripMarkdownSyntax(text)),
          _contentOf(text),
        );
      },
      cases: 300,
    );
  });
}

/// See the FINDING above.
const int _pinnedLossyInputs = 4;
