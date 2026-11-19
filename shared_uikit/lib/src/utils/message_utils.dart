import 'package:cometchat_uikit_shared/cometchat_uikit_shared.dart';
import 'package:flutter/material.dart';

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
  }) {
    if (template?.bubbleView != null) {
      return template?.bubbleView!(message, context, BubbleAlignment.left) ??
          const SizedBox();
    }
    Widget? contentView;
    Widget? statusInfoView;
    Widget? leadingView;
    Widget? headerView;
    Widget? replyView;

    final outgoingMessageBubbleStyle0 =
        CometChatThemeHelper.getTheme<CometChatOutgoingMessageBubbleStyle>(
                context: context,
                defaultTheme: CometChatOutgoingMessageBubbleStyle.of)
            .merge(outgoingMessageBubbleStyle);
    final incomingMessageBubbleStyle0 =
        CometChatThemeHelper.getTheme<CometChatIncomingMessageBubbleStyle>(
                context: context,
                defaultTheme: CometChatIncomingMessageBubbleStyle.of)
            .merge(incomingMessageBubbleStyle);

    final bubbleStyleData = BubbleUIBuilder.getBubbleStyle(
        message,
        outgoingMessageBubbleStyle0,
        incomingMessageBubbleStyle0,
        colorPalette,
        typography,
        spacing);
    final additionalConfigurations =
        BubbleUIBuilder.getAdditionalConfigurations(
            context,
            message,
            textFormatters,
            incomingMessageBubbleStyle0,
            outgoingMessageBubbleStyle0,
            null);

    contentView = _getSuitableContentView(message, colorPalette, context,
        template, bubbleAlignment, additionalConfigurations);

    replyView = _getSuitableReplyView(message, colorPalette, context, template,
        bubbleAlignment, additionalConfigurations);

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
    );

    leadingView = _getAvatar(
      bubbleAlignment,
      message,
      context,
      colorPalette,
      typography,
      spacing,
      template,
      bubbleStyleData?.messageBubbleAvatarStyle,
    );

    headerView = _getHeaderView(
      bubbleAlignment,
      message,
      context,
      colorPalette,
      typography,
      spacing,
      template,
      bubbleStyleData,
    );

    Color backgroundColor = bubbleStyleData?.backgroundColor ??
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
          mainAxisAlignment: bubbleAlignment == BubbleAlignment.left
              ? MainAxisAlignment.start
              : bubbleAlignment == BubbleAlignment.center
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.end,
          children: [
            CometChatMessageBubble(
              style: CometChatMessageBubbleStyle(
                backgroundColor: backgroundColor,
                border: bubbleStyleData?.border,
                borderRadius: bubbleStyleData?.borderRadius,
                backgroundImage: bubbleStyleData?.messageBubbleBackgroundImage,
              ),
              headerView: headerView,
              alignment: bubbleAlignment,
              contentView: contentView,
              footerView: const SizedBox(),
              leadingView: leadingView,
              statusInfoView: statusInfoView,
              replyView: replyView,
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
      BubbleAlignment alignment) {
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
      AdditionalConfigurations? additionalConfigurations) {
    if (template?.contentView != null) {
      return template?.contentView!(messageObject, context, alignment,
          additionalConfigurations: additionalConfigurations);
    } else {
      return const SizedBox();
    }
  }

  static Widget? _getSuitableReplyView(
      BaseMessage messageObject,
      CometChatColorPalette colorPalette,
      BuildContext context,
      CometChatMessageTemplate? template,
      BubbleAlignment alignment,
      AdditionalConfigurations? additionalConfigurations) {
    if (template?.replyView != null) {
      return template?.replyView!(messageObject, context, alignment,
          additionalConfigurations: additionalConfigurations);
    } else {
      return const SizedBox();
    }
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
    bool? receiptsVisibility,
  ) {
    if (template?.statusInfoView != null) {
      return template?.statusInfoView!(
        message,
        context,
        alignment,
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.only(
              left: 0,
              bottom: spacing.padding1 ?? 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.editedAt != null &&
                    (message.category == MessageCategoryConstants.message &&
                        message.type == MessageTypeConstants.text))
                  Padding(
                    padding: EdgeInsets.only(left: spacing.padding1 ?? 0),
                    child: Text(
                      Translations.of(context).edited,
                      style: TextStyle(
                          color: alignment == BubbleAlignment.right
                              ? colorPalette.white
                              : colorPalette.neutral600,
                          fontSize: typography.caption2?.regular?.fontSize,
                          fontWeight: typography.caption2?.regular?.fontWeight,
                          fontFamily: typography.caption2?.regular?.fontFamily),
                    ),
                  ),
                _getTime(
                  message,
                  colorPalette,
                  typography,
                  alignment,
                  dateStyle,
                ),
                if (alignment == BubbleAlignment.right &&
                    (receiptsVisibility ?? true))
                  _getReceiptIcon(message, colorPalette, spacing, receiptStyle),
              ],
            ),
          ),
        ],
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
    CometChatMessageBubbleStyleData? messageBubbleStyleData,
  ) {
    if (message.sender != null &&
        message.receiver != null &&
        message.receiver is Group &&
        alignment == BubbleAlignment.left) {
      if (template?.headerView != null) {
        return template?.headerView!(message, context, alignment);
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _getName(
                alignment,
                message,
                context,
                colorPalette,
                typography,
                spacing,
                template,
                messageBubbleStyleData,
              ),
            ],
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
    CometChatMessageBubbleStyleData? messageBubbleStyleData,
  ) {
    return Container(
      padding: EdgeInsets.only(
        right: spacing.padding2 ?? 0,
        left: spacing.padding2 ?? 0,
      ),
      width: MediaQuery.of(context).size.width * 0.65,
      child: Text(
        message.sender!.name,
        style: TextStyle(
          fontSize: typography.caption1?.medium?.fontSize,
          color: colorPalette.primary,
          fontWeight: typography.caption1?.medium?.fontWeight,
          fontFamily: typography.caption1?.medium?.fontFamily,
          letterSpacing: 0,
        ).merge(messageBubbleStyleData?.senderNameTextStyle),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static Widget _getTime(
      BaseMessage messageObject,
      CometChatColorPalette? colorPalette,
      CometChatTypography? typography,
      BubbleAlignment alignment,
      CometChatDateStyle? dateStyle) {
    if (messageObject.sentAt == null) {
      return const SizedBox();
    }

    DateTime lastMessageTime = messageObject.sentAt!;
    return CometChatDate(
      date: lastMessageTime,
      pattern: DateTimePattern.timeFormat,
      isTransparentBackground: true,
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
        border: Border.all(
          color: Colors.transparent,
          width: 0,
        ),
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
      padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
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
      CometChatSpacing spacing) {
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
                ?.deletedBubbleStyle?.threadedMessageIndicatorIconColor
            : incomingMessageBubbleStyle
                ?.deletedBubbleStyle?.threadedMessageIndicatorIconColor,
        messageBubbleAvatarStyle: isSent
            ? outgoingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleAvatarStyle
            : incomingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleAvatarStyle,
        senderNameTextStyle:
            incomingMessageBubbleStyle?.deletedBubbleStyle?.senderNameTextStyle,
        messageReceiptStyle:
            outgoingMessageBubbleStyle?.deletedBubbleStyle?.messageReceiptStyle,
        messageBubbleDateStyle: isSent
            ? outgoingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleDateStyle
            : incomingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleDateStyle,
        messageBubbleBackgroundImage: isSent
            ? outgoingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleBackgroundImage
            : incomingMessageBubbleStyle
                ?.deletedBubbleStyle?.messageBubbleBackgroundImage,
        threadedMessageIndicatorTextStyle: isSent
            ? outgoingMessageBubbleStyle
                ?.deletedBubbleStyle?.threadedMessageIndicatorTextStyle
            : incomingMessageBubbleStyle
                ?.deletedBubbleStyle?.threadedMessageIndicatorTextStyle,
      );
    }

    String key = "${message.category}${message.type}";
    if (key ==
            MessageCategoryConstants.action +
                MessageTypeConstants.groupActions ||
        key == MessageCategoryConstants.call + CallTypeConstants.audioCall ||
        key == MessageCategoryConstants.call + CallTypeConstants.videoCall) {
      return CometChatMessageBubbleStyleData(
          backgroundColor: colorPalette.transparent);
    }
    CometChatMessageBubbleStyleData? messageBubbleStyleData;
    switch (key) {
      case const (MessageCategoryConstants.agentic + MessageTypeConstants.assistant):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: incomingMessageBubbleStyle
                  ?.aiAssistantBubbleStyle?.backgroundColor ??
              colorPalette.transparent,
          border: incomingMessageBubbleStyle?.aiAssistantBubbleStyle?.border,
          borderRadius: incomingMessageBubbleStyle
                  ?.aiAssistantBubbleStyle?.borderRadius ??
              BorderRadius.circular(0),
          messageBubbleAvatarStyle: incomingMessageBubbleStyle
              ?.aiAssistantBubbleStyle?.messageBubbleAvatarStyle,
          messageBubbleBackgroundImage: incomingMessageBubbleStyle
              ?.aiAssistantBubbleStyle?.messageBubbleBackgroundImage,
        );
        break;
      case const (MessageCategoryConstants.streamMessage +
          MessageTypeConstants.runStarted):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: incomingMessageBubbleStyle
                  ?.aiAssistantBubbleStyle?.backgroundColor ??
              colorPalette.transparent,
          border: incomingMessageBubbleStyle?.aiAssistantBubbleStyle?.border,
          borderRadius:
              incomingMessageBubbleStyle?.aiAssistantBubbleStyle?.borderRadius,
          messageBubbleAvatarStyle: incomingMessageBubbleStyle
              ?.aiAssistantBubbleStyle?.messageBubbleAvatarStyle,
          messageBubbleBackgroundImage: incomingMessageBubbleStyle
              ?.aiAssistantBubbleStyle?.messageBubbleBackgroundImage,
        );
        break;
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
                  spacing)
              : incomingMessageBubbleStyle?.textBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.textBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.textBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.textBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.textBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.textBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.textBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.textBubbleStyle?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message + MessageTypeConstants.image):
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
                  spacing)
              : incomingMessageBubbleStyle?.imageBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.imageBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.imageBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.imageBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.imageBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.imageBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.imageBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.imageBubbleStyle?.threadedMessageIndicatorTextStyle,
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
              spacing)
              : incomingMessageBubbleStyle?.fileBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.fileBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.fileBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.fileBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.fileBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.fileBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.fileBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.fileBubbleStyle?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message + MessageTypeConstants.video):
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
              spacing)
              : incomingMessageBubbleStyle?.videoBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.videoBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.videoBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.videoBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.videoBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.videoBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.videoBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.videoBubbleStyle?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.message + MessageTypeConstants.audio):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle?.audioBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle?.audioBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle?.audioBubbleStyle?.border
              : incomingMessageBubbleStyle?.audioBubbleStyle?.border,
          borderRadius: isSent
              ? getSentTextMediaBorderRadiusGeometry(
              message,
              outgoingMessageBubbleStyle?.audioBubbleStyle?.borderRadius,
              colorPalette,
              typography,
              spacing)
              : incomingMessageBubbleStyle?.audioBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.audioBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.audioBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.audioBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.audioBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.audioBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.audioBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.audioBubbleStyle?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.extensionPoll):
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
                  ?.pollsBubbleStyle?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle
                  ?.pollsBubbleStyle?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle:
              incomingMessageBubbleStyle?.pollsBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle:
              outgoingMessageBubbleStyle?.pollsBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle
                  ?.pollsBubbleStyle?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.pollsBubbleStyle?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle
                  ?.pollsBubbleStyle?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.document):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.border
              : incomingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.borderRadius
              : incomingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.collaborativeDocumentBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.collaborativeDocumentBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.collaborativeDocumentBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle?.collaborativeDocumentBubbleStyle
                  ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.whiteboard):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
          backgroundColor: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.backgroundColor
              : incomingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.backgroundColor,
          border: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.border
              : incomingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.border,
          borderRadius: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.borderRadius
              : incomingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.borderRadius,
          threadedMessageIndicatorIconColor: isSent
              ? outgoingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.threadedMessageIndicatorIconColor
              : incomingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.threadedMessageIndicatorIconColor,
          messageBubbleAvatarStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.messageBubbleAvatarStyle
              : incomingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.messageBubbleAvatarStyle,
          senderNameTextStyle: incomingMessageBubbleStyle
              ?.collaborativeWhiteboardBubbleStyle?.senderNameTextStyle,
          messageReceiptStyle: outgoingMessageBubbleStyle
              ?.collaborativeWhiteboardBubbleStyle?.messageReceiptStyle,
          messageBubbleDateStyle: isSent
              ? outgoingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.messageBubbleDateStyle
              : incomingMessageBubbleStyle
                  ?.collaborativeWhiteboardBubbleStyle?.messageBubbleDateStyle,
          messageBubbleBackgroundImage: isSent
              ? outgoingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.messageBubbleBackgroundImage
              : incomingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.messageBubbleBackgroundImage,
          threadedMessageIndicatorTextStyle: isSent
              ? outgoingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.threadedMessageIndicatorTextStyle
              : incomingMessageBubbleStyle?.collaborativeWhiteboardBubbleStyle
                  ?.threadedMessageIndicatorTextStyle,
        );
        break;
      case const (MessageCategoryConstants.custom + ExtensionType.sticker):
        messageBubbleStyleData = CometChatMessageBubbleStyleData(
            backgroundColor: (isSent ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.backgroundColor : incomingMessageBubbleStyle?.stickerBubbleStyle?.backgroundColor) ??
                ((message.quotedMessage != null)
                    ? (message.sender?.uid == CometChatUIKit.loggedInUser?.uid
                        ? colorPalette.primary ?? Colors.transparent
                        : colorPalette.neutral300 ?? Colors.transparent)
                    : colorPalette.transparent),
            border: isSent
                ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.border
                : incomingMessageBubbleStyle?.stickerBubbleStyle?.border,
            borderRadius: isSent
                ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.borderRadius
                : incomingMessageBubbleStyle?.stickerBubbleStyle?.borderRadius,
            threadedMessageIndicatorIconColor: isSent
                ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle?.threadedMessageIndicatorIconColor
                : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle?.threadedMessageIndicatorIconColor,
            messageBubbleAvatarStyle: isSent
                ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleAvatarStyle
                : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleAvatarStyle,
            senderNameTextStyle: incomingMessageBubbleStyle
                ?.stickerBubbleStyle?.senderNameTextStyle,
            messageReceiptStyle: outgoingMessageBubbleStyle
                ?.stickerBubbleStyle?.messageReceiptStyle,
            messageBubbleDateStyle: isSent
                ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleDateStyle
                : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleDateStyle,
            messageBubbleBackgroundImage: isSent
                ? outgoingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleBackgroundImage
                : incomingMessageBubbleStyle
                    ?.stickerBubbleStyle?.messageBubbleBackgroundImage,
            threadedMessageIndicatorTextStyle: isSent
                ? outgoingMessageBubbleStyle?.stickerBubbleStyle?.threadedMessageIndicatorTextStyle
                : incomingMessageBubbleStyle?.stickerBubbleStyle?.threadedMessageIndicatorTextStyle);
        break;
      case const (MessageCategoryConstants.custom + MessageTypeConstants.meeting):
        CustomMessage msg = message as CustomMessage;
        String? callType;
        if (msg.customData != null &&
            msg.customData?.containsKey('callType') == true) {
          callType = msg.customData?['callType'];
        }
        if (callType == CallTypeConstants.audioCall) {
          messageBubbleStyleData = CometChatMessageBubbleStyleData(
              backgroundColor: isSent
                  ? outgoingMessageBubbleStyle?.voiceCallBubbleStyle?.backgroundColor ??
                      colorPalette.primary
                  : incomingMessageBubbleStyle
                          ?.voiceCallBubbleStyle?.backgroundColor ??
                      colorPalette.neutral300,
              border: isSent
                  ? outgoingMessageBubbleStyle?.voiceCallBubbleStyle?.border
                  : incomingMessageBubbleStyle?.voiceCallBubbleStyle?.border,
              borderRadius: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.borderRadius
                  : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.borderRadius,
              threadedMessageIndicatorIconColor: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.threadedMessageIndicatorIconColor
                  : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.threadedMessageIndicatorIconColor,
              messageBubbleAvatarStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleAvatarStyle
                  : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleAvatarStyle,
              senderNameTextStyle: incomingMessageBubbleStyle
                  ?.voiceCallBubbleStyle?.senderNameTextStyle,
              messageReceiptStyle: outgoingMessageBubbleStyle
                  ?.voiceCallBubbleStyle?.messageReceiptStyle,
              messageBubbleDateStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleDateStyle
                  : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleDateStyle,
              messageBubbleBackgroundImage: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleBackgroundImage
                  : incomingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.messageBubbleBackgroundImage,
              threadedMessageIndicatorTextStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.voiceCallBubbleStyle?.threadedMessageIndicatorTextStyle
                  : incomingMessageBubbleStyle?.voiceCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle);
        } else {
          messageBubbleStyleData = CometChatMessageBubbleStyleData(
              backgroundColor: isSent
                  ? outgoingMessageBubbleStyle?.videoCallBubbleStyle?.backgroundColor ??
                      colorPalette.primary
                  : incomingMessageBubbleStyle
                          ?.videoCallBubbleStyle?.backgroundColor ??
                      colorPalette.neutral300,
              border: isSent
                  ? outgoingMessageBubbleStyle?.videoCallBubbleStyle?.border
                  : incomingMessageBubbleStyle?.videoCallBubbleStyle?.border,
              borderRadius: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.borderRadius
                  : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.borderRadius,
              threadedMessageIndicatorIconColor: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.threadedMessageIndicatorIconColor
                  : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.threadedMessageIndicatorIconColor,
              messageBubbleAvatarStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleAvatarStyle
                  : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleAvatarStyle,
              senderNameTextStyle: incomingMessageBubbleStyle
                  ?.videoCallBubbleStyle?.senderNameTextStyle,
              messageReceiptStyle: outgoingMessageBubbleStyle
                  ?.videoCallBubbleStyle?.messageReceiptStyle,
              messageBubbleDateStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleDateStyle
                  : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleDateStyle,
              messageBubbleBackgroundImage: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleBackgroundImage
                  : incomingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.messageBubbleBackgroundImage,
              threadedMessageIndicatorTextStyle: isSent
                  ? outgoingMessageBubbleStyle
                      ?.videoCallBubbleStyle?.threadedMessageIndicatorTextStyle
                  : incomingMessageBubbleStyle?.videoCallBubbleStyle
                      ?.threadedMessageIndicatorTextStyle);
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
      CometChatActionBubbleStyle? actionBubbleStyle2) {
    AdditionalConfigurations? additionalConfigurations;
    final outgoingMessageBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatOutgoingMessageBubbleStyle>(
                context: context,
                defaultTheme: CometChatOutgoingMessageBubbleStyle.of)
            .merge(outgoingMessageBubbleStyle2);
    final incomingMessageBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatIncomingMessageBubbleStyle>(
                context: context,
                defaultTheme: CometChatIncomingMessageBubbleStyle.of)
            .merge(incomingMessageBubbleStyle2);
    bool isSent = message.sender?.uid == CometChatUIKit.loggedInUser?.uid;

    final actionBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatActionBubbleStyle>(
                context: context, defaultTheme: CometChatActionBubbleStyle.of)
            .merge(actionBubbleStyle2);

    List<CometChatTextFormatter> textFormatters =
        BubbleUIBuilder.getTextFormatters(message, formatters ?? []);

    additionalConfigurations = AdditionalConfigurations(
        textFormatters: textFormatters,
        textBubbleStyle: (isSent ? outgoingMessageBubbleStyle.textBubbleStyle : incomingMessageBubbleStyle.textBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        imageBubbleStyle: (isSent ? outgoingMessageBubbleStyle.imageBubbleStyle : incomingMessageBubbleStyle.imageBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        fileBubbleStyle: (isSent ? outgoingMessageBubbleStyle.fileBubbleStyle : incomingMessageBubbleStyle.fileBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        videoBubbleStyle: (isSent ? outgoingMessageBubbleStyle.videoBubbleStyle : incomingMessageBubbleStyle.videoBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        audioBubbleStyle: (isSent ? outgoingMessageBubbleStyle.audioBubbleStyle : incomingMessageBubbleStyle.audioBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        collaborativeDocumentBubbleStyle: (isSent
                ? outgoingMessageBubbleStyle.collaborativeDocumentBubbleStyle
                : incomingMessageBubbleStyle.collaborativeDocumentBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        collaborativeWhiteboardBubbleStyle: (isSent
                ? outgoingMessageBubbleStyle.collaborativeWhiteboardBubbleStyle
                : incomingMessageBubbleStyle.collaborativeWhiteboardBubbleStyle)
            ?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        pollsBubbleStyle: (isSent ? outgoingMessageBubbleStyle.pollsBubbleStyle : incomingMessageBubbleStyle.pollsBubbleStyle)?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        actionBubbleStyle: actionBubbleStyle,
        deletedBubbleStyle: (isSent ? outgoingMessageBubbleStyle.deletedBubbleStyle : incomingMessageBubbleStyle.deletedBubbleStyle)?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        linkPreviewBubbleStyle: isSent ? outgoingMessageBubbleStyle.linkPreviewBubbleStyle : incomingMessageBubbleStyle.linkPreviewBubbleStyle,
        messageTranslationBubbleStyle: isSent ? outgoingMessageBubbleStyle.messageTranslationBubbleStyle : incomingMessageBubbleStyle.messageTranslationBubbleStyle,
        stickerBubbleStyle: (isSent ? outgoingMessageBubbleStyle.stickerBubbleStyle : incomingMessageBubbleStyle.stickerBubbleStyle)?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        voiceCallBubbleStyle: (isSent ? outgoingMessageBubbleStyle.voiceCallBubbleStyle : incomingMessageBubbleStyle.voiceCallBubbleStyle)?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        videoCallBubbleStyle: (isSent ? outgoingMessageBubbleStyle.videoCallBubbleStyle : incomingMessageBubbleStyle.videoCallBubbleStyle)?.copyWith(border: Border.all(color: Colors.transparent, width: 0)),
        aiAssistantBubbleStyle: incomingMessageBubbleStyle.aiAssistantBubbleStyle,
        messagePreviewStyle: (isSent ? outgoingMessageBubbleStyle.messagePreviewStyle : incomingMessageBubbleStyle.messagePreviewStyle));

    return additionalConfigurations;
  }

  static List<CometChatTextFormatter> getTextFormatters(
      BaseMessage message, List<CometChatTextFormatter> textFormatters) {
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
      CometChatSpacing spacing) {
    final moderationUtil = ModerationCheckUtil.instance;
    if (message.metadata != null &&
        (message.metadata!.containsValue(ErrorConstants.fileErrorCodeAndroid) || message.metadata!.containsValue(ErrorConstants.fileErrorCodeIOS))) {
      return BorderRadius.only(
        topLeft: Radius.circular(spacing.radius4 ?? 16),
        topRight: Radius.circular(spacing.radius4 ?? 16),
      );
    }
    if (moderationUtil.hideModerationStatus == false &&
        ModerationCheckUtil.instance
            .isMessageDisapprovedFromModeration(message)) {
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
      threadedMessageIndicatorTextStyle: threadedMessageIndicatorTextStyle ??
          this.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor: threadedMessageIndicatorIconColor ??
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
      CometChatMessageBubbleStyleData? other) {
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
      CometChatMessageBubbleStyleData? other) {
    if (other == null) return this;
    return copyWith(
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? other.messageBubbleBackgroundImage,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      border: border ?? other.border,
      borderRadius: borderRadius ?? other.borderRadius,
      threadedMessageIndicatorTextStyle: threadedMessageIndicatorTextStyle ??
          other.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor: threadedMessageIndicatorIconColor ??
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
      exceptionBackgroundColor: exceptionBackgroundColor ?? other.exceptionBackgroundColor,
      exceptionTextStyle: exceptionTextStyle ?? other.exceptionTextStyle,
      exceptionIconTint: exceptionIconTint ?? other.exceptionIconTint,
    );
  }
}
