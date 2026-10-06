/// Render-verified prop matrix for [CometChatConversationsStyle] — Track 3
/// PROP1.
///
/// Companion to `conversations_props_test.dart`, which covers
/// `CometChatConversations` itself. 44 style props.
///
/// `mentionsStyle` is pinned as construction-only: it is declared and read
/// nowhere, and unlike the other dead style props it has no receiver to wire
/// it to — the conversation subtitle builds its formatter chain without one.
/// ENG-39121.
///
///   flutter test test/chat_ui/conversations/widget/conversations_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  final _typing = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier(const []));

  @override
  List<TypingIndicator> getTypingIndicators(String id) => const [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

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
  DateTime? get deliveredAt => DateTime.fromMillisecondsSinceEpoch(1700000001);
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
}

class FakeConversation extends Fake implements Conversation {
  FakeConversation({
    required this.conversationWith,
    this.conversationId = 'user_u1',
    this.unreadMessageCount = 2,
  });
  @override
  final String conversationId;
  @override
  final AppEntity conversationWith;
  @override
  final int unreadMessageCount;
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

List<Conversation> _conversations() => [
  FakeConversation(
    conversationWith: FakeUser(name: 'Alice', uid: 'u1'),
  ),
  FakeConversation(
    conversationWith: FakeGroup(name: 'Design', guid: 'g1', type: 'private'),
    conversationId: 'group_g1',
  ),
  FakeConversation(
    conversationWith: FakeGroup(name: 'Leads', guid: 'g2', type: 'password'),
    conversationId: 'group_g2',
  ),
];

MockConversationsBloc _blocIn(ConversationsState state) {
  final bloc = MockConversationsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(
    bloc,
    Stream<ConversationsState>.value(state),
    initialState: state,
  );
  return bloc;
}

MockConversationsBloc _loaded({Set<String> selected = const {}}) => _blocIn(
  ConversationsLoaded(
    conversations: _conversations(),
    hasMore: false,
    selectedConversations: selected,
  ),
);

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

ListBaseStyle _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

ConversationsList _list(WidgetTester tester) =>
    tester.widget<ConversationsList>(find.byType(ConversationsList));

CometChatConversationListItemStyle _itemStyle(WidgetTester tester) => tester
    .widgetList<CometChatConversationListItem>(
      find.byType(CometChatConversationListItem),
    )
    .first
    .style!;

List<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>()
    .toList();

void main() {
  // ===========================================================================
  group('container and chrome', () {
    testWidgets('background, border, radius, title and back icon', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(),
              title: 'Chats',
              conversationsStyle: const CometChatConversationsStyle(
                backgroundColor: _c1,
                border: Border.fromBorderSide(BorderSide(color: _c2, width: 3)),
                borderRadius: BorderRadius.all(Radius.circular(18)),
                backIconColor: _c3,
                titleTextColor: _c4,
                titleTextStyle: TextStyle(fontSize: 29),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final s = _listBaseStyle(tester);
      expect(s.background, _c1);
      expect((s.border as Border?)?.top.color, _c2);
      expect(s.borderRadius, const BorderRadius.all(Radius.circular(18)));
      expect(s.backIconTint, _c3);
      expect(s.titleStyle?.color, _c4);
      expect(s.titleStyle?.fontSize, 29);
    });

    testWidgets('separatorColor and separatorHeight draw the appbar rule', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                separatorColor: _c5,
                separatorHeight: 4,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final shape = _listBaseStyle(tester).appBarShape as Border?;
      expect(shape?.bottom.color, _c5);
      expect(shape?.bottom.width, 4);
    });

    testWidgets('the six search props reach the search field', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(),
              // hideSearch defaults to true on this component.
              hideSearch: false,
              conversationsStyle: const CometChatConversationsStyle(
                searchIconColor: _c1,
                searchBackgroundColor: _c2,
                searchBorder: BorderSide(color: _c3, width: 2),
                searchBorderRadius: BorderRadius.all(Radius.circular(11)),
                searchPlaceHolderTextColor: _c4,
                searchPlaceHolderTextStyle: TextStyle(fontSize: 17),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final s = _listBaseStyle(tester);
      expect(s.searchIconTint, _c1);
      expect(s.searchBoxBackground, _c2);
      expect(s.borderSide?.color, _c3);
      expect(s.borderSide?.width, 2);
      expect(
        s.searchTextFieldRadius,
        const BorderRadius.all(Radius.circular(11)),
      );
      expect(s.searchPlaceholderStyle?.color, _c4);
      expect(s.searchPlaceholderStyle?.fontSize, 17);
    });

    testWidgets('submitIconColor tints the submit affordance', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: {'user_u1'}),
              selectionMode: SelectionMode.multiple,
              conversationsStyle: const CometChatConversationsStyle(
                submitIconColor: _c6,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, _c6);
    });
  });

  // ===========================================================================
  group('rows', () {
    testWidgets('item title and subtitle styling reaches the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                itemTitleTextColor: _c1,
                itemTitleTextStyle: TextStyle(fontSize: 23),
                itemSubtitleTextColor: _c2,
                itemSubtitleTextStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final s = _itemStyle(tester);
      expect(s.titleTextColor, _c1);
      expect(s.titleTextStyle?.fontSize, 23);
      expect(s.subtitleTextColor, _c2);
      expect(s.subtitleTextStyle?.fontSize, 13);
    });

    testWidgets('messageTypeIconColor tints the subtitle type icon', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                messageTypeIconColor: _c3,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      // ConversationsSubtitleView reads it directly.
      expect(_list(tester).style.messageTypeIconColor, _c3);
    });

    testWidgets('avatarStyle and badgeStyle reach the list', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c4),
                badgeStyle: CometChatBadgeStyle(backgroundColor: _c5),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final avatars = tester.widgetList<CometChatAvatar>(
        find.byType(CometChatAvatar),
      );
      expect(avatars, isNotEmpty);
      expect(avatars.first.style?.backgroundColor, _c4);

      final badges = tester.widgetList<CometChatBadge>(
        find.byType(CometChatBadge),
      );
      expect(badges, isNotEmpty);
      expect(badges.first.style.backgroundColor, _c5);
    });

    testWidgets('the four merged sub-styles reach the list', (tester) async {
      // statusIndicator / typing / receipt / date are merged over the ambient
      // theme in didChangeDependencies, then handed to ConversationsList.
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: CometChatConversationsStyle(
                statusIndicatorStyle: const CometChatStatusIndicatorStyle(
                  backgroundColor: _c1,
                ),
                typingIndicatorStyle: const CometChatTypingIndicatorStyle(
                  textStyle: TextStyle(fontSize: 31),
                ),
                // CometChatMessageReceiptStyle has no const constructor, so
                // the whole style is built non-const rather than grafted on
                // with copyWith — copyWith does not register as passing the
                // prop to the construction under test.
                receiptStyle: CometChatMessageReceiptStyle(readIconColor: _c2),
                dateStyle: const CometChatDateStyle(textColor: _c3),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final list = _list(tester);
      expect(list.statusStyle.backgroundColor, _c1);
      expect(list.typingStyle.textStyle?.fontSize, 31);
      expect(list.receiptStyle.readIconColor, _c2);
      expect(list.datesStyle.textColor, _c3);
    });

    testWidgets('FIXED — the two group-badge backgrounds reach the row', (
      tester,
    ) async {
      // ENG-39121: both were declared and never read.
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                privateGroupIconBackground: _c5,
                protectedGroupIconBackground: _c6,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final rows = tester.widgetList<CometChatConversationListItem>(
        find.byType(CometChatConversationListItem),
      );
      expect(rows.first.privateGroupIconBackground, _c5);
      expect(rows.first.protectedGroupIconBackground, _c6);
    });
  });

  // ===========================================================================
  group('selection', () {
    testWidgets('every checkbox prop reaches the row style', (tester) async {
      // checkBoxBorder, checkboxSelectedIconColor and
      // listItemSelectedBackgroundColor were dead until ENG-39121.
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: {'user_u1'}),
              selectionMode: SelectionMode.multiple,
              conversationsStyle: const CometChatConversationsStyle(
                checkBoxBackgroundColor: _c1,
                checkBoxCheckedBackgroundColor: _c2,
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
                checkBoxBorder: BorderSide(color: _c3, width: 2.5),
                checkboxSelectedIconColor: _c4,
                listItemSelectedBackgroundColor: _c5,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final s = _itemStyle(tester);
      expect(s.checkBoxBackgroundColor, _c1);
      expect(s.checkBoxCheckedBackgroundColor, _c2);
      expect(
        s.checkBoxBorderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
      expect(s.checkBoxStrokeColor, _c3);
      expect(s.checkBoxStrokeWidth, 2.5);
      expect(s.checkBoxSelectIconTint, _c4);
      expect(s.selectedBackgroundColor, _c5);
    });
  });

  // ===========================================================================
  group('states and dialog', () {
    testWidgets('the four empty-state text props apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _blocIn(const ConversationsEmpty()),
              conversationsStyle: const CometChatConversationsStyle(
                emptyStateTextColor: _c1,
                emptyStateTextStyle: TextStyle(fontSize: 26),
                emptyStateSubTitleTextColor: _c2,
                emptyStateSubTitleTextStyle: TextStyle(fontSize: 15),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final styles = _textStyles(tester);
      expect(styles.any((s) => s.color == _c1 && s.fontSize == 26), isTrue);
      expect(styles.any((s) => s.color == _c2 && s.fontSize == 15), isTrue);
    });

    testWidgets('the four error-state text props apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _blocIn(
                const ConversationsError(message: 'boom'),
              ),
              conversationsStyle: const CometChatConversationsStyle(
                errorStateTextColor: _c3,
                errorStateTextStyle: TextStyle(fontSize: 26),
                errorStateSubTitleTextColor: _c4,
                errorStateSubTitleTextStyle: TextStyle(fontSize: 15),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      final styles = _textStyles(tester);
      expect(styles.any((s) => s.color == _c3 && s.fontSize == 26), isTrue);
      expect(styles.any((s) => s.color == _c4 && s.fontSize == 15), isTrue);
    });

    testWidgets('deleteConversationDialogStyle reaches the confirm dialog', (
      tester,
    ) async {
      // Asserted on the style the component resolved rather than by driving
      // the dialog open: reaching it means long-pressing a row, which builds
      // the delete overlay, and that overlay overflows by design of its fixed
      // 120px button (ENG-39117). Driving it would fail this case for a reason
      // unrelated to the prop under test.
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _loaded(selected: const {}),
              conversationsStyle: const CometChatConversationsStyle(
                deleteConversationDialogStyle: CometChatConfirmDialogStyle(
                  backgroundColor: _c6,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(
        _list(tester).style.deleteConversationDialogStyle?.backgroundColor,
        _c6,
      );
    });
  });

  // ===========================================================================
  group('DEFECT — mentionsStyle is never read (ENG-39121)', () {
    // Constructed, not pumped: exercised without inflating the numerator.
    // Unlike the other eight dead style props on this component, this one has
    // no receiver — the conversation subtitle builds its formatter chain
    // without taking a mentions style, so wiring it is a feature rather than a
    // one-line map.
    test('mentionsStyle is accepted and discarded', () {
      final style = CometChatConversationsStyle(
        mentionsStyle: CometChatMentionsStyle(),
      );

      expect(style.mentionsStyle, isNotNull);
    });
  });
}
