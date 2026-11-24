import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

/// Styling for every attachment **error alert** the composer raises — one class
/// for both surfaces, since they are the same notice in two places:
///
/// * the composer toast, when a selection is over the attachment count or size
///   limit ("You can attach up to N files", "File exceeds N MB");
/// * the errored-tile alert, stating why a staged attachment was rejected.
///
/// Null fields fall back to sensible theme-derived defaults.
///
/// The alert is informational only — retry lives in the tile itself (a `failed`
/// tile is retried by tapping it), so there is no action label here.
class CometChatAttachmentErrorAlertStyle {
  const CometChatAttachmentErrorAlertStyle({
    this.backgroundColor,
    this.textStyle,
    this.icon,
    this.iconColor,
    this.behavior,
    this.shape,
    this.margin,
    this.duration,
  });

  /// Alert fill (default: the palette's neutral900).
  final Color? backgroundColor;

  /// Message text style.
  final TextStyle? textStyle;

  /// Leading icon (default: an error-outline glyph).
  final Widget? icon;

  /// Leading icon colour when the default glyph is used.
  final Color? iconColor;

  /// Default [SnackBarBehavior.floating].
  final SnackBarBehavior? behavior;

  /// Default a rounded rectangle.
  final ShapeBorder? shape;

  /// Outer margin (floating behavior only).
  final EdgeInsetsGeometry? margin;

  /// How long the alert stays up (default 2s for the toast, 3s for a tile).
  final Duration? duration;
}

/// Shows an attachment's error reason as a [SnackBar]. Not a persistent widget
/// — summoned on demand (tap) via [show], from the [ScaffoldMessenger] above
/// the composer.
///
/// Informational only: it states *why* an attachment failed (over the size /
/// type / count limit). Retry lives in the tile itself — a `failed` (network)
/// tile is retried by tapping it — so this alert carries no action.
///
/// Not shown where hover is available (desktop web): the tile's tooltip already
/// gives the reason there.
abstract final class CometChatAttachmentErrorSnackBar {
  static void show(
    BuildContext context, {
    required AttachmentTile tile,
    CometChatAttachmentErrorAlertStyle? style,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final colors = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final message = tile.notSaved
        ? Translations.of(context).fileNotSaved
        : tile.errorMessage ?? Translations.of(context).uploadFailed;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: style?.behavior ?? SnackBarBehavior.floating,
        backgroundColor: style?.backgroundColor ?? colors.neutral900,
        shape:
            style?.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: style?.margin,
        duration: style?.duration ?? const Duration(seconds: 3),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            style?.icon ??
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: style?.iconColor ?? colors.error,
                ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // neutral50 (not white): it inverts with the neutral900 fill —
                // white on near-black in light, near-black on white in dark.
                // Hardcoded white rendered white-on-white in dark theme.
                style: TextStyle(
                  color: colors.neutral50,
                  fontSize: typography.body?.regular?.fontSize ?? 13,
                  fontFamily: typography.body?.regular?.fontFamily,
                ).merge(style?.textStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
