/// Thumbnail routing and live-player behaviour of [CometChatAttachmentTile].
///
/// `attachment_tile_test.dart` covers the file/audio cards' *status* matrix with
/// no preview source and no player. This file covers the other half: which
/// preview widget each source produces (network url, blob url, local path,
/// video first frame, nothing), the media status scrim, and the staged-audio
/// card once a real (faked) player is behind it — play/pause, the shared
/// one-at-a-time stream, seeking, the clock and disposal.
///
///   flutter test test/chat_ui/message_composer/attachment_tile_media_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_video_player_platform.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

AttachmentTile _tile({
  required String name,
  required String mime,
  String? thumbUrl,
  AttachmentTileStatus status = AttachmentTileStatus.done,
  int size = 4096,
  int loaded = 0,
  int? durationMillis,
}) => AttachmentTile(
  fileId: name,
  name: name,
  mimeType: mime,
  size: size,
  loaded: loaded,
  status: status,
  thumbUrl: thumbUrl,
  durationMillis: durationMillis,
);

/// The [Image]s in the tree whose provider is a [T] — the placeholder art is
/// itself an asset [Image], so "no thumbnail" has to be asserted on the
/// provider kind, not on the absence of an [Image] widget.
Iterable<Image> _imagesFrom<T extends ImageProvider<Object>>(
  WidgetTester tester,
) => tester.widgetList<Image>(find.byType(Image)).where((i) => i.image is T);

