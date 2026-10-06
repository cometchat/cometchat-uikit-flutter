import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import 'package:flutter/material.dart';
import 'cometchat_text_formatter.dart';
import 'attributed_text.dart';
import '../theme/theme.dart';
import '../../core/constants/regex_constants.dart';
import '../../../../cometchat_uikit_shared.dart' show BubbleAlignment;
import 'package:url_launcher/url_launcher.dart';

///[CometChatPhoneNumberFormatter] is a class which is used to style the phone number text
/// ```dart
/// CometChatPhoneNumberFormatter(
///     pattern: RegExp(RegexConstants.phoneNumberRegexPattern),
///     onSearch: (phoneNumber) async {
///     await launchUrl(Uri.parse(('tel:$phoneNumber')));
///     },
///     messageBubbleTextStyle: (theme, alignment,{forConversation}) {
///     return TextStyle(
///     color: Colors.pink,
///     );
///     },
///     );
///     ```
class CometChatPhoneNumberFormatter extends CometChatTextFormatter {
  CometChatPhoneNumberFormatter({
    super.trackingCharacter,
    RegExp? pattern,
    super.showLoadingIndicator,
    super.onSearch,
    super.messageBubbleTextStyle,
    super.messageInputTextStyle,
    super.message,
    super.composerId,
    super.suggestionListEventSink,
    super.previousTextEventSink,
    super.user,
    super.group,
  }) : super(
         pattern: pattern ?? RegExp(RegexConstants.phoneNumberRegexPattern),
       );
  @override
  void init() {
    pattern ??= RegExp(RegexConstants.phoneNumberRegexPattern);
  }

  @override
  void handlePreMessageSend(BuildContext context, BaseMessage baseMessage) {
    // Nothing to do before send: this formatter only decorates text for display.
  }

  @override
  TextStyle getMessageInputTextStyle(BuildContext context) {
    // The phone-number formatter styles matched text in the rendered message, not the
    // composer input, so it contributes no input style of its own. Returning
    // the default matches CometChatMarkdownTextFormatter; the previous
    // UnimplementedError would crash any caller of this public API.
    return const TextStyle();
  }

  @override
  void onScrollToBottom(TextEditingController textEditingController) {
    // Not used: this formatter holds no scroll-dependent state.
  }

  @override
  TextStyle getMessageBubbleTextStyle(
    BuildContext context,
    BubbleAlignment? alignment, {
    bool forConversation = false,
  }) {
    if (messageBubbleTextStyle != null) {
      return messageBubbleTextStyle!(
        context,
        alignment,
        forConversation: forConversation,
      );
    } else {
      CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
        context,
      );
      CometChatTypography typography = CometChatThemeHelper.getTypography(
        context,
      );
      return TextStyle(
        color: alignment == BubbleAlignment.right
            ? colorPalette.white
            : colorPalette.neutral900,
        fontWeight: typography.body?.regular?.fontWeight,
        fontSize: typography.body?.regular?.fontSize,
        fontFamily: typography.body?.regular?.fontFamily,
        decoration: TextDecoration.underline,
      );
    }
  }

  @override
  void onChange(
    TextEditingController textEditingController,
    String previousText,
  ) {
    // Not used: matching is done on render, not on each keystroke.
  }

  @override
  List<AttributedText> getAttributedText(
    String text,
    BuildContext context,
    BubbleAlignment? alignment, {
    List<AttributedText>? existingAttributes,
    Function(String)? onTap,
    bool forConversation = false,
  }) {
    return super.getAttributedText(
      text,
      context,
      alignment,
      existingAttributes: existingAttributes,
      onTap:
          onTap ??
          (text) async {
            if (pattern != null && pattern!.hasMatch(text)) {
              await launchUrl(Uri.parse(('tel:$text')));
            }
          },
      forConversation: forConversation,
    );
  }
}
