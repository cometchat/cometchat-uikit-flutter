/// The staged tray's two behaviours that the prop matrix doesn't reach: opening
/// the fullscreen preview from a tile, and making the strip scrollable with a
/// mouse.
///
///   flutter test test/chat_ui/message_composer/attachment_tray_preview_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_upload_sdk.dart';
import '../../helpers/fake_video_player_platform.dart';

UploadFile _file(String name, String mime, {String? path}) => UploadFile(
  name: name,
  size: 1000,
  mimeType: mime,
  path: path ?? '/tmp/$name',
);

Widget _host(AttachmentTrayController controller) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: CometChatAttachmentTray(controller: controller)),
);

void main() {
  late FakeUploadSdkClient sdk;

  setUp(() async {
    sdk = await registerFakeUploadSdk(maxFileCount: 20);
    installFakeVideoPlayerPlatform();
  });

  tearDown(clearFakeUploadSdk);

  AttachmentTrayController controller() =>
      AttachmentTrayController(receiverId: 'bob', receiverType: 'user');

  /// Completes every staged upload, so no tile spins and the tree can settle.
  void finishUploads(AttachmentTrayController c) {
    final listener = sdk.repo.globalListener!;
    for (final t in c.tiles) {
      listener.onFileUploaded(
        t.fileId,
        Attachment('https://cdn/${t.name}', t.name, '', t.mimeType, t.size),
      );
    }
  }

  group('opening the preview', () {
    testWidgets('an empty tray renders nothing at all', (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c));
      expect(find.byType(CometChatAttachmentTile), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('tapping a media tile opens the viewer over the visual media'
        ' only, at that tile', (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([
        _file('pic.jpg', 'image/jpeg'),
        _file('doc.pdf', 'application/pdf'),
        _file('clip.mp4', 'video/mp4'),
        _file('song.mp3', 'audio/mpeg'),
      ]);
      finishUploads(c);
      await tester.pumpWidget(_host(c));
      await tester.pump();

      // Tap the video tile (the second visual-media tile).
      await tester.tap(find.byType(CometChatVideoFirstFrame));
      await tester.pumpAndSettle();

      final viewer = tester.widget<CometChatMediaViewer>(
        find.byType(CometChatMediaViewer),
      );
      expect(viewer.mediaItems.map((a) => a.fileName), [
        'pic.jpg',
        'clip.mp4',
      ], reason: 'the pdf and the audio are not visual media');
      expect(viewer.startIndex, 1, reason: 'opened on the tapped tile');
      // The extension is split off the staged name for the viewer.
      expect(viewer.mediaItems.map((a) => a.fileExtension), ['jpg', 'mp4']);
      expect(
        viewer.mediaItems.first.fileUrl,
        '/tmp/pic.jpg',
        reason: 'local-first: the staged path, not the CDN url',
      );
    });

    testWidgets('a tile with no preview source is skipped, and the index of'
        ' the tapped tile shifts with it', (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([
        _file('a.jpg', 'image/jpeg'),
        _file('b.jpg', 'image/jpeg'),
        _file('c.jpg', 'image/jpeg'),
      ]);
      finishUploads(c);
      // The first tile has nothing to show: a web bytes pick whose upload
      // produced no url at all.
      c.tiles.first
        ..thumbUrl = null
        ..attachment = null;
      // The second one has finished uploading, so it falls back to the
      // attachment's remote url.
      c.tiles[1].thumbUrl = '';

      await tester.pumpWidget(_host(c));
      await tester.pump();

      await tester.tap(find.byType(CometChatAttachmentTile).last);
      await tester.pumpAndSettle();

      final viewer = tester.widget<CometChatMediaViewer>(
        find.byType(CometChatMediaViewer),
      );
      expect(viewer.mediaItems.map((a) => a.fileUrl), [
        'https://cdn/b.jpg',
        '/tmp/c.jpg',
      ]);
      expect(
        viewer.startIndex,
        1,
        reason: 'index among the items actually shown, not the tray index',
      );
    });

    testWidgets('a name with no extension still previews', (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([_file('screenshot', 'image/png')]);
      finishUploads(c);
      await tester.pumpWidget(_host(c));
      await tester.pump();

      await tester.tap(find.byType(CometChatAttachmentTile));
      await tester.pumpAndSettle();

      final viewer = tester.widget<CometChatMediaViewer>(
        find.byType(CometChatMediaViewer),
      );
      expect(viewer.mediaItems.single.fileExtension, '');
      expect(viewer.startIndex, 0);
    });

    testWidgets('tapping when nothing has a source opens no viewer', (
      tester,
    ) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([_file('a.jpg', 'image/jpeg')]);
      finishUploads(c);
      c.tiles.single
        ..thumbUrl = null
        ..attachment = null;

      await tester.pumpWidget(_host(c));
      await tester.pump();
      await tester.tap(find.byType(CometChatAttachmentTile));
      await tester.pumpAndSettle();

      expect(find.byType(CometChatMediaViewer), findsNothing);
    });

    testWidgets('a file tile is not previewable and its remove badge still'
        ' works', (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([_file('doc.pdf', 'application/pdf')]);
      finishUploads(c);
      await tester.pumpWidget(_host(c));
      await tester.pump();

      await tester.tap(find.byKey(const Key('cometchat_attachment_file_card')));
      await tester.pumpAndSettle();
      expect(find.byType(CometChatMediaViewer), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(c.tiles, isEmpty);
      expect(sdk.repo.log, contains('remove:tile_0'));
    });

    testWidgets('a rejected tile surfaces its reason; a failed one retries', (
      tester,
    ) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([
        _file('bad.pdf', 'application/pdf'),
        _file('flaky.pdf', 'application/pdf'),
      ]);
      final listener = sdk.repo.globalListener!;
      listener.onFileError(
        'tile_0',
        CometChatException('E', null, 'File is too large'),
      );
      listener.onFileFailure(
        'tile_1',
        CometChatException('E', null, 'Network died'),
      );

      await tester.pumpWidget(_host(c));
      await tester.pump();

      final cards = find.byKey(const Key('cometchat_attachment_file_card'));
      await tester.tap(cards.first);
      await tester.pump();
      expect(
        find.textContaining('File is too large'),
        findsOneWidget,
        reason: 'the rejected tile explains itself in a snackbar',
      );

      sdk.repo.log.clear();
      await tester.tap(cards.last);
      await tester.pump();
      expect(sdk.repo.log, contains('retry:tile_1'));
    });
  });

  group('scrolling the strip', () {
    Future<AttachmentTrayController> crowdedTray(WidgetTester tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await c.stage([
        for (var i = 0; i < 12; i++) _file('doc$i.pdf', 'application/pdf'),
      ]);
      finishUploads(c);
      await tester.pumpWidget(_host(c));
      await tester.pump();
      return c;
    }

    double offset(WidgetTester tester) =>
        tester.widget<ListView>(find.byType(ListView)).controller!.offset;

    testWidgets('a vertical mouse wheel scrolls the horizontal strip', (
      tester,
    ) async {
      await crowdedTray(tester);
      expect(offset(tester), 0);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final where = tester.getCenter(find.byType(ListView));
      await tester.sendEventToBinding(pointer.hover(where));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();

      expect(
        offset(tester),
        120,
        reason: 'dy is redirected onto the horizontal axis',
      );
    });

    testWidgets('a genuine horizontal delta is applied TWICE', (tester) async {
      await crowdedTray(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final where = tester.getCenter(find.byType(ListView));
      await tester.sendEventToBinding(pointer.hover(where));
      await tester.sendEventToBinding(pointer.scroll(const Offset(60, 10)));
      await tester.pump();

      // FINDING: `_handlePointerSignal` picks the larger axis and jumps by it
      // unconditionally, but a horizontal delta has ALREADY been consumed by
      // the ListView itself (a raw `Listener.onPointerSignal` bypasses the
      // PointerSignalResolver the Scrollable registers with). A trackpad's
      // genuine horizontal swipe therefore scrolls the tray twice as far as it
      // should — 120px for a 60px delta. Only the vertical redirect, which the
      // ListView ignores, is applied once.
      expect(offset(tester), 120);
    });

    testWidgets('scrolling clamps at both ends of the strip', (tester) async {
      await crowdedTray(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final where = tester.getCenter(find.byType(ListView));
      await tester.sendEventToBinding(pointer.hover(where));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 99999)));
      await tester.pump();
      final atEnd = offset(tester);
      expect(atEnd, greaterThan(0));

      // A second huge scroll can't push it any further (the lazily-built
      // list's max extent only ever shrinks as more items are measured).
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 99999)));
      await tester.pump();
      expect(offset(tester), lessThanOrEqualTo(atEnd));
      expect(offset(tester), greaterThan(0));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -99999)));
      await tester.pump();
      expect(offset(tester), 0, reason: 'clamped at the start');
    });

    testWidgets('a zero-delta signal is ignored', (tester) async {
      await crowdedTray(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final where = tester.getCenter(find.byType(ListView));
      await tester.sendEventToBinding(pointer.hover(where));
      await tester.sendEventToBinding(pointer.scroll(Offset.zero));
      await tester.pump();
      expect(offset(tester), 0);
    });

    testWidgets('the strip can also be dragged with a mouse', (tester) async {
      await crowdedTray(tester);
      // MaterialScrollBehavior excludes the mouse from drag devices; the tray
      // puts it back so a click-drag works on desktop web.
      final behavior = tester
          .widget<ScrollConfiguration>(find.byType(ScrollConfiguration).last)
          .behavior;
      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(offset(tester), greaterThan(0));
      await gesture.up();
      await tester.pump();
    });
  });
}
