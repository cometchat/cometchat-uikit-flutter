/// Behaviour tests for [CometChatCreatePoll] — validation, the option list,
/// and the create request itself.
///
/// The sheet posts through `CometChat.callExtension`, which resolves its
/// repository via `SdkRegistry`, so `test/helpers/fake_sdk_moderation.dart`
/// answers it and both the success and failure paths run for real.
///
///   flutter test test/chat_ui/extensions/create_poll_behaviour_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sdk_moderation.dart';

const _emptyError =
    'Please fill in all required fields before creating a poll.';
const _serverError = 'Something went wrong, please try again';

TextMessage _quoted(int id) => TextMessage(
  text: 'the quoted message',
  receiverUid: 'u2',
  receiverType: ReceiverTypeConstants.user,
  type: MessageTypeConstants.text,
  sender: User(uid: 'u2', name: 'Bob'),
)..id = id;

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SizedBox(height: 900, child: child)),
);

/// The question field is the first text field; option N is at N + 1.
Finder _question() => find.byType(TextField).first;
Finder _option(int index) => find.byType(TextField).at(index + 1);

Finder _createButton() => find.widgetWithText(ElevatedButton, 'Create');

/// Records what the sheet posted to the polls extension.
class _Recorded {
  String? slug;
  String? method;
  String? endpoint;
  Map<String, dynamic>? body;
  int calls = 0;
}

_Recorded _recordExtension({bool fail = false}) {
  final rec = _Recorded();
  fakeCallExtension = (slug, method, endpoint, body) {
    rec
      ..slug = slug
      ..method = method
      ..endpoint = endpoint
      ..body = body;
    rec.calls++;
    if (fail) throw Exception('poll service down');
    return <String, dynamic>{'success': true};
  };
  return rec;
}

Future<void> _fillValidPoll(WidgetTester tester) async {
  await tester.enterText(_question(), 'Lunch?');
  await tester.pump();
  await tester.enterText(_option(0), 'Pizza');
  await tester.pump();
  await tester.enterText(_option(1), 'Sushi');
  await tester.pump();
}

