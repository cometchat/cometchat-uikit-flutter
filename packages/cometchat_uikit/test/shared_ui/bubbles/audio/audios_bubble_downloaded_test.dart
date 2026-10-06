/// The **downloaded** half of the multi-audio bubble
/// (`cometchat_audios_bubble.dart`) — everything a row only does once a copy
/// of the file is on the device: the player it builds, the play/pause/seek
/// transport, the ready clock, the "another player started" pause, the
/// recovery after a player that would not open, and the file card's
/// open-with hand-off.
///
/// Two seams make this reachable on a desktop test host:
///
/// * `installFakePathProvider` gives `platform_file.getDownloadedFilePath` a
///   real directory to look in, so a file written into the attachment's cache
///   bucket is found exactly the way a previously-downloaded file is.
/// * `installFakeVideoPlayerPlatform` gives `video_player` a backend, so the
///   controller the row builds for that file actually initializes.
///
/// Without them every row collapses onto "not downloaded" and none of this
/// can run. The undownloaded paths live in `audios_bubble_test.dart`.
///
///   flutter test test/shared_ui/bubbles/audio/audios_bubble_downloaded_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The cache-bucket rule is internal to the Kit but is exactly what decides
// where a downloaded attachment lives, so the seeding here has to use it
// rather than re-implement it.
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/download_cache_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_path_provider.dart';
import '../../../helpers/fake_video_player_platform.dart';

late Directory _root;

Attachment _audio(String name, {int size = 1024}) =>
    Attachment('https://files.invalid/$name', name, 'mp3', 'audio/mpeg', size);

Attachment _pdf(String name) => Attachment(
  'https://files.invalid/$name',
  name,
  'pdf',
  'application/pdf',
  7,
);

MediaMessage _message(List<Attachment> attachments) {
  final m = MediaMessage(
    receiverUid: 'priya',
    receiverType: ReceiverTypeConstants.user,
    type: MessageTypeConstants.audio,
    muid: 'audios-downloaded-test',
  );
  m.attachments = attachments;
  return m;
}

/// Where the Kit looks for [a]'s cached copy: the download root plus the
/// attachment's per-url bucket.
String _cachePathFor(Attachment a) =>
    '${_root.path}/${DownloadCacheKey.bucketFor(a.fileUrl)}/${a.fileName}';

