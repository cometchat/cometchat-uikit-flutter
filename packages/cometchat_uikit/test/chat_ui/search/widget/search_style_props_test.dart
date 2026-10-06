/// Render-verified style matrix for [CometChatSearchStyle] — Track 3 PROP1,
/// coverage part 2 (ENG-38688).
///
/// CometChatSearch creates its own SearchBloc in initState and exposes no
/// injection seam, so this matrix drives the real one. It types into the real
/// search field, then delivers results through the bloc's own result events —
/// ConversationsResultReceived, MessagesResultReceived and the two error
/// events — which are exactly what the SDK fetch path adds when a request
/// settles. That reaches every surface the style paints without the SDK ever
/// returning data: the bar and chips, the pending search with its clear icon,
/// populated conversation and message sections, and the empty and error
/// states. The 500 ms debounce the typing starts is never allowed to elapse,
/// and dispose cancels it when the tree is torn down.
///
/// Tapping a chip is the one step that does reach the SDK: SearchFilterToggled
/// searches at once, with no debounce. With CometChat never initialised, the
/// SDK fails the request inside its own try block and reports it through
/// onError. It logs "SDK not initialized", and the bloc settles on a messages
/// error. The pub.dev 5.0.7 SDK and the local override both behave this way,
/// and the chip rows assert only on the chips, so that line is expected log
/// noise, not a failure.
///
/// Each row of [_cases] names one prop, the stage that shows it, and a probe
/// reading the painted value that prop controls. The style pumped for a row
/// carries that prop and nothing else ([_StyleCase.on]), and every sentinel is
/// a value no theme uses, so a probe can only see it if CometChatSearch routed
/// that prop to that element.
///
/// 46 of the 49 props are covered. The other three are read nowhere under
/// lib/chat_ui/src/search/ — errorStateSubTitleTextColor and
/// errorStateSubTitleTextStyle (the error view has no subtitle) and
/// receiptStyle (no receipts are rendered) — so there is nothing on screen to
/// assert. They are reported as defects rather than pinned here.
///
///   flutter test test/chat_ui/search/widget/search_style_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────
// Colours and sizes no theme uses. Text-style sentinels carry only a size, so
// a style prop can never mask the colour prop beside it.

const _background = Color(0xFF0D1E2F);
const _barFill = Color(0xFF1E2F30);
const _barText = Color(0xFF2F3041);
const _barTextStyle = TextStyle(fontSize: 23.25);
const _placeholder = Color(0xFF304152);
const _placeholderStyle = TextStyle(fontSize: 22.75);
const _barBorder = BorderSide(color: Color(0xFF415263), width: 2.25);
const _barRadius = BorderRadius.all(Radius.circular(9.5));
const _backIcon = Color(0xFF526374);
const _clearIcon = Color(0xFF637485);

const _chipFill = Color(0xFF748596);
const _chipSelectedFill = Color(0xFF8596A7);
const _chipText = Color(0xFF96A7B8);
const _chipSelectedText = Color(0xFFA7B8C9);
const _chipTextStyle = TextStyle(fontSize: 21.25);
const _chipSelectedTextStyle = TextStyle(fontSize: 20.75);
const _chipBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFFB8C9DA), width: 2.75),
);
const _chipSelectedBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFFC9DAEB), width: 3.25),
);
const _chipRadius = BorderRadius.all(Radius.circular(4.5));
const _chipIcon = Color(0xFFDAEBFC);
const _chipSelectedIcon = Color(0xFFEBFC0D);

const _header = Color(0xFFFC0D1E);
const _headerStyle = TextStyle(fontSize: 19.25);

const _convTitle = Color(0xFF0E1F2A);
const _convTitleStyle = TextStyle(fontSize: 18.75);
const _convSubtitle = Color(0xFF1F2A3B);
const _convSubtitleStyle = TextStyle(fontSize: 17.25);
const _convFill = Color(0xFF2A3B4C);

