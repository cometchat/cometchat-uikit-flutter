import 'package:flutter/foundation.dart';
import '../../../../../cometchat_uikit_shared.dart'
    show UIElementTypeConstants, ModelFieldConstants, DateTimeVisibilityMode;
import 'base_input_element.dart';
import 'text_input_placeholder.dart';
import '../../../../logging/cometchat_log.dart';

/// Represents a dropdown model class , used to draw dropdown .
class DateTimeElement extends BaseInputElement<String> {
  DateTimeElement({
    super.elementType = UIElementTypeConstants.dateTime,
    required super.elementId,
    required this.label,
    this.mode = DateTimeVisibilityMode.dateTime,
    this.from,
    this.to,
    this.placeholder,
    this.dateTimeFormat,
    this.defaultDateTime,
    String? response,
    super.defaultValue,
    bool? optional,
    this.formattedResponse,
  }) : super(optional: optional ?? true);

  String label;
  DateTimeVisibilityMode mode;
  DateTime? from;
  DateTime? to;
  TextInputPlaceholder? placeholder;
  DateTime? formattedResponse;
  String? dateTimeFormat;
  DateTime? defaultDateTime;

  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = super.toMap();
    map[ModelFieldConstants.label] = label;
    return map;
  }

  factory DateTimeElement.fromMap(dynamic map) {
    DateTimeVisibilityMode mode;

    switch (map[ModelFieldConstants.mode]) {
      case "date":
        mode = DateTimeVisibilityMode.date;
        break;
      case "dateTime":
        mode = DateTimeVisibilityMode.dateTime;
        break;
      case "time":
        mode = DateTimeVisibilityMode.time;
        break;
      default:
        mode = DateTimeVisibilityMode.dateTime;
        break;
    }

    DateTime? from;
    DateTime? to;
    DateTime? defaultDateTime;

    // One try per value. Sharing a block made `from` the gatekeeper for
    // `defaultValue`: a payload carrying a default but no lower bound threw on
    // the `from` parse and never reached the default, so the picker opened
    // with no pre-selection even though the server had sent one. `to` was
    // always parsed separately, which is the shape the other two now follow.
    final bool timeOnly = mode == DateTimeVisibilityMode.time;

    try {
      final rawFrom = map[ModelFieldConstants.from];
      from = DateTime.parse(
        timeOnly ? cometchatConstantString + rawFrom : rawFrom,
      );
    } catch (_) {}

    try {
      final rawDefault = map[ModelFieldConstants.defaultValue];
      defaultDateTime = DateTime.parse(
        timeOnly ? cometchatConstantString + rawDefault : rawDefault,
      );
    } catch (_) {}

    try {
      final rawTo = map[ModelFieldConstants.to];
      to = DateTime.parse(timeOnly ? cometchatConstantString + rawTo : rawTo);
    } catch (_) {}

    if (kDebugMode) {
      ccLog("_defaultDateTime is $defaultDateTime");
    }
    return DateTimeElement(
      elementType: map[ModelFieldConstants.elementType],
      elementId: map[ModelFieldConstants.elementId],
      optional: map[ModelFieldConstants.optional],
      label: map[ModelFieldConstants.label],
      defaultValue: map[ModelFieldConstants.defaultValue],
      defaultDateTime: defaultDateTime,
      formattedResponse: defaultDateTime,
      //response:map[ModelFieldConstants.response],
      mode: mode,
      placeholder: map[ModelFieldConstants.placeholder],
      from: from,
      to: to,
      dateTimeFormat: map[ModelFieldConstants.dateTimeFormat],
    );
  }

  @override
  bool validateResponse() {
    if (response == null) return false;
    return true;
  }
}

String cometchatConstantString = "1970-01-01T";
