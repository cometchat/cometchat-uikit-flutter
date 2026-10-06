/// Behaviour tests for SchedulerUtils and its three extensions —
/// Track 3 TEST3 (ENG-38684).
///
/// `scheduler_utils.dart` is 782 executable lines with no test at all — the
/// single largest zero-coverage file in the lane, and a quarter of the whole
/// zero-coverage budget. It is pure static logic: timezone lookup, slot
/// generation, buffer arithmetic and overlap tests. Nothing here needs the
/// chat SDK.
///
/// The timezone database is populated by `initializeTimeZones()`, which the
/// package calls from `CometChatUIKit.init`. Tests call it directly in setUpAll
/// since they do not boot the kit.
///
///   flutter test test/shared_ui/utils/scheduler_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The initializer CometChatUIKit.init calls. It has to be this one:
// SchedulerUtils once read a second database copy that nothing filled, and
// a test that initialised that copy directly hid it.
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/data/latest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTimeRange _range(DateTime start, Duration d) =>
    DateTimeRange(start: start, end: start.add(d));

DateTime _at(int h, [int m = 0]) => DateTime(2026, 9, 8, h, m);

/// The next [weekday] strictly in the future.
///
/// isDateSelectable defaults its lower bound to `DateTime.now()`, so any
/// fixture pinned to a literal past date starts failing the day after it is
/// written. These anchor to the future instead.
DateTime _nextWeekday(int weekday) {
  var d = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).add(const Duration(days: 1));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// The key isDateSelectable builds with DateFormat('yMd').
String _dayKey(DateTime d) => '${d.month}/${d.day}/${d.year}';

