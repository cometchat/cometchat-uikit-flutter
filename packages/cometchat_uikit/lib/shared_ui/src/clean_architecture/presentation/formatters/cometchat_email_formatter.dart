import 'package:flutter/material.dart';
import '../../../../cometchat_uikit_shared.dart';
import 'package:url_launcher/url_launcher.dart';

///[CometChatEmailFormatter] is a class which is used to style the email text
/// ```dart
/// CometChatEmailFormatter(
///    pattern: RegExp(RegexConstants.emailRegexPattern),
///    onSearch: (email) async {
///    await launchUrl(Uri.parse(('mailto:$email')));
///    },
///    messageBubbleTextStyle: (theme, alignment,{forConversation}) {
///    return TextStyle(
///    color: Colors.pink,
///    );
///    },
///    );
///    ```
class CometChatEmailFormatter extends CometChatTextFormatter {
  CometChatEmailFormatter({
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
  }) : super(pattern: pattern ?? RegExp(RegexConstants.emailRegexPattern));

  @override
  void init() {
    pattern ??= RegExp(RegexConstants.emailRegexPattern);
  }

  @override
  void handlePreMessageSend(BuildContext context, BaseMessage baseMessage) {}

  @override
  TextStyle getMessageInputTextStyle(BuildContext context) {
    // The email formatter styles matched text in the rendered message, not the
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
              await launchUrl(Uri.parse(('mailto:$text')));
            }
          },
      forConversation: forConversation,
    );
  }
}
