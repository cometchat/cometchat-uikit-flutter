/// Render-verified prop matrix for [CometChatConversationListItemStyle] —
/// Track 3 PROP1 (ENG-38688, coverage part 2).
///
/// A style class has no pixels of its own, so every row is verified through
/// the widget that paints it: a [CometChatConversationListItem] given the
/// style through `style:`. None of the item's per-prop overrides (avatarStyle,
/// dateStyle, badgeStyle, ...) is passed, so a sentinel that reaches the
/// screen can only have come from the style. The item is given an explicit
/// palette, spacing and typography, so the fallbacks the unset side lands on
/// are known values, not whatever the theme happens to hold.
///
/// How the matrix works. [_matrix] is a table. Each row names the style prop
/// it verifies, the sentinel it sets (a value no theme uses), any other style
/// fields held constant on both sides, the item state to render in, a probe
/// that reads the rendered child the prop controls, and what that probe must
/// return on each side. Every row is pumped twice in one test body: first
/// with the prop left out of the style, then with it set. The unset reading
/// must match the fallback, the set reading must match the sentinel, and the
/// two must differ, so a row fails if the item stopped reading the prop.
///
/// The unset side is built by [_omitting], which passes only the row's base
/// fields, so the prop really is absent and takes its constructor default.
/// Passing it as an explicit null instead would bypass a default, and a
/// default added to the style constructor would then go unnoticed.
///
/// Three reads in the item cannot be caught on their own because another
/// read always covers them, not because a row is weak: subtitleTextColor at
/// 630 (638 re-applies it last) and dateStyle.textColor at 814 and 819
/// (CometChatDate applies textColor as both base colour and final copyWith,
/// so either read alone paints the sentinel). Deleting both 814 and 819 fails
/// the dateStyle row.
///
/// 17 of the 19 props this matrix covers have a row. checkBoxSelectIconTint
/// and receiptStyle had no effect until ENG-38688 wired them;
/// conversations_family_fixes_test.dart covers them, along with the two
/// group-dot backgrounds the same change added and the nested-style fields
/// the item used to overwrite.
///
///   flutter test test/chat_ui/conversations/widget/conversation_list_item_style_props_test.dart
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

class _FakeTextMessage extends Mock implements TextMessage {
  _FakeTextMessage({required User from}) : _from = from;

  final User _from;

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

/// An image message, so the subtitle leads with the message-type icon.
class _FakeImageMessage extends Mock implements MediaMessage {
  _FakeImageMessage({required User from}) : _from = from;

  final User _from;

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
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation({
    required this.conversationWith,
    this.unreadMessageCount = 0,
    BaseMessage? lastMessage,
  }) : _lastMessage = lastMessage;

  @override
  String get conversationId => 'user_u1';

  @override
  final AppEntity conversationWith;

  @override
  final int unreadMessageCount;

  final BaseMessage? _lastMessage;

  @override
  BaseMessage? get lastMessage => _lastMessage;

  @override
  String get conversationType => 'user';

  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _bob = _FakeUser('u2', 'Bob', status: 'offline');

/// Alice: online (so the presence dot shows), 3 unread (so the badge shows),
/// and a text message from Bob (so the timestamp shows).
Conversation _alice() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  unreadMessageCount: 3,
  lastMessage: _FakeTextMessage(from: _bob),
);

/// Alice with no messages, so the subtitle is the plain "tap to start" Text.
Conversation _aliceNoMessages() =>
    _FakeConversation(conversationWith: _FakeUser('u1', 'Alice'));

/// Alice whose last message is an image, so the subtitle shows a photo icon.
Conversation _aliceImage() => _FakeConversation(
  conversationWith: _FakeUser('u1', 'Alice'),
  lastMessage: _FakeImageMessage(from: _bob),
);

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
  heading4: CometChatTextStyleHeading4(
    medium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  ),
  body: CometChatTextStyleBody(regular: TextStyle(fontSize: 14)),
  caption1: CometChatTextStyleCaption1(regular: TextStyle(fontSize: 12)),
);

