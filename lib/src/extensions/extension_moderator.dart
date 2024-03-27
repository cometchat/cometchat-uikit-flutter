import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';

///[ExtensionModerator] is an utility class that scans for information of applied extensions inside the metadata of a [BaseMessage]
class ExtensionModerator {
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
          if (extensionsObject.containsKey(ExtensionConstants.linkPreview)) {
            extensionMap[ExtensionConstants.linkPreview] =
                extensionsObject[ExtensionConstants.linkPreview];
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
}
