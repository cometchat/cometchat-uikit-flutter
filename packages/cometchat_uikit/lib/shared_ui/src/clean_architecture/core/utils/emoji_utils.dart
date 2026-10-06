// The analyzer's valid_regexps lint cannot statically verify unicode
// property escapes (\p{...}), but the regex is valid at runtime with
// unicode: true. Verified by test/shared_ui/emoji_utils_test.dart, whose
// first access constructs the RegExp.
// ignore_for_file: valid_regexps

/// Utility for detecting emoji-only messages and determining display sizes.
///
/// Implements WhatsApp-style emoji scaling: single emoji is largest,
/// size decreases as emoji count increases up to [maxScaledCount].
class EmojiUtils {
  EmojiUtils._();

  /// Maximum number of emojis that get scaled rendering.
  /// Messages with more emojis than this render as normal text.
  static const int maxScaledCount = 3;

  // Matches a single emoji character/sequence including:
  // - Emoji presentation characters
  // - ZWJ sequences (family, profession emojis)
  // - Skin-tone modifiers
  // - Flag sequences (regional indicators)
  // - Keycap sequences
  // - Variation selector sequences
  static final RegExp _emojiRegex = RegExp(
    '(?:'
    // Flag sequences first (two regional indicator symbols) — must be before
    // single-emoji match to avoid splitting flags into two matches
    '[\u{1F1E0}-\u{1F1FF}]{2}'
    '|'
    // Keycap sequences: digit + optional VS16 + combining enclosing keycap
    r'\p{Emoji}\uFE0F?\u20E3'
    '|'
    // Emoji_Presentation or Emoji + VS16, with optional ZWJ chains and skin tones
    r'(?:\p{Emoji_Presentation}|\p{Emoji}\uFE0F)'
    r'(?:\u200D(?:\p{Emoji_Presentation}|\p{Emoji}\uFE0F))*'
    '[\u{1F3FB}-\u{1F3FF}]?'
    ')',
    unicode: true,
  );

  /// Returns the number of emojis if [text] contains ONLY emojis
  /// (and optional whitespace). Returns 0 if the message contains
  /// any non-emoji, non-whitespace characters.
  static int emojiOnlyCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;

    // Strip all emoji sequences
    final stripped = trimmed.replaceAll(_emojiRegex, '');
    // If anything remains besides whitespace, it's not emoji-only
    if (stripped.trim().isNotEmpty) return 0;

    return _emojiRegex.allMatches(trimmed).length;
  }

  /// Returns true if [text] is an emoji-only message that qualifies
  /// for scaled rendering (1–[maxScaledCount] emojis, nothing else).
  static bool isEmojiOnly(String text) {
    final count = emojiOnlyCount(text);
    return count > 0 && count <= maxScaledCount;
  }

  /// Font size for emoji-only messages based on count.
  /// 1 emoji → 48, 2 → 40, 3 → 32.
  static double emojiFontSize(int emojiCount) {
    switch (emojiCount) {
      case 1:
        return 48.0;
      case 2:
        return 40.0;
      case 3:
        return 32.0;
      default:
        return 32.0;
    }
  }
}
