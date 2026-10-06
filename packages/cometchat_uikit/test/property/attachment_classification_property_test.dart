/// Properties of attachment classification (`AttachmentUtils`), file-type
/// styling (`FileTypeStyle`) and the download cache key (`DownloadCacheKey`).
///
///   flutter test test/property/attachment_classification_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/download_cache_key.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';

Attachment _attachment(MimeCase c, {String url = 'https://cdn.example/f'}) =>
    Attachment(url, c.fileName, c.fileExtension, c.mime, 1024);

String _describeAll(List<MimeCase> cases) => cases.join('\n         ');

/// A signed media URL: a stable path plus a rotating signature.
String _genPath(Random r) =>
    'https://${genAlnum(r)}.example.com/${genAlnum(r)}/${genAlnum(r)}.${r.pick(kImageExts)}';

String _genSignature(Random r) =>
    '?Expires=${r.nextInt(1 << 31)}&Signature=${genAlnum(r, min: 8, max: 24)}'
    '&Key-Pair-Id=${genAlnum(r)}';

void main() {
  test('classification is total: every MIME/extension pair lands in exactly '
      'one of media, audio or files, and nothing is dropped or reordered', () {
    forAll((r) => List.generate(r.nextInt(12), (_) => genMimeCase(r)), (cases) {
      final all = cases.map(_attachment).toList();
      final split = AttachmentUtils.categorize(all);

      expect(
        split.media.length + split.audio.length + split.files.length,
        all.length,
      );
      for (final a in all) {
        final homes = [
          split.media.contains(a),
          split.audio.contains(a),
          split.files.contains(a),
        ].where((h) => h).length;
        expect(homes, 1, reason: '${a.fileName} / ${a.fileMimeType}');
      }
      for (final section in [split.media, split.audio, split.files]) {
        final positions = section.map(all.indexOf).toList();
        expect(positions, [...positions]..sort(), reason: 'order kept');
      }
      expect(split.files.every(AttachmentUtils.isNonPreviewableFile), isTrue);
    }, describe: _describeAll);
  });

  test('classification ignores the case of the extension and of the MIME '
      'type', () {
    forAll((r) => (genMimeCase(r), r.nextInt(1 << 30)), (input) {
      final (c, salt) = input;
      final r = Random(salt);
      final shouted = MimeCase(
        scrambleCase(r, c.mime),
        c.baseName,
        scrambleCase(r, c.ext),
        scrambleCase(r, c.fileExtension),
      );
      final a = _attachment(c);
      final b = _attachment(shouted);
      expect(AttachmentUtils.isImage(b), AttachmentUtils.isImage(a));
      expect(AttachmentUtils.isVideo(b), AttachmentUtils.isVideo(a));
      expect(AttachmentUtils.isAudio(b), AttachmentUtils.isAudio(a));
      expect(AttachmentUtils.isGif(b), AttachmentUtils.isGif(a));
    }, cases: 300);
  });

  test('nothing is ever both video and audio, and a known audio extension '
      'always wins over a video MIME type', () {
    forAll(genMimeCase, (c) {
      final a = _attachment(c);
      expect(AttachmentUtils.isVideo(a) && AttachmentUtils.isAudio(a), isFalse);
    }, cases: 300);

    forAll((r) => (r.pick(kAudioExts), genAlnum(r)), (input) {
      final (ext, name) = input;
      final a = Attachment('u', '$name.$ext', ext, 'video/$ext', 1);
      expect(AttachmentUtils.isAudio(a), isTrue);
      expect(AttachmentUtils.isVideo(a), isFalse);
      expect(AttachmentUtils.deriveType([a]), 'audio');
    });
  });

  test('the pair form used by the composer tray agrees with the attachment '
      'form used at send time', () {
    forAll(genMimeCase, (c) {
      final a = _attachment(c);
      expect(
        AttachmentUtils.isImageOf(
          c.mime,
          c.fileName,
          fileExtension: c.fileExtension,
        ),
        AttachmentUtils.isImage(a),
      );
      expect(
        AttachmentUtils.isVideoOf(
          c.mime,
          c.fileName,
          fileExtension: c.fileExtension,
        ),
        AttachmentUtils.isVideo(a),
      );
      expect(
        AttachmentUtils.isAudioOf(
          c.mime,
          c.fileName,
          fileExtension: c.fileExtension,
        ),
        AttachmentUtils.isAudio(a),
      );
    }, cases: 300);
  });

  test('the derived message type is one of the four wire types and is a '
      'media type only when every attachment is of that kind', () {
    forAll((r) => List.generate(r.nextInt(8), (_) => genMimeCase(r)), (cases) {
      final all = cases.map(_attachment).toList();
      final type = AttachmentUtils.deriveType(all);

      expect(['image', 'video', 'audio', 'file'], contains(type));
      if (all.isEmpty) expect(type, 'file');
      if (type == 'image') expect(all.every(AttachmentUtils.isImage), isTrue);
      if (type == 'video') expect(all.every(AttachmentUtils.isVideo), isTrue);
      if (type == 'audio') expect(all.every(AttachmentUtils.isAudio), isTrue);
      if (type == 'file' && all.isNotEmpty) {
        expect(all.every(AttachmentUtils.isImage), isFalse);
        expect(all.every(AttachmentUtils.isVideo), isFalse);
        expect(all.every(AttachmentUtils.isAudio), isFalse);
      }
      // Adding a plain document always demotes the message to `file`.
      final withDoc = [
        ...all,
        Attachment('u', 'a.pdf', 'pdf', 'application/pdf', 1),
      ];
      expect(AttachmentUtils.deriveType(withDoc), 'file');
    }, describe: _describeAll);
  });

  test('a single-attachment message exposes exactly that attachment, and the '
      'plural list wins when both are set', () {
    forAll((r) => List.generate(r.between(1, 6), (_) => genMimeCase(r)), (
      cases,
    ) {
      final all = cases.map(_attachment).toList();
      MediaMessage message({Attachment? single, List<Attachment>? many}) =>
          MediaMessage(
            receiverUid: 'u',
            receiverType: CometChatReceiverType.user,
            type: MessageTypeConstants.file,
            attachment: single,
            attachments: many,
          );

      expect(AttachmentUtils.attachmentsOf(message()), isEmpty);
      expect(AttachmentUtils.attachmentsOf(message(single: all.first)), [
        all.first,
      ]);
      expect(
        AttachmentUtils.attachmentsOf(message(single: all.last, many: all)),
        all,
      );
      expect(
        AttachmentUtils.attachmentsOf(message(single: all.first, many: [])),
        [all.first],
      );
    }, describe: _describeAll);
  });

  test('file-type styling is total and ignores the case of the extension, '
      'whether it comes from the name or from the explicit field', () {
    forAll((r) => (genMimeCase(r), r.nextInt(1 << 30)), (input) {
      final (c, salt) = input;
      final r = Random(salt);
      final lower = FileTypeStyle.of(
        fileName: c.fileName.toLowerCase(),
        mimeType: c.mime,
      );
      final mixed = FileTypeStyle.of(
        fileName: scrambleCase(r, c.fileName),
        mimeType: c.mime,
      );
      expect(mixed.color, lower.color);
      expect(mixed.icon, lower.icon);

      // An explicit extension beats the one in the file name.
      final explicit = FileTypeStyle.of(
        fileName: 'report.zip',
        extension: scrambleCase(r, 'pdf'),
      );
      expect(explicit.icon, FileTypeStyle.of(fileName: 'x.pdf').icon);
      expect(
        FileTypeStyle.extOf(c.fileName),
        FileTypeStyle.extOf(c.fileName).toLowerCase(),
      );
    }, cases: 300);
  });

  test('file-type styling recognises audio only when the MIME type is lower '
      'case', () {
    // FINDING: `FileTypeStyle.of` tests `mimeType.startsWith('audio/')`
    // without folding case, while `AttachmentUtils` — the classifier the same
    // tray and bubble use to decide the KIND — folds it (RFC 2045 §5.1, and
    // its doc comment says pickers do hand back upper-case types). A file
    // reported as `AUDIO/MPEG` with an unknown extension is therefore
    // classified as audio but drawn with the generic-document colour and
    // glyph.
    final audioStyle = FileTypeStyle.of(fileName: 'x', mimeType: 'audio/mpeg');
    final generic = FileTypeStyle.of(fileName: 'x', mimeType: 'text/plain');
    expect(audioStyle.icon, isNot(generic.icon));

    forAll(
      (r) {
        final mime = scrambleCase(
          r,
          'audio/${r.pick(['mpeg', 'ogg', 'x-wav'])}',
        );
        return mime.startsWith('audio/') ? mime.replaceFirst('a', 'A') : mime;
      },
      (mime) {
        expect(AttachmentUtils.isAudioOf(mime, 'clip'), isTrue);
        expect(
          FileTypeStyle.of(fileName: 'clip', mimeType: mime).icon,
          generic.icon,
        );
      },
    );
  });

  test('the download cache key ignores a rotating query-string signature', () {
    forAll((r) => (_genPath(r), _genSignature(r), _genSignature(r)), (input) {
      final (path, sigA, sigB) = input;
      final bare = DownloadCacheKey.bucketFor(path);
      expect(DownloadCacheKey.bucketFor('$path$sigA'), bare);
      expect(DownloadCacheKey.bucketFor('$path$sigB'), bare);
      expect(DownloadCacheKey.stableIdentity('$path$sigA'), path);
    });
  });

  test('different paths map to different cache keys, and every key is a safe '
      'directory name', () {
    final seen = <String, String>{};
    forAll(_genPath, (path) {
      final key = DownloadCacheKey.bucketFor(path);
      expect(RegExp(r'^[0-9a-f]{1,16}$').hasMatch(key), isTrue, reason: key);
      final previous = seen[key];
      expect(
        previous == null || previous == path,
        isTrue,
        reason: 'collision: $previous',
      );
      seen[key] = path;
    }, cases: 2000);
    expect(DownloadCacheKey.bucketFor(''), '');
  });

  test('the cache key of arbitrary text is deterministic and never starts '
      'with a minus sign', () {
    forAll((r) => genUnicode(r, maxParts: 10), (url) {
      final key = DownloadCacheKey.bucketFor(url);
      expect(key, DownloadCacheKey.bucketFor(url));
      expect(key.startsWith('-'), isFalse);
      expect(key.isEmpty, url.isEmpty);
    }, cases: 300);
  });
}
