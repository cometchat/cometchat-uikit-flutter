/// Behaviour tests for the domain use cases —
/// `domain/use_cases/message_use_cases.dart` and the audio-state use cases
/// under `services/audio_state/`.
///
/// A use case is a thin shell over a repository, so the only things it can get
/// wrong are the two it is there for: the validation it applies before calling
/// the repository, and the transformation it applies after. Both are asserted
/// against a recording fake repository, so a use case that forgets to
/// validate — or calls the wrong repository method — fails here.
///
///   flutter test test/shared_ui/clean_architecture/use_cases_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The barrel exports a different `GetMessagesUseCase` (the chat_ui message
// list's own), and the Params classes are not exported at all, so the
// clean-architecture use cases are imported by path under a prefix.
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/domain/use_cases/message_use_cases.dart'
    as domain;
import 'package:flutter_test/flutter_test.dart';

MessageEntity _msg(
  String id, {
  int timestamp = 0,
  bool isDeleted = false,
  String text = 'hello',
}) => MessageEntity(
  id: id,
  text: text,
  senderId: 'u1',
  senderName: 'Alice',
  timestamp: timestamp,
  isDeleted: isDeleted,
);

/// Records every call and answers with whatever the test set up.
///
/// Only the members the use cases touch are implemented; anything else throws
/// through `noSuchMethod`, so a use case reaching for the wrong repository
/// method fails loudly instead of quietly returning null.
class _FakeMessageRepository implements MessageRepository {
  final List<String> calls = [];

  List<MessageEntity> messages = const [];
  Result<List<MessageEntity>>? getMessagesResult;
  Result<MessageEntity>? sendResult;
  Result<List<MessageEntity>>? searchResult;
  Result<void> deleteResult = const Success<void>(null);
  Result<void> markAsReadResult = const Success<void>(null);
  Result<int> unreadResult = const Success<int>(0);

  /// The arguments of the last call, by name.
  Map<String, Object?> lastArgs = const {};

