/// Behaviour tests for [CometChatFlagMessageDialog] and its style class.
///
/// The dialog fetches its reasons through `CometChat.getFlagReasons` and
/// submits through `CometChat.flagMessage`; both resolve their repository via
/// `SdkRegistry`, so `test/helpers/fake_sdk_moderation.dart` answers them and
/// the real dialog runs its load, select, submit and failure paths.
///
///   flutter test test/chat_ui/message_list/flag_message_dialog_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_flag_message_dialog.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sdk_moderation.dart';

FlagReason _reason(String id, {String name = ''}) =>
    FlagReason(id: id, name: name);

TextMessage _message() => TextMessage(
  id: 77,
  text: 'the reported message',
  sender: User(uid: 'u2', name: 'Bob'),
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
);

/// Opens the dialog on a route so Navigator.pop has something to pop, and
/// hands back a getter for whatever the dialog returned.
Future<Object? Function()> _openDialog(
  WidgetTester tester, {
  CometChatFlagMessageStyle? style,
  String Function(String)? flagReasonLocalizer,
  bool? hideFlagRemarkField,
}) async {
  Object? result;
  var closed = false;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showDialog<Object?>(
                  context: context,
                  builder: (_) => CometChatFlagMessageDialog(
                    message: _message(),
                    style: style,
                    flagReasonLocalizer: flagReasonLocalizer,
                    hideFlagRemarkField: hideFlagRemarkField,
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => closed ? result : #stillOpen;
}

void main() {
  setUp(registerFakeSdkBackend);
  tearDown(clearFakeSdkBackend);

  group('reason list', () {
    testWidgets('known reason ids render their localized label', (
      tester,
    ) async {
      fakeFlagReasons = () => [
        _reason('spam', name: 'Spam raw'),
        _reason('sexual', name: 'Sexual raw'),
        _reason('harassment', name: 'Harassment raw'),
      ];
      await _openDialog(tester);

      // The dialog prefers its own translations over the server's names.
      expect(find.text('Spam raw'), findsNothing);
      expect(find.byType(GestureDetector), findsWidgets);
      final chipLabels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(chipLabels, contains('Spam'));
      expect(chipLabels, contains('Sexual'));
      expect(chipLabels, contains('Harassment'));
    });

    testWidgets('an unknown reason id falls back to the server name', (
      tester,
    ) async {
      fakeFlagReasons = () => [_reason('violence', name: 'Violent content')];
      await _openDialog(tester);

      expect(find.text('Violent content'), findsOneWidget);
    });

    testWidgets(
      'FINDING: a reason with no translation and no server name renders an '
      'empty chip. _getLocalizedReason falls back to reason.name, and nothing '
      'guards against an empty one, so the user sees a tappable blank pill '
      'with an empty accessibility label.',
      (tester) async {
        fakeFlagReasons = () => [_reason('mystery')];
        await _openDialog(tester);

        // FINDING: the chip is there, selectable, and says nothing.
        expect(find.text(''), findsWidgets);
        final blank = find.bySemanticsLabel('');
        expect(blank, findsWidgets);
      },
    );

    testWidgets('flagReasonLocalizer overrides every label', (tester) async {
      fakeFlagReasons = () => [
        _reason('spam', name: 'Spam raw'),
        _reason('violence', name: 'Violent content'),
      ];
      await _openDialog(tester, flagReasonLocalizer: (id) => 'reason:$id');

      expect(find.text('reason:spam'), findsOneWidget);
      expect(find.text('reason:violence'), findsOneWidget);
      expect(find.text('Spam'), findsNothing);
    });

    testWidgets('a failed fetch shows the error line and no chips', (
      tester,
    ) async {
      fakeFlagReasons = () => throw Exception('offline');
      await _openDialog(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('selection and the report button', () {
    Finder reportButton() => find.widgetWithText(ElevatedButton, 'Report');

    testWidgets('report is disabled until a reason is picked', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      await _openDialog(tester);

      expect(
        tester.widget<ElevatedButton>(reportButton()).onPressed,
        isNull,
        reason: 'nothing selected yet',
      );

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(reportButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('tapping the selected reason again clears the selection', (
      tester,
    ) async {
      fakeFlagReasons = () => [_reason('spam'), _reason('sexual')];
      await _openDialog(tester);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(reportButton()).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(reportButton()).onPressed, isNull);
    });

    testWidgets('picking a second reason moves the selection', (tester) async {
      fakeFlagReasons = () => [_reason('spam'), _reason('sexual')];
      await _openDialog(tester);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sexual'));
      await tester.pumpAndSettle();

      int? submittedFor;
      String? sentReason;
      fakeFlagMessage = (id, detail) {
        submittedFor = id;
        sentReason = detail.reasonId;
        return 'ok';
      };
      await tester.tap(reportButton());
      await tester.pumpAndSettle();

      expect(submittedFor, 77);
      expect(sentReason, 'sexual', reason: 'the last tap wins');
    });
  });

  group('submitting', () {
    testWidgets('a successful report closes the dialog with true', (
      tester,
    ) async {
      fakeFlagReasons = () => [_reason('spam')];
      final result = await _openDialog(tester);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Report'));
      await tester.pumpAndSettle();

      expect(result(), isTrue);
      expect(find.byType(CometChatFlagMessageDialog), findsNothing);
    });

    testWidgets('a typed remark travels with the report', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      FlagDetail? sent;
      fakeFlagMessage = (id, detail) {
        sent = detail;
        return 'ok';
      };
      await _openDialog(tester);

      await tester.enterText(find.byType(TextField), 'they keep messaging me');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Report'));
      await tester.pumpAndSettle();

      expect(sent?.reasonId, 'spam');
      expect(sent?.remark, 'they keep messaging me');
    });

    testWidgets('an empty remark is sent as null, not as an empty string', (
      tester,
    ) async {
      fakeFlagReasons = () => [_reason('spam')];
      FlagDetail? sent;
      fakeFlagMessage = (id, detail) {
        sent = detail;
        return 'ok';
      };
      await _openDialog(tester);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Report'));
      await tester.pumpAndSettle();

      expect(sent?.remark, isNull);
    });

    testWidgets('a failed report keeps the dialog open and shows the error', (
      tester,
    ) async {
      fakeFlagReasons = () => [_reason('spam')];
      fakeFlagMessage = (_, _) => throw Exception('server said no');
      final result = await _openDialog(tester);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Report'));
      await tester.pumpAndSettle();

      expect(result(), #stillOpen);
      expect(find.byType(CometChatFlagMessageDialog), findsOneWidget);
      // The dialog prefers the server's own detail over the generic fallback.
      expect(find.textContaining('server said no'), findsOneWidget);
      // The button is usable again so the user can retry.
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Report'),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('dismissing', () {
    testWidgets('cancel closes the dialog with false', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      final result = await _openDialog(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(result(), isFalse);
    });

    testWidgets('the close icon closes the dialog with false', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      final result = await _openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result(), isFalse);
    });
  });

  group('the remark field', () {
    testWidgets('is shown by default with its optional hint', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      await _openDialog(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('(optional)'), findsOneWidget);
    });

    testWidgets('hideFlagRemarkField removes it entirely', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      await _openDialog(tester, hideFlagRemarkField: true);

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('(optional)'), findsNothing);
    });
  });

  group('style', () {
    testWidgets('a supplied style reaches the dialog surface', (tester) async {
      fakeFlagReasons = () => [_reason('spam')];
      await _openDialog(
        tester,
        style: const CometChatFlagMessageStyle(
          backgroundColor: Color(0xFF102030),
          borderRadius: BorderRadius.all(Radius.circular(3)),
          titleTextStyle: TextStyle(fontSize: 31),
        ),
      );

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFF102030));
      expect(
        (dialog.shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(3)),
      );
      expect(
        tester.widget<Text>(find.text('Report a message')).style?.fontSize,
        31,
      );
    });

    test('copyWith replaces only the fields it is given', () {
      const base = CometChatFlagMessageStyle(
        backgroundColor: Color(0xFF000001),
        titleTextColor: Color(0xFF000002),
        chipBorderRadius: BorderRadius.zero,
        errorTextColor: Color(0xFF000003),
      );

      final copy = base.copyWith(titleTextColor: const Color(0xFF0000AA));

      expect(copy.titleTextColor, const Color(0xFF0000AA));
      expect(copy.backgroundColor, base.backgroundColor, reason: 'untouched');
      expect(copy.errorTextColor, base.errorTextColor, reason: 'untouched');
      expect(copy.chipBorderRadius, BorderRadius.zero);
    });

    test('merge lets the other style win where it has a value', () {
      const base = CometChatFlagMessageStyle(
        backgroundColor: Color(0xFF000001),
        cancelButtonTextColor: Color(0xFF000002),
        reportButtonTextColor: Color(0xFF000003),
      );
      const other = CometChatFlagMessageStyle(
        backgroundColor: Color(0xFF0000FF),
        chipActiveTitleTextColor: Color(0xFF00FF00),
      );

      final merged = base.merge(other);

      expect(merged.backgroundColor, const Color(0xFF0000FF), reason: 'other');
      expect(merged.chipActiveTitleTextColor, const Color(0xFF00FF00));
      expect(
        merged.cancelButtonTextColor,
        const Color(0xFF000002),
        reason: 'kept: other has no value for it',
      );
      expect(merged.reportButtonTextColor, const Color(0xFF000003));
    });

    test('merge with null answers the receiver unchanged', () {
      const base = CometChatFlagMessageStyle(
        backgroundColor: Color(0xFF000001),
      );
      expect(identical(base.merge(null), base), isTrue);
    });

    test('lerp is a no-op — the style never animates between themes', () {
      const a = CometChatFlagMessageStyle(backgroundColor: Color(0xFF000001));
      const b = CometChatFlagMessageStyle(backgroundColor: Color(0xFF0000FF));
      expect(identical(a.lerp(b, 0.5), a), isTrue);
    });

    testWidgets('of(context) answers a blank style, not the theme extension', (
      tester,
    ) async {
      late CometChatFlagMessageStyle resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              CometChatFlagMessageStyle(backgroundColor: Color(0xFF123456)),
            ],
          ),
          home: Builder(
            builder: (context) {
              resolved = CometChatFlagMessageStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.backgroundColor, isNull);
    });
  });
}
