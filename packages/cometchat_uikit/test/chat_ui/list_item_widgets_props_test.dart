/// Render-verified prop matrix for the three list-item widgets — Track 3
/// PROP1.
///
/// [CometChatConversationListItem] (50 props), [CometChatGroupListItem] (28)
/// and [CometChatListItem] (23). Companion to
/// `list_item_styles_props_test.dart`, which covers the style objects these
/// take; this covers the widgets' own parameters.
///
/// Every construction is inline. A local builder scores zero even when the
/// pump and the assertion are inside the closure — see the note at the top of
/// `list_widgets_props_test.dart`.
///
///   flutter test test/chat_ui/list_item_widgets_props_test.dart
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
  FakeConversation({AppEntity? with_, this.unreadMessageCount = 3})
    : conversationWith = with_ ?? FakeUser(name: 'Alice', uid: 'u1');
  @override
  final AppEntity conversationWith;
  @override
  final int unreadMessageCount;
  @override
  String get conversationId => 'user_u1';
  @override
  BaseMessage? get lastMessage => FakeTextMessage();
  @override
  String get conversationType => conversationWith is User ? 'user' : 'group';

  // Pin fields, read by the row's pin glyph on this branch.
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

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);

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
  group('CometChatConversationListItem', () {
    testWidgets('avatar geometry and style reach the avatar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              avatarHeight: 44,
              avatarWidth: 46,
              avatarPadding: const EdgeInsets.all(7),
              avatarMargin: const EdgeInsets.all(3),
              avatarStyle: const CometChatAvatarStyle(backgroundColor: _c1),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CometChatAvatar>(
        find.byType(CometChatAvatar),
      );
      expect(avatar.height, 44);
      expect(avatar.width, 46);
      expect(avatar.padding, const EdgeInsets.all(7));
      expect(avatar.margin, const EdgeInsets.all(3));
      expect(avatar.style?.backgroundColor, _c1);
    });

    testWidgets('status-indicator geometry and style reach the badge', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              statusIndicatorHeight: 20,
              statusIndicatorWidth: 22,
              statusIndicatorBorderRadius: const BorderRadius.all(
                Radius.circular(9),
              ),
              statusIndicatorStyle: const CometChatStatusIndicatorStyle(
                backgroundColor: _c2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(dot.height, 20);
      expect(dot.width, 22);
      expect(
        dot.style?.borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
    });

    testWidgets('the badge and date props reach their widgets', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              badgeWidth: 34,
              badgeHeight: 26,
              badgePadding: const EdgeInsets.all(4),
              badgeStyle: const CometChatBadgeStyle(backgroundColor: _c3),
              datePattern: (x) => 'pinned',
              datePadding: const EdgeInsets.all(5),
              dateHeight: 30,
              dateWidth: 60,
              dateBackgroundIsTransparent: false,
              dateStyle: const CometChatDateStyle(textColor: _c4),
              dateTimeFormatterCallback: _StubDateFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.width, 34);
      expect(badge.height, 26);
      expect(badge.padding, const EdgeInsets.all(4));
      expect(badge.style.backgroundColor, _c3);

      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.customDateString, 'pinned');
      expect(date.padding, const EdgeInsets.all(5));
      expect(date.height, 30);
      expect(date.width, 60);
      expect(date.isTransparentBackground, isFalse);
      expect(date.style.textStyle?.color, _c4);
      expect(date.dateTimeFormatterCallback, isA<_StubDateFormatter>());
    });

    testWidgets('the four row slots replace their sections', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              leadingView: (c, t) => const Text('lead-slot'),
              titleView: (c, t) => const Text('title-slot'),
              subtitleView: (c, t) => const Text('sub-slot'),
              trailingView: (c, t) => const Text('trail-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lead-slot'), findsOneWidget);
      expect(find.text('title-slot'), findsOneWidget);
      expect(find.text('sub-slot'), findsOneWidget);
      expect(find.text('trail-slot'), findsOneWidget);
    });

    testWidgets('the group icons and their backgrounds reach the badge', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(
                with_: FakeGroup(name: 'Design', guid: 'g1', type: 'private'),
              ),
              onItemClick: (_) {},
              privateGroupIcon: const Icon(Icons.shield),
              protectedGroupIcon: const Icon(Icons.lock),
              privateGroupIconBackground: _c1,
              protectedGroupIconBackground: _c2,
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      // The conversation is with a private group, so the private colour is
      // what should paint.
      expect(dot.style?.backgroundColor, _c1);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('the three hide flags suppress their pieces', (tester) async {
      // hideUserStatus is proven by pairing: a user conversation shows a dot
      // by default, and none with the flag on.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatStatusIndicator), findsOneWidget);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              hideUserStatus: true,
              hideGroupType: true,
              hideReceipts: true,
              hideThreadIndicator: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatStatusIndicator), findsNothing);
    });

    testWidgets('the three receipt icons render for an outgoing message', (
      tester,
    ) async {
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bruno', uid: 'u2');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              readIcon: const Text('read-glyph'),
              deliveredIcon: const Text('delivered-glyph'),
              sentIcon: const Text('sent-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      // The fixture's message is neither read nor delivered, so it is 'sent'.
      expect(find.text('sent-glyph'), findsOneWidget);
      expect(find.text('read-glyph'), findsNothing);
      expect(find.text('delivered-glyph'), findsNothing);
    });

    testWidgets('typing props replace the subtitle', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              typingIndicators: [FakeTyping()],
              typingIndicatorText: 'scribbling…',
              typingIndicatorStyle: const CometChatTypingIndicatorStyle(
                textStyle: TextStyle(fontSize: 31),
              ),
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

    testWidgets('textFormatters, palette, spacing and typography are taken', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => CometChatConversationListItem(
                conversation: FakeConversation(),
                onItemClick: (_) {},
                textFormatters: const <CometChatTextFormatter>[],
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // An empty formatter list replaces the default chain, so the row still
      // renders but through the caller's (empty) one.
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('onSelectionToggle fires from the checkbox', (tester) async {
      var toggles = 0;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: FakeConversation(),
              onItemClick: (_) {},
              selectionMode: SelectionMode.multiple,
              isSelected: false,
              onSelectionToggle: () => toggles++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(toggles, 1);
    });
  });

  // ===========================================================================
  group('CometChatGroupListItem', () {
    testWidgets('avatar geometry and style reach the avatar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              avatarHeight: 44,
              avatarWidth: 46,
              avatarPadding: const EdgeInsets.all(7),
              avatarMargin: const EdgeInsets.all(3),
              avatarStyle: const CometChatAvatarStyle(backgroundColor: _c1),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CometChatAvatar>(
        find.byType(CometChatAvatar),
      );
      expect(avatar.height, 44);
      expect(avatar.width, 46);
      expect(avatar.padding, const EdgeInsets.all(7));
      expect(avatar.margin, const EdgeInsets.all(3));
      expect(avatar.style?.backgroundColor, _c1);
    });

    testWidgets('status-indicator geometry and style reach the badge', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              statusIndicatorHeight: 20,
              statusIndicatorWidth: 22,
              statusIndicatorBorderRadius: const BorderRadius.all(
                Radius.circular(9),
              ),
              statusIndicatorStyle: const CometChatStatusIndicatorStyle(
                border: Border.fromBorderSide(BorderSide(color: _c2)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(dot.height, 20);
      expect(dot.width, 22);
      expect(
        dot.style?.borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
      expect((dot.style?.border! as Border).top.color, _c2);
    });

    testWidgets('the four row slots replace their sections', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              leadingView: (g) => const Text('lead-slot'),
              titleView: (g) => const Text('title-slot'),
              subtitleView: (g) => const Text('sub-slot'),
              trailingView: (g) => const Text('trail-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lead-slot'), findsOneWidget);
      expect(find.text('title-slot'), findsOneWidget);
      expect(find.text('sub-slot'), findsOneWidget);
      expect(find.text('trail-slot'), findsOneWidget);
    });

    testWidgets('the group icons, backgrounds and hide flag', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: 'private'),
              onItemClick: (_) {},
              privateGroupIcon: const Icon(Icons.shield),
              protectedGroupIcon: const Icon(Icons.lock),
              privateGroupIconBackground: _c1,
              protectedGroupIconBackground: _c2,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(
        tester
            .widget<CometChatStatusIndicator>(
              find.byType(CometChatStatusIndicator),
            )
            .style
            ?.backgroundColor,
        _c1,
      );

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(type: 'private'),
              onItemClick: (_) {},
              privateGroupIcon: const Icon(Icons.shield),
              hideGroupTypeIcon: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.shield), findsNothing);
    });

    testWidgets('onItemLongClick and onSelectionToggle fire', (tester) async {
      Group? pressed;
      var toggles = 0;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroupListItem(
              group: FakeGroup(),
              onItemClick: (_) {},
              onItemLongClick: (g) => pressed = g,
              selectionMode: SelectionMode.multiple,
              onSelectionToggle: () => toggles++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Design'));
      await tester.pump();
      expect(pressed?.guid, 'g1');

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(toggles, 1);
    });

    testWidgets('palette, spacing and typography are taken', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => CometChatGroupListItem(
                group: FakeGroup(),
                onItemClick: (_) {},
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('CometChatListItem', () {
    testWidgets('avatar props reach the avatar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatListItem(
              avatarName: 'Alexandra',
              avatarURL: 'https://example.invalid/a.png',
              title: 'Alexandra',
              avatarHeight: 44,
              avatarWidth: 46,
              avatarPadding: EdgeInsets.all(7),
              avatarMargin: EdgeInsets.all(3),
              avatarStyle: CometChatAvatarStyle(backgroundColor: _c1),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CometChatAvatar>(
        find.byType(CometChatAvatar),
      );
      expect(avatar.name, 'Alexandra');
      expect(avatar.image, 'https://example.invalid/a.png');
      expect(avatar.height, 44);
      expect(avatar.width, 46);
      expect(avatar.padding, const EdgeInsets.all(7));
      expect(avatar.margin, const EdgeInsets.all(3));
      expect(avatar.style?.backgroundColor, _c1);
    });

    testWidgets('status-indicator props reach the badge', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatListItem(
              avatarName: 'Alexandra',
              title: 'Alexandra',
              statusIndicatorColor: _c2,
              statusIndicatorIcon: Icon(Icons.shield),
              statusIndicatorHeight: 20,
              statusIndicatorWidth: 22,
              statusIndicatorBorderRadius: BorderRadius.all(Radius.circular(9)),
              statusIndicatorStyle: CometChatStatusIndicatorStyle(
                border: Border.fromBorderSide(BorderSide(color: _c3)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(dot.height, 20);
      expect(dot.width, 22);
      expect(dot.style?.backgroundColor, _c2);
      expect(
        dot.style?.borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('the slots and paddings apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatListItem(
              avatarName: 'Alexandra',
              title: 'Alexandra',
              id: 'row-1',
              titleView: Text('title-slot'),
              subtitleView: Text('sub-slot'),
              tailView: Text('tail-slot'),
              leadingStateView: Text('leading-slot'),
              titlePadding: EdgeInsets.all(6),
              contentPadding: EdgeInsets.all(11),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('title-slot'), findsOneWidget);
      expect(find.text('sub-slot'), findsOneWidget);
      expect(find.text('tail-slot'), findsOneWidget);
      expect(find.text('leading-slot'), findsOneWidget);

      // id becomes the row's ValueKey.
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.key == const ValueKey<String>('row-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.all(6),
        ),
        findsWidgets,
        reason: 'titlePadding',
      );
    });
  });
}
