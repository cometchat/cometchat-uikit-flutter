/// Render-verified prop matrix for [ConversationsList] — Track 3 PROP1.
///
/// 54 props, previously at zero and the largest single unit in the gap. It is
/// exported, so it is in the denominator, but the `CometChatConversations`
/// matrix only reaches it through whatever that component forwards — which
/// proves the forwarding, not the widget.
///
/// Every case constructs the list inline. A local builder function reads far
/// better and scores zero: prop_coverage needs the construction, the pump and
/// the assertion lexically inside the test closure. The sibling file
/// `test/chat_ui/list_widgets_props_test.dart` demonstrated that the hard way
/// — nine passing cases, 0/22 counted.
///
///   flutter test test/chat_ui/conversations/widget/conversations_list_props_test.dart
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
  List<TypingIndicator> typing = const [];

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier(typing));

  @override
  List<TypingIndicator> getTypingIndicators(String id) => typing;

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
  FakeConversation({
    required this.conversationWith,
    this.conversationId = 'user_u1',
    this.unreadMessageCount = 3,
    BaseMessage? last,
  }) : _last = last;
  final BaseMessage? _last;
  @override
  final String conversationId;
  @override
  final AppEntity conversationWith;
  @override
  final int unreadMessageCount;
  @override
  BaseMessage? get lastMessage => _last ?? FakeTextMessage();
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

MockConversationsBloc _bloc(
  ConversationsState state, {
  List<TypingIndicator> typing = const [],
}) {
  final bloc = MockConversationsBloc();
  bloc.typing = typing;
  when(() => bloc.state).thenReturn(state);
  whenListen(
    bloc,
    Stream<ConversationsState>.value(state),
    initialState: state,
  );
  return bloc;
}

ConversationsState _loaded({Set<String> selected = const {}}) =>
    ConversationsLoaded(
      conversations: _conversations(),
      hasMore: false,
      selectedConversations: selected,
    );

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);

Widget _host(Widget Function(BuildContext) build) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Builder(builder: build)),
);

