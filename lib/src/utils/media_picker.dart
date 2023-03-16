import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../flutter_chat_ui_kit.dart';

enum FileType { image, video, audio, any, custom }

class PickedFile {
  PickedFile(
      {required this.name,
      required this.path,
      this.size,
      this.extension,
      this.fileType});

  final String name;
  final String path;
  final int? size;
  final String? extension;
  final String? fileType;
}

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<PickedFile?> takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      return PickedFile(name: image.name, path: image.path);
    } else {
      return null;
    }
  }

  static Future<PickedFile?> pickAnyFile() async {
    return await _getFilesFromMethodChannel(type: "any");
  }

  // static pickCustomFile() async {
  //   try {
  //     var result = await UIConstants.channel.invokeListMethod("pickFile",
  //         {"allowMultipleSelection": true, "withData": false, "type": "any"});
  //     print(result);
  //     if (result != null && result.first["path"] != null) {
  //       Map<String, dynamic> file = Map<String, dynamic>.from(result.first);
  //       return PickedFile(
  //         name: file["name"],
  //         path: file["path"],
  //         size: file["size"],
  //       );
  //     } else {
  //       return null;
  //     }
  //   } on PlatformException catch (e, stack) {
  //     debugPrint("$stack");
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  static Future<PickedFile?> pickImage() async {
    return _getFilesFromMethodChannel(type: "image");
  }

  static Future<PickedFile?> pickVideo() async {
    return _getFilesFromMethodChannel(type: "video");
  }

  static Future<PickedFile?> pickAudio() async {
    return _getFilesFromMethodChannel(type: "audio");
  }

  static List<String> videoExtensions = ['mp4', 'avi', 'mkv', 'mov', 'ts'];
  static List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    "bmp",
    "psd",
    "sgi",
    "tiff",
    "tga"
  ];
  static List<String> audioExtensions = ['mp3', "aac", "wav", "aiff", "caf"];
  static Future<PickedFile?> pickImageVideo() async {
    return await _getFilesFromMethodChannel(
        type: Platform.isIOS ? "imagevideo" : "custom",
        allowedExtensions: imageExtensions + videoExtensions);
  }

  static Future<PickedFile?> _getFilesFromMethodChannel(
      {String type = "any",
      bool? allowMultipleSelection = false,
      bool? withData = false,
      List<String>? allowedExtensions}) async {
    try {
      var result = await UIConstants.channel.invokeListMethod("pickFile", {
        "allowMultipleSelection": allowMultipleSelection,
        "withData": withData,
        "type": type,
        "allowedExtensions": allowedExtensions
      });
      if (result != null && result.first["path"] != null) {
        Map<String, dynamic> file = Map<String, dynamic>.from(result.first);
        String _name = file["name"];
        String _extension =
            _name.substring(_name.lastIndexOf(".") + 1).toLowerCase();
        String? _fileType = _getFileType(_extension);
        return PickedFile(
            name: _name,
            path: file["path"],
            size: file["size"],
            extension: _extension,
            fileType: _fileType);
      } else {
        return null;
      }
    } on PlatformException catch (e, stack) {
      debugPrint("$stack");
    } catch (e) {
      rethrow;
    }
  }

  static String? _getFileType(String extension) {
    if (imageExtensions.contains(extension)) {
      return MessageTypeConstants.image;
    } else if (videoExtensions.contains(extension)) {
      return MessageTypeConstants.video;
    } else if (audioExtensions.contains(extension)) {
      return MessageTypeConstants.audio;
    } else {
      return null;
    }
  }
}
