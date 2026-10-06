/// Golden pins for the message-list bubble, composed the way
/// `CometChatMessageList._buildMessageItem` composes it: a
/// [CometChatMessageBubble] carrying a [CometChatTextBubble] as its content
/// view and a [CometChatReceipt] as its status-info view.
///
/// The previous version of this file rendered a bare `Text(message.text)` in a
/// `Scaffold`, so it was a golden of Flutter's own text layout and would have
/// stayed green through any regression in the Kit. It also shipped without
/// baselines, so both variants failed on every run. Both are fixed here.
///
///   flutter test test/chat_ui/message_list/goldens/                  # verify
///   flutter test test/chat_ui/message_list/goldens/ --update-goldens # rebake
library;

import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

/// GitHub Actions sets CI=true. Platform goldens use the system font and
/// cannot match a container, so only the Ahem variant runs there.
final bool _isCI =
    Platform.environment['CI'] == 'true' ||
    Platform.environment['ALCHEMIST_CI'] == 'true';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _themed({required Brightness brightness, required Widget bubble}) {
  return MediaQuery(
    // The text bubble caps itself at 75% of MediaQuery width, so a zero-size
    // MediaQueryData collapses it to one character per line.
    data: MediaQueryData(
      platformBrightness: brightness,
      size: const Size(320, 320),
    ),
    child: Theme(
      data: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      // The bubble is a Row/Column tree built outside MaterialApp.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: brightness == Brightness.dark
              ? const Color(0xFF141414)
              : const Color(0xFFFFFFFF),
          child: Align(alignment: Alignment.centerLeft, child: bubble),
        ),
      ),
    ),
  );
}

/// The composition under test — the same slots the message list fills.
Widget _bubble({
  required String text,
  required BubbleAlignment alignment,
  ReceiptStatus? receipt,
  int emojiCount = 0,
}) {
  return CometChatMessageBubble(
    alignment: alignment,
    contentPadding: emojiCount > 0 ? EdgeInsets.zero : null,
    contentView: CometChatTextBubble(
      text: text,
      alignment: alignment,
      emojiCount: emojiCount,
    ),
    statusInfoView: receipt == null
        ? null
        : CometChatReceipt(status: receipt, size: 16),
  );
}

// ---------------------------------------------------------------------------
// Variants
// ---------------------------------------------------------------------------

const _outgoing = BubbleAlignment.right;
const _incoming = BubbleAlignment.left;

const _longText =
    'This is a much longer message that should wrap across multiple lines to '
    'test how the message bubble handles text overflow and proper line '
    'breaking behavior in the UI.';

void main() {
  AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: _isCI
          ? const PlatformGoldensConfig(enabled: false)
          : const PlatformGoldensConfig(),
    ),
    run: () {
      _variantGolden(
        'message_list_sent_read',
        'outgoing bubble, read receipt',
        () => _bubble(
          text: 'Read on both sides',
          alignment: _outgoing,
          receipt: ReceiptStatus.read,
        ),
      );
      _variantGolden(
        'message_list_sent_delivered',
        'outgoing bubble, delivered receipt',
        () => _bubble(
          text: 'Delivered, not read',
          alignment: _outgoing,
          receipt: ReceiptStatus.delivered,
        ),
      );
      _variantGolden(
        'message_list_sent_only',
        'outgoing bubble, sent receipt',
        () => _bubble(
          text: 'Just sent this',
          alignment: _outgoing,
          receipt: ReceiptStatus.sent,
        ),
      );
      _variantGolden(
        'message_list_received',
        'incoming bubble, no receipt',
        () => _bubble(text: 'I am doing great, thanks!', alignment: _incoming),
      );
      _variantGolden(
        'message_list_long_text',
        'incoming bubble, multi-line wrapping',
        () => _bubble(text: _longText, alignment: _incoming),
        height: 260,
      );
      _variantGolden(
        'message_list_emoji_only',
        'emoji-only bubble, scaled and unpadded',
        () => _bubble(
          text: '\u{1F44D}\u{1F389}',
          alignment: _incoming,
          emojiCount: 2,
        ),
      );
    },
  );
}

void _variantGolden(
  String fileName,
  String description,
  Widget Function() bubble, {
  double height = 140,
}) {
  goldenTest(
    description,
    fileName: fileName,
    builder: () => Localizations(
      locale: const Locale('en'),
      delegates: Translations.localizationsDelegates,
      child: GoldenTestGroup(
        scenarioConstraints: BoxConstraints.tightFor(
          width: 320,
          height: height,
        ),
        children: [
          GoldenTestScenario(
            name: 'light',
            child: _themed(brightness: Brightness.light, bubble: bubble()),
          ),
          GoldenTestScenario(
            name: 'dark',
            child: _themed(brightness: Brightness.dark, bubble: bubble()),
          ),
        ],
      ),
    ),
  );
}
