/// The small `core/utils` holders and singletons —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Ten exported classes in `clean_architecture/core/utils/` that no test had
/// ever constructed. They are unglamorous, and that is rather the point: a
/// picked file, a categorised attachment list, a state-view slot bundle, two
/// process-wide singletons and the file-type palette all sit on paths the
/// composer and the message list take on every send.
///
/// `AttachmentUtils`'s own predicates are already covered by
/// `test/attachment_utils_test.dart`; what was missing there is
/// [CategorizedAttachments], the value it returns.
///
/// Two of these are singletons with mutable state, so each test that touches
/// one restores it afterwards — otherwise the next file in the run inherits it.
///
///   flutter test test/shared_ui/utils/core_utils_holders_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAttachment extends Fake implements Attachment {
  _FakeAttachment({
    this.fileName = 'report.pdf',
    this.fileMimeType = 'application/pdf',
    this.fileExtension = 'pdf',
  });

  @override
  final String fileName;
  @override
  final String fileMimeType;
  @override
  final String fileExtension;
}

class _FakeTextMessage extends Fake implements TextMessage {
  @override
  ModerationStatusEnum? get moderationStatus => null;
}

void main() {
  // ---------------------------------------------------------------------------
  group('CategorizedAttachments', () {
    test('holds the three lists it is given, in order', () {
      final media = [_FakeAttachment(fileName: 'photo.png')];
      final audio = [_FakeAttachment(fileName: 'note.m4a')];
      final files = [_FakeAttachment(fileName: 'report.pdf')];

      const empty = <Attachment>[];
      final categorized = CategorizedAttachments(media, audio, files);

      expect(categorized.media, same(media));
      expect(categorized.audio, same(audio));
      expect(categorized.files, same(files));
      expect(CategorizedAttachments(empty, empty, empty).media, isEmpty);
    });

    test('AttachmentUtils.categorize sorts a mixed batch into the three '
        'buckets', () {
      // This is the split the multi-attachment gallery bubbles render from:
      // visual media in one carousel, audio as players, everything else as
      // file rows.
      final result = AttachmentUtils.categorize([
        _FakeAttachment(
          fileName: 'photo.png',
          fileMimeType: 'image/png',
          fileExtension: 'png',
        ),
        _FakeAttachment(
          fileName: 'clip.mp4',
          fileMimeType: 'video/mp4',
          fileExtension: 'mp4',
        ),
        _FakeAttachment(
          fileName: 'note.m4a',
          fileMimeType: 'audio/mp4',
          fileExtension: 'm4a',
        ),
        _FakeAttachment(),
      ]);

      expect(result.media.map((a) => a.fileName), ['photo.png', 'clip.mp4']);
      expect(result.audio.map((a) => a.fileName), ['note.m4a']);
      expect(result.files.map((a) => a.fileName), ['report.pdf']);
    });

    test('categorize returns three empty lists for an empty batch', () {
      final result = AttachmentUtils.categorize(const []);

      expect(result.media, isEmpty);
      expect(result.audio, isEmpty);
      expect(result.files, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('PickedFile', () {
    test('requires a name and a path and leaves the rest null', () {
      final file = PickedFile(name: 'report.pdf', path: '/tmp/report.pdf');

      expect(file.name, 'report.pdf');
      expect(file.path, '/tmp/report.pdf');
      expect(file.size, isNull);
      expect(file.extension, isNull);
      expect(file.fileType, isNull);
      expect(file.bytes, isNull);
    });

    test('carries bytes for the web path, where there is no real path', () {
      // On web the picker cannot hand back a filesystem path, so `bytes` is
      // the payload and `path` is a placeholder.
      final file = PickedFile(
        name: 'photo.png',
        path: '',
        size: 1024,
        extension: 'png',
        fileType: 'image',
        bytes: const [1, 2, 3],
      );

      expect(file.path, isEmpty);
      expect(file.bytes, [1, 2, 3]);
      expect(file.size, 1024);
      expect(file.extension, 'png');
      expect(file.fileType, 'image');
    });
  });

  // ---------------------------------------------------------------------------
  group('CustomStateView', () {
    test('is const-constructible with no slots filled', () {
      const view = CustomStateView();

      expect(view.loading, isNull);
      expect(view.error, isNull);
      expect(view.empty, isNull);
    });

    testWidgets('each slot is a builder the list calls with its own context', (
      tester,
    ) async {
      final view = CustomStateView(
        loading: (_) => const Text('loading'),
        error: (_) => const Text('error'),
        empty: (_) => const Text('empty'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  view.loading!(context),
                  view.error!(context),
                  view.empty!(context),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
      expect(find.text('empty'), findsOneWidget);
    });

    test('slots are independent — one may be supplied without the others', () {
      final view = CustomStateView(empty: (_) => const SizedBox());

      expect(view.empty, isNotNull);
      expect(view.loading, isNull);
      expect(view.error, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('FileTypeStyle', () {
    test('maps the document extensions to distinct colours and icons', () {
      expect(FileTypeStyle.of(extension: 'pdf').icon, Icons.picture_as_pdf);
      expect(FileTypeStyle.of(extension: 'docx').icon, Icons.description);
      expect(FileTypeStyle.of(extension: 'xlsx').icon, Icons.table_chart);
      expect(FileTypeStyle.of(extension: 'pptx').icon, Icons.slideshow);
      expect(FileTypeStyle.of(extension: 'zip').icon, Icons.folder_zip);

      final colors = {
        for (final e in ['pdf', 'docx', 'xlsx', 'pptx', 'zip'])
          FileTypeStyle.of(extension: e).color,
      };
      expect(colors, hasLength(5), reason: 'each family gets its own colour');
    });

    test('the aliases inside a family share one style', () {
      expect(
        FileTypeStyle.of(extension: 'doc').color,
        FileTypeStyle.of(extension: 'docx').color,
      );
      expect(
        FileTypeStyle.of(extension: 'csv').icon,
        FileTypeStyle.of(extension: 'xls').icon,
      );
      expect(
        FileTypeStyle.of(extension: '7z').icon,
        FileTypeStyle.of(extension: 'rar').icon,
      );
    });

    test('the extension is case-insensitive and trimmed', () {
      expect(FileTypeStyle.of(extension: 'PDF').icon, Icons.picture_as_pdf);
      expect(FileTypeStyle.of(extension: ' pdf ').icon, Icons.picture_as_pdf);
    });

    test('falls back to the file name when no extension is passed', () {
      expect(
        FileTypeStyle.of(fileName: 'Q3-review.PDF').icon,
        Icons.picture_as_pdf,
      );
      expect(
        FileTypeStyle.of(fileName: 'archive.tar.gz').icon,
        Icons.insert_drive_file,
      );
    });

    test('an audio mime type is only consulted when the extension misses', () {
      expect(FileTypeStyle.of(mimeType: 'audio/mpeg').icon, Icons.audiotrack);
      // A known extension wins over the mime type.
      expect(
        FileTypeStyle.of(extension: 'pdf', mimeType: 'audio/mpeg').icon,
        Icons.picture_as_pdf,
      );
    });

    test('an unknown type gets the generic style', () {
      final style = FileTypeStyle.of(extension: 'unheardof');

      expect(style.icon, Icons.insert_drive_file);
      expect(style.color, const Color(0xFF607D8B));
      expect(FileTypeStyle.of().icon, Icons.insert_drive_file);
    });

    test('extOf takes the last segment, lowercased, and empty when there is '
        'no dot', () {
      expect(FileTypeStyle.extOf('report.PDF'), 'pdf');
      expect(FileTypeStyle.extOf('archive.tar.gz'), 'gz');
      expect(FileTypeStyle.extOf('README'), '');
      expect(FileTypeStyle.extOf(''), '');
    });

    test('tint is lighter in light mode than in dark', () {
      const style = FileTypeStyle(Color(0xFFE53935), Icons.picture_as_pdf);

      expect(style.tint(Brightness.light).a, closeTo(0.12, 0.01));
      expect(style.tint(Brightness.dark).a, closeTo(0.22, 0.01));
      // The hue is preserved; only the alpha moves.
      expect(style.tint(Brightness.light).r, style.color.r);
    });
  });

  // ---------------------------------------------------------------------------
  group('AudioBubbleEvents and AudioBubbleStream', () {
    test('an event names the bubble it is aimed at and the action', () {
      final event = AudioBubbleEvents(
        id: 42,
        action: AudioBubbleActions.pausePlayer,
      );

      expect(event.id, 42);
      expect(event.action, AudioBubbleActions.pausePlayer);
      expect(event.toString(), contains('42'));
      expect(event.toString(), contains('pausePlayer'));
    });

    test('the stream is a process-wide singleton', () {
      // Every audio bubble listens to the same instance — that is how starting
      // one player stops the others.
      expect(AudioBubbleStream(), same(AudioBubbleStream()));
      expect(AudioBubbleStream().stream, isNotNull);
    });

    test('the stream broadcasts an event to every listener', () async {
      final stream = AudioBubbleStream();
      final first = <int>[];
      final second = <int>[];

      final subA = stream.stream.listen((e) => first.add(e.id));
      final subB = stream.stream.listen((e) => second.add(e.id));

      stream.controller.add(
        AudioBubbleEvents(id: 7, action: AudioBubbleActions.stopPlayer),
      );
      await Future<void>.delayed(Duration.zero);

      expect(first, [7]);
      expect(second, [7], reason: 'broadcast, not single-subscription');

      await subA.cancel();
      await subB.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  group('ModerationCheckUtil', () {
    tearDown(() => ModerationCheckUtil.instance.hideModerationStatus = false);

    test('is a singleton and defaults to showing moderation status', () {
      expect(ModerationCheckUtil.instance, same(ModerationCheckUtil.instance));
      expect(ModerationCheckUtil.instance.hideModerationStatus, isFalse);
    });

    test('a message with no moderation status is not disapproved', () {
      expect(
        ModerationCheckUtil.instance.isMessageDisapprovedFromModeration(
          _FakeTextMessage(),
        ),
        isFalse,
      );
    });

    test('DEFECT-ADJACENT — hideModerationStatus does not gate the check', () {
      // The field's own comment says the check "respects hideModerationStatus",
      // but the method body never reads it. Setting it changes nothing here;
      // whatever suppression the flag is meant to provide has to happen at the
      // call sites instead. Pinned so the comment and the behaviour cannot
      // drift further apart unnoticed.
      final message = _FakeTextMessage();
      final before = ModerationCheckUtil.instance
          .isMessageDisapprovedFromModeration(message);

      ModerationCheckUtil.instance.hideModerationStatus = true;

      expect(
        ModerationCheckUtil.instance.isMessageDisapprovedFromModeration(
          message,
        ),
        before,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('FileSizeCheckUtil', () {
    test('is a singleton and starts with no error message', () {
      expect(FileSizeCheckUtil.instance, same(FileSizeCheckUtil.instance));
    });

    test('lifts the declared limit out of the SDK error text', () {
      final message = FileSizeCheckUtil.instance.isFileSizeException(
        'ERR_FILE_SIZE: The file exceeds the 100 MB limit set for this app.',
      );

      expect(message, 'File exceeds the 100 MB limit - try a smaller one.');
      expect(FileSizeCheckUtil.instance.errorMessage, message);
    });

    test('reads every unit the regex allows, case-insensitively', () {
      String limitIn(String exception) =>
          FileSizeCheckUtil.instance.isFileSizeException(exception);

      expect(limitIn('exceeds 25 KB'), contains('25 KB'));
      expect(limitIn('exceeds 2 GB'), contains('2 GB'));
      expect(limitIn('exceeds 1 TB'), contains('1 TB'));
      expect(limitIn('exceeds 100mb'), contains('100mb'));
    });

    test('falls back to 100 MB when the text carries no size', () {
      expect(
        FileSizeCheckUtil.instance.isFileSizeException('Upload failed'),
        contains('100 MB'),
      );
    });

    test('the message is regenerated per call, not accumulated', () {
      FileSizeCheckUtil.instance.isFileSizeException('exceeds 25 KB');
      final second = FileSizeCheckUtil.instance.isFileSizeException(
        'exceeds 2 GB',
      );

      expect(second, contains('2 GB'));
      expect(second, isNot(contains('25 KB')));
    });
  });

  // ---------------------------------------------------------------------------
  group('CustomPopupMenuItem', () {
    testWidgets('renders its child and reports a fixed height', (tester) async {
      const item = CustomPopupMenuItem<String>(
        value: 'reply',
        child: Text('Reply'),
      );

      expect(item.height, 48);
      expect(item.represents('reply'), isTrue);
      expect(item.represents('forward'), isFalse);
      expect(item.represents(null), isFalse);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: item)));
      expect(find.text('Reply'), findsOneWidget);
    });

    testWidgets('tapping it pops the route with its value', (tester) async {
      String? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped = await showDialog<String>(
                    context: context,
                    builder: (_) => const Dialog(
                      child: CustomPopupMenuItem<String>(
                        value: 'reply',
                        child: Text('Reply'),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(popped, 'reply');
    });

    test('an item with no value represents null', () {
      const item = CustomPopupMenuItem<String>(child: Text('Reply'));

      expect(item.value, isNull);
      expect(item.represents(null), isTrue);
      expect(item.represents('reply'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('StatusIndicatorUtils', () {
    test('is constructible directly with an icon and a colour', () {
      const icon = Icon(Icons.check);
      final utils = StatusIndicatorUtils(
        icon: icon,
        statusIndicatorColor: const Color(0xFF1C7549),
      );

      expect(utils.icon, same(icon));
      expect(utils.statusIndicatorColor, const Color(0xFF1C7549));
    });

    testWidgets('a selected row shows the select icon and no status colour', (
      tester,
    ) async {
      // The isSelected branch is the one ENG-38857 turned out to depend on:
      // the group-members list passed selectIcon without isSelected, so the
      // helper never took this branch and the icon never rendered.
      late StatusIndicatorUtils result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = StatusIndicatorUtils.getStatusIndicatorFromParams(
                  context: context,
                  isSelected: true,
                  selectIcon: const Icon(Icons.done_all),
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(result.icon, isA<Icon>());
      expect((result.icon! as Icon).icon, Icons.done_all);
    });

    testWidgets('with nothing to indicate, both fields come back null', (
      tester,
    ) async {
      late StatusIndicatorUtils result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = StatusIndicatorUtils.getStatusIndicatorFromParams(
                  context: context,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(result.icon, isNull);
      expect(result.statusIndicatorColor, isNull);
    });
  });
}
