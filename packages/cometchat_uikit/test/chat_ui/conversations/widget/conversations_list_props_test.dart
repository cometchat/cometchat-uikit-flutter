/// Render-verified prop matrix for [ConversationsList] — Track 3 PROP1
/// (ENG-38688, coverage part 2).
///
/// [ConversationsList] is the body of CometChatConversations: it takes the
/// bloc and the already-resolved style tokens and renders one
/// [CometChatConversationListItem] per conversation, or a state view. The
/// matrix drives it directly with a mocked bloc seeded into a chosen state
/// and asserts on the child each prop is handed to.
///
/// How the matrix works. [_matrix] is a table. Each row names the prop it
/// verifies, the non-default value it sets (a sentinel no theme uses), the
/// state to seed, an optional interaction, a probe that reads the rendered
/// element the prop controls, and what the probe must return. Every row is
/// pumped twice in the same test body. Flags carry an `unflipped` side with
/// its own expectation; every other row gets a control side that leaves the
/// prop at its baseline. The two readings must differ, so a row whose
/// assertion would still hold if the list ignored the prop fails here. One
/// test body renders every row, so the construction the coverage tool scores
/// is the one that runs, and the guard test at the bottom fails if a wired
/// prop loses its row or a row stops setting the prop it names.
///
/// 53 of the 54 props have a row. The tool reports 54 render-verified because
/// receiptStyle is required, so every construction passes it; it has no row.
/// It has no observable effect and is left out rather than tested around:
///
/// * receiptStyle is forwarded and never read: the list item colours its
///   receipt ticks from the palette.
///
/// Some wired props are only partly honoured. The rows pin the fields that
/// reach a child; the dropped ones are reported, not tested around:
///
/// * style: _buildListItem (444-450) maps five item fields, so
///   listItemSelectedBackgroundColor, the checkBox* fields,
///   checkboxSelectedIconColor, messageTypeIconColor and the private and
///   protected group icon backgrounds never reach the row.
/// * statusStyle: only its border is read (list item 437); backgroundColor
///   and borderRadius are dropped.
/// * typingStyle: the list item overwrites its text colour with
///   palette.textHighlight (518).
/// * datesStyle: backgroundColor and border are overwritten (755, 771).
/// * activateSelection: onLongClick never runs unless onItemLongPress is set,
///   because onItemLongClick is only wired then (396-398).
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

/// Records every event instead of handling it, and hands out real typing
/// notifiers so a row can seed "someone is typing".
class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  _MockConversationsBloc(this._events, this._typing);

  final List<ConversationsEvent> _events;
  final Map<String, List<TypingIndicator>> _typing;
  final _notifiers = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _notifiers.putIfAbsent(id, () => ValueNotifier(_typing[id] ?? const []));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) =>
      _typing[conversationId] ?? const [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) => _events.add(event);
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
    this.parentMessageId = 0,
    this.deliveredAt,
    this.readAt,
  }) : _from = from;

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
  _FakeConversation({
    required this.conversationWith,
    required this.conversationId,
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

_FakeConversation _conv(
  AppEntity withWhom,
  String id, {
  BaseMessage? last,
  int unread = 0,
}) => _FakeConversation(
  conversationWith: withWhom,
  conversationId: id,
  unreadMessageCount: unread,
  lastMessage: last,
);

/// Alice (online, a message from Bob, 3 unread), Bob (offline) and a private
/// group with 1 unread.
List<Conversation> _three() => [
  _conv(
    _FakeUser('u1', 'Alice'),
    'user_u1',
    unread: 3,
    last: _FakeTextMessage(from: _bob),
  ),
  _conv(_bob, 'user_u2'),
  _conv(_FakeGroup('g1', 'Dev Team', 'private'), 'group_g1', unread: 1),
];

/// Alice's conversation, whose last message is one the signed-in user sent.
Conversation _mine({bool read = false, bool delivered = false}) => _conv(
  _FakeUser('u1', 'Alice'),
  'user_u1',
  last: _FakeTextMessage(
    from: _me,
    readAt: read ? DateTime(2026, 5, 12, 10, 32) : null,
    deliveredAt: delivered || read ? DateTime(2026, 5, 12, 10, 31) : null,
  ),
);

ConversationsState _loaded() => ConversationsLoaded(conversations: _three());
ConversationsState _loading() => const ConversationsLoading();
ConversationsState _empty() => const ConversationsEmpty();
ConversationsState _error() =>
    const ConversationsError(message: 'Network error');

ConversationsState Function() _only(Conversation Function() conversation) =>
    () => ConversationsLoaded(conversations: [conversation()]);

// Baseline tokens: what every row renders with unless it overrides one.
const _style = CometChatConversationsStyle();
const _statusStyle = CometChatStatusIndicatorStyle();
const _typingStyle = CometChatTypingIndicatorStyle();
const _datesStyle = CometChatDateStyle();
final _receiptStyle = CometChatMessageReceiptStyle();

final _palette = CometChatColorPalette(
  primary: const Color(0xFF6852D6),
  textPrimary: const Color(0xFF141414),
  textSecondary: const Color(0xFF727272),
  textHighlight: const Color(0xFF6852D6),
  iconSecondary: const Color(0xFFA1A1A1),
  background1: const Color(0xFFFFFFFF),
  background4: const Color(0xFFE8E8E8),
  borderDefault: const Color(0xFFDCDCDC),
  success: const Color(0xFF09C26F),
  warning: const Color(0xFFFFAB00),
  error: const Color(0xFFF44649),
  transparent: const Color(0x00000000),
);

final _spacing = CometChatSpacing(
  padding: 2,
  padding1: 4,
  padding2: 8,
  padding3: 12,
  padding4: 16,
  padding5: 20,
  radius1: 4,
  radius2: 8,
  radius5: 20,
  radiusMax: 1000,
);

const _typography = CometChatTypography(
  heading2: CometChatTextStyleHeading2(
    bold: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  ),
  heading3: CometChatTextStyleHeading3(
    bold: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    regular: TextStyle(fontSize: 18),
  ),
  heading4: CometChatTextStyleHeading4(
    medium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  ),
  body: CometChatTextStyleBody(regular: TextStyle(fontSize: 14)),
  caption1: CometChatTextStyleCaption1(regular: TextStyle(fontSize: 12)),
);

// Sentinels: values no theme produces, so a match can only come from the prop.
const _kTitle = Color(0xFF1A2B3C);
const _kRowBackground = Color(0xFF2B3C4D);
const _kPaletteText = Color(0xFF3C4D5E);
const _kPaletteBackground = Color(0xFF4D5E6F);
const _kStatusBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFF5E6F70), width: 2.5),
);
const _kDateText = Color(0xFF6F7081);
const _kAvatarBackground = Color(0xFF708192);
const _kBadgeBackground = Color(0xFF8192A3);
const _kEmptyTitle = Color(0xFF92A3B4);
const _kErrorTitle = Color(0xFFA3B4C5);
const _kSubtitle = Color(0xFFB4C5D6);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every value a row can set. Each field is a prop wired into the one
/// construction in [main]; the guard test holds each field to a row.
class _Props {
  const _Props({
    this.style,
    this.statusStyle,
    this.typingStyle,
    this.datesStyle,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.scrollController,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.hideError,
    this.listItemView,
    this.subtitleView,
    this.trailingView,
    this.leadingView,
    this.titleView,
    this.avatarHeight,
    this.avatarWidth,
    this.avatarPadding,
    this.avatarMargin,
    this.statusIndicatorHeight,
    this.statusIndicatorWidth,
    this.privateGroupIcon,
    this.protectedGroupIcon,
    this.usersStatusVisibility,
    this.groupTypeVisibility,
    this.selectionMode,
    this.activateSelection,
    this.onItemTap,
    this.onItemLongPress,
    this.hideThreadIndicator,
    this.receiptsVisibility,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
    this.textFormatters,
    this.dateTimeFormatterCallback,
    this.itemWrapperBuilder,
    this.onLoad,
    this.onEmpty,
    this.onError,
    this.typingIndicatorText,
    this.datePattern,
    this.datePadding,
    this.dateHeight,
    this.dateWidth,
    this.dateBackgroundIsTransparent,
    this.badgeWidth,
    this.badgeHeight,
    this.badgePadding,
    this.statusIndicatorBorderRadius,
  });

