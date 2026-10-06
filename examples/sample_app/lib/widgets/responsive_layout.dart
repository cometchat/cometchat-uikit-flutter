import 'package:flutter/material.dart';

/// Breakpoints for responsive layout.
///
/// On web/desktop (width >= [kDesktopBreakpoint]), the app shows a split-pane
/// layout: left panel (list) + right panel (detail).
/// On mobile (width < [kDesktopBreakpoint]), the app uses full-screen push
/// navigation as before.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Width at which we switch from mobile (full-screen) to desktop (split-pane).
  static const double kDesktopBreakpoint = 700;

  /// Starting width of the left panel in desktop mode. Draggable at runtime
  /// (see [PanelResizeHandle]), so this is the default, not a fixed size.
  static const double kLeftPanelWidth = 380;

  /// Starting width of the right panel (threads / pinned / search / info).
  /// Matches the left panel so the chat opens centred between two equal
  /// columns; both are draggable from there.
  static const double kRightPanelWidth = kLeftPanelWidth;

  /// Drag limits for the side panels.
  ///
  /// The minimums keep a conversation row and a panel title legible; the
  /// maximums stop either side from squeezing the message list, which has no
  /// width of its own — it takes what the panels leave.
  static const double kLeftPanelMinWidth = 260;
  static const double kLeftPanelMaxWidth = 560;
  static const double kRightPanelMinWidth = 260;
  static const double kRightPanelMaxWidth = 560;

  /// Width the message list must keep no matter where the handles are.
  static const double kMiddlePanelMinWidth = 360;
}

/// A 1px divider that can be dragged to resize the panel beside it.
///
/// The visible rule stays hairline-thin; the drag target is widened to 8px
/// and the cursor switches to a column resize, so the handle is grabbable
/// without drawing a chunky separator.
class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({
    super.key,
    required this.onDelta,
    this.color,
  });

  /// Called with the horizontal drag delta in logical pixels. Positive means
  /// the pointer moved right; the caller decides which side that grows.
  final void Function(double delta) onDelta;

  final Color? color;

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        onHorizontalDragUpdate: (details) => widget.onDelta(details.delta.dx),
        child: SizedBox(
          width: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 2 : 1,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : (widget.color ?? Colors.grey.shade300),
            ),
          ),
        ),
      ),
    );
  }
}

/// Returns true if the current screen width qualifies as desktop/web layout.
bool isDesktopLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >=
      ResponsiveBreakpoints.kDesktopBreakpoint;
}
