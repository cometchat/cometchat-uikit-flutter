/// `CometChatMentionsFormatter` — the two directions between the composer's
/// plain text and the wire form. Track 3 TEST3 (ENG-38684).
///
/// `handlePreMessageSend` rewrites "@Bob" back into `<@uid:u2>` just before a
/// message leaves, and `onMessageEdit` does the reverse when a sent message is
/// pulled back into the composer. Between them they decide who actually gets
/// notified: a mention the send path fails to rewrite is delivered as literal
/// text and pings nobody, and one it rewrites twice pings the wrong person.
/// Neither had ever run in a test.
///
/// `getAttributedText` (the read path) is covered by
/// mentions_formatter_attributed_text_test.dart; this file does not repeat it.
///
///   flutter test test/shared_ui/formatters/mentions_formatter_send_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _bob = cc.User(uid: 'u2', name: 'Bob');
final _carol = cc.User(uid: 'u3', name: 'Carol');
final _john = cc.User(uid: 'u4', name: 'John');
final _johnSmith = cc.User(uid: 'u5', name: 'John Smith');

cc.TextMessage _text(String body) => cc.TextMessage(
  text: body,
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
);

cc.MediaMessage _media(String? caption) => cc.MediaMessage(
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.image,
  caption: caption,
);

/// Runs [body] with a live, localized context.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
}

/// A formatter whose bookkeeping already describes [mentions] — the state the
/// composer would have built up as the user picked each suggestion.
///
/// [mentions] maps the start offset of a mention in the composer text to the
/// user it stands for; a null user marks an `@all`.
CometChatMentionsFormatter _withTracked(
  Map<int, String> positions,
  Map<String, cc.User?> users, {
  String? mentionAllLabelId,
  Set<String> allMentions = const {},
}) {
  final f = CometChatMentionsFormatter(mentionAllLabelId: mentionAllLabelId);
  f.trackedMentionPositions.addAll(positions);
  users.forEach((mention, user) {
    f.mentionedUsersMap[mention] = [user];
  });
  f.mentionAllPositions.addAll(allMentions);
  return f;
}