const _sender = Color(0xFF3B4C5D);
const _senderStyle = TextStyle(fontSize: 16.75);
const _preview = Color(0xFF4C5D6E);
const _previewStyle = TextStyle(fontSize: 15.25);
const _date = Color(0xFF5D6E7F);
const _dateTextStyle = TextStyle(fontSize: 14.75);

const _emptyTitle = Color(0xFF6E7F80);
const _emptyTitleStyle = TextStyle(fontSize: 13.25);
const _emptySubtitle = Color(0xFF7F8091);
const _emptySubtitleStyle = TextStyle(fontSize: 12.75);
const _errorTitle = Color(0xFF8091A2);
const _errorTitleStyle = TextStyle(fontSize: 11.25);

const _seeMore = Color(0xFF91A2B3);
const _seeMoreStyle = TextStyle(fontSize: 10.75);

const _avatarFill = Color(0xFFA2B3C4);
const _avatarStyle = CometChatAvatarStyle(backgroundColor: _avatarFill);
const _badgeFill = Color(0xFFB3C4D5);
const _badgeStyle = CometChatBadgeStyle(backgroundColor: _badgeFill);

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _query = 'zq';

User _user(String uid, String name) => User(uid: uid, name: name);

TextMessage _textMessage({
  required int id,
  required User sender,
  required String text,
  required DateTime sentAt,
}) => TextMessage(
  id: id,
  text: text,
  sender: sender,
  receiverUid: 'me',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: sentAt,
);

/// Three rows with more to come, so "More" renders under the section. Alice
/// carries the last message (subtitle and tail date) and the only unread
/// count (badge).
List<Conversation> _conversations() => [
  Conversation(
    conversationId: 'user_u1',
    conversationType: 'user',
    conversationWith: _user('u1', 'Alice'),
    lastMessage: _textMessage(
      id: 1,
      sender: _user('u1', 'Alice'),
      text: 'lunch plans',
      sentAt: DateTime(2022, 6, 10, 9, 30),
    ),
    unreadMessageCount: 4,
  ),
  Conversation(
    conversationId: 'user_u2',
    conversationType: 'user',
    conversationWith: _user('u2', 'Bob'),
  ),
  Conversation(
    conversationId: 'user_u3',
    conversationType: 'user',
    conversationWith: _user('u3', 'Carla'),
  ),
];

/// Three message hits from three senders, so each row title is unique.
List<BaseMessage> _messages() => [
  _textMessage(
    id: 11,
    sender: _user('u7', 'Zed'),
    text: 'msg one',
    sentAt: DateTime(2023, 1, 15, 8),
  ),
  _textMessage(
    id: 12,
    sender: _user('u8', 'Yara'),
    text: 'msg two',
    sentAt: DateTime(2023, 1, 14, 8),
  ),
  _textMessage(
    id: 13,
    sender: _user('u9', 'Xavi'),
    text: 'msg three',
    sentAt: DateTime(2023, 1, 13, 8),
  ),
];

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

// ─── Stages ──────────────────────────────────────────────────────────────────

enum _Stage {
  /// Just mounted: the bar and the seven unselected chips.
  initial,

  /// The Photos chip tapped, so it renders selected. This fires the one SDK
  /// call in the matrix, which fails fast (see the library comment).
  chipSelected,

  /// Text typed and nothing back yet: loading, with the clear icon showing.
  typed,

  /// Three conversations and three messages back, with more of each.
  results,

  /// Both lists back empty.
  empty,

  /// Both lists failed.
  error,
}

Future<void> _drive(WidgetTester tester, _Stage stage) async {
  await tester.pump();
  if (stage == _Stage.initial) return;

  if (stage == _Stage.chipSelected) {
    await tester.tap(find.text('Photos'));
    await tester.pump();
    await tester.pump();
    return;
  }

  await tester.enterText(find.byType(TextField), _query);
  await tester.pump();

  final bloc = BlocProvider.of<SearchBloc>(
    tester.element(find.byType(TextField)),
  );
  switch (stage) {
    case _Stage.results:
      bloc
        ..add(
          ConversationsResultReceived(
            conversations: _conversations(),
            hasMore: true,
          ),
        )
        ..add(MessagesResultReceived(messages: _messages(), hasMore: true));
    case _Stage.empty:
      bloc
        ..add(
          const ConversationsResultReceived(conversations: [], hasMore: false),
        )
        ..add(const MessagesResultReceived(messages: [], hasMore: false));
    case _Stage.error:
      bloc
        ..add(const ConversationsErrorReceived('conversations unavailable'))
        ..add(const MessagesErrorReceived('messages unavailable'));
    case _Stage.initial:
    case _Stage.chipSelected:
    case _Stage.typed:
      break;
  }
  await tester.pump();
  await tester.pump();
}

