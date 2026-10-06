import 'package:flutter/material.dart';
import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../src/call_logs_load_more_retry.dart';

/// A widget that displays the list of call logs.
///
/// This widget renders a scrollable list of call log items with support for:
/// - Pagination (loads more items when scrolling to bottom; when the next
///   page fails, `state.loadMoreError`, the list ends with a retry row)
/// - Custom item views
/// - Long press options menu
/// - Pre-cached theme values for performance optimization
///
/// The widget uses [CallLogsListItem] for rendering individual items
/// and supports various customization options through callback parameters.
class CallLogsList extends StatelessWidget {
  const CallLogsList({
    super.key,
    required this.state,
    required this.bloc,
    this.onItemTap,
    this.onItemLongPress,
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
    this.setOptions,
    this.addOptions,
    this.loadingStateView,
    this.style,
    this.avatarStyle,
    this.dateStyle,
    this.colorPalette,
    this.spacing,
    this.typography,
  });

  /// Stands in for the logged-in user when [state] has none: it takes part
  /// in no call, so a 1:1 row shows nobody rather than the wrong person.
  static final User _unknownUser = User(uid: '', name: '');

  /// The current state of the call logs BLoC.
  final CallLogsState state;

  /// The call logs BLoC instance for dispatching events.
  final CallLogsBloc bloc;

  /// Callback invoked when an item is tapped.
  final Function(CallLog callLog)? onItemTap;

  /// Callback invoked when an item is long pressed.
  final Function(CallLog callLog)? onItemLongPress;

  /// Callback invoked when the call icon is pressed.
  final Function(CallLog callLog)? onCallIconPressed;

  /// Custom view builder for the entire list item.
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

  /// Callback to set custom options for long press menu.
  final List<CometChatOption>? Function(
    CallLog callLog,
    CallLogsBloc bloc,
    BuildContext context,
  )?
  setOptions;

  /// Callback to add additional options to long press menu.
  final List<CometChatOption>? Function(
    CallLog callLog,
    CallLogsBloc bloc,
    BuildContext context,
  )?
  addOptions;

  /// Custom loading state view for pagination loading indicator.
  final WidgetBuilder? loadingStateView;

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
    final callLogs = state.callLogs;
    final List<GlobalKey> tileKeys = List.generate(
      callLogs.length,
      (index) => GlobalKey(),
    );

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

    return ListView.builder(
      itemCount: state.hasMore ? callLogs.length + 1 : callLogs.length,
      itemBuilder: (context, index) {
        // Show loading indicator for pagination
        if (index >= callLogs.length) {
          // The next page failed: the rows stay, and a retry row asks for it
          // again. The loading row asked on every build, so it looped.
          if (state.loadMoreError != null) {
            return CallLogsLoadMoreRetryRow(
              onRetry: () => bloc.add(const LoadMoreCallLogs()),
              style: effectiveStyle,
              colorPalette: effectiveColorPalette,
              typography: effectiveTypography,
              spacing: effectiveSpacing,
            );
          }
          bloc.add(const LoadMoreCallLogs());
          return CallLogsLoadingView(
            customView: loadingStateView,
            colorPalette: effectiveColorPalette,
            spacing: effectiveSpacing,
            typography: effectiveTypography,
          );
        }

        final log = callLogs[index];

        return CallLogsListItem(
          key: tileKeys[index],
          callLog: log,
          // No logged-in user in the state (fetching it failed): the rows
          // still render, a 1:1 one with an empty title. It used to throw.
          loggedInUser: state.loggedInUser ?? _unknownUser,
          onTap: onItemTap != null ? () => onItemTap!(log) : null,
          onLongPress: () => _handleLongPress(context, log, tileKeys[index]),
          onCallIconPressed: onCallIconPressed != null
              ? () => onCallIconPressed!(log)
              : (CallLogsUtils.isUser(log)
                    ? () => bloc.add(
                        InitiateCallFromLog(callLog: log, context: context),
                      )
                    : null),
          listItemView: listItemView,
          subTitleView: subTitleView,
          trailingView: trailingView,
          leadingView: leadingView,
          titleView: titleView,
          incomingCallIcon: incomingCallIcon,
          outgoingCallIcon: outgoingCallIcon,
          missedCallIcon: missedCallIcon,
          audioCallIcon: audioCallIcon,
          videoCallIcon: videoCallIcon,
          datePattern: datePattern,
          style: effectiveStyle,
          avatarStyle: effectiveAvatarStyle,
          dateStyle: effectiveDateStyle,
          colorPalette: effectiveColorPalette,
          spacing: effectiveSpacing,
          typography: effectiveTypography,
        );
      },
    );
  }

  /// Handles long press on a list item.
  void _handleLongPress(BuildContext context, CallLog callLog, GlobalKey key) {
    if (onItemLongPress != null) {
      onItemLongPress!(callLog);
      return;
    }

    List<CometChatOption>? options;

    if (setOptions != null) {
      options = setOptions!(callLog, bloc, context);
    } else if (addOptions != null) {
      options = addOptions!(callLog, bloc, context);
    }

    if (options != null && options.isNotEmpty) {
      _showPopupMenu(context, options, key);
    }
  }

  /// Shows a popup menu with the given options.
  void _showPopupMenu(
    BuildContext context,
    List<CometChatOption> options,
    GlobalKey key,
  ) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + size.width,
        offset.dy,
        offset.dx + size.width,
        offset.dy + size.height,
      ),
      items: options.map((option) {
        return PopupMenuItem(
          onTap: option.onClick,
          child: Row(
            children: [
              if (option.iconWidget != null) ...[
                option.iconWidget!,
                const SizedBox(width: 8),
              ] else if (option.icon != null) ...[
                Image.network(
                  option.icon!,
                  width: 24,
                  height: 24,
                  color: option.iconTint,
                ),
                const SizedBox(width: 8),
              ],
              Text(option.title ?? '', style: option.titleStyle),
            ],
          ),
        );
      }).toList(),
    );
  }
}
