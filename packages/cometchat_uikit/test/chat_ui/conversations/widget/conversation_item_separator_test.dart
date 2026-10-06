/// Render-verified tests for the conversation row separator and
/// [CometChatConversationsStyle.itemStyle].
///
/// Android v6 documents `itemStyle.separatorColor` and `separatorHeight` as
/// the line between conversation rows, off by default and never drawn after
/// the last row. Here that is:
///
/// - [CometChatConversationListItemStyle.separatorColor] and
///   [CometChatConversationListItemStyle.separatorHeight], which 6.2.0 had
///   deprecated as no-ops, drawing a line along the bottom of the row.
/// - [CometChatConversationListItem.hideSeparator], which [ConversationsList]
///   sets on the last row.
/// - [CometChatConversationsStyle.itemStyle], which carries every row style
///   field from [CometChatConversations] to the rows, under the item fields
///   [CometChatConversationsStyle] carries itself.
///
/// Every test pumps the real widget and reads the built row, against a pump
/// without the prop wherever a default could coincide with the sentinel.
///
///   flutter test test/chat_ui/conversations/widget/conversation_item_separator_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

/// Ignores every event and reports nobody typing.
class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      ValueNotifier(const []);

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.name, this.uid);

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

/// A text message, read when [readAt] is set and otherwise only sent.
class _FakeTextMessage extends Mock implements TextMessage {
  _FakeTextMessage({required User from, this.readAt}) : _from = from;

  final User _from;

  @override
  final DateTime? readAt;

  @override
  DateTime? get deliveredAt => readAt;

  @override
  String? get deletedBy => null;

  @override
  User get sender => _from;

  @override
  int get parentMessageId => 0;

  @override
  int get id => 100;

  @override
  String get text => 'Hello!';

  @override
  DateTime get sentAt => DateTime(2026, 5, 12, 10, 30);

  @override
  String get type => 'text';

  @override
  String get category => 'message';

  @override
  String get receiverUid => 'u1';

  @override
  int get replyCount => 0;

  @override
  String get muid => 'muid_100';

  @override
  List<ReactionCount> get reactions => [];

  @override
  List<User> get mentionedUsers => [];

  @override
  List<String> get tags => [];
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation(this.conversationWith, this.conversationId, {this.message});

  @override
  final AppEntity conversationWith;

  @override
  final String conversationId;

  final BaseMessage? message;

  @override
  int get unreadMessageCount => 0;

  @override
  BaseMessage? get lastMessage => message;

  @override
  String get conversationType => 'user';

  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

// Sentinels no theme uses.
const _kSeparator = Color(0xFFAA1122);
const _kListSeparator = Color(0xFF33CC99);
const _kLight = Color(0xFF7A3E91);
const _kItemTitle = Color(0xFFCC7711);
const _kMappedTitle = Color(0xFF1177CC);
const _kItemRead = Color(0xFF5E2B8A);
const _kMappedRead = Color(0xFF2B8A5E);
const _kItemSent = Color(0xFF8A5E2B);
const _kTint = Color(0xFFEE22CC);

final _palette = CometChatColorPalette(
  primary: const Color(0xFF6852D6),
  textPrimary: const Color(0xFF141414),
  textSecondary: const Color(0xFF727272),
  iconSecondary: const Color(0xFFA1A1A1),
  background1: const Color(0xFFFFFFFF),
  background4: const Color(0xFFE8E8E8),
  borderLight: _kLight,
  borderDefault: const Color(0xFFDCDCDC),
  white: const Color(0xFFFFFFFF),
);

final _me = _FakeUser('Me', 'me');

Conversation _user(String name, String uid, {BaseMessage? message}) =>
    _FakeConversation(_FakeUser(name, uid), 'user_$uid', message: message);

Conversation _alice() => _user('Alice', 'u1');

/// Alice, Bob and Carol, in that order.
List<Conversation> _three() => [
  _alice(),
  _user('Bob', 'u2'),
  _user('Carol', 'u3'),
];

_MockConversationsBloc _loadedBloc(List<Conversation> conversations) {
  final bloc = _MockConversationsBloc();
  final state = ConversationsLoaded(
    conversations: conversations,
    hasMore: false,
  );
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.fromIterable([state]), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// The list item that draws [name].
Finder _row(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(CometChatConversationListItem),
);

/// The row's root container: the first [Container] under the row.
Container _rowContainer(WidgetTester tester, String name) =>
    tester.widget<Container>(
      find.descendant(of: _row(name), matching: find.byType(Container)).first,
    );

/// The row's border, or null while it draws none.
BoxBorder? _border(WidgetTester tester, String name) =>
    (_rowContainer(tester, name).decoration as BoxDecoration?)?.border;

/// The separator line along the bottom of the row, or null without one.
BorderSide? _separator(WidgetTester tester, String name) {
  final border = _border(tester, name);
  return border is Border ? border.bottom : null;
}

Color? _titleColor(WidgetTester tester, String name) =>
    tester.widget<Text>(find.text(name)).style?.color;

Color? _iconColor(WidgetTester tester, String name, IconData icon) => tester
    .widget<Icon>(find.descendant(of: _row(name), matching: find.byIcon(icon)))
    .color;

/// Asserts the row is the default one: a plain coloured box, no border.
void _expectPlainRow(WidgetTester tester, String name) {
  final container = _rowContainer(tester, name);
  expect(container.decoration, isNull);
  expect(container.color, isNotNull);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  User? previousUser;

  setUp(() => previousUser = CometChatUIKit.loggedInUser);

  tearDown(() => CometChatUIKit.loggedInUser = previousUser);

  group('CometChatConversationListItemStyle separator', () {
    testWidgets('separatorColor draws a 1 px line along the bottom', (
      tester,
    ) async {
      Future<void> pump(CometChatConversationListItemStyle? style) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                style: style,
              ),
            ),
          );
          await tester.pump();
        });
      }