// ─── Probes ──────────────────────────────────────────────────────────────────

TextStyle? _styleOfText(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

/// Styles of every Text showing [text], for a label that repeats per section.
Set<TextStyle?> _stylesOfText(WidgetTester tester, String text) =>
    tester.widgetList<Text>(find.text(text)).map((t) => t.style).toSet();

InputDecoration _fieldDecoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

OutlineInputBorder _fieldBorder(WidgetTester tester) =>
    _fieldDecoration(tester).enabledBorder! as OutlineInputBorder;

/// The style the field's EditableText actually lays typed text out with.
TextStyle _typedStyle(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).style;

Finder _chip(String label) => find.widgetWithText(SearchFilterChip, label);

BoxDecoration _chipDecoration(WidgetTester tester, String label) =>
    tester
            .widget<Container>(
              find.descendant(
                of: _chip(label),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

Color? _chipIconColor(WidgetTester tester, String label) => tester
    .widget<Icon>(
      find.descendant(of: _chip(label), matching: find.byType(Icon)),
    )
    .color;

/// The style of the span carrying [text] in the RichText the message preview
/// renders it with (text results go through the rich-text formatters).
TextStyle? _spanStyle(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == text,
    ),
  );
  TextStyle? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      found = span.style;
      return false;
    }
    return true;
  });
  return found;
}

/// Fill of every avatar drawn in the conversation rows.
Set<Color?> _avatarFills(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(
        of: find.byType(CometChatAvatar),
        matching: find.byType(Container),
      ),
    )
    .map((c) => (c.decoration as BoxDecoration?)?.color)
    .toSet();

Color? _badgeColor(WidgetTester tester) =>
    (tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(CometChatBadge),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration)
        .color;

// ─── Matrix ──────────────────────────────────────────────────────────────────

final _dateStyleSentinel = CometChatDateStyle(
  borderRadius: const BorderRadius.all(Radius.circular(7)),
);
const _statusBorderSentinel = Border.fromBorderSide(
  BorderSide(color: Color(0xFFF1E2D3), width: 2),
);

class _StyleCase {
  const _StyleCase(
    this.prop,
    this.target,
    this.stage, {
    required this.probe,
    required this.expected,
  });

  /// The CometChatSearchStyle prop this row covers.
  final String prop;

  /// The element the prop paints, as the test name reads.
  final String target;

  /// Where CometChatSearch has to be driven for [target] to exist.
  final _Stage stage;

  /// Reads back the rendered value the prop controls.
  final Object? Function(WidgetTester tester) probe;

  final Object? expected;

  /// [sentinel] when this row covers [name], otherwise null — so the style a
  /// row pumps carries exactly the prop under test.
  T? on<T>(String name, T sentinel) => name == prop ? sentinel : null;
}

