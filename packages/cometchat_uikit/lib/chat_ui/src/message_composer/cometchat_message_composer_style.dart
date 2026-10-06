import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatMessageComposerStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatMessageComposer]
class CometChatMessageComposerStyle
    extends ThemeExtension<CometChatMessageComposerStyle> {
  const CometChatMessageComposerStyle({
    this.closeIconTint,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.dividerColor,
    this.dividerHeight,
    this.sendButtonIconColor,
    this.sendButtonIconBackgroundColor,
    this.sendButtonBorderRadius,
    this.secondaryButtonIconColor,
    this.secondaryButtonIconBackgroundColor,
    this.secondaryButtonBorderRadius,
    this.auxiliaryButtonIconColor,
    this.auxiliaryButtonIconBackgroundColor,
    this.auxiliaryButtonBorderRadius,
    this.stickerIconColor,
    this.stickerActiveIconColor,
    this.textStyle,
    this.textColor,
    this.placeHolderTextStyle,
    this.placeHolderTextColor,
    this.attachmentOptionSheetStyle,
    this.mentionsStyle,
    this.suggestionListStyle,
    this.mediaRecorderStyle,
    this.filledColor,
    this.richTextToolbarStyle,
    this.inlineAudioRecorderStyle,
    this.attachmentTrayStyle,
    this.stickerKeyboardStyle,
  });

  ///[closeIconTint] provides color to the close Icon/widget
  final Color? closeIconTint;

  ///[backgroundColor] sets the background color of the message composer
  final Color? backgroundColor;

  ///[border] sets the border of the message composer
  final BoxBorder? border;

  ///[dividerColor] sets the color of the divider
  final Color? dividerColor;

  ///[dividerHeight] sets the height of the divider
  final double? dividerHeight;

  ///[sendButtonIconColor] sets the color of the send button icon
  final Color? sendButtonIconColor;
  //
  ///[sendButtonIconBackgroundColor] sets the background color of the send button icon
  final Color? sendButtonIconBackgroundColor;
  //
  ///[sendButtonBorderRadius] sets the border radius of the send button
  final BorderRadiusGeometry? sendButtonBorderRadius;

  ///[secondaryButtonIconColor] sets the color of the secondary button icon
  final Color? secondaryButtonIconColor;

  ///[secondaryButtonIconBackgroundColor] sets the background color of the secondary button icon
  final Color? secondaryButtonIconBackgroundColor;

  ///[secondaryButtonBorderRadius] sets the border radius of the secondary button
  final BorderRadiusGeometry? secondaryButtonBorderRadius;

  ///[auxiliaryButtonIconColor] sets the color of the auxiliary button icon
  final Color? auxiliaryButtonIconColor;

  ///[auxiliaryButtonIconBackgroundColor] sets the background color of the auxiliary button icon
  final Color? auxiliaryButtonIconBackgroundColor;

  ///[auxiliaryButtonBorderRadius] sets the border radius of the auxiliary button
  final BorderRadiusGeometry? auxiliaryButtonBorderRadius;

  ///[stickerIconColor] tints the default sticker button icon while the
  ///sticker keyboard is closed. Falls back to [auxiliaryButtonIconColor],
  ///then to the palette's `iconSecondary`. A custom
  ///[CometChatMessageComposer.stickerIcon] is shown untinted.
  final Color? stickerIconColor;

  ///[stickerActiveIconColor] tints the default sticker button icon while the
  ///sticker keyboard is open. Falls back to the palette's `primary`. A custom
  ///[CometChatMessageComposer.stickerActiveIcon] is shown untinted.
  final Color? stickerActiveIconColor;

  ///[textStyle] sets the style of the text
  final TextStyle? textStyle;

  ///[textColor] sets the color of the text
  final Color? textColor;

  ///[placeHolderTextStyle] sets the style of the placeholder text
  final TextStyle? placeHolderTextStyle;

  ///[placeHolderTextColor] sets the color of the placeholder text
  final Color? placeHolderTextColor;

  ///[borderRadius] sets the border radius of the message composer
  final BorderRadiusGeometry? borderRadius;

  ///[attachmentOptionSheetStyle] provides style to the option sheet that generates a collaborative document
  final CometChatAttachmentOptionSheetStyle? attachmentOptionSheetStyle;

  ///[mentionsStyle] provides style to the mentions
  final CometChatMentionsStyle? mentionsStyle;

  ///[suggestionListStyle] provides style to the mentions
  final CometChatSuggestionListStyle? suggestionListStyle;

  ///[mediaRecorderStyle] provides style to the media recorder
  final CometChatMediaRecorderStyle? mediaRecorderStyle;

  ///[filledColor] sets the background color of the text input
  final Color? filledColor;

  ///[richTextToolbarStyle] provides style to the rich text formatting toolbar
  final CometChatRichTextToolbarStyle? richTextToolbarStyle;

  ///[inlineAudioRecorderStyle] provides style to the inline audio recorder
  final CometChatInlineAudioRecorderStyle? inlineAudioRecorderStyle;

  ///[attachmentTrayStyle] styles the multi-attachment staging tray tiles
  final CometChatAttachmentTrayStyle? attachmentTrayStyle;

  ///[stickerKeyboardStyle] styles the sticker keyboard the composer opens.
  ///Its non-null fields win over a [CometChatStickerKeyboardStyle] registered
  ///on the theme.
  final CometChatStickerKeyboardStyle? stickerKeyboardStyle;

  @override
  CometChatMessageComposerStyle copyWith({
    Color? closeIconTint,
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? dividerColor,
    double? dividerHeight,
    Color? sendButtonIconColor,
    Color? sendButtonIconBackgroundColor,
    BorderRadiusGeometry? sendButtonBorderRadius,
    Color? secondaryButtonIconColor,
    Color? secondaryButtonIconBackgroundColor,
    BorderRadiusGeometry? secondaryButtonBorderRadius,
    Color? auxiliaryButtonIconColor,
    Color? auxiliaryButtonIconBackgroundColor,
    BorderRadiusGeometry? auxiliaryButtonBorderRadius,
    Color? stickerIconColor,
    Color? stickerActiveIconColor,
    TextStyle? textStyle,
    Color? textColor,
    TextStyle? placeHolderTextStyle,
    Color? placeHolderTextColor,
    CometChatAttachmentOptionSheetStyle? attachmentOptionSheetStyle,
    CometChatMentionsStyle? mentionsStyle,
    CometChatSuggestionListStyle? suggestionListStyle,
    CometChatMediaRecorderStyle? mediaRecorderStyle,
    Color? filledColor,
    CometChatRichTextToolbarStyle? richTextToolbarStyle,
    CometChatInlineAudioRecorderStyle? inlineAudioRecorderStyle,
    CometChatAttachmentTrayStyle? attachmentTrayStyle,
    CometChatStickerKeyboardStyle? stickerKeyboardStyle,
  }) {
    return CometChatMessageComposerStyle(
      closeIconTint: closeIconTint ?? this.closeIconTint,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerHeight: dividerHeight ?? this.dividerHeight,
      sendButtonIconColor: sendButtonIconColor ?? this.sendButtonIconColor,
      sendButtonIconBackgroundColor:
          sendButtonIconBackgroundColor ?? this.sendButtonIconBackgroundColor,
      sendButtonBorderRadius:
          sendButtonBorderRadius ?? this.sendButtonBorderRadius,
      secondaryButtonIconColor:
          secondaryButtonIconColor ?? this.secondaryButtonIconColor,
      secondaryButtonIconBackgroundColor:
          secondaryButtonIconBackgroundColor ??
          this.secondaryButtonIconBackgroundColor,
      secondaryButtonBorderRadius:
          secondaryButtonBorderRadius ?? this.secondaryButtonBorderRadius,
      auxiliaryButtonIconColor:
          auxiliaryButtonIconColor ?? this.auxiliaryButtonIconColor,
      auxiliaryButtonIconBackgroundColor:
          auxiliaryButtonIconBackgroundColor ??
          this.auxiliaryButtonIconBackgroundColor,
      auxiliaryButtonBorderRadius:
          auxiliaryButtonBorderRadius ?? this.auxiliaryButtonBorderRadius,
      stickerIconColor: stickerIconColor ?? this.stickerIconColor,
      stickerActiveIconColor:
          stickerActiveIconColor ?? this.stickerActiveIconColor,
      textStyle: textStyle ?? this.textStyle,
      textColor: textColor ?? this.textColor,
      placeHolderTextStyle: placeHolderTextStyle ?? this.placeHolderTextStyle,
      placeHolderTextColor: placeHolderTextColor ?? this.placeHolderTextColor,
      attachmentOptionSheetStyle:
          attachmentOptionSheetStyle ?? this.attachmentOptionSheetStyle,
      mentionsStyle: mentionsStyle ?? this.mentionsStyle,
      suggestionListStyle: suggestionListStyle ?? this.suggestionListStyle,
      mediaRecorderStyle: mediaRecorderStyle ?? this.mediaRecorderStyle,
      filledColor: filledColor ?? this.filledColor,
      richTextToolbarStyle: richTextToolbarStyle ?? this.richTextToolbarStyle,
      inlineAudioRecorderStyle:
          inlineAudioRecorderStyle ?? this.inlineAudioRecorderStyle,
      attachmentTrayStyle: attachmentTrayStyle ?? this.attachmentTrayStyle,
      stickerKeyboardStyle: stickerKeyboardStyle ?? this.stickerKeyboardStyle,
    );
  }

  static CometChatMessageComposerStyle of(BuildContext context) =>
      const CometChatMessageComposerStyle();

  CometChatMessageComposerStyle merge(CometChatMessageComposerStyle? style) {
    if (style == null) return this;
    return copyWith(
      closeIconTint: style.closeIconTint,
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      dividerColor: style.dividerColor,
      dividerHeight: style.dividerHeight,
      sendButtonIconColor: style.sendButtonIconColor,
      sendButtonIconBackgroundColor: style.sendButtonIconBackgroundColor,
      sendButtonBorderRadius: style.sendButtonBorderRadius,
      secondaryButtonIconColor: style.secondaryButtonIconColor,
      secondaryButtonIconBackgroundColor:
          style.secondaryButtonIconBackgroundColor,
      secondaryButtonBorderRadius: style.secondaryButtonBorderRadius,
      auxiliaryButtonIconColor: style.auxiliaryButtonIconColor,
      auxiliaryButtonIconBackgroundColor:
          style.auxiliaryButtonIconBackgroundColor,
      auxiliaryButtonBorderRadius: style.auxiliaryButtonBorderRadius,
      stickerIconColor: style.stickerIconColor,
      stickerActiveIconColor: style.stickerActiveIconColor,
      textStyle: style.textStyle,
      textColor: style.textColor,
      placeHolderTextStyle: style.placeHolderTextStyle,
      placeHolderTextColor: style.placeHolderTextColor,
      attachmentOptionSheetStyle: style.attachmentOptionSheetStyle,
      mentionsStyle: style.mentionsStyle,
      suggestionListStyle: style.suggestionListStyle,
      mediaRecorderStyle: style.mediaRecorderStyle,
      filledColor: style.filledColor,
      richTextToolbarStyle: style.richTextToolbarStyle,
      inlineAudioRecorderStyle: style.inlineAudioRecorderStyle,
      attachmentTrayStyle: style.attachmentTrayStyle,
      stickerKeyboardStyle: style.stickerKeyboardStyle,
    );
  }

  @override
  CometChatMessageComposerStyle lerp(
    CometChatMessageComposerStyle? other,
    double t,
  ) {
    return CometChatMessageComposerStyle(
      closeIconTint: Color.lerp(closeIconTint, other?.closeIconTint, t),
      backgroundColor: Color.lerp(backgroundColor, other?.backgroundColor, t),
      border: BoxBorder.lerp(border, other?.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other?.borderRadius,
        t,
      ),
      dividerColor: Color.lerp(dividerColor, other?.dividerColor, t),
      dividerHeight: lerpDouble(dividerHeight, other?.dividerHeight, t),
      sendButtonIconColor: Color.lerp(
        sendButtonIconColor,
        other?.sendButtonIconColor,
        t,
      ),
      sendButtonIconBackgroundColor: Color.lerp(
        sendButtonIconBackgroundColor,
        other?.sendButtonIconBackgroundColor,
        t,
      ),
      sendButtonBorderRadius: BorderRadiusGeometry.lerp(
        sendButtonBorderRadius,
        other?.sendButtonBorderRadius,
        t,
      ),
      secondaryButtonIconColor: Color.lerp(
        secondaryButtonIconColor,
        other?.secondaryButtonIconColor,
        t,
      ),
      secondaryButtonIconBackgroundColor: Color.lerp(
        secondaryButtonIconBackgroundColor,
        other?.secondaryButtonIconBackgroundColor,
        t,
      ),
      secondaryButtonBorderRadius: BorderRadiusGeometry.lerp(
        secondaryButtonBorderRadius,
        other?.secondaryButtonBorderRadius,
        t,
      ),
      auxiliaryButtonIconColor: Color.lerp(
        auxiliaryButtonIconColor,
        other?.auxiliaryButtonIconColor,
        t,
      ),
      auxiliaryButtonIconBackgroundColor: Color.lerp(
        auxiliaryButtonIconBackgroundColor,
        other?.auxiliaryButtonIconBackgroundColor,
        t,
      ),
      auxiliaryButtonBorderRadius: BorderRadiusGeometry.lerp(
        auxiliaryButtonBorderRadius,
        other?.auxiliaryButtonBorderRadius,
        t,
      ),
      stickerIconColor: Color.lerp(
        stickerIconColor,
        other?.stickerIconColor,
        t,
      ),
      stickerActiveIconColor: Color.lerp(
        stickerActiveIconColor,
        other?.stickerActiveIconColor,
        t,
      ),
      textStyle: TextStyle.lerp(textStyle, other?.textStyle, t),
      textColor: Color.lerp(textColor, other?.textColor, t),
      placeHolderTextStyle: TextStyle.lerp(
        placeHolderTextStyle,
        other?.placeHolderTextStyle,
        t,
      ),
      placeHolderTextColor: Color.lerp(
        placeHolderTextColor,
        other?.placeHolderTextColor,
        t,
      ),
      attachmentOptionSheetStyle: attachmentOptionSheetStyle?.lerp(
        other?.attachmentOptionSheetStyle,
        t,
      ),
      mentionsStyle: mentionsStyle?.lerp(other?.mentionsStyle, t),
      suggestionListStyle: suggestionListStyle?.lerp(
        other?.suggestionListStyle,
        t,
      ),
      mediaRecorderStyle: mediaRecorderStyle?.lerp(
        other?.mediaRecorderStyle,
        t,
      ),
      filledColor: Color.lerp(filledColor, other?.filledColor, t),
      richTextToolbarStyle: richTextToolbarStyle?.lerp(
        other?.richTextToolbarStyle,
        t,
      ),
      inlineAudioRecorderStyle: inlineAudioRecorderStyle,
      attachmentTrayStyle: attachmentTrayStyle?.lerp(
        other?.attachmentTrayStyle,
        t,
      ),
      stickerKeyboardStyle: stickerKeyboardStyle?.lerp(
        other?.stickerKeyboardStyle,
        t,
      ),
    );
  }
}
