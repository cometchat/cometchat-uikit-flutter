import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform;

import 'voice_note_audio_session.dart';

// Conditional import for web audio player
import 'web_audio_player_stub.dart'
    if (dart.library.js_interop) 'web_audio_player.dart'
    as web_player;

/// Global state manager for audio bubbles to preserve playback state across widget rebuilds
class AudioStateManager {
  static final AudioStateManager _singleton = AudioStateManager._internal();

  factory AudioStateManager() {
    return _singleton;
  }

  AudioStateManager._internal();

  final Map<int, AudioBubbleState> _audioStates = {};

  /// Get or create audio state for a specific audio bubble
  AudioBubbleState getAudioState(int id, String? audioUrl, String? localPath) {
    if (!_audioStates.containsKey(id)) {
      _audioStates[id] = AudioBubbleState(
        id: id,
        audioUrl: audioUrl,
        localPath: localPath,
      );
    } else {
      final state = _audioStates[id]!;
      // Only when the file actually moved. updateLocalPath exists to re-point
      // the player at a newly-downloaded copy, and it does that by disposing
      // the live controller and resetting the play state — so calling it with
      // the path the state already holds tears down a perfectly good player
      // for nothing.
      //
      // That mattered because the message list rebuilds every bubble's State
      // whenever the list changes: one voice note sent recreated each State
      // three times over, and each recreation ran this path twice (initState
      // and again when the file check resolved). The result was every audio
      // bubble on screen flipping to a spinner and back, together, on every
      // send — ENG-39490. With the guard, a recreated bubble finds the cached
      // state and reuses its already-initialised controller, which is what
      // keying these by muid was for in the first place.
      if (localPath != null &&
          localPath.isNotEmpty &&
          state.localPath != localPath) {
        state.updateLocalPath(localPath);
      }
      // The sender's state is created from the optimistic message, before the
      // upload has finished — so it is cached with a null audioUrl, and the
      // real one only arrives with the acknowledgement. Adopt it.
      //
      // This used to be skipped on the grounds that refreshing the url would
      // tear players down mid-playback, with a null url held to be "harmless
      // while the local file exists". It isn't: the recording is device-local,
      // so the moment that path stops resolving — cache cleaned, or iOS hands
      // the app a new container UUID after a reinstall, leaving the localPath
      // stamped in server metadata pointing nowhere — the state has no source
      // at all and the sender's own voice note refuses to play until the chat
      // is closed and reopened (ENG-39489). The receiver never hits it: their
      // state is first built from a message that already carries the url.
      //
      // adoptAudioUrl is what makes this safe — it separates "new source"
      // from "drop the controller".
      if (audioUrl != null &&
          audioUrl.isNotEmpty &&
          state.audioUrl != audioUrl) {
        state.adoptAudioUrl(audioUrl);
      }
    }
    return _audioStates[id]!;
  }

  /// Remove audio state when bubble is permanently disposed
  void removeAudioState(int id) {
    final state = _audioStates[id];
    if (state != null) {
      state.dispose();
      _audioStates.remove(id);
    }
  }

  /// Stop all audio playback
  void stopAllAudio() {
    for (final state in _audioStates.values) {
      state.stopAudio();
    }
  }

  /// Pause all audio except the specified one
  void pauseAllExcept(int excludeId) {
    for (final state in _audioStates.values) {
      if (state.id != excludeId) {
        state.pauseAudio();
      }
    }
  }

  /// Clear all audio states and release all memory
  /// Call this when message list is disposed
  void clearAll() {
    for (final state in _audioStates.values) {
      state.dispose();
    }
    _audioStates.clear();
  }
}

/// Individual audio state for each audio bubble
class AudioBubbleState {
  final int id;

  /// Not final: the sender's state is built from the optimistic message, whose
  /// attachment url does not exist until the upload completes. See
  /// [adoptAudioUrl].
  String? audioUrl;
  String? localPath;

