/// Render-verified prop matrix for [CometChatSearch] — Track 3 PROP1
/// (ENG-38688, coverage part 2).
///
/// Unlike CometChatConversations and CometChatUsers, CometChatSearch has no
/// bloc parameter: it builds its own SearchBloc in initState, and that bloc
/// reaches the network through ConversationsRequest.fetchNext and
/// MessagesRequest.fetchPrevious. So this matrix runs the real widget and the
/// real bloc, and fakes one layer further down: the two SDK repositories those
/// requests resolve through SdkRegistry. Everything between the prop and the
/// pixel is production code.
///
/// Each case renders twice in one test body — first with its prop unset, then
/// set — and asserts both observations and that they differ. A widget that
/// ignored the prop would render the baseline twice and fail the case.
///
/// 35 props are in scope and 34 are wired here. One is a defect, deliberately
/// left off the construction so the coverage tool does not credit it:
///
///   receiptsVisibility              declared and never read. Neither the
///                                   conversation subtitle nor the message row
///                                   renders a receipt at all.
///
///   flutter test test/chat_ui/search/widget/search_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these. They are the seam CometChatSearch leaves:
// no bloc injection, so the fake has to sit where the SDK resolves its
// repositories. Identical in the local SDK and in the hosted 5.0.7 CI uses.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────

const _query = 'pasta';
const _rootPage = 'root-page-7Q';
const _errorSentinel = 'search-boom-9';
const _fmt = 'fmt-7Q';
const _backKey = ValueKey('back-7Q');
const _clearKey = ValueKey('clear-7Q');

const _defaultChips = [
  'Unread',
  'Groups',
  'Photos',
  'Videos',
  'Audio',
  'Documents',
  'Links',
];
const _messageChips = ['Photos', 'Videos', 'Audio', 'Documents', 'Links'];

const _bg = Color(0xFF1A2B3C);
const _fill = Color(0xFF2B3C4D);
const _backTint = Color(0xFF3C4D5E);
const _titleInk = Color(0xFF4D5E6F);
const _chipFill = Color(0xFF5E6F70);
const _senderInk = Color(0xFF6F7081);

// ─── SDK fakes ───────────────────────────────────────────────────────────────

enum _Seed { results, empty, error }

/// What the fake repositories answer with, and what they were asked.
class _FakeBackend {
  _Seed seed = _Seed.results;
  int conversationFetches = 0;
  List<String>? conversationTags;
  bool? conversationWithTags;
  String? messageTarget;
  List<String>? messageTypes;
  List<String>? messageCategories;

  void reset(_Seed next) {
    seed = next;
    conversationFetches = 0;
    conversationTags = null;
    conversationWithTags = null;
    messageTarget = null;
    messageTypes = null;
    messageCategories = null;
  }

  Future<sdk.ConversationsResult> conversations(Invocation call) {
    conversationFetches++;
    conversationTags = call.namedArguments[#tags] as List<String>?;
    conversationWithTags = call.namedArguments[#withTags] as bool?;
    switch (seed) {
      case _Seed.error:
        return Future<sdk.ConversationsResult>.error(
          StateError(_errorSentinel),
        );
      case _Seed.empty:
        return Future.value(
          const sdk.ConversationsResult(conversations: [], hasMore: false),
        );
      case _Seed.results:
        return Future.value(
          sdk.ConversationsResult(
            conversations: _conversations(),
            hasMore: false,
          ),
        );
    }
  }

  Future<sdk.MessagesResult> messages(Invocation call, String target) {
    messageTarget = target;
    messageTypes = call.namedArguments[#types] as List<String>?;
    messageCategories = call.namedArguments[#categories] as List<String>?;
    switch (seed) {
      case _Seed.error:
        return Future<sdk.MessagesResult>.error(StateError(_errorSentinel));
      case _Seed.empty:
        return Future.value(
          const sdk.MessagesResult(messages: [], hasMore: false),
        );
      case _Seed.results:
        return Future.value(
          sdk.MessagesResult(messages: _messages(), hasMore: false),
        );
    }
  }
}

/// Answers getConversations through noSuchMethod, so the fake does not have to
/// restate the repository's fifteen named parameters.
class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  _FakeConversationRepository(this._backend);

  final _FakeBackend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getConversations) {
      return _backend.conversations(invocation);
    }
    return super.noSuchMethod(invocation);
  }
}

/// fetchPrevious routes to getMessages with no scope, getUserMessages with a
/// uid, and getGroupMessages with a guid. The target records which one ran.
class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  _FakeMessageRepository(this._backend);

