/// Render-verified prop matrix for the three public props new in 6.1.1 —
/// ENG-38688, coverage part 2, round 2.
///
///   CometChatMessageComposer.richTextToolbarActions
///   StickerAuxiliaryButton.composerId
///   CometChatConversations.pinConversationOptionVisibility
///
/// Same shape as the CometChatSearch matrix: one table per class, and every
/// case renders its unit twice inside one test body — once with the prop
/// unset, once with a sentinel — then asserts both observations and that they
/// differ. A widget that stopped reading the prop renders the baseline twice
/// and fails the case.
///
///   flutter test test/chat_ui/six_one_one_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Fakes & mocks ───────────────────────────────────────────────────────────

class _FakeUser extends Fake implements User {
  _FakeUser({this.uid = 'u1', this.name = 'Alice'});

  @override
  final String uid;
  @override
  final String name;
  @override
  String? get avatar => null;
  @override
  String get status => 'online';
  @override
  String? get role => 'default';
  @override
  String? get link => null;
  @override
  bool get blockedByMe => false;
  @override
  bool get hasBlockedMe => false;
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation({
    required this.conversationWith,
    required this.conversationId,
    this.pinnedBy,
  });

  @override
  final String conversationId;
  @override
  final AppEntity conversationWith;
  @override
  int get unreadMessageCount => 0;
  @override
  BaseMessage? get lastMessage => null;
  @override
  String get conversationType => 'user';
  @override
  DateTime? get pinnedAt => pinnedBy == null ? null : DateTime.utc(2026, 9, 1);
  @override
  final String? pinnedBy;
}

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  final _typing = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier([]));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {
    // No-op: these cases assert rendering, not event handling.
  }
}

class _MockComposerRepository extends Mock
    implements MessageComposerRepository {}

// ─── Harness ─────────────────────────────────────────────────────────────────

enum _Run { baseline, subject }

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ═════════════════════════════════════════════════════════════════════════════
// CometChatMessageComposer.richTextToolbarActions
// ═════════════════════════════════════════════════════════════════════════════

const _probeKey = Key('six-one-one-trailing-probe');
const _draft = 'draft for the 6.1.1 probe';

/// What the consumer's builder and its toolbar action saw.
class _ToolbarLog {
  User? builtFor;
  TextEditingController? tappedController;
  String? tappedText;
}

/// A consumer builder carrying one sentinel action that records its tap.
ComposerActionsBuilder _probeActions(_ToolbarLog log) =>
    (context, user, group, id) {
      log.builtFor = user;
      return [
        CometChatMessageComposerAction(
          id: 'probe-6.1.1',
          title: 'Probe action 6.1.1',
          icon: const Icon(Icons.colorize, key: _probeKey),
          onToolbarTap: (context, controller) {
            log.tappedController = controller;
            log.tappedText = controller.text;
          },
        ),
      ];
    };

class _ComposerCase {
  const _ComposerCase({
    required this.effect,
    required this.layout,
    required this.open,
  });

  final String effect;
  final CometChatComposerLayout layout;

  /// Types the draft and brings the rich-text toolbar on screen.
  final Future<void> Function(WidgetTester tester) open;
}

Future<void> _typeDraft(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, _draft);
  await tester.pump();
}

final _composerMatrix = <_ComposerCase>[
  _ComposerCase(
    effect: 'append to the swap-row toolbar in the double-line layout',
    layout: CometChatComposerLayout.doubleLine,
    open: (tester) async {
      await _typeDraft(tester);
      // The `Aa` toggle swaps the action row for `[✕] + <toolbar>`.
      await tester.tap(find.byIcon(Icons.text_format));
      await tester.pump();
    },
  ),
  // Once the field has focus: before that the trailing slot is withheld from
  // the visible stacked toolbar, because the active controller is null while
  // no segment is focused, and it drops out again on the first rebuild after
  // focus leaves. That gap is a defect filed with this matrix, not a case —
  // see _getActiveTextController and _buildInlineRichTextToolbar in
  // cometchat_message_composer.dart.
  _ComposerCase(
    effect:
        'append to the stacked toolbar in the single-line layout once the '
        'field has focus',
    layout: CometChatComposerLayout.singleLine,
    // The stacked toolbar is always up; typing focuses the normal segment,
    // whose own RichTextEditingController is the one handed to the action.
    open: _typeDraft,
  ),
];

