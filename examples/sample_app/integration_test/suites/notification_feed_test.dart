import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';

/// Notification feed E2E (E2E-186 → E2E-188) — a screen with no coverage
/// before.
///
/// The sample app exposes it as the fifth bottom tab, 'Notifications'
/// (master_app/lib/screens/home_screen.dart, `_buildNotificationsTab` →
/// `CometChatNotificationFeed(showHeader: false)`).
///
/// What is on screen (chat_uikit/lib/chat_ui/src/notification_feed/widgets/):
///   - filter chips: an always-first 'All' chip plus one per server category,
///     each `Semantics(button, selected, label: '<label> filter[, N unread]')`;
///   - content: 'Loading...' → a list of `FeedItemCard`, or the empty state
///     'Nothing here yet', or the error state 'Something went wrong' + Retry.
///
///   E2E-186  The Notifications tab leaves loading and shows feed items or the
///            real empty state — never the error state
///   E2E-187  The 'All' filter chip is present and is the selected category
///            when the feed opens
///   E2E-188  Tapping a category chip makes it the selected category and
///            deselects 'All'
///
/// No fixture seeds feed items: there is no REST surface for it in the harness,
/// so E2E-186 accepts items OR the empty state (both are correct renderings of
/// real data) and E2E-188 skips visibly when the backend defines no categories.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final feed = find.byType(CometChatNotificationFeed);
  Finder inFeed(Finder f) => find.descendant(of: feed, matching: f);

  // notification_feed_filter_chips.dart `_buildChip`: label '$label filter…'.
  final allChip = find.bySemanticsLabel(RegExp(r'^All filter'));
  final anyChip = find.bySemanticsLabel(RegExp(r' filter(, \d+ unread)?$'));

  /// Launch, open the tab, and wait for the feed to leave its loading state.
  Future<void> openFeed(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    await ScreenReach.goToTab(tester, 'Notifications');
    if (feed.evaluate().isEmpty) {
      fail('The Notifications tab did not show CometChatNotificationFeed.');
    }
    if (!await pumpUntilGone(
      tester,
      inFeed(find.text('Loading...')),
      timeout: const Duration(seconds: 30),
    )) {
      fail('The notification feed never left its "Loading..." state.');
    }
  }

  group('Notification feed', () {
    testWidgets(
      'E2E-186: The Notifications tab shows feed items or the real empty '
      'state',
      (tester) async {
        await openFeed(tester);

        final error = inFeed(find.text('Something went wrong'));
        if (error.evaluate().isNotEmpty) {
          final shown = tester
              .widgetList<Text>(inFeed(find.byType(Text)))
              .map((t) => t.data)
              .toList();
          fail('The notification feed rendered its ERROR state: $shown');
        }
        final items = inFeed(find.byType(FeedItemCard)).evaluate().length;
        final empty = inFeed(find.text('Nothing here yet')).evaluate().length;
        // Exactly one of the two data states — not both, not neither.
        expect(
          (items > 0) != (empty > 0),
          isTrue,
          reason:
              'A settled feed shows EITHER cards OR the empty state; got '
              '$items card(s) and $empty empty-state title(s)',
        );
      },
    );

    testWidgets(
      'E2E-187: The All filter chip is selected when the feed opens',
      (tester) async {
        await openFeed(tester);
        final handle = tester.ensureSemantics();
        try {
          await pumpFor(tester, const Duration(seconds: 1));
          expect(
            allChip,
            findsOneWidget,
            reason: 'The feed should always offer an "All" filter chip',
          );
          expect(
            tester.getSemantics(allChip),
            // `isSemantics` replaces this from Flutter 3.40, but CI's compile
            // gate runs 3.38.x, where only containsSemantics exists.
            // ignore: deprecated_member_use
            containsSemantics(isButton: true, isSelected: true),
            reason: '"All" should be the selected category on open',
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'E2E-188: Tapping a category chip makes it the selected category',
      (tester) async {
        await openFeed(tester);
        final handle = tester.ensureSemantics();
        try {
          await pumpFor(tester, const Duration(seconds: 1));
          final chipCount = anyChip.evaluate().length;
          if (chipCount < 2) {
            markTestSkipped(
              'This CometChat app defines no notification '
              'categories, so there is no chip besides "All" to switch to.',
            );
            return;
          }
          // Index 0 is 'All' (always first in the Row); 1 is the first server
          // category.
          final category = anyChip.at(1);
          final label = tester.getSemantics(category).label;

          await tester.tap(category);
          await pumpFor(tester, const Duration(seconds: 3));

          final same = find.bySemanticsLabel(
            RegExp('^${RegExp.escape(label.split(' filter').first)} filter'),
          );
          expect(
            tester.getSemantics(same.first),
            // `isSemantics` replaces this from Flutter 3.40, but CI's compile
            // gate runs 3.38.x, where only containsSemantics exists.
            // ignore: deprecated_member_use
            containsSemantics(isSelected: true),
            reason: 'The tapped chip ("$label") should become selected',
          );
          expect(
            tester.getSemantics(allChip),
            // `isSemantics` replaces this from Flutter 3.40, but CI's compile
            // gate runs 3.38.x, where only containsSemantics exists.
            // ignore: deprecated_member_use
            containsSemantics(isSelected: false),
            reason: '"All" should be deselected once a category is chosen',
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
