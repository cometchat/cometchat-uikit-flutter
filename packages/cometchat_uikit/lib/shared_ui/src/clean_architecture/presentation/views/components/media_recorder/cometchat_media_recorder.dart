import '_microphone_visualizer.dart' show MicrophoneVisualizer;
import "../../../../clean_architecture.dart";
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

///[CometChatMediaRecorder] is a class that allows users to record audio  messages.
///It has a start button to start recording, a stop button to stop recording, a play button to play the recorded message, a pause button to pause the recorded message, a submit button to submit the recorded message and a close button to close the media recorder.
///
/// ```dart
/// CometChatMediaRecorder(
///  },
///  onClose: () {
///  print("Closed");
///  },
///  mediaRecorderStyle: MediaRecorderStyle(
///  backgroundColor: Colors.white,
///  border: Border.all(color: Colors.red),
///  borderRadius: BorderRadius.circular(10),
///  startButtonBackgroundColor: Colors.blue,
///  stopButtonBackgroundColor: Colors.red,
///  pauseButtonBackgroundColor: Colors.green,
///  ),
///  );
///  ```
///
class CometChatMediaRecorder extends StatefulWidget {
  const CometChatMediaRecorder({
    super.key,
    this.onSubmit,
    this.onClose,
    this.style,
    this.padding,
    this.startButtonIcon,
    this.pauseButtonIcon,
    this.deleteButtonIcon,
    this.stopButtonIcon,
    this.sendButtonIcon,
    this.mediaRecorderBloc,
  });

  ///[onSubmit] provides callback to the submit Icon/widget
  final Function(BuildContext, String)? onSubmit;

  ///[onClose] provides callback to the close Icon/widget
  final Function? onClose;

  ///[style] provides style to the media recorder
  final CometChatMediaRecorderStyle? style;

  ///[padding] provides padding to the media recorder
  final EdgeInsetsGeometry? padding;

  ///[startButtonIcon] defines the icon of the start button.
  final Widget? startButtonIcon;

  ///[pauseButtonIcon] defines the icon of the pause button.
  final Widget? pauseButtonIcon;

  ///[deleteButtonIcon] defines the icon of the delete button.
  final Widget? deleteButtonIcon;

  ///[stopButtonIcon] defines the icon of the stop button.
  final Widget? stopButtonIcon;

  ///[sendButtonIcon] defines the icon of the send button.
  final Widget? sendButtonIcon;

  ///[mediaRecorderBloc] Optional external MediaRecorderBloc instance.
  ///If provided, it is used instead of creating one internally and the widget
  ///does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc] — the seam that lets a test
  ///drive the recorder through its states without a live microphone.
  final MediaRecorderBloc? mediaRecorderBloc;

  @override
  State<CometChatMediaRecorder> createState() => _CometChatMediaRecorderState();
}

