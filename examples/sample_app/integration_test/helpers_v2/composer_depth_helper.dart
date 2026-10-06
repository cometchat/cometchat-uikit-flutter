import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatActionBubble,
        CometChatMessageComposer,
        CometChatMessageHeader,
        CometChatMessageList,
        CometChatMessagePreview,
        CometChatRichTextToolbar,
        FormatType,
        FormatTypeExtension;

import '../config/test_credentials.dart';
import 'app_launcher.dart';
import 'navigation_helper.dart';
import 'pump_helper.dart';

/// Strict helpers for the composer-side depth suites (rich text, mentions,
/// swipe-to-reply, drafts — E2E-100…E2E-129).
///
/// Every finder here is traceable to UI Kit source; the file is cited next to
/// each one. Nothing in this class swallows a missing precondition: when the
/// element a scenario depends on is absent, the helper calls [fail] so the
/// test goes red instead of drifting on to a vacuous assertion.
///
/// Sample-app facts these helpers rely on
/// (`master_app/lib/screens/messages_screen.dart`, `_buildComposer`):
///   * `layout: CometChatComposerLayout.singleLine` with
///     `enableRichTextFormatting: true` / `showRichTextFormattingOptions: true`
///     → the formatting toolbar is the STACKED one and is always visible under
///     the input. The `Aa` toggle ("Rich text formatting toolbar" /
///     "Close formatting toolbar" semantics) only exists in the doubleLine
///     layout, which the sample app does not use.
///   * stacked toolbar + code block enabled → the composer runs in
///     segment mode (`SegmentComposerWidget`): prose lives in a
///     `TextFormField` per normal segment, a code block is its own
///     monospace `TextField`.
class ComposerDepthHelper {
  ComposerDepthHelper._();

  // ─── Tokens ────────────────────────────────────────────────────────────────

  /// A unique, LETTERS-ONLY token. Digits are avoided on purpose: the sample
  /// app wires `CometChatPhoneNumberFormatter` into the list, which turns long
  /// digit runs into a `WidgetSpan` and would hide them from `toPlainText()`.
  /// Underscores are avoided because `_x_` is italic markdown.
  static String token(String prefix) {
    var n = DateTime.now().microsecondsSinceEpoch;
    final sb = StringBuffer(prefix);
    while (n > 0) {
      sb.writeCharCode(97 + n % 26);
      n ~/= 26;
    }
    return sb.toString();
  }

  // ─── Navigation (strict) ───────────────────────────────────────────────────

  /// Text inside the chat header only. The peer's name is ALWAYS in the header,
  /// so suites must never treat "name is on screen" as proof of anything else.
  static Finder headerText(String text) => find.descendant(
    of: find.byType(CometChatMessageHeader),
    matching: find.text(text),
  );

  /// Launch, log in as User A and open the 1:1 chat with User B. Fails unless
  /// the header really shows User B (NavigationHelper falls back to "first
  /// conversation", which would silently test the wrong chat).
  static Future<void> launchIntoChatWithB(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    await openChatWithB(tester);
  }

  static Future<void> openChatWithB(WidgetTester tester) async {
    // No-op when already on the Chats tab; needed when coming from Groups.
    await NavigationHelper.goToTab(tester, 'Chats');
    await NavigationHelper.openUserBConversation(tester);
    await pumpUntilFound(tester, composer());
    if (headerText(TestCredentials.userBName).evaluate().isEmpty) {
      fail(
        'Expected the chat with ${TestCredentials.userBName} to be open '
        '(name not found in CometChatMessageHeader)',
      );
    }
    if (composer().evaluate().isEmpty) {
      fail('CometChatMessageComposer is not on screen after opening the chat');
    }
  }

  /// Open a group chat by name and fail unless its header shows that name.
  static Future<void> openGroupByName(WidgetTester tester, String name) async {
    await NavigationHelper.openTestGroup(tester, name: name);
    await pumpUntilFound(tester, composer());
    if (headerText(name).evaluate().isEmpty) {
      fail('Expected group "$name" to be open (name not in the chat header)');
    }
  }

