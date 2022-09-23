import 'package:flutter/material.dart';

class ListStyle {
  /// style for ConversationList,UserList,GroupList
  const ListStyle(
      {this.background,
      this.border,
      this.cornerRadius,
      this.loadingIconTint,
      this.empty,
      this.error,
      this.gradient});

  ///[background] background color of list
  final Color? background;

  ///[border] border for list
  final BoxBorder? border;

  ///[cornerRadius] radius of container
  final double? cornerRadius;

  ///[loadingIconTint]
  final Color? loadingIconTint;

  ///[empty] custom widget to show empty list
  final TextStyle? empty;

  ///[error] widget to show error
  final TextStyle? error;

  final Gradient? gradient;
}

class CustomView {
  ///custom views for list
  const CustomView({this.loading, this.error, this.empty});

  ///[loading] custom loading widget
  final Widget? loading;

  ///[error] custom error widget
  final Widget? error;

  ///[empty] custom empty widget
  final Widget? empty;
}
