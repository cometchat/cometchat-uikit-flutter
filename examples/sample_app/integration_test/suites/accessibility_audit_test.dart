import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sample_app/screens/create_group_screen.dart';
import 'package:sample_app/screens/group_info_screen.dart';
import 'package:sample_app/screens/threads_screen.dart' show InboxSearchBar;
import 'package:sample_app/screens/user_info_screen.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/accessibility_audit_helper.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/message_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';
import '../sdk_user_b/group_actions.dart';

/// Accessibility audit E2E (E2E-160 → E2E-171) — iOS "AccessibilityAuditTests"
/// parity: every main screen, in the REAL app against the REAL backend, audited
/// at the default text size and again at the largest one.
///
/// Each test navigates to one screen and holds ALL of these true at once
/// (see helpers_v2/accessibility_audit_helper.dart):
///   a. every semantics node with a tap / long-press action has a label,
///      value, hint or tooltip — offenders are listed with their rect and
///      nearest labelled ancestor;
///   b. Flutter's `labeledTapTargetGuideline` and the platform tap-target size
///      guideline (48dp Android / 44pt iOS) pass;
///   c. at text scale 2.0 the screen reports NO layout overflow.
///
///   E2E-160  Login screen is accessible at default and large text
///   E2E-161  Conversations list is accessible at default and large text
///   E2E-162  Users list is accessible at default and large text
///   E2E-163  Groups list is accessible at default and large text
///   E2E-164  Call logs tab is accessible at default and large text
///   E2E-165  One-to-one messages screen (header + list + composer) is
///            accessible at default and large text
///   E2E-166  Group messages screen is accessible at default and large text
///   E2E-167  User info screen is accessible at default and large text
///   E2E-168  Group info screen is accessible at default and large text
///   E2E-169  Search screen is accessible at default and large text
///   E2E-170  Create-group sheet is accessible at default and large text
///   E2E-171  Message long-press options overlay is accessible at default and
///            large text
///
/// These tests are EXPECTED to surface findings — that is what they are for.
/// Do not soften an assertion to get a green run; fix the offender it names.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final groupGuid = 'e2ea11y$stamp';
  final groupName = 'E2E A11y $stamp';
  final groupSeedText = 'A11y group seed $stamp';
  final dmSeedText = 'A11y seed $stamp';

  setUpAll(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation(text: dmSeedText);
    // A-owned group with B inside and one message, so the group appears at
    // the top of the Chats list and its screens have real content to audit.
    await UserBGroup.createGroupAsAdmin(groupId: groupGuid, name: groupName);
    await UserBGroup.addMember(TestCredentials.userBUid, groupId: groupGuid);
    await UserBGroup.sendTextToGroup(groupSeedText, groupId: groupGuid);
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    await UserBGroup.deleteGroup(groupId: groupGuid);
    await CleanupHelper.fullReset();
  });

  /// Launch + login, and refuse to continue anywhere but HomeScreen: an audit
  /// of the wrong screen is worse than no audit.
  Future<void> launchHome(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    if (!await pumpUntilFound(
      tester,
      find.byType(BottomNavigationBar),
      timeout: const Duration(seconds: 20),
    )) {
      fail(
        'The app did not reach HomeScreen after login, so there is no '
        'screen to audit.',
      );
    }
  }

  group('Accessibility audit: default + large text', () {
    testWidgets(
      'E2E-160: Login screen is accessible at default and large text',
      (tester) async {
        await AppLauncher.launchOnly(tester);
        // master_app/lib/screens/login_screen.dart: hintText "Enter the UID".
        if (!await pumpUntilFound(
          tester,
          find.widgetWithText(TextFormField, 'Enter the UID'),
          timeout: const Duration(seconds: 15),
        )) {
          fail(
            'The login form is not on screen (SDK init failed, or a cached '
            'session skipped it).',
          );
        }
        await AccessibilityAudit.expectScreenAccessible(tester, 'Login');
      },
    );

    testWidgets(
      'E2E-161: Conversations list is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.goToTab(tester, 'Chats');
        if (!await pumpUntilFound(
          tester,
          ScreenReach.conversationRowNamed(TestCredentials.userBName),
          timeout: const Duration(seconds: 20),
        )) {
          fail(
            'The seeded conversation never appeared, so the list under audit '
            'would be the empty state rather than real rows.',
          );
        }
        await AccessibilityAudit.expectScreenAccessible(
          tester,
          'Conversations list',
        );
      },
    );

    testWidgets('E2E-162: Users list is accessible at default and large text', (
      tester,
    ) async {
      await launchHome(tester);
      await ScreenReach.goToTab(tester, 'Users');
      // CometChatUsers rows are CometChatListItem.
      if (!await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byType(CometChatUsers),
          matching: find.byType(CometChatListItem),
        ),
        timeout: const Duration(seconds: 20),
      )) {
        fail('The Users list did not load any rows to audit.');
      }
      await AccessibilityAudit.expectScreenAccessible(tester, 'Users list');
    });

    testWidgets(
      'E2E-163: Groups list is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.goToTab(tester, 'Groups');
        if (!await pumpUntilFound(
          tester,
          find.descendant(
            of: find.byType(CometChatGroups),
            matching: find.byType(CometChatListItem),
          ),
          timeout: const Duration(seconds: 20),
        )) {
          fail('The Groups list did not load any rows to audit.');
        }
        await AccessibilityAudit.expectScreenAccessible(tester, 'Groups list');
      },
    );

    testWidgets(
      'E2E-164: Call logs tab is accessible at default and large text',
      (tester) async {
        if (kIsWeb) {
          // home_screen.dart only adds the Calls tab when !kIsWeb.
          markTestSkipped('The sample app has no Calls tab on web.');
          return;
        }
        await launchHome(tester);
        await ScreenReach.goToTab(tester, 'Calls');
        // Whatever the account's history, the tab must settle out of loading
        // into rows, the app's "No call logs yet" empty state, or its error
        // state — all three are real screens a user lands on.
        final settled = await pumpUntilFound(
          tester,
          find.byWidgetPredicate(
            (w) =>
                (w is Text &&
                    (w.data == 'No call logs yet' ||
                        w.data == 'Unable to load call logs')) ||
                w is CometChatListItem,
          ),
          timeout: const Duration(seconds: 20),
        );
        if (!settled) {
          fail('The Calls tab never settled into rows, empty or error state.');
        }
        await AccessibilityAudit.expectScreenAccessible(tester, 'Call logs');
      },
    );

    testWidgets(
      'E2E-165: One-to-one messages screen is accessible at default and '
      'large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        // An outgoing bubble too, so receipts + both alignments are in the tree.
        final own = 'A11y own ${DateTime.now().millisecondsSinceEpoch}';
        await MessageHelper.sendMessage(tester, own);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          find.byType(CometChatMessageList),
          own,
        )) {
          fail(
            'The outgoing message never rendered, so the list under audit is '
            'missing its outgoing bubble.',
          );
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, const Duration(seconds: 1));
        await AccessibilityAudit.expectScreenAccessible(
          tester,
          'One-to-one messages (header + list + composer)',
        );
      },
    );

    testWidgets(
      'E2E-166: Group messages screen is accessible at default and large '
      'text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.openConversationNamed(tester, groupName);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          find.byType(CometChatMessageList),
          groupSeedText,
        )) {
          fail('The seeded group message never rendered.');
        }
        await AccessibilityAudit.expectScreenAccessible(
          tester,
          'Group messages (header + list + composer)',
        );
      },
    );

    testWidgets(
      'E2E-167: User info screen is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        await ScreenReach.chooseHeaderMenuEntry(tester, 'User Info');
        if (!await pumpUntilFound(tester, find.byType(UserInfoScreen))) {
          fail('"User Info" did not open UserInfoScreen.');
        }
        await pumpFor(tester, const Duration(seconds: 2));
        await AccessibilityAudit.expectScreenAccessible(tester, 'User info');
      },
    );

    testWidgets(
      'E2E-168: Group info screen is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.openConversationNamed(tester, groupName);
        await ScreenReach.chooseHeaderMenuEntry(tester, 'Group Info');
        if (!await pumpUntilFound(tester, find.byType(GroupInfoScreen))) {
          fail('"Group Info" did not open GroupInfoScreen.');
        }
        await pumpFor(tester, const Duration(seconds: 2));
        await AccessibilityAudit.expectScreenAccessible(tester, 'Group info');
      },
    );

    testWidgets(
      'E2E-169: Search screen is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.goToTab(tester, 'Chats');
        // home_screen.dart `_buildConversationsTab`: InboxSearchBar → _openSearch
        // pushes CometChatSearch.
        await tester.tap(find.byType(InboxSearchBar));
        if (!await pumpUntilFound(tester, find.byType(CometChatSearch))) {
          fail('Tapping the inbox search bar did not open CometChatSearch.');
        }
        await pumpFor(tester, const Duration(seconds: 2));
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, const Duration(seconds: 1));
        await AccessibilityAudit.expectScreenAccessible(tester, 'Search');
      },
    );

    testWidgets(
      'E2E-170: Create-group sheet is accessible at default and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.goToTab(tester, 'Groups');
        // home_screen.dart `_buildGroupsTab`: FAB(Icons.group_add) →
        // showCreateGroup → CreateGroupScreen in a modal bottom sheet.
        final fab = find.widgetWithIcon(FloatingActionButton, Icons.group_add);
        if (!await pumpUntilFound(tester, fab)) {
          fail('The Groups tab has no create-group button.');
        }
        await tester.tap(fab.first);
        if (!await pumpUntilFound(tester, find.byType(CreateGroupScreen))) {
          fail('The create-group button did not open CreateGroupScreen.');
        }
        await pumpFor(tester, const Duration(seconds: 1));
        await AccessibilityAudit.expectScreenAccessible(
          tester,
          'Create-group sheet',
        );
      },
    );

    testWidgets(
      'E2E-171: Message long-press options overlay is accessible at default '
      'and large text',
      (tester) async {
        await launchHome(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        final own = 'A11y options ${DateTime.now().millisecondsSinceEpoch}';
        await MessageHelper.sendMessage(tester, own);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          find.byType(CometChatMessageList),
          own,
        )) {
          fail('The message to long-press never rendered.');
        }
        // Own message → the fullest option set (reactions tray, Reply, Copy,
        // Edit, Delete, More).
        await ScreenReach.openMessageOptions(tester, own);
        await AccessibilityAudit.expectScreenAccessible(
          tester,
          'Message options overlay',
        );
      },
    );
  });
}
