/// Render-verified prop matrix for the four AI view style classes — Track 3
/// PROP1.
///
/// 36 props between them. What this file can reach, and why it stops where it
/// does:
///
///   * [CometChatAIAssistantBubbleStyle] — 5/5. A plain bubble with no fetch,
///     so it pumps like any other widget.
///   * [CometChatAISmartRepliesStyle] — 6 of 12. The view fetches in
///     `initState` through the static `CometChat.getSmartReplies`, which has
///     no seam. Headlessly that fails and the view settles into its error
///     state, which still renders the whole decorated container — so the five
///     container props and `errorTextStyle` are reachable. The four `item*`
///     props need actual replies.
///   * [CometChatAIConversationSummaryStyle] — 6 of 10, same shape.
///     `summaryTextStyle` needs a fetched summary.
///   * [CometChatAIConversationStarterStyle] — 0 of 9. Its build returns
///     `SizedBox.shrink()` unless `_replies` is non-empty, so with no data
///     nothing renders and not one prop is observable.
///
/// Ten of the 36 are declared and read nowhere at all — see the DEFECT group
/// at the end. ENG-39126.
///
///   flutter test test/shared_ui/ai_view_styles_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);

class _FakeUser extends Fake implements User {
  @override
  String get name => 'Alice';
  @override
  String get uid => 'u1';
  @override
  String? get avatar => null;
  @override
  String get status => 'online';
  @override
  String? get role => 'default';
  @override
  String? get link => null;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// The fetching views reach the SDK from `initState`. Headlessly that fails,
/// which is the state under test — the noise it makes is not.
void _ignoreSdkErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('SDK not initialized') ||
        text.contains('has not been implemented') ||
        text.contains('MissingPluginException')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

List<BoxDecoration> _decorations(WidgetTester tester) {
  final out = <BoxDecoration>[];
  for (final c in tester.widgetList<Container>(find.byType(Container))) {
    if (c.decoration is BoxDecoration) out.add(c.decoration! as BoxDecoration);
  }
  for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    if (d.decoration is BoxDecoration) out.add(d.decoration as BoxDecoration);
  }
  return out;
}

List<TextStyle> _textStyles(WidgetTester tester) {
  final out = <TextStyle>[];
  void walk(InlineSpan? span) {
    if (span is TextSpan) {
      if (span.style != null) out.add(span.style!);
      span.children?.forEach(walk);
    }
  }

  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if (t.style != null) out.add(t.style!);
    walk(t.textSpan);
  }
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(r.text);
  }
  return out;
}

