/// Properties of `EmojiUtils`: emoji-only detection and the scaled font size.
///
///   flutter test test/property/emoji_utils_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';

/// One user-perceived emoji each: plain, skin-toned, ZWJ family, flag,
/// keycaps, variation-selector heart, ZWJ + VS16 flag.
const _emoji = [
  '😀',
  '👍🏽',
  '👨‍👩‍👧‍👦',
  '🇮🇳',
  '1️⃣',
  '#️⃣',
  '❤️',
  '🏳️‍🌈',
  '🎉',
  '🔥',
];

/// Skin-toned ZWJ sequences — also ONE user-perceived emoji each.
const _tonedZwj = ['🧑🏿‍🚀', '👩🏽‍💻', '👨🏻‍🍳', '🧑🏾‍🤝‍🧑🏼'];

String _genEmojiRun(Random r, int count) {
  final b = StringBuffer(r.pick(['', ' ', '\n']));
  for (var i = 0; i < count; i++) {
    b.write(r.pick(_emoji));
    b.write(r.pick(['', ' ', '  ', '\n']));
  }
  return b.toString();
}

void main() {
  test('the emoji count of any string is never negative, and detection '
      'agrees with it exactly', () {
    forAll((r) => genUnicode(r, maxParts: 10), (text) {
      final count = EmojiUtils.emojiOnlyCount(text);
      expect(count, greaterThanOrEqualTo(0));
      expect(
        EmojiUtils.isEmojiOnly(text),
        count >= 1 && count <= EmojiUtils.maxScaledCount,
      );
      // Stable: asking twice, or with padding, changes nothing.
      expect(EmojiUtils.emojiOnlyCount(text), count);
      expect(EmojiUtils.emojiOnlyCount('  $text\n'), count);
    }, cases: 300);
  });

  test('a run of N emoji counts as N however it is spaced, sequences '
      'included', () {
    forAll(
      (r) {
        final n = r.between(1, 8);
        return (n, _genEmojiRun(r, n));
      },
      (input) {
        final (n, text) = input;
        expect(EmojiUtils.emojiOnlyCount(text), n);
        expect(EmojiUtils.isEmojiOnly(text), n <= EmojiUtils.maxScaledCount);
      },
      cases: 300,
    );
  });

  test('a skin-toned profession or couple emoji is not recognised as an '
      'emoji at all', () {
    // FINDING: the detector's grammar is
    // `base (ZWJ base)* skin-tone?` — it only allows a Fitzpatrick modifier
    // at the very END of a sequence. Real skin-toned ZWJ sequences put the
    // modifier right after the FIRST base (`🧑 + 🏿 + ZWJ + 🚀`). The regex
    // therefore matches `🧑`, then the lone modifier as a second "emoji",
    // and leaves the ZWJ behind as residue, so `emojiOnlyCount` answers 0:
    // a message that is just "👩🏽‍💻" renders at body size while "👩‍💻"
    // (no skin tone) renders at 48pt. Expected: 1.
    forAll((r) => r.pick(_tonedZwj), (emoji) {
      expect(EmojiUtils.emojiOnlyCount(emoji), 0);
      expect(EmojiUtils.isEmojiOnly(emoji), isFalse);
    }, cases: 20);
  });

  test('one letter anywhere makes a message not emoji-only', () {
    forAll(
      (r) {
        final run = _genEmojiRun(r, r.between(1, 4));
        final at = r.nextInt(run.length + 1);
        // Insert only on a rune boundary so no surrogate pair is split.
        final runes = run.runes.toList();
        final cut = min(at, runes.length);
        return String.fromCharCodes([
          ...runes.take(cut),
          ...genAlnum(r, max: 3, alphabet: 'abcxyzABC').runes,
          ...runes.skip(cut),
        ]);
      },
      (text) {
        expect(EmojiUtils.emojiOnlyCount(text), 0);
        expect(EmojiUtils.isEmojiOnly(text), isFalse);
      },
      cases: 300,
    );
  });

  test('text without any emoji is never emoji-only', () {
    forAll(genPlainWords, (text) {
      // Digits, '#' and '*' carry the Unicode `Emoji` property (they are
      // keycap bases) but are not emoji on their own: the detector asks for
      // `Emoji_Presentation`, an explicit VS16, or the full keycap sequence.
      expect(EmojiUtils.emojiOnlyCount(text), 0);
    });
    forAll((r) => genAlnum(r, alphabet: '0123456789#*'), (digits) {
      expect(EmojiUtils.emojiOnlyCount(digits), 0, reason: 'bare keycap bases');
    });
  });

  test('the emoji font size never grows as the count grows and stays within '
      'its documented range for any count', () {
    forAll(genInt, (count) {
      final size = EmojiUtils.emojiFontSize(count);
      expect(size, inInclusiveRange(32.0, 48.0));
      if (count >= 1 && count < 1 << 40) {
        expect(EmojiUtils.emojiFontSize(count + 1), lessThanOrEqualTo(size));
      }
    }, cases: 300);
  });
}
