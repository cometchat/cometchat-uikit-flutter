import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/notification_feed/utils/timestamp_grouper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NotificationFeedItem _makeItem({
  required String id,
  required int sentAt,
  String category = 'promotions',
}) {
  return NotificationFeedItem(
    id: id,
    category: category,
    content: const {'type': 'test'},
    sentAt: sentAt,
    sender: 'server',
    receiver: 'user1',
    receiverType: 'user',
  );
}

int _toUnixSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  group('groupByTimestamp', () {
    // -----------------------------------------------------------------------
    // Empty input
    // -----------------------------------------------------------------------

    test('returns empty list for empty input', () {
      final result = groupByTimestamp([], 'en_US');
      expect(result, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Today grouping
    // -----------------------------------------------------------------------

    test('groups items from today under "Today" label', () {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
      final todayAfternoon = DateTime(now.year, now.month, now.day, 14, 30);

      final items = [
        _makeItem(id: 'a', sentAt: _toUnixSeconds(todayMorning)),
        _makeItem(id: 'b', sentAt: _toUnixSeconds(todayAfternoon)),
      ];

      final result = groupByTimestamp(items, 'en_US');

      expect(result.length, 1);
      expect(result[0].label, 'Today');
      expect(result[0].items.length, 2);
    });

    // -----------------------------------------------------------------------
    // Yesterday grouping
    // -----------------------------------------------------------------------

    test('groups items from yesterday under "Yesterday" label', () {
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final yesterdayMorning = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        10,
        0,
      );

      final items = [
        _makeItem(id: 'a', sentAt: _toUnixSeconds(yesterdayMorning)),
      ];

      final result = groupByTimestamp(items, 'en_US');

      expect(result.length, 1);
      expect(result[0].label, 'Yesterday');
    });

    // -----------------------------------------------------------------------
    // This week grouping (day name)
    // -----------------------------------------------------------------------

    test('groups items from this week under day name', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Find a day earlier this week (not today, not yesterday)
      // weekday: 1=Mon, 7=Sun. We need at least 3 days into the week.
      if (today.weekday >= 4) {
        // We can test with a day 3 days ago (still this week if today is Thu+)
        final threeDaysAgo = today.subtract(const Duration(days: 3));
        final item = _makeItem(
          id: 'a',
          sentAt: _toUnixSeconds(
            DateTime(
              threeDaysAgo.year,
              threeDaysAgo.month,
              threeDaysAgo.day,
              12,
            ),
          ),
        );

        final result = groupByTimestamp([item], 'en_US');

        expect(result.length, 1);
        // Should be a day name (not "Today", not "Yesterday", not a date)
        expect(result[0].label, isNot('Today'));
        expect(result[0].label, isNot('Yesterday'));
        // Day names are capitalized single words
        expect(result[0].label[0], result[0].label[0].toUpperCase());
      }
    });

    // -----------------------------------------------------------------------
    // Older items (localized date)
    // -----------------------------------------------------------------------

    test('groups older items under localized date', () {
      // Use a date from 2 weeks ago
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final item = _makeItem(id: 'a', sentAt: _toUnixSeconds(twoWeeksAgo));

      final result = groupByTimestamp([item], 'en_US');

      expect(result.length, 1);
      expect(result[0].label, isNot('Today'));
      expect(result[0].label, isNot('Yesterday'));
      // Should contain a comma (localized date format like "Jan 15, 2025")
      expect(result[0].label.contains(','), true);
    });

    // -----------------------------------------------------------------------
    // Multiple groups sorted newest-first
    // -----------------------------------------------------------------------

    test('groups are sorted newest-first', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoWeeksAgo = today.subtract(const Duration(days: 14));

      final items = [
        _makeItem(id: 'old', sentAt: _toUnixSeconds(twoWeeksAgo)),
        _makeItem(id: 'today', sentAt: _toUnixSeconds(today)),
        _makeItem(id: 'yesterday', sentAt: _toUnixSeconds(yesterday)),
      ];

      final result = groupByTimestamp(items, 'en_US');

      expect(result.length, 3);
      expect(result[0].label, 'Today');
      expect(result[1].label, 'Yesterday');
      // Third group is the older date
    });

    // -----------------------------------------------------------------------
    // Items within groups sorted newest-first
    // -----------------------------------------------------------------------

    test('items within a group are sorted newest-first', () {
      final now = DateTime.now();
      final todayEarly = DateTime(now.year, now.month, now.day, 8, 0);
      final todayLate = DateTime(now.year, now.month, now.day, 18, 0);
      final todayMid = DateTime(now.year, now.month, now.day, 12, 0);

      final items = [
        _makeItem(id: 'early', sentAt: _toUnixSeconds(todayEarly)),
        _makeItem(id: 'late', sentAt: _toUnixSeconds(todayLate)),
        _makeItem(id: 'mid', sentAt: _toUnixSeconds(todayMid)),
      ];

      final result = groupByTimestamp(items, 'en_US');

      expect(result.length, 1);
      expect(result[0].items[0].id, 'late');
      expect(result[0].items[1].id, 'mid');
      expect(result[0].items[2].id, 'early');
    });

    // -----------------------------------------------------------------------
    // No items lost or duplicated
    // -----------------------------------------------------------------------

    test('no items are lost or duplicated during grouping', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastWeek = today.subtract(const Duration(days: 10));

      final items = [
        _makeItem(id: 'a', sentAt: _toUnixSeconds(today)),
        _makeItem(id: 'b', sentAt: _toUnixSeconds(today)),
        _makeItem(id: 'c', sentAt: _toUnixSeconds(yesterday)),
        _makeItem(id: 'd', sentAt: _toUnixSeconds(lastWeek)),
        _makeItem(id: 'e', sentAt: _toUnixSeconds(lastWeek)),
      ];

      final result = groupByTimestamp(items, 'en_US');

      // Total items across all groups should equal input
      final totalItems = result.fold<int>(
        0,
        (sum, group) => sum + group.items.length,
      );
      expect(totalItems, items.length);

      // All IDs should be present
      final allIds = result.expand((g) => g.items).map((i) => i.id).toSet();
      expect(allIds, {'a', 'b', 'c', 'd', 'e'});
    });

    // -----------------------------------------------------------------------
    // Locale handling
    // -----------------------------------------------------------------------

    test('works with different locale', () {
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final item = _makeItem(id: 'a', sentAt: _toUnixSeconds(twoWeeksAgo));

      // Should not throw with a different locale
      final result = groupByTimestamp([item], 'de_DE');
      expect(result.length, 1);
      expect(result[0].items.length, 1);
    });

    // -----------------------------------------------------------------------
    // Single item
    // -----------------------------------------------------------------------

    test('handles single item correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final items = [_makeItem(id: 'solo', sentAt: _toUnixSeconds(today))];

      final result = groupByTimestamp(items, 'en_US');

      expect(result.length, 1);
      expect(result[0].label, 'Today');
      expect(result[0].items.length, 1);
      expect(result[0].items[0].id, 'solo');
    });
  });

  group('getRelativeTime', () {
    // getRelativeTime does not produce relative strings ("3h ago"); it returns
    // the time of day for today, 'Yesterday', a weekday name within the week,
    // and dd/MM/yyyy beyond that. These tests previously asserted a relative
    // format that the function has never implemented, so all three failed on
    // every run.
    //
    // Timestamps are anchored to midday rather than derived by subtracting
    // from DateTime.now(): subtracting hours crosses midnight when the suite
    // runs in the small hours, which would silently move a case into the
    // 'Yesterday' branch.

    test('returns the time of day for a timestamp earlier today', () {
      final now = DateTime.now();
      final middayToday = DateTime(now.year, now.month, now.day, 12);

      final result = getRelativeTime(
        middayToday.millisecondsSinceEpoch ~/ 1000,
        'en_US',
      );

      expect(result, DateFormat.jm('en_US').format(middayToday));
    });

    test("returns 'Yesterday' for a timestamp on the previous day", () {
      final now = DateTime.now();
      final middayYesterday = DateTime(
        now.year,
        now.month,
        now.day,
        12,
      ).subtract(const Duration(days: 1));

      final result = getRelativeTime(
        middayYesterday.millisecondsSinceEpoch ~/ 1000,
        'en_US',
      );

      expect(result, 'Yesterday');
    });

    test('returns the weekday name for a timestamp earlier this week', () {
      final now = DateTime.now();
      final threeDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
        12,
      ).subtract(const Duration(days: 3));

      final result = getRelativeTime(
        threeDaysAgo.millisecondsSinceEpoch ~/ 1000,
        'en_US',
      );

      expect(result, DateFormat.EEEE('en_US').format(threeDaysAgo));
    });

    test('returns a full date for a timestamp older than a week', () {
      final now = DateTime.now();
      final tenDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
        12,
      ).subtract(const Duration(days: 10));

      final result = getRelativeTime(
        tenDaysAgo.millisecondsSinceEpoch ~/ 1000,
        'en_US',
      );

      expect(result, DateFormat('dd/MM/yyyy').format(tenDaysAgo));
    });
  });
}
