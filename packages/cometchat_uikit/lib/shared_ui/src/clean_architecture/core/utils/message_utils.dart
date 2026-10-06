import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/additional_configurations.dart';

// Import all necessary dependencies
import '../../presentation/theme/theme/cometchat_theme_helper.dart';
import '../../presentation/theme/colors/cometchat_color_palette.dart';
import '../../presentation/theme/typography/cometchat_typography.dart';
import '../../presentation/theme/spacing/cometchat_spacing.dart';
import '../../presentation/formatters/cometchat_text_formatter.dart';
import '../../../../cometchat_uikit_shared.dart'
    show
        CometChatDateStyle,
        CometChatMessageReceiptStyle,
        CometChatAvatarStyle,
        CometChatActionBubbleStyle,
        CometChatMessageBubble,
        CometChatMessageBubbleStyle,
        CometChatAvatar,
        CometChatDate,
        CometChatReceipt,
        MessageReceiptUtils,
        ReceiptStatus,
        CometChatUIKit,
        MessageCategoryConstants,
        MessageTypeConstants,
        CallTypeConstants,
        ExtensionType,
        DateTimePattern,
        Translations,
        ErrorConstants;
import 'moderation_check_util.dart';
import '../../data/models/extension_bubble_styles/cometchat_outgoing_message_bubble_style.dart';
import '../../data/models/extension_bubble_styles/cometchat_incoming_message_bubble_style.dart';
import '../../data/models/cometchat_message_template.dart';
import '../constants/enums.dart';

