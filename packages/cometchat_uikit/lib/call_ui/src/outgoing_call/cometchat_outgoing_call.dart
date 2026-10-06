import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../src/active_call_tracker.dart';

/// [CometChatOutgoingCall] is a widget which is used to show outgoing call screen
/// when the logged-in user calls another user.
///
/// Removing this screen while the call still rings — disposing the widget,
/// say by a `pushAndRemoveUntil` over it, or closing an external [bloc] —
/// cancels the call on the server (`rejectCall` with status `cancelled`) so
/// the callee stops ringing, and frees the device for the next call. A call
/// already answered, declined or cancelled is not touched again, and neither
/// is one whose cancel [onCancelled] took over.
///
/// A call nobody answers is given up after 45 seconds: the screen sends
/// `rejectCall` with status `unanswered` and closes. For a call the UI Kit
/// placed (the call buttons, the call logs), the 45 seconds count from the
/// placement. Once End was tapped or that happened, an accept that arrives
/// is not joined, and a best-effort `endCall` tries to let the callee go.
/// After End the screen closes when the server answers the cancel, or after
/// 10 seconds at most.
///
/// This screen hears the callee's answer from its first build on. An app
/// put in the background right after placing a call draws no frames, so
/// the screen is built only when the app comes back, and an answer or a
/// decline that arrives before then is missed: the screen rings on until
/// the timeout gives the call up. After a missed answer that `unanswered`
/// fails, and a best-effort `endCall` tries to free the callee.
///
/// ```dart
/// CometChatOutgoingCall(
///   call: call,
///   user: user,
///   onError: (error) {
///     print("Error: $error");
///   },
///   onCancelled: (context, call) {
///     print("Decline Call");
///   },
///   declineButtonIcon: Icon(Icons.call_end),
///   style: CometChatOutgoingCallStyle(
///     backgroundColor: Colors.white,
///     titleColor: Colors.black,
///     subtitleColor: Colors.black,
///     iconColor: Colors.black,
///   ),
/// );
/// ```
class CometChatOutgoingCall extends StatefulWidget {
  /// The active outgoing call
  final Call call;

  /// User being called (optional, for display purposes)
  final User? user;

  /// Subtitle view builder
  final Widget? Function(BuildContext context, Call call)? subtitleView;

  /// Custom decline button icon
  final Widget? declineButtonIcon;

  /// Custom outgoing call style
  final CometChatOutgoingCallStyle? outgoingCallStyle;

  /// Custom session settings builder (V5)
  final SessionSettingsBuilder? sessionSettingsBuilder;

  /// Widget height
  final double? height;

  /// Widget width
  final double? width;

  /// Avatar view builder
  final Widget? Function(BuildContext context, Call call)? avatarView;

  /// Title view builder
  final Widget? Function(BuildContext context, Call call)? titleView;

  /// Cancelled view builder (bottom action button)
  final Widget? Function(BuildContext context, Call call)? cancelledView;

  /// Called when something about this call fails:
  ///
  /// * the SDK's own exception, code kept, when cancelling fails (End, or a
  ///   screen removed while the call rang), or giving up after 45 seconds
  ///   unanswered does. The call is usually already over by then: declined,
  ///   answered at that moment, or ended by the server. It still comes when
  ///   that answer arrives after the screen has closed, but not once a
  ///   logout has begun;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED` when the callee
  ///   answered but microphone or camera access was refused here; `details`
  ///   lists the missing permissions;
  /// * a platform error, its code kept, when asking for those permissions
  ///   fails (a request already running, say);
  /// * `NO_NAVIGATOR` when the callee answered but
  ///   `CallNavigationContext.navigatorKey` has no navigator to show the
  ///   call screen on;
  /// * whatever the call screen then reports: see
  ///   `CometChatOngoingCall.onError`.
  final OnError? onError;

