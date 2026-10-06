/// Behavioural tests for the two single-audio widgets:
///
///  * [CometChatVoiceNoteBubble] — the classic waveform voice-note bubble
///    (`cometchat_voice_note_bubble.dart`)
///  * [CometChatAudioPlayer] — the lazy-loading gesture-waveform player
///    (`cometchat_audio_player.dart`)
///
/// Both drive the shared [AudioBubbleState], so they run against the
/// scriptable [FakeVideoPlayerPlatform]; the waveform extraction and the
/// save-as picker go through the Kit's `cometchat_chat_uikit` method channel,
/// mocked here.
library;

import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The waveform is an internal widget of the audio player: not exported, but
// it is the thing the seek gesture and the bar colours live on.
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/bubbles/audio_bubble/gesture_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uikitChannel = MethodChannel('cometchat_chat_uikit');
  late FakeVideoPlayerPlatform platform;
  late Directory tempDir;
  late List<MethodCall> channelCalls;

  /// Distinct ids per test so the singleton [AudioStateManager] cannot carry
  /// a player from one test into the next.
  int nextId = 500;

  setUp(() {
    platform = installFakeVideoPlayerPlatform();
    tempDir = Directory.systemTemp.createTempSync('cc_voice_note_test');
    channelCalls = <MethodCall>[];
    AudioStateManager().clearAll();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(uikitChannel, (call) async {
          channelCalls.add(call);
          if (call.method == 'extractWaveformFromFile' ||
              call.method == 'extractWaveformFast') {
            return List<double>.filled(40, 0.5);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(uikitChannel, null);
    AudioStateManager().clearAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// The waveform bars, scoped to the strip they live in.
  Finder waveBars() => find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(AnimatedContainer),
  );

  /// Releases the shared players. The Kit deliberately keeps an
  /// [AudioBubbleState] alive after its bubble is gone (so scrolling a list
  /// doesn't restart playback), and a live `video_player` controller polls its
  /// position on a timer — which would outlive the test otherwise.
  Future<void> releasePlayers(WidgetTester tester) async {
    AudioStateManager().clearAll();
    await tester.pump();
    await tester.pump();
  }

  String writeLocalAudio(String name) =>
      (File('${tempDir.path}/$name')..writeAsBytesSync(<int>[1, 2, 3])).path;

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    // Two frames: the async file check resolves, then the player initializes.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  // -------------------------------------------------------------------------
  // CometChatVoiceNoteBubble
  // -------------------------------------------------------------------------
  group('CometChatVoiceNoteBubble', () {
    Widget bubble({
      String? audioUrl = 'https://files.invalid/note.m4a',
      String? localPath,
      BubbleAlignment alignment = BubbleAlignment.left,
      CometChatVoiceNoteBubbleStyle? style,
      Map<String, dynamic>? extraMetadata,
      int? id,
      String? muid,
      double? width,
      Key? key,
    }) {
      return CometChatVoiceNoteBubble(
        key: key,
        audioUrl: audioUrl,
        title: 'note.m4a',
        alignment: alignment,
        style: style,
        width: width,
        id: id ?? nextId++,
        muid: muid,
        metadata: {
          AudioBubbleConstants.localPath: ?localPath,
          ...?extraMetadata,
        },
      );
    }

    testWidgets('isVoiceNote recognises both the current and the legacy '
        'marker, and nothing else', (tester) async {
      MediaMessage withMarker(Object? marker) {
        final m = MediaMessage(
          receiverUid: 'priya',
          receiverType: ReceiverTypeConstants.user,
          type: MessageTypeConstants.audio,
          muid: 'm',
        );
        m.metadata = marker == null ? null : {'audioType': marker};
        return m;
      }

      expect(
        CometChatVoiceNoteBubble.isVoiceNote(withMarker('voice_note')),
        isTrue,
      );
      expect(
        CometChatVoiceNoteBubble.isVoiceNote(withMarker('voiceNote')),
        isTrue,
      );
      expect(
        CometChatVoiceNoteBubble.isVoiceNote(withMarker('audio')),
        isFalse,
      );
      expect(CometChatVoiceNoteBubble.isVoiceNote(withMarker(null)), isFalse);
    });

    testWidgets('a cached recording opens its local file and shows its '
        'duration', (tester) async {
      final path = writeLocalAudio('note.m4a');
      await pump(tester, bubble(localPath: path));

      expect(platform.createdUris.single, 'file://$path');
      expect(find.text('00:00/00:30'), findsOneWidget);
    });

    testWidgets('an incoming recording that is not cached offers a download '
        'button; an outgoing one never does', (tester) async {
      await pump(tester, bubble());
      final t = Translations.of(
        tester.element(find.byType(CometChatVoiceNoteBubble)),
      );
      expect(find.byTooltip(t.download), findsOneWidget);

      await pump(tester, bubble(alignment: BubbleAlignment.right));
      expect(find.byTooltip(t.download), findsNothing);
    });

    testWidgets('a cached incoming recording hides the download button', (
      tester,
    ) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      final t = Translations.of(
        tester.element(find.byType(CometChatVoiceNoteBubble)),
      );

      expect(find.byTooltip(t.download), findsNothing);
    });

    testWidgets('tapping download shows progress, then settles back when the '
        'fetch fails', (tester) async {
      await pump(tester, bubble());
      final t = Translations.of(
        tester.element(find.byType(CometChatVoiceNoteBubble)),
      );

      await tester.tap(find.byTooltip(t.download));
      await tester.pumpAndSettle();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'the progress ring is taken down again',
      );
      expect(
        find.byTooltip(t.download),
        findsOneWidget,
        reason: 'a failed download leaves the button available to retry',
      );
    });

    testWidgets('play swaps the glyph and pause swaps it back', (tester) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(platform.log, contains('play:1'));

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(platform.log, contains('pause:1'));

      await releasePlayers(tester);
    });

    testWidgets('the waveform animates only while playing', (tester) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      final idleBars = tester
          .widgetList<AnimatedContainer>(waveBars())
          .map((c) => c.constraints?.maxHeight)
          .toList();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      // One tick of the 500ms bar animation.
      await tester.pump(const Duration(milliseconds: 600));

      final playingBars = tester
          .widgetList<AnimatedContainer>(waveBars())
          .map((c) => c.constraints?.maxHeight)
          .toList();
      expect(playingBars, hasLength(idleBars.length));
      expect(
        playingBars,
        isNot(equals(idleBars)),
        reason: 'the timer-driven heights replace the static waveform',
      );

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      await tester.pump();
      // Back on the deterministic idle waveform, which is stable per index.
      expect(
        tester
            .widgetList<AnimatedContainer>(waveBars())
            .map((c) => c.constraints?.maxHeight)
            .toList(),
        idleBars,
      );

      await releasePlayers(tester);
    });

    testWidgets('the idle waveform is identical across two separate bubbles — '
        'no random flicker on rebuild', (tester) async {
      await pump(tester, bubble(id: 4001));
      final first = tester
          .widgetList<AnimatedContainer>(waveBars())
          .map((c) => c.constraints?.maxHeight)
          .toList();

      await pump(tester, bubble(id: 4002));
      final second = tester
          .widgetList<AnimatedContainer>(waveBars())
          .map((c) => c.constraints?.maxHeight)
          .toList();

      expect(second, first);
    });

    testWidgets('a recorder-preview bubble draws the long waveform', (
      tester,
    ) async {
      await pump(tester, bubble(key: const ValueKey('plain')));
      final normal = waveBars().evaluate().length;

      await pump(
        tester,
        bubble(
          key: const ValueKey('recorder'),
          extraMetadata: const {AudioBubbleConstants.usedByMediaRecorder: true},
        ),
      );

      expect(normal, 43);
      expect(waveBars(), findsNWidgets(130));
    });

    testWidgets('two bubbles for the same muid share one player', (
      tester,
    ) async {
      final path = writeLocalAudio('note.m4a');
      // The optimistic send (id 0) and the acked message (real id) differ in
      // id but not in muid.
      await pump(tester, bubble(localPath: path, id: 0, muid: 'stable-muid'));
      expect(platform.createdUris, hasLength(1));

      await pump(
        tester,
        bubble(localPath: path, id: 7788, muid: 'stable-muid'),
      );

      expect(
        platform.createdUris,
        hasLength(1),
        reason: 'a second player on the same recording races the first',
      );
    });

    testWidgets('a pause broadcast from another player stops this one', (
      tester,
    ) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: 999999, action: AudioBubbleActions.pausePlayer),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('a stop broadcast rewinds this one', (tester) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: 999999, action: AudioBubbleActions.stopPlayer),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('00:00/00:30'), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('the widget style beats the theme for every painted part', (
      tester,
    ) async {
      const style = CometChatVoiceNoteBubbleStyle(
        backgroundColor: Color(0xFF101010),
        playIconBackgroundColor: Color(0xFF202020),
        playIconColor: Color(0xFF303030),
        audioBarColor: Color(0xFF404040),
        durationTextColor: Color(0xFF505050),
        downloadIconColor: Color(0xFF606060),
      );
      await pump(tester, bubble(style: style));

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CometChatVoiceNoteBubble),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration as BoxDecoration?)?.color,
        const Color(0xFF101010),
      );
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        const Color(0xFF202020),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF303030),
      );
      expect(
        tester.widget<Text>(find.textContaining('00:00/').first).style?.color,
        const Color(0xFF505050),
      );
      final bar = tester.widgetList<AnimatedContainer>(waveBars()).first;
      expect(
        (bar.decoration as BoxDecoration?)?.color,
        const Color(0xFF404040),
      );
    });

    testWidgets('a style swapped in after mount repaints the waveform', (
      tester,
    ) async {
      final key = GlobalKey();
      Widget withStyle(CometChatVoiceNoteBubbleStyle? style) => MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CometChatVoiceNoteBubble(
              key: key,
              audioUrl: 'https://files.invalid/note.m4a',
              title: 'note.m4a',
              alignment: BubbleAlignment.left,
              id: 4100,
              style: style,
              metadata: const {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(withStyle(null));
      await tester.pump();

      await tester.pumpWidget(
        withStyle(
          const CometChatVoiceNoteBubbleStyle(audioBarColor: Color(0xFF8899AA)),
        ),
      );
      await tester.pump();

      final bar = tester.widgetList<AnimatedContainer>(waveBars()).first;
      expect(
        (bar.decoration as BoxDecoration?)?.color,
        const Color(0xFF8899AA),
      );
    });

    testWidgets('pre-cached theme values swapped in after mount are adopted', (
      tester,
    ) async {
      const key = ValueKey('themed');
      final paletteA = CometChatColorPalette(primary: const Color(0xFF010203));
      final paletteB = CometChatColorPalette(primary: const Color(0xFF040506));

      Widget withPalette(CometChatColorPalette palette) => MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CometChatVoiceNoteBubble(
              key: key,
              audioUrl: 'https://files.invalid/note.m4a',
              title: 'note.m4a',
              alignment: BubbleAlignment.left,
              id: 4200,
              colorPalette: palette,
              spacing: CometChatSpacing(padding1: 4),
              typography: CometChatTypography(),
              metadata: const {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(withPalette(paletteA));
      await tester.pump();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF010203),
      );

      await tester.pumpWidget(withPalette(paletteB));
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF040506),
        reason: 'the cached palette is refreshed, not frozen at mount',
      );
    });

    testWidgets('disposing mid-playback leaves no timer running', (
      tester,
    ) async {
      await pump(tester, bubble(localPath: writeLocalAudio('note.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      // A surviving 500ms bar timer would trip the pending-timer check here.
      // (The shared player is released separately — the Kit keeps it alive on
      // purpose so scrolling a list does not restart playback.)
      await tester.pump(const Duration(seconds: 2));
      await releasePlayers(tester);

      expect(find.byType(CometChatVoiceNoteBubble), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // CometChatAudioPlayer
  // -------------------------------------------------------------------------
  group('CometChatAudioPlayer', () {
    Widget player({
      String? audioUrl = 'https://files.invalid/clip.m4a',
      String? localPath,
      int? durationMs,
      BubbleAlignment alignment = BubbleAlignment.left,
      CometChatVoiceNoteBubbleStyle? style,
      int? id,
    }) {
      return SizedBox(
        width: 260,
        child: CometChatAudioPlayer(
          audioUrl: audioUrl,
          title: 'clip.m4a',
          alignment: alignment,
          style: style,
          id: id ?? nextId++,
          metadata: {
            AudioBubbleConstants.localPath: ?localPath,
            'audioDurationMs': ?durationMs,
          },
        ),
      );
    }

    testWidgets('an un-cached clip shows a play button and no real clock', (
      tester,
    ) async {
      await pump(tester, player());

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('00:00 / --:--'), findsOneWidget);
      expect(
        platform.createdUris,
        isEmpty,
        reason: 'nothing is opened until the file is on the device',
      );
    });

    testWidgets("the sender's stamped duration is shown before anything is "
        'loaded', (tester) async {
      await pump(tester, player(durationMs: 95000));

      expect(find.text('00:00 / 01:35'), findsOneWidget);
    });

    testWidgets('a cached clip opens its player and shows the real duration', (
      tester,
    ) async {
      final path = writeLocalAudio('clip.m4a');
      await pump(tester, player(localPath: path));

      expect(platform.createdUris.single, 'file://$path');
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('00:00 / 00:30'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('a cached clip extracts its waveform through the platform', (
      tester,
    ) async {
      await pump(tester, player(localPath: writeLocalAudio('clip.m4a')));

      expect(
        channelCalls.map((c) => c.method),
        contains('extractWaveformFromFile'),
      );
      final wave = tester.widget<GestureWaveform>(find.byType(GestureWaveform));
      expect(wave.enabled, isTrue);
      expect(wave.onSeek, isNotNull);
      expect(wave.amplitudes, everyElement(0.5));
    });

    testWidgets('the waveform is inert until the clip is on the device', (
      tester,
    ) async {
      await pump(tester, player());

      final wave = tester.widget<GestureWaveform>(find.byType(GestureWaveform));
      expect(wave.enabled, isFalse);
      expect(wave.onSeek, isNull);
    });

    testWidgets('dragging the waveform seeks the player', (tester) async {
      await pump(tester, player(localPath: writeLocalAudio('clip.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      platform.log.clear();

      final box = tester.getRect(find.byType(GestureWaveform));
      await tester.tapAt(Offset(box.left + box.width / 2, box.center.dy));
      await tester.pump();
      await tester.pump();

      expect(
        platform.log.where((e) => e.startsWith('seek:')),
        isNotEmpty,
        reason: 'a tap at the halfway mark scrubs the audio',
      );
      expect(find.text('00:15 / 00:30'), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('tapping play on an un-cached clip shows the preparing '
        'spinner and recovers when the fetch fails', (tester) async {
      await pump(tester, player());

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.play_arrow_rounded),
        findsOneWidget,
        reason: 'the button comes back so the user can try again',
      );
    });

    testWidgets('a pause broadcast from another player pauses this one', (
      tester,
    ) async {
      await pump(tester, player(localPath: writeLocalAudio('clip.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: 888888, action: AudioBubbleActions.pausePlayer),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('a style or palette swapped in after mount is adopted', (
      tester,
    ) async {
      const key = ValueKey('player-themed');
      Widget build(
        CometChatVoiceNoteBubbleStyle style,
        CometChatColorPalette palette,
      ) => MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: CometChatAudioPlayer(
                key: key,
                audioUrl: 'https://files.invalid/clip.m4a',
                title: 'clip.m4a',
                alignment: BubbleAlignment.left,
                id: 4300,
                style: style,
                colorPalette: palette,
                spacing: CometChatSpacing(padding2: 8),
                typography: CometChatTypography(),
                metadata: const {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        build(
          const CometChatVoiceNoteBubbleStyle(playIconColor: Color(0xFF010203)),
          CometChatColorPalette(white: const Color(0xFFF0F0F0)),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF010203),
      );

      await tester.pumpWidget(
        build(
          const CometChatVoiceNoteBubbleStyle(playIconColor: Color(0xFF040506)),
          CometChatColorPalette(white: const Color(0xFF0F0F0F)),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF040506),
      );
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        const Color(0xFF0F0F0F),
      );
    });

    testWidgets('a stop broadcast from another player rewinds this one', (
      tester,
    ) async {
      await pump(tester, player(localPath: writeLocalAudio('clip.m4a')));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: 777777, action: AudioBubbleActions.stopPlayer),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('00:00 / 00:30'), findsOneWidget);

      await releasePlayers(tester);
    });

    testWidgets('the play button is announced to screen readers', (
      tester,
    ) async {
      await pump(tester, player());
      final t = Translations.of(tester.element(find.byType(GestureWaveform)));

      expect(find.bySemanticsLabel(t.play), findsOneWidget);
    });

    testWidgets('the widget style beats the theme', (tester) async {
      await pump(
        tester,
        player(
          style: const CometChatVoiceNoteBubbleStyle(
            playIconBackgroundColor: Color(0xFF111222),
            playIconColor: Color(0xFF333444),
            audioBarColor: Color(0xFF555666),
            durationTextColor: Color(0xFF777888),
          ),
        ),
      );

      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        const Color(0xFF111222),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        const Color(0xFF333444),
      );
      final wave = tester.widget<GestureWaveform>(find.byType(GestureWaveform));
      expect(wave.playedColor, const Color(0xFF555666));
      expect(
        wave.unplayedColor,
        const Color(0xFF555666).withValues(alpha: 0.5),
      );
      expect(
        tester.widget<Text>(find.text('00:00 / --:--')).style?.color,
        const Color(0xFF777888),
      );
    });

    testWidgets('an outgoing clip paints its waveform white', (tester) async {
      await pump(tester, player(alignment: BubbleAlignment.right));

      final wave = tester.widget<GestureWaveform>(find.byType(GestureWaveform));
      expect(wave.playedColor, Colors.white);
    });
  });
}
