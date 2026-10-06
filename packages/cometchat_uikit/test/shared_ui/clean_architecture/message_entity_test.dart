/// Behaviour tests for `MessageEntity` and its two enum extensions.
///
/// The entity is pure Dart (Equatable, no SDK), so everything here is an
/// input → asserted-output check. The parts worth pinning are:
///   * `copyWith` — seventeen `??` fall-throughs, where a single copy/paste
///     slip (`senderId: senderId ?? this.senderName`) silently corrupts a
///     field. Each field is therefore changed *alone* and every other field
///     asserted unchanged, via Equatable identity against an expected value.
///   * the derived getters, including their null/empty edges.
///   * `displayName` on both enums — a switch per case, where a wrong string
///     is invisible until it reaches a user.
///
///   flutter test test/shared_ui/clean_architecture/message_entity_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fully populated entity: every optional field is non-null, so a
/// `copyWith` that drops one is visible as a change to null.
const MessageEntity _full = MessageEntity(
  id: 'm1',
  text: 'hello',
  senderId: 'u1',
  senderName: 'Alice',
  senderAvatar: 'https://example.test/a.png',
  receiverId: 'u2',
  receiverName: 'Bob',
  timestamp: 1788787200000,
  type: MessageType.image,
  status: MessageStatus.delivered,
  isDeleted: true,
  deletedAt: '2026-09-08T10:00:00Z',
  attachmentUrls: ['https://example.test/1.png'],
  metadata: {'k': 'v'},
  parentMessageId: 'p1',
  replyCount: 3,
  reactionCount: 4,
);

