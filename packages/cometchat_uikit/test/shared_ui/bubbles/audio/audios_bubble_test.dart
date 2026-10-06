/// Behavioural tests for the multi-audio message bubble
/// (`cometchat_audios_bubble.dart`): what it renders for 0/1/N attachments,
/// the "+N more" collapse, the clock's four fallbacks, the play button's
/// download → error → retry cycle, the trailing save-as button, and the file
/// card an attachment that isn't actually audio falls back to.
///
/// Downloads go through `BubbleUtils.downloadFile`, which cannot succeed on a
/// desktop test host (see the report), so the download branches are exercised
/// through their failure path — which is the one that has a visible UI state.
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _audio(String name, {int size = 1024}) =>
    Attachment('https://files.invalid/$name', name, 'mp3', 'audio/mpeg', size);

MediaMessage _message(
  List<Attachment> attachments, {
  String? caption,
  Map<String, dynamic>? metadata,
}) {
  final m = MediaMessage(
    receiverUid: 'priya',
    receiverType: ReceiverTypeConstants.user,
    type: MessageTypeConstants.audio,
    muid: 'audios-bubble-test',
  );
  m.attachments = attachments;
  m.caption = caption;
  m.metadata = metadata;
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uikitChannel = MethodChannel('cometchat_chat_uikit');
  late List<MethodCall> channelCalls;
  Completer<void>? channelGate;

  setUp(() {
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
  });

  Future<void> pumpBubble(
    WidgetTester tester,
    MediaMessage message, {
    BubbleAlignment alignment = BubbleAlignment.left,
    CometChatAudiosBubbleStyle? style,
    double maxWidth = 280,
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
              style: style,
              maxWidth: maxWidth,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('what the bubble renders', () {
    testWidgets('a message with neither attachments nor a caption renders '
        'nothing', (tester) async {
      await pumpBubble(tester, _message(const []));

      expect(find.byType(Slider), findsNothing);
      expect(tester.getSize(find.byType(CometChatAudiosBubble)), Size.zero);
    });

    testWidgets('a caption survives even when the attachments are missing', (
      tester,
    ) async {
      await pumpBubble(tester, _message(const [], caption: 'Listen to this'));

      expect(
        find.textContaining('Listen to this', findRichText: true),
        findsWidgets,
      );
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('one attachment is one player row, with the file name', (
      tester,
    ) async {
      await pumpBubble(tester, _message([_audio('standup.mp3')]));

      expect(find.text('standup.mp3'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('the caption renders under the rows', (tester) async {
      await pumpBubble(
        tester,
        _message([_audio('a.mp3')], caption: 'Everything for Thursday'),
      );

      expect(
        tester
            .getTopLeft(
              find
                  .textContaining('Everything for Thursday', findRichText: true)
                  .first,
            )
            .dy,
        greaterThan(tester.getTopLeft(find.text('a.mp3')).dy),
      );
    });

    testWidgets('a whitespace-only caption is not a caption', (tester) async {
      await pumpBubble(tester, _message([_audio('a.mp3')], caption: '   '));

      expect(find.byType(CometChatMediaCaption), findsNothing);
    });

    testWidgets('the bubble is capped at maxWidth', (tester) async {
      await pumpBubble(tester, _message([_audio('a.mp3')]), maxWidth: 200);

      expect(tester.getSize(find.byType(CometChatAudiosBubble)).width, 200);
    });

    testWidgets('a narrow screen wins over maxWidth (72% of it)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBubble(tester, _message([_audio('a.mp3')]), maxWidth: 280);

      expect(
        tester.getSize(find.byType(CometChatAudiosBubble)).width,
        closeTo(300 * 0.72, 0.01),
      );
    });
  });

  group('the "+N more" collapse', () {
    List<Attachment> many(int n) =>
        List.generate(n, (i) => _audio('track-$i.mp3'));

    testWidgets('three audios are all shown, with no toggle', (tester) async {
      await pumpBubble(tester, _message(many(3)));

      expect(find.byType(Slider), findsNWidgets(3));
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('four audios collapse to three plus a "+1" toggle', (
      tester,
    ) async {
      await pumpBubble(tester, _message(many(4)));

      expect(find.byType(Slider), findsNWidgets(3));
      expect(find.text('track-3.mp3'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      final t = Translations.of(
        tester.element(find.byType(CometChatAudiosBubble)),
      );
      expect(
        find.text(t.fileListShowMore.replaceAll('{count}', '1')),
        findsOneWidget,
      );
    });

    testWidgets('expanding shows the rest and offers "show less"', (
      tester,
    ) async {
      await pumpBubble(tester, _message(many(5)));

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNWidgets(5));
      expect(find.text('track-4.mp3'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(3));
    });
  });

  group('the clock under the slider', () {
    testWidgets('an un-downloaded audio with no stamped duration shows its '
        'size', (tester) async {
      await pumpBubble(
        tester,
        _message([
          _audio('small.mp3', size: 900),
          _audio('kb.mp3', size: 3 * 1024),
          _audio('mb.mp3', size: 3 * 1024 * 1024 + 512 * 1024),
        ]),
      );

      expect(find.text('900 B'), findsOneWidget);
      expect(find.text('3 KB'), findsOneWidget);
      expect(find.text('3.5 MB'), findsOneWidget);
    });

    testWidgets('a sender-stamped duration is shown up front instead of the '
        'size', (tester) async {
      await pumpBubble(
        tester,
        _message(
          [_audio('a.mp3'), _audio('b.mp3')],
          metadata: {
            'audioDurationsMs': [32000, null],
          },
        ),
      );

      expect(find.text('00:00/00:32'), findsOneWidget);
      expect(
        find.text('1 KB'),
        findsOneWidget,
        reason: 'the second row has no stamped duration and falls back',
      );
    });

    testWidgets('a zero or non-integer stamped duration falls back to the '
        'size', (tester) async {
      await pumpBubble(
        tester,
        _message(
          [_audio('a.mp3'), _audio('b.mp3')],
          metadata: {
            'audioDurationsMs': [0, 'nonsense'],
          },
        ),
      );

      expect(find.text('1 KB'), findsNWidgets(2));
    });

    testWidgets('a durations value that is not a list is ignored', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        _message([_audio('a.mp3')], metadata: {'audioDurationsMs': 32000}),
      );

      expect(find.text('1 KB'), findsOneWidget);
    });

    testWidgets('an hour-plus stamped duration keeps the mm:ss shape of the '
        'reference clock', (tester) async {
      await pumpBubble(
        tester,
        _message(
          [_audio('long.mp3')],
          metadata: {
            'audioDurationsMs': [3723000],
          },
        ),
      );

      // `_fmt` prints total minutes, not h:mm — 62 minutes reads as "62:03".
      expect(find.text('00:00/62:03'), findsOneWidget);
    });
  });

  group('the play button', () {
    testWidgets('a failed download surfaces a retryable error on the button', (
      tester,
    ) async {
      await pumpBubble(tester, _message([_audio('a.mp3')]));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason: 'the row keeps its player and offers a retry, not a file card',
      );

      // The error button is the retry: tapping it runs the whole download →
      // init cycle again, and the row stays a player row throughout rather
      // than flipping into a file card.
      await tester.tap(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('a.mp3'), findsOneWidget);
    });

    testWidgets('the slider is inert until the player is ready', (
      tester,
    ) async {
      await pumpBubble(tester, _message([_audio('a.mp3')]));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
      expect(slider.value, 0.0);
      expect(slider.max, 1.0, reason: 'a zero duration must not make max 0');
    });
  });

  group('the trailing save-as button', () {
    testWidgets('it hands the url, name and mime type to the platform picker', (
      tester,
    ) async {
      await pumpBubble(tester, _message([_audio('a.mp3')]));
      final t = Translations.of(
        tester.element(find.byType(CometChatAudiosBubble)),
      );

      await tester.tap(find.bySemanticsLabel(t.download));
      await tester.pump();
      await tester.pump();

      expect(channelCalls.single.method, 'saveFileWithPicker');
      final args = channelCalls.single.arguments as Map;
      expect(args['url'], 'https://files.invalid/a.mp3');
      expect(args['fileName'], 'a.mp3');
      expect(args['mimeType'], 'audio/mpeg');
      expect(
        args.containsKey('path'),
        isFalse,
        reason: 'nothing is cached, so there is no local copy to reuse',
      );
    });

    testWidgets('it is replaced by a spinner while the picker is open', (
      tester,
    ) async {
      final gate = Completer<void>();
      channelGate = gate;
      await pumpBubble(tester, _message([_audio('a.mp3')]));
      final t = Translations.of(
        tester.element(find.byType(CometChatAudiosBubble)),
      );

      await tester.tap(find.bySemanticsLabel(t.download));
      await tester.pump();

      expect(find.bySemanticsLabel(t.download), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(t.download), findsOneWidget);
    });
  });

  group('an attachment that is not actually audio', () {
    Attachment pdf() => Attachment(
      'https://files.invalid/contract.pdf',
      'contract.pdf',
      'pdf',
      'application/pdf',
      2048,
    );

    testWidgets('renders as a file card — no player, no clock', (tester) async {
      await pumpBubble(tester, _message([pdf()]));

      expect(find.text('contract.pdf'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('its download button saves through the platform picker', (
      tester,
    ) async {
      await pumpBubble(tester, _message([pdf()]));

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pump();
      await tester.pump();

      expect(channelCalls.single.method, 'saveFileWithPicker');
      expect(
        (channelCalls.single.arguments as Map)['mimeType'],
        'application/pdf',
      );
    });

    testWidgets('tapping the card tries to fetch and open the file', (
      tester,
    ) async {
      await pumpBubble(tester, _message([pdf()]));

      await tester.tap(find.text('contract.pdf'));
      await tester.pumpAndSettle();

      // The fetch cannot succeed on a desktop test host, so no open_file call
      // is made — but the row recovers rather than staying stuck.
      expect(channelCalls.map((c) => c.method), isNot(contains('open_file')));
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('an empty url makes the card inert', (tester) async {
      await pumpBubble(
        tester,
        _message([Attachment('', 'ghost.pdf', 'pdf', 'application/pdf', 10)]),
      );

      await tester.tap(find.text('ghost.pdf'));
      await tester.pumpAndSettle();

      expect(channelCalls, isEmpty);
    });

    testWidgets('a mismatched file and a real audio stack to the same height', (
      tester,
    ) async {
      await pumpBubble(tester, _message([pdf(), _audio('a.mp3')]));

      final heights = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CometChatAudiosBubble),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.constraints?.maxHeight)
          .whereType<double>()
          // The 36px minimum on the file card's IconButton is not a row.
          .where((h) => h > 40)
          .toSet();
      expect(heights, {56.0});
    });
  });

  group('styling', () {
    testWidgets('the widget style overrides the row fill, slider and icons', (
      tester,
    ) async {
      const style = CometChatAudiosBubbleStyle(
        rowBackgroundColor: Color(0xFF112233),
        playIconBackgroundColor: Color(0xFF445566),
        playIconColor: Color(0xFF778899),
        sliderActiveColor: Color(0xFFAABBCC),
        nameTextStyle: TextStyle(fontSize: 15),
      );
      await pumpBubble(tester, _message([_audio('a.mp3')]), style: style);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, const Color(0xFF445566));
      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded));
      expect(icon.color, const Color(0xFF778899));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.activeColor, const Color(0xFFAABBCC));
      final name = tester.widget<Text>(find.text('a.mp3'));
      expect(name.style?.fontSize, 15);
    });

    testWidgets('outgoing rows use the sent palette', (tester) async {
      await pumpBubble(
        tester,
        _message([_audio('a.mp3'), _audio('b.mp3')]),
        alignment: BubbleAlignment.right,
      );

      final name = tester.widget<Text>(find.text('a.mp3'));
      expect(name.style?.color, Colors.white);
    });
  });
}
