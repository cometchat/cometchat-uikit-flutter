/// Behaviour pins for [VideoPlayer] — the full-screen player the video bubble
/// pushes when a video is tapped.
///
/// Every path here runs against [FakeVideoPlayerPlatform], so the assertions
/// are about the calls the widget actually makes to the player
/// (`create` / `play` / `pause` / `dispose`) and the chrome it paints around
/// them, not about a real decoder.
///
///   flutter test test/shared_ui/bubbles/media/video_player_test.dart
library;

import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The Kit's own `VideoPlayer` shadows the package's, so the package widget is
// reached through a prefix.
import 'package:video_player/video_player.dart' as vp;

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

  /// Pushes the player onto a route of its own so `Navigator.pop` has
  /// something to pop, and settles the async `initializeVideo()`.
  ///
  /// `pumpAndSettle` is unusable here: the not-yet-initialized state paints a
  /// [CircularProgressIndicator], which never stops animating.
  Future<void> pumpPlayer(WidgetTester tester, Widget player) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => player)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // Route transition, then the fake's `initialized` event (a microtask
    // after `initializeVideo()` subscribes).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  /// Taps the video surface itself.
  ///
  /// The play/pause circle is centred over the video, so `tap(...)` on the
  /// surface would hit the circle instead — aim at its top-left corner.
  Future<void> tapSurface(WidgetTester tester) async {
    final rect = tester.getRect(find.byType(vp.VideoPlayer));
    await tester.tapAt(Offset(rect.left + 6, rect.top + 6));
    await tester.pump();
  }

  /// Lets the overlay's 3s auto-hide timer fire so no timer outlives the test.
  Future<void> drainOverlayTimer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
  }

  group('opening the media', () {
    testWidgets('a network video is opened at its url and starts playing', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      expect(fake.createdUris, ['https://cdn.invalid/clip.mp4']);
      expect(fake.log, contains('play:1'));
      // Initialized -> the surface replaces the spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(vp.VideoPlayer), findsOneWidget);
      // 640x480 from the fake's `initialized` event.
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        640 / 480,
      );
    });

    testWidgets('playFromFile opens the local copy as a file:// url', (
      tester,
    ) async {
      final path = writeRawFile(tempDir, 'clip.mp4', const [0, 1, 2, 3]);

      await pumpPlayer(tester, VideoPlayer(videoUrl: path, playFromFile: true));

      expect(fake.createdUris, ['file://$path']);
    });

    testWidgets('playFromFile falls back to the plain url when no local copy '
        'exists', (tester) async {
      final missing = '${tempDir.path}/never-written.mp4';

      await pumpPlayer(
        tester,
        VideoPlayer(videoUrl: missing, playFromFile: true),
      );

      expect(fake.createdUris, [missing]);
    });

    testWidgets('a player that cannot be created leaves the spinner up and '
        'never plays', (tester) async {
      fake.failCreate = true;

      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/broken.mp4'),
      );

      expect(fake.log.where((c) => c.startsWith('play:')), isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(vp.VideoPlayer), findsNothing);
    });

    testWidgets('media that opens without a duration stays on the spinner', (
      tester,
    ) async {
      fake.initializeWithoutDuration = true;

      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/nodur.mp4'),
      );

      // The widget calls `play()`, but a controller whose media reported no
      // duration is not `isInitialized`, so the call never reaches the
      // platform and the surface is never built.
      expect(fake.createdUris, ['https://cdn.invalid/nodur.mp4']);
      expect(fake.log.where((c) => c.startsWith('play:')), isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(vp.VideoPlayer), findsNothing);
    });

    testWidgets('a url that is not a valid Uri crashes the first build', (
      tester,
    ) async {
      // FINDING: `_controller` is a `late` field assigned inside the try in
      // `initializeVideo()`. `Uri.parse` on a malformed url throws *before*
      // the assignment, the catch only logs, and the very next `build()`
      // reads the unassigned `late` field — so a bad url takes down the
      // route with a LateInitializationError instead of showing the
      // spinner/placeholder the catch clearly intends. `dispose()` reads the
      // same field, so tearing the route down throws a second time.
      // Mounted directly rather than pushed: the build throws, so there must
      // be no route transition left half-run when the tree is torn down.
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayer(videoUrl: 'https://cdn.invalid:notaport/clip.mp4'),
        ),
      );

      expect(tester.takeException(), isA<Error>());
      expect(fake.createdUris, isEmpty);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isA<Error>());
    });
  });

  group('transport controls', () {
    testWidgets('the play/pause circle pauses a playing video, then resumes '
        'it', (tester) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      // Auto-play already ran; the circle shows "pause".
      expect(tester.widget<Icon>(find.byIcon(Icons.pause)).icon, Icons.pause);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(fake.log, contains('pause:1'));

      // The circle only survives the first tap through `_isOverlayVisible`,
      // so re-open the overlay to reach it again.
      await tapSurface(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(fake.log.where((c) => c == 'play:1').length, 2);
      await drainOverlayTimer(tester);
    });

    testWidgets('after the first tap the circle hides until the overlay is '
        'summoned', (tester) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(find.byType(CircleAvatar), findsNothing);

      await tapSurface(tester);
      expect(find.byType(CircleAvatar), findsOneWidget);
      await drainOverlayTimer(tester);
    });
  });

  group('the scrub overlay', () {
    testWidgets('tapping the surface reveals the clock and scrubber, and it '
        'auto-hides after three seconds', (tester) async {
      fake.duration = const Duration(minutes: 1, seconds: 5);

      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      expect(find.byType(vp.VideoProgressIndicator), findsNothing);

      await tapSurface(tester);

      expect(find.byType(vp.VideoProgressIndicator), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget); // position
      expect(find.text('01:05'), findsOneWidget); // duration

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(vp.VideoProgressIndicator), findsNothing);
    });

    testWidgets('a second tap hides the overlay immediately', (tester) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );

      await tapSurface(tester);
      expect(find.byType(vp.VideoProgressIndicator), findsOneWidget);

      await tapSurface(tester);
      expect(find.byType(vp.VideoProgressIndicator), findsNothing);

      // The pending 3s timer from the first tap must not re-hide / re-show.
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(vp.VideoProgressIndicator), findsNothing);
    });

    testWidgets('the clock wraps minutes at the hour rather than counting '
        'total minutes', (tester) async {
      fake.duration = const Duration(hours: 1, minutes: 2, seconds: 3);

      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/long.mp4'),
      );
      await tapSurface(tester);

      expect(find.text('02:03'), findsOneWidget);
      await drainOverlayTimer(tester);
    });

    testWidgets('the scrubber is tinted with the supplied colours', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          playedColor: Color(0xFF00FF00),
          handleColor: Color(0xFF0000FF),
        ),
      );
      await tapSurface(tester);

      final indicator = tester.widget<vp.VideoProgressIndicator>(
        find.byType(vp.VideoProgressIndicator),
      );
      expect(indicator.colors.playedColor, const Color(0xFF00FF00));
      expect(indicator.colors.backgroundColor, const Color(0xFF0000FF));
      expect(indicator.allowScrubbing, isTrue);
      await drainOverlayTimer(tester);
    });
  });

  group('chrome and teardown', () {
    testWidgets('the background and the back arrow honour the passed colours', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(
          videoUrl: 'https://cdn.invalid/clip.mp4',
          fullScreenBackground: Color(0xFF123456),
          backIcon: Color(0xFFABCDEF),
        ),
      );

      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(VideoPlayer),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, const Color(0xFF123456));

      final back = tester.widget<Image>(
        find.descendant(
          of: find.byType(IconButton),
          matching: find.byType(Image),
        ),
      );
      expect(back.color, const Color(0xFFABCDEF));
    });

    testWidgets('the back arrow pops the route', (tester) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );
      expect(find.byType(VideoPlayer), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('leaving the screen disposes the player', (tester) async {
      await pumpPlayer(
        tester,
        const VideoPlayer(videoUrl: 'https://cdn.invalid/clip.mp4'),
      );
      expect(fake.livePlayerIds, isNotEmpty);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      // `VideoPlayerController.dispose()` is not awaited by the State and its
      // own teardown chain runs off the fake-async clock, so the platform
      // call only lands once real async work is allowed to drain.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(fake.log, contains('dispose:1'));
      expect(fake.livePlayerIds, isEmpty);
    });
  });
}
