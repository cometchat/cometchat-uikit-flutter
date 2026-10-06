import 'package:flutter/material.dart';
import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';

/// A widget that displays a single call log item in the list.
///
/// This widget renders an individual call log entry with:
/// - Avatar showing the receiver's profile
/// - Title showing the receiver's name
/// - Subtitle showing call status icon and timestamp
/// - Trailing view showing audio/video call icon
///
/// The widget supports custom views through various callback parameters
/// and accepts pre-cached theme values for performance optimization.
class CallLogsListItem extends StatelessWidget {
  const CallLogsListItem({
    super.key,
    required this.callLog,
    required this.loggedInUser,
    this.onTap,
    this.onLongPress,
    this.onCallIconPressed,
    this.listItemView,
    this.subTitleView,
    this.trailingView,
    this.leadingView,
    this.titleView,
    this.incomingCallIcon,
    this.outgoingCallIcon,
    this.missedCallIcon,
    this.audioCallIcon,
    this.videoCallIcon,
    this.datePattern,
    this.style,
    this.avatarStyle,
    this.dateStyle,
    this.colorPalette,
    this.spacing,
    this.typography,
  });

  /// The call log data to display.
  final CallLog callLog;

  /// The currently logged in user, used to determine call direction. A
  /// group call shows the group whoever it is; a 1:1 call shows the other
  /// participant, and nobody (an empty title) when this user is not in it.
  final User loggedInUser;

  /// Callback invoked when the item is tapped.
  final VoidCallback? onTap;

  /// Callback invoked when the item is long pressed.
  final VoidCallback? onLongPress;

  /// Callback invoked when the call icon is pressed.
  final VoidCallback? onCallIconPressed;

  /// Custom view builder for the entire list item.
  /// When provided, replaces the default list item UI.
  final Widget? Function(CallLog callLog, BuildContext context)? listItemView;

  /// Custom view builder for the subtitle section.
  final Widget? Function(CallLog callLog, BuildContext context)? subTitleView;

  /// Custom view builder for the trailing section.
  final Widget? Function(BuildContext context, CallLog callLog)? trailingView;

  /// Custom view builder for the leading section.
  final Widget? Function(BuildContext context, CallLog callLog)? leadingView;

  /// Custom view builder for the title section.
  final Widget? Function(BuildContext context, CallLog callLog)? titleView;

  /// Custom icon for incoming calls.
  final Widget? incomingCallIcon;

  /// Custom icon for outgoing calls.
  final Widget? outgoingCallIcon;

  /// Custom icon for missed calls.
  final Widget? missedCallIcon;

  /// Custom icon for audio calls.
  final Widget? audioCallIcon;

  /// Custom icon for video calls.
  final Widget? videoCallIcon;

  /// Custom date pattern for formatting timestamps.
  final String? datePattern;

  /// Style configuration for the call logs.
  /// If not provided, will be looked up from context.
  final CometChatCallLogsStyle? style;

  /// Style configuration for the avatar.
  /// If not provided, will be looked up from context.
  final CometChatAvatarStyle? avatarStyle;

  /// Style configuration for the date.
  /// If not provided, will be looked up from context.
  final CometChatDateStyle? dateStyle;

