import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../../../shared_ui/src/logging/cometchat_log.dart';

/// A widget that displays an audio waveform visualization that responds
/// to actual audio amplitude levels from the microphone.
///
/// New bars appear on the RIGHT with smooth animation and scroll LEFT.
/// During playback, bars progressively change color to show progress.
/// Supports tap and drag to seek through the audio.
class AudioWaveformVisualizer extends StatefulWidget {
  const AudioWaveformVisualizer({
    super.key,
    required this.isAnimating,
    this.isPlaying = false,
    this.playbackProgress = 0.0,
    this.barColor,
    this.playedBarColor,
    this.unplayedBarColor,
    this.barWidth = 4.0,
    this.barSpacing = 2.0,
    this.minBarHeight = 6.0,
    this.maxBarHeight = 32.0,
    this.barCount = 50,
    this.borderRadius,
    this.amplitudes,
    this.onAmplitudeReceived,
    this.onSeek,
    this.allowSeeking = true,
    this.amplitudeStream,
  });

  /// Whether the waveform should animate (recording)
  final bool isAnimating;

  /// Whether audio is currently playing back
  final bool isPlaying;

  /// Playback progress from 0.0 to 1.0
  final double playbackProgress;

  final Color? barColor;

  /// Color for bars that have been played (default: primary/purple)
  final Color? playedBarColor;

  /// Color for bars that haven't been played yet (default: grey)
  final Color? unplayedBarColor;

  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final double maxBarHeight;
  final int barCount;
  final BorderRadius? borderRadius;

  /// External amplitudes to display (used during playback)
  /// When provided, these are used instead of listening to the event channel
  final List<double>? amplitudes;

  /// Callback when a new amplitude is received during recording
  /// Use this to store amplitudes in parent state for playback
  final Function(double amplitude)? onAmplitudeReceived;

  /// Callback when user seeks to a position (0.0 to 1.0)
  /// Called on tap or drag on the waveform
  final Function(double progress)? onSeek;

  /// Whether to allow seeking by tap/drag (disabled during recording)
  final bool allowSeeking;

  /// Stream of amplitude values for web (where EventChannel is unavailable)
  final Stream<double>? amplitudeStream;

  @override
  State<AudioWaveformVisualizer> createState() =>
      _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  final List<double> _localBars = [];

  final EventChannel _eventChannel = const EventChannel(
    "cometchat_uikit_shared_audio_intensity",
  );

  StreamSubscription<dynamic>? _streamSubscription;

  late AnimationController _animationController;

  // For tracking drag/seek
  bool _isDragging = false;
  double _dragProgress = 0.0;

