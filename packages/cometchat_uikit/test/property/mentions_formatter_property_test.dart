/// Properties of `CometChatMentionsFormatter`: the step that turns the wire
/// form of a mention (`<@uid:id>` / `<@all:id>`) into what a user reads.
///
///   flutter test test/property/mentions_formatter_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

cc.TextMessage _message(String text, List<cc.User> mentioned) => cc.TextMessage(
  text: text,
  receiverUid: 'receiver',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
)..mentionedUsers = mentioned;

/// A uid the wire format can carry: anything without `>` and without a line
/// terminator (the mention pattern is `<@(uid|all):(.+?)>`, and `.` stops at
/// a line break — CometChat uids cannot contain one).
String _genUid(Random r) => r.chance(0.7)
    ? genAlnum(r, max: 8)
    : genUnicode(
        r,
        maxParts: 3,
        markers: false,
      ).replaceAll(RegExp('[>\n\r\u2028\u2029]'), '');

/// A display name: arbitrary unicode, emoji and RTL included. `<` and `>` are
/// removed so a name can never itself spell a mention token.
String _genName(Random r) {
  final name = genUnicode(
    r,
    maxParts: 4,
    markers: false,
  ).replaceAll(RegExp('[<>]'), '');
  return name.isEmpty ? 'N' : name;
}

class _Case {
  _Case(this.users, this.pieces);

  final List<cc.User> users;

  /// Alternating plain words and mention tokens.
  final List<String> pieces;

  String get text => pieces.join();

  @override
  String toString() =>
      'users: ${users.map((u) => '${show(u.uid)}=${show(u.name)}').toList()}, '
      'text: ${show(text)}';
}

_Case _genCase(Random r, {required bool knownOnly}) {
  final uids = <String>{};
  while (uids.length < r.between(1, 4)) {
    final uid = _genUid(r);
    if (uid.isNotEmpty) uids.add(uid);
  }
  final users = [for (final u in uids) cc.User(uid: u, name: _genName(r))];
  final pieces = <String>[];
  for (var i = 0; i < r.between(1, 6); i++) {
    pieces.add('${genAlnum(r)} ');
    if (r.chance(0.7)) {
      final uid = knownOnly || r.chance(0.6)
          ? r.pick(users).uid
          : 'ghost${genAlnum(r, max: 4)}';
      pieces.add('<@uid:$uid>');
    }
  }
  return _Case(users, pieces);
}

void main() {
  testWidgets('mention formatting never throws for arbitrary text and '
      'arbitrary uid/name sets, and its ranges are ordered and disjoint', (
    tester,
  ) async {
    final context = await pumpContext(tester);

    forAll(
      (r) => _Case(
        List.generate(
          r.nextInt(4),
          (_) => cc.User(uid: _genUid(r), name: genUnicode(r, maxParts: 4)),
        ),
        [genUnicode(r, maxParts: 16)],
      ),
      (c) {
        final attrs = CometChatMentionsFormatter(
          message: _message(c.text, c.users),
        ).getAttributedText(c.text, context, BubbleAlignment.left);

        var cursor = 0;
        for (final a in attrs) {
          expect(a.start, greaterThanOrEqualTo(cursor), reason: '$a');
          expect(a.end, greaterThan(a.start), reason: '$a');
          expect(a.end, lessThanOrEqualTo(c.text.length), reason: '$a');
          expect(a.underlyingText, isNotNull);
          cursor = a.end;
        }
      },
      cases: 200,
    );
  });

  testWidgets('every mention of a known user reads as "@name", and nothing '
      'else in the text changes', (tester) async {
    final context = await pumpContext(tester);

    forAll((r) => _genCase(r, knownOnly: false), (c) {
      final byUid = {for (final u in c.users) u.uid: u.name};
      final expected = c.pieces.map((p) {
        final m = RegExp(r'^<@uid:(.*)>$', dotAll: true).firstMatch(p);
        if (m == null) return p;
        final name = byUid[m.group(1)];
        return name == null ? p : '@$name'; // unknown uid: raw token, verbatim
      }).join();

      final spans = FormatterUtils.buildTextSpan(
        c.text,
        [CometChatMentionsFormatter(message: _message(c.text, c.users))],
        context,
        BubbleAlignment.left,
      );
      expect(visibleText(spans, context), expected);
    });
  });

  test('the plain-text mention replacement leaves no token of a known user '
      'behind and never touches the rest', () {
    forAll((r) => _genCase(r, knownOnly: true), (c) {
      final out = CometChatMentionsFormatter.getTextWithMentions(
        c.text,
        c.users,
      );
      final byUid = {for (final u in c.users) u.uid: u.name};
      final expected = c.pieces.map((p) {
        final m = RegExp(r'^<@uid:(.*)>$', dotAll: true).firstMatch(p);
        return m == null ? p : '@${byUid[m.group(1)]}';
      }).join();
      expect(out, expected);
      for (final u in c.users) {
        expect(out, isNot(contains('<@uid:${u.uid}>')));
      }
    });
  });

  test('looking a uid up in a message answers with that user\'s name, or '
      'with the empty string when the uid was never mentioned', () {
    forAll((r) => _genCase(r, knownOnly: true), (c) {
      final message = _message(c.text, c.users);
      for (final u in c.users) {
        expect(
          CometChatMentionsFormatter.getMentionedUserName(u.uid, message),
          u.name,
        );
      }
      expect(
        CometChatMentionsFormatter.getMentionedUserName('\u0000none', message),
        '',
      );
    });
  });

  testWidgets('markdown and mentions together never throw and never show a '
      'raw token for a known user', (tester) async {
    final context = await pumpContext(tester);

    forAll(
      (r) {
        final c = _genCase(r, knownOnly: true);
        // Wrap random pieces in bold / italic so ranges nest and abut.
        final wrapped = [
          for (final p in c.pieces)
            r.chance(0.4) ? '${r.pick(['**', '_', '~~'])}$p' : p,
        ];
        return _Case(c.users, wrapped);
      },
      (c) {
        final spans = FormatterUtils.buildTextSpan(
          c.text,
          [
            MarkdownTextFormatter(),
            CometChatMentionsFormatter(message: _message(c.text, c.users)),
          ],
          context,
          BubbleAlignment.right,
        );
        final seen = visibleText(spans, context);
        for (final u in c.users) {
          expect(seen, isNot(contains('<@uid:${u.uid}>')));
        }
      },
    );
  });
}