  VideoPlayerController? _controller;
  web_player.WebAudioPlayer? _webPlayer;
  StreamSubscription<Duration>? _webPositionSub;
  StreamSubscription<void>? _webCompletionSub;
  PlayStates _playState = PlayStates.init;
  bool _isInitializing = false;

  /// Whether the native player was opened on this device's own recording.
  /// Only that needs the session routed to the loudspeaker while it plays —
  /// see [VoiceNoteAudioSession].
  bool _playsLocalFile = false;
  Duration? _totalDuration;
  Duration _currentPosition = Duration.zero;

  final StreamController<AudioStateUpdate> _stateController =
      StreamController<AudioStateUpdate>.broadcast();

  AudioBubbleState({
    required this.id,
    required this.audioUrl,
    required this.localPath,
  });

  Stream<AudioStateUpdate> get stateStream => _stateController.stream;

  PlayStates get playState => _playState;
  VideoPlayerController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  Duration? get totalDuration => _totalDuration;
  Duration get currentPosition => _currentPosition;

  /// Completer to prevent concurrent initialization calls
  Completer<void>? _initCompleter;

  /// Hard cap on a single [initializeController] attempt.
  ///
  /// A controller opened on a local file that another controller is tearing
  /// down can hang instead of throwing: the shared MediaCodec event handler
  /// dies with the other player and `initialize()` never returns. That happens
  /// when a message is acknowledged — the optimistic (id 0) bubble and the
  /// real-id bubble briefly hold two players on the same recording. Without a
  /// deadline the `finally` below never runs, so `_isInitializing` stays true
  /// and the bubble spins until the message list is disposed.
  static const Duration _initTimeout = Duration(seconds: 6);

