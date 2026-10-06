/// Behaviour pins for [CometChatImageBubble] — which source the bubble
/// actually renders (local file / thumbnail / full URL / placeholder), when it
/// is tappable, what the default tap opens, and the viewport gate that stops a
/// GIF decoding while it is scrolled out of view.
///
/// Local files are real files on disk (see `media_file_harness.dart`) because
/// the bubble branches on `File(path).existsSync()`; network URLs never
/// resolve here (no platform image cache in a VM test), which is exactly the
/// "failed to resolve" branch several of these cases are about.
///
///   flutter test test/shared_ui/bubbles/media/image_bubble_test.dart
library;

// CometChatImageBubble is deprecated in favour of CometChatImagesBubble but
// still renders the whole `enableMultipleAttachments: false` path.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/media_file_harness.dart';

late Directory _dir;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Iterable<ImageProvider> _providers(WidgetTester tester) =>
    tester.widgetList<Image>(find.byType(Image)).map((i) => i.image);

/// The bubble's placeholder is an [AssetImage] on the kit's own package.
bool _isPlaceholder(ImageProvider p, {String? asset}) =>
    p is AssetImage &&
    p.assetName == (asset ?? AssetConstants.imagePlaceholder) &&
    p.package == UIConstants.packageName;

bool _hasPlaceholder(WidgetTester tester, {String? asset}) =>
    _providers(tester).any((p) => _isPlaceholder(p, asset: asset));

/// The local-file branch wraps a [FileImage] in a [ResizeImage] (cacheWidth /
/// cacheHeight are always passed), so unwrap before reading the path.
String? _fileImagePath(ImageProvider p) {
  if (p is ResizeImage) return _fileImagePath(p.imageProvider);
  if (p is FileImage) return p.file.path;
  return null;
}

Iterable<String> _localPaths(WidgetTester tester) =>
    _providers(tester).map(_fileImagePath).whereType<String>();

String? _networkUrl(WidgetTester tester) {
  final found = find.byType(CachedNetworkImage);
  if (found.evaluate().isEmpty) return null;
  return tester.widget<CachedNetworkImage>(found.first).imageUrl;
}

/// The bubble's own root gesture detector (the one carrying the tap-to-open).
GestureDetector _rootDetector(WidgetTester tester) =>
    tester.widget<GestureDetector>(
      find
          .descendant(
            of: find.byType(CometChatImageBubble),
            matching: find.byType(GestureDetector),
          )
          .first,
    );

