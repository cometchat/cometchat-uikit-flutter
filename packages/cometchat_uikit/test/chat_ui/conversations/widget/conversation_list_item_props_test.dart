/// Render-verified prop matrix for [CometChatConversationListItem] — Track 3
/// PROP1 (ENG-38688, coverage part 2).
///
/// How the matrix works. [_matrix] is a table. Each row names the prop it
/// verifies, the conversation to show, the value it sets (a sentinel no theme
/// uses), an optional interaction, a probe that reads the rendered element the
/// prop controls, and what the probe must return on each side. Every row is
/// pumped twice in the same test body: a base side that leaves the prop out
/// (so the constructor default is pinned too), then the set side. Both
/// readings are checked, and they must differ, so a row whose assertion would
/// still hold if the item ignored the prop fails here. A base side that reads
/// a theme token resolves it from the pumped context with [_FromTheme].
///
/// The four flags have non-null defaults, so a row that sets one is built by
/// a construction that passes that flag alone; the base side goes through the
/// main construction, which leaves every flag out. The guard test at the
/// bottom holds each wired prop to a row, and each flag row to one flag.
///
/// 29 of the 30 props this file covers have rows. receiptStyle has none
/// here: it had no effect until ENG-38688 wired it, and
/// conversations_family_fixes_test.dart covers it. That file also covers the
/// reads ENG-38688 stopped the item overwriting: colorPalette and typography
/// without a style, the title colour inside titleTextStyle, the typing
/// colour, the status dot background, the date background and border, the
/// avatar placeholder style, and media captions through textFormatters.
///
///   flutter test test/chat_ui/conversations/widget/conversation_list_item_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

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
    this.parentMessageId = 0,
    this.deliveredAt,
    this.readAt,
    this.pending = false,
    this.moderationStatus,
  }) : _from = from;

  /// Not yet sent, so it carries no sentAt and shows the pending clock.
  final bool pending;

  @override
  final ModerationStatusEnum? moderationStatus;

  final User _from;

  @override
  User get sender => _from;

  @override
  final int parentMessageId;

  @override
  final DateTime? deliveredAt;

  @override
  final DateTime? readAt;

  @override
  int get id => 100;

  @override
  String get text => 'Hello!';

  @override
  DateTime? get sentAt => pending ? null : DateTime(2026, 5, 12, 10, 30);

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

class _FakeImageMessage extends Mock implements MediaMessage {
  _FakeImageMessage({required User from}) : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  int get id => 101;

  @override
  int get parentMessageId => 0;

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
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation({
    required this.conversationWith,
    required this.conversationId,
    this.unreadMessageCount = 0,
    this.pinnedBy,
    BaseMessage? lastMessage,
  }) : _lastMessage = lastMessage;

  @override
  final String conversationId;

  @override
  final AppEntity conversationWith;

  @override
  final int unreadMessageCount;

  @override
  final String? pinnedBy;

  final BaseMessage? _lastMessage;

  @override
  BaseMessage? get lastMessage => _lastMessage;

  @override
  String get conversationType => conversationWith is User ? 'user' : 'group';

  @override
  DateTime? get pinnedAt => pinnedBy == null ? null : DateTime(2026, 5, 12);
}

/// Replaces the whole last-message preview with a sentinel string.
class _SentinelFormatter extends CometChatTextFormatter {
  @override
  void init() {}

  @override
  TextStyle getMessageInputTextStyle(BuildContext context) => const TextStyle();

  @override
  void handlePreMessageSend(BuildContext context, BaseMessage baseMessage) {}

  @override
  void onScrollToBottom(TextEditingController textEditingController) {}

  @override
  void onChange(
    TextEditingController textEditingController,
    String previousText,
  ) {}

  @override
  List<AttributedText> getAttributedText(
    String text,
    BuildContext context,
    BubbleAlignment? alignment, {
    List<AttributedText>? existingAttributes,
    Function(String)? onTap,
    bool forConversation = false,
  }) => [
    ...?existingAttributes,
    AttributedText(
      start: 0,
      end: text.length,
      underlyingText: 'FORMATTED-BY-SENTINEL',
    ),
  ];
}

/// Answers every date bucket with the same sentinel.
class _SentinelDates extends DateTimeFormatterCallback {
  static const _when = 'WHEN-SENTINEL';

  @override
  String? time(int? timestamp) => _when;

  @override
  String? today(int? timestamp) => _when;

  @override
  String? yesterday(int? timestamp) => _when;

  @override
  String? lastWeek(int? timestamp) => _when;

  @override
  String? otherDays(int? timestamp) => _when;

  @override
  String? minute(int? timestamp) => _when;

  @override
  String? minutes(int? diffInMinutesFromNow, int? timestamp) => _when;

  @override
  String? hour(int? timestamp) => _when;

  @override
  String? hours(int? diffInHourFromNow, int? timestamp) => _when;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = _FakeUser('me', 'Me');
final _bob = _FakeUser('u2', 'Bob', status: 'offline');

/// Online Alice, a text message from Bob, 3 unread.
Conversation _alice() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  unreadMessageCount: 3,
  lastMessage: _FakeTextMessage(from: _bob),
);

/// Alice's conversation, pinned.
Conversation _pinned() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  pinnedBy: 'me',
  lastMessage: _FakeTextMessage(from: _bob),
);

/// Alice's conversation, whose last message is a thread reply from Bob.
Conversation _threaded() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  lastMessage: _FakeTextMessage(from: _bob, parentMessageId: 42),
);

/// Alice's conversation, whose last message is a photo from Bob.
Conversation _photo() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  lastMessage: _FakeImageMessage(from: _bob),
);

/// Alice's conversation, whose last message is one the signed-in user sent.
Conversation _mine({bool read = false, bool delivered = false}) =>
    _FakeConversation(
      conversationWith: _FakeUser('u1', 'Alice'),
      conversationId: 'user_u1',
      lastMessage: _FakeTextMessage(
        from: _me,
        readAt: read ? DateTime(2026, 5, 12, 10, 32) : null,
        deliveredAt: delivered || read ? DateTime(2026, 5, 12, 10, 31) : null,
      ),
    );

Conversation _read() => _mine(read: true);
Conversation _delivered() => _mine(delivered: true);

/// My last message, still on its way out.
Conversation _pending() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  lastMessage: _FakeTextMessage(from: _me, pending: true),
);

/// My last message, which moderation rejected.
Conversation _rejected() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  lastMessage: _FakeTextMessage(
    from: _me,
    moderationStatus: ModerationStatusEnum.DISAPPROVED,
  ),
);

/// My last message, in a pinned conversation.
Conversation _minePinned() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  conversationId: 'user_u1',
  pinnedBy: 'me',
  lastMessage: _FakeTextMessage(from: _me),
);

Conversation _group(String type) => _FakeConversation(
  conversationWith: _FakeGroup('g1', 'Dev Team', type),
  conversationId: 'group_g1',
);

Conversation _privateGroup() => _group('private');
Conversation _protectedGroup() => _group('password');

final _bobTyping = [
  TypingIndicator(sender: _bob, receiverId: 'u1', receiverType: 'user'),
];

