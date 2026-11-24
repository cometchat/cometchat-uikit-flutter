import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart' show CometChatThemeHelper;
import 'contract_ids.dart';

/// The offline state a list shows when the device is offline and nothing is
/// on screen (D84 (3), (7)). Internal: not exported.
///
/// It is a state, not an error: an icon and "Connect to load …" (or "Connect
/// to search"), with no Retry; the list reloads once by itself on reconnect.
abstract final class OfflineListStates {
  /// The kit's offline state with [text], in the list's empty-state colours.
  ///
  /// When the app passed its own error view, [appErrorView] (that view, as
  /// the list renders it) shows instead (D84 (3)). [subtitle], when given,
  /// shows under [text] ("Connect to search" carries one, D84).
  static Widget view(
    BuildContext context,
    String text, {
    String? subtitle,
    Widget? appErrorView,
    Color? textColor,
    TextStyle? textStyle,
  }) {
    if (appErrorView != null) {
      return contractNode(identifier: ContractIds.empty, child: appErrorView);
    }
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    return contractNode(
      identifier: ContractIds.empty,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.padding5 ?? 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: colorPalette.iconSecondary,
              ),
              SizedBox(height: spacing.padding3 ?? 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor ?? colorPalette.textPrimary,
                  fontSize: typography.heading4?.medium?.fontSize,
                  fontWeight: typography.heading4?.medium?.fontWeight,
                  fontFamily: typography.heading4?.medium?.fontFamily,
                ).merge(textStyle).copyWith(color: textColor),
              ),
              if (subtitle != null) ...[
                SizedBox(height: spacing.padding1 ?? 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorPalette.textSecondary,
                    fontSize: typography.body?.regular?.fontSize,
                    fontWeight: typography.body?.regular?.fontWeight,
                    fontFamily: typography.body?.regular?.fontFamily,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
