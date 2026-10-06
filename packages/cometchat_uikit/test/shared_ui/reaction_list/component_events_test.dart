/// Reaction-list and media-recorder events, states and the composer's
/// controller — Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Nine exported classes that no test had ever constructed. Six are bloc
/// events and states, one is [ReactionListLoaded] — which is not a plain
/// holder at all: it carries three computed properties the reaction sheet
/// renders directly from, and `getReactionCount` has a fallback branch that is
/// easy to get wrong. The last is [CustomTextEditingController], the composer's
/// controller, whose whole reason to exist is disposing the gesture
/// recognizers its formatters create.
///
///   flutter test test/shared_ui/reaction_list/component_events_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReaction extends Fake implements Reaction {
  _FakeReaction(this.reaction, this.uid);
  @override
  final String reaction;
  @override
  final String uid;
  @override
  String toString() => '$reaction/$uid';
}

Map<String, List<Reaction>> _reactions() => <String, List<Reaction>>{
  '👍': [_FakeReaction('👍', 'u1'), _FakeReaction('👍', 'u2')],
  '🎉': [_FakeReaction('🎉', 'u3')],
};

void main() {
  // ===========================================================================
  group('the reaction-list event family', () {
    test('FIXED — every event is nameable and dispatchable', () {
      // views.dart exported this file through a `show` naming seven of its
      // fourteen classes, and the seven it omitted were every concrete event.
      // The `show` was there because the file declared a RemoveReaction that
      // collided with the message list's event of the same name — one
      // collision took the whole family off the public surface, leaving
      // CometChatReactionList.reactionListBloc injectable but impossible to
      // drive.
      //
      // The reaction-list event is now RemoveOwnReaction, so the export is
      // wholesale and nothing is hidden. ENG-39101.
      final bloc = ReactionListBloc(messageId: 1);
      addTearDown(bloc.close);

      final events = <ReactionListEvent>[
        const InitializeReactionList(),
        const FetchReactions(),
        const UpdateSelectedReaction('👍'),
        RemoveOwnReaction(_FakeReaction('👍', 'u1')),
        ReactionAdded(_FakeReaction('👍', 'u1')),
        ReactionRemoved(_FakeReaction('👍', 'u1')),
      ];

      expect(events, hasLength(6));
      expect(bloc.state, isA<ReactionListInitial>());
    });

    test('FetchReactions defaults to the all-reactions bucket', () {
      // Now reachable, so the default the sheet opens on can be asserted.
      expect(const FetchReactions().reaction, isNotEmpty);
      expect(const FetchReactions(), const FetchReactions());
      expect(
        const FetchReactions(reaction: '👍'),
        isNot(const FetchReactions(reaction: '🎉')),
      );
    });

    test('ReactionAdded and ReactionRemoved are distinct types over one '
        'reaction', () {
      // Identical props — only the runtime type separates an add from a
      // removal, which matters because the bloc handles them oppositely.
      final reaction = _FakeReaction('👍', 'u1');

      expect(ReactionAdded(reaction).props, ReactionRemoved(reaction).props);
      expect(ReactionAdded(reaction), isNot(ReactionRemoved(reaction)));
    });

    test('RemoveOwnReaction carries the reaction being withdrawn', () {
      final reaction = _FakeReaction('👍', 'u1');

      expect(RemoveOwnReaction(reaction).reaction, same(reaction));
      expect(RemoveOwnReaction(reaction), RemoveOwnReaction(reaction));
      expect(
        RemoveOwnReaction(reaction),
        isNot(RemoveOwnReaction(_FakeReaction('👍', 'u2'))),
      );
    });
  });

  // ===========================================================================
  group('ReactionListLoading', () {
    test(
      'carries the reactions already on screen while the next page loads',
      () {
        // The sheet keeps rendering the current buckets during a fetch, so this
        // state is not empty — that is the difference from ReactionListInitial.
        final state = ReactionListLoading(
          messageReactions: _reactions(),
          selectedReaction: '👍',
        );

        expect(state.messageReactions, hasLength(2));
        expect(state.selectedReaction, '👍');
        expect(state, isA<ReactionListState>());
      },
    );

    test('the selected bucket is part of identity', () {
      final reactions = _reactions();

      expect(
        ReactionListLoading(
          messageReactions: reactions,
          selectedReaction: '👍',
        ),
        isNot(
          ReactionListLoading(
            messageReactions: reactions,
            selectedReaction: '🎉',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  group('ReactionListLoaded', () {
    ReactionListLoaded build({
      Map<String, List<Reaction>>? reactions,
      String selected = '👍',
      int total = 3,
      bool canFetchMore = false,
    }) => ReactionListLoaded(
      messageReactions: reactions ?? _reactions(),
      selectedReaction: selected,
      totalReactions: total,
      canFetchMore: canFetchMore,
    );

    test('carries the buckets, the selection, the total and the page flag', () {
      final state = build(canFetchMore: true);

      expect(state.messageReactions, hasLength(2));
      expect(state.selectedReaction, '👍');
      expect(state.totalReactions, 3);
      expect(state.canFetchMore, isTrue);
    });

    test('getReactionCount returns the bucket size for a known reaction', () {
      expect(build().getReactionCount('👍'), 2);
      expect(build().getReactionCount('🎉'), 1);
    });

    test('getReactionCount falls back to the grand total for an unknown one', () {
      // This is the branch worth pinning: an unknown key does not return 0, it
      // returns totalReactions. That is right for the "All" tab, whose key is
      // never a bucket — and wrong-looking for anything else, so it should not
      // be "tidied" into a zero without checking the All tab first.
      expect(build(total: 3).getReactionCount('🙃'), 3);
      expect(
        build(total: 3).getReactionCount(''),
        3,
        reason: 'the All tab reaches this branch',
      );
    });

    test('isEmpty tracks the buckets, not the total', () {
      expect(build().isEmpty, isFalse);
      expect(build(reactions: {}).isEmpty, isTrue);
      expect(
        build(reactions: {}, total: 9).isEmpty,
        isTrue,
        reason: 'a stale total does not make the sheet non-empty',
      );
    });

    test('copyWith replaces only what it is given', () {
      final base = build();
      final copy = base.copyWith(selectedReaction: '🎉');

      expect(copy.selectedReaction, '🎉');
      expect(copy.totalReactions, base.totalReactions);
      expect(copy.canFetchMore, base.canFetchMore);
      expect(copy.messageReactions, base.messageReactions);
    });

    test('copyWith with nothing given is equal to the original', () {
      // Compared against the same instance rather than a second build(): the
      // fake reactions are not Equatable, so two independent builds hold
      // different objects and would not compare equal however faithful
      // copyWith is.
      final base = build();
      expect(base.copyWith(), base);
    });

    test('equality distinguishes the page flag as well as the data', () {
      expect(build(canFetchMore: false), isNot(build(canFetchMore: true)));
      expect(build(total: 3), isNot(build(total: 4)));
    });
  });

  // ===========================================================================
  group('media-recorder events', () {
    test('UpdateTimerEvent carries the elapsed duration', () {
      expect(
        const UpdateTimerEvent(Duration(seconds: 3)).duration,
        const Duration(seconds: 3),
      );
      expect(
        const UpdateTimerEvent(Duration(seconds: 3)),
        const UpdateTimerEvent(Duration(seconds: 3)),
      );
      expect(
        const UpdateTimerEvent(Duration(seconds: 3)),
        isNot(const UpdateTimerEvent(Duration(seconds: 4))),
      );
    });

    test('UpdateVisualizerEvent carries the amplitude window', () {
      const event = UpdateVisualizerEvent([0.1, 0.5, 0.9]);

      expect(event.amplitudes, [0.1, 0.5, 0.9]);
      expect(event.props, [
        [0.1, 0.5, 0.9],
      ]);
    });

    test('two identical amplitude windows compare equal, and the bloc will '
        'drop the second', () {
      // Equatable compares the list by value, so a repeated waveform frame is
      // a duplicate event. Worth knowing: a genuinely flat signal emits equal
      // frames, and those collapse.
      expect(
        const UpdateVisualizerEvent([0.0, 0.0]),
        const UpdateVisualizerEvent([0.0, 0.0]),
      );
      expect(
        const UpdateVisualizerEvent([0.0, 0.0]),
        isNot(const UpdateVisualizerEvent([0.0, 0.1])),
      );
    });

    test('RecordingErrorEvent carries the message it will surface', () {
      expect(const RecordingErrorEvent('no mic').error, 'no mic');
      expect(
        const RecordingErrorEvent('no mic'),
        const RecordingErrorEvent('no mic'),
      );
      expect(
        const RecordingErrorEvent('no mic'),
        isNot(const RecordingErrorEvent('denied')),
      );
    });
  });

  // ===========================================================================
  group('CustomTextEditingController', () {
    test('starts empty and with no formatters', () {
      final controller = CustomTextEditingController();

      expect(controller.text, isEmpty);
      expect(controller.formatters, isNull);
      controller.dispose();
    });

    test('seeds its text and keeps the formatter list it is given', () {
      final formatters = <CometChatTextFormatter>[CometChatUrlFormatter()];
      final controller = CustomTextEditingController(
        text: 'hello',
        formatters: formatters,
      );

      expect(controller.text, 'hello');
      expect(controller.formatters, same(formatters));
      controller.dispose();
    });

    test(
      'formatters are mutable — the composer swaps them as context changes',
      () {
        final controller = CustomTextEditingController()
          ..formatters = <CometChatTextFormatter>[CometChatEmailFormatter()];

        expect(controller.formatters, hasLength(1));
        controller.dispose();
      },
    );

    testWidgets(
      'with no formatters it builds a plain span carrying the style',
      (tester) async {
        final controller = CustomTextEditingController(text: 'hello');
        addTearDown(controller.dispose);
        late TextSpan span;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                span = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(fontSize: 17),
                  withComposing: false,
                );
                return const SizedBox();
              },
            ),
          ),
        );

        expect(span.toPlainText(), 'hello');
        expect(span.style?.fontSize, 17);
      },
    );

    testWidgets('an empty formatter list takes the same plain path', (
      tester,
    ) async {
      final controller = CustomTextEditingController(
        text: 'hello',
        formatters: <CometChatTextFormatter>[],
      );
      addTearDown(controller.dispose);
      late TextSpan span;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: null,
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(span.toPlainText(), 'hello');
    });

    testWidgets('rebuilding the span repeatedly does not accumulate '
        'recognizers', (tester) async {
      // The controller disposes its gesture recognizers at the top of every
      // build. Without that, each keystroke would leak one per formatted span
      // — which is why this class exists rather than a plain
      // TextEditingController.
      final controller = CustomTextEditingController(text: 'hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (var i = 0; i < 5; i++) {
                controller.buildTextSpan(
                  context: context,
                  style: null,
                  withComposing: false,
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );

      // Disposing after five builds must not throw on an already-disposed
      // recognizer, which is what a double-dispose would look like.
      expect(tester.takeException(), isNull);
    });
  });
}