/// A utility class for message related operations.
/// This class contains methods required for message related operations.
/// It is used to get the message bubble, message time, and message receipt icon.
/// ``` dart
/// MessageUtils.getMessageBubble(
///  message: message,
///  template: messageTemplate,
///  bubbleAlignment: BubbleAlignment.left,
///  colorPalette: colorPalette,
///  typography: typography,
///  spacing: spacing,
///  context: context,
///  );
///  ```
class MessageUtils {
  static Widget getMessageBubble({
    required BaseMessage message,
    CometChatMessageTemplate? template,
    required BubbleAlignment bubbleAlignment,
    required CometChatColorPalette colorPalette,
    required CometChatTypography typography,
    required CometChatSpacing spacing,
    required BuildContext context,
    List<CometChatTextFormatter>? textFormatters,
    CometChatOutgoingMessageBubbleStyle? outgoingMessageBubbleStyle,
    CometChatIncomingMessageBubbleStyle? incomingMessageBubbleStyle,
    Key? key,
    bool? receiptsVisibility,
    // List surfaces (pinned messages) render every bubble flush-left so the
    // column reads as one list. Layout (row alignment, avatar, sender name)
    // follows LEFT while content/status styling still follows
    // [bubbleAlignment], so an outgoing bubble keeps its own colour scheme
    // and readable text. Default off — no change for the chat list.
    bool forceLeftLayout = false,
    // Replaces the sender name in the header (e.g. "You" for the logged-in
    // user's own messages in a pinned list). Null keeps sender.name.
    String? senderNameOverride,
    // Appends "• dd/MM/yy" after the sender name. List surfaces span many
    // days with no date separators, so each row states its own date.
    bool showSentDateInHeader = false,
    // Prefixes the bubble's status line with a pin glyph — the pinned list
    // marks every row as pinned. Default off for the chat list.
    bool showPinIndicator = false,
    // Adds a bookmark glyph beside it when the message is also saved.
    bool showSaveIndicator = false,
  }) {
    if (message.deletedAt == null && template?.bubbleView != null) {
      return template?.bubbleView!(message, context, BubbleAlignment.left) ??
          const SizedBox();
    }
    Widget? contentView;
    Widget? statusInfoView;
    Widget? leadingView;
    Widget? headerView;

    final outgoingMessageBubbleStyle0 =
        CometChatThemeHelper.getTheme<CometChatOutgoingMessageBubbleStyle>(
          context: context,
          defaultTheme: CometChatOutgoingMessageBubbleStyle.of,
        ).merge(outgoingMessageBubbleStyle);
    final incomingMessageBubbleStyle0 =
        CometChatThemeHelper.getTheme<CometChatIncomingMessageBubbleStyle>(
          context: context,
          defaultTheme: CometChatIncomingMessageBubbleStyle.of,
        ).merge(incomingMessageBubbleStyle);

    final bubbleStyleData = BubbleUIBuilder.getBubbleStyle(
      message,
      outgoingMessageBubbleStyle0,
      incomingMessageBubbleStyle0,
      colorPalette,
      typography,
      spacing,
    );
    final additionalConfigurations =
        BubbleUIBuilder.getAdditionalConfigurations(
          context,
          message,
          textFormatters,
          incomingMessageBubbleStyle0,
          outgoingMessageBubbleStyle0,
          null,
        );

    final layoutAlignment = forceLeftLayout
        ? BubbleAlignment.left
        : bubbleAlignment;

    contentView = _getSuitableContentView(
      message,
      colorPalette,
      context,
      template,
      bubbleAlignment,
      additionalConfigurations,
    );

    statusInfoView = _getStatusInfoView(
      bubbleAlignment,
      message,
      context,
      colorPalette,
      typography,
      spacing,
      template,
      bubbleStyleData?.messageBubbleDateStyle,
      bubbleStyleData?.messageReceiptStyle,
      receiptsVisibility,
      showPinIndicator: showPinIndicator,
      showSaveIndicator: showSaveIndicator,
    );

    leadingView = _getAvatar(
      layoutAlignment,
      message,
      context,
      colorPalette,
      typography,
      spacing,
      template,
      bubbleStyleData?.messageBubbleAvatarStyle,
    );

    headerView = _getHeaderView(
      layoutAlignment,
      message,
      context,
      colorPalette,
      typography,
      spacing,
      template,
      bubbleStyleData,
      senderNameOverride: senderNameOverride,
      alwaysShowName: forceLeftLayout,
      showSentDate: showSentDateInHeader,
    );

    Color backgroundColor =
        bubbleStyleData?.backgroundColor ??
        _getBubbleBackgroundColor(
          message,
          template,
          colorPalette,
          bubbleAlignment,
        );

    return Column(
      key: key,
      children: [
        Row(
          mainAxisAlignment: layoutAlignment == BubbleAlignment.left
              ? MainAxisAlignment.start
              : layoutAlignment == BubbleAlignment.center
              ? MainAxisAlignment.center
              : MainAxisAlignment.end,
          children: [
            // Flexible, not a bare child: a Row lays out non-flex children
            // with unbounded width, so a long message would size to its
            // intrinsic width and overflow the row (and ignore any maxWidth
            // the caller set). Loose fit keeps short bubbles hugging their
            // content while long ones wrap at the available width.
            Flexible(
              child: CometChatMessageBubble(
                style: CometChatMessageBubbleStyle(
                  backgroundColor: backgroundColor,
                  border: bubbleStyleData?.border,
                  borderRadius: bubbleStyleData?.borderRadius,
                  backgroundImage:
                      bubbleStyleData?.messageBubbleBackgroundImage,
                ),
                headerView: headerView,
                alignment: layoutAlignment,
                contentView: contentView,
                footerView: const SizedBox(),
                leadingView: leadingView,
                statusInfoView: statusInfoView,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _getBubbleBackgroundColor(
    BaseMessage messageObject,
    CometChatMessageTemplate? template,
    CometChatColorPalette colorPalette,
    BubbleAlignment alignment,
  ) {
    return messageObject.sender?.uid == CometChatUIKit.loggedInUser?.uid
        ? colorPalette.primary ?? Colors.transparent
        : colorPalette.neutral300 ?? Colors.transparent;
  }

  static Widget? _getSuitableContentView(
    BaseMessage messageObject,
    CometChatColorPalette colorPalette,
    BuildContext context,
    CometChatMessageTemplate? template,
    BubbleAlignment alignment,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    if (template?.contentView != null) {
      return template?.contentView!(
        messageObject,
        context,
        alignment,
        additionalConfigurations: additionalConfigurations,
      );
    } else {
      return const SizedBox();
    }
  }

  /// Separator between a state glyph and whatever follows it in the caption
  /// row. Its surrounding spaces are the spacing — no extra padding.
  static Widget _statusBullet(Color? color, CometChatTypography typography) {
    return Text(
      ' • ',
      style: TextStyle(
        color: color,
        fontSize: typography.caption2?.regular?.fontSize,
        fontWeight: typography.caption2?.regular?.fontWeight,
        fontFamily: typography.caption2?.regular?.fontFamily,
      ),
    );
  }

  static Widget? _getStatusInfoView(
    BubbleAlignment alignment,
    BaseMessage message,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatMessageTemplate? template,
    CometChatDateStyle? dateStyle,
    CometChatMessageReceiptStyle? receiptStyle,
    bool? receiptsVisibility, {
    bool showPinIndicator = false,
    bool showSaveIndicator = false,
  }) {
    if (template?.statusInfoView != null) {
      return template?.statusInfoView!(message, context, alignment);
    } else {
      final statusForeground = alignment == BubbleAlignment.right
          ? colorPalette.white
          : colorPalette.neutral600;
      final isSaved = message.savedAt != null;
      return Padding(
        padding: EdgeInsets.only(top: spacing.padding1 ?? 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Any edited `message`-category message shows the tag — that's text
            // plus image/video/audio/file, whose captions became editable with
            // multi-attachment. Restricting this to `type == text` dated from
            // when the SDK rejected editing anything else, and silently hid the
            // tag on edited media captions. Custom/action/call are other
            // categories and stay excluded.
            if (message.editedAt != null &&
                message.category == MessageCategoryConstants.message)
              Padding(
                padding: EdgeInsets.only(right: spacing.padding1 ?? 0),
                child: Text(
                  Translations.of(context).edited,
                  style: TextStyle(
                    color: alignment == BubbleAlignment.right
                        ? colorPalette.white
                        : colorPalette.neutral600,
                    fontSize: typography.caption2?.regular?.fontSize,
                    fontWeight: typography.caption2?.regular?.fontWeight,
                    fontFamily: typography.caption2?.regular?.fontFamily,
                  ),
                ),
              ),
            // State glyphs sit ahead of the time, each closed by its own
            // bullet: pinned when the row is a pin, saved when the reader
            // saved it too, so "pin • save • time" reads as three items.
            if (showPinIndicator) ...[
              Icon(Icons.push_pin, size: 12, color: statusForeground),
              _statusBullet(statusForeground, typography),
            ],
            if (showSaveIndicator && isSaved) ...[
              Icon(Icons.bookmark, size: 12, color: statusForeground),
              _statusBullet(statusForeground, typography),
            ],
            _getTime(
              message,
              colorPalette,
              typography,
              alignment,
              dateStyle,
              // With a glyph ahead of it, the date's default side padding
              // widens the status row past the message text — the bubble
              // then sizes to the row and the line stops reading as
              // right-aligned. Drop it so the row hugs.
              compact: showPinIndicator || showSaveIndicator,
            ),
            if (alignment == BubbleAlignment.right &&
                (receiptsVisibility ?? true))
              _getReceiptIcon(message, colorPalette, spacing, receiptStyle),
          ],
        ),
      );
    }
  }

  static Widget? _getAvatar(
    BubbleAlignment alignment,
    BaseMessage message,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatMessageTemplate? template,
    CometChatAvatarStyle? avatarStyle,
  ) {
    return (message.sender != null &&
            message.receiver != null &&
            message.receiver is Group &&
            alignment == BubbleAlignment.left)
        ? Padding(
            padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
            child: CometChatAvatar(
              image: message.sender?.avatar,
              name: message.sender?.name,
              width: 36,
              height: 36,
              style: avatarStyle,
            ),
          )
        : const SizedBox();
  }

  static Widget? _getHeaderView(
    BubbleAlignment alignment,
    BaseMessage message,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatMessageTemplate? template,
    CometChatMessageBubbleStyleData? messageBubbleStyleData, {
    String? senderNameOverride,
    // Pinned/saved list surfaces show a name on EVERY row (including 1-1
    // and own messages) so each row is attributable at a glance.
    bool alwaysShowName = false,
    // Renders the sent date beside the name, bullet-separated.
    bool showSentDate = false,
  }) {
    if (message.sender != null &&
        (alwaysShowName ||
            (message.receiver != null &&
                message.receiver is Group &&
                alignment == BubbleAlignment.left))) {
      if (template?.headerView != null) {
        return template?.headerView!(message, context, alignment);
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _getName(
            alignment,
            message,
            context,
            colorPalette,
            typography,
            spacing,
            template,
            messageBubbleStyleData,
            senderNameOverride: senderNameOverride,
            showSentDate: showSentDate,
          ),
        );
      }
    }
    return const SizedBox();
  }

  static Widget _getName(
    BubbleAlignment alignment,
    BaseMessage message,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatMessageTemplate? template,
    CometChatMessageBubbleStyleData? messageBubbleStyleData, {
    String? senderNameOverride,
    bool showSentDate = false,
  }) {
    // List surfaces (the ones showing the date) give the name a little more
    // presence than a chat bubble does — it is the row's title there, not a
    // caption above the message.
    final baseNameSize = typography.caption1?.medium?.fontSize;
    final nameText = Text(
      senderNameOverride ?? message.sender!.name,
      style: TextStyle(
        fontSize: showSentDate && baseNameSize != null
            ? baseNameSize + 2
            : baseNameSize,
        color: colorPalette.primary,
        fontWeight: showSentDate
            ? FontWeight.w500
            : typography.caption1?.medium?.fontWeight,
        fontFamily: typography.caption1?.medium?.fontFamily,
        letterSpacing: 0,
      ).merge(messageBubbleStyleData?.senderNameTextStyle),
      overflow: TextOverflow.ellipsis,
    );

    final sentAt = message.sentAt;
    return Padding(
      padding: EdgeInsets.only(
        right: spacing.padding2 ?? 0,
        left: spacing.padding2 ?? 0,
      ),
      child: (!showSentDate || sentAt == null)
          ? nameText
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The name yields first: a long name ellipsizes rather than
                // pushing the date out of the row.
                Flexible(child: nameText),
                Text(
                  ' • ${DateFormat('dd/MM/yyyy').format(sentAt)}',
                  style: TextStyle(
                    fontSize: typography.caption1?.regular?.fontSize,
                    color: colorPalette.textSecondary,
                    fontWeight: typography.caption1?.regular?.fontWeight,
                    fontFamily: typography.caption1?.regular?.fontFamily,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _getTime(
    BaseMessage messageObject,
    CometChatColorPalette? colorPalette,
    CometChatTypography? typography,
    BubbleAlignment alignment,
    CometChatDateStyle? dateStyle, {
    bool compact = false,
  }) {
    if (messageObject.sentAt == null) {
      return const SizedBox();
    }

    DateTime lastMessageTime = messageObject.sentAt!;
    return CometChatDate(
      date: lastMessageTime,
      pattern: DateTimePattern.timeFormat,
      isTransparentBackground: true,
      padding: compact ? EdgeInsets.zero : null,
      style: CometChatDateStyle(
        backgroundColor: Colors.transparent,
        textStyle: TextStyle(
          color: alignment == BubbleAlignment.right
              ? colorPalette?.white
              : colorPalette?.neutral600,
          fontSize: typography?.caption2?.regular?.fontSize,
          fontWeight: typography?.caption2?.regular?.fontWeight,
          fontFamily: typography?.caption2?.regular?.fontFamily,
        ),
        border: Border.all(color: Colors.transparent, width: 0),
      ).merge(dateStyle),
    );
  }

  static Widget _getReceiptIcon(
    BaseMessage message,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatMessageReceiptStyle? receiptStyle,
  ) {
    ReceiptStatus status = MessageReceiptUtils.getReceiptStatus(message);

    return Padding(
      padding: EdgeInsets.only(left: spacing.padding1 ?? 0),
      child: CometChatReceipt(
        status: status,
        size: 16,
        style: CometChatMessageReceiptStyle(
          deliveredIconColor: colorPalette.iconSecondary,
          readIconColor: colorPalette.messageSeen,
          sentIconColor: colorPalette.iconSecondary,
          waitIconColor: colorPalette.iconSecondary,
        ).merge(receiptStyle),
      ),
    );
  }
}

///the following extension [BubbleUIBuilder] is used to build the UI of the message bubbles.
extension BubbleUIBuilder on MessageUtils {
  static CometChatMessageBubbleStyleData? getBubbleStyle(
    BaseMessage message,
    CometChatOutgoingMessageBubbleStyle? outgoingMessageBubbleStyle,
    CometChatIncomingMessageBubbleStyle? incomingMessageBubbleStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    bool isSent = message.sender?.uid == CometChatUIKit.loggedInUser?.uid;
    if (message.deletedAt != null) {
      return CometChatMessageBubbleStyleData(
        backgroundColor: isSent
            ? outgoingMessageBubbleStyle?.deletedBubbleStyle?.backgroundColor
            : incomingMessageBubbleStyle?.deletedBubbleStyle?.backgroundColor,
        border: isSent
            ? outgoingMessageBubbleStyle?.deletedBubbleStyle?.border
            : incomingMessageBubbleStyle?.deletedBubbleStyle?.border,
        borderRadius: isSent
            ? outgoingMessageBubbleStyle?.deletedBubbleStyle?.borderRadius
            : incomingMessageBubbleStyle?.deletedBubbleStyle?.borderRadius,
        threadedMessageIndicatorIconColor: isSent
            ? outgoingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.threadedMessageIndicatorIconColor
            : incomingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.threadedMessageIndicatorIconColor,
        messageBubbleAvatarStyle: isSent
            ? outgoingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleAvatarStyle
            : incomingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleAvatarStyle,
        senderNameTextStyle:
            incomingMessageBubbleStyle?.deletedBubbleStyle?.senderNameTextStyle,
        messageReceiptStyle:
            outgoingMessageBubbleStyle?.deletedBubbleStyle?.messageReceiptStyle,
        messageBubbleDateStyle: isSent
            ? outgoingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleDateStyle
            : incomingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleDateStyle,
        messageBubbleBackgroundImage: isSent
            ? outgoingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleBackgroundImage
            : incomingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.messageBubbleBackgroundImage,
        threadedMessageIndicatorTextStyle: isSent
            ? outgoingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.threadedMessageIndicatorTextStyle
            : incomingMessageBubbleStyle
                  ?.deletedBubbleStyle
                  ?.threadedMessageIndicatorTextStyle,
      );
    }

    String key = "${message.category}${message.type}";
    if (key ==
            MessageCategoryConstants.action +
                MessageTypeConstants.groupActions ||
        key == MessageCategoryConstants.call + CallTypeConstants.audioCall ||
        key == MessageCategoryConstants.call + CallTypeConstants.videoCall) {
      return CometChatMessageBubbleStyleData(
        backgroundColor: colorPalette.transparent,
      );
    }
    CometChatMessageBubbleStyleData? messageBubbleStyleData;
    switch (key) {
      case const (MessageCategoryConstants.message + MessageTypeConstants.text):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.textBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.textBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.textBubbleStyle?.border
              : incomingMessageBubbleStyle?.textBubbleStyle?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
                  message,
                  outgoingMessageBubbleStyle?.textBubbleStyle?.borderRadius,
                  colorPalette,
                  typography,
                  spacing,
                )
              : incomingMessageBubbleStyle?.textBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.textBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.textBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.textBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message +
          MessageTypeConstants.image):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.imageBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.imageBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.imageBubbleStyle?.border
              : incomingMessageBubbleStyle?.imageBubbleStyle?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
                  message,
                  outgoingMessageBubbleStyle?.imageBubbleStyle?.borderRadius,
                  colorPalette,
                  typography,
                  spacing,
                )
              : incomingMessageBubbleStyle?.imageBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.imageBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.imageBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.imageBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message + MessageTypeConstants.file):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.fileBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.fileBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.fileBubbleStyle?.border
              : incomingMessageBubbleStyle?.fileBubbleStyle?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
                  message,
                  outgoingMessageBubbleStyle?.fileBubbleStyle?.borderRadius,
                  colorPalette,
                  typography,
                  spacing,
                )
              : incomingMessageBubbleStyle?.fileBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.fileBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.fileBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.fileBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message +
          MessageTypeConstants.video):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.videoBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.videoBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.videoBubbleStyle?.border
              : incomingMessageBubbleStyle?.videoBubbleStyle?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
                  message,
                  outgoingMessageBubbleStyle?.videoBubbleStyle?.borderRadius,
                  colorPalette,
                  typography,
                  spacing,
                )
              : incomingMessageBubbleStyle?.videoBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.videoBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.videoBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.videoBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message +
          MessageTypeConstants.audio):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.backgroundColor
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.border
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
                  message,
                  outgoingMessageBubbleStyle
                      ?.effectiveVoiceNoteBubbleStyle
                      ?.borderRadius,
                  colorPalette,
                  typography,
                  spacing,
                )
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.effectiveVoiceNoteBubbleStyle
              ?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.effectiveVoiceNoteBubbleStyle
              ?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.effectiveVoiceNoteBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom +
          ExtensionType.extensionPoll):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.pollsBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.pollsBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.pollsBubbleStyle?.border
              : incomingMessageBubbleStyle?.pollsBubbleStyle?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle?.pollsBubbleStyle?.borderRadius
              : incomingMessageBubbleStyle?.pollsBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.pollsBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.pollsBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.pollsBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.document):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.backgroundColor
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.border
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.borderRadius
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.collaborativeDocumentBubbleStyle
              ?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.collaborativeDocumentBubbleStyle
              ?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeDocumentBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.whiteboard):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.backgroundColor
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.border
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.borderRadius
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.collaborativeWhiteboardBubbleStyle
              ?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.collaborativeWhiteboardBubbleStyle
              ?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.collaborativeWhiteboardBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.sticker):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor:
              (isSent
                  ? outgoingMessageBubbleStyle
                        ?.stickerBubbleStyle
                        ?.backgroundColor
                  : incomingMessageBubbleStyle
                        ?.stickerBubbleStyle
                        ?.backgroundColor) ??
              colorPalette.transparent,
          border: isSent
              ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.border
              : incomingMessageBubbleStyle?.stickerBubbleStyle?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.borderRadius
              : incomingMessageBubbleStyle?.stickerBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.stickerBubbleStyle
              ?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.stickerBubbleStyle
              ?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle
                    ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom +
          MessageTypeConstants.meeting):
        CustomMessage msg = message as CustomMessage;
        String? callType;
        if (msg.customData != null &&
            msg.customData?.containsKey('callType') == true) {
          callType = msg.customData?['callType'];
        }
        if (callType == CallTypeConstants.audioCall) {
          messageBubbleStyleData = CometChatMessageBubbleStyleData(
            backgroundColor: isSent
                ? outgoingMessageBubbleStyle
                          ?.voiceCallBubbleStyle
                          ?.backgroundColor ??
                      colorPalette.primary
                : incomingMessageBubbleStyle
                          ?.voiceCallBubbleStyle
                          ?.backgroundColor ??
                      colorPalette.neutral300,
            border: isSent
                ? outgoingMessageBubbleStyle?.voiceCallBubbleStyle?.border
                : incomingMessageBubbleStyle?.voiceCallBubbleStyle?.border,
            borderRadius: isSent
                ? outgoingMessageBubbleStyle?.voiceCallBubbleStyle?.borderRadius
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.borderRadius,
            threadedMessageIndicatorIconColor: isSent
                ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.threadedMessageIndicatorIconColor
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.threadedMessageIndicatorIconColor,
            messageBubbleAvatarStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleAvatarStyle
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleAvatarStyle,
            senderNameTextStyle: incomingMessageBubbleStyle
                ?.voiceCallBubbleStyle
                ?.senderNameTextStyle,
            messageReceiptStyle: outgoingMessageBubbleStyle
                ?.voiceCallBubbleStyle
                ?.messageReceiptStyle,
            messageBubbleDateStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleDateStyle
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleDateStyle,
            messageBubbleBackgroundImage: isSent
                ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleBackgroundImage
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.messageBubbleBackgroundImage,
            threadedMessageIndicatorTextStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle
                : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle,
          );
        } else {
          messageBubbleStyleData = CometChatMessageBubbleStyleData(
            backgroundColor: isSent
                ? outgoingMessageBubbleStyle
                          ?.videoCallBubbleStyle
                          ?.backgroundColor ??
                      colorPalette.primary
                : incomingMessageBubbleStyle
                          ?.videoCallBubbleStyle
                          ?.backgroundColor ??
                      colorPalette.neutral300,
            border: isSent
                ? outgoingMessageBubbleStyle?.videoCallBubbleStyle?.border
                : incomingMessageBubbleStyle?.videoCallBubbleStyle?.border,
            borderRadius: isSent
                ? outgoingMessageBubbleStyle?.videoCallBubbleStyle?.borderRadius
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.borderRadius,
            threadedMessageIndicatorIconColor: isSent
                ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.threadedMessageIndicatorIconColor
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.threadedMessageIndicatorIconColor,
            messageBubbleAvatarStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleAvatarStyle
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleAvatarStyle,
            senderNameTextStyle: incomingMessageBubbleStyle
                ?.videoCallBubbleStyle
                ?.senderNameTextStyle,
            messageReceiptStyle: outgoingMessageBubbleStyle
                ?.videoCallBubbleStyle
                ?.messageReceiptStyle,
            messageBubbleDateStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleDateStyle
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleDateStyle,
            messageBubbleBackgroundImage: isSent
                ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleBackgroundImage
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.messageBubbleBackgroundImage,
            threadedMessageIndicatorTextStyle: isSent
                ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle
                : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle,
          );
        }
        break;
    }

    final defaultMessageBubbleStyleData = CometChatMessageBubbleStyleData(
      backgroundColor: isSent
          ? outgoingMessageBubbleStyle?.backgroundColor ?? colorPalette.primary
          : incomingMessageBubbleStyle?.backgroundColor ??
                colorPalette.neutral300,
      border: isSent
          ? outgoingMessageBubbleStyle?.border
          : incomingMessageBubbleStyle?.border,
      borderRadius: isSent
          ? outgoingMessageBubbleStyle?.borderRadius
          : incomingMessageBubbleStyle?.borderRadius,
      threadedMessageIndicatorIconColor: isSent
          ? outgoingMessageBubbleStyle?.threadedMessageIndicatorIconColor
          : incomingMessageBubbleStyle?.threadedMessageIndicatorIconColor,
      messageBubbleAvatarStyle: isSent
          ? outgoingMessageBubbleStyle?.messageBubbleAvatarStyle
          : incomingMessageBubbleStyle?.messageBubbleAvatarStyle,
      senderNameTextStyle: incomingMessageBubbleStyle?.senderNameTextStyle,
      messageReceiptStyle: outgoingMessageBubbleStyle?.messageReceiptStyle,
      messageBubbleDateStyle: isSent
          ? outgoingMessageBubbleStyle?.messageBubbleDateStyle
          : incomingMessageBubbleStyle?.messageBubbleDateStyle,
      messageBubbleBackgroundImage: isSent
          ? outgoingMessageBubbleStyle?.messageBubbleBackgroundImage
          : incomingMessageBubbleStyle?.messageBubbleBackgroundImage,
      threadedMessageIndicatorTextStyle: isSent
          ? outgoingMessageBubbleStyle?.threadedMessageIndicatorTextStyle
          : incomingMessageBubbleStyle?.threadedMessageIndicatorTextStyle,
    );

    return messageBubbleStyleData?.mergeIfNull(defaultMessageBubbleStyleData);
  }

  static AdditionalConfigurations? getAdditionalConfigurations(
    BuildContext context,
    BaseMessage message,
    List<CometChatTextFormatter>? formatters,
    CometChatIncomingMessageBubbleStyle? incomingMessageBubbleStyle2,
    CometChatOutgoingMessageBubbleStyle? outgoingMessageBubbleStyle2,
    CometChatActionBubbleStyle? actionBubbleStyle2,
  ) {
    AdditionalConfigurations? additionalConfigurations;
    final outgoingMessageBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatOutgoingMessageBubbleStyle>(
          context: context,
          defaultTheme: CometChatOutgoingMessageBubbleStyle.of,
        ).merge(outgoingMessageBubbleStyle2);
    final incomingMessageBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatIncomingMessageBubbleStyle>(
          context: context,
          defaultTheme: CometChatIncomingMessageBubbleStyle.of,
        ).merge(incomingMessageBubbleStyle2);
    bool isSent = message.sender?.uid == CometChatUIKit.loggedInUser?.uid;

    final actionBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatActionBubbleStyle>(
          context: context,
          defaultTheme: CometChatActionBubbleStyle.of,
        ).merge(actionBubbleStyle2);

    List<CometChatTextFormatter> textFormatters =
        BubbleUIBuilder.getTextFormatters(message, formatters ?? []);

    additionalConfigurations = AdditionalConfigurations(
      textFormatters: textFormatters,
      textBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.textBubbleStyle
                  : incomingMessageBubbleStyle.textBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      imageBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.imageBubbleStyle
                  : incomingMessageBubbleStyle.imageBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      fileBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.fileBubbleStyle
                  : incomingMessageBubbleStyle.fileBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      videoBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.videoBubbleStyle
                  : incomingMessageBubbleStyle.videoBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      audioBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.effectiveVoiceNoteBubbleStyle
                  : incomingMessageBubbleStyle.effectiveVoiceNoteBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      actionBubbleStyle: actionBubbleStyle,
      deletedBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.deletedBubbleStyle
                  : incomingMessageBubbleStyle.deletedBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      linkPreviewBubbleStyle: isSent
          ? outgoingMessageBubbleStyle.linkPreviewBubbleStyle
          : incomingMessageBubbleStyle.linkPreviewBubbleStyle,
      messageTranslationBubbleStyle: isSent
          ? outgoingMessageBubbleStyle.messageTranslationBubbleStyle
          : incomingMessageBubbleStyle.messageTranslationBubbleStyle,
      pollsBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.pollsBubbleStyle
                  : incomingMessageBubbleStyle.pollsBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      stickerBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.stickerBubbleStyle
                  : incomingMessageBubbleStyle.stickerBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      collaborativeDocumentBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.collaborativeDocumentBubbleStyle
                  : incomingMessageBubbleStyle.collaborativeDocumentBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      collaborativeWhiteboardBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle
                        .collaborativeWhiteboardBubbleStyle
                  : incomingMessageBubbleStyle
                        .collaborativeWhiteboardBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      voiceCallBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.voiceCallBubbleStyle
                  : incomingMessageBubbleStyle.voiceCallBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
      videoCallBubbleStyle:
          (isSent
                  ? outgoingMessageBubbleStyle.videoCallBubbleStyle
                  : incomingMessageBubbleStyle.videoCallBubbleStyle)
              ?.copyWith(
                border: Border.all(color: Colors.transparent, width: 0),
              ),
    );

    return additionalConfigurations;
  }

  static List<CometChatTextFormatter> getTextFormatters(
    BaseMessage message,
    List<CometChatTextFormatter> textFormatters,
  ) {
    if (message is TextMessage) {
      for (CometChatTextFormatter textFormatter in textFormatters) {
        textFormatter.message = message;
      }
    }
    return textFormatters;
  }

  // This method is used to get the border radius for sent text and media messages.
  // If the message is disapproved, it returns a specific border radius.
  static BorderRadiusGeometry? getSentTextMediaBorderRadiusGeometry(
    BaseMessage message,
    BorderRadiusGeometry? borderRadius,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    final moderationUtil = ModerationCheckUtil.instance;
    if (message.metadata != null &&
        (message.metadata!.containsValue(ErrorConstants.fileErrorCodeAndroid) ||
            message.metadata!.containsValue(ErrorConstants.fileErrorCodeIOS))) {
      return BorderRadius.only(
        topLeft: Radius.circular(spacing.radius4 ?? 16),
        topRight: Radius.circular(spacing.radius4 ?? 16),
      );
    }
    if (moderationUtil.hideModerationStatus == false &&
        ModerationCheckUtil.instance.isMessageDisapprovedFromModeration(
          message,
        )) {
      return BorderRadius.only(
        topLeft: Radius.circular(spacing.radius4 ?? 16),
        topRight: Radius.circular(spacing.radius4 ?? 16),
      );
    } else {
      return borderRadius;
    }
  }
}

