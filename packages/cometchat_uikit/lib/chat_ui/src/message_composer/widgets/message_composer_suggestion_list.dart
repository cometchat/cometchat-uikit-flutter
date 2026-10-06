import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// A widget that displays the suggestion list for mentions and other formatters.
///
/// This widget renders a scrollable list of suggestion items that appears
/// as an overlay above the message input. It supports:
/// - Avatar display for each suggestion
/// - Title and optional subtitle
/// - Infinite scroll with load more callback
/// - Dynamic height based on item count
///
/// The widget is typically shown via OverlayPortal when suggestions are available.
///
/// Example usage:
/// ```dart
/// MessageComposerSuggestionList(
///   suggestions: mentionSuggestions,
///   onItemTap: (item) => insertMention(item),
///   onScrollToBottom: () => loadMoreSuggestions(),
///   scrollController: _scrollController,
/// )
/// ```
class MessageComposerSuggestionList extends StatelessWidget {
  const MessageComposerSuggestionList({
    super.key,
    required this.suggestions,
    required this.onItemTap,
    required this.onScrollToBottom,
    required this.scrollController,
    this.hasMore = true,
    this.style,
    this.colorPalette,
    this.spacing,
    this.typography,
  });

  /// List of suggestion items to display.
  final List<SuggestionListItem> suggestions;

  /// Callback invoked when a suggestion item is tapped.
  final Function(SuggestionListItem) onItemTap;

  /// Callback invoked when the user scrolls to the bottom.
  /// Used for loading more suggestions (pagination).
  final VoidCallback onScrollToBottom;

  /// Scroll controller for the list.
  final ScrollController scrollController;

  /// Whether there are more suggestions to load.
  /// When true, shows a loading indicator at the bottom.
  final bool hasMore;

  /// Style configuration for the suggestion list.
  final CometChatSuggestionListStyle? style;

  /// Color palette for theming.
  /// If not provided, uses CometChatThemeHelper.getColorPalette(context).
  final CometChatColorPalette? colorPalette;

  /// Spacing configuration.
  /// If not provided, uses CometChatThemeHelper.getSpacing(context).
  final CometChatSpacing? spacing;

  /// Typography configuration.
  /// If not provided, uses CometChatThemeHelper.getTypography(context).
  final CometChatTypography? typography;

  @override
  Widget build(BuildContext context) {
    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);
    final effectiveTypography =
        typography ?? CometChatThemeHelper.getTypography(context);

    final effectiveStyle =
        CometChatThemeHelper.getTheme<CometChatSuggestionListStyle>(
          context: context,
          defaultTheme: CometChatSuggestionListStyle.of,
        ).merge(style);

    return Semantics(
      label: Translations.of(
        context,
      ).suggestionListWithItems(suggestions.length),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          effectiveSpacing.margin2 ?? 8,
          0,
          effectiveSpacing.margin2 ?? 8,
          effectiveSpacing.margin1 ?? 4,
        ),
        padding: EdgeInsets.symmetric(vertical: effectiveSpacing.padding2 ?? 8),
        constraints: BoxConstraints(maxHeight: _calculateMaxHeight()),
        decoration: BoxDecoration(
          color:
              effectiveStyle.backgroundColor ??
              effectiveColorPalette.background1,
          border:
              effectiveStyle.border ??
              Border.all(
                width: 1,
                color: effectiveColorPalette.borderDark ?? Colors.transparent,
              ),
          borderRadius:
              effectiveStyle.borderRadius ??
              BorderRadius.circular(effectiveSpacing.radius4 ?? 12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: .03),
              spreadRadius: -2,
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: .08),
              spreadRadius: -4,
              blurRadius: 16,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ListView.builder(
          controller: scrollController,
          itemCount: hasMore ? suggestions.length + 1 : suggestions.length,
          itemBuilder: (context, index) {
            if (index >= suggestions.length) {
              // Trigger load more when reaching the end
              onScrollToBottom();
              return const SizedBox();
            }
            return _buildSuggestionItem(
              suggestions[index],
              effectiveColorPalette,
              effectiveSpacing,
              effectiveTypography,
              effectiveStyle,
            );
          },
        ),
      ),
    );
  }

  double _calculateMaxHeight() {
    if (suggestions.length > 4) {
      return 220;
    } else if (suggestions.isEmpty) {
      return 66;
    } else {
      return suggestions.length * 75.5;
    }
  }

  Widget _buildSuggestionItem(
    SuggestionListItem item,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    CometChatTypography typography,
    CometChatSuggestionListStyle effectiveStyle,
  ) {
    // Use GestureDetector instead of ListTile to prevent focus stealing.
    // ListTile's internal InkWell requests focus on tap, which causes
    // the keyboard to dismiss when selecting a mention suggestion.
    return Semantics(
      label: item.title ?? 'Suggestion item',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onItemTap(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.padding4 ?? 16,
            vertical: spacing.padding2 ?? 8,
          ),
          child: Row(
            children: [
              if (item.avatarName != null || item.avatarUrl != null)
                Padding(
                  padding: EdgeInsets.only(right: spacing.padding3 ?? 12),
                  child: CometChatAvatar(
                    name: item.avatarName,
                    image: item.avatarUrl,
                    style: effectiveStyle.avatarStyle,
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title ?? "",
                        style:
                            TextStyle(
                                  fontSize:
                                      typography.heading4?.medium?.fontSize,
                                  fontWeight:
                                      typography.heading4?.medium?.fontWeight,
                                  fontFamily:
                                      typography.heading4?.medium?.fontFamily,
                                  color: colorPalette.textPrimary,
                                )
                                .merge(effectiveStyle.textStyle)
                                .copyWith(color: effectiveStyle.textColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (item.subtitle != null)
                      Expanded(
                        child: Text(
                          item.subtitle!,
                          style:
                              TextStyle(
                                    fontSize:
                                        typography.body?.regular?.fontSize,
                                    fontWeight:
                                        typography.body?.regular?.fontWeight,
                                    fontFamily:
                                        typography.body?.regular?.fontFamily,
                                    color: colorPalette.textSecondary,
                                  )
                                  .merge(effectiveStyle.textStyle)
                                  .copyWith(
                                    color: effectiveStyle.textColor?.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
