// ENG-41484 (D-322, D-323), BEH-MEDIA-18: the full-screen viewer, the grid's
// hero-aspect check and the legacy image / video bubbles use the copy saved on
// the phone — the attachment's `localPath`, else the SDK's cache — before the
// link, and an expired thumbnail falls back to the full image or the video's
// first frame. With offline off every one of them behaves as before.
//
// Network fetches are counted through `debugNetworkImageHttpClientProvider`:
// every `NetworkImage` load asks it for a client, and it throws so the load
// fails like an offline link.

// The legacy bubbles are deprecated in favour of the multi-attachment ones but
// still render the `enableMultipleAttachments: false` path.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_video_player_platform.dart';
import '../../helpers/media_file_harness.dart';

const _imageUrl = 'https://cdn.example/photo.png?sig=1';
const _thumbUrl = 'https://cdn.example/photo_thumb.png?sig=1';
const _videoUrl = 'https://cdn.example/clip.mp4?sig=1';
const _videoThumbUrl = 'https://cdn.example/clip_thumb.png?sig=1';

Attachment _image({String url = _imageUrl, String? localPath}) => Attachment(
  url,
  'photo.png',
  'png',
  'image/png',
  2048,
  localPath: localPath,
);

Attachment _video({String url = _videoUrl, String? localPath}) =>
    Attachment(url, 'clip.mp4', 'mp4', 'video/mp4', 4096, localPath: localPath);

String? _filePath(ImageProvider p) {
  if (p is ResizeImage) return _filePath(p.imageProvider);
  if (p is FileImage) return p.file.path;
  return null;
}

bool _showsFile(WidgetTester tester, String path) => tester
    .widgetList<Image>(find.byType(Image))
    .any((i) => _filePath(i.image) == path);

