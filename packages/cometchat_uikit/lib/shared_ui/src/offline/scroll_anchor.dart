import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Holds the first visible row of a scrolled-away list where it is on screen
/// while rows are inserted or removed around it (PR #23 §3.3: "scroll anchored
/// to the first visible row"). Internal to the kit.
///
/// [hold] records the topmost visible row and its distance from the top of
/// the viewport. After every frame until [settle] has passed since the last
/// [hold], the scroll offset is corrected by however far that row moved, so
/// rows growing in below it (a reversed list) or above it do not push it. The
/// hold ends early when the list scrolls by any other hand (a drag, a fling,
/// an animated scroll, a jump), when the row leaves the list, or on
/// [release].
class ScrollAnchorKeeper {
  /// Creates a keeper for the list driven by [controller]; [rows] gives the
  /// keys of the rows that can serve as the anchor.
  ScrollAnchorKeeper({
    required this.controller,
    required this.rows,
    this.settle = const Duration(milliseconds: 800),
  });

  /// The list's scroll controller.
  final ScrollController controller;

  /// The keys of the rows that can anchor (each on a widget inside the list).
  final Iterable<GlobalKey> Function() rows;

  /// How long a hold lasts after the last [hold] (the row animations).
  final Duration settle;

  GlobalKey? _anchor;
  double _dy = 0;
  double _pixels = 0;
  Timer? _timer;
  bool _scheduled = false;

  /// Whether a row is held.
  bool get holding => _anchor != null;

  /// Holds the topmost visible row in place until [settle] has passed. A row
  /// already held stays the anchor; the hold is extended.
  void hold() {
    if (!controller.hasClients) return;
    final position = controller.position;
    // Someone is scrolling: their scroll wins.
    if (position.isScrollingNotifier.value) return release();
    _timer?.cancel();
    _timer = Timer(settle, release);
    if (_anchor != null) return;
    final found = _topmostVisible();
    if (found == null) return release();
    _anchor = found.$1;
    _dy = found.$2;
    _pixels = position.pixels;
    _schedule();
  }

  /// Ends the hold.
  void release() {
    _timer?.cancel();
    _timer = null;
    _anchor = null;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _correct();
    });
  }

  void _correct() {
    final key = _anchor;
    if (key == null || !controller.hasClients) return;
    final position = controller.position;
    // Someone else scrolled (a drag, a fling, a jump to the bottom): theirs.
    if (position.isScrollingNotifier.value ||
        (position.pixels - _pixels).abs() > 0.5) {
      return release();
    }
    final dy = _dyOf(key);
    if (dy == null) return release();
    final delta = dy - _dy;
    if (delta.abs() > 0.5) {
      // A reversed list (axis up) scrolls the content down as pixels grow.
      final up = position.axisDirection == AxisDirection.up;
      final target = position.pixels + (up ? -delta : delta);
      position.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      _pixels = position.pixels;
    }
    _schedule();
  }

  (GlobalKey, double)? _topmostVisible() {
    (GlobalKey, double)? best;
    for (final key in rows()) {
      final box = _boxOf(key);
      if (box == null) continue;
      final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox) continue;
      final dy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final visible = dy + box.size.height > 0 && dy < viewport.size.height;
      if (visible && (best == null || dy < best.$2)) best = (key, dy);
    }
    return best;
  }

  double? _dyOf(GlobalKey key) {
    final box = _boxOf(key);
    if (box == null) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  RenderBox? _boxOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box;
  }
}
