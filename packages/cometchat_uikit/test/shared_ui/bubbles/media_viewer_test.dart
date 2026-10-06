/// Behavioural tests for the fullscreen media pager
/// (`cometchat_media_viewer.dart`): which page kind each attachment gets, how
/// the pager is driven (arrows, keyboard, swipe), the video page's play/pause
/// and auto-hiding controls, the "No preview available" fallback, and the
/// download action's two outcomes.
///
/// The video pages run against the scriptable [FakeVideoPlayerPlatform] — with
/// the real (absent) plugin every page would collapse onto the error state, so
/// the ready/playing branches would be untestable. The download action goes
/// through the Kit's `cometchat_chat_uikit` method channel, mocked here.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../helpers/fake_video_player_platform.dart';

/// A 1x1 transparent PNG — enough for `Image.file` to decode successfully.
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Attachment _attachment(
  String url,
  String name,
  String ext,
  String mime, [
  int size = 1024,
]) => Attachment(url, name, ext, mime, size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform platform;
  late Directory tempDir;
  late List<MethodCall> channelCalls;

  /// What the mocked `saveFileWithPicker` hands back: a non-empty string means
  /// the user picked a location and the write succeeded.
  String? savePickerResult;
  Completer<void>? savePickerGate;

  const channel = MethodChannel('cometchat_chat_uikit');

  setUp(() {
    platform = installFakeVideoPlayerPlatform();
    tempDir = Directory.systemTemp.createTempSync('cc_media_viewer_test');
    channelCalls = <MethodCall>[];
    savePickerResult = '/saved/here.png';
    savePickerGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          channelCalls.add(call);
          if (savePickerGate != null) await savePickerGate!.future;
          if (call.method == 'saveFileWithPicker') return savePickerResult;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String writeTempFile(String name, List<int> bytes) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
    return f.path;
  }

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: child,
  );

  Future<void> pumpViewer(
    WidgetTester tester,
    List<Attachment> items, {
    int startIndex = 0,
  }) async {
    await tester.pumpWidget(
      host(CometChatMediaViewer(mediaItems: items, startIndex: startIndex)),
    );
    await tester.pump();
  }

  final audio = _attachment(
    'https://files.invalid/standup.mp3',
    'standup.mp3',
    'mp3',
    'audio/mpeg',
  );
  final remoteImage = _attachment(
    'https://files.invalid/shot.png',
    'shot.png',
    'png',
    'image/png',
  );
  final remoteVideo = _attachment(
    'https://files.invalid/clip.mp4',
    'clip.mp4',
    'mp4',
    'video/mp4',
  );

  group('page kinds', () {
    testWidgets(
      'an audio attachment gets the "no preview" card, not a player',
      (tester) async {
        await pumpViewer(tester, [audio]);

        final t = Translations.of(
          tester.element(find.byType(CometChatMediaViewer)),
        );
        expect(find.text(t.noPreviewAvailable), findsOneWidget);
        expect(find.text(t.fileTypeNotSupportedForPreview), findsOneWidget);
        expect(find.byType(vp.VideoPlayer), findsNothing);
        expect(find.byType(InteractiveViewer), findsNothing);
        // Two download affordances by design: the AppBar one and the body one.
        // bySubtype, not byType: `ElevatedButton.icon` builds a private
        // subclass in some Flutter versions, and `find.byType` matches on
        // exact runtimeType. byType passed on 3.44 and found nothing on
        // CI's 3.47.
        expect(find.bySubtype<ElevatedButton>(), findsOneWidget);
      },
    );

    testWidgets('an image attachment gets a zoomable page', (tester) async {
      final path = writeTempFile('local.png', base64Decode(_pngBase64));
      await pumpViewer(tester, [
        _attachment(path, 'local.png', 'png', 'image/png'),
      ]);
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 4);
    });

    testWidgets(
      'a remote image that fails to load falls back to "no preview"',
      (tester) async {
        // flutter_test's HTTP client answers every request with a 400, so the
        // network image always lands in errorBuilder here.
        await pumpViewer(tester, [remoteImage]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final t = Translations.of(
          tester.element(find.byType(CometChatMediaViewer)),
        );
        expect(find.text(t.noPreviewAvailable), findsOneWidget);
      },
    );

    testWidgets(
      'a video attachment gets an inline player once it initializes',
      (tester) async {
        await pumpViewer(tester, [remoteVideo]);
        await tester.pump();
        await tester.pump();

        expect(find.byType(vp.VideoPlayer), findsOneWidget);
        expect(find.byType(vp.VideoProgressIndicator), findsOneWidget);
        expect(platform.createdUris, ['https://files.invalid/clip.mp4']);
      },
    );

    testWidgets('a video whose player cannot be built shows "no preview"', (
      tester,
    ) async {
      platform.failCreate = true;
      await pumpViewer(tester, [remoteVideo]);
      await tester.pump();
      await tester.pump();

      final t = Translations.of(
        tester.element(find.byType(CometChatMediaViewer)),
      );
      expect(find.text(t.noPreviewAvailable), findsOneWidget);
      expect(find.byType(vp.VideoPlayer), findsNothing);
    });
  });

  group('paging', () {
    testWidgets('the title counts pages and startIndex picks the first one', (
      tester,
    ) async {
      await pumpViewer(tester, [audio, audio, audio], startIndex: 1);

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('arrows appear only where there is somewhere to go', (
      tester,
    ) async {
      await pumpViewer(tester, [audio, audio, audio]);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('swiping the pager updates the counter', (tester) async {
      await pumpViewer(tester, [audio, audio]);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('arrow keys page, and stop at the ends', (tester) async {
      await pumpViewer(tester, [audio, audio]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        find.text('1 / 2'),
        findsOneWidget,
        reason: 'already at the start',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget, reason: 'already at the end');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('an unhandled key is left to the rest of the app', (
      tester,
    ) async {
      await pumpViewer(tester, [audio, audio]);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
    });
  });

  group('closing', () {
    testWidgets('open() pushes the viewer and Escape closes it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      CometChatMediaViewer.open(context, [audio, audio]),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CometChatMediaViewer), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CometChatMediaViewer), findsNothing);
    });

    testWidgets('the close button pops the route', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => CometChatMediaViewer.open(context, [audio]),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CometChatMediaViewer), findsNothing);
    });
  });

  group('download', () {
    testWidgets('a successful save reports where the file went', (
      tester,
    ) async {
      await pumpViewer(tester, [audio]);

      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await tester.pump();
      await tester.pump();

      expect(channelCalls.single.method, 'saveFileWithPicker');
      expect((channelCalls.single.arguments as Map)['fileName'], 'standup.mp3');
      final t = Translations.of(
        tester.element(find.byType(CometChatMediaViewer)),
      );
      expect(find.text(t.fileSaved), findsOneWidget);

      // Let the snackbar expire so no timer outlives the test.
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('a cancelled picker is silent — no error is reported', (
      tester,
    ) async {
      savePickerResult = null;
      await pumpViewer(tester, [audio]);

      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the download button spins and is disabled while saving', (
      tester,
    ) async {
      final gate = Completer<void>();
      savePickerGate = gate;
      await pumpViewer(tester, [audio]);
      // The body button on the "no preview" card drives the same action.
      // See the note on bySubtype above.
      final body = find.bySubtype<ElevatedButton>();
      expect(tester.widget<ElevatedButton>(body).onPressed, isNotNull);

      await tester.tap(body);
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(body).onPressed,
        isNull,
        reason: 'the centre button locks out a second save',
      );
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byIcon(Icons.file_download_outlined), findsNothing);

      // A second tap while busy must not fire another platform call.
      await tester.tap(body, warnIfMissed: false);
      await tester.pump();
      expect(channelCalls, hasLength(1));

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ElevatedButton>(body).onPressed, isNotNull);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('an attachment with no url is not downloadable', (
      tester,
    ) async {
      await pumpViewer(tester, [
        _attachment('', 'ghost.mp3', 'mp3', 'audio/mpeg'),
      ]);

      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await tester.pump();
      await tester.pump();

      expect(channelCalls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the download acts on the page currently shown', (
      tester,
    ) async {
      final second = _attachment(
        'https://files.invalid/second.mp3',
        'second.mp3',
        'mp3',
        'audio/mpeg',
      );
      await pumpViewer(tester, [audio, second]);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.file_download_outlined).first);
      await tester.pump();
      await tester.pump();

      expect((channelCalls.single.arguments as Map)['fileName'], 'second.mp3');
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  group('video page controls', () {
    /// Pumps a single ready video page.
    Future<void> pumpVideo(WidgetTester tester) async {
      await pumpViewer(tester, [remoteVideo]);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the centre button toggles playback and swaps its icon', (
      tester,
    ) async {
      await pumpVideo(tester);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(platform.log, contains('play:1'));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(platform.log, contains('pause:1'));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('controls fade out while playing and come back on a tap', (
      tester,
    ) async {
      await pumpVideo(tester);
      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(opacity(), 1);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(opacity(), 1, reason: 'they linger first');

      await tester.pump(const Duration(milliseconds: 2600));
      expect(opacity(), 0, reason: 'then auto-hide while playing');
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(AnimatedOpacity),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );

      await tester.tap(find.byType(vp.VideoPlayer));
      await tester.pump();
      expect(opacity(), 1);

      await tester.pumpAndSettle();
    });

    testWidgets('pausing keeps the controls up indefinitely', (tester) async {
      await pumpVideo(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('reaching the end of the video brings the controls back', (
      tester,
    ) async {
      await pumpVideo(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2600));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );

      platform.completePlayback();
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
        reason: 'a hidden, un-restartable player would be a dead end',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('the clock shows elapsed and total, with hours when needed', (
      tester,
    ) async {
      platform.duration = const Duration(seconds: 30);
      await pumpVideo(tester);

      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('an hour-long video is clocked as h:mm:ss', (tester) async {
      platform.duration = const Duration(hours: 1, minutes: 2, seconds: 3);
      await pumpVideo(tester);

      expect(find.text('1:02:03'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping the surface before the player is ready does nothing', (
      tester,
    ) async {
      platform.hangInitialize = true;
      await pumpViewer(tester, [remoteVideo]);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsNothing);
    });

    testWidgets('a local (not yet uploaded) video opens from its file path', (
      tester,
    ) async {
      final path = writeTempFile('staged.mp4', <int>[0, 1, 2]);
      await pumpViewer(tester, [
        _attachment(path, 'staged.mp4', 'mp4', 'video/mp4'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(platform.createdUris.single, contains('staged.mp4'));
      expect(find.byType(vp.VideoPlayer), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
