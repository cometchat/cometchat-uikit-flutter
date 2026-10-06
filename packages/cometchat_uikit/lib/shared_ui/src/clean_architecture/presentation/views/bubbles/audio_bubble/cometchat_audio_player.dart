import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../clean_architecture.dart';
import 'waveform_utils.dart';
import 'gesture_waveform.dart';
import '../../../../../logging/cometchat_log.dart';

/// Single-audio player widget (lazy loading + gesture-controlled waveform).
///
/// This is the internal player behind the media recorder's playback preview
/// and the legacy audio bubble factory — it is not itself a routed message
/// bubble. Voice notes render via [CometChatVoiceNoteBubble] and plain audio
/// files via [CometChatAudiosBubble].
///
/// Flow:
/// 1. Initial: Show play button + placeholder bars
/// 2. On first play: Download audio, generate waveform
/// 3. After download: Gesture-controlled seeking on waveform
///
/// Renamed from `CometChatAudioBubbleV2`; the old name survives as a
/// deprecated alias below so no import breaks.
class CometChatAudioPlayer extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Padding around the player.
  @Deprecated(
    'Has no effect. The player derives its spacing from the theme; wrap it in a Padding. Will be removed in 7.0.0.',
  )
  final EdgeInsetsGeometry? padding;

  /// Margin around the player.
  @Deprecated(
    'Has no effect. The player derives its spacing from the theme; wrap it in a Padding. Will be removed in 7.0.0.',
  )
  final EdgeInsetsGeometry? margin;

  const CometChatAudioPlayer({
    super.key,
    this.audioUrl,
    this.title,
    this.style,
    this.playIcon,
    this.pauseIcon,
    this.height,
    this.width,
    this.alignment,
    this.id,
    this.metadata,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.barCount = 40,
    this.padding,
    this.margin,
  });

  final String? audioUrl;
  final String? title;
  final CometChatVoiceNoteBubbleStyle? style;
  final Icon? playIcon;
  final Icon? pauseIcon;
  final double? height;
  final double? width;
  final BubbleAlignment? alignment;
  final int? id;
  final Map<String, dynamic>? metadata;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final int barCount;

  @override
  State<CometChatAudioPlayer> createState() => _CometChatAudioPlayerState();
}

class _CometChatAudioPlayerState extends State<CometChatAudioPlayer> {
  AudioBubbleState? _audioState;
  StreamSubscription<AudioStateUpdate>? _audioStateSubscription;
  StreamSubscription<AudioBubbleEvents>? _eventSubscription;

  late int _tag;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isPreparingToPlay = false; // true from tap until audio starts playing
  double _downloadProgress = 0.0; // 0.0 to 1.0
  int _waveformVersion = 0; // increments each time waveform data changes
  String? _localPath;
  List<double> _waveformData = [];

  // Separate notifier for playback progress — avoids full widget rebuild on every frame
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _durationNotifier = ValueNotifier<String>(
    '00:00 / --:--',
  );
  PlayStates _lastPlayState = PlayStates.init;
  bool _lastInitializing = false;

