/// Internals of [RichTextEditingController] — the editing engine behind the
/// composer's WYSIWYG rich text.
///
/// The public tests in `rich_text_editing_controller_test.dart` pin the
/// markdown round trip. This file pins the parts that only fire while the
/// user is actually editing: the text-change listener (insert into / around a
/// formatted run, delete across one, list continuation on Enter), the
/// selection listener (cursor snapping, link taps), format application in all
/// four shapes (collapsed / selected × span / markdown), and the span tree
/// that `buildTextSpan` renders.
///
/// Everything here is pure logic over text + selection + spans; the few
/// `testWidgets` cases exist only because `buildTextSpan` needs a
/// [BuildContext].
///
///   flutter test test/chat_ui/message_composer/rich_text_editing_controller_internals_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller whose buffer already holds [text] without the change listener
/// having seen it — the state a field is in when a draft is restored.
///
/// Assigning `.text` afterwards would look like a giant insert and run the
/// whole listener, so seeding has to go through the constructor.
RichTextEditingController seeded(String text, {int? cursor}) {
  final c = RichTextEditingController(text: text);
  c.selection = TextSelection.collapsed(offset: cursor ?? text.length);
  return c;
}

/// Types [s] at [pos] the way the platform would: one value change carrying
/// both the new text and the moved cursor.
void typeAt(RichTextEditingController c, int pos, String s) {
  final t = c.text;
  c.value = TextEditingValue(
    text: t.substring(0, pos) + s + t.substring(pos),
    selection: TextSelection.collapsed(offset: pos + s.length),
  );
}

/// Deletes [start, end) the way backspace/selection-delete would.
void deleteRange(RichTextEditingController c, int start, int end) {
  final t = c.text;
  c.value = TextEditingValue(
    text: t.substring(0, start) + t.substring(end),
    selection: TextSelection.collapsed(offset: start),
  );
}

void selectRange(RichTextEditingController c, int start, int end) {
  c.selection = TextSelection(baseOffset: start, extentOffset: end);
}

/// Every [TextSpan] in [root] that carries text, in render order.
List<TextSpan> leaves(TextSpan root) {
  final out = <TextSpan>[];
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text != null) out.add(span);
      span.children?.forEach(walk);
    }
  }

  walk(root);
  return out;
}

/// The leaf whose text is exactly [text].
TextSpan leafNamed(TextSpan root, String text) =>
    leaves(root).firstWhere((s) => s.text == text);

