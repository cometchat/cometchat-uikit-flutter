/// Render-verified prop matrix for [CometChatConfirmDialogStyle] — Track 3
/// PROP1. All 16 props.
///
/// `CometChatConfirmDialog` is not a widget: it is a class holding a
/// `BuildContext` whose `show()` calls `showDialog`. So each case pumps a host,
/// taps a button that calls `show()`, settles, and asserts against the dialog
/// route's own tree.
///
/// The style is resolved as `themeDefault.merge(style)`, so a prop set here
/// wins over the ambient theme — which is what makes a non-default sentinel a
/// valid probe.
///
///   flutter test test/shared_ui/confirm_dialog_style_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);
const _c6 = Color(0xFF606162);
const _c7 = Color(0xFF707172);
const _c8 = Color(0xFF808182);

List<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>()
    .toList();

void main() {
  testWidgets('the dialog opens at all', (tester) async {
    // The premise every other case rests on.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete conversation'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('backgroundColor, border and borderRadius shape the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  backgroundColor: _c1,
                  border: BorderSide(color: _c2, width: 3),
                  borderRadius: BorderRadius.all(Radius.circular(19)),
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, _c1);

    final shape = dialog.shape as RoundedRectangleBorder?;
    expect(shape?.side.color, _c2);
    expect(shape?.side.width, 3);
    expect(shape?.borderRadius, const BorderRadius.all(Radius.circular(19)));
  });

  testWidgets('shadow becomes the barrier colour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(shadow: _c3),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, _c3);
  });

  testWidgets('title and message text props apply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  titleTextColor: _c1,
                  titleTextStyle: TextStyle(fontSize: 27),
                  messageTextColor: _c2,
                  messageTextStyle: TextStyle(fontSize: 15),
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // AlertDialog carries these as titleTextStyle / contentTextStyle and
    // applies them through DefaultTextStyle, so the Text widgets themselves
    // hold no style — reading them would report every prop here as dead.
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.titleTextStyle?.color, _c1);
    expect(dialog.titleTextStyle?.fontSize, 27);
    expect(dialog.contentTextStyle?.color, _c2);
    expect(dialog.contentTextStyle?.fontSize, 15);
  });

  testWidgets('the confirm button props apply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  confirmButtonBackground: _c4,
                  confirmButtonTextColor: _c5,
                  confirmButtonTextStyle: TextStyle(fontSize: 21),
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Delete'));
    expect(label.style?.color, _c5);
    expect(label.style?.fontSize, 21);

    // The label sits inside more than one ButtonStyleButton ancestor, so take
    // the nearest.
    final TextButton button = tester
        .widgetList<TextButton>(
          find.ancestor(
            of: find.text('Delete'),
            matching: find.byType(TextButton),
          ),
        )
        .first;
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), _c4);
  });

  testWidgets('the cancel button props apply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  cancelButtonBackground: _c6,
                  cancelButtonTextColor: _c7,
                  cancelButtonTextStyle: TextStyle(fontSize: 18),
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Cancel'));
    expect(label.style?.color, _c7);
    expect(label.style?.fontSize, 18);

    // The label sits inside more than one ButtonStyleButton ancestor, so take
    // the nearest.
    final TextButton button = tester
        .widgetList<TextButton>(
          find.ancestor(
            of: find.text('Cancel'),
            matching: find.byType(TextButton),
          ),
        )
        .first;
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), _c6);
  });

  testWidgets('iconColor and iconBackgroundColor style the header icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  iconColor: _c8,
                  iconBackgroundColor: _c3,
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
      contains(_c8),
      reason: 'icon tint',
    );

    final backgrounds = <Color>{};
    for (final c in tester.widgetList<Container>(find.byType(Container))) {
      final d = c.decoration;
      if (d is BoxDecoration && d.color != null) backgrounds.add(d.color!);
      if (c.color != null) backgrounds.add(c.color!);
    }
    expect(backgrounds, contains(_c3), reason: 'icon background');
  });

  testWidgets('the two text styles do not leak into each other', (
    tester,
  ) async {
    // Guards the four text props as a set: a builder that reused one style for
    // both would pass every case above.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CometChatConfirmDialog(
                context: context,
                title: const Text('Delete conversation'),
                messageText: const Text('This cannot be undone.'),
                confirmButtonText: 'Delete',
                cancelButtonText: 'Cancel',
                style: const CometChatConfirmDialogStyle(
                  titleTextColor: _c1,
                  messageTextColor: _c2,
                  confirmButtonTextColor: _c5,
                  cancelButtonTextColor: _c7,
                ),
              ).show(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final colors = <Color?>{
      dialog.titleTextStyle?.color,
      dialog.contentTextStyle?.color,
      ..._textStyles(tester).map((t) => t.color),
    };
    expect(colors, containsAll(<Color>[_c1, _c2, _c5, _c7]));
  });
}
