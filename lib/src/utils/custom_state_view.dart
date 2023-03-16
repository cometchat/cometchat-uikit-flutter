import 'package:flutter/material.dart';

class CustomStateView {
  ///custom views for list
  const CustomStateView({this.loading, this.error, this.empty});

  ///[loading] custom loading widget
  final WidgetBuilder? loading;

  ///[error] custom error widget
  final WidgetBuilder? error;

  ///[empty] custom empty widget
  final WidgetBuilder? empty;
}