  @override
  Future<Result<List<MessageEntity>>> getMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    calls.add('getMessages');
    lastArgs = {
      'conversationId': conversationId,
      'limit': limit,
      'offset': offset,
    };
    return getMessagesResult ?? Success<List<MessageEntity>>(messages);
  }

  @override
  Future<Result<MessageEntity>> sendMessage({
    required String conversationId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    calls.add('sendMessage');
    lastArgs = {
      'conversationId': conversationId,
      'text': text,
      'metadata': metadata,
    };
    return sendResult ?? Success<MessageEntity>(_msg('sent', text: text));
  }

  @override
  Future<Result<List<MessageEntity>>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    calls.add('searchMessages');
    lastArgs = {'conversationId': conversationId, 'query': query};
    return searchResult ?? Success<List<MessageEntity>>(messages);
  }

  @override
  Future<Result<void>> deleteMessage(String messageId) async {
    calls.add('deleteMessage');
    lastArgs = {'messageId': messageId};
    return deleteResult;
  }

  @override
  Future<Result<void>> markAsRead({required List<String> messageIds}) async {
    calls.add('markAsRead');
    lastArgs = {'messageIds': messageIds};
    return markAsReadResult;
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    calls.add('getUnreadCount');
    return unreadResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every audio-state call; each returns a canned result.
class _FakeAudioStateRepository implements AudioStateRepository {
  final List<String> calls = [];
  final List<Object?> args = [];

  AudioStateEntity state = AudioStateEntity(
    id: 1,
    audioUrl: 'https://x/a.m4a',
    localPath: null,
    playState: PlayState.init,
    currentPosition: Duration.zero,
    totalDuration: Duration.zero,
    isInitializing: false,
  );

  @override
  Future<Result<AudioStateEntity>> getAudioState(
    int id,
    String? audioUrl,
    String? localPath,
  ) async {
    calls.add('getAudioState');
    args.add([id, audioUrl, localPath]);
    return Success<AudioStateEntity>(state);
  }

  @override
  Future<Result<void>> playAudio(int audioId) async {
    calls.add('playAudio');
    args.add(audioId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> pauseAudio(int audioId) async {
    calls.add('pauseAudio');
    args.add(audioId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> stopAudio(int audioId) async {
    calls.add('stopAudio');
    args.add(audioId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> stopAllAudio() async {
    calls.add('stopAllAudio');
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> pauseAllExcept(int excludeId) async {
    calls.add('pauseAllExcept');
    args.add(excludeId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> removeAudioState(int audioId) async {
    calls.add('removeAudioState');
    args.add(audioId);
    return const Success<void>(null);
  }

  @override
  Future<Result<PlayState>> getPlayState(int audioId) async {
    calls.add('getPlayState');
    args.add(audioId);
    return Success<PlayState>(state.playState);
  }

  @override
  Future<Result<void>> seekToPosition(int audioId, Duration position) async {
    calls.add('seekToPosition');
    args.add([audioId, position]);
    return const Success<void>(null);
  }

  @override
  Stream<Result<AudioStateUpdateEntity>> getAudioStateStream(int audioId) {
    calls.add('getAudioStateStream');
    args.add(audioId);
    return Stream<Result<AudioStateUpdateEntity>>.value(
      Success<AudioStateUpdateEntity>(
        AudioStateUpdateEntity(audioId: audioId, state: PlayState.playing),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The failure a `Result` carries, or null when it succeeded.
Failure? failureOf(Result<Object?> result) =>
    result.fold<Failure?>((f) => f, (_) => null);

void main() {
  late _FakeMessageRepository repo;

  setUp(() => repo = _FakeMessageRepository());

  // ==========================================================================
  group('GetMessagesUseCase', () {
    test(
      'rejects an empty conversation id without calling the repository',
      () async {
        final result = await domain.GetMessagesUseCase(
          repository: repo,
        ).call(domain.GetMessagesParams(conversationId: ''));
        expect(failureOf(result)?.code, 'INVALID_PARAMS');
        expect(failureOf(result)?.message, 'Conversation ID is required');
        expect(repo.calls, isEmpty, reason: 'validation runs first');
      },
    );

    test('forwards the paging arguments it was given', () async {
      await domain.GetMessagesUseCase(repository: repo).call(
        domain.GetMessagesParams(conversationId: 'c1', limit: 10, offset: 20),
      );
      expect(repo.calls, ['getMessages']);
      expect(repo.lastArgs, {
        'conversationId': 'c1',
        'limit': 10,
        'offset': 20,
      });
    });

    test('the paging defaults are 50 from the start', () async {
      await domain.GetMessagesUseCase(
        repository: repo,
      ).call(domain.GetMessagesParams(conversationId: 'c1'));
      expect(repo.lastArgs['limit'], 50);
      expect(repo.lastArgs['offset'], 0);
    });

    test('drops deleted messages and sorts newest first', () async {
      repo.messages = [
        _msg('a', timestamp: 100),
        _msg('gone', timestamp: 300, isDeleted: true),
        _msg('c', timestamp: 200),
      ];
      final result = await domain.GetMessagesUseCase(
        repository: repo,
      ).call(domain.GetMessagesParams(conversationId: 'c1'));
      final ids = result.fold<List<String>>(
        (_) => const [],
        (list) => list.map((m) => m.id).toList(),
      );
      expect(ids, ['c', 'a']);
    });

    test('an all-deleted page comes back empty, not as a failure', () async {
      repo.messages = [_msg('x', isDeleted: true)];
      final result = await domain.GetMessagesUseCase(
        repository: repo,
      ).call(domain.GetMessagesParams(conversationId: 'c1'));
      expect(result.isSuccess, isTrue);
      expect(result.fold<int>((_) => -1, (l) => l.length), 0);
    });

    test('a repository failure is passed through untransformed', () async {
      repo.getMessagesResult = const Failure(message: 'offline', code: 'NET');
      final result = await domain.GetMessagesUseCase(
        repository: repo,
      ).call(domain.GetMessagesParams(conversationId: 'c1'));
      expect(failureOf(result)?.code, 'NET');
    });
  });

  // ==========================================================================
  group('SendMessageUseCase', () {
    test('rejects empty text', () async {
      final result = await domain.SendMessageUseCase(
        repository: repo,
      ).call(domain.SendMessageParams(conversationId: 'c1', text: ''));
      expect(failureOf(result)?.code, 'EMPTY_MESSAGE');
      expect(repo.calls, isEmpty);
    });

    test('rejects an empty conversation id', () async {
      final result = await domain.SendMessageUseCase(
        repository: repo,
      ).call(domain.SendMessageParams(conversationId: '', text: 'hi'));
      expect(failureOf(result)?.code, 'INVALID_PARAMS');
      expect(repo.calls, isEmpty);
    });

    test('text is checked before the conversation id', () async {
      // Both are wrong; the message the user sees names the text.
      final result = await domain.SendMessageUseCase(
        repository: repo,
      ).call(domain.SendMessageParams(conversationId: '', text: ''));
      expect(failureOf(result)?.code, 'EMPTY_MESSAGE');
    });

    test('trims the text before sending', () async {
      await domain.SendMessageUseCase(repository: repo).call(
        domain.SendMessageParams(conversationId: 'c1', text: '  hi there \n'),
      );
      expect(repo.lastArgs['text'], 'hi there');
    });

    test('whitespace-only text is sent as an empty string — pinned', () async {
      // FINDING: the emptiness check runs on the RAW text and the trim runs
      // after it, so "   " passes validation and reaches the repository as
      // "". A whitespace-only send is not rejected, it is silently emptied.
      // Pinned, not fixed — a lib/ change.
      final result = await domain.SendMessageUseCase(
        repository: repo,
      ).call(domain.SendMessageParams(conversationId: 'c1', text: '   '));
      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['sendMessage']);
      expect(repo.lastArgs['text'], '');
    });

    test('metadata is forwarded as given', () async {
      await domain.SendMessageUseCase(repository: repo).call(
        domain.SendMessageParams(
          conversationId: 'c1',
          text: 'hi',
          metadata: const {'k': 'v'},
        ),
      );
      expect(repo.lastArgs['metadata'], const {'k': 'v'});
    });

    test('a repository failure is passed through', () async {
      repo.sendResult = const Failure(message: 'rejected', code: 'BLOCKED');
      final result = await domain.SendMessageUseCase(
        repository: repo,
      ).call(domain.SendMessageParams(conversationId: 'c1', text: 'hi'));
      expect(failureOf(result)?.code, 'BLOCKED');
    });
  });

  // ==========================================================================
  group('SearchMessagesUseCase', () {
    test('rejects an empty query', () async {
      final result = await domain.SearchMessagesUseCase(
        repository: repo,
      ).call(domain.SearchMessagesParams(conversationId: 'c1', query: ''));
      expect(failureOf(result)?.code, 'EMPTY_QUERY');
      expect(repo.calls, isEmpty);
    });

    test('rejects an empty conversation id', () async {
      final result = await domain.SearchMessagesUseCase(
        repository: repo,
      ).call(domain.SearchMessagesParams(conversationId: '', query: 'hi'));
      expect(failureOf(result)?.code, 'INVALID_PARAMS');
      expect(repo.calls, isEmpty);
    });

    test('trims the query', () async {
      await domain.SearchMessagesUseCase(repository: repo).call(
        domain.SearchMessagesParams(conversationId: 'c1', query: '  needle  '),
      );
      expect(repo.calls, ['searchMessages']);
      expect(repo.lastArgs['query'], 'needle');
    });

    test('results are handed back as the repository gave them', () async {
      // Unlike getMessages, search does NOT filter or re-sort.
      repo.messages = [
        _msg('a', timestamp: 100),
        _msg('gone', timestamp: 300, isDeleted: true),
      ];
      final result = await domain.SearchMessagesUseCase(
        repository: repo,
      ).call(domain.SearchMessagesParams(conversationId: 'c1', query: 'x'));
      expect(
        result.fold<List<String>>(
          (_) => const [],
          (l) => [for (final m in l) m.id],
        ),
        ['a', 'gone'],
      );
    });
  });

  // ==========================================================================
  group('DeleteMessageUseCase', () {
    test('rejects an empty id', () async {
      final result = await domain.DeleteMessageUseCase(
        repository: repo,
      ).call('');
      expect(failureOf(result)?.code, 'INVALID_PARAMS');
      expect(repo.calls, isEmpty);
    });

    test('forwards a real id', () async {
      final result = await domain.DeleteMessageUseCase(
        repository: repo,
      ).call('m1');
      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['deleteMessage']);
      expect(repo.lastArgs['messageId'], 'm1');
    });

    test('a repository failure is passed through', () async {
      repo.deleteResult = const Failure(message: 'nope', code: 'FORBIDDEN');
      expect(
        failureOf(
          await domain.DeleteMessageUseCase(repository: repo).call('m1'),
        )?.code,
        'FORBIDDEN',
      );
    });
  });

  // ==========================================================================
  group('MarkMessagesAsReadUseCase', () {
    test('rejects an empty list', () async {
      final result = await domain.MarkMessagesAsReadUseCase(
        repository: repo,
      ).call(const []);
      expect(failureOf(result)?.code, 'EMPTY_LIST');
      expect(repo.calls, isEmpty);
    });

    test('forwards the ids it was given', () async {
      final result = await domain.MarkMessagesAsReadUseCase(
        repository: repo,
      ).call(const ['m1', 'm2']);
      expect(result.isSuccess, isTrue);
      expect(repo.lastArgs['messageIds'], const ['m1', 'm2']);
    });

    test('a repository failure is passed through', () async {
      repo.markAsReadResult = const Failure(message: 'x', code: 'NET');
      expect(
        failureOf(
          await domain.MarkMessagesAsReadUseCase(
            repository: repo,
          ).call(const ['m1']),
        )?.code,
        'NET',
      );
    });
  });

  // ==========================================================================
  group('GetUnreadCountUseCase', () {
    test('has nothing to validate and passes the count through', () async {
      repo.unreadResult = const Success<int>(12);
      final result = await domain.GetUnreadCountUseCase(
        repository: repo,
      ).call(null);
      expect(result.fold<int>((_) => -1, (n) => n), 12);
      expect(repo.calls, ['getUnreadCount']);
    });

    test('a repository failure is passed through', () async {
      repo.unreadResult = const Failure(message: 'x', code: 'NET');
      expect(
        failureOf(
          await domain.GetUnreadCountUseCase(repository: repo).call(null),
        )?.code,
        'NET',
      );
    });
  });

  // ==========================================================================
  group('audio state use cases', () {
    late _FakeAudioStateRepository audio;

    setUp(() => audio = _FakeAudioStateRepository());

    test('each use case calls its own repository method, once', () async {
      await GetAudioStateUseCase(
        audio,
      ).call(id: 1, audioUrl: 'u', localPath: 'p');
      await PlayAudioUseCase(audio).call(2);
      await PauseAudioUseCase(audio).call(3);
      await StopAudioUseCase(audio).call(4);
      await StopAllAudioUseCase(audio).call();
      await PauseAllExceptUseCase(audio).call(5);
      await RemoveAudioStateUseCase(audio).call(6);
      await GetPlayStateUseCase(audio).call(7);
      await SeekAudioUseCase(audio).call(8, const Duration(seconds: 9));

      expect(audio.calls, [
        'getAudioState',
        'playAudio',
        'pauseAudio',
        'stopAudio',
        'stopAllAudio',
        'pauseAllExcept',
        'removeAudioState',
        'getPlayState',
        'seekToPosition',
      ]);
    });

    test('the arguments reach the repository unchanged', () async {
      await GetAudioStateUseCase(
        audio,
      ).call(id: 1, audioUrl: 'https://x/a.m4a', localPath: '/tmp/a');
      expect(audio.args.first, [1, 'https://x/a.m4a', '/tmp/a']);

      await SeekAudioUseCase(audio).call(8, const Duration(seconds: 9));
      expect(audio.args.last, [8, const Duration(seconds: 9)]);
    });

    test('getAudioState optionals default to null', () async {
      await GetAudioStateUseCase(audio).call(id: 1);
      expect(audio.args.single, [1, null, null]);
    });

    test(
      'the state and play state come back as the repository has them',
      () async {
        audio.state = audio.state.copyWith(playState: PlayState.paused);
        final state = await GetAudioStateUseCase(audio).call(id: 1);
        expect(
          state.fold<PlayState?>((_) => null, (s) => s.playState),
          PlayState.paused,
        );
        final play = await GetPlayStateUseCase(audio).call(1);
        expect(play.fold<PlayState?>((_) => null, (s) => s), PlayState.paused);
      },
    );

    test('the stream use case subscribes to the repository stream', () async {
      final updates = await GetAudioStateStreamUseCase(audio).call(3).toList();
      expect(audio.calls, ['getAudioStateStream']);
      expect(audio.args.single, 3);
      expect(updates, hasLength(1));
      expect(updates.single.fold<int?>((_) => null, (u) => u.audioId), 3);
    });
  });
}
