/// Behaviour tests for [MediaPicker].
///
/// [MediaPicker] is a facade over two platform seams, and both can be driven
/// from a VM test:
///
///  * the UI Kit's own `cometchat_chat_uikit` [MethodChannel] (`pickFile`,
///    `checkCameraPermission`), mocked through the test binary messenger, and
///  * `image_picker`, whose `ImagePickerPlatform.instance` is swappable.
///
/// What is asserted here is the Dart-side logic that sits between them: the
/// arguments handed to the native picker, the extension → file-type mapping,
/// which malformed platform replies are dropped and which are propagated, and
/// the error paths.
///
/// Not covered, deliberately:
///  * every `kIsWeb` branch (`_pickFileWeb`, `_webAccept`, `_fromWebPicked`,
///    and the web arms of `pickImage`/`pickVideo`/`pickAnyFile`/…).
///    `kIsWeb` is a compile-time constant and is always false under the VM
///    test runner, so those lines are unreachable here.
///  * the Android/iOS arms of `pickImage`/`pickVideo`/`pickImageVideo`.
///    They branch on `Platform.isAndroid` / `Platform.isIOS` from `dart:io`,
///    which report the host running the test (macOS/Linux in CI) and cannot be
///    overridden — `debugDefaultTargetPlatformOverride` does not touch them.
///    The desktop arm they fall through to is covered instead.
///  * `_ensureAndroidPhotoPicker`'s `useAndroidPhotoPicker = true` assignment,
///    which needs the real `ImagePickerAndroid` implementation registered.
///
///   flutter test test/shared_ui/utils/media_picker_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// `PickedFile` is the UI Kit's own class here, not the deprecated
// image_picker one, so the platform interface is imported by name.
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show
        ImagePickerOptions,
        ImagePickerPlatform,
        ImageSource,
        MediaOptions,
        XFile;

// ─── Seams ───────────────────────────────────────────────────────────────────

/// Swappable stand-in for the `image_picker` platform implementation.
///
/// Only the two entry points [MediaPicker] uses are overridden; everything
/// else keeps `ImagePickerPlatform`'s throwing defaults so an unexpected call
/// fails loudly instead of silently returning null.
class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker();

  /// What `getMedia` returns. Set per test.
  List<XFile> media = const [];

  /// What `getImageFromSource` returns. Set per test.
  XFile? cameraImage;

  /// Thrown instead of returning, when non-null.
  Object? throws;

  /// Every `getMedia` call's options, in order.
  final List<MediaOptions> mediaCalls = [];

  /// Every `getImageFromSource` call's source, in order.
  final List<ImageSource> sourceCalls = [];

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    mediaCalls.add(options);
    if (throws != null) throw throws!;
    return media;
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sourceCalls.add(source);
    if (throws != null) throw throws!;
    return cameraImage;
  }
}

/// An [XFile] whose `length()` resolves without touching the filesystem.
XFile _file(String name, {int size = 3, String? path}) => XFile.fromData(
  Uint8List.fromList(List<int>.filled(size, 0)),
  name: name,
  path: path ?? '/tmp/$name',
);

