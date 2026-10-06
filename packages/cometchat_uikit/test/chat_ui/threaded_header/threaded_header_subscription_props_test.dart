/// Render-verified prop matrix for the two [CometChatThreadedHeader] props new
/// in 6.1.1 — Track 3 PROP1 (ENG-38688, coverage part 2, round 2):
/// threadSubscriptionVisibility and onThreadSubscriptionChange. The other 13
/// are covered by preview_and_threaded_style_props_test.dart and
/// core_widget_props_test.dart.
///
/// Both props drive the follow control in the reply-count row, which renders
/// only with the thread-subscription feature gate on. The header takes a mock
/// ThreadedHeaderBloc through its threadedHeaderBloc seam. The control's tap
/// reaches the SDK through CometChat.subscribeToThread, which has no seam, so
/// the fake sits where the SDK resolves its ThreadRepository (SdkRegistry), as
/// search_props_test.dart does for its repositories.
///
/// Each case renders twice in one test body, first with its prop at the
/// constructor default and then set, and asserts both observations and that
/// they differ. A header that ignored the prop would render the baseline twice
/// and fail the case.
///
///   flutter test test/chat_ui/threaded_header/threaded_header_subscription_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; see the library comment. Both files exist in
// the local SDK and in the hosted 5.0.7.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/threads/thread_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────

const _parentId = 7401;
const _secondParentId = 7402;

// Localized tooltips of the follow control (TranslationsEn).
const _subscribeLabel = 'Subscribe to thread';
const _unsubscribeLabel = 'Unsubscribe from thread';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(uid: 'me-7T', name: 'Me 7T');
final _peer = User(uid: 'u-cara-7T', name: 'Cara 7T');

/// The thread root. Built fresh for every run: the header reads its id, and
/// the bloc stamps its subscription flag.
TextMessage _parent({required bool subscribed}) =>
    TextMessage(
        id: _parentId,
        text: 'thread root 7T',
        sender: _peer,
        receiverUid: _me.uid,
        type: MessageTypeConstants.text,
        receiverType: ReceiverTypeConstants.user,
        category: MessageCategoryConstants.message,
        sentAt: DateTime(2026, 3, 14, 9, 30),
      )
      ..replyCount = 3
      ..threadSubscribed = subscribed;

class _MockThreadedHeaderBloc
    extends MockBloc<ThreadedHeaderEvent, ThreadedHeaderState>
    implements ThreadedHeaderBloc {}

_MockThreadedHeaderBloc _headerBloc(BaseMessage parent) {
  final state = ThreadedHeaderState(
    status: ThreadedHeaderStatus.loaded,
    parentMessage: parent,
    replyCount: 3,
    loggedInUser: _me,
    user: _peer,
    threadSubscribed: parent.threadSubscribed,
  );
  final bloc = _MockThreadedHeaderBloc();
  whenListen(
    bloc,
    Stream<ThreadedHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

// ─── SDK fakes ───────────────────────────────────────────────────────────────

/// Which thread calls reached the SDK. Fresh for every run.
class _FakeBackend {
  final threadCalls = <String>[];
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
    : threads = _FakeThreadRepository(backend);

  @override
  final sdk.ThreadRepository threads;

  @override
  Future<void> dispose() async {}
}

// ─── Matrix plumbing ─────────────────────────────────────────────────────────

/// What onThreadSubscriptionChange received, as 'parentMessageId:subscribed'.
class _Log {
  final changes = <String>[];
}

/// The two props, defaulting to the header's own constructor defaults so the
/// baseline run renders exactly what an integrator who omits them gets.
/// threadSubscriptionVisibility is passed explicitly here, so the last test
/// in this file pumps it omitted and pins that claim.
class _Props {
  const _Props({
    this.threadSubscriptionVisibility = true,
    this.onThreadSubscriptionChange,
  });

  final bool? threadSubscriptionVisibility;
  final void Function(int parentMessageId, bool subscribed)?
  onThreadSubscriptionChange;
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
    required this.subscribed,
    required this.subject,
    required this.probe,
    required this.baseline,
    required this.expected,
  });

  final String prop;
  final String effect;

  /// Whether the thread root arrives subscribed, in both runs.
  final bool subscribed;

  /// Props with [prop] set; the baseline run uses `const _Props()`.
  final _Props Function(_Log log) subject;

  /// Drives the rendered header and returns what it observed.
  final _Probe probe;

  /// Value or matcher for the observation with [prop] at its default.
  final Object? baseline;

  /// Value or matcher for the observation with [prop] set.
  final Object? expected;
}