// Sentinels: values no theme produces, so a match can only come from the prop.
const _kRowBackground = Color(0xFF13579B);
const _kSelectedBackground = Color(0xFF2468AC);
const _kTitle = Color(0xFF3579BD);
const _kSubtitle = Color(0xFF468ACE);
const _kTypeIcon = Color(0xFF579BDF);
const _kCheckFill = Color(0xFF68ACE0);
const _kCheckEmpty = Color(0xFF79BDF1);
const _kCheckStroke = Color(0xFF8ACE02);
const _kAvatar = Color(0xFF9BDF13);
const _kDotBorderColor = Color(0xFFBDF135);
const _kDateText = Color(0xFFCE0246);
const _kBadge = Color(0xFFDF1357);
const _kBadgeText = Color(0xFFE02468);
const _kHighlight = Color(0xFFF13579);
const _kPrimary = Color(0xFF1357AE);
const _kWarning = Color(0xFF24689F);
const _kPaletteEdge = Color(0xFF0246AD);
const _kError = Color(0xFF4A6B8C);
const _kIconSecondary = Color(0xFF5B7C9D);
const _kSuccess = Color(0xFF6C8DAE);

/// The value a style field sets when a row checks that the item-level prop
/// wins over it.
const _kOutranked = Color(0xFF35790A);

const _privateIcon = Icon(Icons.vpn_key, key: ValueKey('private-sentinel'));
const _protectedIcon = Icon(
  Icons.password,
  key: ValueKey('protected-sentinel'),
);
const _readIcon = Icon(Icons.visibility, key: ValueKey('read-sentinel'));
const _deliveredIcon = Icon(Icons.inbox, key: ValueKey('delivered-sentinel'));
const _sentIcon = Icon(Icons.outbox, key: ValueKey('sent-sentinel'));

const _kDotBorder = Border.fromBorderSide(
  BorderSide(color: _kDotBorderColor, width: 2.5),
);
const _kOutrankedBorder = Border.fromBorderSide(
  BorderSide(color: _kOutranked, width: 1.5),
);
const _kDotRadius = BorderRadius.all(Radius.circular(3));
const _kDateRadius = BorderRadius.all(Radius.circular(7));
const _kCheckRadius = BorderRadius.all(Radius.circular(5));

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every value a row can set. Each field is a prop wired into the
/// constructions in [main]; the guard test holds each field to a row.
class _Props {
  const _Props({
    this.hideUserStatus,
    this.hideGroupType,
    this.hideReceipts,
    this.hideThreadIndicator,
    this.onSelectionToggle,
    this.textFormatters,
    this.dateTimeFormatterCallback,
    this.style,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.dateStyle,
    this.badgeStyle,
    this.typingIndicatorStyle,
    this.avatarHeight,
    this.avatarWidth,
    this.avatarPadding,
    this.avatarMargin,
    this.statusIndicatorHeight,
    this.statusIndicatorWidth,
    this.subtitleView,
    this.trailingView,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.privateGroupIcon,
    this.protectedGroupIcon,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
  });

  final bool? hideUserStatus;
  final bool? hideGroupType;
  final bool? hideReceipts;
  final bool? hideThreadIndicator;
  final VoidCallback? onSelectionToggle;
  final List<CometChatTextFormatter>? textFormatters;
  final DateTimeFormatterCallback? dateTimeFormatterCallback;
  final CometChatConversationListItemStyle? style;
  final CometChatAvatarStyle? avatarStyle;
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;
  final CometChatDateStyle? dateStyle;
  final CometChatBadgeStyle? badgeStyle;
  final CometChatTypingIndicatorStyle? typingIndicatorStyle;
  final double? avatarHeight;
  final double? avatarWidth;
  final EdgeInsetsGeometry? avatarPadding;
  final EdgeInsetsGeometry? avatarMargin;
  final double? statusIndicatorHeight;
  final double? statusIndicatorWidth;
  final Widget? Function(Conversation, TypingIndicator?)? subtitleView;
  final Widget? Function(Conversation, TypingIndicator?)? trailingView;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final Widget? privateGroupIcon;
  final Widget? protectedGroupIcon;
  final Widget? readIcon;
  final Widget? deliveredIcon;
  final Widget? sentIcon;

  static const flags = {
    'hideUserStatus',
    'hideGroupType',
    'hideReceipts',
    'hideThreadIndicator',
  };

  Map<String, Object?> get values => {
    'hideUserStatus': hideUserStatus,
    'hideGroupType': hideGroupType,
    'hideReceipts': hideReceipts,
    'hideThreadIndicator': hideThreadIndicator,
    'onSelectionToggle': onSelectionToggle,
    'textFormatters': textFormatters,
    'dateTimeFormatterCallback': dateTimeFormatterCallback,
    'style': style,
    'avatarStyle': avatarStyle,
    'statusIndicatorStyle': statusIndicatorStyle,
    'dateStyle': dateStyle,
    'badgeStyle': badgeStyle,
    'typingIndicatorStyle': typingIndicatorStyle,
    'avatarHeight': avatarHeight,
    'avatarWidth': avatarWidth,
    'avatarPadding': avatarPadding,
    'avatarMargin': avatarMargin,
    'statusIndicatorHeight': statusIndicatorHeight,
    'statusIndicatorWidth': statusIndicatorWidth,
    'subtitleView': subtitleView,
    'trailingView': trailingView,
    'colorPalette': colorPalette,
    'spacing': spacing,
    'typography': typography,
    'privateGroupIcon': privateGroupIcon,
    'protectedGroupIcon': protectedGroupIcon,
    'readIcon': readIcon,
    'deliveredIcon': deliveredIcon,
    'sentIcon': sentIcon,
  };

  /// The props this instance actually sets.
  Set<String> get setNames => {
    for (final e in values.entries)
      if (e.value != null) e.key,
  };

  /// Every prop the constructions read from a row.
  static Set<String> get wired => const _Props().values.keys.toSet();
}

/// What a row records while it runs.
class _Rec {
  int toggles = 0;
  int clicks = 0;

  /// (conversationId, typing sender uid) a slot builder was called with.
  (String?, String?)? slotArgs;

  Widget slot(Conversation c, TypingIndicator? t, String text) {
    slotArgs = (c.conversationId, t?.sender.uid);
    return Text(text);
  }
}

/// A base-side expectation read from the theme the item was pumped under.
class _FromTheme {
  const _FromTheme(this.of);

  final Object? Function(BuildContext context) of;
}

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.set,
    required this.probe,
    required this.expected,
    required this.unset,
    this.base,
    this.conversation = _alice,
    this.typing = const [],
    this.selectionMode = SelectionMode.none,
    this.selected = false,
    this.signedIn = false,
    this.act,
  });

  /// The [CometChatConversationListItem] parameter this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// The values this row sets; gets the recorder so callbacks can record.
  final _Props Function(_Rec rec) set;

  /// What the base side sets. Leaves [prop] out; defaults to nothing at all.
  final _Props Function(_Rec rec)? base;

  /// Reads the rendered element (or recorded call) the prop controls.
  final Object? Function(WidgetTester tester, _Rec rec) probe;

  /// What [probe] must return with [set] applied.
  final Object? expected;

  /// What [probe] must return on the base side.
  final Object? unset;

  final Conversation Function() conversation;
  final List<TypingIndicator> typing;
  final SelectionMode selectionMode;
  final bool selected;

  /// Signs [_me] in, so receipts show on messages [_me] sent.
  final bool signedIn;

  /// A real interaction to run before probing.
  final Future<void> Function(WidgetTester tester)? act;
}

