/// The incoming ringtone is given up on every way out of an accept that
/// opens no call screen, and by the calls' teardown (round 3 review:
/// PROBE-5).
///
/// Before: an accept that returned early (a logout during the permission
/// prompt, a call given up meanwhile, no session) left the ringtone paused
/// but still owned by its bloc, and a logout never reset it. While owned,
/// `SoundManager.play` drops every message sound, so they stayed silent
/// after the logout, until the next incoming call; and a host's own bloc,
/// which the banner's dismiss does not close, rang on after the logout.
///
///   flutter test test/call_ui/incoming_call/incoming_ringtone_ownership_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/resources/sound_manager.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/incoming_ringtone.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallEventService.instance.activeCall = null;
    CallStateService.instance.setActiveIncomingValue(false);
    await CallOperationsServiceLocator.instance.reset();
  });

  /// Whether a message sound reaches the native player now.
  Future<bool> messageSoundPlays() async {
    SoundChannelSpy.methods.clear();
    SoundManager().play(sound: Sound.incomingMessage);
    await pumpEventQueue();
    return SoundChannelSpy.methods.contains('playCustomSound');
  }

  test('PROBE-5: a logout during the permission prompt leaves no ringtone '
      'owned: message sounds play again', () async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
    addTearDown(bloc.close);
    await pumpEventQueue();
    bloc.add(const AcceptCall());
    await pumpEventQueue();
    expect(IncomingRingtone.isRinging, isTrue, reason: 'paused, still owned');

    CallsLifecycle.tearDownLocalCalls();
    prompt.complete();
    await pumpEventQueue();

    expect(IncomingRingtone.isRinging, isFalse);
    expect(await messageSoundPlays(), isTrue);
    expect(dataSource.acceptCallCount, 0);
  });

  test('the teardown stops a host\'s own bloc ringing: the banner\'s '
      'dismiss does not close it', () async {
    final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
    addTearDown(bloc.close);
    await pumpEventQueue();
    expect(IncomingRingtone.isRinging, isTrue);
    SoundChannelSpy.methods.clear();

    CallsLifecycle.tearDownLocalCalls();
    await pumpEventQueue();

    expect(IncomingRingtone.isRinging, isFalse);
    expect(SoundChannelSpy.methods, contains('stopRingtone'));
    expect(await messageSoundPlays(), isTrue);
  });

  test('a teardown with nothing ringing sends nothing to the ringtone '
      'player', () async {
    CallsLifecycle.tearDownLocalCalls();
    await pumpEventQueue();

    expect(SoundChannelSpy.methods, isNot(contains('stopRingtone')));
  });

  test('a logout that starts during the permission prompt: the accept gives '
      'the ringtone up as soon as the prompt answers, before the logout\'s '
      'own teardown, and the bloc reads cancelled', () async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    // Something the logout declines first, and waits for.
    final Completer<void> server = Completer<void>();
    dataSource.rejectGate = server;
    ActiveCallTracker.ringingCall = buildCall(sessionId: 'other');
    final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
    addTearDown(bloc.close);
    await pumpEventQueue();
    bloc.add(const AcceptCall());
    await pumpEventQueue();

    final Future<void> logout = CallsLifecycle.prepareForLogout();
    await pumpEventQueue();
    prompt.complete();
    await pumpEventQueue();

    expect(IncomingRingtone.isRinging, isFalse);
    expect(bloc.state.status, IncomingCallStatus.cancelled);
    expect(dataSource.acceptCallCount, 0);
    server.complete();
    await logout;
  });

  test('an accept of a call with no session gives the ringtone up', () async {
    final IncomingCallBloc bloc = IncomingCallBloc(call: NullSessionCall());
    addTearDown(bloc.close);
    await pumpEventQueue();

    bloc.add(const AcceptCall());
    await pumpEventQueue();

    expect(bloc.state.status, IncomingCallStatus.error);
    expect(IncomingRingtone.isRinging, isFalse);
  });

  // Round 3 review (AH3, AH4): a bloc that no longer owns the ringtone (a
  // banner replaced by the next call's) must not pause or hand over the
  // ringtone the next call rings.
  group('only the owner pauses or hands over the ringtone', () {
    final Object first = Object();
    final Object next = Object();

    setUp(() async {
      await IncomingRingtone.play(owner: first);
      await IncomingRingtone.play(owner: next);
      SoundChannelSpy.methods.clear();
    });

    test('a pause from the earlier owner stops nothing', () async {
      await IncomingRingtone.pause(owner: first);

      expect(SoundChannelSpy.methods, isEmpty);
      expect(IncomingRingtone.isRinging, isTrue);
    });

    test('a hand-over from the earlier owner stops nothing and leaves the '
        'ringtone the next call\'s', () async {
      await IncomingRingtone.handOver(owner: first);

      expect(SoundChannelSpy.methods, isEmpty);
      expect(incomingRingtoneLoop.owns(next), isTrue);
    });

    test('the owner\'s pause and hand-over do reach the player', () async {
      await IncomingRingtone.pause(owner: next);
      await IncomingRingtone.handOver(owner: next);

      expect(SoundChannelSpy.methods, <String>['stopRingtone', 'stopRingtone']);
      expect(IncomingRingtone.isRinging, isFalse);
    });
  });
}
