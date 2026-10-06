/// Behaviour tests for the vendored timezone engine underneath
/// `CometChatTimezoneUtils`:
///
///   lib/shared_ui/src/utils/timezone_utils/location.dart
///   lib/shared_ui/src/utils/timezone_utils/tzdb.dart
///   lib/shared_ui/src/utils/timezone_utils/location_database.dart
///   lib/shared_ui/src/utils/timezone_utils/exceptions.dart
///
/// `location.dart` is what turns an instant into an offset, and its hard part
/// is the *local* direction: given a wall-clock reading with no zone attached,
/// which offset applied? Around a DST transition the naive answer lands on the
/// wrong side of the boundary, and `translateToUtc` / `timeZoneFromLocal`
/// carry explicit corrections for both directions. Those corrections were
/// entirely unexercised, and they are asymmetric — the "utc < start" fix only
/// fires for zones east of UTC and the "utc >= end" fix only for zones west of
/// it — so this file builds one fixture of each sign.
///
/// TIMEZONE INDEPENDENCE: every Location here is constructed from literal
/// offsets and literal UTC instants. Nothing reads the host zone, so these
/// pass identically on a UTC CI runner and on a laptop in IST. The one piece
/// of ambient state is `Location`'s "now" cache, filled at construction from
/// the wall clock; every fixture puts all of its transitions in the past
/// (2020-2021) so the cache resolves to the last transition whatever the date.
///
///   flutter test test/shared_ui/utils/timezone_location_tzdb_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/exceptions.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/location.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/location_database.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/utils/timezone_utils/tzdb.dart';
import 'package:flutter_test/flutter_test.dart';

const int _hour = 3600 * 1000;

int _utcMs(int y, int m, int d, [int h = 0]) =>
    DateTime.utc(y, m, d, h).millisecondsSinceEpoch;

// ─── Fixture A: west of UTC (New-York-shaped) ────────────────────────────────

const _est = TimeZone(-5 * _hour, isDst: false, abbreviation: 'EST');
const _edt = TimeZone(-4 * _hour, isDst: true, abbreviation: 'EDT');

final _nySpring2020 = _utcMs(2020, 3, 8, 7);
final _nyFall2020 = _utcMs(2020, 11, 1, 6);
final _nySpring2021 = _utcMs(2021, 3, 14, 7);
final _nyFall2021 = _utcMs(2021, 11, 7, 6);

Location _newYork() => Location(
  'Test/New_York',
  [_nySpring2020, _nyFall2020, _nySpring2021, _nyFall2021],
  [1, 0, 1, 0],
  [_est, _edt],
);

// ─── Fixture B: east of UTC (Sydney-shaped) ─────────────────────────────────

const _aest = TimeZone(10 * _hour, isDst: false, abbreviation: 'AEST');
const _aedt = TimeZone(11 * _hour, isDst: true, abbreviation: 'AEDT');

final _syFall2020 = _utcMs(2020, 4, 4, 16); // AEDT -> AEST
final _sySpring2020 = _utcMs(2020, 10, 3, 16); // AEST -> AEDT
final _syFall2021 = _utcMs(2021, 4, 3, 16); // AEDT -> AEST
final _sySpring2021 = _utcMs(2021, 10, 2, 16); // AEST -> AEDT

Location _sydney() => Location(
  'Test/Sydney',
  [_syFall2020, _sySpring2020, _syFall2021, _sySpring2021],
  [0, 1, 0, 1],
  [_aest, _aedt],
);

