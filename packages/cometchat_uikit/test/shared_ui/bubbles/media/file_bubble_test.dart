/// Behaviour pins for [CometChatFileBubble] — the single-attachment file card.
///
/// Three things decide what it draws: whether a local copy exists (the tap
/// opens it; no download affordance), whether a URL is known (tap downloads
/// then opens), and the file's extension (type icon + generated
/// "date • size • TYPE" subtitle).
///
///   flutter test test/shared_ui/bubbles/media/file_bubble_test.dart
library;

// CometChatFileBubble is deprecated in favour of CometChatFilesBubble but
// still renders the whole `enableMultipleAttachments: false` path.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/media_file_harness.dart';

late Directory _dir;
late List<MethodCall> _platformCalls;

const _uikitChannel = MethodChannel('cometchat_chat_uikit');

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Widget _bubble({
  String? title,
  String? subtitle,
  String? fileUrl,
  String? fileMimeType,
  String? fileExtension,
  int? fileSize,
  DateTime? dateTime,
  Map<String, dynamic>? metadata,
  BubbleAlignment? alignment,
  Key? key,
}) => Builder(
  builder: (context) => CometChatFileBubble(
    key: key,
    title: title,
    subtitle: subtitle,
    fileUrl: fileUrl,
    fileMimeType: fileMimeType,
    fileExtension: fileExtension,
    fileSize: fileSize,
    dateTime: dateTime,
    metadata: metadata,
    alignment: alignment,
    colorPalette: CometChatThemeHelper.getColorPalette(context),
    spacing: CometChatThemeHelper.getSpacing(context),
    typography: CometChatThemeHelper.getTypography(context),
  ),
);