  /// Called when End is tapped, instead of the UI Kit's own cancel: the
  /// app then cancels the call itself, and End stays live.
  ///
  /// The ringback plays on until the call ends, the screen closes, or the
  /// app calls `CometChatUIKit.soundManager.stop()`, which stops it as in
  /// 6.1.x. A call left ringing is still given up after 45 seconds. End
  /// wins does not apply: an accept that arrives after this tap is still
  /// joined, since the UI Kit does not know whether the app ended the call.
  final Function(BuildContext context, Call call)? onCancelled;

  /// Whether to play no ringback while the call rings.
  final bool? disableSoundForCalls;

  /// The ringback to play instead of the UI Kit's own: a Flutter asset path,
  /// from the app's assets or [customSoundForCallsPackage]'s.
  ///
  /// It plays as a phone call rings, on a call-tone player apart from the
  /// message sounds: looping, from the earpiece for a voice call and the
  /// loudspeaker for a video call (a wired headset takes either, and so does
  /// a hands-free Bluetooth headset on iOS and on Android 12 and later), in
  /// iOS Silent Mode too, and no longer at the Android media volume. It stops
  /// when ringing ends (answered, declined, cancelled, given up after 45 s,
  /// or the screen closes), and `CometChatUIKit.soundManager.stop()` stops
  /// it too. A sound that cannot be found or played gives way to the UI
  /// Kit's own.
  final String? customSoundForCalls;

  /// The Flutter package that ships [customSoundForCalls], for a sound from
  /// another package. Leave it null for an asset of the app's own.
  ///
  /// Honoured on Android and iOS since 6.2.0; before, it was ignored for the
  /// ringback. A value that names no package with that asset (the app's own
  /// name, say, or `'assets'`) makes the UI Kit look in the app's assets
  /// next, then play its own ringback.
  final String? customSoundForCallsPackage;

  /// Optional external BLoC for testing/injection. This widget does not
  /// close it; closing it while the call still rings cancels the call, as
  /// disposing the widget does with its own bloc (see the class docs).
  /// Disposing the widget only stops that bloc's ringback and its 45 s
  /// no-answer timeout: nothing is on screen any more.
  final OutgoingCallBloc? bloc;

  const CometChatOutgoingCall({
    super.key,
    required this.call,
    this.user,
    this.onError,
    this.onCancelled,
    this.subtitleView,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.declineButtonIcon,
    this.outgoingCallStyle,
    this.sessionSettingsBuilder,
    this.width,
    this.height,
    this.avatarView,
    this.titleView,
    this.cancelledView,
    this.bloc,
  });

  @override
  State<CometChatOutgoingCall> createState() => _CometChatOutgoingCallState();
}

class _CometChatOutgoingCallState extends State<CometChatOutgoingCall> {
  late OutgoingCallBloc _bloc;
  bool _isExternalBloc = false;