/// Puts a real file where the Kit expects an earlier download to have landed.
void _seedDownload(Attachment a) {
  final file = File(_cachePathFor(a));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(const [0, 1, 2, 3, 4, 5, 6, 7]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uikitChannel = MethodChannel('cometchat_chat_uikit');
  late List<MethodCall> channelCalls;
  late FakeVideoPlayerPlatform fake;

  /// When set, the platform channel blocks until it is completed — which is
  /// how the row's transient "busy" state can be observed at all.
  Completer<void>? channelGate;

  setUpAll(() => _root = installFakePathProvider(prefix: 'cc_audios_bubble'));

  tearDownAll(() {
    if (_root.existsSync()) _root.deleteSync(recursive: true);
  });

  setUp(() {
    fake = installFakeVideoPlayerPlatform();
    channelCalls = <MethodCall>[];
    channelGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(uikitChannel, (call) async {
          channelCalls.add(call);
          if (channelGate != null) await channelGate!.future;
          if (call.method == 'saveFileWithPicker') return '/saved/copy.mp3';
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(uikitChannel, null);
    for (final entity in _root.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  Future<void> pumpBubble(
    WidgetTester tester,
    MediaMessage message, {
    BubbleAlignment alignment = BubbleAlignment.left,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CometChatAudiosBubble(
              message: message,
              alignment: alignment,
            ),
          ),
        ),
      ),
    );
    // `_restoreDownloaded` -> `_initController` is a chain of awaits ending in
    // the fake platform's deferred `initialized` event.
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Slider slider(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider));

  /// Steps the widget forward while letting REAL file I/O run.
  ///
  /// `BubbleUtils.downloadFile` creates directories and writes through
  /// `dart:io`, which never completes under the test's fake clock.
  Future<void> settleRealIo(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  group('a row whose file is already on the device', () {
    testWidgets('opens a player on the cached file and shows the real clock', (
      tester,
    ) async {
      final a = _audio('standup.mp3');
      _seedDownload(a);

      await pumpBubble(tester, _message([a]));

      // The player was opened against the local copy, not the remote url.
      expect(fake.createdUris.single, contains(_cachePathFor(a)));
      expect(find.text('00:00/00:30'), findsOneWidget);
      expect(find.text('1 KB'), findsNothing);

      final s = slider(tester);
      expect(s.onChanged, isNotNull, reason: 'a ready player is scrubbable');
      expect(s.max, 30000.0);
      expect(s.value, 0.0);
    });

    testWidgets('the leading button plays, then pauses, the cached file', (
      tester,
    ) async {
      final a = _audio('standup.mp3');
      _seedDownload(a);
      await pumpBubble(tester, _message([a]));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();

      expect(fake.log, contains('play:1'));
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      await tester.pump();

      expect(fake.log, contains('pause:1'));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('dragging the slider seeks the player', (tester) async {
      final a = _audio('standup.mp3');
      _seedDownload(a);
      await pumpBubble(tester, _message([a]));

      slider(tester).onChanged!(12000);
      await tester.pump();
      await tester.pump();

      expect(fake.log, contains('seek:1:0:00:12.000000'));
    });

    testWidgets('another player starting anywhere in the app pauses this row', (
      tester,
    ) async {
      final a = _audio('standup.mp3');
      _seedDownload(a);
      await pumpBubble(tester, _message([a]));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(
          id: 'some-other-player'.hashCode,
          action: AudioBubbleActions.pausePlayer,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(fake.log, contains('pause:1'));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('starting one row pauses the other rows of the same message', (
      tester,
    ) async {
      final a = _audio('one.mp3');
      final b = _audio('two.mp3');
      _seedDownload(a);
      _seedDownload(b);
      await pumpBubble(tester, _message([a, b]));

      expect(fake.livePlayerIds, hasLength(2));

      // Play the first row.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
      await tester.pump();
      await tester.pump();

      // The broadcast reaches the second row's player, which pauses.
      expect(fake.log, contains('play:1'));
      expect(fake.log, contains('pause:2'));
    });
  });

  group('a cached file the player cannot open', () {
    /// The row bounds each attempt at 10s and retries once a second later, so
    /// the error only appears after ~21s. Between clock steps the real event
    /// loop has to run too: tearing the wedged controller down goes through
    /// `VideoPlayerController.dispose`, which does not complete under the
    /// fake clock alone.
    Future<void> exhaustInitAttempts(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(seconds: 4));
      }
    }

    testWidgets('retries exactly once and then surfaces a retryable error', (
      tester,
    ) async {
      fake.hangInitialize = true;
      final a = _audio('broken.mp3');
      _seedDownload(a);

      await pumpBubble(tester, _message([a]));
      expect(find.byIcon(Icons.error_outline), findsNothing);

      await exhaustInitAttempts(tester);

      expect(
        fake.log.where((c) => c.startsWith('create:')).length,
        2,
        reason: 'exactly one retry, not an endless loop',
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(slider(tester).onChanged, isNull);
      expect(
        find.byType(Slider),
        findsOneWidget,
        reason: 'a real audio that failed keeps its player row',
      );
      expect(
        find.text('broken.mp3'),
        findsOneWidget,
        reason: 'it must not flip into a document card',
      );
    });

    testWidgets('tapping the error rebuilds the player and plays it', (
      tester,
    ) async {
      fake.hangInitialize = true;
      final a = _audio('broken.mp3');
      _seedDownload(a);

      await pumpBubble(tester, _message([a]));
      await exhaustInitAttempts(tester);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Whatever was wrong is now fixed.
      fake.hangInitialize = false;
      await tester.tap(find.byIcon(Icons.error_outline));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(fake.log.where((c) => c.startsWith('play:')), isNotEmpty);
      expect(find.text('00:00/00:30'), findsOneWidget);
    });
  });

  group('the file card for a non-audio attachment', () {
    testWidgets('tapping it hands an existing local copy to the OS opener', (
      tester,
    ) async {
      final doc = _pdf('contract.pdf');
      _seedDownload(doc);

      await pumpBubble(tester, _message([doc]));
      // A mismatched file is never given a player, even when it is cached.
      expect(fake.createdUris, isEmpty);
      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.text('contract.pdf'));
      await settleRealIo(tester);

      final open = channelCalls.where((c) => c.method == 'open_file').toList();
      expect(open, hasLength(1));
      final args = open.single.arguments as Map;
      expect(args['file_path'], _cachePathFor(doc));
      expect(args['file_type'], 'application/pdf');
      // The row is usable again afterwards.
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('a file name with no extension still renders a card', (
      tester,
    ) async {
      final doc = Attachment(
        'https://files.invalid/readme',
        'readme',
        'pdf',
        'application/pdf',
        12,
      );

      await pumpBubble(tester, _message([doc]));

      expect(find.text('readme'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('the outgoing "+N more" toggle is tinted for the sent side', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        _message(List.generate(4, (i) => _pdf('doc-$i.pdf'))),
        alignment: BubbleAlignment.right,
      );

      final toggle = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.expand_more),
          matching: find.byType(Container),
        ),
      );
      expect(
        (toggle.decoration! as BoxDecoration).color,
        Colors.white.withValues(alpha: 0.12),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.expand_more)).color,
        Colors.white,
      );
    });

    testWidgets('an outgoing card stack is tinted for the sent side', (
      tester,
    ) async {
      final a = _pdf('a.pdf');
      final b = _pdf('b.pdf');

      await pumpBubble(
        tester,
        _message([a, b]),
        alignment: BubbleAlignment.right,
      );

      final fills = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CometChatAudiosBubble),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.constraints?.maxHeight == 56)
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toSet();
      expect(fills, {Colors.white.withValues(alpha: 0.14)});
    });
  });

  group('the busy state', () {
    testWidgets('a player row shows the sent-side spinner while the picker is '
        'open', (tester) async {
      final gate = Completer<void>();
      channelGate = gate;
      final a = _audio('standup.mp3');
      await pumpBubble(tester, _message([a]), alignment: BubbleAlignment.right);
      final t = Translations.of(
        tester.element(find.byType(CometChatAudiosBubble)),
      );

      await tester.tap(find.bySemanticsLabel(t.download));
      await tester.pump();

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // Outgoing rows draw the spinner in the primary colour on a white
      // circle; incoming ones the other way round.
      expect(spinner.valueColor, isA<AlwaysStoppedAnimation<Color>>());
      expect(
        (spinner.valueColor! as AlwaysStoppedAnimation<Color>).value,
        isNot(Colors.white),
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a file card swaps its download glyph for a spinner while the '
        'picker is open', (tester) async {
      final gate = Completer<void>();
      channelGate = gate;
      await pumpBubble(tester, _message([_pdf('contract.pdf')]));

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.file_download_outlined), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });
  });
}
