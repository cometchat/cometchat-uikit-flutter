import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';

/// [CometChatCallButtons] is a button widget with voice and video call icons.
///
/// This widget uses BLoC pattern for state management and supports both
/// user (direct call) and group (meeting) receivers.
///
/// ```dart
/// CometChatCallButtons(
///   user: User(),
///   group: Group(),
/// );
/// ```
class CometChatCallButtons extends StatefulWidget {
  const CometChatCallButtons({
    super.key,
    this.user,
    this.group,
    this.callButtonsStyle,
    this.onError,
    this.hideVideoCallButton,
    this.hideVoiceCallButton,
    this.voiceCallIcon,
    this.videoCallIcon,
    this.outgoingCallConfiguration,
    this.callSettingsBuilder,
    this.callButtonsBloc,
  });

  /// The user a voice or video call goes to. When it changes to another
  /// user (another `uid`), the buttons' own bloc is replaced, so a header
  /// reused for another conversation calls the new person.
  final User? user;

  /// The group a meeting starts in, instead of [user]. A change of `guid`
  /// replaces the buttons' own bloc, as for [user].
  final Group? group;
  final CometChatCallButtonsStyle? callButtonsStyle;

  /// Errors from starting or joining calls: called when a call or meeting
  /// cannot be placed or started:
  ///
  /// * `ACTIVE_CALL`: another call is in progress on this device, a group
  ///   meeting is on the call screen, or a call is being placed from
  ///   another call component (one at a time);
  /// * `NO_NAVIGATOR`: `CallNavigationContext.navigatorKey` has no navigator
  ///   to show the call on. Checked before anything is placed or sent; if
  ///   the navigator goes while a call is being placed, the call is
  ///   cancelled;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED`: microphone (or
  ///   camera) access was refused; `details` lists the missing permissions;
  /// * `CALLS_NOT_READY`: a meeting was not started because the Calls SDK
  ///   is not initialised or not logged in; its message was not sent;
  /// * the SDK's own exception, code kept, when placing the call or sending
  ///   a meeting's message fails (or cancelling a call that could not be
  ///   shown);
  /// * a platform error, its code kept, when asking for permissions fails
  ///   (a request already running, say);
  /// * for a meeting, whatever its call screen reports: see
  ///   `CometChatOngoingCall.onError`.
  ///
  /// The buttons are off from the tap until the call's screen is up (or it
  /// has failed); a tap in that time is dropped. A meeting's screen opens
  /// only once its message is sent. A call placed, or a meeting announced,
  /// while the chat closed still gets its screen (its bloc carries on), so
  /// this can be called after the buttons are gone.
  final OnError? onError;
  final bool? hideVoiceCallButton;
  final bool? hideVideoCallButton;
  final Widget? voiceCallIcon;
  final Widget? videoCallIcon;
  final CometChatOutgoingCallConfiguration? outgoingCallConfiguration;
  final SessionSettingsBuilder Function(
    User? user,
    Group? group,
    bool? isAudioOnly,
  )?
  callSettingsBuilder;

  /// A bloc of the app's own for the buttons, instead of the one they build.
  /// It is used as it is: not rebuilt when [user] or [group] changes (its
  /// receiver is fixed when it is created) and not closed when the buttons
  /// go.
  final CallButtonsBloc? callButtonsBloc;

  @override
  State<CometChatCallButtons> createState() => _CometChatCallButtonsState();
}

class _CometChatCallButtonsState extends State<CometChatCallButtons> {
  late CallButtonsBloc _callButtonsBloc;
  bool _isExternalBloc = false;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;
  late CometChatCallButtonsStyle _style;
  late CometChatColorPalette _colorPalette;

  @override
  void initState() {
    super.initState();
    _initializeBloc();
  }

