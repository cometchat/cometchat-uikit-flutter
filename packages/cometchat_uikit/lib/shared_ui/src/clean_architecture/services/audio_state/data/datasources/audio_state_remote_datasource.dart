import 'dart:async';
import 'package:video_player/video_player.dart';
import '../../domain/entities/audio_state_entity.dart';
import '../../../../../logging/cometchat_log.dart';

/// Remote data source for audio state (in-memory implementation)
abstract class AudioStateRemoteDataSource {
  /// Get or create audio state
  Future<AudioStateEntity> getAudioState(
    int id,
    String? audioUrl,
    String? localPath,
  );

  /// Update audio state
  Future<AudioStateEntity> updateAudioState(AudioStateEntity state);

  /// Get stream of audio state updates
  Stream<AudioStateUpdateEntity> getAudioStateStream(int audioId);

  /// Play audio
  Future<void> playAudio(int audioId);

  /// Pause audio
  Future<void> pauseAudio(int audioId);

  /// Stop audio
  Future<void> stopAudio(int audioId);

  /// Stop all audio
  Future<void> stopAllAudio();

  /// Pause all except specified
  Future<void> pauseAllExcept(int excludeId);

  /// Remove audio state
  Future<void> removeAudioState(int audioId);

  /// Get current play state
  Future<PlayState> getPlayState(int audioId);

  /// Seek to position
  Future<void> seekToPosition(int audioId, Duration position);
}

/// Implementation of audio state data source
class AudioStateRemoteDataSourceImpl implements AudioStateRemoteDataSource {
  final Map<int, AudioStateEntity> _audioStates = {};
  final Map<int, VideoPlayerController?> _controllers = {};
  final Map<int, StreamController<AudioStateUpdateEntity>> _stateControllers =
      {};

  @override
  Future<AudioStateEntity> getAudioState(
    int id,
    String? audioUrl,
    String? localPath,
  ) async {
    if (_audioStates.containsKey(id)) {
      return _audioStates[id]!;
    }

    // Create new audio state
    final state = AudioStateEntity(
      id: id,
      audioUrl: audioUrl,
      localPath: localPath,
      playState: PlayState.init,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      isInitializing: false,
    );

    _audioStates[id] = state;
    _initializeStreamController(id);
    return state;
  }

  @override
  Future<AudioStateEntity> updateAudioState(AudioStateEntity state) async {
    _audioStates[state.id] = state;

    // Emit update through stream
    if (_stateControllers.containsKey(state.id)) {
      _stateControllers[state.id]?.add(
        AudioStateUpdateEntity(
          audioId: state.id,
          state: state.playState,
          currentPosition: state.currentPosition,
          totalDuration: state.totalDuration,
          errorMessage: state.errorMessage,
        ),
      );
    }

    return state;
  }

  @override
  Stream<AudioStateUpdateEntity> getAudioStateStream(int audioId) {
    if (!_stateControllers.containsKey(audioId)) {
      _initializeStreamController(audioId);
    }
    return _stateControllers[audioId]!.stream;
  }

  @override
  Future<void> playAudio(int audioId) async {
    final state = _audioStates[audioId];
    if (state != null) {
      try {
        var updatedState = state.copyWith(playState: PlayState.playing);
        await updateAudioState(updatedState);
      } catch (e) {
        ccLog('[AudioState] Error playing audio: $e');
      }
    }
  }

  @override
  Future<void> pauseAudio(int audioId) async {
    final state = _audioStates[audioId];
    if (state != null) {
      try {
        var updatedState = state.copyWith(playState: PlayState.paused);
        await updateAudioState(updatedState);
      } catch (e) {
        ccLog('[AudioState] Error pausing audio: $e');
      }
    }
  }

  @override
  Future<void> stopAudio(int audioId) async {
    final state = _audioStates[audioId];
    if (state != null) {
      try {
        var updatedState = state.copyWith(
          playState: PlayState.stopped,
          currentPosition: Duration.zero,
        );
        await updateAudioState(updatedState);
      } catch (e) {
        ccLog('[AudioState] Error stopping audio: $e');
      }
    }
  }

  @override
  Future<void> stopAllAudio() async {
    try {
      for (final state in _audioStates.values) {
        await stopAudio(state.id);
      }
    } catch (e) {
      ccLog('[AudioState] Error stopping all audio: $e');
    }
  }

  @override
  Future<void> pauseAllExcept(int excludeId) async {
    try {
      for (final state in _audioStates.values) {
        if (state.id != excludeId) {
          await pauseAudio(state.id);
        }
      }
    } catch (e) {
      ccLog('[AudioState] Error pausing all audio: $e');
    }
  }

  @override
  Future<void> removeAudioState(int audioId) async {
    try {
      final controller = _controllers[audioId];
      if (controller != null) {
        await controller.dispose();
      }

      final stateController = _stateControllers[audioId];
      if (stateController != null) {
        await stateController.close();
      }

      _audioStates.remove(audioId);
      _controllers.remove(audioId);
      _stateControllers.remove(audioId);
    } catch (e) {
      ccLog('[AudioState] Error removing audio state: $e');
    }
  }

  @override
  Future<PlayState> getPlayState(int audioId) async {
    return _audioStates[audioId]?.playState ?? PlayState.init;
  }

  @override
  Future<void> seekToPosition(int audioId, Duration position) async {
    final state = _audioStates[audioId];
    if (state != null) {
      try {
        var updatedState = state.copyWith(currentPosition: position);
        await updateAudioState(updatedState);
      } catch (e) {
        ccLog('[AudioState] Error seeking audio: $e');
      }
    }
  }

  void _initializeStreamController(int audioId) {
    if (!_stateControllers.containsKey(audioId)) {
      _stateControllers[audioId] =
          StreamController<AudioStateUpdateEntity>.broadcast();
    }
  }

  /// Dispose all resources
  void dispose() {
    for (final controller in _controllers.values) {
      controller?.dispose();
    }
    for (final stateController in _stateControllers.values) {
      stateController.close();
    }
    _audioStates.clear();
    _controllers.clear();
    _stateControllers.clear();
  }
}
