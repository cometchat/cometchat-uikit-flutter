// W5 (ENG-41095), G9: media from the device on the offline path — cached
// bytes → URL → "Available when online" placeholder, re-resolved on MediaReady,
// and today's URL path untouched with offline off.

import 'dart:io';

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/bubbles/media_grid/cometchat_media_grid.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/bubbles/media_placeholder/cometchat_video_first_frame.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_media.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _att({String? localPath}) => Attachment(
  'https://cdn.example/photo.png?sig=1',
  'photo.png',
  'png',
  'image/png',
  2048,
  localPath: localPath,
);

Attachment _video({String? localPath}) => Attachment(
  'https://cdn.example/clip.mp4?sig=1',
  'clip.mp4',
  'mp4',
  'video/mp4',
  4096,
  localPath: localPath,
);

Finder _frameFrom(String source) => find.byWidgetPredicate(
  (w) => w is CometChatVideoFirstFrame && w.source == source,
);

/// Pumps frame by frame until [finder] matches. (The test binding has no
/// video plugin, so a device-copy frame fails a frame or two after it shows.)
Future<bool> _appears(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 10; i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 10));
  }
  return finder.evaluate().isNotEmpty;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
);

Widget _network(BuildContext context, Widget? offlineError) => Text(
  offlineError == null ? 'network' : 'network+offline',
  textDirection: TextDirection.ltr,
);

bool _showsFile(WidgetTester tester, String path) => tester
    .widgetList<Image>(find.byType(Image))
    .any(
      (i) => i.image is FileImage && (i.image as FileImage).file.path == path,
    );

void main() {
  final hub = OfflineHub.instance;
  final lookups = <String>[];
  String? cached;

  setUp(() {
    hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    hub.debugLoginSuccess('me');
    lookups.clear();
    cached = null;
    OfflineMedia.debugIsUsable = (p) => p.startsWith('/cache/');
    OfflineMedia.debugCachedMediaPath = (m) async {
      lookups.add((m as MediaMessage).attachment!.fileUrl);
      return cached;
    };
  });

  tearDown(() {
    CometChat.debugSetOfflineEnabledOverride(null);
    OfflineMedia.debugIsUsable = null;
    OfflineMedia.debugCachedMediaPath = null;
  });

  testWidgets('attachment.localPath wins: the device copy renders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OfflineMediaImage(
          attachment: _att(localPath: '/cache/a.png'),
          network: _network,
        ),
      ),
    );
    expect(_showsFile(tester, '/cache/a.png'), isTrue);
    expect(find.text('network'), findsNothing);
    expect(lookups, isEmpty);
  });

  testWidgets('then the SDK cache by URL', (tester) async {
    cached = '/cache/b.png';
    final a = _att();
    await tester.pumpWidget(
      _host(OfflineMediaImage(attachment: a, network: _network)),
    );
    await tester.pump();
    expect(lookups, ['https://cdn.example/photo.png?sig=1']);
    expect(_showsFile(tester, '/cache/b.png'), isTrue);
    expect(a.localPath, '/cache/b.png');
  });

  testWidgets('not cached: the URL, with the offline placeholder as its '
      'error art; MediaReady re-resolves to the device copy', (tester) async {
    await tester.pumpWidget(
      _host(OfflineMediaImage(attachment: _att(), network: _network)),
    );
    await tester.pump();
    expect(find.text('network+offline'), findsOneWidget);

    cached = '/cache/c.png';
    hub.debugMediaDownloaded(null, 'att-1', '/cache/c.png');
    await tester.pump();
    await tester.pump();
    expect(_showsFile(tester, '/cache/c.png'), isTrue);
    expect(find.text('network+offline'), findsNothing);
  });

  testWidgets('offline off: today\'s URL widget, no lookup', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    await tester.pumpWidget(
      _host(
        OfflineMediaImage(
          attachment: _att(localPath: '/cache/a.png'),
          network: _network,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('network'), findsOneWidget);
    expect(lookups, isEmpty);
    expect(await OfflineMedia.resolve(_att()), isNull);
  });

  testWidgets('placeholder shows name, size and "Available when online"', (
    tester,
  ) async {
    await tester.pumpWidget(_host(OfflineMediaPlaceholder(attachment: _att())));
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(find.text('Available when online'), findsOneWidget);
  });

  testWidgets('the image bubble grid renders the device copy with offline '
      'on and today\'s network image with it off', (tester) async {
    final grid = CometChatMediaGrid(
      media: [_att(localPath: '/cache/g.png')],
      width: 200,
    );
    await tester.pumpWidget(_host(grid));
    expect(_showsFile(tester, '/cache/g.png'), isTrue);

    CometChat.debugSetOfflineEnabledOverride(false);
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pumpWidget(_host(grid));
    expect(_showsFile(tester, '/cache/g.png'), isFalse);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((i) => i.image is NetworkImage),
      isTrue,
    );
  });

  group('video grid cell', () {
    testWidgets('attachment.localPath wins: the first frame comes from the '
        'device copy', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatMediaGrid(
            media: [_video(localPath: '/cache/v.mp4')],
            width: 200,
          ),
        ),
      );
      expect(_frameFrom('/cache/v.mp4'), findsOneWidget);
      expect(_frameFrom(_video().fileUrl), findsNothing);
      expect(lookups, isEmpty);
    });

    testWidgets('then the SDK cache by URL', (tester) async {
      cached = '/cache/v1.mp4';
      await tester.pumpWidget(
        _host(CometChatMediaGrid(media: [_video()], width: 200)),
      );
      await tester.pump();
      expect(lookups, [_video().fileUrl]);
      expect(await _appears(tester, _frameFrom('/cache/v1.mp4')), isTrue);
    });

    testWidgets('not cached and the URL cannot load: "Available when online"; '
        'MediaReady re-resolves to the device copy', (tester) async {
      await tester.pumpWidget(
        _host(CometChatMediaGrid(media: [_video()], width: 200)),
      );
      expect(_frameFrom(_video().fileUrl), findsOneWidget); // the URL next
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(OfflineMediaPlaceholder), findsOneWidget);
      expect(find.text('clip.mp4'), findsOneWidget);

      cached = '/cache/v2.mp4';
      hub.debugMediaDownloaded(null, 'att-v', '/cache/v2.mp4');
      expect(await _appears(tester, _frameFrom('/cache/v2.mp4')), isTrue);
    });

    testWidgets('offline off: today\'s URL first frame, no lookup, and the '
        '"no preview" art on failure', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      await tester.pumpWidget(
        _host(
          CometChatMediaGrid(
            media: [_video(localPath: '/cache/v.mp4')],
            width: 200,
          ),
        ),
      );
      expect(_frameFrom(_video().fileUrl), findsOneWidget);
      expect(_frameFrom('/cache/v.mp4'), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(OfflineMediaPlaceholder), findsNothing);
      expect(lookups, isEmpty);
    });
  });

  test('a native path that does not exist is not used', () {
    OfflineMedia.debugIsUsable = null;
    final missing = '${Directory.systemTemp.path}/w5-missing-${DateTime.now()}';
    expect(OfflineMedia.usable(missing), isNull);
    expect(OfflineMedia.usable(null), isNull);
  });
}
