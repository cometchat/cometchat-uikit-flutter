import 'package:flutter/material.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../cometchat_call_logs/call_logs_style.dart';

/// A widget that displays the error state for the call logs list.
///
/// This widget renders the error state UI when call log loading fails.
/// It uses the default error state view from UIStateUtils with a retry button.
///
/// The widget supports custom error views through the [customView] parameter.
/// When provided, the custom view will be rendered instead of the default UI.
class CallLogsErrorView extends StatelessWidget {
  const CallLogsErrorView({
    super.key,
    this.customView,
    this.errorMessage,
    required this.onRetry,
    this.style,
    this.colorPalette,
    this.spacing,
    this.typography,
  });

  /// Optional custom view builder to override the default error view.
  /// When provided, this view will be rendered instead of the default error state UI.
  final WidgetBuilder? customView;

  /// The error message to display (used for debugging/logging purposes).
  final String? errorMessage;

  /// Callback invoked when the retry button is pressed.
  final VoidCallback onRetry;

  /// The style configuration for the call logs widget.
  /// Used to apply custom text styles and colors for the error state.
  /// If not provided, will use default styling.
  final CometChatCallLogsStyle? style;

  /// The color palette used for styling text colors.
  /// If not provided, will be looked up from context.
  final CometChatColorPalette? colorPalette;

  /// The spacing configuration for padding and margins.
  /// If not provided, will be looked up from context.
  final CometChatSpacing? spacing;

  /// The typography configuration for text styles.
  /// If not provided, will be looked up from context.
  final CometChatTypography? typography;

  @override
  Widget build(BuildContext context) {
    // If a custom view is provided, render it instead
    if (customView != null) {
      return Center(child: customView!(context));
    }

    // Use provided values or fallback to context lookup
    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);
    final effectiveTypography =
        typography ?? CometChatThemeHelper.getTypography(context);
    final effectiveStyle = style ?? CometChatCallLogsStyle.of(context);

    // Default error state view using UIStateUtils
    return UIStateUtils.getDefaultErrorStateView(
      context,
      effectiveColorPalette,
      effectiveTypography,
      effectiveSpacing,
      onRetry,
      // `errorMessage` was accepted and then dropped on the floor — the helper
      // has taken an errorStateSubtitle all along.
      errorStateSubtitle: errorMessage,
      errorStateTextColor: effectiveStyle.errorStateTextColor,
      errorStateTextStyle: effectiveStyle.errorStateTextStyle,
      errorStateSubtitleColor: effectiveStyle.errorStateSubTitleTextColor,
      errorStateSubtitleStyle: effectiveStyle.errorStateSubTitleTextStyle,
      buttonBackgroundColor: effectiveStyle.retryButtonBackgroundColor,
      buttonBorderRadius: effectiveStyle.retryButtonBorderRadius,
      buttonBorderSide: effectiveStyle.retryButtonBorder,
      buttonTextColor: effectiveStyle.retryButtonTextColor,
      buttonTextStyle: effectiveStyle.retryButtonTextStyle,
    );
  }
}