// Sentinels: values no theme produces, so a match can only come from the
// style. Every hex below is absent from lib/.
const _kBackground = Color(0xFF1A2B3C);
const _kSelected = Color(0xFF2B3C4D);
const _kTitle = Color(0xFF3C4D5E);
const _kSubtitle = Color(0xFF4D5E6F);
const _kSubtitleStyleColor = Color(0xFF5E6F70);
const _kIconTint = Color(0xFF6F7081);
const _kStroke = Color(0xFF708192);
const _kBoxBackground = Color(0xFF8192A3);
const _kChecked = Color(0xFF92A3B4);
const _kAvatar = Color(0xFFA3B4C5);
const _kStatusBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFFB4C5D6), width: 2.5),
);
const _kDate = Color(0xFFC5D6E7);
const _kBadge = Color(0xFFD6E7F8);

// ─── Probes ──────────────────────────────────────────────────────────────────

BuildContext _ctx(WidgetTester t) =>
    t.element(find.byType(CometChatConversationListItem));

Translations _tr(WidgetTester t) => Translations.of(_ctx(t));

/// The theme's own palette and spacing: what children that are not handed the
/// item's palette fall back to.
CometChatColorPalette _themePalette(WidgetTester t) =>
    CometChatThemeHelper.getColorPalette(_ctx(t));

CometChatSpacing _themeSpacing(WidgetTester t) =>
    CometChatThemeHelper.getSpacing(_ctx(t));

TextStyle? _textStyle(WidgetTester t, String data) =>
    t.widget<Text>(find.text(data)).style;

/// The first Container a widget of [type] builds: the item's row box, the
/// avatar box, the presence dot, the timestamp box, the badge.
Container _box(WidgetTester t, Type type) => t.widget<Container>(
  find
      .descendant(of: find.byType(type).first, matching: find.byType(Container))
      .first,
);

BoxDecoration _decoration(WidgetTester t, Type type) =>
    _box(t, type).decoration! as BoxDecoration;

TextStyle? _dateTextStyle(WidgetTester t) => t
    .widget<Text>(
      find.descendant(
        of: find.byType(CometChatDate),
        matching: find.byType(Text),
      ),
    )
    .style;

Checkbox _checkbox(WidgetTester t) => t.widget<Checkbox>(find.byType(Checkbox));

/// A style constructed with [fields] as its only arguments. Every other prop
/// is left out of the call, not passed as null, so it takes whatever default
/// the constructor declares. This is the unset side of every row.
CometChatConversationListItemStyle _omitting(Map<String, Object?> fields) =>
    Function.apply(CometChatConversationListItemStyle.new, const [], {
          for (final e in fields.entries) Symbol(e.key): e.value,
        })
        as CometChatConversationListItemStyle;

Widget _wrap(Widget child, {Key? key}) => MaterialApp(
  key: key,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every prop on [CometChatConversationListItemStyle]. The guard test holds
/// each to a row or to [_elsewhere].
const _allProps = {
  'backgroundColor',
  'selectedBackgroundColor',
  'titleTextColor',
  'titleTextStyle',
  'subtitleTextColor',
  'subtitleTextStyle',
  'messageTypeIconTint',
  'checkBoxStrokeWidth',
  'checkBoxBorderRadius',
  'checkBoxStrokeColor',
  'checkBoxBackgroundColor',
  'checkBoxCheckedBackgroundColor',
  'checkBoxSelectIconTint',
  'avatarStyle',
  'statusIndicatorStyle',
  'dateStyle',
  'badgeStyle',
  'receiptStyle',
  'typingIndicatorStyle',
};

/// Props this matrix leaves to conversations_family_fixes_test.dart (see the
/// library comment).
const _elsewhere = {'checkBoxSelectIconTint', 'receiptStyle'};

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.value,
    required this.probe,
    required this.unset,
    required this.expected,
    this.base = const {},
    this.conversation = _alice,
    this.isSelected = false,
    this.selectionMode = SelectionMode.none,
    this.typing = false,
  });

  /// The style prop this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// The sentinel the set side gives [prop].
  final Object value;

  /// Other style fields, set identically on both sides.
  final Map<String, Object?> base;

  /// Reads the rendered element the prop controls.
  final Object? Function(WidgetTester t) probe;

  /// What [probe] must return with [prop] left out of the style.
  final Object? Function(WidgetTester t) unset;

  /// What [probe] must return with [prop] set to [value].
  final Object? expected;

  final Conversation Function() conversation;
  final bool isSelected;
  final SelectionMode selectionMode;

  /// Seeds one person typing, so the subtitle is the typing line.
  final bool typing;
}

