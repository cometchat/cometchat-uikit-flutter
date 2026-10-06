/// CometChatMentionsFormatter.getAttributedText — Track 3 TEST3 (ENG-38684).
///
/// `cometchat_mentions_formatter.dart` is 1,870 lines at 23.3% with no test
/// file of its own. `getAttributedText` is the heart of it: it turns the wire
/// form of a mention, `<@uid:id>` or `<@all:id>`, into the styled spans a
/// bubble actually paints. Getting it wrong shows a raw `<@uid:u2>` to a user,
/// or silently drops an @all.
///
/// The branches that had never run, and what each one means on screen:
///
///   * a uid that IS in mentionedUsers      -> "@Name"
///   * a uid that is NOT                    -> the raw marker, verbatim
///   * `<@all:all>` with default config     -> the localized notify-all label
///   * `<@all:x>` when x is not the configured id -> NO span at all, the one
///     branch that produces nothing rather than something
///   * a mention of the logged-in user      -> styled differently from others
///
///   flutter test test/shared_ui/formatters/mentions_formatter_attributed_text_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = cc.User(uid: 'me', name: 'Me');
final _bob = cc.User(uid: 'u2', name: 'Bob');
final _carol = cc.User(uid: 'u3', name: 'Carol');

/// A message carrying [mentioned], which is the list the formatter resolves
/// every `<@uid:…>` against.
cc.TextMessage _msg(String body, List<cc.User> mentioned) => cc.TextMessage(
  text: body,
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: _me,
)..mentionedUsers = mentioned;

/// Runs [body] with a real BuildContext — the formatter reads the theme, the
/// colour palette and the localizations out of it.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext) body,
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

CometChatMentionsFormatter _formatter(
  cc.BaseMessage message, {
  String? mentionAllLabelId,
  String? mentionAllLabel,
}) => CometChatMentionsFormatter(
  message: message,
  mentionAllLabelId: mentionAllLabelId,
  mentionAllLabel: mentionAllLabel,
);

/// Records the openChat events the default mention tap raises.
class _OpenChatSpy with CometChatUIEventListener {
  final List<cc.User?> opened = [];

  @override
  void openChat(cc.User? user, cc.Group? group) => opened.add(user);
}

