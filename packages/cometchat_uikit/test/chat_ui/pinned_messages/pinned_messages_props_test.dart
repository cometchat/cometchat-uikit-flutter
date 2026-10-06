/// Render-verified prop matrices for [CometChatPinnedMessages] and
/// [CometChatPinnedMessagesStyle] — Track 3 PROP1 (ENG-38688, coverage
/// part 2). Both classes are new in 6.1.1.
///
/// CometChatPinnedMessages takes no bloc: its State fetches the pins itself in
/// initState through MessagesRequest.fetchPrevious, which resolves its
/// repository through SdkRegistry. So these matrices run the real widget and
/// fake one layer further down — the SDK's MessageRepository — the same seam
/// the CometChatSearch matrix uses. Everything between a prop and the pixel is
/// production code.
///
/// Every case renders twice in one test body: first with its prop unset, then
/// with a sentinel. It asserts what each render shows and that they differ, so
/// a widget that ignored the prop would render the baseline twice and fail.
/// The one exception is hideUnpinOption: it is a bool?, so its first render
/// passes false explicitly, and the style matrix's unpinIconColor baseline is
/// the render that shows null still offers unpin.
///
/// CometChatPinnedMessages: all 7 props are wired and covered here.
///
/// CometChatPinnedMessagesStyle: 6 of its 10 props are wired and covered. The
/// other 4 have no observable effect and are deliberately left off every
/// construction below, so the coverage tool does not credit them:
///
///   itemTitleTextStyle     never read. Rows are real message bubbles from
///   itemSubtitleTextStyle  MessageUtils.getMessageBubble, which is handed
///   itemDateTextStyle      none of these; _buildBody takes the style and
///                          never touches it.
///   borderRadius           never read. The screen is a pushed Scaffold route,
///                          not the sheet the doc comment describes.
///
///   flutter test test/chat_ui/pinned_messages/pinned_messages_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these. CometChatPinnedMessages has no bloc or
// request injection, so the fake has to sit where the SDK resolves its
// repositories.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────

const _bg = Color(0xFF1A2B3C);
const _iconInk = Color(0xFF2B3C4D);
const _titleInk = Color(0xFF3C4D5E);
const _titleStyle = TextStyle(fontSize: 23.25, color: _titleInk);
const _ruleInk = Color(0xFF4D5E6F);
const _barInk = Color(0xFF5E6F70);
const _unpinInk = Color(0xFF6F7081);

/// What the widget-level `style` case hands the screen.
const _screenStyle = CometChatPinnedMessagesStyle(backgroundColor: _bg);

// ─── SDK fakes ───────────────────────────────────────────────────────────────

/// What the fake repository was asked for, and what it answers with.
class _FakeBackend {
  /// One entry per fetch: `uid:<uid>`, `guid:<guid>`, or `all` when the
  /// request carried no scope.
  final List<String> targets = [];

  Future<sdk.MessagesResult> pins(Invocation call, String target) {
    targets.add(target);
    return Future.value(
      sdk.MessagesResult(messages: _pinsFor(target), hasMore: false),
    );
  }
}

