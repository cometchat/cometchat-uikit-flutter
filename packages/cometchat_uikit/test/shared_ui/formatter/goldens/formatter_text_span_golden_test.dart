/// Golden coverage for every surface that renders through
/// [FormatterUtils.buildTextSpan] — the change in ENG-38859 alters how a
/// caller's `textStyle` combines with the function's own palette/typography
/// defaults, and these pin what that looks like on each surface.
///
/// Two distinct behaviours are covered, because the old code got both wrong:
///
///  * **No caller style** — the function's own defaults apply. Before the fix
///    `textStyle?.merge(defaults)` evaluated to `null`, so the spans carried
///    no style and inherited their parent span's. The message text bubble and
///    the media caption now pass their resolved style, because a child span's
///    own style hides the parent's (see bubble_custom_text_style_test.dart).
///  * **A caller style** — the conversation subtitle, the search preview and
///    the composer/message-list previews all pass one. Before the fix the
///    hard-coded defaults won and the caller's colour and size were dropped.
///
///   flutter test test/shared_ui/formatter/goldens/
///   flutter test test/shared_ui/formatter/goldens/ --update-goldens
library;

import '../../../helpers/golden_config.dart';
import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

/// A caller style deliberately unlike the function's defaults on every axis it
/// sets, so a golden shows immediately which side won.
const _callerStyle = TextStyle(
  color: Color(0xFFB00020),
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.5,
);

Widget _themed({required Brightness brightness, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness),
    child: Theme(
      data: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFFFFFFF),
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      ),
    ),
  );
}

/// The bubble path with no bubble style set: the bubble passes its own
/// resolved default style down, so these pin the default look.
Widget _bubble(BubbleAlignment alignment) =>
    CometChatTextBubble(text: 'The quick brown fox', alignment: alignment);

/// The preview path — a `textStyle` is passed, which is the case where the
/// hard-coded defaults used to win.
Widget _preview({TextStyle? style, BubbleAlignment? alignment}) => Builder(
  builder: (context) => Text.rich(
    TextSpan(
      children: FormatterUtils.buildTextSpan(
        'The quick brown fox',
        const [],
        context,
        alignment ?? BubbleAlignment.left,
        forConversation: true,
        textStyle: style,
      ),
    ),
  ),
);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _golden(
        'formatter_bubble_no_caller_style',
        'text bubble — no caller style, so the function supplies its own',
        light: _bubble(BubbleAlignment.left),
        dark: _bubble(BubbleAlignment.left),
      );
      _golden(
        'formatter_bubble_outgoing_no_caller_style',
        'outgoing text bubble — right alignment picks the white default',
        light: _bubble(BubbleAlignment.right),
        dark: _bubble(BubbleAlignment.right),
      );
      _golden(
        'formatter_preview_with_caller_style',
        'conversation-style preview — the caller style must win',
        light: _preview(style: _callerStyle),
        dark: _preview(style: _callerStyle),
      );
      _golden(
        'formatter_preview_no_caller_style',
        'conversation-style preview — no caller style, defaults apply',
        light: _preview(),
        dark: _preview(),
      );
      _golden(
        'formatter_preview_outgoing_with_caller_style',
        'right-aligned preview — caller colour beats the white default',
        light: _preview(style: _callerStyle, alignment: BubbleAlignment.right),
        dark: _preview(style: _callerStyle, alignment: BubbleAlignment.right),
      );
    },
  );
}

void _golden(
  String fileName,
  String description, {
  required Widget light,
  required Widget dark,
}) {
  goldenTest(
    description,
    fileName: fileName,
    builder: () => Localizations(
      locale: const Locale('en'),
      delegates: Translations.localizationsDelegates,
      child: GoldenTestGroup(
        scenarioConstraints: const BoxConstraints.tightFor(
          width: 320,
          height: 64,
        ),
        children: [
          GoldenTestScenario(
            name: 'light',
            child: _themed(brightness: Brightness.light, child: light),
          ),
          GoldenTestScenario(
            name: 'dark',
            child: _themed(brightness: Brightness.dark, child: dark),
          ),
        ],
      ),
    ),
  );
}