/// Everything the trailing slot produced, including the effect of tapping it.
Future<Map<String, Object?>> _observeTrailing(
  WidgetTester tester,
  _ToolbarLog log,
) async {
  final toolbar = find.byType(CometChatRichTextToolbar);
  final probe = find.descendant(of: toolbar, matching: find.byKey(_probeKey));
  final trailing = probe.evaluate().length;
  // The field the draft was typed into. The doc promises the action the LIVE
  // controller; in the segment layout the composer-level one is a different
  // object, so a type/text check alone would pass a misrouted controller.
  final field = tester.widget<TextField>(
    find
        .descendant(
          of: find.byType(CometChatMessageComposer),
          matching: find.byType(TextField),
        )
        .first,
  );
  if (trailing > 0) {
    await tester.ensureVisible(probe);
    await tester.pump();
    await tester.tap(probe);
    await tester.pump();
  }
  return {
    'toolbar': toolbar.evaluate().length,
    'trailing': trailing,
    'builtFor': log.builtFor?.uid,
    'tappedText': log.tappedText,
    'richController': log.tappedController is RichTextEditingController,
    'liveController': identical(log.tappedController, field.controller),
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// StickerAuxiliaryButton.composerId
// ═════════════════════════════════════════════════════════════════════════════

class _StickerCase {
  const _StickerCase({
    required this.effect,
    required this.composerId,
    required this.foreign,
    required this.own,
  });

  final String effect;

  /// The id the composer hands its button.
  final Map<String, dynamic> composerId;

  /// A hidePanel raised by a different composer: must not reset the button.
  final Map<String, dynamic> foreign;

  /// A hidePanel that targets this button's composer; null is the unaddressed
  /// broadcast CometChatUIKitHelper can raise.
  final Map<String, dynamic>? own;
}

const _stickerMatrix = <_StickerCase>[
  _StickerCase(
    effect: 'ignores a panel event from another conversation',
    composerId: {'uid': 'u1'},
    foreign: {'uid': 'u2'},
    own: {'uid': 'u1'},
  ),
  _StickerCase(
    effect: 'ignores the thread composer opened beside it',
    composerId: {'uid': 'u1'},
    foreign: {'parentMessageId': 42, 'uid': 'u1'},
    own: {'uid': 'u1'},
  ),
  _StickerCase(
    effect: 'on a thread button ignores the parent conversation',
    composerId: {'parentMessageId': 42, 'uid': 'u1'},
    foreign: {'uid': 'u1'},
    own: {'parentMessageId': 42, 'uid': 'u1'},
  ),
  _StickerCase(
    effect: 'ignores another group and still hears an unaddressed broadcast',
    composerId: {'guid': 'g1'},
    foreign: {'guid': 'g2'},
    own: null,
  ),
];

/// 'open' while the sticker panel is up (filled glyph), 'closed' otherwise.
String _stickerState(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byType(StickerAuxiliaryButton),
      matching: find.byType(Image),
    ),
  );
  final asset = (image.image as AssetImage).assetName;
  if (asset == AssetConstants.stickerFilled) return 'open';
  if (asset == AssetConstants.smile) return 'closed';
  return 'unexpected $asset';
}

// ═════════════════════════════════════════════════════════════════════════════
// CometChatConversations.pinConversationOptionVisibility
// ═════════════════════════════════════════════════════════════════════════════

class _PinCase {
  const _PinCase({
    required this.effect,
    required this.deleteVisible,
    required this.subject,
    required this.baseline,
    required this.expected,
    this.pinnedBy,
  });

  final String effect;

  /// Who pinned the long-pressed row; null leaves it unpinned.
  final String? pinnedBy;