final _cases = <_StyleCase>[
  _StyleCase(
    'dateStyle',
    'the result timestamps',
    _Stage.results,
    probe: (t) => t
        .widget<CometChatDate>(find.byType(CometChatDate).first)
        .style
        .borderRadius,
    expected: const BorderRadius.all(Radius.circular(7)),
  ),
  _StyleCase(
    'statusIndicatorStyle',
    'the conversation status dot',
    _Stage.results,
    probe: (t) => t
        .widget<CometChatListItem>(find.byType(CometChatListItem).first)
        .statusIndicatorStyle
        .border,
    expected: _statusBorderSentinel,
  ),
  // ── Search bar ──
  _StyleCase(
    'backgroundColor',
    'the search scaffold',
    _Stage.initial,
    probe: (t) => t
        .widget<Scaffold>(
          find.descendant(
            of: find.byType(CometChatSearch),
            matching: find.byType(Scaffold),
          ),
        )
        .backgroundColor,
    expected: _background,
  ),
  _StyleCase(
    'searchBackgroundColor',
    'the search field fill',
    _Stage.initial,
    probe: (t) => _fieldDecoration(t).fillColor,
    expected: _barFill,
  ),
  _StyleCase(
    'searchTextColor',
    'the typed text',
    _Stage.initial,
    probe: (t) => _typedStyle(t).color,
    expected: _barText,
  ),
  _StyleCase(
    'searchTextStyle',
    'the typed text',
    _Stage.initial,
    probe: (t) => _typedStyle(t).fontSize,
    expected: _barTextStyle.fontSize,
  ),
  _StyleCase(
    'searchPlaceHolderTextColor',
    'the placeholder',
    _Stage.initial,
    probe: (t) => _styleOfText(t, 'Search')?.color,
    expected: _placeholder,
  ),
  _StyleCase(
    'searchPlaceHolderTextStyle',
    'the placeholder',
    _Stage.initial,
    probe: (t) => _styleOfText(t, 'Search')?.fontSize,
    expected: _placeholderStyle.fontSize,
  ),
  _StyleCase(
    'searchBorder',
    'the field outline',
    _Stage.initial,
    probe: (t) => _fieldBorder(t).borderSide,
    expected: _barBorder,
  ),
  _StyleCase(
    'searchBorderRadius',
    'the field outline corners',
    _Stage.initial,
    probe: (t) => _fieldBorder(t).borderRadius,
    expected: _barRadius,
  ),
  _StyleCase(
    'searchBackIconColor',
    'the back arrow',
    _Stage.initial,
    probe: (t) => t.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
    expected: _backIcon,
  ),
  _StyleCase(
    'searchClearIconColor',
    'the clear icon once text is typed',
    _Stage.typed,
    probe: (t) => t.widget<Icon>(find.byIcon(Icons.close)).color,
    expected: _clearIcon,
  ),

  // ── Filter chips ──
  _StyleCase(
    'searchFilterChipBackgroundColor',
    'an unselected chip fill',
    _Stage.initial,
    probe: (t) => _chipDecoration(t, 'Photos').color,
    expected: _chipFill,
  ),
  _StyleCase(
    'searchFilterChipTextColor',
    'an unselected chip label',
    _Stage.initial,
    probe: (t) => _styleOfText(t, 'Photos')?.color,
    expected: _chipText,
  ),
  _StyleCase(
    'searchFilterChipTextStyle',
    'an unselected chip label',
    _Stage.initial,
    probe: (t) => _styleOfText(t, 'Photos')?.fontSize,
    expected: _chipTextStyle.fontSize,
  ),
  _StyleCase(
    'searchFilterChipBorder',
    'an unselected chip outline',
    _Stage.initial,
    probe: (t) => _chipDecoration(t, 'Photos').border,
    expected: _chipBorder,
  ),
  _StyleCase(
    'searchFilterChipBorderRadius',
    'the chip corners',
    _Stage.initial,
    probe: (t) => _chipDecoration(t, 'Photos').borderRadius,
    expected: _chipRadius,
  ),
  _StyleCase(
    'searchFilterIconColor',
    'an unselected chip glyph',
    _Stage.initial,
    probe: (t) => _chipIconColor(t, 'Photos'),
    expected: _chipIcon,
  ),
  _StyleCase(
    'searchFilterChipSelectedBackgroundColor',
    'the selected chip fill',
    _Stage.chipSelected,
    probe: (t) => _chipDecoration(t, 'Photos').color,
    expected: _chipSelectedFill,
  ),
  _StyleCase(
    'searchFilterChipSelectedTextColor',
    'the selected chip label',
    _Stage.chipSelected,
    probe: (t) => _styleOfText(t, 'Photos')?.color,
    expected: _chipSelectedText,
  ),
  _StyleCase(
    'searchFilterChipSelectedTextStyle',
    'the selected chip label',
    _Stage.chipSelected,
    probe: (t) => _styleOfText(t, 'Photos')?.fontSize,
    expected: _chipSelectedTextStyle.fontSize,
  ),
  _StyleCase(
    'searchFilterChipSelectedBorder',
    'the selected chip outline',
    _Stage.chipSelected,
    probe: (t) => _chipDecoration(t, 'Photos').border,
    expected: _chipSelectedBorder,
  ),
  _StyleCase(
    'searchFilterSelectedIconColor',
    'the selected chip glyph',
    _Stage.chipSelected,
    probe: (t) => _chipIconColor(t, 'Photos'),
    expected: _chipSelectedIcon,
  ),

  // ── Section headers ──
  _StyleCase(
    'sectionHeaderTextColor',
    'the Chats header',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Chats')?.color,
    expected: _header,
  ),
  _StyleCase(
    'sectionHeaderTextColor',
    'the Message header',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Message')?.color,
    expected: _header,
  ),
  _StyleCase(
    'sectionHeaderTextStyle',
    'the Chats header',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Chats')?.fontSize,
    expected: _headerStyle.fontSize,
  ),

  // ── Conversation rows ──
  _StyleCase(
    'searchConversationTitleTextColor',
    'a conversation title',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Alice')?.color,
    expected: _convTitle,
  ),
  _StyleCase(
    'searchConversationTitleTextStyle',
    'a conversation title',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Alice')?.fontSize,
    expected: _convTitleStyle.fontSize,
  ),
  _StyleCase(
    'searchConversationSubtitleTextColor',
    'a conversation last-message subtitle',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'lunch plans')?.color,
    expected: _convSubtitle,
  ),
  _StyleCase(
    'searchConversationSubtitleTextStyle',
    'a conversation last-message subtitle',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'lunch plans')?.fontSize,
    expected: _convSubtitleStyle.fontSize,
  ),
  _StyleCase(
    'searchConversationItemBackgroundColor',
    'a conversation row fill',
    _Stage.results,
    probe: (t) =>
        (t
                    .widget<Container>(
                      find.byKey(const ValueKey<String>('user_u1')),
                    )
                    .decoration!
                as BoxDecoration)
            .color,
    expected: _convFill,
  ),
  _StyleCase(
    'avatarStyle',
    'every conversation avatar',
    _Stage.results,
    probe: _avatarFills,
    expected: {_avatarFill},
  ),
  _StyleCase(
    'badgeStyle',
    'the unread badge',
    _Stage.results,
    probe: _badgeColor,
    expected: _badgeFill,
  ),

  // ── Message rows ──
  _StyleCase(
    'searchMessageSenderTextColor',
    'a message row title',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Zed')?.color,
    expected: _sender,
  ),
  _StyleCase(
    'searchMessageSenderTextStyle',
    'a message row title',
    _Stage.results,
    probe: (t) => _styleOfText(t, 'Zed')?.fontSize,
    expected: _senderStyle.fontSize,
  ),
  _StyleCase(
    'searchMessagePreviewTextColor',
    'a message preview',
    _Stage.results,
    probe: (t) => _spanStyle(t, 'msg one')?.color,
    expected: _preview,
  ),
  _StyleCase(
    'searchMessagePreviewTextStyle',
    'a message preview',
    _Stage.results,
    probe: (t) => _spanStyle(t, 'msg one')?.fontSize,
    expected: _previewStyle.fontSize,
  ),
  _StyleCase(
    'searchMessageDateTextColor',
    'a message row date',
    _Stage.results,
    probe: (t) => _styleOfText(t, '15 Jan, 2023')?.color,
    expected: _date,
  ),
  _StyleCase(
    'searchMessageDateTextColor',
    'the conversation row date',
    _Stage.results,
    probe: (t) => _styleOfText(t, '10 Jun, 2022')?.color,
    expected: _date,
  ),
  _StyleCase(
    'searchMessageDateTextStyle',
    'a message row date',
    _Stage.results,
    probe: (t) => _styleOfText(t, '15 Jan, 2023')?.fontSize,
    expected: _dateTextStyle.fontSize,
  ),

  // ── See more ──
  _StyleCase(
    'seeMoreTextColor',
    'every More link',
    _Stage.results,
    probe: (t) => _stylesOfText(t, 'More').map((s) => s?.color).toSet(),
    expected: {_seeMore},
  ),
  _StyleCase(
    'seeMoreTextStyle',
    'every More link',
    _Stage.results,
    probe: (t) => _stylesOfText(t, 'More').map((s) => s?.fontSize).toSet(),
    expected: {_seeMoreStyle.fontSize},
  ),

  // ── Empty state ──
  _StyleCase(
    'emptyStateTextColor',
    'the empty-state title',
    _Stage.empty,
    probe: (t) => _styleOfText(t, 'No records found')?.color,
    expected: _emptyTitle,
  ),
  _StyleCase(
    'emptyStateTextStyle',
    'the empty-state title',
    _Stage.empty,
    probe: (t) => _styleOfText(t, 'No records found')?.fontSize,
    expected: _emptyTitleStyle.fontSize,
  ),
  _StyleCase(
    'emptyStateSubTitleTextColor',
    'the empty-state subtitle',
    _Stage.empty,
    probe: (t) => _styleOfText(t, 'Search "$_query"')?.color,
    expected: _emptySubtitle,
  ),
  _StyleCase(
    'emptyStateSubTitleTextStyle',
    'the empty-state subtitle',
    _Stage.empty,
    probe: (t) => _styleOfText(t, 'Search "$_query"')?.fontSize,
    expected: _emptySubtitleStyle.fontSize,
  ),

  // ── Error state ──
  _StyleCase(
    'errorStateTextColor',
    'the error-state title',
    _Stage.error,
    probe: (t) => _styleOfText(t, 'Something went wrong')?.color,
    expected: _errorTitle,
  ),
  _StyleCase(
    'errorStateTextStyle',
    'the error-state title',
    _Stage.error,
    probe: (t) => _styleOfText(t, 'Something went wrong')?.fontSize,
    expected: _errorTitleStyle.fontSize,
  ),
];