  Future<void> initializeController({bool isRetry = false}) async {
    ccLog("initializeController: $id");

    // If already initialized, return immediately
    if (kIsWeb && _webPlayer != null && _webPlayer!.isInitialized) return;
    if (!kIsWeb && _controller != null && _controller!.value.isInitialized) {
      return;
    }

    // If initialization is already in progress, wait for it
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    bool timedOut = false;

    try {
      _initCompleter = Completer<void>();
      _isInitializing = true;
      _notifyStateUpdate();

      if (kIsWeb) {
        // Web: use HTML <audio> element for proper webm/opus support
        if (audioUrl == null || audioUrl!.isEmpty) {
          ccLog("No valid audio URL for web playback, id: $id");
          _isInitializing = false;
          _notifyStateUpdate();
          return;
        }

        ccLog("Using WEB audio player for: $audioUrl");
        _webPlayer = web_player.createWebAudioPlayer();
        final success = await _webPlayer!.initialize(audioUrl!);

        if (!success) {
          ccLog(
            '[AudioBubbleState] Web audio player failed to initialize for id: $id',
          );
          _webPlayer?.dispose();
          _webPlayer = null;
          _isInitializing = false;
          _notifyStateUpdate();
          return;
        }

        _totalDuration = _webPlayer!.duration;
        ccLog(
          '[AudioBubbleState] Web audio initialized for id: $id, duration: $_totalDuration',
        );

        // Listen for position updates
        _webPositionSub = _webPlayer!.positionStream.listen((pos) {
          _currentPosition = pos;
          // Update duration if it changed (webm progressive duration)
          if (_webPlayer!.duration > Duration.zero) {
            _totalDuration = _webPlayer!.duration;
          }
          _notifyStateUpdate();
        });

        // Listen for completion
        _webCompletionSub = _webPlayer!.completionStream.listen((_) {
          stopAudio();
        });
      } else {
        // Native: use VideoPlayerController
        final bool hasValidLocalFile =
            localPath != null &&
            localPath!.isNotEmpty &&
            platform.fileExistsSync(localPath!);

        if (hasValidLocalFile) {
          ccLog("Using LOCAL audio file: $localPath");
          _playsLocalFile = true;

          _controller = VideoPlayerController.networkUrl(
            Uri.parse('file://$localPath'),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else if (audioUrl != null && audioUrl!.isNotEmpty) {
          ccLog("Using NETWORK audio url: $audioUrl");
          _playsLocalFile = false;

          _controller = VideoPlayerController.networkUrl(
            Uri.parse(audioUrl!),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          ccLog("No valid audio source found for id: $id");
          _isInitializing = false;
          _notifyStateUpdate();
          return;
        }

        await _controller!.initialize().timeout(_initTimeout);

        if (!_controller!.value.isInitialized) {
          ccLog(
            '[AudioBubbleState] Controller failed to initialize for id: $id',
          );
          _disposeController();
          _isInitializing = false;
          _notifyStateUpdate();
          return;
        }

        _totalDuration = _controller!.value.duration;
        ccLog(
          '[AudioBubbleState] Initialized successfully for id: $id, duration: $_totalDuration',
        );

        _controller!.addListener(_onControllerUpdate);
      }
    } on TimeoutException {
      // The player never answered — almost always the teardown race described
      // on [_initTimeout]. Drop the wedged controller so the retry below (or a
      // later play tap) can build a fresh one.
      timedOut = true;
      ccLog(
        '[AudioBubbleState] initialize() timed out after '
        '${_initTimeout.inSeconds}s for id: $id${isRetry ? ' (retry)' : ''}',
      );
      _disposeController();
    } catch (e, stack) {
      ccLog("Error initializing audio controller for id: $id — $e");
      debugPrintStack(stackTrace: stack);
      _disposeController();
      _webPlayer?.dispose();
      _webPlayer = null;
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
      _initCompleter = null;
      _notifyStateUpdate();
    }

    // One retry, and one only — `isRetry` makes a second timeout fall through
    // instead of recursing. By now the player we raced with has finished
    // tearing down, so the fresh controller usually succeeds. Deliberately
    // outside the try/finally: the state is already consistent here, so the
    // recursive call starts from a clean slate rather than re-entering while
    // _isInitializing is still true.
    if (timedOut && !isRetry) {
      await initializeController(isRetry: true);
    }
  }

  void _onControllerUpdate() {
    if (_controller != null) {
      _currentPosition = _controller!.value.position;
      _notifyStateUpdate();

      if (_controller!.value.isCompleted) {
        stopAudio();
      }
    }
  }

  Future<void> playAudio() async {
    if (kIsWeb) {
      if (_webPlayer == null || !_webPlayer!.isInitialized) {
        await initializeController();
      }
      if (_webPlayer == null || !_webPlayer!.isInitialized) {
        ccLog(
          '[AudioBubbleState] Cannot play — web player not initialized for id: $id',
        );
        _playState = PlayStates.stopped;
        _notifyStateUpdate();
        return;
      }
      try {
        AudioStateManager().pauseAllExcept(id);
        _playState = PlayStates.playing;
        await _webPlayer!.play();
        _notifyStateUpdate();
      } catch (e, stack) {
        ccLog('[AudioBubbleState] Error playing web audio for id: $id — $e');
        debugPrintStack(stackTrace: stack);
        _playState = PlayStates.stopped;
        _notifyStateUpdate();
      }
    } else {
      if (_controller == null || !_controller!.value.isInitialized) {
        await initializeController();
      }
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        ccLog(
          '[AudioBubbleState] Cannot play — controller not initialized for id: $id',
        );
        _playState = PlayStates.stopped;
        _notifyStateUpdate();
        return;
      }
      try {
        AudioStateManager().pauseAllExcept(id);
        if (_playsLocalFile) await VoiceNoteAudioSession.takeForSpeaker(id);
        _playState = PlayStates.playing;
        await controller.play();
        _notifyStateUpdate();
      } catch (e, stack) {
        ccLog('[AudioBubbleState] Error playing audio for id: $id — $e');
        debugPrintStack(stackTrace: stack);
        _playState = PlayStates.stopped;
        _notifyStateUpdate();
      }
    }
  }

  Future<void> pauseAudio() async {
    if (kIsWeb) {
      _webPlayer?.pause();
      _playState = PlayStates.paused;
      _notifyStateUpdate();
    } else {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
        _playState = PlayStates.paused;
        _notifyStateUpdate();
      }
      await VoiceNoteAudioSession.release(id);
    }
  }

  Future<void> stopAudio() async {
    if (kIsWeb) {
      _webPlayer?.pause();
      _webPlayer?.seekTo(Duration.zero);
      _playState = PlayStates.stopped;
      _currentPosition = Duration.zero;
      _notifyStateUpdate();
    } else {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
        await controller.seekTo(Duration.zero);
        _playState = PlayStates.stopped;
        _currentPosition = Duration.zero;
        _notifyStateUpdate();
      }
      await VoiceNoteAudioSession.release(id);
    }
  }

