import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../src/call_errors.dart';

/// [CometChatIncomingCall] is the incoming call banner: the caller, the
/// kind of call, and Decline and Accept. With `UIKitSettings.enableCalls`
/// the UI Kit shows it itself (through [IncomingCallOverlay]) over the
/// navigator of `CallNavigationContext.navigatorKey` when a call comes in;
/// configure it with `CallingConfiguration.incomingCallConfiguration`.
///
/// ```dart
/// CometChatIncomingCall(
///   call: call,
///   user: caller,
///   declineButtonText: 'Decline',
///   acceptButtonText: 'Accept',
///   incomingCallStyle: CometChatIncomingCallStyle(
///     backgroundColor: Colors.white,
///   ),
///   onError: (e) => debugPrint('${e.code}: ${e.message}'),
/// )
/// ```
class CometChatIncomingCall extends StatefulWidget {
  /// [call] active Call object
  final Call call;

  /// [user] is used to set a custom user for the widget
  final User? user;

  /// [incomingCallStyle] is used to set a custom incoming call style
  final CometChatIncomingCallStyle? incomingCallStyle;

  /// [callSettingsBuilder] is used to set the session settings (V5)
  final SessionSettingsBuilder? callSettingsBuilder;

  /// [height] is used to set the height of the widget.
  final double? height;

  /// [width] is used to set the width of the widget.
  final double? width;

  /// [declineButtonText] is used to set a custom decline text
  final String? declineButtonText;

  /// [acceptButtonText] is used to set a custom accept text
  final String? acceptButtonText;

  /// [callIcon] is used to set a custom call icon. Without one, the subtitle
  /// shows a phone for a voice call and a video camera for a video call.
  final Widget? callIcon;

  /// [titleView] is used to define the title view.
  final Widget? Function(BuildContext context, Call call)? titleView;

  /// [subTitleView] is used to define the subtitle view.
  final Widget? Function(BuildContext context, Call call)? subTitleView;

  /// [leadingView] is used to define the leading view.
  final Widget? Function(BuildContext context, Call call)? leadingView;

  /// [itemView] is used to define the item view.
  final Widget? Function(BuildContext context, Call call)? itemView;

  /// [trailingView] is used to define the trailing view.
  final Widget? Function(BuildContext context, Call call)? trailingView;

  /// [onDecline] is called at the Decline tap, with the navigator's context
  /// (`CallNavigationContext.navigatorKey`), before the decline goes to the
  /// server. Not called without that navigator, or for a tap that is
  /// ignored (the first tap wins). A side effect: the decline goes ahead
  /// whatever it does, and what it throws goes to [onError]. The UI Kit
  /// stops the ringtone and closes the banner itself.
  final Function(BuildContext, Call)? onDecline;

  /// [onAccept] is called at the Accept tap, as [onDecline], before the
  /// permission request and the accept. The accept goes ahead whatever it
  /// does, even if it takes the banner down with
  /// `IncomingCallOverlay.dismiss()`; a dismiss that names this call's
  /// session counts as the call being over here, and nothing is sent.
  final Function(BuildContext, Call)? onAccept;

  /// Called when something about this call fails:
  ///
  /// * the SDK's own exception, code kept, when accepting or declining
  ///   fails, including when the call was already over (cancelled, ended,
  ///   declined or answered on another device) by the time the request
  ///   landed;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED` when microphone
  ///   or camera access was refused on accept (a video call needs both);
  ///   `details` lists the missing permissions. The call is declined. Without
  ///   an [onError] the UI Kit says so in a SnackBar, with a way to the
  ///   app's settings when the system will not ask again;
  /// * `HOST_CALLBACK_ERROR` when [onAccept] or [onDecline] throws something
  ///   other than a `CometChatException` (which is passed on as it is);
  /// * whatever the call screen then reports: see
  ///   `CometChatOngoingCall.onError`.
  ///
  /// Without an [onError], a failure shows "Something went wrong", except
  /// for a call that was already over, which needs no message.
  final OnError? onError;

