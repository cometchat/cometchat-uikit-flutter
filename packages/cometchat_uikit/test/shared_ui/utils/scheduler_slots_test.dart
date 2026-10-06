/// Behaviour tests for the half of `scheduler_utils.dart` that
/// `scheduler_utils_test.dart` and `test/property/scheduler_utils_property_test.dart`
/// do not reach: the multi-day slot accumulator, the cross-timezone arm of
/// `getAvailableSlots`, the overnight/adjacent cases in `adjustAvailableSlots`,
/// the non-HTTP paths of `fetchICSFile`, and the small action-payload helpers.
///
/// Every date here is a literal — nothing in these functions reads the clock,
/// so a fixed 2026 week keeps the expectations exact on any runner. The one
/// timezone-sensitive group states both zones explicitly.
///
///   flutter test test/shared_ui/utils/scheduler_slots_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The initializer CometChatUIKit.init calls; SchedulerUtils reads this copy
// of the timezone database and nothing else fills it.
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/data/latest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-07 is a Monday, 09-08 a Tuesday.
DateTime _day(int dayOfMonth, [int hour = 0, int minute = 0]) =>
    DateTime(2026, 9, dayOfMonth, hour, minute);

DateTimeRange _range(DateTime start, DateTime end) =>
    DateTimeRange(start: start, end: end);

/// The key `generateCumulativeTimeSlots` builds with DateFormat('yMd').
String _dayKey(DateTime d) => '${d.month}/${d.day}/${d.year}';

Map<String, Map<String, dynamic>> _blocked(
  DateTime day,
  List<DateTimeRange> timings,
) => {
  _dayKey(day): {'timings': timings, 'weekday': 'ignored', 'fullDayOut': false},
};

SchedulerMessage _scheduler({String? title, User? sender, bool? allowSender}) =>
    SchedulerMessage(
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      sender: sender,
      title: title,
      id: 42,
      conversationId: 'c1',
      duration: 30,
      allowSenderInteraction: allowSender,
    );

