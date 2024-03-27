import 'package:flutter/material.dart';

///[ImageModerationFilterStyle] is a data class that has styling-related properties
///to customize the appearance of [ImageModerationFilter]
class ImageModerationFilterStyle {
  ImageModerationFilterStyle(
      {this.warningTextStyle,
      this.warningImageUrl,
      this.warningImagePackageName,
      this.warningImageColor,
      this.filterColor});

  ///[warningTextStyle] styling for text shown if image has sensitive/graphic content
  final TextStyle? warningTextStyle;

  ///[warningImageUrl] image shown on the filter if image has sensitive/graphic content
  final String? warningImageUrl;

  ///[warningImagePackageName] package of the image shown on the filter if image has sensitive/graphic content
  final String? warningImagePackageName;

  ///[warningImageColor] color of the image shown on the filter if image has sensitive/graphic content
  final Color? warningImageColor;

  ///[filterColor] background color of the image filter
  final Color? filterColor;
}
