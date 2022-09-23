import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../flutter_chat_ui_kit.dart';

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

  static Future<PickedFile?> pickFile(FileType type) async {
    if (Platform.isIOS && (type == FileType.video || type == FileType.image)) {
      final XFile? image;
      if (type == FileType.video) {
        image = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        image = await _picker.pickImage(source: ImageSource.gallery);
      }
      if (image != null) {
        return PickedFile(name: image.name, path: image.path);
      } else {
        return null;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: type,
    );

    if (result != null && result.files.first.path != null) {
      PlatformFile file = result.files.first;
      return PickedFile(
          name: file.name,
          path: file.path!,
          size: file.size,
          extension: file.extension);
    } else {
      return null;
    }
  }

  static Future<PickedFile?> pickAnyFile() async {
    return pickFile(FileType.any);
  }

  static Future<PickedFile?> pickImage() async {
    return pickFile(FileType.image);
  }

  static Future<PickedFile?> pickVideo() async {
    return pickFile(FileType.video);
  }

  static Future<PickedFile?> pickAudio() async {
    return pickFile(FileType.audio);
  }

  static List<String> videoExtensions = ['mp4', 'avi', 'mkv'];
  static List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'gif'];
  static Future<PickedFile?> pickImageVideo() async {
    // if (Platform.isIOS) {
    //   final XFile? image;
    //   image = await _picker.pickImage(source: ImageSource.gallery);
    //   debugPrint(image?.path);
    //   if (image != null) {
    //     return PickedFile(
    //       name: image.name,
    //       path: image.path,
    //       fileType: MessageTypes.image,
    //     );
    //   } else {
    //     return null;
    //   }
    // }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imageExtensions + videoExtensions);

    if (result != null && result.files.first.path != null) {
      PlatformFile file = result.files.first;
      return PickedFile(
          name: file.name,
          path: file.path!,
          size: file.size,
          extension: file.extension,
          fileType: imageExtensions.contains(file.extension)
              ? MessageTypeConstants.image
              : MessageTypeConstants.video);
    } else {
      return null;
    }
  }
}
