/// [MessageComposerDataSourceImpl] — the composer's thin adapter over the
/// `CometChat.*` statics.
///
/// Its whole job is to turn the SDK's callback pairs into futures and its
/// [CometChatException]s into [MessageComposerDataSourceException]s. The
/// statics resolve everything through `SdkRegistry`, so a fake client makes
/// both halves assertable without a network.
///
///   flutter test test/chat_ui/message_composer/message_composer_datasource_impl_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_upload_sdk.dart';

void main() {
  late FakeUploadSdkClient sdk;
  late MessageComposerDataSourceImpl datasource;

  setUp(() async {
    sdk = await registerFakeUploadSdk();
    datasource = MessageComposerDataSourceImpl();
  });

  tearDown(clearFakeUploadSdk);

  TextMessage text() => TextMessage(
    text: 'hi',
    receiverUid: 'bob',
    receiverType: 'user',
    type: CometChatMessageType.text,
  );

  MediaMessage media() => MediaMessage(
    receiverUid: 'bob',
    receiverType: 'user',
    type: CometChatMessageType.image,
  );

  CustomMessage custom() => CustomMessage(
    receiverUid: 'bob',
    receiverType: 'user',
    type: 'poll',
    customData: const {'q': 'tea or coffee'},
  );

  Matcher failsWith(String code, String message) => throwsA(
    isA<MessageComposerDataSourceException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', message)
        .having((e) => e.originalException, 'originalException', isNotNull),
  );

  group('sending', () {
    test(
      'a text message is handed to the SDK and the SENT one comes back',
      () async {
        final outgoing = text();
        sdk.messageRepo.rewrite = (m) => text()..id = 42;

        final sent = await datasource.sendTextMessage(outgoing);

        expect(sdk.messageRepo.sent, [same(outgoing)]);
        expect(
          sent.id,
          42,
          reason: 'the server-stamped message, not the draft',
        );
      },
    );

    test('a media message round-trips the same way', () async {
      final outgoing = media();
      final result = await datasource.sendMediaMessage(outgoing);
      expect(sdk.messageRepo.sent, [same(outgoing)]);
      expect(result, same(outgoing));
    });

    test('a custom message round-trips the same way', () async {
      final outgoing = custom();
      final result = await datasource.sendCustomMessage(outgoing);
      expect(sdk.messageRepo.sent, [same(outgoing)]);
      expect(result, same(outgoing));
    });

    test('an edit round-trips the same way', () async {
      final outgoing = text()..id = 7;
      final result = await datasource.editMessage(outgoing);
      expect(sdk.messageRepo.sent, [same(outgoing)]);
      expect(result, same(outgoing));
    });
  });

  group('failures become typed datasource exceptions', () {
    test('a failed text send carries the SDK code and message', () async {
      sdk.messageRepo.failWith = sdkFailure(
        code: 'ERR_BLOCKED',
        message: 'You are blocked',
      );
      await expectLater(
        datasource.sendTextMessage(text()),
        failsWith('ERR_BLOCKED', 'You are blocked'),
      );
    });

    test('a failed media send carries the SDK code and message', () async {
      sdk.messageRepo.failWith = sdkFailure(
        code: 'ERR_FILE_TOO_BIG',
        message: 'File too large',
      );
      await expectLater(
        datasource.sendMediaMessage(media()),
        failsWith('ERR_FILE_TOO_BIG', 'File too large'),
      );
    });

    test('a failed custom send carries the SDK code and message', () async {
      sdk.messageRepo.failWith = sdkFailure(
        code: 'ERR_CUSTOM',
        message: 'Custom rejected',
      );
      await expectLater(
        datasource.sendCustomMessage(custom()),
        failsWith('ERR_CUSTOM', 'Custom rejected'),
      );
    });

    test('a failed edit carries the SDK code and message', () async {
      sdk.messageRepo.failWith = sdkFailure(
        code: 'ERR_NOT_EDITABLE',
        message: 'Too old to edit',
      );
      await expectLater(
        datasource.editMessage(text()..id = 7),
        failsWith('ERR_NOT_EDITABLE', 'Too old to edit'),
      );
    });

    test(
      'an edit of an un-editable message never reaches the repository',
      () async {
        // Only text / custom / media messages can be edited.
        await expectLater(
          datasource.editMessage(
            Action(
              action: 'x',
              message: 'y',
              receiverUid: 'bob',
              receiverType: 'user',
              type: 'groupMember',
            ),
          ),
          throwsA(isA<MessageComposerDataSourceException>()),
        );
        expect(sdk.messageRepo.sent, isEmpty);
      },
    );

    test('the exception prints its code and message', () {
      const e = MessageComposerDataSourceException(
        message: 'nope',
        code: 'ERR_X',
      );
      expect(
        e.toString(),
        'MessageComposerDataSourceException(message: nope, code: ERR_X)',
      );
    });
  });

  group('typing and identity', () {
    test('typing start/end reach the realtime layer for this conversation', () {
      sdk.authRepo.loggedInUser = User(uid: 'me', name: 'Me');

      datasource.startTyping(receiverUid: 'bob', receiverType: 'user');
      datasource.endTyping(receiverUid: 'bob', receiverType: 'user');

      expect(sdk.realtimeRepo.typing, ['start:bob', 'end:bob']);
    });

    test('typing without a logged-in user never reaches the wire', () async {
      sdk.authRepo.loggedInUser = null;
      // FINDING: `startTyping`/`endTyping` are `void` and drop the future the
      // SDK returns, so a rejected indicator (here: nobody logged in) escapes
      // as an UNHANDLED asynchronous error instead of being logged or
      // swallowed. Pinned here by catching it in a guarded zone — without the
      // zone this test fails on the stray error.
      final errors = <Object>[];
      await runZonedGuarded(() async {
        datasource.startTyping(receiverUid: 'bob', receiverType: 'user');
        datasource.endTyping(receiverUid: 'bob', receiverType: 'user');
        await pumpEventQueue();
      }, (error, stack) => errors.add(error));

      expect(sdk.realtimeRepo.typing, isEmpty);
      expect(errors, hasLength(2), reason: 'one escaped error per call');
      expect(errors.first, isA<CometChatException>());
    });

    test('the logged-in user is read straight from the SDK', () async {
      expect(await datasource.getLoggedInUser(), isNull);

      final me = User(uid: 'me', name: 'Me');
      sdk.authRepo.loggedInUser = me;
      expect((await datasource.getLoggedInUser())?.uid, 'me');
    });
  });
}
