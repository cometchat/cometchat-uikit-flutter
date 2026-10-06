import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' show FormatType;

import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/composer_depth_helper.dart';
import '../sdk_user_b/composer_depth_actions.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Rich-text composer — E2E suite (iOS parity, STRICT).
///
/// Every "sends markdown" case applies the format through the composer's real
/// formatting toolbar, types, sends, then holds TWO things true:
///   (a) the payload that left the device — read back over REST as User B —
///       carries exactly the expected markdown, and
///   (b) the bubble in the list renders the run formatted, with no literal
///       markers on screen.
///
///   E2E-100  Bold              → payload `**x**`, bubble run is bold
///   E2E-101  Bold toggled off  → payload `**x** y`; `y` is not bold
///   E2E-102  Italic            → payload `_x_`, bubble run is italic
///   E2E-103  Strikethrough     → payload `~~x~~`, bubble run is struck through
///   E2E-104  Inline code       → payload `` `x` ``, bubble run is monospace
///   E2E-105  Code block        → payload "```\nx\n```", bubble run is monospace
///   E2E-106  Bullet list       → payload `- x`, bubble shows `• x`
///   E2E-107  Numbered list     → payload `1. x\n2. y` (auto-numbered on Enter)
///   E2E-108  Bold on a selected word → only that word is wrapped in `**`
///   E2E-109  Literal `**x**` typed by hand → sent verbatim, rendered bold,
///            markers not shown
///   E2E-110  `**x**` received from User B → rendered bold, markers not shown
///   E2E-111  Bold + italic together → payload `**_x_**`, run is bold AND italic
///
/// Source facts the assertions are pinned to:
///   * Sample app (`master_app/lib/screens/messages_screen.dart`) builds the
///     composer with `layout: singleLine`, `enableRichTextFormatting: true`,
///     `showRichTextFormattingOptions: true` → the toolbar is ON by default and
///     always visible (stacked under the input). There is no `Aa` toggle to
///     open in this layout — that only exists for `doubleLine`.
///   * Markers come from rich_text_span.dart `_getMarkers`: bold `**`, italic
///     `_`, strikethrough `~~`, inline code `` ` ``; italic is wrapped
///     innermost (`_wrapPriority`), hence `**_x_**`.
///   * Line formats come from rich_text_editing_controller.dart
///     `_getLinePrefix`: bullet `"- "`, ordered `"1. "` (next line
///     auto-continues as `"2. "` in `_maybeContinueLineFormat`). NOTE: iOS
///     emits "• " for bullets; Flutter emits "- " and only RENDERS "• "
///     (markdown_text_formatter.dart `_collectBullets`).
///   * Code blocks are separate segments serialised by
///     segment_composer_controller.dart `finalText` as "```<lang>\n<code>\n```".
///   * Bubble styling comes from markdown_text_formatter.dart:
///     bold → `FontWeight.bold`, italic → `FontStyle.italic`, strikethrough →
///     `TextDecoration.lineThrough`, code → `fontFamily: 'monospace'`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Fresh A↔B history per test: literal-marker checks look at the whole
    // message list, so leftovers from a previous case must not be in it.
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation();
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDown(() async {
    // Runs even when the test body failed.
    await CleanupHelper.fullReset();
  });

  bool isBold(TextStyle s) => s.fontWeight == FontWeight.bold;
  bool isItalic(TextStyle s) => s.fontStyle == FontStyle.italic;
  bool isStruck(TextStyle s) => s.decoration == TextDecoration.lineThrough;
  bool isMono(TextStyle s) => s.fontFamily == 'monospace';

  /// Send what is in the composer, wait for the bubble carrying [token], and
  /// return the raw text the server stored for it.
  Future<String> sendAndReadPayload(WidgetTester tester, String token) async {
    await ComposerDepthHelper.tapSend(tester);
    await ComposerDepthHelper.waitForInList(tester, token);
    final sent = await ComposerDepthActions.waitForMessageFromA(token);
    if (sent == null) {
      fail('No message from User A containing "$token" reached the server');
    }
    return ComposerDepthActions.textOf(sent);
  }

  /// Apply one inline [format] from the toolbar, type [token], send.
  Future<String> sendWithInlineFormat(
    WidgetTester tester,
    FormatType format,
    String token,
  ) async {
    await ComposerDepthHelper.launchIntoChatWithB(tester);
    await ComposerDepthHelper.focusComposer(tester);
    await ComposerDepthHelper.tapFormat(tester, format);
    await ComposerDepthHelper.typeAppend(tester, token);
    return sendAndReadPayload(tester, token);
  }

  group('Rich text composer: inline formats', () {
    testWidgets('E2E-100: Bold format sends markdown', (tester) async {
      final tok = ComposerDepthHelper.token('bold');
      final payload = await sendWithInlineFormat(tester, FormatType.bold, tok);

      expect(
        payload,
        '**$tok**',
        reason: 'Bold must go out as **text** markdown',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isBold),
        isTrue,
        reason: 'The sent bubble must render the run in bold',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '**'),
        isFalse,
        reason: 'Literal ** markers must not be visible in the bubble',
      );
    });

    testWidgets('E2E-101: Bold toggle off closes the range', (tester) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final boldTok = ComposerDepthHelper.token('bon');
      final plainTok = ComposerDepthHelper.token('boff');

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.tapFormat(tester, FormatType.bold);
      await ComposerDepthHelper.typeAppend(tester, boldTok);
      // Toggle bold OFF, then keep typing.
      await ComposerDepthHelper.tapFormat(tester, FormatType.bold);
      await ComposerDepthHelper.typeAppend(tester, ' $plainTok');

      final payload = await sendAndReadPayload(tester, plainTok);

      expect(
        payload,
        '**$boldTok** $plainTok',
        reason:
            'Text typed after toggling bold off must sit OUTSIDE the '
            '** range',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, plainTok, isBold),
        isFalse,
        reason: 'The run typed after toggling off must not render bold',
      );
    });

    testWidgets('E2E-102: Italic format sends markdown', (tester) async {
      final tok = ComposerDepthHelper.token('ital');
      final payload = await sendWithInlineFormat(
        tester,
        FormatType.italic,
        tok,
      );

      // rich_text_span.dart `_getMarkers`: italic is "_", not "*".
      expect(
        payload,
        '_${tok}_',
        reason: 'Italic must go out as _text_ markdown',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isItalic),
        isTrue,
        reason: 'The sent bubble must render the run in italics',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '_$tok'),
        isFalse,
        reason: 'Literal _ markers must not be visible in the bubble',
      );
    });

    testWidgets('E2E-103: Strikethrough format sends markdown', (tester) async {
      final tok = ComposerDepthHelper.token('strike');
      final payload = await sendWithInlineFormat(
        tester,
        FormatType.strikethrough,
        tok,
      );

      expect(
        payload,
        '~~$tok~~',
        reason: 'Strikethrough must go out as ~~text~~ markdown',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isStruck),
        isTrue,
        reason: 'The sent bubble must render the run struck through',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '~~'),
        isFalse,
        reason: 'Literal ~~ markers must not be visible in the bubble',
      );
    });

    testWidgets('E2E-104: Inline code format sends markdown', (tester) async {
      final tok = ComposerDepthHelper.token('icode');
      final payload = await sendWithInlineFormat(
        tester,
        FormatType.inlineCode,
        tok,
      );

      expect(
        payload,
        '`$tok`',
        reason: 'Inline code must go out as `text` markdown',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isMono),
        isTrue,
        reason: 'The sent bubble must render the run in monospace',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '`'),
        isFalse,
        reason: 'Literal backticks must not be visible in the bubble',
      );
    });

    testWidgets('E2E-111: Bold plus italic sends nested markdown', (
      tester,
    ) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final tok = ComposerDepthHelper.token('bolditalic');

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.tapFormat(tester, FormatType.bold);
      await ComposerDepthHelper.tapFormat(tester, FormatType.italic);
      await ComposerDepthHelper.typeAppend(tester, tok);

      final payload = await sendAndReadPayload(tester, tok);

      // `_wrapPriority`: italic innermost, bold outermost.
      expect(
        payload,
        '**_${tok}_**',
        reason: 'Bold+italic must nest as **_text_**',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(
          tester,
          tok,
          (s) => isBold(s) && isItalic(s),
        ),
        isTrue,
        reason: 'The sent bubble must render the run bold AND italic',
      );
    });
  });

  group('Rich text composer: block formats', () {
    testWidgets('E2E-105: Code block format sends markdown', (tester) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final tok = ComposerDepthHelper.token('cblock');

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.tapFormat(tester, FormatType.codeBlock);
      if (ComposerDepthHelper.codeField().evaluate().isEmpty) {
        fail(
          'Tapping "Code Block" did not insert a code segment '
          '(no monospace TextField in the composer)',
        );
      }
      await ComposerDepthHelper.typeAppend(
        tester,
        tok,
        field: ComposerDepthHelper.codeField(),
      );

      final payload = await sendAndReadPayload(tester, tok);

      expect(
        payload,
        '```\n$tok\n```',
        reason: 'A code block must go out fenced with triple backticks',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isMono),
        isTrue,
        reason: 'The sent bubble must render the block in monospace',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '```'),
        isFalse,
        reason: 'Literal ``` fences must not be visible in the bubble',
      );
    });

    testWidgets('E2E-106: Bullet list format sends markdown', (tester) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final tok = ComposerDepthHelper.token('bullet');

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.tapFormat(tester, FormatType.bulletList);
      // Pin the emitted syntax: Flutter inserts "- " (iOS inserts "• ").
      expect(
        ComposerDepthHelper.composerText(tester),
        '- ',
        reason: 'The Bullet List button must insert the "- " line prefix',
      );
      await ComposerDepthHelper.typeAppend(tester, tok);

      final payload = await sendAndReadPayload(tester, tok);

      expect(
        payload,
        '- $tok',
        reason: 'A bullet item must go out as "- item" markdown',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '• $tok'),
        isTrue,
        reason: 'The bubble must render the item with a • glyph',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '- $tok'),
        isFalse,
        reason: 'The literal "- " marker must not be visible in the bubble',
      );
    });

    testWidgets('E2E-107: Numbered list format sends markdown', (tester) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final one = ComposerDepthHelper.token('numone');
      final two = ComposerDepthHelper.token('numtwo');

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.tapFormat(tester, FormatType.orderedList);
      expect(
        ComposerDepthHelper.composerText(tester),
        '1. ',
        reason: 'The Numbered List button must insert the "1. " prefix',
      );
      await ComposerDepthHelper.typeAppend(tester, one);
      // Enter on a non-empty item continues the list with the next number.
      await ComposerDepthHelper.typeAppend(tester, '\n');
      expect(
        ComposerDepthHelper.composerText(tester),
        '1. $one\n2. ',
        reason: 'Enter must auto-continue the numbered list as "2. "',
      );
      await ComposerDepthHelper.typeAppend(tester, two);

      final payload = await sendAndReadPayload(tester, two);

      expect(
        payload,
        '1. $one\n2. $two',
        reason: 'Numbered items must go out as "N. item" lines',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '1. $one\n2. $two'),
        isTrue,
        reason: 'The bubble must render both numbered lines',
      );
    });
  });

  group('Rich text composer: selection and literal markdown', () {
    testWidgets('E2E-108: Bold applied to a selected word', (tester) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final word = ComposerDepthHelper.token('selword');
      final before = ComposerDepthHelper.token('pre');
      final after = ComposerDepthHelper.token('post');
      final sentence = '$before $word $after';

      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.typeAppend(tester, sentence);
      final start = sentence.indexOf(word);
      await ComposerDepthHelper.selectRange(tester, start, start + word.length);
      await ComposerDepthHelper.tapFormat(tester, FormatType.bold);

      final payload = await sendAndReadPayload(tester, word);

      expect(
        payload,
        '$before **$word** $after',
        reason: 'Only the selected word must be wrapped in **',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, word, isBold),
        isTrue,
        reason: 'The selected word must render bold in the bubble',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, before, isBold),
        isFalse,
        reason: 'Words outside the selection must not render bold',
      );
    });

    testWidgets(
      'E2E-109: Typed literal markdown markers are stripped in bubble',
      (tester) async {
        await ComposerDepthHelper.launchIntoChatWithB(tester);
        final tok = ComposerDepthHelper.token('literal');
        final tail = ComposerDepthHelper.token('tail');

        await ComposerDepthHelper.focusComposer(tester);
        await ComposerDepthHelper.typeAppend(tester, '**$tok** $tail');

        final payload = await sendAndReadPayload(tester, tail);

        expect(
          payload,
          '**$tok** $tail',
          reason: 'Hand-typed markdown must be sent verbatim',
        );
        expect(
          ComposerDepthHelper.listShows(tester, '**'),
          isFalse,
          reason: 'The bubble must strip the literal ** markers',
        );
        expect(
          ComposerDepthHelper.listHasStyledRun(tester, tok, isBold),
          isTrue,
          reason: 'The hand-typed **run** must render bold',
        );
      },
    );

    testWidgets('E2E-110: Received markdown renders without literal markers', (
      tester,
    ) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final tok = ComposerDepthHelper.token('rcvbold');
      final tail = ComposerDepthHelper.token('rcvtail');

      await UserBMessaging.sendTextToA('**$tok** $tail');
      await ComposerDepthHelper.waitForInList(tester, tail);

      expect(
        ComposerDepthHelper.listShows(tester, '**'),
        isFalse,
        reason: 'An incoming **bold** message must not show literal markers',
      );
      expect(
        ComposerDepthHelper.listHasStyledRun(tester, tok, isBold),
        isTrue,
        reason: 'An incoming **bold** run must render bold',
      );
    });
  });
}
