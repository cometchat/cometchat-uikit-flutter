/// Regression tests for the two ways [AudioStateManager]'s cache mishandled a
/// state it already held.
///
/// ENG-39490 — every audio bubble on screen flipped to a spinner and back,
/// together, whenever a message was sent.
///
/// The message list rebuilds each bubble's State whenever the list changes: on
/// device, one voice note sent recreated every voice-note State three times
/// over, and each recreation reached [AudioStateManager.getAudioState] twice
/// (once from initState, once when the local-file check resolved).
///
/// That rebuild is meant to be cheap — the states are keyed by muid precisely
/// so a recreated bubble finds the cached [AudioBubbleState] and reuses its
/// already-initialised player. It was not cheap, because getAudioState called
/// `updateLocalPath` on every hit, and updateLocalPath disposes the live
/// controller and resets the play state. So each rebuild tore down a working
/// player and re-initialised it, which is the spinner the user saw.
///
/// ENG-39489 — the sender could not play audio they had just sent. Their state
/// is created from the optimistic message, before the upload has produced an
/// attachment url, and the cache refused to ever refresh that url. The only
/// source it could use was the recording on disk, so the moment that path
/// stopped resolving the state had no source at all and the play button did
/// nothing until the chat was closed and reopened.
///
///   flutter test test/shared_ui/bubbles/audio_state_manager_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fresh manager per test — it is a singleton, so leftovers leak between
/// cases otherwise.
void resetManager() => AudioStateManager().clearAll();

void main() {
  setUp(resetManager);
  tearDown(resetManager);

  test('a cached state is returned, not rebuilt', () {
    final first = AudioStateManager().getAudioState(1, 'https://a/x.m4a', '/f');
    final second = AudioStateManager().getAudioState(
      1,
      'https://a/x.m4a',
      '/f',
    );
    expect(identical(first, second), isTrue);
  });

  test(
    're-requesting a state with the same path leaves the player alone — ENG-39490',
    () async {
      final state = AudioStateManager().getAudioState(
        1,
        'https://a/x.m4a',
        '/tmp/voice.m4a',
      );

      // updateLocalPath is what tears the player down, and it always reports
      // itself on the state stream — so a silent stream means it was not run.
      final updates = <AudioStateUpdate>[];
      final sub = state.stateStream.listen(updates.add);

      // Stand in for the rebuilds the message list performs on every change.
      for (var i = 0; i < 6; i++) {
        AudioStateManager().getAudioState(
          1,
          'https://a/x.m4a',
          '/tmp/voice.m4a',
        );
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        updates,
        isEmpty,
        reason:
            'the path never changed, so the controller must not be torn down '
            '— ${updates.length} teardown(s) is the flicker',
      );
      expect(state.localPath, '/tmp/voice.m4a');
    },
  );

  test('a genuinely new path still re-points the player', () async {
    final state = AudioStateManager().getAudioState(2, 'https://a/y.m4a', '');

    final updates = <AudioStateUpdate>[];
    final sub = state.stateStream.listen(updates.add);

    // The download finished and the file is now on disk: that is the case
    // updateLocalPath exists for, and it must still fire.
    AudioStateManager().getAudioState(
      2,
      'https://a/y.m4a',
      '/tmp/downloaded.m4a',
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(updates, hasLength(1));
    expect(state.localPath, '/tmp/downloaded.m4a');
    expect(state.playState, PlayStates.init);
  });

  test('an empty path is ignored rather than clearing a known one', () async {
    final state = AudioStateManager().getAudioState(3, 'https://a/z.m4a', '/p');

    final updates = <AudioStateUpdate>[];
    final sub = state.stateStream.listen(updates.add);

    AudioStateManager().getAudioState(3, 'https://a/z.m4a', '');
    AudioStateManager().getAudioState(3, 'https://a/z.m4a', null);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(updates, isEmpty);
    expect(state.localPath, '/p', reason: 'a known good path must survive');
  });

  test('different ids keep independent states', () {
    final a = AudioStateManager().getAudioState(4, 'https://a/a.m4a', '/a');
    final b = AudioStateManager().getAudioState(5, 'https://a/b.m4a', '/b');
    expect(identical(a, b), isFalse);
    expect(a.localPath, '/a');
    expect(b.localPath, '/b');
  });

  // ---------------------------------------------------------------------------
  // ENG-39489 — the sender's state is created from the optimistic message,
  // before the upload has produced an attachment url.
  // ---------------------------------------------------------------------------

  test('a url that arrives after the state was cached is adopted', () async {
    // The sender's bubble binds while the message is still uploading.
    final state = AudioStateManager().getAudioState(10, null, '');
    expect(state.audioUrl, isNull);

    // The acknowledgement brings the real url.
    final same = AudioStateManager().getAudioState(
      10,
      'https://cdn/voice.m4a',
      '',
    );

    expect(identical(same, state), isTrue, reason: 'still the cached state');
    expect(
      state.audioUrl,
      'https://cdn/voice.m4a',
      reason:
          'without this the sender has no source at all once the recording '
          'path stops resolving, and the play button does nothing forever',
    );
  });

  test(
    'adopting a url leaves a state that has no player ready to build one',
    () async {
      final state = AudioStateManager().getAudioState(11, null, '');
      final updates = <AudioStateUpdate>[];
      final sub = state.stateStream.listen(updates.add);

      AudioStateManager().getAudioState(11, 'https://cdn/a.m4a', '');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(state.playState, PlayStates.init);
      expect(updates, hasLength(1), reason: 'the bubble is told to re-render');
    },
  );

  test('an unchanged url is not re-adopted', () async {
    final state = AudioStateManager().getAudioState(
      12,
      'https://cdn/b.m4a',
      '',
    );
    final updates = <AudioStateUpdate>[];
    final sub = state.stateStream.listen(updates.add);

    for (var i = 0; i < 4; i++) {
      AudioStateManager().getAudioState(12, 'https://cdn/b.m4a', '');
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(updates, isEmpty);
  });

  test('a null or empty url never clears one the state already has', () async {
    final state = AudioStateManager().getAudioState(
      13,
      'https://cdn/c.m4a',
      '',
    );

    AudioStateManager().getAudioState(13, null, '');
    AudioStateManager().getAudioState(13, '', '');

    expect(state.audioUrl, 'https://cdn/c.m4a');
  });
}
