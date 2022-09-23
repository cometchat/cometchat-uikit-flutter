import 'package:flutter/material.dart';

import '../../flutter_chat_ui_kit.dart';

class Options {
  final String id;
  final String title;
  final IconData? icon;
  final Function(BaseMessage message)? onClick;

  Options(this.id, this.title, this.icon, this.onClick);
}
