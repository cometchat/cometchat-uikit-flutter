/// Keying rule for the on-device download cache.
///
/// Downloaded attachments used to be stored under their file name alone, so two
/// different messages each carrying `invoice.pdf` mapped to the same local
/// file — opening the second one silently handed back the first sender's
/// document. Every cached file now lives in a per-attachment bucket derived
/// from its URL, which restores a unique key.
///
/// Pure and platform-independent on purpose: the native, web and stub file
/// utilities all agree on one rule, and it stays unit-testable without a
/// filesystem.
library;

class DownloadCacheKey {
  DownloadCacheKey._();

  /// The bucket directory name for an attachment served from [fileUrl].
  ///
  /// Only the **path** feeds the hash — any `?query` is stripped first.
  /// CometChat media URLs are signed and time-limited, so `Expires`/`Signature`
  /// are regenerated for the very same file; including them would produce a new
  /// bucket on every refresh, missing the cache and re-downloading forever.
  /// Matching on the query-stripped path is the same stable-identity rule
  /// `ThumbnailExtractionUtil` uses to bind thumbnails to attachments.
  ///
  /// Returns an empty string for an empty URL, which callers treat as "no
  /// bucket" and fall back to the flat legacy layout.
  static String bucketFor(String fileUrl) {
    if (fileUrl.isEmpty) return '';
    return _fnv1a64(stableIdentity(fileUrl));
  }

  /// The portion of [fileUrl] that identifies the file across signature
  /// refreshes: everything before the first `?`.
  static String stableIdentity(String fileUrl) {
    final q = fileUrl.indexOf('?');
    return q == -1 ? fileUrl : fileUrl.substring(0, q);
  }

  /// 64-bit FNV-1a, rendered as lowercase hex.
  ///
  /// A hand-rolled hash rather than a `crypto` digest because `crypto` is only
  /// a transitive dependency of this package, and this is a local cache key —
  /// not a security boundary. The sign bit is masked off so the directory name
  /// never carries a leading `-`.
  static String _fnv1a64(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return (hash & 0x7fffffffffffffff).toRadixString(16);
  }
}
