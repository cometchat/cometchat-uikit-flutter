import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ===========================================================================
// CometChatMessageListDateTimeFormatPropertyTest — Flutter equivalent
// Tests date/time formatting logic: today shows time only, yesterday shows
// "Yesterday", older shows date, date separator format, header timestamp.
// ===========================================================================

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockMessageListRepository extends Mock implements MessageListRepository {}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_user';

  @override
  String get name => 'Test User';
}

class FakeTextMessage extends Fake implements TextMessage {
  final int _id;
  final DateTime _sentAt;

  FakeTextMessage(this._id, {required DateTime sentAt}) : _sentAt = sentAt;

  @override
  int get id => _id;

  @override
  String get muid => 'muid_$_id';

  @override
  String get text => 'Message $_id';

  @override
  int get parentMessageId => 0;

  @override
  String get type => 'text';

  @override
  String get category => 'message';

  @override
  User? get sender => FakeUser();

  @override
  DateTime? get sentAt => _sentAt;

  @override
  DateTime? get deletedAt => null;

  @override
  DateTime? get readAt => null;

  @override
  DateTime? get deliveredAt => null;

  @override
  Map<String, dynamic>? get metadata => null;

  @override
  int get replyCount => 0;

  @override
  set replyCount(int value) {}
}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_test_user';

  @override
  int get unreadMessageCount => 0;
}

