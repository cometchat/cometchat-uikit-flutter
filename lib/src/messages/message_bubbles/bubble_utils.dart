import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:path_provider/path_provider.dart';

class BubbleUtils {
  static String fileDownloadPath = "";

  static setDownloadFilePath() async {
    if (Platform.isIOS) {
      fileDownloadPath = (await getTemporaryDirectory()).path;
    } else {
      fileDownloadPath = (await getExternalStorageDirectory())!.path;
    }
  }

  static final emailRegex = RegExp(
    r'^(.*?)((mailto:)?[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z][A-Z]+)',
    caseSensitive: false,
  );
  static final urlRegex =
      RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');

  static final phoneNumberRegex =
      RegExp(r'^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}');

  static Future<String?> downloadFile(String fileUrl, String fileName) async {
    try {
      await setDownloadFilePath();
      if (fileDownloadPath == "") {
        return null;
      }

      String _filePath = fileDownloadPath + "/" + fileName;
      final request = await HttpClient().getUrl(Uri.parse(fileUrl));
      final response = await request.close();
      response.pipe(File(_filePath).openWrite());
      debugPrint("Download path $_filePath");
      return _filePath;
    } catch (e) {
      debugPrint("Something went wrong");
      return null;
    }
  }

  static Future<String?> isFileDownloaded(String fileName) async {
    if (fileDownloadPath.isEmpty) {
      await setDownloadFilePath();
    }

    String _filePath = fileDownloadPath + "/" + fileName;

    if (File(_filePath).existsSync() == true) {
      return _filePath;
    } else {
      return null;
    }
  }
}

class Extensions {
  //Poll Constants
  static const String _options = "options";
  static const String _count = "count";
  static const String _total = "total";
  static const String _results = "results";

