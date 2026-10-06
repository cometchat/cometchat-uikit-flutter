/// The corners of [CometChatAnimatedMessageList] that
/// `animated_message_list_behaviour_test.dart` does not reach: the child-index
/// reuse callback, the newer-page loading indicator, the short-list initial
/// scroll, and the keyboard-follow path for normal (non-reversed) lists.
///
/// Same rules as the behaviour suite: the widget hands its work to
/// `addPostFrameCallback`, which schedules no frame of its own, so every
/// settle has to ask the binding for one; and a bloc built in `setUp` would
/// live outside the fake-async zone, so each test builds its own.
///
///   flutter test test/shared_ui/animated_message_list/animated_message_list_gaps_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'me', name: 'Me');
final _them = User(uid: 'them', name: 'Them');

const double _rowHeight = 100;
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

Widget _row(
  BuildContext context,
  BaseMessage m,
  int index,
  Animation<double> a,
) => KeyedSubtree(
  key: ValueKey<String>('${m.id}-0-0'),
  child: SizedBox(height: _rowHeight, child: Text('m${m.id}')),
);

Widget _host(Widget list) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 400, height: _viewport, child: list),
    ),
  ),
);

Future<void> _drain(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Iterable<String> _rowTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((t) => RegExp(r'^m\d+$').hasMatch(t));

void main() {
  late AnimatedMessageListBloc bloc;

  AnimatedMessageListBloc newBloc() {
    final created = AnimatedMessageListBloc();
    addTearDown(created.close);
    return created;
  }

  Future<ScrollController> pumpSeeded(
    WidgetTester tester, {
    required List<BaseMessage> seed,
    bool reversed = true,
    Future<void> Function()? onLoadNewer,
    bool hasMoreNewer = false,
    LoadMoreBuilder? loadMoreBuilder,
    int? Function(int)? findMessageIndex,
    String? loggedInUserId,
    ComposerHeightNotifier? composerHeightNotifier,
    Duration scrollToEndAnimationDuration = const Duration(milliseconds: 250),
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
          onLoadNewer: onLoadNewer,
          hasMoreNewer: hasMoreNewer,
          loadMoreBuilder: loadMoreBuilder,
          findMessageIndex: findMessageIndex,
          loggedInUserId: loggedInUserId,
          composerHeightNotifier: composerHeightNotifier,
          scrollToEndAnimationDuration: scrollToEndAnimationDuration,
          topPadding: 0,
          bottomPadding: 0,
        ),
      ),
    );
    bloc.add(SetMessages(seed, animated: false));
    await _drain(tester);
    return controller;
  }

  SliverAnimatedList sliverList(WidgetTester tester) =>
      tester.widget<SliverAnimatedList>(find.byType(SliverAnimatedList));

  group('findChildIndexCallback', () {
    // The list never actually calls this (the rows it builds carry no key of
    // their own — see the FINDING in the behaviour suite), so it is exercised
    // here the only way it can be: by calling the callback the widget hands
    // to `SliverAnimatedList`. These pin the mapping it would apply if the
    // rows were ever keyed.

    testWidgets('maps a composite string key to the reversed visual slot', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));
      final find3 = sliverList(tester).findChildIndexCallback!;

      // Reversed: content index 2 (message 3, the newest) is visual slot 0.
      expect(find3(const ValueKey<String>('3-0-0')), 0);
      expect(find3(const ValueKey<String>('2-abc-def')), 1);
      expect(find3(const ValueKey<String>('1-0-0')), 2);
    });

    testWidgets('maps a legacy int key too, and is identity on a normal list', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]), reversed: false);
      final index = sliverList(tester).findChildIndexCallback!;

      expect(index(const ValueKey<int>(1)), 0);
      expect(index(const ValueKey<int>(3)), 2);
    });

    testWidgets('answers null for keys it cannot place', (tester) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]));
      final index = sliverList(tester).findChildIndexCallback!;

      expect(index(const ValueKey<String>('99-0-0')), isNull);
      expect(index(const ValueKey<int>(99)), isNull);
      expect(index(const ValueKey<String>('not-a-number')), isNull);
      expect(index(const ValueKey<double>(1.5)), isNull);
    });

    testWidgets('prefers the host-supplied O(1) lookup over the linear scan', (
      tester,
    ) async {
      final asked = <int>[];
      await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3]),
        findMessageIndex: (id) {
          asked.add(id);
          return id == 2 ? 0 : null;
        },
      );
      final index = sliverList(tester).findChildIndexCallback!;

      // The override claims message 2 lives at content index 0, which is
      // visual slot 2 in a reversed list of three.
      expect(index(const ValueKey<String>('2-0-0')), 2);
      expect(asked, [2]);

      // When the override declines, the widget falls back to its own scan.
      expect(index(const ValueKey<String>('3-0-0')), 0);
      expect(asked, [2, 3]);
    });
  });

  group('the newer-page loading indicator', () {
    testWidgets('a custom loadMoreBuilder renders while newer messages are '
        'loading', (tester) async {
      final gate = Completer<void>();
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        hasMoreNewer: true,
        onLoadNewer: () => gate.future,
        loadMoreBuilder: (_) =>
            const SizedBox(height: 40, child: Text('loading newer')),
      );

      // Leave the newest end, then drag back to it: that is what arms and
      // then fires the newer-page trigger.
      controller.jumpTo(controller.position.maxScrollExtent);
      await _drain(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await _drain(tester);

      expect(find.text('loading newer'), findsOneWidget);

      gate.complete();
      await _drain(tester);
      expect(find.text('loading newer'), findsNothing);
    });
  });

  group('a list shorter than its viewport', () {
    testWidgets('a normal list that does not overflow still ends at the '
        'newest message', (tester) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1]),
        reversed: false,
      );
      expect(controller.position.maxScrollExtent, 0);

      bloc.add(InsertMessage(_msg(2, sender: _me)));
      await _drain(tester);

      expect(_rowTexts(tester), containsAll(<String>['m1', 'm2']));
      // Two 100px rows in a 300px viewport: nothing to scroll, and the list
      // must not have been dragged off the top trying.
      expect(controller.offset, 0);
      expect(controller.position.maxScrollExtent, 0);
    });
  });

  group('the animated diff on a normal list', () {
    testWidgets('an insertion lands at the diffed position, not at the end', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 3]), reversed: false);

      bloc.add(SetMessages(_msgs([1, 2, 3]), animated: true));
      await _drain(tester);

      expect(_rowTexts(tester).toList(), ['m1', 'm2', 'm3']);
    });

    testWidgets('a message edited in place changes nothing about the row '
        'count or the order', (tester) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]), reversed: false);

      // Same ids, but message 2 now carries a newer `updatedAt`: the diff
      // reports it as a CHANGE, which the list deliberately ignores (the row
      // is rebuilt by the message-update notifier instead).
      final edited = <BaseMessage>[
        _msg(1),
        _msg(2)..updatedAt = DateTime(2024, 1, 1, 13),
        _msg(3),
      ];
      bloc.add(SetMessages(edited, animated: true));
      await _drain(tester);

      expect(_rowTexts(tester).toList(), ['m1', 'm2', 'm3']);
    });

    testWidgets('a removal takes the row out at the diffed position', (
      tester,
    ) async {
      await pumpSeeded(tester, seed: _msgs([1, 2, 3]), reversed: false);

      bloc.add(SetMessages(_msgs([1, 3]), animated: true));
      await _drain(tester);

      expect(_rowTexts(tester).toList(), ['m1', 'm3']);
    });
  });

  group('the jump-to-bottom button', () {
    testWidgets('a zero animation duration jumps instead of animating', (
      tester,
    ) async {
      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        scrollToEndAnimationDuration: Duration.zero,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await _drain(tester);
      expect(controller.offset, greaterThan(0));

      await tester.tap(find.byType(ScrollToBottomButton));
      // A single frame is enough because there is no animation to run.
      tester.binding.scheduleFrame();
      await tester.pump();
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(controller.offset, 0);
    });
  });

  group('the keyboard-follow path for normal lists', () {
    testWidgets('FINDING: a normal list never follows the keyboard. Its '
        'spacing sliver is built with includeKeyboardHeight: false, so the '
        'onKeyboardHeightChanged handler it is given can never fire', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding();
      addTearDown(tester.view.reset);

      final controller = await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3, 4, 5, 6]),
        reversed: false,
      );
      controller.jumpTo(100);
      await _drain(tester);

      final spacing = tester.widget<SliverSpacing>(
        find.byType(SliverSpacing, skipOffstage: false),
      );
      expect(spacing.onKeyboardHeightChanged, isNotNull);
      expect(
        spacing.includeKeyboardHeight,
        isFalse,
        reason: 'the handler is wired to a sliver that never calls it',
      );

      // Raising the keyboard therefore moves neither the padding nor the
      // scroll offset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await _drain(tester);

      expect(controller.offset, 100);
      expect(
        tester
            .widget<SliverPadding>(
              find.descendant(
                of: find.byType(SliverSpacing, skipOffstage: false),
                matching: find.byType(SliverPadding, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .padding
            .resolve(TextDirection.ltr)
            .bottom,
        0,
      );
    });

    testWidgets('the composer notifier still moves the bottom spacing', (
      tester,
    ) async {
      final notifier = ComposerHeightNotifier();
      addTearDown(notifier.dispose);

      await pumpSeeded(
        tester,
        seed: _msgs([1, 2, 3]),
        composerHeightNotifier: notifier,
      );

      notifier.setHeight(64);
      await _drain(tester);

      expect(
        tester
            .widget<SliverPadding>(
              find.descendant(
                of: find.byType(SliverSpacing, skipOffstage: false),
                matching: find.byType(SliverPadding, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .padding
            .resolve(TextDirection.ltr)
            .bottom,
        64,
      );
    });
  });
}
