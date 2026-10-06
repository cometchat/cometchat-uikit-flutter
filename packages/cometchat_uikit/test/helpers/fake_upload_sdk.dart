/// A fake SDK surface for the composer: uploads, message sends and typing.
///
/// `AttachmentTrayController` drives the SDK's multi-upload API:
/// `CometChat.createUploadFileRequest` resolves `SdkRegistry.getInstance()`
/// and hands the real [sdk.UploadFileRequest] the client's
/// [sdk.UploadRepository]; the limits (`getMaxAttachmentCount` /
/// `getMaxAttachmentSize`) come from the client's [sdk.SettingsRepository]
/// cache. Registering [FakeUploadSdkClient] there gives the controller a real
/// request object over a repository that records every call and hands back the
/// listener, so the tray's per-file events can be driven by hand.
///
/// The same client also answers the `CometChat.sendMessage` /
/// `sendMediaMessage` / `sendCustomMessage` / `editMessage` / `startTyping` /
/// `endTyping` / `getLoggedInUser` statics the composer's datasource calls,
/// through scriptable message / auth / realtime repositories.
///
/// Same seam as `test/helpers/golden_fake_sdk.dart`, for the composer.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; they are the only seam the tray leaves.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/models/settings/settings.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/settings/settings_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/upload/upload_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/auth/auth_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/realtime/realtime_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/errors/sdk_exception.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';

/// Records every call the tray makes on the upload repository, and keeps the
/// listeners it was handed so a test can emit per-file events.
class FakeUploadRepository extends Fake implements sdk.UploadRepository {
  /// Ordered log of calls, e.g. `ensureBatch:batch_0`, `upload:tile_0`,
  /// `remove:tile_1`, `retry:tile_1`, `clearAll:batch_0`.
  final List<String> log = <String>[];

  /// Batch ids handed out by [generateBatchId], in order.
  final List<String> batchIds = <String>[];

  /// `receiverId` / `receiverType` captured on each [ensureBatch].
  final List<String> receivers = <String>[];

  /// The files handed to [upload], flattened across calls.
  final List<UploadFile> uploadedFiles = <UploadFile>[];

  /// The file ids handed to [upload], flattened across calls.
  final List<String> uploadedIds = <String>[];

  /// The batch-scoped listener registered by the tray. Emit events through it.
  UploadFileListener? globalListener;

  int _seq = 0;

  @override
  String generateBatchId() {
    final id = 'batch_${_seq++}';
    batchIds.add(id);
    return id;
  }

  @override
  void ensureBatch(
    String batchId, {
    String? receiverId,
    String? receiverType,
    int concurrency = 1,
    int? parentMessageId,
    UploadFileListener? globalListener,
  }) {
    log.add('ensureBatch:$batchId');
    receivers.add('$receiverId/$receiverType');
    this.globalListener = globalListener;
  }

  @override
  void setGlobalListener(String batchId, UploadFileListener? listener) {
    globalListener = listener;
  }

  @override
  void upload(
    String batchId,
    List<({String fileId, UploadFile file})> files,
    UploadFileListener listener,
  ) {
    globalListener ??= listener;
    for (final f in files) {
      log.add('upload:${f.fileId}');
      uploadedIds.add(f.fileId);
      uploadedFiles.add(f.file);
    }
  }

  @override
  void removeAttachment(String batchId, String fileId) =>
      log.add('remove:$fileId');

  @override
  void retryAttachment(String batchId, String fileId) =>
      log.add('retry:$fileId');

  @override
  void clearAll(String batchId) => log.add('clearAll:$batchId');
}

/// Answers the four message-sending calls. Each send returns the message it
/// was given (optionally rewritten by [rewrite]) unless [failWith] is set, in
/// which case it throws — the path that becomes the datasource's
/// `MessageComposerDataSourceException`.
class FakeMessageRepository extends Fake implements sdk.MessageRepository {
  /// Every message this repository was asked to send or edit, in order.
  final List<BaseMessage> sent = <BaseMessage>[];

