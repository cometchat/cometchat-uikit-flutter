import '../../../src/call_permission_check.dart';

/// Utility to request microphone/camera permissions before starting a call.
///
/// On Android 6+ and iOS, microphone and camera access are runtime
/// permissions that must be granted before WebRTC can access the hardware.
/// Without this, the Calls SDK throws `SecurityError: Permission denied`
/// when creating audio/video tracks.
///
/// On Web, the browser handles permissions via its own getUserMedia prompt
/// when the WebRTC session starts — native permission_handler is not
/// supported. We return `true` immediately on web.
///
/// The UI Kit's call components ask through the same check, so a call
/// placed or answered from them and one an app starts after this answers
/// `true` need exactly the same permissions. They also tell a permanent
/// refusal apart, which they report to `onError` as
/// `PERMISSION_PERMANENTLY_DENIED`.
class CallPermissions {
  CallPermissions._();

  /// Request microphone permission (audio calls).
  /// Returns `true` if granted or already granted.
  static Future<bool> requestMicrophone() =>
      requestForCallType(isVideoCall: false);

  /// Request microphone + camera permissions (video calls).
  /// Returns `true` if both are granted.
  static Future<bool> requestMicrophoneAndCamera() =>
      requestForCallType(isVideoCall: true);

  /// Request the appropriate permissions for a call type.
  /// [isVideoCall] — if true, requests both microphone and camera.
  static Future<bool> requestForCallType({required bool isVideoCall}) async =>
      (await CallPermissionCheck.request(isVideoCall: isVideoCall)).isGranted;
}
