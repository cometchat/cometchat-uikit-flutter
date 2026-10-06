/// Behaviour tests for the vendored `TZDateTime` — Track 3 TEST3 (ENG-38684).
///
/// `timezone_utils/date_time.dart` is 133 executable lines at 15%: only the
/// handful of members `SchedulerUtils.getConvertedTime` happens to touch had
/// ever run. Everything a caller reads off a converted instant — the calendar
/// getters, the offset, the two string forms, the comparisons — was untested,
/// and this is the type every scheduler slot is expressed in.
///
/// Nothing here depends on the machine's own time zone: every case either
/// builds its own synthetic [Location] with a known offset, or names an IANA
/// zone explicitly, and `setLocalLocation` pins what "local" means for the
/// whole file. A test that read the host zone would pass in Kolkata and fail
/// on a UTC CI box.
///
///   flutter test test/shared_ui/utils/timezone_date_time_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/data/latest.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/date_time.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/env.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/location.dart';
import 'package:flutter_test/flutter_test.dart';

const int _hour = 3600 * 1000;

/// The instant every synthetic location below switches zone at.
final int _t = DateTime.utc(2020).millisecondsSinceEpoch;

TimeZone _zone(int hours, String abbr) =>
    TimeZone(hours * _hour, isDst: false, abbreviation: abbr);

/// A location that is [beforeHours] east of UTC until [_t] and [afterHours]
/// east of UTC from [_t] onwards.
Location _shifting(String name, int beforeHours, int afterHours) => Location(
  name,
  [minTime, _t],
  [0, 1],
  [_zone(beforeHours, 'BEFORE'), _zone(afterHours, 'AFTER')],
);

/// A location with a single, never-changing offset.
Location _fixed(String name, int hours) =>
    Location(name, [minTime], [0], [_zone(hours, name)]);

