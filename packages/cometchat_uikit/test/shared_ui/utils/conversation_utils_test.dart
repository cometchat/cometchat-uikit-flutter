/// Behaviour tests for ConversationUtils.stripMarkdownSyntax —
/// Track 3 TEST3 (ENG-38684).
///
/// `conversation_utils.dart` was at 6% coverage. `stripMarkdownSyntax` is the
/// function that turns a formatted message into the one-line subtitle under a
/// conversation, so every marker the composer can produce has to come back out
/// again. It is a dozen sequential regex passes over user text, and order
/// between those passes matters — bold before italic, and so on.
///
///   flutter test test/shared_ui/utils/conversation_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

String strip(String s) => ConversationUtils.stripMarkdownSyntax(s);

void main() {
  group('inline emphasis', () {
    test('bold markers are removed', () {
      expect(strip('**bold**'), 'bold');
      expect(strip('__bold__'), 'bold');
    });

    test('italic markers are removed', () {
      expect(strip('*italic*'), 'italic');
      expect(strip('a _italic_ b'), 'a italic b');
    });

    test('bold-italic is removed in one pass', () {
      expect(strip('***both***'), 'both');
      expect(strip('___both___'), 'both');
    });

    test('strikethrough markers are removed', () {
      expect(strip('~~gone~~'), 'gone');
    });

    test('inline code markers are removed but the code survives', () {
      expect(strip('run `flutter test` now'), 'run flutter test now');
    });

    test('emphasis inside a sentence keeps the surrounding words', () {
      expect(strip('the **quick** brown fox'), 'the quick brown fox');
    });

    test('two bold runs in one line are both stripped', () {
      expect(strip('**a** and **b**'), 'a and b');
    });
  });

  group('underscores that are not emphasis', () {
    test('a snake_case identifier is left alone', () {
      // The italic underscore rule is anchored to whitespace on both sides,
      // which is what protects identifiers.
      expect(strip('call some_method_name here'), 'call some_method_name here');
    });

    test('a leading underscore word is left alone', () {
      expect(strip('the _private field'), 'the _private field');
    });
  });

  // These four passes originally used String.replaceAll with a r'$1'
  // replacement, which Dart takes literally, so every heading, quote and list
  // put the characters $ and 1 into the conversation subtitle and destroyed
  // the captured newline with them. Fixed under ENG-39024 by switching to
  // replaceAllMapped, matching the inline passes above.
  group('block constructs', () {
    test('a heading marker is removed', () {
      expect(strip('# Title'), 'Title');
      expect(strip('### Deep'), 'Deep');
    });

    test('a blockquote marker is removed', () {
      expect(strip('> quoted'), 'quoted');
      expect(strip('>> double'), 'double');
    });

    test('unordered list markers are removed', () {
      expect(strip('- one'), 'one');
      expect(strip('* one'), 'one');
    });

    test('ordered list markers are removed', () {
      expect(strip('1. first'), 'first');
      expect(strip('12. twelfth'), 'twelfth');
    });

    test('a code fence is removed', () {
      expect(strip('```dart\ncode'), 'code');
    });

    test('markers only count at the start of a line', () {
      expect(strip('a - b'), 'a - b', reason: 'mid-line dash is literal');
      expect(strip('see # 1'), 'see # 1');
    });

    test('no block construct leaves a dollar artifact behind', () {
      for (final input in [
        '# h',
        '> q',
        '>> q',
        '- l',
        '* l',
        '1. l',
        '99. l',
      ]) {
        expect(strip(input), isNot(contains(r'$')), reason: input);
      }
    });
  });

  group('multi-line', () {
    test('each line loses its marker and the newline survives', () {
      expect(strip('- one\n- two'), 'one\ntwo');
    });

    test('mixed constructs across lines', () {
      expect(strip('# Title\n- **item**'), 'Title\nitem');
    });

    test('three list lines keep both separators', () {
      expect(strip('- a\n- b\n- c'), 'a\nb\nc');
    });
  });

  group('edge cases', () {
    test('plain text is unchanged', () {
      expect(strip('nothing to strip'), 'nothing to strip');
    });

    test('an empty string stays empty', () {
      expect(strip(''), '');
    });

    test('the result is trimmed', () {
      expect(strip('   padded   '), 'padded');
    });

    test('unmatched markers are left as literal text', () {
      expect(strip('**unclosed'), '**unclosed');
      expect(strip('a * b'), 'a * b');
    });

    test('an emoji-only message survives', () {
      expect(strip('🎉🎉'), '🎉🎉');
    });

    test('a heading with no text collapses to empty', () {
      expect(strip('# '), '');
    });

    test('inline emphasis inside a heading is stripped too', () {
      expect(strip('# **Title**'), 'Title');
    });
  });
}