  final CometChatConversationsStyle? style;
  final CometChatStatusIndicatorStyle? statusStyle;
  final CometChatTypingIndicatorStyle? typingStyle;
  final CometChatDateStyle? datesStyle;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final ScrollController? scrollController;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final bool? hideError;
  final Widget Function(Conversation conversation)? listItemView;
  final Widget? Function(BuildContext context, Conversation conversation)?
  subtitleView;
  final Widget? Function(Conversation conversation)? trailingView;
  final Widget? Function(BuildContext context, Conversation conversation)?
  leadingView;
  final Widget? Function(BuildContext context, Conversation conversation)?
  titleView;
  final double? avatarHeight;
  final double? avatarWidth;
  final EdgeInsetsGeometry? avatarPadding;
  final EdgeInsetsGeometry? avatarMargin;
  final double? statusIndicatorHeight;
  final double? statusIndicatorWidth;
  final Widget? privateGroupIcon;
  final Widget? protectedGroupIcon;
  final bool? usersStatusVisibility;
  final bool? groupTypeVisibility;
  final SelectionMode? selectionMode;
  final ActivateSelection? activateSelection;
  final void Function(Conversation conversation)? onItemTap;
  final void Function(Conversation conversation)? onItemLongPress;
  final bool? hideThreadIndicator;
  final bool? receiptsVisibility;
  final Widget? readIcon;
  final Widget? deliveredIcon;
  final Widget? sentIcon;
  final List<CometChatTextFormatter>? textFormatters;
  final DateTimeFormatterCallback? dateTimeFormatterCallback;
  final Widget Function(
    BuildContext context,
    Conversation conversation,
    Widget child,
  )?
  itemWrapperBuilder;
  final OnLoad<Conversation>? onLoad;
  final OnEmpty? onEmpty;
  final OnError? onError;
  final String? typingIndicatorText;
  final String Function(Conversation)? datePattern;
  final EdgeInsets? datePadding;
  final double? dateHeight;
  final double? dateWidth;
  final bool? dateBackgroundIsTransparent;
  final double? badgeWidth;
  final double? badgeHeight;
  final EdgeInsetsGeometry? badgePadding;
  final BorderRadiusGeometry? statusIndicatorBorderRadius;

  Map<String, Object?> get values => {
    'style': style,
    'statusStyle': statusStyle,
    'typingStyle': typingStyle,
    'datesStyle': datesStyle,
    'colorPalette': colorPalette,
    'spacing': spacing,
    'typography': typography,
    'scrollController': scrollController,
    'loadingStateView': loadingStateView,
    'emptyStateView': emptyStateView,
    'errorStateView': errorStateView,
    'hideError': hideError,
    'listItemView': listItemView,
    'subtitleView': subtitleView,
    'trailingView': trailingView,
    'leadingView': leadingView,
    'titleView': titleView,
    'avatarHeight': avatarHeight,
    'avatarWidth': avatarWidth,
    'avatarPadding': avatarPadding,
    'avatarMargin': avatarMargin,
    'statusIndicatorHeight': statusIndicatorHeight,
    'statusIndicatorWidth': statusIndicatorWidth,
    'privateGroupIcon': privateGroupIcon,
    'protectedGroupIcon': protectedGroupIcon,
    'usersStatusVisibility': usersStatusVisibility,
    'groupTypeVisibility': groupTypeVisibility,
    'selectionMode': selectionMode,
    'activateSelection': activateSelection,
    'onItemTap': onItemTap,
    'onItemLongPress': onItemLongPress,
    'hideThreadIndicator': hideThreadIndicator,
    'receiptsVisibility': receiptsVisibility,
    'readIcon': readIcon,
    'deliveredIcon': deliveredIcon,
    'sentIcon': sentIcon,
    'textFormatters': textFormatters,
    'dateTimeFormatterCallback': dateTimeFormatterCallback,
    'itemWrapperBuilder': itemWrapperBuilder,
    'onLoad': onLoad,
    'onEmpty': onEmpty,
    'onError': onError,
    'typingIndicatorText': typingIndicatorText,
    'datePattern': datePattern,
    'datePadding': datePadding,
    'dateHeight': dateHeight,
    'dateWidth': dateWidth,
    'dateBackgroundIsTransparent': dateBackgroundIsTransparent,
    'badgeWidth': badgeWidth,
    'badgeHeight': badgeHeight,
    'badgePadding': badgePadding,
    'statusIndicatorBorderRadius': statusIndicatorBorderRadius,
  };

