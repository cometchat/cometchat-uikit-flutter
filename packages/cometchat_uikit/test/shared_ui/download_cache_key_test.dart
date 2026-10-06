import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/download_cache_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// The download cache used to be keyed on the attachment file name alone, so a
/// second sender's `invoice.pdf` resolved to the first sender's local copy and
/// opened the wrong document. These tests pin the two properties that fix
/// depends on: different attachments never share a bucket, and the same
/// attachment keeps its bucket when its signed URL is refreshed.
void main() {
  group('DownloadCacheKey.bucketFor', () {
    test('two attachments sharing a file name get different buckets', () {
      // The reported defect: same name, different senders/messages.
      final a = DownloadCacheKey.bucketFor(
        'https://cdn.example/media/alice/1700000000/invoice.pdf',
      );
      final b = DownloadCacheKey.bucketFor(
        'https://cdn.example/media/bob/1700000001/invoice.pdf',
      );

      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(
        a,
        isNot(b),
        reason: 'colliding buckets would re-open the wrong sender\'s file',
      );
    });

    test('a refreshed signature keeps the same bucket', () {
      // CometChat media URLs are signed and time-limited. If the query fed the
      // hash, every refresh would miss the cache and re-download forever.
      const path = 'https://cdn.example/media/imgA.png';
      expect(
        DownloadCacheKey.bucketFor('$path?Expires=1&Signature=AAA'),
        DownloadCacheKey.bucketFor('$path?Expires=9&Signature=ZZZ'),
      );
    });

    test('an unsigned URL matches its own signed form', () {
      const path = 'https://cdn.example/media/report.pdf';
      expect(
        DownloadCacheKey.bucketFor(path),
        DownloadCacheKey.bucketFor('$path?Signature=live'),
      );
    });

    test('differs on the path even when the query is identical', () {
      expect(
        DownloadCacheKey.bucketFor('https://cdn.example/media/A.png?Sig=x'),
        isNot(
          DownloadCacheKey.bucketFor('https://cdn.example/media/B.png?Sig=x'),
        ),
      );
    });

    test('is stable across calls', () {
      const url = 'https://cdn.example/media/stable.bin?Signature=abc';
      expect(DownloadCacheKey.bucketFor(url), DownloadCacheKey.bucketFor(url));
    });

    test('is a filesystem-safe directory name', () {
      // The bucket becomes a real directory, so it must not contain separators,
      // a leading '-', or anything else needing escaping.
      final bucket = DownloadCacheKey.bucketFor(
        'https://cdn.example/media/nested/path/file name (1).pdf?a=b&c=d',
      );
      expect(bucket, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('empty URL yields no bucket, so callers keep the flat layout', () {
      expect(DownloadCacheKey.bucketFor(''), isEmpty);
    });

    test('distinguishes a large batch of sibling attachments', () {
      // Same file name across many messages — the exact shape of the collision.
      final buckets = <String>{
        for (var i = 0; i < 500; i++)
          DownloadCacheKey.bucketFor('https://cdn.example/media/$i/photo.jpg'),
      };
      expect(buckets, hasLength(500));
    });
  });

  group('DownloadCacheKey.stableIdentity', () {
    test('strips the query', () {
      expect(
        DownloadCacheKey.stableIdentity('https://c.example/a.png?Expires=1'),
        'https://c.example/a.png',
      );
    });

    test('leaves a query-less URL untouched', () {
      expect(
        DownloadCacheKey.stableIdentity('https://c.example/a.png'),
        'https://c.example/a.png',
      );
    });
  });
}