/// fetchPrevious routes to getUserMessages with a uid, getGroupMessages with a
/// guid, and getMessages with neither. Answered through noSuchMethod so the
/// fake does not restate the repository's named parameters.
class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  _FakeMessageRepository(this._backend);

  final _FakeBackend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages) {
      return _backend.pins(
        invocation,
        'uid:${invocation.positionalArguments.first}',
      );
    }
    if (name == #getGroupMessages) {
      return _backend.pins(
        invocation,
        'guid:${invocation.positionalArguments.first}',
      );
    }
    if (name == #getMessages) {
      return _backend.pins(invocation, 'all');
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(_FakeBackend backend)
    : messages = _FakeMessageRepository(backend);

  @override
  final sdk.MessageRepository messages;

  @override
  Future<void> dispose() async {}
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(uid: 'u-me', name: 'Me');
final _alice = User(uid: 'u-alice', name: 'Alice');
final _crew = Group(
  guid: 'g-crew',
  name: 'Crew',
  type: GroupTypeConstants.public,
);
final _scopeUser = User(uid: 'u-scope-7Q', name: 'Scoped User');
final _scopeGroup = Group(
  guid: 'g-scope-7Q',
  name: 'Scoped Group',
  type: GroupTypeConstants.public,
);

/// Two incoming pins for whichever conversation was fetched — fresh objects
/// per fetch, because the screen mutates pin fields on the rows it holds.
List<BaseMessage> _pinsFor(String target) => [
  _pin(201, 'first pin 7Q', target),
  _pin(202, 'second pin 7Q', target),
];

TextMessage _pin(int id, String text, String target) => TextMessage(
  id: id,
  text: text,
  sender: User(uid: 'u-alice', name: 'Alice'),
  receiverUid: 'u-me',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: DateTime(2026, 3, 14, 9, 30),
  conversationId: target,
);

/// A pin that arrives live, addressed the way the SDK addresses it.
TextMessage _live(
  int id, {
  required User sender,
  required String receiverUid,
  required String receiverType,
  required String conversationId,
}) => TextMessage(
  id: id,
  text: 'live pin $id 7Q',
  sender: sender,
  receiverUid: receiverUid,
  type: MessageTypeConstants.text,
  receiverType: receiverType,
  category: MessageCategoryConstants.message,
  sentAt: DateTime(2026, 3, 14, 9, 45),
  conversationId: conversationId,
);

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

/// Lets the initState fetch resolve and the rows build.
Future<void> _load(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The whole-row tap target each pinned row is wrapped in — the opaque
/// GestureDetector around the read-only (IgnorePointer) bubble.
final _rows = find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.behavior == HitTestBehavior.opaque &&
      w.child is ConstrainedBox &&
      (w.child! as ConstrainedBox).child is IgnorePointer,
);

Finder _inHeader(Finder matching) =>
    find.descendant(of: find.byType(AppBar), matching: matching);

Color? _scaffoldColor(WidgetTester tester) => tester
    .widget<Scaffold>(
      find.descendant(
        of: find.byType(CometChatPinnedMessages),
        matching: find.byType(Scaffold),
      ),
    )
    .backgroundColor;

/// Which conversation the screen fetched, and how many rows it listed.
String _fetchedAndListed(_Run run) =>
    '${run.backend.targets.join(', ')} → ${_rows.evaluate().length} rows';

// ─── Widget matrix ───────────────────────────────────────────────────────────

/// What one render can be probed through.
class _Run {
  _Run(this.backend);

  final _FakeBackend backend;

  /// Every message onItemTap was called with.
  final List<BaseMessage> taps = [];
}

class _WidgetCase {
  const _WidgetCase(
    this.prop,
    this.effect, {
    required this.observe,
    required this.byDefault,
    required this.expected,
  });

  /// The CometChatPinnedMessages prop this row covers.
  final String prop;

  /// What setting it does, as the test name reads.
  final String effect;

  /// Drives the pumped screen as far as [prop] needs, then reads back what it
  /// controls.
  final Future<Object?> Function(WidgetTester tester, _Run run) observe;

  /// What the render with [prop] unset shows (a value or a matcher).
  final Object? byDefault;

  /// What the render with the sentinel shows.
  final Object? expected;

  /// [sentinel] when this row covers [name], otherwise null — so the screen a
  /// row pumps carries exactly the prop under test.
  T? on<T>(String name, T sentinel) => name == prop ? sentinel : null;
}

final _widgetCases = <_WidgetCase>[
  _WidgetCase(
    'user',
    'scopes the pin fetch to that user and lists what it returns',
    // Unset, a scope is still required, so the baseline is a group screen.
    observe: (t, run) async => _fetchedAndListed(run),
    byDefault: 'guid:g-crew → 2 rows',
    expected: 'uid:u-scope-7Q → 2 rows',
  ),
  _WidgetCase(
    'group',
    'scopes the pin fetch to that group and lists what it returns',
    observe: (t, run) async => _fetchedAndListed(run),
    byDefault: 'uid:u-alice → 2 rows',
    expected: 'guid:g-scope-7Q → 2 rows',
  ),
  _WidgetCase(
    'onItemTap',
    'fires with the tapped row message',
    observe: (t, run) async {
      await t.tap(_rows.at(1));
      await t.pump();
      return run.taps.map((m) => m.id).toList();
    },
    byDefault: <int>[],
    expected: [202],
  ),
  _WidgetCase(
    'hideUnpinOption',
    'stops a long-press offering unpin',
    observe: (t, run) async {
      await t.longPress(_rows.first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      return find.text('Unpin message?').evaluate().length;
    },
    byDefault: 1,
    expected: 0,
  ),
  _WidgetCase(
    'showBackButton',
    'removes the header back arrow when false',
    observe: (t, run) async =>
        _inHeader(find.byIcon(Icons.arrow_back)).evaluate().length,
    byDefault: 1,
    expected: 0,
  ),
  _WidgetCase(
    'hideAppBar',
    'drops the header when true',
    observe: (t, run) async => find.byType(AppBar).evaluate().length,
    byDefault: 1,
    expected: 0,
  ),
  _WidgetCase(
    'style',
    'reaches the screen scaffold',
    observe: (t, run) async => _scaffoldColor(t),
    byDefault: isNot(_bg),
    expected: _bg,
  ),
];

// ─── Style matrix ────────────────────────────────────────────────────────────

class _StyleCase {
  const _StyleCase(
    this.prop,
    this.target, {
    required this.probe,
    required this.expected,
    this.act,
  });

  /// The CometChatPinnedMessagesStyle prop this row covers.
  final String prop;

  /// The element the prop paints, as the test name reads.
  final String target;

  /// Reads back the rendered value the prop controls.
  final Object? Function(WidgetTester tester) probe;

  final Object? expected;

  /// Runs after the load and before [probe], for props that only show once
  /// something is opened.
  final Future<void> Function(WidgetTester tester)? act;

  /// [sentinel] when this row covers [name], otherwise null — so the style a
  /// row pumps carries exactly the prop under test.
  T? on<T>(String name, T sentinel) => name == prop ? sentinel : null;
}

final _styleCases = <_StyleCase>[
  _StyleCase(
    'backgroundColor',
    'the screen scaffold',
    probe: _scaffoldColor,
    expected: _bg,
  ),
  _StyleCase(
    'iconColor',
    'the header back arrow',
    probe: (t) =>
        t.widget<Icon>(_inHeader(find.byIcon(Icons.arrow_back))).color,
    expected: _iconInk,
  ),
  _StyleCase(
    'titleTextStyle',
    'the header title',
    probe: (t) {
      final style = t.widget<Text>(find.text('Pinned Messages')).style;
      return (style?.fontSize, style?.color);
    },
    expected: (_titleStyle.fontSize, _titleInk),
  ),
  _StyleCase(
    'separatorColor',
    'the header hairline',
    probe: (t) => t.widget<Divider>(_inHeader(find.byType(Divider))).color,
    expected: _ruleInk,
  ),
  _StyleCase(
    'appBarColor',
    'the header app bar',
    probe: (t) => t.widget<AppBar>(find.byType(AppBar)).backgroundColor,
    expected: _barInk,
  ),
  _StyleCase(
    'unpinIconColor',
    'the icon in the unpin confirmation',
    act: _openUnpinDialog,
    // The dialog's own pin, not a row's 12px pin-indicator glyph. t.widget
    // throws unless the dialog is up and carries exactly one.
    probe: (t) => t
        .widget<Icon>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.push_pin),
          ),
        )
        .color,
    expected: _unpinInk,
  ),
];

