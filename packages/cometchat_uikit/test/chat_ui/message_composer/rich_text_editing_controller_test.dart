/// Behaviour tests for RichTextEditingController — Track 3 TEST3 (ENG-38684).
///
/// 1,260 executable lines at 12% coverage, the largest untested body of pure
/// logic left in the lane. It is a TextEditingController that maintains rich
/// formatting alongside the plain buffer, converts to and from markdown, and
/// tracks which formats apply at the cursor. No SDK, no network, no platform.
///
/// The contract that matters most is the markdown round trip: whatever the
/// user typed and styled has to survive `toMarkdown()` on send and
/// `hydrateFromMarkdown()` on edit, or the message changes under them.
///
///   flutter test test/chat_ui/message_composer/rich_text_editing_controller_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Selects [text]'s range [start, end) on [c] the way a drag would.
void select(RichTextEditingController c, int start, int end) {
  c.selection = TextSelection(baseOffset: start, extentOffset: end);
}

void main() {
  late RichTextEditingController c;

  setUp(() => c = RichTextEditingController());
  tearDown(() => c.dispose());

  // -------------------------------------------------------------------------
  group('pending formats', () {
    test('a controller starts with none', () {
      for (final f in FormatType.values) {
        expect(c.hasPendingFormat(f), isFalse, reason: '$f');
      }
    });

    test('add then has', () {
      c.addPendingFormat(FormatType.bold);
      expect(c.hasPendingFormat(FormatType.bold), isTrue);
      expect(c.hasPendingFormat(FormatType.italic), isFalse);
    });

    test('remove clears just the one', () {
      c.addPendingFormat(FormatType.bold);
      c.addPendingFormat(FormatType.italic);
      c.removePendingFormat(FormatType.bold);
      expect(c.hasPendingFormat(FormatType.bold), isFalse);
      expect(c.hasPendingFormat(FormatType.italic), isTrue);
    });

    test('toggle flips in both directions', () {
      c.togglePendingFormat(FormatType.underline);
      expect(c.hasPendingFormat(FormatType.underline), isTrue);
      c.togglePendingFormat(FormatType.underline);
      expect(c.hasPendingFormat(FormatType.underline), isFalse);
    });

    test('adding twice is idempotent', () {
      c.addPendingFormat(FormatType.bold);
      c.addPendingFormat(FormatType.bold);
      c.removePendingFormat(FormatType.bold);
      expect(c.hasPendingFormat(FormatType.bold), isFalse);
    });

    test('clearPendingFormats drops all of them', () {
      c.addPendingFormat(FormatType.bold);
      c.addPendingFormat(FormatType.italic);
      c.clearPendingFormats();
      expect(c.hasPendingFormat(FormatType.bold), isFalse);
      expect(c.hasPendingFormat(FormatType.italic), isFalse);
    });

    test('removing one that was never added is harmless', () {
      c.removePendingFormat(FormatType.bold);
      expect(c.hasPendingFormat(FormatType.bold), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('plain text', () {
    test('an empty controller has empty text', () {
      expect(c.plainText, isEmpty);
      expect(c.toMarkdown(), isEmpty);
    });

    test('plainText mirrors the buffer', () {
      c.text = 'hello world';
      expect(c.plainText, 'hello world');
    });

    test('a controller can be seeded with text', () {
      final seeded = RichTextEditingController(text: 'seeded');
      expect(seeded.plainText, 'seeded');
      seeded.dispose();
    });

    test('clear empties the buffer and the pending formats', () {
      c.text = 'hello';
      c.addPendingFormat(FormatType.bold);
      c.clear();
      expect(c.plainText, isEmpty);
      expect(c.hasPendingFormat(FormatType.bold), isFalse);
    });

    test('getStrippedPlainText returns text with no markdown markers', () {
      c.text = 'plain';
      expect(c.getStrippedPlainText(), isNot(contains('*')));
    });
  });

  // -------------------------------------------------------------------------
  group('applyFormat over a selection', () {
    test('bold wraps the selection in markdown on send', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.bold);
      expect(c.toMarkdown(), contains('**hello**'));
    });

    test('italic wraps the selection', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.italic);
      final md = c.toMarkdown();
      expect(md, anyOf(contains('*hello*'), contains('_hello_')));
    });

    test('strikethrough wraps the selection', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.strikethrough);
      expect(c.toMarkdown(), contains('~~hello~~'));
    });

    test('inline code wraps the selection', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.inlineCode);
      expect(c.toMarkdown(), contains('`hello`'));
    });

    test('the untouched remainder survives verbatim', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.bold);
      expect(c.toMarkdown(), contains('world'));
    });

    test('two formats over one selection both survive', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.bold);
      select(c, 0, 5);
      c.applyFormat(FormatType.italic);
      final md = c.toMarkdown();
      expect(md, contains('hello'));
      expect(md.length, greaterThan('hello world'.length));
    });

    test('applying a format to an empty selection does not throw', () {
      c.text = 'hello';
      select(c, 2, 2);
      expect(() => c.applyFormat(FormatType.bold), returnsNormally);
    });

    test('applying a format to empty text does not throw', () {
      expect(() => c.applyFormat(FormatType.bold), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  group('links', () {
    test('applyLinkFormat emits markdown link syntax', () {
      c.text = 'click here';
      select(c, 0, 10);
      c.applyLinkFormat('click here', 'https://example.com');
      expect(c.toMarkdown(), contains('](https://example.com)'));
    });

    test('the display text is what the user sees', () {
      c.text = 'click here';
      select(c, 0, 10);
      c.applyLinkFormat('click here', 'https://example.com');
      expect(
        c.plainText,
        isNot(contains('https://example.com')),
        reason: 'the URL is metadata, not visible text',
      );
      expect(c.plainText, contains('click here'));
    });

    test('removeLinkFormat drops the link but keeps the words', () {
      c.text = 'click here';
      select(c, 0, 10);
      c.applyLinkFormat('click here', 'https://example.com');
      c.removeLinkFormat(0, c.plainText.length);
      expect(c.toMarkdown(), isNot(contains('https://example.com')));
      expect(c.plainText, contains('click'));
    });

    test('checkLinkAtCursor is safe on plain text', () {
      c.text = 'no links here';
      c.selection = const TextSelection.collapsed(offset: 3);
      expect(() => c.checkLinkAtCursor(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // The round trip. This is the contract the composer depends on: a message
  // opened for edit must come back out unchanged if the user touches nothing.
  // -------------------------------------------------------------------------
  group('markdown round trip', () {
    test('a plain string survives hydration unchanged', () {
      c.hydrateFromMarkdown('just some text');
      expect(c.plainText, 'just some text');
      expect(c.toMarkdown(), 'just some text');
    });

    test('a markdown link hydrates to display text and re-emits its URL', () {
      c.hydrateFromMarkdown('see [the docs](https://example.com) now');
      expect(
        c.plainText,
        'see the docs now',
        reason: 'the markers and URL are stripped from the visible buffer',
      );
      expect(c.toMarkdown(), contains('[the docs](https://example.com)'));
    });

    test('two links round-trip through markdown', () {
      // Regression: the second link's span used to be recorded at its
      // markdown offset rather than its stripped one, so toMarkdown threw
      // RangeError. Fixed under ENG-39023.
      c.hydrateFromMarkdown('[a](https://a.com) and [b](https://b.com)');
      expect(c.plainText, 'a and b');
      final md = c.toMarkdown();
      expect(md, contains('[a](https://a.com)'));
      expect(md, contains('[b](https://b.com)'));
    });

    test('three links round-trip, with text around and between them', () {
      c.hydrateFromMarkdown(
        'x [a](https://a.com) y [b](https://b.com) z [c](https://c.com) w',
      );
      expect(c.plainText, 'x a y b z c w');
      final md = c.toMarkdown();
      for (final u in ['a.com', 'b.com', 'c.com']) {
        expect(md, contains('(https://$u)'), reason: u);
      }
    });

    test('adjacent links with nothing between them round-trip', () {
      c.hydrateFromMarkdown('[a](https://a.com)[b](https://b.com)');
      expect(c.plainText, 'ab');
      expect(c.toMarkdown(), contains('(https://b.com)'));
    });

    test('links with display text of differing lengths round-trip', () {
      // The shift depends on each marker's length, so uneven display text is
      // the case a naive fixed offset would get wrong.
      c.hydrateFromMarkdown(
        '[short](https://a.com) mid [a much longer label](https://b.com)',
      );
      expect(c.plainText, 'short mid a much longer label');
      final md = c.toMarkdown();
      expect(md, contains('[short](https://a.com)'));
      expect(md, contains('[a much longer label](https://b.com)'));
    });

    test('a link at the very start hydrates', () {
      c.hydrateFromMarkdown('[start](https://x.com) trailing');
      expect(c.plainText, 'start trailing');
    });

    test('a link at the very end hydrates', () {
      c.hydrateFromMarkdown('leading [end](https://x.com)');
      expect(c.plainText, 'leading end');
    });

    test('hydrating twice replaces rather than appends', () {
      c.hydrateFromMarkdown('[a](https://a.com)');
      c.hydrateFromMarkdown('[b](https://b.com)');
      expect(c.plainText, 'b');
      expect(c.toMarkdown(), isNot(contains('a.com')));
    });

    test('hydrating an empty string clears the controller', () {
      c.hydrateFromMarkdown('[a](https://a.com)');
      c.hydrateFromMarkdown('');
      expect(c.plainText, isEmpty);
    });

    test('malformed link syntax is left as literal text', () {
      c.hydrateFromMarkdown('[unclosed(https://x.com');
      expect(c.plainText, contains('unclosed'));
    });

    test('non-link markdown is preserved as raw text', () {
      // Only links are converted to spans; other markers stay in the buffer
      // and are rendered by the hidden-marker path.
      c.hydrateFromMarkdown('**bold** text');
      expect(c.toMarkdown(), contains('bold'));
    });
  });

  // -------------------------------------------------------------------------
  group('clearFormatting', () {
    test('formatting is dropped but the words remain', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.clearFormatting();
      expect(c.plainText, contains('hello'));
      expect(c.toMarkdown(), isNot(contains('**')));
    });

    test('clearFormatting on plain text is a no-op', () {
      c.text = 'hello';
      c.clearFormatting();
      expect(c.plainText, 'hello');
    });
  });

  // -------------------------------------------------------------------------
  group('getActiveFormats', () {
    test('no formats are active on plain text', () {
      c.text = 'hello';
      c.selection = const TextSelection.collapsed(offset: 2);
      expect(c.getActiveFormats(), isEmpty);
    });

    test('a pending format reports as active at the cursor', () {
      c.text = 'hello';
      c.selection = const TextSelection.collapsed(offset: 5);
      c.addPendingFormat(FormatType.bold);
      expect(c.getActiveFormats(), contains(FormatType.bold));
    });

    test('a bolded selection reports bold active', () {
      c.text = 'hello world';
      select(c, 0, 5);
      c.applyFormat(FormatType.bold);
      select(c, 1, 4);
      expect(c.getActiveFormats(), contains(FormatType.bold));
    });
  });

  // -------------------------------------------------------------------------
  group('buildTextSpan', () {
    testWidgets('plain text yields a span carrying the text', (tester) async {
      c.text = 'hello';
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = c.buildTextSpan(
                context: context,
                withComposing: false,
                style: const TextStyle(fontSize: 14),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(span.toPlainText(), contains('hello'));
    });

    testWidgets('the caller style reaches the span', (tester) async {
      c.text = 'hello';
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = c.buildTextSpan(
                context: context,
                withComposing: false,
                style: const TextStyle(fontSize: 23),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      final sizes = <double?>[span.style?.fontSize];
      span.visitChildren((s) {
        if (s is TextSpan) sizes.add(s.style?.fontSize);
        return true;
      });
      expect(sizes, contains(23.0));
    });

    testWidgets('an empty controller still builds a span', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => c.buildTextSpan(
                  context: context,
                  withComposing: false,
                  style: const TextStyle(),
                ),
                returnsNormally,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