void main() {
  setUp(() => _dir = createMediaTempDir());
  tearDown(() => disposeMediaTempDir(_dir));

  group('source resolution', () {
    testWidgets('an available local file wins over the remote URL', (
      tester,
    ) async {
      final path = writeImageFile(_dir, 'local.bmp');
      await tester.pumpWidget(
        _host(
          CometChatImageBubble(
            imageUrl: 'https://cdn.test/remote.png',
            metadata: {'localPath': path},
          ),
        ),
      );
      await tester.pump();

      expect(_localPaths(tester), contains(path));
      expect(_networkUrl(tester), isNull);
    });

    testWidgets('a thumbnail URL is preferred over the full-resolution one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            imageUrl: 'https://cdn.test/full.png',
            thumbnailUrl: 'https://cdn.test/thumb.png',
          ),
        ),
      );
      await tester.pump();

      expect(_networkUrl(tester), 'https://cdn.test/thumb.png');
    });

    testWidgets('a GIF ignores its thumbnail so the animation keeps running', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            imageUrl: 'https://cdn.test/party.gif',
            thumbnailUrl: 'https://cdn.test/party-still.png',
          ),
        ),
      );
      // The GIF path mounts behind the viewport gate: one extra frame for the
      // post-frame visibility check.
      await tester.pump();
      await tester.pump();

      expect(_networkUrl(tester), 'https://cdn.test/party.gif');
    });

    testWidgets('an undecodable thumbnail falls back to the full URL', (
      tester,
    ) async {
      for (final thumb in const [
        'https://cdn.test/thumb.heic',
        'https://cdn.test/thumb.HEIF',
        'https://cdn.test/thumb.svg',
        '',
      ]) {
        await tester.pumpWidget(
          _host(
            CometChatImageBubble(
              key: ValueKey(thumb),
              imageUrl: 'https://cdn.test/full.png',
              thumbnailUrl: thumb,
            ),
          ),
        );
        await tester.pump();

        expect(
          _networkUrl(tester),
          'https://cdn.test/full.png',
          reason: 'thumbnail "$thumb" should not be rendered',
        );
      }
    });

    testWidgets('a thumbnail alone is rendered when there is no full URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            thumbnailUrl: 'https://cdn.test/thumb.png',
          ),
        ),
      );
      await tester.pump();

      expect(_networkUrl(tester), 'https://cdn.test/thumb.png');
    });
  });

  group('placeholder', () {
    testWidgets('no URL at all draws the placeholder and is not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const CometChatImageBubble()));
      await tester.pump();

      expect(_hasPlaceholder(tester), isTrue);
      expect(_rootDetector(tester).onTap, isNull);
    });

    testWidgets('an empty URL draws the placeholder', (tester) async {
      await tester.pumpWidget(_host(const CometChatImageBubble(imageUrl: '')));
      await tester.pump();

      expect(_hasPlaceholder(tester), isTrue);
    });

    testWidgets('a format the platform cannot decode draws the placeholder '
        'instead of an empty tile, and stays untappable', (tester) async {
      for (final url in const [
        'https://cdn.test/photo.heic',
        'https://cdn.test/photo.HEIF',
        'https://cdn.test/logo.svg',
        'https://cdn.test/render/svg?id=4',
        'https://cdn.test/svg/logo',
      ]) {
        await tester.pumpWidget(
          _host(CometChatImageBubble(key: ValueKey(url), imageUrl: url)),
        );
        await tester.pump();

        expect(_hasPlaceholder(tester), isTrue, reason: url);
        expect(_networkUrl(tester), isNull, reason: url);
        expect(_rootDetector(tester).onTap, isNull, reason: url);
      }
    });

    testWidgets('an undecodable LOCAL file draws the placeholder too', (
      tester,
    ) async {
      for (final name in const ['shot.heic', 'shot.heif', 'logo.svg']) {
        final path = writeImageFile(_dir, name);
        await tester.pumpWidget(
          _host(
            CometChatImageBubble(
              key: ValueKey(name),
              imageUrl: 'https://cdn.test/full.png',
              metadata: {'localPath': path},
            ),
          ),
        );
        await tester.pump();

        expect(_hasPlaceholder(tester), isTrue, reason: name);
        expect(_localPaths(tester), isEmpty, reason: name);
      }
    });

    testWidgets('placeholderImage replaces the default placeholder asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            placeholderImage: 'assets/icons/file_unknown.png',
          ),
        ),
      );
      await tester.pump();

      expect(
        _hasPlaceholder(tester, asset: 'assets/icons/file_unknown.png'),
        isTrue,
      );
      expect(_hasPlaceholder(tester), isFalse);
    });

    // The local-image `errorBuilder` (undecodable bytes on disk → network
    // image, else placeholder) is not reachable from a VM widget test: the
    // test binding never surfaces a decode failure to the Image widget, so
    // even a plain `Image.file` on garbage bytes keeps waiting rather than
    // calling its errorBuilder. Left uncovered on purpose.
  });

  group('tap', () {
    testWidgets('the default tap opens the viewer on the FULL-resolution URL, '
        'not the thumbnail', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            imageUrl: 'https://cdn.test/full.png',
            thumbnailUrl: 'https://cdn.test/thumb.png',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(CometChatImageBubble));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ImageViewer), findsOneWidget);
      expect(
        tester.widget<ImageViewer>(find.byType(ImageViewer)).imageUrl,
        'https://cdn.test/full.png',
      );

      // Drain the viewer's own 3s loading fallback timer.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('onClick replaces the default viewer navigation', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          CometChatImageBubble(
            imageUrl: 'https://cdn.test/full.png',
            onClick: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(CometChatImageBubble));
      await tester.pump();

      expect(taps, 1);
      expect(find.byType(ImageViewer), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('defaults to a 232 square and honours width/height', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const CometChatImageBubble()));
      await tester.pump();
      expect(
        tester.getSize(find.byType(CometChatImageBubble)),
        const Size(232, 232),
      );

      await tester.pumpWidget(
        _host(const CometChatImageBubble(width: 120, height: 90)),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(CometChatImageBubble)),
        const Size(120, 90),
      );
    });

    testWidgets('style backgroundColor paints the bubble and survives a '
        'style change in place', (tester) async {
      Color? fillOf(WidgetTester t) {
        final c = t.widget<Container>(
          find
              .descendant(
                of: find.byType(CometChatImageBubble),
                matching: find.byType(Container),
              )
              .first,
        );
        return (c.decoration as BoxDecoration?)?.color;
      }

      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            key: ValueKey('same'),
            style: CometChatImageBubbleStyle(
              backgroundColor: Color(0xFF112233),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(fillOf(tester), const Color(0xFF112233));

      // Same element, new style: didUpdateWidget has to re-merge it.
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            key: ValueKey('same'),
            style: CometChatImageBubbleStyle(
              backgroundColor: Color(0xFF445566),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(fillOf(tester), const Color(0xFF445566));
    });

    testWidgets('an injected colorPalette is swapped in place', (tester) async {
      final first = CometChatColorPalette(background3: const Color(0xFF010203));
      final second = CometChatColorPalette(
        background3: const Color(0xFF040506),
      );

      Color? fillOf(WidgetTester t) {
        final c = t.widget<Container>(
          find
              .descendant(
                of: find.byType(CometChatImageBubble),
                matching: find.byType(Container),
              )
              .first,
        );
        return (c.decoration as BoxDecoration?)?.color;
      }

      await tester.pumpWidget(
        _host(
          CometChatImageBubble(
            key: const ValueKey('same'),
            colorPalette: first,
            spacing: CometChatSpacing(radius3: 4),
          ),
        ),
      );
      await tester.pump();
      expect(fillOf(tester), const Color(0xFF010203));

      await tester.pumpWidget(
        _host(
          CometChatImageBubble(
            key: const ValueKey('same'),
            colorPalette: second,
            spacing: CometChatSpacing(radius3: 12),
          ),
        ),
      );
      await tester.pump();
      expect(fillOf(tester), const Color(0xFF040506));
    });
  });

  group('GIF viewport gate', () {
    testWidgets('a GIF with no viewport ancestor is treated as visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CometChatImageBubble(imageUrl: 'https://cdn.test/a.gif')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      // The gate reserves the bubble's box either way, so the layout does not
      // jump when the image mounts.
      expect(
        tester.getSize(find.byType(CometChatImageBubble)),
        const Size(232, 232),
      );
    });

    testWidgets('scrolling a GIF out of view unmounts the image, and '
        'scrolling back remounts it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  CometChatImageBubble(imageUrl: 'https://cdn.test/a.gif'),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CachedNetworkImage), findsOneWidget);

      // Past the bubble's 232px height: nothing of it overlaps the viewport.
      final scrollable = find.byType(Scrollable);
      tester.state<ScrollableState>(scrollable).position.jumpTo(1200);
      await tester.pump();
      expect(find.byType(CachedNetworkImage), findsNothing);

      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('an unsupported GIF URL keeps the placeholder and skips the '
        'gate entirely', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatImageBubble(
            imageUrl: 'https://cdn.test/a.heic',
            thumbnailUrl: 'https://cdn.test/a.gif',
          ),
        ),
      );
      await tester.pump();

      expect(_hasPlaceholder(tester), isTrue);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}
