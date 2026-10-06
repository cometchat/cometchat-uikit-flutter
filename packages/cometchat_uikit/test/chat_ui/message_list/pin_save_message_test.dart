// Pin & Save Message — kit-side unit tests: the option ids in both constants
// copies, the event-bus channels, the state helpers, the hide-flag config
// surface, the header pin-icon gating, and the localization keys.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart'
    as legacy_constants;

class _RecordingListener with CometChatMessageEventListener {
  final List<(String, int)> received = [];

  @override
  void ccMessagePinned(BaseMessage message) =>
      received.add(('pinned', message.id));

  @override
  void ccMessageUnpinned(BaseMessage message) =>
      received.add(('unpinned', message.id));

  @override
  void ccMessageSaved(BaseMessage message) =>
      received.add(('saved', message.id));

  @override
  void ccMessageUnsaved(BaseMessage message) =>
      received.add(('unsaved', message.id));
}

class _PlainListener with CometChatMessageEventListener {}

BaseMessage _message({
  int id = 1,
  DateTime? pinnedAt,
  String? pinnedBy,
  DateTime? savedAt,
}) => BaseMessage(
  id: id,
  receiverUid: 'r1',
  type: 'text',
  receiverType: 'group',
  pinnedAt: pinnedAt,
  pinnedBy: pinnedBy,
  savedAt: savedAt,
);

