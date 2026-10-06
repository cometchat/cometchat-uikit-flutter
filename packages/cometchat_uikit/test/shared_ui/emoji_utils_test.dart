// EmojiUtils decides when a text message renders as large emoji.
//
// Its regex sits under `// ignore_for_file: valid_regexps`, justified by the
// claim that it was "verified by unit tests". There were none. The analyzer
// cannot check \p{...} property escapes, so these tests are the check: the
// first access constructs the RegExp, and an invalid pattern would throw here
// rather than in someone's chat.

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/emoji_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmojiUtils.emojiOnlyCount', () {
    test('a single emoji counts as one', () {
      expect(EmojiUtils.emojiOnlyCount('\u{1F600}'), 1);
    });

    test('a flag, two regional indicators, is one emoji rather than two', () {
      expect(EmojiUtils.emojiOnlyCount('\u{1F1EE}\u{1F1F3}'), 1);
    });

    test('a ZWJ family sequence is one emoji', () {
      expect(
        EmojiUtils.emojiOnlyCount('\u{1F468}\u200D\u{1F469}\u200D\u{1F467}'),
        1,
      );
    });

    test('a skin-tone modifier stays with its emoji', () {
      expect(EmojiUtils.emojiOnlyCount('\u{1F44D}\u{1F3FD}'), 1);
    });

    test('a keycap sequence is one emoji', () {
      expect(EmojiUtils.emojiOnlyCount('1\uFE0F\u20E3'), 1);
    });

    test('an emoji with the VS16 selector is one emoji', () {
      expect(EmojiUtils.emojiOnlyCount('\u2764\uFE0F'), 1);
    });

    test('whitespace around and between emoji is ignored', () {
      expect(EmojiUtils.emojiOnlyCount('  \u{1F600} \u{1F600}  '), 2);
    });

    test('any text alongside the emoji disqualifies the message', () {
      expect(EmojiUtils.emojiOnlyCount('hi \u{1F600}'), 0);
    });

    test('a bare digit is not an emoji, though Unicode lists it as one', () {
      expect(EmojiUtils.emojiOnlyCount('1'), 0);
    });

    test('empty and whitespace-only text count as zero', () {
      expect(EmojiUtils.emojiOnlyCount(''), 0);
      expect(EmojiUtils.emojiOnlyCount('   '), 0);
    });
  });

  group('EmojiUtils.isEmojiOnly', () {
    test('one to three emoji qualify for scaled rendering', () {
      expect(EmojiUtils.isEmojiOnly('\u{1F600}'), isTrue);
      expect(EmojiUtils.isEmojiOnly('\u{1F600}\u{1F600}\u{1F600}'), isTrue);
    });

    test('four emoji render as normal text', () {
      expect(
        EmojiUtils.isEmojiOnly('\u{1F600}\u{1F600}\u{1F600}\u{1F600}'),
        isFalse,
      );
    });
  });

  group('EmojiUtils.emojiFontSize', () {
    test('shrinks as the count grows and holds at the smallest size', () {
      expect(EmojiUtils.emojiFontSize(1), 48);
      expect(EmojiUtils.emojiFontSize(2), 40);
      expect(EmojiUtils.emojiFontSize(3), 32);
      expect(EmojiUtils.emojiFontSize(4), 32);
    });
  });
}
