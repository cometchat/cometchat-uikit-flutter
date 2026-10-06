/// Golden pins for [CometChatMessageInformation], the receipts sheet.
///
/// The real widget is rendered, held in a fixed state through its
/// `messageInformationBloc` seam. The 1-1 view shows the read / delivered
/// stamps; the group view shows one receipt row per member.
///
///   flutter test test/chat_ui/message_information/goldens/                  # verify
///   flutter test test/chat_ui/message_information/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockMessageInformationBloc
    extends MockBloc<MessageInformationEvent, MessageInformationState>
    implements MessageInformationBloc {}

final _me = User(uid: 'u-me', name: 'Sam Carter');
final _priya = User(uid: 'u-priya', name: 'Priya Raman');
final _marcus = User(uid: 'u-marcus', name: 'Marcus Webb');
final _group = Group(
  guid: 'g-design',
  name: 'Design Review',
  type: GroupTypeConstants.private,
);

/// Local, with a two-digit day and hour, so every stamp on the sheet prints
/// at the same width in every zone.
final _sentAt = DateTime(2025, 5, 15, 10, 30);
final _deliveredAt = DateTime(2025, 5, 15, 10, 31);
final _readAt = DateTime(2025, 5, 15, 10, 42);

TextMessage _message({required bool inGroup}) => TextMessage(
  id: 5101,
  text: 'Minutes from today are in the drive',
  sender: _me,
  receiver: inGroup ? _group : _priya,
  receiverUid: inGroup ? _group.guid : _priya.uid,
  type: MessageTypeConstants.text,
  receiverType: inGroup
      ? ReceiverTypeConstants.group
      : ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
  deliveredAt: _deliveredAt,
  readAt: _readAt,
);

MessageReceipt _receipt(User from, {required bool read, bool group = true}) =>
    MessageReceipt(
      messageId: 5101,
      sender: from,
      receiverType: group
          ? ReceiverTypeConstants.group
          : ReceiverTypeConstants.user,
      receiverId: group ? _group.guid : _me.uid,
      timestamp: read ? _readAt : _deliveredAt,
      receiptType: read
          ? MessageReceipt.receiptTypeRead
          : MessageReceipt.receiptTypeDelivered,
      deliveredAt: _deliveredAt,
      readAt: read ? _readAt : null,
    );

_MockMessageInformationBloc _bloc(MessageInformationState state) {
  final bloc = _MockMessageInformationBloc();
  whenListen(
    bloc,
    Stream<MessageInformationState>.value(state),
    initialState: state,
  );
  return bloc;
}

/// The widget is a DraggableScrollableSheet that opens at half of the height
/// it is given, so it gets a whole screen, as it does in a modal bottom sheet.
const _size = goldenScreen;

void main() {
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        '1-1 message information: read and delivered stamps',
        fileName: 'message_information_user',
        size: _size,
        alignment: Alignment.bottomCenter,
        builder: () {
          final message = _message(inGroup: false);
          return CometChatMessageInformation(
            message: message,
            messageInformationBloc: _bloc(
              MessageInformationState(
                status: MessageInformationStatus.loaded,
                parentMessage: message,
                receipts: [_receipt(_priya, read: true, group: false)],
                user: _priya,
              ),
            ),
          );
        },
      );

      lightDarkGolden(
        'group message information: a read row and a delivered-only row',
        fileName: 'message_information_group_receipts',
        size: _size,
        alignment: Alignment.bottomCenter,
        builder: () {
          final message = _message(inGroup: true);
          return CometChatMessageInformation(
            message: message,
            messageInformationBloc: _bloc(
              MessageInformationState(
                status: MessageInformationStatus.loaded,
                parentMessage: message,
                receipts: [
                  _receipt(_priya, read: true),
                  _receipt(_marcus, read: false),
                ],
                group: _group,
              ),
            ),
          );
        },
      );
    },
  );
}
