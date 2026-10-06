import 'package:flutter/material.dart';
import '../../../logging/cometchat_log.dart';

class WidgetPositionUtil {
  static RelativeRect? getWidgetPosition(
    BuildContext context,
    GlobalKey widgetKey,
  ) {
    // Check if widget is mounted
    if (widgetKey.currentContext == null ||
        !widgetKey.currentContext!.mounted) {
      ccLog("Widget is not mounted, skipping position calculation.");
      return null;
    }

    try {
      final RenderBox? renderBox =
          widgetKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null) {
        final Offset offset = renderBox.localToGlobal(Offset.zero);

        // Optional: Adjustments for alignment
        double horizontalOffset = MediaQuery.sizeOf(context).width * 0.65;
        const double verticalOffset = 30.0;

        return RelativeRect.fromLTRB(
          offset.dx + horizontalOffset,
          offset.dy + verticalOffset,
          offset.dx + renderBox.size.width + horizontalOffset,
          offset.dy + renderBox.size.height + verticalOffset,
        );
      } else {
        ccLog("RenderBox is null, position calculation failed.");
      }
    } catch (e, stackTrace) {
      ccLog("Exception while calculating position: $e");
      ccLog("Stack trace: $stackTrace");
    }

    return null;
  }
}
