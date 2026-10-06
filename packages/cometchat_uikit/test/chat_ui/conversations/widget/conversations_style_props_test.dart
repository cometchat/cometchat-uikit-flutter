/// Render-verified prop matrix for [CometChatConversationsStyle] — Track 3
/// PROP1 (ENG-38688, coverage part 2).
///
/// The style is verified through the widget that paints it:
/// `CometChatConversations(conversationsStyle: ...)`, driven by a mocked bloc
/// seeded into a chosen state. Each row names one style field, the sentinel
/// it sets (a value no theme uses), the state to seed, an optional real
/// interaction, a probe that reads the rendered child the field reaches, the
/// reading the sentinel must produce, and the reading the default must
/// produce. Every row is pumped twice in one test body, field unset then set;
/// both readings are pinned and must differ, so a row fails if the widget
/// stopped reading the field. A field read in more than one place has a probe
/// entry per read site. A colour field that is also applied after its
/// TextStyle is merged (`.copyWith(color: ...)`) gets a second, precedence
/// row: the TextStyle carries a decoy colour on both sides, so the row fails
/// if the colour no longer beats it.
///
/// 33 of the 44 fields have a row here. [_unwired] names the other 11, and
/// the guard test keeps them out of this matrix:
///
/// * mentionsStyle: still never read anywhere under conversations/, pending
///   a product decision.
/// * receiptStyle, messageTypeIconColor, privateGroupIconBackground,
///   protectedGroupIconBackground, checkBoxBackgroundColor, checkBoxBorder,
///   checkBoxBorderRadius, checkBoxCheckedBackgroundColor,
///   checkboxSelectedIconColor, listItemSelectedBackgroundColor: these had
///   no effect until ENG-38688 wired them (ConversationsList passed only five
///   fields to each row). conversations_family_fixes_test.dart covers them.
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

/// Swallows every event, and hands out real typing notifiers so a row can
/// seed "someone is typing".
class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  _MockConversationsBloc(this._typing);

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
  _FakeTextMessage({required User from}) : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  int get parentMessageId => 0;

  @override
  DateTime? get deliveredAt => null;

  @override
  DateTime? get readAt => null;

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

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _bob = _FakeUser('u2', 'Bob', status: 'offline');

/// Alice (online, a message from Bob, 3 unread), Bob (offline, no message)
/// and a private group with 1 unread and no message.
List<Conversation> _three() => [
  _FakeConversation(
    conversationWith: _FakeUser('u1', 'Alice'),
    conversationId: 'user_u1',
    unreadMessageCount: 3,
    lastMessage: _FakeTextMessage(from: _bob),
  ),
  _FakeConversation(conversationWith: _bob, conversationId: 'user_u2'),
  _FakeConversation(
    conversationWith: _FakeGroup('g1', 'Dev Team', 'private'),
    conversationId: 'group_g1',
    unreadMessageCount: 1,
  ),
];

ConversationsState _loaded() => ConversationsLoaded(conversations: _three());

/// Alice's row is selected, so the app bar shows the submit tick.
ConversationsState _selected() => ConversationsLoaded(
  conversations: _three(),
  selectedConversations: const {'user_u1'},
);

ConversationsState _empty() => const ConversationsEmpty();

ConversationsState _error() =>
    const ConversationsError(message: 'Network error');

// Sentinels: values no theme produces, so a match can only come from the
// field. None of these colours occurs anywhere in lib/.
const _kBackground = Color(0xFF1A2B3C);
const _kBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFF2B3C4D), width: 3.5),
);
const _kRadius = BorderRadius.all(Radius.circular(13.5));
const _kBackIcon = Color(0xFF3C4D5E);
const _kTitle = Color(0xFF4D5E6F);
const _kSearchIcon = Color(0xFF5E6F70);
const _kSearchBackground = Color(0xFF6F7081);
const _kSearchBorder = BorderSide(color: Color(0xFF708192), width: 2.25);
const _kSearchRadius = BorderRadius.all(Radius.circular(7.5));
const _kPlaceholder = Color(0xFF8192A3);
const _kSeparator = Color(0xFF92A3B4);
const _kSubmit = Color(0xFFA3B4C5);
const _kDialog = Color(0xFFB4C5D6);
const _kEmptyTitle = Color(0xFFC5D6E7);
const _kEmptySubtitle = Color(0xFFD6E7F8);
const _kErrorTitle = Color(0xFF13579B);
const _kErrorSubtitle = Color(0xFF2468AC);
const _kItemTitle = Color(0xFF369BDF);
const _kItemSubtitle = Color(0xFF47ACE0);
const _kAvatar = Color(0xFF58BDF1);
const _kBadge = Color(0xFF6ACE02);
const _kStatusBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFF7BDF13), width: 2.5),
);
const _kDateText = Color(0xFF8CE024);

