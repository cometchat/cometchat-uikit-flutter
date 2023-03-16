import 'package:flutter/material.dart';

class TabItem {
  final String id;

  final String? title;

  final Widget icon;

  final Widget childView;

  TabItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.childView,
  });
}
