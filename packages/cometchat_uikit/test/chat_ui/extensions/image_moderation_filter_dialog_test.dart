/// Tapping the cover over an unsafe image asks before revealing it.
///
/// The dialog passes a title only. `CometChatConfirmDialog` falls back to its
/// block-contact message when no `messageText` is given, so the filter must
/// pass its own (empty) one, or the "reveal image?" dialog asks about
/// blocking a contact.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

/// An image the image-moderation extension flagged as unsafe.
MediaMessage _unsafeImage() => MediaMessage(
  receiverUid: 'u2',
  type: MessageTypeConstants.image,
  receiverType: CometChatReceiverType.user,
  sender: User(uid: 'u2', name: 'Bob'),
  metadata: {
    '@injected': {
      'extensions': {
        ExtensionConstants.imageModeration: {'unsafe': 'yes'},
      },
    },
  },
);

void main() {
  testWidgets('the reveal dialog never shows the block-contact message, '
      'and confirming reveals the image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ImageModerationFilter(
          message: _unsafeImage(),
          child: const SizedBox(key: Key('image'), width: 120, height: 90),
        ),
      ),
    );
    expect(find.byKey(const Key('image')), findsNothing, reason: 'covered');

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    final strings = TranslationsEn();
    expect(find.text(strings.areYouSureUnsafeContent), findsOneWidget);
    expect(find.textContaining('block this contact'), findsNothing);

    await tester.tap(find.text(strings.yes));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('image')), findsOneWidget, reason: 'revealed');
  });
}