/// The colour a precedence row puts on a TextStyle so the matching colour
/// field has something to beat.
const _kDecoy = Color(0xFF9E8D7C);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every style field a row can set. Each is wired into the one
/// [CometChatConversationsStyle] construction in [main]; the guard test holds
/// each to a row.
class _S {
  const _S({
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.backIconColor,
    this.titleTextStyle,
    this.titleTextColor,
    this.emptyStateTextStyle,
    this.emptyStateTextColor,
    this.errorStateTextStyle,
    this.errorStateTextColor,
    this.emptyStateSubTitleTextStyle,
    this.emptyStateSubTitleTextColor,
    this.errorStateSubTitleTextStyle,
    this.errorStateSubTitleTextColor,
    this.itemTitleTextStyle,
    this.itemTitleTextColor,
    this.itemSubtitleTextStyle,
    this.itemSubtitleTextColor,
    this.separatorColor,
    this.separatorHeight,
    this.typingIndicatorStyle,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.badgeStyle,
    this.dateStyle,
    this.deleteConversationDialogStyle,
    this.submitIconColor,
    this.searchIconColor,
    this.searchBackgroundColor,
    this.searchBorder,
    this.searchBorderRadius,
    this.searchPlaceHolderTextStyle,
    this.searchPlaceHolderTextColor,
  });

  final Color? backgroundColor;
  final Border? border;
  final BorderRadiusGeometry? borderRadius;
  final Color? backIconColor;
  final TextStyle? titleTextStyle;
  final Color? titleTextColor;
  final TextStyle? emptyStateTextStyle;
  final Color? emptyStateTextColor;
  final TextStyle? errorStateTextStyle;
  final Color? errorStateTextColor;
  final TextStyle? emptyStateSubTitleTextStyle;
  final Color? emptyStateSubTitleTextColor;
  final TextStyle? errorStateSubTitleTextStyle;
  final Color? errorStateSubTitleTextColor;
  final TextStyle? itemTitleTextStyle;
  final Color? itemTitleTextColor;
  final TextStyle? itemSubtitleTextStyle;
  final Color? itemSubtitleTextColor;
  final Color? separatorColor;
  final double? separatorHeight;
  final CometChatTypingIndicatorStyle? typingIndicatorStyle;
  final CometChatAvatarStyle? avatarStyle;
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;
  final CometChatBadgeStyle? badgeStyle;
  final CometChatDateStyle? dateStyle;
  final CometChatConfirmDialogStyle? deleteConversationDialogStyle;
  final Color? submitIconColor;
  final Color? searchIconColor;
  final Color? searchBackgroundColor;
  final BorderSide? searchBorder;
  final BorderRadius? searchBorderRadius;
  final TextStyle? searchPlaceHolderTextStyle;
  final Color? searchPlaceHolderTextColor;

  Map<String, Object?> get values => {
    'backgroundColor': backgroundColor,
    'border': border,
    'borderRadius': borderRadius,
    'backIconColor': backIconColor,
    'titleTextStyle': titleTextStyle,
    'titleTextColor': titleTextColor,
    'emptyStateTextStyle': emptyStateTextStyle,
    'emptyStateTextColor': emptyStateTextColor,
    'errorStateTextStyle': errorStateTextStyle,
    'errorStateTextColor': errorStateTextColor,
    'emptyStateSubTitleTextStyle': emptyStateSubTitleTextStyle,
    'emptyStateSubTitleTextColor': emptyStateSubTitleTextColor,
    'errorStateSubTitleTextStyle': errorStateSubTitleTextStyle,
    'errorStateSubTitleTextColor': errorStateSubTitleTextColor,
    'itemTitleTextStyle': itemTitleTextStyle,
    'itemTitleTextColor': itemTitleTextColor,
    'itemSubtitleTextStyle': itemSubtitleTextStyle,
    'itemSubtitleTextColor': itemSubtitleTextColor,
    'separatorColor': separatorColor,
    'separatorHeight': separatorHeight,
    'typingIndicatorStyle': typingIndicatorStyle,
    'avatarStyle': avatarStyle,
    'statusIndicatorStyle': statusIndicatorStyle,
    'badgeStyle': badgeStyle,
    'dateStyle': dateStyle,
    'deleteConversationDialogStyle': deleteConversationDialogStyle,
    'submitIconColor': submitIconColor,
    'searchIconColor': searchIconColor,
    'searchBackgroundColor': searchBackgroundColor,
    'searchBorder': searchBorder,
    'searchBorderRadius': searchBorderRadius,
    'searchPlaceHolderTextStyle': searchPlaceHolderTextStyle,
    'searchPlaceHolderTextColor': searchPlaceHolderTextColor,
  };

