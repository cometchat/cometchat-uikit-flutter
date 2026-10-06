/// Render-verified prop matrix for [ConversationsSubtitleView] — Track 3
/// PROP1 (ENG-38688, coverage part 2).
///
/// [ConversationsSubtitleView] is exported but nothing in lib builds it, so the
/// matrix renders it standalone: a receipt tick, a thread arrow, a typing
/// line or the last-message preview, depending on the conversation and the
/// flags.
///
/// How the matrix works. [_matrix] is a table. Each row names the prop it
/// verifies, the conversation it renders, the values it sets (sentinels no
/// theme uses), a probe that reads the rendered element the prop controls,
/// and what the probe must return. Every row is pumped twice in one test
/// body. The first side is either the unset construction, which passes only
/// the required tokens at their baseline and omits every optional prop so the
/// constructor defaults are pinned, or an explicit `unflipped` side. The two
/// readings must differ, so a row whose assertion would still hold if the
/// view ignored the prop fails here. The guard test at the bottom fails if a
/// prop loses its row or a row stops setting the prop it names.
///
/// The set side passes every optional prop straight through, so a row that
/// needs the default receipt passes `hideThreadIndicator: true` explicitly:
/// an explicit null there hides every receipt (see below).
///
/// Every one of the 15 props has at least one row, and props read in more
/// than one place (colorPalette, typography, style, receiptStyle, spacing,
/// typingIndicators, hideThreadIndicator, receiptsVisibility) have a row per
/// read site. Behaviour reported rather than tested around:
///
/// * hideThreadIndicator: false builds a "Sender: " prefix for incoming
///   messages (lib 104-111), but the only Text that paints it sits in the
///   branch that requires the logged-in user to be the sender (121-161), so
///   it is always the empty string.
/// * hideThreadIndicator: an explicit null fails both `!= null` guards
///   (121, 166), so the view paints no receipt at all, where the documented
///   default (true) paints one.
/// * The waiting receipt is drawn by CometChatReceipt from the theme palette:
///   the view never forwards colorPalette (or a waitIcon) to it (229-260).
/// * hideThreadIndicator: false routes the tick through the thread row
///   (121-132), which skips both checks the plain path makes: it keeps the
///   tick while someone is typing (165 is not applied) and puts a tick on a
///   call (_getHideReceipt's call check, 198-200, is not applied).
/// * textFormatters are only handed on for a TextMessage (306-323), so a
///   captioned media message's caption is never formatted, although
///   ConversationSubtitleUtils supports it (95-131).
///
///   flutter test test/chat_ui/conversations/widget/conversations_subtitle_view_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, this.name, {this.role = 'default'});

  @override
  final String uid;

  @override
  final String name;

  @override
  final String? role;

  @override
  String get status => 'online';

  @override
  String? get avatar => null;

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
    this.text = 'Hello!',
    this.id = 100,
    this.deliveredAt,
    this.readAt,
    this.replyCount = 0,
    this.metadata,
    this.mentionedUsers = const [],
    this.type = 'text',
    this.category = 'message',
    this.deletedAt,
  }) : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  final String text;

  @override
  final int id;

  @override
  final DateTime? deliveredAt;

  @override
  final DateTime? readAt;

  @override
  final int replyCount;

  @override
  final Map<String, dynamic>? metadata;

  @override
  final List<User> mentionedUsers;

  @override
  final String type;

  @override
  final String category;

  @override
  final DateTime? deletedAt;

  @override
  DateTime get sentAt => DateTime(2020, 1, 2, 10, 30);

  @override
  String get receiverUid => 'u1';

  @override
  int get parentMessageId => 0;

  @override
  String get muid => 'muid_$id';

  @override
  List<ReactionCount> get reactions => [];

  @override
  List<String> get tags => [];
}

class _FakeMediaMessage extends Mock implements MediaMessage {
  _FakeMediaMessage({required User from}) : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  int get id => 101;

  @override
  DateTime get sentAt => DateTime(2020, 1, 2, 10, 30);

  @override
  String get type => 'image';

  @override
  String get category => 'message';

  @override
  String? get caption => null;

  @override
  int get replyCount => 0;

  @override
  String get receiverUid => 'u1';

  @override
  int get parentMessageId => 0;

  @override
  String get muid => 'muid_101';

  @override
  List<User> get mentionedUsers => [];

  @override
  List<ReactionCount> get reactions => [];

  @override
  List<String> get tags => [];
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation({
    required this.conversationWith,
    required this.conversationId,
    BaseMessage? lastMessage,
  }) : _lastMessage = lastMessage;

