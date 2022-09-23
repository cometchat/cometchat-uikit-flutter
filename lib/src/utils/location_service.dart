import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      var result =
          await UIConstants.channel.invokeMethod("getCurrentLocation", {});
      Map<String, dynamic> res = Map<String, dynamic>.from(result);
      return res;
    } on PlatformException catch (e, stack) {
      debugPrint("$stack");
    } catch (e) {
      rethrow;
    }
    return {"status": false};
  }

  static Future<bool> getLocationPermission() async {
    try {
      final result =
          await UIConstants.channel.invokeMethod("getLocationPermission", {});
      debugPrint(result.toString());
      return result["status"];
    } on PlatformException catch (e, stack) {
      debugPrint("$stack");
    } catch (e) {
      rethrow;
    }
    return false;
  }
}
