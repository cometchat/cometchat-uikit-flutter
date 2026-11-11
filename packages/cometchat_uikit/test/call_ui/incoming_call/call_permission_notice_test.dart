/// Direct tests for [CallPermissionNotice]: the SnackBar on the app's
/// navigator when an incoming call cannot be answered because the microphone
/// (and the camera, for a video call) was refused.
///
///   flutter test test/call_ui/incoming_call/call_permission_notice_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatColorPalette, CometChatLocalize, CometChatLocalizations;
import 'package:cometchat_chat_uikit/src/call_permission_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

void main() {
  late List<String> permissionCalls;
  late CometChatLocalizations strings;

  setUp(() {
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    permissionCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
          permissionCalls.add(call.method);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, null);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// The app as a host has it: the UI Kit's navigator key on its MaterialApp,
  /// with a Scaffold for the SnackBar.
  Future<void> host(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: CometChatLocalize.localizationsDelegates,
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              strings = CometChatLocalize.of(context);
              return const Text('chats');
            },
          ),
        ),
      ),
    );
  }

  SnackBar snackBar(WidgetTester tester) =>
      tester.widget<SnackBar>(find.byType(SnackBar));

  testWidgets('a voice call says the microphone is needed, with no Settings '
      'action when the system can still ask', (tester) async {
    await host(tester);

    CallPermissionNotice.show(isVideoCall: false, permanentlyDenied: false);
    await tester.pump();

    expect(find.text(strings.microphoneRequiredToAnswerCall), findsOneWidget);
    expect(snackBar(tester).action, isNull);
  });

  testWidgets('a video call says the camera and microphone are needed', (
    tester,
  ) async {
    await host(tester);

    CallPermissionNotice.show(isVideoCall: true, permanentlyDenied: false);
    await tester.pump();

    expect(
      find.text(strings.cameraAndMicrophoneRequiredToAnswerCall),
      findsOneWidget,
    );
  });

  testWidgets('permanently denied adds a Settings action that opens the '
      'app\'s settings', (tester) async {
    await host(tester);

    CallPermissionNotice.show(isVideoCall: false, permanentlyDenied: true);
    await tester.pump();

    final action = snackBar(tester).action;
    expect(action, isNotNull);
    expect(action!.label, strings.settings);

    action.onPressed();
    await tester.pump();
    expect(permissionCalls, ['openAppSettings']);
  });

  testWidgets('a failure to open the settings is not thrown', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
          throw PlatformException(code: 'failed');
        });
    await host(tester);

    CallPermissionNotice.show(isVideoCall: false, permanentlyDenied: true);
    await tester.pump();
    snackBar(tester).action!.onPressed();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the SnackBar takes the theme\'s error and white colours', (
    tester,
  ) async {
    await host(
      tester,
      theme: ThemeData(
        extensions: [
          CometChatColorPalette(
            error: const Color(0xFF0000A1),
            white: const Color(0xFF0000A2),
          ),
        ],
      ),
    );

    CallPermissionNotice.show(isVideoCall: false, permanentlyDenied: true);
    await tester.pump();

    final bar = snackBar(tester);
    expect(bar.backgroundColor, const Color(0xFF0000A1));
    expect((bar.content as Text).style?.color, const Color(0xFF0000A2));
    expect(bar.action!.textColor, const Color(0xFF0000A2));
  });

  testWidgets('nothing shows, and nothing throws, before the app\'s navigator '
      'is up', (tester) async {
    // The key on no navigator: an answer can launch the app before its
    // first frame.
    CallPermissionNotice.show(isVideoCall: true, permanentlyDenied: true);
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