final _matrix = <_Row>[
  // ── Row box ───────────────────────────────────────────────────────────────
  _Row(
    'backgroundColor',
    'paints the row box of an unselected item',
    value: _kBackground,
    probe: (t) => _box(t, CometChatConversationListItem).color,
    unset: (t) => _palette.background1,
    expected: _kBackground,
  ),
  _Row(
    'selectedBackgroundColor',
    'paints the row box of a selected item',
    isSelected: true,
    value: _kSelected,
    probe: (t) => _box(t, CometChatConversationListItem).color,
    unset: (t) => _palette.background4,
    expected: _kSelected,
  ),

  // ── Title ─────────────────────────────────────────────────────────────────
  _Row(
    'titleTextColor',
    'colours the conversation name',
    value: _kTitle,
    probe: (t) => _textStyle(t, 'Alice')?.color,
    unset: (t) => _palette.textPrimary,
    expected: _kTitle,
  ),
  _Row(
    'titleTextStyle',
    'sizes and spaces the conversation name',
    value: const TextStyle(fontSize: 21.5, letterSpacing: 1.25),
    probe: (t) {
      final s = _textStyle(t, 'Alice');
      return [s?.fontSize, s?.letterSpacing];
    },
    unset: (t) => [16.0, null],
    expected: [21.5, 1.25],
  ),

  // ── Subtitle ──────────────────────────────────────────────────────────────
  _Row(
    'subtitleTextColor',
    'colours the last-message preview',
    conversation: _aliceNoMessages,
    value: _kSubtitle,
    probe: (t) => _textStyle(t, _tr(t).tapToStartConversation)?.color,
    unset: (t) => _palette.textSecondary,
    expected: _kSubtitle,
  ),
  _Row(
    'subtitleTextColor',
    'wins over the colour inside subtitleTextStyle',
    conversation: _aliceNoMessages,
    base: const {'subtitleTextStyle': TextStyle(color: _kSubtitleStyleColor)},
    value: _kSubtitle,
    probe: (t) => _textStyle(t, _tr(t).tapToStartConversation)?.color,
    unset: (t) => _kSubtitleStyleColor,
    expected: _kSubtitle,
  ),
  _Row(
    'subtitleTextStyle',
    'styles the last-message preview',
    conversation: _aliceNoMessages,
    value: const TextStyle(
      color: _kSubtitleStyleColor,
      fontSize: 17.5,
      letterSpacing: 0.75,
    ),
    probe: (t) {
      final s = _textStyle(t, _tr(t).tapToStartConversation);
      return [s?.color, s?.fontSize, s?.letterSpacing];
    },
    unset: (t) => [_palette.textSecondary, 14.0, 0.0],
    expected: [_kSubtitleStyleColor, 17.5, 0.75],
  ),
  _Row(
    'messageTypeIconTint',
    'tints the photo icon in front of an image preview',
    conversation: _aliceImage,
    value: _kIconTint,
    probe: (t) => t.widget<Icon>(find.byIcon(Icons.photo)).color,
    unset: (t) => _palette.iconSecondary,
    expected: _kIconTint,
  ),

  // ── Selection checkbox ────────────────────────────────────────────────────
  _Row(
    'checkBoxStrokeWidth',
    'sets the unchecked checkbox border width',
    selectionMode: SelectionMode.multiple,
    value: 2.75,
    probe: (t) => _checkbox(t).side?.width,
    unset: (t) => 1.5,
    expected: 2.75,
  ),
  _Row(
    'checkBoxBorderRadius',
    'rounds the checkbox',
    selectionMode: SelectionMode.multiple,
    value: const BorderRadius.all(Radius.circular(7)),
    probe: (t) => (_checkbox(t).shape! as RoundedRectangleBorder).borderRadius,
    unset: (t) => BorderRadius.circular(_spacing.radius1!),
    expected: const BorderRadius.all(Radius.circular(7)),
  ),
  _Row(
    'checkBoxStrokeColor',
    'colours the unchecked checkbox border',
    selectionMode: SelectionMode.multiple,
    value: _kStroke,
    probe: (t) => _checkbox(t).side?.color,
    unset: (t) => _palette.borderDefault,
    expected: _kStroke,
  ),
  _Row(
    'checkBoxBackgroundColor',
    'fills the unchecked checkbox',
    selectionMode: SelectionMode.multiple,
    value: _kBoxBackground,
    probe: (t) {
      final cb = _checkbox(t);
      // The checkbox is unchecked, so it resolves its fill with no states.
      expect(cb.value, isFalse);
      return cb.fillColor!.resolve(const <WidgetState>{});
    },
    unset: (t) => Colors.transparent,
    expected: _kBoxBackground,
  ),
  _Row(
    'checkBoxCheckedBackgroundColor',
    'fills the checked checkbox',
    selectionMode: SelectionMode.multiple,
    isSelected: true,
    value: _kChecked,
    probe: (t) {
      final cb = _checkbox(t);
      expect(cb.value, isTrue);
      return cb.fillColor!.resolve(const {WidgetState.selected});
    },
    unset: (t) => _palette.primary,
    expected: _kChecked,
  ),

  // ── Nested styles ─────────────────────────────────────────────────────────
  _Row(
    'avatarStyle',
    'reaches the avatar box',
    value: const CometChatAvatarStyle(backgroundColor: _kAvatar),
    probe: (t) => _decoration(t, CometChatAvatar).color,
    unset: (t) => _themePalette(t).extendedPrimary500,
    expected: _kAvatar,
  ),
  _Row(
    'statusIndicatorStyle',
    'borders the presence dot',
    value: const CometChatStatusIndicatorStyle(border: _kStatusBorder),
    probe: (t) => _decoration(t, CometChatStatusIndicator).border,
    unset: (t) =>
        Border.all(width: _spacing.spacing ?? 0, color: _palette.background1!),
    expected: _kStatusBorder,
  ),
  _Row(
    'statusIndicatorStyle',
    'rounds the presence dot',
    value: const CometChatStatusIndicatorStyle(
      borderRadius: BorderRadius.all(Radius.circular(3)),
    ),
    probe: (t) => _decoration(t, CometChatStatusIndicator).borderRadius,
    unset: (t) => BorderRadius.circular(_themeSpacing(t).radiusMax ?? 0),
    expected: const BorderRadius.all(Radius.circular(3)),
  ),
  _Row(
    'dateStyle',
    'colours the timestamp',
    value: const CometChatDateStyle(textColor: _kDate),
    probe: (t) => _dateTextStyle(t)?.color,
    unset: (t) => _palette.textSecondary,
    expected: _kDate,
  ),
  _Row(
    'dateStyle',
    'sizes and spaces the timestamp text',
    value: const CometChatDateStyle(
      textStyle: TextStyle(fontSize: 13.5, letterSpacing: 0.5),
    ),
    probe: (t) {
      final s = _dateTextStyle(t);
      return [s?.fontSize, s?.letterSpacing];
    },
    unset: (t) => [12.0, null],
    expected: [13.5, 0.5],
  ),
  _Row(
    'dateStyle',
    'rounds the timestamp box',
    value: const CometChatDateStyle(
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ),
    probe: (t) => _decoration(t, CometChatDate).borderRadius,
    unset: (t) =>
        BorderRadius.all(Radius.circular(_themeSpacing(t).radius1 ?? 0)),
    expected: const BorderRadius.all(Radius.circular(5)),
  ),
  _Row(
    'badgeStyle',
    'fills the unread badge',
    value: const CometChatBadgeStyle(backgroundColor: _kBadge),
    probe: (t) => _decoration(t, CometChatBadge).color,
    unset: (t) => _themePalette(t).primary,
    expected: _kBadge,
  ),
  _Row(
    'typingIndicatorStyle',
    'sizes and spaces the typing line',
    typing: true,
    value: const CometChatTypingIndicatorStyle(
      textStyle: TextStyle(fontSize: 19.5, letterSpacing: 1.5),
    ),
    probe: (t) {
      final s = _textStyle(t, _tr(t).isTyping);
      return [s?.fontSize, s?.letterSpacing];
    },
    unset: (t) => [14.0, null],
    expected: [19.5, 1.5],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatConversationListItemStyle prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        final readings = <Object?>[];

        for (final side in const ['unset', 'set']) {
          // The set side passes the sentinel. The unset side is built by
          // _omitting from the base fields alone, so the prop is not in the
          // call at all.
          final v = <String, Object?>{...row.base, row.prop: row.value};

          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _wrap(
                CometChatConversationListItem(
                  conversation: row.conversation(),
                  onItemClick: (_) {},
                  isSelected: row.isSelected,
                  selectionMode: row.selectionMode,
                  typingIndicators: [
                    if (row.typing)
                      TypingIndicator(
                        sender: _bob,
                        receiverId: 'u1',
                        receiverType: 'user',
                      ),
                  ],
                  colorPalette: _palette,
                  spacing: _spacing,
                  typography: _typography,
                  style: side == 'unset'
                      ? _omitting(row.base)
                      : CometChatConversationListItemStyle(
                          backgroundColor: v['backgroundColor'] as Color?,
                          selectedBackgroundColor:
                              v['selectedBackgroundColor'] as Color?,
                          titleTextColor: v['titleTextColor'] as Color?,
                          titleTextStyle: v['titleTextStyle'] as TextStyle?,
                          subtitleTextColor: v['subtitleTextColor'] as Color?,
                          subtitleTextStyle:
                              v['subtitleTextStyle'] as TextStyle?,
                          messageTypeIconTint:
                              v['messageTypeIconTint'] as Color?,
                          checkBoxStrokeWidth:
                              v['checkBoxStrokeWidth'] as double?,
                          checkBoxBorderRadius:
                              v['checkBoxBorderRadius'] as BorderRadius?,
                          checkBoxStrokeColor:
                              v['checkBoxStrokeColor'] as Color?,
                          checkBoxBackgroundColor:
                              v['checkBoxBackgroundColor'] as Color?,
                          checkBoxCheckedBackgroundColor:
                              v['checkBoxCheckedBackgroundColor'] as Color?,
                          avatarStyle:
                              v['avatarStyle'] as CometChatAvatarStyle?,
                          statusIndicatorStyle:
                              v['statusIndicatorStyle']
                                  as CometChatStatusIndicatorStyle?,
                          dateStyle: v['dateStyle'] as CometChatDateStyle?,
                          badgeStyle: v['badgeStyle'] as CometChatBadgeStyle?,
                          // checkBoxSelectIconTint and receiptStyle are
                          // covered in conversations_family_fixes_test.dart
                          // (see the library comment).
                          typingIndicatorStyle:
                              v['typingIndicatorStyle']
                                  as CometChatTypingIndicatorStyle?,
                        ),
                ),
                // A fresh app per side, so no element state carries over.
                key: ValueKey(side),
              ),
            ),
          );
          await tester.pump();

          final reading = row.probe(tester);
          expect(
            reading,
            side == 'set' ? row.expected : row.unset(tester),
            reason: '${row.prop}, $side side',
          );
          readings.add(reading);
        }

        expect(
          readings.last,
          isNot(equals(readings.first)),
          reason: '${row.prop} must render differently once set',
        );
      });
    }
  });

  test('every readable prop has a row, and no row sets its prop on the '
      'unset side', () {
    expect({
      for (final row in _matrix) row.prop,
    }, _allProps.difference(_elsewhere));
    for (final row in _matrix) {
      expect(row.base.containsKey(row.prop), isFalse, reason: row.claim);
    }
  });
}
