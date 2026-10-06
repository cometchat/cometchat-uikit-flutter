import 'package:flutter/material.dart';
import '../../../l10n/translations.dart';

/// A floating action button that appears when the user scrolls away from the bottom
///
/// This widget animates in/out based on the provided animation controller.
/// When pressed, it triggers the [onPressed] callback to scroll to the bottom.
class ScrollToBottomButton extends StatelessWidget {
  /// Animation controlling the button's visibility
  final Animation<double> animation;

  /// Callback when the button is pressed
  final VoidCallback onPressed;

  /// Background color of the button
  final Color? backgroundColor;

  /// Icon color
  final Color? iconColor;

  /// Icon to display
  final IconData icon;

  /// Size of the button
  final double size;

  /// Elevation of the button
  final double elevation;

  /// Position from the bottom edge
  final double bottom;

  /// Position from the right edge
  final double right;

  /// Unread message count to display as a badge (0 or null = no badge)
  final int unreadCount;

  /// Badge background color
  final Color? badgeColor;

  /// Badge text color
  final Color? badgeTextColor;

  const ScrollToBottomButton({
    super.key,
    required this.animation,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.icon = Icons.keyboard_arrow_down,
    this.size = 40,
    this.elevation = 4,
    this.bottom = 16,
    this.right = 16,
    this.unreadCount = 0,
    this.badgeColor,
    this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;
    final fgColor = iconColor ?? theme.colorScheme.onSurface;

    return Positioned(
      bottom: bottom,
      right: right,
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Unread badge
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      color: badgeTextColor ?? theme.colorScheme.onError,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // Button
              SizedBox(
                width: size,
                height: size,
                child: Material(
                  elevation: elevation,
                  shape: const CircleBorder(),
                  color: bgColor,
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    button: true,
                    label: Translations.of(context).scrollToBottom,
                    child: InkWell(
                      onTap: onPressed,
                      child: Center(
                        child: Icon(icon, color: fgColor, size: size * 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builder type for custom scroll-to-bottom button
typedef ScrollToBottomBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      VoidCallback onPressed,
    );