bool _showsNetwork(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .any((i) => i.image is NetworkImage);

Finder _frameFrom(String source) => find.byWidgetPredicate(
  (w) => w is CometChatVideoFirstFrame && w.source == source,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

/// Lets real file reads and image decodes finish, then pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hub = OfflineHub.instance;
  final lookups = <String>[];
  late Directory dir;
  late FakeVideoPlayerPlatform videos;
  late List<MethodCall> channelCalls;
  var networkFetches = 0;
  String? cached;

  const channel = MethodChannel('cometchat_chat_uikit');

  setUp(() {
    dir = createMediaTempDir();
    videos = installFakeVideoPlayerPlatform();
    hub.debugReset();
    OfflineMedia.debugClearMemo();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('me');
    lookups.clear();
    cached = null;
    networkFetches = 0;
    OfflineMedia.debugCachedMediaPath = (m) async {
      lookups.add((m as MediaMessage).attachment!.fileUrl);
      return cached;
    };
    painting.debugNetworkImageHttpClientProvider = () {
      networkFetches++;
      throw const SocketException('offline');
    };
    channelCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          channelCalls.add(call);
          if (call.method == 'saveFileWithPicker') return '/saved/here';
          return null;
        });
  });

  tearDown(() {
    painting.debugNetworkImageHttpClientProvider = null;
    CometChat.debugSetOfflineEnabledOverride(null);
    OfflineMedia.debugIsUsable = null;
    OfflineMedia.debugCachedMediaPath = null;
    OfflineMedia.debugClearMemo();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    disposeMediaTempDir(dir);
  });

  /// Ends a test: the painting debug hook must be unset before the binding's
  /// invariant check, which runs ahead of `tearDown`.
  void unhook() => painting.debugNetworkImageHttpClientProvider = null;

  Future<void> pumpViewer(WidgetTester tester, List<Attachment> items) async {
    await tester.pumpWidget(_host(CometChatMediaViewer(mediaItems: items)));
    await _settle(tester);
  }

  String availableWhenOnline(WidgetTester tester) => Translations.of(
    tester.element(find.byType(CometChatMediaViewer)),
  ).mediaAvailableWhenOnline;

  group('viewer image page', () {
    testWidgets('a received image already saved shows from disk, no fetch', (
      tester,
    ) async {
      final path = writeImageFile(dir, 'saved.bmp');
      await pumpViewer(tester, [_image(localPath: path)]);

      expect(_showsFile(tester, path), isTrue);
      expect(_showsNetwork(tester), isFalse);
      expect(networkFetches, 0);
      expect(lookups, isEmpty);
      unhook();
    });

    testWidgets('a copy only the SDK cache knows is found and shown', (
      tester,
    ) async {
      cached = writeImageFile(dir, 'sdk.bmp');
      await pumpViewer(tester, [_image()]);

      expect(lookups, [_imageUrl]);
      expect(_showsFile(tester, cached!), isTrue);
      unhook();
    });

    testWidgets('never downloaded, offline: "Available when online"', (
      tester,
    ) async {
      await pumpViewer(tester, [_image()]);

      expect(find.text(availableWhenOnline(tester)), findsOneWidget);
      final t = Translations.of(
        tester.element(find.byType(CometChatMediaViewer)),
      );
      expect(find.text(t.noPreviewAvailable), findsNothing);
      unhook();
    });

    testWidgets('an own image still queued (empty link, local path only)', (
      tester,
    ) async {
      final path = writeImageFile(dir, 'queued.bmp');
      await pumpViewer(tester, [_image(url: '', localPath: path)]);

      expect(_showsFile(tester, path), isTrue);
      expect(networkFetches, 0);
      unhook();
    });

    testWidgets('a composer-tray file renders from its path with no lookup', (
      tester,
    ) async {
      final path = writeImageFile(dir, 'tray.bmp');
      await pumpViewer(tester, [_image(url: path)]);

      expect(_showsFile(tester, path), isTrue);
      expect(lookups, isEmpty);
      unhook();
    });

    testWidgets('offline off: the link as before, no lookup, "No preview" on '
        'failure', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final path = writeImageFile(dir, 'saved.bmp');
      await pumpViewer(tester, [_image(localPath: path)]);

      expect(_showsFile(tester, path), isFalse);
      expect(networkFetches, greaterThan(0));
      expect(lookups, isEmpty);
      final t = Translations.of(
        tester.element(find.byType(CometChatMediaViewer)),
      );
      expect(find.text(t.noPreviewAvailable), findsOneWidget);
      expect(find.text(t.mediaAvailableWhenOnline), findsNothing);
      unhook();
    });
  });

  group('viewer video page', () {
    testWidgets('a saved video plays from the file', (tester) async {
      final path = writeRawFile(dir, 'clip.mp4', const [1, 2, 3]);
      await pumpViewer(tester, [_video(localPath: path)]);

      expect(videos.createdUris, ['file://$path']);
      expect(lookups, isEmpty);
      unhook();
    });

    testWidgets('a copy only the SDK cache knows plays from the file', (
      tester,
    ) async {
      cached = writeRawFile(dir, 'sdk.mp4', const [1, 2, 3]);
      await pumpViewer(tester, [_video()]);

      expect(lookups, [_videoUrl]);
      expect(videos.createdUris, ['file://$cached']);
      unhook();
    });

    testWidgets(
      'never downloaded and the link fails: "Available when online"',
      (tester) async {
        videos.failCreate = true;
        await pumpViewer(tester, [_video()]);

        expect(videos.createdUris, [_videoUrl]);
        expect(find.text(availableWhenOnline(tester)), findsOneWidget);
        unhook();
      },
    );

    testWidgets('offline off: the link plays, no lookup', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final path = writeRawFile(dir, 'clip.mp4', const [1, 2, 3]);
      await pumpViewer(tester, [_video(localPath: path)]);

      expect(videos.createdUris, [_videoUrl]);
      expect(lookups, isEmpty);
      unhook();
    });
  });

  group('viewer download', () {
    Future<Map<Object?, Object?>> download(
      WidgetTester tester,
      Attachment a,
    ) async {
      await pumpViewer(tester, [a]);
      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await _settle(tester);
      final call = channelCalls.singleWhere(
        (c) => c.method == 'saveFileWithPicker',
      );
      return call.arguments as Map<Object?, Object?>;
    }

    testWidgets('a saved file is saved from the local copy', (tester) async {
      final path = writeImageFile(dir, 'saved.bmp');
      final args = await download(tester, _image(localPath: path));

      expect(args['url'], _imageUrl);
      expect(args['path'], path);
      unhook();
    });

    testWidgets('a queued own file (no link) is saved from the local copy', (
      tester,
    ) async {
      final path = writeImageFile(dir, 'queued.bmp');
      final args = await download(tester, _image(url: '', localPath: path));

      expect(args['url'], '');
      expect(args['path'], path);
      unhook();
    });

    testWidgets('offline off: the link only, and no link is not downloadable', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final path = writeImageFile(dir, 'saved.bmp');
      final args = await download(tester, _image(localPath: path));
      expect(args['url'], _imageUrl);
      expect(args.containsKey('path'), isFalse);

      channelCalls.clear();
      await pumpViewer(tester, [_image(url: '', localPath: path)]);
      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await _settle(tester);
      expect(
        channelCalls.where((c) => c.method == 'saveFileWithPicker'),
        isEmpty,
      );
      unhook();
    });
  });

  group('grid hero aspect check', () {
    Widget triple(List<Attachment> media) => _host(
      Scaffold(
        body: Center(child: CometChatMediaGrid(media: media, width: 240)),
      ),
    );

    Finder heroLeftRow() => find.descendant(
      of: find.byType(CometChatMediaGrid),
      matching: find.byType(Row),
    );

    testWidgets('a saved hero is measured from the file, with no fetch', (
      tester,
    ) async {
      // A portrait hero (6×8) lays out on the left.
      final hero = writeImageFile(dir, 'hero.bmp', width: 6, height: 8);
      final other = writeImageFile(dir, 'other.bmp');
      await tester.pumpWidget(
        triple([
          _image(localPath: hero),
          _image(url: '$_imageUrl&2', localPath: other),
          _image(url: '$_imageUrl&3', localPath: other),
        ]),
      );
      await _settle(tester);

      expect(networkFetches, 0);
      expect(heroLeftRow(), findsWidgets);
      unhook();
    });

    testWidgets('offline off: the hero is fetched from the link', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final hero = writeImageFile(dir, 'hero.bmp', width: 6, height: 8);
      await tester.pumpWidget(
        triple([
          _image(localPath: hero),
          _image(url: '$_imageUrl&2'),
          _image(url: '$_imageUrl&3'),
        ]),
      );
      await _settle(tester);

      // The cells and the hero probe, all from the link.
      expect(networkFetches, greaterThan(0));
      expect(lookups, isEmpty);
      unhook();
    });
  });

  group('legacy image bubble', () {
    // Plain pumps: the network branch uses CachedNetworkImage, whose cache
    // manager would reach for path_provider under real async.
    Future<void> pumpBubble(WidgetTester tester, Widget bubble) async {
      await tester.pumpWidget(_host(Scaffold(body: Center(child: bubble))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the link is not fetched while the lookup runs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Scaffold(
            body: Center(child: CometChatImageBubble(imageUrl: _imageUrl)),
          ),
        ),
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump();
      // Not saved: the link, once the lookup has answered.
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      unhook();
    });

    testWidgets('the SDK-cached copy is used instead of the link', (
      tester,
    ) async {
      cached = writeImageFile(dir, 'sdk.bmp');
      await pumpBubble(
        tester,
        const CometChatImageBubble(
          imageUrl: _imageUrl,
          thumbnailUrl: _thumbUrl,
        ),
      );

      expect(lookups, [_imageUrl]);
      expect(_showsFile(tester, cached!), isTrue);
      expect(find.byType(CachedNetworkImage), findsNothing);
      unhook();
    });

    testWidgets('the default tap opens the viewer on the saved copy', (
      tester,
    ) async {
      cached = writeImageFile(dir, 'sdk.bmp');
      await pumpBubble(tester, const CometChatImageBubble(imageUrl: _imageUrl));
      await tester.tap(find.byType(CometChatImageBubble));
      await _settle(tester);

      expect(
        tester.widget<ImageViewer>(find.byType(ImageViewer)).imageUrl,
        cached,
      );
      unhook();
    });

    testWidgets('a failed thumbnail falls back to the full image', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        const CometChatImageBubble(
          imageUrl: _imageUrl,
          thumbnailUrl: _thumbUrl,
        ),
      );
      final thumb = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(thumb.imageUrl, _thumbUrl);

      final fallback = thumb.errorWidget!(
        tester.element(find.byType(CachedNetworkImage)),
        _thumbUrl,
        Exception('expired'),
      );
      expect(fallback, isA<CachedNetworkImage>());
      expect((fallback as CachedNetworkImage).imageUrl, _imageUrl);

      // The full image failing too ends on the placeholder.
      final last = fallback.errorWidget!(
        tester.element(find.byType(CachedNetworkImage)),
        _imageUrl,
        Exception('offline'),
      );
      expect(last, isNot(isA<CachedNetworkImage>()));
      unhook();
    });

    testWidgets('offline off: no lookup, and a failed thumbnail goes to the '
        'placeholder', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      cached = writeImageFile(dir, 'sdk.bmp');
      await pumpBubble(
        tester,
        const CometChatImageBubble(
          imageUrl: _imageUrl,
          thumbnailUrl: _thumbUrl,
        ),
      );

      expect(lookups, isEmpty);
      expect(_showsFile(tester, cached!), isFalse);
      final thumb = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      final fallback = thumb.errorWidget!(
        tester.element(find.byType(CachedNetworkImage)),
        _thumbUrl,
        Exception('expired'),
      );
      expect(fallback, isNot(isA<CachedNetworkImage>()));
      unhook();
    });

    // The message list builds this bubble with a UniqueKey, so every list
    // rebuild makes a fresh state.
    Future<void> rebuild(WidgetTester tester) => tester.pumpWidget(
      _host(
        Scaffold(
          body: Center(
            child: CometChatImageBubble(key: UniqueKey(), imageUrl: _imageUrl),
          ),
        ),
      ),
    );

    // The bubble's lookup spinner: one not drawn by an image still loading
    // (a file decoding or a link fetching draws its own).
    Finder lookupSpinner() => find.byElementPredicate((e) {
      if (e.widget is! CircularProgressIndicator) return false;
      var inImage = false;
      e.visitAncestorElements((a) {
        final w = a.widget;
        inImage = w is Image || w is CachedNetworkImage;
        return !inImage;
      });
      return !inImage;
    });

    testWidgets(
      'list rebuilds reuse the first answer: no spinner, one lookup',
      (tester) async {
        cached = writeImageFile(dir, 'sdk.bmp');
        await rebuild(tester);
        await tester.pump();
        await tester.pump();
        expect(lookups, [_imageUrl]);
        expect(_showsFile(tester, cached!), isTrue);

        for (var i = 0; i < 5; i++) {
          await rebuild(tester);
          expect(lookupSpinner(), findsNothing);
          expect(_showsFile(tester, cached!), isTrue);
          await tester.pump();
        }
        expect(lookups, [_imageUrl]);
        unhook();
      },
    );

    testWidgets('a "not saved" answer is reused, then dropped on a download', (
      tester,
    ) async {
      await rebuild(tester);
      await tester.pump();
      await rebuild(tester);
      expect(lookupSpinner(), findsNothing);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(lookups, [_imageUrl]);

      // A download landed: the bubble asks again and remembers the copy.
      cached = writeImageFile(dir, 'sdk.bmp');
      hub.debugMediaDownloaded(null, 'att-1', cached!);
      await tester.pump();
      await tester.pump();
      expect(lookups, [_imageUrl, _imageUrl]);
      await rebuild(tester);
      expect(lookupSpinner(), findsNothing);
      expect(_showsFile(tester, cached!), isTrue);
      expect(lookups, hasLength(2));
      unhook();
    });

    testWidgets('logout clears the remembered answers', (tester) async {
      cached = writeImageFile(dir, 'sdk.bmp');
      await rebuild(tester);
      await tester.pump();
      expect(OfflineMedia.debugMemoLength, 1);

      hub.debugLogout();
      await tester.pump();
      expect(OfflineMedia.debugMemoLength, 0);
      await rebuild(tester);
      expect(lookupSpinner(), findsOneWidget);
      expect(_showsFile(tester, cached!), isFalse);
      await tester.pump();
      expect(lookups, [_imageUrl, _imageUrl]);
      unhook();
    });

    testWidgets('a cache reset clears the remembered answers', (tester) async {
      await rebuild(tester);
      await tester.pump();
      expect(OfflineMedia.debugMemoLength, 1);

      hub.debugCacheReset(OfflineCacheResetReason.values.first, 0);
      await tester.pump();
      expect(OfflineMedia.debugMemoLength, 0);
      unhook();
    });

    test(
      'a session end during the first-ever lookup leaves the memo empty',
      () async {
        // The memo has never watched the hub (setUp dropped its watch).
        final answer = Completer<String?>();
        OfflineMedia.debugCachedMediaPath = (m) {
          lookups.add((m as MediaMessage).attachment!.fileUrl);
          return answer.future;
        };
        final lookup = OfflineMedia.resolveUrlRemembered(_imageUrl);
        await Future<void>.delayed(Duration.zero);
        expect(lookups, [_imageUrl]);

        hub.debugLoginSuccess('them'); // user switch: SessionEnded
        await Future<void>.delayed(Duration.zero);
        answer.complete(writeImageFile(dir, 'old-user.bmp'));
        await lookup;

        expect(OfflineMedia.debugMemoLength, 0);
        expect(OfflineMedia.rememberedUrl(_imageUrl), (false, null));
      },
    );

    testWidgets('offline off: nothing is remembered', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      await rebuild(tester);
      await tester.pump();
      expect(OfflineMedia.rememberedUrl(_imageUrl), (false, null));
      expect(OfflineMedia.debugMemoLength, 0);
      expect(lookups, isEmpty);
      unhook();
    });
  });

  group('web download source', () {
    test('the saved copy when there is one, else the link', () {
      expect(OfflineMedia.webDownloadSource(_imageUrl, 'blob:x/1'), 'blob:x/1');
      expect(OfflineMedia.webDownloadSource(_imageUrl, null), _imageUrl);
      expect(OfflineMedia.webDownloadSource(_imageUrl, ''), _imageUrl);
      expect(OfflineMedia.webDownloadSource('', 'blob:x/1'), 'blob:x/1');
    });
  });

  group('legacy video bubble', () {
    Future<void> pumpBubble(WidgetTester tester, Widget bubble) async {
      await tester.pumpWidget(_host(Scaffold(body: Center(child: bubble))));
      await _settle(tester);
      await _settle(tester);
    }

    testWidgets('a failed poster falls back to the saved copy\'s first frame', (
      tester,
    ) async {
      cached = writeRawFile(dir, 'sdk.mp4', const [1, 2, 3]);
      await pumpBubble(
        tester,
        const CometChatVideoBubble(
          videoUrl: _videoUrl,
          thumbnailUrl: _videoThumbUrl,
        ),
      );

      expect(lookups, [_videoUrl]);
      expect(_frameFrom(cached!), findsOneWidget);
      unhook();
    });

    testWidgets('a failed poster with no saved copy uses the link\'s frame', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        const CometChatVideoBubble(
          videoUrl: _videoUrl,
          thumbnailUrl: _videoThumbUrl,
        ),
      );

      expect(_frameFrom(_videoUrl), findsOneWidget);
      unhook();
    });

    testWidgets('the tap plays the saved copy from the file', (tester) async {
      cached = writeRawFile(dir, 'sdk.mp4', const [1, 2, 3]);
      await pumpBubble(tester, const CometChatVideoBubble(videoUrl: _videoUrl));
      await tester.tap(find.byType(CometChatVideoBubble));
      await _settle(tester);

      final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(player.videoUrl, cached);
      expect(player.playFromFile, isTrue);
      unhook();
    });

    testWidgets('offline off: no lookup and a failed poster stays blank', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      cached = writeRawFile(dir, 'sdk.mp4', const [1, 2, 3]);
      await pumpBubble(
        tester,
        const CometChatVideoBubble(
          videoUrl: _videoUrl,
          thumbnailUrl: _videoThumbUrl,
        ),
      );

      expect(lookups, isEmpty);
      expect(find.byType(CometChatVideoFirstFrame), findsNothing);
      unhook();
    });
  });
}
