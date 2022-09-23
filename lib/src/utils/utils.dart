import 'package:flutter/material.dart';

import '../../flutter_chat_ui_kit.dart';

class Utils {
  static const internetNotAvailable = "ERROR_INTERNET_UNAVAILABLE";

  static String getErrorTranslatedText(BuildContext context, String errorCode) {
    if (errorCode == internetNotAvailable) {
      return Translations.of(context).error_internet_unavailable;
    } else {}

    return Translations.of(context).something_went_wrong_error;
  }
}
