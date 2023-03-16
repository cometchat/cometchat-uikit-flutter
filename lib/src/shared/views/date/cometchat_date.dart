import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:intl/intl.dart';

enum DateTimePattern { timeFormat, dayDateFormat, dayDateTimeFormat }

/// Creates a widget that that gives default date UI.
class CometChatDate extends StatelessWidget {
  const CometChatDate(
      {Key? key,
      this.date,
      this.pattern,
      this.style = const DateStyle(),
      this.customDateString})
      : super(key: key);

  ///[date] is the date to be shown
  final DateTime? date;

  ///[pattern] formats the DateTime object
  final DateTimePattern? pattern;

  ///[style] contains properties that affects the appearance of this widget
  final DateStyle style;

  ///[customDateString] if not null is shown instead of date from DateTime object
  final String? customDateString;

  bool _isSameDate(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  bool _isSameWeek(DateTime dt1, DateTime dt2) {
    return dt1.difference(dt2) <= const Duration(days: 7) &&
        (dt1.add(Duration(days: -dt1.weekday)).day ==
            dt2.add(Duration(days: -dt2.weekday)).day);
  }

  String _getDateLogic1(DateTime _date, {required String timeFormatter}) {
    return DateFormat(timeFormatter).format(_date);
  }

  String _getDateLogic2(DateTime _date, BuildContext context,
      {required String dateFormatter, required String weekFormatter}) {
    DateTime _todayDate = DateTime.now();
    if (_isSameDate(_todayDate, _date)) {
      return Translations.of(context).today;
    } else if (_isSameDate(_todayDate, _date.add(const Duration(days: 1)))) {
      return Translations.of(context).yesterday;
    } else if (_isSameWeek(_todayDate, _date)) {
      return DateFormat(weekFormatter).format(_date);
    } else {
      return DateFormat(dateFormatter).format(_date);
    }
  }

  String _getDateLogic3(DateTime _date, BuildContext context,
      {required String timeFormatter,
      required String dateFormatter2,
      required String weekFormatter}) {
    DateTime _todayDate = DateTime.now();
    if (_isSameDate(_todayDate, _date)) {
      return DateFormat(timeFormatter).format(_date);
    } else if (_isSameDate(_todayDate, _date.add(const Duration(days: 1)))) {
      return Translations.of(context).yesterday;
    } else if (_isSameWeek(_todayDate, _date)) {
      return DateFormat(weekFormatter).format(_date);
    } else {
      return DateFormat(dateFormatter2).format(_date);
    }
  }

  String _getDate(
    DateTimePattern? datePattern,
    DateTime _date,
    BuildContext context, {
    String timeFormatter = "hh:mm a",
    String weekFormatter = "EEE",
    String dateFormatter = "d MMM, yyyy",
    String dateFormatter2 = "dd MM yyyy",
  }) {
    switch (datePattern) {
      case DateTimePattern.timeFormat:
        return _getDateLogic1(_date, timeFormatter: timeFormatter);
      case DateTimePattern.dayDateFormat:
        return _getDateLogic2(_date, context,
            dateFormatter: dateFormatter, weekFormatter: weekFormatter);
      case DateTimePattern.dayDateTimeFormat:
        return _getDateLogic3(_date, context,
            weekFormatter: weekFormatter,
            timeFormatter: timeFormatter,
            dateFormatter2: dateFormatter2);
      default:
        return _getDateLogic1(_date, timeFormatter: timeFormatter);
    }
  }

  @override
  Widget build(BuildContext context) {
    String _timeFormatter = "hh:mm a";
    String _weekFormatter = "EEE";
    String _dateFormatter = "d MMM, yyyy";
    String _dateFormatter2 = "dd-MM-yyyy";

    String _date;

    if (customDateString != null) {
      _date = customDateString!;
    } else {
      _date = _getDate(pattern, date ?? DateTime.now(), context,
          timeFormatter: _timeFormatter,
          weekFormatter: _weekFormatter,
          dateFormatter: _dateFormatter,
          dateFormatter2: _dateFormatter2);
    }

    return Container(
      padding: style.contentPadding ?? const EdgeInsets.all(2.0),
      height: style.height,
      width: style.width,
      decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius:
              BorderRadius.all(Radius.circular(style.borderRadius ?? 4.0)),
          border: style.border ??
              Border.all(
                  width: 1.0, color: const Color(0xff141414).withOpacity(0.14)),
          color: style.gradient == null
              ? style.isTransparentBackground == true
                  ? style.background?.withOpacity(0)
                  : style.background
              : (style.isTransparentBackground == true
                  ? const Color(0xff141414).withOpacity(0.84)
                  : const Color(0xff141414).withOpacity(0.04)),
          gradient:
              style.isTransparentBackground == true ? null : style.gradient),
      child: Text(
        _date,
        style: style.textStyle ??
            TextStyle(
                fontSize: 12.0,
                color: const Color(0xff141414).withOpacity(0.84)),
      ),
    );
  }
}