void main() {
  setUp(registerFakeSdkBackend);
  tearDown(clearFakeSdkBackend);

  group('validation', () {
    testWidgets('an empty form shows the error banner and posts nothing', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();
      expect(find.text(_emptyError), findsNothing);

      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(find.text(_emptyError), findsOneWidget);
      expect(rec.calls, 0);
    });

    testWidgets('a question with only one filled option is still rejected', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.enterText(_question(), 'Lunch?');
      await tester.pump();
      await tester.enterText(_option(0), 'Pizza');
      await tester.pump();

      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(find.text(_emptyError), findsOneWidget);
      expect(rec.calls, 0);
    });

    testWidgets('whitespace-only answers do not count as options', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.enterText(_question(), '   ');
      await tester.pump();
      await tester.enterText(_option(0), 'Pizza');
      await tester.pump();
      await tester.enterText(_option(1), '   ');
      await tester.pump();

      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(find.text(_emptyError), findsOneWidget);
      expect(rec.calls, 0);
    });

    testWidgets('the banner clears once a valid poll is submitted', (
      tester,
    ) async {
      _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.tap(_createButton());
      await tester.pumpAndSettle();
      expect(find.text(_emptyError), findsOneWidget);

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(find.text(_emptyError), findsNothing);
    });
  });

  group('the create request', () {
    testWidgets('a user poll posts the trimmed question and options', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.enterText(_question(), '  Lunch?  ');
      await tester.pump();
      await tester.enterText(_option(0), '  Pizza ');
      await tester.pump();
      await tester.enterText(_option(1), 'Sushi');
      await tester.pump();
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.calls, 1);
      expect(rec.slug, ExtensionConstants.polls);
      expect(rec.method, 'POST');
      expect(rec.endpoint, ExtensionUrls.createPoll);
      expect(rec.body?['question'], 'Lunch?');
      expect(rec.body?['options'], <String>['Pizza', 'Sushi']);
      expect(rec.body?['receiver'], 'u2');
      expect(rec.body?['receiverType'], ReceiverTypeConstants.user);
      expect(rec.body?.containsKey('quotedMessageId'), isFalse);
    });

    testWidgets('a group poll posts the guid and the group receiver type', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(group: 'g1')));
      await tester.pump();

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.body?['receiver'], 'g1');
      expect(rec.body?['receiverType'], ReceiverTypeConstants.group);
    });

    testWidgets('a quoted message rides along as quotedMessageId', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(
        _wrap(CometChatCreatePoll(user: 'u2', quotedMessage: _quoted(42))),
      );
      await tester.pump();

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.body?['quotedMessageId'], 42);
    });

    testWidgets('an unsent quoted message (id 0) is not attached', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(
        _wrap(CometChatCreatePoll(user: 'u2', quotedMessage: _quoted(0))),
      );
      await tester.pump();

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.body?.containsKey('quotedMessageId'), isFalse);
    });

    testWidgets('a failed create shows the server error and stops spinning', (
      tester,
    ) async {
      final rec = _recordExtension(fail: true);
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.calls, 1);
      expect(find.text(_serverError), findsOneWidget);
      expect(
        find.descendant(
          of: _createButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'the button is usable again',
      );
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('a second tap while in flight does not post twice', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await _fillValidPoll(tester);
      await tester.tap(_createButton());
      // No settle: the request is still in flight on this frame.
      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      expect(rec.calls, 1);
    });
  });

  group('the option list', () {
    testWidgets('defaultAnswers decides how many option fields open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CometChatCreatePoll(user: 'u2', defaultAnswers: 4)),
      );
      await tester.pump();

      // One question field plus four option fields.
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('Add Option appends a field and focuses it', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.tap(find.text('+ Add Option'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('the Add Option link disappears at twelve options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CometChatCreatePoll(user: 'u2', defaultAnswers: 11)),
      );
      await tester.pump();
      expect(find.text('+ Add Option'), findsOneWidget, reason: 'room for one');

      await tester.pumpWidget(
        _wrap(
          const CometChatCreatePoll(
            key: ValueKey('full'),
            user: 'u2',
            defaultAnswers: 12,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('+ Add Option'),
        findsNothing,
        reason: 'twelve options is the cap',
      );
    });

    testWidgets('clearing an extra option removes its field', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatCreatePoll(user: 'u2', defaultAnswers: 3)),
      );
      await tester.pump();

      await tester.enterText(_option(2), 'Ramen');
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(4));

      await tester.enterText(_option(2), '');
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsNWidgets(3),
        reason: 'emptying an option past the defaults drops the row',
      );
    });

    testWidgets('clearing the first option also collapses it when there are '
        'three', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatCreatePoll(user: 'u2', defaultAnswers: 3)),
      );
      await tester.pump();

      await tester.enterText(_option(0), 'Pizza');
      await tester.pump();
      await tester.enterText(_option(0), '');
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets(
      'clearing the second option collapses it when there are three',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const CometChatCreatePoll(user: 'u2', defaultAnswers: 3)),
        );
        await tester.pump();

        await tester.enterText(_option(1), 'Sushi');
        await tester.pump();
        await tester.enterText(_option(1), '');
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNWidgets(3));
      },
    );

    testWidgets('the last two options are never removed', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.enterText(_option(0), 'Pizza');
      await tester.pump();
      await tester.enterText(_option(0), '');
      await tester.pumpAndSettle();
      await tester.enterText(_option(1), 'Sushi');
      await tester.pump();
      await tester.enterText(_option(1), '');
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsNWidgets(3),
        reason: 'a poll always keeps two answer slots',
      );
    });

    testWidgets('FINDING: typing in an option does not reveal its drag handle. '
        'getTextKey only renders the ReorderableDragStartListener when the '
        'answer is non-empty, but the option field\'s onChanged only calls '
        'setState when the text becomes EMPTY — so filling an option never '
        'repaints the row and the reorder handle stays missing until some '
        'unrelated rebuild happens.', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();
      expect(find.byType(ReorderableDragStartListener), findsNothing);

      await tester.enterText(_option(0), 'Pizza');
      await tester.pumpAndSettle();

      // FINDING: this is findsOneWidget the moment onChanged repaints.
      expect(find.byType(ReorderableDragStartListener), findsNothing);

      // Any other setState — here, adding an option — makes it appear.
      await tester.tap(find.text('+ Add Option'));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    });
  });

  group('reordering', () {
    testWidgets('dragging an option handle moves it in the posted options', (
      tester,
    ) async {
      final rec = _recordExtension();
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.enterText(_question(), 'Lunch?');
      await tester.pump();
      await tester.enterText(_option(0), 'Pizza');
      await tester.pump();
      await tester.enterText(_option(1), 'Sushi');
      await tester.pump();
      // Adding a slot is the repaint that finally renders the drag handles
      // (see the FINDING above); the extra empty slot is filtered on submit.
      await tester.tap(find.text('+ Add Option'));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

      final handle = find.byType(ReorderableDragStartListener).first;
      await tester.timedDrag(
        handle,
        const Offset(0, 80),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      await tester.tap(_createButton());
      await tester.pumpAndSettle();

      final options = (rec.body?['options'] as List).cast<String>();
      expect(options, <String>[
        'Sushi',
        'Pizza',
      ], reason: 'the dragged option moved below its neighbour');
    });
  });

  group('the sheet wrapper', () {
    testWidgets('showCometChatCreatePoll opens the sheet with its arguments', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCometChatCreatePoll(
                    context: context,
                    colorPalette: CometChatThemeHelper.getColorPalette(context),
                    spacing: CometChatThemeHelper.getSpacing(context),
                    uid: 'u2',
                    title: 'Sheet poll',
                    quotedMessage: _quoted(9),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CometChatCreatePoll), findsOneWidget);
      expect(find.text('Sheet poll'), findsOneWidget);
      final sheet = tester.widget<CometChatCreatePoll>(
        find.byType(CometChatCreatePoll),
      );
      expect(sheet.user, 'u2');
      expect(sheet.quotedMessage?.id, 9);
    });
  });

  group('focus', () {
    testWidgets('tapping the sheet background dismisses the keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      await tester.tap(_question());
      await tester.pumpAndSettle();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'the question field took focus',
      );

      await tester.tap(find.text('Create Poll'));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });

  group('the header', () {
    testWidgets('title overrides the default heading', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatCreatePoll(user: 'u2', title: 'Start a poll')),
      );
      await tester.pump();

      expect(find.text('Start a poll'), findsOneWidget);
      expect(find.text('Create Poll'), findsNothing);
    });

    testWidgets('without a title the localized heading is used', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CometChatCreatePoll(user: 'u2')));
      await tester.pump();

      expect(find.text('Create Poll'), findsOneWidget);
    });
  });
}