  /// The props this instance actually sets.
  Set<String> get setNames => {
    for (final e in values.entries)
      if (e.value != null) e.key,
  };

  /// Every prop the construction reads from a row.
  static Set<String> get wired => const _Props().values.keys.toSet();
}

/// What a row records while it runs: callback arguments, bloc events, and a
/// scroll controller made on demand.
class _Rec {
  final events = <ConversationsEvent>[];
  Conversation? tapped;
  Conversation? pressed;
  List<Conversation>? loaded;
  int empties = 0;
  Exception? error;

  ScrollController? _controller;
  ScrollController get controller => _controller ??= ScrollController();

  void dispose() => _controller?.dispose();
}

typedef _Side = ({_Props Function(_Rec rec) set, Object? expected});

/// Marks a control side: its reading is not checked on its own, only against
/// the set side's, which it must not match.
class _Differs {
  const _Differs();
}

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.set,
    required this.probe,
    required this.expected,
    this.unflipped,
    this.state = _loaded,
    this.act,
    this.typing = const {},
    this.signedIn = false,
    this.control = true,
  });

  /// The [ConversationsList] parameter this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// The values this row sets; gets the recorder so callbacks can record.
  final _Props Function(_Rec rec) set;

  /// Reads the rendered element (or recorded call) the prop controls.
  final Object? Function(WidgetTester tester, _Rec rec) probe;

  /// What [probe] must return with [set] applied.
  final Object? expected;

  /// For flags: the other side, which must read differently.
  final _Side? unflipped;

  /// The bloc state to seed.
  final ConversationsState Function() state;

  /// A real interaction to run before probing.
  final Future<void> Function(WidgetTester tester)? act;

  /// Typing indicators to seed, by conversation id.
  final Map<String, List<TypingIndicator>> typing;

  /// Signs [_me] in, so receipts show on messages [_me] sent.
  final bool signedIn;

  /// Pumps a control side, with the prop left at its baseline, when the row
  /// has no unflipped side. Off only where the prop cannot be left out.
  final bool control;
}

int _count(Finder finder) => finder.evaluate().length;

Translations _tr(WidgetTester tester) =>
    Translations.of(tester.element(find.byType(ConversationsList)));

TextStyle? _textStyle(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data)).style;

List<String> _textsStartingWith(WidgetTester tester, String prefix) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    // `?text.data` drops the `when` clause, so the list stops being
    // filtered by `prefix` and every Text on screen comes back.
    // `dart fix` applies exactly that rewrite; it silently broke six
    // tests in this file and its sibling.
    // ignore: use_null_aware_elements
    if (text.data case final data? when data.startsWith(prefix)) data,
];

/// The outermost Container a widget of [type] builds: the row box of a list
/// item, the avatar box, the presence dot, the badge.
Container _box(WidgetTester tester, Type type) => tester.widget<Container>(
  find
      .descendant(of: find.byType(type).first, matching: find.byType(Container))
      .first,
);

BoxDecoration _decoration(WidgetTester tester, Type type) =>
    _box(tester, type).decoration! as BoxDecoration;

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
}

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

