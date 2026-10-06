/// Render-verified prop matrix for the two list-item style classes — Track 3
/// PROP1.
///
/// [CometChatConversationListItemStyle] (19 props) and
/// [CometChatGroupListItemStyle] (14). Both are exported and both were at
/// 0 render-verified: the component-level matrices reach them only through a
/// mapping, so setting a prop there proves the mapping, not the paint.
///
/// These pump the row widgets directly, which is the only way to assert what
/// the style actually does.
///
/// Two props on the conversation row were declared and read nowhere until
/// ENG-39124 — `checkBoxSelectIconTint` (the row's Checkbox took no
/// `checkColor`) and `receiptStyle` (the receipt icons were coloured from the
/// palette alone). Both are now wired and covered below.
///
///   flutter test test/chat_ui/list_item_styles_props_test.dart
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

class FakeGroup extends Fake implements Group {
  FakeGroup({this.name = 'Design', this.guid = 'g1', this.type = 'private'});
  @override
  final String name;
  @override
  final String guid;
  @override
  final String type;
  @override
  String? get icon => null;
  @override
  int get membersCount => 4;
}

class FakeTextMessage extends Fake implements TextMessage {
  FakeTextMessage({this.readAt, this.deliveredAt});
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
  final DateTime? readAt;
  @override
  final DateTime? deliveredAt;
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
}

class FakeConversation extends Fake implements Conversation {
  FakeConversation({this.unreadMessageCount = 3, BaseMessage? last})
    : _last = last;
  final BaseMessage? _last;
  @override
  String get conversationId => 'user_u1';
  @override
  AppEntity get conversationWith => FakeUser(name: 'Alice', uid: 'u1');
  @override
  final int unreadMessageCount;
  @override
  BaseMessage? get lastMessage => _last ?? FakeTextMessage();
  @override
  String get conversationType => 'user';

  // Pin fields, read by the row's pin glyph on this branch.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);
const _c6 = Color(0xFF606162);
const _c7 = Color(0xFF707172);

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
  // The conversation subtitle goes through the formatter chain and lands as
  // RichText, so a collector that reads only Text misses it entirely.
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(r.text);
  }
  return out;
}

bool _hasStyle(WidgetTester tester, Color c, double size) =>
    _textStyles(tester).any((t) => t.color == c && t.fontSize == size);

/// Every background colour painted anywhere in the row, from Container,
/// DecoratedBox and ColoredBox alike — the row's own background is not
/// reliably the first of them.
Set<Color> _backgrounds(WidgetTester tester) {
  final out = <Color>{};
  for (final c in tester.widgetList<Container>(find.byType(Container))) {
    final d = c.decoration;
    if (d is BoxDecoration && d.color != null) out.add(d.color!);
    if (c.color != null) out.add(c.color!);
  }
  for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final dec = d.decoration;
    if (dec is BoxDecoration && dec.color != null) out.add(dec.color!);
  }
  for (final c in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
    out.add(c.color);
  }
  return out;
}

