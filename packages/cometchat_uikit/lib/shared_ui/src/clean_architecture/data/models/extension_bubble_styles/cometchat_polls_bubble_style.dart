import 'package:flutter/material.dart';
import '../../../../../cometchat_uikit_shared.dart'
    show CometChatAvatarStyle, CometChatDateStyle, CometChatMessageReceiptStyle;

///[CometChatPollsBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatPollsBubble]
class CometChatPollsBubbleStyle
    extends ThemeExtension<CometChatPollsBubbleStyle> {
  ///poll bubble style
  const CometChatPollsBubbleStyle({
    this.questionTextStyle,
    this.voteCountTextStyle,
    this.pollOptionsTextStyle,
    this.radioButtonColor,
    this.pollOptionsBackgroundColor,
    this.selectedOptionColor,
    this.unSelectedOptionColor,
    this.backgroundColor,
    this.iconColor,
    this.border,
    this.borderRadius,
    this.progressColor,
    this.progressBackgroundColor,
    this.voterAvatarStyle,
    this.messageBubbleAvatarStyle,
    this.messageBubbleDateStyle,
    this.messageBubbleBackgroundImage,
    this.threadedMessageIndicatorTextStyle,
    this.threadedMessageIndicatorIconColor,
    this.senderNameTextStyle,
    this.messageReceiptStyle,
  });

  ///[questionTextStyle] question text style
  final TextStyle? questionTextStyle;

  ///[voteCountTextStyle] vote count text style
  final TextStyle? voteCountTextStyle;

  ///[pollOptionsTextStyle] poll options text style
  final TextStyle? pollOptionsTextStyle;

  ///[radioButtonColor] radio  button color
  final Color? radioButtonColor;

  ///[pollOptionsBackgroundColor] poll option bar background color
  final Color? pollOptionsBackgroundColor;

  ///[selectedOptionColor] selected option poll bar color
  final Color? selectedOptionColor;

  ///[unSelectedOptionColor] unselected option poll bar color
  final Color? unSelectedOptionColor;

  ///[backgroundColor] used to customise the background color of the polls bubble
  final Color? backgroundColor;

  ///[iconColor] is the color of the icon
  final Color? iconColor;

  ///[border] provides border to the message bubble of a received message
  final BoxBorder? border;

  ///[borderRadius] provides border radius to the message bubble of a received message
  final BorderRadiusGeometry? borderRadius;

  ///[progressColor] provides color to the progress bar
  final Color? progressColor;

  ///[progressBackgroundColor] provides color to the progress bar background
  final Color? progressBackgroundColor;

  ///[voterAvatarStyle] provides style to the voter's avatar
  final CometChatAvatarStyle? voterAvatarStyle;

  ///[messageBubbleAvatarStyle] provides style to the avatar of the sender
  final CometChatAvatarStyle? messageBubbleAvatarStyle;

  ///[messageBubbleDateStyle] provides style to the date of the message bubble
  final CometChatDateStyle? messageBubbleDateStyle;

  ///[messageBubbleBackgroundImage] provides background image to the message bubble of the sent message
  final DecorationImage? messageBubbleBackgroundImage;

  ///[threadedMessageIndicatorTextStyle] provides text style to the threaded message indicator
  final TextStyle? threadedMessageIndicatorTextStyle;

  ///[threadedMessageIndicatorIconColor] provides color to the threaded message icon
  final Color? threadedMessageIndicatorIconColor;

  ///[senderNameTextStyle] provides style to the sender name of the message
  final TextStyle? senderNameTextStyle;

  ///[messageReceiptStyle] provides style to the message receipt
  final CometChatMessageReceiptStyle? messageReceiptStyle;

  @override
  CometChatPollsBubbleStyle copyWith({
    TextStyle? questionTextStyle,
    TextStyle? voteCountTextStyle,
    TextStyle? pollOptionsTextStyle,
    Color? radioButtonColor,
    Color? pollOptionsBackgroundColor,
    Color? selectedOptionColor,
    Color? unSelectedOptionColor,
    Color? backgroundColor,
    Color? iconColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? progressColor,
    Color? progressBackgroundColor,
    CometChatAvatarStyle? voterAvatarStyle,
    CometChatAvatarStyle? messageBubbleAvatarStyle,
    CometChatDateStyle? messageBubbleDateStyle,
    DecorationImage? messageBubbleBackgroundImage,
    TextStyle? threadedMessageIndicatorTextStyle,
    Color? threadedMessageIndicatorIconColor,
    TextStyle? senderNameTextStyle,
    CometChatMessageReceiptStyle? messageReceiptStyle,
  }) {
    return CometChatPollsBubbleStyle(
      questionTextStyle: questionTextStyle ?? this.questionTextStyle,
      voteCountTextStyle: voteCountTextStyle ?? this.voteCountTextStyle,
      pollOptionsTextStyle: pollOptionsTextStyle ?? this.pollOptionsTextStyle,
      radioButtonColor: radioButtonColor ?? this.radioButtonColor,
      pollOptionsBackgroundColor:
          pollOptionsBackgroundColor ?? this.pollOptionsBackgroundColor,
      selectedOptionColor: selectedOptionColor ?? this.selectedOptionColor,
      unSelectedOptionColor:
          unSelectedOptionColor ?? this.unSelectedOptionColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      iconColor: iconColor ?? this.iconColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      progressColor: progressColor ?? this.progressColor,
      progressBackgroundColor:
          progressBackgroundColor ?? this.progressBackgroundColor,
      voterAvatarStyle: voterAvatarStyle ?? this.voterAvatarStyle,
      messageBubbleAvatarStyle:
          messageBubbleAvatarStyle ?? this.messageBubbleAvatarStyle,
      messageBubbleDateStyle:
          messageBubbleDateStyle ?? this.messageBubbleDateStyle,
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? this.messageBubbleBackgroundImage,
      threadedMessageIndicatorTextStyle:
          threadedMessageIndicatorTextStyle ??
          this.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          threadedMessageIndicatorIconColor ??
          this.threadedMessageIndicatorIconColor,
      senderNameTextStyle: senderNameTextStyle ?? this.senderNameTextStyle,
      messageReceiptStyle: messageReceiptStyle ?? this.messageReceiptStyle,
    );
  }

  @override
  CometChatPollsBubbleStyle lerp(
    covariant ThemeExtension<CometChatPollsBubbleStyle>? other,
    double t,
  ) {
    if (other is! CometChatPollsBubbleStyle) {
      return this;
    }
    return CometChatPollsBubbleStyle(
      questionTextStyle: TextStyle.lerp(
        questionTextStyle,
        other.questionTextStyle,
        t,
      )!,
      voteCountTextStyle: TextStyle.lerp(
        voteCountTextStyle,
        other.voteCountTextStyle,
        t,
      )!,
      pollOptionsTextStyle: TextStyle.lerp(
        pollOptionsTextStyle,
        other.pollOptionsTextStyle,
        t,
      )!,
      radioButtonColor: Color.lerp(
        radioButtonColor,
        other.radioButtonColor,
        t,
      )!,
      pollOptionsBackgroundColor: Color.lerp(
        pollOptionsBackgroundColor,
        other.pollOptionsBackgroundColor,
        t,
      )!,
      selectedOptionColor: Color.lerp(
        selectedOptionColor,
        other.selectedOptionColor,
        t,
      )!,
      unSelectedOptionColor: Color.lerp(
        unSelectedOptionColor,
        other.unSelectedOptionColor,
        t,
      )!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      border: BoxBorder.lerp(border, other.border, t)!,
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      )!,
      progressColor: Color.lerp(progressColor, other.progressColor, t)!,
      progressBackgroundColor: Color.lerp(
        progressBackgroundColor,
        other.progressBackgroundColor,
        t,
      )!,
      voterAvatarStyle: voterAvatarStyle?.lerp(other.voterAvatarStyle, t),
      messageBubbleAvatarStyle: messageBubbleAvatarStyle?.lerp(
        other.messageBubbleAvatarStyle,
        t,
      ),
      messageBubbleDateStyle: messageBubbleDateStyle?.lerp(
        other.messageBubbleDateStyle,
        t,
      ),
      messageBubbleBackgroundImage: DecorationImage.lerp(
        messageBubbleBackgroundImage,
        other.messageBubbleBackgroundImage,
        t,
      ),
      threadedMessageIndicatorTextStyle: TextStyle.lerp(
        threadedMessageIndicatorTextStyle,
        other.threadedMessageIndicatorTextStyle,
        t,
      ),
      threadedMessageIndicatorIconColor: Color.lerp(
        threadedMessageIndicatorIconColor,
        other.threadedMessageIndicatorIconColor,
        t,
      ),
      senderNameTextStyle: TextStyle.lerp(
        senderNameTextStyle,
        other.senderNameTextStyle,
        t,
      ),
      messageReceiptStyle: messageReceiptStyle?.lerp(
        other.messageReceiptStyle,
        t,
      ),
    );
  }

  static CometChatPollsBubbleStyle of(BuildContext context) =>
      const CometChatPollsBubbleStyle();

  /// Returns a copy of this style with every non-null property of [other]
  /// applied on top, which is what every other style class in the kit means by
  /// `merge` — the caller's style overrides the theme default, not the other
  /// way round. `copyWith` already falls back to this instance for anything
  /// [other] leaves null.
  CometChatPollsBubbleStyle merge(CometChatPollsBubbleStyle? other) {
    if (other == null) return this;
    return copyWith(
      questionTextStyle: other.questionTextStyle,
      voteCountTextStyle: other.voteCountTextStyle,
      pollOptionsTextStyle: other.pollOptionsTextStyle,
      radioButtonColor: other.radioButtonColor,
      pollOptionsBackgroundColor: other.pollOptionsBackgroundColor,
      selectedOptionColor: other.selectedOptionColor,
      unSelectedOptionColor: other.unSelectedOptionColor,
      backgroundColor: other.backgroundColor,
      iconColor: other.iconColor,
      border: other.border,
      borderRadius: other.borderRadius,
      progressColor: other.progressColor,
      progressBackgroundColor: other.progressBackgroundColor,
      voterAvatarStyle: other.voterAvatarStyle,
      messageBubbleAvatarStyle: other.messageBubbleAvatarStyle,
      messageBubbleDateStyle: other.messageBubbleDateStyle,
      messageBubbleBackgroundImage: other.messageBubbleBackgroundImage,
      threadedMessageIndicatorTextStyle:
          other.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          other.threadedMessageIndicatorIconColor,
      senderNameTextStyle: other.senderNameTextStyle,
      messageReceiptStyle: other.messageReceiptStyle,
    );
  }
}
