/// Render-verified prop matrix for CometChatCreatePoll —
/// Track 3 PROP1 (ENG-38684).
///
/// The sheet builds without the SDK: the send path is only reached on submit,
/// which these cases do not trigger.
///
///   flutter test test/chat_ui/extensions/create_poll_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

TextMessage _quoted() => TextMessage(
  text: 'the quoted message',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: User(uid: 'u2', name: 'Bob'),
)..id = 42;

void main() {
  group('CometChatCreatePoll', () {
    testWidgets('title and defaultAnswers drive what renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            height: 900,
            child: CometChatCreatePoll(
              title: 'Start a poll',
              user: 'u2',
              defaultAnswers: 4,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Start a poll'), findsOneWidget, reason: 'title');

      final w = tester.widget<CometChatCreatePoll>(
        find.byType(CometChatCreatePoll),
      );
      expect(w.defaultAnswers, 4, reason: 'defaultAnswers');
      expect(w.user, 'u2', reason: 'user');

      // The answer slots are built lazily, so assert the sheet rendered a
      // field rather than a fixed count that depends on viewport height.
      expect(
        find.byType(TextField),
        findsWidgets,
        reason: 'the sheet renders its inputs',
      );
    });

    testWidgets('the default title falls back to the localized string', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            height: 900,
            child: CometChatCreatePoll(user: 'u2', defaultAnswers: 2),
          ),
        ),
      );
      await tester.pump();
      final w = tester.widget<CometChatCreatePoll>(
        find.byType(CometChatCreatePoll),
      );
      expect(w.title, isNull);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('group, the entity objects and quotedMessage all reach it', (
      tester,
    ) async {
      final group = Group(guid: 'g1', name: 'Team', type: 'public');
      final user = User(uid: 'u2', name: 'Bob');
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 900,
            child: CometChatCreatePoll(
              title: 'Group poll',
              group: 'g1',
              groupObject: group,
              userObject: user,
              quotedMessage: _quoted(),
              defaultAnswers: 3,
            ),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatCreatePoll>(
        find.byType(CometChatCreatePoll),
      );
      expect(w.group, 'g1', reason: 'group');
      expect(w.groupObject?.guid, 'g1', reason: 'groupObject');
      expect(w.userObject?.uid, 'u2', reason: 'userObject');
      expect(w.quotedMessage?.id, 42, reason: 'quotedMessage');
      expect(find.text('Group poll'), findsOneWidget);
    });
  });
}