  @override
  final String conversationId;

  @override
  final AppEntity conversationWith;

  final BaseMessage? _lastMessage;

  @override
  BaseMessage? get lastMessage => _lastMessage;

  @override
  int get unreadMessageCount => 0;

  @override
  String get conversationType => conversationWith is User ? 'user' : 'group';

  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
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

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = _FakeUser('me', 'Me');
final _alice = _FakeUser('u1', 'Alice');
final _bob = _FakeUser('u2', 'Bob');
final _cara = _FakeUser('u3', 'Cara');

Conversation _chat({
  AppEntity? withWhom,
  BaseMessage? last,
  String id = 'user_u1',
}) => _FakeConversation(
  conversationWith: withWhom ?? _alice,
  conversationId: id,
  lastMessage: last,
);

/// Alice, no last message: the preview is the tap-to-start line.
Conversation _blank() => _chat();

/// Alice, last message "Hello!" from Bob.
Conversation _incoming() => _chat(last: _FakeTextMessage(from: _bob));

/// Alice, last message one the signed-in user sent.
Conversation _mine({
  bool read = false,
  bool delivered = false,
  int id = 100,
  int replies = 0,
  Map<String, dynamic>? metadata,
  String type = 'text',
  String category = 'message',
  bool deleted = false,
}) => _chat(
  last: _FakeTextMessage(
    from: _me,
    id: id,
    replyCount: replies,
    metadata: metadata,
    type: type,
    category: category,
    deletedAt: deleted ? DateTime(2020, 1, 2, 10, 35) : null,
    readAt: read ? DateTime(2020, 1, 2, 10, 32) : null,
    deliveredAt: delivered || read ? DateTime(2020, 1, 2, 10, 31) : null,
  ),
);

/// My last message, with replies, so the thread row has an arrow.
Conversation _threaded() => _mine(replies: 2);

/// Alice, last message a photo from Bob: a media-type icon leads the preview.
Conversation _photo() => _chat(last: _FakeMediaMessage(from: _bob));

Conversation _group() => _chat(
  withWhom: _FakeGroup('g1', 'Dev Team', 'public'),
  id: 'group_g1',
  last: _FakeTextMessage(from: _bob),
);

Conversation _agent(String role) => _chat(
  withWhom: _FakeUser('bot', 'Helper Bot', role: role),
  id: 'user_bot',
  last: _FakeTextMessage(from: _bob),
);

/// Bob's last message mentions Cara by uid.
Conversation _mention() => _chat(
  last: _FakeTextMessage(
    from: _bob,
    text: '<@uid:u3> ping',
    mentionedUsers: [_cara],
  ),
);

TypingIndicator _typer(User who) =>
    TypingIndicator(sender: who, receiverId: 'u1', receiverType: 'user');

// Baseline tokens: what every row renders with unless it overrides one.
const _style = CometChatConversationsStyle();
final _receiptStyle = CometChatMessageReceiptStyle();
const _typingStyle = CometChatTypingIndicatorStyle();

const _kTextSecondary = Color(0xFF727272);
const _kTextHighlight = Color(0xFF6852D6);
const _kIconSecondary = Color(0xFFA1A1A1);
const _kIconHighlight = Color(0xFF3E2BA8);
const _kErrorBase = Color(0xFFF44649);

final _palette = CometChatColorPalette(
  textSecondary: _kTextSecondary,
  textHighlight: _kTextHighlight,
  iconSecondary: _kIconSecondary,
  iconHighlight: _kIconHighlight,
  error: _kErrorBase,
);

final _spacing = CometChatSpacing(padding: 2, padding1: 4, padding2: 8);

const _typography = CometChatTypography(
  body: CometChatTextStyleBody(regular: TextStyle(fontSize: 14)),
);

// Sentinels: values no theme produces, so a match can only come from the prop.
const _kSubtitle = Color(0xFF1A2B3C);
const _kTypeIcon = Color(0xFF2B3C4D);
const _kSent = Color(0xFF3C4D5E);
const _kDelivered = Color(0xFF4D5E6F);
const _kRead = Color(0xFF5E6F70);
const _kError = Color(0xFF6F7081);
const _kWait = Color(0xFF708192);
const _kTyping = Color(0xFF8192A3);
const _kPalette = Color(0xFF92A3B4);
const _kSubtitleLoser = Color(0xFF9A8B7C);

// The textStyle carries a colour of its own, so the view's final
// `copyWith(color: itemSubtitleTextColor)` is what makes the colour win.
const _kSubtitleStyle = CometChatConversationsStyle(
  itemSubtitleTextColor: _kSubtitle,
  itemSubtitleTextStyle: TextStyle(fontSize: 13.25, color: _kSubtitleLoser),
);

const _kTypography = CometChatTypography(
  body: CometChatTextStyleBody(
    regular: TextStyle(
      fontSize: 14.75,
      fontWeight: FontWeight.w300,
      fontFamily: 'SentinelSans',
    ),
  ),
);
const _kTypographyReading = (14.75, FontWeight.w300, 'SentinelSans');

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every value a row can set. Each field is a prop wired into the set-side
/// construction in [main]; the guard test holds each field to a row.
class _Props {
  const _Props({
    this.conversation,
    this.typingIndicators,
    this.style,
    this.receiptStyle,
    this.typingStyle,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.hideThreadIndicator,
    this.receiptsVisibility,
    this.typingIndicatorText,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
    this.textFormatters,
  });