  /// deleteConversationOptionVisibility, held fixed across both runs.
  final bool deleteVisible;

  /// pinConversationOptionVisibility in the subject run.
  final bool subject;

  /// Long-press menu labels with the prop unset, and with it set.
  final List<String> baseline;
  final List<String> expected;
}

/// The logged-in user's uid: only a row pinned by this uid offers Unpin.
const _me = 'six-one-one-me';

const _pinMatrix = <_PinCase>[
  _PinCase(
    effect: 'false drops Pin and keeps Delete in the long-press menu',
    deleteVisible: true,
    subject: false,
    baseline: ['Pin', 'Delete'],
    expected: ['Delete'],
  ),
  _PinCase(
    effect: 'false with Delete hidden leaves long-press with no menu',
    deleteVisible: false,
    subject: false,
    baseline: ['Pin'],
    expected: [],
  ),
  _PinCase(
    effect: 'false drops Unpin from a row the logged-in user pinned',
    deleteVisible: true,
    subject: false,
    pinnedBy: _me,
    baseline: ['Unpin', 'Delete'],
    expected: ['Delete'],
  ),
];

_MockConversationsBloc _loadedConversationsBloc({String? pinnedBy}) {
  final bloc = _MockConversationsBloc();
  final state = ConversationsLoaded(
    conversations: [
      _FakeConversation(
        conversationWith: _FakeUser(),
        conversationId: 'user_u1',
        pinnedBy: pinnedBy,
      ),
      _FakeConversation(
        conversationWith: _FakeUser(uid: 'u2', name: 'Bob'),
        conversationId: 'user_u2',
      ),
    ],
    hasMore: false,
  );
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.value(state), initialState: state);
  return bloc;
}

