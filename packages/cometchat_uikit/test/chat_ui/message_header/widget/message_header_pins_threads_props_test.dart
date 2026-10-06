/// Render-verified prop matrix for the nine [CometChatMessageHeader] props new
/// in 6.1.1 — Track 3 PROP1 (ENG-38688, coverage part 2, round 2).
///
/// The other 28 props are covered by message_header_props_test.dart. These
/// nine drive the three surfaces the header grew in 6.1.1:
///
///   header tap       onHeaderTap
///   overflow menu    onSearchTap, onInfoTap, pinnedMessagesVisibility and
///                    onPinnedMessagesTap, plus pinnedMessagesStyle and
///                    onPinnedMessageItemTap, which the menu forwards to the
///                    pinned-messages screen it pushes
///   thread bell      parentMessage and threadSubscriptionVisibility
///
/// The header takes a mock MessageHeaderBloc through its messageHeaderBloc
/// seam. The pinned-messages screen and the bell have no seam: they reach the
/// SDK through MessagesRequest.fetchPrevious and CometChat.subscribeToThread.
/// So, as in search_props_test.dart, the fake sits one layer down, where the
/// SDK resolves its repositories through SdkRegistry. Everything between the
/// prop and the pixel is production code.
///
/// Each case renders twice in one test body, first with its prop at the
/// constructor default and then set, and asserts both observations and that
/// they differ. A header that ignored the prop would render the baseline twice
/// and fail the case.
///
///   flutter test test/chat_ui/message_header/widget/message_header_pins_threads_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these. They are the seam the pinned-messages screen
// and the thread bell leave: neither takes an injectable data source, so the
// fake has to sit where the SDK resolves its repositories. All four files
// exist in the local SDK and in the hosted 5.0.7.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/threads/thread_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────

const _peerName = 'Bob 7Q';
const _rootId = 7301;
const _secondRootId = 7303;
const _pinnedId = 7302;
const _pinnedText = 'pinned-7Q body';

const _sheetBackground = Color(0xFF1A2B3C);
const _sheetBackIcon = Color(0xFF2B3C4D);
const _sheetTitleInk = Color(0xFF3C4D5E);
const _sheetTitleSize = 27.5;
const _sheetRule = Color(0xFF4D5E6F);

// Localized copy the probes look for (TranslationsEn).
const _searchEntry = 'Search';
const _pinnedEntry = 'Pinned Messages';
const _userInfoEntry = 'User Info';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(uid: 'me-7Q', name: 'Me 7Q');
final _peer = User(uid: 'u-bob-7Q', name: _peerName);
final _sentAt = DateTime(2026, 3, 14, 9, 30);

/// The thread root the bell acts on. Built fresh for every run, because a
/// successful toggle stamps threadSubscribed onto the message object.
TextMessage _root() => TextMessage(
  id: _rootId,
  text: 'root-7Q',
  sender: _peer,
  receiverUid: _me.uid,
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
)..threadSubscribed = true;

/// The one pin the fake server holds for this conversation.
TextMessage _pinned() => TextMessage(
  id: _pinnedId,
  text: _pinnedText,
  sender: _peer,
  receiverUid: _me.uid,
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
);

class _MockMessageHeaderBloc
    extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

_MockMessageHeaderBloc _headerBloc() {
  final state = MessageHeaderState(
    status: MessageHeaderStatus.loaded,
    user: _peer,
  );
  final bloc = _MockMessageHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

// ─── SDK fakes ───────────────────────────────────────────────────────────────

/// What the fake repositories were asked. Fresh for every run.
class _FakeBackend {
  final pinFetches = <String>[];
  final threadCalls = <String>[];

  Future<sdk.MessagesResult> pinnedPage(Invocation call) {
    pinFetches.add(
      'uid:${call.positionalArguments.first} '
      'pinned:${call.namedArguments[#pinned]}',
    );
    return Future.value(
      sdk.MessagesResult(messages: [_pinned()], hasMore: false),
    );
  }
}

/// The pinned-messages screen scopes its fetch to the header's user, so
/// fetchPrevious routes to getUserMessages. Answered through noSuchMethod so
/// the fake does not restate the repository's named parameters.
class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  _FakeMessageRepository(this._backend);

  final _FakeBackend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUserMessages) {
      return _backend.pinnedPage(invocation);
    }
    return super.noSuchMethod(invocation);
  }
}

/// Both thread calls succeed and record which thread they were asked about.
class _FakeThreadRepository extends Fake implements sdk.ThreadRepository {
  _FakeThreadRepository(this._backend);

  final _FakeBackend _backend;