  /// Leave the open chat through the header's back button.
  /// cometchat_message_header.dart `_getBackButtonView`:
  /// `Semantics(button: true, label: Translations.of(context).back)` → "Back".
  /// Returns false when there is no back button (two-pane / wide layout, where
  /// the sample app passes `showBackButton: false`).
  static Future<bool> leaveChat(WidgetTester tester) async {
    final back = find.descendant(
      of: find.byType(CometChatMessageHeader),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Back',
      ),
    );
    if (back.evaluate().isEmpty) return false;
    await tester.tap(back.first);
    await pumpUntilGone(tester, composer());
    if (composer().evaluate().isNotEmpty) {
      fail('Tapping the header back button did not leave the chat');
    }
    await pumpFor(tester, const Duration(seconds: 1));
    return true;
  }

  // ─── Composer input ────────────────────────────────────────────────────────

  static Finder composer() => find.byType(CometChatMessageComposer);

  /// Prose input. segment_composer_widget.dart `_NormalSegmentWidget` builds a
  /// `TextFormField` (→ `TextField`) with the body text style; the code segment
  /// is the only field styled `fontFamily: 'monospace'`.
  static Finder proseField() => find.descendant(
    of: composer(),
    matching: find.byWidgetPredicate(
      (w) => w is TextField && w.style?.fontFamily != 'monospace',
    ),
  );

  /// Code-block input. segment_composer_widget.dart `_CodeSegmentWidget`:
  /// `TextField(style: TextStyle(fontFamily: 'monospace', …))`.
  static Finder codeField() => find.descendant(
    of: composer(),
    matching: find.byWidgetPredicate(
      (w) => w is TextField && w.style?.fontFamily == 'monospace',
    ),
  );

  /// Everything currently typed in the composer, across all segments.
  static String composerText(WidgetTester tester) {
    final fields = tester.widgetList<TextField>(
      find.descendant(of: composer(), matching: find.byType(TextField)),
    );
    return fields
        .map((f) => f.controller?.text ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n');
  }

  static Finder _requireField(Finder field, String what) {
    if (field.evaluate().isEmpty) fail('$what is not on screen');
    return field.first;
  }

  /// Focus the prose field so the controller has a valid collapsed selection
  /// (toolbar line formats bail out on `selection.baseOffset == -1`,
  /// rich_text_editing_controller.dart `_applyLineBasedFormat`).
  static Future<void> focusComposer(WidgetTester tester) async {
    final field = _requireField(proseField(), 'Composer text field');
    await tester.showKeyboard(field);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Append [text] after whatever the field already holds — this is what an
  /// IME does (it always reports the full editing value). `enterText` alone
  /// would REPLACE the content and wipe prefixes the toolbar inserted ("- ").
  static Future<void> typeAppend(
    WidgetTester tester,
    String text, {
    Finder? field,
  }) async {
    final target = _requireField(field ?? proseField(), 'Composer text field');
    final current = tester.widget<TextField>(target).controller?.text ?? '';
    await tester.enterText(target, '$current$text');
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Type one character at a time. The mentions formatter
  /// (cometchat_mentions_formatter.dart `_onChange`) is keystroke-driven: it
  /// starts tracking when the character just typed is "@", and treats a
  /// multi-character jump as a paste. Bulk `enterText` would not exercise it.
  static Future<void> typeChars(WidgetTester tester, String text) async {
    for (final rune in text.runes) {
      final target = _requireField(proseField(), 'Composer text field');
      final current = tester.widget<TextField>(target).controller?.text ?? '';
      await tester.enterText(target, '$current${String.fromCharCode(rune)}');
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Replace the whole prose field content (used to clear it).
  static Future<void> setComposerText(WidgetTester tester, String text) async {
    final target = _requireField(proseField(), 'Composer text field');
    await tester.enterText(target, text);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Report a selection the way the platform IME does, without changing text.
  static Future<void> selectRange(
    WidgetTester tester,
    int start,
    int end,
  ) async {
    final target = _requireField(proseField(), 'Composer text field');
    final current = tester.widget<TextField>(target).controller?.text ?? '';
    await tester.showKeyboard(target);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: current,
        selection: TextSelection(baseOffset: start, extentOffset: end),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Tap the ENABLED send button. message_composer_send_button.dart:
  /// `Semantics(label: isDisabled ? 'Send button disabled' : 'Send message')`.
  static Future<void> tapSend(WidgetTester tester) async {
    final send = find.descendant(
      of: composer(),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Send message',
      ),
    );
    if (send.evaluate().isEmpty) {
      fail(
        'Send button is not enabled (no "Send message" semantics node) — '
        'composer text: "${composerText(tester)}"',
      );
    }
    await tester.tap(send.first);
    await pumpForRealtime(tester, duration: const Duration(seconds: 2));
  }

  // ─── Rich-text toolbar ─────────────────────────────────────────────────────

  /// cometchat_rich_text_toolbar.dart — the stacked toolbar widget.
  static Finder toolbar() => find.descendant(
    of: composer(),
    matching: find.byType(CometChatRichTextToolbar),
  );

  /// A format button. cometchat_rich_text_toolbar.dart `_buildFormatButton`:
  /// `Icon(formatType.icon, semanticLabel: formatType.label)` inside an opaque
  /// `GestureDetector`; icons come from format_type.dart
  /// (bold → Icons.format_bold, inlineCode → Icons.code,
  /// codeBlock → Icons.integration_instructions_outlined, …).
  static Finder formatButton(FormatType format) =>
      find.descendant(of: toolbar(), matching: find.byIcon(format.icon));

  /// Tap a toolbar format button. The toolbar is a horizontal
  /// `SingleChildScrollView` and is wider than a phone, so the button is
  /// scrolled into view first.
  static Future<void> tapFormat(WidgetTester tester, FormatType format) async {
    if (toolbar().evaluate().isEmpty) {
      fail('CometChatRichTextToolbar is not rendered in the composer');
    }
    final button = formatButton(format);
    if (button.evaluate().isEmpty) {
      fail('Toolbar has no "${format.label}" button');
    }
    await tester.ensureVisible(button.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button.first);
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ─── Message list inspection (scoped to CometChatMessageList) ─────────────
  //
  // Scoping matters: the Chats tab stays mounted under the messages route and
  // its conversation subtitle repeats the latest message text, so a whole-tree
  // walk can match (and measure) the wrong widget.

  static void _walkList(WidgetTester tester, bool Function(Element) visit) {
    var stop = false;
    void walk(Element e) {
      if (stop) return;
      if (visit(e)) {
        stop = true;
        return;
      }
      e.visitChildren(walk);
    }

    for (final root
        in find.byType(CometChatMessageList, skipOffstage: false).evaluate()) {
      root.visitChildren(walk);
      if (stop) return;
    }
  }

  static String _plain(RichText w) {
    try {
      return w.text.toPlainText();
    } catch (_) {
      return '';
    }
  }

  /// True when [text] is rendered somewhere inside the message list.
  static bool listShows(WidgetTester tester, String text) {
    var found = false;
    _walkList(tester, (e) {
      final w = e.widget;
      if (w is RichText && _plain(w).contains(text)) found = true;
      return found;
    });
    return found;
  }

  static Future<void> waitForInList(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (listShows(tester, text)) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    fail(
      '"$text" did not appear in the message list within '
      '${timeout.inSeconds}s',
    );
  }

  /// True when some text run containing [text] inside the message list carries
  /// a style accepted by [style]. Works for both shapes the bubble produces
  /// (formatter_utils.dart `buildTextSpan`): a styled `TextSpan` (bold, italic,
  /// strikethrough) and a `WidgetSpan` → `Text` (inline code, code block),
  /// whose inner `RichText` root span carries the merged style.
  static bool listHasStyledRun(
    WidgetTester tester,
    String text,
    bool Function(TextStyle style) style,
  ) {
    var found = false;
    _walkList(tester, (e) {
      final w = e.widget;
      if (w is RichText) {
        w.text.visitChildren((span) {
          if (span is TextSpan &&
              (span.text ?? '').contains(text) &&
              span.style != null &&
              style(span.style!)) {
            found = true;
            return false;
          }
          return true;
        });
      }
      return found;
    });
    return found;
  }

  /// On-screen centre of the first list element accepted by [match].
  static Offset? _centerWhere(
    WidgetTester tester,
    bool Function(Widget) match,
  ) {
    Offset? center;
    _walkList(tester, (e) {
      if (!match(e.widget)) return false;
      final ro = e.renderObject;
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        center = ro.localToGlobal(ro.size.center(Offset.zero));
        return true;
      }
      return false;
    });
    return center;
  }

  static Offset? centerInList(WidgetTester tester, String text) =>
      _centerWhere(tester, (w) => w is RichText && _plain(w).contains(text));

  /// Centre of a group action bubble ("… added …").
  /// message_template_utils.dart: `CometChatActionBubble(text: action.message)`.
  static Offset? centerOfActionBubble(WidgetTester tester, String containing) =>
      _centerWhere(
        tester,
        (w) =>
            w is CometChatActionBubble && (w.text ?? '').contains(containing),
      );

  /// Global rect of the message list viewport.
  static Rect listRect(WidgetTester tester) {
    final list = find.byType(CometChatMessageList);
    if (list.evaluate().isEmpty) fail('CometChatMessageList is not on screen');
    return tester.getRect(list.first);
  }

  // ─── Swipe-to-reply ────────────────────────────────────────────────────────

  /// Swipe a bubble to reply. cometchat_message_swipe.dart: rightward
  /// horizontal drag, `swipeThreshold = 60`, visual travel capped at 80.
  /// 160px clears the threshold plus the recogniser's touch slop.
  static Future<void> swipeAt(WidgetTester tester, Offset start) async {
    await tester.dragFrom(start, const Offset(160, 0));
    await pumpFor(tester, const Duration(milliseconds: 900));
  }

  static Future<void> swipeMessage(WidgetTester tester, String text) async {
    final center = centerInList(tester, text);
    if (center == null) {
      fail('Message "$text" is not laid out in the list — cannot swipe it');
    }
    await swipeAt(tester, center);
  }

  static Future<void> longPressMessage(WidgetTester tester, String text) async {
    final center = centerInList(tester, text);
    if (center == null) {
      fail('Message "$text" is not laid out in the list — cannot long-press');
    }
    await tester.longPressAt(center);
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// The long-press options route. cometchat_message_action_overlay.dart
  /// `CometChatMessageActionOverlay` — not exported by the package, so it is
  /// matched by runtime type name.
  static Finder actionOverlay() => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'CometChatMessageActionOverlay',
  );

  /// The reply preview ABOVE THE INPUT. cometchat_message_composer.dart
  /// `_buildInlinePreview` builds a `CometChatMessagePreview` with the close
  /// button; the quoted block inside a sent bubble is the same widget with
  /// `hideCloseButton: true` (cometchat_message_list.dart), so the flag is
  /// what tells the two apart.
  static Finder composerReplyPreview() => find.descendant(
    of: composer(),
    matching: find.byWidgetPredicate(
      (w) => w is CometChatMessagePreview && !w.hideCloseButton,
    ),
  );

  /// Close button of the composer preview. cometchat_message_preview.dart:
  /// `Semantics(button: true, label: close)` → `Icon(Icons.close, size: 16)`.
  static Finder composerReplyPreviewClose() => find.descendant(
    of: composerReplyPreview(),
    matching: find.byIcon(Icons.close),
  );

  /// All text shown by widgets matched by [scope] (Text + RichText).
  static String textUnder(WidgetTester tester, Finder scope) {
    final parts = <String>[];
    for (final w in tester.widgetList<RichText>(
      find.descendant(of: scope, matching: find.byType(RichText)),
    )) {
      parts.add(_plain(w));
    }
    return parts.join('\n');
  }

  /// Text of every quoted-reply block rendered inside list bubbles.
  static List<String> quotedBlocksInList(WidgetTester tester) {
    final out = <String>[];
    _walkList(tester, (e) {
      final w = e.widget;
      if (w is CometChatMessagePreview && w.hideCloseButton) {
        final parts = <String>[];
        void collect(Element c) {
          final cw = c.widget;
          if (cw is RichText) parts.add(_plain(cw));
          c.visitChildren(collect);
        }

        e.visitChildren(collect);
        out.add(parts.join('\n'));
      }
      return false;
    });
    return out;
  }

  // ─── Mention suggestions ───────────────────────────────────────────────────

  /// The suggestion list ITSELF. message_composer_suggestion_list.dart:
  /// `Semantics(label: 'Suggestion list with ${suggestions.length} items')`.
  /// (`MessageComposerSuggestionList` is not exported, hence the label.)
  static Finder suggestionList() => find.descendant(
    of: composer(),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label ?? '').startsWith('Suggestion list with '),
    ),
  );

  /// A row of the list. Same file, `_buildSuggestionItem`:
  /// `Semantics(label: item.title ?? 'Suggestion item', button: true)`.
  static Finder suggestionRows() => find.descendant(
    of: suggestionList(),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          (w.properties.label ?? '').isNotEmpty,
    ),
  );

  static Finder suggestionRow(String title) => find.descendant(
    of: suggestionList(),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == title,
    ),
  );

  /// Titles of the rows currently built (the list is lazy, so this is the
  /// visible window plus cache extent).
  static List<String> suggestionTitles(WidgetTester tester) => tester
      .widgetList<Semantics>(suggestionRows())
      .map((s) => s.properties.label ?? '')
      .toList();

  /// Wait until the suggestion list is open and holds at least one row.
  static Future<void> waitForSuggestions(WidgetTester tester) async {
    final opened = await pumpUntilFound(
      tester,
      suggestionRows(),
      timeout: const Duration(seconds: 15),
    );
    if (!opened) {
      fail(
        'Mention suggestion list did not open (no "Suggestion list with N '
        'items" node with rows under the composer)',
      );
    }
  }

  static Future<void> waitForSuggestionRow(
    WidgetTester tester,
    String title,
  ) async {
    final shown = await pumpUntilFound(
      tester,
      suggestionRow(title),
      timeout: const Duration(seconds: 15),
    );
    if (!shown) {
      fail(
        '"$title" never appeared IN THE SUGGESTION LIST '
        '(rows: ${suggestionTitles(tester)})',
      );
    }
  }

  static Future<void> tapSuggestion(WidgetTester tester, String title) async {
    await waitForSuggestionRow(tester, title);
    await tester.tap(suggestionRow(title).first);
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  /// A rendered mention chip inside the message list. formatter_utils.dart
  /// `buildTextSpan` renders an attributed text that has a background as
  /// `WidgetSpan → Container(decoration) → GestureDetector → Text(name)`.
  /// Returns the background colour of that nearest `Container`, or null when
  /// no `Text` with exactly [label] exists in the list.
  static Color? mentionChipBackground(WidgetTester tester, String label) {
    Color? color;
    var seen = false;
    _walkList(tester, (e) {
      final w = e.widget;
      if (w is Text && w.data == label) {
        seen = true;
        e.visitAncestorElements((a) {
          final aw = a.widget;
          if (aw is Container) {
            final d = aw.decoration;
            if (d is BoxDecoration) color = d.color;
            return false;
          }
          return true;
        });
        return true;
      }
      return false;
    });
    return seen ? (color ?? Colors.transparent) : null;
  }
}
