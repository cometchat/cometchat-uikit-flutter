/// Behaviour tests for [CometChatAnimatedMessageList] — the scrolling engine
/// under [CometChatMessageList].
///
/// These drive the widget through a REAL [AnimatedMessageListBloc] (it is
/// SDK-free: every handler only rewrites its own state and pushes a
/// [MessageOperation] onto the operations stream), so an assertion here pins
/// the same path production takes: bloc event → operation → list animation.
///
///   flutter test test/shared_ui/animated_message_list/animated_message_list_behaviour_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'me', name: 'Me');
final _them = User(uid: 'them', name: 'Them');

/// Item height — every row is exactly this tall so scroll offsets in these
/// tests are arithmetic, not guesswork.
const double _rowHeight = 100;

/// Viewport height for the list under test.
const double _viewport = 300;

TextMessage _msg(int id, {User? sender, DateTime? sentAt}) => TextMessage(
  id: id,
  text: 'msg $id',
  sender: sender ?? _them,
  receiverUid: 'them',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: sentAt ?? DateTime(2024, 1, 1, 12),
);

List<BaseMessage> _msgs(Iterable<int> ids) => [for (final id in ids) _msg(id)];

/// Rows are keyed the way the real message list keys them — a composite
/// `ValueKey<String>` — so [findChildIndexCallback] sees a real key.
Widget _row(
  BuildContext context,
  BaseMessage m,
  int index,
  Animation<double> a,
) {
  return KeyedSubtree(
    key: ValueKey<String>('${m.id}-0-0'),
    child: SizedBox(height: _rowHeight, child: Text('m${m.id}')),
  );
}

Widget _host(Widget list) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 400, height: _viewport, child: list),
    ),
  ),
);