Iterable<String> _assetNames(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<AssetImage>()
    .map((a) => a.assetName);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

String _subtitleOf(WidgetTester tester) =>
    _texts(tester).whereType<String>().last;

/// The bubble's leading type icon is the first asset image it draws.
String _typeIcon(WidgetTester tester) => _assetNames(tester).first;

void main() {
  setUp(() {
    _dir = createMediaTempDir();
    _platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_uikitChannel, (call) async {
          _platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_uikitChannel, null);
    disposeMediaTempDir(_dir);
  });

  group('type icon', () {
    testWidgets('each extension family gets its own icon', (tester) async {
      const cases = <String, String>{
        'docx': AssetConstants.fileDoc,
        'csv': AssetConstants.fileSpreadsheet,
        'png': AssetConstants.fileImage,
        'mp3': AssetConstants.fileAudio,
        'mp4': AssetConstants.fileVideo,
        'pdf': AssetConstants.filePdf,
        'zip': AssetConstants.fileZip,
        'pptx': AssetConstants.filePresentation,
        'txt': AssetConstants.fileText,
        'wat': AssetConstants.fileUnknown,
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(
          _host(
            _bubble(
              key: ValueKey(entry.key),
              title: 'doc.${entry.key}',
              fileExtension: entry.key,
            ),
          ),
        );
        await tester.pump();
        expect(_typeIcon(tester), entry.value, reason: entry.key);
      }
    });

    testWidgets('with no extension given, it is read off the URL — query '
        'string and fragment stripped', (tester) async {
      await tester.pumpWidget(
        _host(
          _bubble(
            title: 'report',
            fileUrl: 'https://cdn.test/a/report.pdf?token=abc#page=2',
          ),
        ),
      );
      await tester.pump();

      expect(_typeIcon(tester), AssetConstants.filePdf);
      expect(_subtitleOf(tester), endsWith('PDF'));
    });

    testWidgets('a URL with no dot in its last segment is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_bubble(title: 'blob', fileUrl: 'https://cdn.test/a/blob')),
      );
      await tester.pump();

      expect(_typeIcon(tester), AssetConstants.fileUnknown);
      // ...and the generated subtitle carries an empty TYPE segment.
      expect(_subtitleOf(tester), endsWith('• '));
    });

    testWidgets('no URL and no extension is unknown', (tester) async {
      await tester.pumpWidget(_host(_bubble(title: 'mystery')));
      await tester.pump();

      expect(_typeIcon(tester), AssetConstants.fileUnknown);
    });
  });

  group('generated subtitle', () {
    testWidgets('size is scaled up one unit at a time and capped at GB', (
      tester,
    ) async {
      const cases = <int, String>{
        0: '0 B',
        1024: '1024 B',
        2048: '2 KB',
        5 * 1024 * 1024: '5 MB',
        7 * 1024 * 1024 * 1024: '7 GB',
        // Over 1024 GB the recursion stops rather than reporting TB.
        3 * 1024 * 1024 * 1024 * 1024: '3072 GB',
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(
          _host(
            _bubble(
              key: ValueKey(entry.key),
              title: 'a.pdf',
              fileExtension: 'pdf',
              fileSize: entry.key,
              dateTime: DateTime(2023, 11, 14),
            ),
          ),
        );
        await tester.pump();
        expect(
          _subtitleOf(tester),
          '14 Nov, 2023 • ${entry.value} • PDF',
          reason: '${entry.key} bytes',
        );
      }
    });

    testWidgets('an explicit subtitle replaces the generated one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_bubble(title: 'a.pdf', subtitle: 'sent by Bob', fileSize: 2048)),
      );
      await tester.pump();

      expect(find.text('sent by Bob'), findsOneWidget);
      expect(_texts(tester).any((t) => t!.contains('KB')), isFalse);
    });

    testWidgets('a file with no name falls back to the localized "file" '
        'label', (tester) async {
      await tester.pumpWidget(
        _host(_bubble(fileUrl: 'https://cdn.test/x.pdf')),
      );
      await tester.pump();

      final title = _texts(tester).whereType<String>().first;
      expect(title, isNotEmpty);
      expect(title, isNot(contains('null')));
    });
  });

  group('open and download affordances', () {
    testWidgets('a locally available file opens through the platform channel '
        'and offers no download button', (tester) async {
      final path = writeRawFile(_dir, 'report.pdf', const [37, 80, 68, 70]);
      await tester.pumpWidget(
        _host(
          _bubble(
            title: 'report.pdf',
            fileUrl: 'https://cdn.test/report.pdf',
            fileMimeType: 'application/pdf',
            metadata: {'localPath': path},
          ),
        ),
      );
      await tester.pump();

      // No download glyph: the copy is already here.
      expect(_assetNames(tester), isNot(contains(AssetConstants.download)));

      await tester.tap(find.byType(CometChatFileBubble));
      await tester.pump();

      expect(_platformCalls.map((c) => c.method), contains('open_file'));
      final args = _platformCalls
          .firstWhere((c) => c.method == 'open_file')
          .arguments;
      expect(args, {'file_path': path, 'file_type': 'application/pdf'});
    });

    testWidgets('a URL-encoded local path is decoded before it is opened', (
      tester,
    ) async {
      final path = writeRawFile(_dir, 'my report.pdf', const [37, 80]);
      await tester.pumpWidget(
        _host(
          _bubble(
            title: 'my report.pdf',
            fileMimeType: 'application/pdf',
            metadata: {'localPath': path.replaceAll(' ', '%20')},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(CometChatFileBubble));
      await tester.pump();

      final args = _platformCalls
          .firstWhere((c) => c.method == 'open_file')
          .arguments;
      expect((args as Map)['file_path'], path);
    });

    testWidgets('a remote-only file shows the download glyph', (tester) async {
      await tester.pumpWidget(
        _host(
          _bubble(title: 'report.pdf', fileUrl: 'https://cdn.test/report.pdf'),
        ),
      );
      await tester.pump();

      expect(_assetNames(tester), contains(AssetConstants.download));
    });

    testWidgets('a file with neither a local copy nor a URL is inert', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_bubble(title: 'report.pdf')));
      await tester.pump();

      final detector = tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byType(CometChatFileBubble),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(detector.onTap, isNull);
      expect(_assetNames(tester), isNot(contains(AssetConstants.download)));
    });

    testWidgets('a failed download leaves the bubble offering the download '
        'again rather than stuck on a spinner', (tester) async {
      // No path_provider on a VM test host, so the download util fails and
      // returns null — the error path.
      await tester.pumpWidget(
        _host(
          _bubble(title: 'report.pdf', fileUrl: 'https://cdn.test/report.pdf'),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(CometChatFileBubble));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_assetNames(tester), contains(AssetConstants.download));
      expect(_assetNames(tester), isNot(contains(AssetConstants.close)));
      // Nothing was opened: there is no local copy to open.
      expect(_platformCalls.map((c) => c.method), isNot(contains('open_file')));
    });

    testWidgets('tapping the download glyph downloads without opening', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _bubble(title: 'report.pdf', fileUrl: 'https://cdn.test/report.pdf'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == AssetConstants.download,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(_platformCalls.map((c) => c.method), isNot(contains('open_file')));
      expect(_assetNames(tester), contains(AssetConstants.download));
    });
  });

  group('alignment', () {
    testWidgets('an outgoing bubble draws its title in white, an incoming one '
        'does not', (tester) async {
      Color? titleColor(WidgetTester t) =>
          t.widget<Text>(find.text('report.pdf')).style?.color;

      await tester.pumpWidget(
        _host(
          _bubble(
            key: const ValueKey('out'),
            title: 'report.pdf',
            alignment: BubbleAlignment.right,
          ),
        ),
      );
      await tester.pump();
      final outgoing = titleColor(tester);

      await tester.pumpWidget(
        _host(
          _bubble(
            key: const ValueKey('in'),
            title: 'report.pdf',
            alignment: BubbleAlignment.left,
          ),
        ),
      );
      await tester.pump();

      expect(outgoing, isNotNull);
      expect(titleColor(tester), isNot(outgoing));
    });

    testWidgets('an explicit style colour wins over the alignment default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatFileBubble(
              title: 'report.pdf',
              alignment: BubbleAlignment.right,
              style: const CometChatFileBubbleStyle(
                titleColor: Color(0xFF123456),
                subtitleColor: Color(0xFF654321),
              ),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('report.pdf')).style?.color,
        const Color(0xFF123456),
      );
      expect(
        tester.widget<Text>(find.text(_subtitleOf(tester))).style?.color,
        const Color(0xFF654321),
      );
    });
  });

  group('in-place reconfiguration', () {
    testWidgets('a new style is re-merged without recreating the bubble', (
      tester,
    ) async {
      Color? fillOf(WidgetTester t) {
        final c = t.widget<Container>(
          find
              .descendant(
                of: find.byType(CometChatFileBubble),
                matching: find.byType(Container),
              )
              .first,
        );
        return (c.decoration as BoxDecoration?)?.color;
      }

      Widget styled(Color color) => _host(
        Builder(
          builder: (context) => CometChatFileBubble(
            key: const ValueKey('same'),
            title: 'report.pdf',
            style: CometChatFileBubbleStyle(backgroundColor: color),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            typography: CometChatThemeHelper.getTypography(context),
          ),
        ),
      );

      await tester.pumpWidget(styled(const Color(0xFF111111)));
      await tester.pump();
      final stateBefore = tester.state(find.byType(CometChatFileBubble));
      expect(fillOf(tester), const Color(0xFF111111));

      await tester.pumpWidget(styled(const Color(0xFF222222)));
      await tester.pump();

      expect(fillOf(tester), const Color(0xFF222222));
      expect(
        tester.state(find.byType(CometChatFileBubble)),
        same(stateBefore),
        reason: 'the bubble must be reconfigured in place, not rebuilt',
      );
      // One row of content, not two stacked ones.
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('reconfiguring across file kinds swaps the icon rather than '
        'accumulating rows', (tester) async {
      await tester.pumpWidget(
        _host(
          _bubble(
            key: const ValueKey('same'),
            title: 'clip.mp4',
            fileExtension: 'mp4',
            fileSize: 2048,
          ),
        ),
      );
      await tester.pump();
      expect(_typeIcon(tester), AssetConstants.fileVideo);

      await tester.pumpWidget(
        _host(
          _bubble(
            key: const ValueKey('same'),
            title: 'sheet.csv',
            fileExtension: 'csv',
            fileSize: 4096,
          ),
        ),
      );
      await tester.pump();

      expect(_typeIcon(tester), AssetConstants.fileSpreadsheet);
      expect(find.text('clip.mp4'), findsNothing);
      expect(find.text('sheet.csv'), findsOneWidget);
      // Title + subtitle only — no leftovers from the previous kind.
      expect(find.byType(Text), findsNWidgets(2));
      expect(
        _assetNames(tester).where((a) => a.startsWith('assets/icons/file_')),
        hasLength(1),
      );
    });
  });
}
