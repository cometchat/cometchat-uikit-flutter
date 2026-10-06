import 'package:flutter/material.dart';
import '../../../../cometchat_chat_uikit.dart';

/// [CometChatGroupListItem] is a dedicated widget for displaying a single group list item.
///
/// This widget is purpose-built for groups and provides group-specific features including:
/// - Avatar with group type indicator (private, password-protected, public)
/// - Title (group name)
/// - Subtitle (member count)
/// - Trailing view (custom content)
/// - Selection mode support with checkbox
/// - Tap and long-press gesture handling
/// - Full theme integration with CometChatTheme
/// - Extensive customization through style objects and individual parameters
///
/// ## Basic Usage
///
/// ```dart
/// CometChatGroupListItem(
///   group: group,
///   onItemClick: (group) => navigateToGroup(group),
/// )
/// ```
///
/// ## With Selection Mode
///
/// ```dart
/// CometChatGroupListItem(
///   group: group,
///   onItemClick: (group) => handleClick(group),
///   selectionMode: SelectionMode.multiple,
///   isSelected: isSelected,
///   onSelectionToggle: () => toggleSelection(),
/// )
/// ```
///
/// ## With Custom Views
///
/// ```dart
/// CometChatGroupListItem(
///   group: group,
///   onItemClick: (group) => handleClick(group),
///   leadingView: (group) => CustomAvatar(group: group),
///   subtitleView: (group) => CustomSubtitle(group: group),
/// )
/// ```
///
/// See also:
/// - [CometChatGroupListItemStyle] for comprehensive styling options
/// - [GroupsList] for displaying a list of groups
class CometChatGroupListItem extends StatelessWidget {
  const CometChatGroupListItem({
    super.key,
    required this.group,
    required this.onItemClick,
    this.onItemLongClick,
    this.onSelectionToggle,
    this.isSelected = false,
    this.selectionMode = SelectionMode.none,
    this.hideGroupTypeIcon = false,
    this.style,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.avatarHeight,
    this.avatarWidth,
    this.avatarPadding,
    this.avatarMargin,
    this.statusIndicatorHeight,
    this.statusIndicatorWidth,
    this.statusIndicatorBorderRadius,
    this.leadingView,
    this.titleView,
    this.subtitleView,
    this.trailingView,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.privateGroupIcon,
    this.protectedGroupIcon,
    this.privateGroupIconBackground,
    this.protectedGroupIconBackground,
  });

  /// [group] is the group object to display
  final Group group;

  /// [onItemClick] callback triggered when the item is tapped
  final Function(Group) onItemClick;

  /// [onItemLongClick] callback triggered when the item is long-pressed
  final Function(Group)? onItemLongClick;

  /// [onSelectionToggle] callback triggered when the selection checkbox is toggled
  final VoidCallback? onSelectionToggle;

  /// [isSelected] whether this group is currently selected
  final bool isSelected;

  /// [selectionMode] determines the selection behavior (none, single, multiple)
  final SelectionMode selectionMode;

  /// [hideGroupTypeIcon] hides the group type indicator (private/password icons)
  final bool hideGroupTypeIcon;

  /// [style] comprehensive style configuration for the list item
  final CometChatGroupListItemStyle? style;

  /// [avatarStyle] style configuration for the avatar (overrides style.avatarStyle)
  final CometChatAvatarStyle? avatarStyle;

  /// [statusIndicatorStyle] style configuration for the status indicator (overrides style.statusIndicatorStyle)
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  /// [avatarHeight] provides height to the avatar widget
  final double? avatarHeight;

  /// [avatarWidth] provides width to the avatar widget
  final double? avatarWidth;

  /// [avatarPadding] provides padding to the avatar widget
  final EdgeInsetsGeometry? avatarPadding;

  /// [avatarMargin] provides margin to the avatar widget
  final EdgeInsetsGeometry? avatarMargin;

  /// [statusIndicatorHeight] provides height to the status indicator
  final double? statusIndicatorHeight;

  /// [statusIndicatorWidth] provides width to the status indicator
  final double? statusIndicatorWidth;

  /// [statusIndicatorBorderRadius] provides border radius to the status indicator
  final BorderRadiusGeometry? statusIndicatorBorderRadius;

