import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'message_composer_datasource.dart';
import '../../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../../shared_ui/src/offline/offline_gate.dart';
import '../../../../../shared_ui/src/offline/offline_send.dart';

/// Implementation of MessageComposerDataSource using CometChat SDK
class MessageComposerDataSourceImpl implements MessageComposerDataSource {
  @override
  Future<TextMessage> sendTextMessage(TextMessage message) async {
    // Offline send seam (W1 §2.9 → W4). Falls through in W1.
    if (OfflineGate.isOn()) {
      final handled = OfflineSend.instance.tryComposerSend<TextMessage>(
        message,
      );
      if (handled != null) return handled;
    }
    final completer = Completer<TextMessage>();

    unawaited(
      CometChat.sendMessage(
        message,
        onSuccess: (TextMessage sentMessage) {
          completer.complete(sentMessage);
        },
        onError: (CometChatException e) {
          completer.completeError(
            MessageComposerDataSourceException(
              message: e.message ?? 'Failed to send text message',
              code: e.code,
              originalException: e,
            ),
          );
        },
      ),
    );

    return completer.future;
  }

  @override
  Future<MediaMessage> sendMediaMessage(MediaMessage message) async {
    // Offline send seam (W1 §2.9 → W4). Falls through in W1.
    if (OfflineGate.isOn()) {
      final handled = OfflineSend.instance.tryComposerSend<MediaMessage>(
        message,
      );
      if (handled != null) return handled;
    }
    final completer = Completer<MediaMessage>();

    // Pass raw filesystem path — file:// prefix breaks MultipartFile.fromFile()
    ccLog(
      '[ComposerDatasource] sendMediaMessage — file: ${message.file}, type: ${message.type}',
    );

    await CometChat.sendMediaMessage(
      message,
      onSuccess: (MediaMessage sentMessage) {
        ccLog(
          '[ComposerDatasource] sendMediaMessage SUCCESS — id: ${sentMessage.id}, attachment: ${sentMessage.attachment?.fileUrl}',
        );
        completer.complete(sentMessage);
      },
      onError: (CometChatException e) {
        ccLog(
          '[ComposerDatasource] sendMediaMessage ERROR — code: ${e.code}, message: ${e.message}, details: ${e.details}',
        );
        completer.completeError(
          MessageComposerDataSourceException(
            message: e.message ?? 'Failed to send media message',
            code: e.code,
            originalException: e,
          ),
        );
      },
    );

    return completer.future;
  }

  @override
  Future<CustomMessage> sendCustomMessage(CustomMessage message) async {
    // Offline send seam (W1 §2.9 → W4). Falls through in W1.
    if (OfflineGate.isOn()) {
      final handled = OfflineSend.instance.tryComposerSend<CustomMessage>(
        message,
      );
      if (handled != null) return handled;
    }
    final completer = Completer<CustomMessage>();

    unawaited(
      CometChat.sendCustomMessage(
        message,
        onSuccess: (CustomMessage sentMessage) {
          completer.complete(sentMessage);
        },
        onError: (CometChatException e) {
          completer.completeError(
            MessageComposerDataSourceException(
              message: e.message ?? 'Failed to send custom message',
              code: e.code,
              originalException: e,
            ),
          );
        },
      ),
    );

    return completer.future;
  }

  @override
  Future<BaseMessage> editMessage(BaseMessage message) async {
    final completer = Completer<BaseMessage>();

    unawaited(
      CometChat.editMessage(
        message,
        onSuccess: (BaseMessage editedMessage) {
          completer.complete(editedMessage);
        },
        onError: (CometChatException e) {
          completer.completeError(
            MessageComposerDataSourceException(
              message: e.message ?? 'Failed to edit message',
              code: e.code,
              originalException: e,
            ),
          );
        },
      ),
    );

    return completer.future;
  }

  @override
  void startTyping({
    required String receiverUid,
    required String receiverType,
  }) {
    CometChat.startTyping(receiverUid: receiverUid, receiverType: receiverType);
  }

  @override
  void endTyping({required String receiverUid, required String receiverType}) {
    CometChat.endTyping(receiverUid: receiverUid, receiverType: receiverType);
  }

  @override
  Future<User?> getLoggedInUser() async {
    return CometChat.getLoggedInUser();
  }
}
