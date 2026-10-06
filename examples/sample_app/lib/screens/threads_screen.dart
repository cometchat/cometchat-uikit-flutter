import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Inbox chrome for the mobile and desktop home screens.
///
/// This file previously also held `ThreadsScreen` and `ThreadsEntryTile`.
/// `ThreadsScreen` was built on the SDK's thread listener and
/// `ThreadSubscriptionState` enum, both removed by the stateless
/// thread-subscription refactor, which left it uncompilable; nothing routed
/// to it. `ThreadsEntryTile` rendered the Threads and Saved shortcut cards
/// above the conversation list — Threads went with the screen, and Saved was
/// dropped after it. Saved messages remain reachable from the `/saved`
/// overflow-menu entry on both home screens.

/// Read-only search bar shown above the conversation list; tapping it opens
/// the app's message-search flow (the conversations list's built-in search is
/// hidden in favour of this one). master_app-only chrome.
class InboxSearchBar extends StatelessWidget {
  const InboxSearchBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    return Container(
      color: palette.background1,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: palette.background3,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: palette.iconSecondary),
                const SizedBox(width: 8),
                Text(
                  'Search',
                  style: TextStyle(
                    color: palette.textTertiary ?? palette.textSecondary,
                    fontSize: typography.body?.regular?.fontSize,
                    fontFamily: typography.body?.regular?.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
