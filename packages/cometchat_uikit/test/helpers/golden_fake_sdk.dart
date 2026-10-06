/// A fake SDK message store for goldens of screens that take no bloc.
///
/// `CometChatPinnedMessages` and `CometChatSavedMessages` fetch through
/// `MessagesRequest.fetchPrevious`, which resolves the SDK's MessageRepository
/// through `SdkRegistry`. Registering this client there answers every message
/// fetch with a fixed page, so the real screen renders real rows without a
/// network. It is the same seam pinned_messages_props_test.dart uses.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; they are the only seam these screens leave.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

/// What every message fetch answers with. A golden's builder sets it before
/// it constructs the screen; a page that throws makes the fetch fail.
List<BaseMessage> Function() fakeMessagePage = () => const [];

class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  /// fetchPrevious routes to getUserMessages, getGroupMessages or getMessages
  /// depending on its scope. Answered through noSuchMethod so the fake does
  /// not restate the repository's named parameters.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages ||
        name == #getGroupMessages ||
        name == #getMessages) {
      return Future<sdk.MessagesResult>.sync(
        () => sdk.MessagesResult(messages: fakeMessagePage(), hasMore: false),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessageRepository();

  @override
  Future<void> dispose() async {}
}

/// Makes every SDK message fetch answer with [fakeMessagePage]. Call from
/// `setUp`, and [clearFakeMessageStore] from `tearDown`.
Future<void> registerFakeMessageStore() async {
  await sdk.SdkRegistry.clear();
  sdk.SdkRegistry.register(_FakeSdkClient());
}

Future<void> clearFakeMessageStore() async {
  fakeMessagePage = () => const [];
  await sdk.SdkRegistry.clear();
}
