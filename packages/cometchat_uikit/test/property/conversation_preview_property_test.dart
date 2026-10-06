/// Properties of the conversation-list preview: the last-message subtitle
/// text, and where a conversation lands among pinned tiers.
///
///   flutter test test/property/conversation_preview_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/conversation_tier_ordering.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/conversation_utils.dart'
    as chat_ui;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

final _peer = User(uid: 'peer', name: 'Peer');
final _group = Group(
  guid: 'g1',
  name: 'Group',
  type: GroupTypeConstants.public,
);

const _markers = ['*', '**', '_', '__', '~~', '`', '> ', '- ', '# '];

Attachment _genAttachment(Random r) {
  final c = genMimeCase(r);
  return Attachment(
    'https://cdn.example/${c.fileName}',
    c.fileName,
    c.fileExtension,
    c.mime,
    1,
  );
}

/// A message of a random class / category / type, as the SDK would build it.
BaseMessage _genMessage(Random r) {
  final toGroup = r.nextBool();
  final receiverType = toGroup
      ? CometChatReceiverType.group
      : CometChatReceiverType.user;
  final sender = r.nextBool() ? _peer : User(uid: 'me', name: 'Me');

  switch (r.nextInt(6)) {
    case 0:
      return TextMessage(
        text: genMarkdownish(r, markers: _markers),
        type: MessageTypeConstants.text,
        category: MessageCategoryConstants.message,
        receiverUid: 'x',
        receiverType: receiverType,
        sender: sender,
      );
    case 1:
      final attachments = List.generate(r.nextInt(5), (_) => _genAttachment(r));
      return MediaMessage(
        type: r.pick([
          MessageTypeConstants.image,
          MessageTypeConstants.video,
          MessageTypeConstants.audio,
          MessageTypeConstants.file,
        ]),
        category: MessageCategoryConstants.message,
        receiverUid: 'x',
        receiverType: receiverType,
        sender: sender,
        caption: r.pick([null, '', '   ', genPlainWords(r, maxWords: 3)]),
        attachment: attachments.isEmpty ? null : attachments.first,
        attachments: r.nextBool() ? attachments : null,
      );
    case 2:
      return CustomMessage(
        type: r.pick([
          ExtensionType.extensionPoll,
          ExtensionType.sticker,
          ExtensionType.document,
          ExtensionType.whiteboard,
          MessageTypeConstants.meeting,
          'x${genAlnum(r)}',
        ]),
        category: MessageCategoryConstants.custom,
        customData: const {},
        receiverUid: 'x',
        receiverType: receiverType,
        sender: sender,
      );
    case 3:
      return cc.Action(
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        message: '${genAlnum(r)} joined',
        action: r.pick([
          'joined',
          'left',
          'kicked',
          'banned',
          'added',
          'scopeChanged',
        ]),
        actionBy: _peer,
        actionOn: User(uid: 'other', name: 'Other'),
        receiverUid: 'g1',
        receiverType: CometChatReceiverType.group,
        sender: sender,
      );
    case 4:
      return Call(
        type: r.pick([MessageTypeConstants.audio, MessageTypeConstants.video]),
        category: MessageCategoryConstants.call,
        callStatus: r.pick([
          CallStatusConstants.initiated,
          CallStatusConstants.ongoing,
          CallStatusConstants.rejected,
          CallStatusConstants.cancelled,
          CallStatusConstants.busy,
          CallStatusConstants.unanswered,
          CallStatusConstants.ended,
          'x${genAlnum(r)}',
        ]),
        callInitiator: r.pick([
          _peer,
          User(uid: 'me', name: 'Me'),
          _group,
          null,
        ]),
        callReceiver: _peer,
        receiverUid: 'x',
        receiverType: receiverType,
        sender: sender,
      );
    default:
      // A category this build has never heard of.
      return TextMessage(
        text: genAlnum(r),
        type: 'x${genAlnum(r)}',
        category: 'x${genAlnum(r)}',
        receiverUid: 'x',
        receiverType: receiverType,
        sender: sender,
      );
  }
}