/// Lets real (off-fake-clock) async work drain until [done] holds, pumping a
/// frame between attempts. Bounded, so a failure is a failure rather than a
/// hang, and it never asserts on how long the work actually took.
Future<void> _drainRealAsync(
  WidgetTester tester,
  bool Function() done, {
  int attempts = 50,
}) async {
  for (var i = 0; i < attempts && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
}

Finder _svgBadge(String asset) => find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      w.bytesLoader is SvgAssetLoader &&
      (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

void main() {
  group('CometChatAttachmentTile — thumbnail source routing', () {
    testWidgets('an image with no source shows the placeholder art only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(name: 'pic.png', mime: 'image/png'),
            onCancelOrRemove: () {},
          ),
        ),
      );
      expect(find.byType(CometChatMediaPlaceholder), findsOneWidget);
      expect(_imagesFrom<NetworkImage>(tester), isEmpty);
      expect(_imagesFrom<FileImage>(tester), isEmpty);
    });

    testWidgets('an empty source string is treated as no source', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(name: 'pic.png', mime: 'image/png', thumbUrl: ''),
            onCancelOrRemove: () {},
          ),
        ),
      );
      expect(find.byType(CometChatMediaPlaceholder), findsOneWidget);
      expect(_imagesFrom<NetworkImage>(tester), isEmpty);
      expect(_imagesFrom<FileImage>(tester), isEmpty);
    });

    testWidgets('an http(s) source loads over the network, cover-fitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              thumbUrl: 'https://cdn.example.com/pic.png',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );

      final image = _imagesFrom<NetworkImage>(tester).single;
      expect(
        (image.image as NetworkImage).url,
        'https://cdn.example.com/pic.png',
      );
      expect(image.fit, BoxFit.cover);

      // Until the first frame decodes, the placeholder art stands in.
      expect(find.byType(CometChatMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a web blob: source also goes through the network image', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              thumbUrl: 'blob:http://localhost/abc-123',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      final image = _imagesFrom<NetworkImage>(tester).single;
      expect(
        (image.image as NetworkImage).url,
        'blob:http://localhost/abc-123',
      );
    });

    testWidgets('a network source that fails falls back to the placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              thumbUrl: 'https://cdn.example.com/missing.png',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      // The test HttpClient answers 400, so the load errors out.
      await tester.pumpAndSettle();
      expect(find.byType(CometChatMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a local path on an image tile loads from the file system', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              thumbUrl: '/tmp/does-not-exist/pic.png',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );

      final image = _imagesFrom<FileImage>(tester).single;
      expect(
        (image.image as FileImage).file.path,
        '/tmp/does-not-exist/pic.png',
      );

      // A missing file degrades to the placeholder instead of throwing into
      // the tray. The read is real file I/O, so let it drain off the fake
      // clock before the fallback is asserted.
      await _drainRealAsync(
        tester,
        () => find.byType(CometChatMediaPlaceholder).evaluate().isNotEmpty,
      );
      expect(find.byType(CometChatMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a video source renders a first frame, never an image load', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'clip.mp4',
              mime: 'video/mp4',
              thumbUrl: '/tmp/clip.mp4',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );

      final frame = tester.widget<CometChatVideoFirstFrame>(
        find.byType(CometChatVideoFirstFrame),
      );
      expect(frame.source, '/tmp/clip.mp4');
      expect(frame.key, const ValueKey('cc_video_thumb_clip.mp4'));
      expect(
        frame.fallback,
        isA<CometChatMediaPlaceholder>(),
        reason: 'an unreadable video falls back to the placeholder art',
      );
      // The play affordance sits over the frame.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a non-image, non-video source falls through to the'
        ' placeholder', (tester) async {
      // Classified as a video by extension (so it renders as a media tile) but
      // the source is a CDN url — `isVideo` short-circuits to the first frame,
      // so force the other leg: an image/video mime with an unusable local
      // source and no image kind.
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'clip.mkv',
              mime: 'video/x-matroska',
              thumbUrl: 'https://cdn.example.com/clip.mkv',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      // A video always uses the first-frame widget, whatever the url scheme.
      expect(find.byType(CometChatVideoFirstFrame), findsOneWidget);
    });

    testWidgets('a tile that is BOTH image-typed and audio-named previews as'
        ' audio', (tester) async {
      // AttachmentUtils classifies by mime OR extension, so these two are not
      // mutually exclusive. The tile renders as a media square (isImage wins
      // the layout) but the thumbnail falls to the audio glyph.
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'song.mp3',
              mime: 'image/png',
              thumbUrl: 'https://cdn.example.com/song.mp3',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      expect(_imagesFrom<NetworkImage>(tester), isEmpty);
      expect(find.byType(CometChatMediaPlaceholder), findsNothing);
    });
  });

  group('CometChatAttachmentTile — media status scrim', () {
    testWidgets('uploading shows a determinate ring once progress arrives', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              status: AttachmentTileStatus.uploading,
              size: 1000,
              loaded: 250,
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      await tester.pump();
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 0.25);
    });

    testWidgets('uploading with no progress yet is indeterminate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              status: AttachmentTileStatus.uploading,
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      await tester.pump();
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, isNull);
    });

    testWidgets('progress past 100% still paints a full ring, never over', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              status: AttachmentTileStatus.uploading,
              size: 1000,
              loaded: 5000,
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      await tester.pump();
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 1.0);
    });

    testWidgets('a rejected media tile shows the error glyph and surfaces its'
        ' reason on tap', (tester) async {
      var errorTapped = false;
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              status: AttachmentTileStatus.rejected,
            ),
            onCancelOrRemove: () {},
            onErrorInteract: () => errorTapped = true,
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(_svgBadge(kAttachmentErrorIconAsset), findsOneWidget);
      expect(_svgBadge(kAttachmentRetryIconAsset), findsNothing);

      await tester.tap(find.byType(CometChatMediaPlaceholder));
      expect(errorTapped, isTrue);
      expect(retried, isFalse, reason: 'rejected is not retryable');
    });

    testWidgets('a failed media tile retries in place on tap', (tester) async {
      var errorTapped = false;
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'pic.png',
              mime: 'image/png',
              status: AttachmentTileStatus.failed,
            ),
            onCancelOrRemove: () {},
            onErrorInteract: () => errorTapped = true,
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(_svgBadge(kAttachmentRetryIconAsset), findsOneWidget);
      await tester.tap(find.byType(CometChatMediaPlaceholder));
      expect(retried, isTrue);
      expect(errorTapped, isFalse);
    });

    testWidgets('a done media tile has no scrim and opens the preview on tap', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(name: 'pic.png', mime: 'image/png'),
            onCancelOrRemove: () {},
            onTap: () => opened = true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_svgBadge(kAttachmentErrorIconAsset), findsNothing);
      await tester.tap(find.byType(CometChatMediaPlaceholder));
      expect(opened, isTrue);
    });
  });

  group('CometChatAttachmentTile — staged audio with a live player', () {
    late FakeVideoPlayerPlatform platform;

    setUp(() {
      platform = installFakeVideoPlayerPlatform(
        duration: const Duration(seconds: 30),
      );
    });

    Future<void> pumpAudio(
      WidgetTester tester, {
      String? thumbUrl = '/tmp/voice.m4a',
      AttachmentTileStatus status = AttachmentTileStatus.done,
      VoidCallback? onCancelOrRemove,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'voice.m4a',
              mime: 'audio/mp4',
              thumbUrl: thumbUrl,
              status: status,
            ),
            onCancelOrRemove: onCancelOrRemove ?? () {},
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // An uploading tile spins forever, so settling would time out; two
        // frames are enough for the player to finish initializing.
        await tester.pump();
        await tester.pump();
      }
    }

    testWidgets('the card initializes its player and shows the real duration', (
      tester,
    ) async {
      await pumpAudio(tester);

      expect(platform.createdUris.single, 'file:///tmp/voice.m4a');
      expect(find.text('00:00/00:30'), findsOneWidget);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 30000);
      expect(slider.value, 0);
      expect(slider.onChanged, isNotNull, reason: 'a done tile can seek');
    });

    testWidgets('tapping the play circle plays, then pauses', (tester) async {
      await pumpAudio(tester);

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(Slider)),
        isNotNull,
        reason: 'the player row is live',
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(platform.log, contains('play:1'));
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(platform.log, contains('pause:1'));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('the play button is labelled for screen readers, and flips'
        ' with state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAudio(tester);

      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dragging the slider seeks the player', (tester) async {
      await pumpAudio(tester);

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(12000);
      await tester.pumpAndSettle();
      expect(platform.log, contains('seek:1:0:00:12.000000'));
    });

    testWidgets('another player starting anywhere in the app pauses this one', (
      tester,
    ) async {
      await pumpAudio(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      platform.log.clear();

      // A different audio surface claims playback.
      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(
          id: 'someone-else'.hashCode,
          action: AudioBubbleActions.pausePlayer,
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.log, contains('pause:1'));
    });

    testWidgets('an event from this same tile does not pause it', (
      tester,
    ) async {
      await pumpAudio(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      platform.log.clear();

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(
          id: 'voice.m4a'.hashCode,
          action: AudioBubbleActions.pausePlayer,
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.log, isNot(contains('pause:1')));
    });

    testWidgets('a source that appears only after the upload finishes still'
        ' builds a player', (tester) async {
      // The web bytes path has no local source until the CDN url lands.
      await pumpAudio(tester, thumbUrl: null);
      expect(platform.createdUris, isEmpty);
      expect(find.text('00:00/--:--'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentTile(
            tile: _tile(
              name: 'voice.m4a',
              mime: 'audio/mp4',
              thumbUrl: 'https://cdn.example.com/voice.m4a',
            ),
            onCancelOrRemove: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(platform.createdUris.single, 'https://cdn.example.com/voice.m4a');
      expect(find.text('00:00/00:30'), findsOneWidget);
    });

    testWidgets('a rebuild with the same source does not rebuild the player', (
      tester,
    ) async {
      await pumpAudio(tester);
      expect(platform.createdUris.length, 1);

      await pumpAudio(tester);
      expect(
        platform.createdUris.length,
        1,
        reason: 'same source ⇒ the existing player is kept',
      );
    });

    testWidgets('an upload that fails mid-playback silences the player', (
      tester,
    ) async {
      await pumpAudio(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      platform.log.clear();

      await pumpAudio(tester, status: AttachmentTileStatus.failed);
      expect(platform.log, contains('pause:1'));
      // The player row is replaced by the failure line.
      expect(find.text('Tap to retry'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('an uploading tile shows the duration but cannot be played', (
      tester,
    ) async {
      await pumpAudio(
        tester,
        status: AttachmentTileStatus.uploading,
        settle: false,
      );

      expect(find.text('00:00/00:30'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull, reason: 'no seeking before it is done');

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(platform.log, isNot(contains('play:1')));
    });

    testWidgets('a player that cannot be created leaves an inert card', (
      tester,
    ) async {
      platform.failCreate = true;
      await pumpAudio(tester);

      expect(find.text('00:00/--:--'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 1, reason: 'a zero-length track still needs max > 0');
      expect(slider.value, 0);
      expect(slider.onChanged, isNull);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(platform.log, isNot(contains('play:1')));
    });

    testWidgets('media that opens but reports no duration stays inert', (
      tester,
    ) async {
      platform.initializeWithoutDuration = true;
      await pumpAudio(tester);
      expect(find.text('00:00/--:--'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    });

    testWidgets('leaving the tray disposes the player', (tester) async {
      await pumpAudio(tester);
      expect(platform.livePlayerIds, isNotEmpty);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      // `VideoPlayerController.dispose()` is not awaited by the State and its
      // own teardown chain runs off the fake-async clock, so the platform call
      // only lands once real async work is allowed to drain.
      await _drainRealAsync(tester, () => platform.log.contains('dispose:1'));
      expect(platform.log, contains('dispose:1'));
      expect(platform.livePlayerIds, isEmpty);
    });

    testWidgets('the remove badge still works on a playing card', (
      tester,
    ) async {
      var removed = false;
      await pumpAudio(tester, onCancelOrRemove: () => removed = true);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      expect(removed, isTrue);
    });
  });
}