void main() {
  // -------------------------------------------------------------------------
  group('MessageEntity constructor defaults', () {
    test('optional fields default to null and the documented values', () {
      const m = MessageEntity(
        id: 'm',
        text: 't',
        senderId: 's',
        senderName: 'S',
        timestamp: 1,
      );
      expect(m.senderAvatar, isNull);
      expect(m.receiverId, isNull);
      expect(m.receiverName, isNull);
      expect(m.deletedAt, isNull);
      expect(m.attachmentUrls, isNull);
      expect(m.metadata, isNull);
      expect(m.parentMessageId, isNull);
      expect(m.replyCount, isNull);
      expect(m.reactionCount, isNull);
      expect(m.type, MessageType.text);
      expect(m.status, MessageStatus.sent);
      expect(m.isDeleted, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('MessageEntity.copyWith', () {
    test('with no arguments returns a value equal to the original', () {
      expect(_full.copyWith(), _full);
      // ...and it really is a new object, not the same instance returned.
      expect(identical(_full.copyWith(), _full), isFalse);
    });

    // Each entry changes exactly one field and states the entity the copy
    // must equal. Equality is Equatable over all seventeen props, so a
    // `??` wired to the wrong field fails here.
    final cases = <String, List<MessageEntity>>{
      'id': [_full.copyWith(id: 'm2'), _fullWith(id: 'm2')],
      'text': [_full.copyWith(text: 'bye'), _fullWith(text: 'bye')],
      'senderId': [_full.copyWith(senderId: 'u9'), _fullWith(senderId: 'u9')],
      'senderName': [
        _full.copyWith(senderName: 'Zoe'),
        _fullWith(senderName: 'Zoe'),
      ],
      'senderAvatar': [
        _full.copyWith(senderAvatar: 'b.png'),
        _fullWith(senderAvatar: 'b.png'),
      ],
      'receiverId': [
        _full.copyWith(receiverId: 'u3'),
        _fullWith(receiverId: 'u3'),
      ],
      'receiverName': [
        _full.copyWith(receiverName: 'Carol'),
        _fullWith(receiverName: 'Carol'),
      ],
      'timestamp': [_full.copyWith(timestamp: 42), _fullWith(timestamp: 42)],
      'type': [
        _full.copyWith(type: MessageType.video),
        _fullWith(type: MessageType.video),
      ],
      'status': [
        _full.copyWith(status: MessageStatus.read),
        _fullWith(status: MessageStatus.read),
      ],
      'isDeleted': [
        _full.copyWith(isDeleted: false),
        _fullWith(isDeleted: false),
      ],
      'deletedAt': [
        _full.copyWith(deletedAt: 'later'),
        _fullWith(deletedAt: 'later'),
      ],
      'attachmentUrls': [
        _full.copyWith(attachmentUrls: const ['x']),
        _fullWith(attachmentUrls: const ['x']),
      ],
      'metadata': [
        _full.copyWith(metadata: const {'k2': 1}),
        _fullWith(metadata: const {'k2': 1}),
      ],
      'parentMessageId': [
        _full.copyWith(parentMessageId: 'p2'),
        _fullWith(parentMessageId: 'p2'),
      ],
      'replyCount': [_full.copyWith(replyCount: 9), _fullWith(replyCount: 9)],
      'reactionCount': [
        _full.copyWith(reactionCount: 9),
        _fullWith(reactionCount: 9),
      ],
    };

    cases.forEach((field, pair) {
      test('changes only $field', () {
        expect(pair[0], pair[1]);
      });
    });

    test('a null argument keeps the existing value, it does not clear it', () {
      // This is the documented shape of `??`: copyWith cannot null a field.
      final cleared = _full.copyWith(
        senderAvatar: null,
        receiverId: null,
        deletedAt: null,
        attachmentUrls: null,
        metadata: null,
        parentMessageId: null,
        replyCount: null,
        reactionCount: null,
      );
      expect(cleared, _full);
    });

    test('changing two fields at once applies both', () {
      final m = _full.copyWith(text: 'edited', status: MessageStatus.error);
      expect(m.text, 'edited');
      expect(m.status, MessageStatus.error);
      expect(m, _fullWith(text: 'edited', status: MessageStatus.error));
    });
  });

  // -------------------------------------------------------------------------
  group('MessageEntity.props / equality', () {
    test('two entities with identical fields are equal and hash alike', () {
      expect(_full, _full.copyWith());
      expect(_full.hashCode, _full.copyWith().hashCode);
    });

    test('props lists every field, so any single change breaks equality', () {
      for (final changed in [
        _full.copyWith(id: 'other'),
        _full.copyWith(text: 'other'),
        _full.copyWith(senderId: 'other'),
        _full.copyWith(senderName: 'other'),
        _full.copyWith(senderAvatar: 'other'),
        _full.copyWith(receiverId: 'other'),
        _full.copyWith(receiverName: 'other'),
        _full.copyWith(timestamp: 7),
        _full.copyWith(type: MessageType.custom),
        _full.copyWith(status: MessageStatus.sending),
        _full.copyWith(isDeleted: false),
        _full.copyWith(deletedAt: 'other'),
        _full.copyWith(attachmentUrls: const ['other']),
        _full.copyWith(metadata: const {'other': true}),
        _full.copyWith(parentMessageId: 'other'),
        _full.copyWith(replyCount: 99),
        _full.copyWith(reactionCount: 99),
      ]) {
        expect(changed, isNot(_full));
      }
      expect(_full.props.length, 17);
    });
  });

  // -------------------------------------------------------------------------
  group('derived getters', () {
    test('isRecent is true within the hour and false beyond it', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(_full.copyWith(timestamp: now).isRecent, isTrue);
      expect(
        _full
            .copyWith(timestamp: now - Duration.millisecondsPerMinute * 59)
            .isRecent,
        isTrue,
      );
      expect(
        _full.copyWith(timestamp: now - Duration.millisecondsPerHour).isRecent,
        isFalse,
      );
      expect(
        _full
            .copyWith(timestamp: now - Duration.millisecondsPerHour * 2)
            .isRecent,
        isFalse,
      );
      // A future timestamp gives a negative difference, which is < an hour.
      expect(
        _full
            .copyWith(timestamp: now + Duration.millisecondsPerHour * 5)
            .isRecent,
        isTrue,
      );
    });

    test('isFromToday compares local Y/M/D, not elapsed time', () {
      final now = DateTime.now();
      expect(
        _full.copyWith(timestamp: now.millisecondsSinceEpoch).isFromToday,
        isTrue,
      );
      // Noon today is the same calendar day however the test is scheduled.
      final noon = DateTime(now.year, now.month, now.day, 12);
      expect(
        _full.copyWith(timestamp: noon.millisecondsSinceEpoch).isFromToday,
        isTrue,
      );
      // 400 days away cannot collide with today in any zone.
      final past = now.subtract(const Duration(days: 400));
      expect(
        _full.copyWith(timestamp: past.millisecondsSinceEpoch).isFromToday,
        isFalse,
      );
      final future = now.add(const Duration(days: 400));
      expect(
        _full.copyWith(timestamp: future.millisecondsSinceEpoch).isFromToday,
        isFalse,
      );
    });

    test('isReply requires a non-null, non-empty parent id', () {
      expect(_full.isReply, isTrue);
      expect(_full.copyWith(parentMessageId: '').isReply, isFalse);
      expect(_bare().isReply, isFalse);
    });

    test('hasReactions requires a count strictly above zero', () {
      expect(_full.hasReactions, isTrue);
      expect(_full.copyWith(reactionCount: 0).hasReactions, isFalse);
      expect(_full.copyWith(reactionCount: -1).hasReactions, isFalse);
      expect(_bare().hasReactions, isFalse);
    });

    test('hasAttachments requires a non-null, non-empty list', () {
      expect(_full.hasAttachments, isTrue);
      expect(_full.copyWith(attachmentUrls: const []).hasAttachments, isFalse);
      expect(_bare().hasAttachments, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('MessageTypeExt', () {
    test('displayName maps every case to its capitalised label', () {
      expect(MessageType.text.displayName, 'Text');
      expect(MessageType.image.displayName, 'Image');
      expect(MessageType.video.displayName, 'Video');
      expect(MessageType.audio.displayName, 'Audio');
      expect(MessageType.file.displayName, 'File');
      expect(MessageType.location.displayName, 'Location');
      expect(MessageType.custom.displayName, 'Custom');
    });

    test('every enum value has a distinct displayName', () {
      final names = MessageType.values.map((e) => e.displayName).toSet();
      expect(names.length, MessageType.values.length);
    });

    test('isMedia covers image/video/audio/file and nothing else', () {
      expect(
        MessageType.values.where((t) => t.isMedia).toList(),
        // Enum declaration order, so the comparison is order-stable.
        const [
          MessageType.image,
          MessageType.video,
          MessageType.audio,
          MessageType.file,
        ],
      );
      expect(MessageType.text.isMedia, isFalse);
      expect(MessageType.location.isMedia, isFalse);
      expect(MessageType.custom.isMedia, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('MessageStatusExt', () {
    test('displayName maps every case to its capitalised label', () {
      expect(MessageStatus.sending.displayName, 'Sending');
      expect(MessageStatus.sent.displayName, 'Sent');
      expect(MessageStatus.delivered.displayName, 'Delivered');
      expect(MessageStatus.read.displayName, 'Read');
      expect(MessageStatus.error.displayName, 'Error');
    });

    test('every enum value has a distinct displayName', () {
      final names = MessageStatus.values.map((e) => e.displayName).toSet();
      expect(names.length, MessageStatus.values.length);
    });

    test('isFinal is true only for read and error', () {
      expect(MessageStatus.values.where((s) => s.isFinal).toList(), const [
        MessageStatus.read,
        MessageStatus.error,
      ]);
      expect(MessageStatus.sending.isFinal, isFalse);
      expect(MessageStatus.sent.isFinal, isFalse);
      expect(MessageStatus.delivered.isFinal, isFalse);
    });
  });
}

/// [_full] with the named fields overridden, built through the constructor
/// rather than `copyWith` so the expectation does not depend on the method
/// under test.
MessageEntity _fullWith({
  String id = 'm1',
  String text = 'hello',
  String senderId = 'u1',
  String senderName = 'Alice',
  String? senderAvatar = 'https://example.test/a.png',
  String? receiverId = 'u2',
  String? receiverName = 'Bob',
  int timestamp = 1788787200000,
  MessageType type = MessageType.image,
  MessageStatus status = MessageStatus.delivered,
  bool isDeleted = true,
  String? deletedAt = '2026-09-08T10:00:00Z',
  List<String>? attachmentUrls = const ['https://example.test/1.png'],
  Map<String, dynamic>? metadata = const {'k': 'v'},
  String? parentMessageId = 'p1',
  int? replyCount = 3,
  int? reactionCount = 4,
}) => MessageEntity(
  id: id,
  text: text,
  senderId: senderId,
  senderName: senderName,
  senderAvatar: senderAvatar,
  receiverId: receiverId,
  receiverName: receiverName,
  timestamp: timestamp,
  type: type,
  status: status,
  isDeleted: isDeleted,
  deletedAt: deletedAt,
  attachmentUrls: attachmentUrls,
  metadata: metadata,
  parentMessageId: parentMessageId,
  replyCount: replyCount,
  reactionCount: reactionCount,
);

/// The minimum entity: every optional left at its default.
MessageEntity _bare() => const MessageEntity(
  id: 'm',
  text: 't',
  senderId: 's',
  senderName: 'S',
  timestamp: 1,
);