///[CometChatMessageBubbleStyleData] is a model class which contains the style properties for the message bubble.
class CometChatMessageBubbleStyleData {
  CometChatMessageBubbleStyleData({
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.messageBubbleDateStyle,
    this.messageBubbleAvatarStyle,
    this.messageBubbleBackgroundImage,
    this.threadedMessageIndicatorIconColor,
    this.threadedMessageIndicatorTextStyle,
    this.senderNameTextStyle,
    this.messageReceiptStyle,
    this.moderationBackgroundColor,
    this.moderationTextStyle,
    this.moderationIconTint,
    this.exceptionBackgroundColor,
    this.exceptionTextStyle,
    this.exceptionIconTint,
  });

  ///[messageBubbleBackgroundImage] provides background image to the message bubble of a received message
  DecorationImage? messageBubbleBackgroundImage;

  ///[backgroundColor] provides background color to the message bubble of a received message
  Color? backgroundColor;

  ///[border] provides border to the message bubble of a received message
  BoxBorder? border;

  ///[borderRadius] provides border radius to the message bubble of a received message
  BorderRadiusGeometry? borderRadius;

  ///[threadedMessageIndicatorTextStyle] provides text style to the threaded message indicator
  TextStyle? threadedMessageIndicatorTextStyle;

  ///[threadedMessageIndicatorIconColor] provides color to the threaded message icon
  Color? threadedMessageIndicatorIconColor;