void main() {
  // The database `CometChatUIKit.init` fills; `getLocation` needs it.
  setUpAll(initializeTimeZones);

  // "Local" is a mutable global in this library and defaults to UTC. Pin it to
  // a zone with a distinctive offset so `local` / `toLocal` / `isLocal` assert
  // something, whatever the host is set to.
  final localZone = _fixed('Test/Local', 7);
  setUp(() => setLocalLocation(localZone));

  // ==========================================================================
  group('constructing from a wall clock', () {
    test('a zero-offset zone takes the wall clock as the instant', () {
      final loc = _fixed('Test/Zero', 0);
      final t = TZDateTime(loc, 2021, 3, 4, 5, 6, 7, 8, 9);
      expect(
        t.millisecondsSinceEpoch,
        DateTime.utc(2021, 3, 4, 5, 6, 7, 8).millisecondsSinceEpoch,
      );
      expect(t.microsecond, 9);
    });

    test('a positive offset is subtracted to reach the instant', () {
      // 12:00 wall in a +05:00 zone is 07:00 UTC.
      final loc = _fixed('Test/Plus5', 5);
      final t = TZDateTime(loc, 2021, 6, 1, 12);
      expect(t.toUtc().hour, 7);
      expect(t.hour, 12, reason: 'the wall clock is what was asked for');
      expect(t.timeZoneOffset, const Duration(hours: 5));
      expect(t.timeZoneName, 'Test/Plus5');
    });

    test('a negative offset is added to reach the instant', () {
      final loc = _fixed('Test/Minus5', -5);
      final t = TZDateTime(loc, 2021, 6, 1, 12);
      expect(t.toUtc().hour, 17);
      expect(t.timeZoneOffset, const Duration(hours: -5));
    });

    test('a wall clock in a spring-forward gap resolves with the OLD '
        'offset', () {
      // +02:00 becomes +05:00 at _t, so wall times in [_t+2h, _t+5h) never
      // happen. Asking for one lands back in the pre-transition zone.
      final loc = _shifting('Test/Gap', 2, 5);
      final gap = DateTime.utc(2020).add(const Duration(hours: 3));
      final t = TZDateTime(loc, gap.year, gap.month, gap.day, gap.hour);
      expect(t.millisecondsSinceEpoch, _t + 1 * _hour);
    });

    test('a wall clock resolved past the end of its zone falls into the '
        'next one', () {
      // -03:00 becomes +00:00 at _t. The wall clock one hour before the
      // transition resolves to an instant at or after it, so the lookup has to
      // be redone against the following zone.
      final loc = _shifting('Test/Overrun', -3, 0);
      final before = DateTime.utc(2019, 12, 31, 23);
      final t = TZDateTime(
        loc,
        before.year,
        before.month,
        before.day,
        before.hour,
      );
      expect(t.millisecondsSinceEpoch, _t - 1 * _hour);
    });

    test('microseconds survive a time-zone shift', () {
      final loc = _fixed('Test/Micro', 3);
      final t = TZDateTime(loc, 2021, 1, 1, 0, 0, 0, 123, 456);
      expect(t.millisecond, 123);
      expect(t.microsecond, 456);
    });
  });

  // ==========================================================================
  group('the named constructors', () {
    test('utc builds a UTC instant and reports isUtc', () {
      final t = TZDateTime.utc(1944, 6, 6, 6, 30);
      expect(t.isUtc, isTrue);
      expect(t.isLocal, isFalse);
      expect(
        t.millisecondsSinceEpoch,
        DateTime.utc(1944, 6, 6, 6, 30).millisecondsSinceEpoch,
      );
      expect(t.timeZoneName, 'UTC');
      expect(t.timeZoneOffset, Duration.zero);
    });

    test('local uses whatever setLocalLocation last named', () {
      final t = TZDateTime.local(2021, 1, 1, 12);
      expect(t.isLocal, isTrue);
      expect(t.isUtc, isFalse);
      expect(t.location, same(localZone));
      // Noon in the pinned +07:00 zone is 05:00 UTC.
      expect(t.toUtc().hour, 5);
    });

    test('fromMillisecondsSinceEpoch places the instant in the given '
        'zone', () {
      final loc = _fixed('Test/Plus2', 2);
      final t = TZDateTime.fromMillisecondsSinceEpoch(loc, _t);
      expect(t.millisecondsSinceEpoch, _t);
      expect(t.hour, 2, reason: '00:00Z is 02:00 at +02:00');
      expect(t.year, 2020);
      expect(t.month, 1);
      expect(t.day, 1);
    });

    test('fromMicrosecondsSinceEpoch keeps sub-millisecond precision', () {
      final loc = _fixed('Test/Plus2b', 2);
      final t = TZDateTime.fromMicrosecondsSinceEpoch(loc, _t * 1000 + 1500);
      expect(t.microsecondsSinceEpoch, _t * 1000 + 1500);
      expect(t.millisecond, 1);
      expect(t.microsecond, 500);
    });

    test('now is in the requested zone and close to DateTime.now', () {
      final loc = _fixed('Test/Plus9', 9);
      final before = DateTime.now().millisecondsSinceEpoch;
      final t = TZDateTime.now(loc);
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(t.location, same(loc));
      expect(t.millisecondsSinceEpoch, inInclusiveRange(before, after));
    });

    test('parse reads an ISO string and re-expresses it in the zone', () {
      final loc = _fixed('Test/Plus1', 1);
      final t = TZDateTime.parse(loc, '2012-02-27T14:00:00Z');
      expect(t.hour, 15);
      expect(t.toUtc().hour, 14);
      expect(() => TZDateTime.parse(loc, 'not a date'), throwsFormatException);
    });

    test('from re-expresses an existing TZDateTime without moving it', () {
      final a = TZDateTime(_fixed('Test/A', 4), 2021, 5, 6, 7);
      final b = TZDateTime.from(a, _fixed('Test/B', -4));
      expect(b.millisecondsSinceEpoch, a.millisecondsSinceEpoch);
      expect(b.hour, 23);
      expect(b.day, 5);
    });
  });

  // ==========================================================================
  group('toUtc / toLocal', () {
    test('toUtc on a UTC instant returns the same object', () {
      final t = TZDateTime.utc(2021);
      expect(identical(t.toUtc(), t), isTrue);
    });

    test('toUtc moves a zoned instant into UTC without changing it', () {
      final t = TZDateTime(_fixed('Test/Plus8', 8), 2021, 7, 1, 9);
      final u = t.toUtc();
      expect(u.isUtc, isTrue);
      expect(u.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
      expect(u.hour, 1);
    });

    test('toLocal on a local instant returns the same object', () {
      final t = TZDateTime.local(2021);
      expect(identical(t.toLocal(), t), isTrue);
    });

    test('toLocal moves a UTC instant into the pinned local zone', () {
      final t = TZDateTime.utc(2021, 1, 1, 0).toLocal();
      expect(t.isLocal, isTrue);
      expect(t.hour, 7);
    });
  });

  // ==========================================================================
  group('toString and toIso8601String', () {
    test('a UTC instant renders with a Z and no offset', () {
      final t = TZDateTime.utc(2021, 2, 3, 4, 5, 6, 7);
      expect(t.toIso8601String(), '2021-02-03T04:05:06.007Z');
      expect(t.toString(), '2021-02-03 04:05:06.007Z');
    });

    test('microseconds are appended only when non-zero', () {
      final loc = _fixed('Test/Us', 0);
      expect(
        TZDateTime(loc, 2021, 1, 1, 0, 0, 0, 12, 0).toIso8601String(),
        endsWith('00:00:00.012+0000'),
      );
      expect(
        TZDateTime(loc, 2021, 1, 1, 0, 0, 0, 12, 34).toIso8601String(),
        endsWith('00:00:00.012034+0000'),
      );
    });

    test('a positive offset renders as +hhmm and a negative one as -hhmm', () {
      expect(
        TZDateTime(
          Location('Test/Half', [minTime], [0], [
            TimeZone(
              5 * _hour + 30 * 60 * 1000,
              isDst: false,
              abbreviation: 'IST',
            ),
          ]),
          2021,
          1,
          1,
          9,
        ).toIso8601String(),
        '2021-01-01T09:00:00.000+0530',
      );
      expect(
        TZDateTime(
          Location('Test/NegHalf', [minTime], [0], [
            TimeZone(
              -(3 * _hour + 30 * 60 * 1000),
              isDst: false,
              abbreviation: 'NST',
            ),
          ]),
          2021,
          1,
          1,
          9,
        ).toIso8601String(),
        '2021-01-01T09:00:00.000-0330',
      );
    });

    test('the year is padded to four digits, sign included', () {
      String yearOf(int year) =>
          TZDateTime.utc(year, 1, 1).toIso8601String().split('-01-01').first;
      expect(yearOf(7), '0007');
      expect(yearOf(70), '0070');
      expect(yearOf(700), '0700');
      expect(yearOf(7000), '7000');
      // A negative year keeps its sign and still pads to four digits.
      expect(TZDateTime.utc(-7, 1, 1).toIso8601String(), startsWith('-0007-'));
      expect(
        TZDateTime.utc(-700, 1, 1).toIso8601String(),
        startsWith('-0700-'),
      );
      expect(
        TZDateTime.utc(-7000, 1, 1).toIso8601String(),
        startsWith('-7000-'),
      );
    });

    test('milliseconds are padded to three digits', () {
      String msOf(int ms) => TZDateTime.utc(
        2021,
        1,
        1,
        0,
        0,
        0,
        ms,
      ).toIso8601String().split('.').last.replaceAll('Z', '');
      expect(msOf(4), '004');
      expect(msOf(40), '040');
      expect(msOf(400), '400');
    });
  });

  // ==========================================================================
  group('arithmetic and comparison', () {
    final loc = _fixed('Test/Cmp', 6);
    final noon = TZDateTime(loc, 2021, 8, 9, 12);

    test('add and subtract stay in the same location', () {
      final later = noon.add(const Duration(hours: 3, minutes: 30));
      expect(later.location, same(loc));
      expect(later.hour, 15);
      expect(later.minute, 30);

      final earlier = noon.subtract(const Duration(days: 1));
      expect(earlier.day, 8);
      expect(earlier.hour, 12);
    });

    test('difference is measured against the instant, not the wall clock', () {
      final other = TZDateTime(_fixed('Test/Cmp2', 0), 2021, 8, 9, 12);
      // Same wall clock, six hours apart in real time.
      expect(noon.difference(other), const Duration(hours: -6));
      expect(noon.difference(DateTime.utc(2021, 8, 9, 6)), Duration.zero);
    });

    test('isBefore / isAfter / isAtSameMomentAs compare instants', () {
      final sameMoment = TZDateTime(_fixed('Test/Cmp3', 0), 2021, 8, 9, 6);
      expect(noon.isAtSameMomentAs(sameMoment), isTrue);
      expect(noon.isBefore(sameMoment), isFalse);
      expect(noon.isAfter(sameMoment), isFalse);

      final later = noon.add(const Duration(seconds: 1));
      expect(noon.isBefore(later), isTrue);
      expect(later.isAfter(noon), isTrue);
      expect(noon.isAtSameMomentAs(later), isFalse);
    });

    test('compareTo orders by instant', () {
      final later = noon.add(const Duration(minutes: 1));
      expect(noon.compareTo(later), lessThan(0));
      expect(later.compareTo(noon), greaterThan(0));
      expect(noon.compareTo(DateTime.utc(2021, 8, 9, 6)), 0);
    });

    test('equality needs the same instant AND the same location', () {
      final sameZone = TZDateTime(loc, 2021, 8, 9, 12);
      expect(noon == sameZone, isTrue);
      expect(noon.hashCode, sameZone.hashCode);
      // ignore: unrelated_type_equality_checks
      expect(noon == DateTime.utc(2021, 8, 9, 6), isFalse);

      final sameMomentElsewhere = TZDateTime(
        _fixed('Test/Cmp4', 0),
        2021,
        8,
        9,
        6,
      );
      expect(noon.isAtSameMomentAs(sameMomentElsewhere), isTrue);
      expect(
        noon == sameMomentElsewhere,
        isFalse,
        reason: 'same instant, different zone, so not equal',
      );
      expect(noon == noon, isTrue);
    });
  });

  // ==========================================================================
  group('calendar getters read the wall clock of the location', () {
    test('every field comes from the zoned, not the UTC, calendar', () {
      // 2021-03-01T23:30:45.678901Z is 2021-03-02T05:00:45 at +05:30.
      final loc = Location('Test/Fields', [minTime], [0], [
        TimeZone(5 * _hour + 30 * 60 * 1000, isDst: false, abbreviation: 'FLD'),
      ]);
      final t = TZDateTime.fromMicrosecondsSinceEpoch(
        loc,
        DateTime.utc(2021, 3, 1, 23, 30, 45, 678, 901).microsecondsSinceEpoch,
      );
      expect(t.year, 2021);
      expect(t.month, 3);
      expect(t.day, 2);
      expect(t.hour, 5);
      expect(t.minute, 0);
      expect(t.second, 45);
      expect(t.millisecond, 678);
      expect(t.microsecond, 901);
      expect(t.weekday, DateTime.tuesday);
      expect(t.timeZoneName, 'FLD');
      expect(t.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    });

    test('a zone change moves the reported weekday across the date line', () {
      final utc = TZDateTime.utc(2021, 3, 1, 23);
      expect(utc.weekday, DateTime.monday);
      expect(
        TZDateTime.from(utc, _fixed('Test/Plus3', 3)).weekday,
        DateTime.tuesday,
      );
    });
  });

  // ==========================================================================
  group('against the real tz database', () {
    test('a named zone reports the offset and abbreviation for the '
        'instant, not for today', () {
      final ny = getLocation('America/New_York');
      final winter = TZDateTime.fromMillisecondsSinceEpoch(
        ny,
        DateTime.utc(2021, 1, 15, 17).millisecondsSinceEpoch,
      );
      final summer = TZDateTime.fromMillisecondsSinceEpoch(
        ny,
        DateTime.utc(2021, 7, 15, 17).millisecondsSinceEpoch,
      );
      expect(winter.timeZoneOffset, const Duration(hours: -5));
      expect(winter.timeZoneName, 'EST');
      expect(winter.hour, 12);
      expect(summer.timeZoneOffset, const Duration(hours: -4));
      expect(summer.timeZoneName, 'EDT');
      expect(summer.hour, 13);
    });
  });
}
