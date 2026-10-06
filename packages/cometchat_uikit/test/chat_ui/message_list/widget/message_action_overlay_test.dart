/// Behaviour pins for [CometChatMessageActionOverlay] — the full-screen
/// context menu a long press on a message opens.
///
/// The overlay's whole job is to return something to its caller: an
/// [ActionItem] when an option is chosen, nothing when it is dismissed, and a
/// reaction through `onReactionTap`. These tests push it as a real route and
/// assert on what the route resolves to, plus the two layout decisions that
/// are not cosmetic (the iOS/Android option row order and the More/Back page
/// split).
///
///   flutter test test/chat_ui/message_list/widget/message_action_overlay_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_action_overlay.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'me', name: 'Me');

TextMessage _message() => TextMessage(
  id: 7,
  text: 'hello there',
  sender: _me,
  receiverUid: 'them',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime(2024, 5, 1, 9),
);

ActionItem _item(String id, String title, {IconData? icon}) =>
    ActionItem(id: id, title: title, icon: icon == null ? null : Icon(icon));

void main() {
  group('the style extension', () {
    const base = CometChatMessageActionOverlayStyle(
      backgroundColor: Color(0xFF010101),
      overlayColor: Color(0xFF020202),
      reactionBackgroundColor: Color(0xFF030303),
      reactionBorderRadius: BorderRadius.all(Radius.circular(3)),
      optionsBackgroundColor: Color(0xFF040404),
      optionsBorderRadius: BorderRadius.all(Radius.circular(4)),
      optionTitleStyle: TextStyle(fontSize: 11),
      optionIconColor: Color(0xFF050505),
      dividerColor: Color(0xFF060606),
    );

    test('copyWith replaces only what it is given', () {
      final copy = base.copyWith(
        optionsBackgroundColor: const Color(0xFFAAAAAA),
        optionsBorderRadius: const BorderRadius.all(Radius.circular(40)),
        optionTitleStyle: const TextStyle(fontSize: 21),
        optionIconColor: const Color(0xFFBBBBBB),
        dividerColor: const Color(0xFFCCCCCC),
      );

      expect(copy.optionsBackgroundColor, const Color(0xFFAAAAAA));
      expect(copy.optionsBorderRadius, BorderRadius.circular(40));
      expect(copy.optionTitleStyle?.fontSize, 21);
      expect(copy.optionIconColor, const Color(0xFFBBBBBB));
      expect(copy.dividerColor, const Color(0xFFCCCCCC));
      // Untouched fields survive.
      expect(copy.backgroundColor, base.backgroundColor);
      expect(copy.overlayColor, base.overlayColor);
      expect(copy.reactionBackgroundColor, base.reactionBackgroundColor);
      expect(copy.reactionBorderRadius, base.reactionBorderRadius);
    });

    test('merge lets the other side win, and null is a no-op', () {
      const other = CometChatMessageActionOverlayStyle(
        overlayColor: Color(0xFF999999),
        dividerColor: Color(0xFF888888),
      );

      final merged = base.merge(other);
      expect(merged.overlayColor, const Color(0xFF999999));
      expect(merged.dividerColor, const Color(0xFF888888));
      // merge() goes through copyWith, so a field the other side leaves null
      // keeps the receiver's value.
      expect(merged.optionsBackgroundColor, base.optionsBackgroundColor);

      expect(base.merge(null), same(base));
    });

    test('lerp interpolates every colour it knows about', () {
      const other = CometChatMessageActionOverlayStyle(
        backgroundColor: Color(0xFF030303),
        overlayColor: Color(0xFF040404),
        reactionBackgroundColor: Color(0xFF050505),
        optionsBackgroundColor: Color(0xFF060606),
        optionIconColor: Color(0xFF070707),
        dividerColor: Color(0xFF080808),
      );

      final half = base.lerp(other, 0.5) as CometChatMessageActionOverlayStyle;

      expect(
        half.backgroundColor,
        Color.lerp(base.backgroundColor, other.backgroundColor, 0.5),
      );
      expect(
        half.dividerColor,
        Color.lerp(base.dividerColor, other.dividerColor, 0.5),
      );
      // Non-colour fields are deliberately not interpolated.
      expect(half.optionTitleStyle, isNull);
      expect(half.optionsBorderRadius, isNull);
    });

    test('lerp against a foreign extension returns the receiver unchanged', () {
      expect(base.lerp(null, 0.5), same(base));
    });

    test(
      'of() is the empty style — the theme extension is the real source',
      () {
        final widget = Builder(
          builder: (context) {
            final style = CometChatMessageActionOverlayStyle.of(context);
            expect(style.overlayColor, isNull);
            expect(style.optionsBackgroundColor, isNull);
            return const SizedBox();
          },
        );
        expect(widget, isNotNull);
      },
    );
  });

  group('the overlay route', () {
    late ActionItem? result;
    late bool closed;

    setUp(() {
      result = null;
      closed = false;
    });

    /// Pushes [overlay] on its own route and settles the entry animation.
    Future<void> pushOverlay(
      WidgetTester tester,
      CometChatMessageActionOverlay overlay, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context)
                          .push<ActionItem>(
                            MaterialPageRoute<ActionItem>(
                              builder: (_) => overlay,
                            ),
                          )
                          .then((value) {
                            result = value;
                            closed = true;
                          }),
                    );
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
    }

    CometChatMessageActionOverlay overlay({
      List<ActionItem>? actions,
      List<String>? favoriteReactions,
      bool hideReactions = false,
      void Function(BaseMessage, String)? onReactionTap,
      String? heroTag,
      Size? bubbleSize,
      CometChatMessageActionOverlayStyle? style,
    }) => CometChatMessageActionOverlay(
      message: _message(),
      bubbleWidget: const SizedBox(
        key: ValueKey('bubble'),
        width: 120,
        height: 40,
      ),
      actionItems:
          actions ??
          [
            _item(
              MessageOptionConstants.replyMessage,
              'Reply',
              icon: Icons.reply,
            ),
            _item(MessageOptionConstants.copyMessage, 'Copy', icon: Icons.copy),
          ],
      bubbleAlignment: BubbleAlignment.right,
      favoriteReactions: favoriteReactions,
      hideReactions: hideReactions,
      onReactionTap: onReactionTap,
      heroTag: heroTag,
      bubbleSize: bubbleSize,
      style: style,
    );

    testWidgets('tapping the dimmed background closes it with no action', (
      tester,
    ) async {
      await pushOverlay(tester, overlay());
      expect(find.byType(CometChatMessageActionOverlay), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
      expect(find.byType(CometChatMessageActionOverlay), findsNothing);
    });

    testWidgets('tapping the bubble itself does NOT close it', (tester) async {
      await pushOverlay(tester, overlay());

      await tester.tap(find.byKey(const ValueKey('bubble')));
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.byType(CometChatMessageActionOverlay), findsOneWidget);
    });

    testWidgets('choosing an option returns that option to the caller', (
      tester,
    ) async {
      await pushOverlay(tester, overlay());

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result?.id, MessageOptionConstants.copyMessage);
    });

    testWidgets(
      'with a hero tag it plays the exit animation before returning',
      (tester) async {
        await pushOverlay(tester, overlay(heroTag: 'msg-7'));

        await tester.tap(find.text('Reply'));
        // The reverse animation is 200ms; the route must still be there while
        // it runs, so the bubble can fly back.
        await tester.pump(const Duration(milliseconds: 50));
        expect(closed, isFalse);
        expect(find.byType(CometChatMessageActionOverlay), findsOneWidget);

        await tester.pumpAndSettle();
        expect(closed, isTrue);
        expect(result?.id, MessageOptionConstants.replyMessage);
      },
    );
  });

  group('the reaction tray', () {
    late String? reacted;

    setUp(() => reacted = null);

    Future<void> pushOverlay(
      WidgetTester tester, {
      List<String>? favoriteReactions,
      bool hideReactions = false,
      Widget? addReactionIcon,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => unawaited(
                    Navigator.of(context).push<ActionItem>(
                      MaterialPageRoute<ActionItem>(
                        builder: (_) => CometChatMessageActionOverlay(
                          message: _message(),
                          bubbleWidget: const SizedBox(width: 120, height: 40),
                          actionItems: [
                            _item(MessageOptionConstants.copyMessage, 'Copy'),
                          ],
                          bubbleAlignment: BubbleAlignment.right,
                          favoriteReactions: favoriteReactions,
                          hideReactions: hideReactions,
                          addReactionIcon: addReactionIcon,
                          onReactionTap: (message, reaction) =>
                              reacted = reaction,
                        ),
                      ),
                    ),
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
    }

    testWidgets('a quick reaction closes the overlay and reports the emoji', (
      tester,
    ) async {
      await pushOverlay(tester, favoriteReactions: const ['🎉', '🥲']);

      expect(find.text('🎉'), findsOneWidget);
      await tester.tap(find.text('🥲'));
      await tester.pumpAndSettle();

      expect(reacted, '🥲');
      expect(find.byType(CometChatMessageActionOverlay), findsNothing);
    });

    testWidgets('the tray is capped at five emojis', (tester) async {
      await pushOverlay(
        tester,
        favoriteReactions: const ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣'],
      );

      expect(find.text('5️⃣'), findsOneWidget);
      expect(find.text('6️⃣'), findsNothing);
    });

    testWidgets('hideReactions removes the tray and the add button', (
      tester,
    ) async {
      await pushOverlay(
        tester,
        hideReactions: true,
        favoriteReactions: const ['🎉'],
      );

      expect(find.text('🎉'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    });

    testWidgets('the add-reaction button opens the emoji keyboard and reports '
        'the pick', (tester) async {
      await pushOverlay(tester, favoriteReactions: const ['🎉']);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.byType(CometChatEmojiKeyboard), findsOneWidget);

      // Pick an emoji: the keyboard resolves its sheet with the chosen one.
      Navigator.of(
        tester.element(find.byType(CometChatEmojiKeyboard)),
      ).pop('🚀');
      await tester.pumpAndSettle();

      expect(reacted, '🚀');
      expect(find.byType(CometChatMessageActionOverlay), findsNothing);
    });

    testWidgets('dismissing the emoji keyboard without a pick still closes '
        'the overlay, and reports nothing', (tester) async {
      await pushOverlay(tester, favoriteReactions: const ['🎉']);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(CometChatEmojiKeyboard))).pop();
      await tester.pumpAndSettle();

      expect(reacted, isNull);
      expect(find.byType(CometChatMessageActionOverlay), findsNothing);
    });

    testWidgets('a custom add-reaction icon replaces the default', (
      tester,
    ) async {
      await pushOverlay(
        tester,
        addReactionIcon: const Icon(Icons.star, key: ValueKey('custom-add')),
      );

      expect(find.byKey(const ValueKey('custom-add')), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    });
  });

  group('the options card', () {
    Future<void> push(
      WidgetTester tester,
      List<ActionItem> actions, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => unawaited(
                    Navigator.of(context).push<ActionItem>(
                      MaterialPageRoute<ActionItem>(
                        builder: (_) => CometChatMessageActionOverlay(
                          message: _message(),
                          bubbleWidget: const SizedBox(width: 120, height: 40),
                          actionItems: actions,
                          bubbleAlignment: BubbleAlignment.left,
                          hideReactions: true,
                        ),
                      ),
                    ),
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
    }

    testWidgets('on Android the icon leads the title', (tester) async {
      await push(tester, [
        _item(MessageOptionConstants.copyMessage, 'Copy', icon: Icons.copy),
      ]);

      expect(
        tester.getCenter(find.byIcon(Icons.copy)).dx,
        lessThan(tester.getCenter(find.text('Copy')).dx),
      );
    });

    testWidgets('on iOS the icon trails the title', (tester) async {
      await push(tester, [
        _item(MessageOptionConstants.copyMessage, 'Copy', icon: Icons.copy),
      ], platform: TargetPlatform.iOS);

      expect(
        tester.getCenter(find.byIcon(Icons.copy)).dx,
        greaterThan(tester.getCenter(find.text('Copy')).dx),
      );
    });

    testWidgets('options with no home on the first page move behind "More"', (
      tester,
    ) async {
      await push(tester, [
        _item(MessageOptionConstants.copyMessage, 'Copy'),
        _item('custom_action', 'Report to admin'),
      ]);

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report to admin'), findsNothing);

      final t = Translations.of(
        tester.element(find.byType(CometChatMessageActionOverlay)),
      );
      await tester.tap(find.text(t.more));
      await tester.pumpAndSettle();

      // The second page shows the overflow and offers the way back.
      expect(find.text('Report to admin'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text(t.backButton), findsOneWidget);

      await tester.tap(find.text(t.backButton));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);

      // Paging never closes the overlay.
      expect(find.byType(CometChatMessageActionOverlay), findsOneWidget);
    });

    testWidgets('no actions at all means no options card', (tester) async {
      await push(tester, const []);

      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(CometChatMessageActionOverlay), findsOneWidget);
    });
  });
}
