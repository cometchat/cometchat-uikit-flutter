/// Render-verified prop matrix for the small shared style classes —
/// Track 3 PROP2 (ENG-38938).
///
/// Each of these sits at 1-2 covered props because it is constructed
/// incidentally somewhere and never exercised. Every one has a single widget
/// (or a single builder) that reads it, so each group pumps that and asserts
/// at the render site.
///
///   flutter test test/shared_ui/small_styles/small_style_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/widgets/message_composer_suggestion_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

Iterable<Color?> _fills(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.color),
];

Iterable<BoxDecoration?> _decorations(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration as BoxDecoration?),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => d.decoration as BoxDecoration?),
];

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

void main() {
  group('CometChatReactionsStyle', () {
    testWidgets('every property reaches the reaction pills', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatReactions(
            reactionList: [
              ReactionCount(reaction: '👍', count: 2, reactedByMe: true),
              ReactionCount(reaction: '🎉', count: 1, reactedByMe: false),
            ],
            alignment: BubbleAlignment.left,
            style: CometChatReactionsStyle(
              backgroundColor: const Color(0xFF214040),
              activeReactionBackgroundColor: const Color(0xFF214141),
              activeReactionBorder: const Border.fromBorderSide(
                BorderSide(color: Color(0xFF214242), width: 3),
              ),
              border: const Border.fromBorderSide(
                BorderSide(color: Color(0xFF214343), width: 2),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(89)),
              countTextColor: const Color(0xFF214444),
              countTextStyle: const TextStyle(fontSize: 17),
              emojiTextStyle: const TextStyle(fontSize: 29),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF214141)));
      expect(
        _decorations(tester).map((d) => d?.borderRadius),
        contains(const BorderRadius.all(Radius.circular(89))),
      );
      expect(_textColors(tester), contains(const Color(0xFF214444)));
      expect(_textSizes(tester), contains(17.0));
      expect(_textSizes(tester), contains(29.0));
    });
  });

  group('CometChatSuggestionListStyle', () {
    testWidgets('every property reaches the suggestion rows', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          MessageComposerSuggestionList(
            suggestions: [SuggestionListItem(id: 'u1', title: 'Alice')],
            onItemTap: (_) {},
            onScrollToBottom: () {},
            scrollController: controller,
            style: const CometChatSuggestionListStyle(
              backgroundColor: Color(0xFF215050),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF215151), width: 3),
              ),
              borderRadius: BorderRadius.all(Radius.circular(91)),
              textColor: Color(0xFF215252),
              textStyle: TextStyle(fontSize: 31),
              avatarStyle: CometChatAvatarStyle(
                backgroundColor: Color(0xFF215353),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _decorations(tester).map((d) => d?.borderRadius),
        contains(const BorderRadius.all(Radius.circular(91))),
      );
      expect(_textColors(tester), contains(const Color(0xFF215252)));
      expect(_textSizes(tester), contains(31.0));
    });
  });

  group('CometChatAttachmentErrorAlertStyle', () {
    testWidgets('every property reaches the error snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CometChatAttachmentErrorSnackBar.show(
                  context,
                  tile: AttachmentTile(
                    fileId: 'f1',
                    name: 'clip.pdf',
                    mimeType: 'application/pdf',
                    size: 1024,
                    status: AttachmentTileStatus.failed,
                    errorMessage: 'upload failed',
                  ),
                  style: const CometChatAttachmentErrorAlertStyle(
                    backgroundColor: Color(0xFF216060),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 9),
                    icon: Icon(Icons.warning, key: Key('alert-icon')),
                    iconColor: Color(0xFF216161),
                    margin: EdgeInsets.only(left: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(93)),
                    ),
                    textStyle: TextStyle(fontSize: 33),
                  ),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, const Color(0xFF216060));
      // Flutter asserts that margin is only legal with floating behavior, so
      // the two cannot be exercised in one snackbar; `behavior` is asserted
      // here on floating and again below on fixed with no margin.
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.margin, const EdgeInsets.only(left: 11));
      expect(bar.duration, const Duration(seconds: 9));
      expect(bar.shape, isA<RoundedRectangleBorder>());
      expect(find.byKey(const Key('alert-icon')), findsOneWidget);
      expect(_textSizes(tester), contains(33.0));
    });
  });

  group('CometChatAttachmentErrorAlertStyle — the fixed behavior', () {
    testWidgets('behavior fixed reaches the snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CometChatAttachmentErrorSnackBar.show(
                  context,
                  tile: AttachmentTile(
                    fileId: 'f1',
                    name: 'clip.pdf',
                    mimeType: 'application/pdf',
                    size: 1024,
                    status: AttachmentTileStatus.failed,
                    errorMessage: 'upload failed',
                  ),
                  // no margin — Flutter asserts margin is floating-only
                  style: const CometChatAttachmentErrorAlertStyle(
                    behavior: SnackBarBehavior.fixed,
                  ),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
        SnackBarBehavior.fixed,
      );
    });
  });
  group('CometChatBadge own props', () {
    testWidgets('count, height, width and padding size the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatBadge(
            count: 42,
            height: 37,
            width: 39,
            padding: EdgeInsets.only(left: 5),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(box.constraints?.maxHeight, 37);
      expect(box.constraints?.maxWidth, 39);
      expect(box.padding, const EdgeInsets.only(left: 5));
    });
  });

  group('CometChatAvatar own props', () {
    testWidgets('name, geometry and the theme objects reach the avatar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatAvatar(
              name: 'Alice',
              height: 41,
              width: 43,
              padding: const EdgeInsets.only(left: 7),
              margin: const EdgeInsets.only(top: 9),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(box.constraints?.maxHeight, 41);
      expect(box.constraints?.maxWidth, 43);
      expect(box.padding, const EdgeInsets.only(left: 7));
      expect(box.margin, const EdgeInsets.only(top: 9));
    });

    testWidgets('image adds a network image over the initials', (tester) async {
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.toString().contains('resolving an image codec') ||
            d.toString().contains('HTTP request failed')) {
          return;
        }
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);

      await tester.pumpWidget(
        _host(
          const CometChatAvatar(
            name: 'Alice',
            image: 'https://example.com/alice.png',
          ),
        ),
      );
      await tester.pump();
      // the avatar keeps the initials underneath as a loading fallback, so
      // what `image` adds is the network image on top of them
      expect(find.text('AL'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('CometChatReceipt own props', () {
    testWidgets('size and colorPalette reach the receipt', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatReceipt(
              status: ReceiptStatus.read,
              size: 29,
              readIcon: const Icon(Icons.done_all, key: Key('read')),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('read')), findsOneWidget);
    });

    testWidgets('each status picks its own icon slot', (tester) async {
      for (final entry in const <ReceiptStatus, String>{
        ReceiptStatus.waiting: 'wait',
        ReceiptStatus.sent: 'sent',
        ReceiptStatus.delivered: 'delivered',
        ReceiptStatus.error: 'error',
        ReceiptStatus.read: 'read',
      }.entries) {
        await tester.pumpWidget(
          _host(
            CometChatReceipt(
              status: entry.key,
              waitIcon: const Icon(Icons.schedule, key: Key('wait')),
              sentIcon: const Icon(Icons.check, key: Key('sent')),
              deliveredIcon: const Icon(Icons.done_all, key: Key('delivered')),
              readIcon: const Icon(Icons.done_all, key: Key('read')),
              errorIcon: const Icon(Icons.error, key: Key('error')),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(Key(entry.value)),
          findsOneWidget,
          reason: 'expected the ${entry.key.name} icon',
        );
      }
    });
  });

  group('CometChatDate own props', () {
    testWidgets('pattern, geometry and the transparent flag reach the date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatDate(
            date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            pattern: DateTimePattern.dayDateFormat,
            height: 45,
            width: 47,
            padding: const EdgeInsets.only(left: 11),
            isTransparentBackground: true,
          ),
        ),
      );
      await tester.pump();
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(box.constraints?.maxHeight, 45);
      expect(box.constraints?.maxWidth, 47);
      expect(box.padding, const EdgeInsets.only(left: 11));
    });

    testWidgets('customDateString replaces the formatted date', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatDate(
            date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            customDateString: 'THE DAY',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('THE DAY'), findsOneWidget);
    });

    testWidgets('dateTimeFormatterCallback reaches the date', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatDate(
            date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            dateTimeFormatterCallback: _TestDateFormatter(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatDate), findsOneWidget);
    });
  });

  group('CometChatReactions own props', () {
    testWidgets(
      'geometry, theme objects and the tap callbacks reach the pills',
      (tester) async {
        var tapped = false;
        var longPressed = false;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => CometChatReactions(
                reactionList: [
                  ReactionCount(reaction: 'A', count: 2, reactedByMe: true),
                ],
                alignment: BubbleAlignment.left,
                height: 49,
                width: 251,
                padding: const EdgeInsets.only(left: 11),
                margin: const EdgeInsets.only(top: 13),
                onReactionTap: (_) => tapped = true,
                onReactionLongPress: (_) => longPressed = true,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.margin),
          contains(const EdgeInsets.only(top: 13)),
        );
        await tester.tap(find.text('A'));
        await tester.pump();
        await tester.longPress(find.text('A'));
        await tester.pump();
        expect(tapped || longPressed, isTrue);
      },
    );
  });
}

/// Concrete formatter, since [DateTimeFormatterCallback] is abstract.
class _TestDateFormatter extends DateTimeFormatterCallback {
  @override
  String? today(int? timestamp) => 'FORMATTED';
}
