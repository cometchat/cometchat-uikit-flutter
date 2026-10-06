import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/utils/call_error_snackbar.dart';

/// master_app shows the UI Kit's call errors as SnackBars, but not the
/// end-of-call noise: a cancel, decline or end that failed because the call
/// was already over (the SDK's own codes, reported by the call screens).
void main() {
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      home: const Scaffold(body: SizedBox()),
    ),
  );

  CometChatException error(String code, {String? details}) =>
      CometChatException(code, details, 'message');

  testWidgets('a placement error is shown, whatever its code', (tester) async {
    await pumpApp(tester);

    showCallPlacementError(error('ERR_UID_NOT_FOUND'));
    await tester.pump();

    expect(find.text("Couldn't place the call (ERR_UID_NOT_FOUND)"), findsOne);
  });

  testWidgets('ACTIVE_CALL from the call buttons is explained', (tester) async {
    await pumpApp(tester);

    showCallPlacementError(error('ACTIVE_CALL'));
    await tester.pump();

    expect(find.text("You're already on a call."), findsOne);
  });

  testWidgets('a permanent permission refusal offers the Settings page', (
    tester,
  ) async {
    await pumpApp(tester);

    showCallPlacementError(
      error('PERMISSION_PERMANENTLY_DENIED', details: 'microphone,camera'),
    );
    await tester.pump();

    expect(
      find.text('Allow microphone and camera access to make and answer calls.'),
      findsOne,
    );
    expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOne);
  });

  testWidgets('a plain refusal has no Settings action', (tester) async {
    await pumpApp(tester);

    showInCallError(error('PERMISSION_DENIED', details: 'microphone'));
    await tester.pump();

    expect(
      find.text('Allow microphone access to make and answer calls.'),
      findsOne,
    );
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('in a call, the UI Kit codes are shown', (tester) async {
    await pumpApp(tester);

    showInCallError(error('JOIN_TIMEOUT'));
    await tester.pump();

    expect(
      find.text("Couldn't join the call. Check your connection and try again."),
      findsOne,
    );
  });

  testWidgets('in a call, the SDK failing a cancel or end after the call is '
      'over is not shown', (tester) async {
    await pumpApp(tester);

    showInCallError(error('ERR_CALL_ENDED'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  // Round 2: the UI Kit reports every failure to onError with the SDK's
  // code (owner: the Android rule). These are the ones that mean nothing to
  // the user; master_app shows none of them.
  group('races nobody can act on are not shown (round 2)', () {
    for (final (String race, String code) in <(String, String)>[
      ("End racing the callee's decline (P2-E05)", 'ERR_CALL_REJECTED'),
      ("End racing the callee's accept (P2-E04)", 'ERR_CALL_ACCEPTED'),
      ("the 45 s no-answer timeout racing an accept", 'ERR_CALL_ACCEPTED'),
      ("the 45 s no-answer timeout racing a decline", 'ERR_CALL_REJECTED'),
      ('both people hanging up at once (P2-E95)', 'ERR_CALL_ENDED'),
      ('a cancel that failed after the screen closed (P2-E35)', 'ERR'),
    ]) {
      testWidgets(race, (tester) async {
        await pumpApp(tester);

        showInCallError(error(code));
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      });
    }
  });

  // Round 3: an incoming call's accept or decline that fails because the
  // call was already over (the caller cancelled while the permission prompt
  // was up, or the same user answered on another device) reaches onError
  // with the SDK's code. Nothing the user can act on.
  group('incoming call races are not shown (round 3)', () {
    for (final (String race, String code) in <(String, String)>[
      (
        'an accept landing after the caller cancelled (P3-E05)',
        'ERR_CALL_TERMINATED',
      ),
      (
        'a decline crossing the caller\'s cancel (P3-E04)',
        'ERR_CALL_TERMINATED',
      ),
      (
        'an accept after the call was answered elsewhere (P3-E32)',
        'ERR_CALL_ACCEPTED',
      ),
      ('a host hook that threw (logged only)', 'HOST_CALLBACK_ERROR'),
    ]) {
      testWidgets(race, (tester) async {
        await pumpApp(tester);

        showInCallError(error(code));
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets(
      'an incoming call answered without the microphone says how '
      'to fix it, with Settings when the system will not ask again (P3-E23)',
      (tester) async {
        await pumpApp(tester);

        showInCallError(
          error('PERMISSION_PERMANENTLY_DENIED', details: 'microphone'),
        );
        await tester.pump();

        expect(
          find.text('Allow microphone access to make and answer calls.'),
          findsOne,
        );
        expect(find.text('Settings'), findsOne);
      },
    );
  });

  group('calling back a blocked user from the call logs (round 2)', () {
    testWidgets('BLOCKED_BY_ME says so', (tester) async {
      await pumpApp(tester);

      showCallPlacementError(error('BLOCKED_BY_ME'));
      await tester.pump();

      expect(
        find.text("You've blocked this user. Unblock them to call."),
        findsOne,
      );
    });

    testWidgets('HAS_BLOCKED_ME does not say who blocked whom', (tester) async {
      await pumpApp(tester);

      showCallPlacementError(error('HAS_BLOCKED_ME'));
      await tester.pump();

      expect(find.text("This user can't be called."), findsOne);
    });
  });

  group('the call buttons (round 1b review)', () {
    // They also hear from a group meeting's call screen, which used to show
    // a failed leave as "Couldn't place the call".
    final original = isCallScreenUp;
    tearDown(() => isCallScreenUp = original);

    testWidgets('with a call screen up, only the UI Kit codes are shown', (
      tester,
    ) async {
      await pumpApp(tester);
      isCallScreenUp = () => true;

      showCallButtonsError(error('ERR_LEAVE_SESSION'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);

      showCallButtonsError(error('JOIN_TIMEOUT'));
      await tester.pump();
      expect(
        find.text(
          "Couldn't join the call. Check your connection and try again.",
        ),
        findsOne,
      );
    });

    testWidgets('with no call screen up, a failure to place is shown', (
      tester,
    ) async {
      await pumpApp(tester);
      isCallScreenUp = () => false;

      showCallButtonsError(error('ERR_UID_NOT_FOUND'));
      await tester.pump();

      expect(
        find.text("Couldn't place the call (ERR_UID_NOT_FOUND)"),
        findsOne,
      );
    });
  });

  group('after NO_NAVIGATOR (round 1b review)', () {
    testWidgets('the failed cancel of that call does not replace it', (
      tester,
    ) async {
      await pumpApp(tester);

      showCallPlacementError(error('NO_NAVIGATOR'));
      await tester.pump();
      showCallPlacementError(error('ERR_CALL_ENDED'));
      await tester.pump();

      expect(find.text("Couldn't show the call screen."), findsOne);
      expect(
        find.text("Couldn't place the call (ERR_CALL_ENDED)"),
        findsNothing,
      );
    });

    testWidgets('once it has gone, the SDK errors show again', (tester) async {
      await pumpApp(tester);

      showCallPlacementError(error('NO_NAVIGATOR'));
      // In, its 4 s on screen, and out.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      showCallPlacementError(error('ERR_UID_NOT_FOUND'));
      await tester.pump();

      expect(
        find.text("Couldn't place the call (ERR_UID_NOT_FOUND)"),
        findsOne,
      );
    });
  });

  test('a call-log load error is left to the call logs screen', () {
    expect(isCallLogsPlacementError(error('CALL_LOGS_ERROR')), isFalse);
    expect(isCallLogsPlacementError(error('NO_NAVIGATOR')), isTrue);
  });
}
