/// Regression tests for the ENG-38688 conversations-family fixes: style
/// fields and props that used to have no effect on the rendered list.
///
/// Every test renders twice in one body, first without the value and then
/// with a sentinel no theme produces, and asserts both readings. Reverting
/// the fix makes the second reading match the first, so the test fails.
///
/// * CometChatConversationsStyle: ConversationsList now passes the selection,
///   checkbox, message-type icon and group-dot fields to each row, and the
///   row reads receiptStyle.
/// * CometChatConversationListItemStyle: checkBoxSelectIconTint,
///   receiptStyle, and the two group-dot backgrounds it gained.
/// * CometChatConversationListItem: receiptStyle, and the reads it used to
///   overwrite: the title colour inside titleTextStyle, the typing colour,
///   the status dot background, the date background and border, the avatar
///   placeholder style, colorPalette and typography without a style, media
///   captions, and the deleted-message icon.
///
/// mentionsStyle on CometChatConversationsStyle is still never read, pending
/// a product decision, so it is left out.
///
///   flutter test test/chat_ui/conversations/widget/conversations_family_fixes_test.dart
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
  final _notifiers = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _notifiers.putIfAbsent(id, () => ValueNotifier(const []));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => const [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, this.name, {this.status = 'online'});

  @override
  final String uid;

  @override
  final String name;

  @override
  final String status;

  @override
  String? get avatar => null;

  @override
  String? get role => 'default';

  @override
  String? get link => null;
}

class _FakeGroup extends Fake implements Group {
  _FakeGroup(this.guid, this.name, this.type);

  @override
  final String guid;

  @override
  final String name;

  @override
  final String type;

  @override
  String? get icon => null;

  @override
  int get membersCount => 5;
}

class _FakeTextMessage extends Mock implements TextMessage {
  _FakeTextMessage({
    required User from,
    this.readAt,
    this.deliveredAt,
    this.deletedBy,
  }) : _from = from;

  final User _from;

  @override
  final DateTime? readAt;

  @override
  final DateTime? deliveredAt;

  @override
  final String? deletedBy;

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

/// An image message with a caption.
class _FakeImageMessage extends Mock implements MediaMessage {
  _FakeImageMessage({required User from, this.caption}) : _from = from;

  final User _from;

  @override
  final String? caption;

  @override
  User get sender => _from;

  @override
  int get parentMessageId => 0;

  @override
  int get id => 101;

  @override
  DateTime get sentAt => DateTime(2026, 5, 12, 10, 30);

  @override
  String get type => 'image';

  @override
  String get category => 'message';

  @override
  String get receiverUid => 'u1';

  @override
  String get muid => 'muid_101';

  @override
  List<ReactionCount> get reactions => [];

  @override
  List<User> get mentionedUsers => [];

  @override
  List<String> get tags => [];
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation(
    this.conversationWith,
    this.conversationId, {
    this.unreadMessageCount = 0,
    BaseMessage? lastMessage,
  }) : _lastMessage = lastMessage;

  @override
  final String conversationId;

  @override
  final AppEntity conversationWith;

  @override
  final int unreadMessageCount;

  final BaseMessage? _lastMessage;

  @override
  BaseMessage? get lastMessage => _lastMessage;