final _matrix = <_Row>[
  // ── The bloc and the resolved tokens ──────────────────────────────────────
  _Row(
    'conversationsBloc',
    'rows come from its state, and paging is asked of it',
    control: false,
    state: () => ConversationsLoaded(
      conversations: [_conv(_FakeUser('zq', 'Zephyr Quill'), 'user_zq')],
      hasMore: true,
    ),
    set: (r) => const _Props(),
    probe: (t, r) => [
      _count(find.text('Zephyr Quill')),
      r.events.whereType<LoadMoreConversations>().isNotEmpty,
    ],
    expected: [1, true],
  ),
  _Row(
    'style',
    'itemTitleTextColor and backgroundColor reach every row',
    set: (r) => const _Props(
      style: CometChatConversationsStyle(
        itemTitleTextColor: _kTitle,
        backgroundColor: _kRowBackground,
      ),
    ),
    probe: (t, r) => [
      _textStyle(t, 'Alice')?.color,
      _box(t, CometChatConversationListItem).color,
    ],
    expected: [_kTitle, _kRowBackground],
  ),
  _Row(
    'style',
    'itemTitleTextStyle and the item subtitle style reach every row',
    set: (r) => const _Props(
      style: CometChatConversationsStyle(
        itemTitleTextStyle: TextStyle(fontSize: 19.25),
        itemSubtitleTextStyle: TextStyle(fontSize: 13.25),
        itemSubtitleTextColor: _kSubtitle,
      ),
    ),
    // Bob and Dev Team have no last message, so their subtitle is the
    // tap-to-start line, drawn in the item subtitle style.
    probe: (t, r) => [
      _textStyle(t, 'Alice')?.fontSize,
      for (final text in t.widgetList<Text>(
        find.text(_tr(t).tapToStartConversation),
      ))
        (text.style?.color, text.style?.fontSize),
    ],
    expected: [19.25, (_kSubtitle, 13.25), (_kSubtitle, 13.25)],
  ),
  _Row(
    'style',
    'avatarStyle and badgeStyle reach the avatar and the unread badge',
    set: (r) => const _Props(
      style: CometChatConversationsStyle(
        avatarStyle: CometChatAvatarStyle(backgroundColor: _kAvatarBackground),
        badgeStyle: CometChatBadgeStyle(backgroundColor: _kBadgeBackground),
      ),
    ),
    probe: (t, r) => [
      _decoration(t, CometChatAvatar).color,
      _decoration(t, CometChatBadge).color,
    ],
    expected: [_kAvatarBackground, _kBadgeBackground],
  ),
  _Row(
    'style',
    'emptyStateTextColor reaches the empty view',
    state: _empty,
    set: (r) => const _Props(
      style: CometChatConversationsStyle(emptyStateTextColor: _kEmptyTitle),
    ),
    probe: (t, r) => _textStyle(t, _tr(t).noConversationsYet)?.color,
    expected: _kEmptyTitle,
  ),
  _Row(
    'style',
    'errorStateTextColor reaches the error view',
    state: _error,
    set: (r) => const _Props(
      style: CometChatConversationsStyle(errorStateTextColor: _kErrorTitle),
    ),
    probe: (t, r) => _textStyle(t, _tr(t).oops)?.color,
    expected: _kErrorTitle,
  ),
  _Row(
    'colorPalette',
    'textPrimary colours the title and background1 paints the row',
    set: (r) => _Props(
      colorPalette: _palette.copyWith(
        textPrimary: _kPaletteText,
        background1: _kPaletteBackground,
      ),
    ),
    probe: (t, r) => [
      _textStyle(t, 'Alice')?.color,
      _box(t, CometChatConversationListItem).color,
    ],
    expected: [_kPaletteText, _kPaletteBackground],
  ),
  _Row(
    'spacing',
    'padding4 and padding3 inset every row',
    set: (r) => _Props(spacing: _spacing.copyWith(padding3: 9, padding4: 17)),
    probe: (t, r) => _box(t, CometChatConversationListItem).padding,
    expected: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
  ),
  _Row(
    'typography',
    'heading4.medium sizes the conversation name',
    set: (r) => _Props(
      typography: _typography.copyWith(
        heading4: const CometChatTextStyleHeading4(
          medium: TextStyle(fontSize: 23.5),
        ),
      ),
    ),
    probe: (t, r) => _textStyle(t, 'Alice')?.fontSize,
    expected: 23.5,
  ),
  _Row(
    'statusStyle',
    'border outlines the presence dot',
    set: (r) => const _Props(
      statusStyle: CometChatStatusIndicatorStyle(border: _kStatusBorder),
    ),
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).border,
    expected: _kStatusBorder,
  ),
  _Row(
    'typingStyle',
    'textStyle sizes the typing line',
    typing: {
      'user_u1': [
        TypingIndicator(sender: _bob, receiverId: 'u1', receiverType: 'user'),
      ],
    },
    set: (r) => const _Props(
      typingStyle: CometChatTypingIndicatorStyle(
        textStyle: TextStyle(fontSize: 21.5),
      ),
    ),
    probe: (t, r) => _textStyle(t, _tr(t).isTyping)?.fontSize,
    expected: 21.5,
  ),
  _Row(
    'datesStyle',
    'textColor colours the timestamp',
    set: (r) =>
        const _Props(datesStyle: CometChatDateStyle(textColor: _kDateText)),
    probe: (t, r) => t
        .widget<Text>(
          find.descendant(
            of: find.byType(CometChatDate).first,
            matching: find.byType(Text),
          ),
        )
        .style
        ?.color,
    expected: _kDateText,
  ),

  // ── State views ───────────────────────────────────────────────────────────
  _Row(
    'loadingStateView',
    'replaces the shimmer while loading',
    state: _loading,
    set: (r) =>
        _Props(loadingStateView: (context) => const Text('LOADING-SENTINEL')),
    probe: (t, r) => _count(find.text('LOADING-SENTINEL')),
    expected: 1,
  ),
  _Row(
    'emptyStateView',
    'replaces the empty state',
    state: _empty,
    set: (r) =>
        _Props(emptyStateView: (context) => const Text('EMPTY-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('EMPTY-SENTINEL')),
      _count(find.text(_tr(t).noConversationsYet)),
    ],
    expected: [1, 0],
  ),
  _Row(
    'errorStateView',
    'replaces the error state',
    state: _error,
    set: (r) =>
        _Props(errorStateView: (context) => const Text('ERROR-SENTINEL')),
    probe: (t, r) => [
      _count(find.text('ERROR-SENTINEL')),
      _count(find.text(_tr(t).oops)),
    ],
    expected: [1, 0],
  ),
  _Row(
    'hideError',
    'true renders nothing in place of the error view',
    state: _error,
    unflipped: (set: (r) => const _Props(), expected: 1),
    set: (r) => const _Props(hideError: true),
    probe: (t, r) => _count(find.byType(ConversationsErrorView)),
    expected: 0,
  ),

  // ── Row slots ─────────────────────────────────────────────────────────────
  _Row(
    'listItemView',
    'replaces each row outright',
    set: (r) => _Props(listItemView: (c) => Text('row-${c.conversationId}')),
    probe: (t, r) => [
      ..._textsStartingWith(t, 'row-'),
      _count(find.byType(CometChatConversationListItem)),
    ],
    expected: ['row-user_u1', 'row-user_u2', 'row-group_g1', 0],
  ),
  _Row(
    'subtitleView',
    'renders under each name',
    set: (r) =>
        _Props(subtitleView: (context, c) => Text('sub-${c.conversationId}')),
    probe: (t, r) => _textsStartingWith(t, 'sub-'),
    expected: ['sub-user_u1', 'sub-user_u2', 'sub-group_g1'],
  ),
  _Row(
    'trailingView',
    'replaces the timestamp and badge column',
    set: (r) => _Props(trailingView: (c) => Text('trail-${c.conversationId}')),
    probe: (t, r) => [
      ..._textsStartingWith(t, 'trail-'),
      _count(find.byType(CometChatBadge)),
    ],
    expected: ['trail-user_u1', 'trail-user_u2', 'trail-group_g1', 0],
  ),
  _Row(
    'leadingView',
    'replaces the avatar',
    set: (r) =>
        _Props(leadingView: (context, c) => Text('lead-${c.conversationId}')),
    probe: (t, r) => [
      ..._textsStartingWith(t, 'lead-'),
      _count(find.byType(CometChatAvatar)),
    ],
    expected: ['lead-user_u1', 'lead-user_u2', 'lead-group_g1', 0],
  ),
  _Row(
    'titleView',
    'replaces the conversation name',
    set: (r) =>
        _Props(titleView: (context, c) => Text('title-${c.conversationId}')),
    probe: (t, r) => [
      ..._textsStartingWith(t, 'title-'),
      _count(find.text('Alice')),
    ],
    expected: ['title-user_u1', 'title-user_u2', 'title-group_g1', 0],
  ),

  // ── Avatar and presence geometry ──────────────────────────────────────────
  _Row(
    'avatarHeight',
    'sets the rendered avatar height',
    set: (r) => const _Props(avatarHeight: 61),
    probe: (t, r) => t.getSize(find.byType(CometChatAvatar).first).height,
    expected: 61,
  ),
  _Row(
    'avatarWidth',
    'sets the rendered avatar width',
    set: (r) => const _Props(avatarWidth: 57),
    probe: (t, r) => t.getSize(find.byType(CometChatAvatar).first).width,
    expected: 57,
  ),
  _Row(
    'avatarPadding',
    'insets the avatar content inside its box',
    set: (r) => const _Props(avatarPadding: EdgeInsets.all(3.5)),
    probe: (t, r) => [
      _box(t, CometChatAvatar).padding,
      t.getSize(
        find
            .descendant(
              of: find.byType(CometChatAvatar).first,
              matching: find.byType(ClipRRect),
            )
            .first,
      ),
    ],
    expected: [const EdgeInsets.all(3.5), const Size(41, 41)],
  ),
  _Row(
    'avatarMargin',
    'spaces the avatar box from its neighbours',
    set: (r) => const _Props(avatarMargin: EdgeInsets.fromLTRB(1, 2, 3, 4)),
    probe: (t, r) => [
      _box(t, CometChatAvatar).margin,
      t.getSize(find.byType(CometChatAvatar).first),
    ],
    expected: [const EdgeInsets.fromLTRB(1, 2, 3, 4), const Size(52, 54)],
  ),
  _Row(
    'statusIndicatorHeight',
    'sets the rendered presence dot height',
    set: (r) => const _Props(statusIndicatorHeight: 11),
    probe: (t, r) =>
        t.getSize(find.byType(CometChatStatusIndicator).first).height,
    expected: 11,
  ),
  _Row(
    'statusIndicatorWidth',
    'sets the rendered presence dot width',
    set: (r) => const _Props(statusIndicatorWidth: 9),
    probe: (t, r) =>
        t.getSize(find.byType(CometChatStatusIndicator).first).width,
    expected: 9,
  ),
  _Row(
    'privateGroupIcon',
    'replaces the shield on a private group',
    state: _only(() => _conv(_FakeGroup('g1', 'Dev Team', 'private'), 'g1')),
    set: (r) => const _Props(
      privateGroupIcon: Icon(Icons.vpn_key, key: ValueKey('private-sentinel')),
    ),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('private-sentinel'))),
      _count(find.byIcon(Icons.shield)),
    ],
    expected: [1, 0],
  ),
  _Row(
    'protectedGroupIcon',
    'replaces the lock on a password group',
    state: _only(() => _conv(_FakeGroup('g2', 'Vault', 'password'), 'g2')),
    set: (r) => const _Props(
      protectedGroupIcon: Icon(Icons.key, key: ValueKey('protected-sentinel')),
    ),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('protected-sentinel'))),
      _count(find.byIcon(Icons.lock)),
    ],
    expected: [1, 0],
  ),

  // ── Flags ─────────────────────────────────────────────────────────────────
  _Row(
    'usersStatusVisibility',
    'false hides the presence dot on a user row',
    state: _only(() => _conv(_FakeUser('u1', 'Alice'), 'user_u1')),
    unflipped: (set: (r) => const _Props(), expected: 1),
    set: (r) => const _Props(usersStatusVisibility: false),
    probe: (t, r) => _count(find.byType(CometChatStatusIndicator)),
    expected: 0,
  ),
  _Row(
    'groupTypeVisibility',
    'false hides the group-type badge',
    state: _only(() => _conv(_FakeGroup('g1', 'Dev Team', 'private'), 'g1')),
    unflipped: (set: (r) => const _Props(), expected: 1),
    set: (r) => const _Props(groupTypeVisibility: false),
    probe: (t, r) => _count(find.byType(CometChatStatusIndicator)),
    expected: 0,
  ),
  _Row(
    'selectionMode',
    'multiple adds a checkbox to every row',
    unflipped: (set: (r) => const _Props(), expected: 0),
    set: (r) => const _Props(selectionMode: SelectionMode.multiple),
    probe: (t, r) => _count(find.byType(Checkbox)),
    expected: 3,
  ),
  _Row(
    'activateSelection',
    'onClick turns a tap into a selection toggle',
    unflipped: (
      set: (r) => const _Props(selectionMode: SelectionMode.multiple),
      expected: <String>[],
    ),
    set: (r) => const _Props(
      selectionMode: SelectionMode.multiple,
      activateSelection: ActivateSelection.onClick,
    ),
    act: (t) => _tap(t, 'Bob'),
    probe: (t, r) => [
      for (final e in r.events)
        if (e is ToggleConversationSelection) e.conversationId,
    ],
    expected: ['user_u2'],
  ),
  _Row(
    'hideThreadIndicator',
    'true drops the reply arrow from a thread reply',
    state: _only(
      () => _conv(
        _FakeUser('u1', 'Alice'),
        'user_u1',
        last: _FakeTextMessage(from: _bob, parentMessageId: 42),
      ),
    ),
    unflipped: (set: (r) => const _Props(), expected: 1),
    set: (r) => const _Props(hideThreadIndicator: true),
    probe: (t, r) => _count(find.byIcon(Icons.subdirectory_arrow_right)),
    expected: 0,
  ),
  _Row(
    'receiptsVisibility',
    'false drops the tick from my own last message',
    signedIn: true,
    state: _only(() => _mine(delivered: true)),
    unflipped: (set: (r) => const _Props(), expected: 1),
    set: (r) => const _Props(receiptsVisibility: false),
    probe: (t, r) => _count(find.byIcon(Icons.done_all)),
    expected: 0,
  ),

  // ── Receipt icons ─────────────────────────────────────────────────────────
  _Row(
    'readIcon',
    'replaces the tick on a read message',
    signedIn: true,
    state: _only(() => _mine(read: true)),
    set: (r) => const _Props(
      readIcon: Icon(Icons.visibility, key: ValueKey('read-sentinel')),
    ),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('read-sentinel'))),
      _count(find.byIcon(Icons.done_all)),
    ],
    expected: [1, 0],
  ),
  _Row(
    'deliveredIcon',
    'replaces the tick on a delivered message',
    signedIn: true,
    state: _only(() => _mine(delivered: true)),
    set: (r) => const _Props(
      deliveredIcon: Icon(Icons.inbox, key: ValueKey('delivered-sentinel')),
    ),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('delivered-sentinel'))),
      _count(find.byIcon(Icons.done_all)),
    ],
    expected: [1, 0],
  ),
  _Row(
    'sentIcon',
    'replaces the tick on a sent message',
    signedIn: true,
    state: _only(_mine),
    set: (r) => const _Props(
      sentIcon: Icon(Icons.outbox, key: ValueKey('sent-sentinel')),
    ),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('sent-sentinel'))),
      _count(find.byIcon(Icons.done)),
    ],
    expected: [1, 0],
  ),

  // ── Formatting and wrapping ───────────────────────────────────────────────
  _Row(
    'textFormatters',
    'format the last-message preview',
    set: (r) => _Props(textFormatters: [_SentinelFormatter()]),
    probe: (t, r) => _count(
      find.textContaining('FORMATTED-BY-SENTINEL', findRichText: true),
    ),
    expected: 1,
  ),
  _Row(
    'dateTimeFormatterCallback',
    'formats the timestamp',
    set: (r) => _Props(dateTimeFormatterCallback: _SentinelDates()),
    probe: (t, r) => _count(find.text('WHEN-SENTINEL')),
    expected: 1,
  ),
  _Row(
    'itemWrapperBuilder',
    'wraps every default row',
    set: (r) => _Props(
      itemWrapperBuilder: (context, c, child) =>
          KeyedSubtree(key: ValueKey('wrap-${c.conversationId}'), child: child),
    ),
    probe: (t, r) => [
      for (final id in ['user_u1', 'user_u2', 'group_g1'])
        _count(
          find.descendant(
            of: find.byKey(ValueKey('wrap-$id')),
            matching: find.byType(CometChatConversationListItem),
          ),
        ),
      _count(
        find.descendant(
          of: find.byKey(const ValueKey('wrap-user_u2')),
          matching: find.text('Bob'),
        ),
      ),
    ],
    expected: [1, 1, 1, 1],
  ),

  // ── Interaction and state callbacks ───────────────────────────────────────
  _Row(
    'onItemTap',
    'fires with the tapped conversation',
    set: (r) => _Props(onItemTap: (c) => r.tapped = c),
    act: (t) => _tap(t, 'Bob'),
    probe: (t, r) => r.tapped?.conversationId,
    expected: 'user_u2',
  ),
  _Row(
    'onItemLongPress',
    'fires with the pressed conversation',
    set: (r) => _Props(onItemLongPress: (c) => r.pressed = c),
    act: (t) async {
      await t.longPress(find.text('Dev Team'));
      await t.pump();
    },
    probe: (t, r) => r.pressed?.conversationId,
    expected: 'group_g1',
  ),
  _Row(
    'scrollController',
    'is attached to the list',
    unflipped: (set: (r) => const _Props(), expected: false),
    set: (r) => _Props(scrollController: r.controller),
    probe: (t, r) => r.controller.hasClients,
    expected: true,
  ),
  _Row(
    'onLoad',
    'reports the loaded conversations',
    set: (r) => _Props(onLoad: (list) => r.loaded = list),
    probe: (t, r) => r.loaded?.map((c) => c.conversationId).toList(),
    expected: ['user_u1', 'user_u2', 'group_g1'],
  ),
  _Row(
    'onEmpty',
    'reports the empty state',
    state: _empty,
    set: (r) => _Props(onEmpty: () => r.empties++),
    probe: (t, r) => r.empties,
    expected: 1,
  ),
  _Row(
    'typingIndicatorText',
    'replaces the typing line',
    typing: {
      'user_u1': [
        TypingIndicator(sender: _bob, receiverId: 'u1', receiverType: 'user'),
      ],
    },
    set: (r) => const _Props(typingIndicatorText: 'typing-sentinel-7T'),
    probe: (t, r) => find.text('typing-sentinel-7T').evaluate().length,
    expected: 1,
  ),
  _Row(
    'datePattern',
    'writes the timestamp text',
    set: (r) => _Props(datePattern: (c) => 'when-${c.conversationId}'),
    probe: (t, r) => find.text('when-user_u1').evaluate().length,
    expected: 1,
  ),
  _Row(
    'datePadding',
    'pads the timestamp',
    set: (r) => const _Props(datePadding: EdgeInsets.all(7)),
    probe: (t, r) =>
        t.widget<CometChatDate>(find.byType(CometChatDate).first).padding,
    expected: const EdgeInsets.all(7),
  ),
  _Row(
    'dateHeight',
    'sizes the timestamp',
    set: (r) => const _Props(dateHeight: 31),
    probe: (t, r) =>
        t.widget<CometChatDate>(find.byType(CometChatDate).first).height,
    expected: 31.0,
  ),
  _Row(
    'dateWidth',
    'sizes the timestamp',
    set: (r) => const _Props(dateWidth: 57),
    probe: (t, r) =>
        t.widget<CometChatDate>(find.byType(CometChatDate).first).width,
    expected: 57.0,
  ),
  _Row(
    'dateBackgroundIsTransparent',
    'false gives the timestamp its background',
    set: (r) => const _Props(dateBackgroundIsTransparent: false),
    // The painted fill, not the flag read back: the row used to force it
    // transparent whatever the flag said.
    probe: (t, r) {
      final date = find.byType(CometChatDate).first;
      final fill =
          (t
                      .widget<Container>(
                        find
                            .descendant(
                              of: date,
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      return fill ==
              CometChatThemeHelper.getColorPalette(t.element(date)).background2
          ? 'background2'
          : fill;
    },
    expected: 'background2',
  ),
  _Row(
    'badgeWidth',
    'sizes the unread badge',
    set: (r) => const _Props(badgeWidth: 41),
    probe: (t, r) =>
        t.widget<CometChatBadge>(find.byType(CometChatBadge).first).width,
    expected: 41.0,
  ),
  _Row(
    'badgeHeight',
    'sizes the unread badge',
    set: (r) => const _Props(badgeHeight: 27),
    probe: (t, r) =>
        t.widget<CometChatBadge>(find.byType(CometChatBadge).first).height,
    expected: 27.0,
  ),
  _Row(
    'badgePadding',
    'pads the unread badge',
    set: (r) => const _Props(badgePadding: EdgeInsets.all(5)),
    probe: (t, r) =>
        t.widget<CometChatBadge>(find.byType(CometChatBadge).first).padding,
    expected: const EdgeInsets.all(5),
  ),
  _Row(
    'statusIndicatorBorderRadius',
    'rounds the status dot',
    set: (r) => const _Props(
      statusIndicatorBorderRadius: BorderRadius.all(Radius.circular(3)),
    ),
    probe: (t, r) => t
        .widget<CometChatStatusIndicator>(
          find.byType(CometChatStatusIndicator).first,
        )
        .style
        ?.borderRadius,
    expected: const BorderRadius.all(Radius.circular(3)),
  ),
  _Row(
    'onError',
    'reports the error with its message',
    state: _error,
    set: (r) => _Props(onError: (e) => r.error = e),
    probe: (t, r) {
      final e = r.error;
      return e is CometChatException ? [e.code, e.message] : [e];
    },
    expected: ['CONVERSATIONS_ERROR', 'Network error'],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('ConversationsList prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        if (row.signedIn) {
          CometChatUIKit.loggedInUser = _me;
          addTearDown(() => CometChatUIKit.loggedInUser = null);
        }
        final sides = <(String, _Side)>[
          if (row.unflipped case final unflipped?)
            ('unflipped', unflipped)
          else if (row.control)
            (
              'control',
              (set: (r) => const _Props(), expected: const _Differs()),
            ),
          ('set', (set: row.set, expected: row.expected)),
        ];
        final readings = <Object?>[];

        for (final (label, side) in sides) {
          final rec = _Rec();
          addTearDown(rec.dispose);
          final p = side.set(rec);
          final state = row.state();
          final bloc = _MockConversationsBloc(rec.events, row.typing);
          whenListen(
            bloc,
            Stream<ConversationsState>.value(state),
            initialState: state,
          );

          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                ConversationsList(
                  conversationsBloc: bloc,
                  style: p.style ?? _style,
                  statusStyle: p.statusStyle ?? _statusStyle,
                  typingStyle: p.typingStyle ?? _typingStyle,
                  receiptStyle: _receiptStyle,
                  datesStyle: p.datesStyle ?? _datesStyle,
                  colorPalette: p.colorPalette ?? _palette,
                  spacing: p.spacing ?? _spacing,
                  typography: p.typography ?? _typography,
                  scrollController: p.scrollController,
                  loadingStateView: p.loadingStateView,
                  emptyStateView: p.emptyStateView,
                  errorStateView: p.errorStateView,
                  hideError: p.hideError,
                  listItemView: p.listItemView,
                  subtitleView: p.subtitleView,
                  trailingView: p.trailingView,
                  leadingView: p.leadingView,
                  titleView: p.titleView,
                  avatarHeight: p.avatarHeight,
                  avatarWidth: p.avatarWidth,
                  avatarPadding: p.avatarPadding,
                  avatarMargin: p.avatarMargin,
                  statusIndicatorHeight: p.statusIndicatorHeight,
                  statusIndicatorWidth: p.statusIndicatorWidth,
                  privateGroupIcon: p.privateGroupIcon,
                  protectedGroupIcon: p.protectedGroupIcon,
                  usersStatusVisibility: p.usersStatusVisibility,
                  groupTypeVisibility: p.groupTypeVisibility,
                  selectionMode: p.selectionMode,
                  activateSelection: p.activateSelection,
                  onItemTap: p.onItemTap,
                  onItemLongPress: p.onItemLongPress,
                  hideThreadIndicator: p.hideThreadIndicator,
                  receiptsVisibility: p.receiptsVisibility,
                  readIcon: p.readIcon,
                  deliveredIcon: p.deliveredIcon,
                  sentIcon: p.sentIcon,
                  textFormatters: p.textFormatters,
                  dateTimeFormatterCallback: p.dateTimeFormatterCallback,
                  itemWrapperBuilder: p.itemWrapperBuilder,
                  onLoad: p.onLoad,
                  onEmpty: p.onEmpty,
                  onError: p.onError,
                  typingIndicatorText: p.typingIndicatorText,
                  datePattern: p.datePattern,
                  datePadding: p.datePadding,
                  dateHeight: p.dateHeight,
                  dateWidth: p.dateWidth,
                  dateBackgroundIsTransparent: p.dateBackgroundIsTransparent,
                  badgeWidth: p.badgeWidth,
                  badgeHeight: p.badgeHeight,
                  badgePadding: p.badgePadding,
                  statusIndicatorBorderRadius: p.statusIndicatorBorderRadius,
                ),
                // A fresh app per side, so no element state carries over.
                key: ValueKey(label),
              ),
            ),
          );
          await tester.pump();
          await row.act?.call(tester);

          final reading = row.probe(tester, rec);
          if (side.expected is! _Differs) {
            expect(reading, side.expected, reason: '${row.prop}, $label side');
          }
          readings.add(reading);
        }

        if (readings.length == 2) {
          expect(
            readings.last,
            isNot(equals(readings.first)),
            reason:
                '${row.prop} must render differently from its '
                '${sides.first.$1} side',
          );
        }
      });
    }
  });

  group('ConversationsList selection gestures', () {
    testWidgets('activateSelection: onClick with no selectionMode leaves a tap '
        'to onItemTap', (tester) async {
      // The tap guard used to read `onClick || (onLongClick && any) && mode`,
      // so the selectionMode check bound to the long-click branch only and
      // onClick selected rows in a list showing no checkboxes.
      final rec = _Rec();
      addTearDown(rec.dispose);
      final state = _loaded();
      final bloc = _MockConversationsBloc(rec.events, const {});
      whenListen(
        bloc,
        Stream<ConversationsState>.value(state),
        initialState: state,
      );
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            ConversationsList(
              conversationsBloc: bloc,
              style: _style,
              statusStyle: _statusStyle,
              typingStyle: _typingStyle,
              receiptStyle: _receiptStyle,
              datesStyle: _datesStyle,
              colorPalette: _palette,
              spacing: _spacing,
              typography: _typography,
              activateSelection: ActivateSelection.onClick,
              onItemTap: (conversation) => rec.tapped = conversation,
            ),
          ),
        ),
      );
      await tester.pump();
      await _tap(tester, 'Bob');

      expect(rec.tapped?.conversationId, 'user_u2');
      expect(rec.events.whereType<ToggleConversationSelection>(), isEmpty);
    });

    testWidgets('activateSelection: onLongClick starts a selection even with '
        'no onItemLongPress', (tester) async {
      // The long-press gesture used to be wired only when onItemLongPress was
      // given, so this combination could never start a selection.
      final rec = _Rec();
      addTearDown(rec.dispose);
      final state = _loaded();
      final bloc = _MockConversationsBloc(rec.events, const {});
      whenListen(
        bloc,
        Stream<ConversationsState>.value(state),
        initialState: state,
      );
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            ConversationsList(
              conversationsBloc: bloc,
              style: _style,
              statusStyle: _statusStyle,
              typingStyle: _typingStyle,
              receiptStyle: _receiptStyle,
              datesStyle: _datesStyle,
              colorPalette: _palette,
              spacing: _spacing,
              typography: _typography,
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Bob'));
      await tester.pump();

      expect(
        [
          for (final e in rec.events)
            if (e is ToggleConversationSelection) e.conversationId,
        ],
        ['user_u2'],
      );
    });
  });

  group('CometChatConversationListItem takes the props ConversationsList '
      'forwards', () {
    testWidgets('typingIndicatorText replaces the typing line', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              typingIndicators: [
                TypingIndicator(
                  sender: _bob,
                  receiverId: 'u1',
                  receiverType: 'user',
                ),
              ],
              typingIndicatorText: 'item-typing-3Q',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('item-typing-3Q'), findsOneWidget);
    });
    testWidgets('datePattern writes the timestamp', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              datePattern: (c) => 'item-when-${c.conversationId}',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('item-when-user_u1'), findsOneWidget);
    });
    testWidgets('datePadding pads the timestamp', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              datePadding: const EdgeInsets.all(9),
            ),
          ),
        ),
      );
      await tester.pump();
      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.padding, const EdgeInsets.all(9));
    });
    testWidgets('dateHeight sizes the timestamp', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              dateHeight: 33,
            ),
          ),
        ),
      );
      await tester.pump();
      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.height, 33.0);
    });
    testWidgets('dateWidth sizes the timestamp', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              dateWidth: 59,
            ),
          ),
        ),
      );
      await tester.pump();
      final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
      expect(date.width, 59.0);
    });
    testWidgets(
      'dateBackgroundIsTransparent false gives the timestamp a background',
      (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: _three().first,
                onItemClick: (_) {},
                dateBackgroundIsTransparent: false,
              ),
            ),
          ),
        );
        await tester.pump();
        final date = tester.widget<CometChatDate>(find.byType(CometChatDate));
        expect(date.isTransparentBackground, isFalse);
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(CometChatDate),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          CometChatThemeHelper.getColorPalette(
            tester.element(find.byType(CometChatDate)),
          ).background2,
        );
      },
    );
    testWidgets('badgeWidth sizes the unread badge', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              badgeWidth: 43,
            ),
          ),
        ),
      );
      await tester.pump();
      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.width, 43.0);
    });
    testWidgets('badgeHeight sizes the unread badge', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              badgeHeight: 29,
            ),
          ),
        ),
      );
      await tester.pump();
      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.height, 29.0);
    });
    testWidgets('badgePadding pads the unread badge', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              badgePadding: const EdgeInsets.all(6),
            ),
          ),
        ),
      );
      await tester.pump();
      final badge = tester.widget<CometChatBadge>(find.byType(CometChatBadge));
      expect(badge.padding, const EdgeInsets.all(6));
    });
    testWidgets('statusIndicatorBorderRadius rounds the status dot', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _three().first,
              onItemClick: (_) {},
              statusIndicatorBorderRadius: const BorderRadius.all(
                Radius.circular(4),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final dot = tester.widget<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(
        dot.style?.borderRadius,
        const BorderRadius.all(Radius.circular(4)),
      );
    });
  });

  test('every wired prop has a row, and every row sets the prop it names', () {
    final rec = _Rec();
    addTearDown(rec.dispose);

    expect(
      {for (final row in _matrix) row.prop},
      {..._Props.wired, 'conversationsBloc'},
    );
    for (final row in _matrix) {
      if (row.prop == 'conversationsBloc') continue;
      expect(row.set(rec).setNames, contains(row.prop), reason: row.claim);
      final unflipped = row.unflipped;
      if (unflipped != null) {
        expect(
          unflipped.set(rec).setNames,
          isNot(contains(row.prop)),
          reason: row.claim,
        );
      }
    }
  });
}
