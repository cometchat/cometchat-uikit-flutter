import 'package:flutter/material.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../cometchat_chat_uikit.dart' as cc;

/// A widget that displays the empty state for the conversations list.
///
/// This widget renders the empty state UI when there are no conversations
/// to display. It shows an empty state image, a title text ("No conversations yet"),
/// and a subtitle text prompting the user to start a new chat.
///
/// The widget supports custom empty views through the [customView] parameter.
/// When provided, the custom view will be rendered instead of the default UI.
class ConversationsEmptyView extends StatelessWidget {
  const ConversationsEmptyView({
    super.key,
    this.customView,
    required this.style,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
  });

  /// Optional custom view builder to override the default empty view.
  /// When provided, this view will be rendered instead of the default empty state UI.
  final WidgetBuilder? customView;

  /// The style configuration for the conversations widget.
  /// Used to apply custom text styles and colors for the empty state.
  final CometChatConversationsStyle style;

  /// The color palette used for styling text colors.
  final CometChatColorPalette colorPalette;

  /// The spacing configuration for padding and margins.
  final CometChatSpacing spacing;

  /// The typography configuration for text styles.
  final CometChatTypography typography;

  @override
  Widget build(BuildContext context) {
    // If a custom view is provided, render it instead
    if (customView != null) {
      return Center(child: customView!(context));
    }

    // Default empty state view.
    //
    // Scrollable so that the illustration and copy stay reachable when the user
    // scales their text up: at 200% on a small phone this Column is taller than
    // the viewport, and without the scroll view the "start a new chat" call to
    // action is the part that falls off the bottom.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Empty state image
            Padding(
              padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
              child: Image.asset(
                AssetConstants(
                  CometChatThemeHelper.getBrightness(context),
                ).conversationEmpty,
                package: UIConstants.packageName,
                excludeFromSemantics: true,
                width: 162,
                height: 121,
              ),
            ),
            // Title text - "No conversations yet"
            Text(
              cc.Translations.of(context).noConversationsYet,
              textAlign: TextAlign.center,
              style:
                  TextStyle(
                        color:
                            style.emptyStateTextColor ??
                            colorPalette.textPrimary,
                        fontSize: typography.heading3?.bold?.fontSize,
                        fontWeight: typography.heading3?.bold?.fontWeight,
                        fontFamily: typography.heading3?.bold?.fontFamily,
                      )
                      .merge(style.emptyStateTextStyle)
                      .copyWith(color: style.emptyStateTextColor),
            ),
            // Subtitle text - "Start a new chat or invite..."
            Text(
              cc.Translations.of(context).startNewChatOrInvite,
              textAlign: TextAlign.center,
              style:
                  TextStyle(
                        color:
                            style.emptyStateSubTitleTextColor ??
                            colorPalette.textSecondary,
                        fontSize: typography.heading3?.regular?.fontSize,
                        fontWeight: typography.heading3?.regular?.fontWeight,
                        fontFamily: typography.heading3?.regular?.fontFamily,
                      )
                      .merge(style.emptyStateSubTitleTextStyle)
                      .copyWith(color: style.emptyStateSubTitleTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