  // Cached theme values
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  late CometChatOutgoingCallStyle _style;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void initState() {
    super.initState();
    _isExternalBloc = widget.bloc != null;
    _bloc =
        widget.bloc ??
        OutgoingCallBloc(
          call: widget.call,
          user: widget.user,
          callSettingsBuilder: widget.sessionSettingsBuilder,
          onCancelledCallTap: widget.onCancelled,
          disableSoundForCalls: widget.disableSoundForCalls,
          customSoundForCalls: widget.customSoundForCalls,
          customSoundForCallsPackage: widget.customSoundForCallsPackage,
          errorCallback: widget.onError,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The bloc closes this screen from outside the widget tree (SDK
    // callbacks), so give it this screen's own route. Otherwise it can only
    // pop whatever is on top, and a second close pops the chat underneath.
    ActiveCallTracker.attachOutgoingCallRoute(_bloc, ModalRoute.of(context));
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _style = CometChatThemeHelper.getTheme<CometChatOutgoingCallStyle>(
        context: context,
        defaultTheme: CometChatOutgoingCallStyle.of,
      ).merge(widget.outgoingCallStyle);
      _themeInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_isExternalBloc) {
      // The host's bloc outlives the screen: it only stops ringing.
      ActiveCallTracker.outgoingScreenGone(_bloc);
    } else {
      _bloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OutgoingCallBloc>.value(
      value: _bloc,
      child: PopScope(
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
        child: Scaffold(
          backgroundColor: _colorPalette.transparent,
          body: Container(
            height: widget.height ?? double.infinity,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              color: _style.backgroundColor ?? _colorPalette.background1,
              border: _style.border,
              borderRadius: _style.borderRadius,
            ),
            child: BlocConsumer<OutgoingCallBloc, OutgoingCallState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status,
              listener: _handleStateChanges,
              builder: (context, state) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _spacing.padding5 ?? 0,
                    vertical: _spacing.padding5 ?? 0,
                  ),
                  child: CometChatCard(
                    title: widget.user?.name,
                    avatarName: widget.user?.name,
                    avatarUrl: widget.user?.avatar,
                    titleView: _getTitleView(context, widget.call),
                    avatarHeight: 120,
                    avatarWidth: 120,
                    titlePadding: EdgeInsets.only(
                      bottom: _spacing.padding2 ?? 0,
                    ),
                    subtitleView: _getSubtitleView(context, widget.call),
                    avatarView: _getAvatarView(context, widget.call),
                    cardStyle: CardStyle(
                      titleStyle:
                          TextStyle(
                                fontSize: _typography.heading1?.bold?.fontSize,
                                fontWeight:
                                    _typography.heading1?.bold?.fontWeight,
                                fontFamily:
                                    _typography.heading1?.bold?.fontFamily,
                                color:
                                    _style.titleColor ??
                                    _colorPalette.textPrimary,
                              )
                              .merge(_style.titleTextStyle)
                              .copyWith(color: _style.titleColor),
                      avatarStyle: CometChatAvatarStyle(
                        placeHolderTextStyle: TextStyle(
                          fontSize: _typography.heading1?.bold?.fontSize,
                          fontWeight: _typography.heading1?.bold?.fontWeight,
                          fontFamily: _typography.heading1?.bold?.fontFamily,
                        ).merge(_style.avatarStyle?.placeHolderTextStyle),
                        backgroundColor: _style.avatarStyle?.backgroundColor,
                        placeHolderTextColor:
                            _style.avatarStyle?.placeHolderTextColor,
                        borderRadius: _style.avatarStyle?.borderRadius,
                        border: _style.avatarStyle?.border,
                      ),
                    ),
                    bottomView: _getCancelledView(context, widget.call, state),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, OutgoingCallState state) {
    if (state.status == OutgoingCallStatus.error &&
        state.errorMessage != null) {
      _showError(context, state.errorMessage!);
    }
  }

  Widget _getSubtitleView(BuildContext context, Call call) {
    if (widget.subtitleView != null) {
      return widget.subtitleView!(context, call)!;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: _spacing.padding10 ?? 0),
      child: Text(
        Translations.of(context).calling,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontWeight: _typography.body?.regular?.fontWeight,
          fontFamily: _typography.body?.regular?.fontFamily,
          color: _style.subtitleColor ?? _colorPalette.textSecondary,
        ).merge(_style.subtitleTextStyle).copyWith(color: _style.subtitleColor),
      ),
    );
  }

  Widget? _getAvatarView(BuildContext context, Call call) {
    return widget.avatarView?.call(context, call);
  }

  Widget? _getTitleView(BuildContext context, Call call) {
    return widget.titleView?.call(context, call);
  }

  Widget _getCancelledView(
    BuildContext context,
    Call call,
    OutgoingCallState state,
  ) {
    if (widget.cancelledView != null) {
      return widget.cancelledView!(context, call)!;
    }
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: _style.declineButtonColor ?? _colorPalette.error,
        borderRadius:
            _style.declineButtonBorderRadius ??
            BorderRadius.circular(_spacing.radiusMax ?? 0),
      ),
      child: IconButton(
        tooltip: Translations.of(context).decline,
        onPressed: state.isCallRejected
            ? null
            : () => _bloc.add(const CancelCall()),
        icon:
            widget.declineButtonIcon ??
            Icon(
              Icons.call_end,
              size: 32,
              color: _style.iconColor ?? _colorPalette.white,
            ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    try {
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
    } catch (_) {}
  }
}
