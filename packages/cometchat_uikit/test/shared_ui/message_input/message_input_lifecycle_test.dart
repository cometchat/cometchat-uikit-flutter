/// [CometChatMessageInput]'s lifecycle and paste behaviour — the parts the
/// prop matrix doesn't reach: swapping the text controller underneath a live
/// field, pushing new `text` in, the left auxiliary-button slot, and the
/// image-paste entry it adds to the selection toolbar.
///
///   flutter test test/shared_ui/message_input/message_input_lifecycle_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  group('controller and text updates', () {
    testWidgets('swapping in a new controller re-seeds the field', (
      tester,
    ) async {
      final first = TextEditingController(text: 'FIRST');
      final second = TextEditingController(text: 'SECOND');
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        _wrap(CometChatMessageInput(textEditingController: first)),
      );
      await _settle(tester);
      expect(find.text('FIRST'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(CometChatMessageInput(textEditingController: second)),
      );
      await _settle(tester);
      expect(find.text('SECOND'), findsOneWidget);
      expect(find.text('FIRST'), findsNothing);
      // The host still owns both controllers — neither was disposed under it.
      expect(() => first.text, returnsNormally);
    });

    testWidgets('dropping back to no controller keeps the field alive', (
      tester,
    ) async {
      final owned = TextEditingController(text: 'OWNED');
      addTearDown(owned.dispose);

      await tester.pumpWidget(
        _wrap(CometChatMessageInput(textEditingController: owned)),
      );
      await _settle(tester);
      await tester.pumpWidget(
        _wrap(const CometChatMessageInput(text: 'INLINE')),
      );
      await _settle(tester);
      expect(find.text('INLINE'), findsOneWidget);
    });

    testWidgets('handing a controller to a field that made its own swaps it'
        ' over', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatMessageInput(text: 'OWN')));
      await _settle(tester);
      expect(find.text('OWN'), findsOneWidget);

      final host = TextEditingController(text: 'HOSTED');
      addTearDown(host.dispose);
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(textEditingController: host)),
      );
      await _settle(tester);

      expect(find.text('HOSTED'), findsOneWidget);
      // The field's own controller was disposed, not the host's.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(host),
      );
      expect(() => host.text, returnsNormally);
    });

    testWidgets('new text pushed in replaces the content and parks the caret'
        ' at the end', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatMessageInput(text: 'one')));
      await _settle(tester);

      await tester.pumpWidget(
        _wrap(const CometChatMessageInput(text: 'one two three')),
      );
      await _settle(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'one two three');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 13),
        reason: 'the caret follows the inserted text',
      );
    });

    testWidgets('a rebuild with the same text leaves the caret alone', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CometChatMessageInput(text: 'abcd')));
      await _settle(tester);

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      controller.selection = const TextSelection.collapsed(offset: 1);

      await tester.pumpWidget(_wrap(const CometChatMessageInput(text: 'abcd')));
      await _settle(tester);
      expect(controller.selection.baseOffset, 1);
    });

    testWidgets('a null text push leaves the field as it was', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatMessageInput(text: 'kept')));
      await _settle(tester);
      await tester.pumpWidget(_wrap(const CometChatMessageInput()));
      await _settle(tester);
      expect(find.text('kept'), findsOneWidget);
    });
  });

  group('auxiliary button alignment', () {
    const aux = Key('aux');
    const primary = Key('primary');

    Widget input(AuxiliaryButtonsAlignment alignment, {bool? hideBottom}) =>
        _wrap(
          CometChatMessageInput(
            auxiliaryButtonsAlignment: alignment,
            hideBottomView: hideBottom,
            auxiliaryButtonView: const SizedBox(key: aux, width: 10),
            primaryButtonView: const SizedBox(key: primary, width: 10),
          ),
        );

    testWidgets('left alignment puts the auxiliary view before the field', (
      tester,
    ) async {
      await tester.pumpWidget(input(AuxiliaryButtonsAlignment.left));
      await _settle(tester);

      expect(find.byKey(aux), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(aux)).dx,
        lessThan(tester.getCenter(find.byType(TextField)).dx),
      );
    });

    testWidgets('right alignment puts it after the field', (tester) async {
      await tester.pumpWidget(input(AuxiliaryButtonsAlignment.right));
      await _settle(tester);
      expect(
        tester.getCenter(find.byKey(aux)).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx),
      );
    });

    testWidgets('hideBottomView drops the left auxiliary view', (tester) async {
      await tester.pumpWidget(
        input(AuxiliaryButtonsAlignment.left, hideBottom: true),
      );
      await _settle(tester);
      expect(find.byKey(aux), findsNothing);
    });
  });

  group('image paste in the selection toolbar', () {
    /// Answers `Clipboard.hasStrings` — Flutter only offers a Paste button when
    /// the clipboard holds text.
    void mockClipboard(WidgetTester tester, {required bool hasText}) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.hasStrings') {
            return <String, dynamic>{'value': hasText};
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': hasText ? 'CLIP' : ''};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Future<void> openToolbar(
      WidgetTester tester, {
      required Future<bool> Function()? onPasteImage,
    }) async {
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(text: 'hello', onPasteImage: onPasteImage)),
      );
      await _settle(tester);
      await tester.tap(find.byType(TextField));
      await _settle(tester);
      // Long-pressing a word raises the selection toolbar.
      await tester.longPress(find.byType(EditableText));
      await _settle(tester);
    }

    testWidgets('with an image-only clipboard a Paste entry is added anyway', (
      tester,
    ) async {
      mockClipboard(tester, hasText: false);
      var pasteImageCalls = 0;
      await openToolbar(
        tester,
        onPasteImage: () async {
          pasteImageCalls++;
          return true;
        },
      );

      final paste = find.widgetWithText(TextButton, 'Paste');
      expect(
        paste,
        findsOneWidget,
        reason: 'Flutter offers none for an image-only clipboard; we add ours',
      );

      await tester.tap(paste);
      await _settle(tester);
      expect(pasteImageCalls, 1);
      // The image was staged, so the text was left alone.
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('an unhandled paste falls back to the normal text paste', (
      tester,
    ) async {
      mockClipboard(tester, hasText: false);
      var pasteImageCalls = 0;
      await openToolbar(
        tester,
        onPasteImage: () async {
          pasteImageCalls++;
          return false;
        },
      );

      await tester.tap(find.widgetWithText(TextButton, 'Paste'));
      await _settle(tester);
      expect(pasteImageCalls, 1);
      // The fallback ran without throwing; there was nothing to paste.
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('with text on the clipboard the existing Paste is wrapped', (
      tester,
    ) async {
      mockClipboard(tester, hasText: true);
      var pasteImageCalls = 0;
      await openToolbar(
        tester,
        onPasteImage: () async {
          pasteImageCalls++;
          return true;
        },
      );

      final paste = find.widgetWithText(TextButton, 'Paste');
      expect(paste, findsOneWidget, reason: 'exactly one, not two');
      await tester.tap(paste);
      await _settle(tester);
      expect(
        pasteImageCalls,
        1,
        reason: 'image paste is tried first even for a text clipboard',
      );
    });

    testWidgets('a text clipboard still falls back to text paste when the'
        ' image hook declines', (tester) async {
      mockClipboard(tester, hasText: true);
      var pasteImageCalls = 0;
      await openToolbar(
        tester,
        onPasteImage: () async {
          pasteImageCalls++;
          return false;
        },
      );

      await tester.tap(find.widgetWithText(TextButton, 'Paste'));
      await _settle(tester);
      expect(pasteImageCalls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('CLIP'),
        reason: 'the wrapped Paste still pastes the text',
      );
    });

    testWidgets('without the hook the toolbar is left untouched', (
      tester,
    ) async {
      mockClipboard(tester, hasText: true);
      await openToolbar(tester, onPasteImage: null);

      // The standard Paste is left exactly as Flutter built it: tapping it
      // pastes the clipboard text into the field.
      final paste = find.widgetWithText(TextButton, 'Paste');
      expect(paste, findsOneWidget);
      await tester.tap(paste);
      await _settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('CLIP'),
      );
    });
  });
}