  final _FakeBackend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getMessages) {
      return _backend.messages(invocation, 'all');
    }
    if (name == #getUserMessages) {
      return _backend.messages(
        invocation,
        'uid:${invocation.positionalArguments.first}',
      );
    }
    if (name == #getGroupMessages) {
      return _backend.messages(
        invocation,
        'guid:${invocation.positionalArguments.first}',
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(_FakeBackend backend)
    : conversations = _FakeConversationRepository(backend),
      messages = _FakeMessageRepository(backend);

  @override
  final sdk.ConversationRepository conversations;

  @override
  final sdk.MessageRepository messages;

  @override
  Future<void> dispose() async {}
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _sentAt = DateTime(2026, 3, 14, 9, 30);

/// An online user with an unread text, and a private group with no last
/// message. The first carries the presence dot, the second the group badge.
List<Conversation> _conversations() => [
  Conversation(
    conversationId: 'user_u-alice',
    conversationType: ReceiverTypeConstants.user,
    conversationWith: User(
      uid: 'u-alice',
      name: 'Alice',
      status: UserStatusConstants.online,
    ),
    lastMessage: TextMessage(
      id: 11,
      text: 'lunch at noon?',
      sender: User(uid: 'u-alice', name: 'Alice'),
      receiverUid: 'u-me',
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
      category: MessageCategoryConstants.message,
      sentAt: _sentAt,
    ),
    unreadMessageCount: 2,
  ),
  Conversation(
    conversationId: 'group_g-design',
    conversationType: ReceiverTypeConstants.group,
    conversationWith: Group(
      guid: 'g-design',
      name: 'Design Crew',
      type: GroupTypeConstants.private,
    ),
  ),
];

/// One message per slot, each from a different sender so every default row
/// has a title of its own to look for.
List<BaseMessage> _messages() => [
  TextMessage(
    id: 101,
    text: 'pasta recipe',
    sender: User(uid: 'u-bob', name: 'Bob'),
    receiverUid: 'u-me',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.user,
    category: MessageCategoryConstants.message,
    sentAt: _sentAt,
  ),
  _media(102, MessageTypeConstants.image, 'Cara'),
  _media(103, MessageTypeConstants.video, 'Dev'),
  _media(104, MessageTypeConstants.file, 'Eve'),
  _media(105, MessageTypeConstants.audio, 'Finn'),
];

/// No attachment, so image and video rows fall back to a date rather than
/// loading a thumbnail.
MediaMessage _media(int id, String type, String sender) => MediaMessage(
  id: id,
  type: type,
  sender: User(uid: 'u-${sender.toLowerCase()}', name: sender),
  receiverUid: 'u-me',
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
);

/// Every branch CometChatDate can take returns the sentinel, so the assertion
/// does not depend on how old the fixture timestamps are.
class _SentinelFormatter extends DateTimeFormatterCallback {
  @override
  String? time(int? timestamp) => _fmt;
  @override
  String? today(int? timestamp) => _fmt;
  @override
  String? yesterday(int? timestamp) => _fmt;
  @override
  String? lastWeek(int? timestamp) => _fmt;
  @override
  String? otherDays(int? timestamp) => _fmt;
}

// ─── Matrix plumbing ─────────────────────────────────────────────────────────

/// What the callbacks under test reported.
class _Log {
  int backs = 0;
  int empties = 0;
  final errors = <String>[];
  final conversationLoads = <List<String?>>[];
  final messageLoads = <List<int>>[];
  final clickedConversations = <String?>[];
  final clickedMessages = <int>[];
}

/// The props a case can set. Every field defaults to null, which for
/// CometChatSearch is the same as not passing it.
class _Props {
  const _Props({
    this.onBack,
    this.onConversationClicked,
    this.onMessageClicked,
    this.onEmpty,
    this.onError,
    this.onMessagesLoad,
    this.onConversationsLoad,
    this.searchFilters,
    this.searchIn,
    this.user,
    this.group,
    this.searchStyle,
    this.searchBackIcon,
    this.searchClearIcon,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.initialStateView,
    this.conversationItemView,
    this.conversationTitleView,
    this.conversationLeadingView,
    this.conversationSubtitleView,
    this.conversationTailView,
    this.usersStatusVisibility,
    this.groupTypeVisibility,
    this.timeSeparatorFormatterCallback,
    this.dateSeparatorFormatterCallback,
    this.searchTextMessageView,
    this.searchImageMessageView,
    this.searchVideoMessageView,
    this.searchFileMessageView,
    this.searchAudioMessageView,
    this.conversationsRequestBuilder,
    this.messagesRequestBuilder,
  });

  final VoidCallback? onBack;
  final Function(Conversation conversation)? onConversationClicked;
  final Function(BaseMessage message)? onMessageClicked;
  final OnEmpty? onEmpty;
  final OnError? onError;
  final OnLoad<BaseMessage>? onMessagesLoad;
  final OnLoad<Conversation>? onConversationsLoad;
  final List<SearchFilter>? searchFilters;
  final List<SearchScope>? searchIn;
  final User? user;
  final Group? group;
  final CometChatSearchStyle? searchStyle;
  final Widget? searchBackIcon;
  final Widget? searchClearIcon;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final WidgetBuilder? initialStateView;
  final Widget? Function(BuildContext, Conversation)? conversationItemView;
  final Widget? Function(BuildContext, Conversation)? conversationTitleView;
  final Widget? Function(BuildContext, Conversation)? conversationLeadingView;
  final Widget? Function(BuildContext, Conversation)? conversationSubtitleView;
  final Widget? Function(BuildContext, Conversation)? conversationTailView;
  final bool? usersStatusVisibility;
  final bool? groupTypeVisibility;
  final DateTimeFormatterCallback? timeSeparatorFormatterCallback;
  final DateTimeFormatterCallback? dateSeparatorFormatterCallback;
  final Widget? Function(BuildContext, TextMessage)? searchTextMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchImageMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchVideoMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchFileMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchAudioMessageView;
  final ConversationsRequestBuilder? conversationsRequestBuilder;
  final MessagesRequestBuilder? messagesRequestBuilder;
}

/// How far to take the search before observing.
enum _Drive {
  /// Nothing typed: the initial state.
  none,

  /// Typed, debounce still pending: both sections loading.
  loading,

  /// Typed and the fake repositories have answered.
  settled,
}

enum _Run { baseline, subject }

typedef _Observe =
    Future<Object?> Function(WidgetTester t, _Log log, _FakeBackend backend);

class _Case {
  const _Case({
    required this.prop,
    required this.effect,
    required this.subject,
    required this.observe,
    required this.baseline,
    required this.expected,
    this.seed = _Seed.results,
    this.drive = _Drive.settled,
  });

  final String prop;
  final String effect;
  final _Props Function(_Log log) subject;
  final _Observe observe;

  /// Value or matcher for the observation with the prop unset.
  final Object? baseline;

  /// Value or matcher for the observation with the prop set.
  final Object? expected;
  final _Seed seed;
  final _Drive drive;
}

/// Opens search as a pushed route over a root page, so the default back
/// behaviour (a pop) has somewhere observable to land.
Widget _wrap(Widget search) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  onGenerateRoute: (_) =>
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
  onGenerateInitialRoutes: (_) => [
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text(_rootPage)),
    ),
    MaterialPageRoute<void>(builder: (_) => search),
  ],
);