Conversation _conversationWith(BaseMessage? last, {bool group = false}) =>
    Conversation(
      conversationId: 'c1',
      conversationType: group ? ConversationType.group : ConversationType.user,
      conversationWith: group ? _group : _peer,
      lastMessage: last,
    );

String _describe(BaseMessage m) =>
    '${m.runtimeType}(category: ${m.category}, type: ${m.type}, '
    '${m is TextMessage ? 'text: ${show(m.text)}' : ''}'
    '${m is MediaMessage ? 'caption: ${show(m.caption)}, attachments: ${AttachmentUtils.attachmentsOf(m).length}' : ''}'
    '${m is Call ? 'status: ${m.callStatus}' : ''})';

Conversation _genRow(Random r, int index) => Conversation(
  conversationId: 'row_$index',
  conversationType: ConversationType.user,
  conversationWith: _peer,
  pinnedAt: r.chance(0.6) ? DateTime(2030, 1, 1 + r.nextInt(20)) : null,
  pinnedBy: r.pick([
    null,
    'me',
    ConversationTierOrdering.appSystemPinner,
    'someone',
  ]),
);

void main() {
  setUp(() => CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me'));
  tearDown(() => CometChatUIKit.loggedInUser = null);

  testWidgets('every message class, category and type produces a non-empty '
      'preview without throwing', (tester) async {
    final context = await pumpContext(tester);

    forAll(
      _genMessage,
      (message) {
        for (final group in [false, true]) {
          final preview = ConversationUtils.getLastConversationMessage(
            _conversationWith(message, group: group),
            context,
          );
          expect(preview.trim(), isNotEmpty);
        }
      },
      cases: 400,
      describe: _describe,
    );
  });

  testWidgets('a text preview shows names instead of mention tokens and '
      'words instead of markdown, keeping every word in order', (tester) async {
    final context = await pumpContext(tester);

    forAll(
      (r) {
        final words = List.generate(
          r.between(1, 5),
          (_) => genAlnum(r, alphabet: kContentLetters),
        );
        final wrap = r.pick(['**', '__', '~~', '`', '']);
        return (words, wrap, r.nextBool());
      },
      (input) {
        final (words, wrap, mention) = input;
        final text = [
          for (final w in words) '$wrap$w$wrap',
          if (mention) '<@uid:peer>',
        ].join(' ');
        final message = TextMessage(
          text: text,
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          receiverUid: 'x',
          receiverType: CometChatReceiverType.user,
        )..mentionedUsers = [if (mention) _peer];

        expect(
          ConversationUtils.getLastConversationMessage(
            _conversationWith(message),
            context,
          ),
          [...words, if (mention) '@Peer'].join(' '),
        );
      },
    );
  });

  testWidgets('a media preview is the caption when there is one, else a '
      'count for several attachments, else the file name, else the type '
      'label', (tester) async {
    final context = await pumpContext(tester);

    forAll(
      _genMessage,
      (message) {
        if (message is! MediaMessage) return; // ~1 in 6 of the 600 cases
        final preview = ConversationUtils.getLastConversationMessage(
          _conversationWith(message),
          context,
        );
        final caption = message.caption?.trim() ?? '';
        final count = AttachmentUtils.attachmentsOf(message).length;
        final visual =
            message.type == MessageTypeConstants.image ||
            message.type == MessageTypeConstants.video;

        if (caption.isNotEmpty && (visual || count <= 1)) {
          expect(preview, caption);
        } else if (caption.isNotEmpty) {
          expect(preview, startsWith('$caption · $count '));
        } else if (count > 1) {
          expect(preview, startsWith('$count '));
        } else if (message.attachment != null) {
          expect(
            preview,
            anyOf(
              message.attachment!.fileName,
              Translations.of(context).messageAudio,
            ),
          );
        } else {
          expect(
            preview,
            AttachmentUtils.singularSubtitleFor(message.type, context),
          );
        }
      },
      cases: 600,
      describe: _describe,
    );
  });

  testWidgets('a media message typed "text" crashes the preview instead of '
      'falling back to a label', (tester) async {
    final context = await pumpContext(tester);

    // FINDING: `ConversationUtils.getLastMessage` switches on the message
    // `type` STRING and then hard-casts (`message as TextMessage`). `type` is
    // sender-controlled — any client can send a MediaMessage or CustomMessage
    // whose type is "text" — and the result is a TypeError thrown while the
    // conversation LIST is building, i.e. one hostile message breaks the
    // recipient's whole list. Expected: an `is TextMessage` check with the
    // type string as fallback, as the `default:` branch already does.
    forAll((r) => (genPlainWords(r, maxWords: 3), r.nextInt(3)), (input) {
      final (caption, attachments) = input;
      final hostile = MediaMessage(
        type: MessageTypeConstants.text,
        category: MessageCategoryConstants.message,
        receiverUid: 'x',
        receiverType: CometChatReceiverType.user,
        caption: caption,
        attachments: List.generate(
          attachments,
          (_) => _genAttachment(Random(1)),
        ),
      );
      expect(
        () => ConversationUtils.getLastConversationMessage(
          _conversationWith(hostile),
          context,
        ),
        throwsA(isA<TypeError>()),
      );
    }, cases: 30);
  });

  testWidgets('the conversations-module preview is total over message '
      'classes, and "deleted" / "no message" always win', (tester) async {
    final context = await pumpContext(tester);
    final t = Translations.of(context);

    expect(
      chat_ui.ConversationUtils.getLastMessageText(context, null),
      t.tapToStartConversation,
    );
    forAll(
      _genMessage,
      (message) {
        final live = chat_ui.ConversationUtils.getLastMessageText(
          context,
          message,
        );
        if (message is TextMessage) expect(live, message.text);
        if (message is MediaMessage || message is CustomMessage) {
          expect(live.trim(), isNotEmpty);
        }

        message.deletedAt = DateTime(2030);
        expect(
          chat_ui.ConversationUtils.getLastMessageText(context, message),
          t.thisMessageDeleted,
        );
        expect(
          chat_ui.ConversationUtils.getMessagePrefix(context, message, 'me'),
          message.receiverType != CometChatReceiverType.group
              ? ''
              : message.sender?.uid == 'me'
              ? '${t.you}: '
              : '${message.sender?.name}: ',
        );
      },
      cases: 300,
      describe: _describe,
    );
  });

  test('inserting a row at the top of its tier keeps system pins above user '
      'pins above normal rows, and puts it first within its own tier', () {
    forAll(
      (r) {
        final rows = List.generate(r.nextInt(12), (i) => _genRow(r, i))
          ..sort(
            (a, b) => ConversationTierOrdering.tierOf(
              a,
            ).compareTo(ConversationTierOrdering.tierOf(b)),
          );
        return (rows, _genRow(r, 99));
      },
      (input) {
        final (rows, incoming) = input;
        final tier = ConversationTierOrdering.tierOf(incoming);
        final index = ConversationTierOrdering.tierTopIndex(tier, rows);

        expect(index, inInclusiveRange(0, rows.length));
        final after = [...rows]..insert(index, incoming);
        final tiers = after.map(ConversationTierOrdering.tierOf).toList();
        expect(tiers, [...tiers]..sort(), reason: 'tiers stay contiguous');
        expect(
          after.indexWhere((c) => ConversationTierOrdering.tierOf(c) == tier),
          index,
          reason: 'first of its tier',
        );
        // `pinnedAt` alone decides whether a row is pinned.
        if (incoming.pinnedAt == null) {
          expect(tier, ConversationTierOrdering.normalTier);
        }
      },
      describe: (i) =>
          '${i.$1.map(ConversationTierOrdering.tierOf).toList()} + ${ConversationTierOrdering.tierOf(i.$2)}',
    );
  });
}