  void _initializeBloc() {
    if (widget.callButtonsBloc != null) {
      _callButtonsBloc = widget.callButtonsBloc!;
      _isExternalBloc = true;
    } else {
      _callButtonsBloc = CallButtonsBloc(
        user: widget.user,
        group: widget.group,
        outgoingCallConfiguration: widget.outgoingCallConfiguration,
        callSettingsBuilder: widget.callSettingsBuilder,
        errorCallback: widget.onError,
      );
      _isExternalBloc = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _style = CometChatThemeHelper.getTheme<CometChatCallButtonsStyle>(
      context: context,
      defaultTheme: CometChatCallButtonsStyle.of,
    ).merge(widget.callButtonsStyle);
  }

  @override
  void didUpdateWidget(CometChatCallButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.callButtonsStyle != oldWidget.callButtonsStyle &&
        widget.callButtonsStyle != null) {
      _style = CometChatThemeHelper.getTheme<CometChatCallButtonsStyle>(
        context: context,
        defaultTheme: CometChatCallButtonsStyle.of,
      ).merge(widget.callButtonsStyle);
    }
    // A header reused for someone else (a new user or group on the same
    // widget) must not call the previous one: the bloc it built for them
    // is replaced. One handed in (callButtonsBloc) is left alone.
    final receiverChanged =
        widget.user?.uid != oldWidget.user?.uid ||
        widget.group?.guid != oldWidget.group?.guid;
    if (widget.callButtonsBloc != oldWidget.callButtonsBloc ||
        (receiverChanged && widget.callButtonsBloc == null)) {
      if (!_isExternalBloc) {
        _callButtonsBloc.close();
      }
      _initializeBloc();
    }
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      _callButtonsBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _colorPalette.transparent ?? Colors.transparent,
      child: BlocProvider.value(
        value: _callButtonsBloc,
        child: BlocBuilder<CallButtonsBloc, CallButtonsState>(
          builder: (context, state) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                if (widget.hideVoiceCallButton != true)
                  _buildVoiceCallButton(context, state),
                if (widget.hideVideoCallButton != true)
                  _buildVideoCallButton(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoiceCallButton(BuildContext context, CallButtonsState state) {
    final hasBorder =
        _style.voiceCallButtonBorder != null &&
        _style.voiceCallButtonBorder != BorderSide.none;
    return IconButton(
      tooltip: Translations.of(context).voiceCall,
      padding: hasBorder
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
          : const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius:
              _style.voiceCallButtonBorderRadius ?? BorderRadius.circular(0),
          side: _style.voiceCallButtonBorder ?? BorderSide.none,
        ),
        backgroundColor: _style.voiceCallButtonColor,
      ),
      onPressed: state.isDisabled
          ? null
          : () => _callButtonsBloc.add(const InitiateVoiceCall()),
      icon:
          widget.voiceCallIcon ??
          Icon(
            Icons.call_outlined,
            size: 24,
            color: _style.voiceCallIconColor ?? _colorPalette.iconPrimary,
          ),
    );
  }

  Widget _buildVideoCallButton(BuildContext context, CallButtonsState state) {
    final hasBorder =
        _style.videoCallButtonBorder != null &&
        _style.videoCallButtonBorder != BorderSide.none;
    return IconButton(
      tooltip: Translations.of(context).videoCall,
      padding: hasBorder
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
          : const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius:
              _style.videoCallButtonBorderRadius ?? BorderRadius.circular(0),
          side: _style.videoCallButtonBorder ?? BorderSide.none,
        ),
        backgroundColor: _style.videoCallButtonColor,
      ),
      onPressed: state.isDisabled
          ? null
          : () => _callButtonsBloc.add(const InitiateVideoCall()),
      icon:
          widget.videoCallIcon ??
          SvgPicture.asset(
            SvgAssetConstants.videoCall,
            height: 24,
            width: 24,
            colorFilter: ColorFilter.mode(
              _style.videoCallIconColor ??
                  _colorPalette.iconPrimary ??
                  Colors.black,
              BlendMode.srcIn,
            ),
            package: UIConstants.packageName,
          ),
    );
  }
}
