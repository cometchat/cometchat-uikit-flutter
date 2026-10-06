/// The one seam `media_picker_test.dart` documents as out of reach:
/// `MediaPicker._ensureAndroidPhotoPicker` opting the Android implementation
/// into the system Photo Picker.
///
/// It needs the real `ImagePickerAndroid` registered as
/// `ImagePickerPlatform.instance` — which a VM test can do, since
/// `image_picker_android` is a direct dependency and the class is plain Dart
/// (its method channel is only touched when a pick actually runs, and that
/// failure is caught by the picker).
///
/// This lives in its own file because the opt-in is latched behind a
/// file-level `bool` that is set on the first pick of the isolate; once
/// `media_picker_test.dart` has taken that first pick with its own fake, the
/// assignment can never be observed again in that isolate.
///
///   flutter test test/shared_ui/utils/media_picker_photo_picker_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The picker re-checks camera permission whenever a pick fails, on an
    // unawaited future; without a handler that would surface as an unhandled
    // MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(UIConstants.channel, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(UIConstants.channel, null);
  });

  test('the first pick opts Android into the system Photo Picker', () async {
    final android = ImagePickerAndroid();
    expect(
      android.useAndroidPhotoPicker,
      isFalse,
      reason:
          'the package default, which opens the Files browser instead '
          'of the gallery and demands a storage permission',
    );
    ImagePickerPlatform.instance = android;

    // The pick itself fails (no Android plugin on this host) and is caught;
    // what matters is the configuration that ran before it.
    expect(await MediaPicker.pickMultipleMedia(), isEmpty);
    expect(android.useAndroidPhotoPicker, isTrue);
  });

  test('the opt-in is latched, so a later implementation is left alone', () {
    // Documented as "runs once". Pinned because it means an app that swaps
    // the image_picker implementation after the first pick gets the old
    // ACTION_GET_CONTENT behaviour back with no warning.
    final second = ImagePickerAndroid();
    ImagePickerPlatform.instance = second;

    return MediaPicker.pickMultipleMedia().then((picked) {
      expect(picked, isEmpty);
      expect(second.useAndroidPhotoPicker, isFalse);
    });
  });
}
