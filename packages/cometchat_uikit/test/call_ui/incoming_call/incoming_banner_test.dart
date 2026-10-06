/// The incoming call banner itself (round 3: P3-C19, P3-C20 and the review's
/// screen-reader item).
///
/// * P3-C19: the banner sits below the status bar, the notch or the Dynamic
///   Island; a fixed 40 put it over the island and the clock.
/// * P3-C20: a video call shows a video camera in the subtitle, as Android
///   does; it showed a phone for every call.
/// * a11y: TalkBack and VoiceOver hear the banner as it appears (a live
///   region on Android, an announcement on iOS); nothing read it out before.
///
///   flutter test test/call_ui/incoming_call/incoming_banner_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

final User _caller = User(uid: 'priya', name: 'Priya Raman');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    debugDefaultTargetPlatformOverride = null;
  });

  /// Shows the banner for a call of [type] over an app whose screen has
  /// [topInset] at the top (the status bar, notch or Dynamic Island).
  Future<void> showBanner(
    WidgetTester tester, {
    String type = CallTypeConstants.audioCall,
    double topInset = 0,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
        child: MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: buildCall(type: type),
      user: _caller,
      disableSoundForCalls: true,
    );
    await tester.pump();
  }

  /// Takes the banner down in the body: its ring timer must not outlive the
  /// test.
  Future<void> dismiss(WidgetTester tester) async {
    IncomingCallOverlay.dismiss();
    await tester.pump();
  }

  group('P3-C19 / P3-E40: the banner sits below the top inset', () {
    for (final double inset in <double>[59, 24, 0]) {
      testWidgets('a $inset pt top inset: the card starts 8 pt below it', (
        WidgetTester tester,
      ) async {
        await showBanner(tester, topInset: inset);

        final double top = tester
            .getTopLeft(find.byType(CometChatIncomingCall))
            .dy;
        expect(top, inset + 8);
        await dismiss(tester);
      });
    }
  });

  group('P3-C20 / P3-N02: the subtitle\'s icon follows the call', () {
    testWidgets('a video call shows a video camera', (
      WidgetTester tester,
    ) async {
      await showBanner(tester, type: CallTypeConstants.videoCall);

      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(find.byIcon(Icons.call), findsNothing);
      expect(find.text('Incoming video call'), findsOneWidget);
      await dismiss(tester);
    });

    testWidgets('a voice call shows a phone', (WidgetTester tester) async {
      await showBanner(tester);

      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsNothing);
      await dismiss(tester);
    });

    testWidgets('a host\'s callIcon still wins', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          home: Scaffold(
            body: CometChatIncomingCall(
              call: buildCall(type: CallTypeConstants.videoCall),
              user: _caller,
              disableSoundForCalls: true,
              callIcon: const Icon(Icons.star),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P3-N01 a11y: screen readers hear the banner', () {
    testWidgets('TalkBack: the banner is a live region labelled with the '
        'caller and the kind of call', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await showBanner(tester, type: CallTypeConstants.videoCall);

      final Finder banner = find.bySemanticsLabel(
        'Priya Raman, Incoming video call',
      );
      expect(banner, findsOneWidget);
      expect(tester.getSemantics(banner).flagsCollection.isLiveRegion, isTrue);
      await dismiss(tester);
      semantics.dispose();
    });

    testWidgets('VoiceOver: the banner is announced as it appears', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await showBanner(tester);
      await tester.pump();

      final List<String> said = tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList();
      expect(said, <String>['Priya Raman, Incoming audio call']);
      await dismiss(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android leaves it to the live region (its announcements are '
        'deprecated)', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await showBanner(tester);
      await tester.pump();

      expect(tester.takeAnnouncements(), isEmpty);
      await dismiss(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // Round 3 review (correctness 12): a banner replaced by another is
  // closed after the new one set the flag, and cleared it while the new
  // call rang.
  group('CallStateService.isActiveIncomingCall', () {
    testWidgets('stays true when a banner is replaced by another call\'s, '
        'and goes false once the last one is dismissed', (
      WidgetTester tester,
    ) async {
      await showBanner(tester);
      expect(CallStateService.instance.isActiveIncomingCall.value, isTrue);

      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: buildCall(sessionId: 'next'),
        user: _caller,
        disableSoundForCalls: true,
      );
      await tester.pump();
      expect(ActiveCallTracker.incomingCallSessionId, 'next');
      expect(CallStateService.instance.isActiveIncomingCall.value, isTrue);

      await dismiss(tester);
      expect(CallStateService.instance.isActiveIncomingCall.value, isFalse);
    });
  });

  // Round 3 review (C9b): the check after the navigator poll compares the
  // call, not just that some call rings. X arrives with no navigator yet,
  // is cancelled while it waits, and Y rings meanwhile: X's wait must not
  // end in a banner for X.
  testWidgets('P3-C09: a call cancelled while it waited for the navigator '
      'gets no banner, even with another call ringing by then', (
    WidgetTester tester,
  ) async {
    final CallEventService service = CallEventService.instance;
    await tester.pumpWidget(const SizedBox.shrink());
    service.onIncomingCallReceived(buildCall(sessionId: 'X'));
    await tester.pump(const Duration(milliseconds: 20));
    service.onIncomingCallCancelled(buildCall(sessionId: 'X'));
    expect(ActiveCallTracker.ringingCall, isNull);
    await tester.pump(const Duration(milliseconds: 30));
    service.onIncomingCallReceived(buildCall(sessionId: 'Y'));
    expect(ActiveCallTracker.ringingCall?.sessionId, 'Y');
    await tester.pump(const Duration(milliseconds: 10));

    // The navigator comes up between the two calls' next polls: X's (at
    // 100 ms) comes first.
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 45));
    expect(ActiveCallTracker.incomingCallSessionId, isNot('X'));
    expect(find.byType(CometChatIncomingCall), findsNothing);

    // Y's poll shows Y.
    await tester.pump(const Duration(milliseconds: 60));
    expect(ActiveCallTracker.incomingCallSessionId, 'Y');
    await tester.pump(const Duration(milliseconds: 400));
    await dismiss(tester);
  });
}
