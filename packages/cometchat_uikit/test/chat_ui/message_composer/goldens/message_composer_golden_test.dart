/// Golden pins for [CometChatMessageComposer] in its resting states.
///
/// The real composer is rendered. Its only outside dependency, the
/// repository behind `MessageComposerServiceLocator`, is mocked the way the
/// composer prop tests mock it, so nothing reaches the SDK. Edit and reply mode
/// are entered the way the message list enters them: by handing the composer's
/// own bloc (from `stateCallBack`) a `SetEditMessage` / `SetReplyMessage`.
///
///   flutter test test/chat_ui/message_composer/goldens/                  # verify
///   flutter test test/chat_ui/message_composer/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockComposerRepository extends Mock
    implements MessageComposerRepository {}

final _me = User(uid: 'u-me', name: 'Sam Carter');
final _peer = User(uid: 'u-priya', name: 'Priya Raman', status: 'online');

TextMessage _message({required User sender, required String text}) =>
    TextMessage(
      id: 4101,
      muid: 'm-4101',
      text: text,
      sender: sender,
      receiverUid: sender.uid == _me.uid ? _peer.uid : _me.uid,
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
      category: MessageCategoryConstants.message,
      sentAt: DateTime(2025, 5, 15, 10, 30),
    );

/// The composer leaves a typing debounce pending; run it out after the shot.
const _drain = Duration(seconds: 5);

const _size = Size(375, 200);

/// Bottom-aligned, where a composer sits, so a preview or toolbar that grows
/// the composer grows it upwards as it does in a chat.
const _alignment = Alignment.bottomCenter;

void main() {
  setUp(() {
    final repo = _MockComposerRepository();
    when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(_me));
    when(
      () => repo.startTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.endTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
    MessageComposerServiceLocator.instance.reset();
    MessageComposerServiceLocator.instance.setup(repository: repo);
  });

  tearDown(() => MessageComposerServiceLocator.instance.reset());

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'composer at rest: placeholder, attach, mic',
        fileName: 'message_composer_empty',
        size: _size,
        alignment: _alignment,
        drain: _drain,
        builder: () => CometChatMessageComposer(user: _peer),
      );

      lightDarkGolden(
        'composer with text: send button enabled',
        fileName: 'message_composer_with_text',
        size: _size,
        alignment: _alignment,
        drain: _drain,
        builder: () => CometChatMessageComposer(user: _peer),
        // Typed, not passed as `text`: the send button follows what the user
        // types, and a prefilled draft alone does not enable it.
        interact: (tester) async {
          final fields = find.byType(EditableText);
          for (var i = 0; i < fields.evaluate().length; i++) {
            await tester.enterText(fields.at(i), 'See you at three');
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        },
      );

      lightDarkGolden(
        'composer without the rich-text toolbar',
        fileName: 'message_composer_plain',
        size: _size,
        alignment: _alignment,
        drain: _drain,
        builder: () => CometChatMessageComposer(
          user: _peer,
          enableRichTextFormatting: false,
        ),
      );

      _previewGolden(
        'composer replying to a message: reply preview above the input',
        fileName: 'message_composer_reply_preview',
        event: () => SetReplyMessage(
          _message(sender: _peer, text: 'Can you send the deck?'),
        ),
      );

      _previewGolden(
        'composer editing a message: edit preview and the text loaded',
        fileName: 'message_composer_edit_mode',
        event: () =>
            SetEditMessage(_message(sender: _me, text: 'Sending the deck now')),
      );
    },
  );
}

void _previewGolden(
  String description, {
  required String fileName,
  required MessageComposerEvent Function() event,
}) {
  // One bloc per theme; both are driven before the picture is taken.
  final blocs = <MessageComposerBloc>[];
  lightDarkGolden(
    description,
    fileName: fileName,
    size: const Size(375, 260),
    alignment: _alignment,
    drain: _drain,
    builder: () =>
        CometChatMessageComposer(user: _peer, stateCallBack: blocs.add),
    interact: (tester) async {
      for (final bloc in blocs) {
        bloc.add(event());
      }
      await tester.pump();
      // The preview slides in.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
}
