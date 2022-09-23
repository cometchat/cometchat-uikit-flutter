import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:video_player/video_player.dart';

enum PlayStates { playing, paused, stopped, init }

///creates a widget that gives audio bubble
///
///used by default  when [messageObject.category]='message' and  [messageObject.type]=[MessageTypeConstants.audio]
class CometChatAudioBubble extends StatefulWidget {
  const CometChatAudioBubble({
    Key? key,
    required this.messageObject,
    this.style = const AudioBubbleStyle(),
    this.audioUrl,
    this.fileName,
  }) : super(key: key);

  ///[messageObject] MediaMessage object
  final MediaMessage? messageObject;

  ///[audioUrl] if audioUrl passed then that audioUrl is used instead of file name from message Object
  final String? audioUrl;

  /// if [fileName]  is present then that is displayed instead of file name from [messageObject]
  final String? fileName;

  ///[style]  Style component for audio Bubble
  final AudioBubbleStyle style;

  @override
  State<CometChatAudioBubble> createState() => _CometChatAudioBubbleState();
}

class _CometChatAudioBubbleState extends State<CometChatAudioBubble> {
  String? filePath;
  bool isInitializing = false;
  PlayStates playerStatus = PlayStates.init;
  String? fileName;
  String? audioUrl;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    setParameters();
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }

  setParameters() {
    if (widget.audioUrl != null) {
      audioUrl = widget.audioUrl;
    } else if (widget.messageObject != null) {
      audioUrl = widget.messageObject?.attachment?.fileUrl;
    }

    if (widget.fileName != null) {
      fileName = widget.fileName!;
    } else if (widget.messageObject != null) {
      fileName = widget.messageObject?.attachment?.fileName;
    }
  }

  playAudio() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      isInitializing = true;
      setState(() {});
      if (audioUrl != null) {
        _controller = VideoPlayerController.network(audioUrl!,
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
    return GestureDetector(
      onTap: () async {
        if (playerStatus == PlayStates.playing) {
          pauseAudio();
        } else {
          playAudio();
        }
      },
      child: Container(
        height: widget.style.height ?? 56,
        width:
            widget.style.width ?? MediaQuery.of(context).size.width * 65 / 100,
        padding: const EdgeInsets.only(left: 12, top: 7, bottom: 9, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isInitializing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xff3399FF),
                      strokeWidth: 3,
                    ))
                : playerStatus == PlayStates.playing
                    ? widget.style.playIcon ??
                        Image.asset(
                          "assets/icons/pause.png",
                          package: UIConstants.packageName,
                          color: const Color(0xff3399FF),
                        )
                    : widget.style.playIcon ??
                        Image.asset(
                          "assets/icons/play.png",
                          package: UIConstants.packageName,
                          color: const Color(0xff3399FF),
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
                  Text(fileName ?? 'Audio',
                      overflow: TextOverflow.ellipsis,
                      style: widget.style.titleStyle ??
                          const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff141414))),
                  Text(
                    Translations.of(context).audio,
                    style: widget.style.subtitleStyle ??
                        TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xff141414).withOpacity(0.58)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioBubbleStyle {
  const AudioBubbleStyle(
      {this.height,
      this.width,
      this.playIcon,
      this.titleStyle,
      this.subtitleStyle,
      this.stoppedIcon});

  ///[height] height of bubble
  final double? height;

  ///[width] width of bubble
  final double? width;

  ///[playIcon] audio play  icon
  final Icon? playIcon;

  final Icon? stoppedIcon;

  ///[titleStyle] file name text style
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle text style
  final TextStyle? subtitleStyle;
}