  // Throttle seek calls during drag
  DateTime? _lastSeekTime;
  static const _seekThrottleMs = 100; // Only seek every 100ms during drag

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );

    if (widget.isAnimating) {
      _startListening();
    }
  }

  @override
  void didUpdateWidget(AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _startListening();
      } else {
        _stopListening();
      }
    }
  }

  void _startListening() {
    _streamSubscription?.cancel();

    // On web, EventChannel is not available — use the provided amplitudeStream
    if (kIsWeb) {
      if (widget.amplitudeStream != null) {
        _streamSubscription = widget.amplitudeStream!.listen((amplitude) {
          _onAmplitudeReceived(amplitude);
        });
      }
      return;
    }

    try {
      _streamSubscription = _eventChannel.receiveBroadcastStream().listen(
        _onAmplitudeReceived,
        onError: (error) {
          if (kDebugMode) {
            ccLog('[AudioWaveformVisualizer] ERROR: $error');
          }
          if (error.toString().contains('MissingPluginException')) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && widget.isAnimating) {
                _startListening();
              }
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        ccLog('[AudioWaveformVisualizer] Exception: $e');
      }
    }
  }

  void _stopListening() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  void _onAmplitudeReceived(dynamic event) {
    if (!mounted || !widget.isAnimating) return;

    double amplitude = 0.0;

    if (event is double) {
      amplitude = event;
    } else if (event is int) {
      amplitude = event.toDouble();
    } else if (event is Map) {
      final value = event['amplitude'] ?? event['level'] ?? 0.0;
      if (value is num) {
        amplitude = value.toDouble();
      }
    } else {
      return;
    }

    amplitude = amplitude.clamp(0.0, 1.0);

    // Amplify for better visual response
    double visualAmplitude;
    if (amplitude < 0.1) {
      visualAmplitude = 0.15 + amplitude * 2.0;
    } else if (amplitude < 0.4) {
      visualAmplitude = 0.35 + (amplitude - 0.1) * 1.17;
    } else {
      visualAmplitude = 0.7 + (amplitude - 0.4) * 0.5;
    }

    final clampedAmplitude = visualAmplitude.clamp(0.15, 1.0);

    // Report to parent for storage
    widget.onAmplitudeReceived?.call(clampedAmplitude);

    // Also store locally for immediate display during recording
    setState(() {
      _localBars.add(clampedAmplitude);
    });
  }

  void _handleTapDown(TapDownDetails details, double totalWidth, int barCount) {
    if (!widget.allowSeeking || widget.isAnimating || barCount == 0) return;

    final progress = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
    widget.onSeek?.call(progress);
  }

  void _handleDragStart(
    DragStartDetails details,
    double totalWidth,
    int barCount,
  ) {
    if (!widget.allowSeeking || widget.isAnimating || barCount == 0) return;

    setState(() {
      _isDragging = true;
      _dragProgress = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    double totalWidth,
    int barCount,
  ) {
    if (!_isDragging || barCount == 0) return;

    final progress = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = progress;
    });

    // Throttle seek calls during drag to avoid overwhelming native player
    final now = DateTime.now();
    if (_lastSeekTime == null ||
        now.difference(_lastSeekTime!).inMilliseconds >= _seekThrottleMs) {
      _lastSeekTime = now;
      widget.onSeek?.call(progress);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    // Final seek to the exact position when drag ends
    widget.onSeek?.call(_dragProgress);

    setState(() {
      _isDragging = false;
    });
  }

  @override
  void dispose() {
    _stopListening();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.barColor ?? Theme.of(context).primaryColor;
    final playedColor = widget.playedBarColor ?? primaryColor;
    final unplayedColor = widget.unplayedBarColor ?? Colors.grey.shade400;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.barWidth / 2);

    return SizedBox(
      height: widget.maxBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalBarWidth = widget.barWidth + widget.barSpacing;
          final maxVisibleBars = (constraints.maxWidth / totalBarWidth).floor();

          // Use external amplitudes if provided (for playback), otherwise use local bars (for recording)
          final sourceBars =
              (widget.amplitudes != null && widget.amplitudes!.isNotEmpty)
              ? widget.amplitudes!
              : _localBars;

          // Get visible bars (most recent ones)
          final visibleBars = sourceBars.length > maxVisibleBars
              ? sourceBars.sublist(sourceBars.length - maxVisibleBars)
              : sourceBars;

          // Calculate total width of bars
          final barsWidth = visibleBars.length * totalBarWidth;
          final totalWidth = constraints.maxWidth;

          // Use drag progress while dragging, otherwise use playback progress
          final currentProgress = _isDragging
              ? _dragProgress
              : widget.playbackProgress;

          // Calculate which bar index the playback has reached
          final playedBarCount = (visibleBars.length * currentProgress).ceil();

          // Determine if we should show playback progress coloring
          final showPlaybackProgress =
              widget.isPlaying ||
              _isDragging ||
              (!widget.isAnimating && widget.playbackProgress > 0);

          // Wrap with gesture detector for seeking
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:
                widget.allowSeeking &&
                    !widget.isAnimating &&
                    visibleBars.isNotEmpty
                ? (details) =>
                      _handleTapDown(details, totalWidth, visibleBars.length)
                : null,
            onHorizontalDragStart:
                widget.allowSeeking &&
                    !widget.isAnimating &&
                    visibleBars.isNotEmpty
                ? (details) =>
                      _handleDragStart(details, totalWidth, visibleBars.length)
                : null,
            onHorizontalDragUpdate:
                widget.allowSeeking &&
                    !widget.isAnimating &&
                    visibleBars.isNotEmpty
                ? (details) =>
                      _handleDragUpdate(details, totalWidth, visibleBars.length)
                : null,
            onHorizontalDragEnd: widget.allowSeeking && !widget.isAnimating
                ? _handleDragEnd
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Spacer to push bars to the right when few bars
                if (barsWidth < constraints.maxWidth)
                  SizedBox(width: constraints.maxWidth - barsWidth),

                // Bars with animation and playback progress coloring
                ...List.generate(visibleBars.length, (index) {
                  final amplitude = visibleBars[index];
                  final height =
                      widget.minBarHeight +
                      (widget.maxBarHeight - widget.minBarHeight) * amplitude;

                  // Determine bar color based on playback progress
                  Color barColor;
                  if (widget.isAnimating) {
                    // Recording - all bars are primary color
                    barColor = primaryColor;
                  } else if (showPlaybackProgress) {
                    // Playing or seeking - show progress
                    barColor = index < playedBarCount
                        ? playedColor
                        : unplayedColor;
                  } else {
                    // Paused recording (not playing) - all bars are primary color
                    barColor = primaryColor;
                  }

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: widget.minBarHeight, end: height),
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedHeight, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: widget.barWidth,
                        height: animatedHeight,
                        margin: EdgeInsets.only(right: widget.barSpacing),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: borderRadius,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
