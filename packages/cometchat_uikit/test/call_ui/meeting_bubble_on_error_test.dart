/// Joining a meeting from its bubble reports to the call buttons' onError
/// (round 1b: every call failure reaches an onError).
///
/// The bubble opened the call screen with no onError at all, so a join that
/// failed, or no navigator to show it on, was invisible to the host.
///
///   flutter test test/call_ui/meeting_bubble_on_error_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CometChatUIKit.authenticationSettings = null;
    CallScreenOverlay.dismiss();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  testWidgets('a meeting joined with no navigator reaches '
      'callButtonsConfiguration.onError as NO_NAVIGATOR', (tester) async {
    final errors = <Exception>[];
    CometChatUIKit.authenticationSettings =
        (UIKitSettingsBuilder()
              ..appId = 'app'
              ..region = 'us'
              ..enableCalls = true
              ..callingConfiguration = CallingConfiguration(
                callButtonsConfiguration: CallButtonsConfiguration(
                  onError: errors.add,
                ),
              ))
            .build();
    // A key attached to nothing: there is no navigator for the call screen.
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();

    final meeting = CustomMessage(
      id: 7,
      receiverUid: 'g1',
      receiverType: ReceiverTypeConstants.group,
      type: MessageTypeConstants.meeting,
      customData: const {
        'callType': CallTypeConstants.audioCall,
        'sessionID': 'g1',
      },
      sender: User(uid: 'someone', name: 'Someone'),
      sentAt: DateTime(2026, 9, 30, 10),
    );
    final template = MessageTemplateUtils.getMessageTemplate(
      messageType: MessageTypeConstants.meeting,
      messageCategory: MessageCategoryConstants.custom,
    )!;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                template.contentView!(meeting, context, BubbleAlignment.left)!,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(CallScreenOverlay.isShowing, isFalse);
    expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
  });
}
