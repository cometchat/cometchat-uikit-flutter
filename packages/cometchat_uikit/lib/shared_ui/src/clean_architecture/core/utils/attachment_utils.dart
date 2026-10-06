import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter/widgets.dart' show BuildContext;

import '../constants/ui_kit_constants.dart';
import '../../../../l10n/translations.dart';

/// Result of categorizing a message's attachments into the three gallery
/// sections (see the multiple-attachments design, §8.0).
class CategorizedAttachments {
  /// `image/*` and `video/*` — rendered as the media grid.
  final List<Attachment> media;

  /// `audio/*` — rendered as inline audio players.
  final List<Attachment> audio;

  /// Everything else — rendered as the files card-list.
  final List<Attachment> files;

  const CategorizedAttachments(this.media, this.audio, this.files);
}

/// Helpers that give single- and multi-attachment [MediaMessage]s one code
/// path. The Flutter SDK exposes attachments as public fields (`attachments`
/// plural and `attachment` singular) rather than a `getAttachments()` method,
/// so [attachmentsOf] normalizes the two.
class AttachmentUtils {
  AttachmentUtils._();

  /// Returns every attachment on [message]: the plural `attachments` array when
  /// present, otherwise the legacy singular `attachment` wrapped in a list,
  /// otherwise empty. Guarantees `attachmentsOf(m).first == m.attachment` for a
  /// single-attachment message (back-compat property).
  static List<Attachment> attachmentsOf(MediaMessage message) {
    final list = message.attachments;
    if (list != null && list.isNotEmpty) return list;
    final single = message.attachment;
    if (single != null) return <Attachment>[single];
    return const <Attachment>[];
  }

