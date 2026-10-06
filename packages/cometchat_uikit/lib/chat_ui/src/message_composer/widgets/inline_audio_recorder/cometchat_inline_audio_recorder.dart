import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

import '../../../../../shared_ui/src/logging/cometchat_log.dart';
import 'web_audio_recorder_stub.dart'
    if (dart.library.js_interop) 'web_audio_recorder.dart';

/// An inline audio recorder widget that replaces the text input in the composer
/// when recording audio. Shows a waveform visualization with recording controls.
///
/// This widget provides a modern audio recording experience similar to
/// WhatsApp/iMessage style inline recording.
///
/// Layout:
/// `Trash` | `Record Indicator/Play` | `Waveform` | [Duration] | `Pause/Mic` | `Send`
///
/// Example usage:
/// ```dart
/// CometChatInlineAudioRecorder(
///   onSubmit: (path) => sendAudioMessage(path),
///   onCancel: () => hideRecorder(),
///   style: CometChatInlineAudioRecorderStyle(
///     waveformRecordingColor: Colors.red,
///   ),
/// )
/// ```
class CometChatInlineAudioRecorder extends StatefulWidget {
  const CometChatInlineAudioRecorder({
    super.key,
    this.onSubmit,
    this.onCancel,
    this.style,
    this.deleteIcon,
    this.sendIcon,
    this.recordIcon,
    this.pauseIcon,
    this.playIcon,
    this.stopIcon,
  });

  /// Callback when audio is submitted with the file path
  /// On web, `fileBytes` contains the audio data for upload
  final Function(String path, {List<int>? fileBytes})? onSubmit;

  /// Callback when recording is cancelled
  final VoidCallback? onCancel;

  /// Style configuration for the recorder
  final CometChatInlineAudioRecorderStyle? style;

  /// Custom delete/trash icon
  final Widget? deleteIcon;

  /// Custom send icon
  final Widget? sendIcon;

  /// Custom record icon
  final Widget? recordIcon;

  /// Custom pause icon
  final Widget? pauseIcon;

  /// Custom play icon
  final Widget? playIcon;

  /// Custom stop icon
  final Widget? stopIcon;

  @override
  State<CometChatInlineAudioRecorder> createState() =>
      _CometChatInlineAudioRecorderState();
}