  @override
  String get conversationType => conversationWith is User ? 'user' : 'group';

  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = _FakeUser('me', 'Me');
final _bob = _FakeUser('u2', 'Bob', status: 'offline');

/// Alice, online, with a message from Bob.
Conversation _aliceFromBob() => _FakeConversation(
  _FakeUser('u1', 'Alice'),
  'user_u1',
  unreadMessageCount: 3,
  lastMessage: _FakeTextMessage(from: _bob),
);

/// Bob, with no message.
Conversation _bobQuiet() => _FakeConversation(_bob, 'user_u2');

/// Alice, whose last message is mine and has been read.
Conversation _aliceMineRead() => _FakeConversation(
  _FakeUser('u1', 'Alice'),
  'user_u1',
  lastMessage: _FakeTextMessage(
    from: _me,
    deliveredAt: DateTime(2026, 5, 12, 10, 31),
    readAt: DateTime(2026, 5, 12, 10, 32),
  ),
);

/// Bob, whose last message is mine and has only been sent.
Conversation _bobMineSent() => _FakeConversation(
  _bob,
  'user_u2',
  lastMessage: _FakeTextMessage(from: _me),
);

/// Alice, whose last message Bob deleted.
Conversation _aliceDeleted() => _FakeConversation(
  _FakeUser('u1', 'Alice'),
  'user_u1',
  lastMessage: _FakeTextMessage(from: _bob, deletedBy: 'u2'),
);

/// Alice, whose last message is a photo with a markdown caption.
Conversation _aliceCaptioned() => _FakeConversation(
  _FakeUser('u1', 'Alice'),
  'user_u1',
  lastMessage: _FakeImageMessage(from: _bob, caption: 'see **this** 7Q'),
);

Conversation _group(String guid, String name, String type) =>
    _FakeConversation(_FakeGroup(guid, name, type), 'group_$guid');

_MockConversationsBloc _bloc(
  List<Conversation> conversations, {
  Set<String> selected = const {},
}) {
  final state = ConversationsLoaded(
    conversations: conversations,
    selectedConversations: selected,
  );
  final bloc = _MockConversationsBloc();
  whenListen(
    bloc,
    Stream<ConversationsState>.value(state),
    initialState: state,
  );
  return bloc;
}

// Sentinels: values no theme produces. None of these colours occurs in lib/.
const _kSelected = Color(0xFF2E4A6B);
const _kBox = Color(0xFF3F5B7C);
const _kChecked = Color(0xFF506C8D);
const _kStroke = Color(0xFF617D9E);
const _kTick = Color(0xFF728EAF);
const _kType = Color(0xFF839FC0);
const _kRead = Color(0xFF94B0D1);
const _kSent = Color(0xFFA5C1E2);
const _kPrivate = Color(0xFFB6D2F3);
const _kProtected = Color(0xFFC7E304);
const _kTitle = Color(0xFFD8F415);
const _kTyping = Color(0xFFE90526);
const _kDot = Color(0xFFFA1637);
const _kDateFill = Color(0xFF0B2748);
const _kDateBorder = Color(0xFF1C3859);
const _kInitials = Color(0xFF2D496A);
const _kPaletteBackground = Color(0xFF3E5A7B);
const _kPaletteText = Color(0xFF4F6B8C);

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

CometChatColorPalette _palette(WidgetTester tester) =>
    CometChatThemeHelper.getColorPalette(_ctx(tester));

/// The list item that draws [name].
Finder _row(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(CometChatConversationListItem),
);

Finder _in(String name, Finder matching) =>
    find.descendant(of: _row(name), matching: matching);

Checkbox _checkbox(WidgetTester tester, String name) =>
    tester.widget<Checkbox>(_in(name, find.byType(Checkbox)));

/// The row box's fill: the outermost Container the item builds.
Color? _rowFill(WidgetTester tester, String name) =>
    tester.widget<Container>(_in(name, find.byType(Container)).first).color;

Color? _dotFill(WidgetTester tester, String name) => tester
    .widget<CometChatStatusIndicator>(
      _in(name, find.byType(CometChatStatusIndicator)),
    )
    .style
    ?.backgroundColor;

Color? _iconColor(WidgetTester tester, String name, IconData icon) =>
    tester.widget<Icon>(_in(name, find.byIcon(icon))).color;

BoxDecoration _dateBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(CometChatDate),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  User? previousUser;

  setUp(() => previousUser = CometChatUIKit.loggedInUser);

  tearDown(() => CometChatUIKit.loggedInUser = previousUser);