  /// Seek to a specific duration
  Future<void> seekTo(Duration position) async {
    if (kIsWeb) {
      _webPlayer?.seekTo(position);
      _currentPosition = position;
      _notifyStateUpdate();
    } else {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.seekTo(position);
        _currentPosition = position;
        _notifyStateUpdate();
      }
    }
  }

  /// Seek to a progress value (0.0 - 1.0)
  Future<void> seekToProgress(double progress) async {
    if (kIsWeb) {
      if (_webPlayer != null && _totalDuration != null) {
        final position = Duration(
          milliseconds:
              (_totalDuration!.inMilliseconds * progress.clamp(0.0, 1.0))
                  .round(),
        );
        await seekTo(position);
      }
    } else {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          _totalDuration != null) {
        final position = Duration(
          milliseconds:
              (_totalDuration!.inMilliseconds * progress.clamp(0.0, 1.0))
                  .round(),
        );
        await seekTo(position);
      }
    }
  }

  /// Get current playback progress (0.0 - 1.0)
  double get playbackProgress {
    if (_totalDuration == null || _totalDuration!.inMilliseconds == 0) {
      return 0.0;
    }
    return (_currentPosition.inMilliseconds / _totalDuration!.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  void _notifyStateUpdate() {
    if (!_stateController.isClosed) {
      _stateController.add(
        AudioStateUpdate(
          id: id,
          playState: _playState,
          isInitializing: _isInitializing,
          totalDuration: _totalDuration,
          currentPosition: _currentPosition,
        ),
      );
    }
  }

  /// Takes a url that only became available after this state was created —
  /// the sender's own message, whose attachment url exists once the upload
  /// finishes.
  ///
  /// Deliberately gentler than [updateLocalPath]: a player that is already
  /// initialised keeps playing, because the url it opened is still good for
  /// this session and the new one will be picked up on the next
  /// initialisation. Only a state with nothing working is reset, so the next
  /// play tap builds a controller from the url instead of finding no source
  /// at all.
  void adoptAudioUrl(String url) {
    audioUrl = url;

    final nativeLive = _controller?.value.isInitialized ?? false;
    final webLive = _webPlayer?.isInitialized ?? false;
    if (nativeLive || webLive) return;

    _disposeController();
    _disposeWebPlayer();
    _playState = PlayStates.init;
    _notifyStateUpdate();
  }

  void updateLocalPath(String path) {
    localPath = path;
    _playState = PlayStates.init;
    _disposeController();
    _disposeWebPlayer();
    _notifyStateUpdate();
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    unawaited(VoiceNoteAudioSession.release(id));
  }

  void _disposeWebPlayer() {
    _webPositionSub?.cancel();
    _webPositionSub = null;
    _webCompletionSub?.cancel();
    _webCompletionSub = null;
    _webPlayer?.dispose();
    _webPlayer = null;
  }

  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    _disposeWebPlayer();
    _stateController.close();
    unawaited(VoiceNoteAudioSession.release(id));
  }
}

enum PlayStates { playing, paused, stopped, init }

class AudioStateUpdate {
  final int id;
  final PlayStates playState;
  final bool isInitializing;
  final Duration? totalDuration;
  final Duration currentPosition;

  AudioStateUpdate({
    required this.id,
    required this.playState,
    required this.isInitializing,
    required this.totalDuration,
    required this.currentPosition,
  });
}
