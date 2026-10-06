/// Render-verified prop matrices for [CometChatSavedMessages] and
/// [CometChatSavedMessagesStyle] — Track 3 PROP1 (ENG-38688, coverage part 2).
///
/// CometChatSavedMessages takes no bloc. Its initState builds a
/// `MessagesRequestBuilder` with `saved = true` and pages it through
/// MessagesRequest.fetchPrevious, which resolves the SDK's MessageRepository
/// through SdkRegistry. So these matrices run the real widget and fake one
/// layer further down — the same seam search_props_test.dart uses. Everything
/// between the prop and the pixel is production code.
///
/// Each case renders twice in one test body — first with its prop unset, then
/// set — and asserts both observations and that they differ. A widget that
/// ignored the prop would render the baseline twice and fail the case.
///
/// 16 props are in scope and 15 are wired here. One style prop is a defect,
/// deliberately left off the construction so the coverage tool does not credit
/// it:
///
///   itemContextTextStyle  declared and merged, never read. The rows have no
///                         conversation-context line; the conversation name
///                         is the row title, styled by itemTitleTextStyle.
///
///   flutter test test/chat_ui/saved_messages/saved_messages_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these. They are the seam CometChatSavedMessages
// leaves: no bloc injection, so the fake has to sit where the SDK resolves its
// repositories. Identical in the local SDK and in the hosted 5.0.7 CI uses.
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

const _rootPage = 'root-page-5V';
const _title = 'Saved Messages';
const _unsaveTitle = 'Unsave message?';
const _aliceText = 'lunch at noon 5V';
const _bobText = 'ship it friday 5V';

const _bg = Color(0xFF1A2B3C);
const _bar = Color(0xFF2B3C4D);
const _titleInk = Color(0xFF3C4D5E);
const _nameInk = Color(0xFF4D5E6F);
const _previewInk = Color(0xFF5E6F70);
const _dateInk = Color(0xFF6F7081);
const _iconTint = Color(0xFF708192);
const _rule = Color(0xFF8192A3);
const _unsaveInk = Color(0xFFC5D6E7);
const _styleBg = Color(0xFF92A3B4);
const _styleBar = Color(0xFFA3B4C5);

const _titleSize = 29.5;
const _nameSize = 19.5;
const _previewSize = 15.5;
const _dateSize = 11.5;

// ─── SDK fakes ───────────────────────────────────────────────────────────────

/// What the fake repository answered, and what it was asked.
class _FakeBackend {
  int fetches = 0;
  bool? savedFilter;

  void reset() {
    fetches = 0;
    savedFilter = null;
  }

  Future<sdk.MessagesResult> messages(Invocation call) {
    fetches++;
    savedFilter = call.namedArguments[#saved] as bool?;
    return Future.value(
      sdk.MessagesResult(messages: _messages(), hasMore: false),
    );
  }
}

/// An unscoped fetchPrevious routes to getMessages. Answered through
/// noSuchMethod so the fake does not restate its named parameters.
class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  _FakeMessageRepository(this._backend);

  final _FakeBackend _backend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getMessages) {
      return _backend.messages(invocation);
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

final _sentAt = DateTime(2026, 3, 14, 9, 30);
final _savedAt = DateTime(2026, 3, 15, 18, 45);

/// A 1-1 text from Alice and a group text Bob sent to Design Crew. The first
/// row is titled by its sender with no prefix; the second by its group, with
/// a "Bob:" prefix on the preview. Both carry a saved-at date.
List<BaseMessage> _messages() => [
  TextMessage(
    id: 101,
    text: _aliceText,
    sender: User(uid: 'u-alice', name: 'Alice'),
    receiver: User(uid: 'u-me', name: 'Me'),
    receiverUid: 'u-me',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.user,
    category: MessageCategoryConstants.message,
    sentAt: _sentAt,
  )..savedAt = _savedAt,
  TextMessage(
    id: 102,
    text: _bobText,
    sender: User(uid: 'u-bob', name: 'Bob'),
    receiver: Group(
      guid: 'g-design',
      name: 'Design Crew',
      type: GroupTypeConstants.public,
    ),
    receiverUid: 'g-design',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.group,
    category: MessageCategoryConstants.message,
    sentAt: _sentAt,
  )..savedAt = _savedAt,
];

// ─── Harness ─────────────────────────────────────────────────────────────────

/// Opens the listing as a pushed route over a root page, so the default pop
/// (back, close, row tap) has somewhere observable to land.
Widget _host(Widget saved) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  onGenerateRoute: (_) =>
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
  onGenerateInitialRoutes: (_) => [
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text(_rootPage)),
    ),
    MaterialPageRoute<void>(builder: (_) => saved),
  ],
);

