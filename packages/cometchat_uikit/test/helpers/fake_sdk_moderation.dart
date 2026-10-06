/// A fake SDK moderation/extension backend for widgets that call
/// `CometChat.getFlagReasons`, `CometChat.flagMessage`,
/// `CometChat.callExtension` or `CometChat.isExtensionEnabled`.
///
/// Those statics resolve their repository through `SdkRegistry`, which is the
/// same seam `golden_fake_sdk.dart` uses for message fetches. Registering this
/// client answers each call from the closures below, so the real widgets run
/// their success AND failure paths without a network.
library;

import 'dart:async';

// The SDK exports none of these; they are the only seam these widgets leave.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/moderation/moderation_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/extensions/extension_repository.dart'
    as sdk;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// What `CometChat.getFlagReasons` answers with. Throw to drive the error path.
List<FlagReason> Function() fakeFlagReasons = () => const <FlagReason>[];

/// What `CometChat.flagMessage` answers with. Throw to drive the error path.
/// Receives the message id and the detail the widget built, so a test can
/// assert what the dialog actually submitted.
String Function(int messageId, FlagDetail detail) fakeFlagMessage = (_, _) =>
    'success';

/// What `CometChat.callExtension` answers with — the INNER payload; the SDK
/// wraps it as `{'data': <this>}` before handing it to the widget. Return a
/// pending `Future` to keep a caller in its loading state.
FutureOr<Map<String, dynamic>> Function(
  String slug,
  String method,
  String endpoint,
  Map<String, dynamic>? body,
)
fakeCallExtension = (_, _, _, _) => <String, dynamic>{};

/// The extension slugs `CometChat.isExtensionEnabled` reports as enabled.
Set<String> fakeEnabledExtensions = <String>{};

class _FakeModerationRepository extends Fake
    implements sdk.ModerationRepository {
  @override
  Future<List<FlagReason>> getFlagReasons() async => fakeFlagReasons();

  @override
  Future<String> flagMessage(int messageId, FlagDetail flagDetail) async =>
      fakeFlagMessage(messageId, flagDetail);
}

class _FakeExtensionRepository extends Fake implements sdk.ExtensionRepository {
  @override
  Future<Map<String, dynamic>> callExtension(
    String slug,
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async => fakeCallExtension(slug, method, endpoint, body);

  @override
  Future<bool> isExtensionEnabled(String slug) async =>
      fakeEnabledExtensions.contains(slug);
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.ModerationRepository moderation = _FakeModerationRepository();

  @override
  final sdk.ExtensionRepository extensions = _FakeExtensionRepository();

  @override
  Future<void> dispose() async {}
}

/// Point every moderation/extension static at the closures above.
/// Call from `setUp`, and [clearFakeSdkBackend] from `tearDown`.
Future<void> registerFakeSdkBackend() async {
  await sdk.SdkRegistry.clear();
  sdk.SdkRegistry.register(_FakeSdkClient());
}

Future<void> clearFakeSdkBackend() async {
  fakeFlagReasons = () => const <FlagReason>[];
  fakeFlagMessage = (_, _) => 'success';
  fakeCallExtension = (_, _, _, _) => <String, dynamic>{};
  fakeEnabledExtensions = <String>{};
  await sdk.SdkRegistry.clear();
}
