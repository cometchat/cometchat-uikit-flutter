import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:video_player/video_player.dart';

enum PlayStates { playing, paused, stopped, init }

///creates a widget that gives audio bubble
///
///used by default  when [messageObject.category]='message' and  [messageObject.type]=[MessageTypeConstants.audio]
class CometChatAudioBubble extends StatefulWidget {
  const CometChatAudioBubble(
      {Key? key,
      this.style = const AudioBubbleStyle(),
      this.audioUrl,
      this.title,
      this.subtitle,
      this.playIcon,
      this.pauseIcon,
      this.theme
      })
      : super(key: key);

  ///[audioUrl] if audioUrl passed then that audioUrl is used instead of file name from message Object
  final String? audioUrl;

  ///[title]  text to show in title
  final String? title;

  ///[subtitle]  text to show in subtitle
  final String? subtitle;

  ///[style]  Style component for audio Bubble
  final AudioBubbleStyle style;

  ///[playIcon] audio play icon
  final Icon? playIcon;

  ///[pauseIcon] audio pause icon
  final Icon? pauseIcon;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  @override
  State<CometChatAudioBubble> createState() => _CometChatAudioBubbleState();
}

class _CometChatAudioBubbleState extends State<CometChatAudioBubble> {
  bool isInitializing = false;
  PlayStates playerStatus = PlayStates.init;

  late CometChatTheme theme;

  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    theme = widget.theme ?? cometChatTheme;
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }

  playAudio() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      isInitializing = true;
      setState(() {});
      if (widget.audioUrl != null) {
        _controller = VideoPlayerController.network(widget.audioUrl!,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        await _controller?.initialize();
      }
      isInitializing = false;
    }

    playerStatus = PlayStates.playing;
    _controller?.play();
    setState(() {});
  }

  pauseAudio() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller?.pause();
      playerStatus = PlayStates.paused;
    }

    setState(() {});
  }

  stopAudio() async {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller?.pause();
      await _controller?.initialize();
      playerStatus = PlayStates.stopped;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.style.height ?? 56,
      width: widget.style.width ?? MediaQuery.of(context).size.width * 65 / 100,
      padding: const EdgeInsets.only(left: 12, top: 7, bottom: 9, right: 12),
      decoration: BoxDecoration(
          color: widget.style.gradient == null
              ? widget.style.background ??
                  theme.palette.getAccent100()
              : null,
          border: widget.style.border,
          borderRadius: BorderRadius.circular(widget.style.borderRadius ?? 8),
          gradient: widget.style.gradient),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              if (playerStatus == PlayStates.playing) {
                pauseAudio();
              } else {
                playAudio();
              }
            },
            child: isInitializing
                ?  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: theme.palette.getPrimary(),
                      strokeWidth: 3,
                    ))
                : playerStatus == PlayStates.playing
                    ? widget.pauseIcon ??
                        Image.asset(
                          AssetConstants.pause,
                          package: UIConstants.packageName,
                          color: widget.style.pauseIconTint ??
                               theme.palette.getPrimary(),
                        )
                    : widget.playIcon ??
                        Image.asset(
                          AssetConstants.play,
                          package: UIConstants.packageName,
                          color: widget.style.playIconTint ??
                               theme.palette.getPrimary(),
                        ),
          ),
          const SizedBox(
            width: 16,
          ),
          Flexible(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(widget.title ?? Translations.of(context).audio,
                      overflow: TextOverflow.ellipsis,
                      style: widget.style.titleStyle ??
                           TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: theme.palette.getAccent())),
                ),
                Flexible(
                  child: Text(
                    widget.subtitle ?? Translations.of(context).audio,
                    style: widget.style.subtitleStyle ??
                        TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: theme.palette.getAccent600()),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
