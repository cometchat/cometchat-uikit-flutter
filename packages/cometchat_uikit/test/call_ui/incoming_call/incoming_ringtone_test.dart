/// The incoming call's ringtone on a native player of its own, and the
/// message sounds held back while it rings (round 3: P3-C11, C12, C13, C14,
/// C16).
///
/// The ringtone used to loop on the message sounds' player, so a message
/// arriving while the phone rang replaced it for good. It now plays through
/// `playRingtone` / `stopRingtone`, which the native side rings as the
/// phone's own ringer does; what the native side does with these arguments
/// is checked on devices (scratchpad/plan/round3_device_checks.md). Here:
/// what the Dart side asks for, and when.
///
///   flutter test test/call_ui/incoming_call/incoming_ringtone_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/resources/sound_manager.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/incoming_ringtone.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// Lets the unawaited channel calls land.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    CallOperationsServiceLocator.instance.setup(
      dataSource: FakeCallOperationsDataSource(),
    );
    SoundChannelSpy.install();
    incomingRingtoneLoop.reset();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    incomingRingtoneLoop.reset();
    debugDefaultTargetPlatformOverride = null;
    IncomingRingtone.isWeb = kIsWeb;
    ActiveCallTracker.callScreenSessionId = null;
    CallStateService.instance.setActiveIncomingValue(false);
    await CallOperationsServiceLocator.instance.reset();
  });

  group('the banner rings on the ringtone player', () {
    test('P3-N01: a looping, vibrating ringtone, the kit\'s own asset from '
        'its package, on playRingtone, not the message player', () async {
      final DateTime start = DateTime(2026, 10, 1, 12);
      ActiveCallTracker.now = () => start;
      addTearDown(() => ActiveCallTracker.now = DateTime.now);
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();

      expect(SoundChannelSpy.methods, <String>['playRingtone']);
      expect(SoundChannelSpy.lastArgumentsOf('playRingtone'), <String, Object?>{
        'assetPath': 'assets/sound/incoming_call.wav',
        'package': 'cometchat_chat_uikit',
        'fallbackAssetPath': 'assets/sound/incoming_call.wav',
        'fallbackPackage': 'cometchat_chat_uikit',
        'looping': true,
        'vibrate': true,
        'callActive': false,
        // 60 s from the ring's start, by the wall clock (owner decision 1).
        'deadlineMs': start
            .add(const Duration(seconds: 60))
            .millisecondsSinceEpoch,
      });
    });

    test('P3-C11: on iOS too the asset is named with its package, so the '
        'native lookup finds it, and it loops', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();

      final Map<Object?, Object?>? args = SoundChannelSpy.lastArgumentsOf(
        'playRingtone',
      );
      expect(args?['package'], 'cometchat_chat_uikit');
      expect(args?['assetPath'], 'assets/sound/incoming_call.wav');
      expect(args?['looping'], isTrue);
      expect(args?['vibrate'], isTrue);
    });

    test('P3-N15 / P3-C14: a custom sound keeps its package, with the app\'s '
        'own asset and the kit\'s ringtone as fallbacks', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        customSoundForCalls: 'assets/custom_ring.wav',
        customSoundForCallsPackage: 'host_sounds',
      );
      addTearDown(bloc.close);
      await _settle();

      final Map<Object?, Object?>? args = SoundChannelSpy.lastArgumentsOf(
        'playRingtone',
      );
      expect(args?['assetPath'], 'assets/custom_ring.wav');
      expect(args?['package'], 'host_sounds');
      expect(args?['fallbackAssetPath'], 'assets/sound/incoming_call.wav');
      expect(args?['fallbackPackage'], 'cometchat_chat_uikit');
    });

    test('P3-N15: a custom sound with no package is the app\'s own asset, '
        'not looked for in the kit', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        customSoundForCalls: 'assets/custom_ring.wav',
      );
      addTearDown(bloc.close);
      await _settle();

      expect(SoundChannelSpy.lastArgumentsOf('playRingtone')?['package'], null);
    });

    test('P3-N16 / P3-C13: disableSoundForCalls sends nothing at all, so '
        'nothing rings and nothing vibrates', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      await _settle();
      await bloc.close();
      await _settle();

      expect(SoundChannelSpy.methods, isEmpty);
    });

    test('P3-E31: over a call screen (a group meeting) the native side is '
        'told a call is on, so it leaves the call\'s audio alone', () async {
      ActiveCallTracker.callScreenSessionId = 'meeting';
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();

      expect(
        SoundChannelSpy.lastArgumentsOf('playRingtone')?['callActive'],
        isTrue,
      );
    });

    // Round 3 review (native 3): a call the kit's overlay does not show (a
    // host's own CometChatOngoingCall, or its own startSession) was not
    // counted. On iOS the ringtone then switched the call's session to
    // soloAmbient, and a decline deactivated it.
    test('over a call session joined and not left (no kit call screen) the '
        'native side is told a call is on too', () async {
      ActiveCallTracker.mayHaveMediaSession = true;
      addTearDown(() => ActiveCallTracker.mayHaveMediaSession = false);
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();

      expect(
        SoundChannelSpy.lastArgumentsOf('playRingtone')?['callActive'],
        isTrue,
      );
    });

    test('with no call on, the native side is told so', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();

      expect(
        SoundChannelSpy.lastArgumentsOf('playRingtone')?['callActive'],
        isFalse,
      );
    });

    test('nothing reaches the channel on the web', () async {
      IncomingRingtone.isWeb = true;
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      await _settle();
      await bloc.close();
      await _settle();

      expect(SoundChannelSpy.methods, isEmpty);
    });
  });

  group('SoundManager', () {
    test('P3-C12: Sound.incomingCall rings on the ringtone player; message '
        'and outgoing sounds stay on the message player', () async {
      final SoundManager sounds = SoundManager();
      sounds.play(sound: Sound.incomingCall, isLooping: true);
      await _settle();
      expect(SoundChannelSpy.methods, <String>['playRingtone']);
      expect(SoundChannelSpy.lastArgumentsOf('playRingtone')?['looping'], true);
      sounds.stop();
      await _settle();
      SoundChannelSpy.methods.clear();

      sounds.play(sound: Sound.incomingMessage);
      sounds.play(sound: Sound.outgoingMessage);
      sounds.play(sound: Sound.outgoingCall, isLooping: true);
      await _settle();

      expect(SoundChannelSpy.methods, <String>[
        'playCustomSound',
        'playCustomSound',
        'playCustomSound',
      ]);
    });

    test('a host\'s own Sound.incomingCall keeps its sound and package, and '
        'loops only when asked to', () async {
      SoundManager().play(
        sound: Sound.incomingCall,
        customSound: 'assets/host.wav',
        packageName: 'host_app',
      );
      await _settle();

      final Map<Object?, Object?>? args = SoundChannelSpy.lastArgumentsOf(
        'playRingtone',
      );
      expect(args?['assetPath'], 'assets/host.wav');
      expect(args?['package'], 'host_app');
      expect(args?['looping'], isFalse);
      expect(args?['vibrate'], isTrue);
    });

    // Round 3 review (API 8, native 18): a host's one-shot ringtone
    // replaced the banner's looping one for good, and its end gave the
    // audio back while the call still rang.
    test('a host\'s one-shot Sound.incomingCall is skipped while the banner '
        'rings, as the other one-shot sounds are', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();
      SoundChannelSpy.methods.clear();

      SoundManager().play(sound: Sound.incomingCall);
      await _settle();

      expect(SoundChannelSpy.methods, isEmpty);
    });

    test('SoundManager.stop() stops the ringtone too, whoever started it, as '
        'it did when the ringtone shared the message player', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();
      SoundChannelSpy.methods.clear();

      SoundManager().stop();
      await _settle();

      expect(SoundChannelSpy.methods, contains('stopRingtone'));
      expect(SoundChannelSpy.methods, contains('stopCallTone'));
      expect(SoundChannelSpy.methods, contains('stopPlayer'));
      expect(IncomingRingtone.isRinging, isFalse);
    });
  });

  group('P3-C16 / P3-E39: no message sounds while an incoming call rings', () {
    for (final Sound sound in <Sound>[
      Sound.incomingMessage,
      Sound.incomingMessageFromOther,
      Sound.outgoingMessage,
    ]) {
      test(
        '$sound waits while the banner rings, and plays again after',
        () async {
          final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
          await _settle();
          SoundChannelSpy.methods.clear();

          SoundManager().play(sound: sound);
          await _settle();
          expect(SoundChannelSpy.methods, isEmpty);

          await bloc.close();
          await _settle();
          SoundChannelSpy.methods.clear();
          SoundManager().play(sound: sound);
          await _settle();
          expect(SoundChannelSpy.methods, <String>['playCustomSound']);
        },
      );
    }

    // Round 3 review (G1): `isLooping` is nullable; only an explicit
    // `true` counts as looping.
    test('a sound played with isLooping: null counts as one-shot: skipped '
        'while the banner rings', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();
      SoundChannelSpy.methods.clear();

      SoundManager().play(sound: Sound.incomingMessage, isLooping: null);
      await _settle();

      expect(SoundChannelSpy.methods, isEmpty);
    });

    test('a banner replaced by the next call does not let message sounds '
        'back in when it closes: the next one still rings', () async {
      final IncomingCallBloc first = IncomingCallBloc(call: buildCall());
      await _settle();
      final IncomingCallBloc second = IncomingCallBloc(
        call: buildCall(sessionId: 'session_2'),
      );
      addTearDown(second.close);
      await _settle();

      await first.close();
      await _settle();
      SoundChannelSpy.methods.clear();
      SoundManager().play(sound: Sound.incomingMessage);
      await _settle();

      expect(SoundChannelSpy.methods, isEmpty);
      expect(CallStateService.instance.isActiveIncomingCall.value, isFalse);
    });

    test('a looping sound still plays while the banner rings', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await _settle();
      SoundChannelSpy.methods.clear();

      SoundManager().play(sound: Sound.outgoingCall, isLooping: true);
      await _settle();

      expect(SoundChannelSpy.methods, <String>['playCustomSound']);
    });

    test('a host\'s own looping incoming-call sound holds them back too, '
        'until SoundManager.stop()', () async {
      SoundManager().play(sound: Sound.incomingCall, isLooping: true);
      await _settle();
      SoundChannelSpy.methods.clear();

      SoundManager().play(sound: Sound.incomingMessage);
      await _settle();
      expect(SoundChannelSpy.methods, isEmpty);

      SoundManager().stop();
      await _settle();
      SoundChannelSpy.methods.clear();
      SoundManager().play(sound: Sound.incomingMessage);
      await _settle();
      expect(SoundChannelSpy.methods, <String>['playCustomSound']);
    });

    test('a banner with its sound turned off holds nothing back: nothing '
        'rings', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      await _settle();

      SoundManager().play(sound: Sound.incomingMessage);
      await _settle();

      expect(SoundChannelSpy.methods, <String>['playCustomSound']);
    });
  });
}
