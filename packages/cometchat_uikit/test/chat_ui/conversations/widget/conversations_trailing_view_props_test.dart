/// Render-verified prop matrix for [ConversationsTrailingView] — Track 3
/// PROP1 (ENG-38688, coverage part 2).
///
/// [ConversationsTrailingView] is exported but nothing in lib builds it, so
/// the matrix renders it standalone: the last-message timestamp
/// ([CometChatDate]), an optional pin and the unread badge
/// ([CometChatBadge]).
///
/// How the matrix works. [_matrix] is a table. Each row names the prop it
/// verifies, the conversation it renders, the values it sets (sentinels no
/// theme uses), a probe that reads the rendered element the prop controls
/// (a colour, a laid-out size or offset, a painted string), and what the
/// probe must return. Every row is pumped twice in one test body. The first
/// side is either the unset construction, which passes only the required
/// tokens at their baseline and omits every optional prop, or an explicit
/// `unflipped` side. The two readings must differ, so a row whose assertion
/// would still hold if the view ignored the prop fails here. The guard test
/// at the bottom fails if a prop loses its row or a row stops setting the
/// prop it names.
///
/// Every one of the 15 props has at least one row, and props read in more
/// than one place (conversation, datesStyle, colorPalette, spacing,
/// typography, dateBackgroundIsTransparent) have a row per read site.
///
///   flutter test test/chat_ui/conversations/widget/conversations_trailing_view_props_test.dart
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

class _FakeTextMessage extends Mock implements TextMessage {
  _FakeTextMessage({required User from, required this.sentAt, this.updatedAt})
    : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  final DateTime sentAt;

  @override
  final DateTime? updatedAt;

  @override
  int get id => 100;

  @override
  String get text => 'Hello!';

  @override
  String get type => 'text';

  @override
  String get category => 'message';

  @override
  String get receiverUid => 'u1';

  @override
  String get muid => 'muid_100';
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation({
    required this.conversationWith,
    this.unreadMessageCount = 3,
    this.pinnedBy,
    BaseMessage? lastMessage,
  }) : _lastMessage = lastMessage;

  @override
  String get conversationId => 'user_${(conversationWith as User).uid}';

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
  String get conversationType => 'user';

  @override
  DateTime? get pinnedAt => pinnedBy == null ? null : DateTime(2020);
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

final _alice = _FakeUser('u1', 'Alice');
final _bob = _FakeUser('u2', 'Bob');

/// Long past, so CometChatDate prints it as "d MMM, yyyy" whatever today is.
final _sent = DateTime(2020, 1, 2, 10, 30);
const _sentText = '2 Jan, 2020';

Conversation _chat({
  User? withWhom,
  DateTime? sentAt,
  DateTime? updatedAt,
  bool noMessage = false,
  int unread = 3,
  String? pinnedBy,
}) => _FakeConversation(
  conversationWith: withWhom ?? _alice,
  unreadMessageCount: unread,
  pinnedBy: pinnedBy,
  lastMessage: noMessage
      ? null
      : _FakeTextMessage(
          from: _bob,
          sentAt: sentAt ?? _sent,
          updatedAt: updatedAt,
        ),
);

/// Alice: a message from Bob on 2 Jan 2020, 3 unread, not pinned.
Conversation _base() => _chat();

/// The same, pinned.
Conversation _pinned() => _chat(pinnedBy: 'me');

Conversation _agent(String role) =>
    _chat(withWhom: _FakeUser('bot', 'Helper Bot', role: role));

// Baseline tokens: what every row renders with unless it overrides one.
const _style = CometChatConversationsStyle();
const _datesStyle = CometChatDateStyle();

const _kTextSecondary = Color(0xFF727272);
const _kIconSecondary = Color(0xFFA1A1A1);
const _kTransparent = Color(0x00000000);

final _palette = CometChatColorPalette(
  textSecondary: _kTextSecondary,
  iconSecondary: _kIconSecondary,
  transparent: _kTransparent,
);

final _spacing = CometChatSpacing(padding: 2, padding1: 4, padding2: 8);

const _typography = CometChatTypography(
  caption1: CometChatTextStyleCaption1(regular: TextStyle(fontSize: 12)),
);

// Sentinels: values no theme produces, so a match can only come from the prop.
const _kBadgeBackground = Color(0xFFA3B4C5);
const _kBadgeText = Color(0xFFB4C5D6);
const _kDateBackground = Color(0xFFC5D6E7);
const _kDateText = Color(0xFFD6E7F8);
const _kDateBorderColor = Color(0xFFE7F809);
const _kPalette = Color(0xFF13579B);
final _kDateBorder = Border.all(color: _kDateBorderColor, width: 1.5);
const _kDateRadius = BorderRadius.all(Radius.circular(6.5));
const _kThemeDateText = Color(0xFF8A7B6C);

const _kTypography = CometChatTypography(
  caption1: CometChatTextStyleCaption1(
    regular: TextStyle(
      fontSize: 13.75,
      fontWeight: FontWeight.w600,
      fontFamily: 'SentinelSans',
    ),
  ),
);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every value a row can set. Each field is a prop wired into the set-side
/// construction in [main]; the guard test holds each field to a row.
class _Props {
  const _Props({
    this.conversation,
    this.style,
    this.datesStyle,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.datePattern,
    this.datePadding,
    this.dateHeight,
    this.dateWidth,
    this.dateBackgroundIsTransparent,
    this.badgeWidth,
    this.badgeHeight,
    this.badgePadding,
    this.dateTimeFormatterCallback,
  });

