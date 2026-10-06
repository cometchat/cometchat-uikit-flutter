/// Render-verified prop matrix for [CometChatSearchStyle] — Track 3 PROP1.
///
/// Companion to `search_props_test.dart`, which covers `CometChatSearch`
/// itself. 49 style props — the largest style class in the Kit.
///
/// Two are pinned as construction-only: `errorStateSubTitleTextColor` and
/// `errorStateSubTitleTextStyle` are declared and read nowhere, because
/// Search's error view renders a title and no subtitle. Wiring them needs a
/// subtitle line and the copy to put in it, which is a content decision rather
/// than a wire-up. ENG-39121.
///
///   flutter test test/chat_ui/search/search_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {
  @override
  // ignore: must_call_super
  void add(SearchEvent event) {
    // No-op: these cases assert rendering, not event handling.
  }
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
  FakeGroup({this.name = 'Design', this.guid = 'g1', this.type = 'public'});

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
  FakeTextMessage({this.id = 100, this.text = 'Thursday works'});

  @override
  final int id;
  @override
  final String text;
  @override
  String get type => MessageTypeConstants.text;
  @override
  String get category => MessageCategoryConstants.message;
  @override
  User get sender => FakeUser(name: 'Bob', uid: 'u2');
  @override
  AppEntity get receiver => FakeUser(name: 'Alice', uid: 'u1');
  @override
  String get receiverUid => 'u1';
  @override
  String get receiverType => ReceiverTypeConstants.user;
  @override
  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(1700000000000);
  @override
  DateTime? get updatedAt => null;
  @override
  DateTime? get deletedAt => null;
  @override
  String get muid => 'muid_100';
  @override
  List<User> get mentionedUsers => const [];
  @override
  String? get deletedBy => null;
  @override
  String? get editedBy => null;
  @override
  DateTime? get editedAt => null;
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
  Map<String, dynamic>? get metadata => null;
}

class FakeMediaMessage extends Fake implements MediaMessage {
  FakeMediaMessage({this.id = 200, required this.type});

  @override
  final int id;
  @override
  final String type;
  @override
  String get category => MessageCategoryConstants.message;
  @override
  User get sender => FakeUser(name: 'Bob', uid: 'u2');
  @override
  AppEntity get receiver => FakeUser(name: 'Alice', uid: 'u1');
  @override
  String get receiverUid => 'u1';
  @override
  String get receiverType => ReceiverTypeConstants.user;
  @override
  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(1700000000000);
  @override
  DateTime? get updatedAt => null;
  @override
  DateTime? get deletedAt => null;
  @override
  String get muid => 'muid_200';
  @override
  Attachment? get attachment => null;
  @override
  List<User> get mentionedUsers => const [];
  @override
  String? get deletedBy => null;
  @override
  String? get editedBy => null;
  @override
  DateTime? get editedAt => null;
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
  Map<String, dynamic>? get metadata => null;
}