      // Nothing set: the default row, a plain colour and no line.
      await pump(null);
      _expectPlainRow(tester, 'Alice');

      await pump(
        const CometChatConversationListItemStyle(separatorColor: _kSeparator),
      );
      final border = _border(tester, 'Alice')! as Border;
      expect(border.bottom.color, _kSeparator);
      expect(border.bottom.width, 1);
      // Only the bottom edge: it divides rows, it does not box them.
      expect(border.top, BorderSide.none);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
      // The background survives the switch to a decoration.
      expect(
        (_rowContainer(tester, 'Alice').decoration! as BoxDecoration).color,
        _palette.background1,
      );
    });

    testWidgets('separatorHeight sets the thickness, and 0 draws nothing', (
      tester,
    ) async {
      Future<void> pump(double height) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                style: CometChatConversationListItemStyle(
                  separatorColor: _kSeparator,
                  separatorHeight: height,
                ),
              ),
            ),
          );
          await tester.pump();
        });
      }

      await pump(3);
      expect(_separator(tester, 'Alice')?.width, 3);
      expect(_separator(tester, 'Alice')?.color, _kSeparator);

      // A zero-width BorderSide would paint a hairline, so none is built.
      await pump(0);
      _expectPlainRow(tester, 'Alice');
    });

    testWidgets('a height alone draws in the palette light border colour', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _alice(),
              onItemClick: (_) {},
              colorPalette: _palette,
              style: const CometChatConversationListItemStyle(
                separatorHeight: 2,
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_separator(tester, 'Alice')?.color, _kLight);
      expect(_separator(tester, 'Alice')?.width, 2);
    });

    testWidgets('an explicit style beats listItemStyle for the colour', (
      tester,
    ) async {
      Future<void> pump(CometChatConversationListItemStyle style) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                style: style,
                listItemStyle: const ListItemStyle(
                  separatorColor: _kListSeparator,
                ),
              ),
            ),
          );
          await tester.pump();
        });
      }

      await pump(
        const CometChatConversationListItemStyle(separatorColor: _kSeparator),
      );
      expect(_separator(tester, 'Alice')?.color, _kSeparator);

      // A style with only a height keeps listItemStyle's colour at its width.
      await pump(const CometChatConversationListItemStyle(separatorHeight: 4));
      expect(_separator(tester, 'Alice')?.color, _kListSeparator);
      expect(_separator(tester, 'Alice')?.width, 4);
    });

    testWidgets('listItemStyle.border replaces the separator line', (
      tester,
    ) async {
      final border = Border.all(color: _kTint, width: 3);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _alice(),
              onItemClick: (_) {},
              colorPalette: _palette,
              style: const CometChatConversationListItemStyle(
                separatorColor: _kSeparator,
                separatorHeight: 2,
              ),
              listItemStyle: ListItemStyle(border: border),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_border(tester, 'Alice'), border);
    });
  });

  group('CometChatConversationListItem.hideSeparator', () {
    testWidgets('leaves the line off the row, whichever style asks for it', (
      tester,
    ) async {
      Future<void> pump({required bool hideSeparator}) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                hideSeparator: hideSeparator,
                style: const CometChatConversationListItemStyle(
                  separatorColor: _kSeparator,
                ),
                listItemStyle: const ListItemStyle(
                  separatorColor: _kListSeparator,
                ),
              ),
            ),
          );
          await tester.pump();
        });
      }

      await pump(hideSeparator: false);
      expect(_separator(tester, 'Alice')?.color, _kSeparator);

      await pump(hideSeparator: true);
      _expectPlainRow(tester, 'Alice');
    });
  });

  group('ConversationsList', () {
    testWidgets('draws no separator after the last row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: ConversationsList(
                conversationsBloc: _loadedBloc(_three()),
                style: const CometChatConversationsStyle(
                  itemStyle: CometChatConversationListItemStyle(
                    separatorColor: _kSeparator,
                  ),
                ),
                statusStyle: const CometChatStatusIndicatorStyle(),
                typingStyle: const CometChatTypingIndicatorStyle(),
                receiptStyle: CometChatMessageReceiptStyle(),
                datesStyle: const CometChatDateStyle(),
                colorPalette: _palette,
                spacing: CometChatSpacing(),
                typography: const CometChatTypography(),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_separator(tester, 'Alice')?.color, _kSeparator);
      expect(_separator(tester, 'Bob')?.color, _kSeparator);
      _expectPlainRow(tester, 'Carol');
    });
  });

  group('CometChatConversationsStyle.itemStyle', () {
    testWidgets('reaches every row through CometChatConversations', (
      tester,
    ) async {
      Future<void> pump(CometChatConversationsStyle style) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              SizedBox(
                height: 600,
                child: CometChatConversations(
                  key: UniqueKey(),
                  conversationsBloc: _loadedBloc(_three()),
                  conversationsStyle: style,
                ),
              ),
            ),
          );
          await tester.pump();
        });
      }

      // Without it the rows keep their defaults: no line, theme title colour.
      await pump(const CometChatConversationsStyle());
      for (final name in ['Alice', 'Bob', 'Carol']) {
        _expectPlainRow(tester, name);
      }
      expect(_titleColor(tester, 'Alice'), isNot(_kItemTitle));

      await pump(
        const CometChatConversationsStyle(
          itemStyle: CometChatConversationListItemStyle(
            separatorColor: _kSeparator,
            separatorHeight: 2,
            titleTextColor: _kItemTitle,
          ),
        ),
      );
      for (final name in ['Alice', 'Bob']) {
        expect(_separator(tester, name)?.color, _kSeparator);
        expect(_separator(tester, name)?.width, 2);
        expect(_titleColor(tester, name), _kItemTitle);
      }
      // The last row gets the style but not the line.
      _expectPlainRow(tester, 'Carol');
      expect(_titleColor(tester, 'Carol'), _kItemTitle);
    });

    testWidgets('a field CometChatConversationsStyle carries itself wins', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: CometChatConversations(
                conversationsBloc: _loadedBloc(_three()),
                conversationsStyle: const CometChatConversationsStyle(
                  itemTitleTextColor: _kMappedTitle,
                  itemStyle: CometChatConversationListItemStyle(
                    titleTextColor: _kItemTitle,
                    separatorColor: _kSeparator,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_titleColor(tester, 'Alice'), _kMappedTitle);
      // The fields it leaves unset still come from itemStyle.
      expect(_separator(tester, 'Alice')?.color, _kSeparator);
    });

    testWidgets('its receiptStyle fills colours the list receiptStyle leaves', (
      tester,
    ) async {
      CometChatUIKit.loggedInUser = _me;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: CometChatConversations(
                conversationsBloc: _loadedBloc([
                  _user(
                    'Alice',
                    'u1',
                    message: _FakeTextMessage(
                      from: _me,
                      readAt: DateTime(2026, 5, 12, 10, 32),
                    ),
                  ),
                  _user('Bob', 'u2', message: _FakeTextMessage(from: _me)),
                ]),
                conversationsStyle: CometChatConversationsStyle(
                  receiptStyle: CometChatMessageReceiptStyle(
                    readIconColor: _kMappedRead,
                  ),
                  itemStyle: CometChatConversationListItemStyle(
                    receiptStyle: CometChatMessageReceiptStyle(
                      readIconColor: _kItemRead,
                      sentIconColor: _kItemSent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_iconColor(tester, 'Alice', Icons.done_all), _kMappedRead);
      expect(_iconColor(tester, 'Bob', Icons.done), _kItemSent);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('copyWith, merge and lerp carry it', () {
      const first = CometChatConversationListItemStyle(
        separatorColor: _kSeparator,
      );
      const second = CometChatConversationListItemStyle(
        separatorColor: _kListSeparator,
      );
      const style = CometChatConversationsStyle(itemStyle: first);

      expect(style.copyWith().itemStyle, first);
      expect(style.copyWith(itemStyle: second).itemStyle, second);
      expect(style.merge(null).itemStyle, first);
      expect(style.merge(const CometChatConversationsStyle()).itemStyle, first);
      expect(
        style
            .merge(const CometChatConversationsStyle(itemStyle: second))
            .itemStyle,
        second,
      );
      const other = CometChatConversationsStyle(itemStyle: second);
      expect(style.lerp(other, 0.25).itemStyle, first);
      expect(style.lerp(other, 0.75).itemStyle, second);
    });
  });
}