  group('CometChatConversationsStyle fields the rows now receive', () {
    testWidgets('listItemSelectedBackgroundColor paints a selected row', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kSelected]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  listItemSelectedBackgroundColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_rowFill(tester, 'Alice'));
      }
      expect(readings, [_palette(tester).background4, _kSelected]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('checkBoxBackgroundColor fills an unselected checkbox', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kBox]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob(), _bobQuiet()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  checkBoxBackgroundColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_checkbox(tester, 'Bob').fillColor!.resolve({}));
      }
      expect(readings, [Colors.transparent, _kBox]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('checkBoxCheckedBackgroundColor fills a checked checkbox', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kChecked]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  checkBoxCheckedBackgroundColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(
          _checkbox(tester, 'Alice').fillColor!.resolve({WidgetState.selected}),
        );
      }
      expect(readings, [_palette(tester).primary, _kChecked]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('checkBoxBorderRadius rounds the checkbox, directional too', (
      tester,
    ) async {
      final readings = <BorderRadiusGeometry>[];
      for (final value in <BorderRadiusGeometry?>[
        null,
        const BorderRadiusDirectional.only(topStart: Radius.circular(3.5)),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  checkBoxBorderRadius: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(
          (_checkbox(tester, 'Alice').shape! as RoundedRectangleBorder)
              .borderRadius,
        );
      }
      final radius1 = CometChatThemeHelper.getSpacing(_ctx(tester)).radius1;
      expect(readings, [
        BorderRadius.circular(radius1 ?? 4),
        const BorderRadius.only(topLeft: Radius.circular(3.5)),
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('checkBoxBorder strokes the checkbox', (tester) async {
      final readings = <BorderSide>[];
      for (final value in <BorderSide?>[
        null,
        const BorderSide(color: _kStroke, width: 2.75),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob(), _bobQuiet()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  checkBoxBorder: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_checkbox(tester, 'Bob').side!);
      }
      expect(readings, [
        BorderSide(
          color: _palette(tester).borderDefault ?? Colors.grey,
          width: 1.5,
        ),
        const BorderSide(color: _kStroke, width: 2.75),
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('checkboxSelectedIconColor colours the tick', (tester) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kTick]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc(
                  [_aliceFromBob()],
                  selected: {'user_u1'},
                ),
                selectionMode: SelectionMode.multiple,
                conversationsStyle: CometChatConversationsStyle(
                  checkboxSelectedIconColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_checkbox(tester, 'Alice').checkColor);
      }
      expect(readings, [null, _kTick]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('messageTypeIconColor tints the deleted-message icon', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kType]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc([_aliceDeleted()]),
                conversationsStyle: CometChatConversationsStyle(
                  messageTypeIconColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_iconColor(tester, 'Alice', Icons.block));
      }
      expect(readings, [_palette(tester).iconSecondary, _kType]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('receiptStyle colours the read and sent ticks', (tester) async {
      CometChatUIKit.loggedInUser = _me;
      final readings = <List<Color?>>[];
      for (final value in <CometChatMessageReceiptStyle?>[
        null,
        CometChatMessageReceiptStyle(
          readIconColor: _kRead,
          sentIconColor: _kSent,
        ),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc([_aliceMineRead(), _bobMineSent()]),
                conversationsStyle: CometChatConversationsStyle(
                  receiptStyle: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add([
          _iconColor(tester, 'Alice', Icons.done_all),
          _iconColor(tester, 'Bob', Icons.done),
        ]);
      }
      final palette = _palette(tester);
      expect(readings, [
        [palette.primary, palette.iconSecondary],
        [_kRead, _kSent],
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('privateGroupIconBackground fills a private group\'s dot', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kPrivate]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc([_group('g1', 'Dev Team', 'private')]),
                conversationsStyle: CometChatConversationsStyle(
                  privateGroupIconBackground: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_dotFill(tester, 'Dev Team'));
      }
      expect(readings, [_palette(tester).warning, _kPrivate]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('protectedGroupIconBackground fills a password group\'s dot', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kProtected]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversations(
                conversationsBloc: _bloc([_group('g2', 'Vault', 'password')]),
                conversationsStyle: CometChatConversationsStyle(
                  protectedGroupIconBackground: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_dotFill(tester, 'Vault'));
      }
      expect(readings, [_palette(tester).success, _kProtected]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('CometChatConversationListItemStyle fields the item now reads', () {
    testWidgets('checkBoxSelectIconTint colours the tick', (tester) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kTick]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                isSelected: true,
                selectionMode: SelectionMode.multiple,
                style: CometChatConversationListItemStyle(
                  checkBoxSelectIconTint: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_checkbox(tester, 'Alice').checkColor);
      }
      expect(readings, [null, _kTick]);
    });

    testWidgets('receiptStyle colours the read ticks', (tester) async {
      CometChatUIKit.loggedInUser = _me;
      final readings = <Color?>[];
      for (final value in <CometChatMessageReceiptStyle?>[
        null,
        CometChatMessageReceiptStyle(readIconColor: _kRead),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceMineRead(),
                onItemClick: (_) {},
                style: CometChatConversationListItemStyle(receiptStyle: value),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_iconColor(tester, 'Alice', Icons.done_all));
      }
      expect(readings, [_palette(tester).primary, _kRead]);
    });

    testWidgets('privateGroupIconBackground fills a private group\'s dot', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kPrivate]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _group('g1', 'Dev Team', 'private'),
                onItemClick: (_) {},
                style: CometChatConversationListItemStyle(
                  privateGroupIconBackground: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_dotFill(tester, 'Dev Team'));
      }
      expect(readings, [_palette(tester).warning, _kPrivate]);
    });

    testWidgets('protectedGroupIconBackground fills a password group\'s dot', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kProtected]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _group('g2', 'Vault', 'password'),
                onItemClick: (_) {},
                style: CometChatConversationListItemStyle(
                  protectedGroupIconBackground: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_dotFill(tester, 'Vault'));
      }
      expect(readings, [_palette(tester).success, _kProtected]);
    });
  });

  group('CometChatConversationListItem reads it used to overwrite', () {
    testWidgets('receiptStyle colours the read ticks', (tester) async {
      CometChatUIKit.loggedInUser = _me;
      final readings = <Color?>[];
      for (final value in <CometChatMessageReceiptStyle?>[
        null,
        CometChatMessageReceiptStyle(readIconColor: _kRead),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceMineRead(),
                onItemClick: (_) {},
                receiptStyle: value,
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_iconColor(tester, 'Alice', Icons.done_all));
      }
      expect(readings, [_palette(tester).primary, _kRead]);
    });

    testWidgets('a colour inside titleTextStyle reaches the title', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kTitle]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                style: CometChatConversationListItemStyle(
                  titleTextStyle: TextStyle(color: value),
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(tester.widget<Text>(find.text('Alice')).style?.color);
      }
      expect(readings, [_palette(tester).textPrimary, _kTitle]);
    });

    testWidgets('a colour inside the typing text style reaches the line', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kTyping]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                typingIndicators: [
                  TypingIndicator(
                    sender: _bob,
                    receiverId: 'u1',
                    receiverType: 'user',
                  ),
                ],
                typingIndicatorStyle: CometChatTypingIndicatorStyle(
                  textStyle: TextStyle(color: value),
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(
          tester.widget<Text>(find.textContaining('typing')).style?.color,
        );
      }
      expect(readings, [_palette(tester).textHighlight, _kTyping]);
    });

    testWidgets('statusIndicatorStyle.backgroundColor fills the online dot', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kDot]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  backgroundColor: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_dotFill(tester, 'Alice'));
      }
      expect(readings.first, isNotNull);
      expect(readings.first, isNot(_kDot));
      expect(readings.last, _kDot);
    });

    testWidgets(
      'dateStyle background and border reach a non-transparent timestamp',
      (tester) async {
        final readings = <List<Object?>>[];
        for (final value in <CometChatDateStyle?>[
          null,
          CometChatDateStyle(
            backgroundColor: _kDateFill,
            border: Border.all(color: _kDateBorder, width: 1.25),
          ),
        ]) {
          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                CometChatConversationListItem(
                  conversation: _aliceFromBob(),
                  onItemClick: (_) {},
                  dateBackgroundIsTransparent: false,
                  dateStyle: value,
                ),
                key: ValueKey(value),
              ),
            ),
          );
          await tester.pump();
          final box = _dateBox(tester);
          readings.add([box.color, box.border]);
        }
        expect(readings, [
          [
            _palette(tester).background2,
            Border.all(width: 0, color: Colors.transparent),
          ],
          [_kDateFill, Border.all(color: _kDateBorder, width: 1.25)],
        ]);
      },
    );

    testWidgets('avatarStyle.placeHolderTextStyle styles the initials', (
      tester,
    ) async {
      final readings = <List<Object?>>[];
      for (final value in <CometChatAvatarStyle?>[
        null,
        const CometChatAvatarStyle(
          placeHolderTextStyle: TextStyle(fontSize: 33.5, color: _kInitials),
        ),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                avatarStyle: value,
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        final initials = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(CometChatAvatar),
                matching: find.byType(Text),
              )
              .first,
        );
        readings.add([initials.style?.fontSize, initials.style?.color]);
      }
      final heading2 = CometChatThemeHelper.getTypography(
        _ctx(tester),
      ).heading2?.bold?.fontSize;
      expect(readings.first.first, heading2);
      expect(readings.last, [33.5, _kInitials]);
    });

    testWidgets('colorPalette drives the defaults when no style is passed', (
      tester,
    ) async {
      final readings = <List<Color?>>[];
      for (final value in <CometChatColorPalette?>[
        null,
        CometChatColorPalette(
          background1: _kPaletteBackground,
          textPrimary: _kPaletteText,
        ),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                colorPalette: value,
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add([
          _rowFill(tester, 'Alice'),
          tester.widget<Text>(find.text('Alice')).style?.color,
        ]);
      }
      final palette = _palette(tester);
      expect(readings, [
        [palette.background1, palette.textPrimary],
        [_kPaletteBackground, _kPaletteText],
      ]);
    });

    testWidgets('typography drives the defaults when no style is passed', (
      tester,
    ) async {
      final readings = <double?>[];
      for (final value in <CometChatTypography?>[
        null,
        const CometChatTypography(
          heading4: CometChatTextStyleHeading4(
            medium: TextStyle(fontSize: 21.5),
          ),
        ),
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceFromBob(),
                onItemClick: (_) {},
                typography: value,
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(tester.widget<Text>(find.text('Alice')).style?.fontSize);
      }
      final heading4 = CometChatThemeHelper.getTypography(
        _ctx(tester),
      ).heading4?.medium?.fontSize;
      expect(readings, [heading4, 21.5]);
    });

    testWidgets('textFormatters format a media caption', (tester) async {
      final readings = <List<String>>[];
      for (final value in <List<CometChatTextFormatter>?>[
        null,
        [MarkdownTextFormatter()],
      ]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceCaptioned(),
                onItemClick: (_) {},
                textFormatters: value,
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add([
          for (final rich in tester.widgetList<RichText>(
            _in('Alice', find.byType(RichText)),
          ))
            rich.text.toPlainText(),
        ]);
      }
      // The default formatters include markdown, so both renders format the
      // caption: the asterisks are gone and the words remain.
      for (final texts in readings) {
        expect(texts.any((t) => t.contains('this 7Q')), isTrue);
        expect(texts.any((t) => t.contains('**')), isFalse);
      }
    });

    testWidgets('messageTypeIconTint tints the deleted-message icon', (
      tester,
    ) async {
      final readings = <Color?>[];
      for (final value in <Color?>[null, _kType]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _aliceDeleted(),
                onItemClick: (_) {},
                style: CometChatConversationListItemStyle(
                  messageTypeIconTint: value,
                ),
              ),
              key: ValueKey(value),
            ),
          ),
        );
        await tester.pump();
        readings.add(_iconColor(tester, 'Alice', Icons.block));
      }
      expect(readings, [_palette(tester).iconSecondary, _kType]);
    });
  });

  group('CometChatConversationListItemStyle.fromTheme', () {
    testWidgets('takes its defaults from the palette, typography and spacing '
        'it is given', (tester) async {
      final readings = <List<Object?>>[];
      for (final custom in [false, true]) {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              Builder(
                builder: (context) => CometChatConversationListItem(
                  conversation: _aliceFromBob(),
                  onItemClick: (_) {},
                  isSelected: true,
                  selectionMode: SelectionMode.multiple,
                  style: custom
                      ? CometChatConversationListItemStyle.fromTheme(
                          context,
                          colorPalette: CometChatColorPalette(
                            background4: _kPaletteBackground,
                          ),
                          typography: const CometChatTypography(
                            heading4: CometChatTextStyleHeading4(
                              medium: TextStyle(fontSize: 21.5),
                            ),
                          ),
                          spacing: CometChatSpacing(radius1: 6.5),
                        )
                      : CometChatConversationListItemStyle.fromTheme(context),
                ),
              ),
              key: ValueKey(custom),
            ),
          ),
        );
        await tester.pump();
        readings.add([
          _rowFill(tester, 'Alice'),
          tester.widget<Text>(find.text('Alice')).style?.fontSize,
          (_checkbox(tester, 'Alice').shape! as RoundedRectangleBorder)
              .borderRadius,
        ]);
      }
      final context = _ctx(tester);
      expect(readings, [
        [
          CometChatThemeHelper.getColorPalette(context).background4,
          CometChatThemeHelper.getTypography(
            context,
          ).heading4?.medium?.fontSize,
          BorderRadius.circular(
            CometChatThemeHelper.getSpacing(context).radius1 ?? 4,
          ),
        ],
        [_kPaletteBackground, 21.5, BorderRadius.circular(6.5)],
      ]);
    });
  });
}
