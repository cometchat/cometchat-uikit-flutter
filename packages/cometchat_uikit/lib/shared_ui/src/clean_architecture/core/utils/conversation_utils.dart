import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;

// Import all necessary dependencies
import '../constants/ui_kit_constants.dart';
import '../constants/asset_constants.dart';
import 'attachment_utils.dart';
import '../../data/models/cometchat_option.dart';
import '../../data/models/interactive_message/scheduler_message.dart';
import '../../presentation/theme/theme/cometchat_theme_helper.dart';
import '../../presentation/theme/colors/cometchat_color_palette.dart';
import '../../presentation/formatters/mentions/cometchat_mentions_formatter.dart';
import 'scheduler_utils.dart';
import '../../../../l10n/translations.dart';
import '../../../../src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../../../../../src/missed_call_rule.dart';

///[ConversationUtils] is an Utility class that helps to
///the last message for any conversation and also
///provides the default action to execute on a conversation
class ConversationUtils {
  /// Get default options for a conversation
  ///
  /// **Deprecated**: This method previously required a controller parameter.
  /// Use [getDefaultOptionsWithCallback] instead to provide custom delete action.
  @Deprecated(
    'Use getDefaultOptionsWithCallback instead. '
    'See CONVERSATIONS_MIGRATION_GUIDE.md for migration instructions.',
  )
  static List<CometChatOption>? getDefaultOptions(
    Conversation conversation,
    dynamic controller,
    BuildContext context,
    CometChatColorPalette colorPalette,
  ) {
    return getDefaultOptionsWithCallback(
      conversation: conversation,
      context: context,
      colorPalette: colorPalette,
      onDelete: null,
    );
  }

  /// Get default options for a conversation with custom delete callback
  ///
  /// This is the new recommended way to get default conversation options.
  /// Provide a custom [onDelete] callback to handle deletion.
  static List<CometChatOption>? getDefaultOptionsWithCallback({
    required Conversation conversation,
    required BuildContext context,
    required CometChatColorPalette colorPalette,
    required Function(Conversation)? onDelete,
  }) {
    return [
      CometChatOption(
        id: ConversationOptionConstants.delete,
        icon: AssetConstants.delete,
        packageName: UIConstants.packageName,
        backgroundColor: colorPalette.background1,
        iconTint: colorPalette.error,
        title: Translations.of(context).delete,
        onClick: () {
          if (onDelete != null) {
            onDelete(conversation);
          }
        },
      ),
    ];
  }