int _count(Finder finder) => finder.evaluate().length;

BuildContext _ctx(WidgetTester tester) => tester.element(find.byType(Scaffold));

CometChatColorPalette _palette(BuildContext c) =>
    CometChatThemeHelper.getColorPalette(c);

CometChatTypography _typography(BuildContext c) =>
    CometChatThemeHelper.getTypography(c);

CometChatSpacing _spacing(BuildContext c) => CometChatThemeHelper.getSpacing(c);

Finder _in(Type type, Type child) =>
    find.descendant(of: find.byType(type), matching: find.byType(child));

/// The outermost Container a widget of [type] builds: the avatar box, the
/// presence dot, the badge, the timestamp box.
BoxDecoration _decoration(WidgetTester tester, Type type) =>
    tester.widget<Container>(_in(type, Container).first).decoration!
        as BoxDecoration;

/// The colour painted behind the whole row.
Color? _rowColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(_in(InkWell, ColoredBox).first).color;

TextStyle? _titleStyle(WidgetTester tester) =>
    tester.widget<Text>(find.text('Alice')).style;

/// The root style of the last-message preview.
TextStyle? _subtitleStyle(WidgetTester tester) =>
    (tester
                .widget<RichText>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is RichText &&
                        w.text.toPlainText().contains('Hello!'),
                  ),
                )
                .text
            as TextSpan)
        .style;

String _typingText(WidgetTester tester) =>
    Translations.of(_ctx(tester)).isTyping;

TextStyle? _typingStyle(WidgetTester tester) =>
    tester.widget<Text>(find.text(_typingText(tester))).style;

Text _dateText(WidgetTester tester) =>
    tester.widget<Text>(_in(CometChatDate, Text));

Text _initials(WidgetTester tester) =>
    tester.widget<Text>(_in(CometChatAvatar, Text));

Checkbox _checkbox(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox));

Color? _dotBorderColor(WidgetTester tester) =>
    (_decoration(tester, CometChatStatusIndicator).border as Border?)
        ?.top
        .color;

/// How many of the read, delivered and sent sentinels are on screen, then how
/// many default [tick]s.
List<int> _receiptReading(IconData tick) => [
  _count(find.byKey(_readIcon.key!)),
  _count(find.byKey(_deliveredIcon.key!)),
  _count(find.byKey(_sentIcon.key!)),
  _count(find.byIcon(tick)),
];

Finder _preview(String text) => find.textContaining(text, findRichText: true);

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

