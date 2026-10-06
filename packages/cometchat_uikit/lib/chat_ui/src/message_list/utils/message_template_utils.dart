import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart' as cc;
import '../../../../call_ui/src/call_bubble/cometchat_call_bubble.dart';
import '../../../../call_ui/src/calling_configuration.dart';
import '../../../../call_ui/src/utils/call_utils.dart';
import '../../../../call_ui/src/utils/call_extension_constants.dart';
import '../../../../call_ui/src/ongoing_call/call_screen_overlay.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/calling_configuration_resolver.dart';
import '../../../../src/meeting_session_settings.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettingsBuilder;
import '../../extensions/extension_constants.dart';
import '../../extensions/polls/cometchat_polls_bubble.dart';
import '../../extensions/stickers/cometchat_sticker_bubble.dart';
import '../../extensions/collaborative/cometchat_collaborative_bubble.dart';
import '../../extensions/link_preview/cometchat_link_preview_bubble.dart';
import '../../extensions/message_translation/message_translation_bubble.dart';
import '../widgets/cometchat_card_bubble.dart';
import '../../extensions/extension_moderator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

///[MessageTemplateUtils] provides default templates to construct
///message bubbles and the default set of options for each bubble type.
class MessageTemplateUtils {
  static CometChatMessageOption getEditOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.editMessage,
      title: Translations.of(context).edit,
      icon: Icon(
        Icons.edit_outlined,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getDeleteOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.deleteMessage,
      title: Translations.of(context).delete,
      icon: Image.asset(
        AssetConstants.delete,
        package: UIConstants.packageName,
        height: 24,
        width: 24,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.error,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor ?? colorPalette.error,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getReplyOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.replyMessage,
      title: Translations.of(context).reply,
      icon: Icon(
        Icons.reply,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getReplyInThreadOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.replyInThreadMessage,
      title: Translations.of(context).replyInThread,
      icon: Icon(
        Icons.subdirectory_arrow_right,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  /// Resolves the thread a message's subscription option acts on: the parent
  /// for a reply, the message itself for a root message.
  static int resolveThreadId(BaseMessage messageObject) =>
      messageObject.parentMessageId != 0
      ? messageObject.parentMessageId
      : messageObject.id;

  /// Whether the logged-in user follows this message's thread.
  ///
  /// Stateless redesign: the message object IS the state — the SDK stamps
  /// `threadSubscribed` from every fetch (normalised, never null) and keeps
  /// no cache. Live coherence across surfaces comes from the kit event bus
  /// (`ccThreadSubscriptionChanged` mutates the object in the list bloc), not
  /// from an SDK store. `false` on a socket-delivered message means "the
  /// server did not tell me", which renders as the un-followed affordance —
  /// safe, because subscribing is idempotent.
  static bool isSubscribedToThreadOf(BaseMessage messageObject) {
    return messageObject.threadSubscribed;
  }

  static CometChatMessageOption getThreadSubscriptionOption(
    BuildContext context,
    BaseMessage messageObject,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    // One option id; the title flips on state (mute vocabulary per the
    // landed design). UNKNOWN renders as the muted/get-notifications action —
    // an unnecessary subscribe is harmless (the endpoint is idempotent).
    final bool isSubscribed = isSubscribedToThreadOf(messageObject);
    return CometChatMessageOption(
      id: MessageOptionConstants.threadSubscription,
      title: isSubscribed
          ? Translations.of(context).messageListOptionStopReplyNotifications
          : Translations.of(context).messageListOptionGetReplyNotifications,
      icon: Icon(
        isSubscribed
            ? Icons.notifications_off_outlined
            : Icons.notifications_outlined,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  /// Whether the message is currently pinned to its conversation. Truth is
  /// the message object itself — pin state rides every fetch and the list
  /// rebinds the object on pin/unpin events.
  static bool isMessagePinned(BaseMessage messageObject) =>
      messageObject.pinnedAt != null;

  /// Whether the logged-in user has saved (bookmarked) this message.
  static bool isMessageSaved(BaseMessage messageObject) =>
      messageObject.savedAt != null;

  static CometChatMessageOption getPinOption(
    BuildContext context,
    BaseMessage messageObject,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    // One surface slot; id and title flip on the message's pin state so the
    // handlers can dispatch by id.
    final bool pinned = isMessagePinned(messageObject);
    return CometChatMessageOption(
      id: pinned
          ? MessageOptionConstants.unpinMessage
          : MessageOptionConstants.pinMessage,
      title: pinned
          ? Translations.of(context).unpinMessageOption
          : Translations.of(context).pinMessageOption,
      icon: Icon(
        pinned ? Icons.push_pin : Icons.push_pin_outlined,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getSaveOption(
    BuildContext context,
    BaseMessage messageObject,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    final bool saved = isMessageSaved(messageObject);
    return CometChatMessageOption(
      id: saved
          ? MessageOptionConstants.unsaveMessage
          : MessageOptionConstants.saveMessage,
      title: saved
          ? Translations.of(context).unsaveMessageOption
          : Translations.of(context).saveMessageOption,
      icon: Icon(
        // Plain outlined bookmark either way — the +/- variants read as
        // separate actions rather than one toggle.
        saved ? Icons.bookmark : Icons.bookmark_border,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getShareOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.shareMessage,
      title: Translations.of(context).share,
      icon: Image.asset(
        AssetConstants.shareOutlined,
        package: UIConstants.packageName,
        height: 24,
        width: 24,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  /// The Translate option for a text message: the 文A icon and the
  /// "Translate" title, styled like the other options by
  /// [messageOptionSheetStyle]. The message list runs it, and shows it only
  /// while the `message-translation` extension is enabled.
  static CometChatMessageOption getTranslateOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.translateMessage,
      title: Translations.of(context).translate,
      icon: Image.asset(
        AssetConstants.translate,
        package: UIConstants.packageName,
        height: 24,
        width: 24,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getCopyOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.copyMessage,
      title: Translations.of(context).copy,
      icon: Icon(
        Icons.content_copy,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getMessageInfo(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.messageInformation,
      title: Translations.of(context).info,
      icon: Icon(
        Icons.info_outline,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  // CometChatMessageOption getForwardOption(BuildContext context) {
  //   return CometChatMessageOption(
  //       id: MessageOptionConstants.forwardMessage,
  //       title: Translations.of(context).forward,
  //       icon: AssetConstants.forward,
  //       packageName: UIConstants.packageName);
  // }

  static CometChatMessageOption getSendMessagePrivately(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.sendMessagePrivately,
      title: Translations.of(context).messagePrivately,
      icon: Image.asset(
        AssetConstants.replyPrivately,
        package: UIConstants.packageName,
        height: 24,
        width: 24,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static CometChatMessageOption getMarkAsUnreadOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.markAsUnread,
      title: Translations.of(context).markAsUnread,
      icon: Icon(
        Icons.mark_email_unread_outlined,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static bool isSentByMe(User loggedInUser, BaseMessage message) {
    return loggedInUser.uid == message.sender?.uid;
  }

  static CometChatMessageOption getReportOption(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatMessageOptionSheetStyle? messageOptionSheetStyle,
  ) {
    return CometChatMessageOption(
      id: MessageOptionConstants.reportMessage,
      title: Translations.of(context).report,
      icon: Icon(
        Icons.error_outline,
        color: messageOptionSheetStyle?.iconColor ?? colorPalette.iconSecondary,
        size: 24,
      ),
      messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
        titleTextStyle: TextStyle(
          color: messageOptionSheetStyle?.titleColor,
          fontFamily: typography.body?.regular?.fontFamily,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
        ).merge(messageOptionSheetStyle?.titleTextStyle),
        borderRadius: messageOptionSheetStyle?.borderRadius,
        border: messageOptionSheetStyle?.border,
        backgroundColor: messageOptionSheetStyle?.backgroundColor,
        iconColor: messageOptionSheetStyle?.iconColor,
        titleColor: messageOptionSheetStyle?.titleColor,
      ),
    );
  }

  static List<CometChatMessageOption> getTextMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final style = additionalConfigurations?.messageOptionSheetStyle;

    if (messageObject.sender?.uid == loggedInUser.uid &&
        ModerationCheckUtil.instance.isMessageDisapprovedFromModeration(
          messageObject,
        )) {
      if (additionalConfigurations?.hideCopyMessageOption != true) {
        messageOptionList.add(
          getCopyOption(context, colorPalette, typography, style),
        );
      }

      if (additionalConfigurations?.hideTranslateMessageOption != true &&
          _validateOption(
            loggedInUser,
            messageObject,
            context,
            group,
            MessageOptionConstants.translateMessage,
          )) {
        messageOptionList.add(
          getTranslateOption(context, colorPalette, typography, style),
        );
      }

      if (additionalConfigurations?.hideDeleteMessageOption != true &&
          _validateOption(
            loggedInUser,
            messageObject,
            context,
            group,
            MessageOptionConstants.deleteMessage,
          )) {
        messageOptionList.add(
          getDeleteOption(context, colorPalette, typography, style),
        );
      }

      return messageOptionList;
    }

    if (additionalConfigurations?.hideReplyOption != true) {
      messageOptionList.add(
        getReplyOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideReplyInThreadOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.replyInThreadMessage,
        )) {
      messageOptionList.add(
        getReplyInThreadOption(context, colorPalette, typography, style),
      );
    }

    // Follow/unfollow thread — placed directly after Reply in thread so the
    // two thread actions sit together. Feature-gated (default off): with the
    // gate off, neither thread-subscription surface renders.
    if (CometChatUIKit.authenticationSettings?.enableThreadSubscription ==
            true &&
        additionalConfigurations?.hideThreadSubscriptionOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.threadSubscription,
        )) {
      messageOptionList.add(
        getThreadSubscriptionOption(
          context,
          messageObject,
          colorPalette,
          typography,
          style,
        ),
      );
    }

    // Pin & Save — gated on the server feature flags. The rendered state
    // (pin vs unpin, save vs unsave) comes from the message object; each
    // state has its own hide flag.
    if (CometChat.isPinMessageEnabled() &&
        (isMessagePinned(messageObject)
            ? additionalConfigurations?.hideUnpinMessageOption != true
            : additionalConfigurations?.hidePinMessageOption != true) &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          isMessagePinned(messageObject)
              ? MessageOptionConstants.unpinMessage
              : MessageOptionConstants.pinMessage,
        )) {
      messageOptionList.add(
        getPinOption(context, messageObject, colorPalette, typography, style),
      );
    }

    if (CometChat.isSaveMessageEnabled() &&
        (isMessageSaved(messageObject)
            ? additionalConfigurations?.hideUnsaveMessageOption != true
            : additionalConfigurations?.hideSaveMessageOption != true) &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          isMessageSaved(messageObject)
              ? MessageOptionConstants.unsaveMessage
              : MessageOptionConstants.saveMessage,
        )) {
      messageOptionList.add(
        getSaveOption(context, messageObject, colorPalette, typography, style),
      );
    }
    if (additionalConfigurations?.hideShareMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.shareMessage,
        )) {
      messageOptionList.add(
        getShareOption(context, colorPalette, typography, style),
      );
    }

    // Translate — offered on every text message, own or not, and still
    // after a translation (Android parity). The message list also hides it
    // until the message-translation extension reports enabled.
    if (additionalConfigurations?.hideTranslateMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.translateMessage,
        )) {
      messageOptionList.add(
        getTranslateOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideCopyMessageOption != true) {
      messageOptionList.add(
        getCopyOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideEditMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.editMessage,
        )) {
      messageOptionList.add(
        getEditOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideMessageInfoOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.messageInformation,
        )) {
      messageOptionList.add(
        getMessageInfo(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideDeleteMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.deleteMessage,
        )) {
      messageOptionList.add(
        getDeleteOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideMessagePrivatelyOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.sendMessagePrivately,
        )) {
      messageOptionList.add(
        getSendMessagePrivately(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.showMarkAsUnreadOption == true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.markAsUnread,
        )) {
      messageOptionList.add(
        getMarkAsUnreadOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideFlagOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.reportMessage,
        )) {
      messageOptionList.add(
        getReportOption(context, colorPalette, typography, style),
      );
    }

    return messageOptionList;
  }

  static List<CometChatMessageOption> getImageMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(
      MessageTemplateUtils.getCommonOptions(
        loggedInUser,
        messageObject,
        context,
        group,
        additionalConfigurations,
      ),
    );
    return messageOptionList;
  }

  static List<CometChatMessageOption> getVideoMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(
      MessageTemplateUtils.getCommonOptions(
        loggedInUser,
        messageObject,
        context,
        group,
        additionalConfigurations,
      ),
    );
    return messageOptionList;
  }

  static List<CometChatMessageOption> getAudioMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(
      MessageTemplateUtils.getCommonOptions(
        loggedInUser,
        messageObject,
        context,
        group,
        additionalConfigurations,
      ),
    );
    // messageOptionList.add(getForwardOption(context));
    return messageOptionList;
  }

  static List<CometChatMessageOption> getFileMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    messageOptionList.addAll(
      MessageTemplateUtils.getCommonOptions(
        loggedInUser,
        messageObject,
        context,
        group,
        additionalConfigurations,
      ),
    );
    // messageOptionList.add(getForwardOption(context));
    return messageOptionList;
  }

  static Widget getDeleteMessageBubble(
    BaseMessage messageObject,
    BuildContext context,
    CometChatDeletedBubbleStyle? style,
  ) {
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    final style0 = CometChatThemeHelper.getTheme<CometChatDeletedBubbleStyle>(
      context: context,
      defaultTheme: CometChatDeletedBubbleStyle.of,
    ).merge(style);
    return CometChatDeletedBubble(
      style: CometChatDeletedBubbleStyle(
        iconColor:
            style0.iconColor ??
            (messageObject.sender?.uid == CometChatUIKit.loggedInUser?.uid
                ? colorPalette.white
                : colorPalette.neutral600),
        textColor:
            style0.textColor ??
            (messageObject.sender?.uid == CometChatUIKit.loggedInUser?.uid
                ? colorPalette.white
                : colorPalette.neutral600),
      ).merge(style0),
    );
  }

  static Widget getGroupActionBubble(
    BaseMessage messageObject,
    CometChatActionBubbleStyle? style,
  ) {
    cc.Action actionMessage = messageObject as cc.Action;

    return CometChatActionBubble(text: actionMessage.message, style: style);
  }

  static CometChatMessageTemplate getTextMessageTemplate() {
    return CometChatMessageTemplate(
      // name: MessageTypeConstants.text,
      type: MessageTypeConstants.text,
      category: MessageCategoryConstants.message,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            TextMessage textMessage = message as TextMessage;
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            return MessageTemplateUtils.getTextMessageContentView(
              textMessage,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
      options: MessageTemplateUtils.getMessageOptions,
    );
  }

  static Widget getTextMessageContentView(
    TextMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    final textBubble = MessageTemplateUtils.getTextMessageBubble(
      message.text,
      message,
      context,
      alignment,
      additionalConfigurations?.textBubbleStyle,
      additionalConfigurations?.textFormatters,
    );

    // Check for link preview extension data in message metadata
    final extensionMap = ExtensionModerator.extensionCheck(message);
    if (extensionMap != null &&
        extensionMap.containsKey(ExtensionConstants.linkPreview)) {
      final linkPreviewData = extensionMap[ExtensionConstants.linkPreview];
      if (linkPreviewData != null && linkPreviewData['links'] != null) {
        final List<dynamic> links = linkPreviewData['links'];
        if (links.isNotEmpty) {
          final linkPreview = CometChatLinkPreviewBubble(
            links: links,
            style: additionalConfigurations?.linkPreviewBubbleStyle,
            alignment: alignment,
            onTapUrl: (url) async {
              if (!RegExp(r'^(https?:\/\/)').hasMatch(url)) {
                url = 'https://$url';
              }
              await launchUrl(Uri.parse(url));
            },
            child: textBubble,
          );
          return _withTranslation(
            message,
            alignment,
            additionalConfigurations,
            linkPreview,
          );
        }
      }
    }

    return _withTranslation(
      message,
      alignment,
      additionalConfigurations,
      textBubble,
    );
  }

  /// [content] under nothing, or — once the Translate option has stored a
  /// translation in `metadata['translated_message']` — above a separator
  /// and the translation, with mentions shown as `@name`.
  static Widget _withTranslation(
    TextMessage message,
    BubbleAlignment alignment,
    AdditionalConfigurations? additionalConfigurations,
    Widget content,
  ) {
    final translated = message.metadata?['translated_message'];
    if (translated is! String || translated.isEmpty) return content;
    return MessageTranslationBubble(
      translatedText: message.mentionedUsers.isEmpty
          ? translated
          : CometChatMentionsFormatter.getTextWithMentions(
              translated,
              message.mentionedUsers,
            ),
      alignment: alignment,
      style: additionalConfigurations?.messageTranslationBubbleStyle,
      child: content,
    );
  }

  static CometChatMessageTemplate getAudioMessageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.audio,
      category: MessageCategoryConstants.message,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            MediaMessage audioMessage = message as MediaMessage;
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            return MessageTemplateUtils.getAudioMessageContentView(
              audioMessage,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
      options: MessageTemplateUtils.getMessageOptions,
    );
  }

  static CometChatMessageTemplate getVideoMessageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.video,
      category: MessageCategoryConstants.message,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            return MessageTemplateUtils.getVideoMessageContentView(
              message as MediaMessage,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
      options: MessageTemplateUtils.getMessageOptions,
    );
  }

  static CometChatMessageTemplate getImageMessageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.image,
      category: MessageCategoryConstants.message,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            return MessageTemplateUtils.getImageMessageContentView(
              message as MediaMessage,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
      options: MessageTemplateUtils.getMessageOptions,
    );
  }

  static CometChatMessageTemplate getGroupActionTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.groupActions,
      category: MessageCategoryConstants.action,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            return getGroupActionBubble(
              message,
              additionalConfigurations?.actionBubbleStyle,
            );
          },
    );
  }

  static CometChatMessageTemplate getDefaultMessageActionsTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.message,
      category: MessageCategoryConstants.action,
    );
  }

  static CometChatMessageTemplate getFileMessageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.file,
      category: MessageCategoryConstants.message,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            return MessageTemplateUtils.getFileMessageContentView(
              message as MediaMessage,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
      options: MessageTemplateUtils.getMessageOptions,
    );
  }

  static CometChatMessageTemplate getFormMessageTemplate() {
    return CometChatMessageTemplate(
      // name: MessageTypeConstants.text,
      type: MessageTypeConstants.form,
      category: MessageCategoryConstants.interactive,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            //TODO: Implement FormMessage ContentView
            // FormMessage formMessage = message as FormMessage;
            // return MessageUIService.getFormMessageContentView(
            //     formMessage, context, alignment, theme);
            return getMessageNotSupportedWidget(message, context);
          },
      //TODO: Implement FormMessage Options
      // options: MessageUIService.getFormMessageOptions,
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => [],
    );
  }

  static CometChatMessageTemplate getSchedulerMessageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.scheduler,
      category: MessageCategoryConstants.interactive,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            //TODO: Implement SchedulerMessage ContentView
            // SchedulerMessage meetingMessage = message as SchedulerMessage;
            // return MessageUIService.getSchedulerMessageContentView(
            //     meetingMessage, context, alignment, theme);
            return getMessageNotSupportedWidget(message, context);
          },
      //TODO: Implement SchedulerMessage Options
      // options: MessageUIService.getSchedulerMessageOptions,
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => [],
    );
  }

  static List<CometChatMessageTemplate> getAllMessageTemplates() {
    List<CometChatMessageTemplate> templates = [
      MessageTemplateUtils.getTextMessageTemplate(),
      MessageTemplateUtils.getImageMessageTemplate(),
      MessageTemplateUtils.getVideoMessageTemplate(),
      MessageTemplateUtils.getAudioMessageTemplate(),
      MessageTemplateUtils.getFileMessageTemplate(),
      MessageTemplateUtils.getGroupActionTemplate(),
      MessageTemplateUtils.getFormMessageTemplate(),
      MessageTemplateUtils.getCardMessageTemplate(),
      MessageTemplateUtils.getCardBubbleTemplate(),
      MessageTemplateUtils.getSchedulerMessageTemplate(),
      MessageTemplateUtils.getPollMessageTemplate(),
      MessageTemplateUtils.getStickerMessageTemplate(),
      MessageTemplateUtils.getCollaborativeDocumentTemplate(),
      MessageTemplateUtils.getCollaborativeWhiteboardTemplate(),
    ];
    if (CometChatUIKit.authenticationSettings?.enableCalls == true) {
      templates.add(_getGroupCallTemplate());
      templates.add(_getDefaultVoiceCallTemplate());
      templates.add(_getDefaultVideoCallTemplate());
    }
    // AI message templates
    templates.add(getAIAssistantMessageTemplate());
    templates.add(getStreamMessageTemplate());
    return templates;
  }

  static CometChatMessageTemplate? getMessageTemplate({
    required String messageType,
    required String messageCategory,
  }) {
    CometChatMessageTemplate? template;
    if (messageCategory == MessageCategoryConstants.call) {
      // Handle call message templates
      if (CometChatUIKit.authenticationSettings?.enableCalls == true) {
        switch (messageType) {
          case CallTypeConstants.audioCall:
            template = _getDefaultVoiceCallTemplate();
            break;
          case CallTypeConstants.videoCall:
            template = _getDefaultVideoCallTemplate();
            break;
        }
      }
    } else if (messageCategory == MessageCategoryConstants.custom &&
        messageType == MessageTypeConstants.meeting) {
      if (CometChatUIKit.authenticationSettings?.enableCalls == true) {
        template = _getGroupCallTemplate();
      }
    } else if (messageCategory == MessageCategoryConstants.custom) {
      switch (messageType) {
        case ExtensionType.extensionPoll:
          template = MessageTemplateUtils.getPollMessageTemplate();
          break;
        case ExtensionType.sticker:
          template = MessageTemplateUtils.getStickerMessageTemplate();
          break;
        case ExtensionType.document:
          template = MessageTemplateUtils.getCollaborativeDocumentTemplate();
          break;
        case ExtensionType.whiteboard:
          template = MessageTemplateUtils.getCollaborativeWhiteboardTemplate();
          break;
      }
    } else if (messageCategory != MessageCategoryConstants.call) {
      if (messageCategory == MessageCategoryConstants.interactive) {
        switch (messageType) {
          case MessageTypeConstants.card:
            template = MessageTemplateUtils.getCardMessageTemplate();
            break;
          case MessageTypeConstants.form:
            template = MessageTemplateUtils.getFormMessageTemplate();
            break;
        }
      } else {
        switch (messageType) {
          case MessageTypeConstants.text:
            template = MessageTemplateUtils.getTextMessageTemplate();
            break;
          case MessageTypeConstants.image:
            template = MessageTemplateUtils.getImageMessageTemplate();
            break;
          case MessageTypeConstants.video:
            template = MessageTemplateUtils.getVideoMessageTemplate();
            break;
          case MessageTypeConstants.groupActions:
            template = MessageTemplateUtils.getGroupActionTemplate();
            break;
          case MessageTypeConstants.file:
            template = MessageTemplateUtils.getFileMessageTemplate();
            break;
          case MessageTypeConstants.audio:
            template = MessageTemplateUtils.getAudioMessageTemplate();
            break;
        }
      }
    }

    return template;
  }

  static List<CometChatMessageOption> getMessageOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> optionList = [];
    if (messageObject.category == MessageCategoryConstants.message) {
      switch (messageObject.type) {
        case MessageTypeConstants.text:
          optionList = MessageTemplateUtils.getTextMessageOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          );
          break;
        case MessageTypeConstants.image:
          optionList = MessageTemplateUtils.getImageMessageOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          );
          break;
        case MessageTypeConstants.video:
          optionList = MessageTemplateUtils.getVideoMessageOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          );
          break;
        case MessageTypeConstants.groupActions:
          optionList = [];
          break;
        case MessageTypeConstants.file:
          optionList = MessageTemplateUtils.getFileMessageOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          );
          break;
        case MessageTypeConstants.audio:
          optionList = MessageTemplateUtils.getAudioMessageOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          );
          break;
      }
    } else if (messageObject.category == MessageCategoryConstants.custom) {
      optionList = MessageTemplateUtils.getCommonOptions(
        loggedInUser,
        messageObject,
        context,
        group,
        additionalConfigurations,
      );
    }
    return optionList;
  }

  static bool _validateOption(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    String optionId,
  ) {
    if (MessageOptionConstants.replyInThreadMessage == optionId &&
        messageObject.parentMessageId == 0) {
      return true;
    }

    // The thread-notification option shows on every message (landed design):
    // on a top-level message it targets that message's thread, on a reply it
    // targets the parent thread. Never gated on replyCount — muting/unmuting
    // a message with zero replies is legitimate.
    if (MessageOptionConstants.threadSubscription == optionId) {
      return true;
    }

    if (MessageOptionConstants.shareMessage == optionId &&
        (messageObject is TextMessage || messageObject is MediaMessage)) {
      return true;
    }

    if (MessageOptionConstants.copyMessage == optionId &&
        messageObject is TextMessage) {
      return true;
    }

    // Translate needs the text and a sent message: the extension is keyed by
    // the message id.
    if (MessageOptionConstants.translateMessage == optionId) {
      return messageObject is TextMessage && messageObject.id != 0;
    }

    // Pin & Save eligibility: any real, non-deleted message — including
    // thread replies. Save is per-viewer and unrestricted; pin additionally
    // needs SBAC (below). Action/unsent/moderation-pending messages never
    // reach here (the assemblers early-return for those).
    final bool isRealMessage =
        messageObject.id != 0 && messageObject.deletedAt == null;

    if ((MessageOptionConstants.saveMessage == optionId ||
            MessageOptionConstants.unsaveMessage == optionId) &&
        isRealMessage) {
      return true;
    }

    bool isSendMyMeOption = isSentByMe(loggedInUser, messageObject);

    // Pin eligibility: any real message. Pin permission is deliberately NOT
    // decided here — the server owns it.
    //
    // This used to mirror delete's scope rule (owner or admin/moderator only),
    // but that hardcoded a policy the backend never told us: no permission
    // data is served for pinning (no capability on Group, no scope key in the
    // /me `features.ux.messages.pinned.*` family — only `enabled` and
    // `limit`). So an app whose server grants participants pin rights got the
    // option silently withheld, with no error to explain it — a false
    // negative the user could not discover or work around.
    //
    // Offering it and letting the server arbitrate makes the failure visible
    // instead: an unauthorized pin returns ERR_UNAUTHORIZED / ERR_FORBIDDEN /
    // ERR_PERMISSION_DENIED, which the list maps to the "no permission" toast.
    // Restore a client-side rule here only when the backend serves the policy
    // to check against.
    if (MessageOptionConstants.pinMessage == optionId ||
        MessageOptionConstants.unpinMessage == optionId) {
      return isRealMessage;
    }

    if (MessageOptionConstants.messageInformation == optionId &&
        isSendMyMeOption) {
      return true;
    }

    bool memberIsNotParticipant =
        (group != null) &&
        ((group.owner == loggedInUser.uid) ||
            (group.scope != GroupMemberScope.participant));

    if (MessageOptionConstants.deleteMessage == optionId &&
        (isSendMyMeOption == true || memberIsNotParticipant == true)) {
      return true;
    }

    if (MessageOptionConstants.editMessage == optionId &&
        (isSendMyMeOption == true || memberIsNotParticipant == true)) {
      return true;
    }

    if (MessageOptionConstants.copyMessage == optionId &&
        messageObject is TextMessage) {
      return true;
    }

    if (MessageOptionConstants.sendMessagePrivately == optionId &&
        group != null &&
        loggedInUser.uid != messageObject.sender?.uid) {
      return true;
    }

    if (MessageOptionConstants.reportMessage == optionId &&
        loggedInUser.uid != messageObject.sender?.uid) {
      return true;
    }

    if (MessageOptionConstants.markAsUnread == optionId &&
        loggedInUser.uid != messageObject.sender?.uid &&
        messageObject.parentMessageId == 0) {
      return true;
    }

    return false;
  }

  static List<CometChatMessageOption> getCommonOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    List<CometChatMessageOption> messageOptionList = [];
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final style = additionalConfigurations?.messageOptionSheetStyle;

    // 🚫 Moderation Disapproved: Only return DELETE if allowed
    if (messageObject.sender?.uid == loggedInUser.uid &&
        ModerationCheckUtil.instance.isMessageDisapprovedFromModeration(
          messageObject,
        )) {
      if (additionalConfigurations?.hideDeleteMessageOption != true &&
          _validateOption(
            loggedInUser,
            messageObject,
            context,
            group,
            MessageOptionConstants.deleteMessage,
          )) {
        messageOptionList.add(
          getDeleteOption(context, colorPalette, typography, style),
        );
      }
      return messageOptionList; // ✅ Only delete option is returned
    }

    // Edit is offered on a media message only when it carries a caption
    // (text sent alongside attachments is stored as MediaMessage.caption).
    // Guard on a non-null, non-empty caption so caption-less media isn't
    // given an Edit option that would have nothing to edit.
    final String? caption = messageObject is MediaMessage
        ? messageObject.caption?.trim()
        : null;
    if (caption != null &&
        caption.isNotEmpty &&
        additionalConfigurations?.hideEditMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.editMessage,
        )) {
      messageOptionList.add(
        getEditOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideReplyOption != true) {
      messageOptionList.add(
        getReplyOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideReplyInThreadOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.replyInThreadMessage,
        )) {
      messageOptionList.add(
        getReplyInThreadOption(context, colorPalette, typography, style),
      );
    }

    // Follow/unfollow thread — placed directly after Reply in thread so the
    // two thread actions sit together. Feature-gated (default off): with the
    // gate off, neither thread-subscription surface renders.
    if (CometChatUIKit.authenticationSettings?.enableThreadSubscription ==
            true &&
        additionalConfigurations?.hideThreadSubscriptionOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.threadSubscription,
        )) {
      messageOptionList.add(
        getThreadSubscriptionOption(
          context,
          messageObject,
          colorPalette,
          typography,
          style,
        ),
      );
    }

    // Pin & Save — gated on the server feature flags. The rendered state
    // (pin vs unpin, save vs unsave) comes from the message object; each
    // state has its own hide flag.
    if (CometChat.isPinMessageEnabled() &&
        (isMessagePinned(messageObject)
            ? additionalConfigurations?.hideUnpinMessageOption != true
            : additionalConfigurations?.hidePinMessageOption != true) &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          isMessagePinned(messageObject)
              ? MessageOptionConstants.unpinMessage
              : MessageOptionConstants.pinMessage,
        )) {
      messageOptionList.add(
        getPinOption(context, messageObject, colorPalette, typography, style),
      );
    }

    if (CometChat.isSaveMessageEnabled() &&
        (isMessageSaved(messageObject)
            ? additionalConfigurations?.hideUnsaveMessageOption != true
            : additionalConfigurations?.hideSaveMessageOption != true) &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          isMessageSaved(messageObject)
              ? MessageOptionConstants.unsaveMessage
              : MessageOptionConstants.saveMessage,
        )) {
      messageOptionList.add(
        getSaveOption(context, messageObject, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideShareMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.shareMessage,
        )) {
      messageOptionList.add(
        getShareOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideMessageInfoOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.messageInformation,
        )) {
      messageOptionList.add(
        getMessageInfo(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideDeleteMessageOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.deleteMessage,
        )) {
      messageOptionList.add(
        getDeleteOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideMessagePrivatelyOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.sendMessagePrivately,
        )) {
      messageOptionList.add(
        getSendMessagePrivately(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.showMarkAsUnreadOption == true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.markAsUnread,
        )) {
      messageOptionList.add(
        getMarkAsUnreadOption(context, colorPalette, typography, style),
      );
    }

    if (additionalConfigurations?.hideFlagOption != true &&
        _validateOption(
          loggedInUser,
          messageObject,
          context,
          group,
          MessageOptionConstants.reportMessage,
        )) {
      messageOptionList.add(
        getReportOption(context, colorPalette, typography, style),
      );
    }

    return messageOptionList;
  }

  static List<String> getAllMessageTypes() {
    List<String> types = [
      CometChatMessageType.text,
      CometChatMessageType.image,
      CometChatMessageType.audio,
      CometChatMessageType.video,
      CometChatMessageType.file,
      MessageTypeConstants.groupActions,
      MessageTypeConstants.form,
      MessageTypeConstants.card,
      MessageTypeConstants.scheduler,
      ExtensionType.extensionPoll,
      ExtensionType.sticker,
      ExtensionType.document,
      ExtensionType.whiteboard,
      CometChatMessageType.assistant,
      CometChatMessageType.runStarted,
    ];
    if (CometChatUIKit.authenticationSettings?.enableCalls == true) {
      if (!types.contains(MessageTypeConstants.audio)) {
        types.add(MessageTypeConstants.audio);
      }
      if (!types.contains(MessageTypeConstants.video)) {
        types.add(MessageTypeConstants.video);
      }
      if (!types.contains(MessageTypeConstants.meeting)) {
        types.add(MessageTypeConstants.meeting);
      }
    }
    return types;
  }

  static List<String> getAllMessageCategories() {
    List<String> categories = [
      CometChatMessageCategory.message,
      CometChatMessageCategory.action,
      CometChatMessageCategory.interactive,
      MessageCategoryConstants.custom,
      MessageCategoryConstants.card,
      CometChatMessageCategory.categoryAgentic,
      CometChatMessageCategory.streamMessage,
    ];
    if (CometChatUIKit.authenticationSettings?.enableCalls == true) {
      if (!categories.contains(MessageCategoryConstants.call)) {
        categories.add(MessageCategoryConstants.call);
      }
    }
    return categories;
  }

  /// Appends the message caption beneath a single-attachment bubble, using the
  /// same renderer as the multi-attachment gallery, so a captioned
  /// one-attachment media message reads identically (the single image/video/
  /// file/audio bubbles don't render captions themselves).
  static Widget _withSingleCaption(
    Widget bubble,
    MediaMessage message,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    final caption = message.caption;
    if (caption == null || caption.trim().isEmpty) return bubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        CometChatMediaCaption(
          caption: caption,
          alignment: alignment,
          formatters: FormatterUtils.ensureMarkdownFormatter(
            additionalConfigurations?.textFormatters,
          ),
        ),
      ],
    );
  }

  static Widget getAudioMessageContentView(
    MediaMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    // Voice notes ALWAYS render via CometChatVoiceNoteBubble (below), on both
    // values of enableMultipleAttachments — a voice note is single by nature
    // and keeps the same look on both paths. Only non-voice audio *files* use
    // the multi-attachment bubble.
    if (!CometChatVoiceNoteBubble.isVoiceNote(message) &&
        (additionalConfigurations?.enableMultipleAttachments ?? true)) {
      return CometChatAudiosBubble(
        message: message,
        alignment: alignment,
        formatters: FormatterUtils.ensureMarkdownFormatter(
          additionalConfigurations?.textFormatters,
        ),
      );
    }
    // CometChatVoiceNoteBubble: voice notes (either flag), and audio files when
    // enableMultipleAttachments is false (reached as CometChatAudioBubble).
    return _withSingleCaption(
      MessageTemplateUtils.getAudioMessageBubble(
        message.attachment?.fileUrl,
        message.attachment?.fileName,
        additionalConfigurations?.effectiveVoiceNoteBubbleStyle,
        message,
        context,
        alignment,
      ),
      message,
      alignment,
      additionalConfigurations: additionalConfigurations,
    );
  }

  static Widget getFileMessageContentView(
    MediaMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    if (additionalConfigurations?.enableMultipleAttachments ?? true) {
      // Every attachment renders as a file card (legacy mixed-type messages
      // from older clients land here too).
      return CometChatFilesBubble(
        message: message,
        alignment: alignment,
        formatters: FormatterUtils.ensureMarkdownFormatter(
          additionalConfigurations?.textFormatters,
        ),
      );
    }
    // Deprecated single-attachment path (enableMultipleAttachments == false).
    return _withSingleCaption(
      MessageTemplateUtils.getFileMessageBubble(
        message.attachment?.fileUrl,
        message.attachment?.fileMimeType,
        message.attachment?.fileName,
        message.id,
        additionalConfigurations?.fileBubbleStyle,
        message,
        alignment,
      ),
      message,
      alignment,
      additionalConfigurations: additionalConfigurations,
    );
  }

  static Widget getImageMessageContentView(
    MediaMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    if (additionalConfigurations?.enableMultipleAttachments ?? true) {
      return CometChatImagesBubble(
        message: message,
        alignment: alignment,
        formatters: FormatterUtils.ensureMarkdownFormatter(
          additionalConfigurations?.textFormatters,
        ),
      );
    }
    // Deprecated single-attachment path (enableMultipleAttachments == false).
    final imageThumbnailUrl = ThumbnailExtractionUtil.extractFromMetadata(
      message.metadata,
      tag: 'template.image.msg${message.id}',
    );
    return _withSingleCaption(
      MessageTemplateUtils.getImageMessageBubble(
        message.attachment?.fileUrl,
        AssetConstants.imagePlaceholder,
        message.caption,
        additionalConfigurations?.imageBubbleStyle,
        message,
        null,
        context,
        thumbnailUrl: imageThumbnailUrl,
      ),
      message,
      alignment,
      additionalConfigurations: additionalConfigurations,
    );
  }

  static Widget getVideoMessageBubble(
    String? videoUrl,
    String? thumbnailUrl,
    MediaMessage message,
    Function()? onClick,
    BuildContext context,
    CometChatVideoBubbleStyle? style,
  ) {
    return CometChatVideoBubble(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      style: style as dynamic,
      metadata: message.metadata,
    );
  }

  static Widget getVideoMessageContentView(
    MediaMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    if (additionalConfigurations?.enableMultipleAttachments ?? true) {
      return CometChatVideosBubble(
        message: message,
        alignment: alignment,
        formatters: FormatterUtils.ensureMarkdownFormatter(
          additionalConfigurations?.textFormatters,
        ),
      );
    }
    // Deprecated single-attachment path (enableMultipleAttachments == false).
    final thumbnailUrl = ThumbnailExtractionUtil.extractFromMetadata(
      message.metadata,
      tag: 'template.video.msg${message.id}',
    );
    return _withSingleCaption(
      MessageTemplateUtils.getVideoMessageBubble(
        message.attachment?.fileUrl,
        thumbnailUrl,
        message,
        null,
        context,
        additionalConfigurations?.videoBubbleStyle,
      ),
      message,
      alignment,
      additionalConfigurations: additionalConfigurations,
    );
  }

  static Widget getTextMessageBubble(
    String messageText,
    TextMessage message,
    BuildContext context,
    BubbleAlignment alignment,
    CometChatTextBubbleStyle? style,
    List<CometChatTextFormatter>? formatters,
  ) {
    return CometChatTextBubble(
      text: messageText,
      alignment: alignment,
      formatters: formatters,
      style: style as dynamic,
    );
  }

  static Widget getAudioMessageBubble(
    String? audioUrl,
    String? title,
    CometChatVoiceNoteBubbleStyle? style,
    MediaMessage message,
    BuildContext context,
    BubbleAlignment alignment,
  ) {
    // Renders voice notes (on either flag) and, when enableMultipleAttachments
    // is false, audio files too. The multi-attachment path uses
    // CometChatAudiosBubble; the waveform player itself is CometChatAudioPlayer.
    return CometChatVoiceNoteBubble(
      style: style,
      audioUrl: audioUrl,
      title: title,
      key: ValueKey('${message.id}_${message.muid}'),
      alignment: alignment,
      id: message.id,
      muid: message.muid,
      metadata: message.metadata,
    );
  }

  static Widget getFileMessageBubble(
    String? fileUrl,
    String? fileMimeType,
    String? title,
    int? id,
    CometChatFileBubbleStyle? style,
    MediaMessage message,
    BubbleAlignment alignment,
  ) {
    return CometChatFileBubble(
      key: UniqueKey(),
      fileUrl: fileUrl,
      fileMimeType: fileMimeType,
      alignment: alignment,
      style: (style ?? const CometChatFileBubbleStyle()) as dynamic,
      title: title ?? "",
      id: id,
      fileSize: message.attachment?.fileSize,
      fileExtension: message.attachment?.fileExtension,
      dateTime: message.sentAt,
      metadata: message.metadata,
    );
  }

  static Widget getImageMessageBubble(
    String? imageUrl,
    String? placeholderImage,
    String? caption,
    CometChatImageBubbleStyle? style,
    MediaMessage message,
    Function()? onClick,
    BuildContext context, {
    String? thumbnailUrl,
  }) {
    return CometChatImageBubble(
      key: UniqueKey(),
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      placeholderImage: placeholderImage,
      style: (style ?? const CometChatImageBubbleStyle()) as dynamic,
      onClick: onClick,
      metadata: message.metadata,
    );
  }

  /// Returns the template for developer card messages (category: "card").
  ///
  /// This is the NEW first-party card bubble (§2.9.7-A).
  /// DO NOT confuse with [getCardMessageTemplate] below which is the
  /// legacy interactive/card NOT_SUPPORTED stub (category: "interactive").
  static CometChatMessageTemplate getCardBubbleTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.card,
      category: MessageCategoryConstants.card,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }

            final cardMessage = message as CardMessage;
            return CometChatCardBubble(message: cardMessage);
          },
      options: getCardBubbleOptions,
    );
  }

  /// Options for developer card messages: text options minus edit and copy.
  /// Preserves all conditional visibility logic (delete-only-for-own/admin, etc.)
  static List<CometChatMessageOption> getCardBubbleOptions(
    User loggedInUser,
    BaseMessage messageObject,
    BuildContext context,
    Group? group,
    AdditionalConfigurations? additionalConfigurations,
  ) {
    // Get the full text options, then remove edit and copy
    final textOptions = getTextMessageOptions(
      loggedInUser,
      messageObject,
      context,
      group,
      additionalConfigurations,
    );
    textOptions.removeWhere(
      (option) =>
          option.id == MessageOptionConstants.editMessage ||
          option.id == MessageOptionConstants.copyMessage,
    );
    return textOptions;
  }

  static CometChatMessageTemplate getCardMessageTemplate() {
    return CometChatMessageTemplate(
      // name: MessageTypeConstants.text,
      type: MessageTypeConstants.card,
      category: MessageCategoryConstants.interactive,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            //TODO: Implement CardMessage ContentView
            // CardMessage cardMessage = message as CardMessage;
            // return MessageUIService.getCardMessageContentView(
            //     cardMessage, context, alignment, theme);
            return getMessageNotSupportedWidget(message, context);
          },
      //TODO: Implement CardMessage Options
      // options: MessageUIService.getCardMessageOptions,
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => [],
    );
  }

  static List<CometChatTextFormatter> getDefaultTextFormatters() {
    return <CometChatTextFormatter>[
      CometChatMentionsFormatter() as CometChatTextFormatter,
      CometChatEmailFormatter() as CometChatTextFormatter,
      CometChatPhoneNumberFormatter() as CometChatTextFormatter,
      CometChatUrlFormatter() as CometChatTextFormatter,
    ];
  }

  static Widget getMessageNotSupportedWidget(
    BaseMessage message,
    BuildContext context,
  ) {
    CometChatSpacing spacing = CometChatThemeHelper.getSpacing(context);
    CometChatTypography typography = CometChatThemeHelper.getTypography(
      context,
    );
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        spacing.padding2 ?? 0,
        spacing.padding2 ?? 0,
        spacing.padding2 ?? 0,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(right: spacing.padding1 ?? 0),
            child: Icon(
              Icons.block,
              color: message.sender?.uid == CometChatUIKit.loggedInUser?.uid
                  ? colorPalette.white
                  : colorPalette.neutral600,
              size: 16,
            ),
          ),
          Text(
            Translations.of(context).unsupportedMessageType,
            style: TextStyle(
              color: message.sender?.uid == CometChatUIKit.loggedInUser?.uid
                  ? colorPalette.white
                  : colorPalette.neutral600,
              fontSize: typography.body?.regular?.fontSize,
              fontWeight: typography.body?.regular?.fontWeight,
              fontFamily: typography.body?.regular?.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // -------- Extension Message Templates --------

  static CometChatMessageTemplate getPollMessageTemplate() {
    return CometChatMessageTemplate(
      type: ExtensionType.extensionPoll,
      category: MessageCategoryConstants.custom,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            if (message is! CustomMessage) {
              return getMessageNotSupportedWidget(message, context);
            }
            final customMessage = message;
            final metadata = customMessage.customData;
            if (metadata == null) {
              return getMessageNotSupportedWidget(message, context);
            }

            final String pollQuestion = metadata['question']?.toString() ?? '';
            final String loggedInUserUid =
                CometChatUIKit.loggedInUser?.uid ?? '';

            // Extract poll results from message metadata injected extensions
            Map<String, dynamic>? pollResults;
            final msgMetadata = customMessage.metadata;
            if (msgMetadata != null) {
              final injected = msgMetadata['@injected'];
              if (injected is Map && injected.containsKey('extensions')) {
                final extensions = injected['extensions'];
                if (extensions is Map &&
                    extensions.containsKey(ExtensionConstants.polls)) {
                  final pollData = extensions[ExtensionConstants.polls];
                  if (pollData is Map) {
                    pollResults = Map<String, dynamic>.from(pollData);
                  }
                }
              }
            }

            // Build options from poll results (has vote counts) or fall back to customData
            List<PollOptions> options = [];

            // Poll ID from extension metadata, fallback to message ID
            final String pollId =
                (pollResults != null && pollResults['id'] != null)
                ? pollResults['id'].toString()
                : customMessage.id.toString();

            if (pollResults != null) {
              // Vote data lives under pollResults['results']['options']
              // per CometChat docs: @injected.extensions.polls.results.options
              final Map<String, dynamic>? resultsMap =
                  pollResults['results'] is Map
                  ? Map<String, dynamic>.from(pollResults['results'])
                  : null;

              if (resultsMap != null && resultsMap.containsKey('options')) {
                final Map<String, dynamic> opts = Map<String, dynamic>.from(
                  resultsMap['options'] ?? {},
                );
                for (var key in opts.keys) {
                  final opt = opts[key];
                  if (opt is Map) {
                    final Map<String, dynamic> votersMap =
                        Map<String, dynamic>.from(opt['voters'] ?? {});
                    final List<User> voters = votersMap.entries
                        .map(
                          (e) => User(
                            uid: e.key,
                            name:
                                (e.value is Map ? e.value['name'] : null) ??
                                e.key,
                            avatar: e.value is Map ? e.value['avatar'] : null,
                          ),
                        )
                        .toList();
                    options.add(
                      PollOptions(
                        id: key,
                        optionText: opt['text']?.toString() ?? '',
                        voteCount: opt['count'] ?? 0,
                        votersUid: votersMap.keys.toList(),
                        voters: voters,
                      ),
                    );
                  }
                }
              } else if (pollResults.containsKey('options')) {
                // Fallback: poll exists but no votes yet — build from top-level options
                final topOptions = pollResults['options'];
                if (topOptions is Map) {
                  for (var key in topOptions.keys) {
                    options.add(
                      PollOptions(
                        id: key.toString(),
                        optionText: topOptions[key]?.toString() ?? '',
                        voteCount: 0,
                        votersUid: [],
                        voters: [],
                      ),
                    );
                  }
                }
              }
            } else if (metadata.containsKey('options')) {
              // Fallback: build from customData options (no vote data)
              final rawOptions = metadata['options'];
              if (rawOptions is List) {
                for (int i = 0; i < rawOptions.length; i++) {
                  options.add(
                    PollOptions(
                      id: (i + 1).toString(),
                      optionText: rawOptions[i]?.toString() ?? '',
                      voteCount: 0,
                      votersUid: [],
                      voters: [],
                    ),
                  );
                }
              }
            }

            return CometChatPollsBubble(
              pollQuestion: pollQuestion,
              options: options,
              pollId: pollId,
              loggedInUser: loggedInUserUid,
              senderUid: customMessage.sender?.uid,
              metadata: pollResults,
              alignment: alignment,
              style: additionalConfigurations?.pollsBubbleStyle,
              choosePoll: (String vote, String id) async {
                try {
                  await CometChat.callExtension(
                    ExtensionConstants.polls,
                    'POST',
                    ExtensionUrls.votePoll,
                    {'vote': vote, 'id': id},
                    onSuccess: (Map<String, dynamic> map) {
                      ccLog('[Polls] Vote success: $map');
                    },
                    onError: (CometChatException e) {
                      ccLog('[Polls] Vote error: ${e.code} ${e.message}');
                    },
                  );
                } catch (e) {
                  ccLog('[Polls] Vote exception: $e');
                }
              },
            );
          },
      options: MessageTemplateUtils.getCommonOptions,
    );
  }

  static CometChatMessageTemplate getStickerMessageTemplate() {
    return CometChatMessageTemplate(
      type: ExtensionType.sticker,
      category: MessageCategoryConstants.custom,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            if (message is! CustomMessage) {
              return getMessageNotSupportedWidget(message, context);
            }
            return CometChatStickerBubble(
              message: message,
              style: additionalConfigurations?.stickerBubbleStyle,
            );
          },
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => MessageTemplateUtils.getCommonOptions(
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ),
    );
  }

  static CometChatMessageTemplate getCollaborativeDocumentTemplate() {
    return CometChatMessageTemplate(
      type: ExtensionType.document,
      category: MessageCategoryConstants.custom,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            if (message is! CustomMessage) {
              return getMessageNotSupportedWidget(message, context);
            }
            String? documentUrl;
            final metadata = message.metadata;
            if (metadata != null) {
              final injected = metadata['@injected'];
              if (injected is Map && injected.containsKey('extensions')) {
                final extensions = injected['extensions'];
                if (extensions is Map &&
                    extensions.containsKey(ExtensionConstants.document)) {
                  final docData = extensions[ExtensionConstants.document];
                  if (docData is Map) {
                    documentUrl = docData['document_url']?.toString();
                  }
                }
              }
            }
            documentUrl ??= message.customData?['document_url']?.toString();

            return CometChatCollaborativeBubble(
              url: documentUrl,
              title: Translations.of(context).collaborativeDocument,
              subtitle: Translations.of(context).openDocumentSubtitle,
              buttonText: Translations.of(context).openDocument,
              alignment: alignment,
              style: additionalConfigurations?.collaborativeDocumentBubbleStyle,
              icon: Image.asset(
                AssetConstants.collaborativeDocumentFilled,
                package: UIConstants.packageName,
                height: 24,
                width: 24,
              ),
              previewImage: AssetConstants.collaborativeDocumentPreview,
            );
          },
      options: MessageTemplateUtils.getCommonOptions,
    );
  }

  static CometChatMessageTemplate getCollaborativeWhiteboardTemplate() {
    return CometChatMessageTemplate(
      type: ExtensionType.whiteboard,
      category: MessageCategoryConstants.custom,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            if (message is! CustomMessage) {
              return getMessageNotSupportedWidget(message, context);
            }
            String? whiteboardUrl;
            final metadata = message.metadata;
            if (metadata != null) {
              final injected = metadata['@injected'];
              if (injected is Map && injected.containsKey('extensions')) {
                final extensions = injected['extensions'];
                if (extensions is Map &&
                    extensions.containsKey(ExtensionConstants.whiteboard)) {
                  final wbData = extensions[ExtensionConstants.whiteboard];
                  if (wbData is Map) {
                    whiteboardUrl = wbData['board_url']?.toString();
                  }
                }
              }
            }
            whiteboardUrl ??= message.customData?['board_url']?.toString();

            return CometChatCollaborativeBubble(
              url: whiteboardUrl,
              title: Translations.of(context).collaborativeWhiteboard,
              subtitle: Translations.of(context).openWhiteboardSubtitle,
              buttonText: Translations.of(context).openWhiteboard,
              alignment: alignment,
              style:
                  additionalConfigurations?.collaborativeWhiteboardBubbleStyle,
              icon: Image.asset(
                AssetConstants.collaborativeWhiteBoardFilled,
                package: UIConstants.packageName,
                height: 24,
                width: 24,
              ),
              previewImage: AssetConstants.collaborativeWhiteboardPreview,
            );
          },
      options: MessageTemplateUtils.getCommonOptions,
    );
  }

  // -------- Call Message Templates (used when enableCalls == true) --------

  /// Template for AI assistant messages (category: agentic, type: assistant).
  /// Renders using [CometChatAIAssistantBubble] with full markdown support.
  static CometChatMessageTemplate getAIAssistantMessageTemplate() {
    return CometChatMessageTemplate(
      type: CometChatMessageType.assistant,
      category: CometChatMessageCategory.categoryAgentic,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            if (message is AIAssistantMessage) {
              return CometChatAIAssistantBubble(
                message: message,
                alignment: alignment,
              );
            }
            // Fallback: render as text if somehow not AIAssistantMessage
            return Text(message.toString());
          },
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => [], // No long-press options for AI messages
    );
  }

  /// Template for stream messages (category: streamMessage, type: run_started).
  /// Renders using [CometChatStreamBubble] with shimmer streaming effect.
  static CometChatMessageTemplate getStreamMessageTemplate() {
    return CometChatMessageTemplate(
      type: CometChatMessageType.runStarted,
      category: CometChatMessageCategory.streamMessage,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message is StreamMessage) {
              return CometChatStreamBubble(message: message);
            }
            return const SizedBox.shrink();
          },
      options:
          (
            loggedInUser,
            messageObject,
            context,
            group,
            additionalConfigurations,
          ) => [], // No long-press options for stream messages
    );
  }

  static CometChatMessageTemplate _getGroupCallTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.meeting,
      category: MessageCategoryConstants.custom,
      options: MessageTemplateUtils.getCommonOptions,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message.deletedAt != null || message is! CustomMessage) {
              return getDeleteMessageBubble(
                message,
                context,
                additionalConfigurations?.deletedBubbleStyle,
              );
            }
            return _getCallBubble(
              message,
              context,
              alignment,
              additionalConfigurations: additionalConfigurations,
            );
          },
    );
  }

  static Widget _getCallBubble(
    CustomMessage message,
    BuildContext context,
    BubbleAlignment alignment, {
    AdditionalConfigurations? additionalConfigurations,
  }) {
    final loggedInUser = CometChatUIKit.loggedInUser;
    String? callType;
    if (message.customData != null &&
        message.customData?.containsKey('callType') == true) {
      callType = message.customData?['callType'];
    }
    String title;
    String icon;
    CometChatCallBubbleStyle? style;

    if (callType == CallTypeConstants.videoCall) {
      title = cc.Translations.of(context).videoCall;
      style = additionalConfigurations?.videoCallBubbleStyle;
      icon = message.sender?.uid == loggedInUser?.uid
          ? AssetConstants.videoOutgoing
          : AssetConstants.videoIncoming;
    } else {
      title = cc.Translations.of(context).voiceCall;
      style = additionalConfigurations?.voiceCallBubbleStyle;
      icon = message.sender?.uid == loggedInUser?.uid
          ? AssetConstants.voiceOutgoing
          : AssetConstants.voiceIncoming;
    }

    String receiver = message.receiverUid;
    String? subtitle;
    if (message.sentAt != null) {
      subtitle = DateFormat('d MMM, hh:mm a').format(message.sentAt!);
    }

    final callingConfig = CallingConfigurationResolver.resolved;

    return CometChatCallBubble(
      title: title,
      iconUrl: icon,
      subtitle: subtitle,
      onTap: (context) => _initiateDirectCall(
        context,
        receiver,
        message,
        callingConfig: callingConfig,
        call: Call(
          receiverUid: receiver,
          receiverType: CometChatReceiverType.group,
          category: MessageCategoryConstants.call,
          type: MessageTypeConstants.meeting,
        ),
      ),
      style: style,
      alignment: alignment,
    );
  }

  static void _initiateDirectCall(
    BuildContext context,
    String sessionID,
    CustomMessage message, {
    Call? call,
    CallingConfiguration? callingConfig,
  }) async {
    // A meeting message still on its way, or one that failed to send: Join
    // does nothing (round 5, D03 A). The host's own bubble shows while the
    // message is sending, before the call buttons open the meeting; a Join
    // there opened it first, and the buttons' screen then replaced it with
    // a second join. A failed message announced no meeting.
    if (message.id <= 0 || message.metadata?['error'] != null) {
      ccLog(
        'MessageTemplateUtils: the meeting message is not sent; Join '
        'ignored',
      );
      return;
    }
    // Joining a meeting from its bubble is the call buttons' job done from
    // the chat, so their onError hears when the join fails.
    final OnError? onError = callingConfig?.callButtonsConfiguration?.onError;
    String? callType;
    String? sessionId;
    if (message.customData != null &&
        message.customData?.containsKey('callType') == true) {
      callType = message.customData?['callType'];
    }
    if (message.customData != null &&
        message.customData?.containsKey('sessionID') == true) {
      sessionId = message.customData?['sessionID'];
    }
    final String meetingSessionId = sessionId ?? sessionID;
    // This meeting is on screen already (a second tap on Join): nothing to
    // do (round 5, D03 A).
    if (CallScreenOverlay.isShowing &&
        ActiveCallTracker.callScreenWorkFlow == CallWorkFlow.directCalling &&
        ActiveCallTracker.callScreenSessionId == meetingSessionId) {
      ccLog('MessageTemplateUtils: meeting $meetingSessionId is on screen');
      return;
    }
    // A call in progress, or another meeting on the call screen: one at a
    // time (round 5, P5-C07; the owner's D06 A). Joining used to replace
    // that call's screen without ending the call. No navigator to show the
    // meeting on is refused by show() itself (NO_NAVIGATOR).
    if (ActiveCallTracker.isInCallOrMeeting) {
      ccLog('MessageTemplateUtils: a call is on; meeting not joined');
      reportCallError(
        onError,
        activeCallException(),
        where: 'MessageTemplateUtils',
      );
      return;
    }
    // The settings the meeting's host joins with too (round 5, P5-C05):
    // the call buttons' callSettingsBuilder, then groupSessionSettingsBuilder,
    // then the tile layout. An audio meeting's flags used to be written into
    // the app's groupSessionSettingsBuilder itself, so every later Join,
    // video ones included, started with the camera paused.
    final SessionSettingsBuilder sessionSettingsBuilder;
    try {
      sessionSettingsBuilder = MeetingSessionSettings.resolve(
        isAudioOnly: callType == CallTypeConstants.audioCall,
        settingsFactory:
            callingConfig?.callButtonsConfiguration?.callSettingsBuilder,
        group: message.receiver is Group ? message.receiver as Group : null,
        configuration: callingConfig,
      );
    } catch (e) {
      // The app's callSettingsBuilder threw: the meeting is not joined.
      ccLog('MessageTemplateUtils: the meeting settings failed: $e');
      reportCallError(
        onError,
        callExceptionFrom(e),
        where: 'MessageTemplateUtils',
      );
      return;
    }
    CallScreenOverlay.show(
      sessionId: meetingSessionId,
      sessionSettingsBuilder: sessionSettingsBuilder,
      callWorkFlow: CallWorkFlow.directCalling,
      onError: onError,
    );
  }

  static CometChatMessageTemplate _getDefaultVoiceCallTemplate() {
    return CometChatMessageTemplate(
      type: CallTypeConstants.audioCall,
      category: MessageCategoryConstants.call,
      footerView: null,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message is Call) {
              final loggedInUser = CometChatUIKit.loggedInUser;
              final CometChatColorPalette colorPalette =
                  CometChatThemeHelper.getColorPalette(context);
              final typography = CometChatThemeHelper.getTypography(context);
              return CometChatActionBubble(
                text: CallUtils.getCallStatus(context, message, loggedInUser),
                leadingIcon: Image.asset(
                  CallUtils.getCallIconByStatus(
                    context,
                    message,
                    loggedInUser,
                    true,
                  ),
                  package: UIConstants.packageName,
                  color: CallUtils.getCallTextColor(
                    context,
                    message,
                    loggedInUser,
                    colorPalette,
                  ),
                  height: 20,
                  width: 20,
                ),
                style: CometChatActionBubbleStyle(
                  textStyle: TextStyle(
                    fontSize: typography.caption1?.regular?.fontSize,
                    fontWeight: typography.caption1?.regular?.fontWeight,
                    fontFamily: typography.caption1?.regular?.fontFamily,
                    color: CallUtils.getCallTextColor(
                      context,
                      message,
                      loggedInUser,
                      colorPalette,
                    ),
                    letterSpacing: 0,
                  ),
                ).merge(additionalConfigurations?.actionBubbleStyle),
              );
            } else {
              return null;
            }
          },
    );
  }

  static CometChatMessageTemplate _getDefaultVideoCallTemplate() {
    return CometChatMessageTemplate(
      type: CallTypeConstants.videoCall,
      category: MessageCategoryConstants.call,
      contentView:
          (
            BaseMessage message,
            BuildContext context,
            BubbleAlignment alignment, {
            AdditionalConfigurations? additionalConfigurations,
          }) {
            if (message is Call) {
              final loggedInUser = CometChatUIKit.loggedInUser;
              final CometChatColorPalette colorPalette =
                  CometChatThemeHelper.getColorPalette(context);
              final typography = CometChatThemeHelper.getTypography(context);

              return CometChatActionBubble(
                text: CallUtils.getCallStatus(context, message, loggedInUser),
                leadingIcon: Image.asset(
                  CallUtils.getCallIconByStatus(
                    context,
                    message,
                    loggedInUser,
                    false,
                  ),
                  package: UIConstants.packageName,
                  // The icon wears the text's colour, as in the voice
                  // template: red only for a missed call.
                  color: CallUtils.getCallTextColor(
                    context,
                    message,
                    loggedInUser,
                    colorPalette,
                  ),
                  height: 24,
                  width: 24,
                ),
                style: CometChatActionBubbleStyle(
                  textStyle: TextStyle(
                    fontSize: typography.caption1?.regular?.fontSize,
                    fontWeight: typography.caption1?.regular?.fontWeight,
                    color: CallUtils.getCallTextColor(
                      context,
                      message,
                      loggedInUser,
                      colorPalette,
                    ),
                  ),
                ).merge(additionalConfigurations?.actionBubbleStyle),
              );
            } else {
              return null;
            }
          },
    );
  }
}
