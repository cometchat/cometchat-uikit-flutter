import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/assertion_helper.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/message_helper.dart';
import '../helpers_v2/navigation_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/search_polls_media_helper.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Media bubbles, full-screen viewer, stickers and voice recorder (iOS
/// parity), STRICT.
///
/// `media_messages_test.dart` / `group_media_messages_test.dart` check that the
/// attachment OPTIONS exist and fall back to "composer still present" when a
/// bubble is not found. Nothing here falls back: each test names the real
/// widget type and fails without it.
///
///   E2E-151  A seeded image renders an image bubble
///            → `CometChatImagesBubble` for that message id, holding an
///              `Image` of the seeded URL.
///   E2E-152  A seeded video renders a video bubble with a play affordance
///            → `CometChatVideosBubble` for that id containing the
///              `Icons.play_arrow_rounded` badge.
///   E2E-153  A seeded file renders a file bubble showing its file name
///            → `CometChatFilesBubble` for that id containing the name.
///   E2E-154  Tapping the image opens the full-screen viewer
///            → `CometChatMediaViewer` opens on the tapped attachment.
///   E2E-155  The viewer can be dismissed and returns to the chat
///            → viewer gone, the same image bubble is back on screen.
///   E2E-156  Pinch zoom in the viewer changes the scale
///            → the `InteractiveViewer`'s transform scale goes from 1.0 to >1.
///   E2E-157  The sticker keyboard opens from the composer and shows stickers
///            → `CometChatStickerKeyboard` with ≥1 sticker image in its grid.
///   E2E-158  Tapping a sticker sends a sticker bubble
///            → a new `CometChatStickerBubble` with that sticker URL, AND the
///              server holds an `extension_sticker` message from A with it.
///   E2E-159  The voice recorder opens, shows the recording UI, and
///            "Delete recording" returns the composer to rest
///            → `CometChatInlineAudioRecorder` replaces the text input, then
///              is gone and the input + mic button are back.
///
/// Where things come from (chat_uikit/lib):
///   * message_template_utils.dart — with `enableMultipleAttachments` (default
///     true, not overridden by master_app) image / video / file messages render
///     as `CometChatImagesBubble` / `CometChatVideosBubble` /
///     `CometChatFilesBubble`, each exposing its `message`.
///   * cometchat_media_grid.dart — every cell is a `GestureDetector` whose tap
///     runs `CometChatMediaViewer.open`; a video cell stacks a
///     `CircleAvatar > Icon(Icons.play_arrow_rounded)` badge over its poster.
///   * cometchat_files_bubble.dart — each card shows `Text(a.fileName)`.
///   * cometchat_media_viewer.dart — a `Scaffold` whose AppBar has a close
///     `IconButton(tooltip: Translations.close = "Close")` and title
///     `n / total`; an image page is
///     `InteractiveViewer(minScale: 1, maxScale: 4)`. There is NO double-tap
///     handler, so zoom is driven with a two-pointer pinch and read from the
///     `Transform` that InteractiveViewer builds around its child.
///   * sticker_auxiliary_button.dart / sticker_keyboard.dart — the composer's
///     `StickerAuxiliaryButton` shows `CometChatStickerKeyboard`, whose grid
///     cells are `Image.network(sticker.stickerUrl)`; a tap sends a custom
///     message of type `extension_sticker` with `customData.sticker_url`,
///     rendered by `CometChatStickerBubble`. The Kit does not gate the button
///     on the extension, so availability is probed with
///     `CometChat.isExtensionEnabled('stickers')` and E2E-157/158 call
///     `markTestSkipped` when it is off.
///   * message_composer_auxiliary_buttons.dart — mic `IconButton(tooltip:
///     Translations.recordVoiceMessage = "Record voice message")`;
///     cometchat_message_composer.dart swaps the input for
///     `CometChatInlineAudioRecorder` while `state.isRecordingMode`; the
///     recorder's controls are `Semantics(label: 'Delete recording')` and
///     `Semantics(label: 'Send audio message')`, plus an MM:SS `Text`.
///     1TO1-104 only checks (tolerantly) that some recorder control appears.
///
/// Seeding: each media test has User B send its own media by URL over REST
/// BEFORE the app launches, so the bubble comes from history, not from a
/// realtime race. Every URL / file name carries a per-run marker.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final run = DateTime.now().millisecondsSinceEpoch;
  var seedCounter = 0;

  setUpAll(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation(text: 'SeedForMediaViewer');
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDownAll(() async {
    // Seeded media, stickers and any voice note live in the shared A↔B
    // conversation; clear them.
    await CleanupHelper.fullReset();
  });

  // ─── Seeding ───────────────────────────────────────────────────────────────

  /// A unique image URL per call (the query string defeats URL-equality
  /// collisions with media left by other suites).
  String uniqueImageUrl() =>
      'https://data-us.cometchat.io/assets/images/avatars/ironman.png'
      '?e2e=$run-${seedCounter++}';

  Future<({int id, String url})> seedImage() async {
    final url = uniqueImageUrl();
    final id = await UserBMessaging.sendMediaToA(
      type: 'image',
      url: url,
      mimeType: 'image/png',
      name: 'viewerimage$run.png',
      extension: 'png',
    );
    return (id: id, url: url);
  }

  Future<void> openChat(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    await NavigationHelper.openUserBConversation(tester);
    AssertionHelper.expectOnMessagesScreen();
  }

  // ─── Finders ───────────────────────────────────────────────────────────────

  Finder imagesBubble(int messageId) => find.byWidgetPredicate(
    (w) => w is CometChatImagesBubble && w.message.id == messageId,
    skipOffstage: false,
  );

  Finder videosBubble(int messageId) => find.byWidgetPredicate(
    (w) => w is CometChatVideosBubble && w.message.id == messageId,
    skipOffstage: false,
  );

  Finder filesBubble(int messageId) => find.byWidgetPredicate(
    (w) => w is CometChatFilesBubble && w.message.id == messageId,
    skipOffstage: false,
  );

  final viewer = find.byType(CometChatMediaViewer);

  /// Seed an image, open the chat, tap its grid cell, wait for the viewer.
  Future<({int id, String url})> openSeededImageInViewer(
    WidgetTester tester,
  ) async {
    final seeded = await seedImage();
    await openChat(tester);

    final bubble = imagesBubble(seeded.id);
    final rendered = await pumpUntilFound(
      tester,
      bubble,
      timeout: const Duration(seconds: 25),
    );
    expect(
      rendered,
      isTrue,
      reason: 'precondition: the seeded image bubble must render',
    );

    // cometchat_media_grid.dart — the cell GestureDetector fills the grid.
    final grid = find.descendant(
      of: bubble,
      matching: find.byType(CometChatMediaGrid),
    );
    expect(grid, findsOneWidget);
    await tester.ensureVisible(grid);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(grid);

    final opened = await pumpUntilFound(
      tester,
      viewer,
      timeout: const Duration(seconds: 10),
    );
    expect(
      opened,
      isTrue,
      reason: 'tapping the image bubble must open CometChatMediaViewer',
    );
    await pumpFor(tester, const Duration(seconds: 1)); // route transition
    return seeded;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  group('Media: bubbles', () {
    testWidgets('E2E-151: A seeded image renders an image bubble', (
      tester,
    ) async {
      final seeded = await seedImage();
      await openChat(tester);

      final bubble = imagesBubble(seeded.id);
      final rendered = await pumpUntilFound(
        tester,
        bubble,
        timeout: const Duration(seconds: 25),
      );
      expect(
        rendered,
        isTrue,
        reason:
            'image message #${seeded.id} must render as a '
            'CometChatImagesBubble',
      );

      // cometchat_media_grid.dart — an image cell is Image.network(a.fileUrl).
      final picture = find.descendant(
        of: bubble,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is NetworkImage &&
              (w.image as NetworkImage).url == seeded.url,
          skipOffstage: false,
        ),
      );
      expect(
        picture,
        findsOneWidget,
        reason: 'the image bubble must display the seeded image URL',
      );
    });

    testWidgets(
      'E2E-152: A seeded video renders a video bubble with a play affordance',
      (tester) async {
        final id = await UserBMessaging.sendMediaToA(
          type: 'video',
          // Small, stable H.264 clip (the Flutter API-docs sample video).
          url:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/'
              'bee.mp4?e2e=$run',
          mimeType: 'video/mp4',
          name: 'viewervideo$run.mp4',
          extension: 'mp4',
        );
        await openChat(tester);

        final bubble = videosBubble(id);
        final rendered = await pumpUntilFound(
          tester,
          bubble,
          timeout: const Duration(seconds: 25),
        );
        expect(
          rendered,
          isTrue,
          reason: 'video message #$id must render as a CometChatVideosBubble',
        );

        // cometchat_media_grid.dart `_VideoCellState.build` — the play badge.
        final playBadge = find.descendant(
          of: bubble,
          matching: find.byIcon(Icons.play_arrow_rounded, skipOffstage: false),
        );
        expect(
          playBadge,
          findsOneWidget,
          reason: 'the video bubble must show a play affordance',
        );
      },
    );

    testWidgets('E2E-153: A seeded file renders a file bubble with its name', (
      tester,
    ) async {
      final fileName = 'paritydoc$run.pdf';
      final id = await UserBMessaging.sendFileToA(name: fileName);
      await openChat(tester);

      final bubble = filesBubble(id);
      final rendered = await pumpUntilFound(
        tester,
        bubble,
        timeout: const Duration(seconds: 25),
      );
      expect(
        rendered,
        isTrue,
        reason: 'file message #$id must render as a CometChatFilesBubble',
      );

      // cometchat_files_bubble.dart — the card title is Text(a.fileName).
      expect(
        find.descendant(
          of: bubble,
          matching: find.text(fileName, skipOffstage: false),
        ),
        findsOneWidget,
        reason: 'the file bubble must show the file name "$fileName"',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('Media: full-screen viewer', () {
    testWidgets('E2E-154: Tapping the image opens the full-screen viewer', (
      tester,
    ) async {
      final seeded = await openSeededImageInViewer(tester);

      final shown = tester.widget<CometChatMediaViewer>(viewer);
      expect(
        shown.mediaItems[shown.startIndex].fileUrl,
        seeded.url,
        reason: 'the viewer must open on the attachment that was tapped',
      );
    });

    testWidgets(
      'E2E-155: The viewer can be dismissed and returns to the chat',
      (tester) async {
        final seeded = await openSeededImageInViewer(tester);

        // cometchat_media_viewer.dart — AppBar leading
        // IconButton(tooltip: Translations.close, icon: Icons.close).
        final close = find.descendant(
          of: viewer,
          matching: find.byTooltip('Close'),
        );
        expect(
          close,
          findsOneWidget,
          reason: 'the viewer must offer a Close button',
        );
        await tester.tap(close);

        final gone = await pumpUntilGone(
          tester,
          viewer,
          timeout: const Duration(seconds: 8),
        );
        expect(gone, isTrue, reason: 'Close must dismiss the viewer');
        expect(
          imagesBubble(seeded.id).hitTestable(),
          findsOneWidget,
          reason:
              'dismissing the viewer must return to the chat with the '
              'image bubble on screen',
        );
      },
    );

    testWidgets('E2E-156: Pinch zoom in the viewer changes the scale', (
      tester,
    ) async {
      await openSeededImageInViewer(tester);

      // `_ImagePage.build` → InteractiveViewer(minScale: 1, maxScale: 4).
      // InteractiveViewer owns its controller, so the scale is read from the
      // Transform it builds around its child.
      final zoomable = find.descendant(
        of: viewer,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        zoomable,
        findsOneWidget,
        reason: 'an image page must be an InteractiveViewer',
      );

      double currentScale() {
        final transform = find.descendant(
          of: zoomable,
          matching: find.byType(Transform),
        );
        return tester
            .widget<Transform>(transform.first)
            .transform
            .getMaxScaleOnAxis();
      }

      expect(
        currentScale(),
        closeTo(1.0, 0.001),
        reason: 'precondition: the viewer opens un-zoomed',
      );

      // Vertical pinch-out: the page sits in a horizontal PageView, so moving
      // the fingers along Y keeps its drag recognizer out of the arena.
      final center = tester.getCenter(zoomable);
      final finger1 = await tester.startGesture(
        center - const Offset(0, 30),
        pointer: 71,
      );
      final finger2 = await tester.startGesture(
        center + const Offset(0, 30),
        pointer: 72,
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var step = 1; step <= 10; step++) {
        await finger1.moveTo(center - Offset(0, 30.0 + step * 14));
        await finger2.moveTo(center + Offset(0, 30.0 + step * 14));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finger1.up();
      await finger2.up();
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(
        currentScale(),
        greaterThan(1.2),
        reason: 'a pinch-out must zoom the image in',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('Composer tools: stickers', () {
    const skipReason = 'stickers extension disabled on the test app';
    bool? stickersEnabled;

    final keyboard = find.byType(CometChatStickerKeyboard);

    // sticker_keyboard.dart — sticker cells are Image.network inside the
    // GridView (the pack selector's images sit in a Row, not the grid).
    Finder stickerCells() => find.descendant(
      of: find.descendant(of: keyboard, matching: find.byType(GridView)),
      matching: find.byWidgetPredicate(
        (w) => w is Image && w.image is NetworkImage,
      ),
    );

    /// Open B's chat and the sticker keyboard. Returns false after
    /// `markTestSkipped` — callers must `return`.
    Future<bool> openStickerKeyboardOrSkip(WidgetTester tester) async {
      await AppLauncher.launchAndLogin(tester);
      stickersEnabled ??= await SdkProbe.isExtensionEnabled(
        ExtensionConstants.stickers,
      );
      if (stickersEnabled != true) {
        markTestSkipped(skipReason);
        return false;
      }
      await NavigationHelper.openUserBConversation(tester);
      AssertionHelper.expectOnMessagesScreen();

      // sticker_auxiliary_button.dart — SizedBox > IconButton(tooltip:
      // Translations.sticker).
      final stickerButton = find.descendant(
        of: find.byType(StickerAuxiliaryButton),
        matching: find.byType(IconButton),
      );
      expect(
        stickerButton,
        findsOneWidget,
        reason: 'the composer must show the sticker button',
      );
      await tester.tap(stickerButton);

      final opened = await pumpUntilFound(
        tester,
        keyboard,
        timeout: const Duration(seconds: 8),
      );
      expect(
        opened,
        isTrue,
        reason: 'the sticker button must open CometChatStickerKeyboard',
      );
      return true;
    }

    testWidgets(
      'E2E-157: The sticker keyboard opens from the composer and shows '
      'stickers',
      (tester) async {
        if (!await openStickerKeyboardOrSkip(tester)) return;

        final loaded = await pumpUntilFound(
          tester,
          stickerCells(),
          timeout: const Duration(seconds: 20),
        );
        expect(
          loaded,
          isTrue,
          reason:
              'with the stickers extension enabled, the keyboard must '
              'list at least one sticker',
        );
      },
    );

    testWidgets('E2E-158: Tapping a sticker sends a sticker bubble', (
      tester,
    ) async {
      if (!await openStickerKeyboardOrSkip(tester)) return;
      final loaded = await pumpUntilFound(
        tester,
        stickerCells(),
        timeout: const Duration(seconds: 20),
      );
      if (!loaded) fail('precondition: the sticker keyboard listed no sticker');

      final cell = stickerCells().first;
      final stickerUrl = (tester.widget<Image>(cell).image as NetworkImage).url;

      Finder bubblesOfThisSticker() => find.byWidgetPredicate(
        (w) => w is CometChatStickerBubble && w.getStickerUrl() == stickerUrl,
        skipOffstage: false,
      );
      final before = bubblesOfThisSticker().evaluate().length;
      final history = await SdkProbe.latestMessagesWithUserB(limit: 1);
      final lastIdBefore = history.isEmpty ? 0 : history.last.id;

      await tester.tap(cell);

      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end) &&
          bubblesOfThisSticker().evaluate().length <= before) {
        await pumpFor(tester, const Duration(milliseconds: 500));
      }
      expect(
        bubblesOfThisSticker().evaluate().length,
        before + 1,
        reason:
            'tapping a sticker must add exactly one sticker bubble for '
            'that sticker',
      );

      // What actually went out.
      final sent = await SdkProbe.waitForCustomMessageFromA(
        type: ExtensionType.sticker,
        where: (m) =>
            m.id > lastIdBefore && m.customData?['sticker_url'] == stickerUrl,
      );
      expect(
        sent.receiverUid,
        TestCredentials.userBUid,
        reason: 'the sticker message must be addressed to User B',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  group('Composer tools: voice recorder', () {
    testWidgets(
      'E2E-159: The voice recorder opens, shows the recording UI, and '
      'Delete recording returns the composer to rest',
      (tester) async {
        if (kIsWeb) {
          // README §1: no audio recording in headless web runs.
          markTestSkipped('voice recording is not available on web test runs');
          return;
        }
        await openChat(tester);

        // message_composer_auxiliary_buttons.dart `_buildVoiceRecordingButton`.
        final mic = find.byTooltip('Record voice message');
        final recorder = find.byType(CometChatInlineAudioRecorder);
        expect(
          mic,
          findsOneWidget,
          reason: 'an empty composer must show the mic button',
        );
        expect(
          recorder,
          findsNothing,
          reason: 'precondition: the recorder is not open yet',
        );

        await tester.tap(mic);
        final opened = await pumpUntilFound(
          tester,
          recorder,
          timeout: const Duration(seconds: 8),
        );
        expect(
          opened,
          isTrue,
          reason: 'the mic button must open CometChatInlineAudioRecorder',
        );

        // The recording UI: delete + send controls and an MM:SS timer, and the
        // text input is swapped out while recording.
        final delete = find.descendant(
          of: recorder,
          matching: KitFinders.semanticsLabel('Delete recording'),
        );
        expect(
          delete,
          findsOneWidget,
          reason: 'the recorder must offer "Delete recording"',
        );
        expect(
          find.descendant(
            of: recorder,
            matching: KitFinders.semanticsLabel('Send audio message'),
          ),
          findsOneWidget,
          reason: 'the recorder must offer "Send audio message"',
        );
        expect(
          find.descendant(
            of: recorder,
            matching: find.byWidgetPredicate(
              (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
            ),
          ),
          findsOneWidget,
          reason: 'the recorder must show an MM:SS duration',
        );
        expect(
          mic,
          findsNothing,
          reason:
              'the mic button belongs to the text input, which the '
              'recorder replaces while recording',
        );

        await tester.tap(delete);
        final closed = await pumpUntilGone(
          tester,
          recorder,
          timeout: const Duration(seconds: 8),
        );
        expect(
          closed,
          isTrue,
          reason: '"Delete recording" must close the recorder',
        );
        expect(
          mic,
          findsOneWidget,
          reason:
              'after deleting, the composer must be back at rest with '
              'its mic button',
        );
        expect(
          MessageHelper.findComposer(),
          findsOneWidget,
          reason: 'after deleting, the text input must be back',
        );
      },
    );
  });
}