final _matrix = <_Row>[
  // ── Visibility flags ──────────────────────────────────────────────────────
  _Row(
    'hideUserStatus',
    'true drops the presence dot of an online user',
    set: (r) => const _Props(hideUserStatus: true),
    probe: (t, r) => _count(find.byType(CometChatStatusIndicator)),
    unset: 1,
    expected: 0,
  ),
  _Row(
    'hideGroupType',
    'true drops the private-group badge',
    conversation: _privateGroup,
    set: (r) => const _Props(hideGroupType: true),
    probe: (t, r) => [
      _count(find.byType(CometChatStatusIndicator)),
      _count(find.byIcon(Icons.shield)),
    ],
    unset: [1, 1],
    expected: [0, 0],
  ),
  _Row(
    'hideReceipts',
    'true drops the tick from my own last message',
    signedIn: true,
    conversation: _mine,
    set: (r) => const _Props(hideReceipts: true),
    probe: (t, r) => _count(find.byIcon(Icons.done)),
    unset: 1,
    expected: 0,
  ),
  _Row(
    'hideThreadIndicator',
    'false shows the thread arrow, which is hidden by default',
    conversation: _threaded,
    set: (r) => const _Props(hideThreadIndicator: false),
    probe: (t, r) => _count(find.byIcon(Icons.subdirectory_arrow_right)),
    unset: 0,
    expected: 1,
  ),

  // ── Selection ─────────────────────────────────────────────────────────────
  _Row(
    'onSelectionToggle',
    'fires when the selection checkbox is tapped',
    selectionMode: SelectionMode.multiple,
    set: (r) => _Props(onSelectionToggle: () => r.toggles++),
    act: (t) async {
      await t.tap(find.byType(Checkbox));
      await t.pump();
    },
    probe: (t, r) => [r.toggles, r.clicks],
    unset: [0, 0],
    expected: [1, 0],
  ),

  // ── Avatar and status dot geometry ────────────────────────────────────────
  _Row(
    'avatarHeight',
    'sets the rendered avatar height',
    set: (r) => const _Props(avatarHeight: 61),
    probe: (t, r) => t.getSize(find.byType(CometChatAvatar)),
    unset: const Size(48, 48),
    expected: const Size(48, 61),
  ),
  _Row(
    'avatarWidth',
    'sets the rendered avatar width',
    set: (r) => const _Props(avatarWidth: 59),
    probe: (t, r) => t.getSize(find.byType(CometChatAvatar)),
    unset: const Size(48, 48),
    expected: const Size(59, 48),
  ),
  _Row(
    'avatarPadding',
    'insets the avatar content inside its box',
    set: (r) => const _Props(avatarPadding: EdgeInsets.all(7)),
    probe: (t, r) => t.getSize(_in(CometChatAvatar, ClipRRect)),
    unset: const Size(48, 48),
    expected: const Size(34, 34),
  ),
  _Row(
    'avatarMargin',
    'offsets the avatar box inside its slot',
    set: (r) => const _Props(avatarMargin: EdgeInsets.all(5)),
    probe: (t, r) =>
        t.getTopLeft(_in(CometChatAvatar, ClipRRect)) -
        t.getTopLeft(find.byType(CometChatAvatar)),
    unset: Offset.zero,
    expected: const Offset(5, 5),
  ),
  _Row(
    'statusIndicatorHeight',
    'sets the rendered presence-dot height',
    set: (r) => const _Props(statusIndicatorHeight: 9),
    probe: (t, r) => t.getSize(find.byType(CometChatStatusIndicator)),
    unset: const Size(14, 14),
    expected: const Size(14, 9),
  ),
  _Row(
    'statusIndicatorWidth',
    'sets the rendered presence-dot width',
    set: (r) => const _Props(statusIndicatorWidth: 11),
    probe: (t, r) => t.getSize(find.byType(CometChatStatusIndicator)),
    unset: const Size(14, 14),
    expected: const Size(11, 14),
  ),

  // ── Group-type icons ──────────────────────────────────────────────────────
  // Each base side passes the sibling icon too, so an icon routed to the
  // wrong group type (or receipt state) shows up on one side or the other.
  _Row(
    'privateGroupIcon',
    'replaces the shield inside the private-group badge',
    conversation: _privateGroup,
    base: (r) => const _Props(protectedGroupIcon: _protectedIcon),
    set: (r) => const _Props(
      protectedGroupIcon: _protectedIcon,
      privateGroupIcon: _privateIcon,
    ),
    probe: (t, r) => [
      _count(
        find.descendant(
          of: find.byType(CometChatStatusIndicator),
          matching: find.byKey(_privateIcon.key!),
        ),
      ),
      _count(find.byKey(_protectedIcon.key!)),
      _count(find.byIcon(Icons.shield)),
    ],
    unset: [0, 0, 1],
    expected: [1, 0, 0],
  ),
  _Row(
    'protectedGroupIcon',
    'replaces the lock inside the protected-group badge',
    conversation: _protectedGroup,
    base: (r) => const _Props(privateGroupIcon: _privateIcon),
    set: (r) => const _Props(
      privateGroupIcon: _privateIcon,
      protectedGroupIcon: _protectedIcon,
    ),
    probe: (t, r) => [
      _count(
        find.descendant(
          of: find.byType(CometChatStatusIndicator),
          matching: find.byKey(_protectedIcon.key!),
        ),
      ),
      _count(find.byKey(_privateIcon.key!)),
      _count(find.byIcon(Icons.lock)),
    ],
    unset: [0, 0, 1],
    expected: [1, 0, 0],
  ),

  // ── Receipt icons ─────────────────────────────────────────────────────────
  _Row(
    'readIcon',
    'replaces the tick on a read message',
    signedIn: true,
    conversation: _read,
    base: (r) =>
        const _Props(deliveredIcon: _deliveredIcon, sentIcon: _sentIcon),
    set: (r) => const _Props(
      deliveredIcon: _deliveredIcon,
      sentIcon: _sentIcon,
      readIcon: _readIcon,
    ),
    probe: (t, r) => _receiptReading(Icons.done_all),
    unset: [0, 0, 0, 1],
    expected: [1, 0, 0, 0],
  ),
  _Row(
    'deliveredIcon',
    'replaces the tick on a delivered message',
    signedIn: true,
    conversation: _delivered,
    base: (r) => const _Props(readIcon: _readIcon, sentIcon: _sentIcon),
    set: (r) => const _Props(
      readIcon: _readIcon,
      sentIcon: _sentIcon,
      deliveredIcon: _deliveredIcon,
    ),
    probe: (t, r) => _receiptReading(Icons.done_all),
    unset: [0, 0, 0, 1],
    expected: [0, 1, 0, 0],
  ),
  _Row(
    'sentIcon',
    'replaces the tick on a sent message',
    signedIn: true,
    conversation: _mine,
    base: (r) =>
        const _Props(readIcon: _readIcon, deliveredIcon: _deliveredIcon),
    set: (r) => const _Props(
      readIcon: _readIcon,
      deliveredIcon: _deliveredIcon,
      sentIcon: _sentIcon,
    ),
    probe: (t, r) => _receiptReading(Icons.done),
    unset: [0, 0, 0, 1],
    expected: [0, 0, 1, 0],
  ),

  // ── Slots, formatting and dates ───────────────────────────────────────────
  _Row(
    'subtitleView',
    'replaces the last-message preview and gets the conversation',
    set: (r) => _Props(subtitleView: (c, t) => r.slot(c, t, 'SUB-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('SUB-SENTINEL')),
      _count(_preview('Hello!')),
      r.slotArgs,
    ],
    unset: [0, 1, null],
    expected: [1, 0, ('user_u1', null)],
  ),
  _Row(
    'subtitleView',
    'replaces the typing line and gets the first typer',
    typing: _bobTyping,
    set: (r) => _Props(subtitleView: (c, t) => r.slot(c, t, 'SUB-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('SUB-SENTINEL')),
      _count(find.text(_typingText(t))),
      r.slotArgs,
    ],
    unset: [0, 1, null],
    expected: [1, 0, ('user_u1', 'u2')],
  ),
  _Row(
    'trailingView',
    'replaces the timestamp and badge and gets the conversation',
    set: (r) => _Props(trailingView: (c, t) => r.slot(c, t, 'TAIL-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('TAIL-SENTINEL')),
      _count(find.byType(CometChatDate)),
      _count(find.byType(CometChatBadge)),
      r.slotArgs,
    ],
    unset: [0, 1, 1, null],
    expected: [1, 0, 0, ('user_u1', null)],
  ),
  _Row(
    'trailingView',
    'gets the first typer while someone is typing',
    typing: _bobTyping,
    set: (r) => _Props(trailingView: (c, t) => r.slot(c, t, 'TAIL-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('TAIL-SENTINEL')),
      _count(find.byType(CometChatDate)),
      r.slotArgs,
    ],
    unset: [0, 1, null],
    expected: [1, 0, ('user_u1', 'u2')],
  ),
  _Row(
    'textFormatters',
    'format the last-message preview',
    set: (r) => _Props(textFormatters: [_SentinelFormatter()]),
    probe: (t, r) => _count(_preview('FORMATTED-BY-SENTINEL')),
    unset: 0,
    expected: 1,
  ),
  _Row(
    'dateTimeFormatterCallback',
    'writes the timestamp',
    set: (r) => _Props(dateTimeFormatterCallback: _SentinelDates()),
    probe: (t, r) => _dateText(t).data,
    unset: '12 May, 2026',
    expected: 'WHEN-SENTINEL',
  ),

  // ── Theme tokens ──────────────────────────────────────────────────────────
  _Row(
    'colorPalette',
    'background1 edges the presence dot',
    set: (r) =>
        _Props(colorPalette: CometChatColorPalette(background1: _kPaletteEdge)),
    probe: (t, r) => _dotBorderColor(t),
    unset: _FromTheme((c) => _palette(c).background1),
    expected: _kPaletteEdge,
  ),
  _Row(
    'colorPalette',
    'warning fills the private-group badge and background1 colours its shield',
    conversation: _privateGroup,
    set: (r) => _Props(
      colorPalette: CometChatColorPalette(
        warning: _kWarning,
        background1: _kPaletteEdge,
      ),
    ),
    probe: (t, r) => [
      _decoration(t, CometChatStatusIndicator).color,
      t.widget<Icon>(find.byIcon(Icons.shield)).color,
    ],
    unset: _FromTheme((c) => [_palette(c).warning, _palette(c).background1]),
    expected: [_kWarning, _kPaletteEdge],
  ),
  _Row(
    'colorPalette',
    'success fills the protected-group badge and background1 colours its lock',
    conversation: _protectedGroup,
    set: (r) => _Props(
      colorPalette: CometChatColorPalette(
        success: _kSuccess,
        background1: _kPaletteEdge,
      ),
    ),
    probe: (t, r) => [
      _decoration(t, CometChatStatusIndicator).color,
      t.widget<Icon>(find.byIcon(Icons.lock)).color,
    ],
    unset: _FromTheme((c) => [_palette(c).success, _palette(c).background1]),
    expected: [_kSuccess, _kPaletteEdge],
  ),
  _Row(
    'colorPalette',
    'primary tints the read tick',
    signedIn: true,
    conversation: _read,
    set: (r) => _Props(colorPalette: CometChatColorPalette(primary: _kPrimary)),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.done_all)).color,
    unset: _FromTheme((c) => _palette(c).primary),
    expected: _kPrimary,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the delivered tick',
    signedIn: true,
    conversation: _delivered,
    set: (r) => _Props(
      colorPalette: CometChatColorPalette(iconSecondary: _kIconSecondary),
    ),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.done_all)).color,
    unset: _FromTheme((c) => _palette(c).iconSecondary),
    expected: _kIconSecondary,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the sent tick and the pin',
    signedIn: true,
    conversation: _minePinned,
    set: (r) => _Props(
      colorPalette: CometChatColorPalette(iconSecondary: _kIconSecondary),
    ),
    probe: (t, r) => [
      t.widget<Icon>(find.byIcon(Icons.done)).color,
      t.widget<Icon>(find.byIcon(Icons.push_pin)).color,
    ],
    unset: _FromTheme(
      (c) => [_palette(c).iconSecondary, _palette(c).iconSecondary],
    ),
    expected: [_kIconSecondary, _kIconSecondary],
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the pending clock',
    signedIn: true,
    conversation: _pending,
    set: (r) => _Props(
      colorPalette: CometChatColorPalette(iconSecondary: _kIconSecondary),
    ),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.schedule)).color,
    unset: _FromTheme((c) => _palette(c).iconSecondary),
    expected: _kIconSecondary,
  ),
  _Row(
    'colorPalette',
    'error tints the mark on a message moderation rejected',
    signedIn: true,
    conversation: _rejected,
    set: (r) => _Props(colorPalette: CometChatColorPalette(error: _kError)),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.error_outline)).color,
    unset: _FromTheme((c) => _palette(c).error),
    expected: _kError,
  ),
  _Row(
    'colorPalette',
    'fills in the row, title, preview and date colours a style leaves out',
    base: (r) => const _Props(style: CometChatConversationListItemStyle()),
    set: (r) => _Props(
      style: const CometChatConversationListItemStyle(),
      colorPalette: CometChatColorPalette(
        background1: _kRowBackground,
        textPrimary: _kTitle,
        textSecondary: _kSubtitle,
      ),
    ),
    probe: (t, r) => [
      _rowColor(t),
      _titleStyle(t)?.color,
      _subtitleStyle(t)?.color,
      _dateText(t).style?.color,
    ],
    unset: _FromTheme(
      (c) => [
        _palette(c).background1,
        _palette(c).textPrimary,
        _palette(c).textSecondary,
        _palette(c).textSecondary,
      ],
    ),
    expected: [_kRowBackground, _kTitle, _kSubtitle, _kSubtitle],
  ),
  _Row(
    'colorPalette',
    'fills in the selected row, type glyph and checkbox a style leaves out',
    conversation: _photo,
    selectionMode: SelectionMode.multiple,
    selected: true,
    base: (r) => const _Props(style: CometChatConversationListItemStyle()),
    set: (r) => _Props(
      style: const CometChatConversationListItemStyle(),
      colorPalette: CometChatColorPalette(
        background4: _kSelectedBackground,
        iconSecondary: _kTypeIcon,
        primary: _kCheckFill,
        borderDefault: _kCheckStroke,
      ),
    ),
    probe: (t, r) => [
      _rowColor(t),
      t.widget<Icon>(find.byIcon(Icons.photo)).color,
      _checkbox(t).fillColor?.resolve({WidgetState.selected}),
      _checkbox(t).side?.color,
    ],
    unset: _FromTheme(
      (c) => [
        _palette(c).background4,
        _palette(c).iconSecondary,
        _palette(c).primary,
        _palette(c).borderDefault,
      ],
    ),
    expected: [_kSelectedBackground, _kTypeIcon, _kCheckFill, _kCheckStroke],
  ),
  _Row(
    'colorPalette',
    'textHighlight colours the typing line',
    typing: _bobTyping,
    set: (r) =>
        _Props(colorPalette: CometChatColorPalette(textHighlight: _kHighlight)),
    probe: (t, r) => _typingStyle(t)?.color,
    unset: _FromTheme((c) => _palette(c).textHighlight),
    expected: _kHighlight,
  ),
  _Row(
    'spacing',
    'padding4 and padding3 inset the row; padding3 spaces avatar and title',
    set: (r) => _Props(spacing: CometChatSpacing(padding4: 29, padding3: 13)),
    probe: (t, r) => [
      t.getTopLeft(find.byType(CometChatAvatar)).dx -
          t.getTopLeft(find.byType(CometChatConversationListItem)).dx,
      t.getTopLeft(_in(InkWell, Row).first).dy -
          t.getTopLeft(find.byType(CometChatConversationListItem)).dy,
      t.getTopLeft(find.text('Alice')).dx -
          t.getTopRight(find.byType(CometChatAvatar)).dx,
    ],
    unset: [16.0, 12.0, 12.0],
    expected: [29.0, 13.0, 13.0],
  ),
  _Row(
    'spacing',
    'spacing edges the dot; padding2 insets the trailing column; '
        'padding1 spaces the pin and the tick',
    signedIn: true,
    conversation: _minePinned,
    set: (r) => _Props(
      spacing: CometChatSpacing(spacing: 2.5, padding2: 7, padding1: 5),
    ),
    probe: (t, r) {
      final column = find
          .ancestor(
            of: find.byType(CometChatDate),
            matching: find.byType(Column),
          )
          .first;
      final pin = find.byIcon(Icons.push_pin);
      final tick = find.byIcon(Icons.done);
      final subtitle = find
          .ancestor(of: tick, matching: find.byType(Row))
          .first;
      return [
        (_decoration(t, CometChatStatusIndicator).border as Border?)?.top.width,
        t.getTopLeft(column).dx -
            t
                .getTopLeft(
                  find
                      .ancestor(of: column, matching: find.byType(Padding))
                      .first,
                )
                .dx,
        t
                .getTopRight(
                  find.ancestor(of: pin, matching: find.byType(Padding)).first,
                )
                .dx -
            t.getTopRight(pin).dx,
        t
                .getTopLeft(
                  find
                      .descendant(of: subtitle, matching: find.byType(Expanded))
                      .first,
                )
                .dx -
            t.getTopRight(tick).dx,
      ];
    },
    unset: _FromTheme(
      (c) => [
        _spacing(c).spacing ?? 0,
        _spacing(c).padding2 ?? 0,
        _spacing(c).padding1 ?? 4,
        _spacing(c).padding1 ?? 4,
      ],
    ),
    expected: [2.5, 7.0, 5.0, 5.0],
  ),
  _Row(
    'spacing',
    'padding3 and padding2 place the checkbox; radius1 rounds it',
    selectionMode: SelectionMode.multiple,
    base: (r) => const _Props(style: CometChatConversationListItemStyle()),
    set: (r) => _Props(
      style: const CometChatConversationListItemStyle(),
      spacing: CometChatSpacing(padding3: 11, padding2: 6, radius1: 2.5),
    ),
    probe: (t, r) => [
      t.getTopLeft(find.byType(Checkbox)).dx -
          t.getTopLeft(find.byType(CometChatConversationListItem)).dx,
      t.getTopLeft(find.byType(CometChatAvatar)).dx -
          t.getTopRight(find.byType(Checkbox)).dx,
      (_checkbox(t).shape! as RoundedRectangleBorder).borderRadius,
    ],
    unset: _FromTheme(
      (c) => [
        (_spacing(c).padding4 ?? 16) + (_spacing(c).padding3 ?? 12),
        _spacing(c).padding2 ?? 8,
        BorderRadius.circular(_spacing(c).radius1 ?? 4),
      ],
    ),
    expected: [16.0 + 11, 6.0, BorderRadius.circular(2.5)],
  ),
  _Row(
    'typography',
    'heading2.bold sizes the avatar initials',
    set: (r) => const _Props(
      typography: CometChatTypography(
        heading2: CometChatTextStyleHeading2(bold: TextStyle(fontSize: 27.5)),
      ),
    ),
    probe: (t, r) => _initials(t).style?.fontSize,
    unset: _FromTheme((c) => _typography(c).heading2?.bold?.fontSize),
    expected: 27.5,
  ),
  _Row(
    'typography',
    'caption1.regular sizes the pin glyph',
    conversation: _pinned,
    set: (r) => const _Props(
      typography: CometChatTypography(
        caption1: CometChatTextStyleCaption1(
          regular: TextStyle(fontSize: 15.5),
        ),
      ),
    ),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.push_pin)).size,
    unset: _FromTheme((c) => _typography(c).caption1?.regular?.fontSize),
    expected: 15.5,
  ),
  _Row(
    'typography',
    'sizes the title, preview and date when a style leaves them out',
    base: (r) => const _Props(style: CometChatConversationListItemStyle()),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(),
      typography: CometChatTypography(
        heading4: CometChatTextStyleHeading4(medium: TextStyle(fontSize: 19.5)),
        body: CometChatTextStyleBody(regular: TextStyle(fontSize: 15.5)),
        caption1: CometChatTextStyleCaption1(
          regular: TextStyle(fontSize: 10.5),
        ),
      ),
    ),
    probe: (t, r) => [
      _titleStyle(t)?.fontSize,
      _subtitleStyle(t)?.fontSize,
      _dateText(t).style?.fontSize,
    ],
    unset: _FromTheme(
      (c) => [
        _typography(c).heading4?.medium?.fontSize,
        _typography(c).body?.regular?.fontSize,
        _typography(c).caption1?.regular?.fontSize,
      ],
    ),
    expected: [19.5, 15.5, 10.5],
  ),
  _Row(
    'typography',
    'body.regular sizes the typing line when a style leaves it out',
    typing: _bobTyping,
    base: (r) => const _Props(style: CometChatConversationListItemStyle()),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(),
      typography: CometChatTypography(
        body: CometChatTextStyleBody(regular: TextStyle(fontSize: 15.5)),
      ),
    ),
    probe: (t, r) => _typingStyle(t)?.fontSize,
    unset: _FromTheme((c) => _typography(c).body?.regular?.fontSize),
    expected: 15.5,
  ),

  // ── style: one row per field the item reads ───────────────────────────────
  _Row(
    'style',
    'backgroundColor paints the row',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        backgroundColor: _kRowBackground,
      ),
    ),
    probe: (t, r) => _rowColor(t),
    unset: _FromTheme((c) => _palette(c).background1),
    expected: _kRowBackground,
  ),
  _Row(
    'style',
    'selectedBackgroundColor paints a selected row',
    selected: true,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        selectedBackgroundColor: _kSelectedBackground,
      ),
    ),
    probe: (t, r) => _rowColor(t),
    unset: _FromTheme((c) => _palette(c).background4),
    expected: _kSelectedBackground,
  ),
  _Row(
    'style',
    'titleTextColor colours the title',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(titleTextColor: _kTitle),
    ),
    probe: (t, r) => _titleStyle(t)?.color,
    unset: _FromTheme((c) => _palette(c).textPrimary),
    expected: _kTitle,
  ),
  _Row(
    'style',
    'titleTextStyle sizes the title',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        titleTextStyle: TextStyle(fontSize: 21.5),
      ),
    ),
    probe: (t, r) => _titleStyle(t)?.fontSize,
    unset: _FromTheme((c) => _typography(c).heading4?.medium?.fontSize),
    expected: 21.5,
  ),
  _Row(
    'style',
    'subtitleTextColor colours the last-message preview',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(subtitleTextColor: _kSubtitle),
    ),
    probe: (t, r) => _subtitleStyle(t)?.color,
    unset: _FromTheme((c) => _palette(c).textSecondary),
    expected: _kSubtitle,
  ),
  _Row(
    'style',
    'subtitleTextStyle sizes the last-message preview',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        subtitleTextStyle: TextStyle(fontSize: 13.5),
      ),
    ),
    probe: (t, r) => _subtitleStyle(t)?.fontSize,
    unset: _FromTheme((c) => _typography(c).body?.regular?.fontSize),
    expected: 13.5,
  ),
  _Row(
    'style',
    'subtitleTextColor outranks a colour inside subtitleTextStyle',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        subtitleTextStyle: TextStyle(color: _kOutranked),
        subtitleTextColor: _kSubtitle,
      ),
    ),
    probe: (t, r) => _subtitleStyle(t)?.color,
    unset: _FromTheme((c) => _palette(c).textSecondary),
    expected: _kSubtitle,
  ),
  _Row(
    'style',
    'messageTypeIconTint tints the photo glyph',
    conversation: _photo,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        messageTypeIconTint: _kTypeIcon,
      ),
    ),
    probe: (t, r) => t.widget<Icon>(find.byIcon(Icons.photo)).color,
    unset: _FromTheme((c) => _palette(c).iconSecondary),
    expected: _kTypeIcon,
  ),
  _Row(
    'style',
    'checkBoxCheckedBackgroundColor fills a ticked checkbox',
    selectionMode: SelectionMode.multiple,
    selected: true,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        checkBoxCheckedBackgroundColor: _kCheckFill,
      ),
    ),
    probe: (t, r) => _checkbox(t).fillColor?.resolve({WidgetState.selected}),
    unset: _FromTheme((c) => _palette(c).primary),
    expected: _kCheckFill,
  ),
  _Row(
    'style',
    'checkBoxBackgroundColor fills an empty checkbox',
    selectionMode: SelectionMode.multiple,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        checkBoxBackgroundColor: _kCheckEmpty,
      ),
    ),
    probe: (t, r) => _checkbox(t).fillColor?.resolve(const {}),
    unset: Colors.transparent,
    expected: _kCheckEmpty,
  ),
  _Row(
    'style',
    'checkBoxStrokeColor and checkBoxStrokeWidth draw the checkbox edge',
    selectionMode: SelectionMode.multiple,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        checkBoxStrokeColor: _kCheckStroke,
        checkBoxStrokeWidth: 2.75,
      ),
    ),
    probe: (t, r) => [_checkbox(t).side?.color, _checkbox(t).side?.width],
    unset: _FromTheme((c) => [_palette(c).borderDefault, 1.5]),
    expected: [_kCheckStroke, 2.75],
  ),
  _Row(
    'style',
    'checkBoxBorderRadius rounds the checkbox',
    selectionMode: SelectionMode.multiple,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        checkBoxBorderRadius: _kCheckRadius,
      ),
    ),
    probe: (t, r) =>
        (_checkbox(t).shape! as RoundedRectangleBorder).borderRadius,
    unset: _FromTheme((c) => BorderRadius.circular(_spacing(c).radius1 ?? 4)),
    expected: _kCheckRadius,
  ),
  _Row(
    'style',
    'avatarStyle fills the avatar',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        avatarStyle: CometChatAvatarStyle(backgroundColor: _kAvatar),
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatAvatar).color,
    unset: _FromTheme((c) => _palette(c).extendedPrimary500),
    expected: _kAvatar,
  ),
  _Row(
    'style',
    'statusIndicatorStyle.border edges the presence dot',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          border: _kDotBorder,
        ),
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).border,
    unset: _FromTheme(
      (c) => Border.all(
        width: _spacing(c).spacing ?? 0,
        color: _palette(c).background1 ?? Colors.transparent,
      ),
    ),
    expected: _kDotBorder,
  ),
  _Row(
    'style',
    'statusIndicatorStyle.borderRadius rounds the presence dot',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          borderRadius: _kDotRadius,
        ),
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).borderRadius,
    unset: _FromTheme((c) => BorderRadius.circular(_spacing(c).radiusMax ?? 0)),
    expected: _kDotRadius,
  ),
  _Row(
    'style',
    'dateStyle colours the timestamp',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        dateStyle: CometChatDateStyle(textColor: _kDateText),
      ),
    ),
    probe: (t, r) => _dateText(t).style?.color,
    unset: _FromTheme((c) => _palette(c).textSecondary),
    expected: _kDateText,
  ),
  _Row(
    'style',
    'dateStyle.textStyle sizes the timestamp',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        dateStyle: CometChatDateStyle(textStyle: TextStyle(fontSize: 11.5)),
      ),
    ),
    probe: (t, r) => _dateText(t).style?.fontSize,
    unset: _FromTheme((c) => _typography(c).caption1?.regular?.fontSize),
    expected: 11.5,
  ),
  _Row(
    'style',
    'dateStyle.borderRadius rounds the timestamp box',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        dateStyle: CometChatDateStyle(borderRadius: _kDateRadius),
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatDate).borderRadius,
    unset: _FromTheme(
      (c) => BorderRadius.all(Radius.circular(_spacing(c).radius1 ?? 0)),
    ),
    expected: _kDateRadius,
  ),
  _Row(
    'style',
    'badgeStyle fills the unread badge',
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        badgeStyle: CometChatBadgeStyle(backgroundColor: _kBadge),
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatBadge).color,
    unset: _FromTheme((c) => _palette(c).primary),
    expected: _kBadge,
  ),
  _Row(
    'style',
    'typingIndicatorStyle sizes the typing line',
    typing: _bobTyping,
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        typingIndicatorStyle: CometChatTypingIndicatorStyle(
          textStyle: TextStyle(fontSize: 17.5),
        ),
      ),
    ),
    probe: (t, r) => _typingStyle(t)?.fontSize,
    unset: _FromTheme((c) => _typography(c).body?.regular?.fontSize),
    expected: 17.5,
  ),

  // ── Per-part styles, and that each outranks its style field ───────────────
  _Row(
    'avatarStyle',
    'fills the avatar',
    set: (r) => const _Props(
      avatarStyle: CometChatAvatarStyle(backgroundColor: _kAvatar),
    ),
    probe: (t, r) => _decoration(t, CometChatAvatar).color,
    unset: _FromTheme((c) => _palette(c).extendedPrimary500),
    expected: _kAvatar,
  ),
  _Row(
    'avatarStyle',
    'outranks style.avatarStyle',
    base: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        avatarStyle: CometChatAvatarStyle(backgroundColor: _kOutranked),
      ),
    ),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        avatarStyle: CometChatAvatarStyle(backgroundColor: _kOutranked),
      ),
      avatarStyle: CometChatAvatarStyle(backgroundColor: _kAvatar),
    ),
    probe: (t, r) => _decoration(t, CometChatAvatar).color,
    unset: _kOutranked,
    expected: _kAvatar,
  ),
  _Row(
    'statusIndicatorStyle',
    'border edges the presence dot',
    set: (r) => const _Props(
      statusIndicatorStyle: CometChatStatusIndicatorStyle(border: _kDotBorder),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).border,
    unset: _FromTheme(
      (c) => Border.all(
        width: _spacing(c).spacing ?? 0,
        color: _palette(c).background1 ?? Colors.transparent,
      ),
    ),
    expected: _kDotBorder,
  ),
  _Row(
    'statusIndicatorStyle',
    'borderRadius rounds the presence dot',
    set: (r) => const _Props(
      statusIndicatorStyle: CometChatStatusIndicatorStyle(
        borderRadius: _kDotRadius,
      ),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).borderRadius,
    unset: _FromTheme((c) => BorderRadius.circular(_spacing(c).radiusMax ?? 0)),
    expected: _kDotRadius,
  ),
  _Row(
    'statusIndicatorStyle',
    'outranks style.statusIndicatorStyle',
    base: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          border: _kOutrankedBorder,
        ),
      ),
    ),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          border: _kOutrankedBorder,
        ),
      ),
      statusIndicatorStyle: CometChatStatusIndicatorStyle(border: _kDotBorder),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).border,
    unset: _kOutrankedBorder,
    expected: _kDotBorder,
  ),
  _Row(
    'dateStyle',
    'textColor colours the timestamp',
    set: (r) =>
        const _Props(dateStyle: CometChatDateStyle(textColor: _kDateText)),
    probe: (t, r) => _dateText(t).style?.color,
    unset: _FromTheme((c) => _palette(c).textSecondary),
    expected: _kDateText,
  ),
  _Row(
    'dateStyle',
    'textStyle sizes the timestamp',
    set: (r) => const _Props(
      dateStyle: CometChatDateStyle(textStyle: TextStyle(fontSize: 11.5)),
    ),
    probe: (t, r) => _dateText(t).style?.fontSize,
    unset: _FromTheme((c) => _typography(c).caption1?.regular?.fontSize),
    expected: 11.5,
  ),
  _Row(
    'dateStyle',
    'borderRadius rounds the timestamp box',
    set: (r) =>
        const _Props(dateStyle: CometChatDateStyle(borderRadius: _kDateRadius)),
    probe: (t, r) => _decoration(t, CometChatDate).borderRadius,
    unset: _FromTheme(
      (c) => BorderRadius.all(Radius.circular(_spacing(c).radius1 ?? 0)),
    ),
    expected: _kDateRadius,
  ),
  _Row(
    'dateStyle',
    'outranks style.dateStyle',
    base: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        dateStyle: CometChatDateStyle(textColor: _kOutranked),
      ),
    ),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        dateStyle: CometChatDateStyle(textColor: _kOutranked),
      ),
      dateStyle: CometChatDateStyle(textColor: _kDateText),
    ),
    probe: (t, r) => _dateText(t).style?.color,
    unset: _kOutranked,
    expected: _kDateText,
  ),
  _Row(
    'badgeStyle',
    'fills the unread badge and colours its count',
    set: (r) => const _Props(
      badgeStyle: CometChatBadgeStyle(
        backgroundColor: _kBadge,
        textColor: _kBadgeText,
      ),
    ),
    probe: (t, r) => [
      _decoration(t, CometChatBadge).color,
      t.widget<Text>(find.text('3')).style?.color,
    ],
    unset: _FromTheme(
      (c) => [_palette(c).primary, _palette(c).buttonIconColor],
    ),
    expected: [_kBadge, _kBadgeText],
  ),
  _Row(
    'badgeStyle',
    'outranks style.badgeStyle',
    base: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        badgeStyle: CometChatBadgeStyle(backgroundColor: _kOutranked),
      ),
    ),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        badgeStyle: CometChatBadgeStyle(backgroundColor: _kOutranked),
      ),
      badgeStyle: CometChatBadgeStyle(backgroundColor: _kBadge),
    ),
    probe: (t, r) => _decoration(t, CometChatBadge).color,
    unset: _kOutranked,
    expected: _kBadge,
  ),
  _Row(
    'typingIndicatorStyle',
    'textStyle sizes the typing line',
    typing: _bobTyping,
    set: (r) => const _Props(
      typingIndicatorStyle: CometChatTypingIndicatorStyle(
        textStyle: TextStyle(fontSize: 17.5),
      ),
    ),
    probe: (t, r) => _typingStyle(t)?.fontSize,
    unset: _FromTheme((c) => _typography(c).body?.regular?.fontSize),
    expected: 17.5,
  ),
  _Row(
    'typingIndicatorStyle',
    'outranks style.typingIndicatorStyle',
    typing: _bobTyping,
    base: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        typingIndicatorStyle: CometChatTypingIndicatorStyle(
          textStyle: TextStyle(fontSize: 9.5),
        ),
      ),
    ),
    set: (r) => const _Props(
      style: CometChatConversationListItemStyle(
        typingIndicatorStyle: CometChatTypingIndicatorStyle(
          textStyle: TextStyle(fontSize: 9.5),
        ),
      ),
      typingIndicatorStyle: CometChatTypingIndicatorStyle(
        textStyle: TextStyle(fontSize: 17.5),
      ),
    ),
    probe: (t, r) => _typingStyle(t)?.fontSize,
    unset: 9.5,
    expected: 17.5,
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatConversationListItem prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        if (row.signedIn) {
          CometChatUIKit.loggedInUser = _me;
          addTearDown(() => CometChatUIKit.loggedInUser = null);
        }
        final sides = <(String, _Props Function(_Rec), Object?)>[
          ('base', row.base ?? (r) => const _Props(), row.unset),
          ('set', row.set, row.expected),
        ];
        final readings = <Object?>[];

        for (final (label, build, expected) in sides) {
          final rec = _Rec();
          final p = build(rec);
          final conversation = row.conversation();
          void onItemClick(Conversation _) => rec.clicks++;

          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                switch (p) {
                  // A flag row passes its flag alone, so the base side, which
                  // takes the last branch, leaves every flag at its default.
                  _Props(hideUserStatus: final bool v) =>
                    CometChatConversationListItem(
                      conversation: conversation,
                      onItemClick: onItemClick,
                      hideUserStatus: v,
                    ),
                  _Props(hideGroupType: final bool v) =>
                    CometChatConversationListItem(
                      conversation: conversation,
                      onItemClick: onItemClick,
                      hideGroupType: v,
                    ),
                  _Props(hideReceipts: final bool v) =>
                    CometChatConversationListItem(
                      conversation: conversation,
                      onItemClick: onItemClick,
                      hideReceipts: v,
                    ),
                  _Props(hideThreadIndicator: final bool v) =>
                    CometChatConversationListItem(
                      conversation: conversation,
                      onItemClick: onItemClick,
                      hideThreadIndicator: v,
                    ),
                  _ => CometChatConversationListItem(
                    conversation: conversation,
                    onItemClick: onItemClick,
                    isSelected: row.selected,
                    selectionMode: row.selectionMode,
                    typingIndicators: row.typing,
                    onSelectionToggle: p.onSelectionToggle,
                    textFormatters: p.textFormatters,
                    dateTimeFormatterCallback: p.dateTimeFormatterCallback,
                    style: p.style,
                    avatarStyle: p.avatarStyle,
                    statusIndicatorStyle: p.statusIndicatorStyle,
                    dateStyle: p.dateStyle,
                    badgeStyle: p.badgeStyle,
                    typingIndicatorStyle: p.typingIndicatorStyle,
                    avatarHeight: p.avatarHeight,
                    avatarWidth: p.avatarWidth,
                    avatarPadding: p.avatarPadding,
                    avatarMargin: p.avatarMargin,
                    statusIndicatorHeight: p.statusIndicatorHeight,
                    statusIndicatorWidth: p.statusIndicatorWidth,
                    subtitleView: p.subtitleView,
                    trailingView: p.trailingView,
                    colorPalette: p.colorPalette,
                    spacing: p.spacing,
                    typography: p.typography,
                    privateGroupIcon: p.privateGroupIcon,
                    protectedGroupIcon: p.protectedGroupIcon,
                    readIcon: p.readIcon,
                    deliveredIcon: p.deliveredIcon,
                    sentIcon: p.sentIcon,
                  ),
                },
                // A fresh app per side, so no element state carries over.
                key: ValueKey(label),
              ),
            ),
          );
          await tester.pump();
          await row.act?.call(tester);

          final reading = row.probe(tester, rec);
          final want = expected is _FromTheme
              ? expected.of(_ctx(tester))
              : expected;
          expect(reading, want, reason: '${row.prop}, $label side');
          readings.add(reading);
        }

        expect(
          readings.last,
          isNot(equals(readings.first)),
          reason: '${row.prop} must render differently from its base side',
        );
      });
    }
  });

  test('every wired prop has a row, and every row sets the prop it names', () {
    final rec = _Rec();
    expect({for (final row in _matrix) row.prop}, _Props.wired);
    expect(_Props.wired, isNot(contains('receiptStyle')));
    for (final row in _matrix) {
      final set = row.set(rec).setNames;
      final base = (row.base ?? (r) => const _Props())(rec).setNames;
      expect(set, contains(row.prop), reason: row.claim);
      expect(base, isNot(contains(row.prop)), reason: row.claim);
      expect(set.difference(base), {row.prop}, reason: row.claim);
      if (_Props.flags.contains(row.prop)) {
        // A flag row is built by a construction that passes only that flag.
        expect(set, {row.prop}, reason: row.claim);
        expect(base, isEmpty, reason: row.claim);
        expect(row.selectionMode, SelectionMode.none, reason: row.claim);
        expect(row.typing, isEmpty, reason: row.claim);
        expect(row.selected, isFalse, reason: row.claim);
      } else {
        expect(set.intersection(_Props.flags), isEmpty, reason: row.claim);
      }
    }
  });
}
