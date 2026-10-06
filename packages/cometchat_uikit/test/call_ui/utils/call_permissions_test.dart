/// `CallPermissions` asks through the same check as the UI Kit's call
/// components (round 2, P2-C02), so an app that asks first and the call
/// buttons agree on what a call needs.
///
///   flutter test test/call_ui/utils/call_permissions_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/utils/call_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PermissionChannelStub.remove);

  test('a voice call asks for the microphone only', () async {
    PermissionChannelStub.install(granted: true);

    expect(await CallPermissions.requestForCallType(isVideoCall: false), true);
    expect(PermissionChannelStub.requested, <int>[Permission.microphone.value]);
  });

  test('a video call needs the camera too', () async {
    PermissionChannelStub.install(
      granted: false,
      grantedPermissions: <Permission>{Permission.microphone},
    );

    expect(await CallPermissions.requestForCallType(isVideoCall: true), false);
    expect(await CallPermissions.requestMicrophoneAndCamera(), false);
    expect(await CallPermissions.requestMicrophone(), true);
    expect(PermissionChannelStub.cameraRequested, isTrue);
  });

  test('both granted: a video call may start', () async {
    PermissionChannelStub.install(granted: true);

    expect(await CallPermissions.requestMicrophoneAndCamera(), true);
  });

  test('a permanent refusal is a refusal', () async {
    PermissionChannelStub.install(granted: false, permanentlyDenied: true);

    expect(await CallPermissions.requestMicrophone(), false);
  });
}
