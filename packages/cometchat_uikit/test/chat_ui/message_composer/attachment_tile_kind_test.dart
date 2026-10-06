import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The composer tray classified staged files by mimeType alone while the send
/// path classifies by mimeType OR extension ([AttachmentUtils]). The two
/// disagreed, so the preview did not match what was actually sent. These tests
/// pin that a staged tile and the attachment it becomes always agree.
void main() {
  AttachmentTile tile(String mimeType, String name) =>
      AttachmentTile(fileId: 'f', name: name, mimeType: mimeType, size: 1);

  Attachment attachment(String mimeType, String name) {
    final ext = name.contains('.') ? name.split('.').last : '';
    return Attachment('https://example.com/$name', name, ext, mimeType, 1);
  }

  /// The kind string the send path stamps (mirrors kindOf in the controller).
  String sendKind(Attachment a) {
    if (AttachmentUtils.isImage(a)) return 'image';
    if (AttachmentUtils.isVideo(a)) return 'video';
    if (AttachmentUtils.isAudio(a)) return 'audio';
    return 'file';
  }

  String tileKind(AttachmentTile t) {
    if (t.isImage) return 'image';
    if (t.isVideo) return 'video';
    if (t.isAudio) return 'audio';
    return 'file';
  }

  group('staged tile kind matches the sent kind', () {
    // (mimeType, fileName, expected kind)
    const cases = <List<String>>[
      // The reported mismatches: a generic mimeType with a media extension.
      ['application/octet-stream', 'clip.m4v', 'video'],
      ['application/octet-stream', 'song.flac', 'audio'],
      ['', 'movie.mkv', 'video'],
      ['', 'track.opus', 'audio'],
      ['application/octet-stream', 'photo.heic', 'image'],
      // Ogg is registered as both audio/ogg and video/ogg; servers report the
      // video form for audio-only files. Audio must win on both sides.
      ['video/ogg', 'voice.ogg', 'audio'],
      // Normal, agreeing cases must not regress.
      ['image/png', 'a.png', 'image'],
      ['video/mp4', 'a.mp4', 'video'],
      ['audio/mpeg', 'a.mp3', 'audio'],
      ['application/pdf', 'a.pdf', 'file'],
      // A real file with no media signal anywhere stays a file.
      ['application/octet-stream', 'archive.zip', 'file'],
      // MIME types are case-insensitive (RFC 2045) — an uppercase type from a
      // picker or server must classify the same as a lowercase one.
      ['IMAGE/JPEG', 'shot', 'image'],
      ['Video/MP4', 'clip', 'video'],
      ['AUDIO/MPEG', 'song', 'audio'],
    ];

    for (final c in cases) {
      final mime = c[0];
      final name = c[1];
      final expected = c[2];

      test('${mime.isEmpty ? '<no mime>' : mime} + $name => $expected', () {
        expect(
          tileKind(tile(mime, name)),
          expected,
          reason: 'tray preview classified it wrongly',
        );
        expect(
          sendKind(attachment(mime, name)),
          expected,
          reason: 'send path classified it wrongly',
        );
      });
    }
  });

  test('a name with no extension falls back to the mimeType', () {
    expect(tileKind(tile('image/png', 'pasted-image')), 'image');
    expect(tileKind(tile('application/octet-stream', 'blob')), 'file');
  });
}