  /// The fields this instance actually sets.
  Set<String> get setNames => {
    for (final e in values.entries)
      if (e.value != null) e.key,
  };

  /// Every field the construction reads from a row.
  static Set<String> get wired => const _S().values.keys.toSet();
}

/// The fields this matrix leaves out: mentionsStyle, which nothing reads,
/// and ten covered by conversations_family_fixes_test.dart. See the library
/// comment.
const _unwired = {
  'receiptStyle',
  'mentionsStyle',
  'messageTypeIconColor',
  'privateGroupIconBackground',
  'protectedGroupIconBackground',
  'checkBoxBackgroundColor',
  'checkBoxBorder',
  'checkBoxBorderRadius',
  'checkBoxCheckedBackgroundColor',
  'checkboxSelectedIconColor',
  'listItemSelectedBackgroundColor',
};

/// The theme tokens the widget falls back to when a field is unset.
typedef _Env = ({
  CometChatColorPalette palette,
  CometChatTypography typography,
  CometChatSpacing spacing,
});

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.set,
    required this.probe,
    required this.expected,
    required this.unset,
    this.base = const _S(),
    this.state = _loaded,
    this.act,
    this.typing = const {},
    this.backButton = false,
    this.search = false,
  });

  /// The [CometChatConversationsStyle] field this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// The style values this row sets.
  final _S set;

  /// Style values rendered on both sides, so a row can show its field
  /// beating another one. [set] repeats them.
  final _S base;

  /// Reads the rendered element the field controls.
  final Object? Function(WidgetTester tester) probe;

  /// What [probe] must return with [set] applied.
  final Object? expected;

  /// What [probe] must return with the field unset: the default, derived
  /// from the theme tokens the widget falls back to.
  final Object? Function(_Env env) unset;

  /// The bloc state to seed.
  final ConversationsState Function() state;

  /// A real interaction to run before probing.
  final Future<void> Function(WidgetTester tester)? act;

  /// Typing indicators to seed, by conversation id.
  final Map<String, List<TypingIndicator>> typing;

  /// Shows the back button, so the back icon renders.
  final bool backButton;

  /// Shows the search box, which CometChatConversations hides by default.
  final bool search;
}

Finder get _conversations => find.byType(CometChatConversations);

Translations _tr(WidgetTester tester) =>
    Translations.of(tester.element(_conversations));

_Env _env(WidgetTester tester) {
  final context = tester.element(_conversations);
  return (
    palette: CometChatThemeHelper.getColorPalette(context),
    typography: CometChatThemeHelper.getTypography(context),
    spacing: CometChatThemeHelper.getSpacing(context),
  );
}

TextStyle? _textStyle(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data)).style;

/// The style of the span that draws [data] inside a RichText: Alice's
/// last-message preview, which goes through the text formatters.
TextStyle? _spanStyle(WidgetTester tester, String data) {
  TextStyle? style;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == data) style = span.style;
      return style == null;
    });
  }
  return style;
}

/// The outermost Container a widget of [type] builds: the row box of a list
/// item, the avatar box, the presence dot, the badge.
Container _box(WidgetTester tester, Type type) => tester.widget<Container>(
  find
      .descendant(of: find.byType(type).first, matching: find.byType(Container))
      .first,
);

BoxDecoration _decoration(WidgetTester tester, Type type) =>
    _box(tester, type).decoration! as BoxDecoration;

/// The box CometChatListBase paints its border and corner radius on.
BoxDecoration _listBaseDecoration(WidgetTester tester) =>
    _box(tester, CometChatListBase).decoration! as BoxDecoration;

AppBar _appBar(WidgetTester tester) => tester.widget<AppBar>(
  find.descendant(of: _conversations, matching: find.byType(AppBar)),
);

