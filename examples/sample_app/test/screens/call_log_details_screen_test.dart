import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/screens/call_log_details_screen.dart';

/// Round 5 (P5-C21): the call-log details header no longer shimmers for
/// ever when its user or group cannot be fetched. Here the chat SDK is not
/// initialised, so every fetch fails, as it does offline: the header falls
/// back to the name the log carries, with no call buttons.
void main() {
  setUp(() => CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me'));
  tearDown(() => CometChatUIKit.loggedInUser = null);

  Future<void> pumpDetails(WidgetTester tester, CallLog log) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        home: CallLogDetailsScreen(callLog: log),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('P5-E36: a 1:1 log whose user cannot be fetched shows the '
      'name from the log, with no call buttons', (tester) async {
    await pumpDetails(
      tester,
      CallLog(
        sessionId: 's1',
        receiverType: 'user',
        type: 'audio',
        status: 'ended',
        initiatedAt: 1756800000,
        initiator: CallUser(uid: 'me', name: 'Me'),
        receiver: CallUser(uid: 'bob', name: 'Bob'),
      ),
    );

    expect(find.byType(CometChatShimmerEffect), findsNothing);
    expect(find.byType(CometChatMessageHeader), findsNothing);
    expect(find.byType(CometChatCallButtons), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('P5-E36: a group log shows the group, even when it cannot be '
      'fetched', (tester) async {
    await pumpDetails(
      tester,
      CallLog(
        sessionId: 's2',
        receiverType: 'group',
        type: 'video',
        status: 'ended',
        initiatedAt: 1756800000,
        initiator: CallUser(uid: 'them', name: 'Them'),
        receiver: CallGroup(guid: 'team', name: 'Team'),
      ),
    );

    expect(find.byType(CometChatShimmerEffect), findsNothing);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Them'), findsNothing);
  });
}
