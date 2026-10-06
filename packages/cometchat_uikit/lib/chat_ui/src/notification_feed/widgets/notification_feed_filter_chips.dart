import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

import '../../../../shared_ui/l10n/translations.dart';
import '../cometchat_notification_feed_style.dart';

/// Horizontal scrollable row of filter chips for the notification feed.
///
/// Always renders N+1 chips: a localized "All" chip (always first) + server
/// categories.
/// Active chip uses filled style, inactive uses border style.
/// Each chip shows an optional unread badge count.
class NotificationFeedFilterChips extends StatelessWidget {
  /// Available categories from the server.
  final List<NotificationCategory> categories;

  /// Currently active category (null = "All").
  final String? activeCategory;

  /// Total unread count (shown on "All" chip).
  final int totalUnreadCount;

  /// Per-category unread counts.
  final Map<String, int> categoryUnreadCounts;

  /// Style configuration.
  final CometChatNotificationFeedStyle style;

  /// Callback when a category is selected. Pass null for "All".
  final void Function(String? categoryId) onCategorySelected;

  const NotificationFeedFilterChips({
    super.key,
    required this.categories,
    required this.activeCategory,
    required this.totalUnreadCount,
    required this.categoryUnreadCounts,
    required this.style,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // "All" chip — always first
            _buildChip(
              label: Translations.of(context).all,
              isActive: activeCategory == null,
              unreadCount: totalUnreadCount,
              onTap: () => onCategorySelected(null),
            ),
            const SizedBox(width: 8),
            // Server categories
            ...categories.map((category) {
              final unread = categoryUnreadCounts[category.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: category.label,
                  isActive: activeCategory == category.id,
                  unreadCount: unread,
                  onTap: () => onCategorySelected(category.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isActive,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    final chipBg = isActive
        ? (style.chipActiveBackgroundColor ?? const Color(0xFF6852D6))
        : (style.chipInactiveBackgroundColor ?? Colors.transparent);
    final chipTextColor = isActive
        ? (style.chipActiveTextColor ?? Colors.white)
        : (style.chipInactiveTextColor ?? Colors.grey.shade800);
    final borderColor = style.chipBorderColor ?? Colors.grey.shade300;

    return Semantics(
      button: true,
      selected: isActive,
      label: '$label filter${unreadCount > 0 ? ', $unreadCount unread' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style:
                    (style.chipTextStyle ??
                            const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ))
                        .copyWith(color: chipTextColor),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                _buildBadge(unreadCount, isActive: isActive),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count, {required bool isActive}) {
    final bgColor = isActive
        ? Colors.white.withValues(alpha: 0.3)
        : (style.badgeBackgroundColor ?? Colors.grey.shade200);
    final textColor = isActive
        ? Colors.white
        : (style.badgeTextColor ?? Colors.grey.shade700);

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style:
            (style.badgeTextStyle ??
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))
                .copyWith(color: textColor),
      ),
    );
  }
}