  /// When set, every call throws it instead of answering.
  Object? failWith;

  /// Applied to the message before it is returned, so a test can assert that
  /// the datasource hands back what the SDK answered, not what it was given.
  BaseMessage Function(BaseMessage message)? rewrite;

  T _answer<T extends BaseMessage>(T message) {
    sent.add(message);
    final failure = failWith;
    if (failure != null) throw failure;
    return (rewrite?.call(message) ?? message) as T;
  }

  @override
  Future<TextMessage> sendTextMessage(TextMessage message) async =>
      _answer(message);

  @override
  Future<MediaMessage> sendMediaMessage(MediaMessage message) async =>
      _answer(message);

  @override
  Future<CustomMessage> sendCustomMessage(CustomMessage message) async =>
      _answer(message);

  @override
  Future<BaseMessage> editMessage(BaseMessage message) async =>
      _answer(message);
}

class FakeAuthRepository extends Fake implements sdk.AuthRepository {
  User? loggedInUser;

  @override
  User? getLoggedInUser() => loggedInUser;
}

class FakeRealtimeRepository extends Fake implements sdk.RealtimeRepository {
  /// Typing indicators sent, as `start:<receiverId>` / `end:<receiverId>`.
  final List<String> typing = <String>[];

  @override
  Future<void> startTyping(TypingIndicator indicator) async =>
      typing.add('start:${indicator.receiverId}');

  @override
  Future<void> endTyping(TypingIndicator indicator) async =>
      typing.add('end:${indicator.receiverId}');
}

/// A thrown-by-the-SDK error, so the `on SdkException` mapping is exercised.
sdk.SdkException sdkFailure({
  String code = 'ERR_SEND',
  String message = 'send failed',
  String? details,
}) => sdk.SdkException(code, message, details);

class _FakeSettingsRepository extends Fake implements sdk.SettingsRepository {
  _FakeSettingsRepository(this._settings);

  final sdk.Settings? _settings;

  @override
  sdk.Settings? getCachedSettings() => _settings;
}

/// An [sdk.SdkClient] that exposes only what the tray reaches for.
class FakeUploadSdkClient extends Fake implements sdk.SdkClient {
  FakeUploadSdkClient({int? maxFileCount, int? maxFileSize})
    : settings = _FakeSettingsRepository(
        (maxFileCount == null && maxFileSize == null)
            ? null
            : sdk.Settings(
                appVersion: 1,
                settingsHash: 'test',
                maxFileCount: maxFileCount,
                maxFileSize: maxFileSize,
              ),
      );

  @override
  final sdk.UploadRepository uploads = FakeUploadRepository();

  @override
  final sdk.SettingsRepository settings;

  @override
  final sdk.MessageRepository messages = FakeMessageRepository();

  @override
  final sdk.AuthRepository auth = FakeAuthRepository();

  @override
  final sdk.RealtimeRepository realtime = FakeRealtimeRepository();

  /// The repositories, already typed.
  FakeUploadRepository get repo => uploads as FakeUploadRepository;
  FakeMessageRepository get messageRepo => messages as FakeMessageRepository;
  FakeAuthRepository get authRepo => auth as FakeAuthRepository;
  FakeRealtimeRepository get realtimeRepo => realtime as FakeRealtimeRepository;

  @override
  Future<void> dispose() async {}
}

/// Registers a fresh [FakeUploadSdkClient] and returns it. Call
/// [clearFakeUploadSdk] from `tearDown`.
Future<FakeUploadSdkClient> registerFakeUploadSdk({
  int? maxFileCount,
  int? maxFileSize,
}) async {
  await sdk.SdkRegistry.clear();
  final client = FakeUploadSdkClient(
    maxFileCount: maxFileCount,
    maxFileSize: maxFileSize,
  );
  sdk.SdkRegistry.register(client);
  return client;
}

Future<void> clearFakeUploadSdk() => sdk.SdkRegistry.clear();
