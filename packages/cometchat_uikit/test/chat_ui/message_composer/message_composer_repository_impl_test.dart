/// MessageComposerRepositoryImpl — the datasource → Result translation.
///
/// Every method has the same four-way shape: success, a
/// `MessageComposerDataSourceException` (carries its own code and original
/// exception), a `CometChatException` (message may be null, so the fallback
/// string matters), and any other throwable (wrapped only when it is an
/// Exception). This file pins all four for each method — the failure text is
/// what the composer surfaces to the user, so the exact string is behaviour.
///
/// Follows the fake-the-abstract-datasource pattern of
/// `test/chat_ui/groups/groups_repository_test.dart`. No SDK calls.
///
///   flutter test test/chat_ui/message_composer/message_composer_repository_impl_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/data/datasources/message_composer_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/data/repositories/message_composer_repository_impl.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

class MockDataSource extends Mock implements MessageComposerDataSource {}

class FakeTextMessage extends Fake implements TextMessage {
  FakeTextMessage([this._text = 'hi']);
  final String _text;
  @override
  String get text => _text;
}

class FakeMediaMessage extends Fake implements MediaMessage {}

class FakeCustomMessage extends Fake implements CustomMessage {}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'uid_1';
}

/// A throwable that is not an `Exception`, to exercise the
/// `e is Exception ? e : null` guard.
class _NotAnException implements Error {
  @override
  StackTrace? get stackTrace => null;
  @override
  String toString() => 'boom';
}

Failure _failure(Result<Object?> result) {
  expect(result.isFailure, isTrue, reason: 'expected a Failure');
  return result as Failure;
}

