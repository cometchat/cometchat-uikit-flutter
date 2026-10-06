import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sample_app/main.dart';
import 'package:sample_app/app_credentials.dart';

import '../config/test_credentials.dart';
import 'pump_helper.dart';

/// Launches the full sample app and handles login for E2E tests.
///
/// This launches the real BlocSampleApp, waits for CometChat SDK initialization,
/// and performs login through the UI as User A.
///
/// After [launchAndLogin] returns, the app is on the HomeScreen with a fully
/// authenticated User A session, ready for test interactions.
class AppLauncher {
  AppLauncher._();

  /// Launch the app, initialize CometChat, and login as User A.
  ///
  /// After this returns:
  ///   - CometChat SDK is initialized
  ///   - User A is logged in
  ///   - HomeScreen is showing (Chats tab)
  ///   - WebSocket connection is active (events will flow)
  static Future<void> launchAndLogin(WidgetTester tester) async {
    // Clear iOS Keychain (flutter_secure_storage) to wipe stale auth tokens
    // from previous test runs. On iOS the Keychain persists across runs.
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    await _applyCredentials();

    // Launch the real app
    await tester.pumpWidget(const BlocSampleApp());

    // Wait for SDK init (CircularProgressIndicator → login/home)
    await pumpFor(tester, const Duration(seconds: 8));

    // Check if already on HomeScreen (cached session)
    if (find.text('Chats').evaluate().isNotEmpty) {
      return;
    }

    // On LoginScreen — perform login
    await _performLogin(tester);
  }

  /// Launch app without login (for testing login flow itself).
  ///
  /// &quot;Without login&quot; has to be made true, not assumed. Wiping
  /// FlutterSecureStorage clears the iOS Keychain, but the SDK keeps its own
  /// session store, so on Android a preceding case that logged in leaves this
  /// one launching straight into the home screen. Measured on an A015: with
  /// the credentials unblocked, E2E-001 logs in and E2E-002 then never sees a
  /// login form. An explicit logout is what makes the name accurate.
  static Future<void> launchOnly(WidgetTester tester) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    await _applyCredentials();

    // Best-effort: there may be no session to end, and a failure here must
    // not mask the assertion the caller is about to make.
    try {
      await CometChatUIKit.logout();
    } catch (_) {
      // No active session, or the SDK was never initialised.
    }

    await tester.pumpWidget(const BlocSampleApp());
    await pumpFor(tester, const Duration(seconds: 8));
  }


  /// True when a real `--dart-define` was supplied for the app under test.
  ///
  /// [TestCredentials] falls back to `YOUR_APP_ID` / `YOUR_REGION` /
  /// `YOUR_AUTH_KEY` placeholders, and those are not inert: writing them into
  /// SharedPreferences overwrites whatever credentials the sample app ships
  /// with, so the SDK dies at startup with ERR_INVALID_REGION and every suite
  /// fails before it reaches the screen it is testing. Measured on an iPhone
  /// 17 Pro simulator and on an Android A015: 19 of 19 cases stopped there.
  static bool get _hasSuppliedCredentials =>
      !TestCredentials.appId.startsWith('YOUR_') &&
      !TestCredentials.region.startsWith('YOUR_') &&
      !TestCredentials.authKey.startsWith('YOUR_');

  /// Point the app at the E2E credentials when they were supplied, and get
  /// out of the way when they were not.
  ///
  /// The keys are *removed* rather than left alone in the second case, so a
  /// device polluted by an earlier placeholder run recovers on the next one —
  /// `AppCredentials.loadSavedCredentials` then falls back to the app's own
  /// defaults instead of reading `YOUR_APP_ID` back out of prefs.
  static Future<void> _applyCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_hasSuppliedCredentials) {
      await prefs.setString('cc_app_id', TestCredentials.appId);
      await prefs.setString('cc_region', TestCredentials.region);
      await prefs.setString('cc_auth_key', TestCredentials.authKey);
    } else {
      await prefs.remove('cc_app_id');
      await prefs.remove('cc_region');
      await prefs.remove('cc_auth_key');
    }
    await AppCredentials.loadSavedCredentials();
  }

  static Future<void> _performLogin(WidgetTester tester) async {
    // Find the UID field
    final uidField = find.widgetWithText(TextFormField, 'Enter the UID');
    if (uidField.evaluate().isNotEmpty) {
      await tester.enterText(uidField, TestCredentials.userAUid);
    } else {
      // Fallback: first TextFormField on screen
      final fields = find.byType(TextFormField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, TestCredentials.userAUid);
      }
    }

    await tester.pump(const Duration(milliseconds: 300));

    // Dismiss keyboard / unfocus text field so the FocusTrap overlay is
    // removed. If it stays, Flutter's overlay AbsorbPointer blocks the tap.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Continue. After unfocusing, the overlay FocusTrap is gone so the
    // tap should land on the button normally.
    final continueBtn = find.text('Continue');
    if (continueBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(continueBtn.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(continueBtn.first, warnIfMissed: false);
    }

    // Wait for login + HomeScreen
    final found = await pumpUntilFound(
      tester,
      find.text('Chats'),
      timeout: const Duration(seconds: 15),
    );

    if (!found) {
      // May still be loading — pump more
      await pumpFor(tester, const Duration(seconds: 5));
    }
  }
}
