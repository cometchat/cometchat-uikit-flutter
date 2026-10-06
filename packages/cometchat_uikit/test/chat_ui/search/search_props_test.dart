/// Render-verified prop matrix for [CometChatSearch] — Track 3 PROP1.
///
/// This matrix could not exist until ENG-39114 landed. `CometChatSearch` built
/// its bloc in `initState` and passed it explicitly to every builder
/// (`bloc: _searchBloc`), so an ambient `BlocProvider` could not stand in and
/// `emit` is protected — most of the component's props had no reachable state
/// to render from. The `searchBloc` parameter added by that fix is what makes
/// everything below possible, and it is the seam its three siblings always had.
///
/// Unlike Users/Groups/Conversations, `SearchState` is one concrete class
/// carrying two independent result sets, so the states here are built directly
/// rather than picked from a sealed family. Two flags decide which branch of
/// `_buildResults` runs: `bothActive` (showConversations && showMessages &&
/// scope == both) selects the aggregate loading/empty/error views, and turning
/// one list off selects the per-section ones.
///
/// 36 props are in scope, 31 render-verified. The five that remain — `user`,
/// `group`, `searchIn`, `conversationsRequestBuilder` and
/// `messagesRequestBuilder` — are read only where the component builds its own
/// bloc, which every case here replaces, so they are pinned as
/// construction-only. Pumping them anyway would score as render-verified while
/// proving nothing.
///
///   flutter test test/chat_ui/search/search_props_test.dart
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

