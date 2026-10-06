import 'package:cometchat_sdk/cometchat_sdk.dart' show CometChatException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import '../shared_ui/src/logging/cometchat_log.dart';
import 'call_errors.dart';

/// What asking for a call's microphone (and camera) access came to.
///
/// Package-private (see `lib/src/`).
final class CallPermissionOutcome {
  const CallPermissionOutcome._({
    this.missing = const <String>[],
    this.permanentlyDenied = false,
  });

  /// Everything the call needs was granted.
  static const CallPermissionOutcome granted = CallPermissionOutcome._();

  /// The permissions not granted, as `microphone` / `camera`.
  final List<String> missing;

  /// Whether one of [missing] is permanently denied, so the system will not
  /// ask again and only the app's settings page can grant it.
  final bool permanentlyDenied;

  /// Whether the call has everything it needs.
  bool get isGranted => missing.isEmpty;

  /// The refusal `onError` gets: [CallErrorCodes.permissionPermanentlyDenied]
  /// or [CallErrorCodes.permissionDenied], with [missing] in `details`
  /// (comma separated) and in `errorParams['permissions']`. [message] is the
  /// text the component shows.
  CometChatException toException(String message) => CometChatException(
    permanentlyDenied
        ? CallErrorCodes.permissionPermanentlyDenied
        : CallErrorCodes.permissionDenied,
    missing.join(','),
    message,
    errorParams: <String, dynamic>{'permissions': List<String>.of(missing)},
  );
}

/// Asks for the permissions a call needs and says which are missing.
///
/// Package-private (see `lib/src/`). The same requests the public
/// `CallPermissions.requestForCallType` makes, but the answer tells a
/// permanent refusal from one the system can still ask about, so the call
/// components can report `PERMISSION_PERMANENTLY_DENIED` and a host can offer
/// its settings page.
abstract final class CallPermissionCheck {
  /// Requests the microphone, and the camera too for [isVideoCall]. On the
  /// web the browser asks when the call starts, so this grants at once.
  static Future<CallPermissionOutcome> request({
    required bool isVideoCall,
  }) async {
    if (kIsWeb) return CallPermissionOutcome.granted;
    final needed = <Permission>[
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];
    final statuses = await needed.request();
    final missing = <String>[];
    var permanentlyDenied = false;
    for (final permission in needed) {
      final status = statuses[permission] ?? PermissionStatus.denied;
      if (status.isGranted) continue;
      missing.add(permission == Permission.camera ? 'camera' : 'microphone');
      if (status.isPermanentlyDenied) permanentlyDenied = true;
    }
    if (missing.isEmpty) return CallPermissionOutcome.granted;
    ccLog(
      'CallPermissionCheck: missing ${missing.join(', ')}'
      '${permanentlyDenied ? ' (permanently denied)' : ''}',
    );
    return CallPermissionOutcome._(
      missing: missing,
      permanentlyDenied: permanentlyDenied,
    );
  }
}
