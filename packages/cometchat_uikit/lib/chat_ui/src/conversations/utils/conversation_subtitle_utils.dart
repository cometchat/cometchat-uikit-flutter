import 'package:flutter/material.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart' as cc;

/// Utility class for building conversation subtitle widgets.
/// These methods are only used by the conversations module.
class ConversationSubtitleUtils {
  static String getLastConversationMessage(
    Conversation conversation,
    BuildContext context,
  ) {
    return ConversationUtils.getLastConversationMessage(conversation, context);
  }

  static Widget getLastConversationWidget(
    Conversation conversation,
    BuildContext context,
    Color? iconColor,
  ) {
    return ConversationUtils.getLastConversationIcon(
      conversation,
      context,
      iconColor,
    );
  }

  static Widget getConversationSubtitle(
    Conversation conversation,
    BuildContext context,
    TextStyle? subtitleStyle,
    Color? iconColor, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    TextStyle subtitleStyle0 = TextStyle(
      overflow: TextOverflow.ellipsis,
      color: colorPalette.textSecondary,
      fontSize: typography.body?.regular?.fontSize,
      fontWeight: typography.body?.regular?.fontWeight,
      fontFamily: typography.body?.regular?.fontFamily,
      letterSpacing: 0,
    ).merge(subtitleStyle);

    BaseMessage? lastMessage = conversation.lastMessage;
    String? messageCategory = lastMessage?.category;

    final spacing = CometChatThemeHelper.getSpacing(context);

    if (messageCategory == null || lastMessage == null) {
      return Text(
        Translations.of(context).tapToStartConversation,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: subtitleStyle0,
      );
    } else if (lastMessage.deletedBy != null &&
        lastMessage.deletedBy!.trim() != '') {
      return Row(
        children: [
          Icon(
            Icons.block,
            color: iconColor ?? colorPalette.iconSecondary,
            size: 16,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: spacing.padding ?? 0),
              child: Text(
                Translations.of(context).thisMessageDeleted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle0,
              ),
            ),
          ),
        ],
      );
    } else {
      String? prefix;
      if (conversation.conversationWith is Group) {
        if ((lastMessage.category == MessageCategoryConstants.action &&
                lastMessage.type == MessageTypeConstants.groupActions) ||
            (lastMessage.category == MessageCategoryConstants.custom &&
                lastMessage.type == MessageTypeConstants.meeting)) {
          prefix = "";
        } else if (lastMessage.sender?.uid !=
            CometChatUIKit.loggedInUser?.uid) {
          prefix = "${lastMessage.sender?.name}: ";
        } else {
          prefix = "${cc.Translations.of(context).you}: ";
        }
      }

      // A media message with a caption renders its preview with markdown /
      // mentions (like the search list), while keeping the leading type icon.
      // (Text messages keep their own formatted path below, which formats the
      // RAW text rather than the markdown-stripped preview string.)
      final bool formatMediaCaption =
          additionalConfigurations?.textFormatters != null &&
          additionalConfigurations!.textFormatters!.isNotEmpty &&
          lastMessage is MediaMessage &&
          (lastMessage.caption?.trim().isNotEmpty ?? false);

      Widget previewText() {
        final preview = getLastConversationMessage(conversation, context);
        if (!formatMediaCaption) {
          return Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle0,
          );
        }
        final formatters = additionalConfigurations.textFormatters!;
        for (final f in formatters) {
          if (f is CometChatMentionsFormatter) f.message = lastMessage;
        }
        return RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: subtitleStyle0,
            children: FormatterUtils.buildTextSpan(
              preview,
              formatters,
              context,
              BubbleAlignment.left,
              forConversation: true,
              textStyle: subtitleStyle0,
            ),
          ),
          textScaler: MediaQuery.textScalerOf(context),
        );
      }

      if (additionalConfigurations != null &&
          additionalConfigurations.textFormatters != null &&
          additionalConfigurations.textFormatters!.isNotEmpty &&
          lastMessage is TextMessage) {
        String text = (lastMessage).text;

        return RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            text: prefix,
            style: subtitleStyle0,
            children: FormatterUtils.buildTextSpan(
              text,
              additionalConfigurations.textFormatters,
              context,
              BubbleAlignment.left,
              forConversation: true,
              textStyle: subtitleStyle0,
            ),
          ),
          textScaler: MediaQuery.textScalerOf(context),
        );
      } else {
        Widget? icon;

        if (prefix != null && prefix.isNotEmpty) {
          icon = getLastConversationWidget(conversation, context, iconColor);
          return Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: EdgeInsets.only(left: spacing.padding ?? 0),
                  child: Text(
                    prefix,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle0,
                  ),
                ),
              ),
              icon,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: spacing.padding ?? 0),
                  child: previewText(),
                ),
              ),
            ],
          );
        }

        icon = getLastConversationWidget(conversation, context, iconColor);
        return Row(
          children: [
            icon,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: spacing.padding ?? 0),
                child: previewText(),
              ),
            ),
          ],
        );
      }
    }
  }
}
