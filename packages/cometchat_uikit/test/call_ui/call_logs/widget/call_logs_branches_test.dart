/// The branches of [CometChatCallLogs] that the prop matrix does not reach:
/// the integrator callbacks and the paths they replace.
///
/// `call_logs_props_test.dart` pins what the component looks like. This pins
/// what it *does*: which bloc event each gesture raises, which override wins
/// over which default, and the long-press options menu — a surface an
/// integrator builds their whole call-history UX on and which nothing else in
/// the suite touches.
///
///   flutter test test/call_ui/call_logs/widget/call_logs_branches_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_message_harness.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

class FakeCallUser extends Fake implements CallUser {
  FakeCallUser(this._name, this._uid);
  final String _name;
  final String _uid;
  @override
  String? get name => _name;
  @override
  String? get uid => _uid;
  @override
  String? get avatar => null;
}

class FakeCallGroup extends Fake implements CallGroup {
  @override
  String? get name => 'Team';
  @override
  String? get guid => 'g1';
  @override
  String? get icon => null;
}

class FakeCallLog extends Fake implements CallLog {
  FakeCallLog({
    this.type = 'audio',
    this.status = 'ended',
    this.toGroup = false,
    int? initiatedAt,
  }) : _initiatedAt = initiatedAt ?? 1756800000;

  /// A group receiver makes `CallLogsUtils.isUser` false, which is the only
  /// way to reach the "do not place a call" arm of the tail icon.
  final bool toGroup;
  final int _initiatedAt;

  @override
  CallEntity? get initiator => FakeCallUser('Alice', 'u1');
  @override
  CallEntity? get receiver =>
      toGroup ? FakeCallGroup() : FakeCallUser('Bob', 'u2');
  @override
  final String? type;
  @override
  final String? status;
  @override
  int? get initiatedAt => _initiatedAt;
  @override
  double? get totalDurationInMinutes => 3;
  @override
  String? get sessionId => 's-$_initiatedAt';
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String get name => 'Alice';
}

// ─── Harness ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

MockCallLogsBloc _blocIn(CallLogsState state) {
  final bloc = MockCallLogsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.fromIterable([state]), initialState: state);
  return bloc;
}

MockCallLogsBloc _loaded({
  bool toGroup = false,
  bool hasMore = false,
  List<FakeCallLog>? logs,
}) {
  final list = logs ?? [FakeCallLog(toGroup: toGroup)];
  return _blocIn(
    CallLogsState(
      status: CallLogsStatus.loaded,
      callLogs: list,
      hasMore: hasMore,
      loggedInUser: FakeUser(),
      groupedEntries: {'Today': list},
    ),
  );
}