  static const _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };
  static const _videoExts = {'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi', '3gp'};
  static const _audioExts = {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus', 'flac'};

  /// Lower-cased extension from a file name, falling back to a supplied
  /// `fileExtension` when the name carries none.
  static String _extOf(String fileName, String fileExtension) {
    final n = fileName.toLowerCase();
    final dot = n.lastIndexOf('.');
    if (dot >= 0 && dot < n.length - 1) return n.substring(dot + 1);
    return fileExtension.toLowerCase();
  }

  /// Lower-cased extension from the file name (falling back to `fileExtension`).
  static String _ext(Attachment a) => _extOf(a.fileName, a.fileExtension);

  /// Kind detection by **mimeType OR extension** over the raw pair, for callers
  /// that classify a file before an [Attachment] exists — notably the composer's
  /// staging tray. Sharing one rule keeps the tray preview identical to the kind
  /// the message is actually sent as; classifying the preview on mimeType alone
  /// made e.g. `.m4v`/`.flac` stage as generic file cards and `.ogg` reported as
  /// `video/ogg` preview as video, then send as audio.
  /// MIME types are case-insensitive (RFC 2045 §5.1) and a picker or server can
  /// hand back `IMAGE/JPEG`, so the type is folded before matching — as [isGif]
  /// already did.
  static bool _mimeIs(String mimeType, String prefix) =>
      mimeType.toLowerCase().startsWith(prefix);

  static bool isImageOf(
    String mimeType,
    String fileName, {
    String fileExtension = '',
  }) =>
      _mimeIs(mimeType, 'image/') ||
      _imageExts.contains(_extOf(fileName, fileExtension));

  /// See [isVideo] for why audio wins over an ambiguous `video/*` mime.
  static bool isVideoOf(
    String mimeType,
    String fileName, {
    String fileExtension = '',
  }) =>
      !isAudioOf(mimeType, fileName, fileExtension: fileExtension) &&
      (_mimeIs(mimeType, 'video/') ||
          _videoExts.contains(_extOf(fileName, fileExtension)));

  static bool isAudioOf(
    String mimeType,
    String fileName, {
    String fileExtension = '',
  }) =>
      _mimeIs(mimeType, 'audio/') ||
      _audioExts.contains(_extOf(fileName, fileExtension));

  /// Kind detection by **mimeType OR extension** — the server's mimeType is not
  /// always reliable (e.g. a video can arrive without a `video/*` type), so we
  /// also fall back to the file extension.
  static bool isImage(Attachment a) =>
      isImageOf(a.fileMimeType, a.fileName, fileExtension: a.fileExtension);

  /// A `video/*` mime does NOT win over an unambiguous audio extension. Ogg is
  /// registered as both `audio/ogg` and `video/ogg`, and servers report the
  /// video form for audio-only `.ogg`/`.opus` files — which made both this and
  /// [isAudio] true, and [deriveType] (video before audio) then typed the
  /// message `video`. It landed in the media grid: no player row, no download
  /// button. None of [_audioExts] is a video container, so preferring audio
  /// here is safe.
  static bool isVideo(Attachment a) =>
      isVideoOf(a.fileMimeType, a.fileName, fileExtension: a.fileExtension);

  static bool isAudio(Attachment a) =>
      isAudioOf(a.fileMimeType, a.fileName, fileExtension: a.fileExtension);

  /// `image/*` or `video/*` — the kinds that go into the media grid and the
  /// fullscreen pager.
  static bool isVisualMedia(Attachment a) => isImage(a) || isVideo(a);

  /// True when [a] can't be previewed inline anywhere — it is neither visual
  /// media (image/video) nor audio, by mimeType OR extension. This is the
  /// **type-mismatch** signal: an attachment that landed in a media/audio bubble
  /// (routed by the message `type` the sender stamped) but whose actual file is
  /// something else entirely (e.g. a PDF sent as an `image`/`audio` message).
  /// Such an attachment gets the "No preview available" fallback in the viewer
  /// and the doc-slash tile in the grid, instead of a broken render.
  ///
  /// Detection is by mimeType/extension only — a remote file can't be
  /// byte-sniffed without downloading it — so this is intentionally
  /// conservative: it fires only on a **positive** non-media signal, never on an
  /// unknown/ambiguous type, which is left to attempt-then-fail-soft.
  static bool isNonPreviewableFile(Attachment a) =>
      !isVisualMedia(a) && !isAudio(a);

  /// Animated GIF — gets a "GIF" corner tag on its grid cell / tray tile.
  static bool isGif(Attachment a) =>
      a.fileMimeType.toLowerCase() == 'image/gif' || _ext(a) == 'gif';

  /// Splits attachments into media / audio / files **by `mimeType`** (never by
  /// the message `type`), preserving order within each section.
  static CategorizedAttachments categorize(List<Attachment> all) {
    final media = <Attachment>[];
    final audio = <Attachment>[];
    final files = <Attachment>[];
    for (final a in all) {
      if (isVisualMedia(a)) {
        media.add(a);
      } else if (isAudio(a)) {
        audio.add(a);
      } else {
        files.add(a);
      }
    }
    return CategorizedAttachments(media, audio, files);
  }

  /// The UIKit-owned message-`type` derivation used at send time: all-image →
  /// `image`, all-video → `video`, all-audio → `audio`, anything mixed (or all
  /// non-media) → `file`.
  static String deriveType(List<Attachment> all) {
    if (all.isEmpty) return 'file';
    if (all.every(isImage)) return 'image';
    if (all.every(isVideo)) return 'video';
    if (all.every(isAudio)) return 'audio';
    return 'file';
  }

  /// A human-readable subtitle for [message] — shared by the composer's reply
  /// banner and a sent message's quoted-reply block. A multi-attachment
  /// MediaMessage reads as "N Images" / "N Videos" / "N Audios" / "N Files"
  /// (matching search's summaries) instead of the flat singular type label a
  /// single attachment gets.
  static String replySubtitleFor(BaseMessage message, BuildContext context) {
    if (message is MediaMessage) {
      final count = attachmentsOf(message).length;
      if (count > 1) {
        final countLabel = switch (message.type) {
          MessageTypeConstants.image => Translations.of(
            context,
          ).searchImagesCount,
          MessageTypeConstants.video => Translations.of(
            context,
          ).searchVideosCount,
          MessageTypeConstants.audio => Translations.of(
            context,
          ).searchAudiosCount,
          _ => Translations.of(context).searchFilesCount,
        };
        return countLabel.replaceAll('{count}', '$count');
      }
    }
    return singularSubtitleFor(message.type, context);
  }

  /// A last-message / list **preview** subtitle for [message] — the caption,
  /// the multi-attachment count, or the type label — matching the search list
  /// exactly (see `_mediaSummary` / `_fileAudioSummary` in `cometchat_search.dart`),
  /// so the conversation list and search read the same. Precedence:
  ///
  /// - **image / video:** caption → "{count} Images/Videos" (multi) →
  ///   single file name → type label.
  /// - **audio / file:** "caption · {count} Audios/Files" (both) → caption →
  ///   "{count} Audios/Files" (multi) → single file name → type label.
  /// - **everything else:** [singularSubtitleFor].
  ///
  /// (Image/video omit the count when a caption exists because search carries
  /// it on the thumbnail's "+N" overlay; the conversation list has no thumbnail
  /// but matches search's text for consistency.)
  static String previewSubtitleFor(BaseMessage message, BuildContext context) {
    if (message is MediaMessage) {
      final t = Translations.of(context);
      final caption = message.caption?.trim();
      final hasCaption = caption != null && caption.isNotEmpty;
      final count = attachmentsOf(message).length;
      switch (message.type) {
        case MessageTypeConstants.image:
        case MessageTypeConstants.video:
          if (hasCaption) return caption;
          if (count > 1) {
            final template = message.type == MessageTypeConstants.image
                ? t.searchImagesCount
                : t.searchVideosCount;
            return template.replaceAll('{count}', '$count');
          }
          return message.attachment?.fileName ??
              singularSubtitleFor(message.type, context);
        case MessageTypeConstants.audio:
        case MessageTypeConstants.file:
          final countLabel = count > 1
              ? (message.type == MessageTypeConstants.audio
                        ? t.searchAudiosCount
                        : t.searchFilesCount)
                    .replaceAll('{count}', '$count')
              : null;
          if (hasCaption && countLabel != null) return '$caption · $countLabel';
          if (hasCaption) return caption;
          if (countLabel != null) return countLabel;
          return message.attachment?.fileName ??
              singularSubtitleFor(message.type, context);
      }
    }
    return singularSubtitleFor(message.type, context);
  }

  /// The plain type label for a single-attachment (or non-media) message —
  /// "Image" / "Video" / "Audio" / "File" / poll / collaborative doc, etc.
  static String singularSubtitleFor(String type, BuildContext context) {
    switch (type) {
      case MessageTypeConstants.text:
        return Translations.of(context).text;
      case MessageTypeConstants.image:
        return Translations.of(context).messageImage;
      case MessageTypeConstants.video:
        return Translations.of(context).messageVideo;
      case MessageTypeConstants.audio:
        return Translations.of(context).messageAudio;
      case MessageTypeConstants.file:
        return Translations.of(context).messageFile;
      case ExtensionType.extensionPoll:
        return Translations.of(context).poll;
      case ExtensionType.document:
        return Translations.of(context).collaborativeDocument;
      case ExtensionType.whiteboard:
        return Translations.of(context).collaborativeWhiteboard;
      default:
        return type;
    }
  }
}