void main() {
  setUpAll(initializeTimeZones);

  // -------------------------------------------------------------------------
  group('generateCumulativeTimeSlots', () {
    const zone = 'America/New_York';
    final mondayNineToFive = {
      'monday': [TimeRange(from: '0900', to: '1700')],
    };

    List<DateTime> slots({
      required int limit,
      DateTime? from,
      DateTime? to,
      Map<String, List<TimeRange>>? availability,
      Map<String, Map<String, dynamic>> blockedDates = const {},
      int interval = 60,
      Duration buffer = Duration.zero,
    }) => SchedulerUtils.generateCumulativeTimeSlots(
      from ?? _day(7),
      to ?? _day(14),
      limit,
      availability ?? mondayNineToFive,
      blockedDates,
      interval,
      buffer,
      zone,
      zone,
    );

    test('fills up to the limit from the first available day', () {
      final result = slots(limit: 3);
      expect(result, hasLength(3));
      expect(result.map((d) => d.hour), [9, 10, 11]);
      expect(result.every((d) => d.day == 7), isTrue);
    });

    test('a limit of zero produces nothing and never walks the range', () {
      expect(slots(limit: 0), isEmpty);
    });

    test('an already-exhausted range produces nothing', () {
      expect(slots(limit: 5, from: _day(14), to: _day(14)), isEmpty);
      expect(slots(limit: 5, from: _day(14), to: _day(7)), isEmpty);
    });

    test('a range with no matching weekday produces nothing', () {
      // 09-08 to 09-13 is Tuesday through Sunday: no Monday in it.
      expect(slots(limit: 5, from: _day(8), to: _day(13)), isEmpty);
    });

    test('it carries on into later days until the limit is met', () {
      final result = slots(
        limit: 5,
        availability: {
          'monday': [TimeRange(from: '0900', to: '1200')],
          'tuesday': [TimeRange(from: '0900', to: '1200')],
        },
      );
      // Three hour-long slots on Monday, then two of Tuesday's three.
      expect(result, hasLength(5));
      expect(result.where((d) => d.day == 7), hasLength(3));
      expect(result.where((d) => d.day == 8), hasLength(2));
      expect(result.last.hour, 10, reason: 'Tuesday is truncated at the limit');
    });

    test('a day whose slots all fit is taken whole', () {
      final result = slots(
        limit: 10,
        from: _day(7),
        to: _day(9),
        availability: {
          'monday': [TimeRange(from: '0900', to: '1200')],
        },
      );
      expect(result, hasLength(3));
    });

    test('a blocked window removes the slots it covers', () {
      final free = slots(limit: 10, from: _day(7), to: _day(8));
      final withBlock = slots(
        limit: 10,
        from: _day(7),
        to: _day(8),
        blockedDates: _blocked(_day(7), [_range(_day(7, 10), _day(7, 13))]),
      );
      expect(free.map((d) => d.hour), [9, 10, 11, 12, 13, 14, 15, 16]);
      expect(withBlock.map((d) => d.hour), isNot(contains(10)));
      expect(withBlock.map((d) => d.hour), isNot(contains(11)));
      expect(withBlock.map((d) => d.hour), contains(9));
      expect(withBlock.length, lessThan(free.length));
    });

    test('a midnight-crossing slot needs the next day to be open at all', () {
      // A 23:00 meeting of two hours runs into Tuesday, so the generator
      // consults the following day before offering it.
      List<DateTime> withTuesday(Map<String, List<TimeRange>> availability) =>
          slots(
            limit: 10,
            from: _day(7),
            to: _day(8),
            availability: availability,
            interval: 120,
          );

      final open = withTuesday({
        'monday': [TimeRange(from: '2300', to: '2359')],
        'tuesday': [TimeRange(from: '0000', to: '0600')],
      });
      expect(open.map((d) => d.hour), [23]);

      // With Tuesday closed there is nowhere for the meeting to finish, so
      // the slot is withheld.
      final closed = withTuesday({
        'monday': [TimeRange(from: '2300', to: '2359')],
      });
      expect(closed, isEmpty);
    });

    test('a block on the next day does not withdraw a crossing slot', () {
      // FINDING: the next day's blocked list is fetched and passed down, but
      // the guard it feeds asks whether the meeting fits *inside* the next
      // day's remaining availability and offers the slot when it does NOT
      // (scheduler_utils.dart:1112-1121). A meeting starting before midnight
      // can never sit inside a window that starts at midnight, so the guard
      // always passes and a blocked morning does not withdraw the slot.
      // Pinned, not fixed — a lib/ change.
      final availability = {
        'monday': [TimeRange(from: '2300', to: '2359')],
        'tuesday': [TimeRange(from: '0000', to: '0600')],
      };
      final free = slots(
        limit: 10,
        from: _day(7),
        to: _day(8),
        availability: availability,
        interval: 120,
      );
      final blockedTuesday = slots(
        limit: 10,
        from: _day(7),
        to: _day(8),
        availability: availability,
        interval: 120,
        blockedDates: _blocked(_day(8), [_range(_day(8, 0), _day(8, 6))]),
      );
      expect(free.map((d) => d.hour), [23]);
      expect(blockedTuesday.map((d) => d.hour), [
        23,
      ], reason: 'the 23:00 slot survives a wholly blocked Tuesday morning');
    });

    test('a blocked window on an unrelated day changes nothing', () {
      final withBlock = slots(
        limit: 10,
        from: _day(7),
        to: _day(8),
        blockedDates: _blocked(_day(12), [_range(_day(12, 10), _day(12, 13))]),
      );
      expect(withBlock.map((d) => d.hour), [9, 10, 11, 12, 13, 14, 15, 16]);
    });

    test('the meeting interval sets the spacing', () {
      final half = slots(limit: 4, interval: 30);
      expect(half.map((d) => '${d.hour}:${d.minute}'), [
        '9:0',
        '9:30',
        '10:0',
        '10:30',
      ]);
    });

    test('a longer meeting than the window yields nothing that day', () {
      expect(
        slots(
          limit: 5,
          from: _day(7),
          to: _day(8),
          // 09:00-17:00 is eight hours; a nine-hour meeting cannot fit.
          interval: 9 * 60,
        ),
        isEmpty,
      );
    });

    test('null availability yields nothing', () {
      expect(slots(limit: 5, availability: const {}), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('getAvailableSlots — across timezones', () {
    // The cross-zone arm converts the selected day into the sender's zone and
    // back, so the result depends on the offsets involved. Every `selected`
    // below is a UTC instant and both zones are named, which keeps these
    // exact whatever zone the runner is configured for.
    final selected = DateTime.utc(2026, 9, 7); // a Monday
    const local = 'America/New_York';

    Map<String, List<TimeRange>> allDay() => {
      for (final weekday in SchedulerUtils.weekdays)
        weekday: [
          TimeRange(from: '0000', to: '1200'),
          TimeRange(from: '1200', to: '2359'),
        ],
    };

    test('a same-zone and a cross-zone lookup do not agree', () {
      final same = SchedulerUtils.getAvailableSlots(selected, local, local, {
        'monday': [TimeRange(from: '0900', to: '1700')],
      });
      final across = SchedulerUtils.getAvailableSlots(
        selected,
        'Asia/Kolkata',
        local,
        {
          'monday': [TimeRange(from: '0900', to: '1700')],
        },
      );
      expect(same, hasLength(1));
      // Same zone: the availability is read at face value. (Compared as
      // instants — the same-zone arm hands back host-local DateTimes, so the
      // isUtc flag differs even where the moment does not.)
      expect(
        same.single.start.isAtSameMomentAs(
          selected.add(const Duration(hours: 9)),
        ),
        isTrue,
      );
      expect(
        same.single.end.isAtSameMomentAs(
          selected.add(const Duration(hours: 17)),
        ),
        isTrue,
      );
      // Cross zone: 09:00-17:00 in Kolkata is the small hours in New York, so
      // the window that survives on the selected day is a different one.
      expect(across, isNotEmpty);
      expect(across.first.start.isAtSameMomentAs(same.single.start), isFalse);
    });

    test('a cross-zone lookup never returns an inverted range', () {
      for (final weekday in SchedulerUtils.weekdays) {
        final result = SchedulerUtils.getAvailableSlots(
          selected,
          'Asia/Kolkata',
          local,
          {
            weekday: [TimeRange(from: '0000', to: '2359')],
          },
        );
        for (final slot in result) {
          expect(
            slot.end.isAfter(slot.start),
            isTrue,
            reason: '$weekday produced ${slot.start}..${slot.end}',
          );
        }
      }
    });

    test('a cross-zone lookup with no availability yields nothing', () {
      expect(
        SchedulerUtils.getAvailableSlots(selected, 'Asia/Kolkata', local, null),
        isEmpty,
      );
      expect(
        SchedulerUtils.getAvailableSlots(
          selected,
          'Asia/Kolkata',
          local,
          const {},
        ),
        isEmpty,
      );
    });

    test('the day either side of the conversion is considered', () {
      // A day in one zone straddles two days in another, so BOTH of those
      // days' availability entries have to be consulted. These four offsets
      // all roll the day over against New York, each by a different amount.
      const zones = [
        'Asia/Kolkata', // +05:30
        'Asia/Kathmandu', // +05:45
        'Pacific/Chatham', // +12:45
        'UTC',
      ];

      for (final zone in zones) {
        final result = SchedulerUtils.getAvailableSlots(
          selected,
          zone,
          local,
          allDay(),
        );
        expect(
          result,
          isNotEmpty,
          reason: '$zone: an all-day availability must yield something',
        );
        for (final slot in result) {
          expect(
            slot.end.isAfter(slot.start),
            isTrue,
            reason: '$zone produced ${slot.start}..${slot.end}',
          );
          // Every slot has to touch the day that was asked about, and none
          // may reach beyond the day either side of it.
          expect(
            slot.start.toUtc().day == 7 || slot.end.toUtc().day == 7,
            isTrue,
            reason: '$zone returned a slot that never touches the 7th',
          );
          expect(
            slot.start.isBefore(DateTime.utc(2026, 9, 6)),
            isFalse,
            reason: '$zone started before the day before',
          );
          expect(
            slot.end.isAfter(DateTime.utc(2026, 9, 9)),
            isFalse,
            reason: '$zone ended after the day after',
          );
        }
      }
    });

    test('a window spilling past the viewer\'s day is trimmed to its end', () {
      // A round-the-clock availability, read from a zone with a different
      // offset, runs off the end of the selected day. The tail is clamped to
      // the last instant of that day rather than offered into the next one.
      // The two pairs below trim on different sides of the conversion: the
      // sender's own day for the first, the following day for the second.
      const pairs = <List<String>>[
        ['UTC', 'Pacific/Kiritimati'],
        ['Asia/Kolkata', 'America/New_York'],
      ];
      final roundTheClock = {
        for (final weekday in SchedulerUtils.weekdays)
          weekday: [TimeRange(from: '0000', to: '2359')],
      };
      final endOfDay = selected.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );

      for (final pair in pairs) {
        final result = SchedulerUtils.getAvailableSlots(
          selected,
          pair[0],
          pair[1],
          roundTheClock,
        );
        expect(
          result.any((s) => s.end.isAtSameMomentAs(endOfDay)),
          isTrue,
          reason: '${pair[0]} → ${pair[1]}: nothing stopped at end of day',
        );
        for (final slot in result) {
          expect(slot.end.isAfter(endOfDay), isFalse, reason: pair[0]);
        }
      }
    });

    test('the second conversion pass can invert a range and assert', () {
      // FINDING: the first pass over the sender's availability clamps a
      // spilled slot only when the clamp keeps the range ordered
      // (`localStartTime.isBefore(endTime)` / `localEndTime.isAfter(startTime)`,
      // scheduler_utils.dart:1485-1492). The second pass — the one that reads
      // the *following* day's availability — applies the same two clamps with
      // those guards dropped (1540-1544), and then builds a DateTimeRange from
      // the result. For a far-west viewer reading a far-east sender's
      // calendar the clamp pushes `end` before `start` and DateTimeRange's
      // assertion fires, taking slot generation down with it. In release,
      // where the assert is compiled out, the caller gets a backwards range
      // instead. Pinned, not fixed — a lib/ change.
      //
      // Both zones are named and the instant is UTC, so this reproduces
      // identically on any runner.
      expect(
        () => SchedulerUtils.getAvailableSlots(
          selected,
          'Asia/Kolkata',
          'Pacific/Midway',
          allDay(),
        ),
        throwsA(isA<AssertionError>()),
      );
      // The mirror case is fine, which is what makes it a one-sided defect.
      expect(
        () => SchedulerUtils.getAvailableSlots(
          selected,
          'Pacific/Midway',
          'Asia/Kolkata',
          allDay(),
        ),
        returnsNormally,
      );
    });

    test('a malformed cross-zone time degrades instead of throwing', () {
      expect(
        () =>
            SchedulerUtils.getAvailableSlots(selected, 'Asia/Kolkata', local, {
              for (final weekday in SchedulerUtils.weekdays)
                weekday: [TimeRange(from: 'nonsense', to: 'also nonsense')],
            }),
        returnsNormally,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('adjustAvailableSlots — edge overlaps', () {
    test('a block that starts before the slot trims the front', () {
      // available 12-17, blocked 09-13 → only 13-17 survives.
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [_range(_day(8, 12), _day(8, 17))],
        [_range(_day(8, 9), _day(8, 13))],
        Duration.zero,
        _day(8),
      );
      expect(adjusted, hasLength(1));
      expect(adjusted.single.start, _day(8, 13));
      expect(adjusted.single.end, _day(8, 17));
    });

    test('the buffer pushes the trimmed front further out', () {
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [_range(_day(8, 12), _day(8, 17))],
        [_range(_day(8, 9), _day(8, 13))],
        const Duration(minutes: 30),
        _day(8),
      );
      expect(adjusted.single.start, _day(8, 13, 30));
    });

    test('a block that swallows the slot leaves nothing', () {
      // blockedEnd is not before availableEnd, so there is no tail to keep.
      expect(
        SchedulerUtils.adjustAvailableSlots(
          [_range(_day(8, 12), _day(8, 17))],
          [_range(_day(8, 9), _day(8, 18))],
          Duration.zero,
          _day(8),
        ),
        isEmpty,
      );
    });

    test('a block ending exactly where the slot starts still defers it', () {
      // The ranges do not overlap, but a back-to-back block still owes the
      // buffer before the next meeting may start.
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [_range(_day(8, 13), _day(8, 17))],
        [_range(_day(8, 9), _day(8, 13))],
        const Duration(minutes: 15),
        _day(8),
      );
      expect(adjusted, hasLength(1));
      expect(adjusted.single.start, _day(8, 13, 15));
      expect(adjusted.single.end, _day(8, 17));
    });

    test('a block wholly before the slot leaves it untouched', () {
      final slot = _range(_day(8, 14), _day(8, 17));
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [slot],
        [_range(_day(8, 9), _day(8, 12))],
        Duration.zero,
        _day(8),
      );
      expect(adjusted, [slot]);
    });

    test('a block running past midnight leaves the evening untrimmed', () {
      // FINDING: a block that ends on the following day is clamped to
      // 23:59:59 of the selected day (so it cannot be "before" the slot's
      // end), which sends the function down the arm that re-adds the
      // available slot whole — including the blocked evening. An evening
      // meeting is therefore still offered against a block that covers it.
      // Pinned, not fixed — a lib/ change.
      final slot = _range(_day(8, 20), _day(8, 22, 30));
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [slot],
        [_range(_day(8, 21), _day(9, 2))],
        Duration.zero,
        _day(8),
      );
      expect(adjusted, [slot]);
    });

    test('an overnight block is clamped to midnight of the selected day', () {
      // Blocked 09-08 22:00 → 09-09 02:00, and the slot runs 09-08 23:00 →
      // 09-09 17:00. Clamping the block's start to midnight on the 9th means
      // the evening of the 8th is offered as its own range; without the clamp
      // that evening would be swallowed.
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        [_range(_day(8, 23), _day(9, 17))],
        [_range(_day(8, 22), _day(9, 2))],
        Duration.zero,
        _day(9),
      );
      expect(adjusted, hasLength(2));
      expect(adjusted.first.start, _day(8, 23));
      expect(adjusted.first.end, _day(9), reason: 'trimmed at midnight');
      expect(adjusted.last.start, _day(9, 2));
      expect(adjusted.last.end, _day(9, 17));
    });
  });

  // -------------------------------------------------------------------------
  group('checkTimeIsOverlapping — with blocked slots', () {
    final available = [_range(_day(8, 9), _day(8, 17))];

    test('a meeting inside a blocked window does not overlap availability', () {
      // Blocked slots are subtracted from availability first, so a meeting
      // sitting inside the block no longer finds a slot to overlap.
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_day(8, 12), _day(8, 13)),
          available,
          [_range(_day(8, 11), _day(8, 14))],
          Duration.zero,
          _day(8),
        ),
        isFalse,
      );
    });

    test('a meeting clear of the block still overlaps availability', () {
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_day(8, 15), _day(8, 16)),
          available,
          [_range(_day(8, 11), _day(8, 14))],
          Duration.zero,
          _day(8),
        ),
        isTrue,
      );
    });

    test('the buffer pushes a meeting out of the surviving slot', () {
      // 14:00-15:00 is free of the block itself, but a one-hour buffer after
      // it means the next meeting cannot start before 15:00.
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_day(8, 14), _day(8, 14, 30)),
          available,
          [_range(_day(8, 11), _day(8, 14))],
          const Duration(hours: 1),
          _day(8),
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('parseICS — timezone and multi-day events', () {
    String ics(String start, String end) =>
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\n$start\n$end\nEND:VEVENT\nEND:VCALENDAR';

    test('an event with no TZID is read as a local time', () {
      final blocked = SchedulerUtils.parseICS(
        ics('DTSTART:20260908T100000', 'DTEND:20260908T110000'),
        'America/New_York',
      );
      expect(blocked, hasLength(1));
      final timings = blocked.values.single['timings'] as List<dynamic>;
      final only = timings.single as DateTimeRange;
      expect(only.start, DateTime(2026, 9, 8, 10));
      expect(only.end, DateTime(2026, 9, 8, 11));
    });

    test('a TZID is only a relabelling — the wall clock is read as local', () {
      // FINDING: the DTSTART/DTEND wire stamps carry no offset, so
      // DateTime.parse reads them in the HOST's zone. The TZID branch then
      // calls getConvertedTime, which is TZDateTime.from — instant-preserving.
      // So a "10:00 America/New_York" event is blocked at whatever instant
      // 10:00 is on the machine doing the parsing, merely displayed in the
      // declared zone. The TZID never reinterprets the wall clock, which is
      // what it is for. Pinned, not fixed — a lib/ change.
      //
      // The assertion is written so it holds on any runner: both readings
      // must be the same instant as the naive local interpretation.
      const start = 'DTSTART;TZID=America/New_York:20260908T100000';
      const end = 'DTEND;TZID=America/New_York:20260908T110000';
      final native = SchedulerUtils.parseICS(
        ics(start, end),
        'America/New_York',
      );
      final foreign = SchedulerUtils.parseICS(ics(start, end), 'Asia/Kolkata');

      final nativeRange =
          (native.values.single['timings'] as List<dynamic>).single
              as DateTimeRange;
      final foreignRange =
          (foreign.values.single['timings'] as List<dynamic>).single
              as DateTimeRange;

      expect(nativeRange.start, DateTime(2026, 9, 8, 10));
      expect(
        foreignRange.start.isAtSameMomentAs(DateTime(2026, 9, 8, 10)),
        isTrue,
        reason: 'the declared zone did not change which instant is blocked',
      );
      // Only the label moved: the foreign reading reports the Kolkata offset.
      expect(
        foreignRange.start.timeZoneOffset,
        const Duration(hours: 5, minutes: 30),
      );
      // Both still describe an hour-long block.
      expect(
        foreignRange.end.difference(foreignRange.start),
        const Duration(hours: 1),
      );
      expect(
        nativeRange.end.difference(nativeRange.start),
        const Duration(hours: 1),
      );
    });

    test('an event spanning two days blocks the tail and the head', () {
      // 25 hours, so the day difference is 1 and the multi-day arm runs.
      final blocked = SchedulerUtils.parseICS(
        ics('DTSTART:20260908T100000', 'DTEND:20260909T110000'),
        'UTC',
      );
      expect(blocked.keys, containsAll(['9/8/2026', '9/9/2026']));
      final first =
          (blocked['9/8/2026']!['timings'] as List<dynamic>).single
              as DateTimeRange;
      expect(first.start, DateTime(2026, 9, 8, 10));
      expect(
        first.end,
        DateTime(2026, 9, 8, 23, 59, 59),
        reason: 'the first day is blocked to end of day',
      );
      final second =
          (blocked['9/9/2026']!['timings'] as List<dynamic>).single
              as DateTimeRange;
      expect(second.start, DateTime(2026, 9, 9));
      expect(second.end, DateTime(2026, 9, 9, 11));
      expect(blocked['9/9/2026']!['fullDayOut'], isFalse);
    });

    test('an event spanning three days marks the middle day full-day-out', () {
      // 49 hours: one whole day sits inside the event.
      final blocked = SchedulerUtils.parseICS(
        ics('DTSTART:20260908T100000', 'DTEND:20260910T110000'),
        'UTC',
      );
      expect(blocked.keys, containsAll(['9/8/2026', '9/9/2026', '9/10/2026']));
      expect(
        blocked['9/9/2026']!['fullDayOut'],
        isTrue,
        reason: 'a day wholly inside the event is out entirely',
      );
      final middle =
          (blocked['9/9/2026']!['timings'] as List<dynamic>).single
              as DateTimeRange;
      expect(middle.start, DateTime(2026, 9, 9));
      expect(middle.end, DateTime(2026, 9, 9, 23, 59, 59));
      // The closing day carries only the head of the event.
      final last =
          (blocked['9/10/2026']!['timings'] as List<dynamic>).single
              as DateTimeRange;
      expect(last.start, DateTime(2026, 9, 10));
      expect(last.end, DateTime(2026, 9, 10, 11));
    });

    test('a line with no colon-separated pair is ignored', () {
      final blocked = SchedulerUtils.parseICS(
        'BEGIN:VCALENDAR\n'
            'BEGIN:VEVENT\n'
            'SUMMARY:a:b:c\n'
            'DTSTART:20260908T100000\n'
            'DTEND:20260908T110000\n'
            'END:VEVENT\n'
            'END:VCALENDAR',
        'UTC',
      );
      expect(blocked, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('fetchICSFile — the paths that need no network', () {
    test('a null url reports an invalid endpoint and blocks nothing', () async {
      final errors = <CometChatException>[];
      final blocked = await SchedulerUtils.fetchICSFile(
        null,
        'UTC',
        errors.add,
      );
      expect(blocked, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single.code, 'ERR');
      expect(errors.single.details, 'INVALID_API_ENDPOINT');
    });

    test('an empty url reports the same', () async {
      final errors = <CometChatException>[];
      final blocked = await SchedulerUtils.fetchICSFile('', 'UTC', errors.add);
      expect(blocked, isEmpty);
      expect(errors.single.details, 'INVALID_API_ENDPOINT');
    });

    test('an unparseable url is reported, not thrown', () async {
      // `[notanipv6]` makes Uri.parse throw inside the try, which is the one
      // way into the failure arm without reaching the network. The caller
      // gets an error object and an empty map, never an exception.
      final errors = <CometChatException>[];
      final blocked = await SchedulerUtils.fetchICSFile(
        'https://[notanipv6]/calendar.ics',
        'UTC',
        errors.add,
      );
      expect(blocked, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single.details, 'UNABLE_TO_PARSE_ICS_FILE');
      expect(errors.single.message, contains('Unable to parse ICS file'));
    });
  });

  // -------------------------------------------------------------------------
  group('action payload helpers', () {
    final alice = User(uid: 'u1', name: 'Alice');

    test('getActionRequestData names the message and the chosen slot', () {
      final data = SchedulerUtils.getActionRequestData(
        _scheduler(title: 'Design review', sender: alice),
        DateTime(2026, 9, 8, 10),
        const Duration(minutes: 45),
        'America/New_York',
      );
      expect(data['conversationId'], 'c1');
      expect(data['senderId'], 'u1');
      expect(data['receiver'], 'u2');
      expect(data['receiverType'], CometChatReceiverType.user);
      expect(data['messageCategory'], MessageCategoryConstants.interactive);
      expect(data['messageType'], MessageTypeConstants.scheduler);
      expect(data['messageId'], 42);
      expect(data['meetStartAt'], DateTime(2026, 9, 8, 10).toString());
      expect(data['duration'], 45, reason: 'the wire carries minutes');
      expect(data['timezoneCode'], 'America/New_York');
    });

    test('getActionRequestData tolerates a message with no sender', () {
      final data = SchedulerUtils.getActionRequestData(
        _scheduler(),
        DateTime(2026, 9, 8, 10),
        const Duration(hours: 1),
        'UTC',
      );
      expect(data['senderId'], isNull);
      expect(data['duration'], 60);
    });

    test('getActionRequestBody wraps the data beside the payload', () {
      final message = _scheduler(title: 'Design review', sender: alice);
      final body = SchedulerUtils.getActionRequestBody(
        message,
        DateTime(2026, 9, 8, 10),
        const Duration(minutes: 30),
        'UTC',
      );
      expect(body.keys, containsAll(['payload', 'data']));
      expect(body['payload'], same(message.interactiveData));
      expect(
        body['data'],
        SchedulerUtils.getActionRequestData(
          message,
          DateTime(2026, 9, 8, 10),
          const Duration(minutes: 30),
          'UTC',
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('getSchedulerTitle', () {
    testWidgets('the message title wins when it has one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              expect(
                SchedulerUtils.getSchedulerTitle(
                  _scheduler(title: 'Design review'),
                  context,
                ),
                'Design review',
              );
              // With no title it falls back to naming the sender.
              expect(
                SchedulerUtils.getSchedulerTitle(
                  _scheduler(
                    sender: User(uid: 'u1', name: 'Alice'),
                  ),
                  context,
                ),
                '${Translations.of(context).meetingWith} Alice',
              );
              // ...and with neither, it still produces the lead-in alone.
              expect(
                SchedulerUtils.getSchedulerTitle(_scheduler(), context),
                '${Translations.of(context).meetingWith} ',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });
  });

  // -------------------------------------------------------------------------
  group('isScheduleButtonDisabled', () {
    final alice = User(uid: 'u1', name: 'Alice');
    final bob = User(uid: 'u2', name: 'Bob');

    tearDown(() => CometChatUIKit.loggedInUser = null);

    test('the sender cannot book their own slot by default', () {
      CometChatUIKit.loggedInUser = alice;
      expect(
        SchedulerUtils.isScheduleButtonDisabled(_scheduler(sender: alice)),
        isTrue,
      );
    });

    test('the sender can book it when sender interaction is allowed', () {
      CometChatUIKit.loggedInUser = alice;
      expect(
        SchedulerUtils.isScheduleButtonDisabled(
          _scheduler(sender: alice, allowSender: true),
        ),
        isFalse,
      );
    });

    test('the recipient can always book it', () {
      CometChatUIKit.loggedInUser = bob;
      expect(
        SchedulerUtils.isScheduleButtonDisabled(_scheduler(sender: alice)),
        isFalse,
      );
    });

    test('with nobody logged in a senderless message is treated as mine', () {
      // Both sides are null, so they compare equal — pinned because it is a
      // surprising consequence of the uid comparison.
      CometChatUIKit.loggedInUser = null;
      expect(SchedulerUtils.isScheduleButtonDisabled(_scheduler()), isTrue);
    });
  });
}
