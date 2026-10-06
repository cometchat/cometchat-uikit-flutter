/// Render-verified prop matrix for the CometChatConversations props that
/// conversations_props_test.dart leaves uncovered — Track 3 PROP1
/// (ENG-38688, coverage part 2).
///
/// How the matrix works. [_matrix] is a table. Each row names the prop it
/// verifies, the bloc state or fake backend it runs against, an optional
/// real interaction, a probe that reads the rendered element (or recorded
/// call) the prop controls, and one expectation per side. Every row is
/// pumped at least twice in one test body:
///
/// * `unset` renders the bare construction, which passes none of the props
///   this file covers, so the constructor default is what renders.
/// * `set` (or `false` for a flag) renders the full construction with the
///   row's sentinel: a colour no theme uses, a keyed builder, a recording
///   callback, a distinctive size.
/// * Nullable flags add a `null` side that passes the flag as an explicit
///   null, pinning that null means the default and not false.
///
/// Each side's reading is checked against its expectation, and the `set`
/// reading must differ from the `unset` one, so a widget that ignored the
/// prop would render its baseline twice and fail.
///
/// Most rows inject a mocked bloc. Five props shape the bloc the widget
/// builds for itself, so their rows pass no bloc and fake one layer further
/// down instead: the SDK client in SdkRegistry. Its conversation repository
/// answers the widget's own fetch, and its realtime repository pushes the
/// presence and receipt events the bloc listens for. Everything between
/// the prop and the pixel is production code.
///
/// usersStatusVisibility and receiptsVisibility are each read twice by the
/// widget, once for ConversationsList and once for the bloc it creates
/// (cometchat_conversations.dart 478-479 and 697, 705). Each read has its
/// own row, so deleting either fails a test. Inside the bloc,
/// receiptsVisibility guards four receipt handlers (conversations_bloc.dart
/// 1460, 1468, 1476, 1484), one row each. routeObserver is read to
/// subscribe, to freeze the covered list and to unsubscribe on dispose
/// (396, 522, 505), and conversationsStyle.backIconColor is read for the
/// default arrow and for the tint around a custom back button (604, 631);
/// each read has a row.
///
/// Reads no widget test can observe: ListBaseStyle.titleStyle (622-630),
/// which CometChatListBase only paints when no titleView is passed, and
/// this widget always passes one; and the bloc removing its user listener
/// on close (conversations_bloc.dart 2042), which leaves no public trace.
///
/// All 35 props this file targets have rows. Four of them had no effect
/// until ENG-38688 fixed them, and their rows fail if the fix is reverted:
///
///   setOptions, addOptions     the long-press menu was a fixed Pin/Delete
///                              list after the bloc migration (a9de54056).
///   customSoundForMessages     the bloc stored it and never played a sound.
///   dateBackgroundIsTransparent  the list item forced the timestamp
///                              transparent, so false changed nothing.
///
/// disableSoundForMessages has a row here too: the template can only show
/// that it renders, and this harness can deliver a real incoming message.
///
///   flutter test test/chat_ui/conversations/widget/conversations_remaining_props_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these. The widget builds its own bloc for these
// rows, so the fake has to sit where the SDK resolves its repositories.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/analytics/sdk_identification.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/auth/auth_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/models/presence/connection_state.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/realtime/realtime_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mock bloc & model fakes ─────────────────────────────────────────────────

/// Ignores every event, and hands out real typing notifiers so a row can
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
  _FakeTextMessage({required User from, this.deliveredAt, this.readAt})
    : _from = from;

  final User _from;

  @override
  User get sender => _from;

  @override
  final DateTime? deliveredAt;

  @override
  final DateTime? readAt;

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

// ─── SDK fakes ───────────────────────────────────────────────────────────────

/// What the fake SDK was asked for, and the realtime events it can push.
class _Backend {
  /// One `(conversationType, limit)` record per conversation fetch.
  final List<(String?, int?)> fetches = [];

  final presence = StreamController<User>.broadcast();
  final receipts = StreamController<MessageReceipt>.broadcast();
  final messages = StreamController<BaseMessage>.broadcast();

  /// Honours the conversationType filter the way the server does, so a
  /// builder that reaches the request changes which rows render. Fresh
  /// objects per fetch, because the bloc mutates receipt fields in place.
  Future<sdk.ConversationsResult> conversations(Invocation call) {
    final type = call.namedArguments[#conversationType] as String?;
    fetches.add((type, call.namedArguments[#limit] as int?));
    return Future.value(
      sdk.ConversationsResult(
        conversations: [
          for (final c in _sdkConversations())
            if (type == null || c.conversationType == type) c,
        ],
        hasMore: false,
      ),
    );
  }

  Future<void> close() async {
    await presence.close();
    await receipts.close();
    await messages.close();
  }
}

/// ConversationsRequest.fetchNext calls getConversations with a dozen named
/// filters. Answered through noSuchMethod so the fake does not restate them.
class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  _FakeConversationRepository(this._backend);

  final _Backend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getConversations) {
      return _backend.conversations(invocation);
    }
    return super.noSuchMethod(invocation);
  }
}

/// CometChat wires its listener maps to these streams on login. Presence
/// and receipts come from the backend; every other stream stays silent.
class _FakeRealtime extends Fake implements sdk.RealtimeRepository {
  _FakeRealtime(this._backend);

  final _Backend _backend;

  @override
  Stream<User> get presenceStream => _backend.presence.stream;

  @override
  Stream<MessageReceipt> get receiptStream => _backend.receipts.stream;

  @override
  Stream<BaseMessage> get messageStream => _backend.messages.stream;

