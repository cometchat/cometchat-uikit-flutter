/// Properties of every place a timestamp becomes a label: the notification
/// feed's `getRelativeTime` / `groupByTimestamp`, the `CometChatDate` widget
/// used by conversations, messages and search, and the call-log helpers.
///
///   flutter test test/property/date_label_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CallLogsUtils;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/generators.dart';
import 'support/harness.dart';

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// A moment of the current local calendar day.
DateTime _genToday(Random r) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    r.nextInt(24),
    r.nextInt(60),
    r.nextInt(60),
  );
}

final _clock = RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM|am|pm)$');

NotificationFeedItem _item(int index, int sentAt) => NotificationFeedItem(
  id: 'item_$index',
  category: 'updates',
  content: const {'type': 'test'},
  sentAt: sentAt,
  sender: 'server',
  receiver: 'user',
  receiverType: 'user',
);

Future<String> _renderedDate(
  WidgetTester tester,
  DateTime date,
  DateTimePattern pattern,
) async {
  await pumpInApp(tester, CometChatDate(date: date, pattern: pattern));
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('any representable timestamp renders a non-empty, single-line '
      'relative label without throwing', () {
    forAll((r) => genEpochSeconds(r, nowSeconds: _nowSeconds()), (seconds) {
      final label = getRelativeTime(seconds, 'en');
      expect(label.trim(), isNotEmpty);
      expect(label, isNot(contains('\n')));
    }, cases: 300);
  });

  test('every moment of today renders as a clock time, never as a date', () {
    forAll(_genToday, (moment) {
      final label = getRelativeTime(
        moment.millisecondsSinceEpoch ~/ 1000,
        'en',
      );
      expect(_clock.hasMatch(label), isTrue, reason: 'got "$label"');
    });
  });

  test('a timestamp more than a week in the future is labelled with a bare '
      'weekday name', () {
    // FINDING: `getRelativeTime` decides "this week" with
    // `now.difference(sentAt).inDays < 7`. For a FUTURE timestamp the
    // difference is negative, so the test passes for every future moment and
    // a notification stamped next year is labelled just "Monday" — a label
    // that reads as "earlier this week". Expected: a full date (the `else`
    // branch), as for anything else outside the current week.
    final weekday = RegExp(
      r'^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$',
    );
    forAll((r) => _nowSeconds() + 8 * 86400 + r.nextInt(50 * 365 * 86400), (
      seconds,
    ) {
      expect(weekday.hasMatch(getRelativeTime(seconds, 'en')), isTrue);
    });
  });

  test('a timestamp beyond the DateTime range throws instead of rendering', () {
    // FINDING: `getRelativeTime` and `groupByTimestamp` feed
    // `sentAt * 1000` straight into `DateTime.fromMillisecondsSinceEpoch`,
    // which rejects anything past ±8.64e15 ms with an ArgumentError. `sentAt`
    // comes from the server; one bad value (milliseconds sent where seconds
    // are expected, times a thousand again) takes the whole feed build down
    // rather than degrading to a fallback label.
    forAll(
      (r) {
        final magnitude = 8640000000001 + r.nextInt(1 << 31);
        return r.nextBool() ? magnitude : -magnitude;
      },
      (seconds) {
        expect(() => getRelativeTime(seconds, 'en'), throwsArgumentError);
        expect(
          () => groupByTimestamp([_item(0, seconds)], 'en'),
          throwsArgumentError,
        );
      },
      cases: 50,
    );
  });

  test('grouping by day keeps every item exactly once, newest group first '
      'and newest item first inside each group', () {
    forAll(
      (r) => List.generate(
        r.nextInt(25),
        (i) => _item(i, _nowSeconds() - r.nextInt(400 * 86400)),
      ),
      (items) {
        final groups = groupByTimestamp(items, 'en');

        final seen = [for (final g in groups) ...g.items.map((i) => i.id)];
        expect(seen, unorderedEquals(items.map((i) => i.id)));
        expect(groups.map((g) => g.label).toSet(), hasLength(groups.length));

        for (final g in groups) {
          expect(g.items, isNotEmpty);
          expect(g.label.trim(), isNotEmpty);
          for (var i = 1; i < g.items.length; i++) {
            expect(
              g.items[i - 1].sentAt,
              greaterThanOrEqualTo(g.items[i].sentAt),
            );
          }
        }
        for (var i = 1; i < groups.length; i++) {
          expect(
            groups[i - 1].items.first.sentAt,
            greaterThan(groups[i].items.first.sentAt),
            reason: 'group ${groups[i - 1].label} before ${groups[i].label}',
          );
        }
      },
      describe: (items) => '${items.map((i) => i.sentAt).toList()}',
    );
  });

  testWidgets('the date widget renders a non-empty label for any date under '
      'every pattern', (tester) async {
    final cases = <(DateTime, DateTimePattern)>[];
    forAll(
      (r) => (
        DateTime.fromMillisecondsSinceEpoch(
          genEpochSeconds(r, nowSeconds: _nowSeconds()) * 1000,
        ),
        r.pick(DateTimePattern.values),
      ),
      cases.add,
      cases: 60,
    );
    for (final (date, pattern) in cases) {
      final label = await _renderedDate(tester, date, pattern);
      expect(
        label.trim(),
        isNotEmpty,
        reason: 'date: $date, pattern: $pattern',
      );
    }
  });

  testWidgets('the date widget shows a clock time for every moment of today '
      'in the conversation-list pattern, and "Today" in the separator '
      'pattern', (tester) async {
    final moments = <DateTime>[];
    forAll(_genToday, moments.add, cases: 40);
    for (final moment in moments) {
      expect(
        _clock.hasMatch(
          await _renderedDate(
            tester,
            moment,
            DateTimePattern.dayDateTimeFormat,
          ),
        ),
        isTrue,
        reason: 'moment: $moment',
      );
      expect(
        await _renderedDate(tester, moment, DateTimePattern.dayDateFormat),
        'Today',
        reason: 'moment: $moment',
      );
    }
  });

  test('a call duration in minutes is rendered so that it reads back to the '
      'same number of seconds', () {
    forAll((r) => r.nextInt(100 * 3600) / 60.0, (minutes) {
      final label = CallLogsUtils.formatMinutesAndSeconds(minutes);
      final m = RegExp(r'^(?:(\d+)h )?(\d+)m (\d{2})s$').firstMatch(label);
      expect(m, isNotNull, reason: 'got "$label"');
      final h = int.parse(m!.group(1) ?? '0');
      final min = int.parse(m.group(2)!);
      final s = int.parse(m.group(3)!);
      expect(min, lessThan(60));
      expect(s, lessThan(60));
      expect(h * 3600 + min * 60 + s, (minutes * 60).round());
    }, cases: 300);
  });

  test('a call-log day key is "dd MMM yyyy" for any timestamp and empty only '
      'for a missing one', () {
    expect(CallLogsUtils.storeValueInMapTime(null), '');
    forAll((r) => genEpochSeconds(r, nowSeconds: _nowSeconds()), (seconds) {
      expect(
        RegExp(
          r'^\d{2} [A-Z][a-z]{2} -?\d{4,}$',
        ).hasMatch(CallLogsUtils.storeValueInMapTime(seconds)),
        isTrue,
        reason: CallLogsUtils.storeValueInMapTime(seconds),
      );
    });
  });
}
