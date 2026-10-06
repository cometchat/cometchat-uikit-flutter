/// What [CometChatVideoBubble] does when it is tapped, and what it re-reads
/// when its style or cached theme objects are swapped under it.
///
/// Opening the player is only testable with a `video_player` backend in place
/// (see `fake_video_player_platform.dart`); without one the pushed route
/// throws before it can be inspected.
///
///   flutter test test/shared_ui/bubbles/media/video_bubble_open_test.dart
library;

import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_video_player_platform.dart';
import '../../../helpers/media_file_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fake;
  late Directory tempDir;

  setUp(() {
    fake = installFakeVideoPlayerPlatform();
    tempDir = createMediaTempDir();
  });

  tearDown(() => disposeMediaTempDir(tempDir));

  Future<void> pumpBubble(WidgetTester tester, Widget bubble) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: Center(child: bubble)),
      ),
    );
    await tester.pump();
  }

  /// Settles the pushed route and the fake player's deferred init event.
  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  group('tapping the bubble', () {
    testWidgets('opens the full-screen player on the remote url', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        const CometChatVideoBubble(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      await tester.tap(find.byType(CometChatVideoBubble));
      await settleRoute(tester);

      expect(find.byType(VideoPlayer), findsOneWidget);
      final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(player.videoUrl, 'https://cdn.invalid/clip.mp4');
      expect(player.playFromFile, isFalse);
      expect(fake.createdUris, ['https://cdn.invalid/clip.mp4']);
    });

    testWidgets('prefers a downloaded copy named in the message metadata', (
      tester,
    ) async {
      final path = writeRawFile(tempDir, 'clip.mp4', const [1, 2, 3]);

      await pumpBubble(
        tester,
        CometChatVideoBubble(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          metadata: <String, dynamic>{'localPath': path},
        ),
      );

      await tester.tap(find.byType(CometChatVideoBubble));
      await settleRoute(tester);

      final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(player.videoUrl, path);
      expect(player.playFromFile, isTrue);
      expect(fake.createdUris, ['file://$path']);
    });

    testWidgets('a metadata path that is not on disk falls back to the url', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        CometChatVideoBubble(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          metadata: <String, dynamic>{
            'localPath': '${tempDir.path}/never-written.mp4',
          },
        ),
      );

      await tester.tap(find.byType(CometChatVideoBubble));
      await settleRoute(tester);

      final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(player.videoUrl, 'https://cdn.invalid/clip.mp4');
      expect(player.playFromFile, isFalse);
    });

    testWidgets('a bubble with no url opens nothing', (tester) async {
      await pumpBubble(tester, const CometChatVideoBubble());

      await tester.tap(find.byType(CometChatVideoBubble));
      await settleRoute(tester);

      expect(find.byType(VideoPlayer), findsNothing);
      expect(fake.createdUris, isEmpty);
    });

    testWidgets('onClick replaces the built-in navigation entirely', (
      tester,
    ) async {
      var clicked = false;
      await pumpBubble(
        tester,
        CometChatVideoBubble(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          onClick: () => clicked = true,
        ),
      );

      await tester.tap(find.byType(CometChatVideoBubble));
      await settleRoute(tester);

      expect(clicked, isTrue);
      expect(find.byType(VideoPlayer), findsNothing);
    });
  });

  group('rebuilding with new theme inputs', () {
    BoxDecoration frameDecoration(WidgetTester tester) =>
        tester
                .widgetList<Container>(
                  find.descendant(
                    of: find.byType(CometChatVideoBubble),
                    matching: find.byType(Container),
                  ),
                )
                .first
                .decoration!
            as BoxDecoration;

    testWidgets('a new style is re-resolved on the spot', (tester) async {
      Future<void> pumpWithStyle(CometChatVideoBubbleStyle style) => pumpBubble(
        tester,
        CometChatVideoBubble(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          style: style,
        ),
      );

      await pumpWithStyle(
        const CometChatVideoBubbleStyle(backgroundColor: Color(0xFF111111)),
      );
      expect(frameDecoration(tester).color, const Color(0xFF111111));

      await pumpWithStyle(
        const CometChatVideoBubbleStyle(backgroundColor: Color(0xFF222222)),
      );
      expect(frameDecoration(tester).color, const Color(0xFF222222));
    });

    testWidgets('a new colour palette and spacing replace the cached ones', (
      tester,
    ) async {
      Future<void> pumpWith(CometChatColorPalette palette, double radius) =>
          pumpBubble(
            tester,
            CometChatVideoBubble(
              videoUrl: 'https://cdn.invalid/clip.mp4',
              colorPalette: palette,
              spacing: CometChatSpacing(radius3: radius),
            ),
          );

      await pumpWith(
        CometChatColorPalette(background3: const Color(0xFF333333)),
        4,
      );
      expect(frameDecoration(tester).color, const Color(0xFF333333));
      expect(frameDecoration(tester).borderRadius, BorderRadius.circular(4));

      await pumpWith(
        CometChatColorPalette(background3: const Color(0xFF444444)),
        18,
      );
      expect(frameDecoration(tester).color, const Color(0xFF444444));
      expect(frameDecoration(tester).borderRadius, BorderRadius.circular(18));
    });
  });
}