  @override
  Future<String> subscribeToThread(int parentMessageId) async {
    _backend.threadCalls.add('subscribe:$parentMessageId');
    return 'success';
  }

  @override
  Future<String> unsubscribeFromThread(int parentMessageId) async {
    _backend.threadCalls.add('unsubscribe:$parentMessageId');
    return 'success';
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(_FakeBackend backend)
    : messages = _FakeMessageRepository(backend),
      threads = _FakeThreadRepository(backend);

  @override
  final sdk.MessageRepository messages;

  @override
  final sdk.ThreadRepository threads;

  @override
  Future<void> dispose() async {}
}

// ─── Matrix plumbing ─────────────────────────────────────────────────────────

/// What the callbacks under test received.
class _Log {
  int headerTaps = 0;
  int searchTaps = 0;
  int infoTaps = 0;
  int pinnedListTaps = 0;
  final pinnedItemTaps = <int>[];
}

/// The nine props, defaulting to the header's own constructor defaults so
/// the baseline run renders exactly what an integrator who omits them gets.
/// The two flags are passed explicitly here, so the last test in this file
/// pumps them omitted and pins that claim.
class _Props {
  const _Props({
    this.onHeaderTap,
    this.onInfoTap,
    this.onPinnedMessageItemTap,
    this.onPinnedMessagesTap,
    this.onSearchTap,
    this.parentMessage,
    this.pinnedMessagesStyle,
    this.pinnedMessagesVisibility = true,
    this.threadSubscriptionVisibility = true,
  });

  final VoidCallback? onHeaderTap;
  final VoidCallback? onInfoTap;
  final void Function(BaseMessage message)? onPinnedMessageItemTap;
  final VoidCallback? onPinnedMessagesTap;
  final VoidCallback? onSearchTap;
  final BaseMessage? parentMessage;
  final CometChatPinnedMessagesStyle? pinnedMessagesStyle;
  final bool? pinnedMessagesVisibility;
  final bool? threadSubscriptionVisibility;
}

enum _Run { baseline, subject }

typedef _Probe =
    Future<Object?> Function(
      WidgetTester tester,
      _Log log,
      _FakeBackend backend,
    );

class _Case {
  const _Case({
    required this.prop,
    required this.effect,
    required this.subject,
    required this.probe,
    required this.baseline,
    required this.expected,
    this.context = _noContext,
  });

  final String prop;
  final String effect;

  /// Props both runs share — whatever the case needs for its prop to have
  /// something to act on.
  final _Props Function(_Log log) context;

  /// [context] with [prop] set.
  final _Props Function(_Log log) subject;

  /// Drives the rendered header and returns what it observed.
  final _Probe probe;

  /// Value or matcher for the observation with [prop] at its default.
  final Object? baseline;

  /// Value or matcher for the observation with [prop] set.
  final Object? expected;
}

_Props _noContext(_Log log) => const _Props();

Widget _wrap(Widget header) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: header),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Opens the overflow menu when the header renders one and returns its entry
/// labels in menu order; an empty list when there is no menu.
Future<List<String>> _openMenu(WidgetTester tester) async {
  final more = find.byIcon(Icons.more_vert);
  if (more.evaluate().isEmpty) return const [];
  await tester.tap(more);
  await _settle(tester);
  return tester
      .widgetList<MenuItemButton>(find.byType(MenuItemButton))
      .map((entry) => (entry.child! as Text).data!)
      .toList();
}

Future<void> _tapEntry(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(MenuItemButton, label));
  // Past the pinned screen's 280ms push, then let its fetch resolve.
  await _settle(tester);
  await _settle(tester);
}

/// The bell glyphs on screen: 'subscribed' while notifications are on,
/// 'unsubscribed' while the thread is muted.
List<String> _bells(WidgetTester tester) => [
  for (final _ in find.byIcon(Icons.notifications_outlined).evaluate())
    'subscribed',
  for (final _ in find.byIcon(Icons.notifications_off_outlined).evaluate())
    'unsubscribed',
];

/// Runs out the thread toast's two-second dismiss timer, so no timer outlives
/// the widget tree.
Future<void> _drainToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

final _sheet = find.byType(CometChatPinnedMessages);