/// The fetch resolves on a microtask: one pump lands it, the next rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Lets a route pop run to completion.
Future<void> _settlePop(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void _sizeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

int _count(Finder finder) => finder.evaluate().length;

Finder _inAppBar(Finder matching) =>
    find.descendant(of: find.byType(AppBar), matching: matching);

/// The listing's own Scaffold, not the root page's.
Color? _screenColor(WidgetTester t) => t
    .widget<Scaffold>(
      find
          .descendant(
            of: find.byType(CometChatSavedMessages),
            matching: find.byType(Scaffold),
          )
          .first,
    )
    .backgroundColor;

/// The Material the app bar paints its background with.
Color? _appBarPaint(WidgetTester t) =>
    t.widget<Material>(_inAppBar(find.byType(Material)).first).color;

TextStyle? _textStyle(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style;

/// Effective style of the span carrying [needle] in a row's rich-text preview.
/// RichText does not inherit DefaultTextStyle, so the spans are the whole
/// story.
TextStyle? _previewSpanStyle(WidgetTester t, String needle) {
  final rich = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(RichText),
  );
  for (final widget in t.widgetList<RichText>(rich)) {
    final hit = _spanStyle(widget.text, null, needle);
    if (hit != null) return hit;
  }
  return null;
}

TextStyle? _spanStyle(InlineSpan span, TextStyle? inherited, String needle) {
  final effective = inherited == null
      ? span.style
      : inherited.merge(span.style);
  if (span is! TextSpan) return null;
  if (span.text?.contains(needle) ?? false) return effective;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final hit = _spanStyle(child, effective, needle);
    if (hit != null) return hit;
  }
  return null;
}

/// The saved-at captions, one per row.
List<Text> _dates(WidgetTester t) => t
    .widgetList<Text>(
      find.descendant(
        of: find.byType(CometChatDate),
        matching: find.byType(Text),
      ),
    )
    .toList();

