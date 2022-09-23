import 'dart:async';

import 'package:flutter/material.dart';

class Debouncer {
  final int milliseconds;

  Timer? _timer;

  Debouncer({this.milliseconds = 500});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
