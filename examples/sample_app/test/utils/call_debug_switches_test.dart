import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/utils/call_debug_switches.dart';

/// The incoming call switches for the round-3 device checks (P3-N15, P3-N16,
/// P3-N17), set with --dart-define. Off by default.
void main() {
  void onError(Exception _) {}

  test(
    'by default: the UI Kit\'s ringtone, no hooks, master_app\'s onError',
    () {
      final config = CallDebugSwitches.incomingCallConfiguration(
        onError: onError,
      );

      expect(CallDebugSwitches.ringtone, 'default');
      expect(CallDebugSwitches.callHooks, isFalse);
      expect(config.onError, same(onError));
      expect(config.customSoundForCalls, isNull);
      expect(config.disableSoundForCalls, isNull);
      expect(config.onAccept, isNull);
      expect(config.onDecline, isNull);
    },
  );

  test('CC_RINGTONE=custom: master_app\'s own ringtone, from its assets', () {
    final config = CallDebugSwitches.incomingCallConfiguration(
      onError: onError,
      ringtoneSwitch: 'custom',
    );

    expect(config.customSoundForCalls, 'assets/custom_ring.wav');
    expect(config.customSoundForCallsPackage, isNull);
    expect(config.disableSoundForCalls, isNull);
  });

  test('CC_RINGTONE=off: no ringtone (and so no vibration)', () {
    final config = CallDebugSwitches.incomingCallConfiguration(
      onError: onError,
      ringtoneSwitch: 'off',
    );

    expect(config.disableSoundForCalls, isTrue);
    expect(config.customSoundForCalls, isNull);
  });

  testWidgets('CC_CALL_HOOKS=1: each hook says it fired', (tester) async {
    final config = CallDebugSwitches.incomingCallConfiguration(
      onError: onError,
      hooks: true,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(SizedBox));
    final call = Call(
      sessionId: 's1',
      receiverUid: 'me',
      type: CallTypeConstants.audioCall,
      receiverType: ReceiverTypeConstants.user,
    );

    config.onAccept!(context, call);
    await tester.pump();
    expect(find.text('onAccept hook fired'), findsOne);

    config.onDecline!(context, call);
    await tester.pump();
    expect(find.text('onDecline hook fired'), findsOne);
  });

  test('the custom ringtone is a real asset of the app', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(CallDebugSwitches.customRingtone);
    expect(data.lengthInBytes, greaterThan(1000));
  });
}