void main() {
  late MockDataSource source;
  late MessageComposerRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(FakeTextMessage());
    registerFallbackValue(FakeMediaMessage());
    registerFallbackValue(FakeCustomMessage());
  });

  setUp(() {
    source = MockDataSource();
    repo = MessageComposerRepositoryImpl(dataSource: source);
  });

  group('sendTextMessage', () {
    test('passes the datasource result straight through on success', () async {
      final sent = FakeTextMessage('sent');
      when(() => source.sendTextMessage(any())).thenAnswer((_) async => sent);

      final result = await repo.sendTextMessage(FakeTextMessage());

      expect(result.isSuccess, isTrue);
      expect((result as Success<TextMessage>).data, same(sent));
    });

    test(
      'a datasource exception keeps its own message, code and cause',
      () async {
        final cause = Exception('socket');
        when(() => source.sendTextMessage(any())).thenThrow(
          MessageComposerDataSourceException(
            message: 'datasource said no',
            code: 'DS_ERR',
            originalException: cause,
          ),
        );

        final failure = _failure(await repo.sendTextMessage(FakeTextMessage()));
        expect(failure.message, 'datasource said no');
        expect(failure.code, 'DS_ERR');
        expect(failure.exception, same(cause));
      },
    );

    test(
      'a CometChatException with a null message uses the fallback',
      () async {
        when(
          () => source.sendTextMessage(any()),
        ).thenThrow(CometChatException('ERR_CODE', 'details', null));

        final failure = _failure(await repo.sendTextMessage(FakeTextMessage()));
        expect(failure.message, 'Failed to send text message');
        expect(failure.code, 'ERR_CODE');
        expect(failure.exception, isA<CometChatException>());
      },
    );

    test('a CometChatException with a message keeps it', () async {
      when(
        () => source.sendTextMessage(any()),
      ).thenThrow(CometChatException('ERR_CODE', 'details', 'sdk says no'));

      expect(
        _failure(await repo.sendTextMessage(FakeTextMessage())).message,
        'sdk says no',
      );
    });

    test('a non-Exception throwable is described but not attached', () async {
      when(() => source.sendTextMessage(any())).thenThrow(_NotAnException());

      final failure = _failure(await repo.sendTextMessage(FakeTextMessage()));
      expect(failure.message, 'Failed to send text message: boom');
      expect(failure.exception, isNull);
    });
  });

  group('sendMediaMessage', () {
    test('returns the sent media message', () async {
      final sent = FakeMediaMessage();
      when(() => source.sendMediaMessage(any())).thenAnswer((_) async => sent);

      final result = await repo.sendMediaMessage(FakeMediaMessage());
      expect((result as Success<MediaMessage>).data, same(sent));
    });

    test('maps each failure kind to its own message', () async {
      when(() => source.sendMediaMessage(any())).thenThrow(
        const MessageComposerDataSourceException(
          message: 'upload failed',
          code: 'UPLOAD',
        ),
      );
      expect(
        _failure(await repo.sendMediaMessage(FakeMediaMessage())).message,
        'upload failed',
      );

      when(
        () => source.sendMediaMessage(any()),
      ).thenThrow(CometChatException('E', 'details', null));
      expect(
        _failure(await repo.sendMediaMessage(FakeMediaMessage())).message,
        'Failed to send media message',
      );

      when(() => source.sendMediaMessage(any())).thenThrow(_NotAnException());
      expect(
        _failure(await repo.sendMediaMessage(FakeMediaMessage())).message,
        'Failed to send media message: boom',
      );
    });
  });

  group('sendCustomMessage', () {
    test('returns the sent custom message', () async {
      final sent = FakeCustomMessage();
      when(() => source.sendCustomMessage(any())).thenAnswer((_) async => sent);

      final result = await repo.sendCustomMessage(FakeCustomMessage());
      expect((result as Success<CustomMessage>).data, same(sent));
    });

    test('maps each failure kind to its own message', () async {
      when(() => source.sendCustomMessage(any())).thenThrow(
        const MessageComposerDataSourceException(message: 'custom failed'),
      );
      expect(
        _failure(await repo.sendCustomMessage(FakeCustomMessage())).message,
        'custom failed',
      );

      when(
        () => source.sendCustomMessage(any()),
      ).thenThrow(CometChatException('E', 'details', null));
      expect(
        _failure(await repo.sendCustomMessage(FakeCustomMessage())).message,
        'Failed to send custom message',
      );

      when(() => source.sendCustomMessage(any())).thenThrow(_NotAnException());
      expect(
        _failure(await repo.sendCustomMessage(FakeCustomMessage())).message,
        'Failed to send custom message: boom',
      );
    });
  });

  group('editMessage', () {
    test('returns the edited message', () async {
      final edited = FakeTextMessage('edited');
      when(() => source.editMessage(any())).thenAnswer((_) async => edited);

      final result = await repo.editMessage(FakeTextMessage());
      expect((result as Success<BaseMessage>).data, same(edited));
    });

    test('maps each failure kind to its own message', () async {
      when(() => source.editMessage(any())).thenThrow(
        const MessageComposerDataSourceException(
          message: 'edit rejected',
          code: 'EDIT',
        ),
      );
      final dsFailure = _failure(await repo.editMessage(FakeTextMessage()));
      expect(dsFailure.message, 'edit rejected');
      expect(dsFailure.code, 'EDIT');

      when(
        () => source.editMessage(any()),
      ).thenThrow(CometChatException('E', 'details', null));
      expect(
        _failure(await repo.editMessage(FakeTextMessage())).message,
        'Failed to edit message',
      );

      when(() => source.editMessage(any())).thenThrow(_NotAnException());
      expect(
        _failure(await repo.editMessage(FakeTextMessage())).message,
        'Failed to edit message: boom',
      );
    });
  });

  group('typing indicators', () {
    test('startTyping forwards both arguments and succeeds', () async {
      when(
        () => source.startTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenReturn(null);

      final result = await repo.startTyping(
        receiverUid: 'uid_1',
        receiverType: 'user',
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => source.startTyping(receiverUid: 'uid_1', receiverType: 'user'),
      ).called(1);
    });

    test('startTyping failure is wrapped, not thrown', () async {
      when(
        () => source.startTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenThrow(Exception('no channel'));

      final failure = _failure(
        await repo.startTyping(receiverUid: 'u', receiverType: 'user'),
      );
      expect(failure.message, startsWith('Failed to start typing:'));
      expect(failure.exception, isA<Exception>());
    });

    test('endTyping forwards both arguments and succeeds', () async {
      when(
        () => source.endTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenReturn(null);

      final result = await repo.endTyping(
        receiverUid: 'guid_1',
        receiverType: 'group',
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => source.endTyping(receiverUid: 'guid_1', receiverType: 'group'),
      ).called(1);
    });

    test('endTyping failure is wrapped, not thrown', () async {
      when(
        () => source.endTyping(
          receiverUid: any(named: 'receiverUid'),
          receiverType: any(named: 'receiverType'),
        ),
      ).thenThrow(_NotAnException());

      final failure = _failure(
        await repo.endTyping(receiverUid: 'u', receiverType: 'user'),
      );
      expect(failure.message, 'Failed to end typing: boom');
      expect(failure.exception, isNull);
    });
  });

  group('getLoggedInUser', () {
    test('returns the user', () async {
      final user = FakeUser();
      when(() => source.getLoggedInUser()).thenAnswer((_) async => user);

      final result = await repo.getLoggedInUser();
      expect((result as Success<User?>).data, same(user));
    });

    test('a null user is a success, not a failure', () async {
      when(() => source.getLoggedInUser()).thenAnswer((_) async => null);

      final result = await repo.getLoggedInUser();
      expect(result.isSuccess, isTrue);
      expect((result as Success<User?>).data, isNull);
    });

    test('a thrown error becomes a Failure', () async {
      when(() => source.getLoggedInUser()).thenThrow(Exception('not logged'));

      final failure = _failure(await repo.getLoggedInUser());
      expect(failure.message, startsWith('Failed to get logged in user:'));
    });
  });
}