  // Connected, so the delivery receipt an incoming message triggers goes over
  // the fake socket (markAsDelivered below) and succeeds quietly.
  @override
  sdk.ConnectionState get connectionState => sdk.ConnectionState.connected;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #markAsDelivered) return Future<void>.value();
    if (invocation.isGetter &&
        invocation.memberName.toString().contains('Stream')) {
      return const Stream<Never>.empty();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeAuth extends Fake implements sdk.AuthRepository {
  @override
  Future<User> loginWithApiKey(String uid, String apiKey) async => _sdkMe;

  @override
  User? getLoggedInUser() => _sdkMe;
}

class _FakeIdentification extends Fake implements sdk.SdkIdentification {
  @override
  Future<void> sendIfNeeded() async {}
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(_Backend backend)
    : conversations = _FakeConversationRepository(backend),
      realtime = _FakeRealtime(backend);

  @override
  final sdk.ConversationRepository conversations;

  @override
  final sdk.RealtimeRepository realtime;

  @override
  final sdk.AuthRepository auth = _FakeAuth();

  @override
  final sdk.SdkIdentification sdkIdentification = _FakeIdentification();

  @override
  Future<void> dispose() async {}
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

/// Alice selected, so the app bar shows the submit action.
ConversationsState _selected() => ConversationsLoaded(
  conversations: _three(),
  selectedConversations: const {'user_u1'},
);

/// More rows than fit the 600 px test screen.
ConversationsState _many() => ConversationsLoaded(
  conversations: [
    for (var i = 0; i < 25; i++)
      _conv(_FakeUser('m$i', 'Row $i', status: 'offline'), 'user_m$i'),
  ],
);

ConversationsState Function() _only(Conversation Function() conversation) =>
    () => ConversationsLoaded(conversations: [conversation()]);

final _sdkMe = User(uid: 'me', name: 'Me', status: 'online');

/// What the fake server holds: Alice (online, my last message only sent),
/// Bob (offline) and a public group (no status dot, my last message only
/// sent).
List<Conversation> _sdkConversations() => [
  Conversation(
    conversationId: 'user_u1',
    conversationType: 'user',
    conversationWith: User(uid: 'u1', name: 'Alice', status: 'online'),
    lastMessage: TextMessage(
      text: 'Hello!',
      id: 100,
      sender: _sdkMe,
      receiverUid: 'u1',
      type: 'text',
      receiverType: 'user',
      category: 'message',
      sentAt: DateTime(2026, 5, 12, 10, 30),
      conversationId: 'user_u1',
    ),
  ),
  Conversation(
    conversationId: 'user_u2',
    conversationType: 'user',
    conversationWith: User(uid: 'u2', name: 'Bob', status: 'offline'),
  ),
  Conversation(
    conversationId: 'group_g1',
    conversationType: 'group',
    conversationWith: Group(guid: 'g1', name: 'Dev Team', type: 'public'),
    lastMessage: TextMessage(
      text: 'Hello team!',
      id: 200,
      sender: _sdkMe,
      receiverUid: 'g1',
      type: 'text',
      receiverType: 'group',
      category: 'message',
      sentAt: DateTime(2026, 5, 12, 10, 40),
      conversationId: 'group_g1',
    ),
  ),
];

/// Seeds "Bob is typing" in Alice's conversation.
final _typingInAlice = {
  'user_u1': [
    TypingIndicator(sender: _bob, receiverId: 'u1', receiverType: 'user'),
  ],
};

// Sentinels: values no theme produces, so a match can only come from the prop.
const _kTitle = Color(0xFF1A2B3C);
const _kBackground = Color(0xFF2B3C4D);
const _kBackIcon = Color(0xFF3C4D5E);
const _kSearchFill = Color(0xFF4D5E6F);
const _kSearchIcon = Color(0xFF5E6F70);
const _kSeparator = Color(0xFF6F7081);
const _kSubmit = Color(0xFF708192);
const _kItemTitle = Color(0xFF8192A3);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// Every prop this file covers. Each field is wired into the full
/// construction in [main]; the guard test holds each field to a row.
class _Props {
  const _Props({
    this.avatarMargin,
    this.avatarPadding,
    this.badgePadding,
    this.conversationsProtocol,
    this.conversationsRequestBuilder,
    this.conversationsStyle,
    this.dateHeight,
    this.datePadding,
    this.datePattern,
    this.dateTimeFormatterCallback,
    this.dateWidth,
    this.deliveredIcon,
    this.groupTypeVisibility,
    this.leadingView,
    this.onSearchTap,
    this.readIcon,
    this.receiptsVisibility,
    this.routeObserver,
    this.scrollController,
    this.searchBoxIcon,
    this.searchContentPadding,
    this.searchPadding,
    this.sentIcon,
    this.statusIndicatorBorderRadius,
    this.statusIndicatorHeight,
    this.statusIndicatorWidth,
    this.submitIcon,
    this.textFormatters,
    this.titleView,
    this.typingIndicatorText,
    this.usersStatusVisibility,
    this.setOptions,
    this.addOptions,
    this.dateBackgroundIsTransparent,
    this.customSoundForMessages,
    this.disableSoundForMessages,
  });

  final EdgeInsetsGeometry? avatarMargin;
  final EdgeInsetsGeometry? avatarPadding;
  final EdgeInsetsGeometry? badgePadding;
  final ConversationsBuilderProtocol? conversationsProtocol;
  final ConversationsRequestBuilder? conversationsRequestBuilder;
  final CometChatConversationsStyle? conversationsStyle;
  final double? dateHeight;
  final EdgeInsets? datePadding;
  final String Function(Conversation conversation)? datePattern;
  final DateTimeFormatterCallback? dateTimeFormatterCallback;
  final double? dateWidth;
  final Widget? deliveredIcon;
  final bool? groupTypeVisibility;
  final Widget? Function(BuildContext context, Conversation conversation)?
  leadingView;
  final GestureTapCallback? onSearchTap;
  final Widget? readIcon;
  final bool? receiptsVisibility;
  final RouteObserver<ModalRoute<void>>? routeObserver;
  final ScrollController? scrollController;
  final Widget? searchBoxIcon;
  final EdgeInsetsGeometry? searchContentPadding;
  final EdgeInsetsGeometry? searchPadding;
  final Widget? sentIcon;
  final BorderRadiusGeometry? statusIndicatorBorderRadius;
  final double? statusIndicatorHeight;
  final double? statusIndicatorWidth;
  final Widget? submitIcon;
  final List<CometChatTextFormatter>? textFormatters;
  final Widget? Function(BuildContext context, Conversation conversation)?
  titleView;
  final String? typingIndicatorText;
  final bool? usersStatusVisibility;
  final List<CometChatOption>? Function(
    Conversation conversation,
    ConversationsBloc bloc,
    BuildContext context,
  )?
  setOptions;
  final List<CometChatOption>? Function(
    Conversation conversation,
    ConversationsBloc bloc,
    BuildContext context,
  )?
  addOptions;
  final bool? dateBackgroundIsTransparent;
  final String? customSoundForMessages;
  final bool? disableSoundForMessages;

  Map<String, Object?> get values => {
    'avatarMargin': avatarMargin,
    'avatarPadding': avatarPadding,
    'badgePadding': badgePadding,
    'conversationsProtocol': conversationsProtocol,
    'conversationsRequestBuilder': conversationsRequestBuilder,
    'conversationsStyle': conversationsStyle,
    'dateHeight': dateHeight,
    'datePadding': datePadding,
    'datePattern': datePattern,
    'dateTimeFormatterCallback': dateTimeFormatterCallback,
    'dateWidth': dateWidth,
    'deliveredIcon': deliveredIcon,
    'groupTypeVisibility': groupTypeVisibility,
    'leadingView': leadingView,
    'onSearchTap': onSearchTap,
    'readIcon': readIcon,
    'receiptsVisibility': receiptsVisibility,
    'routeObserver': routeObserver,
    'scrollController': scrollController,
    'searchBoxIcon': searchBoxIcon,
    'searchContentPadding': searchContentPadding,
    'searchPadding': searchPadding,
    'sentIcon': sentIcon,
    'statusIndicatorBorderRadius': statusIndicatorBorderRadius,
    'statusIndicatorHeight': statusIndicatorHeight,
    'statusIndicatorWidth': statusIndicatorWidth,
    'submitIcon': submitIcon,
    'textFormatters': textFormatters,
    'titleView': titleView,
    'typingIndicatorText': typingIndicatorText,
    'usersStatusVisibility': usersStatusVisibility,
    'setOptions': setOptions,
    'addOptions': addOptions,
    'dateBackgroundIsTransparent': dateBackgroundIsTransparent,
    'customSoundForMessages': customSoundForMessages,
    'disableSoundForMessages': disableSoundForMessages,
  };

  /// The props this instance actually sets.
  Set<String> get setNames => {
    for (final e in values.entries)
      if (e.value != null) e.key,
  };

  /// Every prop the full construction reads from a row.
  static Set<String> get wired => const _Props().values.keys.toSet();
}

/// What one side records while it runs, plus the handles a row's
/// interaction needs.
class _Rec {
  _Rec(this.title);

  final navigator = GlobalKey<NavigatorState>();
  final observer = RouteObserver<ModalRoute<void>>();

  /// The title both constructions pass; the routeObserver row changes it.
  String? title;

  /// Rebuilds the widget's parent, handing it a fresh construction.
  StateSetter? rebuild;

  _Backend? backend;
  Conversation? tapped;
  int searchTaps = 0;

  /// The long-press menu's entries, read before any is tapped.
  List<String>? menu;
  int optionTaps = 0;

  /// Set by the dispose row: the parent then builds nothing, so the widget
  /// is disposed while its route stays on the navigator.
  bool gone = false;
  ModalRoute<void>? route;
  bool? observedBeforeDispose;

  void tap(Conversation conversation) => tapped = conversation;

  ScrollController? _controller;
  ScrollController get controller => _controller ??= ScrollController();

  void dispose() => _controller?.dispose();
}

/// An expectation that depends on the default theme, resolved against the
/// rendered widget.
class _FromTheme {
  const _FromTheme(this.resolve);

  final Object? Function(CometChatColorPalette palette, CometChatSpacing space)
  resolve;
}

class _Side {
  const _Side(this.label, this.props, this.expected) : bare = false;

  /// The bare construction: none of this file's props, so every default
  /// renders.
  const _Side.unset(this.expected)
    : label = 'unset',
      props = _none,
      bare = true;

  final String label;
  final _Props Function(_Rec rec) props;
  final Object? expected;
  final bool bare;
}

_Props _none(_Rec rec) => const _Props();

class _Row {
  const _Row(
    this.prop,
    this.claim, {
    required this.unset,
    required this.set,
    required this.probe,
    this.more = const [],
    this.state = _loaded,
    this.act,
    this.typing = const {},
    this.signedIn = false,
    this.sdk = false,
    this.hideSearch,
    this.searchReadOnly = false,
    this.showBackButton = false,
    this.backButton,
    this.title,
  });

  /// The CometChatConversations parameter this row verifies.
  final String prop;

  /// What the row claims, in words. Becomes the test name.
  final String claim;

  /// What [probe] must return on the bare render.
  final Object? unset;

  /// The side that sets the prop. Its reading must differ from [unset]'s.
  final _Side set;

  /// Further sides, each with its own expectation.
  final List<_Side> more;

  /// Reads the rendered element (or recorded call) the prop controls.
  final Object? Function(WidgetTester tester, _Rec rec) probe;

  /// The mocked bloc's state. Ignored by [sdk] rows.
  final ConversationsState Function() state;

  /// A real interaction to run before probing.
  final Future<void> Function(WidgetTester tester, _Rec rec)? act;

  /// Typing indicators to seed in the mocked bloc, by conversation id.
  final Map<String, List<TypingIndicator>> typing;

  /// Signs the sender of "my" last message in, so its receipt shows.
  final bool signedIn;

  /// Passes no bloc, so the widget builds its own over the fake SDK.
  final bool sdk;

  // Scaffolding both constructions share. None is a prop this file covers.
  final bool? hideSearch;
  final bool searchReadOnly;
  final bool showBackButton;
  final Widget? backButton;
  final String? title;
}

int _count(Finder finder) => finder.evaluate().length;

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(CometChatConversations, skipOffstage: false));

Translations _tr(WidgetTester tester) => Translations.of(_ctx(tester));

List<String> _textsStartingWith(WidgetTester tester, String prefix) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    // `?text.data` drops the `when` clause, so the list stops being
    // filtered by `prefix` and every Text on screen comes back.
    // `dart fix` applies exactly that rewrite; it silently broke six
    // tests in this file and its sibling.
    // ignore: use_null_aware_elements
    if (text.data case final data? when data.startsWith(prefix)) data,
];

/// The outermost Container a widget of [type] builds: the avatar box, the
/// presence dot, the badge, the timestamp.
Container _box(WidgetTester tester, Type type) => tester.widget<Container>(
  find
      .descendant(of: find.byType(type).first, matching: find.byType(Container))
      .first,
);

BoxDecoration _decoration(WidgetTester tester, Type type) =>
    _box(tester, type).decoration! as BoxDecoration;

Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

TextField _searchField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

/// The colour the glyph of [icon] is painted in, wherever it came from.
Color? _glyphColor(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

/// The receipt tick drawn on [name]'s row, as (icon, colour), or null.
(IconData?, Color?)? _receiptIn(WidgetTester tester, String name) {
  final ticks = [Icons.done, Icons.done_all, Icons.schedule];
  final icons = tester
      .widgetList<Icon>(
        find.descendant(
          of: find.ancestor(
            of: find.text(name),
            matching: find.byType(CometChatConversationListItem),
          ),
          matching: find.byType(Icon),
        ),
      )
      .where((icon) => ticks.contains(icon.icon))
      .toList();
  return icons.isEmpty ? null : (icons.single.icon, icons.single.color);
}

/// A [type] receipt for my last message on [name]'s row, pushed through the
/// fake SDK to the bloc the widget builds. Each receipt type reaches the bloc
/// through its own handler, and each handler reads receiptsVisibility
/// (conversations_bloc.dart 1460, 1468, 1476, 1484), so each has a row.
_Row _receiptRow(String type, String name) {
  final group = type.endsWith('All');
  final read = type.startsWith('read');
  final at = DateTime(2026, 5, 12, 10, 45);
  List<Object?> shown(CometChatColorPalette p) => [
    (Icons.done_all, read ? p.primary : p.iconSecondary),
    true,
    read,
  ];
  return _Row(
    'receiptsVisibility',
    "false stops the widget's own bloc applying a $type receipt",
    sdk: true,
    signedIn: true,
    act: (t, r) async {
      r.backend!.receipts.add(
        MessageReceipt(
          messageId: group ? 200 : 100,
          sender: User(uid: 'u1', name: 'Alice'),
          receiverType: group ? 'group' : 'user',
          receiverId: group ? 'g1' : 'me',
          receiptType: type,
          deliveredAt: read ? null : at,
          readAt: read ? at : null,
        ),
      );
      await _drainBatch(t);
      await _tapText(t, name);
    },
    // The tick on that row, and what the bloc recorded on the message.
    probe: (t, r) => [
      _receiptIn(t, name),
      r.tapped?.lastMessage?.deliveredAt != null,
      r.tapped?.lastMessage?.readAt != null,
    ],
    unset: _FromTheme((p, s) => shown(p)),
    set: _Side('false', (r) => const _Props(receiptsVisibility: false), [
      null,
      false,
      false,
    ]),
    more: [_Side('null', _none, _FromTheme((p, s) => shown(p)))],
  );
}

/// Presence dots currently drawn.
int _dots() => _count(find.byType(CometChatStatusIndicator));

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
}

/// Lets the bloc's 50 ms event batch run, then renders its result.
Future<void> _drainBatch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump();
}

Widget _app(_Rec rec, String label, Widget child) => MaterialApp(
  // A fresh app per side, so no element state carries over.
  key: ValueKey(label),
  navigatorKey: rec.navigator,
  navigatorObservers: [rec.observer],
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

final _matrix = <_Row>[
  // ── Long-press options (restored: the bloc migration had dropped them) ────
  _Row(
    'setOptions',
    'replaces the Pin and Delete entries, and runs the chosen option',
    act: _openAliceMenuAndTapOption,
    probe: (t, r) => [r.menu, r.optionTaps],
    unset: [
      ['Pin', 'Delete'],
      0,
    ],
    set: _Side(
      'set',
      (r) => _Props(
        setOptions: (conversation, bloc, context) => [
          CometChatOption(
            id: 'archive',
            title: _kOption,
            onClick: () => r.optionTaps++,
          ),
        ],
      ),
      [
        [_kOption],
        1,
      ],
    ),
  ),
  _Row(
    'addOptions',
    'puts its entries in front of Pin and Delete, and runs the chosen one',
    act: _openAliceMenuAndTapOption,
    probe: (t, r) => [r.menu, r.optionTaps],
    unset: [
      ['Pin', 'Delete'],
      0,
    ],
    set: _Side(
      'set',
      (r) => _Props(
        addOptions: (conversation, bloc, context) => [
          CometChatOption(
            id: 'archive',
            title: _kOption,
            onClick: () => r.optionTaps++,
          ),
        ],
      ),
      [
        [_kOption, 'Pin', 'Delete'],
        1,
      ],
    ),
  ),

  // ── Timestamp background ──────────────────────────────────────────────────
  _Row(
    'dateBackgroundIsTransparent',
    'false paints the timestamp with the theme background',
    probe: (t, r) => _dateFill(t),
    unset: null,
    set: _Side(
      'set',
      (r) => const _Props(dateBackgroundIsTransparent: false),
      _FromTheme((palette, space) => palette.background2),
    ),
    more: [
      _Side(
        'true',
        (r) => const _Props(dateBackgroundIsTransparent: true),
        null,
      ),
    ],
  ),

  // ── Incoming-message sound (restored: the bloc never played one) ──────────
  _Row(
    'customSoundForMessages',
    'replaces the sound an incoming message plays',
    sdk: true,
    act: _receiveFromBob,
    probe: (t, r) => [..._sounds],
    unset: [_kIncomingSound],
    set: _Side(
      'set',
      (r) => const _Props(customSoundForMessages: _kCustomSound),
      [_kCustomSound],
    ),
  ),
  _Row(
    'disableSoundForMessages',
    'true silences incoming messages',
    sdk: true,
    act: _receiveFromBob,
    probe: (t, r) => [..._sounds],
    unset: [_kIncomingSound],
    set: _Side(
      'set',
      (r) => const _Props(disableSoundForMessages: true),
      <String>[],
    ),
    more: [
      _Side('false', (r) => const _Props(disableSoundForMessages: false), [
        _kIncomingSound,
      ]),
    ],
  ),

  // ── Avatar, badge and presence geometry ───────────────────────────────────
  _Row(
    'avatarMargin',
    'spaces every avatar box from its neighbours',
    probe: (t, r) => [
      _box(t, CometChatAvatar).margin,
      t.getSize(find.byType(CometChatAvatar).first),
    ],
    unset: [null, const Size(48, 48)],
    set: _Side(
      'set',
      (r) => const _Props(avatarMargin: EdgeInsets.fromLTRB(1, 2, 3, 4)),
      [const EdgeInsets.fromLTRB(1, 2, 3, 4), const Size(52, 54)],
    ),
  ),
  _Row(
    'avatarPadding',
    'insets the avatar content inside its box',
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
    unset: [null, const Size(48, 48)],
    set: _Side('set', (r) => const _Props(avatarPadding: EdgeInsets.all(3.5)), [
      const EdgeInsets.all(3.5),
      const Size(41, 41),
    ]),
  ),
  _Row(
    'badgePadding',
    'insets the unread count inside its 20 px badge',
    probe: (t, r) => [
      _box(t, CometChatBadge).padding,
      t.getSize(
        find
            .descendant(
              of: find.byType(CometChatBadge).first,
              matching: find.byType(FittedBox),
            )
            .first,
      ),
    ],
    unset: [
      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      const Size(12, 16),
    ],
    set: _Side('set', (r) => const _Props(badgePadding: EdgeInsets.all(5)), [
      const EdgeInsets.all(5),
      const Size(10, 10),
    ]),
  ),
  _Row(
    'statusIndicatorBorderRadius',
    'rounds the drawn presence dot',
    probe: (t, r) => _decoration(t, CometChatStatusIndicator).borderRadius,
    unset: _FromTheme((p, s) => BorderRadius.circular(s.radiusMax!)),
    set: _Side(
      'set',
      (r) => const _Props(
        statusIndicatorBorderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      const BorderRadius.all(Radius.circular(3)),
    ),
  ),
  _Row(
    'statusIndicatorHeight',
    'sets the rendered presence dot height',
    probe: (t, r) =>
        t.getSize(find.byType(CometChatStatusIndicator).first).height,
    unset: 14.0,
    set: _Side('set', (r) => const _Props(statusIndicatorHeight: 9), 9.0),
  ),
  _Row(
    'statusIndicatorWidth',
    'sets the rendered presence dot width',
    probe: (t, r) =>
        t.getSize(find.byType(CometChatStatusIndicator).first).width,
    unset: 14.0,
    set: _Side('set', (r) => const _Props(statusIndicatorWidth: 11), 11.0),
  ),

  // ── Timestamp ─────────────────────────────────────────────────────────────
  _Row(
    'dateHeight',
    'sets the rendered timestamp height',
    probe: (t, r) => t.getSize(find.byType(CometChatDate).first).height,
    unset: 17.0,
    set: _Side('set', (r) => const _Props(dateHeight: 31), 31.0),
  ),
  _Row(
    'dateWidth',
    'sets the rendered timestamp width',
    probe: (t, r) => t.getSize(find.byType(CometChatDate).first).width,
    unset: 147.0,
    set: _Side('set', (r) => const _Props(dateWidth: 57), 57.0),
  ),
  _Row(
    'datePadding',
    'insets the timestamp text inside its box',
    probe: (t, r) {
      final date = find.byType(CometChatDate).first;
      final text = find.descendant(of: date, matching: find.byType(Text));
      return [
        _box(t, CometChatDate).padding,
        t.getTopLeft(text) - t.getTopLeft(date),
      ];
    },
    unset: [EdgeInsets.zero, Offset.zero],
    set: _Side(
      'set',
      (r) => const _Props(datePadding: EdgeInsets.fromLTRB(3, 5, 7, 9)),
      [const EdgeInsets.fromLTRB(3, 5, 7, 9), const Offset(3, 5)],
    ),
  ),
  _Row(
    'datePattern',
    'writes the timestamp text',
    probe: (t, r) => _count(find.text('when-user_u1')),
    unset: 0,
    set: _Side(
      'set',
      (r) => _Props(datePattern: (c) => 'when-${c.conversationId}'),
      1,
    ),
  ),
  _Row(
    'dateTimeFormatterCallback',
    'formats the timestamp',
    probe: (t, r) => _count(find.text('WHEN-SENTINEL')),
    unset: 0,
    set: _Side(
      'set',
      (r) => _Props(dateTimeFormatterCallback: _SentinelDates()),
      1,
    ),
  ),

  // ── Row slots and preview ─────────────────────────────────────────────────
  _Row(
    'leadingView',
    'replaces the avatar on every row',
    probe: (t, r) => [
      ..._textsStartingWith(t, 'lead-'),
      _count(find.byType(CometChatAvatar)),
    ],
    unset: [3],
    set: _Side(
      'set',
      (r) =>
          _Props(leadingView: (context, c) => Text('lead-${c.conversationId}')),
      ['lead-user_u1', 'lead-user_u2', 'lead-group_g1', 0],
    ),
  ),
  _Row(
    'titleView',
    'replaces the conversation name on every row',
    probe: (t, r) => [
      ..._textsStartingWith(t, 'title-'),
      _count(find.text('Alice')),
    ],
    unset: [1],
    set: _Side(
      'set',
      (r) =>
          _Props(titleView: (context, c) => Text('title-${c.conversationId}')),
      ['title-user_u1', 'title-user_u2', 'title-group_g1', 0],
    ),
  ),
  _Row(
    'textFormatters',
    'format the last-message preview',
    probe: (t, r) => [
      _count(find.textContaining('FORMATTED-BY-SENTINEL', findRichText: true)),
      _count(find.textContaining('Hello!', findRichText: true)),
    ],
    unset: [0, 1],
    set: _Side('set', (r) => _Props(textFormatters: [_SentinelFormatter()]), [
      1,
      0,
    ]),
  ),
  _Row(
    'typingIndicatorText',
    'replaces the typing line',
    typing: _typingInAlice,
    probe: (t, r) => [
      _count(find.text('typing-sentinel-7T')),
      _count(find.text(_tr(t).isTyping)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(typingIndicatorText: 'typing-sentinel-7T'),
      [1, 0],
    ),
  ),

  // ── Receipt icons ─────────────────────────────────────────────────────────
  _Row(
    'readIcon',
    'replaces the tick on my read message',
    signedIn: true,
    state: _only(() => _mine(read: true)),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('read-sentinel'))),
      _count(find.byIcon(Icons.done_all)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(
        readIcon: Icon(Icons.visibility, key: ValueKey('read-sentinel')),
      ),
      [1, 0],
    ),
  ),
  _Row(
    'deliveredIcon',
    'replaces the tick on my delivered message',
    signedIn: true,
    state: _only(() => _mine(delivered: true)),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('delivered-sentinel'))),
      _count(find.byIcon(Icons.done_all)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(
        deliveredIcon: Icon(Icons.inbox, key: ValueKey('delivered-sentinel')),
      ),
      [1, 0],
    ),
  ),
  _Row(
    'sentIcon',
    'replaces the tick on my sent message',
    signedIn: true,
    state: _only(_mine),
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('sent-sentinel'))),
      _count(find.byIcon(Icons.done)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(
        sentIcon: Icon(Icons.outbox, key: ValueKey('sent-sentinel')),
      ),
      [1, 0],
    ),
  ),

  // ── Flags, list path (ConversationsList, 697-705) ─────────────────────────
  _Row(
    'usersStatusVisibility',
    'false hides the presence dot on an online user',
    state: _only(() => _conv(_FakeUser('u1', 'Alice'), 'user_u1')),
    probe: (t, r) => _dots(),
    unset: 1,
    set: _Side('false', (r) => const _Props(usersStatusVisibility: false), 0),
    more: [_Side('null', _none, 1)],
  ),
  _Row(
    'receiptsVisibility',
    'false drops the tick from my own last message',
    signedIn: true,
    state: _only(() => _mine(delivered: true)),
    probe: (t, r) => _count(find.byIcon(Icons.done_all)),
    unset: 1,
    set: _Side('false', (r) => const _Props(receiptsVisibility: false), 0),
    more: [_Side('null', _none, 1)],
  ),
  _Row(
    'groupTypeVisibility',
    'false hides the group-type badge on a private group',
    state: _only(() => _conv(_FakeGroup('g1', 'Dev Team', 'private'), 'g1')),
    probe: (t, r) => [_dots(), _count(find.byIcon(Icons.shield))],
    unset: [1, 1],
    set: _Side('false', (r) => const _Props(groupTypeVisibility: false), [
      0,
      0,
    ]),
    more: [
      _Side('null', _none, [1, 1]),
    ],
  ),

  // ── Flags, bloc path (the bloc the widget builds, 478-479) ────────────────
  _Row(
    'usersStatusVisibility',
    'false stops the widget\'s own bloc applying presence events',
    sdk: true,
    act: (t, r) async {
      r.backend!.presence.add(User(uid: 'u2', name: 'Bob', status: 'online'));
      await _drainBatch(t);
      await _tapText(t, 'Bob');
    },
    // Dots drawn, and Bob's status as the bloc now holds it.
    probe: (t, r) => [_dots(), (r.tapped?.conversationWith as User?)?.status],
    unset: [2, 'online'],
    set: _Side('false', (r) => const _Props(usersStatusVisibility: false), [
      0,
      'offline',
    ]),
    more: [
      _Side('null', _none, [2, 'online']),
    ],
  ),
  _receiptRow('delivered', 'Alice'),
  _receiptRow('read', 'Alice'),
  _receiptRow('deliveredToAll', 'Dev Team'),
  _receiptRow('readByAll', 'Dev Team'),

  // ── Fetch shaping (the bloc the widget builds, 480-481) ───────────────────
  _Row(
    'conversationsRequestBuilder',
    'filters and sizes the widget\'s own fetch',
    sdk: true,
    probe: (t, r) => [
      _count(find.text('Alice')),
      _count(find.text('Bob')),
      _count(find.text('Dev Team')),
      ...r.backend!.fetches,
    ],
    unset: [1, 1, 1, (null, 30)],
    set: _Side(
      'set',
      (r) => _Props(
        conversationsRequestBuilder: ConversationsRequestBuilder()
          ..conversationType = 'group'
          ..limit = 7,
      ),
      [0, 0, 1, ('group', 7)],
    ),
  ),
  _Row(
    'conversationsProtocol',
    'shapes the widget\'s own fetch, ahead of a request builder',
    sdk: true,
    probe: (t, r) => [
      _count(find.text('Alice')),
      _count(find.text('Bob')),
      _count(find.text('Dev Team')),
      ...r.backend!.fetches,
    ],
    unset: [1, 1, 1, (null, 30)],
    set: _Side(
      'set',
      (r) => _Props(
        conversationsProtocol: UIConversationsBuilder(
          ConversationsRequestBuilder()
            ..conversationType = 'user'
            ..limit = 9,
        ),
      ),
      [1, 1, 0, ('user', 9)],
    ),
    more: [
      _Side(
        'with a competing request builder',
        (r) => _Props(
          conversationsProtocol: UIConversationsBuilder(
            ConversationsRequestBuilder()
              ..conversationType = 'user'
              ..limit = 9,
          ),
          conversationsRequestBuilder: ConversationsRequestBuilder()
            ..conversationType = 'group'
            ..limit = 7,
        ),
        [1, 1, 0, ('user', 9)],
      ),
    ],
  ),

  // ── Selection action ──────────────────────────────────────────────────────
  _Row(
    'submitIcon',
    'replaces the check shown while conversations are selected',
    state: _selected,
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('submit-sentinel'))),
      _count(find.byIcon(Icons.check)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(
        submitIcon: Icon(Icons.send, key: ValueKey('submit-sentinel')),
      ),
      [1, 0],
    ),
  ),

  // ── Search box ────────────────────────────────────────────────────────────
  _Row(
    'searchBoxIcon',
    'replaces the search prefix icon',
    hideSearch: false,
    probe: (t, r) => [
      _count(find.byKey(const ValueKey('search-icon-sentinel'))),
      _count(find.byIcon(Icons.search)),
    ],
    unset: [0, 1],
    set: _Side(
      'set',
      (r) => const _Props(
        searchBoxIcon: Icon(
          Icons.travel_explore,
          key: ValueKey('search-icon-sentinel'),
        ),
      ),
      [1, 0],
    ),
  ),
  _Row(
    'searchPadding',
    'insets the search box',
    hideSearch: false,
    probe: (t, r) => [
      t
          .widget<Padding>(
            find
                .ancestor(
                  of: find.byType(TextField),
                  matching: find.byType(Padding),
                )
                .first,
          )
          .padding,
      t.getTopLeft(find.byType(TextField)).dx,
    ],
    unset: [const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 16.0],
    set: _Side(
      'set',
      (r) => const _Props(searchPadding: EdgeInsets.fromLTRB(3, 5, 7, 9)),
      [const EdgeInsets.fromLTRB(3, 5, 7, 9), 3.0],
    ),
  ),
  _Row(
    'searchContentPadding',
    'pads the text inside the search box; the end inset narrows it',
    hideSearch: false,
    // With a prefix icon the framework drops the start inset and centres
    // the text in the 40 px box, so the end inset is the one that shows.
    probe: (t, r) => [
      _searchField(t).decoration?.contentPadding,
      t.getSize(find.byType(EditableText)).width,
    ],
    unset: [const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 700.0],
    set: _Side(
      'set',
      (r) =>
          const _Props(searchContentPadding: EdgeInsets.fromLTRB(21, 2, 30, 4)),
      [const EdgeInsets.fromLTRB(21, 2, 30, 4), 682.0],
    ),
  ),
  _Row(
    'onSearchTap',
    'fires when the editable search box is tapped',
    hideSearch: false,
    act: (t, r) async {
      await t.tap(find.byType(TextField));
      await t.pump();
    },
    probe: (t, r) => r.searchTaps,
    unset: 0,
    set: _Side('set', (r) => _Props(onSearchTap: () => r.searchTaps++), 1),
  ),
  _Row(
    'onSearchTap',
    'fires when the read-only search box is tapped',
    hideSearch: false,
    searchReadOnly: true,
    act: (t, r) async {
      await t.tap(find.byType(TextField));
      await t.pump();
    },
    probe: (t, r) => r.searchTaps,
    unset: 0,
    set: _Side('set', (r) => _Props(onSearchTap: () => r.searchTaps++), 1),
  ),

  // ── Scrolling and routing ─────────────────────────────────────────────────
  _Row(
    'scrollController',
    'is attached to the conversation list and scrolls it',
    state: _many,
    act: (t, r) async {
      if (r.controller.hasClients) r.controller.jumpTo(240);
      await t.pump();
    },
    probe: (t, r) => [
      r.controller.hasClients,
      t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels,
    ],
    unset: [false, 0.0],
    set: _Side('set', (r) => _Props(scrollController: r.controller), [
      true,
      240.0,
    ]),
  ),
  _Row(
    'routeObserver',
    'freezes the list while another route covers it',
    title: 'Before-7R',
    act: (t, r) async {
      unawaited(
        r.navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('cover-7R')),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      // A parent rebuild hands the covered widget a new title.
      r.title = 'After-7R';
      r.rebuild!(() {});
      await t.pump();
    },
    // Whether the widget subscribed to its route, and which title the
    // covered (offstage) list now shows.
    probe: (t, r) => [
      r.observer.debugObservingRoute(ModalRoute.of<void>(_ctx(t))!),
      _count(find.text('After-7R', skipOffstage: false)),
      _count(find.text('Before-7R', skipOffstage: false)),
    ],
    unset: [false, 1, 0],
    set: _Side('set', (r) => _Props(routeObserver: r.observer), [true, 0, 1]),
  ),
  _Row(
    'routeObserver',
    'is unsubscribed from when the widget is disposed',
    act: (t, r) async {
      r.route = ModalRoute.of<void>(_ctx(t));
      r.observedBeforeDispose = r.observer.debugObservingRoute(r.route!);
      r.gone = true;
      r.rebuild!(() {});
      await t.pump();
    },
    // Subscribed while mounted; still subscribed once disposed; widgets left.
    probe: (t, r) => [
      r.observedBeforeDispose,
      r.observer.debugObservingRoute(r.route!),
      _count(find.byType(CometChatConversations, skipOffstage: false)),
    ],
    unset: [false, false, 0],
    set: _Side('set', (r) => _Props(routeObserver: r.observer), [
      true,
      false,
      0,
    ]),
  ),

  // ── conversationsStyle, through each widget that paints it ────────────────
  _Row(
    'conversationsStyle',
    'titleTextColor colours the app bar title',
    probe: (t, r) => t
        .widget<Text>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(_tr(t).chats),
          ),
        )
        .style
        ?.color,
    unset: _FromTheme((p, s) => p.textPrimary),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          titleTextColor: _kTitle,
        ),
      ),
      _kTitle,
    ),
  ),
  _Row(
    'conversationsStyle',
    'backgroundColor paints the screen and every row',
    probe: (t, r) => [
      t
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(CometChatListBase),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      _box(t, CometChatConversationListItem).color,
    ],
    unset: _FromTheme((p, s) => [p.background1, p.background1]),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          backgroundColor: _kBackground,
        ),
      ),
      [_kBackground, _kBackground],
    ),
  ),
  _Row(
    'conversationsStyle',
    'backIconColor colours the back arrow',
    showBackButton: true,
    probe: (t, r) => _iconColor(t, Icons.arrow_back),
    unset: _FromTheme((p, s) => p.iconPrimary),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          backIconColor: _kBackIcon,
        ),
      ),
      _kBackIcon,
    ),
  ),
  _Row(
    'conversationsStyle',
    'backIconColor tints a custom back button that sets no colour',
    // CometChatListBase wraps the back button in an IconButton coloured
    // with backIconTint (cometchat_conversations.dart 631).
    showBackButton: true,
    backButton: const Icon(Icons.close),
    probe: (t, r) => _glyphColor(t, Icons.close),
    unset: _FromTheme((p, s) => p.iconPrimary),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          backIconColor: _kBackIcon,
        ),
      ),
      _kBackIcon,
    ),
  ),
  _Row(
    'conversationsStyle',
    'searchBackgroundColor and searchIconColor paint the search box',
    hideSearch: false,
    probe: (t, r) => [
      _searchField(t).decoration?.fillColor,
      _iconColor(t, Icons.search),
    ],
    unset: _FromTheme((p, s) => [p.background3, p.iconSecondary]),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          searchBackgroundColor: _kSearchFill,
          searchIconColor: _kSearchIcon,
        ),
      ),
      [_kSearchFill, _kSearchIcon],
    ),
  ),
  _Row(
    'conversationsStyle',
    'separatorColor and separatorHeight draw the app bar rule',
    probe: (t, r) {
      final rule =
          (t.widget<AppBar>(find.byType(AppBar)).shape! as Border).bottom;
      return [rule.color, rule.width];
    },
    unset: _FromTheme((p, s) => [p.borderLight, 1.0]),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          separatorColor: _kSeparator,
          separatorHeight: 2.5,
        ),
      ),
      [_kSeparator, 2.5],
    ),
  ),
  _Row(
    'conversationsStyle',
    'submitIconColor colours the selection check',
    state: _selected,
    probe: (t, r) => _iconColor(t, Icons.check),
    unset: _FromTheme((p, s) => p.iconPrimary),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          submitIconColor: _kSubmit,
        ),
      ),
      _kSubmit,
    ),
  ),
  _Row(
    'conversationsStyle',
    'itemTitleTextColor colours each conversation name',
    probe: (t, r) => t.widget<Text>(find.text('Alice')).style?.color,
    unset: _FromTheme((p, s) => p.textPrimary),
    set: _Side(
      'set',
      (r) => const _Props(
        conversationsStyle: CometChatConversationsStyle(
          itemTitleTextColor: _kItemTitle,
        ),
      ),
      _kItemTitle,
    ),
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

// ─── Options and sound helpers ───────────────────────────────────────────────

const _kOption = 'Archive 7Q';
const _kCustomSound = 'sounds/ping_7Q.mp3';

/// The kit's incoming-message sound, as the platform receives it off Android.
const _kIncomingSound = 'assets/sound/incoming_message.wav';

/// The sound paths the kit asked the platform to play, oldest first.
final _sounds = <String?>[];

/// The platform channel SoundManager plays through.
const _soundChannel = MethodChannel('cometchat_chat_uikit');

List<String> _menuLabels(WidgetTester tester) => tester
    .widgetList<MenuItemButton>(find.byType(MenuItemButton))
    .map((b) => (b.child! as Text).data!)
    .toList();

/// Long-presses Alice, records the menu, then taps the custom entry if the
/// menu has one.
Future<void> _openAliceMenuAndTapOption(WidgetTester tester, _Rec rec) async {
  await tester.longPress(find.text('Alice'));
  await tester.pump(); // the list marks the row open
  await tester.pump(); // post-frame: the MenuController opens
  await tester.pump(const Duration(milliseconds: 300));
  rec.menu = _menuLabels(tester);
  final custom = find.widgetWithText(MenuItemButton, _kOption);
  if (custom.evaluate().isNotEmpty) {
    await tester.tap(custom);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// The fill CometChatDate paints behind Alice's timestamp.
Color? _dateFill(WidgetTester tester) =>
    (tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(CometChatDate).first,
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration)
        .color;

/// Bob sends the signed-in user a message over the fake socket.
Future<void> _receiveFromBob(WidgetTester tester, _Rec rec) async {
  _sounds.clear();
  rec.backend!.messages.add(
    TextMessage(
      text: 'ping 7Q',
      id: 301,
      sender: User(uid: 'u2', name: 'Bob', status: 'offline'),
      receiverUid: 'me',
      type: 'text',
      receiverType: 'user',
      category: 'message',
      sentAt: DateTime(2026, 5, 12, 10, 50),
      conversationId: 'user_u2',
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  User? previousUser;

  setUp(() {
    previousUser = CometChatUIKit.loggedInUser;
    _sounds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_soundChannel, (call) async {
          if (call.method == 'playCustomSound') {
            _sounds.add((call.arguments as Map)['assetAudioPath'] as String?);
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_soundChannel, null);
    CometChatUIKit.loggedInUser = previousUser;
    await sdk.SdkRegistry.clear();
  });

  group('CometChatConversations remaining prop matrix', () {
    for (final row in _matrix) {
      testWidgets('${row.prop}: ${row.claim}', (tester) async {
        final sides = [_Side.unset(row.unset), row.set, ...row.more];
        final readings = <String, Object?>{};

        for (final side in sides) {
          final rec = _Rec(row.title);
          addTearDown(rec.dispose);
          final p = side.props(rec);

          ConversationsBloc? bloc;
          if (row.sdk) {
            final backend = rec.backend = _Backend();
            addTearDown(backend.close);
            await sdk.SdkRegistry.clear();
            sdk.SdkRegistry.register(_FakeSdkClient(backend));
            // Login is what wires CometChat's listener maps to the fake's
            // realtime streams.
            // ignore: deprecated_member_use
            await CometChat.login(
              'me',
              'test-key',
              onSuccess: null,
              onError: null,
            );
          } else {
            final state = row.state();
            final mock = _MockConversationsBloc(row.typing);
            whenListen(
              mock,
              Stream<ConversationsState>.value(state),
              initialState: state,
            );
            bloc = mock;
          }
          if (row.signedIn) {
            CometChatUIKit.loggedInUser = row.sdk ? _sdkMe : _me;
          }

          await mockNetworkImagesFor(
            () => tester.pumpWidget(
              _app(
                rec,
                side.label,
                StatefulBuilder(
                  builder: (context, setState) {
                    rec.rebuild = setState;
                    if (rec.gone) return const SizedBox();
                    return side.bare
                        ? CometChatConversations(
                            conversationsBloc: bloc,
                            title: rec.title,
                            hideSearch: row.hideSearch,
                            searchReadOnly: row.searchReadOnly,
                            showBackButton: row.showBackButton,
                            backButton: row.backButton,
                            onItemTap: rec.tap,
                          )
                        : CometChatConversations(
                            conversationsBloc: bloc,
                            title: rec.title,
                            hideSearch: row.hideSearch,
                            searchReadOnly: row.searchReadOnly,
                            showBackButton: row.showBackButton,
                            backButton: row.backButton,
                            onItemTap: rec.tap,
                            avatarMargin: p.avatarMargin,
                            avatarPadding: p.avatarPadding,
                            badgePadding: p.badgePadding,
                            conversationsProtocol: p.conversationsProtocol,
                            conversationsRequestBuilder:
                                p.conversationsRequestBuilder,
                            conversationsStyle:
                                p.conversationsStyle ??
                                const CometChatConversationsStyle(),
                            dateHeight: p.dateHeight,
                            datePadding: p.datePadding,
                            datePattern: p.datePattern,
                            dateTimeFormatterCallback:
                                p.dateTimeFormatterCallback,
                            dateWidth: p.dateWidth,
                            deliveredIcon: p.deliveredIcon,
                            groupTypeVisibility: p.groupTypeVisibility,
                            leadingView: p.leadingView,
                            onSearchTap: p.onSearchTap,
                            readIcon: p.readIcon,
                            receiptsVisibility: p.receiptsVisibility,
                            routeObserver: p.routeObserver,
                            scrollController: p.scrollController,
                            searchBoxIcon: p.searchBoxIcon,
                            searchContentPadding: p.searchContentPadding,
                            searchPadding: p.searchPadding,
                            sentIcon: p.sentIcon,
                            statusIndicatorBorderRadius:
                                p.statusIndicatorBorderRadius,
                            statusIndicatorHeight: p.statusIndicatorHeight,
                            statusIndicatorWidth: p.statusIndicatorWidth,
                            submitIcon: p.submitIcon,
                            textFormatters: p.textFormatters,
                            titleView: p.titleView,
                            typingIndicatorText: p.typingIndicatorText,
                            usersStatusVisibility: p.usersStatusVisibility,
                            setOptions: p.setOptions,
                            addOptions: p.addOptions,
                            dateBackgroundIsTransparent:
                                p.dateBackgroundIsTransparent,
                            customSoundForMessages: p.customSoundForMessages,
                            disableSoundForMessages: p.disableSoundForMessages,
                          );
                  },
                ),
              ),
            ),
          );
          await tester.pump();
          if (row.sdk) {
            // The widget's own bloc: logged-in user, then the fetch.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 10));
          }
          await row.act?.call(tester, rec);

          final reading = row.probe(tester, rec);
          var expected = side.expected;
          if (expected is _FromTheme) {
            expected = expected.resolve(
              CometChatThemeHelper.getColorPalette(_ctx(tester)),
              CometChatThemeHelper.getSpacing(_ctx(tester)),
            );
          }
          expect(reading, expected, reason: '${row.prop}, ${side.label} side');
          readings[side.label] = reading;
        }

        expect(
          readings[row.set.label],
          isNot(equals(readings['unset'])),
          reason: '${row.prop} must render differently from its default',
        );

        // Unmount, so the widget's bloc closes and its route unsubscribes.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  });

  test('every wired prop has a row, and every row sets the prop it names', () {
    final rec = _Rec(null);
    addTearDown(rec.dispose);

    expect({for (final row in _matrix) row.prop}, _Props.wired);
    for (final row in _matrix) {
      expect(
        row.set.props(rec).setNames,
        contains(row.prop),
        reason: row.claim,
      );
      for (final side in row.more) {
        if (side.label == 'null') {
          expect(
            side.props(rec).setNames,
            isNot(contains(row.prop)),
            reason: row.claim,
          );
        }
      }
    }
  });
}