  final Conversation? conversation;
  final CometChatConversationsStyle? style;
  final CometChatDateStyle? datesStyle;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final String Function(Conversation)? datePattern;
  final EdgeInsets? datePadding;
  final double? dateHeight;
  final double? dateWidth;
  final bool? dateBackgroundIsTransparent;
  final double? badgeWidth;
  final double? badgeHeight;
  final EdgeInsetsGeometry? badgePadding;
  final DateTimeFormatterCallback? dateTimeFormatterCallback;

  Map<String, Object?> get values => {
    'conversation': conversation,
    'style': style,
    'datesStyle': datesStyle,
    'colorPalette': colorPalette,
    'spacing': spacing,
    'typography': typography,
    'datePattern': datePattern,
    'datePadding': datePadding,
    'dateHeight': dateHeight,
    'dateWidth': dateWidth,
    'dateBackgroundIsTransparent': dateBackgroundIsTransparent,
    'badgeWidth': badgeWidth,
    'badgeHeight': badgeHeight,
    'badgePadding': badgePadding,
    'dateTimeFormatterCallback': dateTimeFormatterCallback,
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
    required this.set,
    required this.probe,
    required this.expected,
    this.conversation = _base,
    this.unflipped,
    this.before = const _Differs(),
    this.themeExtensions = const [],
  });

  /// The [ConversationsTrailingView] parameter this row verifies.
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

  /// Theme extensions both sides render under, for rows that pin a value
  /// against what the app theme would otherwise supply.
  final List<ThemeExtension<dynamic>> themeExtensions;
}

Finder _inView(Finder finder) => find.descendant(
  of: find.byType(ConversationsTrailingView),
  matching: finder,
);

int _count(Finder finder) => finder.evaluate().length;

Finder _dateText() => find.descendant(
  of: find.byType(CometChatDate),
  matching: find.byType(Text),
);

/// The timestamp as painted, or null when there is none.
String? _when(WidgetTester tester) =>
    _count(_dateText()) == 0 ? null : tester.widget<Text>(_dateText()).data;

TextStyle? _whenStyle(WidgetTester tester) =>
    tester.widget<Text>(_dateText()).style;

/// The box a widget of [type] paints: the date chip, the badge.
BoxDecoration _box(WidgetTester tester, Type type) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(type),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// The badge count as painted, or null when no count is shown.
String? _badgeCount(WidgetTester tester) {
  final text = find.descendant(
    of: find.byType(CometChatBadge),
    matching: find.byType(Text),
  );
  return _count(text) == 0 ? null : tester.widget<Text>(text).data;
}

/// Where [child] sits inside [parent], as laid out.
Offset _inset(WidgetTester tester, Finder parent, Finder child) =>
    tester.getTopLeft(child) - tester.getTopLeft(parent);