  ///[messageBubbleAvatarStyle] provides style to the avatar of the senderCometChatAvatarStyle? messageBubbleAvatarStyle;
  CometChatAvatarStyle? messageBubbleAvatarStyle;

  ///[messageBubbleDateStyle] provides style to the date of the message bubble
  CometChatDateStyle? messageBubbleDateStyle;

  ///[senderNameTextStyle] provides style to the sender name of the received message
  TextStyle? senderNameTextStyle;

  ///[messageReceiptStyle] provides style to the message receipt
  CometChatMessageReceiptStyle? messageReceiptStyle;

  ///[moderationBackgroundColor] provides background color to the moderated view
  final Color? moderationBackgroundColor;

  ///[moderationTextStyle] provides text style to the moderated view warning text
  final TextStyle? moderationTextStyle;

  ///[moderationIconTint] provides icon color for the moderated view warning icon
  final Color? moderationIconTint;

  ///[exceptionBackgroundColor] provides background color to the exception view
  final Color? exceptionBackgroundColor;

  ///[exceptionTextStyle] provides text style to the exception view warning text
  final TextStyle? exceptionTextStyle;

  ///[exceptionIconTint] provides icon color for the exception view warning icon
  final Color? exceptionIconTint;

  CometChatMessageBubbleStyleData copyWith({
    DecorationImage? messageBubbleBackgroundImage,
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    TextStyle? threadedMessageIndicatorTextStyle,
    Color? threadedMessageIndicatorIconColor,
    CometChatAvatarStyle? messageBubbleAvatarStyle,
    CometChatDateStyle? messageBubbleDateStyle,
    TextStyle? senderNameTextStyle,
    CometChatMessageReceiptStyle? messageReceiptStyle,
    Color? moderationBackgroundColor,
    TextStyle? moderationTextStyle,
    Color? moderationIconTint,
    Color? exceptionBackgroundColor,
    TextStyle? exceptionTextStyle,
    Color? exceptionIconTint,
  }) {
    return CometChatMessageBubbleStyleData(
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? this.messageBubbleBackgroundImage,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      threadedMessageIndicatorTextStyle:
          threadedMessageIndicatorTextStyle ??
          this.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          threadedMessageIndicatorIconColor ??
          this.threadedMessageIndicatorIconColor,
      messageBubbleAvatarStyle:
          messageBubbleAvatarStyle ?? this.messageBubbleAvatarStyle,
      messageBubbleDateStyle:
          messageBubbleDateStyle ?? this.messageBubbleDateStyle,
      senderNameTextStyle: senderNameTextStyle ?? this.senderNameTextStyle,
      messageReceiptStyle: messageReceiptStyle ?? this.messageReceiptStyle,
      moderationBackgroundColor:
          moderationBackgroundColor ?? this.moderationBackgroundColor,
      moderationTextStyle: moderationTextStyle ?? this.moderationTextStyle,
      moderationIconTint: moderationIconTint ?? this.moderationIconTint,
      exceptionBackgroundColor:
          exceptionBackgroundColor ?? this.exceptionBackgroundColor,
      exceptionTextStyle: exceptionTextStyle ?? this.exceptionTextStyle,
      exceptionIconTint: exceptionIconTint ?? this.exceptionIconTint,
    );
  }