void main() {
  group('CometChatSearchStyle prop matrix', () {
    for (final c in _cases) {
      testWidgets('${c.prop} paints ${c.target}', (tester) async {
        await mockNetworkImagesFor(
          () => tester.pumpWidget(
            _host(
              CometChatSearch(
                searchStyle: CometChatSearchStyle(
                  dateStyle: c.on('dateStyle', _dateStyleSentinel),
                  statusIndicatorStyle: c.on(
                    'statusIndicatorStyle',
                    const CometChatStatusIndicatorStyle(
                      border: _statusBorderSentinel,
                    ),
                  ),
                  backgroundColor: c.on('backgroundColor', _background),
                  searchBackgroundColor: c.on(
                    'searchBackgroundColor',
                    _barFill,
                  ),
                  searchTextColor: c.on('searchTextColor', _barText),
                  searchTextStyle: c.on('searchTextStyle', _barTextStyle),
                  searchPlaceHolderTextColor: c.on(
                    'searchPlaceHolderTextColor',
                    _placeholder,
                  ),
                  searchPlaceHolderTextStyle: c.on(
                    'searchPlaceHolderTextStyle',
                    _placeholderStyle,
                  ),
                  searchBorder: c.on('searchBorder', _barBorder),
                  searchBorderRadius: c.on('searchBorderRadius', _barRadius),
                  searchBackIconColor: c.on('searchBackIconColor', _backIcon),
                  searchClearIconColor: c.on(
                    'searchClearIconColor',
                    _clearIcon,
                  ),
                  searchFilterChipBackgroundColor: c.on(
                    'searchFilterChipBackgroundColor',
                    _chipFill,
                  ),
                  searchFilterChipSelectedBackgroundColor: c.on(
                    'searchFilterChipSelectedBackgroundColor',
                    _chipSelectedFill,
                  ),
                  searchFilterChipTextColor: c.on(
                    'searchFilterChipTextColor',
                    _chipText,
                  ),
                  searchFilterChipSelectedTextColor: c.on(
                    'searchFilterChipSelectedTextColor',
                    _chipSelectedText,
                  ),
                  searchFilterChipTextStyle: c.on(
                    'searchFilterChipTextStyle',
                    _chipTextStyle,
                  ),
                  searchFilterChipSelectedTextStyle: c.on(
                    'searchFilterChipSelectedTextStyle',
                    _chipSelectedTextStyle,
                  ),
                  searchFilterChipBorder: c.on(
                    'searchFilterChipBorder',
                    _chipBorder,
                  ),
                  searchFilterChipSelectedBorder: c.on(
                    'searchFilterChipSelectedBorder',
                    _chipSelectedBorder,
                  ),
                  searchFilterChipBorderRadius: c.on(
                    'searchFilterChipBorderRadius',
                    _chipRadius,
                  ),
                  searchFilterIconColor: c.on(
                    'searchFilterIconColor',
                    _chipIcon,
                  ),
                  searchFilterSelectedIconColor: c.on(
                    'searchFilterSelectedIconColor',
                    _chipSelectedIcon,
                  ),
                  sectionHeaderTextColor: c.on(
                    'sectionHeaderTextColor',
                    _header,
                  ),
                  sectionHeaderTextStyle: c.on(
                    'sectionHeaderTextStyle',
                    _headerStyle,
                  ),
                  searchConversationTitleTextColor: c.on(
                    'searchConversationTitleTextColor',
                    _convTitle,
                  ),
                  searchConversationTitleTextStyle: c.on(
                    'searchConversationTitleTextStyle',
                    _convTitleStyle,
                  ),
                  searchConversationSubtitleTextColor: c.on(
                    'searchConversationSubtitleTextColor',
                    _convSubtitle,
                  ),
                  searchConversationSubtitleTextStyle: c.on(
                    'searchConversationSubtitleTextStyle',
                    _convSubtitleStyle,
                  ),
                  searchConversationItemBackgroundColor: c.on(
                    'searchConversationItemBackgroundColor',
                    _convFill,
                  ),
                  searchMessageSenderTextColor: c.on(
                    'searchMessageSenderTextColor',
                    _sender,
                  ),
                  searchMessageSenderTextStyle: c.on(
                    'searchMessageSenderTextStyle',
                    _senderStyle,
                  ),
                  searchMessagePreviewTextColor: c.on(
                    'searchMessagePreviewTextColor',
                    _preview,
                  ),
                  searchMessagePreviewTextStyle: c.on(
                    'searchMessagePreviewTextStyle',
                    _previewStyle,
                  ),
                  searchMessageDateTextColor: c.on(
                    'searchMessageDateTextColor',
                    _date,
                  ),
                  searchMessageDateTextStyle: c.on(
                    'searchMessageDateTextStyle',
                    _dateTextStyle,
                  ),
                  emptyStateTextColor: c.on('emptyStateTextColor', _emptyTitle),
                  emptyStateTextStyle: c.on(
                    'emptyStateTextStyle',
                    _emptyTitleStyle,
                  ),
                  emptyStateSubTitleTextColor: c.on(
                    'emptyStateSubTitleTextColor',
                    _emptySubtitle,
                  ),
                  emptyStateSubTitleTextStyle: c.on(
                    'emptyStateSubTitleTextStyle',
                    _emptySubtitleStyle,
                  ),
                  errorStateTextColor: c.on('errorStateTextColor', _errorTitle),
                  errorStateTextStyle: c.on(
                    'errorStateTextStyle',
                    _errorTitleStyle,
                  ),
                  seeMoreTextColor: c.on('seeMoreTextColor', _seeMore),
                  seeMoreTextStyle: c.on('seeMoreTextStyle', _seeMoreStyle),
                  avatarStyle: c.on('avatarStyle', _avatarStyle),
                  badgeStyle: c.on('badgeStyle', _badgeStyle),
                ),
              ),
            ),
          ),
        );
        await _drive(tester, c.stage);

        expect(
          c.probe(tester),
          c.expected,
          reason: '${c.prop} did not reach ${c.target}',
        );
      });
    }
  });
}