List<String> _menuLabels(WidgetTester tester) => tester
    .widgetList<MenuItemButton>(find.byType(MenuItemButton))
    .map((b) => (b.child! as Text).data!)
    .toList();

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatMessageComposer richTextToolbarActions matrix', () {
    late _MockComposerRepository repo;

    setUp(() {
      repo = _MockComposerRepository();
      when(
        () => repo.getLoggedInUser(),
      ).thenAnswer((_) async => Success(_FakeUser()));
      when(
        () => repo.startTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repo.endTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenAnswer((_) async => const Success(null));
      MessageComposerServiceLocator.instance.reset();
      MessageComposerServiceLocator.instance.setup(repository: repo);
    });

    tearDown(() => MessageComposerServiceLocator.instance.reset());

    for (final c in _composerMatrix) {
      testWidgets('richTextToolbarActions ${c.effect}', (tester) async {
        final observed = <_Run, Map<String, Object?>>{};
        for (final run in _Run.values) {
          final log = _ToolbarLog();
          final composer = CometChatMessageComposer(
            user: _FakeUser(),
            layout: c.layout,
            richTextToolbarActions: run == _Run.subject
                ? _probeActions(log)
                : null,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_wrap(composer));
          await tester.pump();
          await c.open(tester);
          observed[run] = await _observeTrailing(tester, log);
          // Drain the typing debounce before the tree is torn down.
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.pumpWidget(const SizedBox.shrink());

        // Hoisted rather than written inline as `expect(x, {...}, reason:)`.
        // A block-like literal in that position is the one construct the
        // 3.38 and 3.47 formatters disagree on — 3.47 hugs it onto the
        // `expect(` line, 3.38 splits it — so an inline map here makes the
        // file reformat differently depending on who ran `dart format`, and
        // the package-checks format gate (pinned to the pub.dev toolchain)
        // fails for whoever is not on it. A named local has nothing to hug.
        const baseline = {
          'toolbar': 1,
          'trailing': 0,
          'builtFor': null,
          'tappedText': null,
          'richController': false,
          'liveController': false,
        };
        final subject = {
          'toolbar': 1,
          'trailing': 1,
          'builtFor': 'u1',
          'tappedText': _draft,
          'richController': true,
          'liveController': true,
        };
        expect(
          observed[_Run.baseline],
          baseline,
          reason: 'rendered with richTextToolbarActions unset',
        );
        expect(
          observed[_Run.subject],
          subject,
          reason: 'rendered with richTextToolbarActions set',
        );
        expect(
          observed[_Run.subject],
          isNot(equals(observed[_Run.baseline])),
          reason: 'setting richTextToolbarActions changed nothing',
        );
      });
    }
  });

  group('StickerAuxiliaryButton composerId matrix', () {
    for (final c in _stickerMatrix) {
      testWidgets('composerId ${c.effect}', (tester) async {
        final observed = <_Run, List<String>>{};
        for (final run in _Run.values) {
          final button = StickerAuxiliaryButton(
            composerId: run == _Run.subject ? c.composerId : null,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_wrap(Center(child: button)));
          await tester.pump();

          final states = <String>[];
          await tester.tap(find.byType(IconButton));
          await tester.pump();
          states.add(_stickerState(tester));

          CometChatUIEvents.hidePanel(
            c.foreign,
            CustomUIPosition.composerBottom,
          );
          await tester.pump();
          states.add(_stickerState(tester));

          CometChatUIEvents.hidePanel(c.own, CustomUIPosition.composerBottom);
          await tester.pump();
          states.add(_stickerState(tester));

          observed[run] = states;
        }
        await tester.pumpWidget(const SizedBox.shrink());

        // [after the tap, after the foreign event, after its own event]
        // Hoisted for the same reason as the maps above: a block-like literal
        // as an `expect` argument formats differently on 3.38 and 3.47.
        const baseline = ['open', 'closed', 'closed'];
        const subject = ['open', 'open', 'closed'];
        expect(
          observed[_Run.baseline],
          baseline,
          reason: 'with no composerId any composer\'s event resets it',
        );
        expect(
          observed[_Run.subject],
          subject,
          reason: 'with composerId only its own composer\'s event resets it',
        );
        expect(
          observed[_Run.subject],
          isNot(equals(observed[_Run.baseline])),
          reason: 'setting composerId changed nothing',
        );
      });
    }
  });

  group('CometChatConversations pinConversationOptionVisibility matrix', () {
    setUp(() => CometChatUIKit.loggedInUser = _FakeUser(uid: _me, name: 'Me'));
    tearDown(() => CometChatUIKit.loggedInUser = null);

    for (final c in _pinMatrix) {
      testWidgets('pinConversationOptionVisibility ${c.effect}', (
        tester,
      ) async {
        final observed = <_Run, List<String>>{};
        for (final run in _Run.values) {
          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(
              _wrap(
                run == _Run.subject
                    ? CometChatConversations(
                        conversationsBloc: _loadedConversationsBloc(
                          pinnedBy: c.pinnedBy,
                        ),
                        deleteConversationOptionVisibility: c.deleteVisible,
                        pinConversationOptionVisibility: c.subject,
                      )
                    : CometChatConversations(
                        conversationsBloc: _loadedConversationsBloc(
                          pinnedBy: c.pinnedBy,
                        ),
                        deleteConversationOptionVisibility: c.deleteVisible,
                      ),
              ),
            );
            await tester.pump();
            expect(_menuLabels(tester), isEmpty, reason: 'menu before press');

            await tester.longPress(find.text('Alice'));
            await tester.pump(); // the list marks the row open
            await tester.pump(); // post-frame: the MenuController opens
            await tester.pump(const Duration(milliseconds: 300));
          });
          observed[run] = _menuLabels(tester);
        }
        await tester.pumpWidget(const SizedBox.shrink());

        expect(
          observed[_Run.baseline],
          c.baseline,
          reason: 'long-press menu with pinConversationOptionVisibility unset',
        );
        expect(
          observed[_Run.subject],
          c.expected,
          reason: 'long-press menu with pinConversationOptionVisibility set',
        );
        expect(
          observed[_Run.subject],
          isNot(equals(observed[_Run.baseline])),
          reason: 'setting pinConversationOptionVisibility changed nothing',
        );
      });
    }
  });
}
