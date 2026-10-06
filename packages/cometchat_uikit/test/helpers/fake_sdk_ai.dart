/// A fake SDK AI backend for the views that call `CometChat.getSmartReplies`,
/// `CometChat.getConversationStarter` and `CometChat.getConversationSummary`.
///
/// Those statics validate their arguments and then resolve `sdk.ai` through
/// `SdkRegistry` — the same seam `fake_sdk_moderation.dart` and
/// `golden_fake_sdk.dart` use. Registering this client answers each call from
/// the closures below, so the real views run their loading, success and error
/// paths without a network.
library;

import 'dart:async';

// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/ai/ai_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

/// What `CometChat.getSmartReplies` answers with, keyed by the reply tone the
/// view looks for. Throw to drive the error path; return a pending `Future` to
/// hold the view in its loading state.
FutureOr<Map<String, String>> Function(String receiverId, String receiverType)
fakeSmartReplies = (_, _) => const <String, String>{};

/// What `CometChat.getConversationStarter` answers with.
FutureOr<List<String>> Function(String receiverId, String receiverType)
fakeConversationStarters = (_, _) => const <String>[];

/// What `CometChat.getConversationSummary` answers with.
FutureOr<String> Function(String receiverId, String receiverType)
fakeConversationSummary = (_, _) => '';

class _FakeAiRepository extends Fake implements sdk.AiRepository {
  @override
  Future<Map<String, String>> getSmartReplies(
    String receiverId,
    String receiverType,
  ) async => fakeSmartReplies(receiverId, receiverType);

  @override
  Future<List<String>> getConversationStarter(
    String receiverId,
    String receiverType,
  ) async => fakeConversationStarters(receiverId, receiverType);

  @override
  Future<String> getConversationSummary(
    String receiverId,
    String receiverType,
  ) async => fakeConversationSummary(receiverId, receiverType);
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.AiRepository ai = _FakeAiRepository();

  @override
  Future<void> dispose() async {}
}

/// Point every AI static at the closures above. Call from `setUp`, and
/// [clearFakeAiBackend] from `tearDown`.
Future<void> registerFakeAiBackend() async {
  await sdk.SdkRegistry.clear();
  sdk.SdkRegistry.register(_FakeSdkClient());
}

Future<void> clearFakeAiBackend() async {
  fakeSmartReplies = (_, _) => const <String, String>{};
  fakeConversationStarters = (_, _) => const <String>[];
  fakeConversationSummary = (_, _) => '';
  await sdk.SdkRegistry.clear();
}
