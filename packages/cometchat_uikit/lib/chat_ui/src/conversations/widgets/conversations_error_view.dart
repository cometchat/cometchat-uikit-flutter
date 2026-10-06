import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../cometchat_chat_uikit.dart' as cc;
import '../../../../shared_ui/src/logging/cometchat_log.dart';

/// A widget that displays the error state for the conversations list.
///
/// This widget renders the error state UI when conversation loading fails.
/// It shows an error image, a title text ("Oops"), and a subtitle text
/// explaining that something went wrong and prompting the user to try again.
///
/// The widget supports custom error views through the [customView] parameter.
/// When provided, the custom view will be rendered instead of the default UI.
class ConversationsErrorView extends StatelessWidget {
  const ConversationsErrorView({
    super.key,
    this.customView,
    required this.errorMessage,
    required this.style,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
  });

  /// Optional custom view builder to override the default error view.
  /// When provided, this view will be rendered instead of the default error state UI.
  final WidgetBuilder? customView;

  /// The error message to display (currently used for debugging/logging purposes).
  /// The default UI shows a generic error message from translations.
  final String errorMessage;

  /// The style configuration for the conversations widget.
  /// Used to apply custom text styles and colors for the error state.
  final CometChatConversationsStyle style;

  /// The color palette used for styling text colors.
  final CometChatColorPalette colorPalette;

  /// The spacing configuration for padding and margins.
  final CometChatSpacing spacing;

  /// The typography configuration for text styles.
  final CometChatTypography typography;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      ccLog('[ConversationsErrorView] build');
      ccLog(
        '[ConversationsErrorView]   hasError: true (this view only renders on error)',
      );
      ccLog('[ConversationsErrorView]   errorMessage: $errorMessage');
      ccLog('[ConversationsErrorView]   hasCustomView: ${customView != null}');
    }

    // If a custom view is provided, render it instead
    if (customView != null) {
      return Center(child: customView!(context));
    }

    // Default error state view
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error state image
            Padding(
              padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
              child: Image.asset(
                excludeFromSemantics: true,
                AssetConstants(
                  CometChatThemeHelper.getBrightness(context),
                ).messagesError,
                package: UIConstants.packageName,
                width: 120,
                height: 100,
              ),
            ),
            // Title text - "Oops"
            Text(
              cc.Translations.of(context).oops,
              style:
                  TextStyle(
                        color:
                            style.errorStateTextColor ??
                            colorPalette.textPrimary,
                        fontSize: typography.heading3?.bold?.fontSize,
                        fontWeight: typography.heading3?.bold?.fontWeight,
                        fontFamily: typography.heading3?.bold?.fontFamily,
                      )
                      .merge(style.errorStateTextStyle)
                      .copyWith(color: style.errorStateTextColor),
            ),
            // Subtitle text - "Looks like something went wrong. Please try again."
            Text(
              "${cc.Translations.of(context).looksLikeSomethingWrong}.\n${cc.Translations.of(context).pleaseTryAgain}.",
              textAlign: TextAlign.center,
              style:
                  TextStyle(
                        color:
                            style.errorStateSubTitleTextColor ??
                            colorPalette.textSecondary,
                        fontSize: typography.heading3?.regular?.fontSize,
                        fontWeight: typography.heading3?.regular?.fontWeight,
                        fontFamily: typography.heading3?.regular?.fontFamily,
                      )
                      .merge(style.errorStateSubTitleTextStyle)
                      .copyWith(color: style.errorStateSubTitleTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
