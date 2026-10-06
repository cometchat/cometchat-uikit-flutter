/// Segment-based composition — [SegmentComposerController] and
/// [SegmentComposerWidget].
///
/// The composer is not one text field: prose and code blocks live in separate
/// segments, each with its own controller and focus node, and the sendable
/// markdown is assembled from all of them. Nearly every branch here depends on
/// which segment has focus, so the controller is driven through a real pumped
/// widget rather than in isolation — an unattached [FocusNode] never reports
/// focus, and `focusedSegment` is what the controller keys off.
///
///   flutter test test/chat_ui/message_composer/segment_composer_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors how the composer hosts the widget: a [ListenableBuilder] rebuilds
/// it whenever the controller changes, which is what makes a newly added
/// segment reach the tree (and therefore be focusable).
Widget host(
  SegmentComposerController controller, {
  String placeholder = 'Message',
  ValueChanged<String>? onChange,
  ValueChanged<KeyboardInsertedContent>? onContentInserted,
  Future<bool> Function()? onPasteImage,
  TextStyle? textStyle,
  TextStyle? placeholderStyle,
}) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (_, _) => SegmentComposerWidget(
        controller: controller,
        placeholder: placeholder,
        onChange: onChange,
        onContentInserted: onContentInserted,
        onPasteImage: onPasteImage,
        textStyle: textStyle,
        placeholderStyle: placeholderStyle,
      ),
    ),
  ),
);

/// A compact rendering of the segment list, e.g. `N("before"),C("code"),N("")`.
String shape(SegmentComposerController c) => c.segments
    .map(
      (s) =>
          '${s.type == SegmentType.code ? "C" : "N"}("${s.controller.text}")',
    )
    .join(',');

ComposerSegment codeSegmentOf(SegmentComposerController c) =>
    c.segments.firstWhere((s) => s.type == SegmentType.code);

/// The [TextField] bound to [segment]. A prose segment is a [TextFormField],
/// which builds a [TextField] with the same controller, so matching on the
/// controller finds exactly one field either way.
Finder fieldFor(ComposerSegment segment) => find.byWidgetPredicate(
  (w) => w is TextField && w.controller == segment.controller,
);

/// Answers the clipboard channel with [text] (or nothing when null).
void mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return text == null ? null : <String, dynamic>{'text': text};
        case 'Clipboard.hasStrings':
          return <String, dynamic>{'value': text != null && text.isNotEmpty};
      }
      return null;
    },
  );
}

