/// CallScreenOverlay.show and IncomingCallOverlay.show with no navigator
/// keep nothing (round 1b: P1-C06, P1-C07(d), P4-C21, P5-C19).
///
/// Both used to keep the entry they built even when there was no overlay to
/// insert it into. CallScreenOverlay then reported isShowing and a 1-on-1
/// call on screen, so every later call was refused with ACTIVE_CALL and
/// every incoming one answered busy; and the next show() or dismiss() of
/// either threw on removing an entry that was never inserted.
///
///   flutter test test/call_ui/ongoing_call/call_screen_overlay_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late List<Exception> errors;
  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    errors = <Exception>[];
    // A key attached to nothing: no navigator, no overlay.
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    IncomingCallOverlay.dismiss();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    removeCallJoinDefaults();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  group('CallScreenOverlay.show with no navigator', () {
    test('keeps nothing, frees the device and reports NO_NAVIGATOR once', () {
      service.activeCall = buildCall();

      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
        callWorkFlow: CallWorkFlow.defaultCalling,
        onError: errors.add,
      );

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(ActiveCallTracker.callScreenSessionId, isNull);
      expect(ActiveCallTracker.callScreenWorkFlow, isNull);
      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.hasActiveCall, isFalse);
      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'NO_NAVIGATOR');
    });

    test("releases only that call's record", () {
      service.activeCall = buildCall(sessionId: 'other');

      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );

      expect((service.activeCall as Call?)?.sessionId, 'other');
    });

    test('a later show() or dismiss() does not throw', () {
      for (var i = 0; i < 2; i++) {
        expect(
          () => CallScreenOverlay.show(
            sessionId: 'session_1',
            sessionSettingsBuilder: SessionSettingsBuilder(),
          ),
          returnsNormally,
        );
      }
      expect(CallScreenOverlay.dismiss, returnsNormally);
      expect(CallScreenOverlay.dismiss, returnsNormally);
    });
  });

  testWidgets('CallScreenOverlay.show with a navigator shows the call as '
      'before', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        home: const Scaffold(body: Text('messages')),
      ),
    );
    service.activeCall = buildCall();

    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      onError: errors.add,
    );

    expect(CallScreenOverlay.isShowing, isTrue);
    expect(ActiveCallTracker.callScreenSessionId, 'session_1');
    expect(ActiveCallTracker.callScreenWorkFlow, CallWorkFlow.defaultCalling);
    expect(service.activeCall, isNotNull);
    expect(errors, isEmpty);

    CallScreenOverlay.dismiss();
    await tester.pump();
    expect(CallScreenOverlay.isShowing, isFalse);
  });

  group('IncomingCallOverlay.show with no navigator', () {
    testWidgets('keeps no banner, stops the call counting as ringing and '
        'reports NO_NAVIGATOR', (WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final Call call = buildCall(sessionId: 'ringing');
      ActiveCallTracker.ringingCall = call;
      service.activeCall = buildCall(sessionId: 'active');

      IncomingCallOverlay.show(
        context: context,
        call: call,
        onError: errors.add,
      );

      expect(ActiveCallTracker.incomingCallSessionId, isNull);
      expect(ActiveCallTracker.ringingCall, isNull);
      // Only the ringing record: the active call is left alone.
      expect((service.activeCall as Call?)?.sessionId, 'active');
      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');

      // Nothing was kept, so nothing is left to trip over.
      expect(IncomingCallOverlay.dismiss, returnsNormally);
      expect(
        () => IncomingCallOverlay.show(context: context, call: call),
        returnsNormally,
      );
    });
  });

  group('a host onError that throws (round 1b review)', () {
    // The overlays report and then return to a caller with work left: an
    // accept still has its bookkeeping to finish after its show(). A host
    // callback that threw used to cut that short.
    void hostBug(Exception e) => throw StateError('host bug: $e');

    test('CallScreenOverlay.show still frees the device and returns', () {
      service.activeCall = buildCall();

      expect(
        () => CallScreenOverlay.show(
          sessionId: 'session_1',
          sessionSettingsBuilder: SessionSettingsBuilder(),
          onError: hostBug,
        ),
        returnsNormally,
      );
      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.hasActiveCall, isFalse);
    });

    testWidgets('IncomingCallOverlay.show still releases the ringing call '
        'and returns', (WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final Call call = buildCall(sessionId: 'ringing');
      ActiveCallTracker.ringingCall = call;

      expect(
        () => IncomingCallOverlay.show(
          context: context,
          call: call,
          onError: hostBug,
        ),
        returnsNormally,
      );
      expect(ActiveCallTracker.ringingCall, isNull);
    });
  });

  group('P4-C07: dismiss can be scoped to a call (round 4)', () {
    /// Shows [sessionId]'s call screen in the overlay and lets it join.
    Future<void> showJoined(WidgetTester tester, String sessionId) async {
      CallScreenOverlay.show(
        sessionId: sessionId,
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();
      expect(dataSource.calls, contains('startSession:$sessionId'));
    }

    testWidgets('dismiss(sessionId: another) keeps the overlay; dismiss() '
        'still dismisses', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      await showJoined(tester, 'session_1');

      CallScreenOverlay.dismiss(sessionId: 'other');
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(ActiveCallTracker.callScreenSessionId, 'session_1');

      CallScreenOverlay.dismiss(sessionId: 'session_1');
      expect(CallScreenOverlay.isShowing, isFalse);

      await showJoined(tester, 'session_2');
      CallScreenOverlay.dismiss();
      expect(CallScreenOverlay.isShowing, isFalse);
      await tester.pump();
    });

    testWidgets('a "call ended" for a call whose screen another call '
        'replaced while it was being left keeps the new screen', (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      await showJoined(tester, 'session_1');

      service.onCallEndedMessageReceived(buildCall());
      // Another call's screen comes up while the ended call's session is
      // being left.
      CallScreenOverlay.show(
        sessionId: 'session_2',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isTrue);
      expect(ActiveCallTracker.callScreenSessionId, 'session_2');
    });
  });

  testWidgets("the call screen follows the app's language (round 4)", (
    WidgetTester tester,
  ) async {
    final Completer<Widget> join = Completer<Widget>();
    dataSource.onStartSession = (_) => join.future;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        locale: const Locale('de'),
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: Translations.supportedLocales,
        home: const Scaffold(body: Text('messages')),
      ),
    );

    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();
    await tester.pump();

    // German, not the en_US the overlay's own MaterialApp fell back to.
    expect(find.text('Verbindung wird hergestellt...'), findsOneWidget);
    expect(find.text('Connecting...'), findsNothing);

    CallScreenOverlay.dismiss();
    await tester.pump();
    join.complete(const SizedBox());
  });

  for (final (Locale app, String shown) in <(Locale, String)>[
    (const Locale('it'), 'Connecting...'),
    (const Locale('de', 'AT'), 'Verbindung wird hergestellt...'),
  ]) {
    testWidgets('round 4 review: an app in ${app.toLanguageTag()} sees '
        '"$shown" (a language the UI Kit does not ship falls back to '
        'English, not to Arabic)', (WidgetTester tester) async {
      final Completer<Widget> join = Completer<Widget>();
      dataSource.onStartSession = (_) => join.future;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          locale: app,
          // The app's own: Flutter's, which know Italian.
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: <Locale>[app, const Locale('en')],
          home: const Scaffold(body: Text('messages')),
        ),
      );

      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(shown), findsOneWidget);
      expect(find.text('جاري الاتصال...'), findsNothing);

      CallScreenOverlay.dismiss();
      await tester.pump();
      join.complete(const SizedBox());
    });
  }

  testWidgets("dismiss() after the host's navigator was torn down frees the "
      'device and does not throw', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        home: const Scaffold(body: Text('messages')),
      ),
    );
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();

    // The host replaces its app (a logout to a new MaterialApp, say): the
    // overlay the entry was in is gone.
    await tester.pumpWidget(const SizedBox());

    expect(CallScreenOverlay.dismiss, returnsNormally);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
  });
}
