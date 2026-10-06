/// Properties of poll parsing: the `@injected.extensions.polls` envelope →
/// `PollOptions` step inside `MessageTemplateUtils.getPollMessageTemplate`,
/// and the vote-share arithmetic of `CometChatPollsBubble`.
///
///   flutter test test/property/poll_parsing_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

class _Option {
  _Option(this.id, this.text, this.voters);
  final String id;
  final String text;
  final List<String> voters;
}

/// [paintable] keeps option text to well-formed UTF-16: Flutter's paragraph
/// builder itself rejects a lone surrogate, which is not the UI Kit's doing.
List<_Option> _genOptions(Random r, {bool paintable = false}) => List.generate(
  r.between(2, 8),
  (i) => _Option(
    '${i + 1}',
    paintable ? genPlainWords(r, maxWords: 3) : genUnicode(r, maxParts: 4),
    List.generate(r.nextInt(6), (v) => 'voter_${i}_$v'),
  ),
);

Map<String, dynamic> _envelope(List<_Option> options) => {
  'id': 'poll-1',
  'results': {
    'total': options.fold<int>(0, (n, o) => n + o.voters.length),
    'options': {
      for (final o in options)
        o.id: {
          'text': o.text,
          'count': o.voters.length,
          'voters': {
            for (final v in o.voters) v: {'name': 'Name $v', 'avatar': null},
          },
        },
    },
  },
};

CustomMessage _pollMessage(Object? pollsExtension) => CustomMessage(
  id: 41,
  type: ExtensionType.extensionPoll,
  category: MessageCategoryConstants.custom,
  receiverUid: 'group-1',
  receiverType: CometChatReceiverType.group,
  customData: const {'question': 'Tabs or spaces?'},
  metadata: {
    '@injected': {
      'extensions': {ExtensionConstants.polls: pollsExtension},
    },
  },
);

/// Runs the real parser: the poll template's content view.
Widget _parse(BuildContext context, CustomMessage message) =>
    MessageTemplateUtils.getPollMessageTemplate().contentView!(
      message,
      context,
      BubbleAlignment.left,
    )!;

String _describe(List<_Option> o) =>
    show([for (final e in o) '${e.id}:${e.voters.length}']);

