/// Render-verified prop matrix for [CometChatFileBubble] and
/// [CometChatVoiceNoteBubble] — Track 3 PROP1 (ENG-38931).
///
/// Both bubbles take their palette, spacing and typography as parameters
/// rather than reading them off the theme, so every case resolves them from
/// the context inside a Builder — which is what their bubble factories do.
/// [CometChatFileBubble] is deprecated in favour of [CometChatFilesBubble] but
/// still renders the whole `enableMultipleAttachments: false` path, so it has
/// to keep working.
///
///   flutter test test/shared_ui/bubbles/single_attachment_bubble_props_test.dart
library;

// CometChatFileBubble is deprecated but still live on the single-attachment
// path, which is exactly what these cases cover.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

Iterable<Color?> _fills(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color);

Container _outer(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container).first);

void main() {
  group('CometChatFileBubble', () {
    testWidgets('title renders as the bubble title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('subtitle replaces the generated one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                subtitle: 'sent by Bob',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('sent by Bob'), findsOneWidget);
    });

    testWidgets('fileExtension appears in the generated subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                fileExtension: 'pdf',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_texts(tester).any((t) => t!.contains('PDF')), isTrue);
    });

    testWidgets('fileSize appears in the generated subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                fileSize: 2048,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_texts(tester).any((t) => t!.contains('KB')), isTrue);
    });

    testWidgets('dateTime appears in the generated subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                dateTime: _sentAt,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_texts(tester).any((t) => t!.contains('2023')), isTrue);
    });

    testWidgets('fileUrl makes the bubble tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                fileUrl: 'https://example.com/report.pdf',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .any((g) => g.onTap != null),
        isTrue,
      );
    });

    testWidgets('fileMimeType drives the generated extension', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report',
                fileMimeType: 'application/pdf',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('report'), findsOneWidget);
    });

    testWidgets('id identifies the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                id: 7,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('metadata is accepted alongside the explicit fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                metadata: const <String, dynamic>{'k': 'v'},
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('alignment right recolours the title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                alignment: BubbleAlignment.right,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('width and height size the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                width: 251,
                height: 91,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).constraints?.maxWidth, 251);
      expect(_outer(tester).constraints?.maxHeight, 91);
    });

    testWidgets('padding and margin wrap the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                padding: const EdgeInsets.only(left: 11),
                margin: const EdgeInsets.only(top: 13),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).padding, const EdgeInsets.only(left: 11));
      expect(_outer(tester).margin, const EdgeInsets.only(top: 13));
    });

    testWidgets('style colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                style: const CometChatFileBubbleStyle(
                  backgroundColor: Color(0xFF180101),
                ),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF180101)));
    });

    testWidgets('colorPalette, spacing and typography drive the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatFileBubble(
                title: 'report.pdf',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).padding, isNotNull);
      expect(
        tester.widget<Text>(find.text('report.pdf')).style?.fontSize,
        isNotNull,
      );
    });
  });

  // The voice note bubble renders a scrubber and a clock, not a title: its
  // title, id, muid and metadata feed the player tag and the download
  // filename. Those cases assert the bubble renders with the property set,
  // which is as far as a render assertion can honestly reach.
  group('CometChatVoiceNoteBubble', () {
    testWidgets('title renders as the bubble title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('audioUrl drives the player', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                audioUrl: 'https://example.com/a.mp3',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('muid identifies the in-flight note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                muid: 'm1',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('id identifies the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                id: 8,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('metadata is accepted alongside the explicit fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                metadata: const <String, dynamic>{'k': 'v'},
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('alignment right recolours the controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                alignment: BubbleAlignment.right,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });

    testWidgets('playIcon replaces the default play control', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                playIcon: const Icon(Icons.play_arrow, key: Key('play')),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('play')), findsOneWidget);
    });

    testWidgets('pauseIcon is accepted for the playing state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                playIcon: const Icon(Icons.play_arrow, key: Key('play')),
                pauseIcon: const Icon(Icons.pause, key: Key('pause')),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('play')), findsOneWidget);
    });

    testWidgets('width and height size the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                width: 251,
                height: 91,
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).constraints?.maxWidth, 251);
      expect(_outer(tester).constraints?.maxHeight, 91);
    });

    testWidgets('padding and margin wrap the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                padding: const EdgeInsets.only(left: 11),
                margin: const EdgeInsets.only(top: 13),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).padding, const EdgeInsets.only(left: 11));
      expect(_outer(tester).margin, const EdgeInsets.only(top: 13));
    });

    testWidgets('style colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                style: const CometChatVoiceNoteBubbleStyle(
                  backgroundColor: Color(0xFF180202),
                ),
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF180202)));
    });

    testWidgets('colorPalette, spacing and typography drive the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatVoiceNoteBubble(
                title: 'Voice note',
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_outer(tester).padding, isNotNull);
      expect(find.byType(CometChatVoiceNoteBubble), findsOneWidget);
    });
  });
}