void main() {
  group('Option ids', () {
    test('present and identical in both MessageOptionConstants copies', () {
      expect(MessageOptionConstants.pinMessage, 'pinMessage');
      expect(MessageOptionConstants.unpinMessage, 'unpinMessage');
      expect(MessageOptionConstants.saveMessage, 'saveMessage');
      expect(MessageOptionConstants.unsaveMessage, 'unsaveMessage');
      expect(legacy_constants.MessageOptionConstants.pinMessage, 'pinMessage');
      expect(
        legacy_constants.MessageOptionConstants.unpinMessage,
        'unpinMessage',
      );
      expect(
        legacy_constants.MessageOptionConstants.saveMessage,
        'saveMessage',
      );
      expect(
        legacy_constants.MessageOptionConstants.unsaveMessage,
        'unsaveMessage',
      );
    });
  });

  group('CometChatMessageEvents pin/save channels', () {
    test('reach registered listeners and stop after removal', () {
      final listener = _RecordingListener();
      CometChatMessageEvents.addMessagesListener('test_pin_save', listener);

      CometChatMessageEvents.ccMessagePinned(_message(id: 1));
      CometChatMessageEvents.ccMessageUnpinned(_message(id: 2));
      CometChatMessageEvents.ccMessageSaved(_message(id: 3));
      CometChatMessageEvents.ccMessageUnsaved(_message(id: 4));
      expect(listener.received, [
        ('pinned', 1),
        ('unpinned', 2),
        ('saved', 3),
        ('unsaved', 4),
      ]);

      CometChatMessageEvents.removeMessagesListener('test_pin_save');
      CometChatMessageEvents.ccMessagePinned(_message(id: 5));
      expect(listener.received.length, 4);
    });

    test('existing listeners without the new overrides are unaffected', () {
      final plain = _PlainListener();
      CometChatMessageEvents.addMessagesListener('test_plain_pin', plain);
      expect(
        () => CometChatMessageEvents.ccMessagePinned(_message()),
        returnsNormally,
      );
      CometChatMessageEvents.removeMessagesListener('test_plain_pin');
    });
  });

  group('State helpers', () {
    test('isMessagePinned/isMessageSaved read the message fields', () {
      expect(MessageTemplateUtils.isMessagePinned(_message()), isFalse);
      expect(MessageTemplateUtils.isMessageSaved(_message()), isFalse);
      final stamped = _message(
        pinnedAt: DateTime.fromMillisecondsSinceEpoch(1700000100000),
        pinnedBy: 'app_system',
        savedAt: DateTime.fromMillisecondsSinceEpoch(1700000200000),
      );
      expect(MessageTemplateUtils.isMessagePinned(stamped), isTrue);
      expect(MessageTemplateUtils.isMessageSaved(stamped), isTrue);
    });
  });

  group('Config surface', () {
    test('AdditionalConfigurations carries the four hide flags', () {
      final configurations = AdditionalConfigurations(
        hidePinMessageOption: true,
        hideUnpinMessageOption: true,
        hideSaveMessageOption: true,
        hideUnsaveMessageOption: true,
      );
      expect(configurations.hidePinMessageOption, isTrue);
      expect(configurations.hideUnpinMessageOption, isTrue);
      expect(configurations.hideSaveMessageOption, isTrue);
      expect(configurations.hideUnsaveMessageOption, isTrue);
      expect(AdditionalConfigurations().hidePinMessageOption, isNull);
    });
  });

  group('CometChatMessageHeader.pinnedMessagesVisibility', () {
    Widget host({required bool visible, BaseMessage? parentMessage}) {
      return MaterialApp(
        home: Scaffold(
          appBar: CometChatMessageHeader(
            group: Group(guid: 'g1', name: 'G', type: 'public'),
            pinnedMessagesVisibility: visible,
            parentMessage: parentMessage,
            hideVoiceCallButton: true,
            hideVideoCallButton: true,
          ),
          body: const SizedBox(),
        ),
      );
    }

    // Pinned messages moved from a standalone header icon into the ⋯
    // overflow menu, so the entry only exists once the menu is opened.
    testWidgets('pinned entry is reachable from the ⋯ menu by default', (
      tester,
    ) async {
      await tester.pumpWidget(host(visible: true));
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(
        find.byIcon(Icons.push_pin_outlined),
        findsNothing,
        reason: 'the entry lives in the menu, not the header itself',
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    });

    testWidgets('no ⋯ menu when visibility is off and nothing else to show', (
      tester,
    ) async {
      await tester.pumpWidget(host(visible: false));
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('no pin icon in thread mode (parentMessage set)', (
      tester,
    ) async {
      CometChatUIKit.authenticationSettings =
          (UIKitSettingsBuilder()..enableThreadSubscription = false).build();
      await tester.pumpWidget(
        host(visible: true, parentMessage: _message(id: 42)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });
  });

  group('Localization', () {
    test('base class ships English defaults (non-breaking for subclasses)', () {
      final en = TranslationsEn();
      expect(en.pinMessageOption, 'Pin message');
      expect(en.unpinMessageOption, 'Unpin message');
      expect(en.saveMessageOption, 'Save message');
      expect(en.unsaveMessageOption, 'Unsave message');
      expect(en.messagePinnedToast, 'Message pinned');
      expect(en.messageUnpinnedToast, 'Message unpinned');
      expect(en.messageSavedToast, 'Message saved');
      expect(en.messageUnsavedToast, 'Message unsaved');
      expect(en.pinnedMessagesTitle, 'Pinned Messages');
      expect(en.savedMessagesTitle, 'Saved Messages');
      expect(en.noPinnedMessages, isNotEmpty);
      expect(en.noSavedMessages, isNotEmpty);
      expect(en.pinConfirmTitle, isNotEmpty);
      expect(en.saveConfirmMessage, isNotEmpty);
      expect(
        en.actionPermissionDenied,
        'You don\'t have permission to perform this action.',
      );
      expect(en.pinSaveFailed, isNotEmpty);
    });

    test('cap toasts interpolate the server-supplied limit', () {
      final en = TranslationsEn();
      expect(en.pinLimitReachedToast(100), contains('100'));
      expect(en.saveLimitReachedToast(50), contains('50'));
    });

    test('zh and zh_TW carry distinct translations', () {
      final zh = TranslationsZh();
      final zhTw = TranslationsZhTw();
      expect(zh.pinMessageOption, isNotEmpty);
      expect(zhTw.pinMessageOption, isNotEmpty);
      expect(zh.pinMessageOption, isNot(zhTw.pinMessageOption));
    });
  });
}
