import 'package:flutter/material.dart';

class ActionItem {
  final String id;
  final String title;
  final String? iconUrl;
  final String? iconUrlPackageName;
  final Color? iconTint;
  final TextStyle? titleStyle;
  final Color? iconBackground;
  final double? iconCornerRadius;
  final Color? background;
  final double? cornerRadius;
  //final Function()? actionCallBack; //Change to onItemClick

  final dynamic onItemClick;

  const ActionItem(
      {required this.id,
      required this.title,
      this.iconUrl,
      this.iconUrlPackageName,
      this.iconTint,
      this.iconBackground,
      this.iconCornerRadius,
      this.background,
      this.cornerRadius,
      // this.actionCallBack,
      this.titleStyle,
      this.onItemClick});

  @override
  String toString() {
    return 'ActionItem{id: $id, title: $title, titleStyle: $titleStyle,iconUrl: $iconUrl, iconTint: $iconTint, iconBackground: $iconBackground, iconCornerRadius: $iconCornerRadius, background: $background, cornerRadius: $cornerRadius, }';
  }
}