  // Theme caching
  late CometChatVoiceNoteBubbleStyle _style;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void initState() {
    super.initState();
    _tag = widget.id ?? DateTime.now().millisecondsSinceEpoch;
    _waveformData = WaveformUtils.generatePlaceholder(
      barCount: widget.barCount,
    );

    // Use metadata duration as initial display if available
    final metaDurationMs = widget.metadata?['audioDurationMs'] as int?;
    if (metaDurationMs != null && metaDurationMs > 0) {
      final dur = Duration(milliseconds: metaDurationMs);
      _durationNotifier.value = '00:00 / ${_formatDuration(dur)}';
    }

    _checkFileExists();
    _setupEventStreams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      _style = CometChatThemeHelper.getTheme<CometChatVoiceNoteBubbleStyle>(
        context: context,
        defaultTheme: CometChatVoiceNoteBubbleStyle.of,
      ).merge(widget.style);
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
      _typography =
          widget.typography ?? CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style != oldWidget.style) {
      _style = CometChatThemeHelper.getTheme<CometChatVoiceNoteBubbleStyle>(
        context: context,
        defaultTheme: CometChatVoiceNoteBubbleStyle.of,
      ).merge(widget.style);
    }
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      _colorPalette = widget.colorPalette!;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      _spacing = widget.spacing!;
    }
    if (widget.typography != oldWidget.typography &&
        widget.typography != null) {
      _typography = widget.typography!;
    }
  }

  void _setupEventStreams() {
    _eventSubscription = AudioBubbleStream().stream.asBroadcastStream().listen((
      event,
    ) {
      if (event.id != _tag && event.action == AudioBubbleActions.pausePlayer) {
        _audioState?.pauseAudio();
      } else if (event.action == AudioBubbleActions.stopPlayer) {
        _audioState?.stopAudio();
      }
    });
  }

  Future<void> _checkFileExists() async {
    final localPath = FileUtils.getLocalFilePath(widget.metadata) ?? '';
    if (FileUtils.isLocalFileAvailable(localPath)) {
      _localPath = localPath;
      _isDownloaded = true;
      _setupAudioState();
      // Generate real waveform in background — don't block UI
      unawaited(_generateWaveform());
    } else {
      String fileName = '';
      if (widget.id != null) fileName += '${widget.id}';
      if (widget.title != null) {
        if (fileName.isNotEmpty) fileName += '_';
        fileName += widget.title!;
      }
      String? path = await BubbleUtils.isFileDownloaded(
        fileName,
        fileUrl: widget.audioUrl,
      );
      if (path != null) {
        _localPath = path;
        _isDownloaded = true;
        _setupAudioState();
        // Generate real waveform in background — don't block UI
        unawaited(_generateWaveform());
      }
    }
    if (mounted) setState(() {});
  }

  void _setupAudioState() {
    _audioState = AudioStateManager().getAudioState(
      _tag,
      widget.audioUrl,
      _localPath,
    );
    ccLog(
      '[AudioBubble $_tag] _setupAudioState: audioState.id=${_audioState!.id}, localPath=$_localPath',
    );
    _audioStateSubscription?.cancel();
    _audioStateSubscription = _audioState!.stateStream.listen((update) {
      if (!mounted || update.id != _tag) return;

      // Update progress/duration via ValueNotifiers (no rebuild needed)
      _progressNotifier.value = _audioState!.playbackProgress;
      final pos = _audioState!.currentPosition;
      final dur = _audioState!.totalDuration ?? Duration.zero;
      _durationNotifier.value = _isDownloaded
          ? '${_formatDuration(pos)} / ${_formatDuration(dur)}'
          : '00:00 / --:--';

      // Trigger full rebuild when play state or initializing state changes
      final needsRebuild =
          update.playState != _lastPlayState ||
          update.isInitializing != _lastInitializing;
      if (needsRebuild) {
        _lastPlayState = update.playState;
        _lastInitializing = update.isInitializing;
        setState(() {});
      }
    });
    _audioState!.initializeController();
  }

  Future<void> _generateWaveform() async {
    if (_localPath != null && _localPath!.isNotEmpty) {
      // Phase 1: Show deterministic placeholder instantly (based on file path hash)
      final quickBars = WaveformUtils.generateWaveform(
        _localPath!,
        barCount: widget.barCount,
      );
      if (mounted) {
        setState(() {
          _waveformData = quickBars;
          _waveformVersion++;
        });
      }
      // Phase 2: Extract real waveform via native codec in background
      final accurate = await WaveformUtils.extractWaveformFromFile(
        _localPath!,
        barCount: widget.barCount,
      );
      if (mounted) {
        setState(() {
          _waveformData = accurate;
          _waveformVersion++;
        });
      }
    } else if (widget.audioUrl != null) {
      final amplitudes = WaveformUtils.generateWaveform(
        widget.audioUrl!,
        barCount: widget.barCount,
      );
      if (mounted) {
        setState(() {
          _waveformData = amplitudes;
          _waveformVersion++;
        });
      }
    }
  }

  Future<void> _onPlayTap() async {
    ccLog(
      '[AudioBubble $_tag] _onPlayTap: _isDownloaded=$_isDownloaded, _audioState=${_audioState != null}',
    );
    if (!_isDownloaded) {
      setState(() => _isPreparingToPlay = true);
      await _downloadAndPlay();
    } else {
      _togglePlayPause();
    }
  }

  Future<void> _downloadAndPlay() async {
    if (widget.audioUrl == null || _isDownloading) return;

    // On web, skip download — play directly from network URL
    if (kIsWeb) {
      _localPath = null;
      _isDownloaded = true;
      if (mounted) setState(() => _isPreparingToPlay = false);
      _setupAudioState();
      unawaited(_generateWaveform());
      await Future.delayed(const Duration(milliseconds: 100));
      unawaited(_audioState?.playAudio());
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      String fileName = '';
      if (widget.id != null) fileName += '${widget.id}';
      if (widget.title != null) {
        if (fileName.isNotEmpty) fileName += '_';
        fileName += widget.title!;
      }

      String? path = await _downloadFileWithProgress(
        widget.audioUrl!,
        fileName,
      );
      if (path != null) {
        _localPath = path;
        _isDownloaded = true;
        // Setup audio state immediately with placeholder bars
        if (mounted) setState(() => _isPreparingToPlay = false);
        _setupAudioState();
        // Generate real waveform in background — don't block playback
        unawaited(_generateWaveform());
        // Play after audio is initialized
        await Future.delayed(const Duration(milliseconds: 100));
        unawaited(_audioState?.playAudio());
      } else {
        ccLog('Audio download returned null for ${widget.audioUrl}');
      }
    } catch (e) {
      ccLog('Error downloading audio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isPreparingToPlay = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  /// Download file with progress tracking for large audio files
  Future<String?> _downloadFileWithProgress(
    String fileUrl,
    String fileName,
  ) async {
    if (kIsWeb) {
      // On web, use BubbleUtils.downloadFile which opens URL in new tab
      return BubbleUtils.downloadFile(fileUrl, fileName);
    }
    // On native, delegate to BubbleUtils which handles filesystem download
    return BubbleUtils.downloadFile(fileUrl, fileName);
  }

  void _togglePlayPause() {
    final playState = _audioState?.playState ?? PlayStates.init;
    ccLog(
      '[AudioBubble $_tag] _togglePlayPause: playState=$playState, controller=${_audioState?.controller != null}, initialized=${_audioState?.controller?.value.isInitialized}',
    );
    if (playState == PlayStates.playing) {
      _audioState?.pauseAudio();
    } else {
      // Tell every other audio player (voice notes, audio-file rows, staged
      // tray tiles) to pause before this one starts — only one plays at a
      // time across the whole app.
      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: _tag, action: AudioBubbleActions.pausePlayer),
      );
      _audioState?.playAudio();
    }
  }

  void _onSeek(double progress) {
    _audioState?.seekToProgress(progress);
  }

  @override
  void dispose() {
    _audioStateSubscription?.cancel();
    _eventSubscription?.cancel();
    _progressNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRight = widget.alignment == BubbleAlignment.right;
    final playState = _audioState?.playState ?? PlayStates.init;
    final isInitializing = _audioState?.isInitializing ?? false;

    // Fixed bar dimensions - consistent across all audio lengths
    const barWidth = 3.0;
    const barSpacing = 2.0;
    final gap = _spacing.padding2 ?? 8;

    return Padding(
      padding: EdgeInsets.all(_spacing.padding2 ?? 8),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause Button
            _buildPlayButton(isRight, playState, isInitializing),
            SizedBox(width: gap),
            // Waveform and Duration
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform — uses ValueListenableBuilder so only the painter repaints
                  RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _progressNotifier,
                      builder: (context, progress, _) {
                        return _buildWaveform(
                          progress,
                          isRight,
                          barWidth,
                          barSpacing,
                        );
                      },
                    ),
                  ),
                  SizedBox(height: _spacing.padding ?? 4),
                  // Duration — uses ValueListenableBuilder
                  ValueListenableBuilder<String>(
                    valueListenable: _durationNotifier,
                    builder: (context, durationText, _) {
                      return Text(
                        durationText,
                        style: TextStyle(
                          color:
                              _style.durationTextColor ??
                              (isRight
                                  ? _colorPalette.white
                                  : _colorPalette.neutral600),
                          fontSize:
                              _typography.caption2?.regular?.fontSize ?? 12,
                          fontWeight: _typography.caption2?.regular?.fontWeight,
                        ).merge(_style.durationTextStyle),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(
    bool isRight,
    PlayStates playState,
    bool isInitializing,
  ) {
    if (_isPreparingToPlay || isInitializing) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              value: _isDownloading && _downloadProgress > 0
                  ? _downloadProgress
                  : null, // null = indeterminate spinner
              color: _style.playIconColor ?? _colorPalette.primary,
            ),
            if (_isDownloading && _downloadProgress > 0)
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _style.playIconColor ?? _colorPalette.primary,
                ),
              ),
          ],
        ),
      );
    }

    final isPlaying = playState == PlayStates.playing;

    return Semantics(
      button: true,
      label: isPlaying
          ? Translations.of(context).pause
          : Translations.of(context).play,
      child: GestureDetector(
        onTap: _onPlayTap,
        child: CircleAvatar(
          radius: 20,
          backgroundColor:
              _style.playIconBackgroundColor ?? _colorPalette.white,
          child: isPlaying
              ? widget.pauseIcon ??
                    Icon(
                      Icons.pause,
                      size: 28,
                      color: _style.playIconColor ?? _colorPalette.primary,
                    )
              : widget.playIcon ??
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: _style.playIconColor ?? _colorPalette.primary,
                    ),
        ),
      ),
    );
  }

  Widget _buildWaveform(
    double progress,
    bool isRight,
    double barWidth,
    double barSpacing,
  ) {
    return GestureWaveform(
      key: ValueKey(_waveformVersion),
      amplitudes: _waveformData,
      progress: progress,
      playedColor: _getPlayedColor(isRight),
      unplayedColor: _getUnplayedColor(isRight),
      height: 24,
      // null width = fill available space from Flexible parent
      // Avoids LayoutBuilder which crashes inside IntrinsicWidth
      width: null,
      barWidth: barWidth,
      barSpacing: barSpacing,
      onSeek: _isDownloaded ? _onSeek : null,
      enabled: _isDownloaded,
      expectedBarCount: widget.barCount,
    );
  }

  Color _getPlayedColor(bool isRight) {
    return _style.audioBarColor ??
        (isRight
            ? _colorPalette.white ?? Colors.white
            : _colorPalette.primary ?? Colors.blue);
  }

  Color _getUnplayedColor(bool isRight) {
    final baseColor = _getPlayedColor(isRight);
    return baseColor.withValues(alpha: 0.5);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Deprecated former name of [CometChatAudioPlayer]. Kept as an alias so any
/// code that imported `CometChatAudioBubbleV2` keeps compiling — this is a
/// pure rename with no behavior change, not a removal.
@Deprecated('Renamed to CometChatAudioPlayer.')
typedef CometChatAudioBubbleV2 = CometChatAudioPlayer;
