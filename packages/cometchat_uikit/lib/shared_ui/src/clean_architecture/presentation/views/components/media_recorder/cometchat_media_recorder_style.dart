import "../../../../clean_architecture.dart";
import 'package:flutter/material.dart';

///[CometChatMediaRecorderStyle] is a model class for customizing the styles of [CometChatMediaRecorder] widget.
///
/// ```dart
/// MediaRecorderStyle(
///backgroundColor: Colors.white,
///border: Border.all(color: Colors.red),
///borderRadius: BorderRadius.circular(10),
///textStyle: TextStyle(color: Colors.black),
///textColor: Colors.black,
///  );
///  ```
///
class CometChatMediaRecorderStyle
    extends ThemeExtension<CometChatMediaRecorderStyle> {
  /// Color of the pulsing rings around the record indicator while
  /// recording. Without it they are drawn from
  /// [recordIndicatorBackgroundColor].
  final Color? recordIndicatorColor;

  CometChatMediaRecorderStyle({
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.textStyle,
    this.textColor,
    this.deleteButtonIconColor,
    this.deleteButtonBackgroundColor,
    this.deleteButtonBorderRadius,
    this.deleteButtonBorder,
    this.startButtonIconColor,
    this.startButtonBackgroundColor,
    this.startButtonBorderRadius,
    this.startButtonBorder,
    this.pauseButtonIconColor,
    this.pauseButtonBackgroundColor,
    this.pauseButtonBorderRadius,
    this.pauseButtonBorder,
    this.stopButtonIconColor,
    this.stopButtonBackgroundColor,
    this.stopButtonBorderRadius,
    this.stopButtonBorder,
    this.sendButtonIconColor,
    this.sendButtonBackgroundColor,
    this.sendButtonBorderRadius,
    this.sendButtonBorder,
    this.playButtonIconColor,
    this.recordIndicatorIconColor,
    this.recordIndicatorBackgroundColor,
    this.recordIndicatorBorderRadius,
    this.recordIndicatorBorder,
    this.audioBubbleStyle,
    this.recordIndicatorColor,
  });

  ///[backgroundColor] defines the background color of the media recorder widget.
  final Color? backgroundColor;

  ///[border] defines the border of the media recorder widget.
  final BoxBorder? border;

  ///[borderRadius] defines the border radius of the media recorder widget.
  final BorderRadiusGeometry? borderRadius;

  ///[textStyle] defines the style of the text displayed on the media recorder widget.
  final TextStyle? textStyle;

  ///[textColor] defines the color of the text displayed on the media recorder widget.
  final Color? textColor;

  ///[deleteButtonIconColor] defines the color of the delete button icon.
  final Color? deleteButtonIconColor;

  ///[deleteButtonBackgroundColor] defines the background color of the delete button.
  final Color? deleteButtonBackgroundColor;

  ///[deleteButtonBorderRadius] defines the border radius of the delete button.
  final BorderRadiusGeometry? deleteButtonBorderRadius;

  ///[deleteButtonBorder] defines the border of the delete button.
  final BoxBorder? deleteButtonBorder;

  ///[startButtonIconColor] defines the color of the start button icon.
  final Color? startButtonIconColor;

  ///[startButtonBackgroundColor] defines the background color of the start button.
  final Color? startButtonBackgroundColor;

  ///[startButtonBorderRadius] defines the border radius of the start button.
  final BorderRadiusGeometry? startButtonBorderRadius;

  ///[startButtonBorder] defines the border of the start button.
  final BoxBorder? startButtonBorder;

  ///[pauseButtonIconColor] defines the color of the pause button icon.
  final Color? pauseButtonIconColor;

  ///[pauseButtonBackgroundColor] defines the background color of the pause button.
  final Color? pauseButtonBackgroundColor;

  ///[pauseButtonBorderRadius] defines the border radius of the pause button.
  final BorderRadiusGeometry? pauseButtonBorderRadius;

  ///[pauseButtonBorder] defines the border of the pause button.
  final BoxBorder? pauseButtonBorder;

  ///[stopButtonIconColor] defines the color of the stop button icon.
  final Color? stopButtonIconColor;

  ///[stopButtonBackgroundColor] defines the background color of the stop button.
  final Color? stopButtonBackgroundColor;

  ///[stopButtonBorderRadius] defines the border radius of the stop button.
  final BorderRadiusGeometry? stopButtonBorderRadius;

  ///[stopButtonBorder] defines the border of the stop button.
  final BoxBorder? stopButtonBorder;

  ///[sendButtonIconColor] defines the color of the send button icon.
  final Color? sendButtonIconColor;

  ///[sendButtonBackgroundColor] defines the background color of the send button.
  final Color? sendButtonBackgroundColor;

  ///[sendButtonBorderRadius] defines the border radius of the send button.
  final BorderRadiusGeometry? sendButtonBorderRadius;

  ///[sendButtonBorder] defines the border of the send button.
  final BoxBorder? sendButtonBorder;

  ///[playButtonIconColor] defines the color of the play button icon.
  final Color? playButtonIconColor;

  ///[recordIndicatorIconColor] defines the color of the record button icon.
  final Color? recordIndicatorIconColor;

  ///[recordIndicatorBackgroundColor] defines the background color of the record button.
  final Color? recordIndicatorBackgroundColor;

  ///[recordIndicatorBorderRadius] defines the border radius of the record button.
  final BorderRadiusGeometry? recordIndicatorBorderRadius;

  ///[recordIndicatorBorder] defines the border of the record button.
  final BoxBorder? recordIndicatorBorder;

  ///[audioBubbleStyle] defines the style of the audio bubble.
  final CometChatVoiceNoteBubbleStyle? audioBubbleStyle;

  @override
  CometChatMediaRecorderStyle copyWith({
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? recordingButtonIconColor,
    TextStyle? textStyle,
    Color? textColor,
    Color? deleteButtonIconColor,
    Color? deleteButtonBackgroundColor,
    BorderRadiusGeometry? deleteButtonBorderRadius,
    BoxBorder? deleteButtonBorder,
    Color? startButtonIconColor,
    Color? startButtonBackgroundColor,
    BorderRadiusGeometry? startButtonBorderRadius,
    BoxBorder? startButtonBorder,
    Color? pauseButtonIconColor,
    Color? pauseButtonBackgroundColor,
    BorderRadiusGeometry? pauseButtonBorderRadius,
    BoxBorder? pauseButtonBorder,
    Color? stopButtonIconColor,
    Color? stopButtonBackgroundColor,
    BorderRadiusGeometry? stopButtonBorderRadius,
    BoxBorder? stopButtonBorder,
    Color? sendButtonIconColor,
    Color? sendButtonBackgroundColor,
    BorderRadiusGeometry? sendButtonBorderRadius,
    TextStyle? sendButtonTextStyle,
    Color? sendButtonTextColor,
    BoxBorder? sendButtonBorder,
    Color? playButtonIconColor,
    Color? recordIndicatorIconColor,
    Color? recordIndicatorBackgroundColor,
    BorderRadiusGeometry? recordIndicatorBorderRadius,
    BoxBorder? recordIndicatorBorder,
    CometChatVoiceNoteBubbleStyle? audioBubbleStyle,
    Color? recordIndicatorColor,
  }) {
    return CometChatMediaRecorderStyle(
      backgroundColor: backgroundColor,
      border: border,
      borderRadius: borderRadius,
      textStyle: textStyle,
      textColor: textColor,
      deleteButtonIconColor: deleteButtonIconColor,
      deleteButtonBackgroundColor: deleteButtonBackgroundColor,
      deleteButtonBorderRadius: deleteButtonBorderRadius,
      deleteButtonBorder: deleteButtonBorder,
      startButtonIconColor: startButtonIconColor,
      startButtonBackgroundColor: startButtonBackgroundColor,
      startButtonBorderRadius: startButtonBorderRadius,
      startButtonBorder: startButtonBorder,
      pauseButtonIconColor: pauseButtonIconColor,
      pauseButtonBackgroundColor: pauseButtonBackgroundColor,
      pauseButtonBorderRadius: pauseButtonBorderRadius,
      pauseButtonBorder: pauseButtonBorder,
      stopButtonIconColor: stopButtonIconColor,
      stopButtonBackgroundColor: stopButtonBackgroundColor,
      stopButtonBorderRadius: stopButtonBorderRadius,
      stopButtonBorder: stopButtonBorder,
      sendButtonIconColor: sendButtonIconColor,
      sendButtonBackgroundColor: sendButtonBackgroundColor,
      sendButtonBorderRadius: sendButtonBorderRadius,
      sendButtonBorder: sendButtonBorder,
      playButtonIconColor: playButtonIconColor,
      recordIndicatorIconColor: recordIndicatorIconColor,
      recordIndicatorBackgroundColor: recordIndicatorBackgroundColor,
      recordIndicatorBorderRadius: recordIndicatorBorderRadius,
      recordIndicatorBorder: recordIndicatorBorder,
      audioBubbleStyle: audioBubbleStyle,
      recordIndicatorColor: recordIndicatorColor,
    );
  }

  @override
  CometChatMediaRecorderStyle lerp(
    covariant ThemeExtension<CometChatMediaRecorderStyle>? other,
    double t,
  ) {
    if (other is! CometChatMediaRecorderStyle) {
      return this;
    }
    return copyWith(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      border: BoxBorder.lerp(border, other.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      textColor: Color.lerp(textColor, other.textColor, t),
      deleteButtonIconColor: Color.lerp(
        deleteButtonIconColor,
        other.deleteButtonIconColor,
        t,
      ),
      deleteButtonBackgroundColor: Color.lerp(
        deleteButtonBackgroundColor,
        other.deleteButtonBackgroundColor,
        t,
      ),
      deleteButtonBorderRadius: BorderRadiusGeometry.lerp(
        deleteButtonBorderRadius,
        other.deleteButtonBorderRadius,
        t,
      ),
      deleteButtonBorder: BoxBorder.lerp(
        deleteButtonBorder,
        other.deleteButtonBorder,
        t,
      ),
      pauseButtonBackgroundColor: Color.lerp(
        pauseButtonBackgroundColor,
        other.pauseButtonBackgroundColor,
        t,
      ),
      pauseButtonBorderRadius: BorderRadiusGeometry.lerp(
        pauseButtonBorderRadius,
        other.pauseButtonBorderRadius,
        t,
      ),
      pauseButtonBorder: BoxBorder.lerp(
        pauseButtonBorder,
        other.pauseButtonBorder,
        t,
      ),
      pauseButtonIconColor: Color.lerp(
        pauseButtonIconColor,
        other.pauseButtonIconColor,
        t,
      ),
      playButtonIconColor: Color.lerp(
        playButtonIconColor,
        other.playButtonIconColor,
        t,
      ),
      recordIndicatorBackgroundColor: Color.lerp(
        recordIndicatorBackgroundColor,
        other.recordIndicatorBackgroundColor,
        t,
      ),
      recordIndicatorBorderRadius: BorderRadiusGeometry.lerp(
        recordIndicatorBorderRadius,
        other.recordIndicatorBorderRadius,
        t,
      ),
      recordIndicatorBorder: BoxBorder.lerp(
        recordIndicatorBorder,
        other.recordIndicatorBorder,
        t,
      ),
      recordIndicatorIconColor: Color.lerp(
        recordIndicatorIconColor,
        other.recordIndicatorIconColor,
        t,
      ),
      sendButtonBackgroundColor: Color.lerp(
        sendButtonBackgroundColor,
        other.sendButtonBackgroundColor,
        t,
      ),
      sendButtonBorderRadius: BorderRadiusGeometry.lerp(
        sendButtonBorderRadius,
        other.sendButtonBorderRadius,
        t,
      ),
      sendButtonBorder: BoxBorder.lerp(
        sendButtonBorder,
        other.sendButtonBorder,
        t,
      ),
      sendButtonIconColor: Color.lerp(
        sendButtonIconColor,
        other.sendButtonIconColor,
        t,
      ),

      startButtonBackgroundColor: Color.lerp(
        startButtonBackgroundColor,
        other.startButtonBackgroundColor,
        t,
      ),
      startButtonBorderRadius: BorderRadiusGeometry.lerp(
        startButtonBorderRadius,
        other.startButtonBorderRadius,
        t,
      ),
      startButtonBorder: BoxBorder.lerp(
        startButtonBorder,
        other.startButtonBorder,
        t,
      ),
      startButtonIconColor: Color.lerp(
        startButtonIconColor,
        other.startButtonIconColor,
        t,
      ),
      stopButtonBackgroundColor: Color.lerp(
        stopButtonBackgroundColor,
        other.stopButtonBackgroundColor,
        t,
      ),
      stopButtonBorderRadius: BorderRadiusGeometry.lerp(
        stopButtonBorderRadius,
        other.stopButtonBorderRadius,
        t,
      ),
      stopButtonBorder: BoxBorder.lerp(
        stopButtonBorder,
        other.stopButtonBorder,
        t,
      ),
      stopButtonIconColor: Color.lerp(
        stopButtonIconColor,
        other.stopButtonIconColor,
        t,
      ),
      audioBubbleStyle: audioBubbleStyle?.lerp(other.audioBubbleStyle, t),
      recordIndicatorColor: Color.lerp(
        recordIndicatorColor,
        other.recordIndicatorColor,
        t,
      ),
    );
  }

  static CometChatMediaRecorderStyle of(BuildContext context) {
    return CometChatMediaRecorderStyle();
  }

  CometChatMediaRecorderStyle merge(CometChatMediaRecorderStyle? style) {
    if (style == null) return this;
    return copyWith(
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      textStyle: style.textStyle,
      textColor: style.textColor,
      pauseButtonBackgroundColor: style.pauseButtonBackgroundColor,
      pauseButtonBorderRadius: style.pauseButtonBorderRadius,
      pauseButtonBorder: style.pauseButtonBorder,
      pauseButtonIconColor: style.pauseButtonIconColor,
      playButtonIconColor: style.playButtonIconColor,
      recordIndicatorBackgroundColor: style.recordIndicatorBackgroundColor,
      recordIndicatorBorderRadius: style.recordIndicatorBorderRadius,
      recordIndicatorBorder: style.recordIndicatorBorder,
      recordIndicatorIconColor: style.recordIndicatorIconColor,
      recordIndicatorColor: style.recordIndicatorColor,
      sendButtonBackgroundColor: style.sendButtonBackgroundColor,
      sendButtonBorderRadius: style.sendButtonBorderRadius,
      sendButtonBorder: style.sendButtonBorder,
      sendButtonIconColor: style.sendButtonIconColor,
      startButtonBackgroundColor: style.startButtonBackgroundColor,
      startButtonBorderRadius: style.startButtonBorderRadius,
      startButtonBorder: style.startButtonBorder,
      startButtonIconColor: style.startButtonIconColor,
      deleteButtonBackgroundColor: style.deleteButtonBackgroundColor,
      deleteButtonBorderRadius: style.deleteButtonBorderRadius,
      deleteButtonBorder: style.deleteButtonBorder,
      deleteButtonIconColor: style.deleteButtonIconColor,
      stopButtonBackgroundColor: style.stopButtonBackgroundColor,
      stopButtonBorderRadius: style.stopButtonBorderRadius,
      stopButtonBorder: style.stopButtonBorder,
      stopButtonIconColor: style.stopButtonIconColor,
      audioBubbleStyle: style.audioBubbleStyle,
    );
  }
}
