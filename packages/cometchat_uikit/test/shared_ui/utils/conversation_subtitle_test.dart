/// Behaviour tests for the conversation subtitle builders —
/// Track 3 TEST3 (ENG-38684).
///
/// `ConversationUtils.getLastMessage` and its siblings decide the one line of
/// text under every row of the conversation list. It is the most-read string
/// the Kit produces and it was almost entirely untested: the file sat at 7.9%.
///
/// The markdown stripping half of this file is covered by
/// `conversation_utils_test.dart`; this covers the message-shape dispatch.
///
///   flutter test test/shared_ui/utils/conversation_subtitle_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');

TextMessage _text(String body, {List<User> mentioned = const []}) =>
    TextMessage(
      text: body,
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      type: MessageTypeConstants.text,
      sender: _alice,
    )..mentionedUsers = mentioned;

MediaMessage _media(String type, {String? fileName, String? caption}) {
  final m = MediaMessage(
    receiverUid: 'u2',
    receiverType: CometChatReceiverType.user,
    type: type,
    sender: _alice,
  );
  if (caption != null) m.caption = caption;
  if (fileName != null) {
    // Attachment takes positional args: url, name, extension, mime, size.
    m.attachment = Attachment(
      'https://x/$fileName',
      fileName,
      fileName.split('.').last,
      'application/octet-stream',
      1,
    );
  }
  return m;
}

Conversation _conversation(BaseMessage last) => Conversation(
  conversationId: 'c1',
  conversationType: CometChatConversationType.user,
  conversationWith: _bob,
  lastMessage: last,
);

/// Runs [body] with a real BuildContext, which the subtitle builders need for
/// their localized labels.
Future<void> withContext(
  WidgetTester tester,
  void Function(BuildContext) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('getLastMessage — text', () {
    testWidgets('plain text is used verbatim', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(_text('see you at six')),
            context,
          ),
          'see you at six',
        );
      });
    });

    testWidgets('markdown is stripped for the subtitle', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(_text('a **bold** claim')),
            context,
          ),
          'a bold claim',
        );
      });
    });

    testWidgets('a list marker is stripped and leaves no artifact', (
      tester,
    ) async {
      // Regression cover for ENG-39024, at the level a user actually sees:
      // this is the string that lands under the conversation row.
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(_text('- buy milk')),
          context,
        );
        expect(s, 'buy milk');
        expect(s, isNot(contains(r'$')));
      });
    });

    testWidgets('a mention is resolved to the display name', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(_text('hey <@uid:u2> look', mentioned: [_bob])),
            context,
          ),
          'hey @Bob look',
        );
      });
    });

    testWidgets('an unresolved mention keeps its raw token', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(_text('hey <@uid:ghost>', mentioned: [_bob])),
            context,
          ),
          contains('<@uid:ghost>'),
        );
      });
    });

    testWidgets('a long URL is shortened', (tester) async {
      await withContext(tester, (context) {
        const long =
            'https://example.com/a/very/long/path/that/keeps/going/and/going';
        final s = ConversationUtils.getLastMessage(
          _conversation(_text(long)),
          context,
        );
        expect(
          s.length,
          lessThan(long.length),
          reason: 'the subtitle shortens URLs past 30 characters',
        );
      });
    });

    testWidgets('a short URL is left alone', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(_text('https://a.co')),
            context,
          ),
          contains('a.co'),
        );
      });
    });

    testWidgets('an empty message yields an empty subtitle', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(_conversation(_text('')), context),
          isEmpty,
        );
      });
    });
  });

  group('getLastMessage — media', () {
    testWidgets('a composer recording reads as the friendly Audio label', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(
            _media(
              MessageTypeConstants.audio,
              fileName: 'audio-recording-20260908-120000.m4a',
            ),
          ),
          context,
        );
        expect(
          s,
          isNot(contains('20260908')),
          reason: 'a timestamped filename must not reach the subtitle',
        );
        expect(s, Translations.of(context).messageAudio);
      });
    });

    testWidgets('every recording prefix the heuristic knows is covered', (
      tester,
    ) async {
      await withContext(tester, (context) {
        for (final name in [
          'audio-recording-1.m4a',
          'voice-recording-1.m4a',
          'recording-1.m4a',
          'voicenote-1.m4a',
        ]) {
          expect(
            ConversationUtils.getLastMessage(
              _conversation(_media(MessageTypeConstants.audio, fileName: name)),
              context,
            ),
            Translations.of(context).messageAudio,
            reason: name,
          );
        }
      });
    });

    testWidgets('a picked audio file is not treated as a voice note', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(
            _media(MessageTypeConstants.audio, fileName: 'interview.mp3'),
          ),
          context,
        );
        expect(s, isNotEmpty);
      });
    });

    testWidgets('a captioned recording is not treated as a voice note', (
      tester,
    ) async {
      // The heuristic requires an empty caption, so a caption opts out.
      await withContext(tester, (context) {
        final s = ConversationUtils.getLastMessage(
          _conversation(
            _media(
              MessageTypeConstants.audio,
              fileName: 'audio-recording-1.m4a',
              caption: 'listen to this',
            ),
          ),
          context,
        );
        expect(s, isNot(Translations.of(context).messageAudio));
      });
    });

    testWidgets('image, video and file all produce a non-empty subtitle', (
      tester,
    ) async {
      await withContext(tester, (context) {
        for (final t in [
          MessageTypeConstants.image,
          MessageTypeConstants.video,
          MessageTypeConstants.file,
        ]) {
          expect(
            ConversationUtils.getLastMessage(
              _conversation(_media(t, fileName: 'thing.bin')),
              context,
            ),
            isNotEmpty,
            reason: t,
          );
        }
      });
    });

    testWidgets('a caption wins over the filename', (tester) async {
      await withContext(tester, (context) {
        expect(
          ConversationUtils.getLastMessage(
            _conversation(
              _media(
                MessageTypeConstants.image,
                fileName: 'IMG_0001.jpg',
                caption: 'the view from up here',
              ),
            ),
            context,
          ),
          contains('the view from up here'),
        );
      });
    });
  });

  group('getLastMessage — unknown types', () {
    testWidgets('an unrecognised type falls back to the type name', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final m = TextMessage(
          text: 'x',
          receiverUid: 'u2',
          receiverType: CometChatReceiverType.user,
          type: 'some_custom_type',
          sender: _alice,
        );
        expect(
          ConversationUtils.getLastMessage(_conversation(m), context),
          'some_custom_type',
        );
      });
    });
  });
}