Border _appBarShape(WidgetTester tester) => _appBar(tester).shape! as Border;

InputDecoration _search(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

final _matrix = <_Row>[
  // ── The container and app bar ─────────────────────────────────────────────
  _Row(
    'backgroundColor',
    'paints the list base, its app bar and every row',
    set: const _S(backgroundColor: _kBackground),
    probe: (t) => [
      t
          .widget<Scaffold>(
            find.descendant(
              of: find.byType(CometChatListBase),
              matching: find.byType(Scaffold),
            ),
          )
          .backgroundColor,
      _appBar(t).backgroundColor,
      _box(t, CometChatConversationListItem).color,
    ],
    expected: [_kBackground, _kBackground, _kBackground],
    unset: (e) => [
      e.palette.background1,
      e.palette.background1,
      e.palette.background1,
    ],
  ),
  _Row(
    'border',
    'outlines the list base',
    set: const _S(border: _kBorder),
    probe: (t) => _listBaseDecoration(t).border,
    expected: _kBorder,
    unset: (e) => null,
  ),
  _Row(
    'borderRadius',
    'rounds the outer clip, the list base clip and its box',
    set: const _S(borderRadius: _kRadius),
    probe: (t) => [
      // The clip CometChatConversations wraps the list base in.
      t
          .widget<ClipRRect>(
            find
                .ancestor(
                  of: find.byType(CometChatListBase),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .borderRadius,
      // The list base's own clip, from ListBaseStyle.borderRadius.
      t
          .widget<ClipRRect>(
            find
                .descendant(
                  of: find.byType(CometChatListBase),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .borderRadius,
      _listBaseDecoration(t).borderRadius,
    ],
    expected: [_kRadius, _kRadius, _kRadius],
    unset: (e) => [BorderRadius.zero, BorderRadius.zero, null],
  ),
  _Row(
    'backIconColor',
    'colours the back arrow and tints the list base back button',
    backButton: true,
    set: const _S(backIconColor: _kBackIcon),
    probe: (t) => [
      _iconColor(t, Icons.arrow_back),
      // Nearest first: the conversations IconButton, then the list base's.
      for (final button in t.widgetList<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        ),
      ))
        button.color,
    ],
    expected: [_kBackIcon, null, _kBackIcon],
    unset: (e) => [e.palette.iconPrimary, null, e.palette.iconPrimary],
  ),
  _Row(
    'titleTextColor',
    'colours the app bar title',
    set: const _S(titleTextColor: _kTitle),
    probe: (t) => _textStyle(t, _tr(t).chats)?.color,
    expected: _kTitle,
    unset: (e) => e.palette.textPrimary,
  ),
  _Row(
    'titleTextStyle',
    'sizes the app bar title',
    set: const _S(titleTextStyle: TextStyle(fontSize: 27.25)),
    probe: (t) => _textStyle(t, _tr(t).chats)?.fontSize,
    expected: 27.25,
    unset: (e) => e.typography.heading1?.bold?.fontSize,
  ),
  _Row(
    'separatorColor',
    'colours the line under the app bar',
    set: const _S(separatorColor: _kSeparator),
    probe: (t) => _appBarShape(t).bottom.color,
    expected: _kSeparator,
    unset: (e) => e.palette.borderLight ?? Colors.transparent,
  ),
  _Row(
    'separatorHeight',
    'sets the width of the line under the app bar',
    set: const _S(separatorHeight: 3.75),
    probe: (t) => _appBarShape(t).bottom.width,
    expected: 3.75,
    unset: (e) => 1.0,
  ),
  _Row(
    'submitIconColor',
    'colours the submit tick shown while rows are selected',
    state: _selected,
    set: const _S(submitIconColor: _kSubmit),
    probe: (t) => _iconColor(t, Icons.check),
    expected: _kSubmit,
    unset: (e) => e.palette.iconPrimary,
  ),

  // ── Search box ────────────────────────────────────────────────────────────
  _Row(
    'searchIconColor',
    'colours the search glyph and the prefix icon slot',
    search: true,
    set: const _S(searchIconColor: _kSearchIcon),
    probe: (t) => [_iconColor(t, Icons.search), _search(t).prefixIconColor],
    expected: [_kSearchIcon, _kSearchIcon],
    unset: (e) => [e.palette.iconSecondary, e.palette.iconSecondary],
  ),
  _Row(
    'searchBackgroundColor',
    'fills the search box',
    search: true,
    set: const _S(searchBackgroundColor: _kSearchBackground),
    probe: (t) => _search(t).fillColor,
    expected: _kSearchBackground,
    unset: (e) => e.palette.background3,
  ),
  _Row(
    'searchBorder',
    'outlines the search box in every state',
    search: true,
    set: const _S(searchBorder: _kSearchBorder),
    probe: (t) => [
      (_search(t).enabledBorder! as OutlineInputBorder).borderSide,
      (_search(t).focusedBorder! as OutlineInputBorder).borderSide,
      (_search(t).border! as OutlineInputBorder).borderSide,
    ],
    expected: [_kSearchBorder, _kSearchBorder, _kSearchBorder],
    unset: (e) => [
      for (var i = 0; i < 3; i++)
        BorderSide(color: e.palette.borderLight ?? Colors.transparent),
    ],
  ),
  _Row(
    'searchBorderRadius',
    'rounds the search box',
    search: true,
    set: const _S(searchBorderRadius: _kSearchRadius),
    probe: (t) => [
      (_search(t).enabledBorder! as OutlineInputBorder).borderRadius,
      (_search(t).focusedBorder! as OutlineInputBorder).borderRadius,
      (_search(t).border! as OutlineInputBorder).borderRadius,
    ],
    expected: [_kSearchRadius, _kSearchRadius, _kSearchRadius],
    unset: (e) => [
      for (var i = 0; i < 3; i++)
        BorderRadius.circular(e.spacing.radiusMax ?? 0),
    ],
  ),
  _Row(
    'searchPlaceHolderTextColor',
    'colours the rendered search hint',
    search: true,
    set: const _S(searchPlaceHolderTextColor: _kPlaceholder),
    probe: (t) => _textStyle(t, _tr(t).search)?.color,
    expected: _kPlaceholder,
    unset: (e) => e.palette.textTertiary,
  ),
  _Row(
    'searchPlaceHolderTextColor',
    'beats the colour of searchPlaceHolderTextStyle',
    search: true,
    base: const _S(searchPlaceHolderTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      searchPlaceHolderTextStyle: TextStyle(color: _kDecoy),
      searchPlaceHolderTextColor: _kPlaceholder,
    ),
    probe: (t) => _textStyle(t, _tr(t).search)?.color,
    expected: _kPlaceholder,
    unset: (e) => _kDecoy,
  ),
  _Row(
    'searchPlaceHolderTextStyle',
    'sizes the rendered search hint',
    search: true,
    set: const _S(searchPlaceHolderTextStyle: TextStyle(fontSize: 17.75)),
    probe: (t) => _textStyle(t, _tr(t).search)?.fontSize,
    expected: 17.75,
    unset: (e) => e.typography.heading4?.regular?.fontSize,
  ),

  // ── Delete confirmation dialog ────────────────────────────────────────────
  _Row(
    'deleteConversationDialogStyle',
    'paints the dialog opened from the long-press Delete action',
    set: const _S(
      deleteConversationDialogStyle: CometChatConfirmDialogStyle(
        backgroundColor: _kDialog,
      ),
    ),
    act: (t) async {
      await t.longPress(find.text('Alice'));
      await t.pump(); // the widget marks the row open
      await t.pump(); // post-frame: the MenuController opens
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(_tr(t).delete));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    },
    probe: (t) => t
        .widget<Material>(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        )
        .color,
    expected: _kDialog,
    unset: (e) => e.palette.background1,
  ),

  // ── State views ───────────────────────────────────────────────────────────
  _Row(
    'emptyStateTextColor',
    'colours the empty-state title',
    state: _empty,
    set: const _S(emptyStateTextColor: _kEmptyTitle),
    probe: (t) => _textStyle(t, _tr(t).noConversationsYet)?.color,
    expected: _kEmptyTitle,
    unset: (e) => e.palette.textPrimary,
  ),
  _Row(
    'emptyStateTextColor',
    'beats the colour of emptyStateTextStyle',
    state: _empty,
    base: const _S(emptyStateTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      emptyStateTextStyle: TextStyle(color: _kDecoy),
      emptyStateTextColor: _kEmptyTitle,
    ),
    probe: (t) => _textStyle(t, _tr(t).noConversationsYet)?.color,
    expected: _kEmptyTitle,
    unset: (e) => _kDecoy,
  ),
  _Row(
    'emptyStateTextStyle',
    'sizes the empty-state title',
    state: _empty,
    set: const _S(emptyStateTextStyle: TextStyle(fontSize: 22.75)),
    probe: (t) => _textStyle(t, _tr(t).noConversationsYet)?.fontSize,
    expected: 22.75,
    unset: (e) => e.typography.heading3?.bold?.fontSize,
  ),
  _Row(
    'emptyStateSubTitleTextColor',
    'colours the empty-state subtitle',
    state: _empty,
    set: const _S(emptyStateSubTitleTextColor: _kEmptySubtitle),
    probe: (t) => _textStyle(t, _tr(t).startNewChatOrInvite)?.color,
    expected: _kEmptySubtitle,
    unset: (e) => e.palette.textSecondary,
  ),
  _Row(
    'emptyStateSubTitleTextColor',
    'beats the colour of emptyStateSubTitleTextStyle',
    state: _empty,
    base: const _S(emptyStateSubTitleTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      emptyStateSubTitleTextStyle: TextStyle(color: _kDecoy),
      emptyStateSubTitleTextColor: _kEmptySubtitle,
    ),
    probe: (t) => _textStyle(t, _tr(t).startNewChatOrInvite)?.color,
    expected: _kEmptySubtitle,
    unset: (e) => _kDecoy,
  ),
  _Row(
    'emptyStateSubTitleTextStyle',
    'sizes the empty-state subtitle',
    state: _empty,
    set: const _S(emptyStateSubTitleTextStyle: TextStyle(fontSize: 15.25)),
    probe: (t) => _textStyle(t, _tr(t).startNewChatOrInvite)?.fontSize,
    expected: 15.25,
    unset: (e) => e.typography.heading3?.regular?.fontSize,
  ),
  _Row(
    'errorStateTextColor',
    'colours the error-state title',
    state: _error,
    set: const _S(errorStateTextColor: _kErrorTitle),
    probe: (t) => _textStyle(t, _tr(t).oops)?.color,
    expected: _kErrorTitle,
    unset: (e) => e.palette.textPrimary,
  ),
  _Row(
    'errorStateTextColor',
    'beats the colour of errorStateTextStyle',
    state: _error,
    base: const _S(errorStateTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      errorStateTextStyle: TextStyle(color: _kDecoy),
      errorStateTextColor: _kErrorTitle,
    ),
    probe: (t) => _textStyle(t, _tr(t).oops)?.color,
    expected: _kErrorTitle,
    unset: (e) => _kDecoy,
  ),
  _Row(
    'errorStateTextStyle',
    'sizes the error-state title',
    state: _error,
    set: const _S(errorStateTextStyle: TextStyle(fontSize: 23.25)),
    probe: (t) => _textStyle(t, _tr(t).oops)?.fontSize,
    expected: 23.25,
    unset: (e) => e.typography.heading3?.bold?.fontSize,
  ),
  _Row(
    'errorStateSubTitleTextColor',
    'colours the error-state subtitle',
    state: _error,
    set: const _S(errorStateSubTitleTextColor: _kErrorSubtitle),
    probe: (t) =>
        t.widget<Text>(find.textContaining(_tr(t).pleaseTryAgain)).style?.color,
    expected: _kErrorSubtitle,
    unset: (e) => e.palette.textSecondary,
  ),
  _Row(
    'errorStateSubTitleTextColor',
    'beats the colour of errorStateSubTitleTextStyle',
    state: _error,
    base: const _S(errorStateSubTitleTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      errorStateSubTitleTextStyle: TextStyle(color: _kDecoy),
      errorStateSubTitleTextColor: _kErrorSubtitle,
    ),
    probe: (t) =>
        t.widget<Text>(find.textContaining(_tr(t).pleaseTryAgain)).style?.color,
    expected: _kErrorSubtitle,
    unset: (e) => _kDecoy,
  ),
  _Row(
    'errorStateSubTitleTextStyle',
    'sizes the error-state subtitle',
    state: _error,
    set: const _S(errorStateSubTitleTextStyle: TextStyle(fontSize: 16.75)),
    probe: (t) => t
        .widget<Text>(find.textContaining(_tr(t).pleaseTryAgain))
        .style
        ?.fontSize,
    expected: 16.75,
    unset: (e) => e.typography.heading3?.regular?.fontSize,
  ),

  // ── Rows ──────────────────────────────────────────────────────────────────
  _Row(
    'itemTitleTextColor',
    'colours the conversation name',
    set: const _S(itemTitleTextColor: _kItemTitle),
    probe: (t) => _textStyle(t, 'Alice')?.color,
    expected: _kItemTitle,
    unset: (e) => e.palette.textPrimary,
  ),
  _Row(
    'itemTitleTextStyle',
    'sizes the conversation name',
    set: const _S(itemTitleTextStyle: TextStyle(fontSize: 19.25)),
    probe: (t) => _textStyle(t, 'Alice')?.fontSize,
    expected: 19.25,
    unset: (e) => e.typography.heading4?.medium?.fontSize,
  ),
  // Bob and Dev Team have no last message, so their subtitle is the
  // tap-to-start line, drawn in the item subtitle style. Alice's subtitle is
  // her last message, drawn through the text formatters: a second path.
  _Row(
    'itemSubtitleTextColor',
    'colours the subtitle line of every row, last message included',
    set: const _S(itemSubtitleTextColor: _kItemSubtitle),
    probe: (t) => [
      for (final text in t.widgetList<Text>(
        find.text(_tr(t).tapToStartConversation),
      ))
        text.style?.color,
      _spanStyle(t, 'Hello!')?.color,
    ],
    expected: [_kItemSubtitle, _kItemSubtitle, _kItemSubtitle],
    unset: (e) => [
      e.palette.textSecondary,
      e.palette.textSecondary,
      e.palette.textSecondary,
    ],
  ),
  _Row(
    'itemSubtitleTextColor',
    'beats the colour of itemSubtitleTextStyle',
    base: const _S(itemSubtitleTextStyle: TextStyle(color: _kDecoy)),
    set: const _S(
      itemSubtitleTextStyle: TextStyle(color: _kDecoy),
      itemSubtitleTextColor: _kItemSubtitle,
    ),
    probe: (t) => [
      for (final text in t.widgetList<Text>(
        find.text(_tr(t).tapToStartConversation),
      ))
        text.style?.color,
      _spanStyle(t, 'Hello!')?.color,
    ],
    expected: [_kItemSubtitle, _kItemSubtitle, _kItemSubtitle],
    unset: (e) => [_kDecoy, _kDecoy, _kDecoy],
  ),
  _Row(
    'itemSubtitleTextStyle',
    'sizes the subtitle line of every row, last message included',
    set: const _S(itemSubtitleTextStyle: TextStyle(fontSize: 13.25)),
    probe: (t) => [
      for (final text in t.widgetList<Text>(
        find.text(_tr(t).tapToStartConversation),
      ))
        text.style?.fontSize,
      _spanStyle(t, 'Hello!')?.fontSize,
    ],
    expected: [13.25, 13.25, 13.25],
    unset: (e) => [
      for (var i = 0; i < 3; i++) e.typography.body?.regular?.fontSize,
    ],
  ),
  _Row(
    'avatarStyle',
    'backgroundColor paints the row avatar',
    set: const _S(avatarStyle: CometChatAvatarStyle(backgroundColor: _kAvatar)),
    probe: (t) => _decoration(t, CometChatAvatar).color,
    expected: _kAvatar,
    unset: (e) => e.palette.extendedPrimary500,
  ),
  _Row(
    'badgeStyle',
    'backgroundColor paints the unread badge',
    set: const _S(badgeStyle: CometChatBadgeStyle(backgroundColor: _kBadge)),
    probe: (t) => _decoration(t, CometChatBadge).color,
    expected: _kBadge,
    unset: (e) => e.palette.primary,
  ),
  _Row(
    'statusIndicatorStyle',
    'border outlines the presence dot',
    set: const _S(
      statusIndicatorStyle: CometChatStatusIndicatorStyle(
        border: _kStatusBorder,
      ),
    ),
    probe: (t) => _decoration(t, CometChatStatusIndicator).border,
    expected: _kStatusBorder,
    unset: (e) => Border.all(
      width: e.spacing.spacing ?? 0,
      color: e.palette.background1 ?? Colors.transparent,
    ),
  ),
  _Row(
    'typingIndicatorStyle',
    'textStyle sizes the typing line',
    typing: {
      'user_u1': [
        TypingIndicator(sender: _bob, receiverId: 'u1', receiverType: 'user'),
      ],
    },
    set: const _S(
      typingIndicatorStyle: CometChatTypingIndicatorStyle(
        textStyle: TextStyle(fontSize: 21.5),
      ),
    ),
    probe: (t) => _textStyle(t, _tr(t).isTyping)?.fontSize,
    expected: 21.5,
    unset: (e) => e.typography.body?.regular?.fontSize,
  ),
  _Row(
    'dateStyle',
    'textColor colours the timestamp',
    set: const _S(dateStyle: CometChatDateStyle(textColor: _kDateText)),
    probe: (t) => t
        .widget<Text>(
          find.descendant(
            of: find.byType(CometChatDate).first,
            matching: find.byType(Text),
          ),
        )
        .style
        ?.color,
    expected: _kDateText,
    unset: (e) => e.palette.textSecondary,
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatConversationsStyle prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        final readings = <Object?>[];

        for (final (label, s) in [('unset', row.base), ('set', row.set)]) {
          final state = row.state();
          final bloc = _MockConversationsBloc(row.typing);
          whenListen(
            bloc,
            Stream<ConversationsState>.value(state),
            initialState: state,
          );

          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(
              _wrap(
                CometChatConversations(
                  conversationsBloc: bloc,
                  showBackButton: row.backButton,
                  hideSearch: !row.search,
                  conversationsStyle: CometChatConversationsStyle(
                    backgroundColor: s.backgroundColor,
                    border: s.border,
                    borderRadius: s.borderRadius,
                    backIconColor: s.backIconColor,
                    titleTextStyle: s.titleTextStyle,
                    titleTextColor: s.titleTextColor,
                    emptyStateTextStyle: s.emptyStateTextStyle,
                    emptyStateTextColor: s.emptyStateTextColor,
                    errorStateTextStyle: s.errorStateTextStyle,
                    errorStateTextColor: s.errorStateTextColor,
                    emptyStateSubTitleTextStyle: s.emptyStateSubTitleTextStyle,
                    emptyStateSubTitleTextColor: s.emptyStateSubTitleTextColor,
                    errorStateSubTitleTextStyle: s.errorStateSubTitleTextStyle,
                    errorStateSubTitleTextColor: s.errorStateSubTitleTextColor,
                    itemTitleTextStyle: s.itemTitleTextStyle,
                    itemTitleTextColor: s.itemTitleTextColor,
                    itemSubtitleTextStyle: s.itemSubtitleTextStyle,
                    itemSubtitleTextColor: s.itemSubtitleTextColor,
                    separatorColor: s.separatorColor,
                    separatorHeight: s.separatorHeight,
                    typingIndicatorStyle: s.typingIndicatorStyle,
                    avatarStyle: s.avatarStyle,
                    statusIndicatorStyle: s.statusIndicatorStyle,
                    badgeStyle: s.badgeStyle,
                    dateStyle: s.dateStyle,
                    deleteConversationDialogStyle:
                        s.deleteConversationDialogStyle,
                    submitIconColor: s.submitIconColor,
                    searchIconColor: s.searchIconColor,
                    searchBackgroundColor: s.searchBackgroundColor,
                    searchBorder: s.searchBorder,
                    searchBorderRadius: s.searchBorderRadius,
                    searchPlaceHolderTextStyle: s.searchPlaceHolderTextStyle,
                    searchPlaceHolderTextColor: s.searchPlaceHolderTextColor,
                  ),
                ),
                // A fresh app per side, so no element state carries over.
                key: ValueKey(label),
              ),
            );
            await tester.pump();
            await row.act?.call(tester);
          });

          final reading = row.probe(tester);
          expect(
            reading,
            label == 'set' ? row.expected : row.unset(_env(tester)),
            reason: '${row.prop}, $label render',
          );
          readings.add(reading);
        }

        expect(
          readings.last,
          isNot(equals(readings.first)),
          reason: '${row.prop} must render differently from its unset side',
        );

        // Tear the tree down inside the test so no timer outlives it.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
      });
    }
  });

  test('every wired field has a row, every row adds only the field it '
      'names, and the unwired fields stay out of the construction', () {
    expect({for (final row in _matrix) row.prop}, _S.wired);
    for (final row in _matrix) {
      expect(row.base.setNames, isNot(contains(row.prop)), reason: row.claim);
      expect(row.set.setNames.difference(row.base.setNames), {
        row.prop,
      }, reason: row.claim);
      for (final name in row.base.setNames) {
        expect(row.set.values[name], row.base.values[name], reason: row.claim);
      }
    }
    expect(_S.wired.intersection(_unwired), isEmpty);
    // CometChatConversationsStyle has 44 fields: 33 here, 11 left out.
    expect(_S.wired.length + _unwired.length, 44);
  });
}