class _CometChatMediaRecorderState extends State<CometChatMediaRecorder> {
  late MediaRecorderBloc _bloc;
  bool _isExternalBloc = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaRecorderBloc != null) {
      _bloc = widget.mediaRecorderBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = MediaRecorderBloc();
      _bloc.add(const StartRecordingEvent());
    }
  }

  @override
  void dispose() {
    // an injected bloc belongs to its owner, so only close what we created
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  late CometChatMediaRecorderStyle mediaRecorderStyle;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  late CometChatTypography typography;

  @override
  void didChangeDependencies() {
    mediaRecorderStyle =
        CometChatThemeHelper.getTheme<CometChatMediaRecorderStyle>(
          context: context,
          defaultTheme: CometChatMediaRecorderStyle.of,
        ).merge(widget.style);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    typography = CometChatThemeHelper.getTypography(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<MediaRecorderBloc, MediaRecorderState>(
        buildWhen: (previous, current) =>
            previous.isRecording != current.isRecording ||
            previous.isCompleted != current.isCompleted ||
            previous.duration != current.duration ||
            previous.filePath != current.filePath,
        builder: (context, state) {
          return Container(
            padding:
                widget.padding ??
                EdgeInsets.only(
                  bottom: spacing.padding5 ?? 0,
                  top: spacing.padding3 ?? 0,
                ),
            decoration: BoxDecoration(
              color:
                  mediaRecorderStyle.backgroundColor ??
                  colorPalette.background1,
              border: mediaRecorderStyle.border,
              borderRadius:
                  mediaRecorderStyle.borderRadius ??
                  BorderRadius.only(
                    topLeft: Radius.circular(spacing.radius6 ?? 0),
                    topRight: Radius.circular(spacing.radius6 ?? 0),
                  ),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.padding5 ?? 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
                    child: state.isCompleted
                        ? CometChatAudioPlayer(
                            metadata: {
                              AudioBubbleConstants.localPath: state.filePath,
                              AudioBubbleConstants.usedByMediaRecorder: true,
                            },
                            alignment: BubbleAlignment.right,
                            width: MediaQuery.sizeOf(context).width - 40,
                            style: CometChatVoiceNoteBubbleStyle(
                              playIconColor:
                                  mediaRecorderStyle.playButtonIconColor,
                              backgroundColor: colorPalette.primary,
                              borderRadius: BorderRadius.circular(
                                spacing.radius3 ?? 0,
                              ),
                            ).merge(mediaRecorderStyle.audioBubbleStyle),
                          )
                        : _getAudioAnimation(
                            state,
                            mediaRecorderStyle,
                            colorPalette,
                            typography,
                            spacing,
                          ),
                  ),
                  _getActionItems(
                    state,
                    mediaRecorderStyle,
                    colorPalette,
                    spacing,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _getActionItems(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.isCompleted || state.duration > Duration.zero)
          _buttonWrapper(
            IconButton(
              tooltip: Translations.of(context).deleteRecording,
              padding: const EdgeInsets.all(0),
              constraints: const BoxConstraints(),
              icon:
                  widget.deleteButtonIcon ??
                  Image.asset(
                    excludeFromSemantics: true,
                    AssetConstants.delete48px,
                    package: UIConstants.packageName,
                    color:
                        mediaRecorderStyle.deleteButtonIconColor ??
                        colorPalette.iconSecondary,
                  ),
              onPressed: () async {
                _bloc.add(const CancelRecordingEvent());
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            24,
            colorPalette,
            spacing,
            mediaRecorderStyle.deleteButtonBackgroundColor,
            mediaRecorderStyle.deleteButtonBorderRadius,
            mediaRecorderStyle.deleteButtonBorder,
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.padding5 ?? 0),
          child: state.isCompleted
              ? _getSendButton(state, mediaRecorderStyle, colorPalette, spacing)
              : _getRecordButtons(
                  state,
                  mediaRecorderStyle,
                  colorPalette,
                  spacing,
                ),
        ),
        if (state.isCompleted || state.duration > Duration.zero)
          _buttonWrapper(
            state.isCompleted
                ? _getStartButton(
                    state,
                    mediaRecorderStyle,
                    colorPalette,
                    spacing,
                  )
                : _getStopButton(
                    state,
                    mediaRecorderStyle,
                    colorPalette,
                    spacing,
                  ),
            24,
            colorPalette,
            spacing,
            state.isCompleted
                ? mediaRecorderStyle.startButtonBackgroundColor
                : mediaRecorderStyle.stopButtonBackgroundColor,
            state.isCompleted
                ? mediaRecorderStyle.startButtonBorderRadius
                : mediaRecorderStyle.stopButtonBorderRadius,
            state.isCompleted
                ? mediaRecorderStyle.startButtonBorder
                : mediaRecorderStyle.stopButtonBorder,
          ),
      ],
    );
  }

  Widget _buttonWrapper(
    Widget child,
    double size,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
    Color? backgroundColor,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.padding2 ?? 0),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorPalette.background1,
        border:
            border ??
            Border.all(
              color: colorPalette.borderLight ?? Colors.transparent,
              width: 1,
            ),
        borderRadius:
            borderRadius ?? BorderRadius.circular(spacing.radiusMax ?? 0),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F101828).withValues(alpha: .06),
            blurRadius: 4,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0x0F101828).withValues(alpha: .1),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(height: size, width: size, child: child),
    );
  }

  Widget _getSendButton(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return _buttonWrapper(
      IconButton(
        tooltip: Translations.of(context).sendMessage,
        padding: const EdgeInsets.all(0),
        constraints: const BoxConstraints(),
        splashRadius: 32,
        icon:
            widget.sendButtonIcon ??
            Image.asset(
              excludeFromSemantics: true,
              AssetConstants.mediaRecorderSendIcon,
              package: UIConstants.packageName,
              color: mediaRecorderStyle.sendButtonIconColor,
            ),
        onPressed: () {
          if (state.isCompleted &&
              state.filePath != null &&
              state.filePath!.isNotEmpty) {
            if (widget.onSubmit != null) {
              widget.onSubmit!(context, state.filePath!);
            }
            Navigator.pop(context);
          }
        },
      ),
      32,
      colorPalette,
      spacing,
      mediaRecorderStyle.sendButtonBackgroundColor,
      mediaRecorderStyle.sendButtonBorderRadius,
      mediaRecorderStyle.sendButtonBorder,
    );
  }

  Widget _getAudioAnimation(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 120,
          width: 120,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state.isRecording)
                MicrophoneVisualizer(
                  isAnimating: state.isRecording,
                  startSize: 80,
                  endSize: 120,
                  color:
                      (mediaRecorderStyle.recordIndicatorColor ??
                              mediaRecorderStyle.recordIndicatorBackgroundColor)
                          ?.withValues(alpha: .05) ??
                      colorPalette.extendedPrimary50,
                  borderRadius:
                      mediaRecorderStyle.recordIndicatorBorderRadius ??
                      BorderRadius.circular(spacing.radiusMax ?? 0),
                ),
              if (state.isRecording)
                MicrophoneVisualizer(
                  isAnimating: state.isRecording,
                  startSize: 80,
                  endSize: 100,
                  color:
                      (mediaRecorderStyle.recordIndicatorColor ??
                              mediaRecorderStyle.recordIndicatorBackgroundColor)
                          ?.withValues(alpha: .1) ??
                      colorPalette.extendedPrimary100,
                  borderRadius:
                      mediaRecorderStyle.recordIndicatorBorderRadius ??
                      BorderRadius.circular(spacing.radiusMax ?? 0),
                ),
              Container(
                padding: EdgeInsets.all(spacing.padding4 ?? 0),
                decoration: BoxDecoration(
                  color: (state.duration > Duration.zero
                      ? mediaRecorderStyle.recordIndicatorBackgroundColor ??
                            colorPalette.iconHighlight
                      : mediaRecorderStyle.recordIndicatorBackgroundColor
                                ?.withValues(alpha: .2) ??
                            colorPalette.extendedPrimary200),
                  borderRadius:
                      mediaRecorderStyle.recordIndicatorBorderRadius ??
                      BorderRadius.circular(spacing.radiusMax ?? 0),
                  border: mediaRecorderStyle.recordIndicatorBorder,
                ),
                child: Image.asset(
                  AssetConstants.mic96px,
                  package: UIConstants.packageName,
                  color:
                      mediaRecorderStyle.recordIndicatorIconColor ??
                      colorPalette.white,
                  height: 48,
                  width: 48,
                ),
              ),
            ],
          ),
        ),
        state.duration > Duration.zero
            ? Text(
                _formatDuration(state.duration),
                style: TextStyle(
                  color:
                      mediaRecorderStyle.textColor ??
                      mediaRecorderStyle.textStyle?.color ??
                      colorPalette.textPrimary,
                  fontSize:
                      mediaRecorderStyle.textStyle?.fontSize ??
                      typography.heading4?.regular?.fontSize,
                  fontWeight:
                      mediaRecorderStyle.textStyle?.fontWeight ??
                      typography.heading4?.regular?.fontWeight,
                  fontFamily:
                      mediaRecorderStyle.textStyle?.fontFamily ??
                      typography.heading4?.regular?.fontFamily,
                ),
              )
            : const SizedBox(height: 19),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      return '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '00:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  Widget _getStopButton(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return IconButton(
      tooltip: Translations.of(context).stopRecording,
      padding: const EdgeInsets.all(0),
      constraints: const BoxConstraints(),
      icon:
          widget.stopButtonIcon ??
          Image.asset(
            excludeFromSemantics: true,
            AssetConstants.stop48px,
            package: UIConstants.packageName,
            color:
                mediaRecorderStyle.stopButtonIconColor ??
                colorPalette.iconSecondary,
          ),
      onPressed: () => _bloc.add(const StopRecordingEvent()),
    );
  }

  Widget _getRecordButtons(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return _buttonWrapper(
      state.isRecording
          ? _getPauseButton(state, mediaRecorderStyle, colorPalette, spacing)
          : _getStartButton(state, mediaRecorderStyle, colorPalette, spacing),
      32,
      colorPalette,
      spacing,
      state.isRecording
          ? mediaRecorderStyle.pauseButtonBackgroundColor
          : mediaRecorderStyle.startButtonBackgroundColor,
      state.isRecording
          ? mediaRecorderStyle.pauseButtonBorderRadius
          : mediaRecorderStyle.startButtonBorderRadius,
      state.isRecording
          ? mediaRecorderStyle.pauseButtonBorder
          : mediaRecorderStyle.startButtonBorder,
    );
  }

  Widget _getStartButton(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return IconButton(
      tooltip: Translations.of(context).startRecording,
      padding: const EdgeInsets.all(0),
      constraints: const BoxConstraints(),
      icon:
          widget.startButtonIcon ??
          Image.asset(
            excludeFromSemantics: true,
            AssetConstants.mic96px,
            package: UIConstants.packageName,
            color:
                mediaRecorderStyle.startButtonIconColor ??
                (state.isCompleted
                    ? colorPalette.iconSecondary
                    : colorPalette.error),
          ),
      onPressed: () => _bloc.add(const StartRecordingEvent()),
    );
  }

  Widget _getPauseButton(
    MediaRecorderState state,
    CometChatMediaRecorderStyle mediaRecorderStyle,
    CometChatColorPalette colorPalette,
    CometChatSpacing spacing,
  ) {
    return IconButton(
      tooltip: Translations.of(context).pauseRecording,
      padding: const EdgeInsets.all(0),
      constraints: const BoxConstraints(),
      icon:
          widget.pauseButtonIcon ??
          Image.asset(
            excludeFromSemantics: true,
            AssetConstants.pause72px,
            package: UIConstants.packageName,
            color:
                mediaRecorderStyle.pauseButtonIconColor ?? colorPalette.error,
          ),
      onPressed: () => _bloc.add(const PauseRecordingEvent()),
    );
  }
}