  /// [leadingView] custom widget builder for the leading section (avatar area)
  final Widget? Function(Group)? leadingView;

  /// [titleView] custom widget builder for the title section
  final Widget? Function(Group)? titleView;

  /// [subtitleView] custom widget builder for the subtitle section
  final Widget? Function(Group)? subtitleView;

  /// [trailingView] custom widget builder for the trailing section
  final Widget? Function(Group)? trailingView;

  /// [colorPalette] custom color palette (overrides theme colors)
  final CometChatColorPalette? colorPalette;

  /// [spacing] custom spacing configuration (overrides theme spacing)
  final CometChatSpacing? spacing;

  /// [typography] custom typography configuration (overrides theme typography)
  final CometChatTypography? typography;

  /// [privateGroupIcon] custom icon for private group indicator
  final Widget? privateGroupIcon;

  /// [protectedGroupIcon] custom icon for protected (password) group indicator
  final Widget? protectedGroupIcon;

  /// [privateGroupIconBackground] background colour for the private-group badge
  final Color? privateGroupIconBackground;

  /// [protectedGroupIconBackground] background colour for the protected-group badge
  final Color? protectedGroupIconBackground;

  @override
  Widget build(BuildContext context) {
    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);
    final effectiveTypography =
        typography ?? CometChatThemeHelper.getTypography(context);
    final effectiveStyle =
        style ?? CometChatGroupListItemStyle.fromTheme(context);

    final backgroundColor = isSelected
        ? (effectiveStyle.selectedBackgroundColor ??
              effectiveColorPalette.background4)
        : (effectiveStyle.backgroundColor ?? effectiveColorPalette.background1);

