import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import '../../../messages/message_bubbles/bubble_utils.dart';

///creates a widget that gives file bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.file]
class CometChatFileBubble extends StatefulWidget {
  const CometChatFileBubble(
      {Key? key,
      this.style = const FileBubbleStyle(),
      this.title,
      this.subtitle,
      this.fileUrl,
      this.fileMimeType,
      this.id,
      this.downloadIcon,
      this.theme})
      : super(key: key);

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

  ///[downloadIcon] icon to press for downloading the file
  final Icon? downloadIcon;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  @override
  State<CometChatFileBubble> createState() => _CometChatFileBubbleState();
}

class _CometChatFileBubbleState extends State<CometChatFileBubble> {
  bool isFileDownloading = false;
  bool isFileExists = false;

  String fileName = '';
  String? subtitle;
  String? fileUrl;
  String? fileMimeType;

  late CometChatTheme theme;

  @override
  void initState() {
    super.initState();
    theme = widget.theme ?? cometChatTheme;
    setParameters();
  }

  setParameters() {
    if (widget.id != null) {
      fileName += '${widget.id}';
    }
    if (widget.title != null) {
      if (fileName.isNotEmpty) {
        fileName += '_';
      }
      fileName += widget.title!;
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

    fileExists();
  }

  fileExists() async {
    String? _path = await BubbleUtils.isFileDownloaded(fileName);

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
      String filePath = '${BubbleUtils.fileDownloadPath}/$fileName';
      MethodChannel _channel = const MethodChannel('flutter_chat_ui_kit');

      try {
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
        decoration: BoxDecoration(
            color: widget.style.gradient == null
                ? widget.style.background ?? theme.palette.getAccent100()
                : null,
            gradient: widget.style.gradient,
            border: widget.style.border,
            borderRadius:
                BorderRadius.circular(widget.style.borderRadius ?? 0)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(widget.title ?? Translations.of(context).file,
                        overflow: TextOverflow.ellipsis,
                        style: widget.style.titleStyle ??
                            TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: theme.palette.getAccent())),
                  ),
                  Flexible(
                    child: Text(
                      subtitle ?? Translations.of(context).shared_file,
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
            if (isFileExists == false)
              isFileDownloading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: theme.palette.getPrimary(),
                        strokeWidth: 3,
                      ))
                  : GestureDetector(
                      onTap: () async {
                        if (fileUrl != null) {
                          isFileDownloading = true;
                          setState(() {});
                          String? _path = await BubbleUtils.downloadFile(
                              fileUrl!, fileName);
                          if (_path == null) {
                            isFileExists = false;
                          } else {
                            isFileExists = true;
                          }
                          isFileDownloading = false;
                          setState(() {});
                        }
                      },
                      child: widget.downloadIcon ??
                          Image.asset(
                            AssetConstants.download,
                            package: UIConstants.packageName,
                            color: widget.style.downloadIconTint ??
                                theme.palette.getPrimary(),
                          ),
                    )
          ],
        ),
      ),
    );
  }
}
