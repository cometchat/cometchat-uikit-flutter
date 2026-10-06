/// Regression tests for ENG-39492 — a message carrying a mention rendered far
/// larger than the same message without one, on Android.
///
/// A mention is painted as a [WidgetSpan]: it needs a background pill and
/// horizontal padding, which a TextSpan cannot do. `RenderParagraph` already
/// scales a placeholder by the ambient text scale — it sizes the box and
/// paints the child through a matching transform — so a `Text` inside that box
/// resolving `MediaQuery.textScaler` a second time scales the run twice over.
///
/// It is invisible at a text scale of exactly 1.0, which is why it survived
/// review; QA's Android device ran a raised display size, where the mention
/// took roughly twice the line the surrounding text did.
///
///   flutter test test/shared_ui/formatters/mention_text_scale_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(String uid, String name) => User(uid: uid, name: name);

/// The scales worth holding: 1.0 is the only one the bug ever looked right at,
/// 1.3 is a common Android "large" display size, 2.0 is the accessibility end.
const _scales = <double>[1.0, 1.15, 1.3, 1.6, 2.0];

/// Body text at [scale], laid out wide enough that nothing wraps.
Future<double> _plainHeight(WidgetTester tester, double scale) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 2000,
                child: Text(
                  'hi @Bob',
                  key: key,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(key)).height;
}

/// The same line with the mention rendered through the formatter chain.
Future<double> _mentionHeight(WidgetTester tester, double scale) async {
  const src = 'hi <@uid:u2>';
  final key = GlobalKey();
  late List<InlineSpan> spans;

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                final message = TextMessage(
                  text: src,
                  receiverUid: 'u2',
                  receiverType: CometChatReceiverType.user,
                  type: MessageTypeConstants.text,
                  sender: _user('u1', 'Alice'),
                )..mentionedUsers = [_user('u2', 'Bob')];
                spans = FormatterUtils.buildTextSpan(
                  src,
                  [CometChatMentionsFormatter()..message = message],
                  context,
                  BubbleAlignment.left,
                );
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 2000,
                    child: Text.rich(TextSpan(children: spans), key: key),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Guard the fixture: if the mention never became a WidgetSpan the height
  // comparison below would pass for the wrong reason.
  expect(
    spans.whereType<WidgetSpan>(),
    isNotEmpty,
    reason: 'the mention should render as a WidgetSpan — it needs a pill',
  );
  return tester.getSize(find.byKey(key)).height;
}

void main() {
  testWidgets('a mention occupies one ordinary line at any text scale', (
    tester,
  ) async {
    for (final scale in _scales) {
      final plain = await _plainHeight(tester, scale);
      final mention = await _mentionHeight(tester, scale);
      expect(
        mention,
        closeTo(plain, 1.0),
        reason:
            'at textScale $scale a mention took ${mention}px where plain body '
            'text took ${plain}px — the WidgetSpan child is being scaled on '
            'top of the placeholder scaling (ENG-39492)',
      );
    }
  });

  testWidgets('the mention pill is centred on the line, not hung below it', (
    tester,
  ) async {
    const src = 'hi <@uid:u2>';
    late List<InlineSpan> spans;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            final message = TextMessage(
              text: src,
              receiverUid: 'u2',
              receiverType: CometChatReceiverType.user,
              type: MessageTypeConstants.text,
              sender: _user('u1', 'Alice'),
            )..mentionedUsers = [_user('u2', 'Bob')];
            spans = FormatterUtils.buildTextSpan(
              src,
              [CometChatMentionsFormatter()..message = message],
              context,
              BubbleAlignment.left,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    final widgetSpans = spans.whereType<WidgetSpan>().toList();
    expect(widgetSpans, isNotEmpty);
    for (final span in widgetSpans) {
      expect(
        span.alignment,
        PlaceholderAlignment.middle,
        reason:
            'PlaceholderAlignment.bottom (the default) hangs the box below '
            'the baseline and inflates the line box',
      );
    }
  });
}