  static String getLastCustomMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    if (conversation.lastMessage is CustomMessage) {
      CustomMessage customMessage = conversation.lastMessage as CustomMessage;
      String messageType = customMessage.type;
      String subtitle = '';

      switch (messageType) {
        case ExtensionType.sticker:
          subtitle = Translations.of(context).customMessageSticker;
          break;
        case ExtensionType.document:
          subtitle = Translations.of(context).customMessageDocument;
          break;
        case ExtensionType.whiteboard:
          subtitle = Translations.of(context).customMessageWhiteboard;
          break;
        case ExtensionType.extensionPoll:
          subtitle = Translations.of(context).customMessagePoll;
          break;
        case MessageTypeConstants.meeting:
          subtitle = _getGroupCallSubtitle(customMessage, context);
          break;
        default:
          subtitle = messageType;
          break;
      }
      return subtitle;
    } else {
      return "";
    }
  }

  /// Returns the subtitle text for a group call (meeting) message.
  /// If initiated by the logged-in user: "You've initiated a group call"
  /// If initiated by someone else: "{Name} has initiated a group call"
  static String _getGroupCallSubtitle(
    BaseMessage message,
    BuildContext context,
  ) {
    if (message.sender?.uid == CometChatUIKit.loggedInUser?.uid) {
      return Translations.of(context).youInitiatedGroupCall;
    } else {
      return "${message.sender?.name} ${Translations.of(context).initiatedGroupCall}";
    }
  }

  /// Strips markdown syntax from text so conversation subtitles show plain text.
  /// Handles: bold, italic, strikethrough, inline code, code blocks,
  /// blockquotes, bullet lists, ordered lists, and headings.
  static String stripMarkdownSyntax(String text) {
    String result = text;
    // Code blocks (``` ... ```)
    result = result.replaceAll(RegExp(r'```[^\n]*\n?'), '');
    // Inline code (`code`)
    result = result.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
    // Bold+italic (***text*** or ___text___)
    result = result.replaceAllMapped(RegExp(r'\*{3}(.+?)\*{3}'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'_{3}(.+?)_{3}'), (m) => m[1]!);
    // Bold (**text** or __text__)
    result = result.replaceAllMapped(RegExp(r'\*{2}(.+?)\*{2}'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'_{2}(.+?)_{2}'), (m) => m[1]!);
    // Italic (*text* or _text_)
    result = result.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!);
    result = result.replaceAllMapped(
      RegExp(r'(?<=\s|^)_(.+?)_(?=\s|$)'),
      (m) => m[1]!,
    );
    // Strikethrough (~~text~~)
    result = result.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m[1]!);
    // Blockquote (>> or > at line start)
    result = result.replaceAllMapped(
      RegExp(r'(^|\n)>{1,2}\s?', multiLine: true),
      (m) => m[1]!,
    );
    // Headings (# ## ### etc.)
    result = result.replaceAllMapped(
      RegExp(r'(^|\n)#{1,6}\s+', multiLine: true),
      (m) => m[1]!,
    );
    // Unordered list markers (- or * at line start)
    result = result.replaceAllMapped(
      RegExp(r'(^|\n)[*\-]\s+', multiLine: true),
      (m) => m[1]!,
    );
    // Ordered list markers (1. 2. etc.)
    result = result.replaceAllMapped(
      RegExp(r'(^|\n)\d+\.\s+', multiLine: true),
      (m) => m[1]!,
    );
    return result.trim();
  }

  static String getLastMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    BaseMessage message = conversation.lastMessage!;
    String messageType = message.type;
    String subtitle;

    switch (messageType) {
      case MessageTypeConstants.text:
        subtitle = (message as TextMessage).text;
        if (message.mentionedUsers.isNotEmpty) {
          subtitle = CometChatMentionsFormatter.getTextWithMentions(
            message.text,
            message.mentionedUsers,
          );
        }
        // Strip markdown syntax so subtitle shows plain text
        subtitle = stripMarkdownSyntax(subtitle);
        // Truncate long URLs in the subtitle for better display
        subtitle = _truncateUrlsInText(subtitle);
        break;
      // image / video / file: caption → "{count} Images/…" → filename → label,
      // exactly matching the search list (AttachmentUtils.previewSubtitleFor).
      case MessageTypeConstants.image:
      case MessageTypeConstants.video:
      case MessageTypeConstants.file:
        subtitle = AttachmentUtils.previewSubtitleFor(message, context);
        break;
      case MessageTypeConstants.audio:
        // A voice note (single, un-captioned, recording filename) keeps the
        // friendly "Audio" label instead of showing a timestamped filename;
        // picked audio files use the search-style preview (caption / count).
        final isVoiceNote =
            message is MediaMessage &&
            (message.caption?.trim().isEmpty ?? true) &&
            AttachmentUtils.attachmentsOf(message).length == 1 &&
            message.attachment?.fileName != null &&
            _isVoiceNoteName(message.attachment!.fileName);
        subtitle = isVoiceNote
            ? Translations.of(context).messageAudio
            : AttachmentUtils.previewSubtitleFor(message, context);
        break;
      default:
        subtitle = messageType;
    }
    return subtitle;
  }

  /// Heuristic: treat recordings produced by the composer as voice notes so
  /// the subtitle shows "Audio" rather than a timestamped filename.
  static bool _isVoiceNoteName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.startsWith('audio-recording') ||
        lower.startsWith('voice-recording') ||
        lower.startsWith('recording') ||
        lower.startsWith('voicenote');
  }

  /// Truncates long URLs in text to make them more readable in conversation subtitles.
  ///
  /// URLs longer than [maxUrlLength] characters are shortened to show the domain
  /// and a truncated path (e.g., "https://example.com/very/long/path..." becomes
  /// "example.com/very/lo...").
  static String _truncateUrlsInText(String text, {int maxUrlLength = 30}) {
    // Regular expression to match URLs
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

    return text.replaceAllMapped(urlRegex, (match) {
      final url = match.group(0)!;
      if (url.length <= maxUrlLength) {
        return url;
      }

      // Try to parse the URL to extract domain
      try {
        final uri = Uri.parse(url);
        final domain = uri.host;
        final path = uri.path;

        // If just the domain fits, show domain + truncated path
        if (domain.length < maxUrlLength - 3) {
          final remainingLength =
              maxUrlLength - domain.length - 3; // -3 for "..."
          if (path.isNotEmpty && remainingLength > 0) {
            final truncatedPath = path.length > remainingLength
                ? '${path.substring(0, remainingLength)}...'
                : path;
            return '$domain$truncatedPath';
          }
          return '$domain...';
        }

        // Domain itself is too long, truncate it
        return '${domain.substring(0, maxUrlLength - 3)}...';
      } catch (e) {
        // If URL parsing fails, just truncate the raw URL
        return '${url.substring(0, maxUrlLength - 3)}...';
      }
    });
  }

  static String getLastInteractiveMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    BaseMessage message = conversation.lastMessage!;
    String messageType = message.type;
    String subtitle;
    switch (messageType) {
      case MessageTypeConstants.form:
        subtitle = Translations.of(context).formMessage;
        break;
      case MessageTypeConstants.card:
        subtitle = Translations.of(context).cardMessage;
        break;
      case MessageTypeConstants.scheduler:
        SchedulerMessage schedulerMessage =
            SchedulerMessage.fromInteractiveMessage(
              message as InteractiveMessage,
            );
        String meetingMessage = SchedulerUtils.getSchedulerTitle(
          schedulerMessage,
          context,
        );
        subtitle = "🗓️ $meetingMessage";
        break;
      default:
        subtitle = messageType;
    }
    return subtitle;
  }

  static String getLastActionMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    BaseMessage message = conversation.lastMessage!;
    String subtitle;

    if (message.type == MessageTypeConstants.groupActions) {
      cc.Action actionMessage = message as cc.Action;
      subtitle = actionMessage.message ?? "";
    } else {
      subtitle = message.type;
    }

    return subtitle;
  }

  static String getLastCallMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    Call call = conversation.lastMessage as Call;
    User? conversationWithUser;
    Group? conversationWithGroup;

    if (conversation.conversationWith is User) {
      conversationWithUser = conversation.conversationWith as User;
    } else if (conversation.conversationWith is Group) {
      conversationWithGroup = conversation.conversationWith as Group;
    }

    String subtitle = call.type;
    Group? callInitiatorGroup;
    User? callInitiatorUser;
    if (call.callInitiator is User) {
      callInitiatorUser = call.callInitiator as User;
    } else if (call.callInitiator is Group) {
      callInitiatorGroup = call.callInitiator as Group;
    }
    // If callInitiator is null, both will remain null

    if (call.callStatus == CallStatusConstants.ongoing) {
      subtitle = Translations.of(context).ongoingCall;
    } else if (call.callStatus == CallStatusConstants.ended ||
        call.callStatus == CallStatusConstants.initiated) {
      if ((callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid)) {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).incomingAudioCall;
        } else {
          subtitle = Translations.of(context).incomingVideoCall;
        }
      } else {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).outgoingAudioCall;
        } else {
          subtitle = Translations.of(context).outgoingVdeoCall;
        }
      }
    } else if (MissedCallRule.isMissedStatus(call.callStatus)) {
      // Missed only for the person who did not start the call: the one rule
      // the call bubbles and the call logs use too.
      if ((callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid)) {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).missedVoiceCall;
        } else {
          subtitle = Translations.of(context).missedVideoCall;
        }
      } else {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).unansweredAudioCall;
        } else {
          subtitle = Translations.of(context).unansweredVideoCall;
        }
      }
    } else if (call.callStatus == CallStatusConstants.rejected) {
      // Never missed, and the same on both sides: the chat SDK names whoever
      // declined as the call's initiator, so its direction cannot be trusted.
      subtitle = Translations.of(context).callRejected;
    } else if (call.callStatus == CallStatusConstants.busy) {
      subtitle = Translations.of(context).callBusy;
    }
    return subtitle;
  }

  static String getLastConversationMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    String? messageCategory = conversation.lastMessage?.category;
    String subtitle;
    switch (messageCategory) {
      case MessageCategoryConstants.message:
        subtitle = getLastMessage(conversation, context);
        break;
      case MessageCategoryConstants.custom:
        subtitle = getLastCustomMessage(conversation, context);
        break;
      case MessageCategoryConstants.action:
        subtitle = getLastActionMessage(conversation, context);
        break;
      case MessageCategoryConstants.call:
        subtitle = getLastCallMessage(conversation, context);
        break;
      case MessageCategoryConstants.interactive:
        //TODO: appropriate implement interactive message subtitle
        // subtitle = getLastInteractiveMessage(conversation, context);
        subtitle = Translations.of(context).unsupportedMessageType;
        break;
      case MessageCategoryConstants.card:
        final cardMsg = conversation.lastMessage as CardMessage?;
        subtitle = cardMsg?.getText()?.isNotEmpty == true
            ? cardMsg!.getText()!
            : Translations.of(context).cardMessage;
        break;
      default:
        subtitle = conversation.lastMessage!.type;
        break;
    }

    return subtitle;
  }

  // return icon widget to be shown in the prefix to the last message

  static Widget getLastConversationIcon(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    String? messageCategory = conversation.lastMessage?.category;
    Widget subtitle;
    switch (messageCategory) {
      case MessageCategoryConstants.message:
        subtitle = getLastMessageWidget(conversation, context, iconColor);
        break;
      case MessageCategoryConstants.custom:
        subtitle = getLastCustomWidget(conversation, context, iconColor);
        break;
      // case MessageCategoryConstants.action:
      //   subtitle = getLastActionMessage(conversation, context);
      //   break;
      case MessageCategoryConstants.call:
        subtitle = getLastCallWidget(conversation, context, iconColor);
        break;
      case MessageCategoryConstants.interactive:
        // subtitle = getLastInteractiveWidget(conversation, context);
        subtitle = Icon(Icons.block, color: iconColor, size: 16);
        break;
      default:
        subtitle = const SizedBox();
        break;
    }

    return subtitle;
  }

  static Widget getLastMessageWidget(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    BaseMessage message = conversation.lastMessage!;
    String messageType = message.type;
    Widget subtitle;

    final colorPalette = CometChatThemeHelper.getColorPalette(context);

    switch (messageType) {
      case MessageTypeConstants.text:
        subtitle = _getLastTextMessageWidget(conversation, context, iconColor);
        break;
      case MessageTypeConstants.image:
        subtitle = Icon(
          Icons.photo,
          color: iconColor ?? colorPalette.iconSecondary,
          size: 16,
        );
        break;
      case MessageTypeConstants.video:
        subtitle = Icon(
          Icons.videocam,
          color: iconColor ?? colorPalette.iconSecondary,
          size: 16,
        );
        break;
      case MessageTypeConstants.file:
        subtitle = _getFileIconWidget(message, iconColor, colorPalette);
        break;
      case MessageTypeConstants.audio:
        subtitle = _getAudioIconWidget(message, iconColor, colorPalette);
        break;
      default:
        subtitle = const SizedBox();
    }
    return subtitle;
  }

  /// Returns a file-type-specific icon based on the attachment's extension
  /// or MIME type. Falls back to the generic document icon when no
  /// attachment information is available.
  static Widget _getFileIconWidget(
    BaseMessage message,
    Color? iconColor,
    CometChatColorPalette colorPalette,
  ) {
    const size = 16.0;
    final color = iconColor ?? colorPalette.iconSecondary;

    IconData icon = Icons.description;

    if (message is MediaMessage) {
      final ext = (message.attachment?.fileExtension ?? '').toLowerCase();
      final mime = (message.attachment?.fileMimeType ?? '').toLowerCase();

      if (ext == 'pdf' || mime == 'application/pdf') {
        icon = Icons.picture_as_pdf;
      } else if (ext == 'doc' ||
          ext == 'docx' ||
          mime.contains('word') ||
          mime.contains('msword') ||
          mime.contains('officedocument.wordprocessing')) {
        icon = Icons.article;
      } else if (ext == 'xls' ||
          ext == 'xlsx' ||
          ext == 'csv' ||
          mime.contains('excel') ||
          mime.contains('spreadsheet') ||
          mime == 'text/csv') {
        icon = Icons.table_chart;
      } else if (ext == 'ppt' ||
          ext == 'pptx' ||
          mime.contains('powerpoint') ||
          mime.contains('presentation')) {
        icon = Icons.slideshow;
      } else if (ext == 'zip' ||
          ext == 'rar' ||
          ext == '7z' ||
          ext == 'tar' ||
          ext == 'gz' ||
          mime.contains('zip') ||
          mime.contains('compressed') ||
          mime.contains('x-tar') ||
          mime.contains('gzip')) {
        icon = Icons.folder_zip;
      } else if (ext == 'txt' ||
          ext == 'md' ||
          ext == 'log' ||
          mime.startsWith('text/')) {
        icon = Icons.text_snippet;
      } else if (mime.startsWith('image/')) {
        icon = Icons.photo;
      } else if (mime.startsWith('video/')) {
        icon = Icons.videocam;
      } else if (mime.startsWith('audio/')) {
        icon = Icons.audiotrack;
      }
    }

    return Icon(icon, color: color, size: size);
  }

  /// Returns an audio icon that distinguishes voice notes (mic) from music
  /// or other audio files (audiotrack), using the attachment's file name
  /// and extension as hints.
  static Widget _getAudioIconWidget(
    BaseMessage message,
    Color? iconColor,
    CometChatColorPalette colorPalette,
  ) {
    const size = 16.0;
    final color = iconColor ?? colorPalette.iconSecondary;

    IconData icon = Icons.mic;

    if (message is MediaMessage) {
      final fileName = message.attachment?.fileName ?? '';
      final ext = (message.attachment?.fileExtension ?? '').toLowerCase();
      const musicExtensions = {
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'flac',
        'wma',
      };

      // Only switch to music icon when the attachment clearly isn't a
      // composer-generated voice recording.
      if (musicExtensions.contains(ext) && !_isVoiceNoteName(fileName)) {
        icon = Icons.audiotrack;
      }
    }

    return Icon(icon, color: color, size: size);
  }

  static Widget _getLastTextMessageWidget(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    BaseMessage message = conversation.lastMessage!;
    if (message.metadata != null && _checkForLinks(message.metadata!)) {
      return Icon(
        Icons.link,
        color: iconColor ?? colorPalette.iconSecondary,
        size: 16,
      );
    } else {
      return const SizedBox();
    }
  }

  static bool _checkForLinks(Map<String, dynamic> metadata) {
    // Check if the metadata contains the '@injected' key
    if (metadata.containsKey('@injected')) {
      var injected = metadata['@injected'];

      // Check if 'extensions' exists within 'injected'
      if (injected != null && injected['extensions'] != null) {
        var extensions = injected['extensions'];

        // Check if 'link-preview' exists within 'extensions'
        if (extensions['link-preview'] != null) {
          var linkPreview = extensions['link-preview'];

          // Check if 'links' exists within 'link-preview'
          if (linkPreview['links'] != null) {
            List<dynamic> links = linkPreview['links'];

            // Return true if the list of links is not empty
            return links.isNotEmpty;
          }
        }
      }
    }

    // Return false if no links were found
    return false;
  }

  static Widget getLastCustomWidget(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    BaseMessage message = conversation.lastMessage!;
    String messageType = message.type;
    Widget subtitle;

    final colorPalette = CometChatThemeHelper.getColorPalette(context);

    switch (messageType) {
      case ExtensionType.extensionPoll:
        subtitle = Icon(
          Icons.bar_chart,
          color: iconColor ?? colorPalette.iconSecondary,
          size: 16,
        );
        break;
      case ExtensionType.document:
        subtitle = Image.asset(
          AssetConstants.collaborativeDocumentFilled,
          package: UIConstants.packageName,
          color: iconColor ?? colorPalette.iconSecondary,
          height: 16,
          width: 16,
        );
        break;
      case ExtensionType.sticker:
        subtitle = Image.asset(
          AssetConstants.stickerFilled,
          package: UIConstants.packageName,
          color: iconColor ?? colorPalette.iconSecondary,
          height: 16,
          width: 16,
        );
        break;
      case ExtensionType.whiteboard:
        subtitle = Image.asset(
          AssetConstants.collaborativeWhiteBoardFilled,
          package: UIConstants.packageName,
          color: iconColor ?? colorPalette.iconSecondary,
          height: 16,
          width: 16,
        );
        break;
      case MessageTypeConstants.meeting:
        subtitle = Icon(
          Icons.videocam,
          color: iconColor ?? colorPalette.iconSecondary,
          size: 16,
        );
        break;
      default:
        subtitle = const SizedBox();
    }
    return subtitle;
  }

  static Widget getLastCallWidget(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    Call call = conversation.lastMessage as Call;
    User? conversationWithUser;
    Group? conversationWithGroup;

    final colorPalette = CometChatThemeHelper.getColorPalette(context);

    if (conversation.conversationWith is User) {
      conversationWithUser = conversation.conversationWith as User;
    } else if (conversation.conversationWith is Group) {
      conversationWithGroup = conversation.conversationWith as Group;
    }

    Widget subtitle = const SizedBox();
    Group? callInitiatorGroup;
    User? callInitiatorUser;
    if (call.callInitiator is User) {
      callInitiatorUser = call.callInitiator as User;
    } else if (call.callInitiator is Group) {
      callInitiatorGroup = call.callInitiator as Group;
    }
    // If callInitiator is null, both will remain null

    if (call.callStatus == CallStatusConstants.ongoing) {
      subtitle = const SizedBox();
    } else if (call.callStatus == CallStatusConstants.ended ||
        call.callStatus == CallStatusConstants.initiated) {
      if ((callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid)) {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Image.asset(
            AssetConstants.voiceIncoming,
            package: UIConstants.packageName,
            color: iconColor ?? colorPalette.iconSecondary,
            height: 16,
            width: 16,
          );
        } else {
          subtitle = Image.asset(
            AssetConstants.videoIncoming,
            package: UIConstants.packageName,
            color: iconColor ?? colorPalette.iconSecondary,
            height: 16,
            width: 16,
          );
        }
      } else {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Image.asset(
            AssetConstants.voiceOutgoing,
            package: UIConstants.packageName,
            color: iconColor ?? colorPalette.iconSecondary,
            height: 16,
            width: 16,
          );
        } else {
          subtitle = Image.asset(
            AssetConstants.videoOutgoing,
            package: UIConstants.packageName,
            color: iconColor ?? colorPalette.iconSecondary,
            height: 16,
            width: 16,
          );
        }
      }
    } else if (MissedCallRule.isMissedStatus(call.callStatus)) {
      // Missed only for the person who did not start the call; the caller's
      // own cancelled or unanswered call shows as outgoing.
      final missed =
          (callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid);
      final String asset;
      if (call.type == MessageTypeConstants.audio) {
        asset = missed
            ? AssetConstants.audioMissed
            : AssetConstants.voiceOutgoing;
      } else {
        asset = missed
            ? AssetConstants.videoMissed
            : AssetConstants.videoOutgoing;
      }
      subtitle = Image.asset(
        asset,
        package: UIConstants.packageName,
        color: iconColor ?? colorPalette.iconSecondary,
        height: 16,
        width: 16,
      );
    } else if (call.callStatus == CallStatusConstants.rejected ||
        call.callStatus == CallStatusConstants.busy) {
      // Never missed, and with no direction: the chat SDK names whoever
      // declined (or was busy) as the call's initiator.
      subtitle = Image.asset(
        call.type == MessageTypeConstants.audio
            ? AssetConstants.callNoFill
            : AssetConstants.videocamNoFill,
        package: UIConstants.packageName,
        color: iconColor ?? colorPalette.iconSecondary,
        height: 16,
        width: 16,
      );
    }
    return subtitle;
  }
}