/// How the pushed pinned-messages screen painted its chrome.
Map<String, Object?> _sheetPaint(WidgetTester tester) {
  final appBar = find.descendant(of: _sheet, matching: find.byType(AppBar));
  final scaffold = tester.widget<Scaffold>(
    find.descendant(of: _sheet, matching: find.byType(Scaffold)),
  );
  final back = tester.widget<Icon>(
    find.descendant(of: appBar, matching: find.byIcon(Icons.arrow_back)),
  );
  final title = tester.widget<Text>(
    find.descendant(of: appBar, matching: find.text(_pinnedEntry)),
  );
  final rule = tester.widget<Divider>(
    find.descendant(of: appBar, matching: find.byType(Divider)),
  );
  return {
    'background': scaffold.backgroundColor,
    'backIcon': back.color,
    'titleInk': title.style?.color,
    'titleSize': title.style?.fontSize,
    'rule': rule.color,
  };
}

// ─── The matrix ──────────────────────────────────────────────────────────────

final _matrix = <_Case>[
  _Case(
    prop: 'onHeaderTap',
    effect: 'fires when the name area is tapped',
    subject: (log) => _Props(onHeaderTap: () => log.headerTaps++),
    probe: (tester, log, backend) async {
      await tester.tap(find.text(_peerName));
      await _settle(tester);
      return log.headerTaps;
    },
    baseline: 0,
    expected: 1,
  ),
  _Case(
    prop: 'onSearchTap',
    effect: 'adds a Search entry to the overflow menu that invokes it',
    subject: (log) => _Props(onSearchTap: () => log.searchTaps++),
    probe: (tester, log, backend) async {
      final entries = await _openMenu(tester);
      if (entries.contains(_searchEntry)) {
        await _tapEntry(tester, _searchEntry);
      }
      return {'entries': entries, 'taps': log.searchTaps};
    },
    // With no server answer the Pin feature reads enabled, so the pinned
    // entry keeps the menu alive in the baseline.
    baseline: {
      'entries': [_pinnedEntry],
      'taps': 0,
    },
    expected: {
      'entries': [_searchEntry, _pinnedEntry],
      'taps': 1,
    },
  ),
  _Case(
    prop: 'onInfoTap',
    effect: 'adds a User Info entry to the overflow menu that invokes it',
    subject: (log) => _Props(onInfoTap: () => log.infoTaps++),
    probe: (tester, log, backend) async {
      final entries = await _openMenu(tester);
      if (entries.contains(_userInfoEntry)) {
        await _tapEntry(tester, _userInfoEntry);
      }
      return {'entries': entries, 'taps': log.infoTaps};
    },
    baseline: {
      'entries': [_pinnedEntry],
      'taps': 0,
    },
    expected: {
      'entries': [_pinnedEntry, _userInfoEntry],
      'taps': 1,
    },
  ),
  _Case(
    prop: 'pinnedMessagesVisibility',
    effect: 'false drops the pinned entry and keeps the others',
    // A Search entry in both runs, so the menu outlives the pinned entry.
    context: (log) => _Props(onSearchTap: () {}),
    subject: (log) =>
        _Props(onSearchTap: () {}, pinnedMessagesVisibility: false),
    probe: (tester, log, backend) => _openMenu(tester),
    baseline: [_searchEntry, _pinnedEntry],
    expected: [_searchEntry],
  ),
  _Case(
    prop: 'pinnedMessagesVisibility',
    effect: 'false removes an overflow menu the pinned entry was alone in',
    subject: (log) => const _Props(pinnedMessagesVisibility: false),
    probe: (tester, log, backend) async =>
        find.byIcon(Icons.more_vert).evaluate().length,
    baseline: 1,
    expected: 0,
  ),
  _Case(
    prop: 'onPinnedMessagesTap',
    effect: 'takes over the pinned entry instead of the pushed screen',
    subject: (log) => _Props(onPinnedMessagesTap: () => log.pinnedListTaps++),
    probe: (tester, log, backend) async {
      await _openMenu(tester);
      await _tapEntry(tester, _pinnedEntry);
      return {
        'pushedScreens': _sheet.evaluate().length,
        'pinFetches': [...backend.pinFetches],
        'hostTaps': log.pinnedListTaps,
      };
    },
    baseline: {
      'pushedScreens': 1,
      'pinFetches': ['uid:${_peer.uid} pinned:true'],
      'hostTaps': 0,
    },
    expected: {'pushedScreens': 0, 'pinFetches': <String>[], 'hostTaps': 1},
  ),
  _Case(
    prop: 'pinnedMessagesStyle',
    effect: 'styles the pinned-messages screen the menu pushes',
    subject: (log) => const _Props(
      pinnedMessagesStyle: CometChatPinnedMessagesStyle(
        backgroundColor: _sheetBackground,
        iconColor: _sheetBackIcon,
        titleTextStyle: TextStyle(
          color: _sheetTitleInk,
          fontSize: _sheetTitleSize,
        ),
        separatorColor: _sheetRule,
      ),
    ),
    probe: (tester, log, backend) async {
      await _openMenu(tester);
      await _tapEntry(tester, _pinnedEntry);
      return _sheetPaint(tester);
    },
    baseline: {
      'background': isNot(_sheetBackground),
      'backIcon': isNot(_sheetBackIcon),
      'titleInk': isNot(_sheetTitleInk),
      'titleSize': isNot(_sheetTitleSize),
      'rule': isNot(_sheetRule),
    },
    expected: {
      'background': _sheetBackground,
      'backIcon': _sheetBackIcon,
      'titleInk': _sheetTitleInk,
      'titleSize': _sheetTitleSize,
      'rule': _sheetRule,
    },
  ),
  _Case(
    prop: 'onPinnedMessageItemTap',
    effect: 'receives the pinned row tapped on the pushed screen',
    subject: (log) => _Props(
      onPinnedMessageItemTap: (message) => log.pinnedItemTaps.add(message.id),
    ),
    probe: (tester, log, backend) async {
      await _openMenu(tester);
      await _tapEntry(tester, _pinnedEntry);
      final row = find.descendant(
        of: _sheet,
        matching: find.textContaining(_pinnedText, findRichText: true),
      );
      final rows = row.evaluate().length;
      if (rows > 0) {
        // The bubble sits under an IgnorePointer; the row's own
        // GestureDetector above it is what takes the tap.
        await tester.tap(row.first, warnIfMissed: false);
        await _settle(tester);
      }
      return {
        'rows': rows,
        'rowTaps': [...log.pinnedItemTaps],
        'pushedScreens': _sheet.evaluate().length,
      };
    },
    // The row tap pops the screen either way; only the callback differs.
    baseline: {'rows': 1, 'rowTaps': <int>[], 'pushedScreens': 0},
    expected: {
      'rows': 1,
      'rowTaps': [_pinnedId],
      'pushedScreens': 0,
    },
  ),
  _Case(
    prop: 'parentMessage',
    effect:
        'puts the header in thread mode: a bell acting on that message, '
        'no overflow menu',
    // A Search entry in both runs, so the baseline has a menu to lose.
    context: (log) => _Props(onSearchTap: () {}),
    subject: (log) => _Props(onSearchTap: () {}, parentMessage: _root()),
    probe: (tester, log, backend) async {
      final bell = _bells(tester);
      final menus = find.byIcon(Icons.more_vert).evaluate().length;
      if (bell.isNotEmpty) {
        await tester.tap(find.byIcon(Icons.notifications_outlined));
        await _settle(tester);
        await _drainToast(tester);
      }
      return {
        'bell': bell,
        'overflowMenus': menus,
        'threadCalls': [...backend.threadCalls],
        'bellAfterTap': _bells(tester),
      };
    },
    baseline: {
      'bell': <String>[],
      'overflowMenus': 1,
      'threadCalls': <String>[],
      'bellAfterTap': <String>[],
    },
    // The root arrives subscribed, so the bell starts on and a tap
    // unsubscribes that exact thread.
    expected: {
      'bell': ['subscribed'],
      'overflowMenus': 0,
      'threadCalls': ['unsubscribe:$_rootId'],
      'bellAfterTap': ['unsubscribed'],
    },
  ),
  _Case(
    prop: 'threadSubscriptionVisibility',
    effect: 'false hides the thread bell',
    // A thread header in both runs, so the bell has a message to act on.
    context: (log) => _Props(parentMessage: _root()),
    subject: (log) =>
        _Props(parentMessage: _root(), threadSubscriptionVisibility: false),
    probe: (tester, log, backend) async => _bells(tester),
    baseline: ['subscribed'],
    expected: <String>[],
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    CometChatUIKit.loggedInUser = _me;
    // The bell is gated behind the thread-subscription feature flag.
    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()..enableThreadSubscription = true).build();
  });

  tearDown(() async {
    CometChatUIKit.authenticationSettings = null;
    CometChatUIKit.loggedInUser = null;
    await sdk.SdkRegistry.clear();
  });

  test('the matrix covers exactly the nine 6.1.1 props', () {
    expect(_matrix.map((c) => c.prop).toSet(), {
      'onHeaderTap',
      'onInfoTap',
      'onPinnedMessageItemTap',
      'onPinnedMessagesTap',
      'onSearchTap',
      'parentMessage',
      'pinnedMessagesStyle',
      'pinnedMessagesVisibility',
      'threadSubscriptionVisibility',
    });
  });

  group('CometChatMessageHeader 6.1.1 prop matrix', () {
    for (final c in _matrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        final observed = <_Run, Object?>{};
        for (final run in _Run.values) {
          final log = _Log();
          final backend = _FakeBackend();
          await sdk.SdkRegistry.clear();
          sdk.SdkRegistry.register(_FakeSdkClient(backend));
          final p = run == _Run.subject ? c.subject(log) : c.context(log);

          final header = CometChatMessageHeader(
            user: _peer,
            messageHeaderBloc: _headerBloc(),
            onHeaderTap: p.onHeaderTap,
            onInfoTap: p.onInfoTap,
            onPinnedMessageItemTap: p.onPinnedMessageItemTap,
            onPinnedMessagesTap: p.onPinnedMessagesTap,
            onSearchTap: p.onSearchTap,
            parentMessage: p.parentMessage,
            pinnedMessagesStyle: p.pinnedMessagesStyle,
            pinnedMessagesVisibility: p.pinnedMessagesVisibility,
            threadSubscriptionVisibility: p.threadSubscriptionVisibility,
          );

          // A fresh tree per run, so no state carries over.
          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(_wrap(header));
            await _settle(tester);
            observed[run] = await c.probe(tester, log, backend);
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());

        expect(
          observed[_Run.baseline],
          c.baseline,
          reason: 'rendered with ${c.prop} at its default',
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

  // The matrix passes both visibility flags in every run, so its baseline is
  // "on" only because _Props says so. These pumps leave the flags out, which
  // is what an integrator who never mentions them gets. A constructor default
  // flipped to false fails here and nowhere in the matrix.
  testWidgets('pinnedMessagesVisibility and threadSubscriptionVisibility '
      'render on when omitted', (tester) async {
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(_FakeBackend()));
    late final List<String> conversationMenu;
    late final List<String> threadBell;
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(
          CometChatMessageHeader(user: _peer, messageHeaderBloc: _headerBloc()),
        ),
      );
      await _settle(tester);
      conversationMenu = await _openMenu(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _wrap(
          CometChatMessageHeader(
            user: _peer,
            messageHeaderBloc: _headerBloc(),
            parentMessage: _root(),
          ),
        ),
      );
      await _settle(tester);
      threadBell = _bells(tester);
    });
    await tester.pumpWidget(const SizedBox.shrink());

    expect(conversationMenu, [
      _pinnedEntry,
    ], reason: 'pinnedMessagesVisibility omitted');
    expect(threadBell, [
      'subscribed',
    ], reason: 'threadSubscriptionVisibility omitted');
  });

  // parentMessage can move to another root on a mounted header, as when a
  // host opens a second thread in the same panel. The bell then describes,
  // and acts on, the new root.
  testWidgets('the thread bell follows a new parentMessage', (tester) async {
    final backend = _FakeBackend();
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(backend));
    final bloc = _headerBloc();
    final first = _root(); // arrives subscribed
    final second = TextMessage(
      id: _secondRootId,
      text: 'root-two-7Q',
      sender: _peer,
      receiverUid: _me.uid,
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
      category: MessageCategoryConstants.message,
      sentAt: _sentAt,
    )..threadSubscribed = false;
    Widget header(BaseMessage root) => _wrap(
      CometChatMessageHeader(
        user: _peer,
        messageHeaderBloc: bloc,
        parentMessage: root,
      ),
    );
    late final List<String> before;
    late final List<String> after;
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(header(first));
      await _settle(tester);
      before = _bells(tester);
      await tester.pumpWidget(header(second));
      await _settle(tester);
      after = _bells(tester);
      if (after.contains('unsubscribed')) {
        await tester.tap(find.byIcon(Icons.notifications_off_outlined));
        await _settle(tester);
        await _drainToast(tester);
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());

    expect(before, ['subscribed']);
    expect(after, ['unsubscribed'], reason: "the bell kept the first root's");
    expect(backend.threadCalls, ['subscribe:$_secondRootId']);
    expect([first.threadSubscribed, second.threadSubscribed], [true, true]);
  });

  // A custom listItemView replaces the default item, which is the header's
  // tap target, so the tap has to move with it.
  testWidgets('onHeaderTap fires on a custom listItemView', (tester) async {
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(_FakeBackend()));
    var taps = 0;
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(
          CometChatMessageHeader(
            user: _peer,
            messageHeaderBloc: _headerBloc(),
            listItemView: (group, user, context) =>
                const Text('custom-item-7Q'),
            onHeaderTap: () => taps++,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('custom-item-7Q'));
      await _settle(tester);
    });
    await tester.pumpWidget(const SizedBox.shrink());

    expect(taps, 1);
  });
}
