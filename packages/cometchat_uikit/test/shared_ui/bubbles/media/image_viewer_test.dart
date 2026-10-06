/// Behaviour pins for [ImageViewer] — the full-screen viewer the image bubble
/// pushes. It has three sources (local file, cached network image, and the web
/// `Image.network` variant), a loading scrim with a 3-second fallback timer,
/// and a retry affordance on the error state.
///
///   flutter test test/shared_ui/bubbles/media/image_viewer_test.dart
library;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../helpers/fake_path_provider.dart';
import '../../../helpers/media_file_harness.dart';

late Directory _dir;

/// Root the cache manager latches onto. It is a process-wide singleton, so it
/// has to be installed once for the whole file rather than per test.
late Directory _cacheRoot;

Widget _host(Widget child) => MaterialApp(home: child);

Iterable<ImageProvider> _providers(WidgetTester tester) =>
    tester.widgetList<Image>(find.byType(Image)).map((i) => i.image);

String? _fileImagePath(ImageProvider p) {
  if (p is ResizeImage) return _fileImagePath(p.imageProvider);
  if (p is FileImage) return p.file.path;
  return null;
}

bool _hasPlaceholderAsset(WidgetTester tester, {String? asset}) =>
    _providers(tester).any(
      (p) =>
          p is AssetImage &&
          p.assetName == (asset ?? AssetConstants.imagePlaceholder),
    );

/// The loading scrim is the viewer's only full-bleed progress indicator; the
/// error state draws none.
bool _showsLoadingScrim(WidgetTester tester) => find
    .descendant(
      of: find.byType(Stack),
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;

Finder get _retryButton => find.byType(IconButton);

/// Real async work — an image decode, or a cache-manager round trip — only
/// runs outside the fake clock, so the widget has to be stepped forward with
/// alternating `runAsync` / `pump` rounds.
Future<void> settleRealAsync(
  WidgetTester tester, {
  int rounds = 30,
  Duration step = const Duration(milliseconds: 200),
  bool Function()? until,
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(step));
    await tester.pump();
    if (until != null && until()) return;
  }
}

/// A url the cache manager is primed with in `setUpAll`.
const _cachedUrl = 'https://cdn.test/cached.bmp';

