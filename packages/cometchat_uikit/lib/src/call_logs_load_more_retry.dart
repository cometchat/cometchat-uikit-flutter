import 'package:flutter/material.dart';

import '../call_ui/src/call_logs/cometchat_call_logs/call_logs_style.dart';
import '../cometchat_chat_uikit.dart';

/// The last row of a call-log list whose next page failed to load
/// (`CallLogsState.loadMoreError`): the rows already listed stay, this says
/// the next ones could not be loaded, and Retry asks for the same page again.
/// `CometChatCallLogs` and `CallLogsList` show it in place of the loading row,
/// which asked for the page again on every build.
///
/// Its colours follow the call logs' error state: the error view's subtitle
/// colour for the text and its retry button's for the button.
///
/// Package-private (see `lib/src/`).
class CallLogsLoadMoreRetryRow extends StatelessWidget {
  /// A retry row calling [onRetry] when tapped.
  const CallLogsLoadMoreRetryRow({
    super.key,
    required this.onRetry,
    this.style,
    this.colorPalette,
    this.typography,
    this.spacing,
  });

  /// Asks for the page that failed again.
  final VoidCallback onRetry;

  /// The call logs' style; its error-state colours are used.
  final CometChatCallLogsStyle? style;

  /// The palette, else the theme's.
  final CometChatColorPalette? colorPalette;

  /// The typography, else the theme's.
  final CometChatTypography? typography;

  /// The spacing, else the theme's.
  final CometChatSpacing? spacing;

  @override
  Widget build(BuildContext context) {
    final palette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final type = typography ?? CometChatThemeHelper.getTypography(context);
    final space = spacing ?? CometChatThemeHelper.getSpacing(context);
    final translations = Translations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: space.padding4 ?? 16,
        vertical: space.padding2 ?? 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              translations.somethingWentWrongTryAgain,
              style: TextStyle(
                color:
                    style?.errorStateSubTitleTextColor ?? palette.textSecondary,
                fontSize: type.caption1?.regular?.fontSize,
                fontWeight: type.caption1?.regular?.fontWeight,
                fontFamily: type.caption1?.regular?.fontFamily,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              translations.retry,
              style: TextStyle(
                color: style?.retryButtonTextColor ?? palette.primary,
                fontSize: type.button?.medium?.fontSize,
                fontWeight: type.button?.medium?.fontWeight,
                fontFamily: type.button?.medium?.fontFamily,
              ).merge(style?.retryButtonTextStyle),
            ),
          ),
        ],
      ),
    );
  }
}