  final Conversation? conversation;
  final List<TypingIndicator>? typingIndicators;
  final CometChatConversationsStyle? style;
  final CometChatMessageReceiptStyle? receiptStyle;
  final CometChatTypingIndicatorStyle? typingStyle;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final bool? hideThreadIndicator;
  final bool? receiptsVisibility;
  final String? typingIndicatorText;
  final Widget? readIcon;
  final Widget? deliveredIcon;
  final Widget? sentIcon;
  final List<CometChatTextFormatter>? textFormatters;

  Map<String, Object?> get values => {
    'conversation': conversation,
    'typingIndicators': typingIndicators,
    'style': style,
    'receiptStyle': receiptStyle,
    'typingStyle': typingStyle,
    'colorPalette': colorPalette,
    'spacing': spacing,
    'typography': typography,
    'hideThreadIndicator': hideThreadIndicator,
    'receiptsVisibility': receiptsVisibility,
    'typingIndicatorText': typingIndicatorText,
    'readIcon': readIcon,
    'deliveredIcon': deliveredIcon,
    'sentIcon': sentIcon,
    'textFormatters': textFormatters,
  };

  /// The props this instance actually sets.
  Set<String> get setNames => {
    for (final e in values.entries)
      if (e.value != null) e.key,
  };

  /// Every prop the set-side construction reads from a row.
  static Set<String> get wired => const _Props().values.keys.toSet();
}

/// Marks a side whose reading is not checked on its own, only against the
/// other side's, which it must not match.
class _Differs {
  const _Differs();
}

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.conversation,
    required this.set,
    required this.probe,
    required this.expected,
    this.unflipped,
    this.before = const _Differs(),
    this.signedIn = false,
  });

  /// The [ConversationsSubtitleView] parameter this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// The conversation both sides render (a row may override it on a side).
  final Conversation Function() conversation;

  /// The values the set side passes.
  final _Props Function() set;

  /// The first side's values. Null: the unset construction, which omits every
  /// optional prop and passes the baseline tokens.
  final _Props Function()? unflipped;

  /// Reads the rendered element the prop controls.
  final Object? Function(WidgetTester tester) probe;

  /// What [probe] must return on the set side.
  final Object? expected;

  /// What [probe] must return on the first side.
  final Object? before;

  /// Signs [_me] in, so receipts show on messages [_me] sent.
  final bool signedIn;
}

Finder _inView(Finder finder) => find.descendant(
  of: find.byType(ConversationsSubtitleView),
  matching: finder,
);

int _count(Finder finder) => finder.evaluate().length;

Translations _tr(WidgetTester tester) =>
    Translations.of(tester.element(find.byType(ConversationsSubtitleView)));

/// The plain text of every paragraph the view paints.
List<String> _lines(WidgetTester tester) => [
  for (final r in tester.widgetList<RichText>(_inView(find.byType(RichText))))
    r.text.toPlainText(),
];

bool _says(WidgetTester tester, String line) => _lines(tester).contains(line);

bool _shows(WidgetTester tester, String part) =>
    _lines(tester).any((line) => line.contains(part));

TextStyle? _styleOf(WidgetTester tester, String data) =>
    tester.widget<Text>(_inView(find.text(data))).style;

(Color?, double?) _look(WidgetTester tester, String data) {
  final style = _styleOf(tester, data);
  return (style?.color, style?.fontSize);
}

(double?, FontWeight?, String?) _face(WidgetTester tester, String data) {
  final style = _styleOf(tester, data);
  return (style?.fontSize, style?.fontWeight, style?.fontFamily);
}