Future<void> _openUnpinDialog(WidgetTester t) async {
  await t.longPress(_rows.first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late _FakeBackend backend;
  User? previousUser;

  setUp(() async {
    backend = _FakeBackend();
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(backend));
    // Unpin is offered only to a logged-in user.
    previousUser = CometChatUIKit.loggedInUser;
    CometChatUIKit.loggedInUser = _me;
  });

  tearDown(() async {
    CometChatUIKit.loggedInUser = previousUser;
    await sdk.SdkRegistry.clear();
  });

  group('CometChatPinnedMessages prop matrix', () {
    test('names each of the 7 props exactly once', () {
      final props = _widgetCases.map((c) => c.prop).toList();
      expect(props.toSet(), hasLength(props.length));
      expect(props.toSet(), {
        'user',
        'group',
        'onItemTap',
        'hideUnpinOption',
        'showBackButton',
        'hideAppBar',
        'style',
      });
    });

    for (final c in _widgetCases) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        // 1. The prop unset.
        final unset = _Run(backend);
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _host(
              CometChatPinnedMessages(
                user: c.prop == 'user' ? null : _alice,
                group: c.prop == 'user' ? _crew : null,
                // A bool?, so false is spelled out: a widget that hid unpin
                // for any non-null value would pass against a null baseline.
                hideUnpinOption: c.prop == 'hideUnpinOption' ? false : null,
              ),
            ),
          );
          await _load(tester);
        });
        final baseline = await c.observe(tester, unset);

        // A fresh tree, so the second render runs its own initState fetch and
        // nothing the first one opened (a dialog) survives into it.
        await tester.pumpWidget(const SizedBox.shrink());
        backend.targets.clear();

        // 2. The sentinel.
        final set = _Run(backend);
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _host(
              CometChatPinnedMessages(
                user:
                    c.on('user', _scopeUser) ??
                    (c.prop == 'group' ? null : _alice),
                group: c.on('group', _scopeGroup),
                onItemTap: c.on<void Function(BaseMessage)>(
                  'onItemTap',
                  set.taps.add,
                ),
                style: c.on('style', _screenStyle),
                hideUnpinOption: c.on('hideUnpinOption', true),
                showBackButton: c.on('showBackButton', false) ?? true,
                hideAppBar: c.on('hideAppBar', true) ?? false,
              ),
            ),
          );
          await _load(tester);
        });
        final observed = await c.observe(tester, set);

        expect(observed, c.expected, reason: 'the render with ${c.prop} set');
        expect(baseline, c.byDefault, reason: 'the render with it unset');
        expect(
          baseline,
          isNot(c.expected),
          reason: 'the unset render already showed the sentinel',
        );
      });
    }
  });

  group('CometChatPinnedMessagesStyle prop matrix', () {
    test('names each of the 6 wired props exactly once', () {
      final props = _styleCases.map((c) => c.prop).toList();
      expect(props.toSet(), hasLength(props.length));
      expect(props.toSet(), {
        'backgroundColor',
        'iconColor',
        'titleTextStyle',
        'separatorColor',
        'appBarColor',
        'unpinIconColor',
      });
    });

    for (final c in _styleCases) {
      testWidgets('${c.prop} paints ${c.target}', (tester) async {
        // 1. No style.
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(_host(CometChatPinnedMessages(user: _alice)));
          await _load(tester);
        });
        if (c.act != null) await c.act!(tester);
        final baseline = c.probe(tester);

        await tester.pumpWidget(const SizedBox.shrink());

        // 2. A style carrying only the prop under test.
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _host(
              CometChatPinnedMessages(
                user: _alice,
                style: CometChatPinnedMessagesStyle(
                  backgroundColor: c.on('backgroundColor', _bg),
                  iconColor: c.on('iconColor', _iconInk),
                  titleTextStyle: c.on('titleTextStyle', _titleStyle),
                  separatorColor: c.on('separatorColor', _ruleInk),
                  appBarColor: c.on('appBarColor', _barInk),
                  unpinIconColor: c.on('unpinIconColor', _unpinInk),
                ),
              ),
            ),
          );
          await _load(tester);
        });
        if (c.act != null) await c.act!(tester);

        expect(c.probe(tester), c.expected, reason: 'the styled render');
        expect(
          baseline,
          isNot(c.expected),
          reason: 'the unstyled render already showed the sentinel',
        );
      });
    }
  });

  // A live pin event carries the whole message, and the screen adds it only
  // when it belongs to the listed conversation. Each scope first gets a pin
  // from a conversation whose id contains the scoped id as a substring, then
  // one from the listed conversation itself.
  group('live pin sync', () {
    Future<List<int>> rowsAfterEvents(
      WidgetTester tester,
      Widget screen,
      List<BaseMessage> pins,
    ) async {
      final counts = <int>[];
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_host(screen));
        await _load(tester);
        counts.add(_rows.evaluate().length);
        for (final pin in pins) {
          CometChatMessageEvents.ccMessagePinned(pin);
          await _load(tester);
          counts.add(_rows.evaluate().length);
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      return counts;
    }

    testWidgets('a user screen skips pins from a conversation it is not in', (
      tester,
    ) async {
      final e = User(uid: 'e', name: 'E');
      final counts = await rowsAfterEvents(
        tester,
        CometChatPinnedMessages(user: e),
        [
          // u-me_user_bob contains "e", but neither side of it is e.
          _live(
            301,
            sender: _me,
            receiverUid: 'bob',
            receiverType: ReceiverTypeConstants.user,
            conversationId: 'u-me_user_bob',
          ),
          _live(
            302,
            sender: e,
            receiverUid: _me.uid,
            receiverType: ReceiverTypeConstants.user,
            conversationId: 'e_user_u-me',
          ),
        ],
      );
      expect(counts, [2, 2, 3]);
    });

    testWidgets(
      'a group screen skips pins from a group whose guid extends it',
      (tester) async {
        final counts = await rowsAfterEvents(
          tester,
          CometChatPinnedMessages(
            group: Group(
              guid: 'g1',
              name: 'G1',
              type: GroupTypeConstants.public,
            ),
          ),
          [
            _live(
              301,
              sender: _alice,
              receiverUid: 'g10',
              receiverType: ReceiverTypeConstants.group,
              conversationId: 'group_g10',
            ),
            _live(
              302,
              sender: _alice,
              receiverUid: 'g1',
              receiverType: ReceiverTypeConstants.group,
              conversationId: 'group_g1',
            ),
          ],
        );
        expect(counts, [2, 2, 3]);
      },
    );
  });
}