void main() {
  // ===========================================================================
  group('TimeZone value semantics', () {
    test('two zones with the same fields are equal and hash alike', () {
      const a = TimeZone(3600000, isDst: true, abbreviation: 'CEST');
      const b = TimeZone(3600000, isDst: true, abbreviation: 'CEST');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('each field participates in equality', () {
      const base = TimeZone(3600000, isDst: true, abbreviation: 'CEST');
      expect(
        base,
        isNot(const TimeZone(7200000, isDst: true, abbreviation: 'CEST')),
      );
      expect(
        base,
        isNot(const TimeZone(3600000, isDst: false, abbreviation: 'CEST')),
      );
      expect(
        base,
        isNot(const TimeZone(3600000, isDst: true, abbreviation: 'CET')),
      );
    });

    test('a zone is not equal to a non-zone', () {
      expect(TimeZone.UTC == Object(), isFalse);
    });

    test('a zone equals itself by identity', () {
      expect(TimeZone.UTC, TimeZone.UTC);
    });

    test('toString names the abbreviation, offset and dst flag', () {
      expect(_edt.toString(), '[EDT offset=${-4 * _hour} dst=true]');
      expect(TimeZone.UTC.toString(), '[UTC offset=0 dst=false]');
    });

    test('the UTC constant is a zero-offset, non-dst zone', () {
      expect(TimeZone.UTC.offset, 0);
      expect(TimeZone.UTC.isDst, isFalse);
      expect(TimeZone.UTC.abbreviation, 'UTC');
    });
  });

  // ===========================================================================
  group('TzInstant', () {
    test('it carries the zone and the half-open interval it holds for', () {
      const i = TzInstant(TimeZone.UTC, 10, 20);
      expect(i.timeZone, TimeZone.UTC);
      expect(i.start, 10);
      expect(i.end, 20);
    });
  });

  // ===========================================================================
  group('Location.lookupTimeZone', () {
    test('a location with no zones answers UTC for all of time', () {
      final l = Location('Empty', const [], const [], const []);
      final i = l.lookupTimeZone(0);
      expect(i.timeZone, TimeZone.UTC);
      expect(i.start, minTime);
      expect(i.end, maxTime);
      expect(l.lookupTimeZone(maxTime).timeZone, TimeZone.UTC);
    });

    test('a zone-only location holds that zone for all of time', () {
      final l = Location('Fixed', const [], const [], const [_est]);
      final i = l.lookupTimeZone(_utcMs(2021, 6, 1));
      expect(i.timeZone, _est);
      expect(i.start, minTime);
      expect(i.end, maxTime);
    });

    test('before the first transition it uses the pre-transition zone', () {
      final l = _newYork();
      final i = l.lookupTimeZone(_utcMs(2020, 1, 1));
      // The first transition switches *to* EDT, so what came before is EST.
      expect(i.timeZone, _est);
      expect(i.start, minTime);
      expect(i.end, _nySpring2020);
    });

    test('between two transitions the binary search finds the interval', () {
      final l = _newYork();
      final i = l.lookupTimeZone(_utcMs(2020, 7, 1));
      expect(i.timeZone, _edt);
      expect(i.start, _nySpring2020);
      expect(i.end, _nyFall2020);
    });

    test('a transition instant belongs to the interval it opens', () {
      final l = _newYork();
      expect(l.timeZone(_nySpring2020), _edt);
      expect(l.timeZone(_nySpring2020 - 1), _est);
    });

    test('after the last transition the interval runs to the end of time', () {
      final l = _newYork();
      final i = l.lookupTimeZone(_utcMs(2022, 6, 1));
      expect(i.timeZone, _est);
      expect(i.start, _nyFall2021);
      expect(i.end, maxTime);
    });

    test('the three winter/summer intervals resolve to the right zone', () {
      final l = _newYork();
      expect(l.timeZone(_utcMs(2020, 12, 1)), _est);
      expect(l.timeZone(_utcMs(2021, 6, 1)), _edt);
      expect(l.timeZone(_utcMs(2021, 12, 1)), _est);
    });

    test('currentTimeZone answers for the wall clock', () {
      // Deterministic for any "now" after the last transition in the fixture.
      expect(_newYork().currentTimeZone, _est);
      expect(_sydney().currentTimeZone, _aedt);
    });

    test('toString is the location name', () {
      expect(_newYork().toString(), 'Test/New_York');
    });

    test('a transition still ahead of us bounds the now-cache', () {
      // A real tzdb carries future transitions; the constructor's cache then
      // ends at the next one rather than at the end of time. 2100 keeps this
      // deterministic without reading the host clock.
      final future = _utcMs(2100, 1, 1);
      final l = Location(
        'Test/Future',
        [_nyFall2021, future],
        const [0, 1],
        const [_est, _edt],
      );

      final now = l.lookupTimeZone(DateTime.now().millisecondsSinceEpoch);
      expect(now.timeZone, _est);
      expect(now.start, _nyFall2021);
      expect(now.end, future, reason: 'the cache must stop at the next change');
      expect(l.timeZone(future), _edt);
    });
  });

  // ===========================================================================
  // The four cases of the "what applied before the first transition?" rule.
  group('Location first-zone resolution', () {
    test('case 1: an unused first zone is the answer', () {
      // No transition ever selects zone 0, so zone 0 is the pre-history zone.
      final l = Location('C1', [_utcMs(2020, 1, 1)], const [1], const [
        _est,
        _edt,
      ]);
      expect(l.timeZone(_utcMs(2019, 1, 1)), _est);
    });

    test('case 2: walk back from a daylight first transition to standard', () {
      // zone 0 is used (by the second transition), and the first transition is
      // to DST, so the search walks back to the nearest non-DST zone.
      final l = _newYork();
      expect(l.timeZone(_utcMs(2019, 1, 1)), _est);
    });

    test('case 3: a standard first transition is used directly', () {
      const std = TimeZone(_hour, isDst: false, abbreviation: 'STD');
      const dst = TimeZone(2 * _hour, isDst: true, abbreviation: 'DST');
      // zones[0] is DST, so case 2 does not apply; the scan over transition
      // zones finds the standard one.
      final l = Location(
        'C3',
        [_utcMs(2020, 1, 1), _utcMs(2020, 6, 1)],
        const [1, 0],
        const [dst, std],
      );
      expect(l.timeZone(_utcMs(2019, 1, 1)), std);
    });

    test('case 4: with no standard zone anywhere, the first zone wins', () {
      const d0 = TimeZone(_hour, isDst: true, abbreviation: 'D0');
      const d1 = TimeZone(2 * _hour, isDst: true, abbreviation: 'D1');
      // zone 0 is used, the first transition is to DST but every earlier zone
      // is DST too, and the scan finds no standard zone — so zones.first.
      final l = Location(
        'C4',
        [_utcMs(2020, 1, 1), _utcMs(2020, 6, 1)],
        const [1, 0],
        const [d0, d1],
      );
      expect(l.timeZone(_utcMs(2019, 1, 1)), d0);
    });
  });

  // ===========================================================================
  group('Location.translate', () {
    test('it shifts a UTC instant by the offset in force at that instant', () {
      final l = _newYork();
      final winter = _utcMs(2020, 12, 1);
      final summer = _utcMs(2020, 7, 1);
      expect(l.translate(winter), winter - 5 * _hour);
      expect(l.translate(summer), summer - 4 * _hour);
    });

    test('east of UTC it shifts forward', () {
      final l = _sydney();
      final t = _utcMs(2020, 12, 1);
      expect(l.translate(t), t + 11 * _hour);
    });
  });

  // ===========================================================================
  group('Location.translateToUtc', () {
    test('a zero-offset zone is returned unchanged', () {
      final l = Location('Z', const [], const [], const [TimeZone.UTC]);
      final t = _utcMs(2021, 6, 1);
      expect(l.translateToUtc(t), t);
    });

    test('a local reading inside one interval simply loses the offset', () {
      final l = _newYork();
      // 2020-07-01 12:00 local (EDT, -4h) is 16:00 UTC.
      final local = _utcMs(2020, 7, 1, 12);
      expect(l.translateToUtc(local), local + 4 * _hour);
    });

    test('west of UTC: a reading near the end of an interval is corrected', () {
      // The naive answer (local + 4h) lands past the autumn transition, where
      // the offset is really -5h; the correction re-reads the zone at `end`.
      final l = _newYork();
      final local = _nyFall2020 - _hour;
      expect(l.translateToUtc(local), local + 5 * _hour);
    });

    test(
      'east of UTC: a reading near the start of an interval is corrected',
      () {
        // The naive answer (local - 11h) lands before the spring transition,
        // where the offset is really +10h.
        final l = _sydney();
        final local = _sySpring2020 + _hour;
        expect(l.translateToUtc(local), local - 10 * _hour);
      },
    );
  });

  // ===========================================================================
  group('Location.timeZoneFromLocal', () {
    test('a zero-offset zone needs no correction', () {
      final l = Location('Z', const [], const [], const [TimeZone.UTC]);
      expect(l.timeZoneFromLocal(_utcMs(2021, 6, 1)), TimeZone.UTC);
    });

    test('a reading well inside an interval keeps that interval s zone', () {
      final l = _newYork();
      expect(l.timeZoneFromLocal(_utcMs(2020, 7, 1, 12)), _edt);
      expect(l.timeZoneFromLocal(_utcMs(2020, 12, 1, 12)), _est);
    });

    test(
      'west of UTC: a reading past the interval end takes the next zone',
      () {
        final l = _newYork();
        expect(l.timeZoneFromLocal(_nyFall2020 - _hour), _est);
      },
    );

    test(
      'east of UTC: a reading before the interval start takes the previous zone',
      () {
        final l = _sydney();
        expect(l.timeZoneFromLocal(_sySpring2020 + _hour), _aest);
      },
    );
  });

  // ===========================================================================
  group('LocationDatabase', () {
    test('a fresh database is uninitialised and refuses lookups', () {
      final db = LocationDatabase();
      expect(db.isInitialized, isFalse);
      expect(
        () => db.get('Test/New_York'),
        throwsA(
          isA<LocationNotFoundException>().having(
            (e) => e.msg,
            'msg',
            contains('before initializing'),
          ),
        ),
      );
    });

    test('add makes the database initialised and the entry findable', () {
      final db = LocationDatabase()..add(_newYork());
      expect(db.isInitialized, isTrue);
      expect(db.get('Test/New_York').name, 'Test/New_York');
      expect(db.locations.keys, ['Test/New_York']);
    });

    test('a missing name on an initialised database names the location', () {
      final db = LocationDatabase()..add(_newYork());
      expect(
        () => db.get('Nowhere'),
        throwsA(
          isA<LocationNotFoundException>().having(
            (e) => e.msg,
            'msg',
            contains('"Nowhere"'),
          ),
        ),
      );
    });

    test('adding the same name twice replaces the entry', () {
      final db = LocationDatabase()..add(_newYork());
      final replacement = Location('Test/New_York', const [], const [], const [
        TimeZone.UTC,
      ]);
      db.add(replacement);
      expect(db.locations, hasLength(1));
      expect(db.get('Test/New_York'), same(replacement));
    });

    test(
      'the deprecated isEmpty alias reports initialisation, not emptiness',
      () {
        // Named backwards; it returns true when the database HAS entries.
        final db = LocationDatabase();
        // ignore: deprecated_member_use_from_same_package
        expect(db.isEmpty, isFalse);
        db.add(_newYork());
        // ignore: deprecated_member_use_from_same_package
        expect(db.isEmpty, isTrue);
        // ignore: deprecated_member_use_from_same_package
        expect(db.isEmpty, db.isInitialized);
      },
    );

    test('clear empties the database and re-arms the guard', () {
      final db = LocationDatabase()..add(_newYork());
      db.clear();
      expect(db.isInitialized, isFalse);
      expect(db.locations, isEmpty);
      expect(() => db.get('Test/New_York'), throwsA(isA<Exception>()));
    });
  });

  // ===========================================================================
  group('timezone exceptions', () {
    test('LocationNotFoundException reports its message verbatim', () {
      final e = LocationNotFoundException('no such place');
      expect(e.msg, 'no such place');
      expect(e.toString(), 'no such place');
      expect(e, isA<Exception>());
    });

    test('TimeZoneInitException reports its message verbatim', () {
      final e = TimeZoneInitException('bad db');
      expect(e.msg, 'bad db');
      expect(e.toString(), 'bad db');
      expect(e, isA<Exception>());
    });
  });

  // ===========================================================================
  group('tzdb serialize / deserialize', () {
    LocationDatabase database() => LocationDatabase()
      ..add(_newYork())
      ..add(_sydney());

    test('a round trip preserves names, zones and transitions', () {
      final restored = tzdbDeserialize(tzdbSerialize(database())).toList();

      expect(restored.map((l) => l.name), ['Test/New_York', 'Test/Sydney']);

      final ny = restored.first;
      expect(ny.zones, [_est, _edt]);
      expect(ny.transitionAt, [
        _nySpring2020,
        _nyFall2020,
        _nySpring2021,
        _nyFall2021,
      ]);
      expect(ny.transitionZone, [1, 0, 1, 0]);

      final sydney = restored.last;
      expect(sydney.zones, [_aest, _aedt]);
      expect(sydney.transitionZone, [0, 1, 0, 1]);
    });

    test('a restored location resolves instants exactly like the original', () {
      final restored = tzdbDeserialize(tzdbSerialize(database())).first;
      final original = _newYork();
      for (final t in [
        _utcMs(2019, 1, 1),
        _utcMs(2020, 7, 1),
        _utcMs(2020, 12, 1),
        _utcMs(2021, 7, 1),
        _utcMs(2022, 6, 1),
      ]) {
        expect(
          restored.timeZone(t),
          original.timeZone(t),
          reason: 'instant $t',
        );
        expect(restored.translate(t), original.translate(t));
      }
    });

    test('locations are written in name order, not insertion order', () {
      final db = LocationDatabase()
        ..add(_sydney())
        ..add(_newYork());
      expect(tzdbDeserialize(tzdbSerialize(db)).map((l) => l.name), [
        'Test/New_York',
        'Test/Sydney',
      ]);
    });

    test(
      'an abbreviation shared by two zones is stored once and shared back',
      () {
        const a = TimeZone(_hour, isDst: false, abbreviation: 'SAME');
        const b = TimeZone(2 * _hour, isDst: true, abbreviation: 'SAME');
        final db = LocationDatabase()
          ..add(
            Location('Test/Shared', [_utcMs(2020, 1, 1)], const [1], const [
              a,
              b,
            ]),
          );

        final restored = tzdbDeserialize(tzdbSerialize(db)).single;
        expect(restored.zones.map((z) => z.abbreviation), ['SAME', 'SAME']);
        expect(restored.zones.map((z) => z.offset), [_hour, 2 * _hour]);
        expect(restored.zones.map((z) => z.isDst), [false, true]);
      },
    );

    test('a location with no transitions survives the round trip', () {
      final db = LocationDatabase()
        ..add(Location('Test/Fixed', const [], const [], const [_est]));

      final restored = tzdbDeserialize(tzdbSerialize(db)).single;
      expect(restored.name, 'Test/Fixed');
      expect(restored.transitionAt, isEmpty);
      expect(restored.transitionZone, isEmpty);
      expect(restored.zones, [_est]);
      expect(restored.timeZone(_utcMs(2021, 1, 1)), _est);
    });

    test(
      'an empty database serializes to nothing and reads back as nothing',
      () {
        final bytes = tzdbSerialize(LocationDatabase());
        expect(bytes, isEmpty);
        expect(tzdbDeserialize(bytes), isEmpty);
      },
    );

    test('every record is padded to an eight-byte boundary', () {
      // The reader asserts this; names of differing length must not break it.
      for (final name in ['A', 'AB', 'ABCDEFG', 'A/Very_Long_Location_Name']) {
        final db = LocationDatabase()
          ..add(Location(name, const [], const [], const [_est]));
        final bytes = tzdbSerialize(db);
        expect(bytes.length % 8, 0, reason: name);
        expect(tzdbDeserialize(bytes).single.name, name);
      }
    });

    test('deserialize accepts a plain List<int>, not only a Uint8List', () {
      final bytes = tzdbSerialize(database());
      final asList = List<int>.from(bytes);
      expect(tzdbDeserialize(asList).map((l) => l.name), [
        'Test/New_York',
        'Test/Sydney',
      ]);
    });

    test('transitions are stored to second precision', () {
      // The wire format keeps seconds, so sub-second detail is dropped —
      // pinned so a future format change has to be deliberate.
      final db = LocationDatabase()
        ..add(
          Location('Test/Sub', const [1500], const [0], const [TimeZone.UTC]),
        );
      expect(tzdbDeserialize(tzdbSerialize(db)).single.transitionAt, [1000]);
    });
  });
}
