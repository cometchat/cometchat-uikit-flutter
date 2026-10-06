/// Properties of the pure parts of `SchedulerUtils`: availability-time
/// parsing, slot generation, blocked-slot checks and the selectable-date walk.
///
///   flutter test test/property/scheduler_utils_property_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/generators.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Slot starts for [day] as offsets from its midnight, so that two different
/// days can be compared.
List<Duration> _slotOffsets(
  DateTime day, {
  required int startHour,
  required int startMinute,
  required int lengthMinutes,
  required int meeting,
}) {
  final start = DateTime(day.year, day.month, day.day, startHour, startMinute);
  final end = start.add(Duration(minutes: lengthMinutes));
  final nextDay = DateTime(day.year, day.month, day.day + 1);
  final stamps = SchedulerUtils.generateTimeStamps(
    day,
    [DateTimeRange(start: start, end: end)],
    const [],
    meeting,
    Duration.zero,
    TimeFormat.twelveHour,
    // The whole of the next day is available, so a meeting may run past
    // midnight.
    [DateTimeRange(start: nextDay, end: nextDay.add(const Duration(days: 1)))],
    const [],
  );
  return [
    for (final s in stamps)
      s.difference(DateTime(day.year, day.month, day.day)),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('an availability time parses to the same duration with or without a '
      'separator, for every hour and minute', () {
    forAll(
      (r) => (r.nextInt(24), r.nextInt(60), r.pick([':', '.', ' ', '-', 'h'])),
      (input) {
        final (h, m, sep) = input;
        final expected = Duration(hours: h, minutes: m);
        expect(
          SchedulerUtils.parseAvailabilityTime('${_two(h)}${_two(m)}'),
          expected,
        );
        expect(
          SchedulerUtils.parseAvailabilityTime('${_two(h)}$sep${_two(m)}'),
          expected,
        );
      },
      cases: 300,
    );
  });

  test('parsing any string as an availability time never throws and never '
      'goes negative', () {
    forAll(
      (r) => r.nextBool()
          ? genUnicode(r)
          : genAlnum(r, alphabet: '0123456789:', max: 10),
      (raw) {
        expect(
          SchedulerUtils.parseAvailabilityTime(raw),
          greaterThanOrEqualTo(Duration.zero),
        );
      },
      cases: 300,
    );
  });

  test('an availability time with a very long digit run parses to a '
      'NEGATIVE duration', () {
    // FINDING: `parseAvailabilityTime` takes everything after the first two
    // digits as the minutes, unbounded. A 16–19 digit run still fits an int,
    // but `Duration(minutes: …)` multiplies it by 60,000,000 and wraps, so a
    // malformed payload yields a negative (or otherwise absurd) availability
    // bound instead of `Duration.zero`, the function's documented fallback
    // for input it cannot read. Expected: reject anything but 3–4 digits.
    forAll((r) => '09${genAlnum(r, alphabet: '123456789', min: 17, max: 17)}', (
      raw,
    ) {
      final parsed = SchedulerUtils.parseAvailabilityTime(raw);
      expect(parsed, isNot(Duration.zero));
      expect(parsed.inMinutes.abs(), lessThan(int.parse(raw.substring(2))));
    }, cases: 50);
  });

  test('generated slots are strictly ascending, one meeting apart at least, '
      'start inside the available window and fit before it closes', () {
    forAll(
      (r) => (
        r.between(0, 20),
        r.nextInt(60),
        r.between(10, 180),
        r.pick([15, 20, 30, 45, 60, 90]),
      ),
      (input) {
        final (hour, minute, length, meeting) = input;
        final day = DateTime(2031, 5, 14);
        final offsets = _slotOffsets(
          day,
          startHour: hour,
          startMinute: minute,
          lengthMinutes: length,
          meeting: meeting,
        );
        final open = Duration(hours: hour, minutes: minute);
        final close = open + Duration(minutes: length);

        expect(offsets, hasLength(length ~/ meeting));
        for (var i = 0; i < offsets.length; i++) {
          expect(offsets[i], open + Duration(minutes: meeting * i));
          expect(
            offsets[i] + Duration(minutes: meeting),
            lessThanOrEqualTo(close),
          );
        }
      },
      cases: 300,
    );
  });

  test('a meeting that runs past midnight is offered mid-month but not on the '
      'last day of a month', () {
    // FINDING: `generateTimeStamps` decides "has this slot crossed into the
    // next day" by comparing DAY-OF-MONTH numbers
    // (`from.day > selectedDate.day`, `proposedTime.day > selectedDate.day`).
    // On the last day of a month the next day is the 1st, so `1 > 31` is
    // false: the late-evening slot whose meeting would end after midnight is
    // silently dropped, even though the next day is fully available — and the
    // loop keeps walking into the next day instead of breaking. The same
    // availability therefore offers different slots on the 14th and the 31st.
    // Expected: compare calendar dates, not day numbers.
    forAll((r) => (r.pick([30, 60, 90]), r.between(1, 12)), (input) {
      final (meeting, month) = input;
      final lastDay = DateTime(2031, month + 1, 0);
      final midMonth = DateTime(2031, month, 14);
      // A window that closes ten minutes before midnight: its first slot
      // fits, its second would end after midnight.
      final startMinutes = 24 * 60 - 20 - meeting;
      List<Duration> slots(DateTime day) => _slotOffsets(
        day,
        startHour: startMinutes ~/ 60,
        startMinute: startMinutes % 60,
        lengthMinutes: meeting + 10,
        meeting: meeting,
      );

      final lateSlot = Duration(minutes: startMinutes + meeting);
      expect(slots(midMonth), contains(lateSlot));
      expect(slots(lastDay), isNot(contains(lateSlot)));
    }, cases: 40);
  });

  test('a time is blocked exactly when it lies strictly after a blocked '
      'start and before that block\'s buffered end', () {
    forAll(
      (r) {
        final base = DateTime(2031, 3, 10, 9);
        final blocks = List.generate(r.nextInt(4), (_) {
          final start = base.add(Duration(minutes: r.nextInt(600)));
          return DateTimeRange(
            start: start,
            end: start.add(Duration(minutes: r.between(1, 120))),
          );
        });
        return (
          blocks,
          r.nextInt(60),
          base.add(Duration(minutes: r.nextInt(800))),
        );
      },
      (input) {
        final (blocks, buffer, proposed) = input;
        final expected = blocks.any(
          (b) =>
              proposed.isAfter(b.start) &&
              proposed.isBefore(b.end.add(Duration(minutes: buffer))),
        );
        expect(
          SchedulerUtils.checkBlockedSlotStatus(blocks, buffer, proposed),
          expected,
        );
        // More buffer can only block more.
        if (expected) {
          expect(
            SchedulerUtils.checkBlockedSlotStatus(
              blocks,
              buffer + 30,
              proposed,
            ),
            isTrue,
          );
        }
      },
      cases: 300,
    );
  });

  test('the nearest selectable date always terminates, never moves '
      'backwards, and is either selectable or the date that was asked for', () {
    forAll(
      (r) {
        final from = DateTime(2031, r.between(1, 12), r.between(1, 28));
        final to = r.nextBool()
            ? from.add(Duration(days: r.nextInt(60)))
            : null;
        final selected = from.add(Duration(days: r.nextInt(40) - 5));
        final days = [...SchedulerUtils.weekdays]..shuffle(r);
        final availability = switch (r.nextInt(4)) {
          0 => null,
          1 => <String, List<TimeRange>>{}, // nothing is ever available
          2 => {
            'notAWeekday': [TimeRange(from: '0900', to: '1700')],
          },
          _ => {
            for (final d in days.take(r.between(1, 7)))
              d: r.chance(0.8)
                  ? [TimeRange(from: '0900', to: '1700')]
                  : <TimeRange>[],
          },
        };
        return (selected, from, to, availability);
      },
      (input) {
        final (selected, from, to, availability) = input;
        final result = SchedulerUtils.nearestSelectableDate(
          selected,
          from,
          to,
          const {},
          availability,
        );

        expect(result.isBefore(selected), isFalse);
        final selectable = SchedulerUtils.isDateSelectable(
          result,
          from,
          to,
          const {},
          availability,
        );
        expect(selectable || result == selected, isTrue);
        if (selectable) {
          expect(result.isBefore(from), isFalse);
          if (to != null) expect(result.isAfter(to), isFalse);
        }
      },
      cases: 300,
    );
  });
}