  static int getTotalVoteCount(BaseMessage baseMessage) {
    int voteCount = 0;
    Map result = getPollsResult(baseMessage);
    try {
      if (result.containsKey(_total)) {
        voteCount = result[_total];
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return voteCount;
  }

  static List<String> getVoterInfo(BaseMessage baseMessage, int totalOptions) {
    List<String> votes = [];
    Map result = getPollsResult(baseMessage);
    try {
      if (result.containsKey(_options)) {
        Map _optionsMap = result[_options];
        for (int k = 0; k < totalOptions; k++) {
          Map optionK = _optionsMap["${k + 1}"];
          votes.add(optionK[_count].toString());
        }
      }
    } catch (e, stack) {
      debugPrint("$stack");
    }
    return votes;
  }

  static Map<String, dynamic> getPollsResult(BaseMessage baseMessage) {
    Map<String, dynamic> _result = {};
    Map<String, Map>? extensionList = Extensions.extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.polls)) {
          Map? _polls = extensionList[ExtensionConstants.polls];
          if (_polls != null) {
            if (_polls.containsKey(_results)) {
              _result = _polls[_results];
            }
          }
        }
      } catch (e, stacktrace) {
        debugPrint("$stacktrace");
      }
    }
    return _result;
  }

  static Map<String, Map>? extensionCheck(BaseMessage baseMessage) {
    Map<String, dynamic>? metadata = baseMessage.metadata;
    Map<String, Map<String, dynamic>> extensionMap = {};
    try {
      if (metadata != null) {
        Map? injectedObject = metadata["@injected"];
        if (injectedObject != null &&
            injectedObject.containsKey(ExtensionConstants.extensions)) {
          Map extensionsObject = injectedObject[ExtensionConstants.extensions];
          if (extensionsObject.containsKey(ExtensionConstants.smartReply)) {
            extensionMap[ExtensionConstants.smartReply] =
                extensionsObject[ExtensionConstants.smartReply];
          }
          if (extensionsObject
              .containsKey(ExtensionConstants.messageTranslation)) {
            extensionMap[ExtensionConstants.messageTranslation] =
                extensionsObject[ExtensionConstants.messageTranslation];
          }
          if (extensionsObject
              .containsKey(ExtensionConstants.profanityFilter)) {
            extensionMap[ExtensionConstants.profanityFilter] =
                extensionsObject[ExtensionConstants.profanityFilter];
          }
          if (extensionsObject
              .containsKey(ExtensionConstants.imageModeration)) {
            extensionMap[ExtensionConstants.imageModeration] =
                extensionsObject[ExtensionConstants.imageModeration];
          }
          if (extensionsObject
              .containsKey(ExtensionConstants.thumbnailGeneration)) {
            extensionMap[ExtensionConstants.thumbnailGeneration] =
                extensionsObject[ExtensionConstants.thumbnailGeneration];
          }
          if (extensionsObject
              .containsKey(ExtensionConstants.sentimentalAnalysis)) {
            extensionMap[ExtensionConstants.sentimentalAnalysis] =
                extensionsObject[ExtensionConstants.sentimentalAnalysis];
          }
          if (extensionsObject.containsKey(ExtensionConstants.polls)) {
            extensionMap[ExtensionConstants.polls] =
                extensionsObject[ExtensionConstants.polls];
          }
          if (extensionsObject.containsKey(ExtensionConstants.reactions)) {
            if (extensionsObject[ExtensionConstants.reactions] is Map) {
              extensionMap[ExtensionConstants.reactions] =
                  extensionsObject[ExtensionConstants.reactions];
            }
          }
          if (extensionsObject.containsKey(ExtensionConstants.whiteboard)) {
            extensionMap[ExtensionConstants.whiteboard] =
                extensionsObject[ExtensionConstants.whiteboard];
          }
          if (extensionsObject.containsKey(ExtensionConstants.document)) {
            extensionMap[ExtensionConstants.document] =
                extensionsObject[ExtensionConstants.document];
          }
          if (extensionsObject.containsKey(ExtensionConstants.dataMasking)) {
            extensionMap[ExtensionConstants.dataMasking] =
                extensionsObject[ExtensionConstants.dataMasking];
          }
        }
        return extensionMap;
      } else {
        return null;
      }
    } catch (e, stack) {
      debugPrint("$stack");
    }
    return null;
  }

  static List<dynamic> getMessageLinks(BaseMessage message) {
    Map<String, dynamic>? metadata = message.metadata;
    List<dynamic> links = [];
    try {
      if (metadata != null) {
        Map? injectedObject = metadata["@injected"];
        if (injectedObject != null &&
            injectedObject.containsKey(ExtensionConstants.extensions)) {
          Map extensionsObject = injectedObject[ExtensionConstants.extensions];

          if (extensionsObject.containsKey(ExtensionConstants.linkPreview)) {
            Map<String, dynamic> linkPreview =
                extensionsObject[ExtensionConstants.linkPreview];
            links = linkPreview["links"];
          }
        }
      }
    } catch (e) {
      debugPrint('$e');
    }
    return links;
  }

  static String checkProfanityMessage(BaseMessage baseMessage) {
    String result = (baseMessage as TextMessage).text;
    Map<String, Map>? extensionList = extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.profanityFilter)) {
          Map<dynamic, dynamic>? profanityFilter =
              extensionList[ExtensionConstants.profanityFilter];

          if (profanityFilter != null) {
            String profanity = profanityFilter["profanity"];
            String cleanMessage = profanityFilter["message_clean"];

            if (profanity == "no") {
              result = (baseMessage).text;
            } else {
              result = cleanMessage;
            }
          }
        } else {
          result = (baseMessage).text;
        }
      } catch (e) {
        debugPrint("$e");
      }
    }
    return result;
  }

  static String checkDataMasking(BaseMessage baseMessage) {
    String result = (baseMessage as TextMessage).text;
    String sensitiveData;
    String messageMasked;
    Map<String, Map>? extensionList = extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.dataMasking)) {
          Map<dynamic, dynamic>? dataMasking =
              extensionList[ExtensionConstants.dataMasking];
          Map<dynamic, dynamic> dataObject = dataMasking?["data"];
          if (dataObject.containsKey("sensitive_data") &&
              dataObject.containsKey("message_masked")) {
            sensitiveData = dataObject["sensitive_data"];
            messageMasked = dataObject["message_masked"];
            if (sensitiveData == "no") {
              result = (baseMessage).text;
            } else {
              result = messageMasked;
            }
          } else if (dataObject.containsKey("action") &&
              dataObject.containsKey("message")) {
            result = dataObject["message"];
          }
        } else {
          result = (baseMessage).text;
        }
      } catch (e, stack) {
        debugPrint(stack.toString());
      }
    }
    return result;
  }

  static String? getThumbnailGeneration(BaseMessage baseMessage) {
    String? resultUrl;
    try {
      Map<String, Map>? extensionList = extensionCheck(baseMessage);
      if (extensionList != null &&
          extensionList.containsKey(ExtensionConstants.thumbnailGeneration)) {
        Map? thumbnailGeneration =
            extensionList[ExtensionConstants.thumbnailGeneration];
        if (thumbnailGeneration != null) {
          resultUrl = thumbnailGeneration["url_small"];
        }
      }
    } catch (e, stack) {
      debugPrint("$stack");
    }
    return resultUrl;
  }

  static bool checkImageModeration(MediaMessage mediaMessage) {
    Map<String, Map>? extensions = extensionCheck(mediaMessage);
    if (extensions != null) {
      try {
        if (extensions.containsKey(ExtensionConstants.imageModeration)) {
          Map<dynamic, dynamic>? imageModerationMap =
              extensions[ExtensionConstants.imageModeration];

          if (imageModerationMap != null) {
            String? unsafe = imageModerationMap["unsafe"];
            if (unsafe != null && unsafe.trim().toLowerCase() == "yes") {
              return true;
            }
          }
        }

        return false;
      } catch (e) {
        debugPrint("$e");
      }
    }
    return false;
  }
}
