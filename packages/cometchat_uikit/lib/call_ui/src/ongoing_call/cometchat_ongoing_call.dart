import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../src/active_call_tracker.dart';

/// [CometChatOngoingCall] is a widget that displays the ongoing call screen.
///
/// It shows "Connecting..." until the call view arrives, then the call.
/// While the call is still connecting, back cancels it, as End would: the
/// join is given up, a 1-on-1 call is ended on the server, and the screen
/// closes. Once the call is up, back does nothing (picture-in-picture comes
/// in a later release).
///
/// ```dart
/// CometChatOngoingCall(
///   sessionSettingsBuilder: SessionSettingsBuilder(),
///   sessionId: "SESSION_ID",
///   callWorkFlow: CallWorkFlow.directCalling,
/// );
/// ```
class CometChatOngoingCall extends StatefulWidget {
  /// Session settings builder (V5)
  final SessionSettingsBuilder sessionSettingsBuilder;

  /// Session ID for the call
  final String sessionId;

  /// Call workflow type (directCalling or defaultCalling)
  final CallWorkFlow? callWorkFlow;

  /// Called when the call screen fails. A screen that cannot join gets one
  /// of these codes; by then the screen has closed and the device is free
  /// for the next call (a call placed from this callback is not refused).
  /// The media session is being left, and the audio a ringback or ringtone
  /// handed to the call is given back once it is. There is no error
  /// screen. Nothing is sent to the server.
  ///
  /// * `CALLS_NOT_READY`: the Calls SDK is not initialised or not logged in.
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED`: microphone (or
  ///   camera) access was refused; `details` lists the missing permissions.
  ///   After a permanent refusal only the app's settings page can grant it.
  /// * `JOIN_TIMEOUT`: the Calls SDK did not answer the join in 30 s, or its
  ///   call view did not report joining within 30 s of appearing.
  /// * `JOIN_FAILED`: the Calls SDK refused the join; its own code, message
  ///   and details are in `errorParams` (`sdkCode`, `sdkMessage`,
  ///   `sdkDetails`).
  ///
  /// Ending the call reports the SDK's own exception, code kept, when the
  /// end fails; the call is usually already over by then (the other side
  /// ended it at the same moment, say), and the screen has closed.
  ///
  /// This widget never reports `NO_NAVIGATOR`. `CallScreenOverlay.show`
  /// does, to the `onError` given to it, when there is no navigator to show
  /// this screen on.
  final OnError? onError;

  /// Optional external BLoC for testing/injection
  final OngoingCallBloc? bloc;

  const CometChatOngoingCall({
    super.key,
    required this.sessionSettingsBuilder,
    required this.sessionId,
    this.callWorkFlow,
    this.onError,
    this.bloc,
  });

  @override
  State<CometChatOngoingCall> createState() => _CometChatOngoingCallState();
}

class _CometChatOngoingCallState extends State<CometChatOngoingCall> {
  late OngoingCallBloc _bloc;
  bool _isExternalBloc = false;

  @override
  void initState() {
    super.initState();
    _isExternalBloc = widget.bloc != null;
    _bloc =
        widget.bloc ??
        OngoingCallBloc(
          sessionSettingsBuilder: widget.sessionSettingsBuilder,
          sessionId: widget.sessionId,
          callWorkFlow: widget.callWorkFlow,
          errorCallback: widget.onError,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The route this screen sits on: the bloc closes exactly that one.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null) ActiveCallTracker.attachOngoingCallRoute(_bloc, route);
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  /// Back on this screen: the bloc's own rule. While the call still
  /// connects (until the native side reports the join) it cancels the call,
  /// as End would; once the call is up it does nothing. A screen whose call
  /// failed or ended and is still up (a host's own bloc, say) is taken off
  /// its navigator: back used to do nothing there (round 4 review, probe
  /// B).
  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final OngoingCallStatus status = _bloc.state.status;
    if (_bloc.isClosed ||
        status == OngoingCallStatus.error ||
        status == OngoingCallStatus.ended) {
      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      return;
    }
    final void Function()? back = ActiveCallTracker.backHandlerOf(_bloc);
    if (back != null) {
      back();
      return;
    }
    // A bloc that is not the UI Kit's own (a test double): as before.
    if (_bloc.state.status != OngoingCallStatus.loading) return;
    _bloc.add(const EndCallButtonPressed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OngoingCallBloc>.value(
      value: _bloc,
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: _onBack,
        child: BlocBuilder<OngoingCallBloc, OngoingCallState>(
          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.callingWidget != current.callingWidget,
          builder: (context, state) {
            if (state.status == OngoingCallStatus.error) {
              // The bloc has already closed the screen (it used to be taken
              // down from here, on the next frame), freed the device and
              // told onError. This shows only on a screen that had nowhere
              // to close to.
              return Material(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: Center(
                    child: Text(
                      state.errorMessage ?? 'Something went wrong',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            // The Calls SDK returns an embedded call view on every platform;
            // show "Connecting" until it arrives.
            return state.callingWidget ??
                Material(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Center(
                      child: Text(
                        Translations.of(context).connecting,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