/// Let the operation queue drain.
///
/// The widget hands every operation to `addPostFrameCallback`, which does NOT
/// schedule a frame of its own; in an app the surrounding UI keeps frames
/// coming, but a settled test tree schedules none and `pump()` would be a
/// no-op. Asking the binding for a frame each tick is what makes the queue run.
Future<void> _drain(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Starts a scroll future, drains frames so it can complete, and reports what
/// it answered (null if it never completed).
Future<bool?> _settleScroll(WidgetTester tester, Future<bool> future) async {
  bool? answer;
  unawaited(future.then((value) => answer = value));
  await _drain(tester, frames: 20);
  return answer;
}

Iterable<String> _rowTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((t) => RegExp(r'^m\d+$').hasMatch(t));

double _fade(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(ScrollToBottomButton),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  late AnimatedMessageListBloc bloc;

  /// The bloc has to be built inside the test body, not in `setUp`: its
  /// stream deliveries are scheduled in whatever zone created them, and a
  /// bloc built in `setUp` lands outside the widget test's fake-async zone,
  /// where `pump()` can never flush its events.
  AnimatedMessageListBloc newBloc() {
    final created = AnimatedMessageListBloc();
    addTearDown(created.close);
    return created;
  }

  /// Pumps the list, then seeds it through a `set` operation — the same route
  /// the real message list takes when its first page lands.
  Future<ScrollController> pumpSeeded(
    WidgetTester tester, {
    required List<BaseMessage> seed,
    bool reversed = true,
    Future<void> Function()? onLoadOlder,
    Future<void> Function()? onLoadNewer,
    bool hasMoreNewer = false,
    VoidCallback? onScrollToBottomTap,
    ValueChanged<DateTime?>? onTopVisibleDateChanged,
    String? loggedInUserId,
    LoadMoreBuilder? loadMoreBuilder,
    InitialScrollToEndMode initialScrollToEndMode = InitialScrollToEndMode.jump,
    bool shouldScrollToEndWhenAtBottom = true,
    bool shouldScrollToEndWhenSendingMessage = true,
    int? Function(int)? findMessageIndex,
  }) async {
    bloc = newBloc();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        CometChatAnimatedMessageList(
          bloc: bloc,
          scrollController: controller,
          reversed: reversed,
          itemBuilder: _row,
          onLoadOlder: onLoadOlder,
          onLoadNewer: onLoadNewer,
          hasMoreNewer: hasMoreNewer,
          onScrollToBottomTap: onScrollToBottomTap,
          onTopVisibleDateChanged: onTopVisibleDateChanged,
          loggedInUserId: loggedInUserId,
          loadMoreBuilder: loadMoreBuilder,
          initialScrollToEndMode: initialScrollToEndMode,
          shouldScrollToEndWhenAtBottom: shouldScrollToEndWhenAtBottom,
          shouldScrollToEndWhenSendingMessage:
              shouldScrollToEndWhenSendingMessage,
          findMessageIndex: findMessageIndex,
          topPadding: 0,
          bottomPadding: 0,
        ),
      ),
    );
    bloc.add(SetMessages(seed, animated: false));
    await _drain(tester);
    return controller;
  }

  group('operations reach the list', () {
    testWidgets('set replaces an empty list and clears the empty state', (
      tester,
    ) async {
      bloc = newBloc();
      await tester.pumpWidget(
        _host(
          CometChatAnimatedMessageList(
            bloc: bloc,
            itemBuilder: _row,
            emptyBuilder: (_) => const Text('nothing yet'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('nothing yet'), findsOneWidget);

      bloc.add(SetMessages(_msgs([1, 2, 3]), animated: false));
      await _drain(tester);

      expect(find.text('nothing yet'), findsNothing);
      expect(_rowTexts(tester), containsAll(<String>['m1', 'm2', 'm3']));
    });

    testWidgets('insert puts the new message into the rendered list', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2]));
      expect(_rowTexts(tester), isNot(contains('m3')));

      bloc.add(InsertMessage(_msg(3)));
      await _drain(tester);

      expect(_rowTexts(tester), contains('m3'));
      expect(bloc.state.messages.last.id, 3);
    });

    testWidgets('a non-animated insert lands too', (tester) async {
      await pumpSeeded(tester, seed: _msgs([1, 2]));

      bloc.add(InsertMessage(_msg(3), animated: false));
      await _drain(tester);

      expect(_rowTexts(tester), contains('m3'));
    });

    testWidgets('remove takes the message out of the list', (tester) async {
      final seed = _msgs([1, 2, 3]);
      await pumpSeeded(tester, seed: seed);
      expect(_rowTexts(tester), contains('m2'));

      bloc.add(RemoveMessage(seed[1]));
      await _drain(tester);

      expect(_rowTexts(tester), isNot(contains('m2')));
      expect(_rowTexts(tester), containsAll(<String>['m1', 'm3']));
      expect(bloc.state.messages.map((m) => m.id), <int>[1, 3]);
    });

    testWidgets('update swaps the message in place, keeping the row count', (
      tester,
    ) async {
      final seed = _msgs([1, 2, 3]);
      await pumpSeeded(tester, seed: seed);
      final before = _rowTexts(tester).length;

      final edited = _msg(2)..text = 'edited';
      bloc.add(UpdateMessage(seed[1], edited));
      await _drain(tester);

      expect(_rowTexts(tester).length, before, reason: 'no row added/removed');
      expect((bloc.state.messages[1] as TextMessage).text, 'edited');
    });

    testWidgets('insertAll at index 0 prepends older messages', (tester) async {
      await pumpSeeded(tester, seed: _msgs([5, 6]));

      bloc.add(InsertAllMessages(_msgs([3, 4]), index: 0, animated: false));
      await _drain(tester);

      expect(bloc.state.messages.map((m) => m.id), <int>[3, 4, 5, 6]);
      expect(_rowTexts(tester), containsAll(<String>['m5', 'm6']));
      expect(
        await _settleScroll(tester, bloc.scrollToMessage(3)),
        isTrue,
        reason: 'the prepended message is addressable in the list',
      );
    });

    testWidgets(
      'insertAll at the tail is the newer-insert path and re-reveals the list',
      (tester) async {
        await pumpSeeded(tester, seed: _msgs([1, 2]));

        bloc.add(InsertAllMessages(_msgs([3, 4]), index: 2, animated: false));
        await _drain(tester, frames: 24);

        expect(bloc.state.messages.map((m) => m.id), <int>[1, 2, 3, 4]);
        // The newer-insert path drops opacity to 0 while it rebuilds and
        // restores the anchor; it must always come back to 1.
        expect(
          tester
              .widgetList<Opacity>(find.byType(Opacity))
              .map((o) => o.opacity),
          contains(1.0),
        );
        // The anchor is the message the reader was last looking at (m2), not
        // the newly appended tail — that is the whole point of this path.
        expect(_rowTexts(tester), contains('m2'));
        expect(
          await _settleScroll(
            tester,
            bloc.scrollToMessage(4, duration: Duration.zero),
          ),
          isTrue,
          reason: 'the appended messages are in the list, just below the fold',
        );
      },
    );

    testWidgets('an animated set diffs insertions and removals', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));

      // Drop 2, append 4 — one remove and one insert through the diff.
      bloc.add(SetMessages(_msgs([1, 3, 4])));
      await _drain(tester, frames: 24);

      expect(bloc.state.messages.map((m) => m.id), <int>[1, 3, 4]);
      expect(_rowTexts(tester), contains('m4'));
      expect(_rowTexts(tester), isNot(contains('m2')));
    });

    testWidgets('set back to empty brings the empty state back', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2]));

      bloc.add(SetMessages(const [], animated: false));
      await _drain(tester);

      expect(find.byType(EmptyMessageList), findsOneWidget);
      expect(_rowTexts(tester), isEmpty);
    });
  });

  group('reversed vs normal orientation', () {
    testWidgets('reversed true paints newest at the bottom of the viewport', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
      );

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).reverse,
        isTrue,
      );
      // At offset 0 a reversed list shows the newest messages.
      expect(_rowTexts(tester), contains('m6'));
      expect(_rowTexts(tester), isNot(contains('m1')));
      expect(controller.offset, 0);
    });

    testWidgets('reversed false builds the list top-down and scrolls down', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        reversed: false,
      );

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).reverse,
        isFalse,
      );
      expect(controller.position.maxScrollExtent, 6 * _rowHeight - _viewport);
      // Oldest first: a normal list opens on message 1.
      expect(_rowTexts(tester), contains('m1'));
      expect(_rowTexts(tester), isNot(contains('m6')));

      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      expect(_rowTexts(tester), contains('m6'));
    });

    testWidgets('reversed false with mode none leaves the list at the top', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        reversed: false,
        initialScrollToEndMode: InitialScrollToEndMode.none,
      );

      expect(controller.offset, 0);
      expect(_rowTexts(tester), contains('m1'));
    });
  });

  group('scroll-to-bottom button', () {
    testWidgets('appears once the user scrolls away and jumps back on tap', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
      );
      expect(controller.offset, 0);
      expect(_fade(tester), 0, reason: 'hidden while at the newest end');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await _drain(tester);
      expect(controller.offset, greaterThan(0), reason: 'scrolled away');
      expect(_fade(tester), greaterThan(0), reason: 'the button faded in');

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await _drain(tester);
      expect(controller.offset, 0, reason: 'tapping jumps back to the newest');
    });

    testWidgets('onScrollToBottomTap replaces the built-in scroll', (
      tester,
    ) async {
      var taps = 0;
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        onScrollToBottomTap: () => taps++,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await _drain(tester);
      final offsetBefore = controller.offset;

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await _drain(tester);

      expect(taps, 1);
      expect(
        controller.offset,
        offsetBefore,
        reason: 'the custom callback owns the scroll, the list does not move',
      );
    });

    testWidgets('hasMoreNewer keeps the button up even at offset 0', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        hasMoreNewer: true,
      );
      // Nudge the metrics so the visibility check runs, then come back.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 60));
      await _drain(tester);
      controller.jumpTo(0);
      await _drain(tester);

      expect(
        _fade(tester),
        greaterThan(0),
        reason: 'the list does not hold the latest page yet',
      );
    });

    testWidgets('FINDING: the jump button never shows an unread count. '
        'CometChatAnimatedMessageList builds ScrollToBottomButton without '
        'passing unreadCount, so it stays 0 and the badge branch '
        '(unreadCount > 0) can never render — there is no live new-message '
        'indicator while the user is scrolled up.', (tester) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await _drain(tester);
      expect(_fade(tester), greaterThan(0), reason: 'the button is up');

      // Three messages arrive from the other side while we read history.
      for (final id in [9, 10, 11]) {
        bloc.add(InsertMessage(_msg(id, sender: _them)));
        await _drain(tester);
      }
      expect(bloc.state.messages.length, 11);

      final button = tester.widget<ScrollToBottomButton>(
        find.byType(ScrollToBottomButton),
      );
      // FINDING: any chat UI with an unread badge would report 3 here.
      expect(button.unreadCount, 0);
      expect(find.text('3'), findsNothing);
    });
  });

  group('pagination', () {
    testWidgets('reaching the oldest end asks for older messages', (
      tester,
    ) async {
      var olderCalls = 0;
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        onLoadOlder: () async => olderCalls++,
      );

      // Drag toward older messages — this arms the older-pagination flag —
      // then land at the very top of the reversed list.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
      await _drain(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);

      expect(olderCalls, 1);
    });

    testWidgets('older pagination does not fire before the user scrolls', (
      tester,
    ) async {
      var olderCalls = 0;
      await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        onLoadOlder: () async => olderCalls++,
      );
      await _drain(tester);

      expect(
        olderCalls,
        0,
        reason: 'the flag is only armed by a user scroll gesture',
      );
    });

    testWidgets('loadMoreBuilder renders while older messages are loading', (
      tester,
    ) async {
      final gate = Completer<void>();
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        onLoadOlder: () => gate.future,
        loadMoreBuilder: (_) =>
            const SizedBox(height: 40, child: Text('loading older')),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
      await _drain(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      // The indicator grows the scroll extent; ride to the new top to see it.
      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);

      expect(find.text('loading older'), findsOneWidget);

      gate.complete();
      await _drain(tester);
      expect(find.text('loading older'), findsNothing);
    });

    testWidgets('scrolling back to the newest end asks for newer messages', (
      tester,
    ) async {
      var newerCalls = 0;
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        onLoadNewer: () async => newerCalls++,
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      // Drag back toward the newest end.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await _drain(tester);

      expect(newerCalls, 1);
    });

    testWidgets('a newer load that brings nothing back does not repeat', (
      tester,
    ) async {
      var newerCalls = 0;
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        onLoadNewer: () async => newerCalls++,
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await _drain(tester);
      final afterFirst = newerCalls;
      expect(afterFirst, 1);

      // Sitting at the bottom must not re-trigger: the list length did not
      // change, so the "no more newer" latch stays closed.
      controller.jumpTo(0);
      await _drain(tester);

      expect(newerCalls, afterFirst);
    });
  });

  group('programmatic scrolling through the bloc', () {
    testWidgets('scrollToMessage brings an off-screen message into view', (
      tester,
    ) async {
      DateTime? seenDate;
      await pumpSeeded(
        tester,
        seed: [
          _msg(1, sentAt: DateTime(2024, 1, 1, 9)),
          for (final id in [2, 3, 4, 5, 6, 7, 8])
            _msg(id, sentAt: DateTime(2024, 1, 5, 9)),
        ],
        onTopVisibleDateChanged: (d) => seenDate = d,
      );
      expect(_rowTexts(tester), isNot(contains('m1')));

      final ok = await _settleScroll(
        tester,
        bloc.scrollToMessage(1, duration: Duration.zero),
      );

      expect(ok, isTrue);
      expect(_rowTexts(tester), contains('m1'));
      expect(
        seenDate,
        DateTime(2024, 1, 1),
        reason: 'the sticky date follows the scroll target',
      );
    });

    testWidgets('scrollToMessage answers false for an unknown id', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));
      expect(await bloc.scrollToMessage(999), isFalse);
    });

    testWidgets('scrollToIndex answers false for an out-of-range index', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));
      expect(await bloc.scrollToIndex(99, duration: Duration.zero), isFalse);
      expect(await bloc.scrollToIndex(-1, duration: Duration.zero), isFalse);
    });

    testWidgets('an animated scrollToIndex still lands on the message', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]));

      final ok = await _settleScroll(tester, bloc.scrollToIndex(0));

      expect(ok, isTrue);
      expect(_rowTexts(tester), contains('m1'));
    });

    testWidgets('detaching on dispose makes bloc scrolls no-ops', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pump();

      expect(await bloc.scrollToMessage(1), isFalse);
      expect(await bloc.scrollToIndex(0), isFalse);
    });
  });

  group('sticky date tracking', () {
    testWidgets('reports the topmost visible date and updates as it scrolls', (
      tester,
    ) async {
      final dates = <DateTime?>[];
      await pumpSeeded(
        tester,
        seed: [
          for (final id in [1, 2, 3, 4])
            _msg(id, sentAt: DateTime(2024, 1, 1, 9)),
          for (final id in [5, 6, 7, 8])
            _msg(id, sentAt: DateTime(2024, 3, 4, 9)),
        ],
        onTopVisibleDateChanged: dates.add,
      );

      expect(dates.last, DateTime(2024, 3, 4), reason: 'newest day at rest');

      // Drag up through the January block.
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
        await _drain(tester, frames: 8);
      }

      expect(
        dates.last,
        DateTime(2024, 1, 1),
        reason: 'the oldest day once scrolled to the top',
      );
    });

    testWidgets('the same day is reported once, not on every scroll tick', (
      tester,
    ) async {
      final dates = <DateTime?>[];
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        onTopVisibleDateChanged: dates.add,
      );
      final afterSettle = dates.length;
      expect(afterSettle, greaterThan(0));

      controller.jumpTo(120);
      await _drain(tester);
      controller.jumpTo(240);
      await _drain(tester);

      expect(dates.length, afterSettle, reason: 'all rows share one day');
      expect(dates.last, DateTime(2024, 1, 1));
    });
  });

  group('auto-scroll on new messages', () {
    testWidgets('my own message pulls the list back to the bottom', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        loggedInUserId: 'me',
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await _drain(tester);
      expect(controller.offset, greaterThan(0));

      bloc.add(InsertMessage(_msg(9, sender: _me)));
      await _drain(tester);

      expect(controller.offset, 0);
    });

    testWidgets(
      'an incoming message leaves the list alone once the user scrolled up',
      (tester) async {
        final controller = await pumpSeeded(
          tester,
          seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
          loggedInUserId: 'me',
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
        await _drain(tester);
        final parked = controller.offset;
        expect(parked, greaterThan(0));

        bloc.add(InsertMessage(_msg(9, sender: _them)));
        await _drain(tester);

        expect(
          controller.offset,
          parked,
          reason: 'reading history is not interrupted by an incoming message',
        );
      },
    );

    testWidgets(
      'shouldScrollToEndWhenSendingMessage false keeps my own message from '
      'yanking the list down',
      (tester) async {
        final controller = await pumpSeeded(
          tester,
          seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
          loggedInUserId: 'me',
          shouldScrollToEndWhenSendingMessage: false,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
        await _drain(tester);
        final parked = controller.offset;

        bloc.add(InsertMessage(_msg(9, sender: _me)));
        await _drain(tester);

        expect(controller.offset, parked);
      },
    );
  });

  group('staggered animated batch inserts', () {
    testWidgets('an animated insertAll prepends every older message', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([5, 6]));

      bloc.add(InsertAllMessages(_msgs([2, 3, 4]), index: 0));
      await _drain(tester, frames: 24);

      expect(bloc.state.messages.map((m) => m.id), <int>[2, 3, 4, 5, 6]);
      for (final id in [2, 3, 4]) {
        expect(
          await _settleScroll(
            tester,
            bloc.scrollToMessage(id, duration: Duration.zero),
          ),
          isTrue,
          reason: 'message $id was inserted',
        );
      }
    });

    testWidgets('an animated insertAll on a normal list appends in order', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2]),
        reversed: false,
      );

      bloc.add(InsertAllMessages(_msgs([3, 4, 5]), index: 2));
      await _drain(tester, frames: 24);

      expect(bloc.state.messages.map((m) => m.id), <int>[1, 2, 3, 4, 5]);
      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      expect(_rowTexts(tester), contains('m5'));
    });
  });

  group('normal (non-reversed) scrolling', () {
    testWidgets('the jump button flings a normal list down to the newest', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        reversed: false,
        initialScrollToEndMode: InitialScrollToEndMode.none,
      );
      // Scrolling away from the end (which is the bottom here) shows it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await _drain(tester);
      expect(_fade(tester), greaterThan(0));

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await _drain(tester, frames: 24);

      expect(controller.offset, controller.position.maxScrollExtent);
    });

    testWidgets('my own message scrolls a normal list to the newest end', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
        reversed: false,
        initialScrollToEndMode: InitialScrollToEndMode.none,
        loggedInUserId: 'me',
      );
      expect(controller.offset, 0);

      bloc.add(InsertMessage(_msg(9, sender: _me)));
      await _drain(tester, frames: 24);

      expect(controller.offset, controller.position.maxScrollExtent);
      expect(_rowTexts(tester), contains('m9'));
    });

    testWidgets('initialScrollToEndMode.animate is accepted by a normal list', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4]),
        reversed: false,
        initialScrollToEndMode: InitialScrollToEndMode.animate,
      );

      expect(controller.hasClients, isTrue);
      expect(_rowTexts(tester), isNotEmpty);
    });
  });

  group('alignment-aware scrolling', () {
    testWidgets('an instant scrollToIndex with alignment pushes the row up', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
      );

      final flush = await _settleScroll(
        tester,
        bloc.scrollToIndex(4, duration: Duration.zero),
      );
      expect(flush, isTrue);
      final leadingEdge = controller.offset;
      expect(leadingEdge, lessThan(controller.position.maxScrollExtent));

      final aligned = await _settleScroll(
        tester,
        bloc.scrollToIndex(4, alignment: 0.5, duration: Duration.zero),
      );

      expect(aligned, isTrue);
      expect(
        controller.offset,
        greaterThan(leadingEdge),
        reason: 'alignment 0.5 pushes the target half a viewport further',
      );
    });

    testWidgets('an animated scrollToIndex with alignment also lands', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6, 7, 8]),
      );

      final ok = await _settleScroll(
        tester,
        bloc.scrollToIndex(0, alignment: 0.5),
      );

      expect(ok, isTrue);
      expect(controller.offset, greaterThan(0));
    });
  });

  group('child index reuse', () {
    testWidgets('findMessageIndex is consulted when rows move. '
        'findChildIndexCallback only runs for a child widget that carries a '
        'Key; every row is now keyed by its message (muid, else id), so the '
        'sliver looks rows up through the O(1) findMessageIndex hook and '
        'reuses them on an insert instead of rebuilding them. They used to '
        'sit in an unkeyed RepaintBoundary, which made the lookup dead code.', (
      tester,
    ) async {
      final asked = <int>[];
      await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3]),
        findMessageIndex: (id) {
          asked.add(id);
          return bloc.findMessageIndex(id);
        },
      );

      // Inserts and removals are exactly when a list reuses keyed children.
      bloc.add(InsertMessage(_msg(4)));
      await _drain(tester);
      bloc.add(InsertAllMessages(_msgs([0]), index: 0, animated: false));
      await _drain(tester);

      expect(_rowTexts(tester), contains('m4'));
      expect(asked, isNotEmpty);
    });
  });
}