  /// [disableSoundForCalls] turns the ringtone and the vibration off.
  ///
  /// Otherwise the call rings as the phone's own ringer would for a caller
  /// who is not a phone contact:
  ///
  /// * Android: at the ring volume, silent in Silent and Vibrate mode and at
  ///   ring volume 0. Under Do Not Disturb it rings only when DND lets calls
  ///   from anyone through (DND's allowed-contacts list cannot include the
  ///   caller), and otherwise neither rings nor vibrates. It vibrates
  ///   always in Vibrate mode, never in Silent mode, and in Sound mode as
  ///   the phone's "Vibrate while ringing" (or ramping ringer, or from
  ///   Android 13 the ring vibration intensity) says; the settings differ
  ///   by maker. It keeps ringing in the background, up to the 60 s limit.
  /// * iOS: from the loudspeaker (or a headset), silent with the Ring/Silent
  ///   switch on Silent, vibrating every 2 seconds, at the media volume, and
  ///   pausing other apps' audio. It rings only while the app is in the
  ///   foreground and unlocked; back in the foreground it rings again if the
  ///   call still rings and is within 60 s of the ring's start. Focus modes
  ///   do not silence it.
  ///
  /// Over a group meeting it plays quieter and leaves the meeting's audio
  /// alone; on iOS it then plays through the meeting's audio, so the
  /// Ring/Silent switch does not silence it and it may not vibrate.
  ///
  /// While it rings, message sounds and other one-shot sounds are skipped.
  /// With [disableSoundForCalls] nothing rings, and they play as usual.
  final bool? disableSoundForCalls;

  /// [customSoundForCalls] is the ringtone to play instead of the UI Kit's
  /// own: an asset path, from [customSoundForCallsPackage]'s assets, or the
  /// app's own when that is null.
  final String? customSoundForCalls;

  /// [customSoundForCallsPackage] is the package whose assets hold
  /// [customSoundForCalls]. A sound not found there is looked for in the
  /// app's own assets, and the UI Kit's ringtone plays when it is not found
  /// at all.
  final String? customSoundForCallsPackage;

  /// [incomingCallBloc] Optional external IncomingCallBloc instance.
  /// If provided, this bloc will be used instead of creating a new one
  /// internally. This widget does not close a bloc it was given: close it
  /// yourself when you are done with it (it rings and runs a 60-second
  /// timer from its creation; in a widget test, close it before the test's
  /// body ends). The one it creates itself it closes.
  final IncomingCallBloc? incomingCallBloc;

  const CometChatIncomingCall({
    super.key,
    required this.call,
    this.user,
    this.onError,
    this.onDecline,
    this.onAccept,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.incomingCallStyle,
    this.callSettingsBuilder,
    this.height,
    this.width,
    this.declineButtonText,
    this.acceptButtonText,
    this.callIcon,
    this.titleView,
    this.subTitleView,
    this.leadingView,
    this.itemView,
    this.trailingView,
    this.incomingCallBloc,
  });

  @override
  State<CometChatIncomingCall> createState() => _CometChatIncomingCallState();
}

class _CometChatIncomingCallState extends State<CometChatIncomingCall> {
  /// BLoC to manage incoming call state
  late IncomingCallBloc _incomingCallBloc;

  /// Track if bloc is external (should not be closed by this widget)
  bool _isExternalBloc = false;

  /// Flag to track if theme has been initialized
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  /// Cached theme values
  late CometChatIncomingCallStyle _style;
  late CometChatTypography _typography;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;

  @override
  void initState() {
    super.initState();

    // Use external bloc if provided, otherwise create a new one
    if (widget.incomingCallBloc != null) {
      _incomingCallBloc = widget.incomingCallBloc!;
      _isExternalBloc = true;
    } else {
      _incomingCallBloc = IncomingCallBloc(
        call: widget.call,
        user: widget.user,
        callSettingsBuilder: widget.callSettingsBuilder,
        onDecline: widget.onDecline,
        onAccept: widget.onAccept,
        disableSoundForCalls: widget.disableSoundForCalls,
        customSoundForCalls: widget.customSoundForCalls,
        customSoundForCallsPackage: widget.customSoundForCallsPackage,
        errorCallback: widget.onError,
      );
      _isExternalBloc = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  /// Tells VoiceOver that a call is coming in: the banner appears without
  /// focus, so nothing read it out. TalkBack hears it from the banner's live
  /// region instead (Android has deprecated announcements).
  void _announce() {
    if (!mounted || defaultTargetPlatform == TargetPlatform.android) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        _semanticsLabel(context),
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      ),
    );
  }

  /// "Caller, Incoming audio call": what a screen reader says of the banner.
  String _semanticsLabel(BuildContext context) {
    final name = widget.user?.name;
    final subtitle = _incomingCallBloc.getSubtitle(context);
    return name == null || name.isEmpty ? subtitle : '$name, $subtitle';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize theme once to avoid expensive lookups during rebuilds
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;

    _typography = CometChatThemeHelper.getTypography(context);
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
    _style = CometChatThemeHelper.getTheme<CometChatIncomingCallStyle>(
      context: context,
      defaultTheme: CometChatIncomingCallStyle.of,
    ).merge(widget.incomingCallStyle);
  }

