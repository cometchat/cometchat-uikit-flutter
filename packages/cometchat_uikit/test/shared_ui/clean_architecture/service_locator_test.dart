/// Wiring tests for the shared-UI dependency-injection locators.
///
///   SharedUiServiceLocator      (lib/shared_ui/.../core/di/service_locator.dart)
///   AudioServiceLocator         (lib/shared_ui/.../core/di/audio_service_locator.dart)
///   ConversationsServiceLocator (lib/chat_ui/src/conversations/di/…)
///
/// All three were near zero coverage. None of them needs the SDK to be
/// constructed: every data source these locators build is a plain object whose
/// constructor does no I/O, so `setup()` runs in a VM test as-is.
///
/// A DI container is only worth testing for the thing it can silently get
/// wrong: handing a use case a *different* repository from the one it exposes,
/// or a second `setup()` leaving half the graph pointing at the old objects.
/// So every assertion here is on object identity through the graph, not on
/// "is not null".
///
/// ORDERING: these locators are process-wide singletons with `late` fields, so
/// the first group deliberately runs before anything calls `setup()`.
///
///   flutter test test/shared_ui/clean_architecture/service_locator_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/di/conversations_service_locator.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/di/audio_service_locator.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/di/service_locator.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/data/repositories/repository_impl.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/services/audio_state/data/repositories/audio_state_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===========================================================================
  // Runs first, while the `late` fields are still unassigned.
  group('before setup', () {
    test(
      'an accessor on an un-setup locator throws rather than returning null',
      () {
        expect(
          () => SharedUiServiceLocator().messageRepository,
          throwsA(isA<Error>()),
        );
      },
    );

    test('the conversations locator reports itself uninitialised', () {
      expect(ConversationsServiceLocator.instance.isInitialized, isFalse);
    });

    test(
      'an un-initialised conversations getter throws a StateError naming setup',
      () {
        expect(
          () => ConversationsServiceLocator.instance.getConversationsUseCase,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Call setup()'),
            ),
          ),
        );
      },
    );
  });

  // ===========================================================================
  group('SharedUiServiceLocator', () {
    setUpAll(() async {
      await SharedUiServiceLocator.setup();
    });

    test('the factory always hands back the one instance', () {
      expect(SharedUiServiceLocator(), same(SharedUiServiceLocator()));
    });

    test('setup initialises the conversations locator too', () {
      expect(ConversationsServiceLocator.instance.isInitialized, isTrue);
    });

    test('repositories are built over the concrete data sources', () {
      final l = SharedUiServiceLocator();
      expect(l.messageRepository, isA<MessageRepositoryImpl>());
      expect(l.userRepository, isA<UserRepositoryImpl>());
      expect(l.groupRepository, isA<GroupRepositoryImpl>());
      expect(l.audioStateRepository, isA<AudioStateRepositoryImpl>());
    });

    test(
      'every message use case points at the repository the locator exposes',
      () {
        final l = SharedUiServiceLocator();
        final repo = l.messageRepository;
        expect(l.getMessagesUseCase.repository, same(repo));
        expect(l.sendMessageUseCase.repository, same(repo));
        expect(l.searchMessagesUseCase.repository, same(repo));
        expect(l.deleteMessageUseCase.repository, same(repo));
        expect(l.markMessagesAsReadUseCase.repository, same(repo));
        expect(l.getUnreadCountUseCase.repository, same(repo));
      },
    );

    test('every audio use case points at the audio repository', () {
      final l = SharedUiServiceLocator();
      final repo = l.audioStateRepository;
      expect(l.getAudioStateUseCase.repository, same(repo));
      expect(l.playAudioUseCase.repository, same(repo));
      expect(l.pauseAudioUseCase.repository, same(repo));
      expect(l.stopAudioUseCase.repository, same(repo));
      expect(l.seekAudioUseCase.repository, same(repo));
      expect(l.getAudioStateStreamUseCase.repository, same(repo));
    });

    test('an accessor is stable — it hands back the same object each call', () {
      final l = SharedUiServiceLocator();
      expect(l.messageRepository, same(l.messageRepository));
      expect(l.getMessagesUseCase, same(l.getMessagesUseCase));
    });

    test(
      'asMap exposes exactly the sixteen services, each the live object',
      () {
        final l = SharedUiServiceLocator();
        final map = l.asMap();

        expect(map.keys.toSet(), {
          'messageRepository',
          'userRepository',
          'groupRepository',
          'audioStateRepository',
          'getMessagesUseCase',
          'sendMessageUseCase',
          'searchMessagesUseCase',
          'deleteMessageUseCase',
          'markMessagesAsReadUseCase',
          'getUnreadCountUseCase',
          'getAudioStateUseCase',
          'playAudioUseCase',
          'pauseAudioUseCase',
          'stopAudioUseCase',
          'seekAudioUseCase',
          'getAudioStateStreamUseCase',
        });

        expect(map['messageRepository'], same(l.messageRepository));
        expect(map['userRepository'], same(l.userRepository));
        expect(map['groupRepository'], same(l.groupRepository));
        expect(map['audioStateRepository'], same(l.audioStateRepository));
        expect(map['getMessagesUseCase'], same(l.getMessagesUseCase));
        expect(map['sendMessageUseCase'], same(l.sendMessageUseCase));
        expect(map['searchMessagesUseCase'], same(l.searchMessagesUseCase));
        expect(map['deleteMessageUseCase'], same(l.deleteMessageUseCase));
        expect(
          map['markMessagesAsReadUseCase'],
          same(l.markMessagesAsReadUseCase),
        );
        expect(map['getUnreadCountUseCase'], same(l.getUnreadCountUseCase));
        expect(map['getAudioStateUseCase'], same(l.getAudioStateUseCase));
        expect(map['playAudioUseCase'], same(l.playAudioUseCase));
        expect(map['pauseAudioUseCase'], same(l.pauseAudioUseCase));
        expect(map['stopAudioUseCase'], same(l.stopAudioUseCase));
        expect(map['seekAudioUseCase'], same(l.seekAudioUseCase));
        expect(
          map['getAudioStateStreamUseCase'],
          same(l.getAudioStateStreamUseCase),
        );
      },
    );

    test(
      'a second setup rebuilds the graph and rewires the use cases',
      () async {
        final l = SharedUiServiceLocator();
        final before = l.messageRepository;

        await SharedUiServiceLocator.setup();

        expect(
          l.messageRepository,
          isNot(same(before)),
          reason: 'setup is not idempotent; it builds fresh instances',
        );
        // The important part: nothing is left pointing at the old graph.
        expect(l.getMessagesUseCase.repository, same(l.messageRepository));
        expect(l.getAudioStateUseCase.repository, same(l.audioStateRepository));
      },
    );
  });

  // ===========================================================================
  group('AudioServiceLocator', () {
    setUpAll(() async {
      await SharedUiServiceLocator.setup();
    });

    test('it is a singleton', () {
      expect(AudioServiceLocator.instance, same(AudioServiceLocator.instance));
    });

    test(
      'every getter delegates to the shared locator, not a private copy',
      () {
        final shared = SharedUiServiceLocator();
        final audio = AudioServiceLocator.instance;

        expect(
          audio.getGetAudioStateUseCase(),
          same(shared.getAudioStateUseCase),
        );
        expect(audio.getPlayAudioUseCase(), same(shared.playAudioUseCase));
        expect(audio.getPauseAudioUseCase(), same(shared.pauseAudioUseCase));
        expect(audio.getStopAudioUseCase(), same(shared.stopAudioUseCase));
        expect(audio.getSeekAudioUseCase(), same(shared.seekAudioUseCase));
        expect(
          audio.getGetAudioStateStreamUseCase(),
          same(shared.getAudioStateStreamUseCase),
        );
      },
    );

    test('it follows the shared locator across a re-setup', () async {
      final audio = AudioServiceLocator.instance;
      final before = audio.getPlayAudioUseCase();

      await SharedUiServiceLocator.setup();

      expect(audio.getPlayAudioUseCase(), isNot(same(before)));
      expect(
        audio.getPlayAudioUseCase(),
        same(SharedUiServiceLocator().playAudioUseCase),
      );
    });
  });

  // ===========================================================================
  group('ConversationsServiceLocator', () {
    setUp(() async {
      await ConversationsServiceLocator.instance.reset();
      ConversationsServiceLocator.instance.setup();
    });

    test('instance is a singleton', () {
      expect(
        ConversationsServiceLocator.instance,
        same(ConversationsServiceLocator.instance),
      );
    });

    test('every use case shares the one repository instance', () {
      final l = ConversationsServiceLocator.instance;
      final repo = l.repository;
      expect(l.getConversationsUseCase.repository, same(repo));
      expect(l.loadMoreConversationsUseCase.repository, same(repo));
      expect(l.deleteConversationUseCase.repository, same(repo));
      expect(l.getLoggedInUserUseCase.repository, same(repo));
      expect(l.getConversationUseCase.repository, same(repo));
      expect(l.markAsDeliveredUseCase.repository, same(repo));
    });

    test('a second setup is a no-op — the graph is not rebuilt', () {
      final l = ConversationsServiceLocator.instance;
      final repo = l.repository;
      l.setup();
      expect(l.repository, same(repo));
    });

    test('setupAsync on an initialised locator is also a no-op', () async {
      final l = ConversationsServiceLocator.instance;
      final repo = l.repository;
      await l.setupAsync();
      expect(l.repository, same(repo));
    });

    test(
      'setupAsync builds the same graph as setup when starting cold',
      () async {
        final l = ConversationsServiceLocator.instance;
        await l.reset();
        expect(l.isInitialized, isFalse);

        await l.setupAsync();

        expect(l.isInitialized, isTrue);
        expect(l.getConversationsUseCase.repository, same(l.repository));
        expect(l.markAsDeliveredUseCase.repository, same(l.repository));
      },
    );

    test(
      'reset flips isInitialized and re-arms the guard on every getter',
      () async {
        final l = ConversationsServiceLocator.instance;
        await l.reset();

        expect(l.isInitialized, isFalse);
        expect(() => l.repository, throwsStateError);
        expect(() => l.getConversationsUseCase, throwsStateError);
        expect(() => l.loadMoreConversationsUseCase, throwsStateError);
        expect(() => l.deleteConversationUseCase, throwsStateError);
        expect(() => l.getLoggedInUserUseCase, throwsStateError);
        expect(() => l.getConversationUseCase, throwsStateError);
        expect(() => l.markAsDeliveredUseCase, throwsStateError);
      },
    );

    test('setup after reset rebuilds with fresh objects', () async {
      final l = ConversationsServiceLocator.instance;
      final before = l.repository;
      await l.reset();
      l.setup();
      expect(l.repository, isNot(same(before)));
    });
  });

  // ===========================================================================
  // Left until last: both of these tear the conversations locator down.
  group('SharedUiServiceLocator teardown helpers', () {
    setUp(() async {
      await SharedUiServiceLocator.setup();
    });

    tearDownAll(() async {
      await SharedUiServiceLocator.setup();
    });

    test('reset() tears down the conversations locator', () async {
      expect(ConversationsServiceLocator.instance.isInitialized, isTrue);

      await SharedUiServiceLocator.reset();

      expect(ConversationsServiceLocator.instance.isInitialized, isFalse);
    });

    test('cleanup() does the same as reset()', () async {
      expect(ConversationsServiceLocator.instance.isInitialized, isTrue);

      await SharedUiServiceLocator.cleanup();

      expect(ConversationsServiceLocator.instance.isInitialized, isFalse);
    });

    // FINDING: `SharedUiServiceLocator.reset()` is documented as "Reset all
    // services (useful for testing)", but it only resets the *conversations*
    // locator — its own repositories and use cases survive untouched, so a
    // test that resets between cases still sees the previous graph. Same for
    // `cleanup()`, which is documented as "Cleanup resources" and frees none.
    // Pinned as-is.
    test('reset() does NOT reset the shared locator it belongs to', () async {
      final l = SharedUiServiceLocator();
      final repo = l.messageRepository;

      await SharedUiServiceLocator.reset();

      expect(l.messageRepository, same(repo));
      expect(l.getMessagesUseCase.repository, same(repo));
    });
  });
}
