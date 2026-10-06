/// RichTextSpanManager — the span algebra the toolbar sits on.
///
/// `trailing_toolbar_test.dart` covers the inline-style (DD §8.3) surface and
/// the simple single-span markdown cases. This file covers the parts that only
/// fire on overlapping input: the split/gap arithmetic in `addFormat` and
/// `removeFormat`, the six-way branch in `onTextDeleted`, the offset shifting
/// in `onTextInserted`, and the marker table for the block formats.
///
/// Everything here is pure Dart — no SDK, no widgets.
///
///   flutter test test/chat_ui/message_composer/rich_text_span_manager_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The span covering [position], or null. `spans` is sorted by start.
RichTextSpan? _spanAt(RichTextSpanManager m, int position) {
  for (final span in m.spans) {
    if (position >= span.start && position < span.end) return span;
  }
  return null;
}

void main() {
  group('addFormat — overlap splitting', () {
    test('a format inside an existing span splits it into three', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 10, FormatType.bold)
        ..addFormat(3, 6, FormatType.italic);

      expect(m.spans.length, 3);
      expect(m.spans.map((s) => '${s.start}-${s.end}'), ['0-3', '3-6', '6-10']);
      expect(m.getFormatsAt(1), {FormatType.bold});
      expect(m.getFormatsAt(4), {FormatType.bold, FormatType.italic});
      expect(m.getFormatsAt(7), {FormatType.bold});
    });

    test('a format spanning two islands fills both gaps and the tail', () {
      final m = RichTextSpanManager()
        ..addFormat(5, 8, FormatType.bold)
        ..addFormat(12, 15, FormatType.bold)
        // Covers before-first, between, and after-last.
        ..addFormat(0, 20, FormatType.italic);

      expect(m.spans.map((s) => '${s.start}-${s.end}'), [
        '0-5',
        '5-8',
        '8-12',
        '12-15',
        '15-20',
      ]);
      // The gap pieces carry only the new format...
      expect(m.getFormatsAt(2), {FormatType.italic});
      expect(m.getFormatsAt(10), {FormatType.italic});
      expect(m.getFormatsAt(17), {FormatType.italic});
      // ...and the islands carry both.
      expect(m.getFormatsAt(6), {FormatType.bold, FormatType.italic});
      expect(m.getFormatsAt(13), {FormatType.bold, FormatType.italic});
    });

    test('metadata from both spans is merged on the overlapping part', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 10, FormatType.link, metadata: {'url': 'https://a'})
        ..addFormat(2, 5, FormatType.bold, metadata: {'title': 'T'});

      // Overlap keeps both keys; the untouched remainder keeps only its own.
      expect(m.getMetadataAt(3), {'url': 'https://a', 'title': 'T'});
      expect(m.getMetadataAt(7), {'url': 'https://a'});
      expect(m.getMetadataAt(50), isNull);
    });

    test('an empty or inverted range is ignored', () {
      final m = RichTextSpanManager()
        ..addFormat(4, 4, FormatType.bold)
        ..addFormat(9, 2, FormatType.bold);
      expect(m.spans, isEmpty);
    });

    test('adjacent same-format spans are merged into one', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 5, FormatType.bold)
        ..addFormat(5, 10, FormatType.bold);

      expect(m.spans.length, 1);
      expect(m.spans.single.start, 0);
      expect(m.spans.single.end, 10);
    });
  });

  group('removeFormat', () {
    test('removing from the middle keeps the format on both sides', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 10, FormatType.bold)
        ..removeFormat(3, 6, FormatType.bold);

      expect(m.getFormatsAt(1), {FormatType.bold});
      expect(m.getFormatsAt(4), isEmpty);
      expect(m.getFormatsAt(8), {FormatType.bold});
    });

    test('the other formats in the range survive the removal', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 10, FormatType.bold)
        ..addFormat(0, 10, FormatType.italic)
        ..removeFormat(3, 6, FormatType.bold);

      expect(m.getFormatsAt(1), {FormatType.bold, FormatType.italic});
      expect(m.getFormatsAt(4), {FormatType.italic});
      expect(m.getFormatsAt(8), {FormatType.bold, FormatType.italic});
    });

    test('removing link drops its metadata from the stripped part only', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 10, FormatType.link, metadata: {'url': 'https://a'})
        ..addFormat(0, 10, FormatType.bold)
        ..removeFormat(3, 6, FormatType.link);

      expect(m.getFormatsAt(4), {FormatType.bold});
      expect(_spanAt(m, 4)!.metadata, isNull);
      // Outside the removed range the link and its URL are untouched.
      expect(m.getLinkSpanAt(1)!.metadata, {'url': 'https://a'});
      expect(m.getLinkSpanAt(4), isNull);
    });

    test('removing a format the span does not carry changes nothing', () {
      final m = RichTextSpanManager()..addFormat(0, 10, FormatType.bold);
      m.removeFormat(0, 10, FormatType.italic);
      expect(m.spans.length, 1);
      expect(m.getFormatsAt(5), {FormatType.bold});
    });
  });

  group('onTextInserted', () {
    test('spans at or after the caret shift; a straddling span stretches', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 6, FormatType.bold)
        ..addFormat(10, 12, FormatType.italic)
        ..onTextInserted(4, 2);

      expect(m.spans.map((s) => '${s.start}-${s.end}'), ['0-8', '12-14']);
    });

    test('style ranges shift by the same rules', () {
      final m = RichTextSpanManager()
        ..applyInlineStyle(0, 6, const TextStyle(), id: 'a')
        ..applyInlineStyle(10, 12, const TextStyle(), id: 'b')
        ..onTextInserted(4, 2);

      expect(m.styleRanges.map((r) => '${r.start}-${r.end}'), ['0-8', '12-14']);
    });
  });

  group('onTextDeleted — every span/deletion relationship', () {
    // The deletion is always [10, 15) so the six branches are directly
    // comparable.
    RichTextSpanManager withSpan(int start, int end) => RichTextSpanManager()
      ..addFormat(start, end, FormatType.bold)
      ..onTextDeleted(10, 15);

    test('span entirely before the deletion is untouched', () {
      expect(withSpan(0, 5).spans.single.end, 5);
    });

    test('span entirely after the deletion shifts left by its length', () {
      final spans = withSpan(20, 25).spans;
      expect('${spans.single.start}-${spans.single.end}', '15-20');
    });

    test('span entirely inside the deletion is dropped', () {
      expect(withSpan(11, 13).spans, isEmpty);
    });

    test('deletion inside the span shrinks the span', () {
      final spans = withSpan(8, 18).spans;
      expect('${spans.single.start}-${spans.single.end}', '8-13');
    });

    test('deletion overlapping the span tail truncates it at the cut', () {
      final spans = withSpan(5, 12).spans;
      expect('${spans.single.start}-${spans.single.end}', '5-10');
    });

    test('deletion overlapping the span head pulls it back to the cut', () {
      final spans = withSpan(12, 20).spans;
      expect('${spans.single.start}-${spans.single.end}', '10-15');
    });
  });

  group('onTextDeleted — style ranges', () {
    RichTextSpanManager withRange(int start, int end) => RichTextSpanManager()
      ..applyInlineStyle(start, end, const TextStyle(), id: 'c')
      ..onTextDeleted(10, 15);

    test('range before the cut is untouched, range after shifts', () {
      expect(withRange(0, 5).styleRanges.single.end, 5);
      final after = withRange(20, 25).styleRanges.single;
      expect('${after.start}-${after.end}', '15-20');
    });

    test('a cut inside the range shrinks it', () {
      final r = withRange(8, 18).styleRanges.single;
      expect('${r.start}-${r.end}', '8-13');
    });

    test('a cut across the range tail truncates it', () {
      final r = withRange(5, 12).styleRanges.single;
      expect('${r.start}-${r.end}', '5-10');
    });

    test('a range swallowed by the cut collapses and is dropped', () {
      // No dedicated "inside the deletion" branch exists for style ranges —
      // it falls through to the head-overlap branch, producing an inverted
      // range that the trailing sweep removes.
      expect(withRange(11, 13).styleRanges, isEmpty);
    });
  });

  group('toMarkdown — markers', () {
    test('inline markers close and reopen around every newline', () {
      final m = RichTextSpanManager()..addFormat(0, 11, FormatType.bold);
      expect(m.toMarkdown('hello\nworld'), '**hello**\n**world**');
    });

    test('a blank line stays blank rather than gaining empty markers', () {
      final m = RichTextSpanManager()..addFormat(0, 4, FormatType.bold);
      expect(m.toMarkdown('a\n\nb'), '**a**\n\n**b**');
    });

    test('a code block wraps the whole span, newlines included', () {
      final m = RichTextSpanManager()..addFormat(0, 3, FormatType.codeBlock);
      expect(m.toMarkdown('a\nb'), '```\na\nb\n```');
    });

    test('a code block applies its co-formats inside the fence', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 5, FormatType.codeBlock)
        ..addFormat(0, 5, FormatType.bold);
      expect(m.toMarkdown('hello'), '```\n**hello**\n```');
    });

    test('a multi-line code block applies co-formats per line', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 3, FormatType.codeBlock)
        ..addFormat(0, 3, FormatType.bold);
      expect(m.toMarkdown('a\nb'), '```\n**a**\n**b**\n```');
    });

    test('link is the outermost marker and carries its url', () {
      final m = RichTextSpanManager()
        ..addFormat(0, 4, FormatType.bold)
        ..addFormat(0, 4, FormatType.link, metadata: {'url': 'https://x'});
      expect(m.toMarkdown('text'), '[**text**](https://x)');
    });

    test('a link with no url metadata falls back to the literal "url"', () {
      final m = RichTextSpanManager()..addFormat(0, 4, FormatType.link);
      expect(m.toMarkdown('text'), '[text](url)');
    });

    test('block formats use prefix-only markers', () {
      expect(
        (RichTextSpanManager()..addFormat(0, 4, FormatType.bulletList))
            .toMarkdown('item'),
        '- item',
      );
      expect(
        (RichTextSpanManager()..addFormat(0, 4, FormatType.orderedList))
            .toMarkdown('item'),
        '1. item',
      );
      expect(
        (RichTextSpanManager()..addFormat(0, 4, FormatType.blockquote))
            .toMarkdown('item'),
        '> item',
      );
    });

    test('italic stays innermost so adjacent spans never collide', () {
      // ENG-34742: "_uhku__**oiuhiouh**_" was the broken form.
      final m = RichTextSpanManager()
        ..addFormat(0, 4, FormatType.italic)
        ..addFormat(4, 12, FormatType.italic)
        ..addFormat(4, 12, FormatType.bold);
      expect(m.toMarkdown('uhkuoiuhiouh'), '_uhku_**_oiuhiouh_**');
    });
  });

  test('InlineStyleRange.toString names its bounds and id', () {
    const range = InlineStyleRange(
      start: 2,
      end: 7,
      style: TextStyle(),
      id: 'text-color',
    );
    expect(range.toString(), 'InlineStyleRange(2-7, id=text-color)');
  });

  test('RichTextSpan.toString includes metadata only when present', () {
    const bare = RichTextSpan(start: 0, end: 3, formats: {FormatType.bold});
    expect(bare.toString(), 'RichTextSpan(0-3, {FormatType.bold})');
    const withMeta = RichTextSpan(
      start: 0,
      end: 3,
      formats: {FormatType.link},
      metadata: {'url': 'u'},
    );
    expect(withMeta.toString(), contains('meta={url: u}'));
  });
}
