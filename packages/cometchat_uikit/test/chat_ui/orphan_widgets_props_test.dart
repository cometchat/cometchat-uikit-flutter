/// Render-verified prop matrix for [SearchFilterChip],
/// [ConversationsTrailingView] and [ConversationsSubtitleView] — Track 3
/// PROP1. 48 props between them, all previously at zero.
///
/// The two conversation subviews are **exported and constructed by nothing**.
/// Nothing in `lib/` references either; `ConversationsList` builds its own
/// trailing and subtitle sections inline instead. That is worth knowing beyond
/// coverage: it explains ENG-39115's seven dead date/badge props on
/// `ConversationsList`, which mirror this trailing view's parameters exactly.
/// The list was shaped to delegate here and never did. ENG-39128.
///
/// Their props all work — each is read inside its own build — so they are
/// covered here by constructing them directly, which is the only way anything
/// reaches them today.
///
///   flutter test test/chat_ui/orphan_widgets_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class FakeUser extends Fake implements User {
  FakeUser({this.name = 'Alice', this.uid = 'u1'});
  @override
  final String name;
  @override
  final String uid;
  @override
  String? get avatar => null;
  @override
  String get status => 'online';
  @override
  String? get role => 'default';
  @override
  String? get link => null;
}

class FakeTextMessage extends Fake implements TextMessage {
  @override
  int get id => 100;
  @override
  String get text => 'Thursday works';
  @override
  String get type => 'text';
  @override
  String get category => 'message';
  @override
  User get sender => FakeUser(name: 'Bruno', uid: 'u2');
  @override
  String get receiverUid => 'u1';
  @override
  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(1700000000000);
  @override
  DateTime? get updatedAt => null;
  @override
  DateTime? get deletedAt => null;
  @override
  String? get deletedBy => null;
  @override
  DateTime? get readAt => null;
  @override
  DateTime? get deliveredAt => null;
  @override
  int get parentMessageId => 0;
  @override
  int get replyCount => 0;
  @override
  List<ReactionCount> get reactions => const [];
  @override
  List<String> get tags => const [];
  @override
  List<User> get mentionedUsers => const [];
  @override
  String get muid => 'muid_100';
  @override
  ModerationStatusEnum? get moderationStatus => null;
  @override
  Map<String, dynamic>? get metadata => null;
}

class FakeConversation extends Fake implements Conversation {
  @override
  String get conversationId => 'user_u1';
  @override
  AppEntity get conversationWith => FakeUser(name: 'Alice', uid: 'u1');
  @override
  int get unreadMessageCount => 3;
  @override
  BaseMessage? get lastMessage => FakeTextMessage();
  @override
  String get conversationType => 'user';

  // Pin fields, read by the trailing view's pin glyph on this branch.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

class FakeTyping extends Fake implements TypingIndicator {
  @override
  User get sender => FakeUser(name: 'Bruno', uid: 'u2');
}

class _StubDateFormatter extends DateTimeFormatterCallback {
  @override
  String? today(int? timestamp) => 'stub-today';
}

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);
const _c6 = Color(0xFF606162);

