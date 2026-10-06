// Foundation tests for AttachmentUtils (multiple-attachments feature, Part A).

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _att(String mime, {String name = 'f', String ext = 'x'}) =>
    Attachment('https://example.com/$name', name, ext, mime, 1024);

MediaMessage _msg({List<Attachment>? attachments, Attachment? attachment}) {
  final m = MediaMessage(
    receiverUid: 'u1',
    type: 'image',
    receiverType: 'user',
  );
  m.attachments = attachments;
  m.attachment = attachment;
  return m;
}

void main() {
  group('attachmentsOf', () {
    test('returns the plural array when present', () {
      final list = [_att('image/jpeg'), _att('image/png')];
      expect(AttachmentUtils.attachmentsOf(_msg(attachments: list)).length, 2);
    });

    test('falls back to the singular attachment', () {
      final single = _att('application/pdf');
      final out = AttachmentUtils.attachmentsOf(_msg(attachment: single));
      expect(out.length, 1);
      // Back-compat: attachmentsOf(m).first == m.attachment (Property 11).
      expect(identical(out.first, single), isTrue);
    });

    test('returns empty when there are none', () {
      expect(AttachmentUtils.attachmentsOf(_msg()), isEmpty);
    });
  });

  group('categorize', () {
    test('splits media / audio / files by mimeType', () {
      final all = [
        _att('image/jpeg'),
        _att('video/mp4'),
        _att('audio/mp4'),
        _att('application/pdf'),
        _att('text/plain'),
      ];
      final c = AttachmentUtils.categorize(all);
      expect(c.media.length, 2); // image + video
      expect(c.audio.length, 1);
      expect(c.files.length, 2); // pdf + txt
    });

    test('preserves order within a section', () {
      final a = _att('image/jpeg', name: 'a');
      final b = _att('image/png', name: 'b');
      final c = AttachmentUtils.categorize([a, b]);
      expect(c.media[0].fileName, 'a');
      expect(c.media[1].fileName, 'b');
    });
  });

  group('deriveType', () {
    test('all images -> image', () {
      expect(
        AttachmentUtils.deriveType([_att('image/jpeg'), _att('image/png')]),
        'image',
      );
    });
    test('all videos -> video', () {
      expect(AttachmentUtils.deriveType([_att('video/mp4')]), 'video');
    });
    test('mixed kinds -> file', () {
      expect(
        AttachmentUtils.deriveType([_att('image/jpeg'), _att('audio/mp4')]),
        'file',
      );
    });
    test('empty -> file', () {
      expect(AttachmentUtils.deriveType(const []), 'file');
    });
  });

  group('ogg: audio extension beats a video/* mime', () {
    // Ogg is registered as BOTH audio/ogg and video/ogg; servers report the
    // video form for audio-only files. Typing those `video` put them in the
    // media grid — no player row, no download button.
    final oggAsVideoMime = _att('video/ogg', name: 'clip.ogg', ext: 'ogg');

    test('isAudio true, isVideo false for video/ogg with an .ogg name', () {
      expect(AttachmentUtils.isAudio(oggAsVideoMime), isTrue);
      expect(AttachmentUtils.isVideo(oggAsVideoMime), isFalse);
      expect(AttachmentUtils.isVisualMedia(oggAsVideoMime), isFalse);
    });

    test('deriveType -> audio, not video', () {
      expect(AttachmentUtils.deriveType([oggAsVideoMime]), 'audio');
    });

    test('categorize puts it in audio, not media', () {
      final c = AttachmentUtils.categorize([oggAsVideoMime]);
      expect(c.audio, hasLength(1));
      expect(c.media, isEmpty);
    });

    test('a real video is still a video', () {
      final mp4 = _att('video/mp4', name: 'v.mp4', ext: 'mp4');
      expect(AttachmentUtils.isVideo(mp4), isTrue);
      expect(AttachmentUtils.isAudio(mp4), isFalse);
      expect(AttachmentUtils.deriveType([mp4]), 'video');
    });

    test('audio/ogg and application/ogg still resolve to audio', () {
      for (final mime in ['audio/ogg', 'application/ogg']) {
        final a = _att(mime, name: 'a.ogg', ext: 'ogg');
        expect(AttachmentUtils.isAudio(a), isTrue, reason: mime);
        expect(AttachmentUtils.isVideo(a), isFalse, reason: mime);
      }
    });
  });

  group('isNonPreviewableFile (type-mismatch / no-preview signal)', () {
    test('true for a genuine non-media file (pdf / text / octet-stream)', () {
      for (final mime in [
        'application/pdf',
        'text/plain',
        'application/octet-stream',
      ]) {
        expect(
          AttachmentUtils.isNonPreviewableFile(_att(mime, name: 'a.$mime')),
          isTrue,
          reason: mime,
        );
      }
    });

    test('false for image / video / audio (all previewable)', () {
      expect(AttachmentUtils.isNonPreviewableFile(_att('image/jpeg')), isFalse);
      expect(AttachmentUtils.isNonPreviewableFile(_att('video/mp4')), isFalse);
      expect(AttachmentUtils.isNonPreviewableFile(_att('audio/mpeg')), isFalse);
    });

    test('detects by extension when the mime is unhelpful', () {
      // A PDF mis-typed as octet-stream is still a non-previewable file...
      final pdf = _att('application/octet-stream', name: 'doc.pdf', ext: 'pdf');
      expect(AttachmentUtils.isNonPreviewableFile(pdf), isTrue);
      // ...while an image with an octet-stream mime is still previewable by ext.
      final png = _att('application/octet-stream', name: 'p.png', ext: 'png');
      expect(AttachmentUtils.isNonPreviewableFile(png), isFalse);
    });

    test('a PDF sent in an image message is a mismatch (the core case)', () {
      // The bubble is chosen by message.type=image, but the file is a PDF.
      final m = _msg(
        attachments: [_att('application/pdf', name: 'r.pdf', ext: 'pdf')],
      );
      final a = AttachmentUtils.attachmentsOf(m).first;
      expect(AttachmentUtils.isNonPreviewableFile(a), isTrue);
    });
  });
}
