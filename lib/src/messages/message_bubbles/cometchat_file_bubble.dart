import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import 'bubble_utils.dart';

///creates a widget that gives file bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.file]
class CometChatFileBubble extends StatefulWidget {
  const CometChatFileBubble(
      {Key? key,
      this.messageObject,
      this.style = const FileBubbleStyle(),
      this.title,
      this.subtitle,
      this.fileUrl,
      this.fileMimeType,
      this.id})
      : super(key: key);

  ///[messageObject] MediaMessage object
  final MediaMessage? messageObject;

  ///[title] if title passed then that title is displayed instead of file name from [messageObject]
  final String? title;

  ///[subtitle] subtitle to displayed below title
  final String? subtitle;

  ///[fileUrl] if message message object is not passed then file url should be passed to download the file
  final String? fileUrl;

  ///[fileMimeType] file mime type to open the file if message object is not passed
  final String? fileMimeType;

  ///[style] file bubble style
  final FileBubbleStyle style;

  ///[id] message object id to make file name unique
  final int? id;

  @override
  State<CometChatFileBubble> createState() => _CometChatFileBubbleState();
}

class _CometChatFileBubbleState extends State<CometChatFileBubble> {
  bool isFileDownloading = false;
  bool isFileExists = false;

  String? fileName;
  String? subtitle;
  String? fileUrl;
  String? fileMimeType;
  late int id;

  @override
  void initState() {
    super.initState();

    setParameters();
  }

  setParameters() {
    if (widget.messageObject != null &&
        widget.messageObject!.attachment != null) {
      fileName = widget.messageObject!.attachment!.fileName;
      // subtitle = "Shared File";
      fileUrl = widget.messageObject!.attachment!.fileUrl;
      fileMimeType = widget.messageObject!.attachment!.fileMimeType;
    }
    if (widget.title != null) {
      fileName = widget.title;
    }
    if (widget.subtitle != null) {
      subtitle = widget.subtitle;
    }
    if (widget.fileUrl != null) {
      fileUrl = widget.fileUrl;
    }
    if (widget.fileMimeType != null) {
      fileMimeType = widget.fileMimeType;
    }

    if (widget.id != null && widget.id != 0) {
      id = widget.id!;
    } else if (widget.messageObject != null) {
      id = widget.messageObject!.id;
    }

    fileExists();
  }

  fileExists() async {
    // ToDo: file name
    String? _path = await BubbleUtils.isFileDownloaded(
        "${widget.messageObject!.id}_$fileName");

    if (_path == null) {
      isFileExists = false;
    } else {
      isFileExists = true;
    }
    debugPrint("File Exist $isFileExists");
    if (mounted) {
      setState(() {});
    }
  }

  openFile() async {
    if (isFileExists) {
      String filePath = '${BubbleUtils.fileDownloadPath}/${id}_$fileName';
      MethodChannel _channel = const MethodChannel('flutter_chat_ui_kit');

      try {
        //OpenFile.open(filePath);
        debugPrint("Opening Path = $filePath");
        final _result = await _channel.invokeMethod(
            'open_file', {'file_path': filePath, 'file_type': fileMimeType});
        debugPrint(_result);
      } catch (e) {
        debugPrint('$e');
        debugPrint("Could not open file");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: openFile,
      child: Container(
        height: widget.style.height ?? 56,
        width:
            widget.style.width ?? MediaQuery.of(context).size.width * 65 / 100,
        padding: const EdgeInsets.only(left: 12, top: 7, bottom: 9, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName ?? Translations.of(context).file,
                      overflow: TextOverflow.ellipsis,
                      style: widget.style.titleStyle ??
                          const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff141414))),
                  Text(
                    subtitle ?? Translations.of(context).shared_file,
                    style: widget.style.subtitleStyle ??
                        TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xff141414).withOpacity(0.58)),
                  )
                ],
              ),
            ),
            if (isFileExists == false)
              isFileDownloading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Color(0xff3399FF),
                        strokeWidth: 3,
                      ))
                  : GestureDetector(
                      onTap: () async {
                        if (fileUrl != null) {
                          isFileDownloading = true;
                          setState(() {});
                          String _fileName =
                              '${widget.messageObject!.id}_$fileName';
                          String? _path = await BubbleUtils.downloadFile(
                              fileUrl!, _fileName);
                          if (_path == null) {
                            isFileExists = false;
                          } else {
                            isFileExists = true;
                          }
                          isFileDownloading = false;
                          setState(() {});
                        }
                      },
                      child: widget.style.downloadIcon ??
                          Image.asset(
                            "assets/icons/download.png",
                            package: UIConstants.packageName,
                            color: const Color(0xff3399FF),
                          ),
                    )
          ],
        ),
      ),
    );
  }
}

class FileBubbleStyle {
  const FileBubbleStyle({
    this.height,
    this.width,
    this.downloadIcon,
    this.titleStyle,
    this.subtitleStyle,
  });

  ///[height] height of bubble
  final double? height;

  ///[width] width of bubble
  final double? width;

  ///[playPauseIcon] video play pause icon
  final Icon? downloadIcon;

  ///[titleStyle] file name text style
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle text style
  final TextStyle? subtitleStyle;
}