void main() {
  setUp(() {
    // The "is this me" branch reads the UIKit's static.
    CometChatUIKit.loggedInUser = _me;
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
  });

  // ==========================================================================
  group('getAttributedText — user mentions', () {
    testWidgets('a known uid resolves to the display name', (tester) async {
      final message = _msg('hi <@uid:u2> there', [_bob]);
      await withContext(tester, (context) {
        final spans = _formatter(message).getAttributedText(
          'hi <@uid:u2> there',
          context,
          BubbleAlignment.left,
        );

        expect(spans, hasLength(1));
        expect(spans.single.underlyingText, '@Bob');
        // The span has to point at the marker it replaces, or the bubble
        // paints the highlight over the wrong characters.
        expect(spans.single.start, 'hi '.length);
        expect(spans.single.end, 'hi <@uid:u2>'.length);
      });
    });

    testWidgets('an unknown uid is left as the raw marker, not blanked', (
      tester,
    ) async {
      // Carol is mentioned in the text but absent from mentionedUsers, which
      // is what a stale or partial payload looks like.
      final message = _msg('hi <@uid:u3>', [_bob]);
      await withContext(tester, (context) {
        final spans = _formatter(
          message,
        ).getAttributedText('hi <@uid:u3>', context, BubbleAlignment.left);

        expect(spans, hasLength(1));
        expect(spans.single.underlyingText, '<@uid:u3>');
      });
    });

    testWidgets('several mentions each get their own span, in order', (
      tester,
    ) async {
      const text = '<@uid:u2> and <@uid:u3> both';
      final message = _msg(text, [_bob, _carol]);
      await withContext(tester, (context) {
        final spans = _formatter(
          message,
        ).getAttributedText(text, context, BubbleAlignment.left);

        expect(spans, hasLength(2));
        expect(spans[0].underlyingText, '@Bob');
        expect(spans[1].underlyingText, '@Carol');
        expect(spans[0].start, lessThan(spans[1].start));
      });
    });

    testWidgets('text with no mention produces no spans', (tester) async {
      final message = _msg('nothing to see', const []);
      await withContext(tester, (context) {
        expect(
          _formatter(
            message,
          ).getAttributedText('nothing to see', context, BubbleAlignment.left),
          isEmpty,
        );
      });
    });

    testWidgets('a mention of the logged-in user is styled differently', (
      tester,
    ) async {
      const text = '<@uid:me> and <@uid:u2>';
      final message = _msg(text, [_me, _bob]);
      await withContext(tester, (context) {
        final spans = _formatter(
          message,
        ).getAttributedText(text, context, BubbleAlignment.left);

        expect(spans, hasLength(2));
        // Being mentioned yourself is the whole point of the feature; it must
        // not render identically to someone else being mentioned.
        expect(
          spans[0].style,
          isNot(spans[1].style),
          reason: 'self-mention should not look like any other mention',
        );
      });
    });
  });

  // ==========================================================================
  group('getAttributedText — @all', () {
    testWidgets('the default id formats with the localized notify-all label', (
      tester,
    ) async {
      final message = _msg('<@all:all> heads up', const []);
      await withContext(tester, (context) {
        final spans = _formatter(message).getAttributedText(
          '<@all:all> heads up',
          context,
          BubbleAlignment.left,
        );

        expect(spans, hasLength(1));
        expect(
          spans.single.underlyingText,
          '@${Translations.of(context).notifyAll}',
        );
      });
    });

    testWidgets('a non-matching @all id produces no span at all', (
      tester,
    ) async {
      // The only branch in the function that deliberately emits nothing. If it
      // ever starts emitting, an unconfigured @all would render as a mention.
      final message = _msg('<@all:engineering> heads up', const []);
      await withContext(tester, (context) {
        expect(
          _formatter(message).getAttributedText(
            '<@all:engineering> heads up',
            context,
            BubbleAlignment.left,
          ),
          isEmpty,
        );
      });
    });

    testWidgets('a configured mentionAllLabelId makes that id match', (
      tester,
    ) async {
      final message = _msg('<@all:engineering> heads up', const []);
      await withContext(tester, (context) {
        final spans = _formatter(message, mentionAllLabelId: 'engineering')
            .getAttributedText(
              '<@all:engineering> heads up',
              context,
              BubbleAlignment.left,
            );

        expect(spans, hasLength(1));
        expect(
          spans.single.underlyingText,
          '@${Translations.of(context).notifyAll}',
        );
      });
    });

    testWidgets('a configured mentionAllLabel is what the @all mention shows', (
      tester,
    ) async {
      // It used to be ignored here: the bubble and the conversation preview
      // always showed the localized "Notify All", whatever was configured.
      final message = _msg('<@all:all> heads up', const []);
      await withContext(tester, (context) {
        final spans = _formatter(message, mentionAllLabel: 'Everyone')
            .getAttributedText(
              '<@all:all> heads up',
              context,
              BubbleAlignment.left,
            );

        expect(spans, hasLength(1));
        expect(spans.single.underlyingText, '@Everyone');
      });
    });

    testWidgets('configuring an id stops the default "all" from matching', (
      tester,
    ) async {
      final message = _msg('<@all:all> heads up', const []);
      await withContext(tester, (context) {
        expect(
          _formatter(
            message,
            mentionAllLabelId: 'engineering',
          ).getAttributedText(
            '<@all:all> heads up',
            context,
            BubbleAlignment.left,
          ),
          isEmpty,
        );
      });
    });
  });

  // ==========================================================================
  group('getAttributedText — tapping a mention', () {
    late _OpenChatSpy spy;

    setUp(() {
      spy = _OpenChatSpy();
      CometChatUIEvents.addUiListener('mentions-tap-test', spy);
    });

    tearDown(() => CometChatUIEvents.removeUiListener('mentions-tap-test'));

    testWidgets('an onMentionTap callback receives the tapped text, the user '
        'and the message', (tester) async {
      final message = _msg('hi <@uid:u2>', [_bob]);
      String? seenText;
      cc.User? seenUser;
      cc.BaseMessage? seenMessage;

      await withContext(tester, (context) {
        final formatter = CometChatMentionsFormatter(message: message)
          ..onMentionTap = (text, user, {message}) {
            seenText = text;
            seenUser = user;
            seenMessage = message;
          };
        formatter
            .getAttributedText('hi <@uid:u2>', context, BubbleAlignment.left)
            .single
            .onTap!('@Bob');
      });

      expect(seenText, '@Bob');
      expect(seenUser?.uid, 'u2');
      expect(seenMessage, same(message));
      expect(spy.opened, isEmpty, reason: 'the callback replaces the default');
    });

    testWidgets('with no callback the tap raises the openChat UI event so the '
        'host app can navigate', (tester) async {
      final message = _msg('hi <@uid:u2>', [_bob]);

      await withContext(tester, (context) {
        _formatter(message)
            .getAttributedText('hi <@uid:u2>', context, BubbleAlignment.left)
            .single
            .onTap!('@Bob');
      });

      expect(spy.opened.map((u) => u?.uid), ['u2']);
    });

    testWidgets('tapping an unresolved mention does nothing', (tester) async {
      final message = _msg('hi <@uid:ghost>', [_bob]);

      await withContext(tester, (context) {
        _formatter(message)
            .getAttributedText('hi <@uid:ghost>', context, BubbleAlignment.left)
            .single
            .onTap!('<@uid:ghost>');
      });

      expect(spy.opened, isEmpty);
    });

    testWidgets('tapping an @all does nothing — it is not a person', (
      tester,
    ) async {
      final message = _msg('<@all:all> hi', const []);

      await withContext(tester, (context) {
        _formatter(message)
            .getAttributedText('<@all:all> hi', context, BubbleAlignment.left)
            .single
            .onTap!('@Notify All');
      });

      expect(spy.opened, isEmpty);
    });
  });

  // ==========================================================================
  group('static helpers', () {
    test('getTextWithMentions swaps every marker for its display name', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions('hi <@uid:u2>', [_bob]),
        'hi @Bob',
      );
      expect(
        CometChatMentionsFormatter.getTextWithMentions('<@uid:u2> <@uid:u3>', [
          _bob,
          _carol,
        ]),
        '@Bob @Carol',
      );
    });

    test('getTextWithMentions leaves text alone when nobody is mentioned', () {
      expect(
        CometChatMentionsFormatter.getTextWithMentions(
          'hi <@uid:u2>',
          const [],
        ),
        'hi <@uid:u2>',
      );
    });

    test('getMentionedUserName finds the name, or returns empty', () {
      final message = _msg('hi <@uid:u2>', [_bob]);
      expect(
        CometChatMentionsFormatter.getMentionedUserName('u2', message),
        'Bob',
      );
      expect(
        CometChatMentionsFormatter.getMentionedUserName('nobody', message),
        '',
      );
    });
  });
}