void main() {
  testWidgets('a well-formed envelope yields one option per entry, in order, '
      'whose count equals its number of voters', (tester) async {
    final context = await pumpContext(tester);

    forAll(_genOptions, (options) {
      final bubble = _parse(context, _pollMessage(_envelope(options)));
      expect(bubble, isA<CometChatPollsBubble>());
      final parsed = (bubble as CometChatPollsBubble).options!;

      expect(parsed.map((p) => p.id), options.map((o) => o.id));
      expect(parsed.map((p) => p.optionText), options.map((o) => o.text));
      for (var i = 0; i < options.length; i++) {
        expect(parsed[i].voteCount, options[i].voters.length);
        expect(parsed[i].voteCount, greaterThanOrEqualTo(0));
        expect(parsed[i].votersUid, options[i].voters);
        expect(parsed[i].voters.map((u) => u.uid), options[i].voters);
      }
      expect(bubble.pollId, 'poll-1');
    }, describe: _describe);
  });

  testWidgets('an envelope that is not a map, or has no results, yields an '
      'empty poll rather than a partial one', (tester) async {
    final context = await pumpContext(tester);

    forAll(
      (r) => r.pick<Object? Function()>([
        () => genJunk(r),
        () => <String, dynamic>{'id': genInt(r)},
        () => <String, dynamic>{'results': genJunk(r)},
        () => <String, dynamic>{
          'results': <String, dynamic>{'total': genInt(r)},
        },
        () => <String, dynamic>{
          'results': <String, dynamic>{
            'options': <String, dynamic>{'1': genInt(r), '2': 'text only'},
          },
        },
      ])(),
      (extension) {
        final bubble = _parse(context, _pollMessage(extension));
        expect(bubble, isA<CometChatPollsBubble>());
        expect((bubble as CometChatPollsBubble).options, isEmpty);
        expect(bubble.pollQuestion, 'Tabs or spaces?');
      },
    );
  });

  testWidgets('an option whose count or voters has the wrong type takes the '
      'whole bubble down with a cast error', (tester) async {
    final context = await pumpContext(tester);

    // FINDING: the envelope walk is defensive down to each option
    // (`is Map` checks at every level), but the two leaf reads are not:
    // `voteCount: opt['count'] ?? 0` is an implicit `dynamic → int` cast and
    // `Map<String, dynamic>.from(opt['voters'] ?? {})` assumes a map. A
    // single option with `"count": "3"` (or `3.0`, which JSON decoders do
    // produce) or `"voters": []` (what PHP-style backends emit for an empty
    // object) throws a TypeError from inside the message list's item builder
    // — the poll is not rendered at all, instead of showing the option with
    // 0 votes. iOS treats a damaged option as 0 votes.
    forAll(
      (r) {
        final options = _genOptions(r);
        final envelope = _envelope(options);
        final results = envelope['results'] as Map<String, dynamic>;
        final byId = results['options'] as Map<String, dynamic>;
        final victim = byId[r.pick(options).id] as Map<String, dynamic>;
        if (r.nextBool()) {
          victim['count'] = r.pick<Object>(['3', 3.0, true, <int>[]]);
        } else {
          victim['voters'] = r.pick<Object>([<String>[], 'nobody', 4]);
        }
        return envelope;
      },
      (envelope) {
        expect(
          () => _parse(context, _pollMessage(envelope)),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });

  testWidgets('the rendered shares are each within 0..1 and add up to 1 '
      'whenever anybody voted', (tester) async {
    final cases = <List<_Option>>[];
    forAll((r) => _genOptions(r, paintable: true), cases.add, cases: 40);

    for (final options in cases) {
      final context = await pumpContext(tester);
      final bubble = _parse(context, _pollMessage(_envelope(options)));
      await pumpInApp(tester, bubble);

      final shares = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value!)
          .toList();
      final total = options.fold<int>(0, (n, o) => n + o.voters.length);

      expect(shares, hasLength(options.length), reason: _describe(options));
      for (var i = 0; i < shares.length; i++) {
        expect(shares[i], inInclusiveRange(0.0, 1.0));
        expect(
          shares[i],
          total == 0 ? 0.0 : closeTo(options[i].voters.length / total, 1e-9),
          reason: _describe(options),
        );
      }
      expect(
        shares.fold<double>(0, (a, b) => a + b),
        closeTo(total == 0 ? 0 : 1, 1e-9),
        reason: _describe(options),
      );
    }
  });

  testWidgets('a count that disagrees with the voters list is believed as is, '
      'so a share can be negative', (tester) async {
    // FINDING: nothing reconciles `count` with `voters`, clamps it at 0, or
    // checks it against the envelope's own `total`. A negative or inflated
    // `count` from the extension flows straight into the share
    // (`count / totalVotes`), where `totalVotes` is the sum of those same
    // counts — so one negative option gives another a share above 100 %.
    // Pinned: the bubble reports exactly count / sum(counts).
    final cases = <List<int>>[];
    forAll(
      (r) => [r.between(-5, -1), r.between(6, 12), 0],
      cases.add,
      cases: 25,
    );

    for (final counts in cases) {
      final options = [
        for (var i = 0; i < counts.length; i++) _Option('${i + 1}', 'o$i', []),
      ];
      final envelope = _envelope(options);
      final results = envelope['results'] as Map<String, dynamic>;
      final byId = results['options'] as Map<String, dynamic>;
      for (var i = 0; i < counts.length; i++) {
        (byId['${i + 1}'] as Map<String, dynamic>)['count'] = counts[i];
      }

      final context = await pumpContext(tester);
      await pumpInApp(tester, _parse(context, _pollMessage(envelope)));
      final shares = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value!)
          .toList();

      final sum = counts.reduce((a, b) => a + b);
      expect(shares[0], closeTo(counts[0] / sum, 1e-9));
      expect(shares[0], lessThan(0), reason: '$counts');
      expect(shares[1], greaterThan(1), reason: '$counts');
    }
  });
}
