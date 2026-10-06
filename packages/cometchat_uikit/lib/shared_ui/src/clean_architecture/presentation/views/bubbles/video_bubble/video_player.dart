import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

import "../../../../clean_architecture.dart";
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform;

///Gives Full screen video player for [CometChatVideoBubble]
class VideoPlayer extends StatefulWidget {
  const VideoPlayer({
    super.key,
    required this.videoUrl,
    this.playPauseIcon,
    this.backIcon,
    this.fullScreenBackground,
    this.handleColor,
    this.playedColor,
    this.playFromFile = false,
  });

  final String videoUrl;

  final Icon? playPauseIcon;

  final Color? backIcon;

  final Color? fullScreenBackground;

  final Color? handleColor;

  final Color? playedColor;

  final bool playFromFile;

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController? _controller;

  bool _isOverlayVisible = false;
  bool _videoPlayedOnce = false;

  @override
  void initState() {
    super.initState();
    initializeVideo();
  }

  Future<void> initializeVideo() async {
    try {
      // On web, always use network URL (no local file access)
      if (!kIsWeb &&
          widget.playFromFile &&
          platform.fileExistsSync(widget.videoUrl)) {
        _controller = vp.VideoPlayerController.networkUrl(
          Uri.parse('file://${widget.videoUrl}'),
        );
      } else {
        _controller = vp.VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      }
      await _controller!.initialize().then((_) {
        _controller!.play();
        setState(() {}); // Refresh to display the video
      });
      _controller?.addListener(_onControllerUpdate);
    } catch (e) {
      ccLog('$e');
    }
  }

  void _onControllerUpdate() {
    setState(() {}); // Update progress bar and UI when the video state changes
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    if (_isOverlayVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_isOverlayVisible) {
          setState(() {
            _isOverlayVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: widget.fullScreenBackground ?? const Color(0xffFFFFFF),
        appBar: AppBar(
          leading: IconButton(
            tooltip: Translations.of(context).back,
            padding: const EdgeInsets.all(0),
            color: Colors.green,
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Image.asset(
              excludeFromSemantics: true,
              AssetConstants.back,
              package: UIConstants.packageName,
              color: widget.backIcon ?? const Color(0xff3399FF),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _toggleOverlay,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _controller == null || !_controller!.value.isInitialized
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: vp.VideoPlayer(_controller!),
                            ),
                          ),
                    if (_controller != null &&
                        (!_videoPlayedOnce || _isOverlayVisible))
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (!_videoPlayedOnce) {
                              _videoPlayedOnce = true;
                            }
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_controller != null && _isOverlayVisible)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _formatDuration(_controller!.value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: vp.VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: const EdgeInsets.all(0),
                            colors: vp.VideoProgressColors(
                              playedColor:
                                  widget.playedColor ?? Colors.transparent,
                              backgroundColor:
                                  widget.handleColor ?? Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_controller!.value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