class FakeConversation extends Fake implements Conversation {
  FakeConversation({
    required this.conversationWith,
    this.conversationId = 'user_u1',
    this.unreadMessageCount = 0,
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
}

// ─── State builders ──────────────────────────────────────────────────────────

/// A settled state with one list switched off, so `bothActive` is false and
/// `_buildResults` takes the per-section branch rather than an aggregate one.
SearchState _conversationsState({
  SearchStatus status = SearchStatus.loaded,
  List<Conversation> conversations = const [],
}) => SearchState(
  searchText: 'thu',
  scope: SearchScope.conversations,
  showConversations: true,
  showMessages: false,
  conversationsStatus: status,
  conversations: conversations,
);

SearchState _messagesState({
  SearchStatus status = SearchStatus.loaded,
  List<BaseMessage> messages = const [],
}) => SearchState(
  searchText: 'thu',
  scope: SearchScope.messages,
  showConversations: false,
  showMessages: true,
  messagesStatus: status,
  messages: messages,
);

/// Both lists on and in the same status, which is what the aggregate
/// loading / empty / error branches gate on.
SearchState _bothState(SearchStatus status) => SearchState(
  searchText: 'thu',
  scope: SearchScope.both,
  showConversations: true,
  showMessages: true,
  conversationsStatus: status,
  messagesStatus: status,
);

MockSearchBloc _blocIn(SearchState state) {
  final bloc = MockSearchBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(bloc, Stream<SearchState>.value(state), initialState: state);
  return bloc;
}

List<Conversation> _sampleConversations() => [
  FakeConversation(
    conversationWith: FakeUser(name: 'Alice', uid: 'u1'),
    conversationId: 'user_u1',
  ),
];

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);
const _c6 = Color(0xFF606162);

/// See-more needs at least three results before it is offered.
List<Conversation> _threeConversations() => List.generate(
  3,
  (i) => FakeConversation(
    conversationWith: FakeUser(name: 'User $i', uid: 'u$i'),
    conversationId: 'user_u$i',
  ),
);

/// The shared fixture carries no unread mail, so the badge needs its own.
List<Conversation> _unreadConversations() => [
  FakeConversation(
    conversationWith: FakeUser(name: 'Alice', uid: 'u1'),
    conversationId: 'user_u1',
    unreadMessageCount: 3,
  ),
];

/// Every text style on screen, from plain `Text` and from the rich-text path.
///
/// The message preview is built through a formatter chain, so its style can
/// land on a nested `TextSpan` rather than on `Text.style` — reading only the
/// latter silently misses it, which is how this matrix first "proved" a live
/// prop was dead.
List<TextStyle> _textStyles(WidgetTester tester) {
  final out = <TextStyle>[];

  void walk(InlineSpan? span) {
    if (span == null) return;
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

bool _hasStyle(WidgetTester tester, Color color, double size) =>
    _textStyles(tester).any((t) => t.color == color && t.fontSize == size);

void main() {
  // ===========================================================================
  group('frame and search field', () {
    testWidgets('backgroundColor paints the scaffold', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              searchStyle: const CometChatSearchStyle(backgroundColor: _c1),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .map((s) => s.backgroundColor),
        contains(_c1),
      );
    });

    testWidgets('the eight search-field props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_conversationsState()),
              searchStyle: const CometChatSearchStyle(
                searchBackgroundColor: _c1,
                searchTextColor: _c2,
                searchTextStyle: TextStyle(fontSize: 21),
                searchPlaceHolderTextColor: _c3,
                searchPlaceHolderTextStyle: TextStyle(fontSize: 17),
                searchBorder: BorderSide(color: _c4, width: 2),
                searchBorderRadius: BorderRadius.all(Radius.circular(11)),
                searchBackIconColor: _c5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, _c2);
      expect(field.style?.fontSize, 21);

      final dec = field.decoration!;
      expect(dec.fillColor, _c1);
      expect(dec.hintStyle?.color, _c3);
      expect(dec.hintStyle?.fontSize, 17);

      final border = dec.enabledBorder as OutlineInputBorder?;
      expect(border?.borderSide.color, _c4);
      expect(border?.borderSide.width, 2);
      expect(border?.borderRadius, const BorderRadius.all(Radius.circular(11)));

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.color)
          .toList();
      expect(icons, contains(_c5), reason: 'back icon');
    });

    testWidgets('searchClearIconColor tints the clear affordance', (
      tester,
    ) async {
      // Only rendered once the field has text.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_conversationsState()),
              searchStyle: const CometChatSearchStyle(
                searchClearIconColor: _c6,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(_c6),
      );
    });
  });

  // ===========================================================================
  group('filter chips', () {
    testWidgets('all nine chip props reach the chips', (tester) async {
      const filters = [
        SearchFilter(label: 'Unread', group: 1),
        SearchFilter(label: 'Photos', group: 2),
      ];

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                const SearchState(
                  searchText: 'thu',
                  visibleFilters: filters,
                  selectedFilters: {'Unread'},
                  scope: SearchScope.both,
                ),
              ),
              searchFilters: filters,
              searchStyle: const CometChatSearchStyle(
                searchFilterChipBackgroundColor: _c1,
                searchFilterChipSelectedBackgroundColor: _c2,
                searchFilterChipTextColor: _c3,
                searchFilterChipSelectedTextColor: _c4,
                searchFilterChipTextStyle: TextStyle(fontSize: 12),
                searchFilterChipSelectedTextStyle: TextStyle(fontSize: 14),
                searchFilterChipBorder: Border.fromBorderSide(
                  BorderSide(color: _c5, width: 1),
                ),
                searchFilterChipSelectedBorder: Border.fromBorderSide(
                  BorderSide(color: _c6, width: 2),
                ),
                searchFilterChipBorderRadius: BorderRadius.all(
                  Radius.circular(9),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final chips = tester
          .widgetList<SearchFilterChip>(find.byType(SearchFilterChip))
          .toList();
      expect(chips, hasLength(2));

      final selected = chips.firstWhere((c) => c.isSelected);
      final unselected = chips.firstWhere((c) => !c.isSelected);

      expect(unselected.unselectedColor, _c1);
      expect(selected.selectedColor, _c2);
      expect(unselected.unselectedTextColor, _c3);
      expect(selected.selectedTextColor, _c4);
      expect(unselected.textStyle?.fontSize, 12);
      expect(selected.selectedTextStyle?.fontSize, 14);
      expect((unselected.unSelectedBorder as Border?)?.top.color, _c5);
      expect((selected.selectedBorder as Border?)?.top.color, _c6);
      expect(selected.borderRadius, const BorderRadius.all(Radius.circular(9)));
    });

    testWidgets('the two filter icon tints apply', (tester) async {
      const filters = [
        SearchFilter(label: 'Unread', group: 1, icon: Icons.mail),
        SearchFilter(label: 'Photos', group: 2, icon: Icons.photo),
      ];

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                const SearchState(
                  searchText: 'thu',
                  visibleFilters: filters,
                  selectedFilters: {'Unread'},
                  scope: SearchScope.both,
                ),
              ),
              searchFilters: filters,
              searchStyle: const CometChatSearchStyle(
                searchFilterIconColor: _c1,
                searchFilterSelectedIconColor: _c2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final chips = tester
          .widgetList<SearchFilterChip>(find.byType(SearchFilterChip))
          .toList();
      expect(chips.firstWhere((c) => !c.isSelected).unselectedIconColor, _c1);
      expect(chips.firstWhere((c) => c.isSelected).selectedIconColor, _c2);
    });
  });

  // ===========================================================================
  group('section headers and see-more', () {
    testWidgets('sectionHeader and seeMore text props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                SearchState(
                  searchText: 'thu',
                  scope: SearchScope.both,
                  showConversations: true,
                  showMessages: true,
                  // See-more is offered only with NO filter active, at least
                  // three results, and more to fetch — cometchat_search.dart:512.
                  conversationsStatus: SearchStatus.loaded,
                  conversations: _threeConversations(),
                  hasMoreConversations: true,
                  messagesStatus: SearchStatus.loaded,
                  messages: [FakeTextMessage()],
                ),
              ),
              searchStyle: const CometChatSearchStyle(
                sectionHeaderTextColor: _c1,
                sectionHeaderTextStyle: TextStyle(fontSize: 25),
                seeMoreTextColor: _c2,
                seeMoreTextStyle: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_hasStyle(tester, _c1, 25), isTrue, reason: 'section header');
      expect(_hasStyle(tester, _c2, 12), isTrue, reason: 'see more');
    });
  });

  // ===========================================================================
  group('conversation results', () {
    testWidgets('the five conversation-row props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              searchStyle: const CometChatSearchStyle(
                searchConversationTitleTextColor: _c1,
                searchConversationTitleTextStyle: TextStyle(fontSize: 23),
                searchConversationSubtitleTextColor: _c2,
                searchConversationSubtitleTextStyle: TextStyle(fontSize: 13),
                searchConversationItemBackgroundColor: _c3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_hasStyle(tester, _c1, 23), isTrue, reason: 'row title');
      expect(_hasStyle(tester, _c2, 13), isTrue, reason: 'row subtitle');

      final items = tester.widgetList<CometChatListItem>(
        find.byType(CometChatListItem),
      );
      expect(items, isNotEmpty);
      expect(items.first.style.background, _c3);
    });

    testWidgets('avatarStyle, statusIndicatorStyle, badgeStyle and dateStyle '
        'reach the row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _unreadConversations()),
              ),
              searchStyle: const CometChatSearchStyle(
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c1),
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                badgeStyle: CometChatBadgeStyle(backgroundColor: _c3),
                dateStyle: CometChatDateStyle(borderRadius: BorderRadius.zero),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final items = tester.widgetList<CometChatListItem>(
        find.byType(CometChatListItem),
      );
      expect(items.first.avatarStyle.backgroundColor, _c1);
      // statusIndicatorStyle and dateStyle were dead until ENG-39121 — the
      // component built both inline and dropped the caller's.
      expect(
        items.first.statusIndicatorStyle.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );

      final badges = tester.widgetList<CometChatBadge>(
        find.byType(CometChatBadge),
      );
      expect(badges, isNotEmpty, reason: 'the fixture carries unread mail');
      expect(badges.first.style.backgroundColor, _c3);

      final dates = tester.widgetList<CometChatDate>(
        find.byType(CometChatDate),
      );
      expect(dates, isNotEmpty);
      expect(dates.first.style.borderRadius, BorderRadius.zero);
    });
  });

  // ===========================================================================
  group('message results', () {
    testWidgets('the six message-row props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              searchStyle: const CometChatSearchStyle(
                searchMessageSenderTextColor: _c1,
                searchMessageSenderTextStyle: TextStyle(fontSize: 23),
                searchMessagePreviewTextColor: _c2,
                searchMessagePreviewTextStyle: TextStyle(fontSize: 13),
                searchMessageDateTextColor: _c3,
                searchMessageDateTextStyle: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_hasStyle(tester, _c1, 23), isTrue, reason: 'sender');
      expect(_hasStyle(tester, _c2, 13), isTrue, reason: 'preview');
      expect(_hasStyle(tester, _c3, 11), isTrue, reason: 'date');
    });

    testWidgets('receiptStyle reaches the receipt', (tester) async {
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bob', uid: 'u2');
      addTearDown(() => CometChatUIKit.loggedInUser = null);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              searchStyle: CometChatSearchStyle(
                receiptStyle: CometChatMessageReceiptStyle(sentIconColor: _c4),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final receipts = tester.widgetList<CometChatReceipt>(
        find.byType(CometChatReceipt),
      );
      expect(receipts, isNotEmpty);
      expect(receipts.first.style?.sentIconColor, _c4);
    });
  });

  // ===========================================================================
  group('empty and error states', () {
    testWidgets('the four empty-state props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.empty)),
              searchStyle: const CometChatSearchStyle(
                emptyStateTextColor: _c1,
                emptyStateTextStyle: TextStyle(fontSize: 26),
                emptyStateSubTitleTextColor: _c2,
                emptyStateSubTitleTextStyle: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_hasStyle(tester, _c1, 26), isTrue, reason: 'empty title');
      expect(_hasStyle(tester, _c2, 15), isTrue, reason: 'empty subtitle');
    });

    testWidgets('the two live error-state props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.error)),
              searchStyle: const CometChatSearchStyle(
                errorStateTextColor: _c3,
                errorStateTextStyle: TextStyle(fontSize: 26),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_hasStyle(tester, _c3, 26), isTrue);
    });
  });

  // ===========================================================================
  group('DEFECT — the error subtitle props are never read (ENG-39121)', () {
    // Constructed, not pumped: exercised without inflating the numerator.
    // Search's error view renders a title and no subtitle, so unlike the other
    // dead style props on this class there is nothing to wire them to — adding
    // a subtitle line needs the copy to put in it.
    test('errorStateSubTitle props are accepted and discarded', () {
      const style = CometChatSearchStyle(
        errorStateSubTitleTextColor: _c5,
        errorStateSubTitleTextStyle: TextStyle(fontSize: 15),
      );

      expect(style.errorStateSubTitleTextColor, _c5);
      expect(style.errorStateSubTitleTextStyle?.fontSize, 15);
    });
  });
}