CometChatConversationListItem _row(WidgetTester tester) => tester
    .widgetList<CometChatConversationListItem>(
      find.byType(CometChatConversationListItem),
    )
    .first;

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
  group('the nine required parameters', () {
    testWidgets('all nine reach the rows', (tester) async {
      // Proven through visible effects rather than by being passed: each of
      // the four sub-styles is set to a sentinel and read back off the row.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(
                itemTitleTextColor: _c1,
                itemTitleTextStyle: TextStyle(fontSize: 23),
              ),
              statusStyle: const CometChatStatusIndicatorStyle(
                backgroundColor: _c2,
              ),
              typingStyle: const CometChatTypingIndicatorStyle(
                textStyle: TextStyle(fontSize: 31),
              ),
              receiptStyle: CometChatMessageReceiptStyle(readIconColor: _c3),
              datesStyle: const CometChatDateStyle(textColor: _c4),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 23),
        isTrue,
        reason: 'style reaches the row title',
      );

      final row = _row(tester);
      expect(row.statusIndicatorStyle?.backgroundColor, _c2);
      expect(row.typingIndicatorStyle?.textStyle?.fontSize, 31);
      expect(row.receiptStyle?.readIconColor, _c3);
      expect(row.dateStyle?.textColor, _c4);
      expect(row.colorPalette, isNotNull);
      expect(row.spacing, isNotNull);
      expect(row.typography, isNotNull);
    });
  });

  // ===========================================================================
  group('row slots and state views', () {
    testWidgets('the four row slots replace their sections', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              subtitleView: (c, x) => Text('sub-${x.conversationId}'),
              trailingView: (x) => Text('trail-${x.conversationId}'),
              leadingView: (c, x) => Text('lead-${x.conversationId}'),
              titleView: (c, x) => Text('title-${x.conversationId}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('sub-user_u1'), findsOneWidget);
      expect(find.text('trail-user_u1'), findsOneWidget);
      expect(find.text('lead-user_u1'), findsOneWidget);
      expect(find.text('title-user_u1'), findsOneWidget);
    });

    testWidgets('listItemView and itemWrapperBuilder wrap each row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              listItemView: (x) => Text('row-${x.conversationId}'),
              itemWrapperBuilder: (c, x, child) =>
                  Column(children: [const Text('wrapped'), child]),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-user_u1'), findsOneWidget);
      expect(find.text('wrapped'), findsWidgets);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('the three state views replace their states', (tester) async {
      for (final entry in <String, ConversationsState>{
        'custom-loading': const ConversationsLoading(),
        'custom-empty': const ConversationsEmpty(),
        'custom-error': const ConversationsError(message: 'boom'),
      }.entries) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _host(
              (context) => ConversationsList(
                conversationsBloc: _bloc(entry.value),
                style: const CometChatConversationsStyle(),
                statusStyle: const CometChatStatusIndicatorStyle(),
                typingStyle: const CometChatTypingIndicatorStyle(),
                receiptStyle: CometChatMessageReceiptStyle(),
                datesStyle: const CometChatDateStyle(),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
                loadingStateView: (c) => const Text('custom-loading'),
                emptyStateView: (c) => const Text('custom-empty'),
                errorStateView: (c) => const Text('custom-error'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('hideError suppresses the error view', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(
                const ConversationsError(message: 'boom'),
              ),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              errorStateView: (c) => const Text('custom-error'),
              hideError: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Paired with the case above, where the same state renders it.
      expect(find.text('custom-error'), findsNothing);
    });

    testWidgets('the three state callbacks report their states', (
      tester,
    ) async {
      final loaded = <List<Conversation>>[];
      var empties = 0;
      Object? error;

      for (final state in <ConversationsState>[
        _loaded(),
        const ConversationsEmpty(),
        const ConversationsError(message: 'boom'),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _host(
              (context) => ConversationsList(
                conversationsBloc: _bloc(state),
                style: const CometChatConversationsStyle(),
                statusStyle: const CometChatStatusIndicatorStyle(),
                typingStyle: const CometChatTypingIndicatorStyle(),
                receiptStyle: CometChatMessageReceiptStyle(),
                datesStyle: const CometChatDateStyle(),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
                onLoad: loaded.add,
                onEmpty: () => empties++,
                onError: (e) => error = e,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      expect(loaded, isNotEmpty, reason: 'onLoad');
      expect(empties, greaterThan(0), reason: 'onEmpty');
      expect(error, isNotNull, reason: 'onError');
    });
  });

  // ===========================================================================
  group('row geometry and affordances', () {
    testWidgets('avatar and status-indicator geometry reaches the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              avatarHeight: 44,
              avatarWidth: 46,
              avatarPadding: const EdgeInsets.all(7),
              avatarMargin: const EdgeInsets.all(3),
              statusIndicatorHeight: 20,
              statusIndicatorWidth: 22,
              statusIndicatorBorderRadius: const BorderRadius.all(
                Radius.circular(9),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final row = _row(tester);
      expect(row.avatarHeight, 44);
      expect(row.avatarWidth, 46);
      expect(row.avatarPadding, const EdgeInsets.all(7));
      expect(row.avatarMargin, const EdgeInsets.all(3));
      expect(row.statusIndicatorHeight, 20);
      expect(row.statusIndicatorWidth, 22);
      expect(
        row.statusIndicatorBorderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
    });

    testWidgets('the badge and date geometry reaches the row', (tester) async {
      // badgeWidth and badgeHeight were declared here and read nowhere until
      // ENG-39127 — the row sized its badge 20x20 regardless.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              badgeWidth: 34,
              badgeHeight: 26,
              badgePadding: const EdgeInsets.all(4),
              datePattern: (x) => 'pinned',
              datePadding: const EdgeInsets.all(5),
              dateHeight: 30,
              dateWidth: 60,
              dateBackgroundIsTransparent: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final badge = tester
          .widgetList<CometChatBadge>(find.byType(CometChatBadge))
          .first;
      expect(badge.width, 34);
      expect(badge.height, 26);
      expect(badge.padding, const EdgeInsets.all(4));

      final date = tester
          .widgetList<CometChatDate>(find.byType(CometChatDate))
          .first;
      expect(date.customDateString, 'pinned');
      expect(date.padding, const EdgeInsets.all(5));
      expect(date.height, 30);
      expect(date.width, 60);
      expect(date.isTransparentBackground, isFalse);
    });

    testWidgets('the group-type icons and visibility flags reach the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              privateGroupIcon: const Icon(Icons.shield),
              protectedGroupIcon: const Icon(Icons.lock),
              usersStatusVisibility: false,
              groupTypeVisibility: false,
              receiptsVisibility: false,
              hideThreadIndicator: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final row = _row(tester);
      expect(row.privateGroupIcon, isNotNull);
      expect(row.protectedGroupIcon, isNotNull);
      // The list inverts each of these into a hide* flag on the row.
      expect(row.hideUserStatus, isTrue);
      expect(row.hideGroupType, isTrue);
      expect(row.hideReceipts, isTrue);
      expect(row.hideThreadIndicator, isTrue);
    });

    testWidgets('the three receipt icons and textFormatters reach the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              readIcon: const Icon(Icons.done_all),
              deliveredIcon: const Icon(Icons.done),
              sentIcon: const Icon(Icons.check),
              textFormatters: const <CometChatTextFormatter>[],
              dateTimeFormatterCallback: _StubDateFormatter(),
            ),
          ),
        ),
      );
      await tester.pump();

      final row = _row(tester);
      expect(row.readIcon, isNotNull);
      expect(row.deliveredIcon, isNotNull);
      expect(row.sentIcon, isNotNull);
      expect(row.textFormatters, isEmpty);
      expect(row.dateTimeFormatterCallback, isA<_StubDateFormatter>());
    });

    testWidgets('typingIndicatorText replaces the typing wording', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded(), typing: [FakeTyping()]),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              typingIndicatorText: 'scribbling…',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('scribbling…'), findsWidgets);
    });
  });

  // ===========================================================================
  group('interaction', () {
    testWidgets('onItemTap and onItemLongPress fire with the conversation', (
      tester,
    ) async {
      Conversation? tapped;
      Conversation? pressed;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              onItemTap: (x) => tapped = x,
              onItemLongPress: (x) => pressed = x,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pump();
      expect(tapped?.conversationId, 'user_u1');

      await tester.longPress(find.text('Alice'));
      await tester.pump();
      expect(pressed?.conversationId, 'user_u1');
    });

    testWidgets('selectionMode and activateSelection are honoured together', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded(selected: {'user_u1'})),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onClick,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('scrollController attaches to the list', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _host(
            (context) => ConversationsList(
              conversationsBloc: _bloc(_loaded()),
              style: const CometChatConversationsStyle(),
              statusStyle: const CometChatStatusIndicatorStyle(),
              typingStyle: const CometChatTypingIndicatorStyle(),
              receiptStyle: CometChatMessageReceiptStyle(),
              datesStyle: const CometChatDateStyle(),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.hasClients, isTrue);
    });
  });
}

class _StubDateFormatter extends DateTimeFormatterCallback {
  @override
  String? today(int? timestamp) => 'stub-today';
}