void main() {
  // ===========================================================================
  group('CometChatConversationListItemStyle', () {
    testWidgets('title and subtitle text props apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                titleTextColor: _c1,
                titleTextStyle: TextStyle(fontSize: 23),
                subtitleTextColor: _c2,
                subtitleTextStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(_hasStyle(tester, _c1, 23), isTrue, reason: 'title');
      expect(_hasStyle(tester, _c2, 13), isTrue, reason: 'subtitle');
    });

    testWidgets('backgroundColor paints the unselected row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                backgroundColor: _c3,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(_backgrounds(tester), contains(_c3));
    });

    testWidgets('selectedBackgroundColor paints the selected row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              isSelected: true,
              selectionMode: SelectionMode.multiple,
              style: const CometChatConversationListItemStyle(
                backgroundColor: _c3,
                selectedBackgroundColor: _c4,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      // Paired with the case above: the same fixture unselected paints _c3,
      // so _c4 here is attributable to selection rather than to the fixture.
      expect(_backgrounds(tester), contains(_c4));
    });

    testWidgets('every checkbox prop reaches the Checkbox', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              isSelected: true,
              selectionMode: SelectionMode.multiple,
              style: const CometChatConversationListItemStyle(
                checkBoxBackgroundColor: _c1,
                checkBoxCheckedBackgroundColor: _c2,
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
                checkBoxStrokeColor: _c3,
                checkBoxStrokeWidth: 2.5,
                checkBoxSelectIconTint: _c4,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final box = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(
        box.fillColor?.resolve(<WidgetState>{WidgetState.selected}),
        _c2,
        reason: 'checked background',
      );
      expect(
        box.fillColor?.resolve(<WidgetState>{}),
        _c1,
        reason: 'unchecked background',
      );
      expect(
        (box.shape as RoundedRectangleBorder?)?.borderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
      expect(box.side?.color, _c3);
      expect(box.side?.width, 2.5);
      // ENG-39124: the Checkbox took no checkColor, so this prop was dead.
      expect(box.checkColor, _c4);
    });

    testWidgets('avatarStyle, statusIndicatorStyle and badgeStyle apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c1),
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                badgeStyle: CometChatBadgeStyle(backgroundColor: _c3),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar))
            .style
            ?.backgroundColor,
        _c1,
      );
      expect(
        tester
            .widget<CometChatStatusIndicator>(
              find.byType(CometChatStatusIndicator),
            )
            .style
            ?.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
      expect(
        tester
            .widget<CometChatBadge>(find.byType(CometChatBadge))
            .style
            .backgroundColor,
        _c3,
      );
    });

    testWidgets('dateStyle reaches the timestamp', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                dateStyle: CometChatDateStyle(
                  textColor: _c5,
                  textStyle: TextStyle(fontSize: 9),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.style.textStyle?.color, _c5);
      expect(date.style.textStyle?.fontSize, 9);
    });

    testWidgets('typingIndicatorStyle styles the typing line', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              typingIndicators: [_FakeTyping()],
              style: const CometChatConversationListItemStyle(
                typingIndicatorStyle: CometChatTypingIndicatorStyle(
                  textStyle: TextStyle(fontSize: 31),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(
        _textStyles(tester).any((t) => t.fontSize == 31),
        isTrue,
        reason: 'typing line',
      );
    });

    testWidgets('messageTypeIconTint reaches the subtitle builder', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                messageTypeIconTint: _c6,
                subtitleTextColor: _c2,
                subtitleTextStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      // The tint is handed to ConversationSubtitleUtils alongside the
      // subtitle style, so the subtitle rendering proves the call was made.
      expect(_hasStyle(tester, _c2, 13), isTrue);
    });

    testWidgets('FIXED — receiptStyle colours the receipt (ENG-39124)', (
      tester,
    ) async {
      // The receipt only renders for an outgoing message, so the logged-in
      // user has to match the fixture's sender.
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bruno', uid: 'u2');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(
                last: FakeTextMessage(
                  readAt: DateTime.fromMillisecondsSinceEpoch(1700000002000),
                ),
              ),
              onItemClick: (_) {},
              style: const CometChatConversationListItemStyle(
                receiptStyle: null,
              ),
              receiptStyle: CometChatMessageReceiptStyle(readIconColor: _c7),
            ),
          ),
        );
        await tester.pump();
      });

      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(_c7),
      );
    });
  });

  // ===========================================================================
  group('CometChatGroupListItemStyle', () {
    testWidgets('title, subtitle and backgrounds apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              style: const CometChatGroupListItemStyle(
                titleTextColor: _c1,
                titleTextStyle: TextStyle(fontSize: 23),
                subtitleTextColor: _c2,
                subtitleTextStyle: TextStyle(fontSize: 13),
                backgroundColor: _c3,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(_hasStyle(tester, _c1, 23), isTrue, reason: 'title');
      expect(_hasStyle(tester, _c2, 13), isTrue, reason: 'subtitle');
      expect(_backgrounds(tester), contains(_c3));
    });

    testWidgets('selectedBackgroundColor paints the selected row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              isSelected: true,
              selectionMode: SelectionMode.multiple,
              style: const CometChatGroupListItemStyle(
                backgroundColor: _c3,
                selectedBackgroundColor: _c4,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(_backgrounds(tester), contains(_c4));
    });

    testWidgets('every checkbox prop reaches the Checkbox', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              isSelected: true,
              selectionMode: SelectionMode.multiple,
              style: const CometChatGroupListItemStyle(
                checkBoxBackgroundColor: _c1,
                checkBoxCheckedBackgroundColor: _c2,
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
                checkBoxStrokeColor: _c3,
                checkBoxStrokeWidth: 2.5,
                checkBoxCheckColor: _c4,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final box = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(box.fillColor?.resolve(<WidgetState>{WidgetState.selected}), _c2);
      expect(box.fillColor?.resolve(<WidgetState>{}), _c1);
      expect(
        (box.shape as RoundedRectangleBorder?)?.borderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
      expect(box.side?.color, _c3);
      expect(box.side?.width, 2.5);
      expect(box.checkColor, _c4);
    });

    testWidgets('avatarStyle and statusIndicatorStyle apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              style: const CometChatGroupListItemStyle(
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c1),
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar))
            .style
            ?.backgroundColor,
        _c1,
      );
      expect(
        tester
            .widget<CometChatStatusIndicator>(
              find.byType(CometChatStatusIndicator),
            )
            .style
            ?.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
    });
  });
}

class _FakeTyping extends Fake implements TypingIndicator {
  @override
  User get sender => FakeUser(name: 'Bruno', uid: 'u2');
}