Color? _tint(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(_inView(find.byIcon(icon))).color;

/// The padding of the nearest Padding above [finder].
EdgeInsetsGeometry _padAbove(WidgetTester tester, Finder finder) => tester
    .widget<Padding>(
      find.ancestor(of: finder, matching: find.byType(Padding)).first,
    )
    .padding;

String _tapToStart(WidgetTester t) => _tr(t).tapToStartConversation;

/// The thread-row prefix: always the empty string (see the header).
const _prefix = '';

final _matrix = <_Row>[
  // ── conversation ──────────────────────────────────────────────────────────
  _Row(
    'conversation',
    'its last message is the preview line',
    conversation: _blank,
    set: () => _Props(
      conversation: _chat(
        last: _FakeTextMessage(from: _bob, text: 'preview-sentinel-4K'),
      ),
    ),
    probe: (t) => [_says(t, _tapToStart(t)), _shows(t, 'preview-sentinel-4K')],
    before: [true, false],
    expected: [false, true],
  ),
  _Row(
    'conversation',
    'an AI agent (aiRole) conversation gets no subtitle at all',
    conversation: _incoming,
    set: () => _Props(conversation: _agent(AIConstants.aiRole)),
    probe: (t) => [_count(_inView(find.byType(Row))) > 0, _shows(t, 'Hello!')],
    before: [true, true],
    expected: [false, false],
  ),
  _Row(
    'conversation',
    "an AI agent with the literal role 'ai' gets no subtitle either",
    conversation: _incoming,
    set: () => _Props(conversation: _agent('ai')),
    probe: (t) => [_count(_inView(find.byType(Row))) > 0, _shows(t, 'Hello!')],
    before: [true, true],
    expected: [false, false],
  ),
  _Row(
    'conversation',
    'a reply count puts the arrow on the thread row; none, no arrow',
    signedIn: true,
    conversation: _mine,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => _Props(hideThreadIndicator: false, conversation: _threaded()),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.subdirectory_arrow_right))),
      _count(_inView(find.text(_prefix))),
      _count(_inView(find.byIcon(Icons.check))),
    ],
    before: [0, 0, 1],
    expected: [1, 1, 1],
  ),
  _Row(
    'conversation',
    "the thread row is only for the signed-in user's own last message",
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => _Props(
      hideThreadIndicator: false,
      conversation: _chat(last: _FakeTextMessage(from: _bob, replyCount: 2)),
    ),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.subdirectory_arrow_right))),
      _count(_inView(find.byType(CometChatReceipt))),
    ],
    before: [1, 1],
    expected: [0, 0],
  ),
  // Which last messages carry a tick. The unset side is always my own sent
  // text message, which does.
  _Row(
    'conversation',
    "only the signed-in user's own last message gets a tick",
    signedIn: true,
    conversation: _mine,
    set: () => _Props(conversation: _incoming(), hideThreadIndicator: true),
    probe: (t) => _count(_inView(find.byType(CometChatReceipt))),
    before: 1,
    expected: 0,
  ),
  _Row(
    'conversation',
    'a deleted last message gets no tick',
    signedIn: true,
    conversation: _mine,
    set: () =>
        _Props(conversation: _mine(deleted: true), hideThreadIndicator: true),
    probe: (t) => _count(_inView(find.byType(CometChatReceipt))),
    before: 1,
    expected: 0,
  ),
  _Row(
    'conversation',
    'a groupMember action as the last message gets no tick',
    signedIn: true,
    conversation: _mine,
    set: () => _Props(
      conversation: _mine(type: 'groupMember'),
      hideThreadIndicator: true,
    ),
    probe: (t) => _count(_inView(find.byType(CometChatReceipt))),
    before: 1,
    expected: 0,
  ),
  _Row(
    'conversation',
    'a call as the last message gets no tick',
    signedIn: true,
    conversation: _mine,
    set: () => _Props(
      conversation: _mine(category: MessageCategoryConstants.call),
      hideThreadIndicator: true,
    ),
    probe: (t) => _count(_inView(find.byType(CometChatReceipt))),
    before: 1,
    expected: 0,
  ),

  // ── typingIndicators ──────────────────────────────────────────────────────
  _Row(
    'typingIndicators',
    'one typer in a user chat replaces the preview with the typing line',
    conversation: _incoming,
    set: () => _Props(typingIndicators: [_typer(_bob)]),
    probe: (t) => [_says(t, _tr(t).isTyping), _shows(t, 'Hello!')],
    before: [false, true],
    expected: [true, false],
  ),
  _Row(
    'typingIndicators',
    'one typer in a group is named',
    conversation: _group,
    set: () => _Props(typingIndicators: [_typer(_cara)]),
    probe: (t) => _says(t, 'Cara ${_tr(t).isTyping}'),
    before: false,
    expected: true,
  ),
  _Row(
    'typingIndicators',
    'three typers are counted',
    conversation: _group,
    set: () =>
        _Props(typingIndicators: [_typer(_alice), _typer(_bob), _typer(_cara)]),
    probe: (t) => _says(t, '3 people are typing...'),
    before: false,
    expected: true,
  ),
  _Row(
    'typingIndicators',
    'a typer hides the tick on my own last message',
    signedIn: true,
    conversation: _mine,
    set: () =>
        _Props(typingIndicators: [_typer(_bob)], hideThreadIndicator: true),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.check))),
      _says(t, _tr(t).isTyping),
    ],
    before: [1, false],
    expected: [0, true],
  ),

  // ── style ─────────────────────────────────────────────────────────────────
  _Row(
    'style',
    'itemSubtitleTextColor and itemSubtitleTextStyle style the preview',
    conversation: _blank,
    set: () => const _Props(style: _kSubtitleStyle),
    probe: (t) => _look(t, _tapToStart(t)),
    before: (_kTextSecondary, 14.0),
    expected: (_kSubtitle, 13.25),
  ),
  _Row(
    'style',
    'the same fields style the thread-row prefix',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => const _Props(hideThreadIndicator: false, style: _kSubtitleStyle),
    probe: (t) => _look(t, _prefix),
    before: (_kTextSecondary, 14.0),
    expected: (_kSubtitle, 13.25),
  ),
  _Row(
    'style',
    'messageTypeIconColor tints the media-type icon',
    conversation: _photo,
    set: () => const _Props(
      style: CometChatConversationsStyle(messageTypeIconColor: _kTypeIcon),
    ),
    probe: (t) => _tint(t, Icons.photo),
    before: _kIconSecondary,
    expected: _kTypeIcon,
  ),

  // ── receiptStyle ──────────────────────────────────────────────────────────
  _Row(
    'receiptStyle',
    'sentIconColor tints the sent tick',
    signedIn: true,
    conversation: _mine,
    set: () => _Props(
      receiptStyle: CometChatMessageReceiptStyle(sentIconColor: _kSent),
      hideThreadIndicator: true,
    ),
    probe: (t) => _tint(t, Icons.check),
    before: _kIconSecondary,
    expected: _kSent,
  ),
  _Row(
    'receiptStyle',
    'deliveredIconColor tints the delivered tick',
    signedIn: true,
    conversation: () => _mine(delivered: true),
    set: () => _Props(
      receiptStyle: CometChatMessageReceiptStyle(
        deliveredIconColor: _kDelivered,
      ),
      hideThreadIndicator: true,
    ),
    probe: (t) => _tint(t, Icons.done_all),
    before: _kIconSecondary,
    expected: _kDelivered,
  ),
  _Row(
    'receiptStyle',
    'readIconColor tints the read tick',
    signedIn: true,
    conversation: () => _mine(read: true),
    set: () => _Props(
      receiptStyle: CometChatMessageReceiptStyle(readIconColor: _kRead),
      hideThreadIndicator: true,
    ),
    probe: (t) => _tint(t, Icons.done_all),
    before: _kIconHighlight,
    expected: _kRead,
  ),
  _Row(
    'receiptStyle',
    'errorIconColor tints the failed-send icon',
    signedIn: true,
    conversation: () => _mine(metadata: {'error': 'send failed'}),
    set: () => _Props(
      receiptStyle: CometChatMessageReceiptStyle(errorIconColor: _kError),
      hideThreadIndicator: true,
    ),
    probe: (t) => _tint(t, Icons.error_outlined),
    before: _kErrorBase,
    expected: _kError,
  ),
  _Row(
    'receiptStyle',
    'reaches CometChatReceipt, whose waitIconColor tints the pending clock',
    signedIn: true,
    conversation: () => _mine(id: 0),
    set: () => _Props(
      receiptStyle: CometChatMessageReceiptStyle(waitIconColor: _kWait),
      hideThreadIndicator: true,
    ),
    probe: (t) => _tint(t, Icons.schedule),
    expected: _kWait,
  ),

  // ── typingStyle ───────────────────────────────────────────────────────────
  _Row(
    'typingStyle',
    'textStyle styles the typing line',
    conversation: _incoming,
    unflipped: () => _Props(typingIndicators: [_typer(_bob)]),
    set: () => _Props(
      typingIndicators: [_typer(_bob)],
      typingStyle: const CometChatTypingIndicatorStyle(
        textStyle: TextStyle(color: _kTyping, fontSize: 21.5),
      ),
    ),
    probe: (t) => _look(t, _tr(t).isTyping),
    before: (_kTextHighlight, 14.0),
    expected: (_kTyping, 21.5),
  ),

  // ── colorPalette, one row per read site ───────────────────────────────────
  _Row(
    'colorPalette',
    'textSecondary colours the preview',
    conversation: _blank,
    set: () =>
        _Props(colorPalette: _palette.copyWith(textSecondary: _kPalette)),
    probe: (t) => _styleOf(t, _tapToStart(t))?.color,
    before: _kTextSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'textSecondary colours the thread-row prefix',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => _Props(
      hideThreadIndicator: false,
      colorPalette: _palette.copyWith(textSecondary: _kPalette),
    ),
    probe: (t) => _styleOf(t, _prefix)?.color,
    before: _kTextSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'textHighlight colours the typing line',
    conversation: _incoming,
    unflipped: () => _Props(typingIndicators: [_typer(_bob)]),
    set: () => _Props(
      typingIndicators: [_typer(_bob)],
      colorPalette: _palette.copyWith(textHighlight: _kPalette),
    ),
    probe: (t) => _styleOf(t, _tr(t).isTyping)?.color,
    before: _kTextHighlight,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the thread arrow',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => _Props(
      hideThreadIndicator: false,
      colorPalette: _palette.copyWith(iconSecondary: _kPalette),
    ),
    probe: (t) => _tint(t, Icons.subdirectory_arrow_right),
    before: _kIconSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the delivered tick',
    signedIn: true,
    conversation: () => _mine(delivered: true),
    set: () => _Props(
      hideThreadIndicator: true,
      colorPalette: _palette.copyWith(iconSecondary: _kPalette),
    ),
    probe: (t) => _tint(t, Icons.done_all),
    before: _kIconSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconHighlight tints the read tick',
    signedIn: true,
    conversation: () => _mine(read: true),
    set: () => _Props(
      hideThreadIndicator: true,
      colorPalette: _palette.copyWith(iconHighlight: _kPalette),
    ),
    probe: (t) => _tint(t, Icons.done_all),
    before: _kIconHighlight,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the sent tick',
    signedIn: true,
    conversation: _mine,
    set: () => _Props(
      hideThreadIndicator: true,
      colorPalette: _palette.copyWith(iconSecondary: _kPalette),
    ),
    probe: (t) => _tint(t, Icons.check),
    before: _kIconSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'error tints the failed-send icon',
    signedIn: true,
    conversation: () => _mine(metadata: {'error': 'send failed'}),
    set: () => _Props(
      hideThreadIndicator: true,
      colorPalette: _palette.copyWith(error: _kPalette),
    ),
    probe: (t) => _tint(t, Icons.error_outlined),
    before: _kErrorBase,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the media-type icon when the style sets none',
    conversation: _photo,
    set: () =>
        _Props(colorPalette: _palette.copyWith(iconSecondary: _kPalette)),
    probe: (t) => _tint(t, Icons.photo),
    before: _kIconSecondary,
    expected: _kPalette,
  ),

  // ── spacing ───────────────────────────────────────────────────────────────
  _Row(
    'spacing',
    'padding pads the thread-row prefix on both sides',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => _Props(
      hideThreadIndicator: false,
      spacing: _spacing.copyWith(padding: 7.5),
    ),
    probe: (t) => _padAbove(t, _inView(find.text(_prefix))),
    before: const EdgeInsets.only(left: 2, right: 2),
    expected: const EdgeInsets.only(left: 7.5, right: 7.5),
  ),
  _Row(
    'spacing',
    'padding1 spaces the receipt from the preview',
    signedIn: true,
    conversation: _mine,
    set: () => _Props(
      hideThreadIndicator: true,
      spacing: _spacing.copyWith(padding1: 9.5),
    ),
    probe: (t) => _padAbove(t, _inView(find.byType(CometChatReceipt))),
    before: const EdgeInsets.only(right: 4),
    expected: const EdgeInsets.only(right: 9.5),
  ),

  // ── typography, one row per read site ─────────────────────────────────────
  _Row(
    'typography',
    'body.regular sets the preview face',
    conversation: _blank,
    set: () => const _Props(typography: _kTypography),
    probe: (t) => _face(t, _tapToStart(t)),
    expected: _kTypographyReading,
  ),
  _Row(
    'typography',
    'body.regular sets the typing-line face',
    conversation: _incoming,
    unflipped: () => _Props(typingIndicators: [_typer(_bob)]),
    set: () =>
        _Props(typingIndicators: [_typer(_bob)], typography: _kTypography),
    probe: (t) => _face(t, _tr(t).isTyping),
    before: (14.0, null, null),
    expected: _kTypographyReading,
  ),
  _Row(
    'typography',
    'body.regular sets the thread-row prefix face',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () =>
        const _Props(hideThreadIndicator: false, typography: _kTypography),
    probe: (t) => _face(t, _prefix),
    before: (14.0, null, null),
    expected: _kTypographyReading,
  ),

  // ── hideThreadIndicator ───────────────────────────────────────────────────
  _Row(
    'hideThreadIndicator',
    'false shows the thread row: one tick, the arrow and the prefix',
    signedIn: true,
    conversation: _threaded,
    set: () => const _Props(hideThreadIndicator: false),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.subdirectory_arrow_right))),
      _count(_inView(find.byIcon(Icons.check))),
      _count(_inView(find.text(_prefix))),
    ],
    before: [0, 1, 0],
    expected: [1, 1, 1],
  ),
  _Row(
    'hideThreadIndicator',
    'explicit true hides the thread row and keeps the plain tick',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () => const _Props(hideThreadIndicator: true),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.subdirectory_arrow_right))),
      _count(_inView(find.byIcon(Icons.check))),
      _count(_inView(find.text(_prefix))),
    ],
    before: [1, 1, 1],
    expected: [0, 1, 0],
  ),

  // ── receiptsVisibility ────────────────────────────────────────────────────
  _Row(
    'receiptsVisibility',
    'false drops the tick from my own last message',
    signedIn: true,
    conversation: _mine,
    set: () =>
        const _Props(receiptsVisibility: false, hideThreadIndicator: true),
    probe: (t) => _count(_inView(find.byIcon(Icons.check))),
    before: 1,
    expected: 0,
  ),
  _Row(
    'receiptsVisibility',
    'false drops the tick from the thread row too; null keeps it',
    signedIn: true,
    conversation: _threaded,
    unflipped: () => const _Props(hideThreadIndicator: false),
    set: () =>
        const _Props(receiptsVisibility: false, hideThreadIndicator: false),
    probe: (t) => [
      _count(_inView(find.byIcon(Icons.check))),
      _count(_inView(find.byIcon(Icons.subdirectory_arrow_right))),
    ],
    before: [1, 1],
    expected: [0, 1],
  ),
  _Row(
    'receiptsVisibility',
    'explicit true shows the tick that false hid',
    signedIn: true,
    conversation: _mine,
    unflipped: () =>
        const _Props(receiptsVisibility: false, hideThreadIndicator: true),
    set: () =>
        const _Props(receiptsVisibility: true, hideThreadIndicator: true),
    probe: (t) => _count(_inView(find.byIcon(Icons.check))),
    before: 0,
    expected: 1,
  ),

  // ── typingIndicatorText ───────────────────────────────────────────────────
  _Row(
    'typingIndicatorText',
    'replaces the typing line',
    conversation: _incoming,
    unflipped: () => _Props(typingIndicators: [_typer(_bob)]),
    set: () => _Props(
      typingIndicators: [_typer(_bob)],
      typingIndicatorText: 'typing-sentinel-9Z',
    ),
    probe: (t) => [_says(t, 'typing-sentinel-9Z'), _says(t, _tr(t).isTyping)],
    before: [false, true],
    expected: [true, false],
  ),

  // ── Receipt icons ─────────────────────────────────────────────────────────
  _Row(
    'readIcon',
    'replaces the tick on a read message',
    signedIn: true,
    conversation: () => _mine(read: true),
    set: () => const _Props(
      hideThreadIndicator: true,
      readIcon: Icon(Icons.visibility, key: ValueKey('read-sentinel')),
    ),
    probe: (t) => [
      _count(find.byKey(const ValueKey('read-sentinel'))),
      _count(_inView(find.byIcon(Icons.done_all))),
    ],
    before: [0, 1],
    expected: [1, 0],
  ),
  _Row(
    'deliveredIcon',
    'replaces the tick on a delivered message',
    signedIn: true,
    conversation: () => _mine(delivered: true),
    set: () => const _Props(
      hideThreadIndicator: true,
      deliveredIcon: Icon(Icons.inbox, key: ValueKey('delivered-sentinel')),
    ),
    probe: (t) => [
      _count(find.byKey(const ValueKey('delivered-sentinel'))),
      _count(_inView(find.byIcon(Icons.done_all))),
    ],
    before: [0, 1],
    expected: [1, 0],
  ),
  _Row(
    'sentIcon',
    'replaces the tick on a sent message',
    signedIn: true,
    conversation: _mine,
    set: () => const _Props(
      hideThreadIndicator: true,
      sentIcon: Icon(Icons.outbox, key: ValueKey('sent-sentinel')),
    ),
    probe: (t) => [
      _count(find.byKey(const ValueKey('sent-sentinel'))),
      _count(_inView(find.byIcon(Icons.check))),
    ],
    before: [0, 1],
    expected: [1, 0],
  ),

  // ── textFormatters ────────────────────────────────────────────────────────
  _Row(
    'textFormatters',
    'format the last-message preview',
    conversation: _incoming,
    set: () => _Props(textFormatters: [_SentinelFormatter()]),
    probe: (t) => [_shows(t, 'FORMATTED-BY-SENTINEL'), _shows(t, 'Hello!')],
    before: [false, true],
    expected: [true, false],
  ),
  _Row(
    'textFormatters',
    'unset, the default formatters resolve mentions; an empty list does not',
    conversation: _mention,
    set: () => const _Props(textFormatters: []),
    probe: (t) => [_shows(t, '@Cara'), _shows(t, '<@uid:u3>')],
    before: [true, false],
    expected: [false, true],
  ),
  _Row(
    'textFormatters',
    'a mentions formatter in the list is handed the last message',
    conversation: _mention,
    unflipped: () => const _Props(textFormatters: []),
    set: () => _Props(textFormatters: [CometChatMentionsFormatter()]),
    probe: (t) => [_shows(t, '@Cara'), _shows(t, '<@uid:u3>')],
    before: [false, true],
    expected: [true, false],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  group('ConversationsSubtitleView prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        if (row.signedIn) {
          CometChatUIKit.loggedInUser = _me;
          addTearDown(() => CometChatUIKit.loggedInUser = null);
        }
        final sides = <(String, _Props?, Object?)>[
          (
            row.unflipped == null ? 'unset' : 'unflipped',
            row.unflipped?.call(),
            row.before,
          ),
          ('set', row.set(), row.expected),
        ];
        final readings = <Object?>[];

        for (final (label, p, expected) in sides) {
          final conversation = row.conversation();
          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                // A fresh app per side, so no element state carries over.
                key: ValueKey(label),
                p == null
                    // Unset: required tokens at baseline, every optional
                    // prop omitted so its constructor default applies.
                    ? ConversationsSubtitleView(
                        conversation: conversation,
                        style: _style,
                        receiptStyle: _receiptStyle,
                        typingStyle: _typingStyle,
                        colorPalette: _palette,
                        spacing: _spacing,
                        typography: _typography,
                      )
                    : ConversationsSubtitleView(
                        conversation: p.conversation ?? conversation,
                        typingIndicators: p.typingIndicators ?? const [],
                        style: p.style ?? _style,
                        receiptStyle: p.receiptStyle ?? _receiptStyle,
                        typingStyle: p.typingStyle ?? _typingStyle,
                        colorPalette: p.colorPalette ?? _palette,
                        spacing: p.spacing ?? _spacing,
                        typography: p.typography ?? _typography,
                        hideThreadIndicator: p.hideThreadIndicator,
                        receiptsVisibility: p.receiptsVisibility,
                        typingIndicatorText: p.typingIndicatorText,
                        readIcon: p.readIcon,
                        deliveredIcon: p.deliveredIcon,
                        sentIcon: p.sentIcon,
                        textFormatters: p.textFormatters,
                      ),
              ),
            ),
          );
          await tester.pump();

          final reading = row.probe(tester);
          if (expected is! _Differs) {
            expect(reading, expected, reason: '${row.prop}, $label side');
          }
          readings.add(reading);
        }

        expect(
          readings.last,
          isNot(equals(readings.first)),
          reason:
              '${row.prop} must render differently from its '
              '${sides.first.$1} side',
        );
      });
    }
  });

  test('every prop has a row, and every row sets the prop it names', () {
    expect({for (final row in _matrix) row.prop}, _Props.wired);
    for (final row in _matrix) {
      final set = row.set();
      expect(set.setNames, contains(row.prop), reason: row.claim);
      final unflipped = row.unflipped?.call();
      if (unflipped != null && unflipped.setNames.contains(row.prop)) {
        expect(
          unflipped.values[row.prop],
          isNot(equals(set.values[row.prop])),
          reason: row.claim,
        );
      }
    }
  });
}
