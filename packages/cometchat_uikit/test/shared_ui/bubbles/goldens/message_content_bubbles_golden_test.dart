/// Golden pins for the non-grid message-content bubbles: file, voice note,
/// multi-file, multi-audio, deleted, the image/video placeholder state, and a
/// text bubble carrying a mention. Each renders the real Kit widget as the
/// content view of a real [CometChatMessageBubble], incoming and outgoing,
/// the way `CometChatMessageList` composes it.
///
/// Nothing here reaches the network: media bubbles are given no URL (their
/// placeholder state is the subject) or a URL that is only ever displayed,
/// never fetched, until the user taps.
///
///   flutter test test/shared_ui/bubbles/goldens/                  # verify
///   flutter test test/shared_ui/bubbles/goldens/ --update-goldens # rebake
library;

// The single-attachment file/image/video bubbles are deprecated in favour of
// the multi-attachment family but still ship on the
// `enableMultipleAttachments: false` path, which is what these cases pin.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_message_harness.dart';

const _incoming = BubbleAlignment.left;
const _outgoing = BubbleAlignment.right;

final _sentAt = DateTime(2024, 3, 14, 12, 30);

final _me = User(uid: 'golden-me', name: 'Morgan Reyes');
final _priya = User(uid: 'golden-priya', name: 'Priya Nair');

// ---------------------------------------------------------------------------
// Composition
// ---------------------------------------------------------------------------

Widget _bubble(
  Widget content,
  BubbleAlignment alignment, {
  EdgeInsetsGeometry? contentPadding,
}) {
  return CometChatMessageBubble(
    alignment: alignment,
    contentPadding: contentPadding,
    contentView: content,
    statusInfoView: goldenStatusInfo(
      alignment,
      receipt: ReceiptStatus.delivered,
    ),
  );
}

void _pair(
  String name,
  String description,
  Widget Function(BubbleAlignment alignment) content, {
  double height = 120,
  EdgeInsetsGeometry? contentPadding,
}) {
  for (final alignment in [_incoming, _outgoing]) {
    final side = alignment == _incoming ? 'incoming' : 'outgoing';
    goldenLightDark(
      '${name}_$side',
      '$description — $side',
      size: Size(375, height),
      alignment: goldenRowAlignment(alignment),
      build: () => _bubble(
        content(alignment),
        alignment,
        contentPadding: contentPadding,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

MediaMessage _media(
  String type,
  List<Attachment> attachments, {
  String? caption,
}) {
  final message = MediaMessage(
    receiverUid: _priya.uid,
    receiverType: ReceiverTypeConstants.user,
    type: type,
    muid: 'golden-$type-${attachments.length}',
    sentAt: _sentAt,
  );
  message.attachments = attachments;
  message.caption = caption;
  return message;
}

// `.invalid` never resolves; these URLs are labels, not fetch targets.
Attachment _file(String name, String ext, String mime, int bytes) =>
    Attachment('https://files.invalid/$name', name, ext, mime, bytes);

TextMessage _mentionMessage() => TextMessage(
  // Short enough to stay on one line: the CI variant paints each paragraph
  // as one block, so what shows the mention resolved is the block's width —
  // "Thanks @Priya Nair!" rather than the raw 27-character marker.
  text: 'Thanks <@uid:golden-priya>!',
  receiverUid: _priya.uid,
  receiverType: ReceiverTypeConstants.user,
  type: MessageTypeConstants.text,
  sender: _me,
  mentionedUsers: [_priya],
  sentAt: _sentAt,
);

void main() {
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _pair(
        'bubble_file',
        'file bubble, pdf with size and date subtitle',
        (alignment) => CometChatFileBubble(
          fileUrl: 'https://files.invalid/Q3-roadmap.pdf',
          fileMimeType: 'application/pdf',
          alignment: alignment,
          title: 'Q3-roadmap.pdf',
          id: 4201,
          fileSize: 2 * 1024 * 1024 + 300 * 1024,
          fileExtension: 'pdf',
          dateTime: _sentAt,
        ),
      );

      _pair(
        'bubble_files_multi',
        'multi-file bubble, three cards of different types with a caption',
        (alignment) => CometChatFilesBubble(
          alignment: alignment,
          message: _media(MessageTypeConstants.file, [
            _file('Q3-roadmap.pdf', 'pdf', 'application/pdf', 2400000),
            _file(
              'budget.xlsx',
              'xlsx',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              86000,
            ),
            _file('release-notes.zip', 'zip', 'application/zip', 12800000),
          ], caption: 'Everything for Thursday'),
        ),
        height: 330,
        contentPadding: EdgeInsets.zero,
      );

      _pair(
        'bubble_voice_note',
        'voice note bubble, idle (not yet played)',
        (alignment) => CometChatVoiceNoteBubble(
          audioUrl: 'https://files.invalid/voice-note.m4a',
          title: 'voice-note.m4a',
          alignment: alignment,
          id: 4202,
          muid: 'golden-voice-note',
          metadata: const {
            CometChatVoiceNoteBubble.audioTypeKey:
                CometChatVoiceNoteBubble.audioTypeVoiceNote,
          },
        ),
      );

      _pair(
        'bubble_audios_multi',
        'multi-audio bubble, two audio files',
        (alignment) => CometChatAudiosBubble(
          alignment: alignment,
          message: _media(MessageTypeConstants.audio, [
            _file('standup-recording.mp3', 'mp3', 'audio/mpeg', 3400000),
            _file('jingle-draft.wav', 'wav', 'audio/wav', 910000),
          ]),
        ),
        height: 200,
        contentPadding: EdgeInsets.zero,
      );

      _pair('bubble_deleted', 'deleted-message bubble', (alignment) {
        // The message list colours the deleted bubble by whether the logged-in
        // user sent it, so the fixture carries a sender on each side.
        return Builder(
          builder: (context) => MessageTemplateUtils.getDeleteMessageBubble(
            TextMessage(
              text: '',
              receiverUid: _priya.uid,
              receiverType: ReceiverTypeConstants.user,
              type: MessageTypeConstants.text,
              sender: alignment == _outgoing ? _me : _priya,
              deletedAt: _sentAt,
            ),
            context,
            null,
          ),
        );
      }, height: 90);

      _pair(
        'bubble_image_placeholder',
        'single image bubble with nothing to show — placeholder glyph',
        (alignment) => const CometChatImageBubble(),
        height: 310,
      );

      _pair(
        'bubble_video_placeholder',
        'single video bubble without a poster — play badge on the fill',
        (alignment) => const CometChatVideoBubble(
          videoUrl: 'https://files.invalid/walkthrough.mp4',
        ),
        height: 200,
      );

      _pair('bubble_text_mention', 'text bubble with a resolved @mention', (
        alignment,
      ) {
        final message = _mentionMessage();
        return CometChatTextBubble(
          text: message.text,
          alignment: alignment,
          formatters: [CometChatMentionsFormatter(message: message)],
        );
      }, height: 100);
    },
  );
}