  @override
  void dispose() {
    // Only close the bloc if we created it internally
    if (!_isExternalBloc) {
      _incomingCallBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Translations.of(context).popScreenDisabled,
                style: TextStyle(
                  color: _colorPalette.white,
                  fontSize: _typography.button?.medium?.fontSize,
                  fontWeight: _typography.button?.medium?.fontWeight,
                  fontFamily: _typography.button?.medium?.fontFamily,
                ),
              ),
              backgroundColor: _colorPalette.error,
            ),
          );
        }
      },
      child: BlocProvider.value(
        value: _incomingCallBloc,
        // A live region, so TalkBack reads the banner out as it appears.
        child: Semantics(
          container: true,
          liveRegion: true,
          label: _semanticsLabel(context),
          // Scrollable so the card stays whole when the user has scaled their
          // text up: at 200% on a small phone the caller name, status and the
          // accept/decline buttons are taller than the viewport, and the
          // buttons are what falls off the bottom.
          child: SingleChildScrollView(child: _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Use custom itemView if provided
    if (widget.itemView != null) {
      return widget.itemView!(context, widget.call)!;
    }

    return Container(
      height: widget.height,
      width: widget.width,
      padding: EdgeInsets.all(_spacing.padding5 ?? 0),
      decoration: BoxDecoration(
        color: _style.backgroundColor ?? _colorPalette.background3,
        border:
            _style.border ??
            Border.all(
              width: 1,
              color: _colorPalette.borderLight ?? Colors.transparent,
            ),
        borderRadius:
            _style.borderRadius ?? BorderRadius.circular(_spacing.radius3 ?? 0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08101828),
            offset: Offset(0, 4),
            blurRadius: 6,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Color(0x14101828),
            offset: Offset(0, 12),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: BlocConsumer<IncomingCallBloc, IncomingCallState>(
        // Only rebuild on status changes to optimize performance
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.isDisabled != current.isDisabled,
        listener: _handleStateChanges,
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _spacing.padding4 ?? 0),
                child: ListTile(
                  horizontalTitleGap: 0,
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 0,
                  minVerticalPadding: 0,
                  minTileHeight: 0,
                  leading: _getLeadingView(context),
                  title: _getTitleView(context),
                  subtitle: _getSubTitleView(context, state),
                  trailing: _getTrailingView(context),
                ),
              ),
              _buildActionButtons(context, state),
            ],
          );
        },
      ),
    );
  }

  /// Handle state changes for side effects
  void _handleStateChanges(BuildContext context, IncomingCallState state) {
    // Handle error state by showing snackbar if no custom error handler.
    // Not for an error the UI Kit has already explained (a refused
    // permission has its own message) or that needs none (the call was
    // already over).
    if (state.status == IncomingCallStatus.error &&
        state.errorMessage != null &&
        widget.onError == null &&
        explainedIncomingCallErrors[state] != true) {
      _showErrorSnackbar(context, state.errorMessage!);
    }
  }

  /// Show error snackbar
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colorPalette.error,
        content: Text(
          Translations.of(context).somethingWentWrongError,
          style: TextStyle(
            color: _colorPalette.white,
            fontSize: _typography.button?.medium?.fontSize,
            fontWeight: _typography.button?.medium?.fontWeight,
            fontFamily: _typography.button?.medium?.fontFamily,
          ),
        ),
      ),
    );
  }

  /// Build action buttons (Decline and Accept)
  Widget _buildActionButtons(BuildContext context, IncomingCallState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Decline button
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: _spacing.padding2 ?? 0),
            // Off once either button is tapped, as Accept: the first tap
            // wins.
            child: TextButton(
              onPressed: state.isDisabled
                  ? null
                  : () {
                      _incomingCallBloc.add(const RejectCall());
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  _style.declineButtonColor ?? _colorPalette.error,
                ),
                side: WidgetStateProperty.all(
                  BorderSide(
                    color: _colorPalette.borderDark ?? Colors.transparent,
                    width: 1,
                  ),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    side: BorderSide(
                      color: _colorPalette.borderDark ?? Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.all(
                      Radius.circular(_spacing.radius2 ?? 0),
                    ),
                  ),
                ),
              ),
              child: Text(
                widget.declineButtonText ?? Translations.of(context).decline,
                style:
                    TextStyle(
                          fontSize: _typography.button?.medium?.fontSize,
                          fontWeight: _typography.button?.medium?.fontWeight,
                          fontFamily: _typography.button?.medium?.fontFamily,
                          color:
                              _style.declineTextColor ??
                              _colorPalette.buttonIconColor,
                        )
                        .merge(_style.declineTextStyle)
                        .copyWith(color: _style.declineTextColor),
              ),
            ),
          ),
        ),
        // Accept button
        Expanded(
          child: TextButton(
            onPressed: state.isDisabled
                ? null
                : () {
                    _incomingCallBloc.add(const AcceptCall());
                  },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                _style.acceptButtonColor ?? _colorPalette.success,
              ),
              side: WidgetStateProperty.all(
                BorderSide(
                  color: _colorPalette.borderDark ?? Colors.transparent,
                  width: 1,
                ),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  side: BorderSide(
                    color: _colorPalette.borderDark ?? Colors.transparent,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(_spacing.radius2 ?? 0),
                  ),
                ),
              ),
            ),
            child: Text(
              widget.acceptButtonText ?? Translations.of(context).accept,
              style:
                  TextStyle(
                        fontSize: _typography.button?.medium?.fontSize,
                        fontWeight: _typography.button?.medium?.fontWeight,
                        fontFamily: _typography.button?.medium?.fontFamily,
                        color:
                            _style.acceptTextColor ??
                            _colorPalette.buttonIconColor,
                      )
                      .merge(_style.acceptTextStyle)
                      .copyWith(color: _style.acceptTextColor),
            ),
          ),
        ),
      ],
    );
  }

  /// Leading view
  Widget? _getLeadingView(BuildContext context) {
    if (widget.leadingView != null) {
      return widget.leadingView!(context, widget.call);
    }
    return null;
  }

  /// Title view
  Widget _getTitleView(BuildContext context) {
    if (widget.titleView != null) {
      return widget.titleView!(context, widget.call)!;
    }
    return Text(
      widget.user?.name ?? '',
      style: TextStyle(
        fontSize: _typography.heading1?.bold?.fontSize,
        fontWeight: _typography.heading1?.bold?.fontWeight,
        fontFamily: _typography.heading1?.bold?.fontFamily,
        color: _style.titleColor ?? _colorPalette.textPrimary,
      ).merge(_style.titleTextStyle).copyWith(color: _style.titleColor),
    );
  }

  /// Subtitle view: the call's kind, or "Connecting..." while the accept
  /// goes through (the ringtone has stopped and both buttons are off by
  /// then, and on a slow network that can take a while).
  Widget _getSubTitleView(BuildContext context, IncomingCallState state) {
    if (widget.subTitleView != null) {
      return widget.subTitleView!(context, widget.call)!;
    }
    final isVideoCall = widget.call.type == CallTypeConstants.videoCall;
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(right: _spacing.padding ?? 0),
          child:
              widget.callIcon ??
              Icon(
                isVideoCall ? Icons.videocam : Icons.call,
                color: _style.callIconColor ?? _colorPalette.iconSecondary,
                size: 16,
              ),
        ),
        Text(
          state.status == IncomingCallStatus.accepting
              ? Translations.of(context).connecting
              : _incomingCallBloc.getSubtitle(context),
          style:
              TextStyle(
                    fontSize: _typography.body?.regular?.fontSize,
                    fontWeight: _typography.body?.regular?.fontWeight,
                    fontFamily: _typography.body?.regular?.fontFamily,
                    color: _style.subtitleColor ?? _colorPalette.textSecondary,
                  )
                  .merge(_style.subtitleTextStyle)
                  .copyWith(color: _style.subtitleColor),
        ),
      ],
    );
  }

  /// Trailing view
  Widget _getTrailingView(BuildContext context) {
    if (widget.trailingView != null) {
      return widget.trailingView!(context, widget.call)!;
    }
    return CometChatAvatar(
      height: 48,
      width: 48,
      image: widget.user?.avatar,
      name: widget.user?.name,
      style: CometChatAvatarStyle(
        placeHolderTextStyle: TextStyle(
          fontSize: _typography.heading1?.bold?.fontSize,
          fontWeight: _typography.heading1?.bold?.fontWeight,
          fontFamily: _typography.heading1?.bold?.fontFamily,
        ).merge(_style.avatarStyle?.placeHolderTextStyle),
        backgroundColor: _style.avatarStyle?.backgroundColor,
        placeHolderTextColor: _style.avatarStyle?.placeHolderTextColor,
        borderRadius: _style.avatarStyle?.borderRadius,
        border: _style.avatarStyle?.border,
      ),
    );
  }
}
