import 'package:flutter/material.dart';

class BaseStyles {
  const BaseStyles(
      {this.width,
      this.height,
      this.background,
      this.gradient,
      this.border,
      this.borderRadius});

  ///[width] provides width to the widget
  final double? width;

  ///[height] provides height to the widget
  final double? height;

  ///[background] provides background color to the widget
  final Color? background;

  ///[gradient] provides (background) gradient to the widget
  final Gradient? gradient;

  ///[border] provides border around the widget
  final BoxBorder? border;

  ///[borderRadius] provides radius to the border around the widget
  final double? borderRadius;

}
