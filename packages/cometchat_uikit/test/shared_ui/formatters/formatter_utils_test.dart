/// Behaviour tests for FormatterUtils — Track 3 TEST3 (ENG-38684).
///
/// 434 executable lines at 14.7%. This is the layer that turns a message's
/// text into the spans a bubble paints: it runs the formatter chain, merges
/// each formatter's attributed ranges, and applies the caller's style
/// underneath. `buildTextSpan` here is the function whose style handling was
/// wrong in ENG-38859, so the merge order is worth holding down.
///
///   flutter test test/shared_ui/formatters/formatter_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [body] with a real BuildContext and a themed ancestor.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext) body,
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

/// Flattens a span tree to the styles actually applied to text.
List<TextStyle> stylesOf(List<InlineSpan> spans) {
  final out = <TextStyle>[];
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (s.style != null && (s.text?.isNotEmpty ?? false)) out.add(s.style!);
      s.children?.forEach(walk);
    }
  }

  spans.forEach(walk);
  return out;
}

String plainOf(List<InlineSpan> spans) =>
    spans.map((s) => s.toPlainText()).join();

void main() {
  // -------------------------------------------------------------------------
  group('ensureMarkdownFormatter', () {
    test('a null list becomes a lone markdown formatter', () {
      final r = FormatterUtils.ensureMarkdownFormatter(null);
      expect(r, hasLength(1));
      expect(r.single, isA<MarkdownTextFormatter>());
    });

    test('an empty list becomes a lone markdown formatter', () {
      expect(FormatterUtils.ensureMarkdownFormatter([]), hasLength(1));
    });

    test('a list already carrying one is returned untouched', () {
      final existing = <CometChatTextFormatter>[MarkdownTextFormatter()];
      final r = FormatterUtils.ensureMarkdownFormatter(existing);
      expect(identical(r, existing), isTrue, reason: 'no copy, no reorder');
    });

    test('markdown is prepended to a list without one', () {
      final mentions = CometChatMentionsFormatter();
      final r = FormatterUtils.ensureMarkdownFormatter([mentions]);
      expect(r, hasLength(2));
      expect(
        r.first,
        isA<MarkdownTextFormatter>(),
        reason: 'markdown runs first',
      );
      expect(r.last, same(mentions));
    });

    test('the caller order of the other formatters is preserved', () {
      final a = CometChatMentionsFormatter();
      final b = CometChatMentionsFormatter();
      final r = FormatterUtils.ensureMarkdownFormatter([a, b]);
      expect(r[1], same(a));
      expect(r[2], same(b));
    });
  });

  // -------------------------------------------------------------------------
  group('buildTextSpan', () {
    testWidgets('plain text with no formatters still yields the text', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hello world',
          null,
          context,
          BubbleAlignment.left,
        );
        expect(plainOf(spans), contains('hello world'));
      });
    });

    testWidgets('the caller style is applied to the text — ENG-38859', (
      tester,
    ) async {
      // The regression this file is most exposed to: TextStyle.merge lets the
      // argument win, so a careless merge order silently discards whatever the
      // caller passed. A distinctive size makes that visible.
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hello world',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          BubbleAlignment.left,
          textStyle: const TextStyle(fontSize: 27, letterSpacing: 3),
        );
        final styles = stylesOf(spans);
        expect(styles, isNotEmpty);
        expect(
          styles.any((s) => s.fontSize == 27),
          isTrue,
          reason: 'the caller size must survive the formatter chain',
        );
      });
    });

    testWidgets('markdown emphasis is rendered rather than left as markers', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'a **bold** word',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          BubbleAlignment.left,
        );
        final text = plainOf(spans);
        expect(text, contains('bold'));
        expect(
          stylesOf(spans).any(
            (s) =>
                s.fontWeight == FontWeight.bold ||
                s.fontWeight == FontWeight.w700,
          ),
          isTrue,
          reason: 'the emphasis is applied, not just stripped',
        );
      });
    });

    testWidgets('both bubble alignments produce spans', (tester) async {
      await withContext(tester, (context) {
        for (final a in BubbleAlignment.values) {
          expect(
            FormatterUtils.buildTextSpan(
              'hello',
              FormatterUtils.ensureMarkdownFormatter(null),
              context,
              a,
            ),
            isNotEmpty,
            reason: '$a',
          );
        }
      });
    });

    testWidgets('empty text does not throw', (tester) async {
      await withContext(tester, (context) {
        expect(
          () => FormatterUtils.buildTextSpan(
            '',
            FormatterUtils.ensureMarkdownFormatter(null),
            context,
            BubbleAlignment.left,
          ),
          returnsNormally,
        );
      });
    });

    testWidgets('a null alignment is tolerated', (tester) async {
      await withContext(tester, (context) {
        expect(
          () => FormatterUtils.buildTextSpan('hi', null, context, null),
          returnsNormally,
        );
      });
    });

    testWidgets('forConversation still produces the text', (tester) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildTextSpan(
          'hello world',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          BubbleAlignment.left,
          forConversation: true,
        );
        expect(plainOf(spans), contains('hello'));
      });
    });
  });

  // -------------------------------------------------------------------------
  group('buildConversationTextSpan', () {
    testWidgets('produces the subtitle text', (tester) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          'the last message',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          null,
        );
        expect(plainOf(spans), contains('the last message'));
      });
    });

    testWidgets('the supplied style reaches the spans', (tester) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          'the last message',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          const TextStyle(fontSize: 19),
        );
        expect(stylesOf(spans).any((s) => s.fontSize == 19), isTrue);
      });
    });

    testWidgets('markdown markers do not survive into a subtitle', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          'a **bold** word',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          null,
        );
        expect(
          plainOf(spans),
          isNot(contains('**')),
          reason: 'a subtitle shows the words, not the syntax',
        );
      });
    });

    testWidgets('a bare URL passes through — truncation is attribute-scoped', (
      tester,
    ) async {
      // `_truncateUrlForConversation` runs only over segments a formatter
      // attributed, and MarkdownTextFormatter marks `[text](url)`, not bare
      // autolinks. So a plain URL reaches the subtitle at full length here.
      //
      // Worth knowing because there are two independent URL shorteners with
      // different limits: this one at 25 characters, and
      // ConversationUtils._truncateUrlsInText at 30, which is the one that
      // actually shortens the subtitle on screen.
      const url =
          'https://example.com/a/very/long/path/that/keeps/going/and/going';
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          url,
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          null,
        );
        expect(plainOf(spans), url);
      });
    });

    testWidgets('an attributed link is what truncation applies to', (
      tester,
    ) async {
      // Markdown link syntax does get attributed, so this is the path that
      // reaches the shortener.
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          '[see here](https://example.com/a/very/long/path/that/keeps/going)',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          null,
        );
        final text = plainOf(spans);
        expect(text, isNot(contains('](')), reason: 'syntax is consumed');
        expect(text, contains('see here'));
      });
    });

    testWidgets('a short URL is left intact', (tester) async {
      await withContext(tester, (context) {
        final spans = FormatterUtils.buildConversationTextSpan(
          'https://a.co',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          null,
        );
        expect(plainOf(spans), contains('a.co'));
      });
    });

    testWidgets('empty text does not throw', (tester) async {
      await withContext(tester, (context) {
        expect(
          () => FormatterUtils.buildConversationTextSpan(
            '',
            FormatterUtils.ensureMarkdownFormatter(null),
            context,
            null,
          ),
          returnsNormally,
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  group('buildTextContent', () {
    testWidgets('plain text yields at least one widget', (tester) async {
      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          'hello world',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          BubbleAlignment.left,
        );
        expect(widgets, isNotEmpty);
      });
    });

    testWidgets('a fenced code block is split into its own widget', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final widgets = FormatterUtils.buildTextContent(
          'before\n```\ncode\n```\nafter',
          FormatterUtils.ensureMarkdownFormatter(null),
          context,
          BubbleAlignment.left,
        );
        expect(
          widgets.length,
          greaterThan(1),
          reason: 'block elements break the run into separate widgets',
        );
      });
    });

    testWidgets('empty text does not throw', (tester) async {
      await withContext(tester, (context) {
        expect(
          () => FormatterUtils.buildTextContent(
            '',
            FormatterUtils.ensureMarkdownFormatter(null),
            context,
            BubbleAlignment.left,
          ),
          returnsNormally,
        );
      });
    });
  });
}
