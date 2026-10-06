import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../call_ui/src/call_operations/di/call_operations_service_locator.dart';
import '../call_ui/src/call_settings/call_navigation_context.dart';
import '../call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import '../call_ui/src/outgoing_call/cometchat_outgoing_call_configuration.dart';
import '../cometchat_calls_uikit.dart' show Call, SessionSettingsBuilder, User;
import '../shared_ui/src/constants/ui_kit_constants.dart'
    show
        CallStatusConstants,
        MessageCategoryConstants,
        OnError,
        ReceiverTypeConstants;
import '../shared_ui/src/events/call_events/cometchat_call_events.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'call_errors.dart';
import 'calls_lifecycle.dart';

/// The one place the UI Kit opens the outgoing call screen for a call this
/// device has just placed: the call buttons, the call logs' call-back, and
/// what a host builds on them. Android has one too,
/// `CometChatCallActivity.launchOutgoingCallScreen`.
///
/// Package-private (see `lib/src/`).
///
/// There used to be two push sites, each with its own configuration and
/// title. The call buttons waited 300 ms before pushing and, with no
/// navigator by then, returned without a word; the call logs titled the
/// screen with the callee's UID.
abstract final class OutgoingCallLauncher {
  /// How long [show] waits for the next frame before it pushes anyway: an
  /// app in the background draws none.
  @visibleForTesting
  static Duration frameWaitLimit = const Duration(milliseconds: 300);

  /// Shows the outgoing call screen for [call], which this device has just
  /// placed, and completes with whether it is up.
  ///
  /// Announces the call (`ccOutgoingCall`, which records it as this
  /// device's active call), takes the keyboard down, and on the next frame
  /// pushes [CometChatOutgoingCall] on `CallNavigationContext.navigatorKey`,
  /// dressed with the whole of [configuration].
  ///
  /// Only there: the call screen that follows an accept is shown in that
  /// navigator's overlay too, so a call shown anywhere else could ring and
  /// never be joined (the caller got NO_NAVIGATOR once the callee
  /// answered).
  ///
  /// The title is [user], else the call's receiver as the server sent it.
  ///
  /// [epoch] is `CallsLifecycle.callEpoch` from before the call was placed.
  /// Calls torn down since (a logout) have dealt with this one: nothing is
  /// shown and its record is released.
  ///
  /// With no navigator at all the call cannot be shown and nothing would
  /// ever end it: its record is released, it is cancelled on the server
  /// (`cancelled`, a failure of which reaches [onError] with the SDK's
  /// code), and [onError] gets `NO_NAVIGATOR`.
  static Future<bool> show(
    Call call, {
    required int epoch,
    User? user,
    CometChatOutgoingCallConfiguration? configuration,
    SessionSettingsBuilder? sessionSettingsBuilder,
    OnError? onError,
  }) async {
    // The no-answer timeout counts from here, not from the screen's first
    // build, which an app in the background puts off.
    ActiveCallTracker.markPlaced(call);
    call.category = MessageCategoryConstants.call;
    CometChatCallEvents.ccOutgoingCall(call);
    FocusManager.instance.primaryFocus?.unfocus();

    await _nextFrame();

    if (epoch != CallsLifecycle.callEpoch) {
      // Torn down in the meantime: the call was the active one by then, so
      // the teardown saw to it. No screen over the login screen.
      ccLog(
        'OutgoingCallLauncher: calls were torn down; not showing '
        '${call.sessionId}',
      );
      ActiveCallTracker.releaseCall(call);
      return false;
    }

    final navigator = _appNavigator();
    if (navigator == null) {
      _abandon(call, onError);
      return false;
    }
    try {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => _screen(
              call,
              title: user ?? _receiverOf(call),
              configuration: configuration,
              sessionSettingsBuilder: sessionSettingsBuilder,
            ),
          ),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      ccLog('OutgoingCallLauncher: pushing the screen failed: $e\n$stackTrace');
      _abandon(call, onError);
      return false;
    }
  }

  /// The next frame, or [frameWaitLimit] when none comes.
  static Future<void> _nextFrame() {
    final done = Completer<void>();
    final limit = Timer(frameWaitLimit, () {
      if (!done.isCompleted) done.complete();
    });
    SchedulerBinding.instance.endOfFrame.then((_) {
      limit.cancel();
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  static NavigatorState? _appNavigator() {
    final app = CallNavigationContext.navigatorKey.currentState;
    return app != null && app.mounted ? app : null;
  }

  /// The callee as the server sent it back, for a call to a user.
  static User? _receiverOf(Call call) {
    if (call.receiverType != ReceiverTypeConstants.user) return null;
    final callReceiver = call.callReceiver;
    if (callReceiver is User) return callReceiver;
    final receiver = call.receiver;
    return receiver is User ? receiver : null;
  }

  static CometChatOutgoingCall _screen(
    Call call, {
    required User? title,
    required CometChatOutgoingCallConfiguration? configuration,
    required SessionSettingsBuilder? sessionSettingsBuilder,
  }) => CometChatOutgoingCall(
    call: call,
    user: title,
    subtitleView: configuration?.subtitleView,
    declineButtonIcon: configuration?.declineButtonIcon,
    onCancelled: configuration?.onCancelled,
    disableSoundForCalls: configuration?.disableSoundForCalls,
    customSoundForCalls: configuration?.customSoundForCalls,
    customSoundForCallsPackage: configuration?.customSoundForCallsPackage,
    onError: configuration?.onError,
    outgoingCallStyle: configuration?.outgoingCallStyle,
    sessionSettingsBuilder:
        sessionSettingsBuilder ?? configuration?.sessionSettingsBuilder,
    height: configuration?.height,
    width: configuration?.width,
    avatarView: configuration?.avatarView,
    titleView: configuration?.titleView,
    cancelledView: configuration?.cancelledView,
  );

  /// [call] was placed, but there is no navigator to show it on. Nothing
  /// would ever cancel it, so the callee would ring with nobody on the other
  /// end and its record would leave this device "in a call". It is released
  /// and cancelled on the server (owner decision), and [onError] hears
  /// NO_NAVIGATOR, before any failure of that cancel.
  static void _abandon(Call call, OnError? onError) {
    final sessionId = call.sessionId;
    ccLog(
      'OutgoingCallLauncher: no navigator for the outgoing call screen of '
      '$sessionId; cancelling it. Set CallNavigationContext.navigatorKey.',
    );
    ActiveCallTracker.releaseCall(call);
    reportCallError(
      onError,
      noNavigatorException('outgoing call screen'),
      where: 'OutgoingCallLauncher',
    );
    if (sessionId == null || sessionId.isEmpty) return;
    unawaited(_cancel(sessionId, onError));
  }

  static Future<void> _cancel(String sessionId, OnError? onError) async {
    try {
      final result = await CallOperationsServiceLocator
          .instance
          .rejectCallUseCase
          .call(sessionId, CallStatusConstants.cancelled);
      result.fold(
        (failure) {
          ccLog(
            'OutgoingCallLauncher: cancel of $sessionId failed: '
            '${failure.message}',
          );
          reportCallError(
            onError,
            callFailureException(failure),
            where: 'OutgoingCallLauncher',
          );
        },
        (cancelledCall) {
          cancelledCall.category = MessageCategoryConstants.call;
          CometChatCallEvents.ccCallRejected(cancelledCall);
        },
      );
    } catch (e) {
      ccLog('OutgoingCallLauncher: cancel of $sessionId failed: $e');
    }
  }
}