    return Semantics(
      label: _buildAccessibilityLabel(context),
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => onItemClick(group),
        onLongPress: onItemLongClick != null
            ? () => onItemLongClick!(group)
            : null,
        child: Container(
          color: backgroundColor,
          padding: EdgeInsets.symmetric(
            horizontal: effectiveSpacing.padding4 ?? 16,
            vertical: effectiveSpacing.padding3 ?? 12,
          ),
          child: Row(
            children: [
              if (selectionMode != SelectionMode.none)
                _buildSelectionCheckbox(
                  effectiveStyle,
                  effectiveColorPalette,
                  effectiveSpacing,
                ),
              _buildLeadingView(
                context,
                effectiveStyle,
                effectiveColorPalette,
                effectiveSpacing,
                effectiveTypography,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTitleView(
                      context,
                      effectiveStyle,
                      effectiveColorPalette,
                      effectiveTypography,
                    ),
                    const SizedBox(height: 2),
                    _buildSubtitleView(
                      context,
                      effectiveStyle,
                      effectiveColorPalette,
                      effectiveTypography,
                    ),
                  ],
                ),
              ),
              _buildTrailingView(
                context,
                effectiveStyle,
                effectiveColorPalette,
                effectiveTypography,
                effectiveSpacing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildAccessibilityLabel(BuildContext context) {
    final parts = <String>[group.name];

    // Add member count
    final memberCount = group.membersCount;
    if (memberCount > 0) {
      parts.add('$memberCount ${memberCount == 1 ? 'member' : 'members'}');
    }

    // Add group type
    if (group.type == CometChatGroupType.private) {
      parts.add('private group');
    } else if (group.type == CometChatGroupType.password) {
      parts.add('password protected group');
    } else {
      parts.add('public group');
    }

    if (isSelected) parts.add('selected');

    return parts.join(', ');
  }

  Widget _buildSelectionCheckbox(
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
    CometChatSpacing effectiveSpacing,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: effectiveSpacing.padding3 ?? 12,
        right: effectiveSpacing.padding2 ?? 8,
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Checkbox(
          value: isSelected,
          onChanged: (value) => onSelectionToggle?.call(),
          checkColor: effectiveStyle.checkBoxCheckColor,
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return effectiveStyle.checkBoxCheckedBackgroundColor ??
                  effectiveColorPalette.primary;
            }
            return effectiveStyle.checkBoxBackgroundColor ?? Colors.transparent;
          }),
          shape: RoundedRectangleBorder(
            borderRadius:
                effectiveStyle.checkBoxBorderRadius ??
                BorderRadius.circular(effectiveSpacing.radius1 ?? 4),
          ),
          side: BorderSide(
            color:
                effectiveStyle.checkBoxStrokeColor ??
                effectiveColorPalette.borderDefault ??
                Colors.grey,
            width: effectiveStyle.checkBoxStrokeWidth ?? 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingView(
    BuildContext context,
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
    CometChatSpacing effectiveSpacing,
    CometChatTypography effectiveTypography,
  ) {
    if (leadingView != null) {
      final customView = leadingView!(group);
      if (customView != null) {
        return Padding(
          padding: EdgeInsets.only(right: effectiveSpacing.padding3 ?? 12),
          child: customView,
        );
      }
    }

    // Create avatar style with explicit text size to match other list items
    final effectiveAvatarStyle =
        (avatarStyle ??
                effectiveStyle.avatarStyle ??
                const CometChatAvatarStyle())
            .copyWith(
              placeHolderTextStyle: TextStyle(
                fontSize: effectiveTypography.heading2?.bold?.fontSize,
                fontWeight: effectiveTypography.heading2?.bold?.fontWeight,
                fontFamily: effectiveTypography.heading2?.bold?.fontFamily,
              ),
            );

    return Padding(
      padding: EdgeInsets.only(right: effectiveSpacing.padding3 ?? 12),
      child: Stack(
        children: [
          CometChatAvatar(
            image: group.icon,
            name: group.name,
            height: avatarHeight ?? 48,
            width: avatarWidth ?? 48,
            padding: avatarPadding,
            margin: avatarMargin,
            style: effectiveAvatarStyle,
          ),
          if (_shouldShowStatusIndicator())
            Positioned(
              right: 0,
              bottom: 0,
              child: CometChatStatusIndicator(
                height: statusIndicatorHeight ?? 14,
                width: statusIndicatorWidth ?? 14,
                backgroundImage: _getStatusIndicatorIcon(effectiveColorPalette),
                style: CometChatStatusIndicatorStyle(
                  // borderRadius was absent here, so neither the widget's
                  // statusIndicatorBorderRadius nor the style's borderRadius
                  // could reach the badge. ENG-39124.
                  borderRadius:
                      statusIndicatorBorderRadius ??
                      statusIndicatorStyle?.borderRadius ??
                      effectiveStyle.statusIndicatorStyle?.borderRadius,
                  border:
                      statusIndicatorStyle?.border ??
                      effectiveStyle.statusIndicatorStyle?.border ??
                      Border.all(
                        width: effectiveSpacing.spacing ?? 0,
                        color:
                            effectiveColorPalette.background1 ??
                            Colors.transparent,
                      ),
                  backgroundColor: _getStatusIndicatorBackgroundColor(
                    effectiveStyle,
                    effectiveColorPalette,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleView(
    BuildContext context,
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
    CometChatTypography effectiveTypography,
  ) {
    if (titleView != null) {
      final customView = titleView!(group);
      if (customView != null) {
        return customView;
      }
    }

    return Text(
      group.name,
      style:
          (effectiveStyle.titleTextStyle ??
                  effectiveTypography.heading4?.medium)
              ?.copyWith(
                color:
                    effectiveStyle.titleTextColor ??
                    effectiveColorPalette.textPrimary,
              ),
      maxLines: scaledMaxLines(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitleView(
    BuildContext context,
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
    CometChatTypography effectiveTypography,
  ) {
    if (subtitleView != null) {
      final customView = subtitleView!(group);
      if (customView != null) {
        return customView;
      }
    }

    // Default subtitle shows member count
    final memberCount = group.membersCount;
    final memberText =
        '$memberCount ${memberCount == 1 ? Translations.of(context).member : Translations.of(context).members}';

    return Text(
      memberText,
      style:
          (effectiveStyle.subtitleTextStyle ??
                  effectiveTypography.body?.regular)
              ?.copyWith(
                color:
                    effectiveStyle.subtitleTextColor ??
                    effectiveColorPalette.textSecondary,
              ),
      maxLines: scaledMaxLines(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailingView(
    BuildContext context,
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
    CometChatTypography effectiveTypography,
    CometChatSpacing effectiveSpacing,
  ) {
    if (trailingView != null) {
      final customView = trailingView!(group);
      if (customView != null) {
        return Padding(
          padding: EdgeInsets.only(left: effectiveSpacing.padding2 ?? 8),
          child: customView,
        );
      }
    }

    // Default trailing view is empty
    return const SizedBox.shrink();
  }

  bool _shouldShowStatusIndicator() {
    if (hideGroupTypeIcon) return false;

    // Show indicator for private and password-protected groups
    return group.type == CometChatGroupType.private ||
        group.type == CometChatGroupType.password;
  }

  /// The status dot's colour: the style's colour for this group type first,
  /// then any status indicator style, then the palette.
  Color? _getStatusIndicatorBackgroundColor(
    CometChatGroupListItemStyle effectiveStyle,
    CometChatColorPalette effectiveColorPalette,
  ) {
    final fromStatusStyle =
        statusIndicatorStyle?.backgroundColor ??
        effectiveStyle.statusIndicatorStyle?.backgroundColor;
    if (group.type == CometChatGroupType.password) {
      // Caller-supplied colour first, then the style, then the status-indicator
      // style; protected groups default to the success colour (green).
      return protectedGroupIconBackground ??
          effectiveStyle.protectedGroupIconBackground ??
          fromStatusStyle ??
          effectiveColorPalette.success ??
          Colors.green;
    } else if (group.type == CometChatGroupType.private) {
      // Private groups default to the warning colour (yellow).
      return privateGroupIconBackground ??
          effectiveStyle.privateGroupIconBackground ??
          fromStatusStyle ??
          effectiveColorPalette.warning ??
          Colors.yellow;
    }
    return fromStatusStyle;
  }

  Widget? _getStatusIndicatorIcon(CometChatColorPalette effectiveColorPalette) {
    // Use custom icons if provided, otherwise use default icons with proper color
    if (group.type == CometChatGroupType.private) {
      if (privateGroupIcon != null) {
        return privateGroupIcon;
      }
      return Icon(
        Icons.shield,
        color: effectiveColorPalette.background1 ?? Colors.white,
        size: 7,
      );
    } else if (group.type == CometChatGroupType.password) {
      if (protectedGroupIcon != null) {
        return protectedGroupIcon;
      }
      return Icon(
        Icons.lock,
        color: effectiveColorPalette.background1 ?? Colors.white,
        size: 7,
      );
    }
    return null;
  }
}

/// Style configuration for [CometChatGroupListItem].
///
/// This class provides comprehensive styling options for the group list item widget.
@immutable
class CometChatGroupListItemStyle {
  const CometChatGroupListItemStyle({
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.titleTextStyle,
    this.titleTextColor,
    this.subtitleTextStyle,
    this.subtitleTextColor,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.checkBoxBackgroundColor,
    this.checkBoxCheckedBackgroundColor,
    this.checkBoxBorderRadius,
    this.checkBoxStrokeColor,
    this.checkBoxStrokeWidth,
    this.checkBoxCheckColor,
    this.privateGroupIconBackground,
    this.protectedGroupIconBackground,
  });

  /// Background color of the list item
  final Color? backgroundColor;

  /// Background color when the item is selected
  final Color? selectedBackgroundColor;

  /// Text style for the title (group name)
  final TextStyle? titleTextStyle;

  /// Text color for the title
  final Color? titleTextColor;

  /// Text style for the subtitle (member count)
  final TextStyle? subtitleTextStyle;

  /// Text color for the subtitle
  final Color? subtitleTextColor;

  /// Style for the avatar
  final CometChatAvatarStyle? avatarStyle;

  /// Style for the status indicator (group type icon)
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  /// Background color for unchecked checkbox
  final Color? checkBoxBackgroundColor;

  /// Background color for checked checkbox
  final Color? checkBoxCheckedBackgroundColor;

  /// Border radius for checkbox
  final BorderRadius? checkBoxBorderRadius;

  /// Stroke color for checkbox border
  final Color? checkBoxStrokeColor;

  /// Stroke width for checkbox border
  final double? checkBoxStrokeWidth;

  /// Colour of the check mark inside a checked checkbox
  final Color? checkBoxCheckColor;

  /// Background of the status dot on a private group. Defaults to the
  /// palette's warning colour.
  final Color? privateGroupIconBackground;

  /// Background of the status dot on a password-protected group. Defaults to
  /// the palette's success colour.
  final Color? protectedGroupIconBackground;

  /// Creates a style from the current theme context
  factory CometChatGroupListItemStyle.fromTheme(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);

    return CometChatGroupListItemStyle(
      backgroundColor: colorPalette.background1,
      selectedBackgroundColor: colorPalette.background4,
      titleTextStyle: typography.heading4?.medium,
      titleTextColor: colorPalette.textPrimary,
      subtitleTextStyle: typography.body?.regular,
      subtitleTextColor: colorPalette.textSecondary,
      checkBoxCheckedBackgroundColor: colorPalette.primary,
      checkBoxStrokeColor: colorPalette.borderDefault,
    );
  }

  /// Creates a copy of this style with the given fields replaced
  CometChatGroupListItemStyle copyWith({
    Color? backgroundColor,
    Color? selectedBackgroundColor,
    TextStyle? titleTextStyle,
    Color? titleTextColor,
    TextStyle? subtitleTextStyle,
    Color? subtitleTextColor,
    CometChatAvatarStyle? avatarStyle,
    CometChatStatusIndicatorStyle? statusIndicatorStyle,
    Color? checkBoxBackgroundColor,
    Color? checkBoxCheckedBackgroundColor,
    BorderRadius? checkBoxBorderRadius,
    Color? checkBoxStrokeColor,
    double? checkBoxStrokeWidth,
    Color? checkBoxCheckColor,
    Color? privateGroupIconBackground,
    Color? protectedGroupIconBackground,
  }) {
    return CometChatGroupListItemStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      selectedBackgroundColor:
          selectedBackgroundColor ?? this.selectedBackgroundColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? this.statusIndicatorStyle,
      checkBoxBackgroundColor:
          checkBoxBackgroundColor ?? this.checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor:
          checkBoxCheckedBackgroundColor ?? this.checkBoxCheckedBackgroundColor,
      checkBoxBorderRadius: checkBoxBorderRadius ?? this.checkBoxBorderRadius,
      checkBoxStrokeColor: checkBoxStrokeColor ?? this.checkBoxStrokeColor,
      checkBoxStrokeWidth: checkBoxStrokeWidth ?? this.checkBoxStrokeWidth,
      checkBoxCheckColor: checkBoxCheckColor ?? this.checkBoxCheckColor,
      privateGroupIconBackground:
          privateGroupIconBackground ?? this.privateGroupIconBackground,
      protectedGroupIconBackground:
          protectedGroupIconBackground ?? this.protectedGroupIconBackground,
    );
  }

  /// Merges this style with another, with the other style taking precedence
  CometChatGroupListItemStyle merge(CometChatGroupListItemStyle? other) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      selectedBackgroundColor: other.selectedBackgroundColor,
      titleTextStyle: other.titleTextStyle,
      titleTextColor: other.titleTextColor,
      subtitleTextStyle: other.subtitleTextStyle,
      subtitleTextColor: other.subtitleTextColor,
      avatarStyle: other.avatarStyle,
      statusIndicatorStyle: other.statusIndicatorStyle,
      checkBoxBackgroundColor: other.checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor: other.checkBoxCheckedBackgroundColor,
      checkBoxBorderRadius: other.checkBoxBorderRadius,
      checkBoxStrokeColor: other.checkBoxStrokeColor,
      checkBoxStrokeWidth: other.checkBoxStrokeWidth,
      checkBoxCheckColor: other.checkBoxCheckColor,
      privateGroupIconBackground: other.privateGroupIconBackground,
      protectedGroupIconBackground: other.protectedGroupIconBackground,
    );
  }

  /// Gets the style from the current context
  static CometChatGroupListItemStyle of(BuildContext context) {
    return CometChatGroupListItemStyle.fromTheme(context);
  }
}
