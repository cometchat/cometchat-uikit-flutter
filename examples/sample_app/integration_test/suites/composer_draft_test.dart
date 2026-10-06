import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/composer_depth_helper.dart';
import '../sdk_user_b/group_actions.dart';

/// Composer drafts — E2E suite (iOS parity, STRICT).
///
///   E2E-112  A draft typed in the chat with User B does not leak into another
///            conversation: that conversation's composer opens empty.
///   E2E-113  A draft typed in the chat with User B is DISCARDED when the chat
///            is left and re-entered: the composer opens empty.
///
/// PRODUCT DECISION PINNED BY E2E-113 — read before "fixing" it.
/// Neither the UI Kit nor the sample app keeps per-conversation drafts: there
/// is no draft store anywhere under `chat_uikit/lib` or `master_app/lib`
/// (a case-insensitive search for "draft" finds nothing), the composer owns its
/// text controllers and disposes them with the route, and
/// `messages_screen.dart` never passes `CometChatMessageComposer.text`. So
/// unsent text is lost on navigation — same as iOS, which raised it as a
/// product question. E2E-113 pins today's behaviour strictly; if drafts are
/// added on purpose, this is the test to flip (expect the draft to come back),
/// and E2E-112 then becomes the guard that matters.
///
/// (Rotation keeping the text — E2E-065 — lives in configuration_test.dart and
/// is a different thing: same route, same controller.)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final otherGuid = 'e2e_draft_$stamp';
  final otherName = 'E2E Draft $stamp';

  setUpAll(() async {
    // A second conversation that is guaranteed to exist and that User A can
    // open: a throwaway group created as User A.
    await UserBGroup.createGroupAsAdmin(groupId: otherGuid, name: otherName);
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    await UserBGroup.deleteGroup(groupId: otherGuid);
    await CleanupHelper.fullReset();
  });

  setUp(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation();
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  /// Open the chat with B and leave an unsent draft in its composer.
  Future<String> typeDraftInChatWithB(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    await ComposerDepthHelper.openChatWithB(tester);
    final draft = 'unsent ${ComposerDepthHelper.token('draft')}';
    await ComposerDepthHelper.focusComposer(tester);
    await ComposerDepthHelper.typeAppend(tester, draft);
    expect(
      ComposerDepthHelper.composerText(tester),
      draft,
      reason: 'Precondition: the draft must be in the composer',
    );
    return draft;
  }

  group('Composer drafts', () {
    testWidgets('E2E-112: Draft does not leak into another chat', (
      tester,
    ) async {
      await typeDraftInChatWithB(tester);

      // Phone layout: back to the list first. Two-pane layout has no back
      // button and the Groups tab is reachable directly.
      await ComposerDepthHelper.leaveChat(tester);
      await ComposerDepthHelper.openGroupByName(tester, otherName);

      expect(
        ComposerDepthHelper.composerText(tester),
        isEmpty,
        reason:
            'A different conversation must open with an EMPTY composer — '
            'the draft typed for User B must not leak into it',
      );
    });

    testWidgets('E2E-113: Draft after leaving and re-entering the same chat', (
      tester,
    ) async {
      await typeDraftInChatWithB(tester);

      final wentBack = await ComposerDepthHelper.leaveChat(tester);
      if (!wentBack) {
        // Two-pane layout: "leaving" means selecting another conversation.
        await ComposerDepthHelper.openGroupByName(tester, otherName);
      }
      await ComposerDepthHelper.openChatWithB(tester);

      // Pinned current behaviour: no per-conversation draft persistence.
      expect(
        ComposerDepthHelper.composerText(tester),
        isEmpty,
        reason:
            'The Kit keeps no drafts: re-entering the chat must show an '
            'empty composer (see the PRODUCT DECISION note in this file)',
      );
    });
  });
}