void main() {
  setUpAll(() async {
    _cacheRoot = installFakePathProvider(prefix: 'cc_image_viewer');
    installInProcessSqlite();
    // Seeded here rather than inside a test: `setUpAll` runs in the plain
    // async zone, so the cache index database is opened (and this entry
    // written) before any test's fake clock is in the way.
    await DefaultCacheManager().putFile(
      _cachedUrl,
      solidBmp(width: 12, height: 9),
      fileExtension: 'bmp',
    );
  });

  tearDownAll(() {
    if (_cacheRoot.existsSync()) _cacheRoot.deleteSync(recursive: true);
  });

  setUp(() => _dir = createMediaTempDir());
  tearDown(() => disposeMediaTempDir(_dir));

  group('local file', () {
    testWidgets('renders the file itself, with no loading scrim and no '
        'pending fallback timer', (tester) async {
      final path = writeImageFile(_dir, 'shot.bmp');
      await tester.pumpWidget(_host(ImageViewer(imageUrl: path)));
      await tester.pump();

      expect(_providers(tester).map(_fileImagePath), contains(path));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(_showsLoadingScrim(tester), isFalse);
      // No `Future.delayed` was armed: the test would fail on a pending timer
      // if one had been.
    });

    testWidgets('a picture that really decodes reaches the frame builder and '
        'is shown, still with no scrim', (tester) async {
      final path = writeImageFile(_dir, 'shot.bmp', width: 16, height: 12);
      await tester.pumpWidget(_host(ImageViewer(imageUrl: path)));
      await tester.pump();

      // Decoding is real async: without this the frame callback never runs
      // and the viewer only ever holds an unresolved provider.
      await settleRealAsync(tester, rounds: 6);

      expect(_providers(tester).map(_fileImagePath), contains(path));
      expect(_hasPlaceholderAsset(tester), isFalse);
      expect(_showsLoadingScrim(tester), isFalse);
    });
  });

  group('network', () {
    testWidgets('starts behind the loading scrim and clears it after the '
        '3-second fallback', (tester) async {
      await tester.pumpWidget(
        _host(const ImageViewer(imageUrl: 'https://cdn.test/full.png')),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(_showsLoadingScrim(tester), isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(_showsLoadingScrim(tester), isFalse);
    });

    testWidgets('while loading it shows the placeholder asset, not a retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ImageViewer(imageUrl: 'https://cdn.test/full.png')),
      );
      await tester.pump();

      expect(_hasPlaceholderAsset(tester), isTrue);
      expect(_retryButton, findsNothing);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('placeholderImage replaces the asset shown while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ImageViewer(
            imageUrl: 'https://cdn.test/full.png',
            placeholderImage: 'assets/icons/file_unknown.png',
            placeHolderImagePackageName: 'cometchat_chat_uikit',
          ),
        ),
      );
      await tester.pump();

      expect(
        _hasPlaceholderAsset(tester, asset: 'assets/icons/file_unknown.png'),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('network — the fetch actually runs', () {
    // These drive the real `DefaultCacheManager`: the cache index is a real
    // SQLite database in a temp directory (see `fake_path_provider.dart`) and
    // the fetch goes through the test binding's HttpClient, which answers 400
    // — so an uncached url reliably lands on `errorWidget`.

    testWidgets('a url that cannot be fetched falls back to a retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ImageViewer(imageUrl: 'https://cdn.test/missing-1.png')),
      );
      await tester.pump();
      expect(_retryButton, findsNothing);

      await settleRealAsync(
        tester,
        until: () => _retryButton.evaluate().isNotEmpty,
      );
      // The error branch clears `_isLoading` from a post-frame callback.
      await tester.pump();
      await tester.pump();

      expect(_retryButton, findsOneWidget);
      expect(tester.widget<IconButton>(_retryButton).tooltip, isNotEmpty);
      // The error state also tears the scrim down — an image that failed must
      // not sit behind a spinner forever.
      expect(_showsLoadingScrim(tester), isFalse);
      // The button's glyph is the refresh asset, not the placeholder.
      expect(
        _providers(tester).any(
          (p) => p is AssetImage && p.assetName == AssetConstants.refreshIcon,
        ),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 3)); // drain the fallback
    });

    testWidgets('retry re-keys the image so the fetch is attempted again', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ImageViewer(imageUrl: 'https://cdn.test/missing-2.png')),
      );
      await tester.pump();
      await settleRealAsync(
        tester,
        until: () => _retryButton.evaluate().isNotEmpty,
      );
      // Two frames for the post-frame callback that takes the scrim down —
      // while it is up it covers (and swallows taps meant for) the button.
      await tester.pump();
      await tester.pump();
      expect(_retryButton, findsOneWidget);
      expect(_showsLoadingScrim(tester), isFalse);

      final keyBefore = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .key;

      await tester.tap(_retryButton);
      await tester.pump();

      // A fresh key forces `CachedNetworkImage` to rebuild from scratch
      // rather than reuse the failed element.
      final keyAfter = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .key;
      expect(keyAfter, isNot(keyBefore));
      expect(keyAfter, isA<ValueKey<String>>());
      expect(
        (keyAfter! as ValueKey<String>).value,
        startsWith('https://cdn.test/missing-2.png'),
      );

      // The retry arms its own 3s fallback; once it elapses the scrim is down
      // whatever the fetch did.
      await tester.pump(const Duration(seconds: 3));
      expect(_showsLoadingScrim(tester), isFalse);
    });

    testWidgets('an already-cached picture is rendered through imageBuilder, '
        'with no scrim and no retry', (tester) async {
      await tester.pumpWidget(_host(const ImageViewer(imageUrl: _cachedUrl)));
      await tester.pump();

      await settleRealAsync(tester, until: () => !_showsLoadingScrim(tester));

      expect(_retryButton, findsNothing);
      expect(_showsLoadingScrim(tester), isFalse);
      // imageBuilder wraps the resolved provider in a plain contained Image.
      final built = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is! AssetImage);
      expect(built, isNotEmpty);
      expect(built.first.fit, BoxFit.contain);

      await tester.pump(const Duration(seconds: 3)); // drain the fallback
    });
  });

  group('local file that will not decode', () {
    testWidgets('falls back to the placeholder image, tinted for the theme', (
      tester,
    ) async {
      // Real bytes on disk (so `isLocalFileAvailable` is true) that no codec
      // can read — this is the viewer's `errorBuilder` path.
      final path = writeRawFile(_dir, 'corrupt.bmp', const [1, 2, 3, 4, 5]);

      await tester.pumpWidget(_host(ImageViewer(imageUrl: path)));
      await tester.pump();
      await settleRealAsync(tester, until: () => _hasPlaceholderAsset(tester));

      expect(_hasPlaceholderAsset(tester), isTrue);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(_showsLoadingScrim(tester), isFalse);
    });

    testWidgets('a custom placeholder is used for the decode failure too', (
      tester,
    ) async {
      final path = writeRawFile(_dir, 'corrupt2.bmp', const [9, 9, 9]);

      await tester.pumpWidget(
        _host(
          ImageViewer(
            imageUrl: path,
            placeholderImage: 'assets/icons/file_unknown.png',
            placeHolderImagePackageName: 'cometchat_chat_uikit',
          ),
        ),
      );
      await tester.pump();
      await settleRealAsync(
        tester,
        until: () => _hasPlaceholderAsset(
          tester,
          asset: 'assets/icons/file_unknown.png',
        ),
      );

      expect(
        _hasPlaceholderAsset(tester, asset: 'assets/icons/file_unknown.png'),
        isTrue,
      );
    });
  });

  group('zoom', () {
    testWidgets('pinch interaction is accepted and leaves the picture in '
        'place', (tester) async {
      final path = writeImageFile(_dir, 'shot.bmp');
      await tester.pumpWidget(_host(ImageViewer(imageUrl: path)));
      await tester.pump();

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 0.1);
      expect(viewer.maxScale, 4.0);
      expect(viewer.panEnabled, isTrue);

      // FINDING: `_isZoomed` is tracked from these two callbacks but never
      // read by `build`, so a zoom changes no rendered output. These cases
      // pin that: the callbacks must stay crash-free and must not disturb the
      // picture.
      viewer.onInteractionUpdate!(ScaleUpdateDetails(scale: 2.5));
      viewer.onInteractionEnd!(ScaleEndDetails());
      await tester.pump();
      expect(_providers(tester).map(_fileImagePath), contains(path));

      viewer.onInteractionUpdate!(ScaleUpdateDetails(scale: 1.0));
      viewer.onInteractionEnd!(ScaleEndDetails());
      await tester.pump();
      expect(_providers(tester).map(_fileImagePath), contains(path));
    });
  });
}