Future<void> _drive(WidgetTester tester, _Drive drive) async {
  await tester.pump();
  if (drive == _Drive.none) return;
  await tester.enterText(find.byType(TextField), _query);
  await tester.pump();
  if (drive == _Drive.loading) return;
  // Past the bloc's 500ms debounce, then let the fetches resolve and rebuild.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  await tester.pump();
}

int _count(Finder finder) => finder.evaluate().length;

List<String> _textsStartingWith(WidgetTester t, String prefix) =>
    t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .whereType<String>()
        .where((s) => s.startsWith(prefix))
        .toList()
      ..sort();

List<String> _chipLabels(WidgetTester t) => t
    .widgetList<SearchFilterChip>(find.byType(SearchFilterChip))
    .map((c) => c.label)
    .toList();

TextField _field(WidgetTester t) => t.widget<TextField>(find.byType(TextField));

// ─── The matrix ──────────────────────────────────────────────────────────────

final _matrix = <_Case>[
  // ── Search bar ──────────────────────────────────────────────────────────
  _Case(
    prop: 'onBack',
    effect: 'replaces the default pop',
    drive: _Drive.none,
    subject: (log) => _Props(onBack: () => log.backs++),
    observe: (t, log, _) async {
      await t.tap(find.byIcon(Icons.arrow_back));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      return [log.backs, _count(find.byType(CometChatSearch))];
    },
    // Unset, the tap pops search off and the root page is all that is left.
    baseline: [0, 0],
    expected: [1, 1],
  ),
  _Case(
    prop: 'searchBackIcon',
    effect: 'replaces the arrow in the search field, which still goes back',
    drive: _Drive.none,
    subject: (_) => const _Props(
      searchBackIcon: Icon(Icons.keyboard_double_arrow_left, key: _backKey),
    ),
    observe: (t, _, _) async {
      final shown = [
        _count(
          find.descendant(
            of: find.byType(TextField),
            matching: find.byKey(_backKey),
          ),
        ),
        _count(find.byIcon(Icons.arrow_back)),
      ];
      // The custom icon has to be the back tap target, not merely rendered:
      // tapping it must pop search and uncover the root page.
      final custom = find.byKey(_backKey);
      await t.tap(
        custom.evaluate().isNotEmpty ? custom : find.byIcon(Icons.arrow_back),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      return [
        ...shown,
        _count(find.byType(CometChatSearch)),
        _count(find.text(_rootPage)),
      ];
    },
    baseline: [0, 1, 0, 1],
    expected: [1, 0, 0, 1],
  ),
  _Case(
    prop: 'searchClearIcon',
    effect: 'replaces the clear affordance, which still clears',
    subject: (_) =>
        const _Props(searchClearIcon: Icon(Icons.backspace, key: _clearKey)),
    observe: (t, _, _) async {
      final shown = [
        _count(find.byKey(_clearKey)),
        _count(find.byIcon(Icons.close)),
      ];
      final custom = find.byKey(_clearKey);
      await t.tap(
        custom.evaluate().isNotEmpty ? custom : find.byIcon(Icons.close),
      );
      await t.pump();
      return [...shown, _field(t).controller?.text];
    },
    baseline: [0, 1, ''],
    expected: [1, 0, ''],
  ),
  _Case(
    prop: 'user',
    effect: 'scopes the hint and the message request to that user',
    subject: (_) => _Props(
      user: User(uid: 'u-scope-7Q', name: 'Priya'),
    ),
    observe: (t, _, b) async => [
      _field(t).decoration?.hintText,
      b.messageTarget,
    ],
    baseline: [isNot(contains('Priya')), 'all'],
    expected: [endsWith(' in Priya'), 'uid:u-scope-7Q'],
  ),
  _Case(
    prop: 'group',
    effect: 'scopes the hint and the message request to that group',
    subject: (_) => _Props(
      group: Group(
        guid: 'g-scope-7Q',
        name: 'Hiking Club',
        type: GroupTypeConstants.public,
      ),
    ),
    observe: (t, _, b) async => [
      _field(t).decoration?.hintText,
      b.messageTarget,
    ],
    baseline: [isNot(contains('Hiking Club')), 'all'],
    expected: [endsWith(' in Hiking Club'), 'guid:g-scope-7Q'],
  ),

  // ── Filters and scope ───────────────────────────────────────────────────
  _Case(
    prop: 'searchFilters',
    effect: 'replaces the default chips',
    drive: _Drive.none,
    subject: (_) => const _Props(
      searchFilters: [
        SearchFilter(label: 'Starred-7Q', group: 2, icon: Icons.star),
      ],
    ),
    observe: (t, _, _) async => [
      _chipLabels(t),
      _count(find.byIcon(Icons.star)),
    ],
    baseline: [_defaultChips, 0],
    expected: [
      ['Starred-7Q'],
      1,
    ],
  ),
  _Case(
    prop: 'searchIn',
    effect: 'messages-only drops conversation chips, rows and requests',
    subject: (_) => const _Props(searchIn: [SearchScope.messages]),
    observe: (t, _, b) async => [
      _chipLabels(t),
      _count(find.text('Alice')),
      _count(find.text('Bob')),
      b.conversationFetches,
    ],
    baseline: [_defaultChips, 1, 1, 1],
    expected: [_messageChips, 0, 1, 0],
  ),

  // ── Request builders ────────────────────────────────────────────────────
  _Case(
    prop: 'conversationsRequestBuilder',
    effect: 'its tags reach the conversations request',
    subject: (_) => _Props(
      conversationsRequestBuilder: ConversationsRequestBuilder()
        ..tags = ['vip-7Q']
        ..withTags = true,
    ),
    observe: (t, _, b) async => [b.conversationTags, b.conversationWithTags],
    // Unset, the bloc's fresh builder sends no tags and withTags false.
    baseline: [null, false],
    expected: [
      ['vip-7Q'],
      true,
    ],
  ),
  _Case(
    prop: 'messagesRequestBuilder',
    effect: 'its types and categories reach the messages request',
    subject: (_) => _Props(
      messagesRequestBuilder: MessagesRequestBuilder()
        ..types = ['custom-7Q']
        ..categories = ['custom'],
    ),
    observe: (t, _, b) async => [b.messageTypes, b.messageCategories],
    // Unset, the bloc widens the request so card messages are searchable.
    baseline: [
      [
        MessageTypeConstants.text,
        MessageTypeConstants.image,
        MessageTypeConstants.video,
        MessageTypeConstants.audio,
        MessageTypeConstants.file,
        MessageTypeConstants.card,
      ],
      [MessageCategoryConstants.message, MessageCategoryConstants.card],
    ],
    expected: [
      ['custom-7Q'],
      ['custom'],
    ],
  ),

  // ── State views ─────────────────────────────────────────────────────────
  _Case(
    prop: 'initialStateView',
    effect: 'renders before anything is typed',
    drive: _Drive.none,
    subject: (_) => _Props(initialStateView: (_) => const Text('initial-7Q')),
    observe: (t, _, _) async => _count(find.text('initial-7Q')),
    baseline: 0,
    expected: 1,
  ),
  _Case(
    prop: 'loadingStateView',
    effect: 'replaces the shimmer while both sections load',
    drive: _Drive.loading,
    subject: (_) => _Props(loadingStateView: (_) => const Text('loading-7Q')),
    observe: (t, _, _) async => [
      _count(find.text('loading-7Q')),
      _count(find.byType(CometChatShimmerEffect)),
    ],
    baseline: [0, 1],
    expected: [1, 0],
  ),
  _Case(
    prop: 'emptyStateView',
    effect: 'replaces the empty illustration',
    seed: _Seed.empty,
    subject: (_) => _Props(emptyStateView: (_) => const Text('empty-7Q')),
    observe: (t, _, _) async => [
      _count(find.text('empty-7Q')),
      _count(find.byType(Image)),
    ],
    baseline: [0, 1],
    expected: [1, 0],
  ),
  _Case(
    prop: 'errorStateView',
    effect: 'replaces the error view',
    seed: _Seed.error,
    subject: (_) => _Props(errorStateView: (_) => const Text('error-7Q')),
    observe: (t, _, _) async => [
      _count(find.text('error-7Q')),
      _count(find.byIcon(Icons.error_outline_rounded)),
    ],
    baseline: [0, 1],
    expected: [1, 0],
  ),

  // ── State callbacks ─────────────────────────────────────────────────────
  _Case(
    prop: 'onEmpty',
    effect: 'fires once when both sections settle empty',
    seed: _Seed.empty,
    subject: (log) => _Props(onEmpty: () => log.empties++),
    observe: (t, log, _) async => log.empties,
    baseline: 0,
    expected: 1,
  ),
  _Case(
    prop: 'onError',
    effect: 'fires once, carrying the failure',
    seed: _Seed.error,
    subject: (log) => _Props(onError: (e) => log.errors.add(e.toString())),
    observe: (t, log, _) async => log.errors.toList(),
    baseline: isEmpty,
    expected: [contains(_errorSentinel)],
  ),
  _Case(
    prop: 'onConversationsLoad',
    effect: 'fires once with the loaded conversations',
    subject: (log) => _Props(
      onConversationsLoad: (list) =>
          log.conversationLoads.add(list.map((c) => c.conversationId).toList()),
    ),
    observe: (t, log, _) async => log.conversationLoads.toList(),
    baseline: isEmpty,
    expected: [
      ['user_u-alice', 'group_g-design'],
    ],
  ),
  _Case(
    prop: 'onMessagesLoad',
    effect: 'fires once with the loaded messages',
    subject: (log) => _Props(
      onMessagesLoad: (list) =>
          log.messageLoads.add(list.map((m) => m.id).toList()),
    ),
    observe: (t, log, _) async => log.messageLoads.toList(),
    baseline: isEmpty,
    expected: [
      unorderedEquals([101, 102, 103, 104, 105]),
    ],
  ),

  // ── Row taps ────────────────────────────────────────────────────────────
  _Case(
    prop: 'onConversationClicked',
    effect: 'receives the tapped conversation',
    subject: (log) => _Props(
      onConversationClicked: (c) =>
          log.clickedConversations.add(c.conversationId),
    ),
    observe: (t, log, _) async {
      await t.tap(find.text('Alice'));
      await t.pump();
      return log.clickedConversations.toList();
    },
    baseline: isEmpty,
    expected: ['user_u-alice'],
  ),
  _Case(
    prop: 'onMessageClicked',
    effect: 'receives the tapped message',
    subject: (log) =>
        _Props(onMessageClicked: (m) => log.clickedMessages.add(m.id)),
    observe: (t, log, _) async {
      await t.tap(find.text('Bob'));
      await t.pump();
      return log.clickedMessages.toList();
    },
    baseline: isEmpty,
    expected: [101],
  ),

  // ── Conversation row slots ──────────────────────────────────────────────
  _Case(
    prop: 'conversationItemView',
    effect: 'replaces every conversation row',
    subject: (_) => _Props(
      conversationItemView: (_, c) => Text('item-${c.conversationId}'),
    ),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'item-'),
      _count(find.text('Alice')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['item-group_g-design', 'item-user_u-alice'],
      0,
    ],
  ),
  _Case(
    prop: 'conversationTitleView',
    effect: 'replaces the name',
    subject: (_) => _Props(
      conversationTitleView: (_, c) => Text('title-${c.conversationId}'),
    ),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'title-'),
      _count(find.text('Alice')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['title-group_g-design', 'title-user_u-alice'],
      0,
    ],
  ),
  _Case(
    prop: 'conversationLeadingView',
    effect: 'replaces the avatar',
    subject: (_) => _Props(
      conversationLeadingView: (_, c) => Text('lead-${c.conversationId}'),
    ),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'lead-'),
      _count(find.byType(CometChatAvatar)),
    ],
    baseline: [<String>[], 2],
    expected: [
      ['lead-group_g-design', 'lead-user_u-alice'],
      0,
    ],
  ),
  _Case(
    prop: 'conversationSubtitleView',
    effect: 'replaces the last-message preview',
    subject: (_) => _Props(
      conversationSubtitleView: (_, c) => Text('sub-${c.conversationId}'),
    ),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'sub-'),
      find
          .textContaining('lunch at noon?', findRichText: true)
          .evaluate()
          .isNotEmpty,
    ],
    baseline: [<String>[], true],
    expected: [
      ['sub-group_g-design', 'sub-user_u-alice'],
      false,
    ],
  ),
  _Case(
    prop: 'conversationTailView',
    effect: 'replaces the date and unread badge',
    subject: (_) => _Props(
      conversationTailView: (_, c) => Text('tail-${c.conversationId}'),
    ),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'tail-'),
      _count(find.byType(CometChatBadge)),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['tail-group_g-design', 'tail-user_u-alice'],
      0,
    ],
  ),
  _Case(
    prop: 'usersStatusVisibility',
    effect: 'false drops the presence dot and leaves the group badge',
    subject: (_) => const _Props(usersStatusVisibility: false),
    observe: (t, _, _) async => [
      _count(find.byType(CometChatStatusIndicator)),
      _count(find.byIcon(Icons.shield)),
    ],
    baseline: [2, 1],
    expected: [1, 1],
  ),
  _Case(
    prop: 'groupTypeVisibility',
    effect: 'false drops the private-group badge and leaves the dot',
    subject: (_) => const _Props(groupTypeVisibility: false),
    observe: (t, _, _) async => [
      _count(find.byType(CometChatStatusIndicator)),
      _count(find.byIcon(Icons.shield)),
    ],
    baseline: [2, 1],
    expected: [1, 0],
  ),
  _Case(
    prop: 'timeSeparatorFormatterCallback',
    effect: 'formats every row timestamp',
    subject: (_) =>
        _Props(timeSeparatorFormatterCallback: _SentinelFormatter()),
    // Alice's tail plus all five message rows; the group has no last message.
    observe: (t, _, _) async => _count(find.text(_fmt)),
    baseline: 0,
    expected: 6,
  ),
  _Case(
    prop: 'dateSeparatorFormatterCallback',
    effect: 'formats the month separators',
    subject: (_) =>
        _Props(dateSeparatorFormatterCallback: _SentinelFormatter()),
    // Row timestamps keep their own format; only a separator can show it.
    observe: (t, _, _) async => _count(find.text(_fmt)) > 0,
    baseline: false,
    expected: true,
  ),

  // ── Message row slots ───────────────────────────────────────────────────
  _Case(
    prop: 'searchTextMessageView',
    effect: 'replaces text rows only',
    subject: (_) =>
        _Props(searchTextMessageView: (_, m) => Text('slot-text-${m.id}')),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'slot-'),
      _count(find.text('Bob')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['slot-text-101'],
      0,
    ],
  ),
  _Case(
    prop: 'searchImageMessageView',
    effect: 'replaces image rows only',
    subject: (_) =>
        _Props(searchImageMessageView: (_, m) => Text('slot-image-${m.id}')),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'slot-'),
      _count(find.text('Cara')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['slot-image-102'],
      0,
    ],
  ),
  _Case(
    prop: 'searchVideoMessageView',
    effect: 'replaces video rows only',
    subject: (_) =>
        _Props(searchVideoMessageView: (_, m) => Text('slot-video-${m.id}')),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'slot-'),
      _count(find.text('Dev')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['slot-video-103'],
      0,
    ],
  ),
  _Case(
    prop: 'searchFileMessageView',
    effect: 'replaces file rows only',
    subject: (_) =>
        _Props(searchFileMessageView: (_, m) => Text('slot-file-${m.id}')),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'slot-'),
      _count(find.text('Eve')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['slot-file-104'],
      0,
    ],
  ),
  _Case(
    prop: 'searchAudioMessageView',
    effect: 'replaces audio rows only',
    subject: (_) =>
        _Props(searchAudioMessageView: (_, m) => Text('slot-audio-${m.id}')),
    observe: (t, _, _) async => [
      _textsStartingWith(t, 'slot-'),
      _count(find.text('Finn')),
    ],
    baseline: [<String>[], 1],
    expected: [
      ['slot-audio-105'],
      0,
    ],
  ),

  // ── Style ───────────────────────────────────────────────────────────────
  _Case(
    prop: 'searchStyle',
    effect: 'paints the scaffold, field, chips and both row kinds',
    subject: (_) => const _Props(
      searchStyle: CometChatSearchStyle(
        backgroundColor: _bg,
        searchBackgroundColor: _fill,
        searchBackIconColor: _backTint,
        searchConversationTitleTextColor: _titleInk,
        searchFilterChipBackgroundColor: _chipFill,
        searchMessageSenderTextColor: _senderInk,
      ),
    ),
    observe: (t, _, _) async {
      final scaffold = t.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(CometChatSearch),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      final chip = t.widget<Container>(
        find
            .descendant(
              of: find.byType(SearchFilterChip).first,
              matching: find.byType(Container),
            )
            .first,
      );
      return [
        scaffold.backgroundColor,
        _field(t).decoration?.fillColor,
        t.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
        t.widget<Text>(find.text('Alice')).style?.color,
        (chip.decoration as BoxDecoration?)?.color,
        t.widget<Text>(find.text('Bob')).style?.color,
      ];
    },
    baseline: [
      isNot(_bg),
      isNot(_fill),
      isNot(_backTint),
      isNot(_titleInk),
      isNot(_chipFill),
      isNot(_senderInk),
    ],
    expected: [_bg, _fill, _backTint, _titleInk, _chipFill, _senderInk],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late _FakeBackend backend;

  setUp(() async {
    backend = _FakeBackend();
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(backend));
  });

  tearDown(sdk.SdkRegistry.clear);

  test('the matrix names each of the 34 wired props exactly once', () {
    final props = _matrix.map((c) => c.prop).toList();
    expect(props.toSet(), hasLength(props.length));
    expect(props, hasLength(34));
  });

  group('CometChatSearch prop matrix', () {
    for (final c in _matrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        tester.view.physicalSize = const Size(1000, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final observed = <_Run, Object?>{};
        for (final run in _Run.values) {
          backend.reset(c.seed);
          final log = _Log();
          final p = run == _Run.subject ? c.subject(log) : const _Props();

          // receiptsVisibility is left off on purpose: it is a defect, see the
          // library comment.
          final search = CometChatSearch(
            onBack: p.onBack,
            onConversationClicked: p.onConversationClicked,
            onMessageClicked: p.onMessageClicked,
            onEmpty: p.onEmpty,
            onError: p.onError,
            onMessagesLoad: p.onMessagesLoad,
            onConversationsLoad: p.onConversationsLoad,
            searchFilters: p.searchFilters,
            searchIn: p.searchIn,
            user: p.user,
            group: p.group,
            searchStyle: p.searchStyle,
            searchBackIcon: p.searchBackIcon,
            searchClearIcon: p.searchClearIcon,
            loadingStateView: p.loadingStateView,
            emptyStateView: p.emptyStateView,
            errorStateView: p.errorStateView,
            initialStateView: p.initialStateView,
            conversationItemView: p.conversationItemView,
            conversationTitleView: p.conversationTitleView,
            conversationLeadingView: p.conversationLeadingView,
            conversationSubtitleView: p.conversationSubtitleView,
            conversationTailView: p.conversationTailView,
            usersStatusVisibility: p.usersStatusVisibility,
            groupTypeVisibility: p.groupTypeVisibility,
            timeSeparatorFormatterCallback: p.timeSeparatorFormatterCallback,
            dateSeparatorFormatterCallback: p.dateSeparatorFormatterCallback,
            searchTextMessageView: p.searchTextMessageView,
            searchImageMessageView: p.searchImageMessageView,
            searchVideoMessageView: p.searchVideoMessageView,
            searchFileMessageView: p.searchFileMessageView,
            searchAudioMessageView: p.searchAudioMessageView,
            conversationsRequestBuilder: p.conversationsRequestBuilder,
            messagesRequestBuilder: p.messagesRequestBuilder,
          );

          // A fresh tree per run: the bloc reads most of these in initState.
          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(_wrap(search));
            await _drive(tester, c.drive);
          });
          observed[run] = await c.observe(tester, log, backend);
        }
        await tester.pumpWidget(const SizedBox.shrink());

        expect(
          observed[_Run.baseline],
          c.baseline,
          reason: 'rendered with ${c.prop} unset',
        );
        expect(
          observed[_Run.subject],
          c.expected,
          reason: 'rendered with ${c.prop} set',
        );
        expect(
          observed[_Run.subject],
          isNot(equals(observed[_Run.baseline])),
          reason: 'setting ${c.prop} changed nothing',
        );
      });
    }
  });
}
