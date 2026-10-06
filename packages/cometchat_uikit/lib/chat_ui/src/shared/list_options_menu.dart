// The long-press options menu GroupsList and UsersList open on a row.
//
// Internal: no barrel exports this file, so it is not public API. Keep it that
// way — both lists import it directly.

import 'package:flutter/material.dart';

import '../../../shared_ui/cometchat_uikit_shared.dart';

/// Opens [options] as a menu anchored on the row [rowContext] belongs to, and
/// runs the chosen option's `onClick` once, after the menu has closed. Opens
/// nothing when [options] is empty.
///
/// [rowContext] must be the long-pressed row's own context, not the list's:
/// the menu is positioned over that row's box.
void showListOptionsMenu({
  required BuildContext rowContext,
  required List<CometChatOption> options,
  required CometChatColorPalette colorPalette,
  required CometChatSpacing spacing,
}) {
  if (options.isEmpty) return;

  var position = RelativeRect.fill;
  final row = rowContext.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(rowContext).overlay?.context.findRenderObject()
          as RenderBox?;
  if (row != null && overlay != null) {
    position = RelativeRect.fromRect(
      Rect.fromPoints(
        row.localToGlobal(Offset.zero, ancestor: overlay),
        row.localToGlobal(row.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }

  showMenu<CometChatOption>(
    context: rowContext,
    position: position,
    menuPadding: EdgeInsets.zero,
    color: colorPalette.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
      side: BorderSide(
        color: colorPalette.borderLight ?? Colors.transparent,
        width: 1,
      ),
    ),
    shadowColor: colorPalette.transparent,
    elevation: 8,
    items: [
      for (final option in options)
        CustomPopupMenuItem<CometChatOption>(
          value: option,
          child: GetMenuView(
            option: option,
            iconTint: option.iconTint ?? colorPalette.iconSecondary,
          ),
        ),
    ],
  ).then((selected) => selected?.onClick?.call());
}