  /// The color palette used for styling.
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
    // If custom list item view is provided, use it
    if (listItemView != null) {
      final customView = listItemView!(callLog, context);
      if (customView != null) {
        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: customView,
        );
      }
    }

    // Use provided values or fallback to context lookup
    final effectiveColorPalette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final effectiveSpacing =
        spacing ?? CometChatThemeHelper.getSpacing(context);
    final effectiveTypography =
        typography ?? CometChatThemeHelper.getTypography(context);
    final effectiveStyle =
        style ??
        CometChatThemeHelper.getTheme<CometChatCallLogsStyle>(
          context: context,
          defaultTheme: CometChatCallLogsStyle.of,
        );
    final effectiveAvatarStyle =
        avatarStyle ??
        CometChatThemeHelper.getTheme<CometChatAvatarStyle>(
          context: context,
          defaultTheme: CometChatAvatarStyle.of,
        ).merge(effectiveStyle.avatarStyle);
    final effectiveDateStyle =
        dateStyle ??
        CometChatThemeHelper.getTheme<CometChatDateStyle>(
          context: context,
          defaultTheme: CometChatDateStyle.of,
        ).merge(effectiveStyle.dateStyle);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: CometChatListItem(
        hideSeparator: true,
        avatarURL: CallLogsUtils.getAvatarUrl(loggedInUser, callLog),
        avatarName: CallLogsUtils.getDisplayName(loggedInUser, callLog),
        title: CallLogsUtils.getDisplayName(loggedInUser, callLog),
        style: ListItemStyle(
          background: effectiveColorPalette.transparent,
          titleStyle:
              TextStyle(
                    overflow: TextOverflow.ellipsis,
                    fontSize: effectiveTypography.heading4?.medium?.fontSize,
                    fontWeight:
                        effectiveTypography.heading4?.medium?.fontWeight,
                    fontFamily:
                        effectiveTypography.heading4?.medium?.fontFamily,
                    color:
                        effectiveStyle.itemTitleTextColor ??
                        CallUtils.getCallStatusColor(
                          callLog,
                          loggedInUser,
                          effectiveColorPalette,
                        ),
                  )
                  .merge(effectiveStyle.itemTitleTextStyle)
                  .copyWith(color: effectiveStyle.itemTitleTextColor),
          padding: EdgeInsets.only(
            left: effectiveSpacing.padding4 ?? 0,
            right: effectiveSpacing.padding4 ?? 0,
            top: effectiveSpacing.padding3 ?? 0,
            bottom: effectiveSpacing.padding3 ?? 0,
          ),
        ),
        subtitleView: _buildSubtitleView(
          context,
          effectiveColorPalette,
          effectiveTypography,
          effectiveSpacing,
          effectiveStyle,
          effectiveDateStyle,
        ),
        tailView: _buildTailView(
          context,
          effectiveColorPalette,
          effectiveStyle,
        ),
        avatarStyle: effectiveAvatarStyle,
        leadingStateView: leadingView?.call(context, callLog),
        titleView: titleView?.call(context, callLog),
      ),
    );
  }

  /// Builds the subtitle view showing call status icon and timestamp.
  Widget _buildSubtitleView(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatCallLogsStyle style,
    CometChatDateStyle dateStyle,
  ) {
    if (subTitleView != null) {
      final customView = subTitleView!(callLog, context);
      if (customView != null) {
        return customView;
      }
    }

    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(right: spacing.padding1 ?? 4),
          child: CallUtils.getCallIcon(
            context,
            callLog,
            loggedInUser,
            colorPalette,
            typography,
            spacing,
            style,
            incomingCallIcon: incomingCallIcon,
            missedCallIcon: missedCallIcon,
            outgoingCallIcon: outgoingCallIcon,
          ),
        ),
        Expanded(
          child: CallLogsUtils.getTime(
            context,
            callLog.initiatedAt,
            colorPalette,
            typography,
            spacing,
            style,
            dateStyle,
            datePattern: datePattern,
          ),
        ),
      ],
    );
  }

  /// Builds the trailing view showing audio/video call icon.
  Widget _buildTailView(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatCallLogsStyle style,
  ) {
    if (trailingView != null) {
      final customView = trailingView!(context, callLog);
      if (customView != null) {
        return customView;
      }
    }

    final IconData iconData = (callLog.type == CallTypeConstants.audioCall)
        ? Icons.call_outlined
        : Icons.videocam_outlined;

    final Widget? icon = (callLog.type == CallTypeConstants.audioCall)
        ? audioCallIcon
        : videoCallIcon;

    final Color? iconColor = (callLog.type == CallTypeConstants.audioCall)
        ? style.audioCallIconColor
        : style.videoCallIconColor;

    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        tooltip: (callLog.type == CallTypeConstants.audioCall)
            ? Translations.of(context).audioCall
            : Translations.of(context).videoCall,
        padding: EdgeInsets.zero,
        onPressed: onCallIconPressed,
        icon:
            icon ??
            Icon(
              iconData,
              size: 24,
              color: iconColor ?? colorPalette.iconPrimary,
            ),
      ),
    );
  }
}