/// Presses Cmd+V on whatever currently holds focus.
Future<void> pressPaste(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pumpAndSettle();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  group('ComposerSegment', () {
    test('a normal segment carries a rich controller, a code one does not', () {
      final normal = ComposerSegment(id: 'a', type: SegmentType.normal);
      final code = ComposerSegment(id: 'b', type: SegmentType.code);
      expect(normal.controller, isA<RichTextEditingController>());
      expect(code.controller, isNot(isA<RichTextEditingController>()));
      normal.dispose();
      code.dispose();
    });

    test('isEmpty ignores whitespace, text mirrors the controller', () {
      final s = ComposerSegment(id: 'a', type: SegmentType.normal, text: '  ');
      expect(s.isEmpty, isTrue);
      s.controller.text = 'x';
      expect(s.isEmpty, isFalse);
      expect(s.text, 'x');
      s.dispose();
    });

    test('a code segment remembers its language and seed text', () {
      final s = ComposerSegment(
        id: 'a',
        type: SegmentType.code,
        text: 'print(1)',
        language: 'dart',
      );
      expect(s.language, 'dart');
      expect(s.text, 'print(1)');
      expect(s.previousText, 'print(1)');
      s.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('initial state', () {
    testWidgets('one empty prose segment, nothing to send', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));

      expect(shape(c), 'N("")');
      expect(c.hasContent, isFalse);
      expect(c.isTypingInCode, isFalse);
      expect(c.finalText, isEmpty);
      expect(c.plainText, isEmpty);
      expect(c.consumePendingFocus(), isNull);
      expect(c.pendingFocusSegmentId, isNull);
      c.dispose();
    });

    testWidgets('the placeholder is shown on the only segment', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c, placeholder: 'Say something'));
      expect(find.text('Say something'), findsOneWidget);
      c.dispose();
    });

    test('the exposed segment list cannot be mutated by callers', () {
      final c = SegmentComposerController();
      expect(
        () => c.segments.add(ComposerSegment(id: 'x', type: SegmentType.code)),
        throwsUnsupportedError,
      );
      c.dispose();
    });

    testWidgets('typed prose counts as content and serializes', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'hello');
      await tester.pumpAndSettle();

      expect(c.hasContent, isTrue);
      expect(c.plainText, 'hello');
      expect(c.finalText, 'hello');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('inserting a code block', () {
    testWidgets('with nothing focused one is appended after the prose', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N(""),C(""),N("")');
      expect(c.isTypingInCode, isTrue);
      expect(
        codeSegmentOf(c).focusNode.hasFocus,
        isTrue,
        reason: 'the caret moves into the new block',
      );
      c.dispose();
    });

    testWidgets('the cursor line is moved into the block', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'one\ntwo\nthree',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N("one"),C("two"),N("three")');
      expect(c.finalText, 'one\n```\ntwo\n```\nthree');
      c.dispose();
    });

    testWidgets('a selection is moved into the block', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'abc def ghi',
        selection: TextSelection(baseOffset: 4, extentOffset: 7),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N("abc "),C("def"),N(" ghi")');
      c.dispose();
    });

    // FINDING: extracting a selection writes the text *before* it back into
    // the prose segment (`focused.controller.text = before`). When the segment
    // still holds inline markdown, that assignment reaches the rich
    // controller's delete listener, which sees the markdown pattern break,
    // rescues it by restoring the marker-stripped *full* text, and so undoes
    // the truncation. The extracted words are then in both the prose segment
    // and the code block, and the message is sent with them twice.
    testWidgets('FINDING: extracting from markdown prose duplicates the text', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'abc **d** efg',
        selection: TextSelection(baseOffset: 4, extentOffset: 9),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(
        shape(c),
        'N("abc d efg"),C("d"),N(" efg")',
        reason: 'FINDING: the prose segment should have been cut to "abc "',
      );
      expect(
        c.finalText,
        'abc **d** efg\n```\nd\n```\n efg',
        reason: 'FINDING: the extracted "d" is sent twice, once still bold',
      );
      c.dispose();
    });

    testWidgets('a single-line segment is replaced by the block in place', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'only line',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N(""),C("only line"),N("")');
      c.dispose();
    });

    testWidgets('formatting is stripped from the extracted line', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: '- **bold** and _it_',
        selection: TextSelection.collapsed(offset: 19),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(
        codeSegmentOf(c).text,
        'bold and it',
        reason: 'markers and the list prefix do not belong inside code',
      );
      c.dispose();
    });

    testWidgets('a link is stripped to its display text', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: '1. see [docs](https://x.com)',
        selection: TextSelection.collapsed(offset: 27),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(codeSegmentOf(c).text, 'see docs');
      c.dispose();
    });

    testWidgets('a selection running to the end leaves an empty tail segment', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'keep move',
        selection: TextSelection(baseOffset: 5, extentOffset: 9),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N("keep "),C("move"),N("")');
      c.dispose();
    });

    testWidgets('every markdown dialect is stripped out of the block', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      const line = '> __b__ ~~s~~ *i* `c` [l](https://x.com)';
      c.segments.first.controller.value = const TextEditingValue(
        text: line,
        selection: TextSelection.collapsed(offset: line.length),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(codeSegmentOf(c).text, 'b s i c l');
      c.dispose();
    });

    testWidgets('toggling inside a code block removes it again', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      codeSegmentOf(c).controller.text = 'body';
      await tester.pumpAndSettle();

      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      expect(shape(c), 'N("body")');
      expect(c.isTypingInCode, isFalse);
      c.dispose();
    });

    testWidgets('toggle("codeBlock") goes through the same path', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggle('codeBlock');
      await tester.pumpAndSettle();
      expect(c.segments.where((s) => s.type == SegmentType.code), hasLength(1));
      c.dispose();
    });

    testWidgets('applyFormat(codeBlock) inserts one too', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.applyFormat(FormatType.codeBlock);
      await tester.pumpAndSettle();
      expect(c.segments.where((s) => s.type == SegmentType.code), hasLength(1));
      c.dispose();
    });

    testWidgets('an empty code block still counts as content', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      expect(c.hasContent, isTrue);
      expect(
        c.finalText,
        isEmpty,
        reason: 'an empty block serializes to nothing',
      );
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('leaving and removing a code block', () {
    testWidgets('three Enters on a trailing blank line exit the block', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      codeSegmentOf(c).controller.text = 'x\n\n\n';
      await tester.pumpAndSettle();

      expect(
        codeSegmentOf(c).text,
        'x',
        reason: 'the three exit newlines are trimmed back off',
      );
      expect(c.isTypingInCode, isFalse);
      expect(
        c.segments.last.focusNode.hasFocus,
        isTrue,
        reason: 'focus lands on the prose segment after the block',
      );
      c.dispose();
    });

    testWidgets('backspace on an empty block removes it', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(shape(c), 'N("")');
      c.dispose();
    });

    testWidgets('backspace on a non-empty block is left to the field', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      codeSegmentOf(c).controller.text = 'keep';
      await tester.pumpAndSettle();

      expect(c.handleBackspaceOnEmptyCodeBlock(), isFalse);
      expect(c.segments.where((s) => s.type == SegmentType.code), hasLength(1));
      c.dispose();
    });

    testWidgets('handleBackspaceOnEmptyCodeBlock refuses from a prose field', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();
      expect(c.handleBackspaceOnEmptyCodeBlock(), isFalse);
      c.dispose();
    });

    testWidgets('backspace on the empty prose after a block re-enters it', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'body\n\n\n';
      await tester.pumpAndSettle();
      expect(c.segments.last.focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(shape(c), 'N(""),C("body")');
      expect(code.focusNode.hasFocus, isTrue);
      expect(
        code.controller.selection.baseOffset,
        4,
        reason: 'the caret lands at the end of the code',
      );
      c.dispose();
    });

    testWidgets('the last prose segment is never removed by backspace', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();
      expect(c.handleBackspaceOnEmptyNormalSegment(), isFalse);
      expect(shape(c), 'N("")');
      c.dispose();
    });

    testWidgets('removing a block merges the text around it', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();

      c.segments.first.controller.value = const TextEditingValue(
        text: 'before\nmid\nafter',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();
      expect(shape(c), 'N("before"),C("mid"),N("after")');

      c.removeCodeSegment(codeSegmentOf(c));
      await tester.pumpAndSettle();

      expect(shape(c), 'N("before\nmid\nafter")');
      expect(
        c.segments.first.controller.selection.baseOffset,
        10,
        reason: 'the caret sits just after the re-merged code text',
      );
      c.dispose();
    });

    testWidgets('an empty block merges without inserting blank lines', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'prose');
      await tester.pumpAndSettle();
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      c.removeCodeSegment(codeSegmentOf(c));
      await tester.pumpAndSettle();

      expect(c.plainText, 'prose');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('formatting through the toolbar', () {
    testWidgets('toggle("bold") formats the focused prose selection', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'hello');
      c.segments.first.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      c.toggle('bold');
      await tester.pumpAndSettle();

      expect(c.finalText, '**hello**');
      expect(c.getActiveFormats(), contains(FormatType.bold));
      c.dispose();
    });

    testWidgets('every toolbar name maps to a format', (tester) async {
      const names = {
        'italic': FormatType.italic,
        'underline': FormatType.underline,
        'strikethrough': FormatType.strikethrough,
        'inlineCode': FormatType.inlineCode,
        'bulletList': FormatType.bulletList,
        'orderedList': FormatType.orderedList,
        'blockquote': FormatType.blockquote,
      };
      for (final entry in names.entries) {
        final c = SegmentComposerController();
        await tester.pumpWidget(host(c));
        await tester.enterText(fieldFor(c.segments.first), 'hello');
        c.segments.first.controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 5,
        );
        c.toggle(entry.key);
        await tester.pumpAndSettle();
        expect(c.getActiveFormats(), contains(entry.value), reason: entry.key);
        c.dispose();
      }
    });

    testWidgets('an unknown toolbar name changes nothing', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'hello');
      c.toggle('not-a-format');
      await tester.pumpAndSettle();
      expect(c.plainText, 'hello');
      c.dispose();
    });

    testWidgets('with nothing focused the first prose segment is used', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.segments.first.controller.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );
      c.applyFormat(FormatType.bold);
      await tester.pumpAndSettle();
      expect(c.finalText, '**hello**');
      c.dispose();
    });

    testWidgets('an explicit target segment overrides the focused one', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();
      c.segments.first.controller.value = const TextEditingValue(
        text: 'one\ntwo',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      final trailing = c.segments.last;
      trailing.controller.value = const TextEditingValue(
        text: 'two',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      c.applyFormat(FormatType.bold, targetSegment: trailing);
      await tester.pumpAndSettle();

      expect(
        (trailing.controller as RichTextEditingController).toMarkdown(),
        '**two**',
      );
      c.dispose();
    });

    testWidgets('a focused code block reports codeBlock as the active format', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      expect(c.getActiveFormats(), {FormatType.codeBlock});
      c.dispose();
    });

    testWidgets('with nothing focused the active formats come from the first '
        'prose segment', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.segments.first.controller.value = const TextEditingValue(
        text: '- item',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pumpAndSettle();
      expect(c.getActiveFormats(), contains(FormatType.bulletList));
      c.dispose();
    });

    testWidgets('an inline format inside a code block is ignored', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      codeSegmentOf(c).controller.text = 'codeline';
      await tester.pumpAndSettle();

      c.applyFormat(FormatType.bold);
      await tester.pumpAndSettle();

      expect(shape(c), 'N(""),C("codeline"),N("")');
      c.dispose();
    });

    testWidgets('a list format inside a code block dissolves the block', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      codeSegmentOf(c).controller.text = 'codeline';
      await tester.pumpAndSettle();

      c.applyFormat(FormatType.bulletList);
      await tester.pumpAndSettle();

      expect(
        shape(c),
        'N("- codeline")',
        reason: 'the code becomes prose and takes the bullet prefix',
      );
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('serialization', () {
    testWidgets('prose, code and prose are fenced and joined', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();
      c.segments.first.controller.value = const TextEditingValue(
        text: 'intro\nbody\noutro',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(c.finalText, 'intro\n```\nbody\n```\noutro');
      expect(c.plainText, 'intro\nbody\noutro');
      c.dispose();
    });

    testWidgets('a language tag is emitted on the opening fence', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.language = 'dart';
      code.controller.text = 'void main() {}';
      await tester.pumpAndSettle();

      expect(c.finalText, '```dart\nvoid main() {}\n```');
      c.dispose();
    });

    testWidgets('prose formatting is serialized as markdown', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'hello world');
      c.segments.first.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      c.applyFormat(FormatType.italic);
      await tester.pumpAndSettle();

      expect(c.finalText, '_hello_ world');
      c.dispose();
    });

    testWidgets('clear resets to a single empty segment', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      codeSegmentOf(c).controller.text = 'x';
      await tester.pumpAndSettle();

      c.clear();
      await tester.pumpAndSettle();

      expect(shape(c), 'N("")');
      expect(c.hasContent, isFalse);
      expect(c.finalText, isEmpty);
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('callback wiring', () {
    testWidgets('onChange reports the prose segment text', (tester) async {
      final c = SegmentComposerController();
      String? seen;
      await tester.pumpWidget(host(c, onChange: (v) => seen = v));
      await tester.enterText(fieldFor(c.segments.first), 'typed');
      await tester.pumpAndSettle();
      expect(seen, 'typed');
      c.dispose();
    });

    testWidgets('onLinkTap set before a segment exists still reaches it', (
      tester,
    ) async {
      final c = SegmentComposerController();
      LinkTapDetails? tapped;
      c.onLinkTap = (d) => tapped = d;
      await tester.pumpWidget(host(c));

      final rich = c.segments.first.controller as RichTextEditingController;
      rich.value = const TextEditingValue(
        text: 'go here',
        selection: TextSelection(baseOffset: 3, extentOffset: 7),
      );
      rich.applyLinkFormat('here', 'https://l.com');
      rich.selection = const TextSelection.collapsed(offset: 4);
      await tester.pumpAndSettle();

      expect(tapped?.url, 'https://l.com');
      c.dispose();
    });

    testWidgets(
      'onLinkTap set after a code block reaches every prose segment',
      (tester) async {
        final c = SegmentComposerController();
        await tester.pumpWidget(host(c));
        c.toggleCodeBlock();
        await tester.pumpAndSettle();

        LinkTapDetails? tapped;
        c.onLinkTap = (d) => tapped = d;

        final trailing = c.segments.last;
        final rich = trailing.controller as RichTextEditingController;
        rich.value = const TextEditingValue(
          text: 'tail',
          selection: TextSelection(baseOffset: 0, extentOffset: 4),
        );
        rich.applyLinkFormat('tail', 'https://t.com');
        rich.selection = const TextSelection.collapsed(offset: 2);
        await tester.pumpAndSettle();

        expect(tapped?.url, 'https://t.com');
        c.dispose();
      },
    );

    testWidgets('onFormatterTextChanged is propagated to prose segments', (
      tester,
    ) async {
      final c = SegmentComposerController();
      String? previous;
      c.onFormatterTextChanged = (p) => previous = p;
      await tester.pumpWidget(host(c));

      final rich = c.segments.first.controller as RichTextEditingController;
      rich.value = const TextEditingValue(
        text: 'hi there',
        selection: TextSelection(baseOffset: 0, extentOffset: 2),
      );
      rich.applyLinkFormat('hi', 'https://a.com');
      rich.editLinkFormat(0, 2, 'yo', 'https://b.com');
      await tester.pumpAndSettle();

      expect(previous, 'hi there');
      c.dispose();
    });

    testWidgets('setting formatters rebuilds the untouched first segment', (
      tester,
    ) async {
      final c = SegmentComposerController();
      final first = c.segments.first;
      c.formatters = [CometChatMentionsFormatter()];
      await tester.pumpWidget(host(c));

      expect(c.segments, hasLength(1));
      expect(
        identical(c.segments.first, first),
        isFalse,
        reason: 'the segment is recreated so it picks the formatters up',
      );
      c.dispose();
    });

    testWidgets('setting formatters leaves a segment with text alone', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'draft');
      final first = c.segments.first;

      c.formatters = [CometChatMentionsFormatter()];
      await tester.pumpAndSettle();

      expect(identical(c.segments.first, first), isTrue);
      expect(c.plainText, 'draft', reason: 'the draft is not thrown away');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('paste', () {
    testWidgets('a pasted URL over a selection becomes a link', (tester) async {
      mockClipboard(tester, 'https://paste.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'label here', reason: 'the words are kept');
      expect(rich.toMarkdown(), '[label](https://paste.example) here');
      c.dispose();
    });

    testWidgets('pasted non-URL text replaces the selection', (tester) async {
      mockClipboard(tester, 'plainpaste');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'plainpaste here');
      c.dispose();
    });

    testWidgets('a URL pasted over inline code stays literal text', (
      tester,
    ) async {
      mockClipboard(tester, 'https://paste.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      rich.applyFormat(FormatType.inlineCode);
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'https://paste.example here');
      c.dispose();
    });

    testWidgets('onPasteImage claims the paste when it handles it', (
      tester,
    ) async {
      mockClipboard(tester, 'https://paste.example');
      var calls = 0;
      final c = SegmentComposerController();
      await tester.pumpWidget(
        host(
          c,
          onPasteImage: () async {
            calls++;
            return true;
          },
        ),
      );
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(calls, 1);
      expect(rich.text, 'label here', reason: 'the text paste is skipped');
      c.dispose();
    });

    testWidgets('onPasteImage declining falls through to the link paste', (
      tester,
    ) async {
      mockClipboard(tester, 'https://paste.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c, onPasteImage: () async => false));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.toMarkdown(), '[label](https://paste.example) here');
      c.dispose();
    });

    testWidgets('onPasteImage declining with no selection pastes the text', (
      tester,
    ) async {
      mockClipboard(tester, 'dropped in');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c, onPasteImage: () async => false));
      await tester.enterText(fieldFor(c.segments.first), 'ab');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'abdropped in');
      c.dispose();
    });

    testWidgets('a URL pasted in a code block becomes raw markdown', (
      tester,
    ) async {
      mockClipboard(tester, 'https://raw.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'sel text';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(code.controller.text, '[sel](https://raw.example) text');
      c.dispose();
    });

    testWidgets('non-URL text pasted in a code block replaces the selection', (
      tester,
    ) async {
      mockClipboard(tester, 'zzz');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'sel text';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(code.controller.text, 'zzz text');
      c.dispose();
    });

    testWidgets('an empty clipboard leaves the text untouched', (tester) async {
      mockClipboard(tester, '');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'label here');
      c.dispose();
    });

    testWidgets('the context menu Paste applies the link too', (tester) async {
      mockClipboard(tester, 'https://menu.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(rich.toMarkdown(), '[label](https://menu.example) here');
      c.dispose();
    });

    testWidgets('a Paste button is offered even for an image-only clipboard', (
      tester,
    ) async {
      mockClipboard(tester, null);
      var calls = 0;
      final c = SegmentComposerController();
      await tester.pumpWidget(
        host(
          c,
          onPasteImage: () async {
            calls++;
            return true;
          },
        ),
      );
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      c.segments.first.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();

      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      expect(
        find.text('Paste'),
        findsOneWidget,
        reason: 'Flutter hides Paste when the clipboard holds no strings',
      );
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      c.dispose();
    });

    testWidgets('Ctrl+V is honoured the same way as Cmd+V', (tester) async {
      mockClipboard(tester, 'https://ctrl.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(rich.toMarkdown(), '[label](https://ctrl.example) here');
      c.dispose();
    });

    testWidgets('onPasteImage declining non-URL text pastes it over the '
        'selection', (tester) async {
      mockClipboard(tester, 'not a url');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c, onPasteImage: () async => false));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      await pressPaste(tester);

      expect(rich.text, 'not a url here');
      c.dispose();
    });

    testWidgets('the context menu falls back to a plain paste for non-URLs', (
      tester,
    ) async {
      mockClipboard(tester, 'just words');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      final rich = c.segments.first.controller as RichTextEditingController;
      rich.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(rich.text, 'just words here');
      c.dispose();
    });

    testWidgets('the image-only Paste button falls back to a text paste', (
      tester,
    ) async {
      mockClipboard(tester, null);
      var calls = 0;
      final c = SegmentComposerController();
      await tester.pumpWidget(
        host(
          c,
          onPasteImage: () async {
            calls++;
            return false;
          },
        ),
      );
      await tester.enterText(fieldFor(c.segments.first), 'label here');
      await tester.pumpAndSettle();

      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(
        c.segments.first.controller.text,
        'label here',
        reason: 'an empty clipboard has nothing to paste',
      );
      c.dispose();
    });

    testWidgets('Ctrl+V in a code block also pastes a raw link', (
      tester,
    ) async {
      mockClipboard(tester, 'https://ctrl-code.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'sel text';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(code.controller.text, '[sel](https://ctrl-code.example) text');
      c.dispose();
    });

    testWidgets('the code block context menu pastes a URL as raw markdown', (
      tester,
    ) async {
      mockClipboard(tester, 'https://menu-code.example');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'sel text';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();

      tester
          .state<EditableTextState>(
            find.byWidgetPredicate(
              (w) => w is EditableText && w.controller == code.controller,
            ),
          )
          .showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(code.controller.text, '[sel](https://menu-code.example) text');
      c.dispose();
    });

    testWidgets('the code block context menu pastes non-URLs normally', (
      tester,
    ) async {
      mockClipboard(tester, 'words');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'sel text';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();

      tester
          .state<EditableTextState>(
            find.byWidgetPredicate(
              (w) => w is EditableText && w.controller == code.controller,
            ),
          )
          .showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(code.controller.text, 'words text');
      c.dispose();
    });

    testWidgets('the code block context menu pastes with no selection', (
      tester,
    ) async {
      mockClipboard(tester, 'tail');
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(c);
      code.controller.text = 'abc';
      await tester.pumpAndSettle();
      code.controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pumpAndSettle();

      tester
          .state<EditableTextState>(
            find.byWidgetPredicate(
              (w) => w is EditableText && w.controller == code.controller,
            ),
          )
          .showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(code.controller.text, 'abctail');
      c.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('widget rendering', () {
    testWidgets('an empty unfocused segment is hidden once a block exists', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      expect(
        fieldFor(c.segments.first),
        findsNothing,
        reason: 'two empty prose fields around a block would look broken',
      );
      expect(fieldFor(codeSegmentOf(c)), findsOneWidget);
      c.dispose();
    });

    testWidgets('a non-empty prose segment beside a block is rendered', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      await tester.tap(fieldFor(c.segments.first));
      await tester.pumpAndSettle();
      c.segments.first.controller.value = const TextEditingValue(
        text: 'intro\nbody',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();
      c.insertCodeBlock();
      await tester.pumpAndSettle();

      expect(fieldFor(c.segments.first), findsOneWidget);
      c.dispose();
    });

    testWidgets('the caller text styles reach the prose field', (tester) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(
        host(
          c,
          textStyle: const TextStyle(fontSize: 27),
          placeholderStyle: const TextStyle(fontSize: 19),
          placeholder: 'ph',
        ),
      );
      final field = tester.widget<TextField>(fieldFor(c.segments.first));
      expect(field.style?.fontSize, 27);
      expect(field.decoration?.hintStyle?.fontSize, 19);
      expect(field.decoration?.hintText, 'ph');
      c.dispose();
    });

    testWidgets('onContentInserted enables rich content insertion', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c, onContentInserted: (_) {}));
      final field = tester.widget<TextField>(fieldFor(c.segments.first));
      expect(field.contentInsertionConfiguration, isNotNull);
      expect(
        field.contentInsertionConfiguration!.allowedMimeTypes,
        contains('image/png'),
      );
      c.dispose();
    });

    testWidgets('without the callback rich content insertion is off', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      final field = tester.widget<TextField>(fieldFor(c.segments.first));
      expect(field.contentInsertionConfiguration, isNull);
      c.dispose();
    });

    testWidgets('a code block is rendered in monospace on its own surface', (
      tester,
    ) async {
      final c = SegmentComposerController();
      await tester.pumpWidget(host(c));
      c.toggleCodeBlock();
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(fieldFor(codeSegmentOf(c)));
      expect(field.style?.fontFamily, 'monospace');
      expect(field.maxLines, isNull, reason: 'the block grows with content');
      c.dispose();
    });

    testWidgets('swapping the controller rewires the pending-focus listener', (
      tester,
    ) async {
      final first = SegmentComposerController();
      final second = SegmentComposerController();
      await tester.pumpWidget(host(first));
      await tester.pumpWidget(host(second));

      second.toggleCodeBlock();
      await tester.pumpAndSettle();
      final code = codeSegmentOf(second);
      code.controller.text = 'x\n\n\n';
      await tester.pumpAndSettle();

      expect(
        second.segments.last.focusNode.hasFocus,
        isTrue,
        reason: 'the new controller\'s pending focus is honoured',
      );
      first.dispose();
      second.dispose();
    });
  });
}