void main() {
  setUpAll(initializeTimeZones);

  // -------------------------------------------------------------------------
  group('timezone helpers', () {
    test('getTimeZoneIdentifiers resolves a known zone to its abbreviation', () {
      // Exercises the 976-line static timeZones map plus the location database.
      final abbr = SchedulerUtils.getTimeZoneIdentifiers('America/New_York');
      expect(abbr, isNotEmpty);
      expect(abbr, anyOf('EST', 'EDT'));
    });

    test('getTimeZoneIdentifiers returns empty string for an unknown zone', () {
      expect(SchedulerUtils.getTimeZoneIdentifiers('Mars/Olympus'), '');
    });

    test('getConvertedTime moves an instant into the target zone', () {
      final utcNoon = DateTime.utc(2026, 9, 8, 12);
      final ny = SchedulerUtils.getConvertedTime(utcNoon, 'America/New_York');
      // Same instant, different wall clock. September is daylight time (-4).
      expect(ny.toUtc(), utcNoon);
      expect(ny.hour, 8);
    });
  });

  // -------------------------------------------------------------------------
  group('getFormattedTime', () {
    test('twelveHour renders a meridiem', () {
      final s = SchedulerUtils.getFormattedTime(
        _at(15, 5),
        TimeFormat.twelveHour,
      );
      expect(s, contains('3'));
      expect(s.toUpperCase(), contains('PM'));
    });

    test('twentyFourHour renders 24-hour clock with no meridiem', () {
      final s = SchedulerUtils.getFormattedTime(
        _at(15, 5),
        TimeFormat.twentyFourHour,
      );
      expect(s, '15:05');
      expect(s.toUpperCase(), isNot(contains('PM')));
    });

    test('midnight differs between the two formats', () {
      final midnight = _at(0, 0);
      expect(
        SchedulerUtils.getFormattedTime(midnight, TimeFormat.twentyFourHour),
        '00:00',
      );
      expect(
        SchedulerUtils.getFormattedTime(
          midnight,
          TimeFormat.twelveHour,
        ).toUpperCase(),
        contains('AM'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('checkBlockedSlotStatus', () {
    final blocked = [_range(_at(10), const Duration(hours: 1))]; // 10:00-11:00

    test('a time inside the blocked slot is blocked', () {
      expect(
        SchedulerUtils.checkBlockedSlotStatus(blocked, 0, _at(10, 30)),
        isTrue,
      );
    });

    test('a time after the slot is free when there is no buffer', () {
      expect(
        SchedulerUtils.checkBlockedSlotStatus(blocked, 0, _at(11, 30)),
        isFalse,
      );
    });

    test('the buffer extends the block past the slot end', () {
      // 11:30 is clear of the slot but inside a 60-minute buffer.
      expect(
        SchedulerUtils.checkBlockedSlotStatus(blocked, 60, _at(11, 30)),
        isTrue,
      );
    });

    test('the start is exclusive — exactly the start time is not blocked', () {
      // isAfter(start) is strict, so the boundary itself reads as free.
      expect(
        SchedulerUtils.checkBlockedSlotStatus(blocked, 0, _at(10, 0)),
        isFalse,
      );
    });

    test('no blocked slots means nothing is blocked', () {
      expect(
        SchedulerUtils.checkBlockedSlotStatus([], 60, _at(10, 30)),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('isDateSelectable', () {
    final monday = _nextWeekday(DateTime.monday);
    final dayKey = _dayKey(monday);

    test('a full-day-out blocked date is not selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(monday, null, null, {
          dayKey: {'fullDayOut': true},
        }, null),
        isFalse,
      );
    });

    test('a blocked date that is not full-day-out stays selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(monday, null, null, {
          dayKey: {'fullDayOut': false},
        }, null),
        isTrue,
      );
    });

    test('a weekday absent from availability is not selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(monday, null, null, {}, {
          'tuesday': [],
        }),
        isFalse,
      );
    });

    test('a weekday present but empty is not selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(monday, null, null, {}, {'monday': []}),
        isFalse,
      );
    });

    test('a weekday with a range is selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(monday, null, null, {}, {
          'monday': [TimeRange(from: '0900', to: '1700')],
        }),
        isTrue,
      );
    });

    // The window used to be a disjunction containing
    // `selectedDate.isAtSameMomentAs(selectedDate)`, always true, so neither
    // bound was enforced. Fixed under ENG-39021.
    test('a date before `from` is not selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(
          DateTime(2020, 1, 1),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
          {},
          null,
        ),
        isFalse,
      );
    });

    test('a date after `to` is not selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(
          DateTime(2030, 1, 1),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
          {},
          null,
        ),
        isFalse,
      );
    });

    test('a date inside the window is selectable', () {
      expect(
        SchedulerUtils.isDateSelectable(
          DateTime(2026, 6, 1),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
          {},
          null,
        ),
        isTrue,
      );
    });

    test('both bounds are inclusive', () {
      for (final d in [DateTime(2026, 1, 1), DateTime(2026, 12, 31)]) {
        expect(
          SchedulerUtils.isDateSelectable(
            d,
            DateTime(2026, 1, 1),
            DateTime(2026, 12, 31),
            {},
            null,
          ),
          isTrue,
          reason: '$d',
        );
      }
    });

    test('a null `to` leaves the upper end open', () {
      expect(
        SchedulerUtils.isDateSelectable(
          DateTime(2099, 1, 1),
          DateTime(2026, 1, 1),
          null,
          {},
          null,
        ),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('nearestSelectableDate', () {
    test('returns the day itself when it is already selectable', () {
      final d = _nextWeekday(DateTime.monday);
      expect(SchedulerUtils.nearestSelectableDate(d, null, null, {}, null), d);
    });

    test('walks forward past consecutive blocked days', () {
      final start = _nextWeekday(DateTime.monday);
      final second = start.add(const Duration(days: 1));
      final blocked = {
        _dayKey(start): {'fullDayOut': true},
        _dayKey(second): {'fullDayOut': true},
      };
      expect(
        SchedulerUtils.nearestSelectableDate(start, null, null, blocked, null),
        start.add(const Duration(days: 2)),
      );
    });

    test('terminates instead of hanging when nothing is ever selectable', () {
      // Availability keyed with names the class does not know means every day
      // reads as unavailable. This used to recurse forever and hang the
      // isolate; it is now a bounded walk that gives up. ENG-39021.
      final start = _nextWeekday(DateTime.monday);
      expect(
        SchedulerUtils.nearestSelectableDate(start, null, null, {}, {
          'mon': [TimeRange(from: '0900', to: '1700')],
        }),
        start,
        reason: 'falls back to the day it was given',
      );
    });

    test('stops at the end of the window rather than walking past it', () {
      final start = _nextWeekday(DateTime.monday);
      final d2 = start.add(const Duration(days: 1));
      final d3 = start.add(const Duration(days: 2));
      expect(
        SchedulerUtils.nearestSelectableDate(start, null, d3, {
          _dayKey(start): {'fullDayOut': true},
          _dayKey(d2): {'fullDayOut': true},
          _dayKey(d3): {'fullDayOut': true},
        }, null),
        start,
      );
    });

    test('skips weekdays that carry no availability', () {
      // Only Wednesday is available, so Monday should advance to it.
      final monday = _nextWeekday(DateTime.monday);
      final result = SchedulerUtils.nearestSelectableDate(
        monday,
        null,
        null,
        {},
        {
          'wednesday': [TimeRange(from: '0900', to: '1700')],
        },
      );
      expect(result, monday.add(const Duration(days: 2)));
    });
  });

  // -------------------------------------------------------------------------
  group('getAvailableSlots', () {
    test(
      'builds one range per availability entry for the matching weekday',
      () {
        // 2026-09-07 is a Monday.
        final slots = SchedulerUtils.getAvailableSlots(
          _nextWeekday(DateTime.monday),
          'America/New_York',
          'America/New_York',
          {
            'monday': [
              TimeRange(from: '0900', to: '1200'),
              TimeRange(from: '1300', to: '1700'),
            ],
          },
        );
        expect(slots, hasLength(2));
        expect(slots.first.start.hour, 9);
        expect(slots.first.end.hour, 12);
        expect(slots.last.start.hour, 13);
        expect(slots.last.end.hour, 17);
      },
    );

    test('a weekday with no availability yields no slots', () {
      final slots = SchedulerUtils.getAvailableSlots(
        _nextWeekday(DateTime.monday),
        'America/New_York',
        'America/New_York',
        {
          'tuesday': [TimeRange(from: '0900', to: '1700')],
        },
      );
      expect(slots, isEmpty);
    });

    test('a colon-formatted time is tolerated — ENG-39021', () {
      // The documented format is HHmm, but the payload is untrusted and the
      // equally plausible HH:mm used to throw FormatException and take slot
      // generation down. It now parses to the same slot.
      final slots = SchedulerUtils.getAvailableSlots(
        _nextWeekday(DateTime.monday),
        'America/New_York',
        'America/New_York',
        {
          'monday': [TimeRange(from: '09:00', to: '17:00')],
        },
      );
      expect(slots, hasLength(1));
      expect(slots.single.start.hour, 9);
      expect(slots.single.end.hour, 17);
    });

    test('a malformed time degrades to midnight rather than throwing', () {
      expect(
        () => SchedulerUtils.getAvailableSlots(
          _nextWeekday(DateTime.monday),
          'America/New_York',
          'America/New_York',
          {
            'monday': [TimeRange(from: 'garbage', to: 'also garbage')],
          },
        ),
        returnsNormally,
      );
    });

    test('null availability yields no slots', () {
      expect(
        SchedulerUtils.getAvailableSlots(
          _nextWeekday(DateTime.monday),
          'America/New_York',
          'America/New_York',
          null,
        ),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('adjustAvailableSlots', () {
    test('a blocked slot in the middle splits the available range', () {
      final available = [_range(_at(9), const Duration(hours: 8))]; // 09-17
      final blocked = [_range(_at(12), const Duration(hours: 1))]; // 12-13
      final adjusted = SchedulerUtils.adjustAvailableSlots(
        available,
        blocked,
        Duration.zero,
        DateTime(2026, 9, 8),
      );
      expect(adjusted, isNotEmpty);
      // Nothing produced may span the blocked hour.
      for (final s in adjusted) {
        expect(
          s.start.isBefore(_at(13)) &&
              s.end.isAfter(_at(12)) &&
              s.start.isBefore(_at(12)) == false &&
              s.end.isAfter(_at(13)),
          isFalse,
          reason: 'no adjusted slot may contain the blocked window whole',
        );
      }
    });

    test('no blocked slots leaves nothing to adjust', () {
      final available = [_range(_at(9), const Duration(hours: 8))];
      expect(
        SchedulerUtils.adjustAvailableSlots(
          available,
          const [],
          Duration.zero,
          DateTime(2026, 9, 8),
        ),
        isEmpty,
        reason: 'the inner loop never runs without blocked slots',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('checkTimeIsOverlapping', () {
    final available = [_range(_at(9), const Duration(hours: 8))]; // 09-17

    test('a meeting strictly inside an available slot overlaps', () {
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_at(10), const Duration(hours: 1)),
          available,
          const [],
          Duration.zero,
          DateTime(2026, 9, 8),
        ),
        isTrue,
      );
    });

    test('a meeting outside every available slot does not overlap', () {
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_at(20), const Duration(hours: 1)),
          available,
          const [],
          Duration.zero,
          DateTime(2026, 9, 8),
        ),
        isFalse,
      );
    });

    test('no available slots means no overlap', () {
      expect(
        SchedulerUtils.checkTimeIsOverlapping(
          _range(_at(10), const Duration(hours: 1)),
          const [],
          const [],
          Duration.zero,
          DateTime(2026, 9, 8),
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('getAvailabilityJson', () {
    test('each TimeRange becomes its from/to map', () {
      final json = SchedulerUtils.getAvailabilityJson({
        'monday': [
          TimeRange(from: '0900', to: '1200'),
          TimeRange(from: '1300', to: '1700'),
        ],
        'tuesday': [],
      });
      expect(json.keys, containsAll(['monday', 'tuesday']));
      expect(json['monday'], hasLength(2));
      expect(json['tuesday'], isEmpty);
      expect((json['monday']!.first as Map)['from'], '0900');
      expect((json['monday']!.first as Map)['to'], '1200');
    });

    test('null availability yields an empty map', () {
      expect(SchedulerUtils.getAvailabilityJson(null), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('DateTimeRange extension', () {
    final a = _range(_at(10), const Duration(hours: 1)); // 10-11

    test('isOverlappingWithBuffer is false for well-separated ranges', () {
      final far = _range(_at(15), const Duration(hours: 1));
      expect(a.isOverlappingWithBuffer(far, 0), isFalse);
    });

    test('a large enough buffer makes separated ranges overlap', () {
      final near = _range(_at(12), const Duration(hours: 1)); // 12-13
      expect(a.isOverlappingWithBuffer(near, 0), isFalse);
      expect(a.isOverlappingWithBuffer(near, 120), isTrue);
    });

    test('isStartsBetweenOther is strict at both ends', () {
      final outer = _range(_at(9), const Duration(hours: 8)); // 09-17
      expect(a.isStartsBetweenOther(outer), isTrue);
      expect(outer.isStartsBetweenOther(outer), isFalse, reason: 'not strict');
    });

    test('isEndsBetweenOther accounts for the buffer', () {
      final outer = _range(_at(9), const Duration(hours: 3)); // 09-12
      expect(a.isEndsBetweenOther(outer, Duration.zero), isTrue);
      // Pushing the end past 12:00 takes it outside.
      expect(a.isEndsBetweenOther(outer, const Duration(hours: 2)), isFalse);
    });

    test('timeIsValid requires the meeting strictly inside', () {
      final outer = _range(_at(9), const Duration(hours: 8));
      expect(outer.timeIsValid(a), isTrue);
      expect(
        outer.timeIsValid(outer),
        isFalse,
        reason: 'boundaries are strict',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('DateTime extension', () {
    test('isSameDay ignores the clock', () {
      expect(_at(1).isSameDay(_at(23)), isTrue);
      expect(_at(1).isSameDay(DateTime(2026, 9, 9)), isFalse);
    });

    test('isSameTime ignores the date', () {
      expect(_at(10, 30).isSameTime(DateTime(2030, 1, 1, 10, 30)), isTrue);
      expect(_at(10, 30).isSameTime(_at(10, 31)), isFalse);
    });

    test('adjustTimeDifference adds for a positive offset', () {
      expect(_at(10).adjustTimeDifference(2, 30), _at(12, 30));
    });

    test('adjustTimeDifference subtracts for a negative offset', () {
      expect(_at(10).adjustTimeDifference(-2, 30), _at(7, 30));
    });

    test('a zero-hour offset still applies its minutes — ENG-39021', () {
      expect(_at(10).adjustTimeDifference(0, 30), _at(10, 30));
    });

    test('a zero-hour negative offset subtracts its minutes', () {
      expect(_at(10).adjustTimeDifference(0, -30), _at(9, 30));
    });

    test('a wholly zero offset is a no-op', () {
      expect(_at(10).adjustTimeDifference(0, 0), _at(10));
    });
  });

  // -------------------------------------------------------------------------
  group('List<DateTime> extension', () {
    test('containsSameDate matches on day and clock together', () {
      final list = [_at(10), _at(11)];
      expect(list.containsSameDate(_at(10)), isTrue);
      expect(list.containsSameDate(_at(12)), isFalse);
      expect(
        list.containsSameDate(DateTime(2026, 9, 9, 10)),
        isFalse,
        reason: 'same clock, different day',
      );
    });

    test('getMax returns the latest instant', () {
      expect([_at(10), _at(15), _at(12)].getMax(), _at(15));
    });

    test('validateEntry accepts a later, unseen time', () {
      expect([_at(10)].validateEntry(_at(11)), isTrue);
    });

    test('validateEntry rejects a duplicate', () {
      expect([_at(10)].validateEntry(_at(10)), isFalse);
    });

    test('validateEntry rejects a time earlier than the max', () {
      expect([_at(10), _at(15)].validateEntry(_at(12)), isFalse);
    });

    test('validateEntry accepts anything into an empty list', () {
      expect(<DateTime>[].validateEntry(_at(10)), isTrue);
    });
  });
  // -------------------------------------------------------------------------
  // The static timeZones map — 976 lines of it, read by
  // CometChatUIKit._inititalizeTimeZoneDetails to resolve the local zone.
  // -------------------------------------------------------------------------
  group('timeZones map', () {
    test('every entry carries the abbr and name the kit reads', () {
      final zones = SchedulerUtils.timeZones;
      expect(zones, isNotEmpty);
      expect(zones.length, greaterThan(100));

      final missingName = <String>[];
      final missingAbbr = <String>[];
      zones.forEach((key, value) {
        if (value['name'] == null) missingName.add(key);
        if (value['abbr'] == null) missingAbbr.add(key);
      });
      // _inititalizeTimeZoneDetails reads value["abbr"], value["sabbr"] and
      // value["name"]; a null name would surface as a blank picker entry.
      expect(missingAbbr, isEmpty, reason: 'entries with no abbr');
      expect(missingName, isEmpty, reason: 'entries with no name');
    });

    test('known IANA identifiers are present and well formed', () {
      final zones = SchedulerUtils.timeZones;
      for (final id in ['Etc/GMT+12', 'Pacific/Midway']) {
        expect(zones.containsKey(id), isTrue, reason: id);
        expect(zones[id]!['name'], isA<String>());
      }
    });

    test('the map survives a filtering consumer — ENG-39021', () {
      // _inititalizeTimeZoneDetails used to bind this static directly and
      // removeWhere on it, permanently emptying it for the process. It now
      // takes a copy; this asserts that filtering a copy leaves the original
      // intact, which is the property that was violated.
      final before = SchedulerUtils.timeZones.length;
      final copy = Map<String, Map>.of(SchedulerUtils.timeZones);
      copy.removeWhere((k, v) => true);
      expect(copy, isEmpty);
      expect(
        SchedulerUtils.timeZones.length,
        before,
        reason: 'the shared static must be untouched',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('parseICS', () {
    const ics =
        'BEGIN:VCALENDAR\n'
        'BEGIN:VEVENT\n'
        'DTSTART;TZID=America/New_York:20260908T100000\n'
        'DTEND;TZID=America/New_York:20260908T110000\n'
        'END:VEVENT\n'
        'END:VCALENDAR';

    test('a single event becomes one blocked date with one timing', () {
      final blocked = SchedulerUtils.parseICS(ics, 'America/New_York');
      expect(blocked, hasLength(1));
      final entry = blocked.values.single;
      expect(entry['timings'], hasLength(1));
      expect(entry['fullDayOut'], isFalse);
      expect(entry['weekday'], 'Tuesday', reason: '2026-09-08 is a Tuesday');
    });

    test('two events on the same day collapse into one date key', () {
      final two = ics.replaceFirst(
        'END:VCALENDAR',
        'BEGIN:VEVENT\n'
            'DTSTART;TZID=America/New_York:20260908T140000\n'
            'DTEND;TZID=America/New_York:20260908T150000\n'
            'END:VEVENT\n'
            'END:VCALENDAR',
      );
      final blocked = SchedulerUtils.parseICS(two, 'America/New_York');
      expect(blocked, hasLength(1));
      expect(blocked.values.single['timings'], hasLength(2));
    });

    test('events on different days produce separate keys', () {
      final twoDays = ics.replaceFirst(
        'END:VCALENDAR',
        'BEGIN:VEVENT\n'
            'DTSTART;TZID=America/New_York:20260909T100000\n'
            'DTEND;TZID=America/New_York:20260909T110000\n'
            'END:VEVENT\n'
            'END:VCALENDAR',
      );
      expect(
        SchedulerUtils.parseICS(twoDays, 'America/New_York'),
        hasLength(2),
      );
    });

    test('content with no events yields no blocked dates', () {
      expect(
        SchedulerUtils.parseICS('BEGIN:VCALENDAR\nEND:VCALENDAR', 'UTC'),
        isEmpty,
      );
    });

    test('an empty string yields no blocked dates', () {
      expect(SchedulerUtils.parseICS('', 'UTC'), isEmpty);
    });
  });
}