Widget _wrap(Widget header) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: header),
);

/// Tooltips of the follow controls on screen — one per rendered control.
List<String> _followControls(WidgetTester tester) => tester
    .widgetList<IconButton>(find.byType(IconButton))
    .where((button) {
      final icon = button.icon;
      return icon is Icon &&
          (icon.icon == Icons.notifications_outlined ||
              icon.icon == Icons.notifications_off_outlined);
    })
    .map((button) => button.tooltip ?? '')
    .toList();

/// Taps the follow control, lets the SDK call resolve, then runs out the
/// thread toast's two-second dismiss timer so no timer outlives the tree.
Future<void> _toggle(WidgetTester tester, IconData glyph) async {
  await tester.tap(find.byIcon(glyph));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

// ─── The matrix ──────────────────────────────────────────────────────────────

final _matrix = <_Case>[
  _Case(
    prop: 'threadSubscriptionVisibility',
    effect: 'false hides the follow control',
    subscribed: false,
    subject: (log) => const _Props(threadSubscriptionVisibility: false),
    probe: (tester, log, backend) async => _followControls(tester),
    baseline: [_subscribeLabel],
    expected: <String>[],
  ),
  _Case(
    prop: 'onThreadSubscriptionChange',
    effect: 'reports a successful subscribe with the parent id and true',
    subscribed: false,
    subject: (log) => _Props(
      onThreadSubscriptionChange: (id, subscribed) =>
          log.changes.add('$id:$subscribed'),
    ),
    probe: (tester, log, backend) async {
      await _toggle(tester, Icons.notifications_off_outlined);
      return {
        'threadCalls': [...backend.threadCalls],
        'reported': [...log.changes],
      };
    },
    // The toggle reaches the SDK either way; only the report differs.
    baseline: {
      'threadCalls': ['subscribe:$_parentId'],
      'reported': <String>[],
    },
    expected: {
      'threadCalls': ['subscribe:$_parentId'],
      'reported': ['$_parentId:true'],
    },
  ),
  _Case(
    prop: 'onThreadSubscriptionChange',
    effect: 'reports a successful unsubscribe with the parent id and false',
    subscribed: true,
    subject: (log) => _Props(
      onThreadSubscriptionChange: (id, subscribed) =>
          log.changes.add('$id:$subscribed'),
    ),
    probe: (tester, log, backend) async {
      final before = _followControls(tester);
      await _toggle(tester, Icons.notifications_outlined);
      return {
        'control': before,
        'threadCalls': [...backend.threadCalls],
        'reported': [...log.changes],
      };
    },
    baseline: {
      'control': [_unsubscribeLabel],
      'threadCalls': ['unsubscribe:$_parentId'],
      'reported': <String>[],
    },
    expected: {
      'control': [_unsubscribeLabel],
      'threadCalls': ['unsubscribe:$_parentId'],
      'reported': ['$_parentId:false'],
    },
  ),
];

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    CometChatUIKit.loggedInUser = _me;
    // The follow control is gated behind the thread-subscription feature flag.
    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()..enableThreadSubscription = true).build();
  });

  tearDown(() async {
    CometChatUIKit.authenticationSettings = null;
    CometChatUIKit.loggedInUser = null;
    await sdk.SdkRegistry.clear();
  });

  test('the matrix covers exactly the two 6.1.1 props', () {
    expect(_matrix.map((c) => c.prop).toSet(), {
      'threadSubscriptionVisibility',
      'onThreadSubscriptionChange',
    });
  });

  group('CometChatThreadedHeader 6.1.1 prop matrix', () {
    for (final c in _matrix) {
      testWidgets('${c.prop} ${c.effect}', (tester) async {
        final observed = <_Run, Object?>{};
        for (final run in _Run.values) {
          final log = _Log();
          final backend = _FakeBackend();
          await sdk.SdkRegistry.clear();
          sdk.SdkRegistry.register(_FakeSdkClient(backend));
          final p = run == _Run.subject ? c.subject(log) : const _Props();
          final parent = _parent(subscribed: c.subscribed);

          final header = CometChatThreadedHeader(
            parentMessage: parent,
            loggedInUser: _me,
            threadedHeaderBloc: _headerBloc(parent),
            threadSubscriptionVisibility: p.threadSubscriptionVisibility,
            onThreadSubscriptionChange: p.onThreadSubscriptionChange,
          );

          // A fresh tree per run: the toggle's debounce lives in the state.
          await tester.pumpWidget(const SizedBox.shrink());
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(_wrap(header));
            await tester.pump();
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

  // The matrix passes threadSubscriptionVisibility in every run, so its
  // baseline is "on" only because _Props says so. This pump leaves it out,
  // which is what an integrator who never mentions it gets. A constructor
  // default flipped to false fails here and nowhere in the matrix.
  testWidgets('threadSubscriptionVisibility renders the control when omitted', (
    tester,
  ) async {
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient(_FakeBackend()));
    final parent = _parent(subscribed: false);
    late final List<String> controls;
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(
          CometChatThreadedHeader(
            parentMessage: parent,
            loggedInUser: _me,
            threadedHeaderBloc: _headerBloc(parent),
          ),
        ),
      );
      await tester.pump();
      controls = _followControls(tester);
    });
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controls, [_subscribeLabel]);
  });

  // parentMessage can move to another root on a mounted header. Whatever the
  // header shows, its follow control, SDK call and report must name the same
  // thread.
  group('a new parentMessage', () {
    TextMessage secondRoot() =>
        TextMessage(
            id: _secondParentId,
            text: 'thread root two 7T',
            sender: _peer,
            receiverUid: _me.uid,
            type: MessageTypeConstants.text,
            receiverType: ReceiverTypeConstants.user,
            category: MessageCategoryConstants.message,
            sentAt: DateTime(2026, 3, 14, 9, 45),
          )
          ..replyCount = 5
          ..threadSubscribed = false;

    Widget header(BaseMessage root, _Log log, {ThreadedHeaderBloc? bloc}) =>
        _wrap(
          CometChatThreadedHeader(
            parentMessage: root,
            loggedInUser: _me,
            threadedHeaderBloc: bloc,
            onThreadSubscriptionChange: (id, subscribed) =>
                log.changes.add('$id:$subscribed'),
          ),
        );

    testWidgets('re-initializes the header own bloc onto it', (tester) async {
      final backend = _FakeBackend();
      await sdk.SdkRegistry.clear();
      sdk.SdkRegistry.register(_FakeSdkClient(backend));
      final log = _Log();
      final first = _parent(subscribed: true);
      final second = secondRoot();
      late final List<String> controls;
      late final bool showsSecond;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(header(first, log));
        await tester.pump();
        await tester.pumpWidget(header(second, log));
        await tester.pump();
        controls = _followControls(tester);
        showsSecond = find
            .text('thread root two 7T', findRichText: true)
            .evaluate()
            .isNotEmpty;
        if (controls.contains(_subscribeLabel)) {
          await _toggle(tester, Icons.notifications_off_outlined);
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());

      expect(showsSecond, isTrue, reason: 'the bubble kept the first root');
      expect(controls, [_subscribeLabel]);
      expect(backend.threadCalls, ['subscribe:$_secondParentId']);
      expect(log.changes, ['$_secondParentId:true']);
      expect([first.threadSubscribed, second.threadSubscribed], [true, true]);
    });

    testWidgets('with an injected bloc, a tap acts on the root it shows', (
      tester,
    ) async {
      final backend = _FakeBackend();
      await sdk.SdkRegistry.clear();
      sdk.SdkRegistry.register(_FakeSdkClient(backend));
      final log = _Log();
      final first = _parent(subscribed: true);
      // The owner has not re-initialized its bloc, so it still holds first.
      final bloc = _headerBloc(first);
      late final List<String> controls;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(header(first, log, bloc: bloc));
        await tester.pump();
        await tester.pumpWidget(header(secondRoot(), log, bloc: bloc));
        await tester.pump();
        controls = _followControls(tester);
        await _toggle(tester, Icons.notifications_outlined);
      });
      await tester.pumpWidget(const SizedBox.shrink());

      expect(controls, [_unsubscribeLabel]);
      expect(backend.threadCalls, ['unsubscribe:$_parentId']);
      expect(log.changes, ['$_parentId:false']);
    });
  });
}