final _matrix = <_Row>[
  // ── conversation ──────────────────────────────────────────────────────────
  _Row(
    'conversation',
    "its last message's sentAt is the timestamp",
    set: () => _Props(conversation: _chat(sentAt: DateTime(2021, 3, 4, 9))),
    probe: _when,
    before: _sentText,
    expected: '4 Mar, 2021',
  ),
  _Row(
    'conversation',
    'updatedAt wins over sentAt',
    set: () => _Props(conversation: _chat(updatedAt: DateTime(2022, 6, 7, 9))),
    probe: _when,
    before: _sentText,
    expected: '7 Jun, 2022',
  ),
  _Row(
    'conversation',
    'no last message, no timestamp',
    set: () => _Props(conversation: _chat(noMessage: true)),
    probe: (t) => [_count(find.byType(CometChatDate)), _when(t)],
    before: [1, _sentText],
    expected: [0, null],
  ),
  _Row(
    'conversation',
    'unreadMessageCount is the badge count',
    set: () => _Props(conversation: _chat(unread: 7)),
    probe: _badgeCount,
    before: '3',
    expected: '7',
  ),
  _Row(
    'conversation',
    'a pin shows the pin icon',
    set: () => _Props(conversation: _pinned()),
    probe: (t) => _count(_inView(find.byIcon(Icons.push_pin))),
    before: 0,
    expected: 1,
  ),
  _Row(
    'conversation',
    'an AI agent (aiRole) conversation gets no timestamp and no badge',
    set: () => _Props(conversation: _agent(AIConstants.aiRole)),
    probe: (t) => [
      _count(find.byType(CometChatDate)),
      _count(find.byType(CometChatBadge)),
    ],
    before: [1, 1],
    expected: [0, 0],
  ),
  _Row(
    'conversation',
    "an AI agent with the literal role 'ai' is hidden too",
    set: () => _Props(conversation: _agent('ai')),
    probe: (t) => [
      _count(find.byType(CometChatDate)),
      _count(find.byType(CometChatBadge)),
    ],
    before: [1, 1],
    expected: [0, 0],
  ),

  // ── style ─────────────────────────────────────────────────────────────────
  _Row(
    'style',
    'badgeStyle colours the unread badge and its count',
    set: () => const _Props(
      style: CometChatConversationsStyle(
        badgeStyle: CometChatBadgeStyle(
          backgroundColor: _kBadgeBackground,
          textColor: _kBadgeText,
        ),
      ),
    ),
    probe: (t) => [
      _box(t, CometChatBadge).color,
      t
          .widget<Text>(
            find.descendant(
              of: find.byType(CometChatBadge),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.color,
    ],
    expected: [_kBadgeBackground, _kBadgeText],
  ),

  // ── datesStyle, one row per field ─────────────────────────────────────────
  _Row(
    'datesStyle',
    'backgroundColor fills the date chip',
    set: () => const _Props(
      datesStyle: CometChatDateStyle(backgroundColor: _kDateBackground),
    ),
    probe: (t) => _box(t, CometChatDate).color,
    before: _kTransparent,
    expected: _kDateBackground,
  ),
  _Row(
    'datesStyle',
    'textColor colours the timestamp, over a textStyle colour',
    set: () => const _Props(
      datesStyle: CometChatDateStyle(
        textColor: _kDateText,
        textStyle: TextStyle(color: _kBadgeText),
      ),
    ),
    probe: (t) => _whenStyle(t)?.color,
    before: _kTextSecondary,
    expected: _kDateText,
  ),
  _Row(
    'datesStyle',
    'textColor is forwarded to CometChatDate, so it beats a themed textColor',
    themeExtensions: const [CometChatDateStyle(textColor: _kThemeDateText)],
    set: () =>
        const _Props(datesStyle: CometChatDateStyle(textColor: _kDateText)),
    probe: (t) => _whenStyle(t)?.color,
    before: _kThemeDateText,
    expected: _kDateText,
  ),
  _Row(
    'datesStyle',
    'textStyle sizes the timestamp',
    set: () => const _Props(
      datesStyle: CometChatDateStyle(
        textStyle: TextStyle(fontSize: 15.25, fontStyle: FontStyle.italic),
      ),
    ),
    probe: (t) => (_whenStyle(t)?.fontSize, _whenStyle(t)?.fontStyle),
    before: (12.0, null),
    expected: (15.25, FontStyle.italic),
  ),
  _Row(
    'datesStyle',
    'border outlines the date chip',
    set: () => _Props(datesStyle: CometChatDateStyle(border: _kDateBorder)),
    probe: (t) => _box(t, CometChatDate).border,
    before: Border.all(width: 0, color: Colors.transparent),
    expected: _kDateBorder,
  ),
  _Row(
    'datesStyle',
    'borderRadius rounds the date chip',
    set: () => const _Props(
      datesStyle: CometChatDateStyle(borderRadius: _kDateRadius),
    ),
    probe: (t) => _box(t, CometChatDate).borderRadius,
    expected: _kDateRadius,
  ),

  // ── colorPalette, one row per read site ───────────────────────────────────
  _Row(
    'colorPalette',
    'transparent fills the date chip when datesStyle sets no background',
    set: () => _Props(colorPalette: _palette.copyWith(transparent: _kPalette)),
    probe: (t) => _box(t, CometChatDate).color,
    before: _kTransparent,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'textSecondary colours the timestamp when datesStyle sets no colour',
    set: () =>
        _Props(colorPalette: _palette.copyWith(textSecondary: _kPalette)),
    probe: (t) => _whenStyle(t)?.color,
    before: _kTextSecondary,
    expected: _kPalette,
  ),
  _Row(
    'colorPalette',
    'iconSecondary tints the pin',
    conversation: _pinned,
    set: () =>
        _Props(colorPalette: _palette.copyWith(iconSecondary: _kPalette)),
    probe: (t) => t.widget<Icon>(_inView(find.byIcon(Icons.push_pin))).color,
    before: _kIconSecondary,
    expected: _kPalette,
  ),

  // ── spacing ───────────────────────────────────────────────────────────────
  _Row(
    'spacing',
    'padding2 insets the whole trailing column from the left',
    set: () => _Props(spacing: _spacing.copyWith(padding2: 10.5)),
    probe: (t) =>
        t.widget<Padding>(_inView(find.byType(Padding)).first).padding,
    before: const EdgeInsets.only(left: 8),
    expected: const EdgeInsets.only(left: 10.5),
  ),
  _Row(
    'spacing',
    'padding1 spaces the pin from the badge',
    conversation: _pinned,
    set: () => _Props(spacing: _spacing.copyWith(padding1: 9.5)),
    probe: (t) => t
        .widget<Padding>(
          find
              .ancestor(
                of: _inView(find.byIcon(Icons.push_pin)),
                matching: find.byType(Padding),
              )
              .first,
        )
        .padding,
    before: const EdgeInsets.only(right: 4),
    expected: const EdgeInsets.only(right: 9.5),
  ),

  // ── typography, one row per read site ─────────────────────────────────────
  _Row(
    'typography',
    'caption1.regular sets the timestamp face',
    set: () => const _Props(typography: _kTypography),
    probe: (t) => (
      _whenStyle(t)?.fontSize,
      _whenStyle(t)?.fontWeight,
      _whenStyle(t)?.fontFamily,
    ),
    expected: (13.75, FontWeight.w600, 'SentinelSans'),
  ),
  _Row(
    'typography',
    'caption1.regular fontSize sizes the pin',
    conversation: _pinned,
    set: () => const _Props(typography: _kTypography),
    probe: (t) => t.getSize(_inView(find.byIcon(Icons.push_pin))),
    before: const Size(12, 12),
    expected: const Size(13.75, 13.75),
  ),

  // ── Date props ────────────────────────────────────────────────────────────
  _Row(
    'datePattern',
    'writes the timestamp from the conversation',
    set: () => _Props(datePattern: (c) => 'when-${c.conversationId}'),
    probe: _when,
    before: _sentText,
    expected: 'when-user_u1',
  ),
  _Row(
    'dateTimeFormatterCallback',
    'formats the timestamp',
    set: () => _Props(dateTimeFormatterCallback: _SentinelDates()),
    probe: _when,
    before: _sentText,
    expected: 'WHEN-SENTINEL',
  ),
  _Row(
    'datePadding',
    'insets the timestamp inside its chip; unset, there is none',
    set: () => const _Props(datePadding: EdgeInsets.fromLTRB(9, 5, 3, 1)),
    probe: (t) => _inset(t, find.byType(CometChatDate), _dateText()),
    before: Offset.zero,
    expected: const Offset(9, 5),
  ),
  _Row(
    'dateHeight',
    'sets the laid-out height of the date chip',
    set: () => const _Props(dateHeight: 33),
    probe: (t) => t.getSize(find.byType(CometChatDate)).height,
    expected: 33.0,
  ),
  _Row(
    'dateWidth',
    'sets the laid-out width of the date chip',
    set: () => const _Props(dateWidth: 59),
    probe: (t) => t.getSize(find.byType(CometChatDate)).width,
    expected: 59.0,
  ),
  _Row(
    'dateBackgroundIsTransparent',
    'true clears the date background',
    unflipped: () => const _Props(
      datesStyle: CometChatDateStyle(backgroundColor: _kDateBackground),
    ),
    set: () => const _Props(
      datesStyle: CometChatDateStyle(backgroundColor: _kDateBackground),
      dateBackgroundIsTransparent: true,
    ),
    probe: (t) => _box(t, CometChatDate).color,
    before: _kDateBackground,
    expected: _kDateBackground.withValues(alpha: 0),
  ),
  _Row(
    'dateBackgroundIsTransparent',
    'explicit false keeps the background true cleared',
    unflipped: () => const _Props(
      datesStyle: CometChatDateStyle(backgroundColor: _kDateBackground),
      dateBackgroundIsTransparent: true,
    ),
    set: () => const _Props(
      datesStyle: CometChatDateStyle(backgroundColor: _kDateBackground),
      dateBackgroundIsTransparent: false,
    ),
    probe: (t) => _box(t, CometChatDate).color,
    before: _kDateBackground.withValues(alpha: 0),
    expected: _kDateBackground,
  ),

  // ── Badge props ───────────────────────────────────────────────────────────
  _Row(
    'badgeWidth',
    'sets the laid-out width of the badge',
    set: () => const _Props(badgeWidth: 43),
    probe: (t) => t.getSize(find.byType(CometChatBadge)).width,
    before: 16.0,
    expected: 43.0,
  ),
  _Row(
    'badgeHeight',
    'sets the laid-out height of the badge; unset, it is 20',
    set: () => const _Props(badgeHeight: 29),
    probe: (t) => t.getSize(find.byType(CometChatBadge)).height,
    before: 20.0,
    expected: 29.0,
  ),
  _Row(
    'badgePadding',
    'insets the count inside the badge',
    set: () => const _Props(badgePadding: EdgeInsets.only(left: 5, top: 3)),
    probe: (t) => _inset(
      t,
      find.byType(CometChatBadge),
      find.descendant(
        of: find.byType(CometChatBadge),
        matching: find.byType(FittedBox),
      ),
    ),
    expected: const Offset(5, 3),
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

Widget _wrap(
  Widget child, {
  Key? key,
  List<ThemeExtension<dynamic>> extensions = const [],
}) => MaterialApp(
  key: key,
  theme: ThemeData(extensions: extensions),
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: Align(alignment: Alignment.topRight, child: child),
  ),
);

void main() {
  group('ConversationsTrailingView prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
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
                extensions: row.themeExtensions,
                p == null
                    // Unset: required tokens at baseline, every optional
                    // prop omitted.
                    ? ConversationsTrailingView(
                        conversation: conversation,
                        style: _style,
                        datesStyle: _datesStyle,
                        colorPalette: _palette,
                        spacing: _spacing,
                        typography: _typography,
                      )
                    : ConversationsTrailingView(
                        conversation: p.conversation ?? conversation,
                        style: p.style ?? _style,
                        datesStyle: p.datesStyle ?? _datesStyle,
                        colorPalette: p.colorPalette ?? _palette,
                        spacing: p.spacing ?? _spacing,
                        typography: p.typography ?? _typography,
                        datePattern: p.datePattern,
                        datePadding: p.datePadding,
                        dateHeight: p.dateHeight,
                        dateWidth: p.dateWidth,
                        dateBackgroundIsTransparent:
                            p.dateBackgroundIsTransparent,
                        badgeWidth: p.badgeWidth,
                        badgeHeight: p.badgeHeight,
                        badgePadding: p.badgePadding,
                        dateTimeFormatterCallback: p.dateTimeFormatterCallback,
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