void main() {
  // ===========================================================================
  group('CometChatAIAssistantBubbleStyle', () {
    testWidgets('all five props reach the bubble', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatAIAssistantBubble(
            text: 'Here is a summary of the thread.',
            style: CometChatAIAssistantBubbleStyle(
              backgroundColor: _c1,
              border: Border.fromBorderSide(BorderSide(color: _c2, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(13)),
              textColor: _c3,
              textStyle: TextStyle(fontSize: 19),
            ),
          ),
        ),
      );
      await tester.pump();

      final dec = _decorations(tester).firstWhere((d) => d.color == _c1);
      expect((dec.border as Border?)?.top.color, _c2);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(13)));

      // textColor is applied last with copyWith, so it wins over textStyle's
      // own colour — asserting both together proves the merge order too.
      expect(
        _textStyles(tester).any((t) => t.color == _c3 && t.fontSize == 19),
        isTrue,
        reason: 'bubble text',
      );
    });
  });

  // ===========================================================================
  group('CometChatAISmartRepliesStyle', () {
    testWidgets('the five container props and errorTextStyle apply', (
      tester,
    ) async {
      _ignoreSdkErrors();

      await tester.pumpWidget(
        _wrap(
          CometChatAISmartRepliesView(
            user: _FakeUser(),
            style: const CometChatAISmartRepliesStyle(
              backgroundColor: _c1,
              border: Border.fromBorderSide(BorderSide(color: _c2, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(14)),
              titleStyle: TextStyle(color: _c3, fontSize: 21),
              closeIconColor: _c4,
              errorTextStyle: TextStyle(color: _c5, fontSize: 15),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The container props travel through DecoratedContainerStyle, so the
      // assertion reads them off the decorated container the view builds.
      final decorated = tester.widget<CometChatDecoratedContainer>(
        find.byType(CometChatDecoratedContainer),
      );
      expect(decorated.style?.backgroundColor, _c1);
      expect((decorated.style?.border as Border?)?.top.color, _c2);
      expect(
        decorated.style?.borderRadius,
        const BorderRadius.all(Radius.circular(14)),
      );
      expect(decorated.style?.titleStyle?.color, _c3);
      expect(decorated.style?.titleStyle?.fontSize, 21);
      expect(decorated.style?.closeIconColor, _c4);

      // errorTextStyle is the state the view actually settles into here.
      expect(
        _textStyles(tester).any((t) => t.color == _c5 && t.fontSize == 15),
        isTrue,
        reason: 'error line',
      );
    });
  });

  // ===========================================================================
  group('CometChatAIConversationSummaryStyle', () {
    testWidgets('the five container props and errorTextStyle apply', (
      tester,
    ) async {
      _ignoreSdkErrors();

      await tester.pumpWidget(
        _wrap(
          CometChatAIConversationSummaryView(
            user: _FakeUser(),
            aiConversationSummaryStyle:
                const CometChatAIConversationSummaryStyle(
                  backgroundColor: _c1,
                  border: Border.fromBorderSide(
                    BorderSide(color: _c2, width: 2),
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  titleStyle: TextStyle(color: _c3, fontSize: 21),
                  closeIconColor: _c4,
                  errorTextStyle: TextStyle(color: _c5, fontSize: 15),
                ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final decorated = tester.widget<CometChatDecoratedContainer>(
        find.byType(CometChatDecoratedContainer),
      );
      expect(decorated.style?.backgroundColor, _c1);
      expect((decorated.style?.border as Border?)?.top.color, _c2);
      expect(
        decorated.style?.borderRadius,
        const BorderRadius.all(Radius.circular(14)),
      );
      expect(decorated.style?.titleStyle?.color, _c3);
      expect(decorated.style?.titleStyle?.fontSize, 21);
      expect(decorated.style?.closeIconColor, _c4);

      expect(
        _textStyles(tester).any((t) => t.color == _c5 && t.fontSize == 15),
        isTrue,
        reason: 'error line',
      );
    });
  });

  // ===========================================================================
  group('BLOCKED — props that need fetched data (ENG-39126)', () {
    // Constructed, not pumped: exercised without inflating the numerator.
    //
    // These are live — the views do read them — but every one renders only
    // once the SDK has returned data, and the fetch is a static
    // CometChat.getSmartReplies / getConversationSummary / getConversationStarter
    // call with no injection point. CometChatAIConversationStarterView is the
    // extreme case: its build returns SizedBox.shrink() unless _replies is
    // non-empty, so not one of its props is observable without data.
    //
    // Same shape as ENG-39114 on Search, and it wants the same kind of seam.

    test('the four SmartReplies item props need replies', () {
      const style = CometChatAISmartRepliesStyle(
        itemTextStyle: TextStyle(fontSize: 13),
        itemBackgroundColor: _c1,
        itemBorder: Border.fromBorderSide(BorderSide(color: _c2)),
        itemBorderRadius: BorderRadius.all(Radius.circular(5)),
      );

      expect(style.itemTextStyle?.fontSize, 13);
      expect(style.itemBackgroundColor, _c1);
      expect(style.itemBorder, isNotNull);
      expect(style.itemBorderRadius, isNotNull);
    });

    test('summaryTextStyle needs a fetched summary', () {
      const style = CometChatAIConversationSummaryStyle(
        summaryTextStyle: TextStyle(fontSize: 15),
      );

      expect(style.summaryTextStyle?.fontSize, 15);
    });

    test('every live ConversationStarter prop needs replies', () {
      const style = CometChatAIConversationStarterStyle(
        backgroundColor: _c1,
        border: Border.fromBorderSide(BorderSide(color: _c2)),
        borderRadius: BorderRadius.all(Radius.circular(9)),
        itemTextStyle: TextStyle(fontSize: 13),
      );

      expect(style.backgroundColor, _c1);
      expect(style.border, isNotNull);
      expect(style.borderRadius, isNotNull);
      expect(style.itemTextStyle?.fontSize, 13);
    });
  });

  // ===========================================================================
  group('DEFECT — ten props read nowhere at all (ENG-39126)', () {
    // Different from the group above: these are not waiting on data, they have
    // no reader in any state. Each view was checked for `_style.<prop>` and
    // `style.<prop>` across its whole file.

    test('SmartReplies has no empty state to style', () {
      // The third branch of its content is a ListView over _replies; with none
      // it renders an empty list, not an empty view. So these two never paint.
      const style = CometChatAISmartRepliesStyle(
        emptyTextStyle: TextStyle(fontSize: 15),
        emptyIconTint: _c1,
      );

      expect(style.emptyTextStyle?.fontSize, 15);
      expect(style.emptyIconTint, _c1);
    });

    test('ConversationSummary drops three', () {
      const style = CometChatAIConversationSummaryStyle(
        emptyTextStyle: TextStyle(fontSize: 15),
        emptyIconTint: _c1,
        shadowColor: _c2,
      );

      expect(style.emptyTextStyle?.fontSize, 15);
      expect(style.emptyIconTint, _c1);
      expect(style.shadowColor, _c2);
    });

    test('ConversationStarter drops five — more than half its surface', () {
      const style = CometChatAIConversationStarterStyle(
        emptyTextStyle: TextStyle(fontSize: 15),
        emptyIconTint: _c1,
        errorIconTint: _c2,
        errorTextStyle: TextStyle(fontSize: 17),
        shadowColor: _c3,
      );

      expect(style.emptyTextStyle?.fontSize, 15);
      expect(style.emptyIconTint, _c1);
      expect(style.errorIconTint, _c2);
      expect(style.errorTextStyle?.fontSize, 17);
      expect(style.shadowColor, _c3);
    });
  });
}