/// One `pickFile` reply entry as the native side shapes it.
Map<String, Object?> _entry(String name, {String? path, int? size = 11}) => {
  'name': name,
  'path': path ?? '/tmp/$name',
  'size': size,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeImagePicker picker;

  /// `pickFile` invocations recorded from the UI Kit channel.
  late List<Map<Object?, Object?>> pickFileArgs;

  /// What the mocked `pickFile` returns; `_throw` makes it throw instead.
  Object? pickFileResult;
  Object? pickFileThrows;

  /// What `checkCameraPermission` returns, and how many times it was asked.
  late bool cameraPermission;
  late int permissionChecks;

  setUp(() {
    picker = _FakeImagePicker();
    ImagePickerPlatform.instance = picker;
    pickFileArgs = [];
    pickFileResult = null;
    pickFileThrows = null;
    cameraPermission = true;
    permissionChecks = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(UIConstants.channel, (call) async {
          switch (call.method) {
            case 'pickFile':
              pickFileArgs.add(call.arguments as Map<Object?, Object?>);
              if (pickFileThrows != null) throw pickFileThrows!;
              return pickFileResult;
            case 'checkCameraPermission':
              permissionChecks++;
              return cameraPermission;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(UIConstants.channel, null);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // File-type classification
  //
  // `_getFileType` is private, so it is exercised through the pickers that
  // stamp `fileType` onto their result. The mapping drives which bubble the
  // composer builds for a staged attachment, so a wrong answer is visible.
  // ═══════════════════════════════════════════════════════════════════════════

  group('extension → fileType', () {
    test(
      'maps image, video and audio extensions, and leaves the rest null',
      () async {
        final cases = <String, String?>{
          'photo.JPG': MessageTypeConstants.image,
          'photo.heic': MessageTypeConstants.image,
          'clip.mp4': MessageTypeConstants.video,
          'clip.m2ts': MessageTypeConstants.video,
          'song.mp3': MessageTypeConstants.audio,
          'song.opus': MessageTypeConstants.audio,
          'notes.pdf': null,
          'archive.zip': null,
        };

        for (final entry in cases.entries) {
          pickFileResult = [_entry(entry.key)];
          final picked = await MediaPicker.pickAnyFile();
          expect(
            picked?.fileType,
            entry.value,
            reason: '${entry.key} classified wrongly',
          );
        }
      },
    );

    test('extension is taken after the last dot and lower-cased', () async {
      pickFileResult = [_entry('my.holiday.PNG')];
      final picked = await MediaPicker.pickAnyFile();
      expect(picked!.extension, 'png');
      expect(picked.fileType, MessageTypeConstants.image);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Single-file pickers over the UI Kit channel
  // ═══════════════════════════════════════════════════════════════════════════

  group('_getFilesFromMethodChannel', () {
    test(
      'pickAnyFile forwards type "any" and returns the first entry',
      () async {
        pickFileResult = [_entry('doc.pdf', path: '/files/doc.pdf', size: 42)];

        final picked = await MediaPicker.pickAnyFile();

        expect(pickFileArgs.single, {
          'allowMultipleSelection': false,
          'withData': false,
          'type': 'any',
          'allowedExtensions': null,
        });
        expect(picked!.name, 'doc.pdf');
        expect(picked.path, '/files/doc.pdf');
        expect(picked.size, 42);
        expect(picked.extension, 'pdf');
        expect(picked.fileType, isNull);
      },
    );

    test('pickAudio forwards type "audio"', () async {
      pickFileResult = [_entry('take.m4a')];

      final picked = await MediaPicker.pickAudio();

      expect(pickFileArgs.single['type'], 'audio');
      expect(picked!.fileType, MessageTypeConstants.audio);
    });

    test('the path is passed through verbatim, not URL-encoded', () async {
      // Encoding spaces/brackets here made the file unreadable downstream
      // (dart:io File wants the literal path) — see the comment in lib.
      pickFileResult = [
        _entry('my file [1].png', path: '/files/my file [1].png'),
      ];

      final picked = await MediaPicker.pickAnyFile();

      expect(picked!.path, '/files/my file [1].png');
    });

    test('a null reply yields null', () async {
      pickFileResult = null;
      expect(await MediaPicker.pickAnyFile(), isNull);
    });

    test('an entry with a null path yields null', () async {
      pickFileResult = [
        {'name': 'doc.pdf', 'path': null, 'size': 1},
      ];
      expect(await MediaPicker.pickAnyFile(), isNull);
    });

    test('a PlatformException is swallowed and yields null', () async {
      pickFileThrows = PlatformException(code: 'denied');
      expect(await MediaPicker.pickAnyFile(), isNull);
    });

    test('a non-PlatformException is rethrown to the caller', () async {
      pickFileThrows = MissingPluginException('no impl');
      await expectLater(MediaPicker.pickAnyFile(), throwsA(isA<Exception>()));
    });

    // FINDING: an empty (rather than null) `pickFile` reply is a plausible
    // "user cancelled" shape, but `_getFilesFromMethodChannel` reaches for
    // `result.first` before testing for emptiness. The StateError falls into
    // the bare `catch (e) { rethrow; }`, so an empty list surfaces to the
    // caller as a thrown StateError instead of the null every other
    // cancellation path returns. Pinned, not fixed.
    test(
      'an empty reply throws StateError instead of returning null',
      () async {
        pickFileResult = <Object?>[];
        await expectLater(MediaPicker.pickAnyFile(), throwsStateError);
      },
    );
  });

  group('pickImage / pickVideo / pickImageVideo', () {
    // On a desktop test host neither Platform.isAndroid nor Platform.isIOS is
    // true, so all three fall through to the "custom" arm that hands the
    // native side an explicit allow-list. That list is what stops the document
    // browser from offering unsupported formats.
    test('pickImage asks for custom with image+video extensions', () async {
      pickFileResult = [_entry('a.png')];

      await MediaPicker.pickImage();

      expect(pickFileArgs.single['type'], 'custom');
      expect(
        pickFileArgs.single['allowedExtensions'],
        MediaPicker.imageExtensions + MediaPicker.videoExtensions,
      );
    });

    test('pickVideo asks for custom with image+video extensions', () async {
      pickFileResult = [_entry('a.mp4')];

      await MediaPicker.pickVideo();

      expect(pickFileArgs.single['type'], 'custom');
      expect(
        pickFileArgs.single['allowedExtensions'],
        MediaPicker.imageExtensions + MediaPicker.videoExtensions,
      );
    });

    test(
      'pickImageVideo asks for custom with image+video extensions',
      () async {
        pickFileResult = [_entry('a.mov')];

        final picked = await MediaPicker.pickImageVideo();

        expect(pickFileArgs.single['type'], 'custom');
        expect(
          pickFileArgs.single['allowedExtensions'],
          MediaPicker.imageExtensions + MediaPicker.videoExtensions,
        );
        expect(picked!.fileType, MessageTypeConstants.video);
      },
    );

    test('the three extension lists are disjoint', () {
      // _getFileType checks image, then video, then audio, so an extension in
      // two lists would silently resolve to whichever comes first.
      final image = MediaPicker.imageExtensions.toSet();
      final video = MediaPicker.videoExtensions.toSet();
      final audio = MediaPicker.audioExtensions.toSet();
      expect(image.intersection(video), isEmpty);
      expect(image.intersection(audio), isEmpty);
      expect(video.intersection(audio), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Multi-select over the UI Kit channel
  // ═══════════════════════════════════════════════════════════════════════════

  group('_pickMultipleOfType', () {
    test(
      'pickMultipleAudio forwards the type, the multi flag and the limit',
      () async {
        pickFileResult = [_entry('a.mp3'), _entry('b.wav')];

        final picked = await MediaPicker.pickMultipleAudio(limit: 3);

        expect(pickFileArgs.single, {
          'allowMultipleSelection': true,
          'withData': false,
          'type': 'audio',
          'allowedExtensions': null,
          'limit': 3,
        });
        expect(picked.map((f) => f.name), ['a.mp3', 'b.wav']);
        expect(
          picked.map((f) => f.fileType),
          everyElement(MessageTypeConstants.audio),
        );
      },
    );

    test('pickMultipleAnyFiles forwards type "any"', () async {
      pickFileResult = [_entry('a.pdf')];

      final picked = await MediaPicker.pickMultipleAnyFiles(limit: 2);

      expect(pickFileArgs.single['type'], 'any');
      expect(picked.single.extension, 'pdf');
    });

    // The documented contract: a picker with no max (Android's document
    // picker) may return more than `limit`, and the whole over-sized batch is
    // handed back so the composer can reject it with a toast. Trimming to the
    // first N here is what the comment in lib explicitly rules out.
    test('an over-limit selection is returned in full, not trimmed', () async {
      pickFileResult = [_entry('a.pdf'), _entry('b.pdf'), _entry('c.pdf')];

      final picked = await MediaPicker.pickMultipleAnyFiles(limit: 1);

      expect(picked.length, 3);
    });

    test('entries with a missing or empty path are dropped', () async {
      pickFileResult = [
        _entry('good.pdf'),
        {'name': 'nopath.pdf', 'path': null, 'size': 1},
        {'name': 'empty.pdf', 'path': '', 'size': 1},
        _entry('also-good.pdf'),
      ];

      final picked = await MediaPicker.pickMultipleAnyFiles();

      expect(picked.map((f) => f.name), ['good.pdf', 'also-good.pdf']);
    });

    test(
      'a name with no dot yields an empty extension and no fileType',
      () async {
        pickFileResult = [_entry('README')];

        final picked = await MediaPicker.pickMultipleAnyFiles();

        expect(picked.single.extension, '');
        expect(picked.single.fileType, isNull);
      },
    );

    test('a null reply yields an empty list', () async {
      pickFileResult = null;
      expect(await MediaPicker.pickMultipleAnyFiles(), isEmpty);
    });

    test('an empty reply yields an empty list', () async {
      pickFileResult = <Object?>[];
      expect(await MediaPicker.pickMultipleAnyFiles(), isEmpty);
    });

    test('a PlatformException is swallowed and yields an empty list', () async {
      pickFileThrows = PlatformException(code: 'denied');
      expect(await MediaPicker.pickMultipleAudio(), isEmpty);
    });

    test('a non-PlatformException is rethrown', () async {
      pickFileThrows = MissingPluginException('no impl');
      await expectLater(
        MediaPicker.pickMultipleAnyFiles(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gallery multi-select over image_picker
  // ═══════════════════════════════════════════════════════════════════════════

  group('pickMultipleMedia', () {
    test(
      'maps each XFile, sizing from length() and classifying by extension',
      () async {
        picker.media = [_file('a.png', size: 7), _file('b.mp4', size: 9)];

        final picked = await MediaPicker.pickMultipleMedia(limit: 4);

        expect(picked.map((f) => f.name), ['a.png', 'b.mp4']);
        expect(picked.map((f) => f.size), [7, 9]);
        expect(picked.map((f) => f.extension), ['png', 'mp4']);
        expect(picked.map((f) => f.fileType), [
          MessageTypeConstants.image,
          MessageTypeConstants.video,
        ]);
        // Not web: bytes are left unread so a large gallery pick is not slurped
        // into memory.
        expect(picked.map((f) => f.bytes), everyElement(isNull));
      },
    );

    test('the limit is forwarded to the multi-select picker', () async {
      picker.media = [_file('a.png')];

      await MediaPicker.pickMultipleMedia(limit: 5);

      expect(picker.mediaCalls.single.allowMultiple, isTrue);
      expect(picker.mediaCalls.single.limit, 5);
    });

    // The native multi-pickers cannot express "at most one" (iOS PHPicker
    // requires a selectionLimit >= 2), so one remaining slot has to become a
    // single-item pick.
    test('a limit of 1 degrades to a single-item pick', () async {
      picker.media = [_file('a.png')];

      final picked = await MediaPicker.pickMultipleMedia(limit: 1);

      expect(picker.mediaCalls.single.allowMultiple, isFalse);
      expect(picked.single.name, 'a.png');
    });

    test('a limit of 1 with nothing chosen yields an empty list', () async {
      picker.media = const [];

      expect(await MediaPicker.pickMultipleMedia(limit: 1), isEmpty);
      expect(picker.mediaCalls.single.allowMultiple, isFalse);
    });

    test(
      'a name with no dot yields an empty extension and no fileType',
      () async {
        picker.media = [_file('scan', path: '/tmp/scan')];

        final picked = await MediaPicker.pickMultipleMedia();

        expect(picked.single.extension, '');
        expect(picked.single.fileType, isNull);
      },
    );

    test(
      'a failure yields an empty list and triggers a permission check',
      () async {
        picker.throws = PlatformException(code: 'photo_access_denied');

        final picked = await MediaPicker.pickMultipleMedia();

        expect(picked, isEmpty);
        // checkForPhotoPermission is fired unawaited; let it land.
        await Future<void>.delayed(Duration.zero);
        expect(permissionChecks, 1);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Camera
  // ═══════════════════════════════════════════════════════════════════════════

  group('takePhoto', () {
    test('returns the captured file with name and path', () async {
      picker.cameraImage = _file('IMG_1.jpg', path: '/cam/IMG_1.jpg');

      final picked = await MediaPicker.takePhoto();

      expect(picker.sourceCalls.single, ImageSource.camera);
      expect(picked!.name, 'IMG_1.jpg');
      expect(picked.path, '/cam/IMG_1.jpg');
      // FINDING (behavioural gap, pinned): unlike every other picker,
      // takePhoto does not populate size/extension/fileType, so a camera
      // capture reaches the composer without the size the SDK's ±10% upload
      // policy checks against.
      expect(picked.size, isNull);
      expect(picked.extension, isNull);
      expect(picked.fileType, isNull);
    });

    test(
      'a cancelled capture yields null and triggers a permission check',
      () async {
        picker.cameraImage = null;

        expect(await MediaPicker.takePhoto(), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(permissionChecks, 1);
      },
    );

    test(
      'a failed capture yields null and triggers a permission check',
      () async {
        picker.throws = PlatformException(code: 'camera_access_denied');

        expect(await MediaPicker.takePhoto(), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(permissionChecks, 1);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Permission probe
  // ═══════════════════════════════════════════════════════════════════════════

  group('checkForPhotoPermission', () {
    test('asks the native side and completes when granted', () async {
      cameraPermission = true;
      await MediaPicker.checkForPhotoPermission();
      expect(permissionChecks, 1);
    });

    test('completes without throwing when denied', () async {
      cameraPermission = false;
      await MediaPicker.checkForPhotoPermission();
      expect(permissionChecks, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PickedFile
  // ═══════════════════════════════════════════════════════════════════════════

  test('PickedFile keeps every field it is given', () {
    final file = PickedFile(
      name: 'a.png',
      path: '/tmp/a.png',
      size: 12,
      extension: 'png',
      fileType: MessageTypeConstants.image,
      bytes: const [1, 2, 3],
    );

    expect(file.name, 'a.png');
    expect(file.path, '/tmp/a.png');
    expect(file.size, 12);
    expect(file.extension, 'png');
    expect(file.fileType, MessageTypeConstants.image);
    expect(file.bytes, [1, 2, 3]);
  });

  test('FileType enumerates the picker kinds', () {
    expect(FileType.values, [
      FileType.image,
      FileType.video,
      FileType.audio,
      FileType.any,
      FileType.custom,
    ]);
  });
}