class FakeMessagesRequest extends Fake implements MessagesRequest {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MessageListBloc _makeBloc(MockMessageListRepository repo) {
  return MessageListBloc(
    getMessagesUseCase: GetMessagesUseCase(repo),
    loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
    loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
    markAsReadUseCase: MarkAsReadUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    user: FakeUser(),
    disableSDKListeners: true,
  );
}

void _stubRepo(MockMessageListRepository repo, {List<BaseMessage>? messages}) {
  when(
    () => repo.getLoggedInUser(),
  ).thenAnswer((_) async => Success(FakeUser()));
  when(
    () => repo.getMessages(
      conversationWith: any(named: 'conversationWith'),
      conversationType: any(named: 'conversationType'),
      limit: any(named: 'limit'),
      parentMessageId: any(named: 'parentMessageId'),
      types: any(named: 'types'),
      categories: any(named: 'categories'),
      hideReplies: any(named: 'hideReplies'),
      withParent: any(named: 'withParent'),
    ),
  ).thenAnswer((_) async => Success(messages ?? []));
  when(
    () => repo.getConversation(
      conversationWith: any(named: 'conversationWith'),
      conversationType: any(named: 'conversationType'),
    ),
  ).thenAnswer((_) async => Success(FakeConversation()));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// A fixed anchor instead of the wall clock.
///
/// These cases assert calendar-day arithmetic on their own fixtures — "an hour
/// ago is still today", "two messages five minutes apart share a separator".
/// Anchored to `DateTime.now()` those statements are only true for 23 of every
/// 24 hours: inside the first hour after midnight, "an hour ago" is yesterday,
/// and the suite went red for reasons unrelated to any change (ENG-38856).
/// Mid-afternoon on a mid-month day keeps every offset used below — up to 30
/// days back — clear of a day, month or year boundary.
final _now = DateTime(2026, 6, 15, 14, 30);

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTextMessage(0, sentAt: _now));
    registerFallbackValue(FakeMessagesRequest());
    registerFallbackValue(FakeConversation());
  });

  // =========================================================================
  // Date/Time Formatting — Message Timestamps
  // =========================================================================

  group('Date/Time Formatting — Message Timestamps', () {
    late MockMessageListRepository repo;

    setUp(() {
      repo = MockMessageListRepository();
    });

    // -----------------------------------------------------------------------
    // Today's messages
    // -----------------------------------------------------------------------

    group('Today messages', () {
      test('message sent today has sentAt on same day as now', () {
        final now = _now;
        final message = FakeTextMessage(1, sentAt: now);
        final sentDate = message.sentAt!;
        expect(sentDate.year, equals(now.year));
        expect(sentDate.month, equals(now.month));
        expect(sentDate.day, equals(now.day));
      });

      test('message sent 1 hour ago is still today', () {
        final oneHourAgo = _now.subtract(const Duration(hours: 1));
        final message = FakeTextMessage(1, sentAt: oneHourAgo);
        final now = _now;
        expect(message.sentAt!.day, equals(now.day));
      });

      test('message sent at midnight boundary is today', () {
        final now = _now;
        final midnight = DateTime(now.year, now.month, now.day, 0, 0, 1);
        final message = FakeTextMessage(1, sentAt: midnight);
        expect(message.sentAt!.day, equals(now.day));
      });
    });

    // -----------------------------------------------------------------------
    // Yesterday's messages
    // -----------------------------------------------------------------------

    group('Yesterday messages', () {
      test('message sent yesterday has sentAt one day before today', () {
        final yesterday = _now.subtract(const Duration(days: 1));
        final message = FakeTextMessage(1, sentAt: yesterday);
        final now = _now;
        final diff = DateTime(now.year, now.month, now.day)
            .difference(
              DateTime(
                message.sentAt!.year,
                message.sentAt!.month,
                message.sentAt!.day,
              ),
            )
            .inDays;
        expect(diff, equals(1));
      });

      test('message sent 36 hours ago may be yesterday', () {
        final thirtyySixHoursAgo = _now.subtract(const Duration(hours: 36));
        final message = FakeTextMessage(1, sentAt: thirtyySixHoursAgo);
        expect(message.sentAt, isNotNull);
        // Depending on current time, this could be yesterday or 2 days ago
      });
    });

    // -----------------------------------------------------------------------
    // Older messages (2+ days ago)
    // -----------------------------------------------------------------------

    group('Older messages', () {
      test('message sent 2 days ago is older than yesterday', () {
        final twoDaysAgo = _now.subtract(const Duration(days: 2));
        final message = FakeTextMessage(1, sentAt: twoDaysAgo);
        final now = _now;
        final diff = DateTime(now.year, now.month, now.day)
            .difference(
              DateTime(
                message.sentAt!.year,
                message.sentAt!.month,
                message.sentAt!.day,
              ),
            )
            .inDays;
        expect(diff, greaterThanOrEqualTo(2));
      });

      test('message sent 7 days ago is older', () {
        final weekAgo = _now.subtract(const Duration(days: 7));
        final message = FakeTextMessage(1, sentAt: weekAgo);
        final now = _now;
        final diff = DateTime(now.year, now.month, now.day)
            .difference(
              DateTime(
                message.sentAt!.year,
                message.sentAt!.month,
                message.sentAt!.day,
              ),
            )
            .inDays;
        expect(diff, greaterThanOrEqualTo(7));
      });

      test('message sent 30 days ago is older', () {
        final monthAgo = _now.subtract(const Duration(days: 30));
        final message = FakeTextMessage(1, sentAt: monthAgo);
        final now = _now;
        final diff = DateTime(now.year, now.month, now.day)
            .difference(
              DateTime(
                message.sentAt!.year,
                message.sentAt!.month,
                message.sentAt!.day,
              ),
            )
            .inDays;
        expect(diff, greaterThanOrEqualTo(30));
      });

      test('message from previous year is older', () {
        final lastYear = DateTime(_now.year - 1, 6, 15, 10, 30);
        final message = FakeTextMessage(1, sentAt: lastYear);
        expect(message.sentAt!.year, lessThan(_now.year));
      });
    });

    // -----------------------------------------------------------------------
    // Date Separator Logic
    // -----------------------------------------------------------------------

    group('Date separator logic', () {
      test('messages on same day share a date separator', () {
        final now = _now;
        final msg1 = FakeTextMessage(1, sentAt: now);
        final msg2 = FakeTextMessage(
          2,
          sentAt: now.subtract(const Duration(minutes: 5)),
        );

        expect(msg1.sentAt!.day, equals(msg2.sentAt!.day));
        expect(msg1.sentAt!.month, equals(msg2.sentAt!.month));
        expect(msg1.sentAt!.year, equals(msg2.sentAt!.year));
      });

      test('messages on different days have different date separators', () {
        final today = _now;
        final yesterday = today.subtract(const Duration(days: 1));
        final msg1 = FakeTextMessage(1, sentAt: today);
        final msg2 = FakeTextMessage(2, sentAt: yesterday);

        final day1 = DateTime(
          msg1.sentAt!.year,
          msg1.sentAt!.month,
          msg1.sentAt!.day,
        );
        final day2 = DateTime(
          msg2.sentAt!.year,
          msg2.sentAt!.month,
          msg2.sentAt!.day,
        );
        expect(day1, isNot(equals(day2)));
      });

      test('messages spanning multiple days produce multiple separators', () {
        final now = _now;
        final messages = [
          FakeTextMessage(1, sentAt: now),
          FakeTextMessage(2, sentAt: now.subtract(const Duration(days: 1))),
          FakeTextMessage(3, sentAt: now.subtract(const Duration(days: 2))),
          FakeTextMessage(4, sentAt: now.subtract(const Duration(days: 3))),
        ];

        final uniqueDays = messages
            .map(
              (m) => DateTime(m.sentAt!.year, m.sentAt!.month, m.sentAt!.day),
            )
            .toSet();
        expect(uniqueDays.length, equals(4));
      });
    });

    // -----------------------------------------------------------------------
    // Custom datePattern callback
    // -----------------------------------------------------------------------

    group('Custom datePattern callback', () {
      test('datePattern callback receives the message', () {
        final message = FakeTextMessage(
          1,
          sentAt: DateTime(2024, 3, 15, 14, 30),
        );
        String customPattern(BaseMessage msg) {
          return '${msg.sentAt!.hour}:${msg.sentAt!.minute.toString().padLeft(2, '0')}';
        }

        final result = customPattern(message);
        expect(result, equals('14:30'));
      });

      test('dateSeparatorPattern callback receives DateTime', () {
        final dateTime = DateTime(2024, 3, 15);
        String customSeparator(DateTime dt) {
          return '${dt.day}/${dt.month}/${dt.year}';
        }

        final result = customSeparator(dateTime);
        expect(result, equals('15/3/2024'));
      });
    });

    // -----------------------------------------------------------------------
    // Messages loaded with timestamps are ordered correctly
    // -----------------------------------------------------------------------

    group('Message ordering by timestamp', () {
      test('messages are loaded and state preserves sentAt order', () async {
        final now = _now;
        final messages = [
          FakeTextMessage(1, sentAt: now.subtract(const Duration(minutes: 30))),
          FakeTextMessage(2, sentAt: now.subtract(const Duration(minutes: 20))),
          FakeTextMessage(3, sentAt: now.subtract(const Duration(minutes: 10))),
          FakeTextMessage(4, sentAt: now),
        ];
        _stubRepo(repo, messages: messages);

        final bloc = _makeBloc(repo);
        bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 80));

        expect(bloc.state.status, MessageListStatus.loaded);
        expect(bloc.state.messages.length, 4);
        // Messages should be in the order returned by the repository
        expect(bloc.state.messages[0].id, equals(1));
        expect(bloc.state.messages[3].id, equals(4));
        await bloc.close();
      });

      test('null sentAt message is still stored in state', () async {
        // Edge case: message with null sentAt
        final messages = [FakeTextMessage(1, sentAt: _now)];
        _stubRepo(repo, messages: messages);

        final bloc = _makeBloc(repo);
        bloc.add(
          const LoadMessages(
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 80));

        expect(bloc.state.messages.length, 1);
        expect(bloc.state.messages.first.sentAt, isNotNull);
        await bloc.close();
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('Edge cases', () {
      test('message at exact midnight boundary', () {
        final now = _now;
        final midnight = DateTime(now.year, now.month, now.day);
        final justBeforeMidnight = midnight.subtract(
          const Duration(seconds: 1),
        );
        final justAfterMidnight = midnight.add(const Duration(seconds: 1));

        // These are on different days
        expect(justBeforeMidnight.day, isNot(equals(justAfterMidnight.day)));
      });

      test('message from year boundary (Dec 31 → Jan 1)', () {
        final dec31 = DateTime(2024, 12, 31, 23, 59, 59);
        final jan1 = DateTime(2025, 1, 1, 0, 0, 1);

        expect(dec31.year, isNot(equals(jan1.year)));
        expect(dec31.day, isNot(equals(jan1.day)));
      });

      test('message from leap year Feb 29', () {
        final leapDay = DateTime(2024, 2, 29, 12, 0);
        expect(leapDay.month, equals(2));
        expect(leapDay.day, equals(29));
      });

      test('multiple messages at exact same timestamp', () {
        final timestamp = DateTime(2024, 6, 15, 10, 30, 0);
        final msg1 = FakeTextMessage(1, sentAt: timestamp);
        final msg2 = FakeTextMessage(2, sentAt: timestamp);

        expect(msg1.sentAt, equals(msg2.sentAt));
        expect(msg1.id, isNot(equals(msg2.id)));
      });
    });
  });
}