class _CometChatInlineAudioRecorderState
    extends State<CometChatInlineAudioRecorder> {
  late InlineAudioRecorderBloc _bloc;
  late CometChatInlineAudioRecorderStyle _style;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  /// Method channel for native audio recording
  static const MethodChannel _channel = MethodChannel('cometchat_chat_uikit');

  /// Web audio recorder instance (only used on web)
  WebAudioRecorder? _webRecorder;
  StreamSubscription<double>? _webAmplitudeSubscription;

  /// Current recorded file path from native
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _bloc = InlineAudioRecorderBloc();
    // Start recording
    if (kIsWeb) {
      _startWebRecording();
    } else {
      _startNativeRecording();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _style = CometChatInlineAudioRecorderStyle.of(context).merge(widget.style);
  }

  @override
  void dispose() {
    // Release all media resources
    if (kIsWeb) {
      _webAmplitudeSubscription?.cancel();
      _webRecorder?.dispose();
    } else {
      _releaseMediaResources();
    }
    _bloc.close();
    super.dispose();
  }

  /// Start web audio recording using the record package
  Future<void> _startWebRecording() async {
    try {
      _webRecorder = WebAudioRecorder();

      // Listen to amplitude updates
      _webAmplitudeSubscription = _webRecorder!.amplitudeStream.listen((amp) {
        _bloc.add(UpdateAmplitude(amp));
      });

      final started = await _webRecorder!.startRecording();
      if (started) {
        _bloc.add(const StartRecording());
      } else {
        _bloc.add(
          const RecordingError(
            'Failed to start recording — microphone permission may be denied',
          ),
        );
      }
    } catch (e) {
      ccLog('[InlineAudioRecorder] Web recording error: $e');
      _bloc.add(RecordingError(e.toString()));
    }
  }

  /// Stop web recording and get the blob URL
  Future<String?> _stopWebRecording() async {
    if (_webRecorder == null) return null;
    try {
      final result = await _webRecorder!.stopRecording();
      if (result != null) {
        _recordedFilePath = result.path;
        return result.path;
      }
      return null;
    } catch (e) {
      ccLog('[InlineAudioRecorder] Web stop error: $e');
      return null;
    }
  }

  /// Release all native media resources (recording and playback)
  Future<void> _releaseMediaResources() async {
    try {
      await _channel.invokeMethod('releaseMediaResources', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Released all media resources');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error releasing media resources: $e');
      }
      // Fallback: try to stop recording individually
      unawaited(_stopNativeRecording());
    }
  }

  /// Start native audio recording via method channel
  Future<void> _startNativeRecording() async {
    try {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Starting native recording...');
      }

      final result = await _channel.invokeMethod('startRecordingAudio', {});

      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Native recording started: $result');
      }

      if (result == true) {
        _bloc.add(const StartRecording());
      } else {
        if (kDebugMode) {
          ccLog('[InlineAudioRecorder] Failed to start native recording');
        }
        _bloc.add(const RecordingError('Failed to start recording'));
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error starting native recording: $e');
      }
      _bloc.add(RecordingError(e.toString()));
    }
  }

  /// Stop native audio recording and get file path
  Future<String?> _stopNativeRecording() async {
    try {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Stopping native recording...');
      }

      final result = await _channel.invokeMethod('stopRecordingAudio', {});

      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Native recording stopped, path: $result');
      }

      if (result is String && result.isNotEmpty) {
        _recordedFilePath = result;
        return result;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error stopping native recording: $e');
      }
      return null;
    }
  }

  /// Pause native audio recording
  Future<void> _pauseNativeRecording() async {
    try {
      await _channel.invokeMethod('pauseRecordingAudio', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Native recording paused');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error pausing native recording: $e');
      }
    }
  }

  /// Extract waveform from the recorded file and update state
  Future<void> _extractAndSetWaveform() async {
    if (kDebugMode) {
      ccLog('[InlineAudioRecorder] Extracting waveform from recorded file...');
    }
    final waveform = await _extractWaveform(sampleCount: 50);
    if (kDebugMode) {
      ccLog(
        '[InlineAudioRecorder] Extracted waveform: ${waveform.length} samples',
      );
    }
    if (waveform.isNotEmpty) {
      _bloc.add(SetExtractedWaveform(waveform));
    }
  }

  /// Resume native audio recording
  /// Returns true if it was a true resume, false if it had to restart fresh
  Future<bool> _resumeNativeRecording() async {
    try {
      final result = await _channel.invokeMethod('resumeRecordingAudio', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Native recording resumed: $result');
      }
      // If result is true, it was a true resume
      // If result is false or the method had to restart, it's a fresh start
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error resuming native recording: $e');
      }
      return false;
    }
  }

  /// Play the recorded audio
  Future<void> _playRecordedAudio() async {
    try {
      await _channel.invokeMethod('playRecordedAudio', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Playing recorded audio');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error playing recorded audio: $e');
      }
    }
  }

  /// Pause playing the recorded audio
  Future<void> _pausePlayingRecordedAudio() async {
    try {
      await _channel.invokeMethod('pausePlayingRecordedAudio', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Paused playing recorded audio');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error pausing playback: $e');
      }
    }
  }

  /// Resume playing the recorded audio from current position
  Future<void> _resumePlayingRecordedAudio() async {
    try {
      await _channel.invokeMethod('resumePlayingRecordedAudio', {});
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Resumed playing recorded audio');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error resuming playback: $e');
      }
    }
  }

  /// Seek to a specific position in the recorded audio
  Future<void> _seekRecordedAudio(int positionMs) async {
    try {
      await _channel.invokeMethod('seekRecordedAudio', {
        'position': positionMs,
      });
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Seeked to position: $positionMs ms');
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error seeking audio: $e');
      }
    }
  }

  /// Extract waveform data from the recorded audio file
  Future<List<double>> _extractWaveform({int sampleCount = 50}) async {
    try {
      final result = await _channel.invokeMethod('extractWaveform', {
        'sampleCount': sampleCount,
      });
      if (kDebugMode) {
        ccLog(
          '[InlineAudioRecorder] Extracted waveform with ${(result as List?)?.length ?? 0} samples',
        );
      }
      if (result is List) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        ccLog('[InlineAudioRecorder] Error extracting waveform: $e');
      }
      return [];
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<InlineAudioRecorderBloc, InlineAudioRecorderState>(
        builder: (context, state) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding3 ?? 12,
              vertical: _spacing.padding3 ?? 12,
            ),
            decoration: BoxDecoration(
              color: _style.backgroundColor ?? _colorPalette.background1,
              border:
                  _style.border ??
                  Border.all(
                    color: _colorPalette.borderDefault ?? Colors.transparent,
                    width: 1,
                  ),
              borderRadius:
                  _style.borderRadius ??
                  BorderRadius.circular(_spacing.radius2 ?? 8),
            ),
            child: Row(
              children: [
                // Delete button
                _buildDeleteButton(state),

                SizedBox(width: _spacing.padding2 ?? 8),

                // Recording indicator (red dot) or Play button
                _buildRecordingIndicatorOrPlayButton(state),

                SizedBox(width: _spacing.padding2 ?? 8),

                // Waveform visualization
                Expanded(child: _buildWaveform(state)),

                SizedBox(width: _spacing.padding2 ?? 8),

                // Duration display
                _buildDurationDisplay(state),

                SizedBox(width: _spacing.padding2 ?? 8),

                // Pause/Resume/Mic button
                _buildPauseOrMicButton(state),

                SizedBox(width: _spacing.padding2 ?? 8),

                // Send button
                _buildSendButton(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeleteButton(InlineAudioRecorderState state) {
    return Semantics(
      label: Translations.of(context).deleteRecording,
      button: true,
      child: GestureDetector(
        onTap: () async {
          // Stop recording first
          if (kIsWeb) {
            await _webRecorder?.dispose();
          } else {
            await _stopNativeRecording();
          }
          _bloc.add(const CancelRecording());
          widget.onCancel?.call();
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _style.deleteButtonBackgroundColor ?? _colorPalette.transparent,
            shape: BoxShape.circle,
          ),
          child:
              widget.deleteIcon ??
              Icon(
                Icons.delete_outline,
                color:
                    _style.deleteButtonIconColor ?? _colorPalette.iconSecondary,
                size: 26,
              ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicatorOrPlayButton(InlineAudioRecorderState state) {
    if (state.isRecording) {
      // Show animated recording indicator (red dot)
      return _buildRecordingIndicator();
    } else if (state.isPlaying || state.isCompleted || state.isPaused) {
      // Show play/pause button for playback (including when playing)
      return _buildPlayPauseButton(state);
    }

    // Default - show recording indicator
    return _buildRecordingIndicator();
  }

  Widget _buildRecordingIndicator() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: _AnimatedRecordingDot(
        color:
            _style.recordingIndicatorColor ?? _colorPalette.error ?? Colors.red,
        size: 14,
      ),
    );
  }

  Widget _buildPlayPauseButton(InlineAudioRecorderState state) {
    final isPlaying = state.isPlaying;

    return Semantics(
      label: isPlaying ? 'Pause playback' : 'Play recording',
      button: true,
      child: GestureDetector(
        onTap: () async {
          if (isPlaying) {
            // Pause playback
            await _pausePlayingRecordedAudio();
            _bloc.add(const PausePlayback());
          } else {
            // Get current state from bloc
            final currentState = _bloc.state;

            // Check if we should resume from current position or start fresh
            if (currentState.currentPosition > Duration.zero &&
                currentState.currentPosition < currentState.duration) {
              // Resume from current position
              await _resumePlayingRecordedAudio();
              _bloc.add(const ResumePlayback());
            } else {
              // Start from beginning - this will finalize the recording file
              await _playRecordedAudio();
              _bloc.add(const PlayRecording());

              // Extract waveform after file is finalized (playRecordedAudio stops the recorder)
              // Only extract if we don't have extracted waveform yet
              if (currentState.extractedWaveform.isEmpty) {
                unawaited(_extractAndSetWaveform());
              }
            }
          }
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _style.playButtonBackgroundColor ?? _colorPalette.transparent,
            shape: BoxShape.circle,
          ),
          child: isPlaying
              ? (widget.pauseIcon ??
                    Icon(
                      Icons.pause,
                      color:
                          _style.pauseButtonIconColor ?? _colorPalette.primary,
                      size: 26,
                    ))
              : (widget.playIcon ??
                    Icon(
                      Icons.play_arrow,
                      color:
                          _style.playButtonIconColor ?? _colorPalette.primary,
                      size: 26,
                    )),
        ),
      ),
    );
  }

  Widget _buildWaveform(InlineAudioRecorderState state) {
    // Only animate (add new bars) when recording, NOT when playing
    final isAnimating = state.isRecording;
    // Keep primary color even when paused (don't turn grey)
    final waveformColor =
        _style.waveformRecordingColor ?? _colorPalette.primary;

    // Calculate playback progress (0.0 to 1.0)
    // Show progress when playing, paused during playback, or completed with position
    double playbackProgress = 0.0;
    if (state.duration.inMilliseconds > 0) {
      if (state.isPlaying ||
          (state.isPaused && state.currentPosition.inMilliseconds > 0) ||
          (state.isCompleted && state.currentPosition.inMilliseconds > 0)) {
        playbackProgress =
            state.currentPosition.inMilliseconds /
            state.duration.inMilliseconds;
      }
      playbackProgress = playbackProgress.clamp(0.0, 1.0);
    }

    // Use extracted waveform for playback if available, otherwise fall back to recording amplitudes
    final playbackAmplitudes = state.extractedWaveform.isNotEmpty
        ? state.extractedWaveform
        : state.amplitudes;

    if (kDebugMode && !isAnimating) {
      ccLog(
        '[InlineAudioRecorder] _buildWaveform: extractedWaveform.length=${state.extractedWaveform.length}, amplitudes.length=${state.amplitudes.length}',
      );
      ccLog(
        '[InlineAudioRecorder] _buildWaveform: using ${state.extractedWaveform.isNotEmpty ? "extractedWaveform" : "amplitudes"} with ${playbackAmplitudes.length} samples',
      );
    }

    return AudioWaveformVisualizer(
      isAnimating: isAnimating,
      isPlaying: state.isPlaying,
      playbackProgress: playbackProgress,
      barColor: waveformColor,
      playedBarColor: waveformColor, // Purple for played bars
      unplayedBarColor:
          _colorPalette.neutral300 ??
          Colors.grey.shade300, // Light grey for unplayed bars
      barWidth: 3.0,
      barSpacing: 2.0,
      minBarHeight: 4.0,
      maxBarHeight: 28.0,
      barCount: 35,
      // Pass extracted waveform for playback (when not recording), fall back to recording amplitudes
      amplitudes: !isAnimating ? playbackAmplitudes : null,
      // Store amplitudes during recording
      onAmplitudeReceived: isAnimating
          ? (amplitude) => _bloc.add(UpdateAmplitude(amplitude))
          : null,
      // Allow seeking only when not recording and has recording
      allowSeeking: !isAnimating && state.hasRecording,
      // Web amplitude stream for recording visualization
      amplitudeStream: kIsWeb ? _webRecorder?.amplitudeStream : null,
      // Handle seek - native seekTo already starts playback
      onSeek: !isAnimating && state.hasRecording
          ? (progress) async {
              // Calculate position in milliseconds
              final positionMs = (state.duration.inMilliseconds * progress)
                  .round();

              // Seek native audio player (this also starts playback)
              await _seekRecordedAudio(positionMs);

              // Update bloc state - SeekToPosition will set status to playing
              _bloc.add(SeekToPosition(progress));
            }
          : null,
    );
  }

  Widget _buildDurationDisplay(InlineAudioRecorderState state) {
    // Show current position during playback or when paused during playback
    // Otherwise show total duration
    final showPlaybackPosition =
        state.isPlaying ||
        (state.isPaused && state.currentPosition > Duration.zero) ||
        (state.isCompleted && state.currentPosition > Duration.zero);

    final duration = showPlaybackPosition
        ? state.currentPosition
        : state.duration;

    return Text(
      _formatDuration(duration),
      style: TextStyle(
        color: _style.durationTextColor ?? _colorPalette.textSecondary,
        fontSize: _typography.caption1?.regular?.fontSize ?? 12,
        fontWeight: _typography.caption1?.regular?.fontWeight,
        fontFamily: _typography.caption1?.regular?.fontFamily,
      ).merge(_style.durationTextStyle),
    );
  }

  Widget _buildPauseOrMicButton(InlineAudioRecorderState state) {
    if (state.isRecording) {
      // Show pause button when recording
      return _buildPauseButton();
    } else if (state.isPaused && !state.isCompleted) {
      // Show mic button to resume recording
      return _buildMicButton(isResume: true);
    } else if (state.isCompleted || state.isPlaying) {
      // Show mic button to re-record
      return _buildMicButton(isResume: false);
    }

    // Default - show mic button
    return _buildMicButton(isResume: false);
  }

  Widget _buildPauseButton() {
    return Semantics(
      label: Translations.of(context).pauseRecording,
      button: true,
      child: GestureDetector(
        onTap: () async {
          if (kIsWeb) {
            await _webRecorder?.pauseRecording();
          } else {
            await _pauseNativeRecording();
          }
          _bloc.add(const PauseRecording());
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _style.pauseButtonBackgroundColor ?? _colorPalette.transparent,
            shape: BoxShape.circle,
          ),
          child:
              widget.pauseIcon ??
              Icon(
                Icons.pause,
                color: _style.pauseButtonIconColor ?? _colorPalette.error,
                size: 26,
              ),
        ),
      ),
    );
  }

  Widget _buildMicButton({required bool isResume}) {
    return Semantics(
      label: isResume ? 'Resume recording' : 'Record again',
      button: true,
      child: GestureDetector(
        onTap: () async {
          if (isResume) {
            if (kIsWeb) {
              await _webRecorder?.resumeRecording();
              _bloc.add(const ResumeRecording(isFreshRestart: false));
            } else {
              final wasRealResume = await _resumeNativeRecording();
              // If it wasn't a real resume (had to restart), reset duration/amplitudes
              _bloc.add(ResumeRecording(isFreshRestart: !wasRealResume));
            }
          } else {
            // Re-record: start fresh recording
            if (kIsWeb) {
              await _webRecorder?.dispose();
              await _startWebRecording();
            } else {
              await _startNativeRecording();
            }
          }
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _style.recordButtonBackgroundColor ?? _colorPalette.transparent,
            shape: BoxShape.circle,
          ),
          child:
              widget.recordIcon ??
              Icon(
                Icons.mic,
                color: isResume
                    ? (_style.recordButtonIconColor ?? _colorPalette.error)
                    : (_style.recordButtonIconColor ??
                          _colorPalette.iconSecondary),
                size: 26,
              ),
        ),
      ),
    );
  }

  Widget _buildSendButton(InlineAudioRecorderState state) {
    final canSend = state.hasRecording || state.duration > Duration.zero;

    return Semantics(
      label: Translations.of(context).sendAudioMessage,
      button: true,
      enabled: canSend,
      child: GestureDetector(
        onTap: canSend
            ? () async {
                // Stop recording if still recording and get file path
                String? filePath = _recordedFilePath;
                if (state.isRecording || state.isPaused) {
                  if (kIsWeb) {
                    filePath = (await _stopWebRecording());
                  } else {
                    filePath = await _stopNativeRecording();
                  }
                  _bloc.add(const StopRecording());
                }

                // Submit the recording with the file path
                if (filePath != null && filePath.isNotEmpty) {
                  final bytes = kIsWeb ? _webRecorder?.recordedBytes : null;
                  widget.onSubmit?.call(filePath, fileBytes: bytes);
                } else if (kDebugMode) {
                  ccLog(
                    '[InlineAudioRecorder] No file path available for submission',
                  );
                }
              }
            : null,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: canSend
                ? (_style.sendButtonBackgroundColor ?? _colorPalette.primary)
                : (_colorPalette.neutral300),
            shape: BoxShape.circle,
          ),
          child:
              widget.sendIcon ??
              Icon(
                Icons.send,
                color: _style.sendButtonIconColor ?? _colorPalette.white,
                size: 20,
              ),
        ),
      ),
    );
  }
}

/// Animated recording indicator dot that pulses
class _AnimatedRecordingDot extends StatefulWidget {
  const _AnimatedRecordingDot({required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  State<_AnimatedRecordingDot> createState() => _AnimatedRecordingDotState();
}

class _AnimatedRecordingDotState extends State<_AnimatedRecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size * _animation.value,
          height: widget.size * _animation.value,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
