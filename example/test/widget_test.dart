// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
//   testWidgets('Verify Platform version', (WidgetTester tester) async {
//     // Build our app and trigger a frame.
//     await tester.pumpWidget(const MyApp());

//     // Verify that platform version is retrieved.
//     expect(
//       find.byWidgetPredicate(
//         (Widget widget) =>
//             widget is Text && widget.data!.startsWith('Running on:'),
//       ),
//       findsOneWidget,
//     );
//   });

  testWidgets(
    'testing init 5',
    (tester) async {
      print('test began');
      // UIKitSettings uiKitSettings = (UIKitSettingsBuilder()
      //       ..subscriptionType = CometChatSubscriptionType.allUsers
      //       ..region = CometChatConstants.region
      //       ..autoEstablishSocketConnection = true
      //       ..appId = CometChatConstants.appId
      //       ..authKey = CometChatConstants.authKey)
      //     .build();
      // print('auth settings initialized');

      // await CometChatUIKit.init(
      //     uiKitSettings: uiKitSettings,
      //     onSuccess: (String successMessage) {
      //       debugPrint(
      //           "Initialization completed successfully  $successMessage");
      //     },
      //     onError: (CometChatException e) {
      //       debugPrint("Initialization failed with exception: ${e.message}");
      //     });
      // print('cometchat ui kit initialized');
      // await tester.pumpAndSettle();
      // await tester.pumpWidget(MyApp());
      // final signInButton = find.widgetWithText(MaterialButton, 'SUPERHERO1');
      // expect(signInButton, findsOneWidget,
      //     reason: "there are 4 buttons to login and 1 has superhero1");
      // print('superhero1 button found');

      // await tester.tap(signInButton);
      // print('trying to login');
      // await tester.pumpAndSettle(Duration(seconds: 10));
      // print('went to dashboard?');

      // final cardForConvoWithMsg =
      //     find.widgetWithText(ListTile, 'Conversation with messages');
      // expect(cardForConvoWithMsg, findsOneWidget,
      //     reason: "ListTile for conversations with messages is only 1");
      // print('ListTile for conversations with messages found');
      // signInButton.
      // await CometChatUIKit.login('superhero1');
      // await tester.pump();
      // await tester.pumpWidget(CometChatUsers());
    },
  );
}