void main() {
  // ==========================================================================
  group('handlePreMessageSend — composer text to wire form', () {
    testWidgets('a tracked mention becomes its uid token and the user is '
        'attached to the message', (tester) async {
      final f = _withTracked({3: '@Bob'}, {'@Bob': _bob});
      final message = _text('hi @Bob there');

      await withContext(tester, (context) {
        final out = f.handlePreMessageSend(context, message) as cc.TextMessage;
        expect(out.text, 'hi <@uid:u2> there');
        expect(out.mentionedUsers.map((u) => u.uid), ['u2']);
      });
    });

    testWidgets('every occurrence of the same mention text is rewritten', (
      tester,
    ) async {
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});
      final message = _text('@Bob and @Bob again');

      await withContext(tester, (context) {
        final out = f.handlePreMessageSend(context, message) as cc.TextMessage;
        expect(out.text, '<@uid:u2> and <@uid:u2> again');
        // The same user is only listed once.
        expect(out.mentionedUsers, hasLength(1));
      });
    });

    testWidgets('mentioning a user whose name is a prefix of another '
        'user\'s CORRUPTS the outgoing text', (tester) async {
      // FINDING: `handlePreMessageSend` sorts the mention TEXTS longest-first
      // — the code comments say this is to stop "@John" matching inside
      // "@John Smith" — but then collects EVERY occurrence of every mention
      // text independently, so the short name still matches inside the long
      // one. The overlapping ranges are all kept, sorted by start position and
      // applied one after another, each replacing a range of a string the
      // previous replacement already rewrote.
      //
      // Result below: "@John Smith @John hi" ships as
      // "<@uid:u4>:u5> <@uid:u4> hi" — the leading mention is spliced into
      // garbage that pings John instead of John Smith, and the recipient sees
      // a fragment of a uid token in the message body. Expected: collect
      // occurrences into a non-overlapping set, longest first, and skip any
      // match that falls inside a range already claimed.
      final f = _withTracked(
        {0: '@John Smith', 12: '@John'},
        {'@John Smith': _johnSmith, '@John': _john},
      );
      final message = _text('@John Smith @John hi');

      await withContext(tester, (context) {
        final out = f.handlePreMessageSend(context, message) as cc.TextMessage;
        expect(out.text, '<@uid:u4>:u5> <@uid:u4> hi');
        expect(
          out.text,
          isNot('<@uid:u5> <@uid:u4> hi'),
          reason: 'this is what it should have been',
        );
      });
    });

    testWidgets('two unrelated names are each rewritten to their own uid', (
      tester,
    ) async {
      // The same shape as the case above, but with names that share no prefix:
      // here the replacement ranges do not overlap and the result is correct.
      final f = _withTracked(
        {0: '@Bob', 9: '@Carol'},
        {'@Bob': _bob, '@Carol': _carol},
      );

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _text('@Bob and @Carol hi'))
                as cc.TextMessage;
        expect(out.text, '<@uid:u2> and <@uid:u3> hi');
        expect(out.mentionedUsers.map((u) => u.uid).toList()..sort(), [
          'u2',
          'u3',
        ]);
      });
    });

    testWidgets('positions that no longer match are irrelevant — the text is '
        'searched, not indexed', (tester) async {
      // Markdown conversion happens before this method runs, so the stored
      // offsets are stale by the time it is called. Pinned because an
      // offset-based implementation would corrupt the bolded text.
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});
      final message = _text('**bold** then @Bob');

      await withContext(tester, (context) {
        final out = f.handlePreMessageSend(context, message) as cc.TextMessage;
        expect(out.text, '**bold** then <@uid:u2>');
      });
    });

    testWidgets('an @all mention becomes the all token with the default id', (
      tester,
    ) async {
      final f = _withTracked(
        {0: '@Notify All'},
        {'@Notify All': null},
        allMentions: {'@Notify All'},
      );
      final message = _text('@Notify All standup now');

      await withContext(tester, (context) {
        final out = f.handlePreMessageSend(context, message) as cc.TextMessage;
        expect(out.text, '<@all:all> standup now');
        expect(out.mentionedUsers, isEmpty);
      });
    });

    testWidgets('a configured mentionAllLabelId is written into the token', (
      tester,
    ) async {
      final f = _withTracked(
        {0: '@Team'},
        {'@Team': null},
        mentionAllLabelId: 'engineering',
        allMentions: {'@Team'},
      );

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _text('@Team ship it'))
                as cc.TextMessage;
        expect(out.text, '<@all:engineering> ship it');
      });
    });

    testWidgets('a tracked mention with no user and no @all flag is left '
        'alone', (tester) async {
      // The composer inserts a null placeholder when text that looks like a
      // mention is typed or pasted without a suggestion being picked. There is
      // no uid to rewrite it to, so it must ship as plain text.
      final f = _withTracked({0: '@Ghost'}, {'@Ghost': null});

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _text('@Ghost hello'))
                as cc.TextMessage;
        expect(out.text, '@Ghost hello');
        expect(out.mentionedUsers, isEmpty);
      });
    });

    testWidgets('a media caption is rewritten, not the (absent) text', (
      tester,
    ) async {
      // An unconditional `as TextMessage` here used to crash when an edited
      // media caption went through the pipeline.
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _media('@Bob look'))
                as cc.MediaMessage;
        expect(out.caption, '<@uid:u2> look');
        expect(out.mentionedUsers.map((u) => u.uid), ['u2']);
      });
    });

    testWidgets('a media message with no caption stays empty', (tester) async {
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _media(null)) as cc.MediaMessage;
        expect(out.caption, '');
      });
    });

    testWidgets('a message that is neither text nor media is returned '
        'untouched', (tester) async {
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});
      final custom = cc.CustomMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: ExtensionType.sticker,
        customData: const {'a': 1},
      );

      await withContext(tester, (context) {
        expect(f.handlePreMessageSend(context, custom), same(custom));
        // Bookkeeping is left intact, because nothing was consumed.
        expect(f.trackedMentionPositions, isNotEmpty);
      });
    });

    testWidgets('sending clears every tracking map and the tracker', (
      tester,
    ) async {
      final f = _withTracked({0: '@Bob'}, {'@Bob': _bob});
      f.mentionCount.add('u2');
      f.mentionTextToPositions['@Bob'] = [0];
      f.mentionTracker = '@Bo';

      await withContext(tester, (context) {
        f.handlePreMessageSend(context, _text('@Bob hi'));
        expect(f.mentionedUsersMap, isEmpty);
        expect(f.mentionCount, isEmpty);
        expect(f.mentionAllPositions, isEmpty);
        expect(f.trackedMentionPositions, isEmpty);
        expect(f.mentionTextToPositions, isEmpty);
        expect(f.mentionTracker, isEmpty);
      });
    });

    testWidgets('the same mention text tracked at two positions is processed '
        'once', (tester) async {
      final f = _withTracked({0: '@Bob', 9: '@Bob'}, {'@Bob': _bob});

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _text('@Bob and @Bob'))
                as cc.TextMessage;
        // Two tracked entries, one mention text, both occurrences rewritten
        // exactly once — not four overlapping replacements.
        expect(out.text, '<@uid:u2> and <@uid:u2>');
      });
    });
  });

  // ==========================================================================
  group('onMessageEdit — wire form back into the composer', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    test('a known uid token is replaced by the display name and tracked', () {
      final f = CometChatMentionsFormatter();
      controller.text = 'hi <@uid:u2> there';

      f.onMessageEdit(controller, mentionedUsers: [_bob]);

      expect(controller.text, 'hi @Bob there');
      expect(f.trackedMentionPositions, {3: '@Bob'});
      expect(f.mentionTextToPositions, {
        '@Bob': [3],
      });
      expect(f.mentionedUsersMap['@Bob']?.single?.uid, 'u2');
      expect(f.mentionCount, {'u2'});
      // The caret is parked at the end so the user can keep typing.
      expect(controller.selection.baseOffset, controller.text.length);
      expect(f.lastCursorPos, controller.text.length);
    });

    test('two mentions are tracked at their FINAL offsets, not their '
        'original ones', () {
      // Each replacement shortens the string, so the second mention's final
      // position is not where its token was. Getting this wrong makes the
      // composer highlight the wrong characters.
      final f = CometChatMentionsFormatter();
      controller.text = '<@uid:u2> and <@uid:u3>!';

      f.onMessageEdit(controller, mentionedUsers: [_bob, _carol]);

      expect(controller.text, '@Bob and @Carol!');
      expect(f.trackedMentionPositions, {0: '@Bob', 9: '@Carol'});
      expect(f.mentionCount, {'u2', 'u3'});
    });

    test('a uid that is not in the supplied list is left as the raw token', () {
      final f = CometChatMentionsFormatter();
      controller.text = 'hi <@uid:ghost>';

      f.onMessageEdit(controller, mentionedUsers: [_bob]);

      expect(controller.text, 'hi <@uid:ghost>');
      expect(f.trackedMentionPositions, isEmpty);
      expect(f.mentionCount, isEmpty);
    });

    test('an @all token expands to the configured label and is flagged as '
        'an @all', () {
      final f = CometChatMentionsFormatter(mentionAllLabel: 'Everyone');
      controller.text = '<@all:all> standup';

      f.onMessageEdit(controller);

      expect(controller.text, '@Everyone standup');
      expect(f.mentionAllPositions, {'@Everyone'});
      expect(f.mentionedUsersMap['@Everyone'], [null]);
      // An @all is nobody in particular, so it must not consume a mention slot.
      expect(f.mentionCount, isEmpty);
    });

    test('with no label and no context an @all falls back to "all"', () {
      final f = CometChatMentionsFormatter();
      controller.text = '<@all:all>';

      f.onMessageEdit(controller);

      expect(controller.text, '@all');
    });

    test('an @all token whose id is not the configured one is left raw', () {
      final f = CometChatMentionsFormatter(mentionAllLabel: 'Everyone');
      controller.text = '<@all:marketing> hi';

      f.onMessageEdit(controller);

      expect(controller.text, '<@all:marketing> hi');
      expect(f.mentionAllPositions, isEmpty);
    });

    test('an @all and a user mention are both expanded, in order', () {
      final f = CometChatMentionsFormatter(mentionAllLabel: 'All');
      controller.text = '<@all:all> ping <@uid:u2>';

      f.onMessageEdit(controller, mentionedUsers: [_bob]);

      expect(controller.text, '@All ping @Bob');
      expect(f.trackedMentionPositions, {0: '@All', 10: '@Bob'});
    });

    test('the same user mentioned twice gets two entries but one count', () {
      final f = CometChatMentionsFormatter();
      controller.text = '<@uid:u2> <@uid:u2>';

      f.onMessageEdit(controller, mentionedUsers: [_bob]);

      expect(controller.text, '@Bob @Bob');
      expect(f.mentionedUsersMap['@Bob'], hasLength(2));
      expect(f.mentionTextToPositions['@Bob'], [0, 5]);
      expect(f.mentionCount, {'u2'});
    });

    test('editing wipes the state left over from the previous message', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Stale'] = [_carol];
      f.mentionCount.add('u3');
      f.mentionAllPositions.add('@Stale');
      f.trackedMentionPositions[99] = '@Stale';
      f.mentionTextToPositions['@Stale'] = [99];
      f.mentionTracker = '@Sta';
      controller.text = 'plain text';

      f.onMessageEdit(controller);

      expect(controller.text, 'plain text');
      expect(f.mentionedUsersMap, isEmpty);
      expect(f.mentionCount, isEmpty);
      expect(f.mentionAllPositions, isEmpty);
      expect(f.trackedMentionPositions, isEmpty);
      expect(f.mentionTextToPositions, isEmpty);
      expect(f.mentionTracker, isEmpty);
    });

    testWidgets('with a context the @all label is localized', (tester) async {
      final f = CometChatMentionsFormatter();
      controller.text = '<@all:all> hi';

      await withContext(tester, (context) {
        // getAttributedText is what stores the context on the formatter.
        f.getAttributedText('', context, BubbleAlignment.left);
        f.onMessageEdit(controller);
        expect(controller.text, '@${Translations.of(context).notifyAll} hi');
      });
    });
  });

  // ==========================================================================
  group('a full round trip', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets('edit then send returns the original wire text', (
      tester,
    ) async {
      const wire = 'hey <@uid:u2> and <@uid:u3>, standup';
      final f = CometChatMentionsFormatter();
      controller.text = wire;

      f.onMessageEdit(controller, mentionedUsers: [_bob, _carol]);
      expect(controller.text, 'hey @Bob and @Carol, standup');

      await withContext(tester, (context) {
        final out =
            f.handlePreMessageSend(context, _text(controller.text))
                as cc.TextMessage;
        expect(out.text, wire);
        expect(out.mentionedUsers.map((u) => u.uid).toList()..sort(), [
          'u2',
          'u3',
        ]);
      });
    });
  });
}
