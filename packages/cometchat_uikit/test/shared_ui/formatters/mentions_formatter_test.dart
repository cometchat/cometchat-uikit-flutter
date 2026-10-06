/// Behaviour tests for CometChatMentionsFormatter — Track 3 TEST3 (ENG-38684).
///
/// 815 executable lines at 17% coverage. The formatter turns the wire form of
/// a mention, `<@uid:someone>`, into the `@Display Name` a reader sees, and
/// back again on send. It is string-offset work over user-supplied text, which
/// is the same shape as the bug the rich text controller just yielded, so it
/// is worth pinning precisely.
///
///   flutter test test/shared_ui/formatters/mentions_formatter_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(String uid, String name) => User(uid: uid, name: name);

TextMessage _message(String text, {List<User> mentioned = const []}) =>
    TextMessage(
      text: text,
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      type: MessageTypeConstants.text,
      sender: _user('u1', 'Alice'),
    )..mentionedUsers = mentioned;

void main() {
  // -------------------------------------------------------------------------
  // getTextWithMentions: the wire form -> what a reader sees.
  // -------------------------------------------------------------------------
  group('getTextWithMentions', () {
    test('a single mention becomes the display name', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions('hey <@uid:u2> look', [
          _user('u2', 'Bob'),
        ]),
        'hey @Bob look',
      );
    });

    test('two mentions are both substituted', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions(
          '<@uid:u2> and <@uid:u3>',
          [_user('u2', 'Bob'), _user('u3', 'Carol')],
        ),
        '@Bob and @Carol',
      );
    });

    test('the same uid mentioned twice is replaced in both places', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions(
          '<@uid:u2> then <@uid:u2>',
          [_user('u2', 'Bob')],
        ),
        '@Bob then @Bob',
      );
    });

    test('a token with no matching user is left as the raw wire form', () {
      // The reader sees the raw token. Worth knowing: an unresolved mention
      // does not degrade to something readable.
      expect(
        CometChatMentionsFormatter.getTextWithMentions('hey <@uid:ghost>', [
          _user('u2', 'Bob'),
        ]),
        'hey <@uid:ghost>',
      );
    });

    test('an empty mention list leaves the text untouched', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions('hey <@uid:u2>', []),
        'hey <@uid:u2>',
      );
    });

    test('text with no mentions is returned verbatim', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions('nothing here', [
          _user('u2', 'Bob'),
        ]),
        'nothing here',
      );
    });

    test('an empty string stays empty', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions('', [
          _user('u2', 'Bob'),
        ]),
        '',
      );
    });

    test('a uid that is a prefix of another is not partially replaced', () {
      // 'u2' must not match inside '<@uid:u22>' — the closing angle bracket
      // is part of the search, so this is safe. Pinned because a looser
      // implementation would corrupt the longer mention.
      expect(
        CometChatMentionsFormatter.getTextWithMentions(
          '<@uid:u2> and <@uid:u22>',
          [_user('u2', 'Bob'), _user('u22', 'Bobby')],
        ),
        '@Bob and @Bobby',
      );
    });

    test('a display name containing the wire syntax is not re-expanded', () {
      // Replacement is a single pass per user, so a name that itself looks
      // like a token is inserted literally rather than re-scanned.
      expect(
        CometChatMentionsFormatter.getTextWithMentions('<@uid:u2>', [
          _user('u2', '<@uid:u3>'),
        ]),
        '@<@uid:u3>',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('getMentionedUserName', () {
    test('resolves a uid present on the message', () {
      final m = _message('hi', mentioned: [_user('u2', 'Bob')]);
      expect(CometChatMentionsFormatter.getMentionedUserName('u2', m), 'Bob');
    });

    test('returns empty string for a uid that is not mentioned', () {
      final m = _message('hi', mentioned: [_user('u2', 'Bob')]);
      expect(CometChatMentionsFormatter.getMentionedUserName('u9', m), '');
    });

    test('returns empty string when the message mentions nobody', () {
      expect(
        CometChatMentionsFormatter.getMentionedUserName('u2', _message('hi')),
        '',
      );
    });

    test('picks the first match when a uid appears twice', () {
      final m = _message(
        'hi',
        mentioned: [_user('u2', 'Bob'), _user('u2', 'Bob Duplicate')],
      );
      expect(CometChatMentionsFormatter.getMentionedUserName('u2', m), 'Bob');
    });
  });

  // -------------------------------------------------------------------------
  group('the mention pattern', () {
    final re = RegExp(RegexConstants.mentionRegexPattern);

    test('matches a uid mention', () {
      final m = re.firstMatch('hey <@uid:u2> there');
      expect(m, isNotNull);
      expect(m!.group(1), 'uid');
      expect(m.group(2), 'u2');
    });

    test('matches an all mention', () {
      final m = re.firstMatch('<@all:everyone>');
      expect(m, isNotNull);
      expect(m!.group(1), 'all');
    });

    test('is non-greedy across two mentions', () {
      final all = re.allMatches('<@uid:a> <@uid:b>').toList();
      expect(all, hasLength(2), reason: 'a greedy pattern would match once');
      expect(all.first.group(2), 'a');
      expect(all.last.group(2), 'b');
    });

    test('does not match an unrelated angle-bracket construct', () {
      expect(re.hasMatch('<b>bold</b>'), isFalse);
    });

    test('does not match an unclosed token', () {
      expect(re.hasMatch('<@uid:u2'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('mentioned-user bookkeeping', () {
    test('setMentionedUsers then getMentionedUsers round-trips', () {
      final f = CometChatMentionsFormatter();
      f.setMentionedUsers([_user('u2', 'Bob'), _user('u3', 'Carol')]);
      final uids = f.getMentionedUsers('anything').map((u) => u.uid);
      expect(uids, containsAll(['u2', 'u3']));
    });

    test('the same user added twice is returned once', () {
      final f = CometChatMentionsFormatter();
      f.setMentionedUsers([_user('u2', 'Bob')]);
      f.setMentionedUsers([_user('u2', 'Bob')]);
      expect(
        f.getMentionedUsers('anything').where((u) => u.uid == 'u2'),
        hasLength(1),
        reason: 'dedup is by uid',
      );
    });

    test('two different users sharing a display name are both kept', () {
      // The map is keyed by "@name", so a name collision must not lose one.
      final f = CometChatMentionsFormatter();
      f.setMentionedUsers([_user('u2', 'Bob'), _user('u3', 'Bob')]);
      final uids = f.getMentionedUsers('anything').map((u) => u.uid);
      expect(uids, containsAll(['u2', 'u3']));
    });

    test('a fresh formatter reports no mentioned users', () {
      expect(CometChatMentionsFormatter().getMentionedUsers('x'), isEmpty);
    });

    test('resetMentionsTracker clears the tracker', () {
      final f = CometChatMentionsFormatter();
      f.mentionTracker = '@Bo';
      f.resetMentionsTracker();
      expect(f.mentionTracker, isEmpty);
    });

    test('updatePreviousText does not throw', () {
      final f = CometChatMentionsFormatter();
      expect(() => f.updatePreviousText('hello'), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  group('text styles', () {
    testWidgets('the bubble style is produced for both alignments', (
      tester,
    ) async {
      final f = CometChatMentionsFormatter();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              for (final a in BubbleAlignment.values) {
                expect(
                  f.getMessageBubbleTextStyle(context, a),
                  isA<TextStyle>(),
                  reason: '$a',
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets('the input style is produced', (tester) async {
      final f = CometChatMentionsFormatter();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              expect(f.getMessageInputTextStyle(context), isA<TextStyle>());
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });
  });
}