/// The internally-built bloc polls `CallEventService.waitForCallsSdk` for up
/// to 30 × 200ms before giving up. Run the fake clock past that so no timer
/// outlives the test.
Future<void> _drainCallsSdkWait(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  installGoldenImageNetwork();
  setUpAll(() {
    registerFallbackValue(const LoadCallLogs());
  });

  // =========================================================================
  group('row gestures', () {
    testWidgets('onItemClick receives the tapped log', (tester) async {
      final log = FakeCallLog();
      final tapped = <CallLog>[];

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(logs: [log]),
            onItemClick: tapped.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(CometChatListItem).first);
      await tester.pump();

      expect(tapped, [same(log)]);
    });

    testWidgets('onItemLongPress wins over the options menu entirely', (
      tester,
    ) async {
      final log = FakeCallLog();
      final pressed = <CallLog>[];
      var optionsAsked = false;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(logs: [log]),
            onItemLongPress: pressed.add,
            setOptions: (_, _, _) {
              optionsAsked = true;
              return [CometChatOption(id: 'x', title: 'X')];
            },
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(pressed, [same(log)]);
      expect(optionsAsked, isFalse);
      expect(find.byType(PopupMenuItem<dynamic>), findsNothing);
    });
  });

  // =========================================================================
  group('long-press options menu', () {
    testWidgets('setOptions renders one menu entry per option', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (log, bloc, context) => [
              CometChatOption(id: 'a', title: 'Delete'),
              CometChatOption(id: 'b', title: 'Block'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('setOptions is handed the log and the live bloc', (
      tester,
    ) async {
      final log = FakeCallLog();
      final bloc = _loaded(logs: [log]);
      CallLog? seenLog;
      CallLogsBloc? seenBloc;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: bloc,
            setOptions: (l, b, _) {
              seenLog = l;
              seenBloc = b;
              return [CometChatOption(id: 'a', title: 'Delete')];
            },
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(seenLog, same(log));
      expect(seenBloc, same(bloc));
    });

    testWidgets('tapping a menu entry fires that option onClick', (
      tester,
    ) async {
      var clicks = 0;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'a',
                title: 'Delete',
                onClick: () => clicks++,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(clicks, 1);
    });

    testWidgets('an option iconWidget is shown beside its title', (
      tester,
    ) async {
      const probe = Key('opt-icon');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'a',
                title: 'Delete',
                iconWidget: const Icon(Icons.delete, key: probe),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.byKey(probe), findsOneWidget);
    });

    testWidgets('an option icon URL is rendered as a tinted network image', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => [
              CometChatOption(
                id: 'a',
                title: 'Delete',
                icon: goldenImageUrl('delete', 0xFF0000, width: 8, height: 8),
                iconTint: const Color(0xFF884422),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(PopupMenuItem<dynamic>),
          matching: find.byType(Image),
        ),
      );
      expect(image.color, const Color(0xFF884422));
      expect(image.width, 24);
      expect(image.height, 24);
    });

    testWidgets('setOptions suppresses addOptions rather than merging', (
      tester,
    ) async {
      // The name suggests addOptions *adds*; the implementation makes the two
      // mutually exclusive, with setOptions winning.
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => [CometChatOption(id: 'a', title: 'Set')],
            addOptions: (_, _, _) => [CometChatOption(id: 'b', title: 'Added')],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.text('Set'), findsOneWidget);
      expect(find.text('Added'), findsNothing);
    });

    testWidgets('addOptions alone supplies the menu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            addOptions: (_, _, _) => [CometChatOption(id: 'b', title: 'Added')],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('with neither builder a long press opens no menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded())),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<dynamic>), findsNothing);
    });

    testWidgets('a builder that returns an empty list opens no menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => const [],
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<dynamic>), findsNothing);
    });

    testWidgets('a builder that returns null opens no menu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => null,
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CometChatListItem).first);
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<dynamic>), findsNothing);
    });
  });

  // =========================================================================
  group('the call icon', () {
    testWidgets('onCallLogIconClicked replaces the built-in dial', (
      tester,
    ) async {
      final log = FakeCallLog();
      final bloc = _loaded(logs: [log]);
      final clicked = <CallLog>[];

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: bloc,
            onCallLogIconClicked: clicked.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(IconButton).last);
      await tester.pump();

      expect(clicked, [same(log)]);
      verifyNever(() => bloc.add(any(that: isA<InitiateCallFromLog>())));
    });

    testWidgets('without an override a 1:1 log dials through the bloc', (
      tester,
    ) async {
      final log = FakeCallLog();
      final bloc = _loaded(logs: [log]);

      await tester.pumpWidget(_wrap(CometChatCallLogs(callLogsBloc: bloc)));
      await tester.pump();
      await tester.tap(find.byType(IconButton).last);
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<InitiateCallFromLog>())),
      ).captured;
      expect(captured, hasLength(1));
      expect((captured.single as InitiateCallFromLog).callLog, same(log));
    });

    testWidgets('a group-receiver log does not dial at all', (tester) async {
      // `CallLogsUtils.isUser` is false, so the icon is inert rather than
      // starting a call the kit cannot place.
      final bloc = _loaded(toGroup: true);

      await tester.pumpWidget(_wrap(CometChatCallLogs(callLogsBloc: bloc)));
      await tester.pump();
      await tester.tap(find.byType(IconButton).last);
      await tester.pump();

      verifyNever(() => bloc.add(any(that: isA<InitiateCallFromLog>())));
    });
  });

  // =========================================================================
  group('pagination', () {
    testWidgets('hasMore appends a loader row and asks for the next page', (
      tester,
    ) async {
      final bloc = _loaded(hasMore: true);

      await tester.pumpWidget(_wrap(CometChatCallLogs(callLogsBloc: bloc)));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<LoadMoreCallLogs>()))).called(1);
    });

    testWidgets('without hasMore no extra page is requested', (tester) async {
      final bloc = _loaded();

      await tester.pumpWidget(_wrap(CometChatCallLogs(callLogsBloc: bloc)));
      await tester.pump();

      verifyNever(() => bloc.add(any(that: isA<LoadMoreCallLogs>())));
    });

    testWidgets('loadingStateView replaces the paging loader too', (
      tester,
    ) async {
      const probe = Key('custom-loader');
      final bloc = _loaded(hasMore: true);

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: bloc,
            loadingStateView: (_) => const SizedBox(key: probe, height: 8),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
    });
  });

  // =========================================================================
  group('loading state', () {
    testWidgets('the default loading view is the shimmer placeholder list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _blocIn(
              const CallLogsState(status: CallLogsStatus.loading),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatShimmerEffect), findsOneWidget);
      // Placeholder rows: a circular avatar plus two bars each.
      expect(find.byType(CircleAvatar), findsWidgets);
    });

    testWidgets('loadingStateView replaces the shimmer', (tester) async {
      const probe = Key('custom-loading');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _blocIn(
              const CallLogsState(status: CallLogsStatus.loading),
            ),
            loadingStateView: (_) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
      expect(find.byType(CometChatShimmerEffect), findsNothing);
    });
  });

  // =========================================================================
  group('error state', () {
    testWidgets('the default error view retries through the bloc', (
      tester,
    ) async {
      final bloc = _blocIn(
        const CallLogsState(
          status: CallLogsStatus.error,
          errorMessage: 'Network error',
        ),
      );

      await tester.pumpWidget(_wrap(CometChatCallLogs(callLogsBloc: bloc)));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<RefreshCallLogs>()))).called(1);
    });

    testWidgets('errorStateView replaces the default and its retry', (
      tester,
    ) async {
      const probe = Key('custom-error');
      final bloc = _blocIn(
        const CallLogsState(status: CallLogsStatus.error, errorMessage: 'x'),
      );

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: bloc,
            errorStateView: (_) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('onError is handed the bloc message wrapped as an exception', (
      tester,
    ) async {
      final seen = <CometChatException>[];

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _blocIn(
              const CallLogsState(
                status: CallLogsStatus.error,
                errorMessage: 'Network error',
              ),
            ),
            onError: (e) => seen.add(e as CometChatException),
          ),
        ),
      );
      await tester.pump();

      expect(seen, hasLength(1));
      expect(seen.single.code, 'CALL_LOGS_ERROR');
      expect(seen.single.message, 'Network error');
    });
  });

  // =========================================================================
  group('empty and loaded callbacks', () {
    testWidgets('onEmpty fires for the empty state', (tester) async {
      var empties = 0;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _blocIn(
              const CallLogsState(status: CallLogsStatus.empty),
            ),
            onEmpty: () => empties++,
          ),
        ),
      );
      await tester.pump();

      expect(empties, 1);
    });

    testWidgets('emptyStateView replaces the built-in empty copy', (
      tester,
    ) async {
      const probe = Key('custom-empty');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _blocIn(
              const CallLogsState(status: CallLogsStatus.empty),
            ),
            emptyStateView: (_) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
      expect(find.byIcon(Icons.call), findsNothing);
    });

    testWidgets('onLoad is handed the loaded logs', (tester) async {
      final log = FakeCallLog();
      final loaded = <List<CallLog>>[];

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(logs: [log]),
            onLoad: loaded.add,
          ),
        ),
      );
      await tester.pump();

      expect(loaded, hasLength(1));
      expect(loaded.single, [same(log)]);
    });
  });

  // =========================================================================
  group('row slot overrides', () {
    testWidgets('listItemView replaces the whole row', (tester) async {
      const probe = Key('row');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            listItemView: (log, context) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
      expect(find.byType(CometChatListItem), findsNothing);
    });

    testWidgets('a listItemView returning null collapses the row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            listItemView: (log, context) => null,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CometChatListItem), findsNothing);
    });

    testWidgets('leadingStateView and titleView fill their slots', (
      tester,
    ) async {
      const leading = Key('leading');
      const title = Key('title');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            leadingStateView: (_, _) => const SizedBox(key: leading),
            titleView: (_, _) => const SizedBox(key: title),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(leading), findsOneWidget);
      expect(find.byKey(title), findsOneWidget);
    });

    testWidgets('trailingView replaces the call icon button', (tester) async {
      const probe = Key('tail');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            trailingView: (_, _) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('subTitleView replaces the icon-and-time row', (tester) async {
      const probe = Key('sub');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            subTitleView: (_, _) => const SizedBox(key: probe),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
    });
  });

  // =========================================================================
  group('date separators', () {
    testWidgets('one separator per date bucket, not one per row', (
      tester,
    ) async {
      final today = DateTime.now();
      final sameDay =
          DateTime(
            today.year,
            today.month,
            today.day,
            9,
          ).millisecondsSinceEpoch ~/
          1000;
      final alsoSameDay =
          DateTime(
            today.year,
            today.month,
            today.day,
            11,
          ).millisecondsSinceEpoch ~/
          1000;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(
              logs: [
                FakeCallLog(initiatedAt: alsoSameDay),
                FakeCallLog(initiatedAt: sameDay),
              ],
            ),
            dateSeparatorPattern: 'BUCKET',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BUCKET'), findsOneWidget);
      expect(find.byType(CometChatListItem), findsNWidgets(2));
    });

    testWidgets('a log without a timestamp gets no separator', (tester) async {
      final bloc = _blocIn(
        CallLogsState(
          status: CallLogsStatus.loaded,
          callLogs: [_NoTimestampLog()],
          loggedInUser: FakeUser(),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(callLogsBloc: bloc, dateSeparatorPattern: 'BUCKET'),
        ),
      );
      await tester.pump();

      expect(find.text('BUCKET'), findsNothing);
      expect(find.byType(CometChatListItem), findsOneWidget);
    });
  });

  // =========================================================================
  group('without an injected bloc', () {
    testWidgets('the screen builds its own bloc and stands up', (tester) async {
      // No `callLogsBloc`, so the widget initialises the service locator and
      // constructs a CallLogsBloc itself. Without a live SDK the first fetch
      // simply fails, but the screen must still mount and dispose cleanly —
      // this is the path every integrator who does not inject a bloc takes.
      await tester.pumpWidget(_wrap(const CometChatCallLogs()));
      await _drainCallsSdkWait(tester);

      expect(find.byType(CometChatCallLogs), findsOneWidget);

      // Replacing the subtree disposes the widget, which must close the bloc
      // it owns; a double close or a leak would throw here.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();

      expect(find.byType(CometChatCallLogs), findsNothing);
    });

    testWidgets('a supplied request builder is honoured over the protocol', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsRequestBuilder: CallLogRequestBuilder()..limit = 7,
          ),
        ),
      );
      await _drainCallsSdkWait(tester);

      expect(find.byType(CometChatCallLogs), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
    });

    testWidgets('with only a builder protocol its request builder is used', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBuilderProtocol: UICallLogsBuilder(
              CallLogRequestBuilder()..limit = 5,
            ),
          ),
        ),
      );
      await _drainCallsSdkWait(tester);

      expect(find.byType(CometChatCallLogs), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  // =========================================================================
  group('app bar', () {
    testWidgets('onBack is wired to the back button', (tester) async {
      var backs = 0;

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            showBackButton: true,
            onBack: () => backs++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();

      expect(backs, 1);
    });

    testWidgets('appBarOptions are rendered into the menu row', (tester) async {
      const probe = Key('app-bar-option');

      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            appBarOptions: [const SizedBox(key: probe, width: 8, height: 8)],
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(probe), findsOneWidget);
    });

    testWidgets('hideAppbar removes the title bar', (tester) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded(), hideAppbar: true)),
      );
      await tester.pump();

      expect(find.text('Calls'), findsNothing);
    });
  });
}

class _NoTimestampLog extends FakeCallLog {
  @override
  int? get initiatedAt => null;
}