  CometChatMessageBubbleStyleData merge(
    CometChatMessageBubbleStyleData? other,
  ) {
    if (other == null) return this;
    return copyWith(
      messageBubbleBackgroundImage: other.messageBubbleBackgroundImage,
      backgroundColor: other.backgroundColor,
      border: other.border,
      borderRadius: other.borderRadius,
      threadedMessageIndicatorTextStyle:
          other.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          other.threadedMessageIndicatorIconColor,
      messageBubbleAvatarStyle: other.messageBubbleAvatarStyle,
      messageBubbleDateStyle: other.messageBubbleDateStyle,
      senderNameTextStyle: other.senderNameTextStyle,
      messageReceiptStyle: other.messageReceiptStyle,
      moderationBackgroundColor: other.moderationBackgroundColor,
      moderationTextStyle: other.moderationTextStyle,
      moderationIconTint: other.moderationIconTint,
      exceptionBackgroundColor: other.exceptionBackgroundColor,
      exceptionTextStyle: other.exceptionTextStyle,
      exceptionIconTint: other.exceptionIconTint,
    );
  }

  CometChatMessageBubbleStyleData mergeIfNull(
    CometChatMessageBubbleStyleData? other,
  ) {
    if (other == null) return this;
    return copyWith(
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? other.messageBubbleBackgroundImage,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      border: border ?? other.border,
      borderRadius: borderRadius ?? other.borderRadius,
      threadedMessageIndicatorTextStyle:
          threadedMessageIndicatorTextStyle ??
          other.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          threadedMessageIndicatorIconColor ??
          other.threadedMessageIndicatorIconColor,
      messageBubbleAvatarStyle:
          messageBubbleAvatarStyle ?? other.messageBubbleAvatarStyle,
      messageBubbleDateStyle:
          messageBubbleDateStyle ?? other.messageBubbleDateStyle,
      senderNameTextStyle: senderNameTextStyle ?? other.senderNameTextStyle,
      messageReceiptStyle: messageReceiptStyle ?? other.messageReceiptStyle,
      moderationBackgroundColor:
          moderationBackgroundColor ?? other.moderationBackgroundColor,
      moderationTextStyle: moderationTextStyle ?? other.moderationTextStyle,
      moderationIconTint: moderationIconTint ?? other.moderationIconTint,
      exceptionBackgroundColor:
          exceptionBackgroundColor ?? other.exceptionBackgroundColor,
      exceptionTextStyle: exceptionTextStyle ?? other.exceptionTextStyle,
      exceptionIconTint: exceptionIconTint ?? other.exceptionIconTint,
    );
  }
}