/// The header hairline's painted border colour.
Color _ruleColor(WidgetTester t) {
  final box = t.widget<DecoratedBox>(
    find
        .descendant(
          of: _inAppBar(find.byType(Divider)),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).bottom.color;
}

enum _Run { baseline, subject }

// ─── CometChatSavedMessages matrix ───────────────────────────────────────────

/// What the callbacks under test reported.
class _Log {
  final taps = <int>[];
}

/// The props a widget case can set. The defaults are the widget's documented
/// ones; the baseline run does not use this class at all, it pumps a bare
/// `const CometChatSavedMessages()` so a changed default would show up there.
class _Props {
  const _Props({
    this.onItemTap,
    this.style,
    this.hideUnsaveOption,
    this.showBackButton = true,
    this.popOnItemTap = true,
    this.useCloseButton = false,
  });

  final Function(BaseMessage message)? onItemTap;
  final CometChatSavedMessagesStyle? style;
  final bool? hideUnsaveOption;
  final bool showBackButton;
  final bool popOnItemTap;
  final bool useCloseButton;
}

class _Case {
  const _Case({
    required this.prop,
    required this.effect,
    required this.subject,
    required this.observe,
    required this.baseline,
    required this.expected,
  });

  final String prop;
  final String effect;
  final _Props Function(_Log log) subject;
  final Future<Object?> Function(WidgetTester t, _Log log) observe;

  /// Value or matcher for the observation with the prop unset.
  final Object? baseline;

  /// Value or matcher for the observation with the prop set.
  final Object? expected;
}

final _widgetMatrix = <_Case>[
  _Case(
    prop: 'onItemTap',
    effect: 'reports the tapped row with its message',
    subject: (log) => _Props(onItemTap: (message) => log.taps.add(message.id)),
    observe: (t, log) async {
      await t.tap(find.text('Design Crew'));
      await t.pump();
      return List<int>.of(log.taps);
    },
    baseline: <int>[],
    expected: [102],
  ),
  _Case(
    prop: 'popOnItemTap',
    effect: 'false keeps the listing up when a row is tapped',
    subject: (_) => const _Props(popOnItemTap: false),
    observe: (t, _) async {
      await t.tap(find.text('Alice'));
      await _settlePop(t);
      return [
        _count(find.byType(CometChatSavedMessages)),
        _count(find.text(_rootPage)),
      ];
    },
    // Unset, the row pops the listing and the root page is all that is left.
    baseline: [0, 1],
    expected: [1, 0],
  ),
  _Case(
    prop: 'showBackButton',
    effect: 'false drops the back arrow and its pop',
    subject: (_) => const _Props(showBackButton: false),
    observe: (t, _) async {
      final arrow = _inAppBar(find.byIcon(Icons.arrow_back));
      final shown = [
        _count(arrow),
        _count(_inAppBar(find.byIcon(Icons.close))),
        _count(find.byTooltip('Back')),
      ];
      // The default arrow has to be a working back affordance, not merely
      // drawn: tapping it must uncover the root page.
      if (arrow.evaluate().isNotEmpty) {
        await t.tap(arrow);
        await _settlePop(t);
      }
      return [...shown, _count(find.text(_rootPage))];
    },
    baseline: [1, 0, 1, 1],
    expected: [0, 0, 0, 0],
  ),
  _Case(
    prop: 'useCloseButton',
    effect: 'swaps the leading arrow for a trailing close that still dismisses',
    subject: (_) => const _Props(useCloseButton: true),
    observe: (t, _) async {
      final arrow = _inAppBar(find.byIcon(Icons.arrow_back));
      final close = _inAppBar(find.byIcon(Icons.close));
      final shown = close.evaluate().isNotEmpty ? close : arrow;
      final trailing =
          t.getCenter(shown).dx > t.getCenter(find.text(_title)).dx;
      final chrome = [_count(arrow), _count(close), trailing];
      await t.tap(shown);
      await _settlePop(t);
      return [...chrome, _count(find.text(_rootPage))];
    },
    baseline: [1, 0, false, 1],
    expected: [0, 1, true, 1],
  ),
  _Case(
    prop: 'hideUnsaveOption',
    effect: 'true removes the long-press unsave affordance',
    subject: (_) => const _Props(hideUnsaveOption: true),
    observe: (t, _) async {
      final row = find
          .ancestor(of: find.text('Alice'), matching: find.byType(InkWell))
          .first;
      final armed = t.widget<InkWell>(row).onLongPress != null;
      await t.longPress(find.text('Alice'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      return [armed, _count(find.text(_unsaveTitle))];
    },
    // Unset, a long-press opens the unsave confirmation.
    baseline: [true, 1],
    expected: [false, 0],
  ),
  _Case(
    prop: 'style',
    effect: 'reaches the screen and its app bar',
    subject: (_) => const _Props(
      style: CometChatSavedMessagesStyle(
        backgroundColor: _styleBg,
        appBarColor: _styleBar,
      ),
    ),
    observe: (t, _) async => [_screenColor(t), _appBarPaint(t)],
    baseline: [isNot(_styleBg), isNot(_styleBar)],
    expected: [_styleBg, _styleBar],
  ),
];

// ─── CometChatSavedMessagesStyle matrix ──────────────────────────────────────

/// The style props a case can set. itemContextTextStyle is absent on
/// purpose: it is a defect, see the library comment.
class _StyleProps {
  const _StyleProps({
    this.backgroundColor,
    this.appBarColor,
    this.titleTextStyle,
    this.itemTitleTextStyle,
    this.itemSubtitleTextStyle,
    this.itemDateTextStyle,
    this.iconColor,
    this.separatorColor,
    this.unsaveIconColor,
  });

  final Color? backgroundColor;
  final Color? appBarColor;
  final TextStyle? titleTextStyle;
  final TextStyle? itemTitleTextStyle;
  final TextStyle? itemSubtitleTextStyle;
  final TextStyle? itemDateTextStyle;
  final Color? iconColor;
  final Color? separatorColor;
  final Color? unsaveIconColor;
}

class _StyleCase {
  const _StyleCase({
    required this.prop,
    required this.effect,
    required this.subject,
    required this.observe,
    required this.baseline,
    required this.expected,
    this.act,
  });

  final String prop;
  final String effect;
  final _StyleProps subject;
  final Object? Function(WidgetTester t) observe;
  final Object? baseline;
  final Object? expected;

  /// Runs after the pump and before [observe], for props that only show once
  /// something is opened.
  final Future<void> Function(WidgetTester t)? act;
}

final _styleMatrix = <_StyleCase>[
  _StyleCase(
    prop: 'backgroundColor',
    effect: 'paints the screen',
    subject: const _StyleProps(backgroundColor: _bg),
    observe: _screenColor,
    baseline: isNot(_bg),
    expected: _bg,
  ),
  _StyleCase(
    prop: 'appBarColor',
    effect: 'paints the app bar',
    subject: const _StyleProps(appBarColor: _bar),
    observe: _appBarPaint,
    baseline: isNot(_bar),
    expected: _bar,
  ),
  _StyleCase(
    prop: 'titleTextStyle',
    effect: 'styles the screen title',
    subject: const _StyleProps(
      titleTextStyle: TextStyle(color: _titleInk, fontSize: _titleSize),
    ),
    observe: (t) {
      final style = _textStyle(t, _title);
      return [style?.color, style?.fontSize];
    },
    baseline: [isNot(_titleInk), isNot(_titleSize)],
    expected: [_titleInk, _titleSize],
  ),
  _StyleCase(
    prop: 'itemTitleTextStyle',
    effect: 'styles every row title',
    subject: const _StyleProps(
      itemTitleTextStyle: TextStyle(color: _nameInk, fontSize: _nameSize),
    ),
    observe: (t) => [
      _textStyle(t, 'Alice')?.color,
      _textStyle(t, 'Design Crew')?.color,
      _textStyle(t, 'Alice')?.fontSize,
    ],
    baseline: [isNot(_nameInk), isNot(_nameInk), isNot(_nameSize)],
    expected: [_nameInk, _nameInk, _nameSize],
  ),
  _StyleCase(
    prop: 'itemSubtitleTextStyle',
    effect: 'styles the preview text and its sender prefix',
    subject: const _StyleProps(
      itemSubtitleTextStyle: TextStyle(
        color: _previewInk,
        fontSize: _previewSize,
      ),
    ),
    observe: (t) => [
      _previewSpanStyle(t, _aliceText)?.color,
      _previewSpanStyle(t, _aliceText)?.fontSize,
      _textStyle(t, 'Bob:')?.color,
    ],
    baseline: [isNot(_previewInk), isNot(_previewSize), isNot(_previewInk)],
    expected: [_previewInk, _previewSize, _previewInk],
  ),
  _StyleCase(
    prop: 'itemDateTextStyle',
    effect: 'styles every saved-at caption',
    subject: const _StyleProps(
      itemDateTextStyle: TextStyle(color: _dateInk, fontSize: _dateSize),
    ),
    observe: (t) => [
      for (final date in _dates(t)) [date.style?.color, date.style?.fontSize],
    ],
    baseline: [
      [isNot(_dateInk), isNot(_dateSize)],
      [isNot(_dateInk), isNot(_dateSize)],
    ],
    expected: [
      [_dateInk, _dateSize],
      [_dateInk, _dateSize],
    ],
  ),
  _StyleCase(
    prop: 'iconColor',
    effect: 'tints the back arrow',
    subject: const _StyleProps(iconColor: _iconTint),
    observe: (t) =>
        t.widget<Icon>(_inAppBar(find.byIcon(Icons.arrow_back))).color,
    baseline: isNot(_iconTint),
    expected: _iconTint,
  ),
  _StyleCase(
    prop: 'separatorColor',
    effect: 'paints the hairline under the header',
    subject: const _StyleProps(separatorColor: _rule),
    observe: _ruleColor,
    baseline: isNot(_rule),
    expected: _rule,
  ),
  _StyleCase(
    prop: 'unsaveIconColor',
    effect: 'tints the icon in the unsave confirmation',
    subject: const _StyleProps(unsaveIconColor: _unsaveInk),
    act: _openUnsaveDialog,
    observe: (t) => t
        .widgetList<Icon>(find.byIcon(Icons.bookmark_remove_outlined))
        .last
        .color,
    baseline: isNot(_unsaveInk),
    expected: _unsaveInk,
  ),
];

Future<void> _openUnsaveDialog(WidgetTester t) async {
  await t.longPress(find.text('Alice'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late _FakeBackend backend;

  setUp(() async {
    backend = _FakeBackend();
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(backend));
  });

  tearDown(sdk.SdkRegistry.clear);

  test('each matrix names each of its wired props exactly once', () {
    final widgetProps = _widgetMatrix.map((c) => c.prop).toList();
    expect(widgetProps.toSet(), hasLength(widgetProps.length));
    expect(widgetProps, hasLength(6));

    final styleProps = _styleMatrix.map((c) => c.prop).toList();
    expect(styleProps.toSet(), hasLength(styleProps.length));
    expect(styleProps, hasLength(9));
  });

  testWidgets('the fixture rows arrive through a saved-only fetch', (
    tester,
  ) async {
    // Every baseline below leans on this: two rows, a title, a date each.
    _sizeView(tester);
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_host(const CometChatSavedMessages()));
      await _settle(tester);
    });

    expect(backend.fetches, 1);
    expect(backend.savedFilter, isTrue);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Design Crew'), findsOneWidget);
    expect(find.text('Bob:'), findsOneWidget);
    expect(_previewSpanStyle(tester, _aliceText), isNotNull);
    expect(_previewSpanStyle(tester, _bobText), isNotNull);
    expect(_dates(tester), hasLength(2));
  });

  group('CometChatSavedMessages prop matrix', () {
    for (final c in _widgetMatrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        _sizeView(tester);

        final observed = <_Run, Object?>{};
        for (final run in _Run.values) {
          backend.reset();
          final log = _Log();
          final p = run == _Run.subject ? c.subject(log) : null;

          // A fresh tree per run: the fetch runs in initState.
          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(
              _host(
                p == null
                    ? const CometChatSavedMessages()
                    : CometChatSavedMessages(
                        onItemTap: p.onItemTap,
                        style: p.style,
                        hideUnsaveOption: p.hideUnsaveOption,
                        showBackButton: p.showBackButton,
                        popOnItemTap: p.popOnItemTap,
                        useCloseButton: p.useCloseButton,
                      ),
              ),
            );
            await _settle(tester);
          });
          observed[run] = await c.observe(tester, log);
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

  group('CometChatSavedMessagesStyle prop matrix', () {
    for (final c in _styleMatrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        _sizeView(tester);

        final observed = <_Run, Object?>{};
        for (final run in _Run.values) {
          backend.reset();
          final s = run == _Run.subject ? c.subject : const _StyleProps();

          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(
              _host(
                CometChatSavedMessages(
                  // itemContextTextStyle is left off on purpose: it is a
                  // defect, see the library comment.
                  style: CometChatSavedMessagesStyle(
                    backgroundColor: s.backgroundColor,
                    appBarColor: s.appBarColor,
                    titleTextStyle: s.titleTextStyle,
                    itemTitleTextStyle: s.itemTitleTextStyle,
                    itemSubtitleTextStyle: s.itemSubtitleTextStyle,
                    itemDateTextStyle: s.itemDateTextStyle,
                    iconColor: s.iconColor,
                    separatorColor: s.separatorColor,
                    unsaveIconColor: s.unsaveIconColor,
                  ),
                ),
              ),
            );
            await _settle(tester);
          });
          if (c.act != null) await c.act!(tester);
          observed[run] = c.observe(tester);
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

  group('interplay the matrices cannot show', () {
    testWidgets('useCloseButton is only read while showBackButton is true', (
      tester,
    ) async {
      _sizeView(tester);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _host(const CometChatSavedMessages(useCloseButton: true)),
        );
        await _settle(tester);
      });
      final withBack = _count(_inAppBar(find.byIcon(Icons.close)));

      await tester.pumpWidget(const SizedBox.shrink());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _host(
            const CometChatSavedMessages(
              showBackButton: false,
              useCloseButton: true,
            ),
          ),
        );
        await _settle(tester);
      });

      expect(withBack, 1);
      expect(_inAppBar(find.byIcon(Icons.close)), findsNothing);
      expect(_inAppBar(find.byIcon(Icons.arrow_back)), findsNothing);
    });

    testWidgets('iconColor also tints the panel close button', (tester) async {
      _sizeView(tester);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _host(const CometChatSavedMessages(useCloseButton: true)),
        );
        await _settle(tester);
      });
      final untinted = tester
          .widget<Icon>(_inAppBar(find.byIcon(Icons.close)))
          .color;

      await tester.pumpWidget(const SizedBox.shrink());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _host(
            const CometChatSavedMessages(
              useCloseButton: true,
              style: CometChatSavedMessagesStyle(iconColor: _iconTint),
            ),
          ),
        );
        await _settle(tester);
      });

      expect(untinted, isNot(_iconTint));
      expect(
        tester.widget<Icon>(_inAppBar(find.byIcon(Icons.close))).color,
        _iconTint,
      );
    });
  });
}