void main() {
  // ===========================================================================
  group('the seam itself (ENG-39114)', () {
    testWidgets('an injected bloc drives the component', (tester) async {
      // The whole matrix rests on this: if searchBloc were ignored, the
      // component would build its own bloc, reach the SDK, and this initial
      // state would never render.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              initialStateView: (context) => const Text('injected-initial'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('injected-initial'), findsOneWidget);
    });

    testWidgets('an injected bloc is not closed on dispose', (tester) async {
      // The caller owns it. Closing someone else's bloc is the classic bug
      // this guard exists to prevent, and it only shows up on teardown.
      final bloc = _blocIn(const SearchState());
      await mockNetworkImagesFor(
        () => tester.pumpWidget(_wrap(CometChatSearch(searchBloc: bloc))),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      verifyNever(() => bloc.close());
    });
  });

  // ===========================================================================
  group('chrome — back and clear affordances', () {
    testWidgets('searchBackIcon replaces the default back icon', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              searchBackIcon: const Text('back-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('back-glyph'), findsOneWidget);
    });

    testWidgets('onBack fires from the back affordance', (tester) async {
      var backs = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              searchBackIcon: const Text('back-glyph'),
              onBack: () => backs++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('back-glyph'));
      await tester.pump();

      expect(backs, 1);
    });

    testWidgets('searchClearIcon appears once the field has text', (
      tester,
    ) async {
      // The suffix rebuilds on searchText.isEmpty flipping, so the clear
      // affordance is absent in the initial state and present here.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_conversationsState()),
              searchClearIcon: const Text('clear-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('clear-glyph'), findsOneWidget);
    });

    testWidgets('searchClearIcon is absent while the field is empty', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              searchClearIcon: const Text('clear-glyph'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('clear-glyph'), findsNothing);
    });
  });

  // ===========================================================================
  group('state views', () {
    testWidgets('initialStateView renders before anything is typed', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              initialStateView: (context) => const Text('custom-initial'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-initial'), findsOneWidget);
    });

    testWidgets('loadingStateView replaces the spinner', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.loading)),
              loadingStateView: (context) => const Text('custom-loading'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-loading'), findsOneWidget);
    });

    testWidgets('emptyStateView replaces the no-results view', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.empty)),
              emptyStateView: (context) => const Text('custom-empty'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-empty'), findsOneWidget);
    });

    testWidgets('errorStateView replaces the error view', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.error)),
              errorStateView: (context) => const Text('custom-error'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom-error'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('conversation result slots', () {
    testWidgets('conversationItemView replaces the whole row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationItemView: (context, conversation) =>
                  Text('row-${conversation.conversationId}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-user_u1'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('conversationTitleView replaces the title', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationTitleView: (context, conversation) =>
                  const Text('title-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('title-slot'), findsOneWidget);
    });

    testWidgets('conversationLeadingView replaces the avatar area', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationLeadingView: (context, conversation) =>
                  const Text('leading-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('leading-slot'), findsOneWidget);
    });

    testWidgets('conversationSubtitleView replaces the subtitle', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationSubtitleView: (context, conversation) =>
                  const Text('subtitle-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('subtitle-slot'), findsOneWidget);
    });

    testWidgets('conversationTailView replaces the tail', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationTailView: (context, conversation) =>
                  const Text('tail-slot'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('tail-slot'), findsOneWidget);
    });

    testWidgets('onConversationClicked fires with the tapped conversation', (
      tester,
    ) async {
      Conversation? tapped;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              conversationItemView: (context, conversation) =>
                  const Text('row-slot'),
              onConversationClicked: (conversation) => tapped = conversation,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('row-slot'));
      await tester.pump();

      expect(tapped?.conversationId, 'user_u1');
    });
  });

  // ===========================================================================
  group('message result slots', () {
    testWidgets('searchTextMessageView replaces a text result', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              searchTextMessageView: (context, message) =>
                  Text('text-${message.id}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('text-100'), findsOneWidget);
    });

    for (final entry in <String, String>{
      'image': MessageTypeConstants.image,
      'video': MessageTypeConstants.video,
      'file': MessageTypeConstants.file,
      'audio': MessageTypeConstants.audio,
    }.entries) {
      testWidgets('search${entry.key}MessageView replaces a ${entry.key} '
          'result', (tester) async {
        // The dispatch at cometchat_search.dart:786-797 keys on message.type,
        // so each slot is checked against a message of exactly its own type —
        // a shared fixture would let one slot cover for another.
        final message = FakeMediaMessage(type: entry.value);
        final state = _messagesState(messages: [message]);
        Widget slot(BuildContext context, MediaMessage m) =>
            Text('${entry.key}-${m.id}');

        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatSearch(
                searchBloc: _blocIn(state),
                searchImageMessageView:
                    entry.value == MessageTypeConstants.image ? slot : null,
                searchVideoMessageView:
                    entry.value == MessageTypeConstants.video ? slot : null,
                searchFileMessageView: entry.value == MessageTypeConstants.file
                    ? slot
                    : null,
                searchAudioMessageView:
                    entry.value == MessageTypeConstants.audio ? slot : null,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('${entry.key}-200'), findsOneWidget);
      });
    }

    testWidgets('onMessageClicked fires with the tapped message', (
      tester,
    ) async {
      BaseMessage? tapped;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              searchTextMessageView: (context, message) =>
                  const Text('msg-slot'),
              onMessageClicked: (message) => tapped = message,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('msg-slot'));
      await tester.pump();

      expect(tapped?.id, 100);
    });
  });

  // ===========================================================================
  group('filters and style', () {
    testWidgets('searchFilters render as chips', (tester) async {
      const filters = [
        SearchFilter(label: 'Unread', group: 1),
        SearchFilter(label: 'Photos', group: 2),
      ];

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                SearchState(
                  searchText: 'thu',
                  visibleFilters: filters,
                  scope: SearchScope.both,
                ),
              ),
              searchFilters: filters,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SearchFilterChip), findsNWidgets(2));
      expect(find.text('Unread'), findsOneWidget);
    });

    testWidgets('searchStyle reaches the scaffold background', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(const SearchState()),
              searchStyle: const CometChatSearchStyle(
                backgroundColor: Color(0xFFEDF2F2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scaffolds = tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .map((s) => s.backgroundColor);
      expect(scaffolds, contains(const Color(0xFFEDF2F2)));
    });
  });

  // ===========================================================================
  group('presence, group type and date formatting', () {
    testWidgets('usersStatusVisibility false drops the presence dot', (
      tester,
    ) async {
      int dots() => find.byType(CometChatStatusIndicator).evaluate().length;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final withStatus = dots();

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              usersStatusVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(withStatus, greaterThan(dots()));
    });

    testWidgets('groupTypeVisibility false drops the group badge', (
      tester,
    ) async {
      List<Conversation> groupConversation() => [
        FakeConversation(
          conversationWith: FakeGroup(
            name: 'Design',
            guid: 'g1',
            type: 'private',
          ),
          conversationId: 'group_g1',
        ),
      ];

      int badges() => find.byType(CometChatStatusIndicator).evaluate().length;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: groupConversation()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final withBadge = badges();

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: groupConversation()),
              ),
              groupTypeVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(withBadge, greaterThan(badges()));
    });

    testWidgets('timeSeparatorFormatterCallback reaches the result date', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              timeSeparatorFormatterCallback: _StubDateFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      final dates = tester.widgetList<CometChatDate>(
        find.byType(CometChatDate),
      );
      expect(dates, isNotEmpty);
      expect(dates.first.dateTimeFormatterCallback, isA<_StubDateFormatter>());
    });

    testWidgets('dateSeparatorFormatterCallback.otherDays labels the month '
        'separator', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              dateSeparatorFormatterCallback: _MonthLabelFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('stub-month'), findsOneWidget);
    });

    testWidgets('a dateSeparatorFormatterCallback without otherDays keeps the '
        'month label, not a time of day', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              dateSeparatorFormatterCallback: _TimeOnlyFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('stub-time'), findsNothing);
      expect(
        find.textContaining(RegExp(r'^[A-Z][a-z]+, \d{4}$')),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  group('the state-reporting callbacks', () {
    testWidgets('onConversationsLoad reports the loaded list', (tester) async {
      final reported = <List<Conversation>>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              onConversationsLoad: (conversations) =>
                  reported.add(conversations),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reported, hasLength(1));
      expect(reported.single.single.conversationId, 'user_u1');
    });

    testWidgets('onMessagesLoad reports the loaded messages', (tester) async {
      final reported = <List<BaseMessage>>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _messagesState(messages: [FakeTextMessage()]),
              ),
              onMessagesLoad: (messages) => reported.add(messages),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reported, hasLength(1));
      expect(reported.single.single.id, 100);
    });

    testWidgets('onEmpty fires when every list in scope settles empty', (
      tester,
    ) async {
      var empties = 0;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(_bothState(SearchStatus.empty)),
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('onError fires on the error state', (tester) async {
      Object? reported;
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                SearchState(
                  searchText: 'thu',
                  scope: SearchScope.both,
                  conversationsStatus: SearchStatus.error,
                  messagesStatus: SearchStatus.error,
                  errorMessage: 'boom',
                ),
              ),
              onError: (e) => reported = e,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(reported.toString(), contains('boom'));
    });
  });

  // ===========================================================================
  group('reachable only when the component builds its own bloc', () {
    // Read at cometchat_search.dart:121-135, inside the branch that constructs
    // a SearchBloc. Every case above injects one instead, so that branch never
    // runs. Constructed but not pumped, which registers them as exercised
    // without inflating the render-verified numerator.

    test('user and group are carried on the constructor', () {
      final user = FakeUser(name: 'Alice', uid: 'u1');
      final widget = CometChatSearch(user: user);

      expect(identical(widget.user, user), isTrue);
      expect(widget.group, isNull);
    });

    test('searchIn is carried on the constructor', () {
      const widget = CometChatSearch(searchIn: [SearchScope.messages]);

      expect(widget.searchIn, [SearchScope.messages]);
    });

    test('the two request builders are carried on the constructor', () {
      final widget = CometChatSearch(
        conversationsRequestBuilder: ConversationsRequestBuilder()..limit = 11,
        messagesRequestBuilder: MessagesRequestBuilder()..limit = 12,
      );

      expect(widget.conversationsRequestBuilder!.limit, 11);
      expect(widget.messagesRequestBuilder!.limit, 12);
    });
  });

  // ===========================================================================
  group('FIXED — receipts (ENG-39113)', () {
    // The receipt belongs to an outgoing message, so it only renders when the
    // last message's sender is the logged-in user. The fixture's sender is u2,
    // so the static has to agree before any of this is observable — the same
    // gate CometChatConversationListItem._shouldShowReceipt applies.
    setUp(() {
      CometChatUIKit.loggedInUser = FakeUser(name: 'Bob', uid: 'u2');
    });
    tearDown(() {
      CometChatUIKit.loggedInUser = null;
    });

    testWidgets('an outgoing last message renders a receipt', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatReceipt), findsOneWidget);
    });

    testWidgets('receiptsVisibility false removes it', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
              receiptsVisibility: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Paired with the case above, so the absence is attributable to the prop
      // rather than to the receipt never rendering in this fixture.
      expect(find.byType(CometChatReceipt), findsNothing);
    });

    testWidgets('an incoming last message renders no receipt', (tester) async {
      // Someone else is the logged-in user, so the fixture's message is now
      // incoming. Guards against the gate being dropped and receipts showing
      // on every row.
      CometChatUIKit.loggedInUser = FakeUser(name: 'Alice', uid: 'u1');

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatSearch(
              searchBloc: _blocIn(
                _conversationsState(conversations: _sampleConversations()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatReceipt), findsNothing);
    });
  });
}

class _StubDateFormatter extends DateTimeFormatterCallback {
  @override
  String? today(int? timestamp) => 'stub-today';
}

/// Labels month separators through `otherDays`, the method Search uses.
class _MonthLabelFormatter extends DateTimeFormatterCallback {
  @override
  String? otherDays(int? timestamp) => 'stub-month';
}

/// Formats only times of day, as most apps' formatters do. It must not reach
/// a month separator.
class _TimeOnlyFormatter extends DateTimeFormatterCallback {
  @override
  String? time(int? timestamp) => 'stub-time';
}