Future<TextSpan> buildSpan(
  WidgetTester tester,
  RichTextEditingController c, {
  TextStyle style = const TextStyle(fontSize: 14),
}) async {
  late TextSpan span;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          span = c.buildTextSpan(
            context: context,
            style: style,
            withComposing: false,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return span;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═════════════════════════════════════════════════════════════════════════
  // Typing: what happens to the formatted runs as characters arrive.
  // ═════════════════════════════════════════════════════════════════════════
  group('typing around a formatted run', () {
    test('text typed with a pending format comes out formatted', () {
      final c = RichTextEditingController();
      c.addPendingFormat(FormatType.bold);
      typeAt(c, 0, 'abc');
      expect(c.spanManager.spans.single.start, 0);
      expect(c.spanManager.spans.single.end, 3);
      expect(c.toMarkdown(), '**abc**');
      c.dispose();
    });

    test('typing inside a bold run extends it', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      typeAt(c, 3, 'XY');
      expect(c.text, 'helXYlo world');
      expect(c.toMarkdown(), '**helXYlo** world');
      c.dispose();
    });

    test('typing at the far end of the buffer stays unformatted', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      typeAt(c, 11, '!');
      expect(c.toMarkdown(), '**hello** world!');
      c.dispose();
    });

    test('turning bold off mid-run splits it around the new character', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);

      c.selection = const TextSelection.collapsed(offset: 3);
      c.applyFormat(FormatType.bold); // user toggles bold off at the cursor
      expect(c.disabledFormats, contains(FormatType.bold));
      expect(c.getActiveFormats(), isEmpty);

      typeAt(c, 3, 'Z');
      expect(c.text, 'helZlo world');
      expect(
        c.toMarkdown(),
        '**hel**Z**lo** world',
        reason: 'the typed character is carved out of the bold run',
      );
      c.dispose();
    });

    test('a newline inside a run closes it and carries the format over', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 11);
      c.applyFormat(FormatType.bold);

      typeAt(c, 5, '\n');
      expect(c.text, 'hello\n world');
      expect(
        c.spanManager.spans.length,
        2,
        reason: 'the run is split at the newline',
      );
      expect(
        c.pendingFormats,
        contains(FormatType.bold),
        reason: 'so the next character on the new line is still bold',
      );
      c.dispose();
    });

    test('an active IME composing region is left alone', () {
      final c = RichTextEditingController(text: 'ab');
      c.addPendingFormat(FormatType.bold);
      c.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      );
      expect(
        c.spanManager.spans,
        isEmpty,
        reason: 'no span is created while the IME still owns the text',
      );
      c.dispose();
    });

    test('deleting a formatted run drops its span', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      deleteRange(c, 0, 5);
      expect(c.text, ' world');
      expect(c.spanManager.spans, isEmpty);
      expect(c.toMarkdown(), ' world');
      c.dispose();
    });

    test('deleting before a run shifts it left', () {
      final c = RichTextEditingController(text: 'xx hello');
      selectRange(c, 3, 8);
      c.applyFormat(FormatType.bold);
      deleteRange(c, 0, 3);
      expect(c.text, 'hello');
      expect(c.toMarkdown(), '**hello**');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Typed markdown that a delete breaks is rescued into spans, so the user
  // does not watch their formatting evaporate one backspace at a time.
  // ═════════════════════════════════════════════════════════════════════════
  group('broken markdown becomes spans', () {
    test('deleting a closing marker keeps the bold', () {
      final c = seeded('**bold**');
      deleteRange(c, 7, 8);
      expect(c.text, 'bold', reason: 'the remaining markers are stripped too');
      expect(c.spanManager.spans.single.formats, {FormatType.bold});
      expect(c.toMarkdown(), '**bold**');
      c.dispose();
    });

    test('nested markdown collapses into one multi-format span', () {
      final c = seeded('_**bi**_');
      deleteRange(c, 7, 8);
      expect(c.text, 'bi');
      expect(c.spanManager.spans.single.formats, {
        FormatType.italic,
        FormatType.bold,
      });
      c.dispose();
    });

    test('deleting the whole content leaves nothing behind', () {
      final c = seeded('**h**');
      deleteRange(c, 2, 3);
      expect(c.text, isEmpty);
      expect(c.spanManager.spans, isEmpty);
      c.dispose();
    });

    test('unrelated spans survive the conversion', () {
      final c = RichTextEditingController(text: 'zz **b** yy');
      selectRange(c, 0, 2);
      c.applyFormat(FormatType.underline);
      deleteRange(c, 7, 8);
      expect(c.text, 'zz b yy');
      expect(c.toMarkdown(), '<u>zz</u> **b** yy');
      c.dispose();
    });

    test('deleting an opening marker rescues every broken pattern', () {
      final c = seeded('**one** and **two**');
      deleteRange(c, 0, 1);
      expect(c.text, 'one and two');
      expect(c.spanManager.spans.map((s) => '${s.start}-${s.end}'), [
        '0-3',
        '8-11',
      ]);
      expect(c.toMarkdown(), '**one** and **two**');
      c.dispose();
    });

    test('a span whose edge sits inside a marker is remapped, not dropped', () {
      final c = RichTextEditingController(text: '**bold** x');
      selectRange(c, 1, 8);
      c.applyFormat(FormatType.underline);
      deleteRange(c, 7, 8);
      expect(c.text, 'bold x');
      expect(c.spanManager.spans.single.formats, {
        FormatType.underline,
        FormatType.bold,
      });
      c.dispose();
    });

    test('nested and sibling patterns are both converted', () {
      final c = seeded('_**bi**_ and **z**');
      deleteRange(c, 7, 8);
      expect(c.text, 'bi and z');
      expect(c.spanManager.spans.first.formats, {
        FormatType.italic,
        FormatType.bold,
      });
      expect(c.toMarkdown(), contains('**z**'));
      c.dispose();
    });

    test('a delete that touches no marker is an ordinary delete', () {
      final c = seeded('**bold** tail');
      deleteRange(c, 12, 13);
      expect(c.text, '**bold** tai');
      expect(c.spanManager.spans, isEmpty);
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Line-based formats: Enter continues the list, Enter on an empty item
  // leaves it, backspace through a prefix cleans the remnant up.
  // ═════════════════════════════════════════════════════════════════════════
  group('line continuation on Enter', () {
    test('a bullet line continues with another bullet', () {
      final c = seeded('- item');
      typeAt(c, 6, '\n');
      expect(c.text, '- item\n- ');
      expect(c.selection.baseOffset, 9, reason: 'cursor after the new prefix');
      c.dispose();
    });

    test('an ordered line continues with the next number', () {
      final c = seeded('1. item');
      typeAt(c, 7, '\n');
      expect(c.text, '1. item\n2. ');
      c.dispose();
    });

    test('an ordered line numbered 7 continues at 8', () {
      final c = seeded('7. item');
      typeAt(c, 7, '\n');
      expect(c.text, '7. item\n8. ');
      c.dispose();
    });

    test('a blockquote line continues as a blockquote', () {
      final c = seeded('> q');
      typeAt(c, 3, '\n');
      expect(c.text, '> q\n> ');
      c.dispose();
    });

    test('Enter on an empty bullet exits the list', () {
      final c = seeded('- a\n- ');
      typeAt(c, 6, '\n');
      expect(c.text, '- a\n\n');
      expect(c.selection.baseOffset, 4);
      c.dispose();
    });

    test('Enter on an empty numbered item exits the list', () {
      final c = seeded('1. a\n2. ');
      typeAt(c, 8, '\n');
      expect(c.text, '1. a\n\n');
      c.dispose();
    });

    test('a plain line gets no prefix', () {
      final c = seeded('plain');
      typeAt(c, 5, '\n');
      expect(c.text, 'plain\n');
      c.dispose();
    });

    test('backspacing a prefix down to its stub removes the stub', () {
      final c = seeded('- ');
      deleteRange(c, 1, 2);
      expect(
        c.text,
        isEmpty,
        reason: 'the leftover "-" is cleaned so the line is really plain',
      );
      c.dispose();
    });

    test('a leftover "1." from an ordered prefix is cleaned too', () {
      final c = seeded('1. ');
      deleteRange(c, 2, 3);
      expect(c.text, isEmpty);
      c.dispose();
    });

    test('a literal ">" the user typed is not cleaned up', () {
      final c = seeded('>x');
      deleteRange(c, 1, 2);
      expect(
        c.text,
        '>',
        reason: 'the old line had no valid prefix, so nothing to exit',
      );
      c.dispose();
    });

    test('deleting a list line renumbers the ones below it', () {
      final c = seeded('1. a\n2. b\n3. c');
      deleteRange(c, 5, 10); // drop the "2. b" line
      expect(c.text, '1. a\n2. c');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('applyFormat — line based', () {
    test('bullet prefix is added and the cursor moves with the text', () {
      final c = seeded('hello');
      c.applyFormat(FormatType.bulletList);
      expect(c.text, '- hello');
      expect(c.selection.baseOffset, 7);
      c.dispose();
    });

    test('a second line-based format replaces the first', () {
      final c = seeded('hello');
      c.applyFormat(FormatType.bulletList);
      c.applyFormat(FormatType.orderedList);
      expect(c.text, '1. hello');
      c.dispose();
    });

    test('applying the same format again toggles it off', () {
      final c = seeded('> q');
      c.selection = const TextSelection.collapsed(offset: 3);
      c.applyFormat(FormatType.blockquote);
      expect(c.text, 'q');
      c.dispose();
    });

    test('an ordered prefix of any number toggles off', () {
      final c = seeded('9. q');
      c.applyFormat(FormatType.orderedList);
      expect(c.text, 'q');
      c.dispose();
    });

    test('a new item numbers itself from the line above', () {
      final c = seeded('3. a\nb');
      c.applyFormat(FormatType.orderedList);
      expect(c.text, '3. a\n4. b');
      c.dispose();
    });

    test('an out-of-sequence block is renumbered when the list changes', () {
      final c = seeded('1. a\n5. b\n9. c', cursor: 4);
      c.applyFormat(FormatType.bulletList);
      expect(
        c.text,
        '- a\n5. b\n6. c',
        reason: 'the block now starts at 5, so the next item becomes 6',
      );
      c.dispose();
    });

    test('an invalid cursor is refused rather than crashing', () {
      final c = RichTextEditingController(text: 'abc');
      c.selection = const TextSelection.collapsed(offset: -1);
      c.applyFormat(FormatType.bulletList);
      expect(c.text, 'abc');
      c.dispose();
    });

    test('line prefixes survive the markdown round trip', () {
      final c = seeded('hello');
      c.applyFormat(FormatType.bulletList);
      expect(c.toMarkdown(), '- hello');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('applyFormat — inline', () {
    test('a collapsed toggle flips the pending format both ways', () {
      final c = RichTextEditingController();
      c.selection = const TextSelection.collapsed(offset: 0);
      c.applyFormat(FormatType.bold);
      expect(c.pendingFormats, contains(FormatType.bold));
      c.applyFormat(FormatType.bold);
      expect(c.pendingFormats, isEmpty);
      c.dispose();
    });

    test('applying then re-applying over a selection removes the span', () {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      expect(c.spanManager.spans, isEmpty);
      expect(c.toMarkdown(), 'hello');
      c.dispose();
    });

    test(
      'a partially covered selection gets the format added, not removed',
      () {
        final c = RichTextEditingController(text: 'hello world');
        selectRange(c, 0, 5);
        c.applyFormat(FormatType.bold);
        selectRange(c, 0, 11);
        c.applyFormat(FormatType.bold);
        expect(c.toMarkdown(), '**hello world**');
        c.dispose();
      },
    );

    test('selecting typed markdown and re-applying strips the markers', () {
      final c = RichTextEditingController(text: 'a **bold** b');
      selectRange(c, 4, 8);
      expect(c.getActiveFormats(), contains(FormatType.bold));
      c.applyFormat(FormatType.bold);
      expect(c.text, 'a bold b');
      expect(
        c.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
        reason: 'the selection follows the unwrapped content',
      );
      c.dispose();
    });

    test('a cursor inside typed markdown strips the markers too', () {
      final c = RichTextEditingController(text: 'a **bold** b');
      c.selection = const TextSelection.collapsed(offset: 5);
      c.applyFormat(FormatType.bold);
      expect(c.text, 'a bold b');
      expect(c.selection.baseOffset, 3, reason: 'shifted by the opening "**"');
      c.dispose();
    });

    test('codeBlock is delegated to the segment composer', () {
      final c = RichTextEditingController(text: 'x');
      var calls = 0;
      c.onInsertCodeBlock = () => calls++;
      c.applyFormat(FormatType.codeBlock);
      expect(calls, 1);
      expect(c.text, 'x', reason: 'the controller does not rewrite the buffer');
      c.dispose();
    });

    test('codeBlock with no delegate is a no-op', () {
      final c = RichTextEditingController(text: 'x');
      expect(() => c.applyFormat(FormatType.codeBlock), returnsNormally);
      expect(c.text, 'x');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('getActiveFormats', () {
    test('a span reports at a cursor inside it', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 3);
      expect(c.getActiveFormats(), {FormatType.bold});
      c.dispose();
    });

    test('a cursor past the run reports nothing', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 8);
      expect(c.getActiveFormats(), isEmpty);
      c.dispose();
    });

    test('typed markdown reports at the cursor', () {
      final c = RichTextEditingController(text: 'a **bold** b');
      c.selection = const TextSelection.collapsed(offset: 5);
      expect(c.getActiveFormats(), contains(FormatType.bold));
      c.dispose();
    });

    test('an <u> pattern reports underline', () {
      final c = RichTextEditingController(text: 'a <u>u</u> b');
      c.selection = const TextSelection.collapsed(offset: 6);
      expect(c.getActiveFormats(), contains(FormatType.underline));
      c.dispose();
    });

    test('a selection wider than the markdown reports nothing', () {
      final c = RichTextEditingController(text: 'a **bold** b');
      selectRange(c, 0, 12);
      expect(
        c.getActiveFormats(),
        isEmpty,
        reason: 'the pattern does not cover the whole selection',
      );
      c.dispose();
    });

    test('line formats report from the line prefix', () {
      for (final pair in const [
        ('- item', FormatType.bulletList),
        ('> item', FormatType.blockquote),
        ('4. item', FormatType.orderedList),
      ]) {
        final c = seeded(pair.$1);
        expect(c.getActiveFormats(), contains(pair.$2), reason: pair.$1);
        c.dispose();
      }
    });

    test('a prefix inside inline code is literal text, not a list', () {
      final c = RichTextEditingController(text: '`- x`');
      c.selection = const TextSelection.collapsed(offset: 3);
      final active = c.getActiveFormats();
      expect(active, contains(FormatType.inlineCode));
      expect(active, isNot(contains(FormatType.bulletList)));
      c.dispose();
    });

    test('a purely-emoji or all-marker run is not treated as markdown', () {
      final c = RichTextEditingController(text: '_😀_ and *****');
      c.selection = const TextSelection.collapsed(offset: 2);
      expect(c.getActiveFormats(), isEmpty);
      c.dispose();
    });

    test('a disabled format is subtracted from the active set', () {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 2);
      c.applyFormat(FormatType.bold);
      expect(c.getActiveFormats(), isEmpty);
      c.dispose();
    });

    // FINDING: getActiveFormats() falls back to `cursorPos - 1` when the
    // cursor sits at the end of a formatted run, but applyFormat() reads only
    // `getFormatsAt(cursorPos)`. So with the cursor at the end of a bold run
    // the toolbar shows Bold ON, yet tapping Bold takes the "turn ON" branch
    // and adds it to the pending set — the button cannot be switched off, and
    // the next typed character comes out bold. The two should read the same
    // position. Pinned as-is; do not "fix" the test when lib is fixed — flip
    // the expectation instead.
    test(
      'FINDING: at the end of a run the toolbar and the button disagree',
      () {
        final c = RichTextEditingController(text: 'hello world');
        selectRange(c, 0, 5);
        c.applyFormat(FormatType.bold);
        c.selection = const TextSelection.collapsed(offset: 5);

        expect(
          c.getActiveFormats(),
          contains(FormatType.bold),
          reason: 'the toolbar highlights Bold at the end of the run',
        );

        c.applyFormat(FormatType.bold); // user taps Bold to switch it off

        expect(
          c.pendingFormats,
          contains(FormatType.bold),
          reason: 'FINDING: the tap turns bold ON again instead of off',
        );
        expect(c.getActiveFormats(), contains(FormatType.bold));
        c.dispose();
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('selection listener', () {
    test('moving the cursor clears the disabled formats', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 2);
      c.applyFormat(FormatType.bold);
      expect(c.disabledFormats, isNotEmpty);

      c.selection = const TextSelection.collapsed(offset: 9);
      expect(c.disabledFormats, isEmpty);
      c.dispose();
    });

    test('a cursor dropped inside an opening marker snaps to the content', () {
      final c = RichTextEditingController(text: '**bold**');
      c.selection = const TextSelection.collapsed(offset: 1);
      expect(c.selection.baseOffset, 2);
      c.dispose();
    });

    test('a cursor inside a closing marker snaps back to the content end', () {
      final c = RichTextEditingController(text: '**bold**');
      c.selection = const TextSelection.collapsed(offset: 7);
      expect(c.selection.baseOffset, 6);
      c.dispose();
    });

    test('a cursor on plain text is left where the user put it', () {
      final c = RichTextEditingController(text: 'plain text');
      c.selection = const TextSelection.collapsed(offset: 4);
      expect(c.selection.baseOffset, 4);
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('links', () {
    test('tapping inside a link span reports its text, url and range', () {
      final c = RichTextEditingController(text: 'click here');
      selectRange(c, 0, 10);
      c.applyLinkFormat('click here', 'https://e.com');

      LinkTapDetails? tapped;
      c.onLinkTap = (d) => tapped = d;
      c.selection = const TextSelection.collapsed(offset: 3);

      expect(tapped, isNotNull);
      expect(tapped!.displayText, 'click here');
      expect(tapped!.url, 'https://e.com');
      expect(tapped!.start, 0);
      expect(tapped!.end, 10);
      c.dispose();
    });

    test('tapping inside a typed markdown link reports the same shape', () {
      final c = RichTextEditingController(text: 'a [lbl](https://e.com) b');
      LinkTapDetails? tapped;
      c.onLinkTap = (d) => tapped = d;
      c.selection = const TextSelection.collapsed(offset: 5);

      expect(tapped, isNotNull);
      expect(tapped!.displayText, 'lbl');
      expect(tapped!.url, 'https://e.com');
      expect(tapped!.start, 2);
      expect(tapped!.end, 22);
      c.dispose();
    });

    test('a non-collapsed selection never fires the callback', () {
      final c = RichTextEditingController(text: 'a [lbl](https://e.com) b');
      var fired = 0;
      c.onLinkTap = (_) => fired++;
      selectRange(c, 3, 6);
      c.checkLinkAtCursor();
      expect(fired, 0);
      c.dispose();
    });

    test('a cursor away from any link fires nothing', () {
      final c = RichTextEditingController(text: 'a [lbl](https://e.com) b');
      var fired = 0;
      c.onLinkTap = (_) => fired++;
      c.selection = const TextSelection.collapsed(offset: 23);
      expect(fired, 0);
      c.dispose();
    });

    test('applyLinkFormat with no selection appends at the end', () {
      final c = RichTextEditingController(text: 'abc');
      c.applyLinkFormat('Z', 'https://z.com');
      expect(c.text, 'abcZ');
      expect(c.toMarkdown(), 'abc[Z](https://z.com)');
      c.dispose();
    });

    test('editLinkFormat rewrites a span link and tells the formatters', () {
      final c = RichTextEditingController(text: 'hi there');
      selectRange(c, 0, 2);
      c.applyLinkFormat('hi', 'https://a.com');

      String? previousText;
      c.onFormatterTextChanged = (p) => previousText = p;
      c.editLinkFormat(0, 2, 'yo', 'https://b.com');

      expect(c.text, 'yo there');
      expect(c.toMarkdown(), '[yo](https://b.com) there');
      expect(previousText, 'hi there');
      c.dispose();
    });

    test('editLinkFormat rewrites a markdown link in place', () {
      final c = RichTextEditingController(text: 'x [old](https://a.com) y');
      c.editLinkFormat(2, 22, 'new', 'https://b.com');
      expect(c.text, 'x [new](https://b.com) y');
      c.dispose();
    });

    test('removeLinkFormat unwraps a markdown link to its display text', () {
      final c = RichTextEditingController(text: 'x [old](https://a.com) y');
      c.removeLinkFormat(2, 22);
      expect(c.text, 'x old y');
      c.dispose();
    });

    test(
      'removeLinkFormat on a span link keeps the text and drops the url',
      () {
        final c = RichTextEditingController(text: 'hi there');
        selectRange(c, 0, 2);
        c.applyLinkFormat('hi', 'https://a.com');
        c.removeLinkFormat(0, 2);
        expect(c.text, 'hi there');
        expect(c.toMarkdown(), 'hi there');
        c.dispose();
      },
    );

    test('out-of-range edits are refused', () {
      final c = RichTextEditingController(text: 'abc');
      c.editLinkFormat(-1, 2, 'x', 'u');
      c.editLinkFormat(0, 99, 'x', 'u');
      c.editLinkFormat(2, 2, 'x', 'u');
      c.removeLinkFormat(-1, 2);
      c.removeLinkFormat(2, 2);
      expect(c.text, 'abc');
      c.dispose();
    });

    test('removeLinkFormat over text that is not a link does nothing', () {
      final c = RichTextEditingController(text: 'plain words');
      c.removeLinkFormat(0, 5);
      expect(c.text, 'plain words');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('consumer inline styles', () {
    test('a coloured range serializes as a colour tag around the text', () {
      final c = RichTextEditingController(text: 'hello world');
      c.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      expect(c.toMarkdown(), '<color=#FF0000>hello</color> world');
      c.dispose();
    });

    test('a colour composes with a format marker instead of splitting it', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFF00FF00)),
        id: 'color',
      );
      expect(c.toMarkdown(), '<color=#00FF00>**hello**</color> world');
      c.dispose();
    });

    test('removeInlineStyle takes the colour back off', () {
      final c = RichTextEditingController(text: 'hello world');
      c.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'color',
      );
      c.removeInlineStyle(0, 5, id: 'color');
      expect(c.spanManager.styleRanges, isEmpty);
      expect(c.toMarkdown(), 'hello world');
      c.dispose();
    });

    test('collapsed ranges are ignored by both calls', () {
      final c = RichTextEditingController(text: 'hello');
      c.applyInlineStyle(2, 2, const TextStyle(), id: 'x');
      expect(c.spanManager.styleRanges, isEmpty);
      c.removeInlineStyle(2, 2, id: 'x');
      expect(c.spanManager.styleRanges, isEmpty);
      c.dispose();
    });

    test('mention ranges are read back from the attached formatter', () {
      final formatter = CometChatMentionsFormatter();
      formatter.trackedMentionPositions[6] = '@bob';
      final c = RichTextEditingController(
        text: 'hello @bob',
        formatters: [formatter],
      );
      expect(c.getMentionRanges(), [const TextRange(start: 6, end: 10)]);
      c.dispose();
    });

    test('with no formatters there are no mention ranges', () {
      final c = RichTextEditingController(text: 'hello @bob');
      expect(c.getMentionRanges(), isEmpty);
      c.dispose();
    });

    test('lastNonCollapsedSelection remembers the last drag', () {
      final c = RichTextEditingController(text: 'hello');
      expect(c.lastNonCollapsedSelection, isNull);
      selectRange(c, 1, 4);
      c.selection = const TextSelection.collapsed(offset: 0);
      expect(
        c.lastNonCollapsedSelection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
        reason: 'collapsing on blur must not lose what the user selected',
      );
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('triple backtick shortcut', () {
    test('``` at the start of the buffer opens a code block', () {
      final c = seeded('``');
      var calls = 0;
      c.onInsertCodeBlock = () => calls++;
      typeAt(c, 2, '`');
      expect(calls, 1);
      expect(c.text, isEmpty, reason: 'the backticks are consumed');
      c.dispose();
    });

    test('``` at the start of a later line also opens one', () {
      final c = seeded('x\n``');
      var calls = 0;
      c.onInsertCodeBlock = () => calls++;
      typeAt(c, 4, '`');
      expect(calls, 1);
      expect(c.text, 'x\n');
      c.dispose();
    });

    test('``` in the middle of a line is left as literal text', () {
      final c = seeded('x``');
      var calls = 0;
      c.onInsertCodeBlock = () => calls++;
      typeAt(c, 3, '`');
      expect(calls, 0);
      expect(c.text, 'x```');
      c.dispose();
    });

    test('with no delegate the backticks stay in the text', () {
      final c = seeded('``');
      typeAt(c, 2, '`');
      expect(c.text, '```');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('stripping and clearing', () {
    test('getStrippedPlainText removes markers and line prefixes', () {
      final c = RichTextEditingController(text: '- **bold** x\n> _it_\n3. `c`');
      expect(c.getStrippedPlainText(), 'bold x\nit\nc');
      c.dispose();
    });

    test('getStrippedPlainText leaves plain text alone', () {
      final c = RichTextEditingController(text: 'nothing to strip');
      expect(c.getStrippedPlainText(), 'nothing to strip');
      c.dispose();
    });

    test('clearFormatting drops spans, pending and disabled formats', () {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.addPendingFormat(FormatType.italic);
      c.clearFormatting();
      expect(c.spanManager.spans, isEmpty);
      expect(c.pendingFormats, isEmpty);
      expect(c.disabledFormats, isEmpty);
      expect(c.text, 'hello');
      c.dispose();
    });

    test('hydrateFromMarkdown resets the formatting state', () {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.addPendingFormat(FormatType.italic);

      c.hydrateFromMarkdown('go [here](https://x.com)');
      expect(c.text, 'go here');
      expect(c.pendingFormats, isEmpty);
      expect(c.toMarkdown(), 'go [here](https://x.com)');
      c.dispose();
    });

    test('formatting applied after hydration composes with the link', () {
      final c = RichTextEditingController();
      c.hydrateFromMarkdown('go [here](https://x.com)');
      selectRange(c, 0, 2);
      c.applyFormat(FormatType.bold);
      expect(c.toMarkdown(), '**go** [here](https://x.com)');
      c.dispose();
    });

    test('dispose leaves no spans behind', () {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.dispose();
      expect(c.spanManager.spans, isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Second pass: the branches that only fire on shapes a quick test misses.
  // ═════════════════════════════════════════════════════════════════════════
  group('multi-character edits inside a run', () {
    test('pasting a line break carries the run onto the new line', () {
      final c = RichTextEditingController(text: 'abcdef');
      selectRange(c, 0, 6);
      c.applyFormat(FormatType.bold);
      typeAt(c, 3, 'X\nY');
      expect(c.text, 'abcX\nYdef');
      // The dropped "e" is the same off-by-one recorded in the FINDING below:
      // the run is closed at a new-text offset before the spans are shifted.
      expect(c.toMarkdown(), '**abcX**\n**Yd**e**f**');
      c.dispose();
    });

    // FINDING: pressing Enter inside a formatted run closes the run with
    // `removeFormat(newlinePos, newlinePos + 1)`, where `newlinePos` is an
    // offset in the NEW text — but the span manager is still in old-text
    // coordinates at that point (`onTextInserted` runs on the next line). The
    // call therefore clears the format from whichever character used to sit
    // at the insert position, so one character next to the break silently
    // loses its formatting. Pinned as-is.
    test('FINDING: a character beside a mid-run newline loses its format', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 11);
      c.applyFormat(FormatType.bold);
      typeAt(c, 5, '\n');
      expect(c.text, 'hello\n world');
      expect(
        c.toMarkdown(),
        '**hello**\n **world**',
        reason: 'FINDING: the space should have stayed bold',
      );
      c.dispose();
    });

    test('a pending format adds to the run the cursor sits in', () {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 3);
      c.addPendingFormat(FormatType.italic);
      typeAt(c, 3, 'Q');
      final typed = c.spanManager.getFormatsAt(3);
      expect(typed, {
        FormatType.bold,
        FormatType.italic,
      }, reason: 'bold from the run it sits in, italic from the pending set');
      expect(c.toMarkdown(), contains('_Q_'));
      c.dispose();
    });

    test('a delete that leaves a still-parsing pattern is not rescued', () {
      // Dropping one "*" of the first closing marker turns "**one** and
      // **two**" into a single longer bold pattern, so the text still parses
      // as markdown and no span conversion is needed.
      final c = seeded('**one** and **two**');
      deleteRange(c, 6, 7);
      expect(c.text, '**one* and **two**');
      expect(c.spanManager.spans, isEmpty);
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('markdown dialects', () {
    test('__bold__ is recognised as bold', () {
      final c = RichTextEditingController(text: 'a __b__ c');
      c.selection = const TextSelection.collapsed(offset: 5);
      expect(c.getActiveFormats(), contains(FormatType.bold));
      c.dispose();
    });

    test('~~strike~~ is recognised as strikethrough', () {
      final c = RichTextEditingController(text: 'a ~~b~~ c');
      c.selection = const TextSelection.collapsed(offset: 5);
      expect(c.getActiveFormats(), contains(FormatType.strikethrough));
      c.dispose();
    });

    test('`code` is recognised as inline code', () {
      final c = RichTextEditingController(text: 'a `b` c');
      c.selection = const TextSelection.collapsed(offset: 3);
      expect(c.getActiveFormats(), contains(FormatType.inlineCode));
      c.dispose();
    });

    test('all of them strip down to plain text together', () {
      final c = RichTextEditingController(
        text: '__b__ ~~s~~ `c` <u>u</u> [l](https://x.com)',
      );
      expect(c.getStrippedPlainText(), 'b s c u l');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('ordered list renumbering', () {
    test('a two-digit prefix shifts the spans that follow it', () {
      final c = seeded('9. a\n1. b\nc', cursor: 10);
      selectRange(c, 10, 11);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 10);
      c.applyFormat(FormatType.orderedList);

      expect(c.text, '9. a\n10. b\n11. c');
      expect(
        c.toMarkdown(),
        '9. a\n10. b\n11. **c**',
        reason: 'the bold run moves with the longer prefixes',
      );
      c.dispose();
    });

    test('a cursor in a renumbered line keeps its place in the content', () {
      final c = seeded('1. a\n5. bX\n9. c');
      deleteRange(c, 9, 10); // backspace the "X"
      expect(c.text, '1. a\n2. b\n3. c');
      expect(
        c.selection.baseOffset,
        9,
        reason: 'the prefix kept its length, so the caret does not move',
      );
      c.dispose();
    });

    test('renumbering to a shorter prefix pulls the spans back with it', () {
      final c = seeded('8. aX\n10. b');
      selectRange(c, 10, 11);
      c.applyFormat(FormatType.bold);
      c.selection = const TextSelection.collapsed(offset: 5);
      deleteRange(c, 4, 5); // backspace the "X"

      expect(c.text, '8. a\n9. b');
      expect(
        c.toMarkdown(),
        '8. a\n9. **b**',
        reason: 'the bold run still covers "b" after the prefix shrank',
      );
      c.dispose();
    });

    test('Enter in the middle of a list line still continues the list', () {
      final c = seeded('- item tail', cursor: 6);
      typeAt(c, 6, '\n');
      expect(c.text, '- item\n-  tail');
      expect(c.selection.baseOffset, 9);
      c.dispose();
    });

    test('a broken prefix on a later line is cleaned up too', () {
      final c = seeded('first\n> ');
      deleteRange(c, 7, 8);
      expect(c.text, 'first\n');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('editLinkFormat length changes', () {
    test('a longer markdown link shifts the spans after it', () {
      final c = RichTextEditingController(text: 'x [old](https://a.com) tail');
      selectRange(c, 23, 27);
      c.applyFormat(FormatType.bold);
      c.editLinkFormat(2, 22, 'brand new label', 'https://much-longer.example');

      expect(c.text, 'x [brand new label](https://much-longer.example) tail');
      expect(
        c.toMarkdown(),
        contains('**tail**'),
        reason: 'the trailing bold run survives the longer replacement',
      );
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // buildTextSpan — what the field actually paints.
  // ═════════════════════════════════════════════════════════════════════════
  group('buildTextSpan', () {
    testWidgets('a bold span is painted bold', (tester) async {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);
      expect(leafNamed(span, 'hello').style?.fontWeight, FontWeight.bold);
      expect(leafNamed(span, ' world').style?.fontWeight, isNull);
      c.dispose();
    });

    testWidgets('inline code gets a monospace face and a backdrop', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'ab cd');
      selectRange(c, 0, 2);
      c.applyFormat(FormatType.inlineCode);
      final span = await buildSpan(tester, c);
      final code = leafNamed(span, 'ab');
      expect(code.style?.fontFamily, 'monospace');
      expect(code.style?.backgroundColor, isNotNull);
      c.dispose();
    });

    testWidgets('a link span is underlined and recoloured', (tester) async {
      final c = RichTextEditingController(text: 'click here');
      selectRange(c, 0, 5);
      c.applyLinkFormat('click', 'https://e.com');
      final span = await buildSpan(tester, c);
      final link = leafNamed(span, 'click');
      expect(link.style?.decoration, TextDecoration.underline);
      expect(link.style?.color, const Color(0xFF1976D2));
      c.dispose();
    });

    testWidgets('whitespace under a strikethrough gets a visible backdrop', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'ab  cd');
      selectRange(c, 2, 4);
      c.applyFormat(FormatType.strikethrough);
      final span = await buildSpan(tester, c);
      final blank = leafNamed(span, '  ');
      expect(blank.style?.decoration, TextDecoration.lineThrough);
      expect(
        blank.style?.backgroundColor,
        isNotNull,
        reason: 'a line through two spaces is otherwise invisible',
      );
      c.dispose();
    });

    testWidgets('a blockquote line renders a bar and a tinted background', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> quoted');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), contains('┃ '));
      expect(span.toPlainText(), isNot(contains('> ')));
      expect(leafNamed(span, 'quoted').style?.backgroundColor, isNotNull);
      c.dispose();
    });

    testWidgets('an empty blockquote still paints its background', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> ');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), contains('┃ '));
      c.dispose();
    });

    testWidgets('a bullet line shows a bullet glyph instead of the dash', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '- item');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), '• item');
      c.dispose();
    });

    testWidgets('an ordered line keeps its number prefix', (tester) async {
      final c = RichTextEditingController(text: '2. item');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), '2. item');
      c.dispose();
    });

    testWidgets('a span inside a bullet line is still styled', (tester) async {
      final c = RichTextEditingController(text: '- item');
      selectRange(c, 2, 6);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);
      expect(leafNamed(span, 'item').style?.fontWeight, FontWeight.bold);
      c.dispose();
    });

    testWidgets('a span inside a blockquote keeps the quote background', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> quoted');
      selectRange(c, 2, 8);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);
      final quoted = leafNamed(span, 'quoted');
      expect(quoted.style?.fontWeight, FontWeight.bold);
      expect(quoted.style?.backgroundColor, isNotNull);
      c.dispose();
    });

    testWidgets('typed markdown renders styled with the markers hidden', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'plain **b**');
      final span = await buildSpan(tester, c);

      expect(
        span.toPlainText(),
        'plain **b**',
        reason: 'the marker characters stay in the buffer so offsets hold',
      );
      expect(leafNamed(span, 'b').style?.fontWeight, FontWeight.bold);
      final marker = leaves(span).firstWhere((s) => s.text == '**');
      expect(marker.style?.fontSize, 0.01, reason: 'markers are collapsed');
      expect(marker.style?.color, Colors.transparent);
      c.dispose();
    });

    testWidgets('nested markdown applies both formats to the inner text', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '_**bi**_');
      final span = await buildSpan(tester, c);
      final inner = leafNamed(span, 'bi');
      expect(inner.style?.fontStyle, FontStyle.italic);
      expect(inner.style?.fontWeight, FontWeight.bold);
      c.dispose();
    });

    testWidgets('a consumer colour reaches the painted span', (tester) async {
      final c = RichTextEditingController(text: 'hello world');
      c.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFF00FF00)),
        id: 'color',
      );
      final span = await buildSpan(tester, c);
      expect(leafNamed(span, 'hello').style?.color, const Color(0xFF00FF00));
      c.dispose();
    });

    testWidgets('a consumer colour composes with bold rather than erasing it', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'hello world');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.bold);
      c.applyInlineStyle(
        0,
        5,
        const TextStyle(color: Color(0xFF00FF00)),
        id: 'color',
      );
      final span = await buildSpan(tester, c);
      final styled = leafNamed(span, 'hello');
      expect(styled.style?.color, const Color(0xFF00FF00));
      expect(styled.style?.fontWeight, FontWeight.bold);
      c.dispose();
    });

    testWidgets('multiple lines are joined by real newlines', (tester) async {
      final c = RichTextEditingController(text: '> q\n- b\nplain');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), '┃ q\n• b\nplain');
      c.dispose();
    });

    testWidgets('plain text with no formatting takes the parent path', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'nothing special');
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), 'nothing special');
      c.dispose();
    });

    testWidgets('a bold run inside a bullet line is bounded by plain text', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '- ab cd ef');
      selectRange(c, 5, 7);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);

      expect(span.toPlainText(), '• ab cd ef');
      expect(leafNamed(span, 'ab ').style?.fontWeight, isNull);
      expect(leafNamed(span, 'cd').style?.fontWeight, FontWeight.bold);
      expect(leafNamed(span, ' ef').style?.fontWeight, isNull);
      c.dispose();
    });

    testWidgets('a bold run inside a blockquote keeps the quote backdrop', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> ab cd ef');
      selectRange(c, 5, 7);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);

      for (final part in ['ab ', 'cd', ' ef']) {
        expect(
          leafNamed(span, part).style?.backgroundColor,
          isNotNull,
          reason: 'the whole quoted line is tinted: $part',
        );
      }
      expect(leafNamed(span, 'cd').style?.fontWeight, FontWeight.bold);
      c.dispose();
    });

    testWidgets('markdown and a span coexist on one bullet line', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '- x **b** y');
      selectRange(c, 10, 11);
      c.applyFormat(FormatType.underline);
      final span = await buildSpan(tester, c);

      expect(leafNamed(span, 'b').style?.fontWeight, FontWeight.bold);
      expect(leafNamed(span, 'y').style?.decoration, TextDecoration.underline);
      c.dispose();
    });

    testWidgets('markdown and a span coexist on one blockquote line', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> x **b** y');
      selectRange(c, 10, 11);
      c.applyFormat(FormatType.underline);
      final span = await buildSpan(tester, c);

      expect(leafNamed(span, 'b').style?.fontWeight, FontWeight.bold);
      expect(leafNamed(span, 'y').style?.decoration, TextDecoration.underline);
      c.dispose();
    });

    testWidgets('plain text after the last markdown match is still emitted', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'x **b** y');
      selectRange(c, 0, 1);
      c.applyFormat(FormatType.underline);
      final span = await buildSpan(tester, c);

      expect(span.toPlainText(), 'x **b** y');
      expect(leafNamed(span, 'x').style?.decoration, TextDecoration.underline);
      expect(leafNamed(span, ' y').style?.fontWeight, isNull);
      c.dispose();
    });

    testWidgets('a decoration on the caller style is combined, not replaced', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'hello');
      selectRange(c, 0, 5);
      c.applyFormat(FormatType.strikethrough);
      final span = await buildSpan(
        tester,
        c,
        style: const TextStyle(
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      );
      expect(
        leafNamed(span, 'hello').style?.decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
      c.dispose();
    });

    testWidgets('a code block span renders dark and monospaced', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'code here');
      c.spanManager.addFormat(0, 4, FormatType.codeBlock);
      final span = await buildSpan(tester, c);

      final code = leafNamed(span, 'code');
      expect(code.style?.fontFamily, 'monospace');
      expect(code.style?.backgroundColor, const Color(0xFF2D2D2D));
      expect(code.style?.color, const Color(0xFFFFFFFF));
      expect(c.toMarkdown(), '```\ncode\n``` here');
      c.dispose();
    });

    testWidgets('a consumer colour inside a bullet line survives the rebuild', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '- hello world');
      c.applyInlineStyle(
        2,
        7,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'col',
      );
      final span = await buildSpan(tester, c);
      expect(leafNamed(span, 'hello').style?.color, const Color(0xFFFF0000));
      expect(leafNamed(span, ' world').style?.color, isNull);
      c.dispose();
    });

    testWidgets('a consumer colour inside a blockquote keeps the backdrop', (
      tester,
    ) async {
      final c = RichTextEditingController(text: '> hello world');
      c.applyInlineStyle(
        2,
        7,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'col',
      );
      final span = await buildSpan(tester, c);
      final coloured = leafNamed(span, 'hello');
      expect(coloured.style?.color, const Color(0xFFFF0000));
      expect(coloured.style?.backgroundColor, isNotNull);
      c.dispose();
    });

    testWidgets('two overlapping consumer styles compose in the overlap', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'hello world');
      c.applyInlineStyle(
        0,
        8,
        const TextStyle(color: Color(0xFFFF0000)),
        id: 'colour',
      );
      c.applyInlineStyle(
        3,
        11,
        const TextStyle(backgroundColor: Color(0xFF0000FF)),
        id: 'highlight',
      );
      final span = await buildSpan(tester, c);

      expect(leafNamed(span, 'hel').style?.color, const Color(0xFFFF0000));
      expect(leafNamed(span, 'hel').style?.backgroundColor, isNull);
      final overlap = leafNamed(span, 'lo wo');
      expect(overlap.style?.color, const Color(0xFFFF0000));
      expect(overlap.style?.backgroundColor, const Color(0xFF0000FF));
      expect(leafNamed(span, 'rld').style?.color, isNull);
      c.dispose();
    });

    // FINDING: a mention is rendered through its formatter attribution, whose
    // `underlyingText` replaces the matched range. When a format span splits
    // the attribution in two, `_buildMergedSegments` emits the display text on
    // the first sub-segment and then the raw buffer text of the second one, so
    // the tail of the mention is painted twice — "@bob" renders as "@bobob".
    // Pinned as-is.
    testWidgets('FINDING: a format applied over part of a mention doubles it', (
      tester,
    ) async {
      final formatter = CometChatMentionsFormatter();
      formatter.trackedMentionPositions[3] = '@bob';
      final c = RichTextEditingController(
        text: 'hi @bob ok',
        formatters: [formatter],
      );
      selectRange(c, 3, 5); // bold only "@b", splitting the mention
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);

      expect(
        span.toPlainText(),
        'hi @bobob ok',
        reason: 'FINDING: the painted text should still read "hi @bob ok"',
      );
      c.dispose();
    });

    testWidgets('a mention keeps its own styling next to a bold run', (
      tester,
    ) async {
      final formatter = CometChatMentionsFormatter();
      formatter.trackedMentionPositions[3] = '@bob';
      final c = RichTextEditingController(
        text: 'hi @bob ok',
        formatters: [formatter],
      );
      selectRange(c, 0, 2);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);

      expect(leafNamed(span, 'hi').style?.fontWeight, FontWeight.bold);
      final mention = leafNamed(span, '@bob');
      expect(mention.style?.color, isNotNull);
      expect(
        mention.style?.backgroundColor,
        isNotNull,
        reason: 'the mention chip keeps its pill background',
      );
      c.dispose();
    });

    testWidgets('a mention inside a bold selection keeps the mention style', (
      tester,
    ) async {
      final formatter = CometChatMentionsFormatter();
      formatter.trackedMentionPositions[3] = '@bob';
      final c = RichTextEditingController(
        text: 'hi @bob ok',
        formatters: [formatter],
      );
      selectRange(c, 0, 10);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);

      expect(leafNamed(span, 'hi ').style?.fontWeight, FontWeight.bold);
      expect(leafNamed(span, ' ok').style?.fontWeight, FontWeight.bold);
      expect(
        leafNamed(span, '@bob').style?.fontWeight,
        isNot(FontWeight.bold),
        reason: 'the mention attribution wins over the format laid across it',
      );
      c.dispose();
    });

    testWidgets('a mention inside a bullet line still renders', (tester) async {
      final formatter = CometChatMentionsFormatter();
      formatter.trackedMentionPositions[5] = '@bob';
      final c = RichTextEditingController(
        text: '- hi @bob ok',
        formatters: [formatter],
      );
      final span = await buildSpan(tester, c);

      expect(span.toPlainText(), '• hi @bob ok');
      expect(leafNamed(span, '@bob').style?.color, isNotNull);
      c.dispose();
    });

    testWidgets('a mentions formatter still renders alongside a span', (
      tester,
    ) async {
      final c = RichTextEditingController(
        text: 'hi @bob ok',
        formatters: [CometChatMentionsFormatter()],
      );
      selectRange(c, 0, 2);
      c.applyFormat(FormatType.bold);
      final span = await buildSpan(tester, c);
      expect(span.toPlainText(), 'hi @bob ok');
      expect(leafNamed(span, 'hi').style?.fontWeight, FontWeight.bold);
      c.dispose();
    });
  });
}