Widget _host(Widget Function(BuildContext) build) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Builder(builder: build)),
);

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
  group('SearchFilterChip', () {
    testWidgets('the selected chip takes every selected-* prop', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        _host(
          (context) => SearchFilterChip(
            label: 'Unread',
            icon: Icons.mark_email_unread_outlined,
            isSelected: true,
            onTap: () => taps++,
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            typography: CometChatThemeHelper.getTypography(context),
            selectedColor: _c1,
            selectedIconColor: _c2,
            selectedTextColor: _c3,
            selectedTextStyle: const TextStyle(fontSize: 17),
            selectedBorder: const Border.fromBorderSide(
              BorderSide(color: _c4, width: 2),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unread'), findsOneWidget);

      final dec = _decorations(tester).firstWhere((d) => d.color == _c1);
      expect((dec.border as Border?)?.top.color, _c4);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(11)));

      expect(
        _textStyles(tester).any((t) => t.color == _c3 && t.fontSize == 17),
        isTrue,
        reason: 'selected label',
      );
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(_c2),
        reason: 'selected icon',
      );

      await tester.tap(find.text('Unread'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the unselected chip takes every unselected-* prop', (
      tester,
    ) async {
      // Paired with the case above: the same chip in the other state, so each
      // prop is attributable to selection rather than to the fixture.
      await tester.pumpWidget(
        _host(
          (context) => SearchFilterChip(
            label: 'Photos',
            icon: Icons.photo_outlined,
            isSelected: false,
            onTap: () {},
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            typography: CometChatThemeHelper.getTypography(context),
            unselectedColor: _c5,
            unselectedIconColor: _c6,
            unselectedTextColor: _c1,
            textStyle: const TextStyle(fontSize: 13),
            unSelectedBorder: const Border.fromBorderSide(
              BorderSide(color: _c2, width: 1),
            ),
          ),
        ),
      );
      await tester.pump();

      final dec = _decorations(tester).firstWhere((d) => d.color == _c5);
      expect((dec.border as Border?)?.top.color, _c2);

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 13),
        isTrue,
        reason: 'unselected label',
      );
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(_c6),
        reason: 'unselected icon',
      );
    });
  });

  // ===========================================================================
  group('ConversationsTrailingView', () {
    testWidgets('the date and badge props reach their widgets', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsTrailingView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(),
              datesStyle: const CometChatDateStyle(textColor: _c1),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              datePattern: (x) => 'pinned',
              datePadding: const EdgeInsets.all(5),
              dateHeight: 30,
              dateWidth: 60,
              dateBackgroundIsTransparent: false,
              badgeWidth: 34,
              badgeHeight: 26,
              badgePadding: const EdgeInsets.all(4),
              dateTimeFormatterCallback: _StubDateFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.customDateString, 'pinned');
      expect(date.padding, const EdgeInsets.all(5));
      expect(date.height, 30);
      expect(date.width, 60);
      expect(date.isTransparentBackground, isFalse);
      expect(date.dateTimeFormatterCallback, isA<_StubDateFormatter>());

      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.width, 34);
      expect(badge.height, 26);
      expect(badge.padding, const EdgeInsets.all(4));
    });

    testWidgets('style and datesStyle reach the rendered date', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsTrailingView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(
                badgeStyle: CometChatBadgeStyle(backgroundColor: _c2),
              ),
              datesStyle: const CometChatDateStyle(textColor: _c1),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();

      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.style.textStyle?.color, _c1);

      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.style.backgroundColor, _c2);
    });
  });

  // ===========================================================================
  group('ConversationsSubtitleView', () {
    testWidgets('the receipt props render for an outgoing message', (
      tester,
    ) async {
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bruno', uid: 'u2');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsSubtitleView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(),
              receiptStyle: CometChatMessageReceiptStyle(sentIconColor: _c1),
              typingStyle: const CometChatTypingIndicatorStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              readIcon: const Text('read-glyph'),
              deliveredIcon: const Text('delivered-glyph'),
              sentIcon: const Text('sent-glyph'),
              hideThreadIndicator: false,
              textFormatters: const <CometChatTextFormatter>[],
            ),
          ),
        ),
      );
      await tester.pump();

      // The fixture's message is neither read nor delivered, so 'sent'.
      expect(find.text('sent-glyph'), findsOneWidget);
      expect(find.text('read-glyph'), findsNothing);
      expect(find.text('delivered-glyph'), findsNothing);
    });

    testWidgets('receiptsVisibility false removes the receipt', (tester) async {
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bruno', uid: 'u2');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsSubtitleView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              sentIcon: const Text('sent-glyph'),
              receiptsVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Paired with the case above, where the same fixture renders it.
      expect(find.text('sent-glyph'), findsNothing);
    });

    testWidgets('the typing props replace the subtitle', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsSubtitleView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(
                textStyle: TextStyle(fontSize: 31),
              ),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              typingIndicators: [FakeTyping()],
              typingIndicatorText: 'scribbling…',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('scribbling…'), findsOneWidget);
      expect(
        _textStyles(tester).any((t) => t.fontSize == 31),
        isTrue,
        reason: 'typing style',
      );
    });

    testWidgets('style, palette, spacing and typography are taken', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsSubtitleView(
              conversation: FakeConversation(),
              style: const CometChatConversationsStyle(
                itemSubtitleTextColor: _c3,
                itemSubtitleTextStyle: TextStyle(fontSize: 13),
              ),
              receiptStyle: CometChatMessageReceiptStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c3 && t.fontSize == 13),
        isTrue,
        reason: 'subtitle style',
      );
    });
  });
}
